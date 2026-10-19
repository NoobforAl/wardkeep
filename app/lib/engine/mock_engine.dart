import 'dart:async';
import 'dart:math';

import 'engine.dart';

/// Simulated engine for UI development until libcore is wired in.
class MockEngine implements VpnEngine {
  MockEngine({this.connectDelay = const Duration(milliseconds: 1200)});

  final Duration connectDelay;

  /// The Tor circuit a connected Tor profile reports (for tests and the preview).
  List<TorHop> torPath = const [];
  final _states = StreamController<EngineState>.broadcast();
  final _logs = StreamController<String>.broadcast();
  final _rng = Random();
  EngineState _state = const EngineState();
  Timer? _traffic;

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<String> get logs => _logs.stream;

  void _emit(EngineState s) {
    _state = s;
    _states.add(s);
  }

  void _log(String line) => _logs.add('${DateTime.now().toIso8601String().substring(11, 19)}  $line');

  @override
  String get name => 'preview (mock)';

  @override
  Future<void> connect(
    ProfileInfo profile, {
    List<ProfileInfo> fallbacks = const [],
    ConnectOptions options = const ConnectOptions(),
  }) async {
    _log('connecting to ${profile.name} (${profile.protocol})');
    const stages = [
      ConnectProgress('network_check', 15),
      ConnectProgress('prepare', 25),
      ConnectProgress('engine_start', 45),
      ConnectProgress('tunnel_up', 65),
    ];
    for (final p in [...stages, ConnectProgress('handshake', 85, profile: profile.name)]) {
      _emit(EngineState(status: ConnStatus.connecting, activeProfileId: profile.id, progress: p));
      await Future<void>.delayed(connectDelay ~/ 5);
      if (_state.status != ConnStatus.connecting) return;
    }
    _emit(EngineState(
      status: ConnStatus.connected,
      activeProfileId: profile.id,
      connectedSince: DateTime.now(),
      progress: ConnectProgress('connected', 100, profile: profile.name),
      torPath: profile.protocol == 'tor' ? torPath : const [],
    ));
    _log('connected, health probe ok');
    _traffic?.cancel();
    _traffic = Timer.periodic(const Duration(seconds: 1), (_) {
      final up = _rng.nextInt(200000), down = _rng.nextInt(2000000);
      _emit(_state.copyWith(upBps: up, downBps: down, upTotal: _state.upTotal + up, downTotal: _state.downTotal + down));
    });
  }

  @override
  Future<void> disconnect() async {
    _traffic?.cancel();
    _emit(_state.copyWith(status: ConnStatus.disconnecting));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _emit(const EngineState());
    _log('disconnected');
  }

  @override
  Future<ImportResult> importText(String text) async {
    // Minimal parse so the UI flow works; the Go core does the real parsing.
    final profiles = <ProfileInfo>[];
    final errors = <String>[];
    for (final line in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      if (line.startsWith('tor://')) {
        final kind = line.substring(6).replaceAll('/', '');
        profiles.add(ProfileInfo.fromJson({
          'id': 'tor-$kind',
          'name': kind.isEmpty ? 'Tor' : 'Tor ($kind)',
          'protocol': 'tor',
          'server': '',
          'port': 0,
          'tor': {'builtin': kind},
        }));
        continue;
      }
      final uri = Uri.tryParse(line);
      if (uri == null || uri.host.isEmpty || !uri.hasPort) {
        errors.add(line);
        continue;
      }
      final protocol = switch (uri.scheme) {
        'hy2' => 'hysteria2',
        'ss' => 'shadowsocks',
        'wg' => 'wireguard',
        final s => s,
      };
      profiles.add(ProfileInfo(
        id: '${uri.scheme}-${uri.host}-${uri.port}-${profiles.length}',
        name: uri.fragment.isEmpty ? '${uri.host}:${uri.port}' : Uri.decodeComponent(uri.fragment),
        protocol: protocol,
        server: uri.host,
        port: uri.port,
      ));
    }
    return ImportResult(profiles, errors);
  }

  @override
  Future<SubscriptionResult> fetchSubscription(Map<String, dynamic> request) async =>
      throw StateError('Subscriptions need the Wardkeep core (not available in preview mode)');

  @override
  Future<int> testLatency(ProfileInfo profile) async {
    await Future<void>.delayed(Duration(milliseconds: 200 + _rng.nextInt(400)));
    return _rng.nextInt(10) == 0 ? -1 : 40 + _rng.nextInt(260);
  }

  @override
  Future<void> setStopOnClose(bool value) async {}

  @override
  Future<List<ProtocolFormSpec>> forms() async => const [
    ProtocolFormSpec(
      protocol: 'trojan',
      label: 'Trojan',
      fields: [
        FormFieldSpec(key: 'name', label: 'Name', kind: 'text'),
        FormFieldSpec(key: 'server', label: 'Server', kind: 'text', required: true),
        FormFieldSpec(key: 'port', label: 'Port', kind: 'int'),
        FormFieldSpec(key: 'password', label: 'Password', kind: 'secret', required: true),
        FormFieldSpec(key: 'tls.fingerprint', label: 'Fingerprint', kind: 'choice', choices: ['', 'chrome', 'firefox'], advanced: true),
      ],
    ),
    ProtocolFormSpec(
      protocol: 'tor',
      label: 'Tor',
      fields: [
        FormFieldSpec(key: 'name', label: 'Name', kind: 'text'),
        FormFieldSpec(key: 'tor.builtin', label: 'Bridges', kind: 'choice', choices: ['', 'snowflake', 'obfs4']),
        FormFieldSpec(key: 'tor.bridges', label: 'Bridge lines', kind: 'multiline'),
      ],
    ),
  ];

