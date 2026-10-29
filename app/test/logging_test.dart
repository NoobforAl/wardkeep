import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/daemon_engine.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/errors.dart';
import 'package:omnitun/l10n/l10n.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/log_alerts.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/logs_screen.dart';
import 'package:omnitun/ui/screens/settings_screen.dart';
import 'package:omnitun/ui/system_notifications.dart';

/// The preview engine, with log records pushed by the test and the `logging.set` calls it got.
class _LogEngine extends MockEngine {
  final records = StreamController<LogRecord>.broadcast();
  final loggingCalls = <(String level, DateTime? until)>[];

  @override
  Stream<LogRecord> get logs => records.stream;

  @override
  Future<void> setLogging(String level, {DateTime? until}) async {
    loggingCalls.add((level, until));
    await super.setLogging(level, until: until);
  }

  @override
  void dispose() {
    unawaited(records.close());
    super.dispose();
  }
}

/// Records the system notifications instead of showing them.
class _FakeSystemNotifications extends SystemNotifications {
  final shown = <(String title, String body, String conn)>[];

  /// Whether each shown one was a failure of the connection (Android leaves those to "Connection lost").
  final connection = <bool>[];

  @override
  Future<void> start(void Function(String conn) openLogs) async {}

  @override
  Future<void> show({required String title, required String body, required String conn, bool connection = false}) async {
    shown.add((title, body, conn));
    this.connection.add(connection);
  }
}

LogRecord _failure({String conn = '7f3a', String code = 'TOR_TIMEOUT'}) => LogRecord.fromJson({
  'time': '2026-10-29T01:02:03.456Z',
  'level': 'error',
  'source': 'tor',
  'msg': 'bootstrap stalled',
  'op': 'connect',
  'conn': conn,
  'code': code,
  'notify': true,
});

