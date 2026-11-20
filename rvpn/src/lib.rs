//! Wardkeep's rVPN client: a local SOCKS5 server whose connections ride one multiplexed rVPN tunnel.
//!
//! The `wardkeep-rvpn` binary (src/main.rs) is started by the Go core, which routes rVPN profiles into its
//! SOCKS port. The tunnel is upstream's (github.com/PDG-Global/rvpn-core): an X3DH handshake, then every
//! frame under one Double Ratchet, over a WebSocket on TLS. The protocol and the crypto are upstream's
//! rvpn-core crate; the client side is ported from upstream's rvpn-client onto rustls (see the header of
//! each ported file).

pub mod args;
pub mod connect;
pub mod error;
pub mod handshake;
pub mod keys;
pub mod logging;
pub mod server;
pub mod socks;
pub mod tunnel;
pub mod ws;

#[cfg(test)]
mod e2e;
