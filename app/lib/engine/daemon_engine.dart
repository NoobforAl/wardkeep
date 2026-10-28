import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../state/dns_state.dart';
import 'engine.dart';

export 'engine.dart' show EngineException;

/// Talks to the omnitun-svc daemon over its loopback control protocol
/// (newline-delimited JSON, token-authenticated). See core/control.
///
/// The daemon is started as a child process with --parent-pid, so it stops the
/// tunnel and exits if this app dies; while connected, a ping keeps its lease.
class DaemonEngine implements VpnEngine {
  DaemonEngine._(this._socket, this._process);

  final Socket _socket;
  final Process? _process;
  final _states = StreamController<EngineState>.broadcast();
  final _logs = StreamController<LogRecord>.broadcast();
  final _pending = <int, Completer<dynamic>>{};
  int _nextId = 0;
  Timer? _ping;
  EngineState _state = const EngineState();

  /// Launches [executable] and connects to it.
  static Future<DaemonEngine> launch(String executable, {String? controlFile}) async {
    final process = await Process.start(executable, [
      '--parent-pid',
      '$pid',
      if (controlFile != null) ...['--control-file', controlFile],
    ]);
    final ready = Completer<String>();
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.startsWith('READY ') && !ready.isCompleted) ready.complete(line.substring(6).trim());
    });
    process.stderr.transform(utf8.decoder).listen((_) {});
    unawaited(process.exitCode.then((code) {
      if (!ready.isCompleted) ready.completeError(StateError('omnitun-svc exited with code $code'));
    }));
    await ready.future.timeout(const Duration(seconds: 15));
    final file = controlFile ?? defaultControlFile();
    final control = jsonDecode(await File(file).readAsString()) as Map<String, dynamic>;
    return _connect(control['addr'] as String, control['token'] as String, process);
  }

  /// Connects to an already running daemon (e.g. the Windows service).
  static Future<DaemonEngine> attach({String? controlFile}) async {
    final control =
        jsonDecode(await File(controlFile ?? defaultControlFile()).readAsString()) as Map<String, dynamic>;
    return _connect(control['addr'] as String, control['token'] as String, null);
  }

  /// The control file of the Windows service (`omnitun-svc` running as SYSTEM,
  /// see core/winsvc): `%ProgramData%\omnitun\control\control.json`. The
  /// service makes its directory readable only by the accounts named at
  /// install time, so for any other user the file simply cannot be read.
  /// Null off Windows.
  static String? serviceControlFile([Map<String, String>? env]) {
    if (!Platform.isWindows && env == null) return null;
    final environment = env ?? Platform.environment;
    final programData = environment['ProgramData'] ?? r'C:\ProgramData';
    return '$programData\\omnitun\\control\\control.json';
  }

  /// Connects to the Windows service when it is installed, running and lets
  /// this user in; null in every other case (no file, a stale file, a wrong
  /// token, not readable), so the caller keeps using its own daemon.
  static Future<DaemonEngine?> attachService({String? controlFile}) async {
    final file = controlFile ?? serviceControlFile();
    if (file == null || !File(file).existsSync()) return null;
    try {
      final engine = await attach(controlFile: file);
      engine.isService = true;
      return engine;
    } catch (_) {
      return null;
    }
  }

  /// True for the Windows service (it runs as SYSTEM: VPN mode needs no admin
  /// rights, but it has no desktop session, so no system proxy).
  bool isService = false;

  /// True once the control connection is lost.
  bool get isClosed => _closed.isCompleted;

  /// Connects to a core whose address and token are already known (Android in-process core).
  static Future<DaemonEngine> attachTo(String addr, String token) => _connect(addr, token, null);

  static Future<DaemonEngine> _connect(String addr, String token, Process? process) async {
    final colon = addr.lastIndexOf(':');
    final socket = await Socket.connect(addr.substring(0, colon), int.parse(addr.substring(colon + 1)),
        timeout: const Duration(seconds: 5));
    final engine = DaemonEngine._(socket, process);
    engine._listen();
    final hello = await engine._call('hello', {'token': token}) as Map<String, dynamic>;
    engine._applyState(hello['state'] as Map<String, dynamic>);
    engine._ping = Timer.periodic(const Duration(seconds: 4), (_) => engine._call('ping').ignore());
    return engine;
  }

  static String defaultControlFile() {
    final base = Platform.isWindows
        ? Platform.environment['APPDATA']!
        : Platform.isMacOS
            ? '${Platform.environment['HOME']}/Library/Application Support'
            : Platform.environment['XDG_CONFIG_HOME'] ?? '${Platform.environment['HOME']}/.config';
    return '$base${Platform.pathSeparator}omnitun${Platform.pathSeparator}control.json';
  }

  void _listen() {
    _socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      _onLine,
      onDone: _onClosed,
      onError: (_) => _onClosed(),
    );
  }

  void _onLine(String line) {
    final msg = jsonDecode(line) as Map<String, dynamic>;
    final event = msg['event'] as String?;
    if (event == 'state') {
      _applyState(msg['data'] as Map<String, dynamic>);
    } else if (event == 'log') {
      _logs.add(LogRecord.fromJson(msg['data'] as Map<String, dynamic>));
    } else if (msg.containsKey('id')) {
      final completer = _pending.remove(msg['id']);
      if (completer == null) return;
      final err = msg['error'] as Map<String, dynamic>?;
      if (err != null) {
        completer.completeError(
          EngineException(
            err['code'] as String,
            err['message'] as String,
            {for (final e in (err['args'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
          ),
        );
      } else {
        completer.complete(msg['result']);
      }
    }
  }

  void _onClosed() {
    if (_closed.isCompleted) return;
    for (final completer in _pending.values) {
      completer.completeError(EngineException('DISCONNECTED', 'lost connection to the core'));
    }
    _pending.clear();
    _ping?.cancel();
    // CoreEngine reconnects; it reports an error only if that keeps failing.
    _closed.complete();
  }

  final _closed = Completer<void>();

  /// Completes when the control connection is lost.
  Future<void> get closed => _closed.future;

  Future<dynamic> _call(String method, [Object? params]) {
    if (_closed.isCompleted) {
      return Future.error(EngineException('DISCONNECTED', 'lost connection to the core'));
    }
    final id = ++_nextId;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _socket.write('${jsonEncode({'id': id, 'method': method, 'params': ?params})}\n');
    return completer.future;
  }

  void _emit(EngineState next) {
    _state = next;
    _states.add(next);
  }

  void _applyState(Map<String, dynamic> raw) {
    final status = switch (raw['status']) {
      // Still connected, but the device itself has no internet.
      'connected' when raw['no_network'] == true => ConnStatus.noInternet,
      'connected' => ConnStatus.connected,
      'connecting' => ConnStatus.connecting,
      'error' => ConnStatus.error,
      _ => ConnStatus.disconnected,
    };
    final since = raw['since'] as String?;
    final selected = raw['selected'] as String?;
    final failover = raw['failover'] as Map<String, dynamic>?;
    final progress = raw['progress'] as Map<String, dynamic>?;
    _emit(EngineState(
      status: status,
      activeProfileId: selected ?? _state.activeProfileId,
      connectedSince: since == null ? null : DateTime.parse(since).toLocal(),
      error: raw['error'] as String?,
      errorCode: raw['error_code'] as String?,
      upBps: (raw['up_bps'] as num?)?.toInt() ?? 0,
      downBps: (raw['down_bps'] as num?)?.toInt() ?? 0,
      upTotal: (raw['up_total'] as num?)?.toInt() ?? 0,
      downTotal: (raw['down_total'] as num?)?.toInt() ?? 0,
      failover: failover == null
          ? null
          : FailoverInfo(
              from: failover['from'] as String,
              to: failover['to'] as String,
              reason: failover['reason'] as String,
              at: DateTime.parse(failover['at'] as String).toLocal(),
            ),
      progress: progress == null ? null : ConnectProgress.fromJson(progress),
      torPath: [
        for (final hop in (raw['tor_path'] as List<dynamic>? ?? const []))
          TorHop(role: (hop as Map<String, dynamic>)['role'] as String, country: hop['country'] as String?),
      ],
    ));
  }

  @override
  String get name => 'omnitun core (sing-box)';

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<LogRecord> get logs => _logs.stream;

  @override
  Future<LoggingMode> loggingMode() async =>
      LoggingMode.fromJson(await _call('logging.get') as Map<String, dynamic>? ?? const {});

  @override
  Future<void> setLogging(String level, {DateTime? until}) async {
    await _call('logging.set', {
      'level': level,
      if (until != null) 'until': DateTime.fromMillisecondsSinceEpoch(until.millisecondsSinceEpoch, isUtc: true).toIso8601String(),
    });
  }

  /// The core's "start" request for a connection.
  static Map<String, dynamic> startParams(ProfileInfo profile, List<ProfileInfo> fallbacks, ConnectOptions options) => {
    'profiles': [profile.raw, for (final f in fallbacks) f.raw],
    'selected': profile.id,
    'mode': options.tunMode ? 'tun' : 'proxy',
    'listen_port': options.listenPort,
    'system_proxy': options.systemProxy,
    if (options.dns.isNotEmpty) 'dns': options.dns,
    if (options.dnsRelay.isNotEmpty && isDnsCryptStamp(options.dns)) 'dns_relay': options.dnsRelay,
    'failover': options.autoFailover,
    if (!options.bypassLan) 'proxy_private': true,
    if (options.includePackages.isNotEmpty) 'include_packages': options.includePackages,
    if (options.excludePackages.isNotEmpty) 'exclude_packages': options.excludePackages,
    if (options.bypass.isNotEmpty) 'bypass': options.bypass,
    if (options.bypass.isNotEmpty && options.bypassOnly) 'bypass_only': true,
    if (options.killSwitch && options.tunMode) 'kill_switch': true,
    if (options.killSwitch && options.tunMode && options.killSwitchEarly) 'kill_switch_early': true,
    if (!options.ipv6) 'no_ipv6': true,
    if (options.mtu > 0) 'mtu': options.mtu,
  };

  @override
  Future<void> connect(
    ProfileInfo profile, {
    List<ProfileInfo> fallbacks = const [],
    ConnectOptions options = const ConnectOptions(),
  }) async {
    _emit(EngineState(status: ConnStatus.connecting, activeProfileId: profile.id));
    try {
      await _call('start', startParams(profile, fallbacks, options));
    } on EngineException catch (e) {
      _emit(EngineState(
        status: e.code == 'NO_NETWORK' ? ConnStatus.noInternet : ConnStatus.error,
        activeProfileId: profile.id,
        error: e.message,
      ));
    }
  }

  @override
  Future<void> disconnect() async {
    _emit(_state.copyWith(status: ConnStatus.disconnecting));
    await _call('stop');
  }

  @override
  Future<ImportResult> importText(String text) async {
    try {
      final res = await _call('import', {'text': text}) as Map<String, dynamic>;
      final profiles = [
        for (final p in (res['profiles'] as List? ?? const [])) ProfileInfo.fromJson(p as Map<String, dynamic>),
      ];
      final errors = [for (final e in (res['errors'] as List? ?? const [])) e as String];
      return ImportResult(profiles, errors);
    } on EngineException catch (e) {
      // The core sends the reasons for the entries that failed one per line; without any, its own message.
      final details = (e.args['details'] ?? '').split('\n').where((l) => l.isNotEmpty).toList();
      return ImportResult(const [], details.isEmpty ? [e.message] : details, failure: e);
    }
  }

  @override
  Future<SubscriptionResult> fetchSubscription(Map<String, dynamic> request) async {
    final res = await _call('subscribe', request) as Map<String, dynamic>;
    return SubscriptionResult(
      [for (final p in (res['profiles'] as List? ?? const [])) ProfileInfo.fromJson(p as Map<String, dynamic>)],
      [for (final e in (res['errors'] as List? ?? const [])) e as String],
      SubscriptionInfo.fromJson(res['info'] as Map<String, dynamic>? ?? const {}),
    );
  }

  @override
  Future<int> testLatency(ProfileInfo profile) async {
    final res = await _call('test', {
      'profiles': [profile.raw],
    }) as List;
    return ((res.first as Map<String, dynamic>)['ms'] as num).toInt();
  }

  @override
  Future<List<ProtocolFormSpec>> forms() async => [
    for (final f in await _call('forms') as List) ProtocolFormSpec.fromJson(f as Map<String, dynamic>),
  ];

  @override
  Future<ProfileInfo> buildProfile(Map<String, String> values, {String? protocol, ProfileInfo? profile}) async {
    final res = await _call('build_profile', {
      'values': values,
      if (profile != null) 'profile': profile.raw else 'protocol': protocol,
    });
    return ProfileInfo.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<ExitInfo> exitInfo() async => ExitInfo.fromJson(await _call('exit_info') as Map<String, dynamic>);

  @override
  Future<MeshStatus> meshStatus() async => MeshStatus.fromJson(await _call('mesh_status') as Map<String, dynamic>);

  @override
  Future<MeshStatus> setMeshExit(String id) async =>
      MeshStatus.fromJson(await _call('mesh_exit', {'id': id}) as Map<String, dynamic>);

  @override
  Future<BypassReport> parseBypass(String text) async =>
      BypassReport.fromJson(await _call('parse_bypass', {'text': text}) as Map<String, dynamic>);

  @override
  Future<Map<String, String>> profileValues(ProfileInfo profile) async {
    final res = await _call('profile_values', {'profile': profile.raw}) as Map<String, dynamic>;
    return {for (final e in res.entries) e.key: e.value as String};
  }

  @override
  Future<List<WarningSpec>> warnings(ProfileInfo profile) async => [
    for (final w in await _call('warnings', {'profile': profile.raw}) as List)
      WarningSpec.fromJson(w as Map<String, dynamic>),
  ];

  @override
  Future<List<ResolverScanResult>> scanResolvers({
    required String domain,
    required String pubKey,
    List<String> resolvers = const [],
  }) async => [
    for (final r in await _call('dnstt_scan', {
      'domain': domain,
      'pubkey': pubKey,
      if (resolvers.isNotEmpty) 'resolvers': resolvers,
    }) as List)
      ResolverScanResult.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<String> exportLink(ProfileInfo profile) async =>
      await _call('export_link', {'profile': profile.raw}) as String;

  /// Desktop: the daemon follows the app's lifetime (lease + parent-pid).
  @override
  Future<void> setStopOnClose(bool value) async {}

  @override
  void dispose() {
    _ping?.cancel();
    _socket.destroy();
    _process?.kill();
    _states.close();
    _logs.close();
  }
}
