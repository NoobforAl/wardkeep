import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/countries.dart';
import 'package:omnitun/state/location.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/devices_screen.dart';
import 'package:omnitun/ui/screens/location_screen.dart';

/// A mock engine that remembers what it was asked and can be made to fail.
class MeshEngine extends MockEngine {
  MeshEngine() : super(connectDelay: Duration.zero);
  final exitCalls = <String>[];
  Exception? exitFails;

  @override
  Future<MeshStatus> setMeshExit(String id) async {
    exitCalls.add(id);
    if (exitFails != null) throw exitFails!;
    return super.setMeshExit(id);
  }
}

const _mesh = {
  'id': 'm',
  'name': 'Home mesh',
  'protocol': 'tailscale',
  'server': '',
  'port': 0,
  'password': 'tskey-auth-kABC-secret',
  'tailscale': {'control_url': 'https://hs.example.com:8443', 'hostname': 'phone'},
};

Map<String, dynamic> _data({bool withOther = false}) => {
  'onboarded': true,
  'profiles': [
    if (withOther) {'id': 'o', 'name': 'Plain VPN', 'protocol': 'trojan', 'server': '203.0.113.9', 'port': 443},
    _mesh,
  ],
};

Future<ProviderContainer> _start(WidgetTester tester, MockEngine engine, Map<String, dynamic> data) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(AppStore.memory(data)), engineProvider.overrideWithValue(engine)],
      child: const OmnitunApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(OmnitunApp)));
}

Future<void> _connectAndOpenDevices(WidgetTester tester) async {
  await tester.tap(find.text('Connect'));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1)); // the status eases in (one frame starts it, one ends it)
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('My devices'));
  await tester.pumpAndSettle();
}

/// Ends the test cleanly: the mock engine's traffic timer must not outlive it.
Future<void> _finish(WidgetTester tester, MockEngine engine) async {
  await tester.pumpWidget(const SizedBox());
  final done = engine.disconnect();
  await tester.pump(const Duration(milliseconds: 400));
  await done;
}

