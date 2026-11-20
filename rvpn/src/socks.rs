//! A minimal SOCKS5 server: CONNECT only, no auth or username/password auth (RFC 1929). The same server as
//! tor/src/socks.rs plus the password check: the Go core always starts this process with a random user and
//! password, so another local program cannot use the tunnel.

use std::net::{Ipv4Addr, Ipv6Addr};
use std::time::Duration;

use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

/// Where a SOCKS client wants to connect.
#[derive(Debug, Clone, PartialEq)]
pub struct Target {
    pub host: String,
    pub port: u16,
}

/// The user and password a client must send (RFC 1929).
#[derive(Clone, PartialEq)]
pub struct Credentials {
    pub user: String,
    pub pass: String,
}

/// Never the password in a debug print.
impl std::fmt::Debug for Credentials {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Credentials(..)")
    }
}

/// The protocol version byte that starts every SOCKS5 message.
const VERSION: u8 = 5;

/// Auth method "no authentication".
const NO_AUTH: u8 = 0x00;

/// Auth method "username/password" (RFC 1929).
const USER_PASS: u8 = 0x02;

/// Auth method reply "none of your methods is acceptable".
const NO_ACCEPTABLE_METHOD: u8 = 0xff;

/// Version byte of the username/password sub-negotiation, and its two statuses.
const AUTH_VERSION: u8 = 1;
const AUTH_OK: u8 = 0;
const AUTH_FAILED: u8 = 1;

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
    pub const COMMAND_NOT_SUPPORTED: u8 = 0x07;
    pub const ADDRESS_NOT_SUPPORTED: u8 = 0x08;
}

/// How long a client has to send its greeting, password and CONNECT request. A local program that
/// connects and says nothing must not keep a task (and a socket) forever.
pub const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);

/// Converts a message to an `InvalidData` error.
fn bad(msg: &str) -> std::io::Error {
    std::io::Error::new(std::io::ErrorKind::InvalidData, msg.to_string())
}

/// `handshake`, giving up with `TimedOut` after `limit`.
pub async fn handshake_within<S: AsyncRead + AsyncWrite + Unpin>(
    stream: &mut S,
    auth: Option<&Credentials>,
    limit: Duration,
) -> std::io::Result<Target> {
    tokio::time::timeout(limit, handshake(stream, auth))
        .await
        .unwrap_or_else(|_| {
            Err(std::io::Error::new(
                std::io::ErrorKind::TimedOut,
                "timed out waiting for SOCKS handshake",
            ))
        })
}

/// Equal in time that depends only on the lengths, not on where the bytes differ.
fn same(a: &[u8], b: &[u8]) -> bool {
    rvpn_core::crypto::constant_time_eq(a, b)
}

/// Reads `[LEN][LEN bytes]`, the shape of a name or a password field.
async fn read_field<S: AsyncRead + Unpin>(stream: &mut S) -> std::io::Result<Vec<u8>> {
    let mut len = [0u8; 1];
    stream.read_exact(&mut len).await?;

    let mut field = vec![0u8; usize::from(len[0])];
    stream.read_exact(&mut field).await?;
    Ok(field)
}

