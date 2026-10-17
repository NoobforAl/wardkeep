import '../engine/engine.dart';
import 'location.dart';

/// What the Windows tray icon's menu is made of, kept apart from the plugin that shows it so that what
/// it lists can be tested on its own (see ui/tray.dart for the part that talks to the system).
///
/// Entries that can be chosen have a [TrayEntry.key]: [trayToggleKey], [trayOpenKey], [trayQuitKey],
/// [trayAutomaticKey] or [trayServerKey] + a profile's ID.
const trayToggleKey = 'toggle';
const trayOpenKey = 'open';
const trayQuitKey = 'quit';
const trayAutomaticKey = 'auto';
const _serverPrefix = 'server:';

String trayServerKey(String profileId) => '$_serverPrefix$profileId';

/// The profile ID in a [trayServerKey], or null for any other key.
String? trayServerOfKey(String key) => key.startsWith(_serverPrefix) ? key.substring(_serverPrefix.length) : null;

/// How many servers the "Switch server" submenu lists: a native menu with hundreds of lines is no use.
const trayMaxServers = 12;

/// How long a server's name may be in the menu.
const _maxLabel = 48;

/// The words of the menu, in the app's language.
class TrayTexts {
  const TrayTexts({
    required this.connect,
    required this.cancel,
    required this.disconnect,
    required this.switchServer,
    required this.automatic,
    required this.noServers,
    required this.open,
    required this.quit,
  });

  final String connect;
  final String cancel;
  final String disconnect;
  final String switchServer;
  final String automatic;
  final String noServers;
  final String open;
  final String quit;
}

class TrayEntry {
  const TrayEntry.item(this.label, {this.key, this.checked = false, this.enabled = true}) : children = null;

  const TrayEntry.submenu(this.label, List<TrayEntry> this.children, {this.enabled = true})
      : key = null,
        checked = false;

  const TrayEntry.separator()
      : label = '',
        key = null,
        checked = false,
        enabled = false,
        children = null;

  final String label;
  final String? key;

  /// Marks the choice in use (a check mark in front).
  final bool checked;
  final bool enabled;

  /// The entries of a submenu, null for anything else.
  final List<TrayEntry>? children;

  bool get isSeparator => label.isEmpty && key == null && children == null;

  Map<String, Object?> toJson() => {
        'label': label,
        if (key != null) 'key': key,
        if (checked) 'checked': true,
        if (!enabled) 'enabled': false,
        if (children != null) 'children': [for (final c in children!) c.toJson()],
      };

  @override
  String toString() => toJson().toString();
}

/// The menu: the state, Connect / Disconnect, the servers to switch to, Open, Quit.
///
/// [statusLine] is the state in words (already translated, e.g. "Connected to Germany"). [choice] is the
/// user's choice of where to connect (null = automatic, see location.dart); it is marked in the list.
List<TrayEntry> buildTrayMenu({
  required TrayTexts texts,
  required String statusLine,
  required ConnStatus status,
  required List<ProfileInfo> profiles,
  required String? choice,
  int maxServers = trayMaxServers,
}) {
  final main = switch (status) {
    ConnStatus.connecting => TrayEntry.item(texts.cancel, key: trayToggleKey),
    ConnStatus.connected || ConnStatus.noInternet => TrayEntry.item(texts.disconnect, key: trayToggleKey),
    ConnStatus.disconnecting => TrayEntry.item(texts.disconnect, key: trayToggleKey, enabled: false),
    // Nothing to connect to without a server.
    _ => TrayEntry.item(texts.connect, key: trayToggleKey, enabled: profiles.isNotEmpty),
  };

  // A server that wants a password the app does not have cannot start from a menu: it needs the form.
  final usable = profiles.where((p) => !(p.needsCredentials && !p.hasCredentials)).toList();
  final fastest = byLatency(usable).take(maxServers).toList();
  // The chosen server is always in the list, even when it is not among the fastest.
  final chosen = usable.where((p) => p.id == choice).firstOrNull;
  if (chosen != null && !fastest.any((p) => p.id == chosen.id)) fastest.add(chosen);

  final servers = usable.isEmpty
      ? TrayEntry.submenu(texts.switchServer, [TrayEntry.item(texts.noServers, enabled: false)], enabled: false)
      : TrayEntry.submenu(texts.switchServer, [
          TrayEntry.item(texts.automatic, key: trayAutomaticKey, checked: choice == null),
          const TrayEntry.separator(),
          for (final p in fastest) TrayEntry.item(_short(p.name), key: trayServerKey(p.id), checked: p.id == choice),
        ]);

  return [
    TrayEntry.item(statusLine, enabled: false),
    const TrayEntry.separator(),
    main,
    servers,
    const TrayEntry.separator(),
    TrayEntry.item(texts.open, key: trayOpenKey),
    TrayEntry.item(texts.quit, key: trayQuitKey),
  ];
}

String _short(String name) {
  final one = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length <= _maxLabel ? one : '${one.substring(0, _maxLabel - 1)}…';
}
