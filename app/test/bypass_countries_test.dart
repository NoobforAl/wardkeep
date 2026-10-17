import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/bypass_countries.dart';
import 'package:omnitun/state/ipdb.dart';
import 'package:omnitun/state/ipdb_state.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/bypass_countries_screen.dart';
import 'package:omnitun/ui/theme.dart';

/// The database controller with a database already installed (the real one reads it from disk
/// on its own schedule, which a test cannot wait for under fake time).
class _FixedDb extends IpDbController {
  _FixedDb(this.db);

  final IpCountryDb? db;

  @override
  IpDbState build() => IpDbState(phase: db == null ? IpDbPhase.none : IpDbPhase.ready, db: db);
}

Future<IpCountryDb> _build(Directory dir, String v4, String v6) async {
  File('${dir.path}/v4.csv').writeAsStringSync(v4);
  File('${dir.path}/v6.csv').writeAsStringSync(v6);
  await compileIpDb('${dir.path}/v4.csv', '${dir.path}/v6.csv', '${dir.path}/ipcountry.bin');
  return IpCountryDb.fromBytes(File('${dir.path}/ipcountry.bin').readAsBytesSync());
}

int _ip4(String s) => s.split('.').fold(0, (v, p) => (v << 8) | int.parse(p));

String _dotted(int a) => '${a >> 24 & 255}.${a >> 16 & 255}.${a >> 8 & 255}.${a & 255}';

