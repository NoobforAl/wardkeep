//! `omnitun-tor`: Arti behind a local SOCKS5 port, started by the Go core.
//!
//! Usage: omnitun-tor --data DIR [--socks-port N] [--bridge LINE]... [--transport NAME=HOST:PORT]...
//!
//! stdout carries one JSON object per line for the core:
//!   {"event":"listening","socks":"127.0.0.1:PORT"}
//!   {"event":"bootstrap","percent":42,"status":"..."}
//!   {"event":"ready"}
//!   {"event":"path","hops":[{"role":"guard","country":"DE"},{"role":"middle","country":"FR"},{"role":"exit","country":"NL"}]}
//!     (the circuit the traffic rides, whenever it changes: roles and countries only)
//!   {"event":"error","message":"..."}
//! The process exits when stdin closes, so it never outlives the core.

use std::net::IpAddr;
use std::sync::{Arc, Mutex};

use anyhow::Context;
use arti_client::config::pt::TransportConfigBuilder;
use arti_client::config::{BoolOrAuto, BridgeConfigBuilder, TorClientConfigBuilder};
use arti_client::{HasKind, TorClient, TorClientConfig};
use futures::StreamExt;
use omnitun_tor::{args, path, socks};
use serde_json::json;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Semaphore;
use tor_geoip::GeoipDb;
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
    #[cfg(feature = "dhat-heap")]
    drop(PROFILER.lock().unwrap().take());
    std::process::exit(code)
}

fn emit(v: serde_json::Value) {
    // One line per event; stdout is line-buffered by the core's reader.
    println!("{v}");
}

fn config(a: &args::Args) -> anyhow::Result<TorClientConfig> {
    let mut b = TorClientConfigBuilder::from_directories(
        a.data_dir.join("state"),
        a.data_dir.join("cache"),
    );
    for line in &a.bridges {
        let bridge: BridgeConfigBuilder = line
            .parse()
            .with_context(|| format!("bad bridge line {line:?}"))?;
        b.bridges().bridges().push(bridge);
    }
    if !a.bridges.is_empty() {
        b.bridges().enabled(BoolOrAuto::Explicit(true));
    }
    for (name, addr) in &a.transports {
        let mut t = TransportConfigBuilder::default();
        t.protocols(vec![
            name.parse()
                .with_context(|| format!("bad transport name {name:?}"))?,
        ])
        .proxy_addr(*addr);
        b.bridges().transports().push(t);
    }
    Ok(b.build()?)
}

/// What the connections share: the client, and what is needed to describe the circuit they ride.
struct Shared {
    client: Arc<TorClient<PreferredRuntime>>,
    geoip: Arc<GeoipDb>,
    /// The first hop is a bridge, not a guard.
    bridged: bool,
    /// The countries of the path last reported, so a circuit is announced once, not per connection.
    last: Mutex<Vec<Option<String>>>,
}

/// The country of a relay (or bridge): from its address, else from the address of the bridge behind its
/// pluggable transport. Unknown (None) for a fronted bridge such as Snowflake: it has no real address.
fn hop_country(db: &GeoipDb, hop: &impl ChanTarget) -> Option<String> {
    let mut ips: Vec<IpAddr> = hop.addrs().map(|a| a.ip()).collect();
    if ips.is_empty() {
        if let ChannelMethod::Pluggable(pt) = hop.chan_method() {
            if let PtTargetAddr::IpPort(sa) = pt.addr() {
                ips.push(sa.ip());
            }
        }
    }
    db.lookup_country_code_multi(ips)
        .map(|c| c.get().to_string())
        .filter(|c| c != "??")
}

