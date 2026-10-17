import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/daemon_engine.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/l10n.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/network_tiles.dart';

final _profile = ProfileInfo.fromJson({
  'id': 'p1',
  'name': 'p',
  'protocol': 'trojan',
  'server': 'example.com',
  'port': 443,
});

Widget _app(Widget home, {ProviderContainer? container}) => UncontrolledProviderScope(
      container: container ?? ProviderContainer(overrides: [storeProvider.overrideWithValue(AppStore.memory({})), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))]),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

void main() {
  test('IPv6 and the MTU are sent to the core only when the user changed them', () {
    final plain = DaemonEngine.startParams(_profile, const [], const ConnectOptions());
    expect(plain.containsKey('no_ipv6'), isFalse);
    expect(plain.containsKey('mtu'), isFalse);
    final custom = DaemonEngine.startParams(_profile, const [], const ConnectOptions(ipv6: false, mtu: 1280));
    expect(custom['no_ipv6'], true);
    expect(custom['mtu'], 1280);
  });

  test('the settings keep them across a restart, and an older file gets the defaults', () {
    final s = const SettingsState().copyWith(ipv6: false, mtu: 1400);
    final back = SettingsState.fromJson(s.toJson(), const SettingsState());
    expect(back.ipv6, isFalse);
    expect(back.mtu, 1400);
    final old = SettingsState.fromJson({'tun_mode': true}, const SettingsState());
    expect(old.ipv6, isTrue);
    expect(old.mtu, 0);
  });

  testWidgets('the MTU dialog takes a number in range, empty or Reset for the default, and says what is wrong', (tester) async {
    int? result = -1;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showDialog<int>(context: context, builder: (_) => const MtuDialog(1280)),
        child: const Text('open'),
      ),
    )));
    Future<void> openDialog() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await openDialog();
    expect(find.widgetWithText(TextField, '1280'), findsOneWidget, reason: 'it shows the current value');
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('576'), findsOneWidget, reason: 'too small: the range is named');
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'and the dialog stays');
    await tester.enterText(find.byType(TextField), '70000');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1420');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 1420);

    await openDialog();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 0, reason: 'empty is the default');

    await openDialog();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(result, 0);

    result = -1;
    await openDialog();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'Cancel changes nothing');
  });

  testWidgets('the settings rows change the settings, and the MTU row waits for VPN mode', (tester) async {
    final container = ProviderContainer(overrides: [storeProvider.overrideWithValue(AppStore.memory({})), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(
      Consumer(builder: (context, ref, _) => ListView(children: networkTiles(context, ref, ref.watch(settingsProvider)))),
      container: container,
    ));
    expect(find.text('Default'), findsOneWidget);
    // proxy mode: the MTU row is disabled, the IPv6 switch is not
    await tester.tap(find.text('MTU'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('IPv6'));
    await tester.pump();
    expect(container.read(settingsProvider).ipv6, isFalse);

    container.read(settingsProvider.notifier).update((s) => s.copyWith(tunMode: true));
    await tester.pump();
    await tester.tap(find.text('MTU'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1380');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).mtu, 1380);
    expect(find.text('1380'), findsOneWidget);
    // let the settings' delayed save run before the test ends
    await tester.pump(const Duration(seconds: 5));
  });
}
