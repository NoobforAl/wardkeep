//! The one tunnel, made lazily: the first SOCKS CONNECT (and the first after the tunnel died) dials the
//! hosts in turn; CONNECTs that arrive meanwhile wait for that same attempt. After a round in which every
//! host failed, new attempts wait out a backoff (1 s doubling to 30 s); CONNECTs in that window fail at
//! once instead of hanging.

use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

use tokio::sync::Mutex;
use tokio::time::Instant;

use crate::error::ConnectError;
use crate::tunnel::Tunnel;

/// The longest wait between two rounds.
pub const MAX_BACKOFF: Duration = Duration::from_secs(30);

/// The wait after `failures` failed rounds in a row: 1 s, 2 s, 4 s, ... capped at [`MAX_BACKOFF`].
pub fn backoff(failures: u32) -> Duration {
    let shift = failures.saturating_sub(1).min(5);
    Duration::from_secs(1u64 << shift).min(MAX_BACKOFF)
}

/// Dials host number `index` and runs the handshake.
pub type Dial = Arc<
    dyn Fn(usize) -> Pin<Box<dyn Future<Output = Result<Arc<Tunnel>, ConnectError>> + Send>>
        + Send
        + Sync,
>;

/// What happened in a connect round, for the events on stdout.
pub trait Report: Send + Sync {
    /// The handshake with host `index` succeeded.
    fn ready(&self, index: usize);

    /// One host failed (logged; not an event).
    fn host_failed(&self, index: usize, err: &ConnectError);

    /// Every host failed; `err` is the one to report.
    fn all_failed(&self, err: &ConnectError);
}

struct State {
    tunnel: Option<Arc<Tunnel>>,

    /// The host that worked last; tried first.
    preferred: usize,

    /// Failed rounds in a row.
    failures: u32,

    /// No new round before this.
    retry_at: Option<Instant>,
}

/// Why no tunnel could be had.
#[derive(Debug, Clone, PartialEq)]
pub enum Unavailable {
    /// In the backoff after a failed round.
    Backoff,
    /// This round failed: the error reported for it.
    Failed(ConnectError),
}

/// Holds the tunnel and makes a new one when it is needed.
pub struct Connector {
    hosts: usize,
    dial: Dial,
    report: Arc<dyn Report>,
    state: Mutex<State>,
}

impl Connector {
    pub fn new(hosts: usize, dial: Dial, report: Arc<dyn Report>) -> Connector {
        Connector {
            hosts,
            dial,
            report,
            state: Mutex::new(State {
                tunnel: None,
                preferred: 0,
                failures: 0,
                retry_at: None,
            }),
        }
    }

    /// The live tunnel, or a new one. The lock is held for the whole round, so concurrent callers share it.
    pub async fn tunnel(&self) -> Result<Arc<Tunnel>, Unavailable> {
        let mut state = self.state.lock().await;
        if let Some(tunnel) = &state.tunnel
            && tunnel.is_alive()
        {
            return Ok(Arc::clone(tunnel));
        }

        state.tunnel = None;
        if state.retry_at.is_some_and(|at| Instant::now() < at) {
            return Err(Unavailable::Backoff);
        }

        // The host that worked last first, then the others in the order given.
        let order = (0..self.hosts).map(|step| (state.preferred + step) % self.hosts);
        let mut errors = Vec::new();
        for index in order {
            match (self.dial)(index).await {
                Ok(tunnel) => {
                    state.preferred = index;
                    state.failures = 0;
                    state.retry_at = None;
                    state.tunnel = Some(Arc::clone(&tunnel));
                    self.report.ready(index);
                    return Ok(tunnel);
                }

                Err(err) => {
                    self.report.host_failed(index, &err);
                    errors.push(err);
                }
            }
        }

        state.failures = state.failures.saturating_add(1);
        state.retry_at = Some(Instant::now() + backoff(state.failures));

        let worst = ConnectError::worst(errors)
            .unwrap_or_else(|| ConnectError::network("there is no host to connect to"));
        self.report.all_failed(&worst);
        Err(Unavailable::Failed(worst))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::Code;
    use std::sync::Mutex as StdMutex;

    #[derive(Default)]
    struct Log(StdMutex<Vec<String>>);

    impl Report for Log {
        fn ready(&self, index: usize) {
            self.0.lock().unwrap().push(format!("ready {index}"));
        }

        fn host_failed(&self, index: usize, err: &ConnectError) {
            self.0
                .lock()
                .unwrap()
                .push(format!("failed {index} {}", err.code.name()));
        }

        fn all_failed(&self, err: &ConnectError) {
            self.0
                .lock()
                .unwrap()
                .push(format!("all {}", err.code.name()));
        }
    }

    impl Log {
        fn take(&self) -> Vec<String> {
            std::mem::take(&mut *self.0.lock().unwrap())
        }
    }

    /// A dial that fails for every host with the codes given.
    fn failing(codes: Vec<Code>, calls: Arc<StdMutex<Vec<usize>>>) -> Dial {
        Arc::new(move |index| {
            calls.lock().unwrap().push(index);
            let code = codes[index];
            Box::pin(async move { Err(ConnectError::new(code, "x", "y")) })
        })
    }

    #[test]
    fn backoff_doubles_to_the_cap() {
        let waits: Vec<u64> = (1..=8).map(|n| backoff(n).as_secs()).collect();
        assert_eq!(waits, [1, 2, 4, 8, 16, 30, 30, 30]);
        assert_eq!(backoff(0).as_secs(), 1);
        assert_eq!(backoff(u32::MAX), MAX_BACKOFF);
    }

    #[tokio::test(start_paused = true)]
    async fn every_host_in_order_then_backoff() {
        let calls = Arc::new(StdMutex::new(Vec::new()));
        let log = Arc::new(Log::default());
        let connector = Connector::new(
            3,
            failing(vec![Code::Network, Code::Upgrade, Code::Tls], calls.clone()),
            log.clone(),
        );

        let err = connector.tunnel().await.err().unwrap();
        let Unavailable::Failed(worst) = err else {
            panic!("not a failed round")
        };
        assert_eq!(worst.code, Code::Upgrade);
        assert_eq!(*calls.lock().unwrap(), [0, 1, 2]);
        assert_eq!(
            log.take(),
            [
                "failed 0 network",
                "failed 1 upgrade",
                "failed 2 tls",
                "all upgrade"
            ]
        );

        // Within the backoff: no dial, no event.
        assert_eq!(connector.tunnel().await.err(), Some(Unavailable::Backoff));
        assert_eq!(calls.lock().unwrap().len(), 3);
        assert!(log.take().is_empty());

        // After it: a new round.
        tokio::time::advance(backoff(1) + Duration::from_millis(1)).await;
        assert!(matches!(
            connector.tunnel().await,
            Err(Unavailable::Failed(_))
        ));
        assert_eq!(calls.lock().unwrap().len(), 6);

        // The second wait is longer.
        tokio::time::advance(backoff(1) + Duration::from_millis(1)).await;
        assert_eq!(connector.tunnel().await.err(), Some(Unavailable::Backoff));
    }
}
