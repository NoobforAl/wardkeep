import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/bypass_countries.dart';
import 'package:omnitun/state/country_zones.dart';
import 'package:omnitun/state/ipdb_state.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/bypass_countries_screen.dart';
import 'package:omnitun/ui/theme.dart';

/// A little web server that answers like the sources of the country lists.
class _Sources {
  final answers = <String, String>{}; // path -> body; a path that is not here is a 404
  final hits = <String>[];
  late final HttpServer server;
  var bigBody = false;

  Future<void> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      hits.add(req.uri.path);
      final body = bigBody ? 'x' * (6 * 1024 * 1024) : answers[req.uri.path];
      if (body == null) {
        req.response.statusCode = 404;
      } else {
        req.response.write(body);
      }
      await req.response.close();
    });
  }

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  /// For the downloader: two places per family, the first one under /a, the second under /b.
  List<List<String>> Function(String) get urls => (cc) => [
    [url('/a/v4/$cc'), url('/b/v4/$cc')],
    [url('/a/v6/$cc'), url('/b/v6/$cc')],
  ];
}

void main() {
  late _Sources src;
  late Directory tmp;
  // The test binding answers every HTTP request itself; these tests talk to a real local server.
  setUpAll(() => HttpOverrides.global = null);
  setUp(() async {
    src = _Sources();
    await src.start();
    tmp = Directory.systemTemp.createTempSync('country_zones');
  });
  tearDown(() async {
    await src.server.close(force: true);
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps a file open a moment longer
    }
  });

  group('the list of a country', () {
    test('only blocks are taken from a downloaded text; comments and rubbish are dropped', () {
      expect(
        parseZone('# Country: Iran\n2.57.3.0/24\n\n  5.160.0.0/20  # a comment\nnot a block\n2001:790::/32\n1.2.3.4\n<html>\n'),
        ['2.57.3.0/24', '5.160.0.0/20', '2001:790::/32'],
      );
      expect(parseZone(''), isEmpty);
    });

    test('IPv4 and IPv6 are both fetched; a country with no IPv6 list still works', () async {
      src.answers['/a/v4/ir'] = '2.57.3.0/24\n5.160.0.0/20\n';
      src.answers['/a/v6/ir'] = '2001:790::/32\n';
      final d = CountryZonesDownloader(urls: src.urls);
      expect(await d.fetch('IR'), ['2.57.3.0/24', '5.160.0.0/20', '2001:790::/32']);
      src.answers.remove('/a/v6/ir');
      expect(await d.fetch('ir'), ['2.57.3.0/24', '5.160.0.0/20'], reason: 'no IPv6 list for it');
    });

    test('the second place is used when the first does not answer', () async {
      src.answers['/b/v4/de'] = '3.0.0.0/15\n';
      src.answers['/b/v6/de'] = '2a00:1450::/32\n';
      expect(await CountryZonesDownloader(urls: src.urls).fetch('de'), ['3.0.0.0/15', '2a00:1450::/32']);
      expect(src.hits, containsAllInOrder(['/a/v4/de', '/b/v4/de']));
    });

    test('no IPv4 list anywhere is a failure, and so is an answer that is not a list or is too big', () async {
      final d = CountryZonesDownloader(urls: src.urls, timeout: const Duration(seconds: 5));
      await expectLater(d.fetch('ir'), throwsA(isA<HttpException>()));
      src.answers['/a/v4/ir'] = '<html>not a list</html>';
      await expectLater(d.fetch('ir'), throwsA(isA<HttpException>()));
      src.bigBody = true;
      await expectLater(d.fetch('ir'), throwsA(isA<HttpException>()));
      await expectLater(d.fetch('../etc'), throwsA(isA<ArgumentError>()), reason: 'a code is two letters');
    });
  });

  ProviderContainer container({Map<String, Object?> settings = const {}, bool failFirst = false}) {
    final c = ProviderContainer(overrides: [
      storeProvider.overrideWithValue(AppStore.memory({'settings': {'show_exit': false, ...settings}})),
      engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
      ipDbProvider.overrideWith(() => _NoDb()),
      countryZonesDirProvider.overrideWithValue(() async => Directory('${tmp.path}/zones')),
      countryZonesDownloaderProvider.overrideWithValue(CountryZonesDownloader(urls: src.urls, timeout: const Duration(seconds: 5))),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a ticked country is downloaded once, kept on disk, and found again at the next start', () async {
    src.answers['/a/v4/ir'] = '2.57.3.0/24\n5.160.0.0/20\n';
    final c = container(settings: {'bypass_countries': ['IR']});
    c.listen(countryZonesProvider, (_, _) {});
    expect(c.read(bypassCountryTextProvider), '', reason: 'nothing downloaded yet');
    await c.read(countryZonesProvider.notifier).ensure('ir');
    await c.read(countryZonesProvider.notifier).ensure('IR');
    expect(src.hits.where((h) => h == '/a/v4/ir'), hasLength(1), reason: 'not fetched twice');
    expect(c.read(countryZonesProvider)['IR']!.status, ZoneStatus.ready);
    expect(c.read(bypassCountryTextProvider).split('\n'), ['2.57.3.0/24', '5.160.0.0/20']);
    expect(c.read(countryRangeCountsProvider), {'IR': 2});
    expect(File('${tmp.path}/zones/IR.txt').existsSync(), isTrue);

    // A later start: the list comes from the disk, with no download.
    src.hits.clear();
    final again = container(settings: {'bypass_countries': ['IR']});
    again.listen(countryZonesProvider, (_, _) {});
    for (var i = 0; i < 50 && again.read(countryZonesProvider).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    expect(again.read(bypassCountryTextProvider).split('\n'), ['2.57.3.0/24', '5.160.0.0/20']);
    expect(src.hits, isEmpty);
  });

  test('a failed download is shown as failed, adds nothing to the bypass, and works when tried again', () async {
    final c = container(settings: {'bypass_countries': ['IR']});
    c.listen(countryZonesProvider, (_, _) {});
    await c.read(countryZonesProvider.notifier).ensure('IR');
    expect(c.read(countryZonesProvider)['IR']!.status, ZoneStatus.failed);
    expect(c.read(bypassCountryTextProvider), '');
    src.answers['/a/v4/ir'] = '2.57.3.0/24\n';
    await c.read(countryZonesProvider.notifier).ensure('IR');
    expect(c.read(countryZonesProvider)['IR']!.status, ZoneStatus.ready);
    expect(c.read(bypassCountryTextProvider), '2.57.3.0/24');
  });

  group('the picker without the database', () {
    late _FakeDownloader fake;
    Future<ProviderContainer> show(WidgetTester tester, {Map<String, Object?> store = const {}}) async {
      fake = _FakeDownloader();
      final c = ProviderContainer(overrides: [
        storeProvider.overrideWithValue(AppStore.memory({
          'settings': {'show_exit': false},
          'profiles': [
            {'id': 's', 'name': 'Berlin', 'protocol': 'trojan', 'server': 'de1.example.com', 'port': 443, 'password': 'pw', 'country': 'DE'},
          ],
          'selected': 's',
          ...store,
        })),
        engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
        ipDbProvider.overrideWith(() => _NoDb()),
        countryZonesDirProvider.overrideWithValue(() async => Directory('${tmp.path}/zones')),
        countryZonesDownloaderProvider.overrideWithValue(fake),
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

    testWidgets('every country is offered; ticking one downloads its list, and the range count appears', (tester) async {
      src.answers['/a/v4/ir'] = '2.57.3.0/24\n5.160.0.0/20\n';
      final c = await show(tester);
      fake.lists['IR'] = ['2.57.3.0/24', '5.160.0.0/20'];
      expect(find.textContaining('a few kilobytes'), findsOneWidget, reason: 'the banner says how it works');
      expect(find.text('Get the country database'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'iran');
      await tester.pumpAndSettle();
      expect(find.text('Iran'), findsOneWidget);
      await tester.tap(find.text('Iran'));
      await tester.pump(const Duration(milliseconds: 100)); // the fake download, in fake time
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // the file it is kept in
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).bypassCountries, ['IR']);
      expect(find.text('2 addresses or ranges'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // the store writes after a short delay
    });

    testWidgets('a country whose list fails says so, and a tap on it tries again', (tester) async {
      final c = await show(tester);
      await tester.enterText(find.byType(TextField), 'iran');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iran'));
      await tester.pump(const Duration(milliseconds: 100)); // the fake download, in fake time
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // the file it is kept in
      await tester.pumpAndSettle();
      expect(find.text('Could not download. Tap to try again.'), findsOneWidget);
      fake.lists['IR'] = ['2.57.3.0/24'];
      await tester.tap(find.text('Iran'));
      await tester.pump(const Duration(milliseconds: 100)); // the fake download, in fake time
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // the file it is kept in
      await tester.pumpAndSettle();
      expect(find.text('1 address or range'), findsOneWidget);
      expect(c.read(settingsProvider).bypassCountries, ['IR'], reason: 'the retry did not untick it');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ticking the country of the selected server says that its traffic would skip the VPN too', (tester) async {
      await show(tester);
      fake.lists['DE'] = ['3.0.0.0/15'];
      await tester.enterText(find.byType(TextField), 'germany');
      await tester.pumpAndSettle();
      expect(find.textContaining('Your selected server is here'), findsNothing);
      await tester.tap(find.text('Germany'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your selected server is here'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// A downloader that answers from a table, so the screen tests need no network.
class _FakeDownloader extends CountryZonesDownloader {
  final lists = <String, List<String>>{};

  @override
  Future<List<String>> fetch(String cc) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return lists[cc.toUpperCase()] ?? (throw const HttpException('no list'));
  }
}

/// The database controller with nothing installed (the real one looks at the disk on its own schedule).
class _NoDb extends IpDbController {
  @override
  IpDbState build() => const IpDbState();
}
