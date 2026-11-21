// Copyright (C) 2024-2025 PDG Global Limited (Hong Kong)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Ported to Wardkeep from rvpn-core v1.3.9, rvpn/crates/rvpn-client/src/socks5_tunnel.rs: `TunnelSender`,
// `Socks5Tunnel::{connect, open_flow, receive_loop, handle_control_message, dispatch_data_frame,
// flow_to_ws_loop}` and `handle_multiplexed_connection`. Left out: the tunnel pool (rotation, idle reaping,
// byte counters) and the dashboard. Changed: when the tunnel dies every flow is closed at once (upstream
// left idle flows open on a dead tunnel); a flow's CloseFlow is sent by its uplink task after the last
// queued data (upstream's Drop could send it ahead of that data); nothing is logged with a destination.

//! One multiplexed rVPN tunnel: every SOCKS connection is a flow on it.
//!
//! All frames are encrypted with the tunnel's single Double Ratchet. Control messages (CreateFlow,
//! CloseFlow, WindowUpdate, Ping) travel on flow 0; data on the flow's own id. Flow control is
//! credit-based in both directions: the uplink spends `FlowSendCredits` that the server's WindowUpdate
//! grants back, and every chunk written to the local socket is granted back to the server.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex, PoisonError, Weak};
use std::time::Duration;

use bytes::Bytes;
use rand::{Rng, SeedableRng};
use rvpn_core::crypto::{DoubleRatchet, IdentityKey, RatchetMessage, X3DHPublicBundle};
use rvpn_core::protocol::multiplex::{CreditWait, FLOW_CREDIT_STALL_TIMEOUT, FlowSendCredits};
use rvpn_core::protocol::padding::{pad_packet, unpad_packet};
use rvpn_core::protocol::{ControlMessage, MultiplexedFrame, PayloadType};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::sync::mpsc;
use tokio_tungstenite::WebSocketStream;

use crate::error::ConnectError;
use crate::handshake;
use crate::ws::{self, Message, Reader, Tasks, Writer};

/// No message at all for this long (Pongs answer the keepalive every 3 to 7 s): the tunnel is dead.
/// Upstream: 3 times the longest keepalive interval.
const RECEIVE_TIMEOUT: Duration = Duration::from_secs(21);

/// The application keepalive (a Ping control message) every 3 to 7 s, jittered.
const KEEPALIVE_MS: std::ops::RangeInclusive<u64> = 3000..=7000;

/// Read size of the local socket. `pad_packet` adds 2 bytes of length and the frame 6 of header; upstream
/// keeps a chunk at 8190.
const READ_CHUNK: usize = 8190;

/// How long the server may take to open a flow (FlowCreated) before it is closed here. The SOCKS client was
/// told at once that the connection is up (0-RTT), so a server that cannot reach the target and never says so
/// (an IPv6 destination on a server without IPv6) would leave the app waiting forever; closing the flow lets it
/// try again or another address.
const FLOW_OPEN_TIMEOUT: Duration = Duration::from_secs(10);

/// Frames queued per flow and direction. With the credit window the server can never fill the downlink
/// one; a full uplink one stops reading the local socket (TCP backpressure).
const FLOW_CHANNEL: usize = 256;

/// Why a send on the tunnel failed.
#[derive(Debug)]
pub enum SendError {
    /// Padding or framing (a frame too large).
    Encode,
    /// The ratchet refused to encrypt.
    Encrypt,
    /// The WebSocket is gone.
    Closed,
}

impl std::fmt::Display for SendError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            SendError::Encode => "a frame could not be encoded",
            SendError::Encrypt => "a frame could not be encrypted",
            SendError::Closed => "the tunnel is closed",
        })
    }
}

impl std::error::Error for SendError {}

/// Ordered encrypt + enqueue on the tunnel's WebSocket writer.
///
/// The Double Ratchet numbers messages when it encrypts, so wire order must be encrypt order: a frame
/// encrypted later that overtook an earlier one into the writer channel would be dropped by the receiving
/// ratchet ("Message too old") and its payload, a WindowUpdate grant for instance, lost. Every send path
/// (data, WindowUpdate, CreateFlow/CloseFlow, keepalive) goes through here: `order` is held across
/// encrypt + enqueue; the ratchet lock is released before the enqueue waits, so a full writer channel
/// never stalls the receive loop's decrypts.
#[derive(Clone)]
struct TunnelSender {
    writer: Writer,
    ratchet: Arc<Mutex<DoubleRatchet>>,
    order: Arc<tokio::sync::Mutex<()>>,
}

