import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/bypass_screen.dart';
import 'package:omnitun/ui/screens/location_screen.dart';
import 'package:omnitun/ui/screens/profile_editor_screen.dart';
import 'package:omnitun/ui/theme.dart';
import 'package:omnitun/ui/widgets/credentials_dialog.dart';

/// The other forms that take typing: with the keyboard up and a bottom system bar, the field being typed
/// in and the form's action must stay on screen (keyboard_test.dart does the import sheet and the
/// subscription form).
const _screens = <(String, Size, double, double)>[
  ('phone', Size(412, 915), 300, 48),
  ('small phone', Size(360, 640), 260, 48),
  ('short phone', Size(360, 427), 200, 48),
];

void main() {
  for (final (name, size, keyboard, bar) in _screens) {
    for (final scale in [1.0, 1.3]) {
      Future<void> open(WidgetTester tester, Widget Function(BuildContext, WidgetRef) home, {int servers = 0}) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final store = AppStore.memory({
          'onboarded': true,
          'profiles': [
            for (var i = 0; i < servers; i++)
              {'id': 'p$i', 'name': 'Server $i', 'protocol': 'trojan', 'server': 's$i.example.com', 'port': 443, 'password': 'pw'},
          ],
        });
        await tester.pumpWidget(ProviderScope(
          overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))],
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(builder: (context, ref, _) => home(context, ref)),
          ),
        ));
        await tester.pumpAndSettle();
      }

      /// Taps [field], raises the keyboard and the bar, types, and checks the field and [action].
      Future<void> typeIn(WidgetTester tester, Finder field, Finder action, String what) async {
        // On the smallest screens a dialog scrolls: the person scrolls to the field first.
        await tester.ensureVisible(field);
        await tester.pump();
        await tester.tap(field);
        await tester.pump();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        tester.view.padding = FakeViewPadding.zero;
        tester.view.viewPadding = FakeViewPadding(bottom: bar);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpAndSettle();
        await tester.enterText(field, 'x');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$what: layout overflow');
        final top = size.height - keyboard;
        final f = tester.getRect(field);
        expect(f.top >= 0 && f.top + 40 <= top, isTrue, reason: '$what: the field is hidden ($f, keyboard from $top)');
        final a = tester.getRect(action);
        expect(a.top >= 0 && a.bottom <= top + 0.5, isTrue, reason: '$what: the action is out of reach ($a, keyboard from $top)');
      }

      testWidgets('server editor on a $name at text scale $scale', (tester) async {
        await open(tester, (_, _) => const ProfileEditorScreen(protocol: 'trojan'));
        await typeIn(tester, find.byType(TextField).last, find.text('Save'), 'server editor');
      });

      testWidgets('bypass list editor on a $name at text scale $scale', (tester) async {
        await open(tester, (_, _) => const BypassEditScreen());
        await typeIn(tester, find.byType(TextField).last, find.text('Save'), 'bypass editor');
      });

      testWidgets('location search on a $name at text scale $scale', (tester) async {
        // The search field is there from the seventh server on.
        await open(tester, (_, _) => const LocationScreen(), servers: 9);
        await typeIn(tester, find.byType(TextField).first, find.byType(AppBar), 'location search');
      });

      testWidgets('password dialog on a $name at text scale $scale', (tester) async {
        final profile = ProfileInfo(
          id: 'p',
          name: 'A server',
          protocol: 'openvpn',
          server: 'a.example.com',
          port: 1194,
          raw: {'id': 'p', 'name': 'A server', 'protocol': 'openvpn', 'server': 'a.example.com', 'port': 1194},
        );
        await open(tester, (context, ref) => Scaffold(
              body: Center(child: TextButton(onPressed: () => askCredentials(context, ref, profile), child: const Text('ask'))),
            ));
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        await typeIn(tester, find.byType(TextField).last, find.byType(FilledButton).last, 'password dialog');
      });
    }
  }
}
