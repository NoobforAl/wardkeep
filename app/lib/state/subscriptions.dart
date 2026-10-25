import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import '../l10n/app_localizations.dart';
import '../l10n/errors.dart';
import 'providers.dart';

/// How a subscription request authenticates (mirrors core/subscription.Auth).
class SubscriptionAuth {
  const SubscriptionAuth({
    this.type = 'none',
    this.username = '',
    this.password = '',
    this.token = '',
    this.header = '',
    this.queryKey = '',
  });

  /// none, basic, bearer, header or query.
  final String type;
  final String username;
  final String password;
  final String token;
  final String header;
  final String queryKey;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (username.isNotEmpty) 'username': username,
        if (password.isNotEmpty) 'password': password,
        if (token.isNotEmpty) 'token': token,
        if (header.isNotEmpty) 'header': header,
        if (queryKey.isNotEmpty) 'query_key': queryKey,
      };

  factory SubscriptionAuth.fromJson(Map<String, dynamic> j) => SubscriptionAuth(
        type: j['type'] as String? ?? 'none',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        token: j['token'] as String? ?? '',
        header: j['header'] as String? ?? '',
        queryKey: j['query_key'] as String? ?? '',
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.auth = const SubscriptionAuth(),
    this.info = const SubscriptionInfo(),
    this.updatedAt,
    this.lastError,
    this.lastErrorCode,
    this.lastErrorArgs = const {},
    this.via = defaultVia,
    this.fallbackUrls = const [],
    this.publicKey = '',
  });

  /// Other addresses of the same subscription, tried in order when [url] cannot be reached.
  final List<String> fallbackUrls;

  /// The provider's public signing key (base64). When set, every answer must carry a valid signature.
  final String publicKey;

  /// Whether [s] is a public key: 32 bytes as base64 (standard or URL-safe, padded or not).
  static bool isValidKey(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    for (final codec in [base64, base64Url]) {
      try {
        if (codec.decode(codec.normalize(t)).length == 32) return true;
      } on FormatException {
        // not this alphabet
      }
    }
    return false;
  }

  /// Splits the signing key off a subscription link: a provider's link carries it after "#pk=".
  /// Returns the link without it, and the key ('' when there is none).
  static (String url, String key) splitKey(String link) {
    final at = link.indexOf('#');
    if (at < 0) return (link, '');
    final frag = link.substring(at + 1);
    for (final part in frag.split('&')) {
      if (part.startsWith('pk=')) return (link.substring(0, at), Uri.decodeComponent(part.substring(3)));
    }
    return (link, '');
  }

  /// Download directly, and through the VPN when that fails and the VPN is up.
  static const defaultVia = 'auto';

  final String id;
  final String name;
  final String url;
  final SubscriptionAuth auth;
  final SubscriptionInfo info;
  final DateTime? updatedAt;
  final String? lastError;

  /// The core's code and values for [lastError], so it can be shown in the user's language.
  final String? lastErrorCode;
  final Map<String, String> lastErrorArgs;

  /// [lastError] in the language of the app.
  String lastErrorText(AppLocalizations l) =>
      (lastErrorCode == null ? null : translateCode(l, lastErrorCode!, lastErrorArgs)) ?? '$lastError';

  /// How it is downloaded: 'direct', 'auto' (through the VPN when direct fails and the VPN is up)
  /// or 'tunnel' (always through the VPN, for providers that are blocked).
  final String via;

  /// The provider's interval, or once a day.
  Duration get refreshInterval =>
      Duration(hours: info.updateIntervalHours > 0 ? info.updateIntervalHours : 24);

  bool get isDue => updatedAt == null || DateTime.now().difference(updatedAt!) >= refreshInterval;

  Map<String, dynamic> toRequest() => {
        'url': url,
        'auth': auth.toJson(),
        if (via != 'direct') 'via': via,
        if (fallbackUrls.isNotEmpty) 'fallback_urls': fallbackUrls,
        if (publicKey.isNotEmpty) 'public_key': publicKey,
        // An answer signed before the last accepted one is a replay of an old list.
        if (publicKey.isNotEmpty && info.signedAt > 0) 'not_before': info.signedAt,
      };

  Subscription copyWith({
    String? name,
    String? url,
    SubscriptionAuth? auth,
    SubscriptionInfo? info,
    DateTime? updatedAt,
    String? lastError,
    String? lastErrorCode,
    Map<String, String>? lastErrorArgs,
    String? via,
    List<String>? fallbackUrls,
    String? publicKey,
    bool clearError = false,
  }) =>
      Subscription(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        auth: auth ?? this.auth,
        info: info ?? this.info,
        updatedAt: updatedAt ?? this.updatedAt,
        lastError: clearError ? null : lastError ?? this.lastError,
        lastErrorCode: clearError ? null : (lastError != null ? lastErrorCode : this.lastErrorCode),
        lastErrorArgs: clearError ? const {} : (lastError != null ? (lastErrorArgs ?? const {}) : this.lastErrorArgs),
        via: via ?? this.via,
        fallbackUrls: fallbackUrls ?? this.fallbackUrls,
        publicKey: publicKey ?? this.publicKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'auth': auth.toJson(),
        'info': info.toJson(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (lastError != null) 'last_error': lastError,
        if (lastErrorCode != null) 'last_error_code': lastErrorCode,
        if (lastErrorArgs.isNotEmpty) 'last_error_args': lastErrorArgs,
        'via': via,
        if (fallbackUrls.isNotEmpty) 'fallback_urls': fallbackUrls,
        if (publicKey.isNotEmpty) 'public_key': publicKey,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        auth: SubscriptionAuth.fromJson(Map<String, dynamic>.from(j['auth'] as Map? ?? const {})),
        info: SubscriptionInfo.fromJson(Map<String, dynamic>.from(j['info'] as Map? ?? const {})),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
        lastError: j['last_error'] as String?,
        lastErrorCode: j['last_error_code'] as String?,
        lastErrorArgs: {for (final e in (j['last_error_args'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
        via: j['via'] as String? ?? defaultVia,
        fallbackUrls: [for (final u in (j['fallback_urls'] as List? ?? const [])) '$u'],
        publicKey: j['public_key'] as String? ?? '',
      );
}

/// The countries the device is set up for (its language settings, upper-case codes), best first.
List<String> deviceCountries() => [
      for (final l in PlatformDispatcher.instance.locales)
        if ((l.countryCode ?? '').isNotEmpty) l.countryCode!.toUpperCase(),
    ];

/// The profiles of [result] in the order the provider asked for. The provider's order counts only on a
/// verified answer (the core drops it otherwise); a country's own order wins over the general one, and
/// protocols it does not name keep their place after those it does.
List<ProfileInfo> orderedByProvider(SubscriptionResult result, {List<String>? countries}) {
  final order = result.info.protocolOrder;
  if (!result.info.verified || order.isEmpty) return result.profiles;
  List<String>? wanted;
  for (final c in countries ?? deviceCountries()) {
    wanted = order[c.toUpperCase()];
    if (wanted != null) break;
  }
  final list = wanted ?? order[''];
  if (list == null || list.isEmpty) return result.profiles;
  int rank(ProfileInfo p) {
    final i = list.indexOf(p.protocol);
    return i < 0 ? list.length : i;
  }

  final indexed = [for (var i = 0; i < result.profiles.length; i++) (i, result.profiles[i])];
  indexed.sort((a, b) {
    final c = rank(a.$2).compareTo(rank(b.$2));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Subscriptions, persisted. Each one owns the profiles in the group with its ID.
class SubscriptionsController extends Notifier<List<Subscription>> {
  static const _key = 'subscriptions';
  final _refreshing = <String>{};

  @override
  List<Subscription> build() {
    final saved = ref.read(storeProvider).read<List<dynamic>>(_key) ?? const [];
    return [
      for (final s in saved)
        if (s is Map) Subscription.fromJson(Map<String, dynamic>.from(s)),
    ];
  }

  void _save(List<Subscription> next) {
    state = next;
    ref.read(storeProvider).write(_key, [for (final s in next) s.toJson()]);
  }

  void _put(Subscription sub) => _save([for (final s in state) s.id == sub.id ? sub : s]);

  bool isRefreshing(String id) => _refreshing.contains(id);

  /// Fetches a new subscription and keeps it only if the fetch works.
  /// Returns the number of profiles; throws with a user-facing message.
  Future<int> add({
    required String url,
    String name = '',
    SubscriptionAuth auth = const SubscriptionAuth(),
    String via = Subscription.defaultVia,
    List<String> fallbackUrls = const [],
    String publicKey = '',
  }) async {
    final id = 'sub-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    // A provider's link carries its signing key after "#pk="; take it from there when none was typed.
    final (clean, linkKey) = Subscription.splitKey(url.trim());
    final draft = Subscription(
      id: id,
      name: name,
      url: clean,
      auth: auth,
      via: via,
      fallbackUrls: fallbackUrls,
      publicKey: publicKey.trim().isNotEmpty ? publicKey.trim() : linkKey,
    );
    final result = await ref.read(engineProvider).fetchSubscription(draft.toRequest());
    final sub = draft.copyWith(
      name: name.isNotEmpty ? name : (result.info.title.isNotEmpty ? result.info.title : Uri.parse(draft.url).host),
      info: result.info,
      updatedAt: DateTime.now(),
    );
    _save([...state, sub]);
    ref.read(profilesProvider.notifier).replaceGroup(id, orderedByProvider(result));
    return result.profiles.length;
  }

  /// Re-downloads a subscription and replaces its profiles. Failures are
  /// recorded on the subscription (its profiles are kept) and rethrown.
  Future<int> refresh(String id) async {
    final sub = state.where((s) => s.id == id).firstOrNull;
    if (sub == null || !_refreshing.add(id)) return 0;
    state = [...state]; // let listeners show the spinner
    try {
      final result = await ref.read(engineProvider).fetchSubscription(sub.toRequest());
      ref.read(profilesProvider.notifier).replaceGroup(id, orderedByProvider(result));
      _put(sub.copyWith(info: result.info, updatedAt: DateTime.now(), clearError: true));
      return result.profiles.length;
    } catch (e) {
      _put(
        sub.copyWith(
          lastError: _message(e),
          lastErrorCode: e is EngineException ? e.code : null,
          lastErrorArgs: e is EngineException ? e.args : null,
        ),
      );
      rethrow;
    } finally {
      _refreshing.remove(id);
      state = [...state];
    }
  }

  /// Refreshes every subscription whose interval has passed; errors are recorded, not thrown.
  Future<void> refreshDue() async {
    for (final s in [...state]) {
      if (s.isDue) {
        try {
          await refresh(s.id);
        } catch (_) {}
      }
    }
  }

  void update(Subscription sub) => _put(sub);

  /// Starts the signature check over: the next answer is accepted whatever its time (the provider changed its
  /// key, or restored an old backup, which made its answers look older than the last one).
  void forgetSignature(String id) {
    final sub = state.where((s) => s.id == id).firstOrNull;
    if (sub != null) _put(sub.copyWith(info: sub.info.unsigned(), clearError: true));
  }

  void remove(String id) {
    _save(state.where((s) => s.id != id).toList());
    ref.read(profilesProvider.notifier).removeGroup(id);
  }

  static String _message(Object e) {
    final s = e.toString();
    return s.startsWith('Bad state: ') ? s.substring(11) : s;
  }
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsController, List<Subscription>>(SubscriptionsController.new);

/// Bytes as a short human string (KB, MB, GB).
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}
