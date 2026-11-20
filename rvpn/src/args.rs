//! Command-line options of the `wardkeep-rvpn` binary.
//!
//! Error texts name the flag, never its value: values are server addresses and paths, and the error
//! reaches the core's log.
//!
//! The SOCKS login is not a flag: other local users can read a process's command line. It comes from the
//! environment ([`USER_ENV`], [`PASS_ENV`]), which only the process's own user can read.

use std::path::PathBuf;

use crate::logging::Level;
use crate::server::{self, Server};
use crate::socks::Credentials;

/// Parsed command line.
#[derive(Debug, PartialEq)]
pub struct Args {
    /// Holds `identity.key` (created on the first start).
    pub data_dir: PathBuf,

    /// The server's `prekey-bundle.json`.
    pub bundle: PathBuf,

    /// `--server` and the `--alt` hosts.
    pub server: Server,

    /// SOCKS5 listen port on 127.0.0.1 (0 = any free port).
    pub socks_port: u16,

    /// The user and password every SOCKS client must send; None = no auth.
    pub socks_auth: Option<Credentials>,

    /// The least severe log records written (`error` unless the core asks for more).
    pub log_level: Level,
}

/// The SOCKS5 user every client must send (with [`PASS_ENV`]).
pub const USER_ENV: &str = "WARDKEEP_RVPN_SOCKS_USER";

/// The SOCKS5 password every client must send (with [`USER_ENV`]).
pub const PASS_ENV: &str = "WARDKEEP_RVPN_SOCKS_PASS";

/// RFC 1929 sends each of them with a one-byte length.
fn credential(name: &str, value: String) -> Result<String, String> {
    if value.len() > 255 {
        return Err(format!("{name} must be 1 to 255 bytes"));
    }

    Ok(value)
}

