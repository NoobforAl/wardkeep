import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/l10n.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/state/usage.dart';
import 'package:omnitun/ui/widgets/profile_subtitle.dart';

EngineState _on(String id, int up, int down, {ConnStatus status = ConnStatus.connected}) =>
    EngineState(status: status, activeProfileId: id, upTotal: up, downTotal: down);

final _profile = ProfileInfo.fromJson({'id': 'a', 'name': 'A', 'protocol': 'trojan', 'server': 'a.example', 'port': 443});

/// Lets a test hand the app any engine state.
class _Feeder extends MockEngine {
  _Feeder() : super(connectDelay: Duration.zero);

  final controller = StreamController<EngineState>.broadcast();

  @override
  Stream<EngineState> get states => controller.stream;

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }
}

void main() {
  group('UsageMeter', () {
    test('the first state only sets the starting point, then growth is counted', () {
      final m = UsageMeter();
      expect(m.feed(_on('a', 5000000, 90000000)), isNull, reason: 'attached to a tunnel that was already running');
      expect(m.feed(_on('a', 5000100, 90001000)), (id: 'a', up: 100, down: 1000));
      expect(m.feed(_on('a', 5000100, 90001000)), isNull, reason: 'nothing moved');
      expect(m.feed(_on('a', 5000200, 90003000)), (id: 'a', up: 100, down: 2000));
    });

    test('a counter that went back is a new tunnel: all it has counted is new', () {
      final m = UsageMeter();
      m.feed(_on('a', 0, 0));
      m.feed(_on('a', 1000, 5000));
      expect(m.feed(_on('a', 10, 20)), (id: 'a', up: 10, down: 20));
    });

    test('nothing is counted while not connected, for Automatic, or without a server; and a restart is a new start', () {
      final m = UsageMeter();
      m.feed(_on('a', 0, 0));
      expect(m.feed(_on('a', 100, 100, status: ConnStatus.connecting)), isNull);
      expect(m.feed(_on('auto', 100, 100)), isNull);
      expect(m.feed(const EngineState(status: ConnStatus.connected, upTotal: 9, downTotal: 9)), isNull);
      // back on server a with a counter that is high: it is a starting point again, not 100 MB of new data
      expect(m.feed(_on('a', 100000000, 100000000)), isNull);
      expect(m.feed(_on('a', 100000050, 100000070)), (id: 'a', up: 50, down: 70));
    });

    test('switching server in a running tunnel starts the other server from the counters as they are', () {
      final m = UsageMeter();
      m.feed(_on('a', 0, 0));
      expect(m.feed(_on('a', 10, 10)), (id: 'a', up: 10, down: 10));
      expect(m.feed(_on('b', 100, 100)), isNull);
      expect(m.feed(_on('b', 130, 150)), (id: 'b', up: 30, down: 50));
    });
  });

  group('the saved counter', () {
    ProviderContainer make(AppStore store, _Feeder engine) {
      final c = ProviderContainer(overrides: [
        storeProvider.overrideWithValue(store),
        engineProvider.overrideWithValue(engine),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('adds up per server across connections, survives a restart and can be reset', () async {
      final store = AppStore.memory({});
      final engine = _Feeder();
      var c = make(store, engine);
      c.read(connectionProvider);
      c.read(profileUsageProvider);
      Future<void> send(EngineState s) async {
        engine.controller.add(s);
        await Future<void>.delayed(Duration.zero);
      }

      await send(_on('a', 0, 0));
      await send(_on('a', 1000, 2000000));
      await send(_on('a', 3000, 3000000));
      await send(const EngineState()); // disconnected: saved
      expect(c.read(profileUsageProvider)['a']!.up, 3000);
      expect(c.read(profileUsageProvider)['a']!.down, 3000000);
      expect(c.read(usageOfProvider('a')), 3003000);
      expect(c.read(usageOfProvider('b')), 0);
      expect(c.read(profileUsageProvider)['a']!.since, isNotNull);

      // a second connection, to the same server, adds to it
      await send(_on('a', 0, 0));
      await send(_on('a', 500, 500));
      await send(const EngineState());
      expect(c.read(usageOfProvider('a')), 3004000);

      // a restart of the app finds it again
      c.dispose();
      c = make(store, engine);
      expect(c.read(usageOfProvider('a')), 3004000);

      c.read(profileUsageProvider.notifier).reset('a');
      expect(c.read(usageOfProvider('a')), 0);
      expect(store.read<Map<String, dynamic>>('usage'), isEmpty, reason: 'and the reset is remembered');
    });
  });

  group('under the server name', () {
    Widget app(ProviderContainer c, {Locale locale = const Locale('en')}) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileSubtitle(_profile)),
          ),
        );

    testWidgets('shows the address alone until data went through, then how much, in KB, MB or GB', (tester) async {
      final store = AppStore.memory({
        'usage': {
          'a': {'up': 1, 'down': 1},
        },
      });
      final c = ProviderContainer(overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(_Feeder())]);
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c));
      expect(find.text('a.example:443'), findsOneWidget);
      expect(find.text('2 B used'), findsOneWidget);

      Future<void> set(int bytes) async {
        c.read(profileUsageProvider.notifier).state = {'a': ProfileUsage(down: bytes)};
        await tester.pump();
      }

      await set(1536 * 1024);
      expect(find.text('1.5 MB used'), findsOneWidget);
      await set(5 * 1024 * 1024 * 1024);
      expect(find.text('5.0 GB used'), findsOneWidget);
      await set(0);
      expect(find.byKey(const Key('profile-usage')), findsNothing);
      expect(find.text('a.example:443'), findsOneWidget);
    });

    testWidgets('is worded in the language of the app', (tester) async {
      final store = AppStore.memory({
        'usage': {
          'a': {'up': 0, 'down': 3 * 1024 * 1024},
        },
      });
      final c = ProviderContainer(overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(_Feeder())]);
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, locale: const Locale('ru')));
      expect(find.textContaining('3.0 MB'), findsOneWidget);
      expect(find.text('Использовано 3.0 MB'), findsOneWidget);
    });
  });
}
