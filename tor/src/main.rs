//! `omnitun-tor`: Arti behind a local SOCKS5 port, started by the Go core.
//!
//! Usage: omnitun-tor --data DIR [--socks-port N] [--bridge LINE]... [--transport NAME=HOST:PORT]...
//!                     [--log-level trace|debug|info|warn|error|fatal]
//!
//! stdout carries one JSON object per line for the core:
//!   {"event":"listening","socks":"127.0.0.1:PORT"}
//!   {"event":"bootstrap","percent":42,"status":"..."}
//!   {"event":"ready"}
//!   {"event":"path","hops":[{"role":"guard","country":"DE"},{"role":"middle","country":"FR"},{"role":"exit","country":"NL"}]}
//!     (the circuit the traffic rides, whenever it changes: roles and countries only)
//!   {"event":"error","message":"..."}
//!   {"event":"log","time":"...","level":"warn","source":"tor","target":"tor_guardmgr","msg":"...",...}
//!     (a log record, docs/logging.md: Arti's logs and ours at --log-level and above, and panics)
//! stderr carries nothing on purpose. The process exits when stdin closes, so it never outlives the core.

use std::sync::{Arc, Mutex};

use anyhow::Context;

use arti_client::config::pt::TransportConfigBuilder;
use arti_client::config::{BoolOrAuto, BridgeConfigBuilder, TorClientConfigBuilder};
use arti_client::{HasKind, TorClient, TorClientConfig};

use futures::StreamExt;
use omnitun_tor::logging::{self, Level, Record};
use omnitun_tor::{args, path, socks};
use serde_json::json;

use tokio::io::AsyncReadExt;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Semaphore;

use tor_geoip::{CountryCode, GeoipDb};
use tor_linkspec::{ChanTarget, ChannelMethod, PtTargetAddr};
use tor_proto::client::stream::ClientStreamCtrl;
use tor_rtcompat::PreferredRuntime;

/// Connections served at once (each is two sockets, two buffers and an Arti stream).
const MAX_CONNECTIONS: usize = 2048;

#[cfg(feature = "dhat-heap")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

/// The heap profiler, kept here so every exit can drop it: dhat writes its file when it drops,
/// and `process::exit` would skip that.
#[cfg(feature = "dhat-heap")]
static PROFILER: Mutex<Option<dhat::Profiler>> = Mutex::new(None);

/// Ends the process.
fn finish(code: i32) -> ! {
    // A poisoned lock still holds the profiler; a panic here (in the panic hook) would abort.
    #[cfg(feature = "dhat-heap")]
    drop(
        PROFILER
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .take(),
    );
    std::process::exit(code)
}

/// After the panic hook wrote its record: the exit code Rust uses for a panic, in every build (the
/// release build would abort, the others could lose a panic inside a task).
fn exit_after_panic() {
    finish(101);
}

/// Writes an event for the core. One JSON object per line: each line is flushed as it is written, under
/// the same stdout lock as the log records, and the core reads it line by line.
fn emit(event: serde_json::Value) {
    logging::write_line(&event.to_string());
}

/// The engine's error code for a stream Arti could not open (docs/logging.md, `code`).
fn stream_error_code(kind: arti_client::ErrorKind) -> &'static str {
    use arti_client::ErrorKind;
    match kind {
        ErrorKind::RemoteHostNotFound | ErrorKind::RemoteHostResolutionFailed => "DNS_FAILED",
        ErrorKind::RemoteConnectionRefused => "REFUSED",
        ErrorKind::RemoteNetworkTimeout | ErrorKind::TorNetworkTimeout | ErrorKind::ExitTimeout => {
            "TIMEOUT"
        }
        ErrorKind::RemoteStreamReset => "RESET",
        _ => "TOR_STREAM_FAILED",
    }
}