/// Tells the core which relays a stream's circuit uses, when that is not what was last told.
fn report_path(sh: &Shared, stream: &arti_client::DataStream) {
    let Some(tunnel) = stream.client_stream_ctrl().and_then(|c| c.tunnel()) else {
        return;
    };
    // A client tunnel is one circuit; take its path.
    let Some(circuit) = tunnel.all_paths().into_iter().next() else {
        return;
    };
    let countries: Vec<Option<String>> = circuit
        .iter()
        .map(|h| h.as_chan_target().and_then(|t| hop_country(&sh.geoip, t)))
        .collect();
    if countries.is_empty() {
        return;
    }
    let mut last = sh.last.lock().unwrap();
    if *last != countries {
        emit(path::event(&countries, sh.bridged));
        *last = countries;
    }
}

async fn serve(sh: Arc<Shared>, mut conn: TcpStream) {
    let client = &sh.client;
    let target = match socks::handshake_within(&mut conn, socks::HANDSHAKE_TIMEOUT).await {
        Ok(t) => t,
        Err(_) => return,
    };
    match client.connect((target.host.as_str(), target.port)).await {
        Ok(mut stream) => {
            report_path(&sh, &stream);
            if socks::send_reply(&mut conn, socks::reply::SUCCEEDED)
                .await
                .is_err()
            {
                return;
            }
            let _ = tokio::io::copy_bidirectional(&mut conn, &mut stream).await;
        }
        Err(e) => {
            // Never log the destination: the app log can be shown or exported.
            eprintln!("connect failed: {:?}", e.kind());
            let code = match e.kind() {
                arti_client::ErrorKind::RemoteHostNotFound
                | arti_client::ErrorKind::RemoteNetworkFailed => socks::reply::HOST_UNREACHABLE,
                _ => socks::reply::GENERAL_FAILURE,
            };
            let _ = socks::send_reply(&mut conn, code).await;
        }
    }
}

async fn run(a: args::Args) -> anyhow::Result<()> {
    let listener = TcpListener::bind(("127.0.0.1", a.socks_port))
        .await
        .context("listen")?;
    emit(json!({"event": "listening", "socks": listener.local_addr()?.to_string()}));

    let client = TorClient::builder()
        .config(config(&a)?)
        .create_unbootstrapped()?;
    let mut events = client.bootstrap_events();
    tokio::spawn(async move {
        let mut last = -1;
        while let Some(status) = events.next().await {
            let percent = (status.as_frac() * 100.0) as i32;
            if percent != last {
                last = percent;
                let mut v =
                    json!({"event": "bootstrap", "percent": percent, "status": status.to_string()});
                if let Some(b) = status.blocked() {
                    v["blocked"] = json!(b.to_string());
                }
                emit(v);
            }
        }
    });
    client.bootstrap().await.context("bootstrap")?;
    emit(json!({"event": "ready"}));

    let shared = Arc::new(Shared {
        client,
        geoip: GeoipDb::new_embedded(),
        bridged: !a.bridges.is_empty(),
        last: Mutex::new(Vec::new()),
    });
    // Past this many open connections the port stops accepting until one ends, so
    // a runaway local program cannot grow the task and socket count without bound.
    let slots = Arc::new(Semaphore::new(MAX_CONNECTIONS));
    loop {
        let permit = slots.clone().acquire_owned().await?;
        let (conn, _) = listener.accept().await?;
        let sh = shared.clone();
        tokio::spawn(async move {
            serve(sh, conn).await;
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
    let _ = rustls::crypto::ring::default_provider().install_default();
    // Arti's logs go to stderr (RUST_LOG overrides the default "warn").
    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_ansi(false)
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                "warn,tor_circmgr=info,tor_guardmgr=info,tor_chanmgr=info".into()
            }),
        )
        .init();
    let a = match args::parse(std::env::args().skip(1)) {
        Ok(a) => a,
        Err(e) => {
            emit(json!({"event": "error", "message": e}));
            finish(2);
        }
    };
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
    if let Err(e) = run(a).await {
        emit(json!({"event": "error", "message": format!("{e:#}")}));
        let _ = tokio::io::stdout().flush().await;
        finish(1);
    }
}
