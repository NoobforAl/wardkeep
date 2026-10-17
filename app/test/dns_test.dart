import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/daemon_engine.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/l10n.dart';
import 'package:omnitun/state/dns_resolvers.dart';
import 'package:omnitun/state/dns_state.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/dns_screen.dart';

// Stamps from the public resolver and relay lists; the Go tests (core/dnscrypt) use the same ones.
const quad9 =
    'sdns://AQcAAAAAAAAADTkuOS45LjEwOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA';
const scaleway =
    'sdns://AQcAAAAAAAAADjIxMi40Ny4yMjguMTM2IOgBuE6mBr-wusDOQ0RbsV66ZLAvo8SqMa4QY2oHkDJNHzIuZG5zY3J5cHQtY2VydC5mci5kbnNjcnlwdC5vcmc';
const cloudflareDoh = 'sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5';
const relayBerlin = 'sdns://gREzNy4xMjAuMjE3Ljc1OjQ0Mw';

final _profile = ProfileInfo.fromJson({
  'id': 'p1',
  'name': 'p',
  'protocol': 'trojan',
  'server': 'example.com',
  'port': 443,
});

ProviderContainer _container() => ProviderContainer(overrides: [
      storeProvider.overrideWithValue(AppStore.memory({})),
      engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
    ]);

