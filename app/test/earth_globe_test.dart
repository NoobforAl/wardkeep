import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/ui/widgets/earth_globe.dart';

const _tehran = (35.7, 51.4);
const _berlin = (52.5, 13.4);

/// The home screen rebuilds the globe on every speed and clock tick. The globe must fly once
/// per change of place and stay still otherwise.
void main() {
  Widget globe({(double, double)? home, (double, double)? exit, Color exitColor = Colors.amber}) => MaterialApp(
    home: SizedBox(
      width: 400,
      height: 400,
      child: EarthBackdrop(home: home, exit: exit, homeColor: Colors.red, exitColor: exitColor),
    ),
  );

  testWidgets('rebuilding with the same places in the middle of a flight does not restart it', (tester) async {
    await tester.pumpWidget(globe(home: _tehran));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse, reason: 'at rest the globe does not animate');

    // Connecting: one flight to the exit...
    await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
    // ...while the screen rebuilds every 100 ms (speed, clock).
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
    }
    // 2.5 s later the 2 s flight is over; it was not restarted by the rebuilds.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse, reason: 'the flight was restarted by a rebuild');
  });

  testWidgets('the exit changing colour on "connected" does not start a second flight', (tester) async {
    await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
    await tester.pumpAndSettle();
    await tester.pumpWidget(globe(home: _tehran, exit: _berlin, exitColor: Colors.teal));
    expect(tester.hasRunningAnimations, isFalse, reason: 'a colour change flew the globe again');
  });

  testWidgets('disconnecting flies back once', (tester) async {
    await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
    await tester.pumpAndSettle();
    await tester.pumpWidget(globe(home: _tehran));
    expect(tester.hasRunningAnimations, isTrue);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(globe(home: _tehran));
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a new exit in the middle of a flight turns the globe from where it is, once', (tester) async {
    await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpWidget(globe(home: _tehran, exit: (40.7, -74.0)));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(globe(home: _tehran, exit: (40.7, -74.0)));
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