void main() {
  group('LogRecord', () {
    test('reads every key of the contract and keeps unknown ones', () {
      final record = LogRecord.fromJson({
        'time': '2026-10-29T01:02:03.456Z',
        'level': 'error',
        'source': 'tor',
        'msg': 'bootstrap stalled',
        'target': 'tor_guardmgr',
        'op': 'connect',
        'conn': '7f3a',
        'profile': 'p_19',
        'code': 'TOR_BLOCKED',
        'err': 'no guard',
        'notify': true,
        'caller': 'tor.go:12',
        'stack': 'goroutine 1',
        'user': 'alice',
        'attempt': 3,
      });
      expect(record.time.toUtc(), DateTime.utc(2026, 10, 29, 1, 2, 3, 456));
      expect(record.level, 'error');
      expect(record.source, 'tor');
      expect(record.msg, 'bootstrap stalled');
      expect(
        [record.target, record.op, record.conn, record.profile, record.code, record.err, record.caller, record.stack],
        ['tor_guardmgr', 'connect', '7f3a', 'p_19', 'TOR_BLOCKED', 'no guard', 'tor.go:12', 'goroutine 1'],
      );
      expect(record.notify, isTrue);
      expect(record.extra, {'user': 'alice', 'attempt': 3});
      expect(record.fields, contains(('attempt', '3')));
      expect(record.toLine(), contains('user=alice'));
      // An export writes the same record back.
      final exported = record.toJson();
      expect(exported['time'], '2026-10-29T01:02:03.456Z');
      expect(exported['user'], 'alice');
      expect(LogRecord.fromJson(jsonDecode(jsonEncode(exported)) as Map<String, dynamic>).toJson(), exported);
    });

    test('an older core: message instead of msg, no source, an upper-case level', () {
      final record = LogRecord.fromJson({'time': '2026-10-29T01:02:03Z', 'level': 'WARNING', 'message': 'old style'});
      expect(record.msg, 'old style');
      expect(record.level, 'warn');
      expect(record.source, 'core');
      expect(record.extra, isEmpty);
      expect(record.notify, isFalse);
      // msg wins when both are there.
      expect(LogRecord.fromJson({'msg': 'new', 'message': 'old'}).msg, 'new');
      expect(LogRecord.fromJson({'level': 'nonsense'}).level, 'info');
    });

    test('a failure is told in the user\'s language by its code, else by its message', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(logRecordText(l, _failure()), l.errTorTimeout);
      expect(logRecordText(l, _failure(code: 'TOR_EXITED')), l.errTorExited);
      expect(logRecordText(l, _failure(code: 'PANIC')), l.errPanic);
      expect(logRecordText(l, _failure(code: 'SOMETHING_NEW')), 'bootstrap stalled');
    });
  });

  test('the log keeps the latest 500 records', () async {
    final engine = _LogEngine();
    final container = ProviderContainer(overrides: [engineProvider.overrideWithValue(engine)]);
    addTearDown(container.dispose);
    container.listen(logsProvider, (_, _) {});
    for (var i = 0; i < LogsController.maxRecords + 20; i++) {
      engine.records.add(LogRecord.app('line $i'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(container.read(logsProvider), isEmpty, reason: 'records reach the screen in batches');
    await Future<void>.delayed(LogsController.publishEvery * 2);
    final logs = container.read(logsProvider);
    expect(logs, hasLength(LogsController.maxRecords));
    expect(logs.first.msg, 'line 20');
    expect(logs.last.msg, 'line ${LogsController.maxRecords + 19}');
  });

  group('debug logging setting', () {
    test('choosing a level sends logging.set with an end 24 hours later; off sends the default', () async {
      final engine = _LogEngine();
      final container = ProviderContainer(overrides: [engineProvider.overrideWithValue(engine)]);
      addTearDown(container.dispose);
      final now = DateTime.utc(2026, 10, 29, 12);
      // The end is in the future relative to the real clock only when [now] is; use the real clock.
      container.read(settingsProvider.notifier).setLogLevel('debug');
      await Future<void>.delayed(Duration.zero);
      expect(engine.loggingCalls.single.$1, 'debug');
      final until = engine.loggingCalls.single.$2!;
      expect(until.difference(DateTime.now()).inMinutes, closeTo(24 * 60, 1));
      expect(container.read(settingsProvider).activeLogLevel(), 'debug');
      expect(container.read(settingsProvider).activeLogLevel(now.add(const Duration(days: 400))), '');

      container.read(settingsProvider.notifier).setLogLevel('');
      await Future<void>.delayed(Duration.zero);
      expect(engine.loggingCalls.last, ('', null));
      expect((await container.read(loggingModeProvider.future))!.level, '');
    });

    test('a level still running is sent again at start; one that ran out is off', () async {
      final future = DateTime.now().toUtc().add(const Duration(hours: 3)).toIso8601String();
      final engine = _LogEngine();
      final container = ProviderContainer(overrides: [
        engineProvider.overrideWithValue(engine),
        storeProvider.overrideWithValue(AppStore.memory({
          'settings': {'log_level': 'trace', 'log_until': future},
        })),
      ]);
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).logLevel, 'trace');
      await Future<void>.delayed(Duration.zero);
      expect(engine.loggingCalls.single.$1, 'trace');

      final expiredEngine = _LogEngine();
      final expired = ProviderContainer(overrides: [
        engineProvider.overrideWithValue(expiredEngine),
        storeProvider.overrideWithValue(AppStore.memory({
          'settings': {'log_level': 'trace', 'log_until': '2020-01-01T00:00:00Z', 'notify_os': false},
        })),
      ]);
      addTearDown(expired.dispose);
      expect(expired.read(settingsProvider).logLevel, '');
      expect(expired.read(settingsProvider).notifyOs, isFalse);
      expect(expired.read(settingsProvider).notifyPopup, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(expiredEngine.loggingCalls, isEmpty);
    });
  });

  testWidgets('the settings page warns, then sends the level chosen', (tester) async {
    final engine = _LogEngine();
    await tester.pumpWidget(ProviderScope(
      overrides: [engineProvider.overrideWithValue(engine)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.scrollUntilVisible(find.byKey(const Key('debug-logging')), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('debug-logging')));
    await tester.pumpAndSettle();
    // The core's own level is shown under the setting.
    expect(find.textContaining('info (dev build)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('debug-logging')));
    await tester.pumpAndSettle();
    expect(find.text(l.debugLoggingWarning), findsOneWidget);
    await tester.tap(find.text(l.logLevelDebug));
    await tester.pumpAndSettle();
    expect(engine.loggingCalls.single.$1, 'debug');
    expect(find.textContaining(l.logLevelDebug), findsWidgets);
  });

  test('the control protocol: log events become records, logging.set and logging.get go to the core', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requests = <Map<String, dynamic>>[];
    server.listen((client) {
      client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        final request = jsonDecode(line) as Map<String, dynamic>;
        requests.add(request);
        final result = switch (request['method']) {
          'hello' => {
            'state': {'status': 'disconnected'},
          },
          'logging.get' => {'level': 'debug', 'default': 'error', 'mode': 'release', 'until': '2026-10-30T00:00:00Z'},
          _ => null,
        };
        client.write('${jsonEncode({'id': request['id'], 'result': result})}\n');
        if (request['method'] == 'hello') {
          client.write('${jsonEncode({
            'event': 'log',
            'data': {'time': '2026-10-29T01:02:03.456Z', 'level': 'error', 'source': 'core', 'message': 'old core', 'conn': 'c1'},
          })}\n');
        }
      });
    });
    final engine = await DaemonEngine.attachTo('127.0.0.1:${server.port}', 'token');
    addTearDown(engine.dispose);
    final first = await engine.logs.first;
    expect(first.msg, 'old core');
    expect(first.conn, 'c1');

    await engine.setLogging('trace', until: DateTime.utc(2026, 10, 30, 1, 2, 3, 456, 789));
    final set = requests.firstWhere((request) => request['method'] == 'logging.set');
    expect(set['params'], {'level': 'trace', 'until': '2026-10-30T01:02:03.456Z'});

    final mode = await engine.loggingMode();
    expect(mode.level, 'debug');
    expect(mode.defaultLevel, 'error');
    expect(mode.mode, 'release');
    expect(mode.until!.toUtc(), DateTime.utc(2026, 10, 30));
  });

  group('failures nothing handled', () {
    Future<(_LogEngine, _FakeSystemNotifications, AppStore)> pumpApp(WidgetTester tester, {Map<String, dynamic>? settings}) async {
      final engine = _LogEngine();
      final notifications = _FakeSystemNotifications();
      final store = AppStore.memory({'onboarded': true, 'settings': ?settings});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          engineProvider.overrideWithValue(engine),
          systemNotificationsProvider.overrideWithValue(notifications),
        ],
        child: const OmnitunApp(),
      ));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return (engine, notifications, store);
    }

    testWidgets('are told once per connection and code, with "View logs" opening that connection\'s log', (tester) async {
      final (engine, notifications, _) = await pumpApp(tester);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      engine.records.add(LogRecord.app('unrelated', level: 'info'));
      engine.records.add(LogRecord.fromJson({'level': 'info', 'source': 'core', 'msg': 'other attempt', 'conn': 'zz'}));
      engine.records.add(_failure());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l.errTorTimeout), findsOneWidget);
      expect(find.text(l.logsView), findsOneWidget);
      // The app is in front with the notice on screen: no system notification as well.
      expect(notifications.shown, isEmpty);

      // The same connection and code again: not told again.
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      var told = 0;
      container.listen(logAlertsProvider, (_, _) => told++);
      engine.records.add(_failure());
      await tester.pump();
      expect(told, 0);
      // Another code of the same connection is.
      engine.records.add(_failure(code: 'TOR_MISSING'));
      await tester.pump();
      expect(told, 1);
      await tester.pump(const Duration(milliseconds: 500));

      // In the background the system notification tells it as well.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      engine.records.add(_failure(conn: 'b2'));
      await tester.pump();
      expect(notifications.shown.single.$3, 'b2');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(l.logsView));
      await tester.pumpAndSettle();
      expect(find.byType(LogsScreen), findsOneWidget);
      expect(find.byKey(const Key('logs-conn-filter')), findsOneWidget);
      expect(find.textContaining('bootstrap stalled', findRichText: true), findsWidgets);
      expect(find.textContaining('other attempt', findRichText: true), findsNothing);
      // Clearing the filter shows every record.
      await tester.tap(find.descendant(of: find.byKey(const Key('logs-conn-filter')), matching: find.byType(Icon)).last);
      await tester.pumpAndSettle();
      expect(find.textContaining('other attempt', findRichText: true), findsOneWidget);
    });

    testWidgets('without the in-app notice a system notification tells it', (tester) async {
      final (engine, notifications, _) = await pumpApp(tester, settings: {'notify_popup': false});
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      engine.records.add(_failure());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l.logsView), findsNothing);
      expect(notifications.shown.single, (l.appName, l.errTorTimeout, '7f3a'));
    });

    testWidgets('a failure of the connection is marked as one (Android leaves it to "Connection lost")', (tester) async {
      final (engine, notifications, _) = await pumpApp(tester, settings: {'notify_popup': false});
      // A running connection that fell to the error state (op connect, from the attempt it belongs to).
      engine.records.add(LogRecord.fromJson({
        'level': 'error',
        'source': 'core',
        'msg': 'the connection failed: the server did not answer in time',
        'op': 'connect',
        'conn': 'c1',
        'code': 'TIMEOUT',
        'notify': true,
      }));
      // Something else that failed with nothing to handle it.
      engine.records.add(LogRecord.fromJson({
        'level': 'fatal',
        'source': 'core',
        'msg': 'panic: boom',
        'op': 'subscription',
        'code': 'PANIC',
        'notify': true,
      }));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(notifications.shown.map((n) => n.$3), ['c1', '']);
      expect(notifications.connection, [true, false]);
    });

    test('only the records of a connection are failures of the connection', () {
      expect(SystemNotifications.isConnectionFailure(_failure()), isTrue);
      expect(SystemNotifications.isConnectionFailure(LogRecord.app('import failed', level: 'error')), isFalse);
    });

    testWidgets('with both switched off nothing is told', (tester) async {
      final (engine, notifications, _) = await pumpApp(tester, settings: {'notify_popup': false, 'notify_os': false});
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      engine.records.add(_failure());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l.logsView), findsNothing);
      expect(notifications.shown, isEmpty);
    });
  });
}