/// Every address of a list of IPv4 blocks.
Set<int> _expand(List<String> cidrs) {
  final out = <int>{};
  for (final c in cidrs) {
    final parts = c.split('/');
    final start = _ip4(parts[0]), bits = int.parse(parts[1]);
    final size = 1 << (32 - bits);
    expect(start % size, 0, reason: '$c is not aligned');
    for (var i = 0; i < size; i++) {
      out.add(start + i);
    }
  }
  return out;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('bypass_countries'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps a file open a moment longer; the temp folder is cleaned up later.
    }
  });

  test('a country is turned into the smallest list of blocks that covers it exactly', () async {
    final db = await _build(
      tmp,
      '1.0.0.0,1.255.255.255,AA\n'
      '10.0.0.5,10.0.0.12,AA\n'
      '10.0.0.13,10.0.0.13,BB\n'
      '203.0.113.0,203.0.113.255,AA\n',
      '2001:db8::,2001:db8:0:ff:ffff:ffff:ffff:ffff,AA\n2a07:d880::,2a07:d883:ffff:ffff:ffff:ffff:ffff:ffff,BB\n',
    );
    final aa = db.cidrsOf('AA');
    expect(aa, contains('1.0.0.0/8'));
    expect(aa, contains('203.0.113.0/24'));
    // 10.0.0.5-12 is not aligned: 5/32, 6/31, 8/30, 12/32.
    expect(aa.where((c) => c.startsWith('10.0.0.')).toList(), ['10.0.0.5/32', '10.0.0.6/31', '10.0.0.8/30', '10.0.0.12/32']);
    expect(aa, contains('2001:db8::/56'), reason: '256 consecutive /64 blocks are one /56');
    expect(db.cidrsOf('BB'), containsAll(['10.0.0.13/32', '2a07:d880::/30']));
    expect(db.cidrsOf('ZZ'), isEmpty);
    expect(db.cidrsOf('x'), isEmpty);
    expect(db.cidrsOf('aa'), aa, reason: 'the code is not case sensitive');
    expect(db.rangeCounts(), {'AA': 4, 'BB': 2});
  });

  test('the blocks cover the country exactly: every address of them is the country\'s, and none is missed', () async {
    // Random ranges for two countries inside 100.64.0.0/20, so that every address can be checked.
    final rng = math.Random(42);
    final base = _ip4('100.64.0.0');
    final rows = <String>[];
    var at = 0;
    final owner = <int, String>{};
    while (at < 4096) {
      final len = 1 + rng.nextInt(300);
      final end = math.min(at + len - 1, 4095);
      final cc = rng.nextBool() ? 'AA' : 'BB';
      // A gap now and then: nobody's.
      if (rng.nextInt(5) != 0) {
        rows.add('${_dotted(base + at)},${_dotted(base + end)},$cc');
        for (var a = at; a <= end; a++) {
          owner[base + a] = cc;
        }
      }
      at = end + 1;
    }
    final db = await _build(tmp, '${rows.join('\n')}\n', '');
    for (final cc in ['AA', 'BB']) {
      final covered = _expand(db.cidrsOf(cc));
      final want = {for (final e in owner.entries) if (e.value == cc) e.key};
      expect(covered.length, want.length, reason: '$cc: the blocks cover a different number of addresses');
      expect(covered.containsAll(want), isTrue, reason: '$cc: an address is missing');
    }
  });

  testWidgets('chosen countries become lines for the core, only while the database is installed', (tester) async {
    final db = await tester.runAsync(() => _build(tmp, '1.0.0.0,1.0.0.255,AA\n203.0.113.0,203.0.113.255,BB\n', ''));
    ProviderContainer container(IpCountryDb? withDb, List<String> chosen) => ProviderContainer(overrides: [
      storeProvider.overrideWithValue(AppStore.memory({'settings': {'bypass_countries': chosen, 'show_exit': false}})),
      engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
      ipDbProvider.overrideWith(() => _FixedDb(withDb)),
    ]);

    final without = container(null, ['AA']);
    addTearDown(without.dispose);
    expect(without.read(bypassCountryTextProvider), '', reason: 'no database: nothing to add');
    expect(without.read(countryRangeCountsProvider), isEmpty);

    final c = container(db, ['AA']);
    addTearDown(c.dispose);
    expect(c.read(bypassCountryTextProvider), '1.0.0.0/24');
    expect(c.read(countryRangeCountsProvider), {'AA': 1, 'BB': 1});

    c.read(settingsProvider.notifier).update((s) => s.copyWith(bypassCountries: ['AA', 'BB']));
    expect(c.read(bypassCountryTextProvider).split('\n'), ['1.0.0.0/24', '203.0.113.0/24']);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(bypassCountries: []));
    expect(c.read(bypassCountryTextProvider), '');
    expect(c.read(storeProvider).read<Map<String, dynamic>>('settings')!['bypass_countries'], isEmpty);
    await tester.pump(const Duration(seconds: 1)); // the store writes after a short delay
  });

  testWidgets('the picker lists the countries of the database, toggles one and saves it; without it every country is offered',
      (tester) async {
    final db = await tester.runAsync(() => _build(tmp, '1.0.0.0,1.0.0.255,AU\n203.0.113.0,203.0.113.255,DE\n', ''));
    Future<ProviderContainer> show(IpCountryDb? withDb) async {
      final c = ProviderContainer(overrides: [
        storeProvider.overrideWithValue(AppStore.memory({'settings': {'show_exit': false}})),
        engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
        ipDbProvider.overrideWith(() => _FixedDb(withDb)),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BypassCountriesScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    var c = await show(db);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('France'), findsNothing, reason: 'a country with no ranges is not offered');
    await tester.tap(find.text('Germany'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).bypassCountries, ['DE']);
    await tester.tap(find.text('Germany'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).bypassCountries, isEmpty);
    await tester.enterText(find.byType(TextField), 'austr');
    await tester.pumpAndSettle();
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('Germany'), findsNothing);

    // Without the database every country is offered (each downloads its own small list), and the
    // database is offered as the more exact option.
    c = await show(null);
    expect(find.textContaining('a few kilobytes'), findsOneWidget);
    expect(find.text('Get the country database'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'franc');
    await tester.pumpAndSettle();
    expect(find.text('France'), findsOneWidget, reason: 'a country with no ranges in any database is still offered');
  });
}
