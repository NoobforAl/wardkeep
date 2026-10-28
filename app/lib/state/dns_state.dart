import 'dart:convert';

import 'dns_resolvers.dart';

/// DNS stamps (`sdns://...`) and the resolver choices of the DNS screen.
///
/// The core (core/dnscrypt/stamp.go) is the authority and checks the stamp again when the VPN starts;
/// this file reads just enough of a stamp to tell people what is wrong with it, and what it names,
/// without starting anything. The tests use the same stamps as the Go tests.

const dnsStampPrefix = 'sdns://';

/// What a stamp names. The numbers are the stamp format's.
enum DnsKind {
  plain(0x00, 'Plain'),
  dnscrypt(0x01, 'DNSCrypt'),
  doh(0x02, 'DoH'),
  dot(0x03, 'DoT'),
  doq(0x04, 'DoQ'),
  relay(0x81, 'relay');

  const DnsKind(this.code, this.label);
  final int code;
  final String label;
}

/// Why a resolver setting cannot be used. The screen turns each into a translated message.
enum DnsProblem {
  /// Not `sdns://...` and not a resolver URL either.
  notStamp,

  /// The stamp is not base64, is cut short or has extra data.
  damaged,

  /// A kind of stamp the app does not use (for example oblivious DoH).
  unsupported,

  /// A relay stamp where a resolver is needed.
  relayAsResolver,

  /// Something that is not a relay where a relay is needed.
  notRelay,

  /// A resolver URL with a scheme the core does not speak.
  badUrl,
}

/// What a stamp names.
class DnsStamp {
  const DnsStamp({required this.kind, required this.props, required this.address, required this.name});

  final DnsKind kind;

  /// Declared properties: bit 0 DNSSEC, bit 1 no logs, bit 2 no filtering.
  final int props;

  /// The address as written in the stamp (may be empty for DoH, DoT and DoQ).
  final String address;

  /// Short name for people: the provider without its DNSCrypt prefix, or the host.
  final String name;
}

/// Either [stamp] (or, for a plain URL, only [name]) or a [problem].
class DnsCheck {
  const DnsCheck.ok({this.stamp, this.name = ''}) : problem = null;
  const DnsCheck.bad(DnsProblem this.problem) : stamp = null, name = '';

  final DnsStamp? stamp;
  final DnsProblem? problem;

  /// The host of a URL setting; for a stamp see [stamp].
  final String name;

  bool get ok => problem == null;
}

class _Reader {
  _Reader(this.bytes);
  final List<int> bytes;
  int pos = 1; // the first byte is the stamp's kind
  bool failed = false;

  int u8() {
    if (pos >= bytes.length) {
      failed = true;
      return 0;
    }
    return bytes[pos++];
  }

  List<int> take(int count) {
    if (pos + count > bytes.length) {
      failed = true;
      pos = bytes.length;
      return const [];
    }
    final chunk = bytes.sublist(pos, pos + count);
    pos += count;
    return chunk;
  }

  List<int> lp() => take(u8());

  /// A set of strings in which every length byte but the last has its top bit set.
  void vlp() {
    while (!failed) {
      final len = u8();
      take(len & 0x7f);
      if (len & 0x80 == 0) break;
    }
  }

  bool get atEnd => pos >= bytes.length;
}

/// Reads a stamp; the result is a [DnsCheck] with [DnsCheck.stamp] or a problem.
DnsCheck parseDnsStamp(String input) {
  final text = input.trim();
  if (!text.startsWith(dnsStampPrefix)) return const DnsCheck.bad(DnsProblem.notStamp);
  List<int> raw;
  try {
    var body = text.substring(dnsStampPrefix.length).replaceAll('=', '');
    body += '=' * ((4 - body.length % 4) % 4);
    raw = base64Url.decode(body);
  } on FormatException {
    return const DnsCheck.bad(DnsProblem.damaged);
  }
  if (raw.isEmpty) return const DnsCheck.bad(DnsProblem.damaged);
  final kind = DnsKind.values.where((k) => k.code == raw[0]).firstOrNull;
  if (kind == null) return const DnsCheck.bad(DnsProblem.unsupported);

  final reader = _Reader(raw);
  var props = 0;
  if (kind != DnsKind.relay) {
    final propBytes = reader.take(8);
    for (var i = 0; i < propBytes.length; i++) {
      props |= propBytes[i] << (8 * i);
    }
  }
  final address = utf8.decode(reader.lp(), allowMalformed: true);
  var name = address;
  switch (kind) {
    case DnsKind.dnscrypt:
      final key = reader.lp();
      final provider = utf8.decode(reader.lp(), allowMalformed: true);
      if (!reader.failed && (key.length != 32 || provider.isEmpty || address.isEmpty)) {
        return const DnsCheck.bad(DnsProblem.damaged);
      }
      name = provider.replaceFirst('2.dnscrypt-cert.', '');
    case DnsKind.doh:
      reader.vlp();
      final host = utf8.decode(reader.lp(), allowMalformed: true);
      reader.lp(); // path
      if (!reader.failed && !reader.atEnd) reader.vlp(); // bootstrap addresses
      name = _hostOnly(host.isEmpty ? address : host);
    case DnsKind.dot:
    case DnsKind.doq:
      reader.vlp();
      final host = utf8.decode(reader.lp(), allowMalformed: true);
      if (!reader.failed && !reader.atEnd) reader.vlp();
      name = _hostOnly(host.isEmpty ? address : host);
    case DnsKind.plain:
    case DnsKind.relay:
      break;
  }
  if (reader.failed || !reader.atEnd) return const DnsCheck.bad(DnsProblem.damaged);
  return DnsCheck.ok(stamp: DnsStamp(kind: kind, props: props, address: address, name: name));
}

