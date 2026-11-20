//! The server to dial: `--server wss://HOST[:PORT][/PATH]` and the `--alt HOST` fallbacks.
//!
//! The multiplexed endpoint is `{PATH}/mux`, as upstream's client derives it (`derive_mux_path` in
//! rvpn-client/src/tunnel_pool.rs). Only `wss://` is accepted: the rVPN handshake is not meant to run in the
//! clear, and there is no fallback to `ws://`.

/// Where the tunnel connects. Every host shares the port, the path and the bundle.
#[derive(Debug, Clone, PartialEq)]
pub struct Server {
    /// The primary host first, then the `--alt` hosts, in the order given. IPv6 literals without brackets.
    pub hosts: Vec<String>,

    pub port: u16,

    /// The WebSocket path of the multiplexed endpoint, e.g. `/ws/mux`.
    pub mux_path: String,
}

impl Server {
    /// The URL of the upgrade request for host number `index` (brackets around an IPv6 literal).
    pub fn url(&self, index: usize) -> Option<String> {
        let host = self.hosts.get(index)?;
        Some(format!(
            "wss://{}:{}{}",
            bracketed(host),
            self.port,
            self.mux_path
        ))
    }
}

/// `host`, or `[host]` when it is an IPv6 literal (for URLs and the Host header).
pub fn bracketed(host: &str) -> String {
    if host.contains(':') {
        format!("[{host}]")
    } else {
        host.to_string()
    }
}

/// `{path}/mux`, unless the path already ends in `/mux` (upstream's `derive_mux_path`).
fn mux_path(path: &str) -> String {
    let base = path.trim_end_matches('/');
    if base.ends_with("/mux") {
        base.to_string()
    } else {
        format!("{base}/mux")
    }
}

/// A host name, an IPv4 literal, or an IPv6 literal (with or without brackets); returned without brackets.
/// Error texts never repeat the input: it is a server address.
pub fn parse_host(text: &str) -> Result<String, String> {
    if let Some(inner) = text.strip_prefix('[') {
        let inner = inner
            .strip_suffix(']')
            .ok_or("an IPv6 address needs a closing ]")?;
        return inner
            .parse::<std::net::Ipv6Addr>()
            .map(|_| inner.to_string())
            .map_err(|_| "not a valid IPv6 address".into());
    }

    if text.contains(':') {
        return text
            .parse::<std::net::Ipv6Addr>()
            .map(|_| text.to_string())
            .map_err(|_| {
                "a host must not carry a port (all hosts share the server's port)".into()
            });
    }

    let valid = !text.is_empty()
        && text.len() <= 253
        && text
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_'));
    if !valid {
        return Err("not a valid host name".into());
    }

    Ok(text.to_string())
}

/// Parses `wss://HOST[:PORT][/PATH]` (port 443 when left out).
pub fn parse_url(url: &str) -> Result<Server, String> {
    let rest = url
        .strip_prefix("wss://")
        .ok_or("the server URL must start with wss://")?;

    if rest.contains(['?', '#', '@']) || rest.chars().any(char::is_whitespace) {
        return Err("the server URL must not have a query, a fragment, a user or spaces".into());
    }

    let (authority, path) = match rest.find('/') {
        Some(slash) => rest.split_at(slash),
        None => (rest, "/"),
    };

    // [v6]:port, [v6], host:port or host.
    let (host, port) = if authority.starts_with('[') {
        let end = authority
            .find(']')
            .ok_or("an IPv6 address needs a closing ]")?;
        let (host, after) = authority.split_at(end + 1);
        match after {
            "" => (host, None),
            _ => (
                host,
                Some(
                    after
                        .strip_prefix(':')
                        .ok_or("bad text after the IPv6 address")?,
                ),
            ),
        }
    } else {
        match authority.rsplit_once(':') {
            Some((host, port)) => (host, Some(port)),
            None => (authority, None),
        }
    };

    let port = match port {
        None => 443,
        Some(text) => match text.parse::<u16>() {
            Ok(port) if port > 0 => port,
            _ => return Err("the server port must be a number from 1 to 65535".into()),
        },
    };

    Ok(Server {
        hosts: vec![parse_host(host)?],
        port,
        mux_path: mux_path(path),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_host_port_and_path() {
        let server = parse_url("wss://vpn.example.com:8443/api/ws").unwrap();
        assert_eq!(server.hosts, vec!["vpn.example.com"]);
        assert_eq!(server.port, 8443);
        assert_eq!(server.mux_path, "/api/ws/mux");
        assert_eq!(
            server.url(0).unwrap(),
            "wss://vpn.example.com:8443/api/ws/mux"
        );
        assert_eq!(server.url(1), None);
    }

    #[test]
    fn defaults_port_and_path() {
        let server = parse_url("wss://vpn.example.com").unwrap();
        assert_eq!((server.port, server.mux_path.as_str()), (443, "/mux"));

        let server = parse_url("wss://vpn.example.com/").unwrap();
        assert_eq!(server.mux_path, "/mux");

        let server = parse_url("wss://192.0.2.7:443/ws/").unwrap();
        assert_eq!(server.hosts, vec!["192.0.2.7"]);
        assert_eq!(server.mux_path, "/ws/mux");
    }

    #[test]
    fn keeps_an_explicit_mux_path() {
        let server = parse_url("wss://vpn.example.com/tunnel/mux").unwrap();
        assert_eq!(server.mux_path, "/tunnel/mux");
    }

    #[test]
    fn parses_ipv6() {
        let server = parse_url("wss://[2001:db8::1]:8443/ws").unwrap();
        assert_eq!(server.hosts, vec!["2001:db8::1"]);
        assert_eq!(server.port, 8443);
        assert_eq!(server.url(0).unwrap(), "wss://[2001:db8::1]:8443/ws/mux");

        let server = parse_url("wss://[::1]").unwrap();
        assert_eq!((server.hosts[0].as_str(), server.port), ("::1", 443));
    }

    #[test]
    fn rejects_bad_urls() {
        for url in [
            "ws://vpn.example.com/ws",
            "https://vpn.example.com",
            "vpn.example.com",
            "wss://",
            "wss://:443/ws",
            "wss://vpn.example.com:0/ws",
            "wss://vpn.example.com:70000/ws",
            "wss://vpn.example.com:x/ws",
            "wss://user:pw@vpn.example.com/ws",
            "wss://vpn.example.com/ws?x=1",
            "wss://vpn.example.com/ws#f",
            "wss://vpn example.com/ws",
            "wss://[2001:db8::1/ws",
            "wss://[2001:db8::1]x/ws",
            "wss://[not-v6]/ws",
        ] {
            let err = parse_url(url).unwrap_err();
            assert!(!err.contains("example"), "{url}: error repeats the input");
        }
    }

    #[test]
    fn parses_alt_hosts() {
        assert_eq!(parse_host("alt.example.net").unwrap(), "alt.example.net");
        assert_eq!(parse_host("198.51.100.4").unwrap(), "198.51.100.4");
        assert_eq!(parse_host("[2001:db8::2]").unwrap(), "2001:db8::2");
        assert_eq!(parse_host("2001:db8::2").unwrap(), "2001:db8::2");

        for host in ["", "alt.example.net:443", "a/b", "a b", "[::1", "wss://a"] {
            assert!(parse_host(host).is_err(), "{host:?}");
        }
    }

    #[test]
    fn brackets_only_ipv6() {
        assert_eq!(bracketed("2001:db8::1"), "[2001:db8::1]");
        assert_eq!(bracketed("vpn.example.com"), "vpn.example.com");
    }
}