/// The engine's error code for a failure that ends the process, when one fits.
fn run_error_code(err: &anyhow::Error) -> Option<&'static str> {
    let in_use = err.chain().any(|cause| {
        cause
            .downcast_ref::<std::io::Error>()
            .is_some_and(|io_err| io_err.kind() == std::io::ErrorKind::AddrInUse)
    });

    if in_use {
        Some("PORT_IN_USE")
    } else if format!("{err:#}").contains("bad bridge line") {
        Some("TOR_BAD_BRIDGE")
    } else {
        None
    }
}

fn config(args: &args::Args) -> anyhow::Result<TorClientConfig> {
    let mut builder = TorClientConfigBuilder::from_directories(
        args.data_dir.join("state"),
        args.data_dir.join("cache"),
    );

    for line in &args.bridges {
        let bridge: BridgeConfigBuilder = line
            .parse()
            .with_context(|| format!("bad bridge line {line:?}"))?;

        builder.bridges().bridges().push(bridge);
    }

    if !args.bridges.is_empty() {
        builder.bridges().enabled(BoolOrAuto::Explicit(true));
    }

    for (name, addr) in &args.transports {
        let mut transport = TransportConfigBuilder::default();
        transport
            .protocols(vec![
                name.parse()
                    .with_context(|| format!("bad transport name {name:?}"))?,
            ])
            .proxy_addr(*addr);

        builder.bridges().transports().push(transport);
    }

    Ok(builder.build()?)
}

/// What the connections share: the client, and what is needed to describe the circuit they ride.
struct Shared {
    client: Arc<TorClient<PreferredRuntime>>,
    geoip: Arc<GeoipDb>,

    /// The first hop is a bridge, not a guard.
    bridged: bool,

    /// The countries of the path last reported, so a circuit is announced once, not per connection.
    last: Mutex<Vec<Option<CountryCode>>>,
}

/// The country of a relay (or bridge): from its address, else from the address of the bridge behind its
/// pluggable transport. Unknown (None) for a fronted bridge such as Snowflake: it has no real address.
fn hop_country(db: &GeoipDb, hop: &impl ChanTarget) -> Option<CountryCode> {
    let mut relay_ips = hop.addrs().map(|addr| addr.ip()).peekable();
    let code = match relay_ips.peek().is_some() {
        true => db.lookup_country_code_multi(relay_ips),
        false => match hop.chan_method() {
            ChannelMethod::Pluggable(pt) => match pt.addr() {
                PtTargetAddr::IpPort(bridge_addr) => db.lookup_country_code(bridge_addr.ip()),
                _ => None,
            },
            _ => None,
        },
    };

    code.copied().filter(|code| code.get() != "??")
}

/// Tells the core which relays a stream's circuit uses, when that is not what was last told.
fn report_path(shared: &Shared, stream: &arti_client::DataStream) {
    let Some(tunnel) = stream.client_stream_ctrl().and_then(|ctrl| ctrl.tunnel()) else {
        return;
    };

    // A client tunnel is one circuit; take its path.
    let Some(circuit) = tunnel.all_paths().into_iter().next() else {
        return;
    };

    // Country codes are two bytes and Copy: comparing them with the last path allocates no strings.
    let countries: Vec<Option<CountryCode>> = circuit
        .iter()
        .map(|hop| {
            hop.as_chan_target()
                .and_then(|target| hop_country(&shared.geoip, target))
        })
        .collect();

    if countries.is_empty() {
        return;
    }

    let mut last = shared.last.lock().unwrap();
    if *last != countries {
        let names: Vec<Option<&str>> = countries
            .iter()
            .map(|code| code.as_ref().map(CountryCode::get))
            .collect();
        emit(path::event(&names, shared.bridged));

        *last = countries;
    }
}

