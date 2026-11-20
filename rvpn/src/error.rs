//! Why a connect attempt failed, as the `code` of the `error` event and a sentence for it.
//!
//! The sentences and the details are safe to log and to show: no host, IP, port, path or key, and no text
//! of a library error that may hold one (rustls names the certificate's DNS names, resolvers the host).

use std::fmt;

/// The `code` of an `error` event about connecting.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Code {
    /// DNS, TCP or a timeout: the server was not reached.
    Network,

    /// The certificate or the TLS handshake failed.
    Tls,

    /// The HTTP answer to the upgrade was not 101 (a decoy page: the path is wrong).
    Upgrade,

    /// The server rejected the handshake, or its identity or signature did not match the bundle.
    Handshake,
}

impl Code {
    pub fn name(self) -> &'static str {
        match self {
            Code::Network => "network",
            Code::Tls => "tls",
            Code::Upgrade => "upgrade",
            Code::Handshake => "handshake",
        }
    }
}

/// One failed connect attempt.
#[derive(Debug, Clone, PartialEq)]
pub struct ConnectError {
    pub code: Code,

    /// A short English sentence for the `error` event.
    pub message: &'static str,

    /// More for the log: an error kind, an HTTP status, a certificate problem's name. Never an address.
    pub detail: String,
}

impl ConnectError {
    pub fn new(code: Code, message: &'static str, detail: impl Into<String>) -> ConnectError {
        ConnectError {
            code,
            message,
            detail: detail.into(),
        }
    }

    pub fn network(detail: impl Into<String>) -> ConnectError {
        ConnectError::new(
            Code::Network,
            "The server could not be reached (DNS, TCP or a timeout).",
            detail,
        )
    }

    pub fn tls(detail: impl Into<String>) -> ConnectError {
        ConnectError::new(
            Code::Tls,
            "The TLS connection to the server failed (certificate or TLS error).",
            detail,
        )
    }

    pub fn upgrade(detail: impl Into<String>) -> ConnectError {
        ConnectError::new(
            Code::Upgrade,
            "The server did not accept the WebSocket upgrade; the path may be wrong.",
            detail,
        )
    }

    pub fn handshake(message: &'static str, detail: impl Into<String>) -> ConnectError {
        ConnectError::new(Code::Handshake, message, detail)
    }

    /// Of the errors of one round over every host, the one to report: the furthest any host got (a host
    /// that answered the handshake says more than one that could not be reached).
    pub fn worst(errors: Vec<ConnectError>) -> Option<ConnectError> {
        errors.into_iter().max_by_key(|err| err.code)
    }
}

impl fmt::Display for ConnectError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} ({})", self.message, self.detail)
    }
}

impl std::error::Error for ConnectError {}

/// The name of an I/O error's kind (`ConnectionRefused`, `TimedOut`, ...), never its text.
pub fn io_kind(err: &std::io::Error) -> String {
    format!("{:?}", err.kind())
}

/// A rustls error as a fixed name: its Display and Debug carry the certificate's names.
pub fn rustls_name(err: &rustls::Error) -> &'static str {
    use rustls::{CertificateError, Error};
    match err {
        Error::InvalidCertificate(cert) => match cert {
            CertificateError::Expired | CertificateError::ExpiredContext { .. } => {
                "certificate expired"
            }
            CertificateError::NotValidYet | CertificateError::NotValidYetContext { .. } => {
                "certificate not valid yet"
            }
            CertificateError::UnknownIssuer => "certificate from an unknown issuer",
            CertificateError::NotValidForName | CertificateError::NotValidForNameContext { .. } => {
                "certificate not valid for the host"
            }
            CertificateError::Revoked => "certificate revoked",
            CertificateError::BadSignature => "certificate with a bad signature",
            _ => "certificate rejected",
        },
        Error::AlertReceived(_) => "TLS alert from the server",
        Error::NoApplicationProtocol => "no common ALPN protocol",
        Error::PeerIncompatible(_) => "the server's TLS is incompatible",
        Error::PeerMisbehaved(_) => "the server broke the TLS protocol",
        Error::InvalidMessage(_) => "invalid TLS message",
        _ => "TLS error",
    }
}

/// A failure of the TLS handshake: a rustls error inside the I/O error is a TLS failure, anything else
/// (a reset, the connection closed) a network one.
pub fn from_tls_io(err: &std::io::Error) -> ConnectError {
    match err
        .get_ref()
        .and_then(|inner| inner.downcast_ref::<rustls::Error>())
    {
        Some(tls) => ConnectError::tls(rustls_name(tls)),
        None => ConnectError::network(format!("during TLS: {}", io_kind(err))),
    }
}

/// A failure of the WebSocket upgrade.
pub fn from_ws(err: &tokio_tungstenite::tungstenite::Error) -> ConnectError {
    use tokio_tungstenite::tungstenite::Error;
    match err {
        Error::Http(response) => {
            ConnectError::upgrade(format!("HTTP {}", response.status().as_u16()))
        }
        Error::Io(io_err) => {
            ConnectError::network(format!("during the upgrade: {}", io_kind(io_err)))
        }
        Error::Tls(_) => ConnectError::tls("TLS error during the upgrade"),
        Error::ConnectionClosed | Error::AlreadyClosed => {
            ConnectError::network("connection closed during the upgrade")
        }
        _ => ConnectError::upgrade("not a WebSocket answer"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn worst_is_the_furthest() {
        let worst = ConnectError::worst(vec![
            ConnectError::network("a"),
            ConnectError::handshake("x", "b"),
            ConnectError::tls("c"),
        ])
        .unwrap();
        assert_eq!(worst.code, Code::Handshake);
        assert_eq!(ConnectError::worst(Vec::new()), None);
    }

    #[test]
    fn names() {
        assert_eq!(Code::Network.name(), "network");
        assert_eq!(Code::Tls.name(), "tls");
        assert_eq!(Code::Upgrade.name(), "upgrade");
        assert_eq!(Code::Handshake.name(), "handshake");
    }

    #[test]
    fn tls_errors_name_no_host() {
        let err = std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            rustls::Error::InvalidCertificate(rustls::CertificateError::UnknownIssuer),
        );
        let classified = from_tls_io(&err);
        assert_eq!(classified.code, Code::Tls);
        assert_eq!(classified.detail, "certificate from an unknown issuer");

        let reset = std::io::Error::from(std::io::ErrorKind::ConnectionReset);
        assert_eq!(from_tls_io(&reset).code, Code::Network);
    }
}
