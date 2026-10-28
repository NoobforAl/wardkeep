import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'country_zones.dart';
import 'ipdb_state.dart';
import 'providers.dart';

/// The address ranges of the countries the user chose to bypass the VPN, one block per line, ready to
/// be added to the bypass lists sent to the core. A country's ranges come from the offline country
/// database when it is installed (exact, nothing to download), otherwise from the small list downloaded
/// for that country; a country with neither yet adds nothing. A big country is tens of thousands of
/// lines, so this is worked out once per change, not per connection.
final bypassCountryTextProvider = Provider<String>((ref) {
  final codes = ref.watch(settingsProvider.select((s) => s.bypassCountries));
  if (codes.isEmpty) return '';
  final db = ref.watch(ipDbProvider.select((s) => s.db));
  final zones = ref.watch(countryZonesProvider);
  final lines = <String>[];
  for (final code in codes) {
    if (db != null) {
      lines.addAll(db.cidrsOf(code));
    } else {
      final zone = zones[code.toUpperCase()];
      if (zone != null && zone.status == ZoneStatus.ready) lines.addAll(zone.lines);
    }
  }
  return lines.join('\n');
});

/// How many ranges each country has (what the picker shows): from the installed database, else from the
/// lists downloaded so far.
final countryRangeCountsProvider = Provider<Map<String, int>>((ref) {
  final db = ref.watch(ipDbProvider.select((s) => s.db));
  if (db != null) return db.rangeCounts();
  return {
    for (final e in ref.watch(countryZonesProvider).entries)
      if (e.value.status == ZoneStatus.ready) e.key: e.value.lines.length,
  };
});