async fn serve(shared: Arc<Shared>, mut conn: TcpStream) {
    let client = &shared.client;
    let target = match socks::handshake_within(&mut conn, socks::HANDSHAKE_TIMEOUT).await {
        Ok(target) => target,
        Err(_) => return,
    };

    match client.connect((target.host.as_str(), target.port)).await {
        Ok(mut stream) => {
            report_path(&shared, &stream);
            if socks::send_reply(&mut conn, socks::reply::SUCCEEDED)
                .await
                .is_err()
            {
                return;
            }

            let _ = tokio::io::copy_bidirectional(&mut conn, &mut stream).await;
        }

        Err(err) => {
            // Handled (the SOCKS client gets an error reply), so a warning without notify. Never the
            // destination or Arti's error text, which names it: the app log can be shown or exported.
            tracing::warn!(
                op = "connect",
                code = stream_error_code(err.kind()),
                kind = ?err.kind(),
                "Tor could not open a stream"
            );
            let code = match err.kind() {
                arti_client::ErrorKind::RemoteHostNotFound
                | arti_client::ErrorKind::RemoteNetworkFailed => socks::reply::HOST_UNREACHABLE,
                _ => socks::reply::GENERAL_FAILURE,
            };

            let _ = socks::send_reply(&mut conn, code).await;
        }
    }
}

async fn run(args: args::Args) -> anyhow::Result<()> {
    let listener = TcpListener::bind(("127.0.0.1", args.socks_port))
        .await
        .context("listen")?;

    emit(json!({"event": "listening", "socks": listener.local_addr()?.to_string()}));

    let client = TorClient::builder()
        .config(config(&args)?)
        .create_unbootstrapped()?;

    let mut events = client.bootstrap_events();
    tokio::spawn(async move {
        let mut last = -1;
        while let Some(status) = events.next().await {
            let percent = (status.as_frac() * 100.0) as i32;
            if percent != last {
                last = percent;
                let mut event =
                    json!({"event": "bootstrap", "percent": percent, "status": status.to_string()});

                if let Some(blocked) = status.blocked() {
                    event["blocked"] = json!(blocked.to_string());
                }

                emit(event);
            }
        }
    });

    client.bootstrap().await.context("bootstrap")?;
    emit(json!({"event": "ready"}));

    let shared = Arc::new(Shared {
        client,
        geoip: GeoipDb::new_embedded(),
        bridged: !args.bridges.is_empty(),
        last: Mutex::new(Vec::new()),
    });

    // Past this many open connections the port stops accepting until one ends, so
    // a runaway local program cannot grow the task and socket count without bound.
    let slots = Arc::new(Semaphore::new(MAX_CONNECTIONS));
    loop {
        let permit = slots.clone().acquire_owned().await?;
        let (conn, _) = listener.accept().await?;
        let shared = shared.clone();
        tokio::spawn(async move {
            serve(shared, conn).await;
            drop(permit);
        });
    }
}

#[tokio::main]
async fn main() {
    #[cfg(feature = "dhat-heap")]
    {
        *PROFILER.lock().unwrap() = Some(dhat::Profiler::new_heap());
    }

    // A panic becomes a fatal record on stdout instead of text on stderr.
    logging::install_panic_hook(exit_after_panic);

    let _ = rustls::crypto::ring::default_provider().install_default();

    let args = match args::parse(std::env::args().skip(1)) {
        Ok(args) => args,
        Err(err) => {
            emit(json!({"event": "error", "message": err}));
            Record::new(Level::Error, "Tor did not start: bad command line")
                .with("op", "start")
                .with("err", err)
                .with("notify", true)
                .write();
            finish(2);
        }
    };

    // Arti's logs and ours, as records on stdout (RUST_LOG replaces the level's filter).
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

    if let Err(err) = run(args).await {
        let message = format!("{err:#}");
        emit(json!({"event": "error", "message": message}));

        // Nothing in this process handles it: Tor stops, so the user is told.
        tracing::error!(
            op = "run",
            code = run_error_code(&err),
            err = message,
            notify = true,
            "Tor stopped"
        );
        finish(1);
    }
}
