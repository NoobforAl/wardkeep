//! A minimal SOCKS5 server (no auth, CONNECT only) — all the Go core needs.

use std::net::{Ipv4Addr, Ipv6Addr};
use std::time::Duration;

use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

/// Where a SOCKS client wants to connect.
#[derive(Debug, Clone, PartialEq)]
pub struct Target {
    pub host: String,
    pub port: u16,
}

/// SOCKS5 reply codes we send.
pub mod reply {
    pub const SUCCEEDED: u8 = 0x00;
    pub const GENERAL_FAILURE: u8 = 0x01;
    pub const HOST_UNREACHABLE: u8 = 0x04;
    pub const COMMAND_NOT_SUPPORTED: u8 = 0x07;
}

/// How long a client has to send its greeting and CONNECT request. A local
/// program that connects and says nothing must not keep a task (and a socket) forever.
pub const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);

/// `handshake`, giving up with `TimedOut` after `limit`.
pub async fn handshake_within<S: AsyncRead + AsyncWrite + Unpin>(
    s: &mut S,
    limit: Duration,
) -> std::io::Result<Target> {
    tokio::time::timeout(limit, handshake(s))
        .await
        .unwrap_or_else(|_| {
            Err(std::io::Error::new(
                std::io::ErrorKind::TimedOut,
                "SOCKS handshake timed out",
            ))
        })
}

/// Reads the greeting and the CONNECT request. On an unsupported request it
/// replies with an error itself and returns Err.
pub async fn handshake<S: AsyncRead + AsyncWrite + Unpin>(s: &mut S) -> std::io::Result<Target> {
    let bad = |m: &str| std::io::Error::new(std::io::ErrorKind::InvalidData, m.to_string());
    let mut head = [0u8; 2];
    s.read_exact(&mut head).await?;
    if head[0] != 5 {
        return Err(bad("not SOCKS5"));
    }
    let mut methods = vec![0u8; head[1] as usize];
    s.read_exact(&mut methods).await?;
    if !methods.contains(&0) {
        s.write_all(&[5, 0xff]).await?;
        return Err(bad("client requires authentication"));
    }
    s.write_all(&[5, 0]).await?;

    let mut req = [0u8; 4];
    s.read_exact(&mut req).await?;
    if req[0] != 5 {
        return Err(bad("bad request version"));
    }
    if req[1] != 1 {
        send_reply(s, reply::COMMAND_NOT_SUPPORTED).await?;
        return Err(bad("only CONNECT is supported"));
    }
    let host = match req[3] {
        1 => {
            let mut a = [0u8; 4];
            s.read_exact(&mut a).await?;
            Ipv4Addr::from(a).to_string()
        }
        3 => {
            let mut len = [0u8; 1];
            s.read_exact(&mut len).await?;
            let mut name = vec![0u8; len[0] as usize];
            s.read_exact(&mut name).await?;
            String::from_utf8(name).map_err(|_| bad("bad host name"))?
        }
        4 => {
            let mut a = [0u8; 16];
            s.read_exact(&mut a).await?;
            Ipv6Addr::from(a).to_string()
        }
        _ => return Err(bad("bad address type")),
    };
    let mut port = [0u8; 2];
    s.read_exact(&mut port).await?;
    Ok(Target {
        host,
        port: u16::from_be_bytes(port),
    })
}

/// Sends a reply with an all-zero bound address.
pub async fn send_reply<S: AsyncWrite + Unpin>(s: &mut S, code: u8) -> std::io::Result<()> {
    s.write_all(&[5, code, 0, 1, 0, 0, 0, 0, 0, 0]).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn parses_domain_connect() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server).await });
        client.write_all(&[5, 1, 0]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, 0]);
        let mut req = vec![5, 1, 0, 3, 11];
        req.extend_from_slice(b"example.com");
        req.extend_from_slice(&443u16.to_be_bytes());
        client.write_all(&req).await.unwrap();
        let t = task.await.unwrap().unwrap();
        assert_eq!(
            t,
            Target {
                host: "example.com".into(),
                port: 443
            }
        );
    }

    #[tokio::test]
    async fn silent_client_times_out() {
        // The client connects and never sends a byte.
        let (_client, mut server) = tokio::io::duplex(256);
        let err = handshake_within(&mut server, Duration::from_millis(50))
            .await
            .unwrap_err();
        assert_eq!(err.kind(), std::io::ErrorKind::TimedOut);
    }

    #[tokio::test]
    async fn stalled_halfway_times_out() {
        // The greeting arrives, the request never does.
        let (mut client, mut server) = tokio::io::duplex(256);
        let task =
            tokio::spawn(
                async move { handshake_within(&mut server, Duration::from_millis(100)).await },
            );
        client.write_all(&[5, 1, 0]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, 0]);
        let err = task.await.unwrap().unwrap_err();
        assert_eq!(err.kind(), std::io::ErrorKind::TimedOut);
    }

    #[tokio::test]
    async fn prompt_client_is_not_cut_off() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task =
            tokio::spawn(async move { handshake_within(&mut server, HANDSHAKE_TIMEOUT).await });
        client.write_all(&[5, 1, 0]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        let mut req = vec![5, 1, 0, 1, 127, 0, 0, 1];
        req.extend_from_slice(&80u16.to_be_bytes());
        client.write_all(&req).await.unwrap();
        let t = task.await.unwrap().unwrap();
        assert_eq!((t.host.as_str(), t.port), ("127.0.0.1", 80));
    }

    #[tokio::test]
    async fn rejects_udp_associate() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server).await });
        client.write_all(&[5, 1, 0]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        client
            .write_all(&[5, 3, 0, 1, 0, 0, 0, 0, 0, 0])
            .await
            .unwrap();
        let mut rep = [0u8; 10];
        client.read_exact(&mut rep).await.unwrap();
        assert_eq!(rep[1], reply::COMMAND_NOT_SUPPORTED);
        assert!(task.await.unwrap().is_err());
    }
}
