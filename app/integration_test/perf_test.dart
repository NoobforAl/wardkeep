import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/widgets/earth_globe.dart';
import 'package:vm_service/vm_service_io.dart';

/// Frame times of the real app. Run it in profile mode (debug mode is several times slower and says
/// nothing about the app), from app/:
///
///   flutter drive --profile -d windows --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
///
/// Each scenario is traced; test_driver/perf_driver.dart writes `build/SCENARIO.timeline_summary.json`
/// (average and worst frame build and raster time, missed frames) and the process's memory goes to
/// build/memory.json. The engine is the mock one: nothing real is connected, so this measures the UI.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frame times and memory', (tester) async {
    final store = AppStore.memory({
      'onboarded': true,
      'profiles': [
        for (var i = 0; i < 60; i++)
          {'id': 'p$i', 'name': 'Server $i', 'protocol': 'trojan', 'server': 's$i.example.com', 'port': 443, 'password': 'pw'},
      ],
    });
    final engine = MockEngine(connectDelay: Duration.zero);
    await tester.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(engine)],
      child: const OmnitunApp(),
    ));
    await tester.pumpAndSettle();

    // The process's memory, split: what the Dart heap holds after a collection, what Dart owns outside
    // it (images, buffers), and the process total (which also has the engine, the GPU and the plugins).
    final info = await developer.Service.getInfo();
    final uri = info.serverUri!;
    final service = await vmServiceConnectUri(uri.replace(scheme: 'ws', path: '${uri.path}ws').toString());
    final isolateId = developer.Service.getIsolateId(Isolate.current)!;
    final memory = <String, Object>{};
    Future<void> sample(String when) async {
      final profile = await service.getAllocationProfile(isolateId, gc: true);
      final usage = profile.memoryUsage!;
      final classes = [...?profile.members]..sort((a, b) => (b.bytesCurrent ?? 0).compareTo(a.bytesCurrent ?? 0));
      memory[when] = {
        'top_classes': [
          for (final c in classes.take(8)) '${c.classRef?.name}: ${((c.bytesCurrent ?? 0) / (1 << 20)).toStringAsFixed(1)} MB in ${c.instancesCurrent}',
        ],
        'rss_mb': (ProcessInfo.currentRss / (1 << 20)).round(),
        'dart_heap_mb': ((usage.heapUsage ?? 0) / (1 << 20)).round(),
        'dart_external_mb': ((usage.externalUsage ?? 0) / (1 << 20)).round(),
      };
    }

    Future<void> scenario(String name, Future<void> Function() body) async {
      await binding.traceAction(body, reportKey: name);
    }

    Future<void> seconds(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    await sample('start');
    await scenario('disconnected', () => seconds(5));

    await tester.tap(find.text('Connect').last); // on a wide window the rail's label comes first
    await tester.pump();
    await seconds(4); // the flight to the exit
    await sample('connected');
    // Connected: a speed report every second, the flow along the route, the clock.
    await scenario('connected', () => seconds(15));

    // The user turns the Earth with a finger: every frame paints the dotted globe again.
    final globe = find.byType(EarthBackdrop);
    await scenario('globe_drag', () async {
      for (var i = 0; i < 8; i++) {
        await tester.drag(globe, Offset(i.isEven ? 260 : -260, 20), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await seconds(2);
    });
    await sample('after_drag');

    // Connect and disconnect over and over, the memory should come back.
    for (var i = 1; i <= 20; i++) {
      await tester.tap(find.text('Disconnect'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Connect').last);
      await seconds(2);
      if (i % 4 == 0) await sample('reconnect_$i');
    }

    await service.dispose();
    binding.reportData = {...?binding.reportData, 'memory': memory};
  });
}