Widget _app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  group('reading stamps', () {
    test('a DNSCrypt stamp: kind, provider, address, properties', () {
      final c = parseDnsStamp(quad9);
      expect(c.ok, isTrue);
      final st = c.stamp!;
      expect(st.kind, DnsKind.dnscrypt);
      expect(st.name, 'quad9.net');
      expect(st.address, '9.9.9.10:8443');
      expect(st.props, 7, reason: 'DNSSEC, no logs, no filtering');
      expect(parseDnsStamp(scaleway).stamp!.name, 'fr.dnscrypt.org');
    });

    test('DoH and relay stamps', () {
      final doh = parseDnsStamp(cloudflareDoh).stamp!;
      expect(doh.kind, DnsKind.doh);
      expect(doh.name, 'dns.cloudflare.com');
      expect(doh.address, '1.0.0.1');
      final relay = parseDnsStamp(relayBerlin).stamp!;
      expect(relay.kind, DnsKind.relay);
      expect(relay.address, '37.120.217.75:443');
    });

    test('a stamp is accepted with spaces around it and with base64 padding', () {
      expect(parseDnsStamp('  $quad9  \n').ok, isTrue);
      expect(parseDnsStamp('$quad9==').ok, isTrue);
    });

    test('each way a stamp can be wrong has its own problem', () {
      expect(parseDnsStamp('https://1.1.1.1/dns-query').problem, DnsProblem.notStamp);
      expect(parseDnsStamp('').problem, DnsProblem.notStamp);
      expect(parseDnsStamp('sdns://').problem, DnsProblem.damaged);
      expect(parseDnsStamp('sdns://!!!').problem, DnsProblem.damaged);
      expect(parseDnsStamp(quad9.substring(0, quad9.length - 30)).problem, DnsProblem.damaged, reason: 'cut short');
      expect(parseDnsStamp('${quad9}AAAA').problem, DnsProblem.damaged, reason: 'extra data');
      expect(parseDnsStamp('sdns://BQcAAAAAAAAAAAA').problem, DnsProblem.unsupported, reason: 'type 0x05');
    });
  });

  group('the resolver setting', () {
    test('URLs, bare IPs and resolver stamps are accepted; relays and junk are not', () {
      for (final ok in ['https://1.1.1.1/dns-query', 'tls://9.9.9.9', 'tcp://8.8.8.8', 'udp://8.8.8.8', '1.1.1.1', quad9, cloudflareDoh]) {
        expect(checkDnsSetting(ok).ok, isTrue, reason: ok);
      }
      expect(checkDnsSetting(relayBerlin).problem, DnsProblem.relayAsResolver);
      expect(checkDnsSetting('gopher://x').problem, DnsProblem.badUrl);
      expect(checkDnsSetting('sdns://AAAA').problem, DnsProblem.damaged);
      expect(checkDnsSetting('not a url at all').problem, DnsProblem.badUrl);
    });

    test('the relay setting takes a relay stamp or an address, and refuses a resolver', () {
      expect(checkDnsRelay(relayBerlin).ok, isTrue);
      expect(checkDnsRelay('203.0.113.5:4443').ok, isTrue);
      expect(checkDnsRelay(quad9).problem, DnsProblem.notRelay);
      expect(checkDnsRelay('two words').problem, DnsProblem.notRelay);
    });

    test('describing it for people', () {
      expect(describeDns(quad9), 'DNSCrypt · quad9.net');
      expect(describeDns(quad9, relayBerlin), 'DNSCrypt · quad9.net (anonymized)');
      expect(describeDns(quad9, relayBerlin, 'anonymisé'), 'DNSCrypt · quad9.net (anonymisé)');
      expect(describeDns(cloudflareDoh, relayBerlin), 'DoH · dns.cloudflare.com', reason: 'a relay only applies to DNSCrypt');
      expect(describeDns('tls://1.1.1.1'), 'tls://1.1.1.1');
      expect(isDefaultDns(SettingsState.defaultRemoteDns), isTrue);
      expect(isDefaultDns(''), isTrue);
      expect(isDefaultDns(quad9), isFalse);
    });
  });

  group('the bundled lists', () {
    test('every resolver is a DNSCrypt stamp with DNSSEC, no logs and no filtering', () {
      expect(kDnsCryptResolvers.length, greaterThan(10));
      for (final r in kDnsCryptResolvers) {
        final st = parseDnsStamp(r.stamp).stamp;
        expect(st?.kind, DnsKind.dnscrypt, reason: r.name);
        expect(r.dnssec && r.noLog && r.noFilter, isTrue, reason: r.name);
        expect(st!.props & 7, 7, reason: r.name);
        expect(st.address.startsWith('['), isFalse, reason: '${r.name} is IPv4');
      }
      expect(kDnsCryptResolvers.map((r) => r.name).toSet().length, kDnsCryptResolvers.length);
    });

    test('every relay is a relay stamp', () {
      expect(kDnsRelays.length, greaterThan(5));
      for (final r in kDnsRelays) {
        expect(parseDnsStamp(r.stamp).stamp?.kind, DnsKind.relay, reason: r.name);
      }
    });

    test('the relay picked for a resolver is run by someone else, in another country when possible', () {
      for (final r in kDnsCryptResolvers) {
        final relay = pickRelayFor(r);
        expect(relay, isNotNull, reason: r.name);
        expect(dnsOperatorOf(relay!.name), isNot(dnsOperatorOf(r.name)), reason: '${r.name} via ${relay.name}');
      }
      final scaleway = kDnsCryptResolvers.firstWhere((r) => r.name == 'scaleway-fr');
      expect(dnsOperatorOf('anon-scaleway2'), 'scaleway');
      expect(dnsOperatorOf('dnscry.pt-anon-adelaide-ipv4'), dnsOperatorOf('dnscry.pt-adelaide-ipv4'));
      expect(pickRelayFor(scaleway)!.country, isNot('FR'));
    });
  });

  group('settings', () {
    test('the relay is kept across a restart; an older file has none', () {
      final s = const SettingsState().copyWith(remoteDns: quad9, dnsRelay: relayBerlin);
      final back = SettingsState.fromJson(s.toJson(), const SettingsState());
      expect(back.remoteDns, quad9);
      expect(back.dnsRelay, relayBerlin);
      expect(SettingsState.fromJson({'remote_dns': 'tls://1.1.1.1'}, const SettingsState()).dnsRelay, '');
    });

    test('the core gets the stamp, and the relay only with a DNSCrypt stamp', () {
      Map<String, dynamic> params(String dns, String relay) =>
          DaemonEngine.startParams(_profile, const [], ConnectOptions(dns: dns, dnsRelay: relay));
      expect(params(quad9, relayBerlin)['dns'], quad9);
      expect(params(quad9, relayBerlin)['dns_relay'], relayBerlin);
      expect(params(quad9, '').containsKey('dns_relay'), isFalse);
      expect(params('tls://1.1.1.1', relayBerlin).containsKey('dns_relay'), isFalse);
      expect(params(cloudflareDoh, relayBerlin).containsKey('dns_relay'), isFalse);
      expect(params('', '').containsKey('dns'), isFalse);
    });
  });

  group('the DNS screen', () {
    Future<ProviderContainer> open(WidgetTester tester, {SettingsState Function(SettingsState)? start}) async {
      tester.view.physicalSize = const Size(900, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _container();
      addTearDown(c.dispose);
      if (start != null) c.read(settingsProvider.notifier).update(start);
      await tester.pumpWidget(_app(c, const DnsScreen()));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('the default is selected at first; choosing a DNSCrypt resolver stores its stamp', (tester) async {
      final c = await open(tester);
      expect(c.read(settingsProvider).remoteDns, SettingsState.defaultRemoteDns);
      final scalewayRow = find.byKey(const ValueKey('dns-stamp-scaleway-fr'));
      expect(scalewayRow, findsOneWidget);
      await tester.tap(scalewayRow);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).remoteDns, scaleway);
      await tester.tap(find.byKey(const ValueKey('dns-preset-quad9-https')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).remoteDns, 'https://9.9.9.9/dns-query');
      await tester.tap(find.byKey(const ValueKey('dns-preset-default')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).remoteDns, SettingsState.defaultRemoteDns);
    });

    testWidgets('Anonymized needs a DNSCrypt resolver; turning it on picks a relay of another operator', (tester) async {
      final c = await open(tester);
      final toggle = find.byKey(const ValueKey('dns-anonymized'));
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull, reason: 'the default is not DNSCrypt');
      expect(find.text('Choose a DNSCrypt resolver to use this'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dns-stamp-scaleway-fr')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final relay = c.read(settingsProvider).dnsRelay;
      expect(relay, isNotEmpty);
      final entry = dnsRelayEntry(relay)!;
      expect(dnsOperatorOf(entry.name), isNot('scaleway'));
      expect(find.byKey(const ValueKey('dns-relay')), findsOneWidget);

      // Another DNSCrypt resolver keeps the relay unless it is that resolver's own operator.
      await tester.tap(find.byKey(const ValueKey('dns-stamp-ibksturm')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dnsRelay, relay);

      // A resolver that is not DNSCrypt drops it.
      await tester.tap(find.byKey(const ValueKey('dns-preset-cloudflare-tls')));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dnsRelay, '');
      expect(find.byKey(const ValueKey('dns-relay')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('dns-stamp-scaleway-fr')));
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dnsRelay, isNotEmpty);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).dnsRelay, '');
    });

    testWidgets('a custom address: errors are named, Save stays off until it is valid, then it is stored', (tester) async {
      final c = await open(tester);
      final field = find.byKey(const ValueKey('dns-custom-field'));
      final save = find.byKey(const ValueKey('dns-custom-save'));
      bool saveEnabled() => tester.widget<FilledButton>(save).onPressed != null;
      expect(saveEnabled(), isFalse);

      await tester.enterText(field, 'gopher://hello');
      await tester.pump();
      expect(find.textContaining('sdns:// stamp'), findsOneWidget);
      expect(saveEnabled(), isFalse);

      await tester.enterText(field, quad9.substring(0, quad9.length - 30));
      await tester.pump();
      expect(find.text('This stamp is damaged or cut short. Copy it again.'), findsOneWidget);
      expect(saveEnabled(), isFalse);

      await tester.enterText(field, relayBerlin);
      await tester.pump();
      expect(find.text('This is a relay stamp, not a resolver'), findsOneWidget);
      expect(saveEnabled(), isFalse);

      await tester.enterText(field, 'sdns://BQcAAAAAAAAAAAA');
      await tester.pump();
      expect(find.text('This kind of stamp is not supported'), findsOneWidget);

      expect(c.read(settingsProvider).remoteDns, SettingsState.defaultRemoteDns, reason: 'nothing invalid was stored');

      await tester.enterText(field, cloudflareDoh);
      await tester.pump();
      expect(saveEnabled(), isTrue);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).remoteDns, cloudflareDoh);

      await tester.enterText(field, 'tls://1.1.1.1');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).remoteDns, 'tls://1.1.1.1');
    });

    testWidgets('a custom value from before is shown in the field', (tester) async {
      await open(tester, start: (s) => s.copyWith(remoteDns: 'tls://dns.example'));
      expect(find.widgetWithText(TextField, 'tls://dns.example'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // the store's write delay
    });
  });

  group('the line in the connected details', () {
    testWidgets('names the DNSCrypt resolver, nothing for the default', (tester) async {
      final c = _container();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const Scaffold(body: DnsLine())));
      expect(find.byKey(const ValueKey('dns-line')), findsNothing);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(remoteDns: quad9));
      await tester.pump();
      expect(find.text('DNS: DNSCrypt · quad9.net'), findsOneWidget);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(dnsRelay: relayBerlin));
      await tester.pump();
      expect(find.text('DNS: DNSCrypt · quad9.net (anonymized)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // the store's write delay
    });
  });
}