impl TunnelSender {
    /// Encrypts an already padded `plaintext` and enqueues it.
    async fn send_encrypted(&self, plaintext: &[u8], kind: PayloadType) -> Result<(), SendError> {
        let _order = self.order.lock().await;
        let wire = {
            let mut ratchet = self.ratchet.lock().unwrap_or_else(PoisonError::into_inner);
            ratchet
                .encrypt(plaintext, &[kind as u8])
                .map_err(|_| SendError::Encrypt)?
                .to_bytes()
                .map_err(|_| SendError::Encode)?
        };

        self.writer
            .send(Message::Binary(wire.into()))
            .await
            .map_err(|_| SendError::Closed)
    }

    /// Frames, pads and sends a control message (on flow 0).
    async fn send_control(&self, message: &ControlMessage) -> Result<(), SendError> {
        let frame = MultiplexedFrame::new_control(message).map_err(|_| SendError::Encode)?;
        self.send_frame(&frame, PayloadType::Admin).await
    }

    async fn send_frame(
        &self,
        frame: &MultiplexedFrame,
        kind: PayloadType,
    ) -> Result<(), SendError> {
        let encoded = frame.encode().map_err(|_| SendError::Encode)?;
        let padded = pad_packet(&encoded).map_err(|_| SendError::Encode)?;
        self.send_encrypted(&padded, kind).await
    }
}

/// What the tunnel keeps of an open flow.
struct FlowState {
    /// Data from the server to the local socket.
    to_local: mpsc::Sender<Bytes>,

    /// Uplink credits, topped up by the server's WindowUpdate.
    credits: Arc<FlowSendCredits>,

    /// Set once the server answers the flow (FlowCreated, or data): see `FLOW_OPEN_TIMEOUT`.
    answered: Arc<AtomicBool>,
}

/// The multiplexed tunnel all flows share.
pub struct Tunnel {
    sender: TunnelSender,
    ratchet: Arc<Mutex<DoubleRatchet>>,
    next_flow_id: AtomicU32,
    flows: Mutex<HashMap<u32, FlowState>>,

    /// False once the receive loop has ended: the next CONNECT makes a new tunnel.
    alive: AtomicBool,

    /// The WebSocket's helper tasks, stopped when the tunnel dies or drops.
    ws_tasks: Tasks,
}

/// The two ends a SOCKS connection relays between.
pub struct Flow {
    pub id: u32,
    to_server: mpsc::Sender<Vec<u8>>,
    from_server: mpsc::Receiver<Bytes>,
    tunnel: Weak<Tunnel>,
}

impl Tunnel {
    /// Upgrades on an established stream (TLS in the binary, plain TCP in the tests), runs the handshake
    /// and starts the receive loop and the keepalive.
    pub async fn start<S>(
        ws: WebSocketStream<S>,
        identity: &Arc<IdentityKey>,
        bundle: &X3DHPublicBundle,
    ) -> Result<Arc<Tunnel>, ConnectError>
    where
        S: AsyncRead + AsyncWrite + Unpin + Send + 'static,
    {
        let (mut reader, writer, ws_tasks) = ws::split(ws);
        let ratchet = handshake::perform(&mut reader, &writer, identity, bundle).await?;
        let ratchet = Arc::new(Mutex::new(ratchet));

        let tunnel = Arc::new(Tunnel {
            sender: TunnelSender {
                writer,
                ratchet: Arc::clone(&ratchet),
                order: Arc::new(tokio::sync::Mutex::new(())),
            },
            ratchet,
            next_flow_id: AtomicU32::new(1),
            flows: Mutex::new(HashMap::new()),
            alive: AtomicBool::new(true),
            ws_tasks,
        });

        tokio::spawn({
            let tunnel = Arc::clone(&tunnel);
            async move {
                let reason = tunnel.receive_loop(reader).await;
                tracing::info!(op = "tunnel", reason, "the rVPN tunnel closed");
                tunnel.shut_down();
            }
        });

        tokio::spawn(keepalive(Arc::downgrade(&tunnel)));
        Ok(tunnel)
    }

