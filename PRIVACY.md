# Wardkeep privacy policy

Last updated: November 1, 2026. The app shows the same text under Settings > Privacy policy.

Wardkeep has no account, no ads, no analytics and no crash reporting. Its developers run no server that the
app reports to, so we never receive your data.

## What stays on your device

Your servers (with their passwords and keys), subscriptions, settings and traffic counters are kept in the
app's private storage on this device. They leave it only when you export or share them.

## Logs

Logs are kept on this device only. They never contain the sites you visit, IP addresses, host names or app
names: those are removed before a record is written. You decide whether to copy, save or share them.

## What the app contacts on its own

- Before it connects: a quick check that the internet works (the public DNS servers of Cloudflare, Google,
  Quad9 and OpenDNS, and a name lookup of microsoft.com and apple.com).
- Once connected: a test request to Google (gstatic.com) through the VPN, to check that the server works.
- "Show exit address and country" (on unless you turn it off): Cloudflare (1.1.1.1) or api.country.is,
  which see the address you connect from: your own when not connected, the server's when connected.
- DNS: names are resolved by the DNS server you choose (Cloudflare by default).

## Only when you ask

- Subscriptions you add, refreshed from their address (by default once a day).
- The offline country database (from jsDelivr or unpkg) and the address lists of countries you bypass (from
  ipdeny.com or jsDelivr).
- NordVPN's server list, if you add a NordVPN account.
- Tor's directory and relays, when you use Tor.

## Your VPN servers

Your traffic goes through the servers you add, and the app contacts them to test and use them. Their
operators can see your traffic as any VPN provider can; their own privacy policy applies, not this one.

## Permissions (Android)

- VPN: to route your traffic.
- Notifications: to show the connection and errors.
- Camera: only while you scan a QR code. The image never leaves the device, and no Google service is used.
- The list of installed apps: only to choose apps for split tunneling.

## Changes and contact

Wardkeep is open source (MIT), so all of this can be checked in its code. If this policy changes, the new
version comes with an app update. Questions: open an issue at https://github.com/NoobforAl/wardkeep.