  @override
  Future<ProfileInfo> buildProfile(Map<String, String> values, {String? protocol, ProfileInfo? profile}) async {
    final merged = {...?profile?.raw, ...values};
    final p = protocol ?? profile!.protocol;
    for (final f in (await forms()).firstWhere((f) => f.protocol == p).fields) {
      if (f.required && (merged[f.key] ?? '').toString().trim().isEmpty) {
        throw EngineException('FORM_REQUIRED', '${f.label} is required', {'label': f.label});
      }
    }
    final server = (merged['server'] ?? '').toString();
    final port = int.tryParse((merged['port'] ?? '').toString()) ?? 443;
    final name = (merged['name'] ?? '').toString();
    return ProfileInfo.fromJson({
      ...?profile?.raw,
      ...values,
      'id': profile?.id ?? '$p-$server-$port',
      'name': name.isEmpty ? (server.isEmpty ? p : server) : name,
      'protocol': p,
      'server': server,
      'port': port,
    });
  }

  /// The mesh [meshStatus] answers while connected (tests change it): a small home network.
  MeshStatus mesh = MeshStatus(
    state: 'Running',
    network: 'home',
    domain: 'home.example',
    self: const MeshDevice(id: 's', name: 'phone', dnsName: 'phone.home.example', os: 'android', addresses: ['100.64.0.1'], online: true),
    devices: [
      const MeshDevice(
        id: 'a', name: 'home-pc', dnsName: 'home-pc.home.example', os: 'windows', addresses: ['100.64.0.2', 'fd7a::2'],
        online: true, exitOption: true, owner: 'Alice',
      ),
      const MeshDevice(id: 'b', name: 'laptop', dnsName: 'laptop.home.example', os: 'linux', addresses: ['100.64.0.3'], online: true, owner: 'Alice'),
      MeshDevice(
        id: 'c', name: 'tablet', dnsName: 'tablet.home.example', os: 'android', addresses: ['100.64.0.4'], exitOption: true,
        lastSeen: DateTime(2026, 10, 1, 12), owner: 'Alice',
      ),
    ],
  );

  @override
  Future<MeshStatus> meshStatus() async {
    if (_state.status != ConnStatus.connected) throw EngineException('NOT_RUNNING', 'no mesh profile is connected');
    return mesh;
  }

  @override
  Future<MeshStatus> setMeshExit(String id) async {
    if (_state.status != ConnStatus.connected) throw EngineException('NOT_RUNNING', 'no mesh profile is connected');
    final target = mesh.devices.where((d) => d.id == id).firstOrNull;
    if (id.isNotEmpty && target == null) throw EngineException('MESH_FAILED', 'peer not found: $id');
    if (target != null && !target.exitOption) throw EngineException('MESH_FAILED', 'peer does not offer exit node: $id');
    if (target != null && !target.online) throw EngineException('MESH_FAILED', 'the device is offline');
    mesh = MeshStatus(
      state: mesh.state,
      network: mesh.network,
      domain: mesh.domain,
      self: mesh.self,
      devices: [
        for (final d in mesh.devices)
          MeshDevice(
            id: d.id, name: d.name, dnsName: d.dnsName, os: d.os, addresses: d.addresses, online: d.online,
            exitOption: d.exitOption, exit: d.id == id && id.isNotEmpty, lastSeen: d.lastSeen, owner: d.owner,
          ),
      ],
    );
    return mesh;
  }

  /// What [exitInfo] answers (tests change it).
  ExitInfo exit = const ExitInfo('203.0.113.77', 'NL');

  @override
  Future<ExitInfo> exitInfo() async => exit;

  @override
  Future<BypassReport> parseBypass(String text) async {
    // A simple count so the screens work without the core (the real rules are the core's).
    var entries = 0;
    final issues = <BypassIssue>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].split('#').first.trim();
      if (line.isEmpty) continue;
      if (line.contains(' ')) {
        issues.add(BypassIssue(i + 1, line, 'not a domain, address or range', code: 'BAD_ENTRY'));
      } else {
        entries++;
      }
    }
    return BypassReport(entries: entries, domains: entries, issues: issues);
  }

  @override
  Future<Map<String, String>> profileValues(ProfileInfo profile) async => {
    'name': profile.name,
    'server': profile.server,
    'port': '${profile.port}',
    'password': profile.raw['password'] as String? ?? '',
  };

  @override
  Future<String> exportLink(ProfileInfo profile) async {
    if (profile.protocol != 'trojan') throw EngineException('BAD_REQUEST', 'no share link for ${profile.protocol}');
    return 'trojan://${Uri.encodeComponent(profile.raw['password'] as String? ?? '')}@${profile.server}:${profile.port}'
        '#${Uri.encodeComponent(profile.name)}';
  }

  @override
  void dispose() {
    _traffic?.cancel();
    _states.close();
    _logs.close();
  }
}
