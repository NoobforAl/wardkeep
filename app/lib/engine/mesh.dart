/// The mesh (Tailscale / Headscale) side of the engine contract: the devices of the
/// network a connected mesh profile has joined.
library;

/// One device of the mesh.
class MeshDevice {
  const MeshDevice({
    required this.id,
    required this.name,
    this.dnsName = '',
    this.os = '',
    this.addresses = const [],
    this.online = false,
    this.exitOption = false,
    this.exit = false,
    this.lastSeen,
    this.owner = '',
  });

  /// The identifier [VpnEngine.setMeshExit] takes.
  final String id;
  final String name;

  /// The MagicDNS name ("laptop.mesh.example"), without the final dot.
  final String dnsName;
  final String os;
  final List<String> addresses;
  final bool online;

  /// The device offers its internet connection to the others.
  final bool exitOption;

  /// The device whose connection is in use as the exit.
  final bool exit;
  final DateTime? lastSeen;

  /// The account the device belongs to (devices shared with you belong to someone else).
  final String owner;

  /// The address to show first: IPv4 if there is one.
  String get address => addresses.firstWhere((a) => !a.contains(':'), orElse: () => addresses.isEmpty ? '' : addresses.first);

  factory MeshDevice.fromJson(Map<String, dynamic> j) {
    final seen = (j['last_seen'] as num?)?.toInt() ?? 0;
    return MeshDevice(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      dnsName: j['dns_name'] as String? ?? '',
      os: j['os'] as String? ?? '',
      addresses: [for (final a in (j['addresses'] as List? ?? const [])) a as String],
      online: j['online'] as bool? ?? false,
      exitOption: j['exit_option'] as bool? ?? false,
      exit: j['exit'] as bool? ?? false,
      lastSeen: seen > 0 ? DateTime.fromMillisecondsSinceEpoch(seen * 1000) : null,
      owner: j['owner'] as String? ?? '',
    );
  }
}

/// The mesh as this device sees it.
class MeshStatus {
  const MeshStatus({
    this.state = 'NoState',
    this.authUrl = '',
    this.network = '',
    this.domain = '',
    this.self,
    this.devices = const [],
  });

  /// Tailscale's own state: NoState, NeedsLogin, Starting, Running, Stopped.
  final String state;

  /// Set when the device waits for a login (the auth key was not accepted).
  final String authUrl;
  final String network;

  /// The MagicDNS suffix of the devices' names.
  final String domain;
  final MeshDevice? self;

  /// The other devices, online ones first.
  final List<MeshDevice> devices;

  bool get running => state == 'Running';

  /// The device in use as the exit, if any.
  MeshDevice? get exitDevice => devices.where((d) => d.exit).firstOrNull;

  factory MeshStatus.fromJson(Map<String, dynamic> j) => MeshStatus(
    state: j['state'] as String? ?? 'NoState',
    authUrl: j['auth_url'] as String? ?? '',
    network: j['network'] as String? ?? '',
    domain: j['domain'] as String? ?? '',
    self: j['self'] == null ? null : MeshDevice.fromJson(j['self'] as Map<String, dynamic>),
    devices: [for (final d in (j['devices'] as List? ?? const [])) MeshDevice.fromJson(d as Map<String, dynamic>)],
  );
}