/// Parses `--data DIR --bundle FILE --server URL [--alt HOST]... [--socks-port N] [--log-level LEVEL]`,
/// and the SOCKS login from `env` ([`USER_ENV`] and [`PASS_ENV`]: both or neither).
pub fn parse(
    mut argv: impl Iterator<Item = String>,
    env: impl Fn(&str) -> Option<String>,
) -> Result<Args, String> {
    let mut data_dir = None;
    let mut bundle = None;
    let mut server: Option<Server> = None;
    let mut alts = Vec::new();
    let mut socks_port = 0;
    let mut log_level = Level::default();

    while let Some(flag) = argv.next() {
        let mut value = || argv.next().ok_or_else(|| format!("{flag} needs a value"));
        match flag.as_str() {
            "--data" => data_dir = Some(PathBuf::from(value()?)),
            "--bundle" => bundle = Some(PathBuf::from(value()?)),
            "--server" => {
                server =
                    Some(server::parse_url(&value()?).map_err(|err| format!("--server: {err}"))?);
            }

            "--alt" => {
                alts.push(server::parse_host(&value()?).map_err(|err| format!("--alt: {err}"))?);
            }
            "--socks-port" => {
                socks_port = value()?
                    .parse()
                    .map_err(|_| "--socks-port must be a number from 0 to 65535".to_string())?;
            }

            "--log-level" => {
                let name = value()?;
                log_level = Level::parse(&name).ok_or_else(|| {
                    format!("--log-level {name}: not one of trace, debug, info, warn, error, fatal")
                })?;
            }

            // Not echoed: a misplaced value (a server address) would land here.
            _ => return Err("unknown option".into()),
        }
    }

    let mut server = server.ok_or("--server is required")?;
    server.hosts.extend(alts);

    // An empty variable counts as unset.
    let user = env(USER_ENV).filter(|value| !value.is_empty());
    let pass = env(PASS_ENV).filter(|value| !value.is_empty());
    let socks_auth = match (user, pass) {
        (Some(user), Some(pass)) => Some(Credentials {
            user: credential(USER_ENV, user)?,
            pass: credential(PASS_ENV, pass)?,
        }),
        (None, None) => None,
        _ => return Err(format!("{USER_ENV} and {PASS_ENV} go together")),
    };

    Ok(Args {
        data_dir: data_dir.ok_or("--data is required")?,
        bundle: bundle.ok_or("--bundle is required")?,
        server,
        socks_port,
        socks_auth,
        log_level,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(argv: &[&str]) -> Result<Args, String> {
        parse(argv.iter().map(|arg| arg.to_string()), |_| None)
    }

    const BASE: [&str; 6] = [
        "--data",
        "d",
        "--bundle",
        "b.json",
        "--server",
        "wss://vpn.example.com:8443/ws",
    ];

    fn with_env(extra: &[&str], env: &[(&str, &str)]) -> Result<Args, String> {
        let mut argv = BASE.to_vec();
        argv.extend_from_slice(extra);
        let env: Vec<(String, String)> = env
            .iter()
            .map(|(key, value)| (key.to_string(), value.to_string()))
            .collect();
        parse(argv.iter().map(|arg| arg.to_string()), move |key| {
            env.iter()
                .find(|(name, _)| name == key)
                .map(|(_, value)| value.clone())
        })
    }

    fn with(extra: &[&str]) -> Result<Args, String> {
        with_env(extra, &[])
    }

    #[test]
    fn parses_everything() {
        let parsed = with_env(
            &[
                "--alt",
                "alt.example.net",
                "--alt",
                "[2001:db8::5]",
                "--socks-port",
                "1080",
                "--log-level",
                "debug",
            ],
            &[(USER_ENV, "u"), (PASS_ENV, "p")],
        )
        .unwrap();

        assert_eq!(parsed.data_dir, PathBuf::from("d"));
        assert_eq!(parsed.bundle, PathBuf::from("b.json"));
        assert_eq!(
            parsed.server.hosts,
            vec!["vpn.example.com", "alt.example.net", "2001:db8::5"]
        );
        assert_eq!(parsed.server.port, 8443);
        assert_eq!(parsed.server.mux_path, "/ws/mux");
        assert_eq!(parsed.socks_port, 1080);
        assert_eq!(
            parsed.socks_auth,
            Some(Credentials {
                user: "u".into(),
                pass: "p".into()
            })
        );
        assert_eq!(parsed.log_level, Level::Debug);
    }

    #[test]
    fn defaults() {
        let parsed = with(&[]).unwrap();
        assert_eq!(parsed.socks_port, 0);
        assert_eq!(parsed.socks_auth, None);
        assert_eq!(parsed.log_level, Level::Error);
        assert_eq!(parsed.server.hosts.len(), 1);
    }

    #[test]
    fn requires_data_bundle_and_server() {
        assert!(args(&[]).is_err());
        assert!(args(&BASE[2..]).is_err());
        assert!(args(&[BASE[0], BASE[1], BASE[4], BASE[5]]).is_err());
        assert!(args(&BASE[..4]).is_err());
    }

    /// The login comes from the environment only, both variables or neither; the flags are gone.
    #[test]
    fn socks_login_from_the_environment() {
        assert!(with_env(&[], &[(USER_ENV, "u")]).is_err());
        assert!(with_env(&[], &[(PASS_ENV, "p")]).is_err());
        assert!(with_env(&[], &[(USER_ENV, "u"), (PASS_ENV, "")]).is_err());
        assert_eq!(
            with_env(&[], &[(USER_ENV, ""), (PASS_ENV, "")])
                .unwrap()
                .socks_auth,
            None
        );

        let long = "x".repeat(256);
        let err = with_env(&[], &[(USER_ENV, &long), (PASS_ENV, "hunter2")]).unwrap_err();
        assert!(!err.contains("hunter2") && !err.contains("xxx"), "{err}");

        assert!(with(&["--socks-user", "u", "--socks-pass", "p"]).is_err());
    }

    #[test]
    fn rejects_bad_input() {
        for extra in [
            &["--alt"][..],
            &["--alt", "alt.example.net:443"],
            &["--socks-port", "65536"],
            &["--socks-port", "x"],
            &["--log-level", "verbose"],
            &["--nope"],
            &["vpn2.example.com"],
        ] {
            let err = with(extra).unwrap_err();
            assert!(!err.contains("example"), "{extra:?}: {err}");
        }

        assert!(
            args(&[
                "--data",
                "d",
                "--bundle",
                "b",
                "--server",
                "ws://vpn.example.com"
            ])
            .is_err()
        );
    }
}