void main() {
  test('a mesh profile has no server of its own', () {
    final p = ProfileInfo.fromJson(_mesh);
    expect(p.isMesh, isTrue);
    expect(p.address, 'hs.example.com');
    expect(ProfileInfo.fromJson({..._mesh, 'tailscale': <String, dynamic>{}}).address, 'Tailscale');
    expect(ProfileInfo.fromJson({'id': 'x', 'name': 'x', 'protocol': 'trojan', 'server': 'a.example', 'port': 443}).isMesh, isFalse);
  });

  test('the answer of mesh_status is read as the core sends it', () {
    // The shape core/engine.MeshStatus has in JSON (empty fields are left out by the core).
    final st = MeshStatus.fromJson({
      'state': 'Running',
      'network': 'home',
      'domain': 'ts.example',
      'self': {'id': '1', 'name': 'phone', 'dns_name': 'phone.ts.example', 'addresses': ['100.64.0.1', 'fd7a::1'], 'online': true},
      'devices': [
        {'id': '2', 'name': 'pc', 'addresses': ['fd7a::2', '100.64.0.2'], 'online': true, 'exit_option': true, 'exit': true, 'owner': 'Alice'},
        {'id': '3', 'name': 'old', 'online': false, 'last_seen': 1760000000},
      ],
    });
    expect(st.running, isTrue);
    expect(st.self?.address, '100.64.0.1'); // IPv4 first
    expect(st.devices[0].address, '100.64.0.2');
    expect(st.exitDevice?.id, '2');
    expect(st.devices[1].address, '');
    expect(st.devices[1].lastSeen, DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000));
    expect(const MeshStatus().running, isFalse);
    expect(MeshStatus.fromJson({'state': 'Running'}).devices, isEmpty); // a null list from the core
  });

  test('Auto never starts a mesh profile and it has no country', () {
    final mesh = ProfileInfo.fromJson({..._mesh, 'name': 'DE mesh'}).copyWith(latencyMs: 5);
    final plain = ProfileInfo.fromJson({'id': 'o', 'name': 'Plain', 'protocol': 'trojan', 'server': 'x.example', 'port': 443}).copyWith(latencyMs: 300);
    expect(planConnection([mesh, plain], null, (_) => null)!.primary.id, 'o');
    expect(planConnection([mesh, plain], 'm', (_) => null)!.primary.id, 'm'); // when the user picks it
    expect(guessCountry(mesh), isNull);
    expect(groupByCountry([mesh, plain], (_) => null, (c) => c).expand((g) => g.profiles).map((p) => p.id), ['o']);
  });

  testWidgets('connected to a mesh profile, the home screen leads to the devices', (tester) async {
    final engine = MeshEngine();
    await _start(tester, engine, _data());
    expect(find.text('My devices'), findsNothing); // not connected: nothing to show
    await tester.tap(find.text('Connect'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1)); // the status eases in (one frame starts it, one ends it)
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Home mesh'), findsOneWidget);
    expect(find.text('My devices'), findsOneWidget);

    await tester.tap(find.text('My devices'));
    await tester.pumpAndSettle();
    // This device, then the others: names, MagicDNS names, addresses, online state.
    expect(find.text('phone'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('home-pc'), findsOneWidget);
    expect(find.text('home-pc.home.example'), findsOneWidget);
    expect(find.text('100.64.0.2'), findsOneWidget);
    expect(find.text('laptop'), findsOneWidget);
    expect(find.text('Online'), findsNWidgets(2));
    expect(find.textContaining('Offline · Last seen'), findsOneWidget);
    expect(find.text('home · home.example'), findsOneWidget);
    // Only the online device that offers its connection can be used as the exit.
    expect(find.text('Use as exit'), findsOneWidget);
    await _finish(tester, engine);
  });

  testWidgets('use as exit, then stop using it', (tester) async {
    final engine = MeshEngine();
    await _start(tester, engine, _data());
    await _connectAndOpenDevices(tester);

    await tester.tap(find.text('Use as exit'));
    await tester.pumpAndSettle();
    expect(engine.exitCalls, ['a']);
    expect(find.text('Exit in use'), findsOneWidget);
    expect(find.text('Stop using as exit'), findsOneWidget);
    expect(find.text('Use as exit'), findsNothing);
    expect(engine.mesh.exitDevice?.name, 'home-pc');

    await tester.tap(find.text('Stop using as exit'));
    await tester.pumpAndSettle();
    expect(engine.exitCalls, ['a', '']);
    expect(find.text('Use as exit'), findsOneWidget);
    expect(find.text('Exit in use'), findsNothing);
    expect(engine.mesh.exitDevice, isNull);
    await _finish(tester, engine);
  });

  testWidgets('a refused exit is explained in the user\'s language', (tester) async {
    final engine = MeshEngine()..exitFails = EngineException('MESH_FAILED', 'peer does not offer exit node: a');
    await _start(tester, engine, _data());
    await _connectAndOpenDevices(tester);
    await tester.tap(find.text('Use as exit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be used as the exit right now'), findsOneWidget);
    expect(find.text('Use as exit'), findsOneWidget); // still offered: nothing changed
    await _finish(tester, engine);
  });

  testWidgets('the list follows the network: a device that comes online appears', (tester) async {
    final engine = MeshEngine();
    await _start(tester, engine, _data());
    await _connectAndOpenDevices(tester);
    expect(find.text('tablet'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
    engine.mesh = MeshStatus(
      state: 'Running',
      self: engine.mesh.self,
      devices: [
        ...engine.mesh.devices,
        const MeshDevice(id: 'd', name: 'desk', addresses: ['100.64.0.9'], online: true),
      ],
    );
    expect(find.text('desk'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('desk'), findsOneWidget);
    await _finish(tester, engine);
  });

  testWidgets('before the network is joined, and when the key is refused', (tester) async {
    final engine = MeshEngine();
    await _start(tester, engine, _data());
    await _connectAndOpenDevices(tester);
    engine.mesh = const MeshStatus(state: 'Starting');
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Joining the network…'), findsOneWidget);
    expect(find.text('home-pc'), findsNothing);

    engine.mesh = const MeshStatus(state: 'NeedsLogin', authUrl: 'https://login.example/x');
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.textContaining('did not accept this device'), findsOneWidget);
    await _finish(tester, engine);
  });

  testWidgets('without a connected mesh profile the screen says so', (tester) async {
    final engine = MeshEngine();
    final c = await _start(tester, engine, _data());
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const DevicesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Connect a Tailscale or Headscale profile to see your devices.'), findsOneWidget);
    expect(c.read(connectionProvider).status, ConnStatus.disconnected);
    await _finish(tester, engine);
  });

  testWidgets('the location list shows the mesh under "My devices" and picking it selects it', (tester) async {
    final engine = MeshEngine();
    final c = await _start(tester, engine, _data(withOther: true));
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const LocationScreen()));
    await tester.pumpAndSettle();
    expect(find.text('My devices'), findsOneWidget);
    expect(find.text('Home mesh'), findsOneWidget);
    expect(find.text('hs.example.com'), findsOneWidget);
    await tester.tap(find.text('Home mesh'));
    await tester.pumpAndSettle();
    expect(c.read(selectedProfileIdProvider), 'm');
    await _finish(tester, engine);
  });
}
