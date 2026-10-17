# Wardkeep app

One calm screen: an Earth that shows where you are and where you exit, the state in words, and one button.

## Look

A dark-fantasy look in cold, muted blues (a light "stone" theme is in Settings). Behind the home screen is a dotted Earth: when you connect it turns to the exit country and marks it with a glow. Turn it with one finger (or the mouse), zoom with two fingers (or the wheel); a round button brings it back. While you are connected a thin line follows the path to the exit with dots streaming along it, more of them when there is more traffic; it stops when your phone asks for less motion (Android: *Remove animations*), which also saves battery. Fonts are open (SIL OFL, texts in the app's assets): Inter for all text, Vazirmatn for Persian and Arabic. The land outlines are Natural Earth (public domain). `scripts/gen-icon.py`, `gen-fonts.py` and `gen-globe.py` rebuild the icon, the fonts and the globe data.

## Opening files and links with Wardkeep

Tap a share link (`vless://…`, `trojan://…`, `ss://…`, `hy2://…`, …) anywhere on the phone, or open or share a VPN config file (OpenVPN `.ovpn`, WireGuard `.conf`, Clash/sing-box `.json` or `.yaml`, a `.txt` of links) with Wardkeep, and it imports the servers at once ("Imported 2 profiles"). A subscription link (`https://…`) opens the subscription form instead. On Windows, Linux and macOS the system starts Wardkeep with the file or link, once the file types are registered (`app/windows/packaging`, `app/linux/packaging`); on iPhone and Mac the declarations are in the project but the receiving code is not written yet.

## Offline country database (optional)

Settings → **Offline country database**. Not installed by default. Download it once (about 23 MB, free data) and Wardkeep gives servers a country from their addresses without asking any website, and gives a country to an address a lookup found. The download carries on where it stopped after an error, a pause or a closed app, and every file is checked (size and SHA-256) before it is used. Switch it off or delete it at any time. Data: regional internet registries and ASN announcements (CC0), from the ip-location-db project.

## On Windows

The app draws its own title bar (minimize, maximize, close) in its colours and opens at a size that fits your monitor (about 88 % of its height); drag any edge or corner to resize, and it remembers the size and place. If you start it again while it is running, the first window comes forward (and takes the link or file you opened) instead of a second copy starting. Closing the window ends the app and its core, unless you switch on Settings → **Keep running in the tray**.

**Tray icon.** While the app runs there is an icon in the notification area (the shield). Its tooltip and menu show the state ("Not connected", "Connected · server name"), **Connect / Disconnect** (it says Cancel while connecting), **Switch server** (Automatic, and the fastest twelve servers, with the one in use ticked; choosing one while connected moves the connection there, a server that still needs a password is not listed), **Open Wardkeep** and **Quit**. A left click on the icon brings the window back; a right click opens the menu. The menu is in the app's language and follows the connection. **Quit** ends the app and its core, exactly like closing the window does with the setting off. With **Keep running in the tray** on, closing the window only hides it (the app, the connection and the icon carry on) and starting Wardkeep again, or opening a `vless://` link, brings the hidden window back. If the icon cannot be created the setting has no effect, so a window can never be hidden with nothing to bring it back by. The option is off by default.

**Installer.** `omnitun-<version>-windows-x64-setup.exe` (Inno Setup, source in `installer/`) installs for the current user only: no administrator rights, nothing outside `%LOCALAPPDATA%\Programs\Wardkeep` and your own registry branch. It adds a Start menu entry and, if you tick them, a desktop shortcut, **start with Windows** (starts in the tray, without a window: `--background`) and **share links and config files** (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `hy2://`, `hysteria://`, `tuic://`, `wireguard://`, `awg://`, `anytls://`, `sstp://`, `ikev2://`, `nordvpn://`, `naive+https://`, `wardkeep://` open Wardkeep; `.ovpn`, `.conf`, `.json`, `.yaml`, `.yml`, `.txt` get it in "Open with", the default program is not changed). Uninstalling (Settings → Apps, or `unins000.exe`) removes all of that and asks whether to keep your servers and settings (`%APPDATA%\dev.omnitun\omnitun`, and the core's cache in `%APPDATA%\omnitun`); a silent uninstall (`/VERYSILENT`) keeps them unless `/DELETEDATA` is given. The same files are in the ZIP for running without installing. Both are signed when the release build has a code-signing certificate (repository secrets `WINDOWS_CERT_PFX_BASE64` and `WINDOWS_CERT_PASSWORD`); without one Windows SmartScreen warns on the first start. Build it yourself with `installeruild-installer.ps1` (needs Inno Setup 6); `installer	est-installer.ps1` installs and uninstalls it silently and checks the files and registry entries.

## First start

Three short screens say what the app does, how to add servers and what Android will ask. **Skip** is always there. They are only shown when the app has no servers yet.

## The home screen

* The ring fills while connecting (the real progress: network check, configuration, engine, tunnel, handshake). If something fails it stops red at the step that failed and says why, in your language.
* "Connected" is only shown after a real test connection through the tunnel worked.
* **Not connected:** the Earth is turned to where you really are, with a red marker and your country (found with a direct request to Cloudflare or `api.country.is`; Settings → "Show exit address and country" turns it off, and then the Earth just rests).
* **Connecting:** the Earth flies to the server's country and the big button fills with the real progress ("Cancel · 48%"). **Connected:** it says **Connected to <country>** with the flag, the server's name and part of the exit address (`147.78.x.x`). Disconnecting flies back. Nothing is written on the Earth.
* **Location** opens the list of places. **Connect / Cancel / Disconnect** is the only button.
* Settings (the sliders icon) is at the top, and Logs are in Settings. Everything else opens from there and closes with Back; there is no footer.
* A notification (Android) shows the speed and has a Disconnect button.

## Choosing where to connect

* **Automatic**: the fastest server you know (run the speed test, the gauge icon), switching to the next one if a server stops working.
* **A country**: any server in that country, fastest first. The arrow opens its servers; tap one to use only that server.
* **Tor**: has its own row; it only runs when you pick it.
* Choosing a place while connected moves the connection there.

Countries come from what you set ("Set country" in a server's menu or in its editor), else they are guessed from the name (a flag emoji, `DE-Berlin-01`, `[US]`, a country or big-city name) and from the address (`de1.example.com`, `.nl`). Servers whose country is not known are under **Other**. The app does not look servers up in a GeoIP database.

## Adding servers

**+** in the location list:

* **Import a config, link or QR**: share links (`vless://`, `trojan://`, `ss://`, `hy2://`, `tuic://`, `anytls://`, `ssh://`, `sstp://`, `ikev2://`, `wireguard://`, `awg://`, …), Clash and sing-box configs, Xray client JSON, WireGuard/AmneziaWG `.conf`, OpenVPN `.ovpn`, Tor bridge lines, or a subscription link. Paste, open a file or scan a QR code.
* **Add a server by hand**: pick the protocol; the form is checked by the same core that connects, and its messages are shown as they are.
* **Add a subscription**: URL, optional authentication (none, Basic, Bearer, a custom header, a token in the URL) and how to download it: directly, **directly or through the VPN if the provider is blocked**, or always through the VPN. Usage and expiry from the provider are shown, and it refreshes on the provider's interval.

A server's menu: **Edit**, **Share link or QR** (scan it on another device), **Set country**, **Delete**. Editing a server that came from a subscription is overwritten the next time the subscription refreshes. **Manage servers** (Settings, or the **+** menu) is where you reorder servers (failover order), manage subscriptions and delete.

For Tor, **Bridge settings** is the editor: no bridge, Snowflake, obfs4 or your own bridge lines (paste, file, QR). Where Tor is blocked, Snowflake worked on the test phone; the built-in obfs4 bridges did not.

## Bypass lists

Settings → **Bypass lists**: websites and addresses that should not use the VPN (your bank, local services). One entry per line:

```
example.com            the domain and its subdomains
full:www.example.com   exactly this name
keyword:bank           names containing this word
regexp:^ads?\..*       names matching an expression
203.0.113.7            an address
10.0.0.0/8             a range (IPv4 or IPv6)
# a comment
```

Add a list by typing, pasting, opening a `.txt` file or downloading a link. The app shows how many entries it understood and which lines it will ignore. Each list can be switched off. **Only the listed destinations use the VPN** turns it round: everything else goes direct. Changes apply the next time you connect.

**Battery and speed.** The app tidies a list before using it: a name under another listed domain, a name containing a listed keyword, and nested or neighbouring address ranges are merged, so the matcher stays small. Traffic to listed addresses is decided first and never inspected; names are only recognised (from the first packet of a connection) when your list has names in it. Listed address ranges are kept out of the VPN's routes (the largest first, up to a limit of a few hundred routes; the rest are still bypassed, one step later). In "only the listed" mode with only addresses, nothing else enters the VPN at all.

**Whole countries.** At the top of the same screen, **Countries** lets you tick countries whose addresses go straight to the internet, around the VPN (and, with *Only the listed destinations use the VPN*, the only ones that use it). The address ranges come from the **offline country database** (Settings → *Offline country database*, a one-time download of about 23 MB, public registry data): without it, the screen still lists every country: ticking one downloads just that country's list (a few KB, from IPdeny, or from ipverse if that is blocked), and the screen offers the full database too. If the country you tick is the one your selected server is in, the screen says so. A country is a list of ranges that the app counts for you (Iran about 4 000 blocks, Germany about 83 000, the United States about 209 000), merged with your own lists; the ranges are a snapshot, so *Update* the database now and then. The tunnel to your server is not affected by this (the app's own connection to the server never goes through the tunnel), but anything you send to a ticked country skips the VPN, including the country your server is in.

## Settings worth knowing

* **VPN mode** off = proxy only (a local SOCKS/HTTP port, no VPN permission). On Android it is on by default.
* **Auto-switch on failure**: try the next server when one stops working.
* **Bypass local network**: LAN devices stay reachable while connected.
* **Always-on VPN and kill switch** (Android): opens the system's VPN settings. Turn on "Always-on VPN" (Android reconnects at boot and after the app was stopped, using the last connection) and, if you want, "Block connections without VPN" (no traffic while the VPN is down). Connect once from the app first.
* **Split tunneling** (Android): choose which apps use the VPN, or which bypass it.
* **Remote DNS**: the resolver used through the tunnel: a URL, a DNS stamp, or a DNSCrypt resolver from a list (see **DNS** below).
* **Language**: English, فارسی, Русский, 中文, العربية, Español, हिन्दी, Français, Português, اردو, Bahasa Indonesia, Türkçe, Tiếng Việt (the layout mirrors for Persian, Arabic and Urdu). Translations other than English were not checked by native speakers: tell us what reads wrong. **Appearance**: dark, light or the system's.

## DNS

Settings → **Remote DNS** opens the DNS screen. It sets which resolver answers the names your apps look up while the VPN is on. The choices:

* **Default**: Cloudflare over HTTPS (`https://1.1.1.1/dns-query`), as before. **Cloudflare · TLS** and **Quad9 · HTTPS** are the same kind of choice with another resolver or protocol.
* **DNSCrypt resolvers**: a short list of public DNSCrypt resolvers that validate DNSSEC, keep no logs and filter nothing. The list is bundled in the app (about two dozen entries chosen from the DNSCrypt project's public list; its signature was checked when it was bundled, and `scripts/gen-resolvers.py` rebuilds it), because the place the list lives, GitHub, may be blocked where you are.
* **Custom**: any address the core understands (`https://…`, `tls://…`, `tcp://…`, `udp://…`, a bare IP) or a **DNS stamp** (`sdns://…`: a short string that carries the protocol, address, port and, for DNSCrypt, the resolver's public key). A stamp may name a DNSCrypt, DoH, DoT, DoQ or plain resolver. A wrong entry is refused with the reason (not a stamp, damaged, a kind that is not supported, a relay stamp where a resolver is needed) and nothing is saved until it is valid. When the VPN starts the core checks it again.
* **Anonymized DNSCrypt** (a switch, only with a DNSCrypt resolver): the queries go through a *relay*, a server that passes them on without being able to read them, so the resolver never sees where they come from. The app picks a relay run by someone other than the resolver's operator (in another country when it can); you can choose another. The bundled relay list comes from the same signed source.

While connected, the home screen shows one more line under the server, `DNS: DNSCrypt · quad9.net` (with `(anonymized)` when a relay is used), but only once you have changed the default.

**What it does.** A DNSCrypt resolver is *authenticated*: its public key is part of the stamp, so nobody on the path can answer in its place, and the queries are encrypted. The app's DNSCrypt client runs inside the VPN's core and sends its packets **through the tunnel** (the same outbound as your traffic), so the network you are on sees only the VPN connection, not the resolver, the relay or any lookup. With Tor the client uses TCP only (Tor carries no UDP) and only the ports Tor exits allow. If the resolver cannot be reached the lookups **fail**: the app does not quietly fall back to another resolver, and the log says "DNS unavailable" with the reason. A resolver whose key is not the one in the stamp is refused.

**What it does not.** It protects the names you look up. It does not hide which sites you then connect to (the VPN server and the sites see those), and the resolver you choose still sees the names (with a relay it does not see your address). In this version:

* It applies to tunnels run by the core's sing-box engine (the share-link protocols, WireGuard, OpenVPN, Tor). AmneziaWG, SSTP and IKEv2 tunnels take the DNS their server pushes.
* Lookups to a resolver on your local network (the router's address as the phone's DNS, for example) stay local while *Bypass local network* is on, by design; turn it off to send them through the VPN too.
* Names in your **bypass lists** are looked up with the system's resolver, as the connections to them go around the VPN.
* Certificate pins in DoH, DoT and DoQ stamps are not checked (sing-box does not take them); the connection is checked against the host name as usual.
* Tested: the stamp reader, the DNSCrypt client against the library's server (both ciphers), a wrong key refused, a certificate rotation, Anonymized DNSCrypt through a relay, the sing-box configuration for every kind of stamp, a full chain with a real sing-box tunnel, and, on Linux in Docker (`tools/dockertest/dnscrypt_leak.py`), a leak capture: with the VPN up nothing but VPN traffic leaves the network card and the resolver sees only the VPN server. Not tested on a phone or on Windows, nor from a network that blocks DNSCrypt's usual ports (443 and 5353 are common; Quad9 uses 8443): try several resolvers.

## What the messages mean

| Message | Usually |
|---|---|
| The server did not answer in time | the server is down, or blocked from your network; try another protocol or server |
| The server refused the connection | nothing listens on that port, or a firewall rejected it |
| The server's security certificate was rejected | a self-signed certificate that was not pinned, or a wrong date on the phone |
| The username or password was rejected | edit the server and check them (OpenVPN, SSTP, IKEv2) |
| No internet connection | the device itself is offline; nothing is wrong with the server |
| Tor did not finish connecting | this network blocks Tor; use a Snowflake bridge |

## Privacy

Server passwords and keys are kept in the app's private storage; Android backup of the app is off, so they are not copied to a cloud account. Tor never logs the destinations it connects to. The log screen can be copied or cleared.

## Windows: service and kill switch

**Status: written and unit-tested, not tried on a real service.** Nothing below has been installed or run as administrator yet; `scripts/windows-service-test.ps1` is the check to run first.

Without the service the app works as before: it starts its own `omnitun-svc` for the user, which is enough for proxy mode (system proxy) but cannot open the VPN (TUN) adapter without administrator rights.

### The service

`omnitun-svc` can run as a Windows service (LocalSystem), so VPN mode works from an app that is not run as administrator. In an elevated terminal:

```
omnitun-svc install [--user NAME]...   copies the program to Program Files\Omnitun and registers the service (starts automatically, restarts after a crash)
omnitun-svc start | stop
omnitun-svc status                     works for any user; says whether this user can use the service
omnitun-svc uninstall [--purge]        --purge also removes %ProgramData%\omnitun
omnitun-svc cleanup [--force]          removes leftovers of a crashed run (refuses while the service runs)
```

The app prefers the service for VPN mode when it finds one that lets the user in (`%ProgramData%\omnitun\control\control.json`, the token is accepted); proxy mode and everything else stay in the app's own daemon, because the service has no desktop session to set the system proxy in. If the service is not installed, stopped or does not admit the user, nothing changes. As before, the tunnel stops about 5 seconds after the app is gone (the lease), the service keeps running.

**Who may drive the VPN.** The service listens on 127.0.0.1 only, on a random port, and does nothing before a valid token. The token is made at every start and kept in `%ProgramData%\omnitun\control\`, a folder with its own access list: SYSTEM and Administrators full control, plus read access for the accounts named at install time (`--user`, by default the account that ran the installer). No other user can read the token. The folder is created with that list already attached and is never adopted if it exists but is not owned by SYSTEM or Administrators or is a link. The program is copied to Program Files so that no normal user can replace what runs as SYSTEM. A request carries profiles, never sing-box JSON or file paths.

### Crash cleanup

When the core dies without cleaning up, the TUN mode leaves a Wintun adapter called `Wardkeep` (its address, routes and DNS settings go with it) and possibly a stale resolver cache. The service removes these when it starts and when it stops, and `omnitun-svc cleanup` does it by hand; only the adapter whose identity is derived from exactly that name is touched. Firewall rules of the tunnel and of the kill switch are in dynamic sessions that Windows removes when the process ends, so they cannot be left behind. Not covered: the system proxy of proxy mode is a per-user setting that a crash leaves pointing at a dead port.

### Kill switch

With the service, VPN mode can block every packet that does not use the tunnel (Windows Filtering Platform, a dynamic session): allowed are loopback, the tunnel adapter, the VPN servers' addresses, the core's own sockets, DHCP and neighbour discovery, local networks (unless "send local networks through the VPN" is on) and the ranges of the user's bypass list (at most 4096). A dropped tunnel keeps the block until the user disconnects; a failed first connection lifts it; "block while connecting" raises it before the tunnel is up. If the block cannot be raised the connection is stopped with an error. Not supported yet: Tor, IKEv2, SSTP and AmneziaWG profiles, and "only these use the VPN". The request fields are `kill_switch` and `kill_switch_early`; there is no Settings switch yet. If `omnitun-svc` itself is killed the block disappears with it. `omnitun-svc killswitch-selftest --yes` tries it for a few seconds (the whole machine loses its network meanwhile).

### Antivirus and interface-bound sockets

In VPN mode sing-box binds its outgoing sockets to the real network interface (`auto_detect_interface`, needed so they do not loop into the tunnel). Some security software on Windows interferes with such sockets (Kaspersky on the developer's PC also intercepts DNS over HTTPS and blocks outgoing TCP port 53 from unknown programs; use `tls://` DNS there). A plain socket and one bound with `IP_UNICAST_IF` both connected on the developer's PC, but that PC's default interface was a VPN's, so it says nothing about the real adapter. There is no safe code change: dropping the binding would make the tunnel loop. If VPN mode fails with "forbidden by its access permissions", allow `omnitun-svc.exe` in the security software.
