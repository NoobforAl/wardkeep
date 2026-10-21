import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/profiles_screen.dart';
import 'package:omnitun/ui/screens/settings_screen.dart';

/// The computer layout (a window from `wideBreakpoint` wide): a rail of destinations on the left, the
/// controls in a column beside a large globe, and the other pages inside the window, not behind a button.
void main() {
  const sizes = <(String, Size, double)>[
    ('small window', Size(900, 600), 1.0),
    ('laptop', Size(1280, 720), 1.0),
    ('laptop, large text', Size(1280, 720), 1.5),
    ('full HD', Size(1920, 1040), 1.0),
  ];

  Future<void> open(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final store = AppStore.memory({
      'onboarded': true,
      'profiles': [
        {'id': 'a', 'name': 'A server', 'protocol': 'trojan', 'server': 'a.example.com', 'port': 443, 'password': 'pw'},
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))],
      child: const OmnitunApp(),
    ));
    await tester.pumpAndSettle();
  }

  for (final (name, size, scale) in sizes) {
    testWidgets('on a $name: the rail, the controls and the globe fit, nothing overflows', (tester) async {
      await open(tester, size, scale);
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsOneWidget);
      final screen = Offset.zero & size;
      final button = tester.getRect(find.text('Connect').last); // the rail's label comes first
      expect(screen.contains(button.center), isTrue, reason: 'the button is off screen: $button');
      // The controls are in a column to the left of the globe, not under it.
      final status = tester.getRect(find.text('Not connected'));
      expect(status.center.dx < size.width * 0.45, isTrue, reason: 'the status is not in the left column: $status');

      // Connected (the mock engine: nothing real), the clock and the speed join the status.
      await tester.tap(find.text('Connect').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull, reason: 'connected: layout overflow');
      final connected = tester.getRect(find.textContaining('Connected').first);
      expect(connected.top >= 0 && connected.bottom <= size.height, isTrue, reason: 'connected: status off screen $connected');
      expect(screen.contains(tester.getRect(find.text('Disconnect')).center), isTrue, reason: 'connected: the button is off screen');
      await tester.tap(find.text('Disconnect'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // the store's delayed write
    });
  }

  testWidgets('the rail opens the servers and the settings inside the window', (tester) async {
    await open(tester, const Size(1280, 720), 1.0);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'the rail stays');

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Servers')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilesScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // the store's delayed write
  });

  testWidgets('a page opened from a page stays beside the rail, and Escape goes back', (tester) async {
    await open(tester, const Size(1280, 720), 1.0);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage servers'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'the rail stays in view');
    final page = tester.getRect(find.byType(ProfilesScreen).last);
    expect(page.left >= tester.getRect(find.byType(NavigationRail)).right, isTrue, reason: 'beside the rail: $page');
    expect(page.width, lessThanOrEqualTo(600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ProfilesScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the location list opens beside the rail, not over the window', (tester) async {
    await open(tester, const Size(1280, 720), 1.0);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Select location'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a phone keeps the one column and no rail', (tester) async {
    await open(tester, const Size(412, 915), 1.0);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // the store's delayed write
  });
}
