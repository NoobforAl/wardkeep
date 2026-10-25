import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/state/subscriptions.dart';

ProfileInfo _p(String id, String protocol) =>
    ProfileInfo.fromJson({'id': id, 'name': id, 'protocol': protocol, 'server': '$id.x', 'port': 443});

/// A key as the server prints it: 32 bytes, base64.
final _keyStd = base64Encode(List.filled(32, 7));
String _b64(List<int> bytes) => base64Encode(bytes);

class SignedEngine extends MockEngine {
  List<ProfileInfo> next = [];
  SubscriptionInfo info = const SubscriptionInfo();
  Map<String, dynamic>? lastRequest;

  @override
  Future<SubscriptionResult> fetchSubscription(Map<String, dynamic> request) async {
    lastRequest = request;
    return SubscriptionResult(next, const [], info);
  }
}

void main() {
  late SignedEngine engine;
  late AppStore store;
  late ProviderContainer c;

  ProviderContainer make() => ProviderContainer(overrides: [
        storeProvider.overrideWithValue(store),
        engineProvider.overrideWithValue(engine),
      ]);

  setUp(() {
    engine = SignedEngine();
    store = AppStore.memory();
    c = make();
  });
  tearDown(() => c.dispose());

  test('a provider link carries its signing key after #pk=', () {
    expect(Subscription.splitKey('https://p.example/sub/abc#pk=AAA-_'), ('https://p.example/sub/abc', 'AAA-_'));
    expect(Subscription.splitKey('https://p.example/sub/abc'), ('https://p.example/sub/abc', ''));
    expect(Subscription.splitKey('https://p.example/sub#other'), ('https://p.example/sub#other', ''));
    expect(Subscription.splitKey('https://p.example/sub#a=1&pk=k%2Bk'), ('https://p.example/sub', 'k+k'));
  });

  test('a signing key is 32 bytes of base64, in either alphabet', () {
    expect(Subscription.isValidKey(_keyStd), isTrue);
    expect(Subscription.isValidKey(_keyStd.replaceAll('=', '')), isTrue); // padding left off
    expect(Subscription.isValidKey(_b64(List.filled(32, 250)).replaceAll('+', '-').replaceAll('/', '_')), isTrue); // URL-safe
    expect(Subscription.isValidKey(''), isFalse);
    expect(Subscription.isValidKey('not a key'), isFalse);
    expect(Subscription.isValidKey(_b64(List.filled(31, 1))), isFalse);
    expect(Subscription.isValidKey(_b64(List.filled(33, 1))), isFalse);
  });

  test('the key and the backup addresses go to the core, are kept, and survive a restart', () async {
    engine.next = [_p('a', 'trojan')];
    await c.read(subscriptionsProvider.notifier).add(
          url: 'https://p.example/sub/abc#pk=${_keyStd.replaceAll('+', '-').replaceAll('/', '_')}',
          fallbackUrls: ['https://backup.example/sub/abc'],
        );
    final req = engine.lastRequest!;
    expect(req['url'], 'https://p.example/sub/abc'); // the key is not part of the address
    expect(req['public_key'], _keyStd.replaceAll('+', '-').replaceAll('/', '_'));
    expect(req['fallback_urls'], ['https://backup.example/sub/abc']);

    c.dispose();
    c = make();
    final sub = c.read(subscriptionsProvider).single;
    expect(sub.url, 'https://p.example/sub/abc');
    expect(sub.publicKey, isNotEmpty);
    expect(sub.fallbackUrls, ['https://backup.example/sub/abc']);
    expect(sub.toRequest()['public_key'], sub.publicKey);

    // An older save, with neither, still loads.
    final old = Subscription.fromJson({'id': 's', 'name': 'n', 'url': 'https://x.example/'});
    expect(old.publicKey, '');
    expect(old.fallbackUrls, isEmpty);
    expect(old.toRequest().containsKey('public_key'), isFalse);
  });

  test('a typed key wins over the one in the link', () async {
    engine.next = [_p('a', 'trojan')];
    await c.read(subscriptionsProvider.notifier).add(url: 'https://p.example/sub#pk=fromlink', publicKey: 'typed');
    expect(engine.lastRequest!['public_key'], 'typed');
  });

  test('the provider\'s order is used only for a verified answer, and a country can have its own', () async {
    final profiles = [_p('t', 'trojan'), _p('s', 'shadowsocks'), _p('h', 'hysteria2'), _p('v', 'vless')];
    final order = {
      '': ['vless', 'hysteria2'],
      'IR': ['hysteria2', 'trojan'],
    };
    List<String> ids(List<ProfileInfo> l) => [for (final p in l) p.id];
    SubscriptionResult result(bool verified) =>
        SubscriptionResult(profiles, const [], SubscriptionInfo(verified: verified, protocolOrder: order));

    // The general order, then the protocols it does not name in their own order.
    expect(ids(orderedByProvider(result(true), countries: ['DE'])), ['v', 'h', 't', 's']);
    // The country's own order wins; the device's regions are tried in turn.
    expect(ids(orderedByProvider(result(true), countries: ['ir'])), ['h', 't', 's', 'v']);
    expect(ids(orderedByProvider(result(true), countries: ['US', 'IR'])), ['h', 't', 's', 'v']);
    // Nothing changes when the answer was not verified, or the provider named nothing.
    expect(ids(orderedByProvider(result(false), countries: ['IR'])), ['t', 's', 'h', 'v']);
    expect(
      ids(orderedByProvider(SubscriptionResult(profiles, const [], const SubscriptionInfo(verified: true)), countries: ['IR'])),
      ['t', 's', 'h', 'v'],
    );

    // And a refresh puts the group in that order.
    engine.next = profiles;
    engine.info = SubscriptionInfo(verified: true, protocolOrder: {
      '': ['hysteria2', 'vless']
    });
    await c.read(subscriptionsProvider.notifier).add(url: 'https://p.example/sub', publicKey: _keyStd);
    final first = c.read(profilesProvider).first;
    expect(first.id, anyOf('h', 'v')); // the order put a Hysteria 2 or VLESS profile first
  });

  test('the answer says whether it was verified, and what the provider asks for', () {
    final info = SubscriptionInfo.fromJson({
      'verified': true,
      'protocol_order': {
        '': ['vless'],
        'IR': ['hysteria2', 'trojan'],
      },
    });
    expect(info.verified, isTrue);
    expect(info.protocolOrder['IR'], ['hysteria2', 'trojan']);
    expect(SubscriptionInfo.fromJson(const {}).verified, isFalse);
    expect(SubscriptionInfo.fromJson(info.toJson()).protocolOrder, info.protocolOrder);
  });
}
