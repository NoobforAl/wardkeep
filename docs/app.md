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

**Installer (Windows).** `wardkeep-<version>-windows-x64-setup.exe` (Inno Setup, source in `installer/`) installs for the current user only: no administrator rights, nothing outside `%LOCALAPPDATA%\Programs\Wardkeep` and your own registry branch. It adds a Start menu entry and, if you tick them, a desktop shortcut, **start with Windows** (starts in the tray, without a window: `--background`) and **share links and config files** (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `hy2://`, `hysteria://`, `tuic://`, `wireguard://`, `awg://`, `anytls://`, `nordvpn://`, `naive+https://`, `wardkeep://` open Wardkeep; `.ovpn`, `.conf`, `.json`, `.yaml`, `.yml`, `.txt` get it in "Open with", the default program is not changed). Uninstalling (Settings → Apps, or `unins000.exe`) removes all of that and asks whether to keep your servers and settings (`%APPDATA%\dev.omnitun\omnitun`, and the core's cache in `%APPDATA%\omnitun`); a silent uninstall (`/VERYSILENT`) keeps them unless `/DELETEDATA` is given. It is signed when the release build has a code-signing certificate (repository secrets `WINDOWS_CERT_PFX_BASE64` and `WINDOWS_CERT_PASSWORD`); without one Windows SmartScreen warns on the first start. Build it yourself with `installer\build-installer.ps1` (needs Inno Setup 6); `installer\test-installer.ps1` installs and uninstalls it silently and checks the files and registry entries.

**Installer (Linux).** `wardkeep-<version>-linux-x64-setup.sh` (source in `installer/linux/`) is one file that installs for the current user only; it refuses to run as root. Run it with `sh wardkeep-<version>-linux-x64-setup.sh`. The program goes to `~/.local/share/wardkeep` (`--prefix DIR` changes that), the command `wardkeep` is a link in `~/.local/bin`, and the menu entry (`dev.omnitun.app.desktop`) and its icon go to `~/.local/share/applications` and `~/.local/share/icons`. Unless `--no-links` is given, Wardkeep becomes the program for the share links above (`xdg-mime`) and is offered for config files under "Open with". Running the installer again updates the program. `sh ~/.local/share/wardkeep/uninstall.sh` removes all of it and keeps your servers and settings (`~/.local/share/dev.omnitun.app`, `~/.config/omnitun`); `--purge` deletes them too. It needs `tar`, `xz` and GTK 3 with `libayatana-appindicator3` and `libnotify` (Debian/Ubuntu: `sudo apt install libgtk-3-0 libayatana-appindicator3-1 libnotify4`); the installer checks the libraries and says which one is missing. `installer/linux/test-installer.sh` installs, updates and uninstalls it in a throw-away home folder and checks every step.

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

* **Import a config, link or QR**: share links (`vless://`, `trojan://`, `ss://`, `hy2://`, `tuic://`, `anytls://`, `ssh://`, `wireguard://`, `awg://`, …), Clash and sing-box configs, Xray client JSON, WireGuard/AmneziaWG `.conf`, OpenVPN `.ovpn`, Tor bridge lines, or a subscription link. Paste, open a file or scan a QR code.
  * **Scanning a QR code** (Android and iOS) opens the camera and reads the first QR code in view; the camera permission is asked for then, and a camera that cannot be used (permission refused, no camera) is named on the screen. The decoder is zxing-cpp (flutter_zxing) on CameraX: no Google ML Kit or Play services, so it works on phones without them. There is no scan from a picture; a QR code in a screenshot cannot be imported yet.
  * **JSON** can be pasted as text or opened as a file: a whole Xray or sing-box config, a SIP008 list, a single outbound copied out of a config (`{"protocol": "vless", …}` or `{"type": "vless", …}`), or a list `[ … ]` of any of those (and of share links). Comments (`//`, `/* */`) and trailing commas are accepted, and so is JSON pasted with its markdown code fence. A file may be UTF-8 or UTF-16, up to 8 MB.
  * **When it fails, the sheet says why** (and stays open so the text can be fixed): not valid JSON, with the line, column and character where it stops making sense, or the text ending too early; valid JSON with no proxy server in it, saying what it does hold (`outbounds: direct, block`); a server that is there but wrong, with the reason for each one listed under the message; a file that is empty, binary, in an unknown encoding, too large, missing, or one Wardkeep may not read. A file another app sends (Android "Open with" or "Share") gets the same messages.
* **Add a server by hand**: pick the protocol; the form is checked by the same core that connects, and its messages are shown as they are.
* **Add a subscription**: URL, optional authentication (none, Basic, Bearer, a custom header, a token in the URL) and how to download it: directly, **directly or through the VPN if the provider is blocked**, or always through the VPN. Usage and expiry from the provider are shown, and it refreshes on the provider's interval.
  * **Signed subscriptions.** A provider that signs its subscription (a Wardkeep server does) gives a link ending in `#pk=<key>`; paste it as it is and the key is taken from it, or type the key in **Signing key**. From then on every answer must carry a valid signature, or it is refused (*not signed*, *the signature is wrong*): a list changed on the way, or served from another address or user's, does not pass, and neither does an old answer played back (*older than the last one accepted*; if the provider restored an old backup, open the subscription and save it again). A signed subscription is marked **Signed**. A signed subscription does not follow redirects: use the final address. With no key nothing is checked, and the form says so.
  * **Backup addresses.** More addresses of the same subscription, one per line, tried in order when the first cannot be reached (a blocked name, a moved server). They face the same signature check, and must keep the same path.
  * **Protocol order.** A provider can ask for protocols to be tried in an order, for everyone or for one country (the phone's region setting decides which one applies). It counts only on a signed answer.

A server's menu: **Edit**, **Share link or QR** (scan it on another device), **Set country**, **Delete**. Editing a server that came from a subscription is overwritten the next time the subscription refreshes. **Manage servers** (Settings, or the **+** menu) is where you reorder servers (failover order), manage subscriptions and delete.

Under **More options** the editors of VLESS, VMess, Trojan, AnyTLS and Shadowsocks hold settings that help on a hostile network:

* **Multiplexing** (VLESS, VMess, Trojan, Shadowsocks; smux, yamux or h2mux): many connections over one, so a page that opens thirty costs one handshake. The server has to allow it (a Wardkeep server does for Trojan and Shadowsocks, not for VLESS-Reality, whose users have the `xtls-rprx-vision` flow, which cannot be multiplexed). On a bad link it can slow every connection at once.
* **Fragment the TLS handshake** and **Fragment the TLS records** (VLESS, VMess, Trojan, AnyTLS): split the first packet (or its TLS record), so a filter that reads the server name from it does not see it whole. It helps against some filters, can break on others and adds delay.
* **Encrypted Client Hello (ECH)** (VLESS without Reality, VMess, Trojan, AnyTLS): hides the server name inside the handshake. It needs a server that supports it, and its configuration (PEM) or a DNS record that publishes it.
* **Through a proxy** (WireGuard): a share link of a proxy (VLESS, VMess, Trojan, Shadowsocks, Hysteria 2 or TUIC) that carries the WireGuard packets, for networks that block UDP. The proxy has to pass UDP; if it is slow the tunnel can stall.

For Tor, **Bridge settings** is the editor: no bridge, Snowflake, obfs4 or your own bridge lines (paste, file, QR). Where Tor is blocked, Snowflake worked on the test phone; the built-in obfs4 bridges did not.

## Warnings

Protocols and settings that are easy to recognise, unsafe or slow say so: a note in the protocol list, an amber box at the top of the editor (a setting's own note shows only while it is on) and on the share screen. A warning never stops you from saving. What they mean:

| Warning | It is shown for |
|---|---|
| The server's certificate is not checked | *Skip certificate check* |
| Not wrapped in TLS | VLESS, VMess or Trojan with security *none* |
| An older protocol, easy to recognise | VMess: VLESS with Reality is better |
| Looks like random bytes | Shadowsocks without a plugin such as shadow-tls: some networks block that pattern |
| Deprecated | Hysteria 1: use Hysteria 2 |
| Easy to identify, often blocked on strict networks | WireGuard, OpenVPN; SSH tunnels likewise |
| Slow, TCP only, visible DNS volume | the DNS tunnel; and *anyone with the link can use the server* when it has no login |
| Fragmenting, ECH, multiplexing, WireGuard through a proxy | a short note on what each costs |

## DNS tunnel

For networks where nothing but DNS gets out. Connections travel inside DNS queries to a resolver, which asks the tunnel server's zone (the protocol is [dnstt](https://www.bamsoftware.com/software/dnstt/)). It is slow (usually well under 1 Mbit/s), TCP only, and the volume of DNS queries is visible to whoever watches the network: **use it when nothing else works**.

* **Add** it with *Add a server by hand → DNS tunnel*, or import a `dnstt://<server key>@<domain>?resolver=...&user=...&pass=...` link (a Wardkeep server prints one per user). The fields are the tunnel domain, the server's key (64 hex digits), the resolvers (`udp://IP:port`, `tls://host:port`, `https://host/path`), and the login of the server's upstream.
* **Resolvers** are tried in order; the first few are tried at once, and when none answers the next ones are. A session that ends is retried through the same resolver first. A UDP resolver has to be an IP address, so no name is looked up outside the tunnel's own sockets.
* **Find working resolvers** (under the resolvers field) tests the tunnel through well-known public resolvers, a few of which answer inside Iran, and fills the field with the ones that work, the fastest first. It refuses while the VPN is on (it would measure the VPN): disconnect first.
* It runs only when you pick it, like Tor: **Automatic** never chooses it, no country is guessed for it, and it never falls back to another server. The **kill switch** does not support it yet.
* Its own connections to the resolver leave through the network directly and never through the VPN they carry.

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

* It applies to tunnels run by the core's sing-box engine (the share-link protocols, WireGuard, OpenVPN, Tor). AmneziaWG tunnels take the DNS their server pushes.
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
| The username or password was rejected | edit the server and check them (OpenVPN) |
| No internet connection | the device itself is offline; nothing is wrong with the server |
| Tor did not finish connecting | this network blocks Tor; use a Snowflake bridge |
| The subscription is not signed (a signing key is set) | the provider's answer has no signature; check the key, or ask the provider |
| The subscription's signature is wrong | the list was changed on the way, or the key is an old one |
| Older than the last one accepted | an old copy was served, or the provider restored a backup: save the subscription again to start over |
| Disconnect first (resolver scan) | the scan has to use the network directly, not through the VPN |

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

**Who may drive the VPN.** The service listens on 127.0.0.1 only, on a random port, and does nothing before a valid token. The token is made at every start and kept in `%ProgramData%\omnitun\control\`, a folder with its own access list: SYSTEM and Administrators full control, plus read access for the accounts named at install time (`--user`, by default the account that ran the installer). No other user can read the token. The folder is created with that list already attached and is never adopted if it exists but is not owned by SYSTEM or Administrators or is a link. The program is copied to Program Files so that no normal user can replace what runs as SYSTEM; only `omnitun-svc.exe`, `libcronet.dll` and `omnitun-tor.exe` are copied (exact names, no links, hashed while copying), and `install` opens each file once and keeps the handle (so it cannot be changed, renamed or deleted meanwhile), checks the file's access list through that handle, and refuses the source if the file, the folder holding it or any folder above it up to the drive root can be changed or taken over by non-administrators (or if one is a link); the message names the folder that failed. `--unsafe-source` skips this, for development. A request carries profiles, never sing-box JSON or file paths.

### Crash cleanup

When the core dies without cleaning up, the TUN mode leaves a Wintun adapter called `Wardkeep` (its address, routes and DNS settings go with it) and possibly a stale resolver cache. The service removes these when it starts and when it stops, and `omnitun-svc cleanup` does it by hand; only the adapter whose identity is derived from exactly that name is touched. Firewall rules of the tunnel and of the kill switch are in dynamic sessions that Windows removes when the process ends, so they cannot be left behind. Not covered: the system proxy of proxy mode is a per-user setting that a crash leaves pointing at a dead port.

### Kill switch

With the service, VPN mode can block every packet that does not use the tunnel (Windows Filtering Platform, a dynamic session): allowed are loopback, the tunnel adapter, the VPN servers' addresses, the core's own sockets, DHCP (outgoing messages only to the broadcast address and, for IPv6, the DHCP multicast groups and link-local addresses; not tied to the DHCP service's process, which shares a host process) and neighbour discovery, local networks (unless "send local networks through the VPN" is on) and the ranges of the user's bypass list (at most 4096). A dropped tunnel, or the engine stopping itself for a restart or failover, keeps the block until the user disconnects (or the app is gone for 5 s); a failed first connection lifts it; "block while connecting" raises it before the tunnel is up. If the block cannot be raised the connection is stopped with an error. Not supported yet: Tor, AmneziaWG and DNS tunnel profiles, and "only these use the VPN". The request fields are `kill_switch` and `kill_switch_early`; there is no Settings switch yet. If `omnitun-svc` itself is killed the block disappears with it. `omnitun-svc killswitch-selftest --yes` tries it for a few seconds (the whole machine loses its network meanwhile).

### Antivirus and interface-bound sockets

In VPN mode sing-box binds its outgoing sockets to the real network interface (`auto_detect_interface`, needed so they do not loop into the tunnel). Some security software on Windows interferes with such sockets (Kaspersky on the developer's PC also intercepts DNS over HTTPS and blocks outgoing TCP port 53 from unknown programs; use `tls://` DNS there). A plain socket and one bound with `IP_UNICAST_IF` both connected on the developer's PC, but that PC's default interface was a VPN's, so it says nothing about the real adapter. There is no safe code change: dropping the binding would make the tunnel loop. If VPN mode fails with "forbidden by its access permissions", allow `omnitun-svc.exe` in the security software.
