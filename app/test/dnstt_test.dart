import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/countries.dart';
import 'package:omnitun/state/location.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/theme.dart';

/// A mock whose forms include the DNS tunnel editor, the way the core sends it.
class _TunnelEngine extends MockEngine {
  Object? scanError;
  int scans = 0;
  String? scannedDomain, scannedKey;

  @override
  Future<List<ProtocolFormSpec>> forms() async => const [
    ProtocolFormSpec(
      protocol: 'dnstt',
      label: 'DNS tunnel',
      warnings: [WarningSpec(code: 'DNSTT_SLOW', text: 'Slow.')],
      fields: [
        FormFieldSpec(key: 'name', label: 'Name', kind: 'text'),
        FormFieldSpec(key: 'dnstt.domain', label: 'Tunnel domain', kind: 'text', required: true),
        FormFieldSpec(key: 'dnstt.pubkey', label: 'Server key', kind: 'text', required: true),
        FormFieldSpec(
          key: 'dnstt.resolvers',
          label: 'Resolvers',
          kind: 'list',
          defaultValue: 'udp://8.8.8.8:53, udp://1.1.1.1:53',
        ),
        FormFieldSpec(key: 'username', label: 'Username', kind: 'text'),
        FormFieldSpec(key: 'password', label: 'Password', kind: 'secret'),
      ],
    ),
  ];

  @override
  Future<List<ResolverScanResult>> scanResolvers({
    required String domain,
    required String pubKey,
    List<String> resolvers = const [],
  }) async {
    scans++;
    scannedDomain = domain;
    scannedKey = pubKey;
    if (scanError != null) throw scanError!;
    return scan;
  }
}

Future<ProviderContainer> _start(WidgetTester tester, _TunnelEngine engine) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(
          AppStore.memory({
            'profiles': [
              {'id': 'x', 'name': 'Old', 'protocol': 'trojan', 'server': 'old.example.com', 'port': 443},
            ],
          }),
        ),
        engineProvider.overrideWithValue(engine),
      ],
      child: const OmnitunApp(),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(OmnitunApp)));
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Location'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Add servers'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add a server by hand'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('DNS tunnel'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the DNS tunnel editor finds working resolvers and puts the fastest in the field', (tester) async {
    final engine = _TunnelEngine();
    await _start(tester, engine);
    await _openEditor(tester);

    // The editor starts with the core's default resolvers, and warns that the tunnel is slow.
    expect(find.widgetWithText(TextField, 'udp://8.8.8.8:53, udp://1.1.1.1:53'), findsOneWidget);
    expect(find.byKey(const Key('warning-DNSTT_SLOW')), findsOneWidget);

    // Without the domain and the key there is nothing to test.
    await tester.tap(find.byKey(const Key('scan-resolvers')));
    await tester.pumpAndSettle();
    expect(find.text('Fill in the tunnel domain and the server key first.'), findsOneWidget);
    expect(engine.scans, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Tunnel domain *'), 't.example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Server key *'), 'ab' * 32);
    await tester.tap(find.byKey(const Key('scan-resolvers')));
    await tester.pumpAndSettle();
    expect(engine.scans, 1);
    expect(engine.scannedDomain, 't.example.com');
    expect(engine.scannedKey, 'ab' * 32);
    expect(find.text('Working resolvers found: 2'), findsOneWidget);
    // Only the ones that worked, in the order the core gave them (fastest first).
    expect(find.widgetWithText(TextField, 'udp://1.1.1.1:53, https://dns.google/dns-query'), findsOneWidget);

    // Nothing works: the field is left alone and the message says what to check.
    engine.scan = const [ResolverScanResult(resolver: 'udp://1.1.1.1:53', error: 'timeout')];
    await tester.tap(find.byKey(const Key('scan-resolvers')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No resolver worked'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'udp://1.1.1.1:53, https://dns.google/dns-query'), findsOneWidget);

    // While the VPN is on the core refuses, and the message is in the user's language.
    engine.scanError = EngineException('SCAN_CONNECTED', 'disconnect first');
    await tester.tap(find.byKey(const Key('scan-resolvers')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Disconnect first: the scan has to use the network directly'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('a DNS tunnel is chosen by hand, like Tor: not by Automatic, and no country is guessed for it', () {
    final trojan = ProfileInfo.fromJson({'id': 'a', 'name': 'DE one', 'protocol': 'trojan', 'server': 'a.example', 'port': 443});
    final tunnel = ProfileInfo.fromJson({'id': 'd', 'name': 'DE tunnel', 'protocol': 'dnstt', 'server': 't.example.com', 'port': 53});
    expect(planConnection([tunnel, trojan], null, (_) => null)!.primary.id, 'a');
    expect(planConnection([tunnel, trojan], null, (_) => null)!.fallbacks.map((p) => p.id), isNot(contains('d')));
    expect(planConnection([tunnel, trojan], 'd', (_) => null)!.primary.id, 'd'); // when the user picks it
    expect(guessCountry(tunnel), isNull); // the name says DE, but a tunnel is reached by its zone, not a place
    expect(protocolBadge('dnstt'), 'DNS');
    expect(tunnel.address, 't.example.com:53');
  });

  test('the scan result reads what the core sends', () {
    final ok = ResolverScanResult.fromJson({'resolver': 'udp://1.1.1.1:53', 'ms': 120});
    final bad = ResolverScanResult.fromJson({'resolver': 'udp://8.8.8.8:53', 'error': 'timeout'});
    expect(ok.works, isTrue);
    expect(bad.works, isFalse);
    expect(bad.error, 'timeout');
  });
}
