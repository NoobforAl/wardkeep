import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';

/// While connected the core reports the speed every second. These count how much of the
/// screen is built again for each report: the numbers the user sees change, the page does not.
void main() {
  Future<Map<String, int>> perTick(WidgetTester tester, Size size, {int ticks = 10}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final engine = MockEngine(connectDelay: Duration.zero);
    final store = AppStore.memory({
      'onboarded': true,
      'profiles': [
        {'id': 'a', 'name': 'Server A', 'protocol': 'trojan', 'server': 'a.example.com', 'port': 443, 'password': 'pw'},
        {'id': 'b', 'name': 'Server B', 'protocol': 'trojan', 'server': 'b.example.com', 'port': 443, 'password': 'pw'},
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(engine)],
      child: const OmnitunApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect').last); // on a wide window the rail's label comes first
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 3)); // connected, the flight is over

    final built = <String, int>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      built.update(element.widget.runtimeType.toString(), (n) => n + 1, ifAbsent: () => 1);
    };
    final watch = Stopwatch()..start();
    for (var i = 0; i < ticks; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    watch.stop();
    debugOnRebuildDirtyWidget = null;
    final total = built.values.fold<int>(0, (a, b) => a + b);
    final top = built.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('${size.width.toInt()}x${size.height.toInt()}: ${(total / ticks).toStringAsFixed(1)} widgets built per tick, '
        '${(watch.elapsedMicroseconds / ticks / 1000).toStringAsFixed(2)} ms per tick; most built: '
        '${top.take(8).map((e) => '${e.key} ${(e.value / ticks).toStringAsFixed(1)}').join(', ')}');

    await tester.tap(find.text('Disconnect'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2)); // the mock's traffic timer is cancelled with the engine
    return {for (final e in built.entries) e.key: (e.value / ticks).ceil()};
  }

  testWidgets('a speed report rebuilds little of the phone screen', (tester) async {
    final built = await perTick(tester, const Size(412, 915));
    final total = built.values.fold<int>(0, (a, b) => a + b);
    expect(total, lessThan(_phoneBudget), reason: 'built per tick: $built');
  });

  testWidgets('a speed report rebuilds little of the wide screen', (tester) async {
    final built = await perTick(tester, const Size(1280, 800));
    final total = built.values.fold<int>(0, (a, b) => a + b);
    expect(total, lessThan(_wideBudget), reason: 'built per tick: $built');
  });
}

// What one speed report may build: a little over what it does now (199 on the phone, 330 on the wide
// window), so a change that makes it build much more fails here. See docs/performance.md.
const _phoneBudget = 260;
const _wideBudget = 430;