    pub fn is_alive(&self) -> bool {
        self.alive.load(Ordering::SeqCst)
    }

    /// The number of open flows.
    pub fn flow_count(&self) -> usize {
        self.flows_lock().len()
    }

    fn flows_lock(&self) -> std::sync::MutexGuard<'_, HashMap<u32, FlowState>> {
        self.flows.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Marks the tunnel dead, stops the WebSocket and closes every flow: each local socket is closed, and
    /// each uplink task parked on credits wakes and ends.
    pub fn shut_down(&self) {
        self.alive.store(false, Ordering::SeqCst);
        self.ws_tasks.stop();

        let flows = std::mem::take(&mut *self.flows_lock());
        for state in flows.values() {
            state.credits.close();
        }
    }

    /// Opens a flow to `host:port` and returns at once (upstream's 0-RTT): the server buffers data that
    /// arrives before its connection to the target is up. A FlowFailed later closes the flow.
    pub async fn open_flow(self: &Arc<Self>, host: &str, port: u16) -> Result<Flow, SendError> {
        if !self.is_alive() {
            return Err(SendError::Closed);
        }

        // Flow 0 is the control channel; skip it when the counter wraps.
        let mut id = self.next_flow_id.fetch_add(1, Ordering::Relaxed);
        if id == 0 {
            id = self.next_flow_id.fetch_add(1, Ordering::Relaxed);
        }

        let (to_local, from_server) = mpsc::channel::<Bytes>(FLOW_CHANNEL);
        let (to_server, uplink) = mpsc::channel::<Vec<u8>>(FLOW_CHANNEL);
        let credits = Arc::new(FlowSendCredits::new());
        let answered = Arc::new(AtomicBool::new(false));

        // Registered before CreateFlow goes out, so no answer can find the flow missing.
        self.flows_lock().insert(
            id,
            FlowState {
                to_local,
                credits: Arc::clone(&credits),
                answered: Arc::clone(&answered),
            },
        );

        let create = ControlMessage::CreateFlow {
            flow_id: id,
            target: host.to_string(),
            port,
        };
        if let Err(err) = self.sender.send_control(&create).await {
            self.flows_lock().remove(&id);
            return Err(err);
        }

        tokio::spawn(uplink_loop(
            id,
            uplink,
            self.sender.clone(),
            credits,
            Arc::downgrade(self),
        ));

        tokio::spawn({
            let tunnel = Arc::downgrade(self);
            async move {
                tokio::time::sleep(FLOW_OPEN_TIMEOUT).await;
                if answered.load(Ordering::SeqCst) {
                    return;
                }
                if let Some(tunnel) = tunnel.upgrade()
                    && tunnel.flows_lock().contains_key(&id)
                {
                    tracing::debug!(op = "connect", "the server did not open a flow in time");
                    tunnel.close_flow(id).await;
                }
            }
        });

        Ok(Flow {
            id,
            to_server,
            from_server,
            tunnel: Arc::downgrade(self),
        })
    }

    /// Grants the server `credits` more bytes on `flow_id` (downlink flow control), after that many bytes
    /// were written to the local socket. A failure is not fatal: at worst the flow stalls and the
    /// server's stall valve closes it.
    async fn send_window_update(&self, flow_id: u32, credits: u32) {
        let update = ControlMessage::WindowUpdate {
            flow_id,
            window_size: credits,
        };
        if let Err(err) = self.sender.send_control(&update).await {
            tracing::debug!(op = "tunnel", err = %err, "a WindowUpdate was not sent");
        }
    }

    /// Ends a flow from this side: forgets it and tells the server (CloseFlow).
    async fn close_flow(&self, flow_id: u32) {
        if let Some(state) = self.flows_lock().remove(&flow_id) {
            state.credits.close();
        }

        if self.is_alive()
            && let Err(err) = self
                .sender
                .send_control(&ControlMessage::CloseFlow { flow_id })
                .await
        {
            tracing::debug!(op = "tunnel", err = %err, "a CloseFlow was not sent");
        }
    }

