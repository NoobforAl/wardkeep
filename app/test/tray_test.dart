import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/state/tray_menu.dart';
import 'package:omnitun/ui/tray.dart';

ProfileInfo _profile(String id, {int? latency, String? name, Map<String, dynamic> raw = const {}}) => ProfileInfo(
      id: id,
      name: name ?? 'P-$id',
      protocol: 'vless',
      server: '$id.example.com',
      port: 443,
      latencyMs: latency,
      raw: raw,
    );

const _texts = TrayTexts(
  connect: 'Connect',
  cancel: 'Cancel',
  disconnect: 'Disconnect',
  switchServer: 'Switch server',
  automatic: 'Automatic',
  noServers: 'No servers',
  open: 'Open',
  quit: 'Quit',
);

List<TrayEntry> _menu({
  ConnStatus status = ConnStatus.disconnected,
  List<ProfileInfo> profiles = const [],
  String? choice,
  int max = trayMaxServers,
}) =>
    buildTrayMenu(texts: _texts, statusLine: 'state', status: status, profiles: profiles, choice: choice, maxServers: max);

TrayEntry _byKey(List<TrayEntry> menu, String key) =>
    menu.firstWhere((e) => e.key == key, orElse: () => throw StateError('no $key in $menu'));

TrayEntry _servers(List<TrayEntry> menu) => menu.firstWhere((e) => e.children != null);

