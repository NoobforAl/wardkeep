import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/ui/widgets/splash.dart';

void main() {
  Widget app({bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const SplashCover(child: Text('home')),
        ),
      );

  testWidgets('shows the whole shield over the app, then goes away', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 200)); // the picture is decoded
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('home'), findsOneWidget); // the app is built underneath already

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows nothing when the system asks for no animations', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    expect(find.byType(Image), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
