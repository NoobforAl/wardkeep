import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import 'providers.dart';

/// How much data went through one server (config), counted by this app on this device.
class ProfileUsage {
  const ProfileUsage({this.up = 0, this.down = 0, this.since});

  final int up;
  final int down;

  /// When counting started (the first byte), for "since …" text.
  final DateTime? since;

  int get total => up + down;

  ProfileUsage plus(int dUp, int dDown, DateTime now) =>
      ProfileUsage(up: up + dUp, down: down + dDown, since: since ?? now);

  Map<String, dynamic> toJson() => {'up': up, 'down': down, if (since != null) 'since': since!.toIso8601String()};

  factory ProfileUsage.fromJson(Map<String, dynamic> j) => ProfileUsage(
        up: (j['up'] as num?)?.toInt() ?? 0,
        down: (j['down'] as num?)?.toInt() ?? 0,
        since: DateTime.tryParse(j['since'] as String? ?? ''),
      );
}

/// Turns the tunnel's running byte counters (which restart with every connection) into amounts to add to
/// a server's total. Pure, so it can be tested without an engine.
class UsageMeter {
  int _up = 0, _down = 0;
  String? _id;

  /// Feed every engine state; returns what to add to which server, or null.
  /// The first state of a connection only sets the starting point (up to a second of traffic is not
  /// counted), so that attaching to a tunnel that has been running a while does not count its past twice;
  /// the same after the selected server changed in a running tunnel. A counter that went back means a new
  /// tunnel started, and everything it counted so far is new.
  ({String id, int up, int down})? feed(EngineState s) {
    final id = s.activeProfileId;
    if (s.status != ConnStatus.connected || id == null || id == 'auto') {
      _id = null;
      _up = _down = 0;
      return null;
    }
    if (_id != id) {
      _id = id;
      _up = s.upTotal;
      _down = s.downTotal;
      return null;
    }
    final dUp = s.upTotal >= _up ? s.upTotal - _up : s.upTotal;
    final dDown = s.downTotal >= _down ? s.downTotal - _down : s.downTotal;
    _up = s.upTotal;
    _down = s.downTotal;
    if (dUp == 0 && dDown == 0) return null;
    return (id: id, up: dUp, down: dDown);
  }
}

/// Data used per server, remembered across restarts. The tunnel's counters are global, so a connection made
/// with "Automatic" is not counted for any one server.
class UsageController extends Notifier<Map<String, ProfileUsage>> {
  static const _key = 'usage';
  static const _saveEvery = Duration(seconds: 15);

  final _meter = UsageMeter();
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);
  bool _dirty = false;

  @override
  Map<String, ProfileUsage> build() {
    ref.listen(connectionProvider, (prev, next) {
      final add = _meter.feed(next);
      if (add != null) {
        final now = DateTime.now();
        state = {...state, add.id: (state[add.id] ?? const ProfileUsage()).plus(add.up, add.down, now)};
        _dirty = true;
        if (now.difference(_saved) >= _saveEvery) _flush(now);
      } else if (_dirty && next.status != ConnStatus.connected) {
        _flush(DateTime.now());
      }
    });
    ref.onDispose(() {
      if (_dirty) _flush(DateTime.now());
    });
    final saved = ref.read(storeProvider).read<Map<String, dynamic>>(_key) ?? const {};
    return {
      for (final e in saved.entries)
        if (e.value is Map) e.key: ProfileUsage.fromJson(Map<String, dynamic>.from(e.value as Map)),
    };
  }

  void _flush(DateTime now) {
    _saved = now;
    _dirty = false;
    ref.read(storeProvider).write(_key, {for (final e in state.entries) e.key: e.value.toJson()});
  }

  /// Starts counting a server from zero again.
  void reset(String id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
    _flush(DateTime.now());
  }
}

final profileUsageProvider = NotifierProvider<UsageController, Map<String, ProfileUsage>>(UsageController.new);

/// Bytes the app has counted for one server (0 when nothing yet).
final usageOfProvider = Provider.family<int, String>((ref, id) => ref.watch(profileUsageProvider.select((m) => m[id]?.total ?? 0)));
