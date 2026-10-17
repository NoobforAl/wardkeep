import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where to get a country's address ranges, one small list per address family, from the first of
/// several places that answers: IPdeny's aggregated country zones, then ipverse's, through jsDelivr
/// (which is often reachable where the first is not). [cc] is the lower-case two-letter code.
List<List<String>> defaultZoneUrls(String cc) => [
  [
    'https://www.ipdeny.com/ipblocks/data/aggregated/$cc-aggregated.zone',
    'https://cdn.jsdelivr.net/gh/ipverse/country-ip-blocks@master/country/$cc/ipv4-aggregated.txt',
  ],
  [
    'https://www.ipdeny.com/ipv6/ipaddresses/blocks/$cc.zone',
    'https://cdn.jsdelivr.net/gh/ipverse/country-ip-blocks@master/country/$cc/ipv6-aggregated.txt',
  ],
];

final _cidr = RegExp(r'^(?:\d{1,3}(?:\.\d{1,3}){3}/\d{1,2}|[0-9a-fA-F:]+:[0-9a-fA-F:]*/\d{1,3})$');

/// The CIDR blocks in a downloaded list: one per line, anything after `#` and blank lines ignored, a line
/// that is not a block dropped. A country's list is a few kilobytes; a hostile or wrong answer is refused.
List<String> parseZone(String text) {
  final out = <String>[];
  for (var line in const LineSplitter().convert(text)) {
    final i = line.indexOf('#');
    if (i >= 0) line = line.substring(0, i);
    line = line.trim();
    if (_cidr.hasMatch(line)) out.add(line);
  }
  return out;
}

/// Downloads a country's list: IPv4 is required, IPv6 is added when there is one.
class CountryZonesDownloader {
  CountryZonesDownloader({this.urls = defaultZoneUrls, this.timeout = const Duration(seconds: 20)});

  final List<List<String>> Function(String cc) urls;
  final Duration timeout;

  /// 5 MB is more than the biggest country's list (the United States, about 0.5 MB).
  static const maxBytes = 5 * 1024 * 1024;

  Future<List<String>> fetch(String cc) async {
    final code = cc.toLowerCase();
    if (!RegExp(r'^[a-z]{2}$').hasMatch(code)) throw ArgumentError('not a country code: $cc');
    final lists = urls(code);
    final v4 = await _firstAnswer(lists[0]);
    if (v4 == null || v4.isEmpty) throw const HttpException('no address list for this country');
    final v6 = lists.length > 1 ? await _firstAnswer(lists[1]) : null;
    return [...v4, ...?v6];
  }

  Future<List<String>?> _firstAnswer(List<String> places) async {
    for (final url in places) {
      final client = HttpClient()..connectionTimeout = timeout;
      try {
        final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
        request.headers.set('accept-encoding', 'identity');
        final response = await request.close().timeout(timeout);
        if (response.statusCode != 200) continue;
        final bytes = <int>[];
        await for (final chunk in response.timeout(timeout)) {
          bytes.addAll(chunk);
          if (bytes.length > maxBytes) throw const HttpException('the list is too big');
        }
        final lines = parseZone(utf8.decode(bytes, allowMalformed: true));
        if (lines.isNotEmpty) return lines;
      } catch (_) {
        // try the next place
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }
}

/// How one country's list is doing.
enum ZoneStatus { loading, ready, failed }

class ZoneState {
  const ZoneState(this.status, {this.lines = const []});

  final ZoneStatus status;
  final List<String> lines;
}

/// Where the lists are kept (overridden in tests).
final countryZonesDirProvider = Provider<Future<Directory> Function()>((ref) {
  return () async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}country_zones');
  };
});

final countryZonesDownloaderProvider = Provider<CountryZonesDownloader>((ref) => CountryZonesDownloader());

/// The downloaded lists, by country code: read from disk once, fetched one country at a time on request,
/// and kept for the next start.
class CountryZonesController extends Notifier<Map<String, ZoneState>> {
  @override
  Map<String, ZoneState> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<File> _file(String cc) async {
    final dir = await ref.read(countryZonesDirProvider)();
    return File('${dir.path}${Platform.pathSeparator}${cc.toUpperCase()}.txt');
  }

  Future<void> _load() async {
    try {
      final dir = await ref.read(countryZonesDirProvider)();
      if (!await dir.exists()) return;
      final found = <String, ZoneState>{};
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.txt')) continue;
        final name = e.uri.pathSegments.last;
        final cc = name.substring(0, name.length - 4).toUpperCase();
        if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) continue;
        final lines = parseZone(await e.readAsString());
        if (lines.isNotEmpty) found[cc] = ZoneState(ZoneStatus.ready, lines: lines);
      }
      if (!ref.mounted) return;
      state = {...found, ...state}; // what was fetched meanwhile wins
    } catch (_) {
      // no place to keep lists: they are fetched again each start
    }
  }

  /// Makes sure [cc] has its list: nothing to do when it has, otherwise it is downloaded (and tried
  /// again by calling this again after a failure).
  Future<void> ensure(String cc) async {
    cc = cc.toUpperCase();
    final now = state[cc];
    if (now != null && (now.status == ZoneStatus.ready || now.status == ZoneStatus.loading)) return;
    state = {...state, cc: const ZoneState(ZoneStatus.loading)};
    try {
      final lines = await ref.read(countryZonesDownloaderProvider).fetch(cc);
      if (!ref.mounted) return;
      state = {...state, cc: ZoneState(ZoneStatus.ready, lines: lines)};
      try {
        final f = await _file(cc);
        await f.parent.create(recursive: true);
        await f.writeAsString('${lines.join('\n')}\n');
      } catch (_) {
        // kept for this run only
      }
    } catch (_) {
      if (ref.mounted) state = {...state, cc: const ZoneState(ZoneStatus.failed)};
    }
  }
}

final countryZonesProvider = NotifierProvider<CountryZonesController, Map<String, ZoneState>>(CountryZonesController.new);