    /// Forgets a flow the server ended (CloseFlow, FlowFailed): its local socket closes.
    fn forget_flow(&self, flow_id: u32) {
        if let Some(state) = self.flows_lock().remove(&flow_id) {
            state.credits.close();
        }
    }

    /// Reads, decrypts and dispatches until the tunnel ends; returns why, for the log.
    async fn receive_loop(&self, mut reader: Reader) -> &'static str {
        loop {
            let msg = match tokio::time::timeout(RECEIVE_TIMEOUT, reader.recv()).await {
                Ok(Some(msg)) => msg,
                Ok(None) => return "the WebSocket closed",
                Err(_) => return "nothing received for 21 s",
            };

            if !self.is_alive() {
                return "shut down";
            }

            let data = match msg {
                Message::Binary(data) => data,
                Message::Close(_) => return "the server closed the WebSocket",
                _ => continue,
            };

            let Ok(message) = RatchetMessage::from_bytes(&data) else {
                tracing::warn!(op = "tunnel", "a tunnel message could not be parsed");
                continue;
            };

            let plaintext = {
                let mut ratchet = self.ratchet.lock().unwrap_or_else(PoisonError::into_inner);
                let kind = [message.header.payload_type];
                ratchet.decrypt(&message, &kind)
            };

            // A ratchet out of step cannot decrypt anything after this: the tunnel is over.
            let Ok(plaintext) = plaintext else {
                tracing::warn!(op = "tunnel", "a tunnel message did not decrypt");
                return "the ratchet lost sync";
            };

            let Ok(frame) = unpad_packet(&plaintext) else {
                tracing::warn!(op = "tunnel", "a tunnel message had bad padding");
                continue;
            };

            // [flow_id: 4][len: 2][payload: len]
            if frame.len() < 6 {
                tracing::warn!(op = "tunnel", "a tunnel frame was too short");
                continue;
            }

            let flow_id = u32::from_be_bytes([frame[0], frame[1], frame[2], frame[3]]);
            let len = usize::from(u16::from_be_bytes([frame[4], frame[5]]));
            if frame.len() < 6 + len {
                tracing::warn!(op = "tunnel", "a tunnel frame was truncated");
                continue;
            }

            if flow_id == 0 {
                self.handle_control(&frame[6..6 + len]);
            } else {
                // No copy: the Vec becomes the Bytes, the payload a view into it.
                let payload = Bytes::from(frame).slice(6..6 + len);
                self.dispatch(flow_id, payload).await;
            }
        }
    }

    fn handle_control(&self, payload: &[u8]) {
        let frame = MultiplexedFrame::new_data(0, Bytes::copy_from_slice(payload));
        let Ok(message) = frame.parse_control() else {
            tracing::debug!(op = "tunnel", "an unknown control message was skipped");
            return;
        };

        match message {
            // 0-RTT: nothing waits for FlowCreated, but a flow never answered is closed (FLOW_OPEN_TIMEOUT).
            ControlMessage::FlowCreated { flow_id, .. } => {
                if let Some(state) = self.flows_lock().get(&flow_id) {
                    state.answered.store(true, Ordering::SeqCst);
                }
            }

            ControlMessage::Pong { .. } => {}

            // The server's error text is not logged: it can name the destination.
            ControlMessage::FlowFailed { flow_id, .. } => {
                tracing::debug!(op = "connect", "the server could not open a flow");
                self.forget_flow(flow_id);
            }

            ControlMessage::CloseFlow { flow_id } => self.forget_flow(flow_id),

            // The server wrote that many bytes of the flow to the target: credits back to the uplink.
            ControlMessage::WindowUpdate {
                flow_id,
                window_size,
            } => {
                if let Some(state) = self.flows_lock().get(&flow_id) {
                    state.credits.grant(u64::from(window_size));
                }
            }

            ControlMessage::CreateFlow { .. } | ControlMessage::Ping { .. } => {}
        }
    }

    /// Hands a data frame to its flow without waiting: a slow flow must not stall the others. With the
    /// credit window the channel cannot fill unless the server overruns it; then the frame is dropped.
    async fn dispatch(&self, flow_id: u32, data: Bytes) {
        let closed = {
            let flows = self.flows_lock();
            let Some(state) = flows.get(&flow_id) else {
                return;
            };

            state.answered.store(true, Ordering::SeqCst);
            match state.to_local.try_send(data) {
                Ok(()) => false,
                Err(mpsc::error::TrySendError::Full(_)) => {
                    tracing::warn!(
                        op = "tunnel",
                        "a flow's queue was full: the server sent past its credit window"
                    );
                    false
                }

                Err(mpsc::error::TrySendError::Closed(_)) => true,
            }
        };

        // The local side is gone.
        if closed {
            self.close_flow(flow_id).await;
        }
    }
}

