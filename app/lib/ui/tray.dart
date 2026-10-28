import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../engine/engine.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../state/tray_menu.dart';
import 'theme.dart';

/// The Windows tray icon: the state at a glance, Connect / Disconnect, a quick switch between servers,
/// Open and Quit. With "Keep running in the tray" on (Settings) closing the window only hides it and
/// the app, its core and the tray icon carry on until Quit.
///
/// Started once from the app (see `main.dart`); does nothing on other systems. If the icon cannot be
/// created, closing the window ends the app as before: a hidden window with no icon would be lost.
final trayProvider = Provider<TrayController>((ref) {
  final controller = TrayController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// True when Windows started the app at sign-in (`--background`, set by the installer's "start with
/// Windows"): the window stays hidden until the tray icon is used. Set in `main`.
bool startInBackground = false;

/// The icon is an asset (a few sizes cut from the app icon by installer/make-tray-icon.py).
const trayIconAsset = 'assets/tray.ico';

class TrayController with TrayListener, WindowListener {
  TrayController(this._ref, {bool? supported}) : _supported = supported ?? (!kIsWeb && Platform.isWindows);

  final Ref _ref;
  final bool _supported;
  bool _started = false;
  bool _up = false;
  bool _keep = false;
  bool? _preventing;
  String _lastShown = '';
  Future<void> _queue = Future.value();

  /// Whether the tray icon is there.
  bool get isUp => _up;

  Future<void> start() async {
    if (!_supported || _started) return;
    _started = true;
    try {
      trayManager.addListener(this);
      windowManager.addListener(this);
      await trayManager.setIcon(trayIconAsset);
      _up = true;
    } catch (_) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      // A window that was left hidden, with no icon to open it by, would be lost.
      if (startInBackground) await showWindow();
      return;
    }
    // Everything the menu shows, and the setting; the menu is only sent to the system when it changed.
    _ref.listen(connectionProvider, (_, _) => _refresh());
    _ref.listen(profilesProvider, (_, _) => _refresh());
    _ref.listen(selectedProfileIdProvider, (_, _) => _refresh());
    _ref.listen(settingsProvider.select((s) => (s.language, s.keepInTray)), (_, _) => _refresh());
    await _refresh();
  }

  void dispose() {
    if (!_up) return;
    _up = false;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  /// Rebuilds the menu and the tip, one at a time.
  Future<void> _refresh() => _queue = _queue.then((_) => _apply()).catchError((Object _) {});

  Future<void> _apply() async {
    if (!_up) return;
    final settings = _ref.read(settingsProvider);
    _keep = settings.keepInTray;
    // Closing the window is only held back while the icon is there to bring it back.
    if ((_preventing ?? false) != _keep) {
      _preventing = _keep;
      await windowManager.setPreventClose(_keep);
    }
    final l = _localizations(settings.language);
    final state = _ref.read(connectionProvider);
    final profiles = _ref.read(profilesProvider);
    final status = _statusLine(l, state, profiles);
    final entries = buildTrayMenu(
      texts: TrayTexts(
        connect: l.buttonConnect,
        cancel: l.buttonCancel,
        disconnect: l.buttonDisconnect,
        switchServer: l.traySwitchServer,
        automatic: l.automatic,
        noServers: l.noServers,
        open: l.trayOpen,
        quit: l.trayQuit,
      ),
      statusLine: status,
      status: state.status,
      profiles: profiles,
      choice: _ref.read(selectedProfileIdProvider),
    );
    final tip = _tip('${l.appName}: $status');
    final signature = jsonEncode([tip, for (final e in entries) e.toJson()]);
    if (signature == _lastShown) return;
    _lastShown = signature;
    await trayManager.setToolTip(tip);
    await trayManager.setContextMenu(Menu(items: [for (final e in entries) _item(e)]));
  }

  /// The words of the app's language (the system's one when none is chosen; English when it has none).
  AppLocalizations _localizations(String language) {
    final code = language.isEmpty ? PlatformDispatcher.instance.locale.languageCode : language;
    final known = AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
    return lookupAppLocalizations(Locale(known ? code : 'en'));
  }

  String _statusLine(AppLocalizations l, EngineState state, List<ProfileInfo> profiles) {
    final text = statusLabel(l, state.status);
    if (state.status != ConnStatus.connected) return text;
    final name = profiles.where((p) => p.id == state.activeProfileId).firstOrNull?.name;
    return name == null ? text : '$text · $name';
  }

  /// The tip is limited to 127 characters by Windows.
  String _tip(String text) => text.length <= 120 ? text : '${text.substring(0, 119)}…';

  MenuItem _item(TrayEntry e) {
    if (e.isSeparator) return MenuItem.separator();
    // "&" would make the next letter a keyboard shortcut in a Windows menu.
    final label = e.label.replaceAll('&', '&&');
    final children = e.children;
    if (children != null) {
      return MenuItem.submenu(
        label: label,
        disabled: !e.enabled,
        submenu: Menu(items: [for (final c in children) _item(c)]),
      );
    }
    // A checkbox is how the system menu shows the choice in use; an unchecked one looks like a plain line.
    if (e.key == trayAutomaticKey || (e.key != null && trayServerOfKey(e.key!) != null)) {
      return MenuItem.checkbox(key: e.key, label: label, checked: e.checked, disabled: !e.enabled);
    }
    return MenuItem(key: e.key, label: label, disabled: !e.enabled);
  }

  // The icon: a click brings the window back, a right click opens the menu.

  @override
  void onTrayIconMouseDown() => unawaited(showWindow());

  @override
  void onTrayIconRightMouseDown() {
    // ignore: deprecated_member_use
    unawaited(trayManager.popUpContextMenu(bringAppToFront: true));
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) unawaited(_choose(key));
  }

  Future<void> _choose(String key) async {
    try {
      switch (key) {
        case trayToggleKey:
          await _ref.read(connectionProvider.notifier).toggle();
        case trayOpenKey:
          await showWindow();
        case trayQuitKey:
          await quit();
        case trayAutomaticKey:
          await _switchTo(null);
        default:
          final id = trayServerOfKey(key);
          if (id != null) await _switchTo(id);
      }
    } catch (_) {
      // a failed connection shows in the app's own state; nothing to add here
    }
  }

  /// Chooses where to connect, and moves the connection there if it is up (as the location list does).
  Future<void> _switchTo(String? id) async {
    if (id != null) {
      final profile = _ref.read(profilesProvider).where((p) => p.id == id).firstOrNull;
      if (profile == null || (profile.needsCredentials && !profile.hasCredentials)) return;
    }
    final connection = _ref.read(connectionProvider.notifier);
    final current = _ref.read(selectedProfileIdProvider);
    final wasActive = connection.isActive;
    _ref.read(selectedProfileIdProvider.notifier).select(id);
    if (wasActive && id != current) await connection.reconnect();
  }

  /// Brings the window back from the tray (or from behind other windows).
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Ends the app, and with it the core. Same as closing the window with the tray setting off.
  Future<void> quit() async {
    _up = false;
    try {
      await trayManager.destroy(); // the icon would stay in the tray until the mouse passes over it
    } catch (_) {}
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    // With the tray setting off the window closes (and the app ends) by itself.
    if (_up && _keep) unawaited(windowManager.hide());
  }
}
