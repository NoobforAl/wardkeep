import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/profiles_screen.dart';
import 'package:omnitun/ui/screens/subscription_screen.dart';
import 'package:omnitun/ui/theme.dart';

/// Phone sizes with the keyboard open and a bottom system bar (gesture bar or the
/// back/home/recents keys): the main button of a form must stay on screen, above both.
const _screens = <(String, Size, double, double)>[
  ('phone', Size(412, 915), 300, 48),
  ('small phone', Size(360, 640), 260, 48),
  ('short phone', Size(360, 427), 200, 48),
];

void main() {
  for (final (name, size, keyboard, bar) in _screens) {
    for (final scale in [1.0, 1.3]) {
      Future<void> open(WidgetTester tester, void Function(BuildContext, WidgetRef) show) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final store = AppStore.memory({'onboarded': true, 'profiles': <Object>[]});
        await tester.pumpWidget(ProviderScope(
          overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))],
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(child: TextButton(onPressed: () => show(context, ref), child: const Text('open'))),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      /// The user taps a field, then the keyboard and the system bar come up.
      Future<void> typeIn(WidgetTester tester, Finder field) async {
        await tester.tap(field);
        await tester.pump();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewPadding = FakeViewPadding(bottom: bar);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpAndSettle();
        // Typing makes the field scroll its caret into view above the keyboard.
        await tester.enterText(field, 'x');
        await tester.pumpAndSettle();
      }

      void expectAboveKeyboard(WidgetTester tester, Finder button, String what) {
        final rect = tester.getRect(button);
        expect(rect.bottom <= size.height - keyboard + 0.5, isTrue, reason: '$what: the button is behind the keyboard ($rect)');
        expect(rect.top >= 0, isTrue, reason: '$what: the button is above the screen ($rect)');
      }

      testWidgets('import sheet on a $name at text scale $scale: Import stays above the keyboard', (tester) async {
        await open(tester, (context, ref) => showImportSheet(context, ref));
        await typeIn(tester, find.byType(TextField).last);
        expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Import'), 'import sheet');
        // The form scrolls above the pinned button: at least the first line of the field is in view.
        final field = tester.getRect(find.byType(TextField).last);
        final button = tester.getRect(find.widgetWithText(FilledButton, 'Import'));
        expect(field.top + 48 <= button.top && field.top >= 0, isTrue, reason: 'the text field is hidden ($field, button $button)');
      });

      testWidgets('subscription form on a $name at text scale $scale: its button stays above the keyboard', (tester) async {
        await open(tester, (context, ref) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));
        });
        await typeIn(tester, find.byType(TextField).first);
        expectAboveKeyboard(tester, find.byType(FilledButton).last, 'subscription form');
      });
    }
  }
}