/// Sends a Ping control message every 3 to 7 s while the tunnel lives; the Pong keeps the receive loop's
/// timeout from firing. WebSocket pings alone are not always passed on by reverse proxies.
async fn keepalive(tunnel: Weak<Tunnel>) {
    let mut rng = rand::rngs::StdRng::from_entropy();
    loop {
        tokio::time::sleep(Duration::from_millis(rng.gen_range(KEEPALIVE_MS))).await;
        let Some(tunnel) = tunnel.upgrade() else {
            return;
        };

        if !tunnel.is_alive() {
            return;
        }

        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |since| {
                u64::try_from(since.as_millis()).unwrap_or(u64::MAX)
            });
        if let Err(err) = tunnel
            .sender
            .send_control(&ControlMessage::Ping { timestamp })
            .await
        {
            tracing::debug!(op = "tunnel", err = %err, "a keepalive was not sent");
        }
    }
}

/// Sends a flow's local data to the server, at most its credits at a time; at zero it parks until a
/// WindowUpdate (the queue then fills and the relay stops reading the local socket). When the relay is
/// done the queue ends, and after the last data the flow is closed with CloseFlow.
async fn uplink_loop(
    flow_id: u32,
    mut queue: mpsc::Receiver<Vec<u8>>,
    sender: TunnelSender,
    credits: Arc<FlowSendCredits>,
    tunnel: Weak<Tunnel>,
) {
    // The part of a chunk past the credits, sent next.
    let mut pending: Option<Vec<u8>> = None;

    loop {
        let data = match pending.take() {
            Some(rest) => rest,
            None => match queue.recv().await {
                Some(data) => data,
                None => break,
            },
        };

        if data.is_empty() {
            continue;
        }

        let len = u64::try_from(data.len()).unwrap_or(u64::MAX);
        let allowed = usize::try_from(credits.try_consume(len)).unwrap_or(data.len());
        if allowed == 0 {
            match credits
                .wait_for_credit_or_stall(FLOW_CREDIT_STALL_TIMEOUT)
                .await
            {
                CreditWait::Granted => {
                    pending = Some(data);
                    continue;
                }

                // Closed while parked (the server ended it, or the tunnel died): nothing to tell.
                CreditWait::Closed => return,

                // A peer that never grants credits.
                CreditWait::Stalled => {
                    tracing::warn!(
                        op = "tunnel",
                        "a flow got no credits for 60 s and was closed"
                    );
                    break;
                }
            }
        }

        let frame = if allowed >= data.len() {
            MultiplexedFrame::new_data(flow_id, data)
        } else {
            pending = Some(data[allowed..].to_vec());
            MultiplexedFrame::new_data(flow_id, Bytes::copy_from_slice(&data[..allowed]))
        };

        if sender.send_frame(&frame, PayloadType::Data).await.is_err() {
            return;
        }
    }

    if let Some(tunnel) = tunnel.upgrade() {
        tunnel.close_flow(flow_id).await;
    }
}

