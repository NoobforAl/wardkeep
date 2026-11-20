//! `wardkeep-rvpn`: a local SOCKS5 port whose connections ride one multiplexed rVPN tunnel, started by the
//! Go core.
//!
//! Usage: wardkeep-rvpn --data DIR --bundle FILE --server wss://HOST[:PORT][/PATH] [--alt HOST]...
//!                      [--socks-port N] [--log-level trace|debug|info|warn|error|fatal]
//!
//!   --data DIR       holds identity.key (upstream's format); created with a new key on the first start
//!   --bundle FILE    the server's prekey-bundle.json (upstream's X3DHPublicBundle); it pins the server
//!   --server URL     the primary host; the tunnel endpoint is PATH + "/mux" (port 443 when left out)
//!   --alt HOST       fallback hosts, tried in order after the primary; same port, path and bundle
//!   --socks-port N   on 127.0.0.1 only (0, the default, picks a free port)
//!
//! Environment: WARDKEEP_RVPN_SOCKS_USER and WARDKEEP_RVPN_SOCKS_PASS, both set: every SOCKS client must log
//! in with them (RFC 1929, compared in constant time); both unset: no auth. Not flags, because other local
//! users can read a command line.
//!
//! stdout carries one JSON object per line for the core:
//!   {"event":"listening","socks":"127.0.0.1:PORT"}
//!     (once, when the port is bound; the tunnel is made at the first SOCKS CONNECT)
//!   {"event":"ready","host":N}
//!     (each time a tunnel handshake succeeds; N = index of the host, 0 = --server, 1 = the first --alt)
//!   {"event":"error","code":C,"message":M}
//!     C = handshake | tls | upgrade | network: a connect round in which every host failed (the furthest
//!         any host got: handshake > upgrade > tls > network); the process goes on, the next CONNECT after
//!         the backoff (1 s doubling to 30 s) tries again
//!     C = args:  bad command line, environment or bundle file; exit 2
//!     C = start: the identity key or the port could not be had; exit 1
//!     M is a short English sentence with no host, IP, port, path or key in it.
//!   {"event":"log","time":"...","level":"warn","source":"rvpn","target":"...","msg":"...",...}
//!     (a log record, docs/logging.md: ours at --log-level and above, and panics)
//! stderr carries nothing on purpose. The process exits when stdin closes, so it never outlives the core.
//!
//! SOCKS5: CONNECT only (no UDP ASSOCIATE, no BIND), domain, IPv4 and IPv6 targets. The reply is "succeeded"
//! as soon as the CreateFlow is sent (upstream's 0-RTT); a FlowFailed from the server then closes the
//! client's socket.

use std::sync::Arc;

use serde_json::json;
use tokio::io::AsyncReadExt;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Semaphore;

use wardkeep_rvpn::connect::{Connector, Dial, Report, Unavailable};
use wardkeep_rvpn::error::ConnectError;
use wardkeep_rvpn::logging::{self, Level, Record};
use wardkeep_rvpn::socks::{self, Credentials};
use wardkeep_rvpn::tunnel::{self, Tunnel};
use wardkeep_rvpn::{args, keys, ws};

/// Connections served at once (each is a socket, two queues and a flow).
const MAX_CONNECTIONS: usize = 2048;

/// Ends the process.
fn finish(code: i32) -> ! {
    std::process::exit(code)
}

/// After the panic hook wrote its record: the exit code Rust uses for a panic.
fn exit_after_panic() {
    finish(101);
}

/// Writes an event for the core, one JSON object per line, under the same stdout lock as the log records.
fn emit(event: &serde_json::Value) {
    logging::write_line(&event.to_string());
}

/// An `error` event and its log record, then exit.
fn fail(code: &str, message: &str, exit: i32) -> ! {
    emit(&json!({"event": "error", "code": code, "message": message}));
    Record::new(Level::Error, "rVPN did not start")
        .with("op", "start")
        .with("code", code)
        .with("err", message)
        .with("notify", true)
        .write();
    finish(exit);
}

/// Connect rounds as events and records. Hosts by index only.
struct Events;

impl Report for Events {
    fn ready(&self, index: usize) {
        emit(&json!({"event": "ready", "host": index}));
        tracing::info!(op = "connect", host = index, "the rVPN tunnel is up");
    }

    fn host_failed(&self, index: usize, err: &ConnectError) {
        tracing::warn!(
            op = "connect",
            host = index,
            code = err.code.name(),
            err = %err,
            "an rVPN host failed"
        );
    }

    fn all_failed(&self, err: &ConnectError) {
        emit(&json!({"event": "error", "code": err.code.name(), "message": err.message}));
    }
}

