import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';

Map<String, dynamic> _data(String protocol) => {
  'onboarded': true,
  'profiles': [
    {'id': 'a', 'name': 'My profile', 'protocol': protocol, 'server': '203.0.113.9', 'port': 443},
  ],
};

Future<MockEngine> _connect(WidgetTester tester, String protocol, List<TorHop> path) async {
  final engine = MockEngine(connectDelay: Duration.zero)..torPath = path;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(AppStore.memory(_data(protocol))), engineProvider.overrideWithValue(engine)],
      child: const OmnitunApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Connect'));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return engine;
}

/// Ends the test cleanly: the mock engine's traffic timer must not outlive it.
Future<void> _finish(WidgetTester tester, MockEngine engine) async {
  await tester.pumpWidget(const SizedBox());
  final done = engine.disconnect();
  await tester.pump(const Duration(milliseconds: 400));
  await done;
}

void main() {
  testWidgets('a Tor circuit shows its three relays, each with its role and country', (tester) async {
    final engine = await _connect(tester, 'tor', const [
      TorHop(role: 'bridge', country: 'DE'),
      TorHop(role: 'middle', country: 'SE'),
      TorHop(role: 'exit', country: 'NL'),
    ]);
    expect(find.text('Bridge'), findsOneWidget);
    expect(find.text('Relay'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('Sweden'), findsOneWidget);
    expect(find.text('Netherlands'), findsOneWidget);
    await _finish(tester, engine);
  });

  testWidgets('a relay whose country is not known says so, and a guard is called Entry', (tester) async {
    final engine = await _connect(tester, 'tor', const [
      TorHop(role: 'guard'),
      TorHop(role: 'middle', country: 'FR'),
      TorHop(role: 'exit', country: 'CH'),
    ]);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
    expect(find.text('Switzerland'), findsOneWidget);
    await _finish(tester, engine);
  });

  testWidgets('a bridge behind Snowflake is hidden, not unknown, and touching a relay says what it knows', (tester) async {
    final engine = await _connect(tester, 'tor', const [
      TorHop(role: 'bridge'),
      TorHop(role: 'middle', country: 'LT'),
      TorHop(role: 'exit', country: 'NL'),
    ]);
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);

    await tester.tap(find.text('Bridge'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hides from your network that you use Tor'), findsOneWidget);
    expect(find.textContaining('cannot be shown on the map'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // the barrier closes the sheet
    await tester.pumpAndSettle();
    expect(find.textContaining('hides from your network'), findsNothing);

    await tester.tap(find.text('Lithuania'));
    await tester.pumpAndSettle();
    expect(find.textContaining('knows neither who you are nor what you visit'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Netherlands'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sees where you go, but not who you are'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _finish(tester, engine);
  });

  testWidgets('no circuit is shown for a profile that is not Tor, or before Tor reports one', (tester) async {
    final engine = await _connect(tester, 'trojan', const [TorHop(role: 'exit', country: 'NL')]);
    expect(find.text('Relay'), findsNothing);
    expect(find.text('Netherlands'), findsNothing);
    await _finish(tester, engine);
  });
}
