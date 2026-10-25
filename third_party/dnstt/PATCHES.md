# Omnitun patches to dnstt

Upstream: https://www.bamsoftware.com/git/dnstt.git (David Fifield), commit
`0c5c52a57d899c05428c116898941761a2ed83c2` ("Update CHANGELOG to v1.20260501.0.").
License: CC0 1.0 (public domain), see `COPYING`.

Taken: `dns/`, `noise/`, `turbotunnel/`, the client (`dnstt-client/*.go` → `client/`) and
the server (`dnstt-server/main.go` → `server/server.go`). Left out: the man pages, the
README, the TODO, the changelog, and the flag-parsing `main` functions.

The wire format is upstream's, byte for byte: a client of this package works with a stock
`dnstt-server`, and the server here with a stock `dnstt-client`. Upstream's tests are kept.

1. Import path: `www.bamsoftware.com/git/dnstt.git/...` →
   `github.com/NoobforAl/omnitun/third_party/dnstt/...`; the two programs are packages
   (`client`, `server`), not `main`.
2. `client/client.go` (new, replaces `dnstt-client/main.go`): the session as a library.
   `Open` builds the DNS transport, the KCP connection, the Noise channel and the smux
   session and returns a `Session` (`Forward` carries one local TCP connection through a
   new stream, `Done`, `Close`); `Probe` opens and closes one and reports the handshake
   time (the test of a resolver); `ParseResolver` checks `udp://`, `tls://`, `https://`.
3. Sockets are injected: `Config.Dial` (DoH and DoT) and `Config.ListenPacket` (UDP, told the
   resolver's address it will talk to) open every outbound socket, so the embedding app can route them past its own VPN. In
   `client/utls.go` `utlsDialContext`, `NewUTLSRoundTripper` and `makeRoundTripper` take the
   dial function instead of using `net.Dialer`.
4. Nothing goes out through the system's own sockets or proxy settings: a UDP resolver must
   be an IP address (no name lookup), the plain-`http` branch of the uTLS round tripper is an
   error (a DoH resolver must be `https://`), and the HTTP/1.1 transport made by the uTLS
   round tripper has `Proxy = nil`.
5. Logging: `log.Printf` → `logf`, which does nothing until `SetLogf` is called (both
   packages); upstream logged to the process's standard logger.
6. `server/serve.go` (new, replaces `dnstt-server/main.go`): `Serve(ctx, conn, Config)` runs
   the server on an already open UDP socket until the context ends. Key generation and key
   files are not here: `noise.GeneratePrivkey`, `PubkeyFromPrivkey`, `EncodeKey` and
   `DecodeKey` are used by the caller.
7. `server/server.go` `run`: upstream closed the channel to `sendLoop` as soon as `run`
   returned, which panics a `recvLoop` that is still sending ("send on closed channel"): fine
   for a program that is about to exit, not for a library that is stopped and started. `run`
   now closes the socket, waits for `recvLoop`, then closes the channel, and closes its
   `QueuePacketConn`.
8. `noise/noise_test.go`: `t.Fatal` in a goroutine → `t.Error` (go vet refuses it).
9. A resolver that accepts the connection and then answers nothing (a middlebox that swallows the TLS
   handshake) held `Probe` and `Open` forever: `utlsDialContext` ran `Handshake()` with no context
   (`HandshakeContext(ctx)` now), and `NewTLSPacketConn` made its first dial from
   `context.Background()` (it takes the caller's context for that dial; redials still use their own).