String _hostOnly(String hostPort) {
  if (hostPort.startsWith('[')) {
    final end = hostPort.indexOf(']');
    return end > 0 ? hostPort.substring(1, end) : hostPort;
  }
  final colon = hostPort.lastIndexOf(':');
  return colon > 0 && !hostPort.substring(0, colon).contains(':') ? hostPort.substring(0, colon) : hostPort;
}

/// Checks the resolver setting: a resolver URL or a stamp that names a resolver.
DnsCheck checkDnsSetting(String input) {
  final text = input.trim();
  if (text.startsWith(dnsStampPrefix)) {
    final check = parseDnsStamp(text);
    if (!check.ok) return check;
    if (check.stamp!.kind == DnsKind.relay) return const DnsCheck.bad(DnsProblem.relayAsResolver);
    return check;
  }
  // A bare IP is a UDP resolver; otherwise the scheme must be one the core speaks.
  final uri = Uri.tryParse(text.contains('://') ? text : 'udp://$text');
  if (uri == null ||
      !RegExp(r'^[0-9A-Za-z._:-]+$').hasMatch(uri.host) ||
      !{'https', 'tls', 'tcp', 'udp'}.contains(uri.scheme)) {
    return const DnsCheck.bad(DnsProblem.badUrl);
  }
  return DnsCheck.ok(name: uri.host);
}

/// Checks the relay setting: a relay stamp, or `ip:port`.
DnsCheck checkDnsRelay(String input) {
  final text = input.trim();
  if (text.startsWith(dnsStampPrefix)) {
    final check = parseDnsStamp(text);
    if (!check.ok) return check;
    return check.stamp!.kind == DnsKind.relay ? check : const DnsCheck.bad(DnsProblem.notRelay);
  }
  final match = RegExp(r'^(\[[0-9a-fA-F:.]+\]|[0-9a-zA-Z._-]+)(:\d{1,5})?$').firstMatch(text);
  return match == null ? const DnsCheck.bad(DnsProblem.notRelay) : DnsCheck.ok(name: match.group(1)!);
}

/// Whether [dns] is a DNSCrypt stamp (the only kind Anonymized DNSCrypt applies to).
bool isDnsCryptStamp(String dns) {
  final check = parseDnsStamp(dns);
  return check.ok && check.stamp!.kind == DnsKind.dnscrypt;
}

/// A short description of the resolver in use, e.g. `DNSCrypt · quad9.net`; with a relay it ends
/// in ` (anonymized)` ([anonymized] is the translated word). A plain URL setting is returned as it is.
String describeDns(String dns, [String relay = '', String anonymized = 'anonymized']) {
  final check = parseDnsStamp(dns);
  if (!check.ok) return dns;
  final stamp = check.stamp!;
  final anon = stamp.kind == DnsKind.dnscrypt && relay.trim().isNotEmpty;
  return '${stamp.kind.label} · ${stamp.name}${anon ? ' ($anonymized)' : ''}';
}

/// A resolver choice shown first in the DNS screen. The title of [isDefault] is translated by the
/// screen; the others are names of services and stay as they are.
class DnsPreset {
  const DnsPreset(this.id, this.title, this.dns, {this.isDefault = false});
  final String id;
  final String title;
  final String dns;
  final bool isDefault;
}

const dnsPresets = <DnsPreset>[
  DnsPreset('default', 'Cloudflare · HTTPS', 'https://1.1.1.1/dns-query', isDefault: true),
  DnsPreset('cloudflare-tls', 'Cloudflare · TLS', 'tls://1.1.1.1'),
  DnsPreset('quad9-https', 'Quad9 · HTTPS', 'https://9.9.9.9/dns-query'),
];

/// The bundled resolvers worth offering first: DNSCrypt, DNSSEC, no logs, no filtering. The list the
/// script writes is sorted by country; these are the ones shown.
List<DnsListEntry> get dnsCryptChoices => kDnsCryptResolvers;

/// The text before the first `-` or `.` of a list name, without the `anon-`/`doh-` marker: the operator.
String dnsOperatorOf(String name) {
  final bare = name.replaceFirst(RegExp(r'^(anon-|doh-)'), '').replaceFirst('dnscry.pt-anon-', 'dnscry-');
  // Numbered nodes (scaleway, scaleway2) belong to one operator.
  return bare.split(RegExp(r'[-.]')).first.toLowerCase().replaceAll(RegExp(r'\d+$'), '');
}

/// The relay to use with [resolver] when the person turns "Anonymized" on: from another operator
/// than the resolver (a relay run by the resolver's own operator hides nothing), and, if possible,
/// in another country. Null when the list has nothing suitable.
DnsListEntry? pickRelayFor(DnsListEntry resolver, [List<DnsListEntry> relays = kDnsRelays]) {
  final op = dnsOperatorOf(resolver.name);
  final other = [for (final r in relays) if (dnsOperatorOf(r.name) != op) r];
  if (other.isEmpty) return null;
  return other.where((r) => r.country.isNotEmpty && r.country != resolver.country).firstOrNull ?? other.first;
}

/// The list entry whose stamp is [stamp], or null.
DnsListEntry? dnsEntryForStamp(String stamp, [List<DnsListEntry> list = kDnsCryptResolvers]) =>
    list.where((e) => e.stamp == stamp.trim()).firstOrNull;

/// The relay entry for the stored relay setting, or null (custom).
DnsListEntry? dnsRelayEntry(String relay) => dnsEntryForStamp(relay, kDnsRelays);

/// Whether the tunnel's resolver setting is the app default.
bool isDefaultDns(String dns) => dns.trim().isEmpty || dns.trim() == dnsPresets.first.dns;