/// Reads the greeting, the password when `auth` is set, and the CONNECT request. On an unsupported or
/// refused request it replies with an error itself and returns Err.
///
/// ```text
///  client                                              server (us)
///    | 1. greeting  [VER=5][NMETHODS=n][METHODS: n bytes]   |
///    |----------------------------------------------------->|
///    | 2. choice    [VER=5][METHOD]  0 = none, 2 = password |
///    |<-----------------------------------------------------|  (0xff = refused)
///    | 2a. only with METHOD=2 (RFC 1929):                   |
///    |    [VER=1][ULEN][USER][PLEN][PASS]                   |
///    |----------------------------------------------------->|
///    |    [VER=1][STATUS]  0 = accepted, else closed        |
///    |<-----------------------------------------------------|
///    | 3. request   [VER=5][CMD=1][RSV=0][ATYP][ADDR][PORT] |
///    |----------------------------------------------------->|
///    |    ATYP=1 IPv4: 4 bytes, 3 domain: [LEN][name],      |
///    |    4 IPv6: 16 bytes; PORT 2 bytes big-endian         |
/// ```
///
/// The reply to the request (step 4) is sent later by the caller with `send_reply`.
pub async fn handshake<S: AsyncRead + AsyncWrite + Unpin>(
    stream: &mut S,
    auth: Option<&Credentials>,
) -> std::io::Result<Target> {
    // 1. Greeting: version and how many auth methods follow.
    let mut head = [0u8; 2];

    stream.read_exact(&mut head).await?;
    if head[0] != VERSION {
        return Err(bad("not SOCKS5"));
    }

    // At most 255 methods: a stack buffer, not a heap allocation per connection.
    let mut methods = [0u8; 255];
    let methods = &mut methods[..usize::from(head[1])];

    stream.read_exact(methods).await?;

    // 2. Choice: the password when one is set (and then nothing else), else "no auth".
    let wanted = if auth.is_some() { USER_PASS } else { NO_AUTH };
    if !methods.contains(&wanted) {
        stream.write_all(&[VERSION, NO_ACCEPTABLE_METHOD]).await?;
        return Err(bad("client does not offer the required auth method"));
    }

    stream.write_all(&[VERSION, wanted]).await?;

    if let Some(expected) = auth {
        let mut version = [0u8; 1];
        stream.read_exact(&mut version).await?;
        if version[0] != AUTH_VERSION {
            return Err(bad("bad auth version"));
        }

        let user = read_field(stream).await?;
        let pass = read_field(stream).await?;

        // Both compared, always: `&` does not short-circuit.
        let accepted =
            same(&user, expected.user.as_bytes()) & same(&pass, expected.pass.as_bytes());
        if !accepted {
            stream.write_all(&[AUTH_VERSION, AUTH_FAILED]).await?;
            return Err(bad("wrong SOCKS user or password"));
        }

        stream.write_all(&[AUTH_VERSION, AUTH_OK]).await?;
    }

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
            let name = read_field(stream).await?;
            if name.is_empty() {
                send_reply(stream, reply::ADDRESS_NOT_SUPPORTED).await?;
                return Err(bad("empty host name"));
            }

            String::from_utf8(name).map_err(|_| bad("bad host name"))?
        }

        ATYP_IPV6 => {
            let mut octets = [0u8; 16];
            stream.read_exact(&mut octets).await?;

            Ipv6Addr::from(octets).to_string()
        }

        _ => {
            send_reply(stream, reply::ADDRESS_NOT_SUPPORTED).await?;
            return Err(bad("bad address type"));
        }
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

    fn creds() -> Credentials {
        Credentials {
            user: "u1".into(),
            pass: "secret".into(),
        }
    }

    /// The client side of RFC 1929: `[1][ULEN][USER][PLEN][PASS]`.
    fn auth_message(user: &str, pass: &str) -> Vec<u8> {
        let mut msg = vec![AUTH_VERSION, u8::try_from(user.len()).unwrap()];
        msg.extend_from_slice(user.as_bytes());
        msg.push(u8::try_from(pass.len()).unwrap());
        msg.extend_from_slice(pass.as_bytes());
        msg
    }

    fn connect_domain(name: &str, port: u16) -> Vec<u8> {
        let mut req = vec![5, 1, 0, ATYP_DOMAIN, u8::try_from(name.len()).unwrap()];
        req.extend_from_slice(name.as_bytes());
        req.extend_from_slice(&port.to_be_bytes());
        req
    }

    #[tokio::test]
    async fn parses_domain_connect() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server, None).await });

        client.write_all(&[5, 1, 0]).await.unwrap();

        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, 0]);

        client
            .write_all(&connect_domain("example.com", 443))
            .await
            .unwrap();

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
    async fn parses_ipv4_and_ipv6() {
        for (atyp, addr, want) in [
            (ATYP_IPV4, vec![192, 0, 2, 1], "192.0.2.1"),
            (
                ATYP_IPV6,
                Ipv6Addr::new(0x2001, 0xdb8, 0, 0, 0, 0, 0, 1)
                    .octets()
                    .to_vec(),
                "2001:db8::1",
            ),
        ] {
            let (mut client, mut server) = tokio::io::duplex(256);
            let task = tokio::spawn(async move { handshake(&mut server, None).await });
            client.write_all(&[5, 1, 0]).await.unwrap();
            let mut resp = [0u8; 2];
            client.read_exact(&mut resp).await.unwrap();

            let mut req = vec![5, 1, 0, atyp];
            req.extend_from_slice(&addr);
            req.extend_from_slice(&80u16.to_be_bytes());
            client.write_all(&req).await.unwrap();

            let target = task.await.unwrap().unwrap();
            assert_eq!((target.host.as_str(), target.port), (want, 80));
        }
    }

    #[tokio::test]
    async fn password_accepted() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server, Some(&creds())).await });

        // The client offers both; the server picks the password.
        client.write_all(&[5, 2, NO_AUTH, USER_PASS]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, USER_PASS]);

        client
            .write_all(&auth_message("u1", "secret"))
            .await
            .unwrap();
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [AUTH_VERSION, AUTH_OK]);

        client
            .write_all(&connect_domain("example.org", 8443))
            .await
            .unwrap();
        let target = task.await.unwrap().unwrap();
        assert_eq!((target.host.as_str(), target.port), ("example.org", 8443));
    }

    #[tokio::test]
    async fn wrong_password_refused() {
        for (user, pass) in [
            ("u1", "secreT"),
            ("u2", "secret"),
            ("u1", "secret2"),
            ("", ""),
        ] {
            let (mut client, mut server) = tokio::io::duplex(256);
            let task = tokio::spawn(async move { handshake(&mut server, Some(&creds())).await });

            client.write_all(&[5, 1, USER_PASS]).await.unwrap();
            let mut resp = [0u8; 2];
            client.read_exact(&mut resp).await.unwrap();
            client.write_all(&auth_message(user, pass)).await.unwrap();
            client.read_exact(&mut resp).await.unwrap();
            assert_eq!(resp, [AUTH_VERSION, AUTH_FAILED], "{user}/{pass}");
            assert!(task.await.unwrap().is_err());
        }
    }

    /// With a password set, a client that only offers "no auth" is refused before anything else.
    #[tokio::test]
    async fn password_required() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server, Some(&creds())).await });

        client.write_all(&[5, 1, NO_AUTH]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, NO_ACCEPTABLE_METHOD]);
        assert!(task.await.unwrap().is_err());
    }

    /// Without a password, a client that insists on one is refused.
    #[tokio::test]
    async fn no_auth_only_without_password() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server, None).await });

        client.write_all(&[5, 1, USER_PASS]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        assert_eq!(resp, [5, NO_ACCEPTABLE_METHOD]);
        assert!(task.await.unwrap().is_err());
    }

    #[tokio::test]
    async fn silent_client_times_out() {
        let (_client, mut server) = tokio::io::duplex(256);
        let err = handshake_within(&mut server, None, Duration::from_millis(50))
            .await
            .unwrap_err();

        assert_eq!(err.kind(), std::io::ErrorKind::TimedOut);
    }

    #[tokio::test]
    async fn rejects_udp_associate_and_bind() {
        for cmd in [2u8, 3] {
            let (mut client, mut server) = tokio::io::duplex(256);
            let task = tokio::spawn(async move { handshake(&mut server, None).await });

            client.write_all(&[5, 1, 0]).await.unwrap();
            let mut resp = [0u8; 2];
            client.read_exact(&mut resp).await.unwrap();
            client
                .write_all(&[5, cmd, 0, 1, 0, 0, 0, 0, 0, 0])
                .await
                .unwrap();

            let mut rep = [0u8; 10];
            client.read_exact(&mut rep).await.unwrap();
            assert_eq!(rep[1], reply::COMMAND_NOT_SUPPORTED);
            assert!(task.await.unwrap().is_err());
        }
    }

    #[tokio::test]
    async fn rejects_bad_address_type() {
        let (mut client, mut server) = tokio::io::duplex(256);
        let task = tokio::spawn(async move { handshake(&mut server, None).await });

        client.write_all(&[5, 1, 0]).await.unwrap();
        let mut resp = [0u8; 2];
        client.read_exact(&mut resp).await.unwrap();
        client.write_all(&[5, 1, 0, 9]).await.unwrap();

        let mut rep = [0u8; 10];
        client.read_exact(&mut rep).await.unwrap();
        assert_eq!(rep[1], reply::ADDRESS_NOT_SUPPORTED);
        assert!(task.await.unwrap().is_err());
    }

    #[test]
    fn credentials_debug_hides_the_password() {
        assert_eq!(format!("{:?}", creds()), "Credentials(..)");
    }
}
