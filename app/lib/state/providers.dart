import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/core_engine.dart';
import '../engine/engine.dart';
import 'countries.dart';
import 'bypass_countries.dart';
import 'ipdb_state.dart';
import 'location.dart';
import 'store.dart';

/// Overridden in main() with the store loaded from disk.
final storeProvider = Provider<AppStore>((ref) => AppStore.memory());

final engineProvider = Provider<VpnEngine>((ref) {
  final engine = CoreEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Imported profiles, persisted as the core's raw profile JSON.
class ProfilesController extends Notifier<List<ProfileInfo>> {
  static const _key = 'profiles';

  @override
  List<ProfileInfo> build() {
    final saved = ref.read(storeProvider).read<List<dynamic>>(_key) ?? const [];
    final out = <ProfileInfo>[];
    for (final raw in saved) {
      try {
        out.add(ProfileInfo.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (_) {
        // Skip entries written by an incompatible version.
      }
    }
    return out;
  }

  void _save(List<ProfileInfo> next) {
    state = next;
    ref.read(storeProvider).write(_key, [for (final p in next) p.raw]);
  }

  /// Adds profiles, skipping ones whose ID is already present.
  int addAll(Iterable<ProfileInfo> profiles) {
    final known = {for (final p in state) p.id};
    final fresh = profiles.where((p) => known.add(p.id)).toList();
    if (fresh.isNotEmpty) _save([...state, ...fresh]);
    return fresh.length;
  }

  void remove(String id) {
    _save(state.where((p) => p.id != id).toList());
    _fixSelection();
  }

  /// Deletes every server (all subscriptions' too) except the built-in Tor ones, which are the
  /// app's own default and never come from the user's files.
  void clearAll() {
    _save(state.where((p) => p.protocol == 'tor').toList());
    _fixSelection();
  }

  /// When the chosen server is gone, or Auto has nothing left to start on, choose the default.
  void _fixSelection() {
    final choice = ref.read(selectedProfileIdProvider);
    if (choice != null && countryOfChoice(choice) != null) return;
    final gone = choice != null && !state.any((p) => p.id == choice);
    final nothingAuto = choice == null && !state.any((p) => p.protocol != 'tor');
    if (!gone && !nothingAuto) return;
    final fallback = resolveDefault(state, ref.read(defaultProfileIdProvider));
    if (fallback != null) ref.read(selectedProfileIdProvider.notifier).select(fallback.id);
  }

  /// Puts an edited profile where [oldId] was (same group and place in the list). If
  /// the edit gave it a new ID, a selection of the old one follows.
  void replace(String oldId, ProfileInfo edited) {
    final at = state.indexWhere((p) => p.id == oldId);
    if (at < 0) {
      addAll([edited]);
      return;
    }
    final keep = state[at];
    final next = [...state];
    next[at] = edited.group == keep.group ? edited : edited.inGroup(keep.group);
    // Another profile with the ID the edit now has would be a duplicate.
    _save([for (var i = 0; i < next.length; i++) if (i == at || next[i].id != edited.id) next[i]]);
    if (edited.id != oldId && ref.read(selectedProfileIdProvider) == oldId) {
      ref.read(selectedProfileIdProvider.notifier).select(edited.id);
    }
  }

  /// Replaces the profiles of [group] (a subscription refresh), keeping the
  /// group's position in the list. IDs are stable, so the selection survives.
  void replaceGroup(String group, List<ProfileInfo> profiles) {
    final at = state.indexWhere((p) => p.group == group);
    final rest = state.where((p) => p.group != group).toList();
    final fresh = <String>{};
    // Credentials entered in the app aren't part of the subscription; keep them.
    final old = {for (final p in state) p.id: p};
    final incoming = [
      for (final p in profiles)
        if (fresh.add(p.id))
          (p.needsCredentials && !p.hasCredentials && (old[p.id]?.hasCredentials ?? false))
              ? p.inGroup(group).withCredentials(old[p.id]!.raw['username'] as String, old[p.id]!.raw['password'] as String)
              : p.inGroup(group),
    ];
    // A profile also imported manually stays in its manual group.
    final manual = {for (final p in rest) p.id};
    incoming.removeWhere((p) => manual.contains(p.id));
    final insertAt = at < 0 ? rest.length : rest.where((p) => state.indexOf(p) < at).length;
    _save([...rest.take(insertAt), ...incoming, ...rest.skip(insertAt)]);
  }

  /// Saves the username and password of a profile that needs them (OpenVPN).
  void setCredentials(String id, String username, String password) =>
      _save([for (final p in state) p.id == id ? p.withCredentials(username, password) : p]);

  /// Puts a server in [group] (a group of the user's, or [ProfileInfo.defaultGroup]). It keeps its place in the
  /// list: the order is the failover priority, and moving a server must not change it.
  void moveTo(String id, String group) {
    final at = state.indexWhere((p) => p.id == id);
    if (at < 0 || state[at].group == group) return;
    final next = [...state];
    next[at] = state[at].inGroup(group);
    _save(next);
  }

  /// Sends the servers of a group of the user's back to the default group (the group is being removed).
  void ungroup(String group) =>
      _save([for (final p in state) p.group == group ? p.inGroup(ProfileInfo.defaultGroup) : p]);

  void removeGroup(String group) {
    _save(state.where((p) => p.group != group).toList());
    _fixSelection();
  }

  /// Moves a profile within its group; [from]/[to] are positions inside the
  /// group ([to] already adjusted for the removed item).
  void reorderInGroup(String group, int from, int to) {
    final members = state.where((p) => p.group == group).toList();
    final moved = members.removeAt(from);
    members.insert(to, moved);
    var i = 0;
    _save([for (final p in state) p.group == group ? members[i++] : p]);
  }

  /// Moves a profile to [to] (index after removal); the order is the failover priority.
  void reorder(int from, int to) {
    final next = [...state];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    _save(next);
  }

  // Latency is transient and not persisted.
  void setLatency(String id, int ms) =>
      state = [for (final p in state) p.id == id ? p.copyWith(latencyMs: ms) : p];
}

/// The profile editors of the protocols the core can build by hand.
final formsProvider = FutureProvider<List<ProtocolFormSpec>>((ref) => ref.read(engineProvider).forms());

final profilesProvider =
    NotifierProvider<ProfilesController, List<ProfileInfo>>(ProfilesController.new);

/// Where the user wants to connect: null = Auto, "country:DE" = a country,
/// otherwise one profile's ID (see location.dart).
class SelectedProfileController extends Notifier<String?> {
  static const _key = 'selected';

  @override
  String? build() => ref.read(storeProvider).read<String>(_key);

  void select(String? id) {
    state = id;
    ref.read(storeProvider).write(_key, id);
  }
}

final selectedProfileIdProvider =
    NotifierProvider<SelectedProfileController, String?>(SelectedProfileController.new);

/// Tor with Snowflake bridges, obfs4 bridges and direct: the app's own default configuration. It
/// needs nothing from the user and is always available; their servers come on top of it.
const torDefaultLinks = ['tor://snowflake', 'tor://obfs4', 'tor://'];

/// The kind of bridges a Tor profile uses ("snowflake", "obfs4"), or null (direct, or not Tor).
String? torKind(ProfileInfo p) {
  if (p.protocol != 'tor') return null;
  return (p.raw['tor'] as Map?)?['builtin'] as String?;
}

/// The profile the user marked as default; null = the built-in default (Tor with Snowflake).
class DefaultProfileController extends Notifier<String?> {
  static const _key = 'default_profile';

  /// Set when the app itself added the Tor defaults to an empty list: the introduction is still due.
  static const freshInstall = 'fresh_install';

  @override
  String? build() => ref.read(storeProvider).read<String>(_key);

  void set(String? id) {
    state = id;
    ref.read(storeProvider).write(_key, id);
  }

  /// Adds the Tor defaults on a brand new install (and whenever [force] asks, after the user deleted
  /// them) and selects the default then. Returns how many were added.
  Future<int> ensureTorDefaults({bool force = false}) async {
    final store = ref.read(storeProvider);
    const seeded = 'defaults_seeded';
    if (!force && store.read<bool>(seeded) == true) return 0;
    final fresh = ref.read(profilesProvider).isEmpty;
    if (!force && !fresh) {
      // Someone who already set the app up has their own list; Restore Tor defaults is in the menu.
      store.write(seeded, true);
      return 0;
    }
    final ImportResult result;
    try {
      result = await ref.read(engineProvider).importText(torDefaultLinks.join('\n'));
    } catch (_) {
      return 0; // the core is not ready; the next start tries again
    }
    final added = ref.read(profilesProvider.notifier).addAll(result.profiles);
    store.write(seeded, true);
    if (fresh && !force) store.write(freshInstall, true);
    final choice = ref.read(selectedProfileIdProvider);
    if ((fresh || force) && choice == null) {
      final fallback = resolveDefault(ref.read(profilesProvider), state);
      if (fallback != null) ref.read(selectedProfileIdProvider.notifier).select(fallback.id);
    }
    return added;
  }
}

final defaultProfileIdProvider =
    NotifierProvider<DefaultProfileController, String?>(DefaultProfileController.new);

/// The default profile: the one the user chose, else Tor with Snowflake, else any Tor profile.
/// What the app selects when it has no valid choice (first start, a deleted server).
final defaultProfileProvider = Provider<ProfileInfo?>(
  (ref) => resolveDefault(ref.watch(profilesProvider), ref.watch(defaultProfileIdProvider)),
);

/// [defaultProfileProvider] as a function, for the controllers that cannot depend on it.
ProfileInfo? resolveDefault(List<ProfileInfo> profiles, String? chosen) {
  final mine = profiles.where((p) => p.id == chosen).firstOrNull;
  if (mine != null) return mine;
  return profiles.where((p) => torKind(p) == 'snowflake').firstOrNull ??
      profiles.where((p) => p.protocol == 'tor').firstOrNull;
}

/// Countries the user set by hand, by profile ID (they win over the guess).
class CountryOverrides extends Notifier<Map<String, String>> {
  static const _key = 'countries';

  @override
  Map<String, String> build() {
    final saved = ref.read(storeProvider).read<Map<String, dynamic>>(_key) ?? const {};
    return {for (final e in saved.entries) e.key: e.value as String};
  }

  /// Sets the country of a profile; null goes back to the guess.
  void set(String id, String? code) {
    final next = {...state};
    code == null ? next.remove(id) : next[id] = code;
    state = next;
    ref.read(storeProvider).write(_key, next);
  }
}

final countryOverridesProvider = NotifierProvider<CountryOverrides, Map<String, String>>(CountryOverrides.new);

/// Countries seen when connected (the exit lookup), by profile ID.
class LearnedCountries extends Notifier<Map<String, String>> {
  static const _key = 'learned_countries';

  @override
  Map<String, String> build() {
    final saved = ref.read(storeProvider).read<Map<String, dynamic>>(_key) ?? const {};
    return {for (final e in saved.entries) e.key: e.value as String};
  }

  void learn(String id, String code) {
    if (state[id] == code) return;
    final next = {...state, id: code};
    state = next;
    ref.read(storeProvider).write(_key, next);
  }
}

final learnedCountriesProvider = NotifierProvider<LearnedCountries, Map<String, String>>(LearnedCountries.new);

/// The country of a profile: the user's choice, else the one seen when connected, else the one the
/// offline database gives for the server's address (when it is installed), else a guess from the
/// server's name and address.
final profileCountryProvider = Provider<String? Function(ProfileInfo)>((ref) {
  final overrides = ref.watch(countryOverridesProvider);
  final learned = ref.watch(learnedCountriesProvider);
  final fromDb = ref.watch(dbCountriesProvider);
  final active = ref.watch(ipDbActiveProvider) != null; // a database that is switched off or deleted says nothing
  final guesses = <String, String?>{};
  return (p) =>
      overrides[p.id] ??
      learned[p.id] ??
      (active ? fromDb[p.server] : null) ??
      guesses.putIfAbsent(p.id, () => guessCountry(p));
});

/// The profile to start with and the ones to fall back to, for the current choice.
final connectionPlanProvider = Provider<ConnectionPlan?>((ref) {
  return planConnection(
    ref.watch(profilesProvider),
    ref.watch(selectedProfileIdProvider),
    ref.watch(profileCountryProvider),
  );
});

/// The profile that Connect will start with.
final selectedProfileProvider = Provider<ProfileInfo?>((ref) => ref.watch(connectionPlanProvider)?.primary);

class ConnectionController extends Notifier<EngineState> {
  @override
  EngineState build() {
    final engine = ref.watch(engineProvider);
    final sub = engine.states.listen((next) {
      state = next;
      // Follow automatic switches so the UI shows the profile actually in use.
      final active = next.activeProfileId;
      // Auto and country choices stay as they are; they pick the profile themselves.
      final choice = ref.read(selectedProfileIdProvider);
      final specific = choice != null && countryOfChoice(choice) == null;
      if (next.failover != null && active != null && specific && active != choice) {
        ref.read(selectedProfileIdProvider.notifier).select(active);
      }
    });
    ref.onDispose(sub.cancel);
    return const EngineState();
  }

  bool get isActive => switch (state.status) {
        ConnStatus.connected || ConnStatus.connecting || ConnStatus.noInternet => true,
        _ => false,
      };

  Future<void> toggle() async {
    if (isActive) {
      await ref.read(engineProvider).disconnect();
      return;
    }
    await _connect();
  }

  /// Switches to the location chosen now (disconnect, then connect).
  Future<void> reconnect() async {
    await ref.read(engineProvider).disconnect();
    await _connect();
  }

  Future<void> _connect() async {
    final engine = ref.read(engineProvider);
    final plan = ref.read(connectionPlanProvider);
    if (plan == null) return;
    final settings = ref.read(settingsProvider);
    await engine.connect(
      plan.primary,
      fallbacks: plan.fallbacks,
      options: ConnectOptions(
        tunMode: settings.tunMode,
        systemProxy: settings.systemProxy,
        dns: settings.remoteDns,
        dnsRelay: settings.dnsRelay,
        includePackages: settings.splitMode == 'include' ? settings.splitApps : const [],
        excludePackages: settings.splitMode == 'exclude' ? settings.splitApps : const [],
        autoFailover: settings.autoFailover,
        bypassLan: settings.bypassLan,
        bypass: [ref.read(bypassListsProvider.notifier).enabledText, ref.read(bypassCountryTextProvider)]
            .where((t) => t.isNotEmpty)
            .join('\n'),
        bypassOnly: settings.bypassOnly,
        ipv6: settings.ipv6,
        mtu: settings.mtu,
      ),
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionController, EngineState>(ConnectionController.new);

/// What the exit lookup found for the current connection (null until it did, or when it is off).
class ExitController extends Notifier<ExitInfo?> {
  int _generation = 0;

  @override
  ExitInfo? build() {
    ref.listen(connectionProvider.select((s) => (s.status, s.activeProfileId)), (prev, next) {
      final (status, id) = next;
      if (status != ConnStatus.connected) {
        _generation++;
        if (state != null) state = null;
        return;
      }
      // Once per connection (and again after a failover moved it).
      if (prev?.$1 == ConnStatus.connected && prev?.$2 == id) return;
      _lookup(id);
    });
    return null;
  }

  Future<void> _lookup(String? profileId) async {
    if (!ref.read(settingsProvider).showExit) return;
    final generation = ++_generation;
    state = null;
    try {
      final info = withDbCountry(await ref.read(engineProvider).exitInfo(), ref.read(ipDbActiveProvider));
      if (generation != _generation) return; // connected elsewhere, or disconnected, meanwhile
      state = info;
      // Tor's exit changes with every circuit, and a mesh exits where the user already is (or at a device
      // chosen later), so neither says anything about the profile.
      final profile = ref.read(profilesProvider).where((p) => p.id == profileId).firstOrNull;
      if (info.country != null && profile != null && profile.protocol != 'tor' && !profile.isMesh) {
        ref.read(learnedCountriesProvider.notifier).learn(profile.id, info.country!);
      }
    } catch (_) {
      // The address is a nicety; a failed lookup shows nothing.
    }
  }
}

final exitProvider = NotifierProvider<ExitController, ExitInfo?>(ExitController.new);

/// True when running under `flutter test`: no real network, no real waiting.
bool get _underTest => Platform.environment.containsKey('FLUTTER_TEST');

/// Asks a public service where this device's own address is, directly (not through any tunnel).
typedef DirectLookup = Future<ExitInfo> Function();

final directLookupProvider = Provider<DirectLookup>((ref) {
  /// One GET, read as text.
  Future<String> get(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw HttpException('status ${response.statusCode}');
      return await response.transform(const Utf8Decoder()).join().timeout(const Duration(seconds: 8));
    } finally {
      client.close(force: true);
    }
  }

  return () async {
    // Tests never reach the network.
    if (_underTest) throw const SocketException('no network in tests');
    // Some networks block one of the services, so there are two; the first that answers wins.
    final sources = <Future<ExitInfo> Function()>[
      () async {
        // Cloudflare's trace: "key=value" lines with ip= and loc=.
        final lines = (await get('https://1.1.1.1/cdn-cgi/trace')).split('\n');
        final fields = {
          for (final l in lines)
            if (l.contains('=')) l.substring(0, l.indexOf('=')): l.substring(l.indexOf('=') + 1).trim(),
        };
        final loc = fields['loc'];
        return ExitInfo(fields['ip'] ?? '', loc == null || loc.length != 2 ? null : loc);
      },
      () async => ExitInfo.fromJson(jsonDecode(await get('https://api.country.is/')) as Map<String, dynamic>),
    ];
    Object? last;
    for (final source in sources) {
      try {
        final info = await source();
        if (info.country != null) return info;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? const HttpException('no answer');
  };
});

/// Where the device really is, by its address: shown on the globe while the VPN is off (like Mullvad's
/// "you are here"). Looked up only while not connected and only when the user allows address lookups
/// (Settings); the last answer is remembered so the globe has it at once on the next start.
class HomeLocation extends Notifier<ExitInfo?> {
  static const _key = 'home_country';
  int _generation = 0;

  /// What the lookup service answered last, before the database had its say.
  ExitInfo? _raw;

  @override
  ExitInfo? build() {
    ref.listen(connectionProvider.select((s) => s.status), (prev, next) {
      if (next == ConnStatus.disconnected && prev != next) _lookup(const Duration(milliseconds: 1500));
    });
    // The database loads from disk while the first lookup is already under way: an answer that came without
    // it (a service may place an address in the wrong country) is corrected as soon as it is there.
    ref.listen(ipDbActiveProvider, (prev, next) {
      final raw = _raw;
      if (next == null || raw == null || identical(prev, next)) return;
      if (!const {ConnStatus.disconnected, ConnStatus.error}.contains(ref.read(connectionProvider).status)) return;
      _show(withDbCountry(raw, next));
    });
    ref.listen(settingsProvider.select((s) => s.showExit), (prev, next) {
      if (next && !prev!) _lookup();
    });
    Future.microtask(_lookup);
    final saved = ref.read(storeProvider).read<String>(_key);
    return saved == null ? null : ExitInfo('', saved);
  }

  Future<void> _lookup([Duration delay = Duration.zero]) async {
    final generation = ++_generation;
    if (delay > Duration.zero && !_underTest) await Future<void>.delayed(delay);
    bool idle() =>
        generation == _generation &&
        ref.mounted &&
        ref.read(settingsProvider).showExit &&
        const {ConnStatus.disconnected, ConnStatus.error}.contains(ref.read(connectionProvider).status);
    if (!idle()) return;
    try {
      final raw = await ref.read(directLookupProvider)();
      if (!idle()) return; // connected meanwhile: that answer would describe the VPN, not the device
      _raw = raw;
      _show(withDbCountry(raw, ref.read(ipDbActiveProvider)));
    } catch (_) {
      // Offline or blocked: keep what is known.
    }
  }

  void _show(ExitInfo info) {
    state = info;
    if (info.country != null) ref.read(storeProvider).write(_key, info.country);
  }
}

final homeProvider = NotifierProvider<HomeLocation, ExitInfo?>(HomeLocation.new);

/// The latest log records of the core and the app, the oldest first.
class LogsController extends Notifier<List<LogRecord>> {
  /// The most records kept; the oldest go first.
  static const maxRecords = 500;

  /// How often new records reach the screen. At debug level the core can send hundreds of lines a second;
  /// publishing each one copied the whole list and marked the log page for a rebuild every time.
  static const publishEvery = Duration(milliseconds: 100);

  final _records = ListQueue<LogRecord>(maxRecords);
  Timer? _publish;

  @override
  List<LogRecord> build() {
    final sub = ref.watch(engineProvider).logs.listen(add);
    ref.onDispose(() {
      sub.cancel();
      _publish?.cancel();
    });
    _records.clear();
    return const [];
  }

  void add(LogRecord record) {
    if (_records.length >= maxRecords) _records.removeFirst();
    _records.addLast(record);
    _publish ??= Timer(publishEvery, flush);
  }

  /// Shows the records added since the last time at once.
  void flush() {
    _publish?.cancel();
    _publish = null;
    state = List.unmodifiable(_records);
  }

  void clear() {
    _records.clear();
    flush();
  }
}

final logsProvider = NotifierProvider<LogsController, List<LogRecord>>(LogsController.new);

/// What the core logs now (`logging.get`); null when it cannot say (an older core).
final loggingModeProvider = FutureProvider<LoggingMode?>((ref) async {
  try {
    return await ref.watch(engineProvider).loggingMode();
  } catch (_) {
    return null;
  }
});

/// A named list of destinations that go around the VPN (see core/singbox/bypasslist.go).
class BypassList {
  const BypassList({required this.id, required this.name, required this.text, this.enabled = true, this.entries = 0});

  final String id;
  final String name;

  /// One entry per line: a domain, `full:`, `keyword:`, `regexp:`, an address or a range.
  final String text;
  final bool enabled;

  /// How many entries the core found in [text] when it was added.
  final int entries;

  BypassList copyWith({String? name, String? text, bool? enabled, int? entries}) => BypassList(
    id: id,
    name: name ?? this.name,
    text: text ?? this.text,
    enabled: enabled ?? this.enabled,
    entries: entries ?? this.entries,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'text': text, 'enabled': enabled, 'entries': entries};

  factory BypassList.fromJson(Map<String, dynamic> j) => BypassList(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'List',
    text: j['text'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
    entries: (j['entries'] as num?)?.toInt() ?? 0,
  );
}

/// The user's bypass lists, persisted.
class BypassListsController extends Notifier<List<BypassList>> {
  static const _key = 'bypass_lists';

  @override
  List<BypassList> build() {
    final saved = ref.read(storeProvider).read<List<dynamic>>(_key) ?? const [];
    return [
      for (final s in saved)
        if (s is Map) BypassList.fromJson(Map<String, dynamic>.from(s)),
    ];
  }

  void _save(List<BypassList> next) {
    state = next;
    ref.read(storeProvider).write(_key, [for (final l in next) l.toJson()]);
  }

  String add({required String name, required String text, required int entries}) {
    final id = 'bl-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    _save([...state, BypassList(id: id, name: name, text: text, entries: entries)]);
    return id;
  }

  void update(BypassList list) => _save([for (final l in state) l.id == list.id ? list : l]);

  void remove(String id) => _save(state.where((l) => l.id != id).toList());

  /// The text of every enabled list, as sent to the core.
  String get enabledText => [for (final l in state) if (l.enabled) l.text.trim()].where((t) => t.isNotEmpty).join('\n');
}

final bypassListsProvider = NotifierProvider<BypassListsController, List<BypassList>>(BypassListsController.new);

/// Whether the first-start introduction has been seen.
class OnboardedController extends Notifier<bool> {
  static const _key = 'onboarded';

  @override
  bool build() => ref.read(storeProvider).read<bool>(_key) ?? false;

  void done() {
    state = true;
    ref.read(storeProvider).write(_key, true);
  }
}

final onboardedProvider = NotifierProvider<OnboardedController, bool>(OnboardedController.new);

class SettingsState {
  const SettingsState({
    this.tunMode = false,
    this.systemProxy = true,
    this.stopOnClose = true,
    this.autoFailover = true,
    this.bypassLan = true,
    this.bypassOnly = false,
    this.bypassCountries = const [],
    this.remoteDns = defaultRemoteDns,
    this.dnsRelay = '',
    this.splitMode = 'off',
    this.splitApps = const [],
    this.theme = 'dark',
    this.language = '',
    this.keepInTray = false,
    this.showExit = true,
    this.ipv6 = true,
    this.mtu = 0,
    this.logLevel = '',
    this.logUntil = '',
    this.notifyPopup = true,
    this.notifyOs = true,
  });

  /// The levels "Debug logging" offers; '' is off (the build's default).
  static const logLevels = ['', 'info', 'debug', 'trace'];

  /// How long a chosen log level lasts before it turns itself off.
  static const logLevelLifetime = Duration(hours: 24);

  static const defaultRemoteDns = 'https://1.1.1.1/dns-query';

  /// Capture all traffic. Off = proxy mode (works without admin rights on desktop).
  final bool tunMode;

  /// In proxy mode, set the OS proxy to the local port while connected.
  final bool systemProxy;
  final bool stopOnClose;
  final bool autoFailover;

  /// Local networks (LAN, link-local, multicast) don't go through the VPN.
  final bool bypassLan;

  /// With bypass lists: only the listed destinations use the VPN, everything else goes direct.
  final bool bypassOnly;

  /// Two-letter codes of the countries whose address ranges bypass the VPN (they come from the offline
  /// country database; see bypass_countries.dart). With [bypassOnly] they are the only ones that use it.
  final List<String> bypassCountries;

  /// Resolver used through the tunnel: https://, tls://, tcp://, udp:// or an IP.
  final String remoteDns;

  /// Anonymized DNSCrypt: the relay (a relay stamp) the queries go through; '' = none.
  /// Only used when [remoteDns] is a DNSCrypt stamp.
  final String dnsRelay;

  /// Split tunneling (Android): 'off', 'include' (only [splitApps] use the VPN)
  /// or 'exclude' ([splitApps] bypass the VPN).
  final String splitMode;
  final List<String> splitApps;

  /// 'dark' (default), 'light' or 'system'.
  final String theme;

  /// The app's language: a code from l10n.dart's supportedLanguages, or '' for the system's.
  final String language;

  /// After connecting, ask a public service (through the VPN) for the exit address and country.
  final bool showExit;

  /// Windows: closing the window hides it to the tray icon instead of ending the app (see ui/tray.dart).
  final bool keepInTray;

  /// IPv6 through the VPN; off keeps it out (refused, not leaked).
  final bool ipv6;

  /// The tunnel's packet size (VPN mode); 0 is the core's default.
  final int mtu;

  /// "Debug logging": `info`, `debug` or `trace`, or '' for off (the core keeps only errors in a release).
  final String logLevel;

  /// When [logLevel] turns itself off (RFC 3339); '' with no level.
  final String logUntil;

  /// A failure nothing handled shows a red notice in the app.
  final bool notifyPopup;

  /// ... and a notification of the system's.
  final bool notifyOs;

  /// [logLevel] while it lasts, else ''.
  String activeLogLevel([DateTime? now]) {
    final until = DateTime.tryParse(logUntil);
    if (logLevel.isEmpty || until == null || !until.isAfter(now ?? DateTime.now())) return '';
    return logLevel;
  }

  SettingsState copyWith({
    bool? tunMode,
    bool? systemProxy,
    bool? stopOnClose,
    bool? autoFailover,
    bool? bypassLan,
    bool? bypassOnly,
    List<String>? bypassCountries,
    String? remoteDns,
    String? dnsRelay,
    String? splitMode,
    List<String>? splitApps,
    String? theme,
    String? language,
    bool? keepInTray,
    bool? showExit,
    bool? ipv6,
    int? mtu,
    String? logLevel,
    String? logUntil,
    bool? notifyPopup,
    bool? notifyOs,
  }) =>
      SettingsState(
        tunMode: tunMode ?? this.tunMode,
        systemProxy: systemProxy ?? this.systemProxy,
        stopOnClose: stopOnClose ?? this.stopOnClose,
        autoFailover: autoFailover ?? this.autoFailover,
        bypassLan: bypassLan ?? this.bypassLan,
        bypassOnly: bypassOnly ?? this.bypassOnly,
        bypassCountries: bypassCountries ?? this.bypassCountries,
        remoteDns: remoteDns ?? this.remoteDns,
        dnsRelay: dnsRelay ?? this.dnsRelay,
        splitMode: splitMode ?? this.splitMode,
        splitApps: splitApps ?? this.splitApps,
        theme: theme ?? this.theme,
        language: language ?? this.language,
        keepInTray: keepInTray ?? this.keepInTray,
        showExit: showExit ?? this.showExit,
        ipv6: ipv6 ?? this.ipv6,
        mtu: mtu ?? this.mtu,
        logLevel: logLevel ?? this.logLevel,
        logUntil: logUntil ?? this.logUntil,
        notifyPopup: notifyPopup ?? this.notifyPopup,
        notifyOs: notifyOs ?? this.notifyOs,
      );

  Map<String, dynamic> toJson() => {
        'tun_mode': tunMode,
        'system_proxy': systemProxy,
        'stop_on_close': stopOnClose,
        'auto_failover': autoFailover,
        'bypass_lan': bypassLan,
        'bypass_only': bypassOnly,
        'bypass_countries': bypassCountries,
        'remote_dns': remoteDns,
        'dns_relay': dnsRelay,
        'split_mode': splitMode,
        'split_apps': splitApps,
        'theme': theme,
        'language': language,
        'keep_in_tray': keepInTray,
        'show_exit': showExit,
        'ipv6': ipv6,
        'mtu': mtu,
        'log_level': logLevel,
        'log_until': logUntil,
        'notify_popup': notifyPopup,
        'notify_os': notifyOs,
      };

  /// Missing keys keep the values from [defaults].
  factory SettingsState.fromJson(Map<String, dynamic> j, SettingsState defaults) => SettingsState(
        tunMode: j['tun_mode'] as bool? ?? defaults.tunMode,
        systemProxy: j['system_proxy'] as bool? ?? defaults.systemProxy,
        stopOnClose: j['stop_on_close'] as bool? ?? defaults.stopOnClose,
        autoFailover: j['auto_failover'] as bool? ?? defaults.autoFailover,
        bypassLan: j['bypass_lan'] as bool? ?? defaults.bypassLan,
        bypassOnly: j['bypass_only'] as bool? ?? defaults.bypassOnly,
        bypassCountries: [for (final c in (j['bypass_countries'] as List? ?? const [])) c as String],
        remoteDns: j['remote_dns'] as String? ?? defaults.remoteDns,
        dnsRelay: j['dns_relay'] as String? ?? defaults.dnsRelay,
        splitMode: j['split_mode'] as String? ?? defaults.splitMode,
        splitApps: [for (final a in (j['split_apps'] as List? ?? const [])) a as String],
        theme: j['theme'] as String? ?? defaults.theme,
        language: j['language'] as String? ?? defaults.language,
        keepInTray: j['keep_in_tray'] as bool? ?? defaults.keepInTray,
        showExit: j['show_exit'] as bool? ?? defaults.showExit,
        ipv6: j['ipv6'] as bool? ?? defaults.ipv6,
        mtu: j['mtu'] as int? ?? defaults.mtu,
        logLevel: j['log_level'] as String? ?? defaults.logLevel,
        logUntil: j['log_until'] as String? ?? defaults.logUntil,
        notifyPopup: j['notify_popup'] as bool? ?? defaults.notifyPopup,
        notifyOs: j['notify_os'] as bool? ?? defaults.notifyOs,
      );
}

class SettingsController extends Notifier<SettingsState> {
  static const _key = 'settings';

  @override
  SettingsState build() {
    // Android captures all traffic by default; desktop starts in proxy mode (TUN needs admin rights there).
    final defaults = SettingsState(tunMode: Platform.isAndroid);
    final saved = ref.read(storeProvider).read<Map<String, dynamic>>(_key);
    var settings = saved == null ? defaults : SettingsState.fromJson(saved, defaults);
    // Debug logging that ran out while the app was closed is off.
    if (settings.logLevel.isNotEmpty && settings.activeLogLevel().isEmpty) {
      settings = settings.copyWith(logLevel: '', logUntil: '');
    }
    // The native side needs this to act when the OS closes the app.
    final engine = ref.read(engineProvider);
    Future.microtask(() => engine.setStopOnClose(settings.stopOnClose));
    if (settings.logLevel.isNotEmpty) Future.microtask(() => _sendLogging(settings));
    _scheduleLoggingEnd(settings);
    ref.onDispose(() => _loggingEnd?.cancel());
    return settings;
  }

  Timer? _loggingEnd;

  void update(SettingsState Function(SettingsState) change) {
    final before = state;
    state = change(state);
    ref.read(storeProvider).write(_key, state.toJson());
    if (state.stopOnClose != before.stopOnClose) {
      ref.read(engineProvider).setStopOnClose(state.stopOnClose);
    }
    if (state.logLevel != before.logLevel || state.logUntil != before.logUntil) {
      _sendLogging(state);
      _scheduleLoggingEnd(state);
    }
  }

  /// Turns "Debug logging" to [level] ('' = off) for [SettingsState.logLevelLifetime].
  void setLogLevel(String level, {DateTime? now}) => update((s) => s.copyWith(
    logLevel: level,
    logUntil: level.isEmpty ? '' : (now ?? DateTime.now()).toUtc().add(SettingsState.logLevelLifetime).toIso8601String(),
  ));

  /// Tells the core (`logging.set`); the engine sends it again after a reconnect.
  Future<void> _sendLogging(SettingsState settings) async {
    final until = DateTime.tryParse(settings.logUntil);
    try {
      await ref.read(engineProvider).setLogging(settings.activeLogLevel(), until: until);
    } catch (_) {
      // An older core cannot change its level; the settings page shows what it reports.
    }
    if (ref.mounted) ref.invalidate(loggingModeProvider);
  }

  /// The setting turns itself off when its time is up (the core does the same on its own).
  void _scheduleLoggingEnd(SettingsState settings) {
    _loggingEnd?.cancel();
    final until = DateTime.tryParse(settings.logUntil);
    if (settings.logLevel.isEmpty || until == null) return;
    _loggingEnd = Timer(until.difference(DateTime.now()), () {
      if (ref.mounted) update((s) => s.copyWith(logLevel: '', logUntil: ''));
    });
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
