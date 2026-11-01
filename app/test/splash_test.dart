import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardkeep/ui/widgets/splash.dart';

void main() {
  Widget app({bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const SplashCover(child: Text('home')),
        ),
      );

  /// The opacity the shield is drawn with (the nearest Opacity above it).
  double shieldOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.ancestor(of: find.byType(Image), matching: find.byType(Opacity)).first).opacity;

  /// The opacity of the whole cover (ground, glow, shield and name).
  double coverOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.ancestor(of: find.byType(ColoredBox), matching: find.byType(Opacity)).first).opacity;

  testWidgets('the shield and the name over the app; the shield leaves before the ground', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 200)); // the picture is decoded
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(SplashCover.side, SplashCover.side));
    expect(find.text('home'), findsOneWidget); // the app is built underneath already

    // The shield is in the middle of the screen, where Android's launch screen has it.
    final screen = tester.getRect(find.byType(MaterialApp));
    expect((tester.getCenter(find.byType(Image)) - screen.center).distance, lessThan(1));

    // Halfway: the shield and the name are shown.
    await tester.pump(SplashCover.duration * 0.5);
    expect(shieldOpacity(tester), 1);
    expect(find.text('Wardkeep'), findsOneWidget);

    // Before the ground starts to fade, the shield is gone: it never lies over the home screen.
    await tester.pump(SplashCover.duration * 0.32); // at 0.82
    expect(shieldOpacity(tester), 0);
    expect(coverOpacity(tester), greaterThan(0.9));

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Wardkeep'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows nothing when the system asks for no animations', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    expect(find.byType(Image), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
