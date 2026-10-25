import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'daemon_engine.dart';
import 'engine.dart';
import 'mock_engine.dart';

/// Engine used by the app: starts the real core and forwards to it.
/// Desktop launches the omnitun-svc daemon; Android starts the core inside the
/// app process (core/mobile) via the "omnitun/core" channel.
///
/// The control connection can drop (Android freezes background apps, a
/// daemon can crash), so it reconnects automatically and only reports an
/// error if that keeps failing. Falls back to [MockEngine] when no core can be
/// started at all, logging why.
class CoreEngine implements VpnEngine {
  /// [serviceControlFile] and [localControlFile] override where the Windows
  /// service's and the per-user daemon's control files are (tests).
  CoreEngine({this._serviceControlFile, this._localControlFile}) {
    _ready = _start();
  }

  static const _channel = MethodChannel('omnitun/core');
  static const _retryDelays = [
    Duration(milliseconds: 200),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  late Future<VpnEngine> _ready;
  VpnEngine? _inner;
  bool _disposed = false;
  final _states = StreamController<EngineState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  final String? _serviceControlFile;
  final String? _localControlFile;
  // Windows: the per-user daemon and, when installed, the SYSTEM service.
  DaemonEngine? _local;
  DaemonEngine? _service;
  final _watched = <DaemonEngine>{};
  EngineState _last = const EngineState();

  /// True while the Windows service carries the connection (VPN mode without
  /// administrator rights).
  bool get usingService {
    final e = _inner;
    return e is DaemonEngine && e.isService;
  }

  Future<VpnEngine> _start() async {
    VpnEngine engine;
    try {
      engine = await _connectCore(reconnect: false);
    } catch (e) {
      _logs.add('core unavailable, using preview engine: $e');
      engine = MockEngine();
    }
    _adopt(engine);
    return engine;
  }

  Future<DaemonEngine> _connectCore({required bool reconnect}) async {
    if (Platform.isAndroid) {
      final info = jsonDecode(await _channel.invokeMethod<String>('start') ?? '{}') as Map<String, dynamic>;
      final engine = await DaemonEngine.attachTo(info['addr'] as String, info['token'] as String);
      if (!reconnect) unawaited(_channel.invokeMethod<void>('requestNotifications'));
      return engine;
    }
    if (Platform.isIOS) throw UnsupportedError('iOS core bridge is not implemented yet');
    if (reconnect) {
      // The daemon may still be running; otherwise start a new one.
      try {
        return await DaemonEngine.attach(controlFile: _localControlFile);
      } catch (_) {}
    }
    final exe = findDaemonExecutable();
    if (exe == null) {
      throw StateError('omnitun-svc not found (build it with scripts/go.ps1 build -o bin/ ./cmd/...)');
    }
    return DaemonEngine.launch(exe, controlFile: _localControlFile);
  }

  void _adopt(VpnEngine engine) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs
      ..clear()
      ..add(engine.states.listen((s) {
        _last = s;
        _states.add(s);
      }))
      ..add(engine.logs.listen(_logs.add));
    _inner = engine;
    if (engine is DaemonEngine) {
      if (engine.isService) {
        _service = engine;
      } else {
        _local = engine;
      }
      // One watcher per connection, and only the engine in use is replaced.
      if (_watched.add(engine)) {
        unawaited(engine.closed.then((_) {
          _watched.remove(engine);
          if (!_disposed && identical(_inner, engine)) _ready = _reconnect();
        }));
      }
    }
  }

  /// Windows: VPN mode runs in the service when one is installed and lets this
  /// user in, so the app needs no administrator rights; everything else runs in
  /// the per-user daemon (the service has no desktop session, so it cannot set
  /// the system proxy, and without a service nothing changes). A tunnel is
  /// never left running in the engine that is switched away from.
  Future<void> _chooseEngine(bool vpnMode) async {
    final current = await _ready;
    DaemonEngine? target;
    if (vpnMode) {
      var svc = _service;
      if (svc == null || svc.isClosed) {
        svc = _service = await DaemonEngine.attachService(controlFile: _serviceControlFile);
      }
      target = svc;
    } else if (current is DaemonEngine && current.isService) {
      var local = _local;
      if (local == null || local.isClosed) local = _local = await _connectCore(reconnect: true);
      target = local;
    }
    if (target == null || identical(target, current)) return;
    if (_last.status != ConnStatus.disconnected && _last.status != ConnStatus.error) {
      await current.disconnect();
    }
    _ready = Future.value(target);
    _adopt(target);
  }

