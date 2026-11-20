//! End to end in one process: the real client (upgrade, handshake, tunnel, relay) against a fake rVPN
//! server task that plays upstream's server side (rvpn-server handler.rs: ServerHello, X3DH as responder,
//! `DoubleRatchet::init_bob`) and echoes each flow's data. Plain TCP under the WebSocket, through the
//! `ws::upgrade` seam: TLS is the only part not covered.

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::time::Duration;

    use futures::{SinkExt, StreamExt};
    use rvpn_core::crypto::{DoubleRatchet, IdentityKey, RatchetMessage, X3DHResponder};
    use rvpn_core::protocol::padding::{pad_packet, unpad_packet};
    use rvpn_core::protocol::{ControlMessage, HandshakeMessage, MultiplexedFrame, PayloadType};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::{TcpListener, TcpStream};
    use tokio::sync::mpsc;
    use tokio_tungstenite::tungstenite::Message;
    use tokio_tungstenite::tungstenite::handshake::server::{ErrorResponse, Request, Response};

    use crate::error::Code;
    use crate::handshake::tests::server_hello;
    use crate::tunnel::{Tunnel, relay};
    use crate::ws;

    const PATH: &str = "/ws/mux";

    /// What the fake server saw, in order.
    #[derive(Debug, PartialEq)]
    enum Seen {
        Create {
            flow: u32,
            target: String,
            port: u16,
        },
        Data {
            flow: u32,
            len: usize,
        },
        Window {
            flow: u32,
            credits: u32,
        },
        Close {
            flow: u32,
        },
    }

    async fn send(
        ws: &mut tokio_tungstenite::WebSocketStream<TcpStream>,
        ratchet: &mut DoubleRatchet,
        frame: &MultiplexedFrame,
        kind: PayloadType,
    ) {
        let padded = pad_packet(&frame.encode().unwrap()).unwrap();
        let msg = ratchet.encrypt(&padded, &[kind as u8]).unwrap();
        ws.send(Message::Binary(msg.to_bytes().unwrap().into()))
            .await
            .unwrap();
    }

    /// One connection of the fake server: the path check, the responder handshake, then echo.
    async fn fake_server(
        listener: TcpListener,
        responder: X3DHResponder,
        seen: mpsc::UnboundedSender<Seen>,
    ) {
        let (tcp, _) = listener.accept().await.unwrap();
        #[allow(
            clippy::result_large_err,
            reason = "the error type is tungstenite's callback signature"
        )]
        let check_path = |request: &Request,
                          response: Response|
         -> Result<Response, ErrorResponse> {
            if request.uri().path() == PATH {
                Ok(response)
            } else {
                // The decoy page of a wrong path.
                let mut decoy = ErrorResponse::new(Some("<html>hello</html>".into()));
                *decoy.status_mut() = tokio_tungstenite::tungstenite::http::StatusCode::NOT_FOUND;
                Err(decoy)
            }
        };
        let Ok(mut ws) = tokio_tungstenite::accept_hdr_async(tcp, check_path).await else {
            return;
        };

        // Hello -> X3DH (responder) -> ServerHello.
        let Some(Ok(Message::Binary(hello))) = ws.next().await else {
            panic!("no Hello")
        };
        let HandshakeMessage::Hello {
            ephemeral_key: Some(ephemeral),
            identity_key: Some(identity),
            ..
        } = serde_json::from_slice(&hello).unwrap()
        else {
            panic!("not a Hello")
        };
        let shared = responder
            .agree(
                &identity.try_into().unwrap(),
                &ephemeral.try_into().unwrap(),
                false,
            )
            .unwrap();
        let mut ratchet = DoubleRatchet::init_bob(shared);
        let hello = server_hello(&responder.get_public_bundle(), true);
        ws.send(Message::Binary(serde_json::to_vec(&hello).unwrap().into()))
            .await
            .unwrap();

        while let Some(Ok(msg)) = ws.next().await {
            let Message::Binary(bytes) = msg else {
                continue;
            };
            let parsed = RatchetMessage::from_bytes(&bytes).unwrap();
            let plain = ratchet.decrypt(&parsed, &[]).unwrap();
            let frame = MultiplexedFrame::decode(&unpad_packet(&plain).unwrap()).unwrap();

            if frame.flow_id != 0 {
                let flow = frame.flow_id;
                let _ = seen.send(Seen::Data {
                    flow,
                    len: frame.payload.len(),
                });

                // Echo, and grant the client the credits back as if written to the target.
                let mut echo = b"echo:".to_vec();
                echo.extend_from_slice(&frame.payload);
                let data = MultiplexedFrame::new_data(flow, echo);
                send(&mut ws, &mut ratchet, &data, PayloadType::Data).await;

                let credits = u32::try_from(frame.payload.len()).unwrap();
                let update = MultiplexedFrame::new_control(&ControlMessage::WindowUpdate {
                    flow_id: flow,
                    window_size: credits,
                })
                .unwrap();
                send(&mut ws, &mut ratchet, &update, PayloadType::Admin).await;
                continue;
            }

            match frame.parse_control().unwrap() {
                ControlMessage::CreateFlow {
                    flow_id,
                    target,
                    port,
                } => {
                    let _ = seen.send(Seen::Create {
                        flow: flow_id,
                        target,
                        port,
                    });
                    let created = MultiplexedFrame::new_control(&ControlMessage::FlowCreated {
                        flow_id,
                        local_port: None,
                    })
                    .unwrap();
                    send(&mut ws, &mut ratchet, &created, PayloadType::Admin).await;
                }

                ControlMessage::WindowUpdate {
                    flow_id,
                    window_size,
                } => {
                    let _ = seen.send(Seen::Window {
                        flow: flow_id,
                        credits: window_size,
                    });
                }

                ControlMessage::CloseFlow { flow_id } => {
                    let _ = seen.send(Seen::Close { flow: flow_id });
                }

                ControlMessage::Ping { timestamp } => {
                    let pong =
                        MultiplexedFrame::new_control(&ControlMessage::Pong { timestamp }).unwrap();
                    send(&mut ws, &mut ratchet, &pong, PayloadType::Admin).await;
                }

                _ => {}
            }
        }
    }

    /// Starts the fake server with `responder`, and the client with `bundle` on `path`.
    async fn start(
        responder: X3DHResponder,
        bundle: &rvpn_core::crypto::X3DHPublicBundle,
        path: &str,
    ) -> (
        Result<Arc<Tunnel>, crate::error::ConnectError>,
        mpsc::UnboundedReceiver<Seen>,
    ) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let (seen_tx, seen) = mpsc::unbounded_channel();
        tokio::spawn(fake_server(listener, responder, seen_tx));

        let identity = Arc::new(IdentityKey::generate());
        let result = async {
            let tcp = TcpStream::connect(("127.0.0.1", port))
                .await
                .map_err(|_| crate::error::ConnectError::network("connect"))?;
            let ws = ws::upgrade(tcp, "127.0.0.1", port, path).await?;
            Tunnel::start(ws, &identity, bundle).await
        }
        .await;
        (result, seen)
    }

    async fn next(seen: &mut mpsc::UnboundedReceiver<Seen>) -> Seen {
        tokio::time::timeout(Duration::from_secs(5), seen.recv())
            .await
            .unwrap()
            .unwrap()
    }

    /// CreateFlow -> data -> echo through the ratchet -> WindowUpdate -> CloseFlow.
    #[tokio::test]
    async fn a_flow_through_the_real_ratchet() {
        let responder = X3DHResponder::new();
        let bundle = responder.get_public_bundle();
        let (tunnel, mut seen) = start(responder, &bundle, PATH).await;
        let tunnel = tunnel.unwrap();

        let flow = tunnel.open_flow("example.com", 443).await.unwrap();
        assert_eq!(
            next(&mut seen).await,
            Seen::Create {
                flow: 1,
                target: "example.com".into(),
                port: 443
            }
        );

        // The local application's side of the SOCKS connection.
        let (mut app, mut local) = tokio::io::duplex(64 * 1024);
        let relaying = tokio::spawn(async move { relay(&mut local, flow).await });

        app.write_all(b"hello").await.unwrap();
        assert_eq!(next(&mut seen).await, Seen::Data { flow: 1, len: 5 });

        let mut echo = [0u8; 10];
        app.read_exact(&mut echo).await.unwrap();
        assert_eq!(&echo, b"echo:hello");

        // The client granted the server the 10 bytes it wrote to the local socket.
        assert_eq!(
            next(&mut seen).await,
            Seen::Window {
                flow: 1,
                credits: 10
            }
        );

        // The application closes: the flow ends with CloseFlow.
        drop(app);
        relaying.await.unwrap();
        assert_eq!(next(&mut seen).await, Seen::Close { flow: 1 });
        tokio::time::timeout(Duration::from_secs(5), async {
            while tunnel.flow_count() > 0 {
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
        })
        .await
        .unwrap();
        assert!(tunnel.is_alive());

        // A second flow on the same tunnel gets the next id.
        let _second = tunnel.open_flow("192.0.2.1", 80).await.unwrap();
        assert_eq!(
            next(&mut seen).await,
            Seen::Create {
                flow: 2,
                target: "192.0.2.1".into(),
                port: 80
            }
        );
    }

    /// A server with another identity than the bundle's is refused before any flow.
    #[tokio::test]
    async fn another_server_identity_is_refused() {
        let bundle = X3DHResponder::new().get_public_bundle();
        let (tunnel, _seen) = start(X3DHResponder::new(), &bundle, PATH).await;
        assert_eq!(tunnel.err().unwrap().code, Code::Handshake);
    }

    /// A wrong path gets the decoy page: an upgrade error, not a network one.
    #[tokio::test]
    async fn a_wrong_path_is_an_upgrade_error() {
        let responder = X3DHResponder::new();
        let bundle = responder.get_public_bundle();
        let (tunnel, _seen) = start(responder, &bundle, "/ws").await;
        let err = tunnel.err().unwrap();
        assert_eq!(err.code, Code::Upgrade);
        assert_eq!(err.detail, "HTTP 404");
    }
}
