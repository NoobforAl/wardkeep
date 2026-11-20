// Copyright (C) 2024-2025 PDG Global Limited (Hong Kong)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Ported to Wardkeep from rvpn-core v1.3.9, rvpn/crates/rvpn-client/src/websocket.rs: the Chrome-like
// upgrade headers and `split_websocket` (writer, reader and ping tasks on bounded channels). Changed: the
// TLS underneath is rustls with webpki roots instead of BoringSSL, the helper tasks are aborted when the
// handle drops, and nothing is logged with an address.

//! The WebSocket under the tunnel: TCP, TLS (rustls, ALPN `http/1.1`), the upgrade, and the task split.

use std::sync::{Arc, OnceLock};
use std::time::Duration;

use futures::{SinkExt, StreamExt};
use rand::{Rng, SeedableRng};
use tokio::io::{AsyncRead, AsyncWrite};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::tungstenite::handshake::client::generate_key;
use tokio_tungstenite::tungstenite::http::Request;

pub use tokio_tungstenite::tungstenite::Message;

use crate::error::{ConnectError, from_tls_io, from_ws, io_kind};
use crate::server::bracketed;

/// DNS and TCP to one host.
const TCP_TIMEOUT: Duration = Duration::from_secs(10);

/// TLS and the upgrade, after TCP.
const UPGRADE_TIMEOUT: Duration = Duration::from_secs(15);

/// Capacity of the bounded channels of [`split`]. Bounded on purpose (upstream: an unbounded reader
/// leaked memory under a stalled consumer); backpressure reaches TCP instead of the heap.
const CHANNEL_CAPACITY: usize = 256;

/// The User-Agent of the upgrade: Chrome 131, as upstream sends.
const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

/// The TLS client configuration, built once: webpki roots, the ring provider, ALPN `http/1.1` only.
/// HTTP/2 would drop the Upgrade header, and the server would answer with its decoy page.
fn tls_config() -> Result<Arc<rustls::ClientConfig>, ConnectError> {
    static CONFIG: OnceLock<Option<Arc<rustls::ClientConfig>>> = OnceLock::new();
    CONFIG
        .get_or_init(|| {
            let roots = rustls::RootCertStore {
                roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
            };

            let provider = Arc::new(rustls::crypto::ring::default_provider());
            let mut config = rustls::ClientConfig::builder_with_provider(provider)
                .with_safe_default_protocol_versions()
                .ok()?
                .with_root_certificates(roots)
                .with_no_client_auth();
            config.alpn_protocols = vec![b"http/1.1".to_vec()];
            Some(Arc::new(config))
        })
        .clone()
        .ok_or_else(|| ConnectError::tls("no TLS configuration"))
}

/// The upgrade request with upstream's Chrome-like headers. No `Sec-WebSocket-Extensions`: without
/// permessage-deflate offered, the server cannot turn compression on.
fn upgrade_request(host: &str, port: u16, path: &str) -> Result<Request<()>, ConnectError> {
    let authority = format!("{}:{port}", bracketed(host));
    Request::builder()
        .method("GET")
        .uri(format!("wss://{authority}{path}"))
        .header("Host", &authority)
        .header("Connection", "Upgrade")
        .header("Upgrade", "websocket")
        .header("Sec-WebSocket-Version", "13")
        .header("Sec-WebSocket-Key", generate_key())
        .header("User-Agent", USER_AGENT)
        .header("Accept", "*/*")
        .header("Accept-Encoding", "gzip, deflate, br")
        .header("Accept-Language", "en-US,en;q=0.9")
        .header("Cache-Control", "no-cache")
        .header("Pragma", "no-cache")
        .header("Sec-Fetch-Dest", "websocket")
        .header("Sec-Fetch-Mode", "websocket")
        .header("Sec-Fetch-Site", "same-origin")
        .body(())
        .map_err(|_| ConnectError::upgrade("the upgrade request could not be built"))
}

/// The WebSocket upgrade over an established stream (TLS in the binary; plain TCP in the tests).
pub async fn upgrade<S>(
    stream: S,
    host: &str,
    port: u16,
    path: &str,
) -> Result<WebSocketStream<S>, ConnectError>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let request = upgrade_request(host, port, path)?;
    let (ws, _response) = tokio_tungstenite::client_async(request, stream)
        .await
        .map_err(|err| from_ws(&err))?;
    Ok(ws)
}

/// The stream the tunnel runs on in the binary.
pub type TlsStream = tokio_rustls::client::TlsStream<TcpStream>;

/// TCP, TLS (the certificate checked against the webpki roots for `host`; SNI = `host`, none for an IP
/// literal) and the upgrade to `wss://host:port/path`.
pub async fn connect(
    host: &str,
    port: u16,
    path: &str,
) -> Result<WebSocketStream<TlsStream>, ConnectError> {
    let tcp = tokio::time::timeout(TCP_TIMEOUT, TcpStream::connect((host, port)))
        .await
        .map_err(|_| ConnectError::network("TCP connect timed out"))?
        .map_err(|err| ConnectError::network(io_kind(&err)))?;
    let _ = tcp.set_nodelay(true);

    let name = rustls::pki_types::ServerName::try_from(host.to_string())
        .map_err(|_| ConnectError::tls("the host is not a valid TLS server name"))?;
    let connector = tokio_rustls::TlsConnector::from(tls_config()?);

    tokio::time::timeout(UPGRADE_TIMEOUT, async {
        let tls = connector
            .connect(name, tcp)
            .await
            .map_err(|err| from_tls_io(&err))?;
        upgrade(tls, host, port, path).await
    })
    .await
    .map_err(|_| ConnectError::network("TLS or the upgrade timed out"))?
}

