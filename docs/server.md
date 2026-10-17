# Wardkeep server

`omnitun-server` is one program that serves many VPN protocols to your own users, with one subscription link per user, quotas and traffic accounting, a terminal UI and a web API.

**Honest status.** The sing-box protocols (the first ten below) are tested end to end against Wardkeep's own client. SSTP, IKEv2/IPsec and AmneziaWG have also run on Linux in Docker with real clients (`make docker-e2e`: `sstpc`, strongSwan, OpenVPN, `wg-quick` and an AmneziaWG client connect, reach a web server through the server's NAT, and are counted; see [Tests](#tests)). The same test connects three users at once through three protocols and checks IPv6 inside the tunnels. The installer, the firewall helpers and ACME were written and unit-tested here on Windows with a fake command runner; **they have not run on a real Linux host yet**, and the Windows, iOS and Android IKEv2/SSTP clients have not been tried. Try `install --dry-run` first, then a fresh VPS you can throw away.

## Quick start (a VPS you own)

```sh
# 1. put the binary on the server (a release build, or: go build ./cmd/omnitun-server)
# 2. as root:
omnitun-server init                    # a guided wizard: address, protocols, ports, the site to imitate, first user
omnitun-server install --dry-run       # shows every step
omnitun-server install                 # system user, hardened systemd unit, starts now and at boot, opens the firewall
omnitun-server link alice --qr         # links and QR codes for alice; --sub prints only her subscription URL
```

No terminal wizard? Give everything as flags:

```sh
omnitun-server init --host vpn.example.com --protocols vless-reality,trojan,hysteria2 \
    --port trojan=9443 --first-user alice
```

`init` checks your choices before writing anything; two protocols on the same port (including TCP/UDP overlaps that clash) are refused.

## Protocols

| Protocol | Default port | Notes |
|---|---|---|
| VLESS + Reality | 443/tcp | imitates a real site (`--reality-site`); needs no certificate |
| Shadowsocks 2022 | 8388/tcp+udp | |
| Trojan | 8443/tcp | TLS with the server certificate |
| Hysteria2 | 8443/udp | |
| TUIC v5 | 8444/udp | |
| AnyTLS | 8445/tcp | |
| ShadowTLS v3 | 8446/tcp | with Shadowsocks inside |
| NaiveProxy | 8447/tcp | needs a certificate clients trust (use ACME) |
| WireGuard | 51820/udp | every user gets a key pair and a fixed address (10.30.0.0/16); standard `.conf` download |
| OpenVPN UDP / TCP | 1194 | `.ovpn` download |
| SSTP | 8448/tcp | **Linux, root or `CAP_NET_ADMIN`**; off by default |
| IKEv2/IPsec | 4500/udp (+ 500/udp, TCP 4500) | **Linux, root or `CAP_NET_ADMIN`**; off by default; the server proves itself with its certificate, users sign in with EAP-MSCHAPv2 |
| AmneziaWG | 51821/udp | **Linux, root or `CAP_NET_ADMIN`**; off by default; random obfuscation parameters per server; AmneziaWG 2.0 by default, 1.x on request (see below) |
| DNSCrypt resolver | 5443/tcp+udp | not a way to connect: a DNS resolver for the tunnel's users; off by default, needs `dnscrypt listen <tunnel address>` first; see *DNSCrypt resolver* below |

```sh
omnitun-server proto list                  # ports, status, traffic this month
omnitun-server proto enable sstp
omnitun-server proto port trojan 9443
omnitun-server firewall                    # open the ports again after changing protocols
```

SSTP, IKEv2 and AmneziaWG need a TUN device and NAT on the host. The server sets up and removes narrow nftables (or iptables) rules itself: clients may reach the internet; client-to-client traffic and the host's private networks are dropped. Docker's own firewall policy can still block forwarding. Native Windows and iOS IKEv2/SSTP clients need a certificate they trust, so use `cert acme` for those.

### AmneziaWG: 2.0 or 1.x

A new server makes **AmneziaWG 2.0** parameters: junk packets (`Jc` 4-12, `Jmin`, `Jmax`), paddings `S1`-`S4` for the four kinds of packet (with the 1.x rule `S1 + 56 != S2`), and four header **ranges** `H1`-`H4` that do not touch each other and stay clear of WireGuard's own message types 1-4. A 2.0 header is drawn from its range for every packet, so there is no fixed byte pattern left to match, which is what filters that learned AmneziaWG 1.x look for. That is why 2.0 is the default. The parameters are random per server, checked with the same rules the app uses when it imports them (`core/awg` `CheckParams`), and written into the `.conf` file and the `awg://` link every user gets.

**Classic 1.x** (single-number headers, no `S3`/`S4`) is for old third-party clients that never learned 2.0:

```sh
omnitun-server init --host vpn.example.com --awg-version 1.x     # a new server (2.0 without the flag; the wizard asks too)
omnitun-server proto awg-version 1.x                             # an existing one: new parameters, same keys
omnitun-server proto list                                        # the AmneziaWG row shows 2.0 or 1.x
```

Over the web API: `PATCH /api/v1/protocols/amneziawg` with `{"amneziawg_version": "1.x"}`; in the terminal UI: `v` on the AmneziaWG line of the Protocols tab. Changing the version makes new parameters (the server's keys and the users' keys stay), so **every AmneziaWG user imports their config or link again**; asking for the version the server already has changes nothing. A server stored by an older build keeps the 1.x parameters it has until you change them.

### IPv6 inside the tunnels

Off by default, because a host without IPv6 to the internet would make apps wait for addresses that go nowhere:

```sh
omnitun-server init --host vpn.example.com --ipv6      # a new server
omnitun-server proto ipv6 on                           # an existing one (off to switch back); PUT /api/v1/server/ipv6
sysctl -w net.ipv6.conf.all.forwarding=1               # the host must forward IPv6 (the server warns when it does not)
```

With it on, every user gets a second, unique-local address in **WireGuard** (`fd30:0:0:1::/64`), **AmneziaWG** (`fd31:0:0:1::/64`), **OpenVPN** (`fd18:0:0:1::/64` UDP, `fd19:0:0:1::/64` TCP) and **IKEv2/IPsec** (`fd10:10:10::/64`); the address is derived from the user's IPv4 tunnel address, nothing more is stored. The server forwards and masquerades it (nftables `ip6` table, or `ip6tables`) with the same narrow policy as IPv4: the internet only, not client-to-client or the host's private networks (`fc00::/7`, `fe80::/10`, `::1`). IPv6 traffic is counted for the user like IPv4. **SSTP cannot carry IPv6.** The users' configs and links change (an extra address), so they import them again. If the host gets its own IPv6 address from a router advertisement, `forwarding=1` also switches that off unless `net.ipv6.conf.all.accept_ra=2` is set.

### DNSCrypt resolver (optional)

`dnscrypt` (5443, TCP and UDP) is not a way to connect: it is a DNS resolver for your users, encrypted and authenticated with [DNSCrypt](https://www.dnscrypt.org/), so the VPN's DNS is private and under your control. It is **off by default**, and it is **never open to the internet**: it does not start until you name the one address it listens on, it answers only the VPN's clients, and it asks a public resolver unless you choose otherwise.

```sh
omnitun-server dnscrypt listen 10.30.0.1   # the server's side of the tunnel your users are in (see below)
omnitun-server proto enable dnscrypt       # refused until a listen address is set; a running server picks the change up
omnitun-server link --stamp                # the DNS stamp (sdns://...) to give to clients
omnitun-server dnscrypt status             # listen address, who may ask, key, upstream, stamp
omnitun-server dnscrypt allow 203.0.113.0/24   # more source ranges that may ask (no argument clears them)
omnitun-server dnscrypt upstream 9.9.9.9   # the resolver it asks (default 1.1.1.1; `system` = the host's resolv.conf)
omnitun-server dnscrypt rotate-key         # a new long-term key: the stamp changes, give clients the new one
```

* **Listen address.** One specific address, never `0.0.0.0` or `::` (refused, as is an unset address: `proto enable dnscrypt` and `init --protocols dnscrypt` say how to set it). Use the server's address inside the tunnel: 10.30.0.1 (WireGuard), 10.31.0.1 (AmneziaWG), 10.18.0.1 / 10.19.0.1 (OpenVPN UDP / TCP), or 127.0.0.1 for tests. That interface must exist when the server starts. The stamp names this address and the port, so it works from inside the tunnel. The `firewall` command opens the port for enabled protocols; if the listen address is a tunnel address that is harmless, since nothing outside can reach it. Do not point it at a public address unless you also want the cost of that.
* **Who may ask.** Only these sources are answered; everything else is dropped without a reply, the certificate request included: loopback, the server's own addresses (users of proxy protocols such as Trojan reach it from there), the VPN client networks (10.30/16, 10.31/16, 10.9.0/24, 10.10.10/24, 10.18/16, 10.19/16 and their IPv6 counterparts) and ranges you add with `dnscrypt allow` (a range of every address is refused). Each source address is limited to about 60 queries a second (a burst of 120) and 2 certificate requests a second (a burst of 6); UDP answers are cut to 1232 bytes; `ANY` queries are refused.
* **Upstream.** `1.1.1.1` by default, over UDP and then TCP. The host's `/etc/resolv.conf` is *not* used unless you say `dnscrypt upstream system`, because it often names a resolver that knows internal names.
* **Keys.** `init` makes a long-term Ed25519 key; its public half is in the stamp, and clients refuse a resolver that cannot prove it holds it. The short-term key and the certificate it signs are made when the server starts and replaced every 7 days by the running server (a certificate is valid for 14 days; a client that held the old one takes the new one when its queries stop being answered). The stamp does not change with them.
* **Stamp.** `link --stamp` (also `dnscrypt stamp`) prints it. Paste it into Wardkeep's DNS screen (*Custom*), into `dnscrypt-proxy`, or any client that reads DNS stamps. It declares *no logs* and *no filtering* (the server does neither) and does not claim DNSSEC. A client reaches the address only through the tunnel, so give it to users who are connected (or whose app sends DNS through the VPN).
* **It is not a VPN profile.** It never appears in a user's links or subscription.
* **Host.** Linux or any system where the address can be bound; no root is needed above port 1023. Tested in Docker (`tools/dockertest/dnscrypt_leak.py` runs this resolver with the server's address allowed, a Shadowsocks server and a client in TUN mode, and checks that no lookup leaves the client's card). Not tried with the real WireGuard or OpenVPN tunnel addresses.

## Users, links and quotas

```sh
omnitun-server user add alice --days 30 --quota 100 --note "Alice's phone"
omnitun-server user list                   # state, expiry, usage, live speed
omnitun-server user quota alice 200        # GB per month, 0 = none
omnitun-server user expire alice never
omnitun-server user disable alice
omnitun-server user reset alice            # new credentials; the old links stop working
omnitun-server link alice --ovpn udp       # the OpenVPN config file
```

A user's subscription URL carries the usage, quota and expiry in the standard `Subscription-Userinfo` header, so apps like Wardkeep show them. The monthly quota is counted per UTC calendar month and **blocks** the user (their connections are dropped) until the month rolls over or you raise it. `user usage <name> --reset` clears the count.

Traffic, live connections and speed are counted per user and per protocol for every protocol. OpenVPN users are told apart by the tunnel address they were given (this needs the patched copy of the OpenVPN library in `third_party/sing-openvpn`). A WireGuard-style protocol (AmneziaWG) has no sessions, so a user counts as connected for three minutes after the last handshake. IKEv2 can miss the last two seconds before a client disconnects.

## Certificates

The server starts with a self-signed certificate (clients are told to pin it). For a real one:

```sh
omnitun-server cert acme --domain vpn.example.com --email you@example.com   # Let's Encrypt by default
omnitun-server cert status
omnitun-server cert self-signed            # go back
```

`--dns cloudflare|alidns --dns-token …` uses a DNS challenge; otherwise port 80 must be reachable (`--http-port` to change it). The certificate renews while the server runs. **ACME has not been run against a real CA from here**: try it on a real domain before relying on it.

## Web API, terminal UI, logs

```sh
omnitun-server api enable                  # then `run` serves it; docs at /docs (OpenAPI)
omnitun-server api token                   # the bearer token; --new replaces it at once
omnitun-server api tls on                  # HTTPS with the server certificate
omnitun-server tui                         # users, links with QR codes, protocols, server, logs
omnitun-server logs -f                     # what the server reported: reloads, quota blocks, warnings
```

The API listens on 127.0.0.1 by default. Reach it over an SSH tunnel, or turn on `api tls` before listening publicly (the server warns when it listens publicly without TLS).

## Backup, restore, moving from Xray

```sh
omnitun-server backup omnitun.tar.gz       # state, keys, certificates: it holds every secret
omnitun-server restore omnitun.tar.gz [--force]
omnitun-server import xray /etc/xray/config.json --host vpn.example.com --adopt-reality
```

`import xray` moves an Xray or V2Ray server's users (with their UUIDs and Trojan passwords) and, for a new server, the VLESS+Reality key, short id, site and port, so existing client links keep working.

## Tests

Go tests (`go test ./server/... ./cmd/omnitun-server ./core/protocols`) cover the manager, the CLI, the API, the terminal UI, the in-process AmneziaWG, SSTP and IKEv2 servers (including a handshake between a client device built from the link or `.conf` the server hands out and the server's own device) and the NAT rule sets.

`make docker-e2e` (`tools/dockertest/run.py`; needs Docker; about 25 minutes the first time) runs the real thing: this repo's Linux server in a container with a TUN device and NAT, a web server on a network only the server reaches, and client containers with the standard clients (`openvpn`, `wg-quick`, `sstpc`, strongSwan, and this repo's AmneziaWG client). It has three parts:

- **single**: one user at a time, per protocol: the tunnel works and the web server sees the server's address (NAT), the server shows the live connection and speed, and the traffic is counted for the user and for the protocol.
- **concurrent**: alice, bob and carol connected **at the same time** through three different protocols (OpenVPN UDP, WireGuard and SSTP; then AmneziaWG, IKEv2 and OpenVPN TCP), downloading 8, 4 and 2 MB. Each gets their own live numbers and their own counted bytes (checked against what each downloaded, so a mix-up between users would show), and the protocol totals match. Then bob is disabled and carol is reset while alice keeps downloading: the disabled user and the old credentials are refused, enabling brings bob back with his old credentials, carol's new ones work. **One thing this shows: a change to the user list restarts the listeners, so connected users are cut for a moment.** AmneziaWG and WireGuard clients pick up again by themselves and a transfer survives; an OpenVPN transfer did not, and SSTP and IKEv2 clients have to connect again. Changes that do not touch the listeners (a note, a quota figure, the API settings) no longer restart anything.
- **ipv6**: `proto ipv6 on`, then WireGuard, AmneziaWG, OpenVPN (UDP and TCP) and IKEv2 each get an IPv6 address in the tunnel, reach an IPv6 web server through the server's NAT66, and the IPv6 traffic is counted for the user; SSTP is checked to have none.

`E2E_PREFIX=name` prefixes the containers and networks (default `e2e`), `--only single|concurrent|ipv6`, `--quick`, `--keep`, and `PROTO="sstp ikev2"` choose parts. `.github/workflows/docker-e2e.yml` runs it on GitHub (Ubuntu runner, read-only token, no secrets, every action pinned by hash); that workflow has been checked for syntax only and **has not run on GitHub yet**.

## Files

The data directory is `/var/lib/omnitun-server` as root and `~/.omnitun-server` otherwise (`--data` or `OMNITUN_SERVER_DATA`). It holds `state.json` (users and keys), `stats.json`, `server.log` and the certificates. Several commands can write at the same time; changes are picked up by a running server without a restart.