/// TLS + WebSocket + handshake to host `index`.
fn dial(
    server: Arc<wardkeep_rvpn::server::Server>,
    identity: Arc<rvpn_core::crypto::IdentityKey>,
    bundle: Arc<rvpn_core::crypto::X3DHPublicBundle>,
) -> Dial {
    Arc::new(move |index| {
        let server = Arc::clone(&server);
        let identity = Arc::clone(&identity);
        let bundle = Arc::clone(&bundle);
        Box::pin(async move {
            let host = server
                .hosts
                .get(index)
                .ok_or_else(|| ConnectError::network("no such host"))?;
            let ws = ws::connect(host, server.port, &server.mux_path).await?;
            Tunnel::start(ws, &identity, &bundle).await
        })
    })
}

async fn serve(connector: Arc<Connector>, auth: Option<Arc<Credentials>>, mut conn: TcpStream) {
    let Ok(target) =
        socks::handshake_within(&mut conn, auth.as_deref(), socks::HANDSHAKE_TIMEOUT).await
    else {
        return;
    };

    let tunnel = match connector.tunnel().await {
        Ok(tunnel) => tunnel,
        Err(Unavailable::Backoff | Unavailable::Failed(_)) => {
            let _ = socks::send_reply(&mut conn, socks::reply::GENERAL_FAILURE).await;
            return;
        }
    };

    let flow = match tunnel.open_flow(&target.host, target.port).await {
        Ok(flow) => flow,
        Err(err) => {
            tracing::warn!(op = "connect", err = %err, "a flow could not be opened");
            let _ = socks::send_reply(&mut conn, socks::reply::GENERAL_FAILURE).await;
            return;
        }
    };

    if socks::send_reply(&mut conn, socks::reply::SUCCEEDED)
        .await
        .is_ok()
    {
        tunnel::relay(&mut conn, flow).await;
    }
}

async fn run(args: args::Args) {
    let bundle = match keys::load_bundle(&args.bundle) {
        Ok(bundle) => Arc::new(bundle),
        Err(err) => fail("args", &err, 2),
    };

    let identity = match keys::load_or_create(&args.data_dir) {
        Ok(key) => Arc::new(key),
        Err(err) => fail("start", &err.to_string(), 1),
    };

    let listener = match TcpListener::bind(("127.0.0.1", args.socks_port)).await {
        Ok(listener) => listener,
        Err(err) => fail(
            "start",
            &format!("the SOCKS port could not be opened ({:?})", err.kind()),
            1,
        ),
    };

    let local = match listener.local_addr() {
        Ok(addr) => addr,
        Err(err) => fail(
            "start",
            &format!("the SOCKS port could not be read ({:?})", err.kind()),
            1,
        ),
    };
    emit(&json!({"event": "listening", "socks": local.to_string()}));

    let server = Arc::new(args.server);
    let connector = Arc::new(Connector::new(
        server.hosts.len(),
        dial(Arc::clone(&server), identity, bundle),
        Arc::new(Events),
    ));
    let auth = args.socks_auth.map(Arc::new);

    // Past this many open connections the port stops accepting until one ends, so a runaway local
    // program cannot grow the task and socket count without bound.
    let slots = Arc::new(Semaphore::new(MAX_CONNECTIONS));
    loop {
        let Ok(permit) = Arc::clone(&slots).acquire_owned().await else {
            return;
        };

        let conn = match listener.accept().await {
            Ok((conn, _)) => conn,
            Err(err) => {
                tracing::warn!(op = "accept", err = ?err.kind(), "a SOCKS connection was not accepted");
                continue;
            }
        };

        let connector = Arc::clone(&connector);
        let auth = auth.clone();
        tokio::spawn(async move {
            serve(connector, auth, conn).await;
            drop(permit);
        });
    }
}

#[tokio::main]
async fn main() {
    // A panic becomes a fatal record on stdout instead of text on stderr.
    logging::install_panic_hook(exit_after_panic);

    let _ = rustls::crypto::ring::default_provider().install_default();

    let args = match args::parse(std::env::args().skip(1), |name| std::env::var(name).ok()) {
        Ok(args) => args,
        Err(err) => fail("args", &err, 2),
    };

    logging::init(args.log_level);

    // Exit when the core goes away (stdin closes).
    tokio::spawn(async {
        let mut stdin = tokio::io::stdin();
        let mut buf = [0u8; 64];
        while let Ok(n) = stdin.read(&mut buf).await {
            if n == 0 {
                break;
            }
        }
        finish(0);
    });

    run(args).await;
}