/// The receiving side of a split WebSocket.
pub type Reader = mpsc::Receiver<Message>;

/// The sending side of a split WebSocket.
#[derive(Clone)]
pub struct Writer {
    sender: mpsc::Sender<Message>,
}

impl Writer {
    /// Queues a message for the writer task; waits while the channel is full (backpressure).
    pub async fn send(&self, msg: Message) -> Result<(), Closed> {
        self.sender.send(msg).await.map_err(|_| Closed)
    }

    #[cfg(test)]
    pub(crate) fn from_sender(sender: mpsc::Sender<Message>) -> Writer {
        Writer { sender }
    }
}

/// The WebSocket's writer task is gone.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Closed;

impl std::fmt::Display for Closed {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("the WebSocket is closed")
    }
}

impl std::error::Error for Closed {}

/// The reader, writer and ping tasks of a split WebSocket. Dropping it (or [`Tasks::stop`]) aborts them,
/// so a dead tunnel's ping task cannot keep its socket open.
pub struct Tasks {
    joins: std::sync::Mutex<Vec<JoinHandle<()>>>,
}

impl Tasks {
    pub fn stop(&self) {
        let joins = std::mem::take(
            &mut *self
                .joins
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner),
        );
        for join in joins {
            join.abort();
        }
    }

    #[cfg(test)]
    pub(crate) fn none() -> Tasks {
        Tasks {
            joins: std::sync::Mutex::new(Vec::new()),
        }
    }
}

impl Drop for Tasks {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Splits the WebSocket into a reader channel, a writer channel, and the tasks between them and the
/// socket, plus a task that sends a WebSocket ping every 8 to 14 s (jittered, as upstream).
pub fn split<S>(ws: WebSocketStream<S>) -> (Reader, Writer, Tasks)
where
    S: AsyncRead + AsyncWrite + Unpin + Send + 'static,
{
    let (mut sink, mut stream) = ws.split();

    let (to_ws, mut from_app) = mpsc::channel::<Message>(CHANNEL_CAPACITY);
    let (to_app, app_rx) = mpsc::channel::<Message>(CHANNEL_CAPACITY);

    let writer = tokio::spawn(async move {
        while let Some(msg) = from_app.recv().await {
            if let Err(err) = sink.send(msg).await {
                tracing::debug!(op = "tunnel", err = %err, "WebSocket send failed");
                break;
            }
        }

        let _ = sink.close().await;
    });

    let pinger = {
        let to_ws = to_ws.clone();
        tokio::spawn(async move {
            let mut rng = rand::rngs::StdRng::from_entropy();
            tokio::time::sleep(Duration::from_millis(rng.gen_range(5000..=8000))).await;
            loop {
                // A full channel means TCP backpressure: skip this ping, the next one gets through.
                match to_ws.try_send(Message::Ping(Vec::new().into())) {
                    Ok(()) | Err(mpsc::error::TrySendError::Full(_)) => {}
                    Err(mpsc::error::TrySendError::Closed(_)) => break,
                }

                tokio::time::sleep(Duration::from_millis(rng.gen_range(8000..=14000))).await;
            }
        })
    };

    // When this task ends it drops `to_app`, and the reader sees the end of the channel.
    let reader = tokio::spawn(async move {
        while let Some(item) = stream.next().await {
            match item {
                Ok(msg) => {
                    if to_app.send(msg).await.is_err() {
                        break;
                    }
                }

                Err(err) => {
                    tracing::debug!(op = "tunnel", err = %err, "WebSocket receive failed");
                    break;
                }
            }
        }
    });

    let tasks = Tasks {
        joins: std::sync::Mutex::new(vec![reader, writer, pinger]),
    };

    (app_rx, Writer { sender: to_ws }, tasks)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_has_the_chrome_headers() {
        let request = upgrade_request("2001:db8::1", 8443, "/ws/mux").unwrap();
        assert_eq!(request.uri().to_string(), "wss://[2001:db8::1]:8443/ws/mux");

        let headers = request.headers();
        assert_eq!(headers["Host"], "[2001:db8::1]:8443");
        assert_eq!(headers["Upgrade"], "websocket");
        assert_eq!(headers["Sec-WebSocket-Version"], "13");
        assert_eq!(headers["User-Agent"], USER_AGENT);
        assert_eq!(headers["Sec-Fetch-Mode"], "websocket");
        assert!(!headers.contains_key("Sec-WebSocket-Extensions"));
        // Upstream's comment says 15 headers; it sends these 14.
        assert_eq!(headers.len(), 14);
    }

    #[test]
    fn tls_offers_only_http1() {
        let config = tls_config().unwrap();
        assert_eq!(config.alpn_protocols, vec![b"http/1.1".to_vec()]);
    }
}
