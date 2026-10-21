import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/location_screen.dart';

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => testAllLatencies(ref),
        child: const Text('test'),
      );
}

/// Measuring every server takes seconds; the user may leave the screen meanwhile. The results
/// that arrive after that must still be recorded, and must not throw.
void main() {
  testWidgets('latency results arriving after the screen is closed are kept and do not throw', (tester) async {
    final store = AppStore.memory({
      'onboarded': true,
      'profiles': [
        for (var i = 0; i < 6; i++)
          {'id': 'p$i', 'name': 'Server $i', 'protocol': 'trojan', 'server': 's$i.example.com', 'port': 443, 'password': 'pw'},
      ],
    });
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine())],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, show, _) => show ? const _Host() : const SizedBox(),
          ),
        );
      }),
    ));

    await tester.tap(find.text('test'));
    await tester.pump(const Duration(milliseconds: 50));
    shown.value = false; // the user leaves while the tests run
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // all the mock's results arrive

    expect(tester.takeException(), isNull);
    final measured = container.read(profilesProvider).where((p) => p.latencyMs != null).length;
    expect(measured, 6, reason: 'every result is recorded even though the screen is gone');
  });
}