  Future<VpnEngine> _reconnect() async {
    for (var attempt = 0;; attempt++) {
      await Future<void>.delayed(_retryDelays[attempt.clamp(0, _retryDelays.length - 1)]);
      if (_disposed) throw StateError('disposed');
      try {
        final engine = await _connectCore(reconnect: true);
        _adopt(engine);
        _logs.add('reconnected to the core');
        return engine;
      } catch (e) {
        if (attempt == 2) {
          _states.add(const EngineState(status: ConnStatus.error, error: 'Lost connection to the core service', errorCode: 'CORE_LOST'));
        }
        _logs.add('reconnect failed: $e');
      }
    }
  }

  /// Looks for the daemon next to the app, via OMNITUN_SVC, or in the repo's bin/ (development).
  static String? findDaemonExecutable() {
    final name = Platform.isWindows ? 'omnitun-svc.exe' : 'omnitun-svc';
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      ?Platform.environment['OMNITUN_SVC'],
      '${File(Platform.resolvedExecutable).parent.path}$sep$name',
    ];
    var dir = Directory.current;
    for (var i = 0; i < 4; i++) {
      candidates.add('${dir.path}${sep}bin$sep$name');
      dir = dir.parent;
    }
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  @override
  String get name => _inner?.name ?? 'starting…';

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<String> get logs => _logs.stream;

  @override
  Future<void> connect(
    ProfileInfo profile, {
    List<ProfileInfo> fallbacks = const [],
    ConnectOptions options = const ConnectOptions(),
  }) async {
    if (Platform.isWindows) await _chooseEngine(options.tunMode);
    final engine = await _ready;
    if (Platform.isAndroid && options.tunMode && engine is DaemonEngine) {
      // The system consent dialog must be accepted before the core can open a TUN.
      const permission = ConnectProgress('permission', 5);
      _states.add(EngineState(status: ConnStatus.connecting, activeProfileId: profile.id, progress: permission));
      // IKEv2 on the system's own client has its own consent dialog.
      final bool granted;
      try {
        granted = profile.protocol == 'ikev2' && (profile.raw['ikev2'] as Map?)?['system'] == true
            ? await _channel.invokeMethod<bool>('prepareIkev2', jsonEncode(profile.raw)) ?? false
            : await _channel.invokeMethod<bool>('prepareVpn') ?? false;
      } on PlatformException catch (e) {
        _states.add(EngineState(
          status: ConnStatus.error,
          activeProfileId: profile.id,
          error: e.message ?? e.code,
          progress: permission,
        ));
        return;
      }
      if (!granted) {
        _states.add(EngineState(
          status: ConnStatus.error,
          activeProfileId: profile.id,
          error: 'VPN permission was not granted',
          errorCode: 'NO_PERMISSION',
          progress: permission,
        ));
        return;
      }
    }
    if (Platform.isAndroid && options.tunMode) {
      // Android's "Always-on VPN" restarts the tunnel by itself, with this request.
      try {
        await _channel.invokeMethod<void>('saveLastConnect', jsonEncode(DaemonEngine.startParams(profile, fallbacks, options)));
      } on PlatformException {
        // Only always-on VPN loses out.
      }
    }
    return engine.connect(profile, fallbacks: fallbacks, options: options);
  }

  @override
  Future<void> disconnect() async => (await _ready).disconnect();

  @override
  Future<ImportResult> importText(String text) async => (await _ready).importText(text);

  @override
  Future<int> testLatency(ProfileInfo profile) async => (await _ready).testLatency(profile);

  @override
  Future<List<ProtocolFormSpec>> forms() async => (await _ready).forms();

  @override
  Future<ProfileInfo> buildProfile(Map<String, String> values, {String? protocol, ProfileInfo? profile}) async =>
      (await _ready).buildProfile(values, protocol: protocol, profile: profile);

  @override
  Future<ExitInfo> exitInfo() async => (await _ready).exitInfo();

  @override
  Future<MeshStatus> meshStatus() async => (await _ready).meshStatus();

  @override
  Future<MeshStatus> setMeshExit(String id) async => (await _ready).setMeshExit(id);

  @override
  Future<BypassReport> parseBypass(String text) async => (await _ready).parseBypass(text);

  @override
  Future<Map<String, String>> profileValues(ProfileInfo profile) async => (await _ready).profileValues(profile);

  @override
  Future<List<WarningSpec>> warnings(ProfileInfo profile) async => (await _ready).warnings(profile);

  @override
  Future<String> exportLink(ProfileInfo profile) async => (await _ready).exportLink(profile);

  @override
  Future<SubscriptionResult> fetchSubscription(Map<String, dynamic> request) async =>
      (await _ready).fetchSubscription(request);

  @override
  Future<void> setStopOnClose(bool value) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('setStopOnClose', value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _inner?.dispose();
    for (final e in [_local, _service]) {
      if (e != null && !identical(e, _inner)) e.dispose();
    }
    _states.close();
    _logs.close();
  }
}
