//! Command-line options of the `wardkeep-tor` binary.

use std::net::SocketAddr;
use std::path::PathBuf;

use crate::logging::Level;

/// Parsed command line.
#[derive(Debug, Default, PartialEq)]
pub struct Args {
    /// Data directory for Arti's state and cache.
    pub data_dir: PathBuf,

    /// SOCKS5 listen port on 127.0.0.1 (0 = any free port).
    pub socks_port: u16,

    /// Bridge lines, e.g. "obfs4 192.0.2.1:443 FINGERPRINT cert=... iat-mode=0".
    pub bridges: Vec<String>,

    /// Unmanaged pluggable transports: (protocol, local SOCKS address).
    pub transports: Vec<(String, SocketAddr)>,

    /// The least severe log records written (`error` unless the core asks for more).
    pub log_level: Level,

    /// The bridge lines come on stdin ([`read_bridges`]) rather than as `--bridge`: on the command line every
    /// local user could read them.
    pub bridges_on_stdin: bool,
}

/// Adds one bridge line, accepting the torrc style "Bridge obfs4 ..." too; an empty line adds nothing.
fn push_bridge(args: &mut Args, line: &str) {
    let line = line.trim();
    let line = line.strip_prefix("Bridge ").unwrap_or(line).trim();
    if !line.is_empty() {
        args.bridges.push(line.to_string());
    }
}

/// Reads bridge lines, one per line, up to an empty line or the end of `input` (`--bridges-stdin`).
pub fn read_bridges(args: &mut Args, input: impl std::io::BufRead) -> std::io::Result<()> {
    for line in input.lines() {
        let line = line?;
        if line.trim().is_empty() {
            break;
        }
        push_bridge(args, &line);
    }

    Ok(())
}

/// Parses `--data DIR --socks-port N [--bridge LINE]... [--bridges-stdin] [--transport NAME=ADDR]...
/// [--log-level LEVEL]`.
pub fn parse(mut argv: impl Iterator<Item = String>) -> Result<Args, String> {
    let mut args = Args::default();
    let mut have_data = false;

    while let Some(flag) = argv.next() {
        let mut value = || argv.next().ok_or_else(|| format!("{flag} needs a value"));
        match flag.as_str() {
            "--data" => {
                args.data_dir = PathBuf::from(value()?);
                have_data = true;
            }

            "--socks-port" => {
                args.socks_port = value()?
                    .parse()
                    .map_err(|err| format!("--socks-port: {err}"))?;
            }

            "--bridge" => {
                let line = value()?;
                push_bridge(&mut args, &line);
            }

            "--bridges-stdin" => args.bridges_on_stdin = true,

            "--transport" => {
                let spec = value()?;
                let (name, addr) = spec
                    .split_once('=')
                    .ok_or("--transport needs NAME=HOST:PORT")?;

                let addr = addr
                    .parse()
                    .map_err(|err| format!("--transport {name}: {err}"))?;

                args.transports.push((name.to_string(), addr));
            }

            "--log-level" => {
                let name = value()?;
                args.log_level = Level::parse(&name).ok_or_else(|| {
                    format!("--log-level {name}: not one of trace, debug, info, warn, error, fatal")
                })?;
            }

            other => return Err(format!("unknown option {other}")),
        }
    }

    if !have_data {
        return Err("--data is required".into());
    }

    Ok(args)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(argv: &[&str]) -> Result<Args, String> {
        parse(argv.iter().map(|arg| arg.to_string()))
    }

    #[test]
    fn parses_everything() {
        let parsed = args(&[
            "--data",
            "d",
            "--socks-port",
            "9150",
            "--bridge",
            "Bridge obfs4 192.0.2.1:443 AAAA cert=x iat-mode=0",
            "--transport",
            "obfs4=127.0.0.1:4000",
        ])
        .unwrap();

        assert_eq!(parsed.socks_port, 9150);
        assert_eq!(
            parsed.bridges,
            vec!["obfs4 192.0.2.1:443 AAAA cert=x iat-mode=0"]
        );

        assert_eq!(
            parsed.transports,
            vec![("obfs4".into(), "127.0.0.1:4000".parse().unwrap())]
        );
    }

    /// With `--bridges-stdin` the lines come on stdin, up to an empty line; what follows is not read as bridges.
    #[test]
    fn bridges_on_stdin() {
        let mut parsed = args(&["--data", "d", "--bridges-stdin"]).unwrap();
        assert!(parsed.bridges_on_stdin);
        assert!(parsed.bridges.is_empty());

        let input = "Bridge obfs4 192.0.2.1:443 AAAA cert=x\r\n  snowflake 192.0.2.3:80 BBBB  \n\nnot a bridge\n";
        read_bridges(&mut parsed, input.as_bytes()).unwrap();
        assert_eq!(
            parsed.bridges,
            vec![
                "obfs4 192.0.2.1:443 AAAA cert=x",
                "snowflake 192.0.2.3:80 BBBB"
            ]
        );

        // Without the empty line the end of the input ends the list.
        let mut parsed = Args::default();
        read_bridges(&mut parsed, "obfs4 192.0.2.1:443 AAAA".as_bytes()).unwrap();
        assert_eq!(parsed.bridges, vec!["obfs4 192.0.2.1:443 AAAA"]);
    }

    #[test]
    fn rejects_bad_input() {
        assert!(args(&[]).is_err());
        assert!(args(&["--data"]).is_err());
        assert!(args(&["--data", "d", "--transport", "obfs4"]).is_err());
        assert!(args(&["--data", "d", "--nope"]).is_err());
    }

    #[test]
    fn log_level() {
        assert_eq!(args(&["--data", "d"]).unwrap().log_level, Level::Error);
        for (name, level) in [
            ("trace", Level::Trace),
            ("debug", Level::Debug),
            ("info", Level::Info),
            ("warn", Level::Warn),
            ("error", Level::Error),
            ("fatal", Level::Fatal),
        ] {
            let parsed = args(&["--data", "d", "--log-level", name]).unwrap();
            assert_eq!(parsed.log_level, level);
        }

        assert!(args(&["--data", "d", "--log-level"]).is_err());
        assert!(args(&["--data", "d", "--log-level", "verbose"]).is_err());
        assert!(args(&["--data", "d", "--log-level", "DEBUG"]).is_err());
        assert!(args(&["--data", "d", "--log-level", ""]).is_err());
    }
}