/// Relays a SOCKS connection through its flow until either side ends. Every chunk written to the local
/// socket is granted back to the server (WindowUpdate).
pub async fn relay<S>(socket: &mut S, flow: Flow)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let Flow {
        id,
        to_server,
        mut from_server,
        tunnel,
    } = flow;
    let mut buf = vec![0u8; READ_CHUNK];

    loop {
        tokio::select! {
            read = socket.read(&mut buf) => match read {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if to_server.send(buf[..n].to_vec()).await.is_err() {
                        break;
                    }
                }
            },

            data = from_server.recv() => {
                let Some(data) = data else { break };
                if socket.write_all(&data).await.is_err() {
                    break;
                }

                let Some(tunnel) = tunnel.upgrade() else { break };
                let granted = u32::try_from(data.len()).unwrap_or(u32::MAX);
                tunnel.send_window_update(id, granted).await;
            }
        }
    }

    let _ = socket.shutdown().await;
    // Dropping `to_server` ends the uplink task's queue: it sends what is left, then CloseFlow.
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    /// Upstream's regression test for the "Message too old" stall: many tasks encrypting on the shared
    /// ratchet, a writer channel of 1 so every send waits; wire order must stay message-number order and
    /// every frame must decrypt.
    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn sender_keeps_wire_order_under_contention() {
        const TASKS: usize = 8;
        const PER_TASK: usize = 50;

        let secret = [0x42u8; 32];
        let alice = DoubleRatchet::init_alice(secret, [0u8; 32]);
        let mut bob = DoubleRatchet::init_bob(secret);

        let (tx, mut rx) = mpsc::channel::<Message>(1);
        let sender = TunnelSender {
            writer: Writer::from_sender(tx),
            ratchet: Arc::new(Mutex::new(alice)),
            order: Arc::new(tokio::sync::Mutex::new(())),
        };

        let mut handles = Vec::new();
        for task in 0..TASKS {
            let sender = sender.clone();
            handles.push(tokio::spawn(async move {
                for i in 0..PER_TASK {
                    let payload = format!("task{task}-msg{i}").into_bytes();
                    sender
                        .send_encrypted(&payload, PayloadType::Data)
                        .await
                        .unwrap();
                }
            }));
        }
        drop(sender);

        let mut numbers = Vec::new();
        let mut payloads = HashSet::new();
        while let Some(msg) = rx.recv().await {
            let Message::Binary(bytes) = msg else {
                panic!("not binary")
            };
            let parsed = RatchetMessage::from_bytes(&bytes).unwrap();
            numbers.push(parsed.header.message_number);
            let plain = bob.decrypt(&parsed, &[PayloadType::Data as u8]).unwrap();
            payloads.insert(String::from_utf8(plain).unwrap());
        }

        for handle in handles {
            handle.await.unwrap();
        }

        assert_eq!(numbers.len(), TASKS * PER_TASK);
        let mut sorted = numbers.clone();
        sorted.sort_unstable();
        assert_eq!(numbers, sorted);
        assert_eq!(payloads.len(), TASKS * PER_TASK);
    }

    /// A tunnel over channels (no socket), its writer's receiving end, and the server's ratchet.
    fn test_tunnel() -> (Arc<Tunnel>, mpsc::Receiver<Message>, DoubleRatchet) {
        let secret = [0x24u8; 32];
        let ratchet = Arc::new(Mutex::new(DoubleRatchet::init_alice(secret, [0u8; 32])));
        let (tx, rx) = mpsc::channel::<Message>(64);
        let tunnel = Arc::new(Tunnel {
            sender: TunnelSender {
                writer: Writer::from_sender(tx),
                ratchet: Arc::clone(&ratchet),
                order: Arc::new(tokio::sync::Mutex::new(())),
            },
            ratchet,
            next_flow_id: AtomicU32::new(1),
            flows: Mutex::new(HashMap::new()),
            alive: AtomicBool::new(true),
            ws_tasks: Tasks::none(),
        });
        (tunnel, rx, DoubleRatchet::init_bob(secret))
    }

    /// The control message in a frame the tunnel sent.
    fn control_of(msg: Message, bob: &mut DoubleRatchet) -> ControlMessage {
        let Message::Binary(bytes) = msg else {
            panic!("not binary")
        };
        let parsed = RatchetMessage::from_bytes(&bytes).unwrap();
        let plain = bob.decrypt(&parsed, &[]).unwrap();
        let frame = MultiplexedFrame::decode(&unpad_packet(&plain).unwrap()).unwrap();
        frame.parse_control().unwrap()
    }

    /// Server FlowFailed: the flow is forgotten and the relay's channel ends, so the local socket closes.
    #[tokio::test]
    async fn flow_failed_closes_the_flow() {
        let (tunnel, mut wire, mut bob) = test_tunnel();
        let mut flow = tunnel.open_flow("example.com", 443).await.unwrap();
        assert_eq!(flow.id, 1);
        assert_eq!(
            control_of(wire.recv().await.unwrap(), &mut bob),
            ControlMessage::CreateFlow {
                flow_id: 1,
                target: "example.com".into(),
                port: 443
            }
        );

        let failed = MultiplexedFrame::new_control(&ControlMessage::FlowFailed {
            flow_id: 1,
            error: "refused".into(),
        })
        .unwrap();
        tunnel.handle_control(&failed.payload);

        assert_eq!(tunnel.flow_count(), 0);
        assert!(flow.from_server.recv().await.is_none());
    }

    /// A flow the server never answers is closed after FLOW_OPEN_TIMEOUT (with CloseFlow), so the app does
    /// not wait forever; an answered one stays open.
    #[tokio::test(start_paused = true)]
    async fn unanswered_flow_is_closed() {
        let (tunnel, mut wire, mut bob) = test_tunnel();
        let mut silent = tunnel.open_flow("2001:db8::1", 443).await.unwrap();
        let answered = tunnel.open_flow("example.com", 443).await.unwrap();
        let _ = wire.recv().await;
        let _ = wire.recv().await;
        let created = MultiplexedFrame::new_control(&ControlMessage::FlowCreated {
            flow_id: answered.id,
            local_port: None,
        })
        .unwrap();
        tunnel.handle_control(&created.payload);

        tokio::time::sleep(FLOW_OPEN_TIMEOUT + Duration::from_secs(1)).await;
        assert!(
            silent.from_server.recv().await.is_none(),
            "the silent flow is still open"
        );
        assert_eq!(tunnel.flow_count(), 1, "the answered flow was closed");
        assert_eq!(
            control_of(wire.recv().await.unwrap(), &mut bob),
            ControlMessage::CloseFlow { flow_id: silent.id }
        );
    }

    /// A dead tunnel closes every flow and opens no new one.
    #[tokio::test]
    async fn shut_down_closes_every_flow() {
        let (tunnel, _wire, _bob) = test_tunnel();
        let mut first = tunnel.open_flow("a.example", 80).await.unwrap();
        let mut second = tunnel.open_flow("b.example", 80).await.unwrap();
        assert_eq!(tunnel.flow_count(), 2);

        tunnel.shut_down();
        assert!(!tunnel.is_alive());
        assert!(first.from_server.recv().await.is_none());
        assert!(second.from_server.recv().await.is_none());
        assert!(tunnel.open_flow("c.example", 80).await.is_err());
    }

    /// The uplink sends at most its credits, parks, and continues after a WindowUpdate.
    #[tokio::test]
    async fn uplink_waits_for_credits() {
        let (tunnel, mut wire, mut bob) = test_tunnel();
        let flow = tunnel.open_flow("example.com", 80).await.unwrap();
        let _create = wire.recv().await.unwrap();

        // Spend all but 10 bytes of the window, then queue 30.
        let credits = Arc::clone(&tunnel.flows_lock()[&flow.id].credits);
        let window = credits.available();
        assert_eq!(credits.try_consume(window - 10), window - 10);
        flow.to_server.send(vec![7u8; 30]).await.unwrap();

        let data_len = |msg: Message, bob: &mut DoubleRatchet| {
            let Message::Binary(bytes) = msg else {
                panic!("not binary")
            };
            let parsed = RatchetMessage::from_bytes(&bytes).unwrap();
            let plain = bob.decrypt(&parsed, &[]).unwrap();
            let frame = MultiplexedFrame::decode(&unpad_packet(&plain).unwrap()).unwrap();
            assert_eq!(frame.flow_id, flow.id);
            frame.payload.len()
        };

        assert_eq!(data_len(wire.recv().await.unwrap(), &mut bob), 10);
        tokio::time::sleep(Duration::from_millis(50)).await;
        assert!(wire.try_recv().is_err(), "sent past the credits");

        let update = MultiplexedFrame::new_control(&ControlMessage::WindowUpdate {
            flow_id: flow.id,
            window_size: 100,
        })
        .unwrap();
        tunnel.handle_control(&update.payload);
        assert_eq!(data_len(wire.recv().await.unwrap(), &mut bob), 20);
    }
}