/// What the tray menu is made of: the state, Connect / Disconnect, the servers, Open and Quit.
void main() {
  group('the menu', () {
    test('lists the state, the main action, the servers, Open and Quit in that order', () {
      final menu = _menu(profiles: [_profile('a')]);
      expect(menu.map((e) => e.isSeparator ? '-' : e.label).toList(), [
        'state', '-', 'Connect', 'Switch server', '-', 'Open', 'Quit',
      ]);
      expect(menu.first.enabled, isFalse); // the state line is only to read
    });

    test('the main action follows the connection', () {
      final one = [_profile('a')];
      expect(_byKey(_menu(profiles: one), trayToggleKey).label, 'Connect');
      expect(_byKey(_menu(profiles: one, status: ConnStatus.connecting), trayToggleKey).label, 'Cancel');
      expect(_byKey(_menu(profiles: one, status: ConnStatus.connected), trayToggleKey).label, 'Disconnect');
      expect(_byKey(_menu(profiles: one, status: ConnStatus.noInternet), trayToggleKey).label, 'Disconnect');
      expect(_byKey(_menu(profiles: one, status: ConnStatus.error), trayToggleKey).label, 'Connect');
      final going = _byKey(_menu(profiles: one, status: ConnStatus.disconnecting), trayToggleKey);
      expect(going.enabled, isFalse);
    });

    test('without servers there is nothing to connect to or to switch to', () {
      final menu = _menu();
      expect(_byKey(menu, trayToggleKey).enabled, isFalse);
      final servers = _servers(menu);
      expect(servers.enabled, isFalse);
      expect(servers.children!.single.label, 'No servers');
      expect(servers.children!.single.key, isNull);
    });

    test('Automatic and the servers, with the choice marked', () {
      final profiles = [_profile('a', latency: 90), _profile('b', latency: 20), _profile('c')];
      var sub = _servers(_menu(profiles: profiles, choice: null)).children!;
      expect(sub.first.key, trayAutomaticKey);
      expect(sub.first.checked, isTrue);
      // fastest first, then the ones never tested
      expect(sub.where((e) => trayServerOfKey(e.key ?? '') != null).map((e) => e.label).toList(), ['P-b', 'P-a', 'P-c']);
      expect(sub.where((e) => e.checked).length, 1);

      sub = _servers(_menu(profiles: profiles, choice: 'a')).children!;
      expect(sub.first.checked, isFalse);
      expect(sub.singleWhere((e) => e.checked).key, trayServerKey('a'));
      expect(trayServerOfKey(trayServerKey('a')), 'a');
      expect(trayServerOfKey(trayOpenKey), isNull);

      // a country choice (or anything else that is not a server) marks nothing
      sub = _servers(_menu(profiles: profiles, choice: 'country:DE')).children!;
      expect(sub.where((e) => e.checked), isEmpty);
    });

    test('only the fastest few are listed, but the chosen server is always there', () {
      final profiles = [for (var i = 0; i < 30; i++) _profile('s$i', latency: 100 + i)];
      var sub = _servers(_menu(profiles: profiles, max: 5)).children!;
      expect(sub.where((e) => trayServerOfKey(e.key ?? '') != null).length, 5);
      expect(sub.any((e) => e.key == trayServerKey('s29')), isFalse);
      sub = _servers(_menu(profiles: profiles, choice: 's29', max: 5)).children!;
      expect(sub.where((e) => trayServerOfKey(e.key ?? '') != null).length, 6);
      expect(sub.singleWhere((e) => e.checked).key, trayServerKey('s29'));
    });

    test('a server that still needs a password is not offered; long names are cut', () {
      final needs = _profile('p', raw: {'openvpn': {'needs_auth': true}});
      final long = _profile('l', name: 'x' * 100);
      final sub = _servers(_menu(profiles: [needs, long])).children!;
      final names = sub.where((e) => trayServerOfKey(e.key ?? '') != null).map((e) => e.label).toList();
      expect(names.length, 1);
      expect(names.single.length, lessThanOrEqualTo(48));
      expect(names.single.endsWith('…'), isTrue);
    });
  });

  group('the tray icon', () {
    final tray = <MethodCall>[];
    final window = <MethodCall>[];
    var iconFails = false;
    late MockEngine engine;
    late ProviderContainer container;
    late TrayController controller;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      tray.clear();
      window.clear();
      iconFails = false;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('tray_manager'), (call) async {
        tray.add(call);
        if (call.method == 'setIcon' && iconFails) throw PlatformException(code: 'no');
        return true;
      });
      messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
        window.add(call);
        return call.method == 'isMinimized' ? false : true;
      });
      engine = MockEngine(connectDelay: Duration.zero);
      container = ProviderContainer(overrides: [
        storeProvider.overrideWithValue(AppStore.memory()),
        engineProvider.overrideWithValue(engine),
        trayProvider.overrideWith((ref) {
          final c = TrayController(ref, supported: true);
          ref.onDispose(c.dispose);
          return c;
        }),
      ]);
      controller = container.read(trayProvider);
    });

    tearDown(() {
      container.dispose();
      engine.dispose();
    });

    List<_Json> items([List<MethodCall>? calls]) {
      final last = (calls ?? tray).lastWhere((c) => c.method == 'setContextMenu');
      return [for (final i in (last.arg('menu')! as _Json)['items']! as List) i as _Json];
    }

    _Json find(String key, [List<_Json>? from]) {
      for (final i in from ?? items()) {
        if (i['key'] == key) return i;
        final sub = i['submenu'] as _Json?;
        if (sub != null) {
          final inner = find(key, [for (final s in sub['items']! as List) s as _Json]);
          if (inner.isNotEmpty) return inner;
        }
      }
      return const {};
    }

    List<String> labels() => [for (final i in items()) if (i['type'] != 'separator') i['label'] as String];

    Future<void> click(String key) async {
      final id = find(key)['id'];
      expect(id, isNotNull, reason: 'no menu item $key');
      await _fromSystem('tray_manager', 'onTrayMenuItemClick', {'id': id});
      await pumpEventQueue();
    }

    int count(List<MethodCall> calls, String method) => calls.where((c) => c.method == method).length;

    Future<void> start() async {
      await controller.start();
      await pumpEventQueue();
    }

    test('shows the icon with a tip and a menu, and does nothing where there is no tray', () async {
      final other = container.read(Provider((ref) => TrayController(ref, supported: false)));
      await other.start();
      expect(tray, isEmpty);

      await start();
      expect(controller.isUp, isTrue);
      final icon = tray.firstWhere((c) => c.method == 'setIcon');
      expect((icon.arg('iconPath') as String).replaceAll('\\', '/'), endsWith('data/flutter_assets/assets/tray.ico'));
      expect(tray.firstWhere((c) => c.method == 'setToolTip').arg('toolTip'), contains('Wardkeep'));
      expect(labels(), ['Not connected', 'Connect', 'Switch server', 'Open Wardkeep', 'Quit']);
    });

    test('the menu follows the app language', () async {
      await start();
      container.read(settingsProvider.notifier).update((s) => s.copyWith(language: 'ru'));
      await pumpEventQueue();
      final ru = lookupAppLocalizations(const Locale('ru'));
      expect(ru.trayOpen, isNot('Open Wardkeep'));
      expect(labels(), [ru.statusDisconnected, ru.buttonConnect, ru.traySwitchServer, ru.trayOpen, ru.trayQuit]);
      expect(tray.lastWhere((c) => c.method == 'setToolTip').arg('toolTip'), startsWith('Wardkeep: '));
    });

    test('follows the connection and the servers, and sends the menu only when it changed', () async {
      container.read(profilesProvider.notifier).addAll([_profile('a'), _profile('b')]);
      container.read(selectedProfileIdProvider.notifier).select('a');
      await start();
      expect(find(trayToggleKey)['label'], 'Connect');
      expect(find(trayServerKey('a'))['checked'], isTrue);
      expect(find(trayServerKey('b'))['checked'], isFalse);

      await container.read(connectionProvider.notifier).toggle();
      await pumpEventQueue();
      expect(container.read(connectionProvider).status, ConnStatus.connected);
      expect(find(trayToggleKey)['label'], 'Disconnect');
      expect(labels().first, 'Connected · P-a');

      // The speed changes every second: no new menu for that.
      final menus = count(tray, 'setContextMenu');
      container.read(connectionProvider.notifier).state =
          container.read(connectionProvider).copyWith(upBps: 5, downBps: 9);
      await pumpEventQueue();
      expect(count(tray, 'setContextMenu'), menus);
    });

    test('Connect and Disconnect', () async {
      container.read(profilesProvider.notifier).addAll([_profile('a')]);
      container.read(selectedProfileIdProvider.notifier).select('a');
      await start();
      await click(trayToggleKey);
      expect(container.read(connectionProvider).status, ConnStatus.connected);
      await click(trayToggleKey);
      await Future<void>.delayed(const Duration(milliseconds: 400)); // the mock takes a moment to disconnect
      await pumpEventQueue();
      expect(container.read(connectionProvider).status, ConnStatus.disconnected);
    });

    test('Switch server chooses where to connect, and moves a live connection there', () async {
      container.read(profilesProvider.notifier).addAll([_profile('a'), _profile('b')]);
      container.read(selectedProfileIdProvider.notifier).select('a');
      await start();

      // not connected: only the choice changes
      await click(trayServerKey('b'));
      expect(container.read(selectedProfileIdProvider), 'b');
      expect(container.read(connectionProvider).status, ConnStatus.disconnected);
      expect(find(trayServerKey('b'))['checked'], isTrue);

      await container.read(connectionProvider.notifier).toggle();
      await pumpEventQueue();
      expect(container.read(connectionProvider).activeProfileId, 'b');

      // connected: the connection moves
      await click(trayServerKey('a'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();
      expect(container.read(selectedProfileIdProvider), 'a');
      expect(container.read(connectionProvider).status, ConnStatus.connected);
      expect(container.read(connectionProvider).activeProfileId, 'a');

      await click(trayAutomaticKey);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();
      expect(container.read(selectedProfileIdProvider), isNull);
    });

    test('a click on the icon brings the window back; a right click opens the menu', () async {
      await start();
      await _fromSystem('tray_manager', 'onTrayIconMouseDown', null);
      await pumpEventQueue();
      expect(window.map((c) => c.method), containsAllInOrder(['show', 'focus']));
      await _fromSystem('tray_manager', 'onTrayIconRightMouseDown', null);
      await pumpEventQueue();
      final pop = tray.lastWhere((c) => c.method == 'popUpContextMenu');
      // the system closes a menu on a click elsewhere only if the app is in front while it is open
      expect(pop.arg('bringAppToFront'), isTrue);
    });

    test('Open brings the window back', () async {
      await start();
      await click(trayOpenKey);
      expect(window.map((c) => c.method), containsAllInOrder(['show', 'focus']));
    });

    test('Quit removes the icon and ends the app', () async {
      await start();
      await click(trayQuitKey);
      expect(tray.map((c) => c.method), contains('destroy'));
      expect(window.map((c) => c.method), contains('destroy'));
      expect(count(window, 'hide'), 0);
    });

    test('closing the window ends the app as before while the tray setting is off', () async {
      await start();
      // nothing holds the close back, and a close does not hide the window
      expect(window.where((c) => c.method == 'setPreventClose' && c.arg('isPreventClose') == true), isEmpty);
      await _fromSystem('window_manager', 'onEvent', {'eventName': 'close'});
      await pumpEventQueue();
      expect(count(window, 'hide'), 0);
    });

    test('with "Keep running in the tray" on, closing the window hides it; off again, it closes', () async {
      await start();
      container.read(settingsProvider.notifier).update((s) => s.copyWith(keepInTray: true));
      await pumpEventQueue();
      expect(window.lastWhere((c) => c.method == 'setPreventClose').arg('isPreventClose'), isTrue);
      await _fromSystem('window_manager', 'onEvent', {'eventName': 'close'});
      await pumpEventQueue();
      expect(count(window, 'hide'), 1);
      expect(count(window, 'destroy'), 0); // still running

      container.read(settingsProvider.notifier).update((s) => s.copyWith(keepInTray: false));
      await pumpEventQueue();
      expect(window.lastWhere((c) => c.method == 'setPreventClose').arg('isPreventClose'), isFalse);
      await _fromSystem('window_manager', 'onEvent', {'eventName': 'close'});
      await pumpEventQueue();
      expect(count(window, 'hide'), 1);
    });

    test('the setting is on from the start when it was saved on', () async {
      container.dispose();
      container = ProviderContainer(overrides: [
        storeProvider.overrideWithValue(AppStore.memory({'settings': {'keep_in_tray': true}})),
        engineProvider.overrideWithValue(engine),
        trayProvider.overrideWith((ref) {
          final c = TrayController(ref, supported: true);
          ref.onDispose(c.dispose);
          return c;
        }),
      ]);
      controller = container.read(trayProvider);
      await start();
      expect(window.lastWhere((c) => c.method == 'setPreventClose').arg('isPreventClose'), isTrue);
    });

    test('if the icon cannot be made, the window is never held back from closing', () async {
      iconFails = true;
      container.read(settingsProvider.notifier).update((s) => s.copyWith(keepInTray: true));
      await start();
      expect(controller.isUp, isFalse);
      expect(window.where((c) => c.method == 'setPreventClose'), isEmpty);
      await _fromSystem('window_manager', 'onEvent', {'eventName': 'close'});
      await pumpEventQueue();
      expect(count(window, 'hide'), 0);
    });

    test('started at sign-in without a window: the window is shown if there is no icon to open it by', () async {
      startInBackground = true;
      addTearDown(() => startInBackground = false);
      iconFails = true;
      await start();
      expect(window.map((c) => c.method), containsAllInOrder(['show', 'focus']));

      window.clear();
      iconFails = false;
      final again = container.read(Provider((ref) => TrayController(ref, supported: true)));
      await again.start();
      await pumpEventQueue();
      expect(again.isUp, isTrue);
      expect(window.map((c) => c.method), isNot(contains('show'))); // the icon is there: the window stays hidden
    });

    test('the setting is off by default and is saved', () {
      expect(const SettingsState().keepInTray, isFalse);
      final on = const SettingsState().copyWith(keepInTray: true);
      expect(SettingsState.fromJson(on.toJson(), const SettingsState()).keepInTray, isTrue);
      expect(SettingsState.fromJson(const {}, const SettingsState()).keepInTray, isFalse);
    });
  });
}

/// A call from the native side to Dart, as the plugins make them.
Future<void> _fromSystem(String channel, String method, Object? arguments) {
  final done = Future<void>.value();
  unawaited(TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    channel,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  ));
  return done;
}

/// A map as the platform channels decode it.
typedef _Json = Map<Object?, Object?>;

extension on MethodCall {
  /// One named argument of a call whose arguments are a map.
  Object? arg(String key) => (arguments as _Json)[key];
}
