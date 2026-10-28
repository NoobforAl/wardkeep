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

/// The protocol version byte that starts every SOCKS5 message.
const VERSION: u8 = 5;

/// Auth method "no authentication".
const NO_AUTH: u8 = 0x00;

/// Auth method reply "none of your methods is acceptable".
const NO_ACCEPTABLE_METHOD: u8 = 0xff;

/// Request command CONNECT (open a TCP stream to the target).
const CMD_CONNECT: u8 = 1;

/// Address types of a request.
const ATYP_IPV4: u8 = 1;
const ATYP_DOMAIN: u8 = 3;
const ATYP_IPV6: u8 = 4;

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

/// Bad, Convert str message to std::io::Error with InvalidData kind.
fn bad(msg: &str) -> std::io::Error {
    std::io::Error::new(std::io::ErrorKind::InvalidData, msg.to_string())
}

/// `handshake`, giving up with `TimedOut` after `limit`.
pub async fn handshake_within<S: AsyncRead + AsyncWrite + Unpin>(
    stream: &mut S,
    limit: Duration,
) -> std::io::Result<Target> {
    tokio::time::timeout(limit, handshake(stream))
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
///
/// The stream is a pipe of bytes with no message boundaries: each `read_exact`
/// takes the next N bytes off it, so the code reads one field at a time, in the
/// order the client sends them:
///
/// ```text
///  client                                              server (us)
///    | 1. greeting  [VER=5][NMETHODS=n][METHODS: n bytes]   |
///    |----------------------------------------------------->|  read 2, then n
///    | 2. choice    [VER=5][METHOD=0 no auth]               |
///    |<-----------------------------------------------------|  (0xff = refused)
///    | 3. request   [VER=5][CMD=1][RSV=0][ATYP][ADDR][PORT] |
///    |----------------------------------------------------->|  read 4, ADDR, 2
///    |                                                      |
///    |    ATYP=1 IPv4:   ADDR = 4 bytes                     |
///    |    ATYP=3 domain: ADDR = [LEN][LEN bytes of name]    |
///    |    ATYP=4 IPv6:   ADDR = 16 bytes                    |
///    |    PORT = 2 bytes, big-endian (0x01 0xBB = 443)      |
/// ```
///
/// For example, CONNECT to example.com:443 arrives as
/// `05 01 00 | 05 01 00 03 0B "example.com" 01 BB`. The reply (step 4) is sent
/// later by the caller with `send_reply`, once Tor has opened the stream.
pub async fn handshake<S: AsyncRead + AsyncWrite + Unpin>(
    stream: &mut S,
) -> std::io::Result<Target> {
    // 1. Greeting: version and how many auth methods follow.
    let mut head = [0u8; 2];

    stream.read_exact(&mut head).await?;
    if head[0] != VERSION {
        return Err(bad("not SOCKS5"));
    }

    // At most 255 methods: a stack buffer, not a heap allocation per connection.
    let mut methods = [0u8; 255];
    let methods = &mut methods[..head[1] as usize];

    stream.read_exact(methods).await?;

    // 2. Choice: we only speak "no auth".
    if !methods.contains(&NO_AUTH) {
        stream.write_all(&[VERSION, NO_ACCEPTABLE_METHOD]).await?;
        return Err(bad("client requires authentication"));
    }

    stream.write_all(&[VERSION, NO_AUTH]).await?;

    // 3. Request: [VER][CMD][RSV][ATYP], then the address and the port.
    let mut req = [0u8; 4];
    stream.read_exact(&mut req).await?;
    if req[0] != VERSION {
        return Err(bad("bad request version"));
    }

    if req[1] != CMD_CONNECT {
        send_reply(stream, reply::COMMAND_NOT_SUPPORTED).await?;
        return Err(bad("only CONNECT is supported"));
    }

    let host = match req[3] {
        ATYP_IPV4 => {
            let mut octets = [0u8; 4];
            stream.read_exact(&mut octets).await?;
            Ipv4Addr::from(octets).to_string()
        }

        ATYP_DOMAIN => {
            let mut len = [0u8; 1];
            stream.read_exact(&mut len).await?;

            let mut name = vec![0u8; len[0] as usize];
            stream.read_exact(&mut name).await?;

            String::from_utf8(name).map_err(|_| bad("bad host name"))?
        }

        ATYP_IPV6 => {
            let mut octets = [0u8; 16];
            stream.read_exact(&mut octets).await?;

            Ipv6Addr::from(octets).to_string()
        }

        _ => return Err(bad("bad address type")),
    };

    let mut port = [0u8; 2];
    stream.read_exact(&mut port).await?;

    Ok(Target {
        host,
        port: u16::from_be_bytes(port),
    })
}

/// Sends a reply with an all-zero bound address:
/// `[VER=5][REP=code][RSV=0][ATYP=1][0.0.0.0][port 0]`.
pub async fn send_reply<S: AsyncWrite + Unpin>(stream: &mut S, code: u8) -> std::io::Result<()> {
    stream
        .write_all(&[VERSION, code, 0, ATYP_IPV4, 0, 0, 0, 0, 0, 0])
        .await
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

        let mut req = vec![5, 1, 0, ATYP_DOMAIN, 11];
        req.extend_from_slice(b"example.com");
        req.extend_from_slice(&443u16.to_be_bytes());
        client.write_all(&req).await.unwrap();

        let target = task.await.unwrap().unwrap();
        assert_eq!(
            target,
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

        let target = task.await.unwrap().unwrap();
        assert_eq!((target.host.as_str(), target.port), ("127.0.0.1", 80));
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
