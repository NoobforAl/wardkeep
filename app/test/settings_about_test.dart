import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wardkeep/engine/mock_engine.dart';
import 'package:wardkeep/l10n/l10n.dart';
import 'package:wardkeep/state/providers.dart';
import 'package:wardkeep/state/store.dart';
import 'package:wardkeep/ui/screens/privacy_screen.dart';
import 'package:wardkeep/ui/screens/settings_screen.dart';

Future<void> _pumpSettings(WidgetTester tester, {Locale? locale}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(AppStore.memory({'onboarded': true})),
      engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  final about = find.byKey(const Key('settings-about'));
  await tester.scrollUntilVisible(about, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Wardkeep',
        packageName: 'dev.omnitun.app',
        version: '0.3.0',
        buildNumber: '2001',
        buildSignature: '',
      ));

  testWidgets('the app info is centered at the end of settings, not in a card: name, version, license', (tester) async {
    await _pumpSettings(tester);
    final about = find.byKey(const Key('settings-about'));

    expect(find.ancestor(of: about, matching: find.byType(Card)), findsNothing);
    final name = find.descendant(of: about, matching: find.text('Wardkeep'));
    expect(name, findsOneWidget);
    final list = tester.getRect(find.byType(ListView));
    expect((tester.getCenter(name).dx - list.center.dx).abs(), lessThan(1));
    expect(tester.getRect(about).top, greaterThanOrEqualTo(tester.getRect(find.byType(Card).last).bottom));

    expect(find.text('Version 0.3.0'), findsOneWidget);
    expect(find.text('MIT License'), findsOneWidget);
    expect(find.textContaining('engine'), findsNothing);
    expect(find.text('Open-source licenses'), findsNothing);
  });

  testWidgets('the privacy policy opens from under the app info', (tester) async {
    await _pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.privacyIntro), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('November 1, 2026'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text(l.privacyChanges), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the privacy policy in ${locale.languageCode}: every section, nothing overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivacyScreen(),
      ));
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(locale);
      final last = find.textContaining(l.privacyUpdated('').trim().replaceAll(RegExp(r'[:：]$'), ''));
      await tester.scrollUntilVisible(last, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
}
