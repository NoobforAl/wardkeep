import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ipdb_state.dart';
import 'providers.dart';

/// The address ranges of the countries the user chose to bypass the VPN, one block per line, ready to
/// be added to the bypass lists sent to the core. Empty when no country is chosen or the offline
/// country database (where the ranges come from) is not installed. A big country is tens of
/// thousands of lines, so this is worked out once per change, not per connection.
final bypassCountryTextProvider = Provider<String>((ref) {
  final codes = ref.watch(settingsProvider.select((s) => s.bypassCountries));
  final db = ref.watch(ipDbProvider.select((s) => s.db));
  if (codes.isEmpty || db == null) return '';
  return [for (final c in codes) ...db.cidrsOf(c)].join('\n');
});

/// How many ranges the installed database has per country (empty without it): what the picker shows.
final countryRangeCountsProvider = Provider<Map<String, int>>((ref) {
  final db = ref.watch(ipDbProvider.select((s) => s.db));
  return db?.rangeCounts() ?? const {};
});
