import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/core_engine.dart';
import 'package:omnitun/engine/daemon_engine.dart';
import 'package:omnitun/engine/engine.dart';

/// The Windows service (core/winsvc): where its control file is, how the app
/// detects it and when it prefers it. Nothing here installs or starts a
/// service: a daemon started by the test stands in for it, and the connection
/// attempts are refused by the core before any tunnel is made.
void main() {
  final exe = CoreEngine.findDaemonExecutable();
  final sep = Platform.pathSeparator;

  ProfileInfo profile(Map<String, dynamic> j) => ProfileInfo.fromJson(j);
  final tor = profile({'id': 'tor1', 'name': 'Tor', 'protocol': 'tor', 'server': '', 'port': 0, 'tor': {}});

  test('the service control file is in ProgramData, in a directory of its own', () {
    expect(DaemonEngine.serviceControlFile({'ProgramData': r'D:\PD'}), r'D:\PD\omnitun\control\control.json');
    expect(DaemonEngine.serviceControlFile({}), r'C:\ProgramData\omnitun\control\control.json');
    // Not the per-user file: the two must never be mistaken for each other.
    expect(DaemonEngine.serviceControlFile({}), isNot(DaemonEngine.defaultControlFile()));
  });

  test('the kill switch is only requested in VPN mode', () {
    final p = tor;
    Map<String, dynamic> params(ConnectOptions o) => DaemonEngine.startParams(p, const [], o);
    expect(params(const ConnectOptions()).containsKey('kill_switch'), isFalse);
    expect(params(const ConnectOptions(tunMode: true)).containsKey('kill_switch'), isFalse);
    expect(params(const ConnectOptions(killSwitch: true)).containsKey('kill_switch'), isFalse, reason: 'proxy mode');
    final on = params(const ConnectOptions(tunMode: true, killSwitch: true));
    expect(on['kill_switch'], isTrue);
    expect(on.containsKey('kill_switch_early'), isFalse);
    expect(params(const ConnectOptions(tunMode: true, killSwitch: true, killSwitchEarly: true))['kill_switch_early'], isTrue);
    expect(params(const ConnectOptions(tunMode: true, killSwitchEarly: true)).containsKey('kill_switch_early'), isFalse);
  });

  group('detection', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('omnitun-svc-detect'));
    tearDown(() async => dir.delete(recursive: true).catchError((_) => dir));

    test('no control file: not installed or not running', () async {
      expect(await DaemonEngine.attachService(controlFile: '${dir.path}${sep}control.json'), isNull);
    });

    test('an unreadable or broken control file is not a service', () async {
      final f = File('${dir.path}${sep}control.json');
      for (final body in ['', 'not json', '{}', '{"addr":"127.0.0.1:1"}', '{"addr":"127.0.0.1:1","token":"x"}']) {
        await f.writeAsString(body);
        expect(await DaemonEngine.attachService(controlFile: f.path), isNull, reason: body);
      }
    });

    test('a running core is found and marked as the service; a stale file is not', () async {
      final file = '${dir.path}${sep}control.json';
      final core = await DaemonEngine.launch(exe!, controlFile: file);
      final found = await DaemonEngine.attachService(controlFile: file);
      expect(found, isNotNull);
      expect(found!.isService, isTrue);
      expect(core.isService, isFalse);
      // The service stops but leaves its file (a crash does): not detected.
      final stale = await File(file).readAsString();
      found.dispose();
      core.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await File(file).writeAsString(stale);
      expect(await DaemonEngine.attachService(controlFile: file), isNull);
    }, skip: exe == null ? 'omnitun-svc not built' : false);

    test('a wrong token is not accepted', () async {
      final file = '${dir.path}${sep}control.json';
      final core = await DaemonEngine.launch(exe!, controlFile: file);
      addTearDown(core.dispose);
      final j = jsonDecode(await File(file).readAsString()) as Map<String, dynamic>;
      final bad = '${dir.path}${sep}bad.json';
      await File(bad).writeAsString(jsonEncode({...j, 'token': 'wrong'}));
      expect(await DaemonEngine.attachService(controlFile: bad), isNull);
    }, skip: exe == null ? 'omnitun-svc not built' : false);
  });

  // CoreEngine uses the service for VPN mode and the per-user daemon for the
  // rest. Both are daemons started here; the VPN-mode requests carry a Tor
  // profile with the kill switch, which the core refuses before it opens any
  // tunnel, so no adapter is made even if this runs with administrator rights.
  test('VPN mode goes to the service when there is one, proxy mode to the own daemon', () async {
    final dir = await Directory.systemTemp.createTemp('omnitun-svc-route');
    addTearDown(() => dir.delete(recursive: true).catchError((_) => dir));
    final serviceFile = '${dir.path}${sep}service.json';
    final localFile = '${dir.path}${sep}local.json';
    final fakeService = await DaemonEngine.launch(exe!, controlFile: serviceFile);
    addTearDown(fakeService.dispose);

    final engine = CoreEngine(serviceControlFile: serviceFile, localControlFile: localFile);
    addTearDown(engine.dispose);
    final states = <EngineState>[];
    engine.states.listen(states.add);
    await engine.forms(); // waits until the own daemon is up
    expect(engine.usingService, isFalse);

    // VPN mode: the service.
    await engine.connect(tor, options: const ConnectOptions(tunMode: true, killSwitch: true));
    expect(engine.usingService, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(states.last.status, ConnStatus.error);
    expect(states.last.error, contains('kill switch'));

    // Proxy mode: back to the own daemon (with a server nothing listens on).
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final dead = profile({'id': 'dead1', 'name': 'dead', 'protocol': 'shadowsocks', 'server': '127.0.0.1', 'port': port, 'method': 'aes-128-gcm', 'password': 'x'});
    await engine.connect(dead, options: ConnectOptions(systemProxy: false, listenPort: port + 1, autoFailover: false));
    expect(engine.usingService, isFalse);
    await engine.disconnect();

    // VPN mode again: the service is still used.
    await engine.connect(tor, options: const ConnectOptions(tunMode: true, killSwitch: true));
    expect(engine.usingService, isTrue);
  }, skip: !Platform.isWindows
      ? 'the service exists on Windows only'
      : exe == null
          ? 'omnitun-svc not built'
          : false, timeout: const Timeout(Duration(seconds: 90)));

  test('without a service VPN mode stays on the own daemon', () async {
    final dir = await Directory.systemTemp.createTemp('omnitun-svc-noroute');
    addTearDown(() => dir.delete(recursive: true).catchError((_) => dir));
    final engine = CoreEngine(
      serviceControlFile: '${dir.path}${sep}missing.json',
      localControlFile: '${dir.path}${sep}local.json',
    );
    addTearDown(engine.dispose);
    final states = <EngineState>[];
    engine.states.listen(states.add);
    await engine.forms();
    await engine.connect(tor, options: const ConnectOptions(tunMode: true, killSwitch: true));
    expect(engine.usingService, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(states.last.status, ConnStatus.error);
    expect(states.last.error, contains('kill switch'));
  }, skip: !Platform.isWindows
      ? 'the service exists on Windows only'
      : exe == null
          ? 'omnitun-svc not built'
          : false, timeout: const Timeout(Duration(seconds: 60)));
}
