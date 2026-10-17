import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/ui/widgets/earth_globe.dart';

const _tehran = (35.7, 51.4);
const _berlin = (52.5, 13.4);

/// The home screen rebuilds the globe on every speed and clock tick. The globe must fly once
/// per change of place and stay still otherwise.
void main() {
  _flowTests();
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

  group('turning the Earth by hand', () {
    EarthBackdropState state(WidgetTester tester) => tester.state<EarthBackdropState>(find.byType(EarthBackdrop));

    Future<void> rest(WidgetTester tester) async {
      await tester.pumpWidget(globe(home: _tehran));
      await tester.pumpAndSettle();
    }

    testWidgets('dragging right turns it west, up turns it south, the way a ball under a finger turns', (tester) async {
      await rest(tester);
      final before = state(tester).shownCentre;
      await tester.drag(find.byType(EarthBackdrop), const Offset(80, 0));
      await tester.pumpAndSettle();
      final after = state(tester).shownCentre;
      expect(after.$2, lessThan(before.$2), reason: 'a drag to the right shows land further west');
      await tester.drag(find.byType(EarthBackdrop), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(state(tester).shownCentre.$1, lessThan(after.$1), reason: 'a drag up shows land further south');
    });

    testWidgets('it cannot be turned past the poles', (tester) async {
      await rest(tester);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(EarthBackdrop), const Offset(0, 150));
      }
      await tester.pumpAndSettle();
      expect(state(tester).shownCentre.$1, lessThanOrEqualTo(75.0));
      for (var i = 0; i < 16; i++) {
        await tester.drag(find.byType(EarthBackdrop), const Offset(0, -150));
      }
      await tester.pumpAndSettle();
      expect(state(tester).shownCentre.$1, greaterThanOrEqualTo(-75.0));
    });

    testWidgets('a fling coasts and then stops by itself', (tester) async {
      await rest(tester);
      await tester.fling(find.byType(EarthBackdrop), const Offset(200, 0), 1500);
      await tester.pump(const Duration(milliseconds: 100));
      final early = state(tester).turn.$2;
      await tester.pump(const Duration(milliseconds: 200));
      expect(state(tester).turn.$2, isNot(early), reason: 'it should still be coasting');
      await tester.pumpAndSettle();
      final stopped = state(tester).turn.$2;
      await tester.pump(const Duration(seconds: 2));
      expect(state(tester).turn.$2, stopped);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a double tap brings it back to the place it shows', (tester) async {
      await rest(tester);
      final home = state(tester).shownCentre;
      await tester.drag(find.byType(EarthBackdrop), const Offset(-90, 40));
      await tester.pumpAndSettle();
      expect(state(tester).shownCentre, isNot(home));
      await tester.tap(find.byType(EarthBackdrop));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(EarthBackdrop));
      await tester.pumpAndSettle();
      final back = state(tester).shownCentre;
      expect((back.$1 - home.$1).abs(), lessThan(0.1));
      expect((back.$2 - home.$2).abs(), lessThan(0.1));
    });

    testWidgets('a new place after the user turned it flies on from where the user left it', (tester) async {
      await rest(tester);
      await tester.drag(find.byType(EarthBackdrop), const Offset(120, 30));
      await tester.pumpAndSettle();
      final left = state(tester).shownCentre;
      await tester.pumpWidget(globe(home: _tehran, exit: _berlin));
      final start = state(tester).shownCentre;
      expect((start.$1 - left.$1).abs(), lessThan(0.5), reason: 'the globe jumped when the flight began');
      expect((start.$2 - left.$2).abs(), lessThan(0.5), reason: 'the globe jumped when the flight began');
      await tester.pumpAndSettle();
      expect(state(tester).turn, (0.0, 0.0));
    });

    testWidgets('it turns inside a page that scrolls, and the page still scrolls elsewhere', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(
          controller: controller,
          child: Column(children: [
            SizedBox(
              width: 300,
              height: 300,
              child: EarthBackdrop(home: _tehran, homeColor: Colors.red, exitColor: Colors.amber),
            ),
            const SizedBox(height: 1200, width: 300),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final before = state(tester).turn;
      await tester.drag(find.byType(EarthBackdrop), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(controller.offset, 0, reason: 'a drag on the Earth must not scroll the page');
      expect(state(tester).turn, isNot(before));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400), warnIfMissed: false);
      await tester.dragFrom(const Offset(700, 500), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0), reason: 'the page scrolls where the Earth is not');
    });
  });
}

/// The connection animation: it runs only while connecting or connected, never while idle, and not when
/// the system asks for less motion; and it paints (a packet, rings, a line and dots) without errors.
void _flowTests() {
  Widget globe({bool connecting = false, bool connected = false, int up = 0, int down = 0, bool reduce = false}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: SizedBox(
            width: 400,
            height: 400,
            child: EarthBackdrop(
              home: _tehran,
              exit: _berlin,
              homeColor: Colors.red,
              exitColor: Colors.teal,
              connecting: connecting,
              connected: connected,
              upBps: up,
              downBps: down,
            ),
          ),
        ),
      );
  EarthBackdropState state(WidgetTester tester) => tester.state<EarthBackdropState>(find.byType(EarthBackdrop));

  group('the connection animation', () {
    testWidgets('does not run when idle, runs while connecting and while connected, stops after', (tester) async {
      await tester.pumpWidget(globe());
      await tester.pumpAndSettle();
      expect(state(tester).flowRunning, isFalse);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(globe(connecting: true));
      expect(state(tester).flowRunning, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(globe(connected: true, up: 20000, down: 800000));
      expect(state(tester).flowRunning, isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(globe());
      expect(state(tester).flowRunning, isFalse, reason: 'it must stop when the VPN is off');
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('does not run when the system asks for less motion', (tester) async {
      await tester.pumpWidget(globe(connected: true, down: 500000, reduce: true));
      expect(state(tester).flowRunning, isFalse);
    });

    testWidgets('paints for every traffic level, with nothing moving too, without errors', (tester) async {
      for (final (up, down) in [(0, 0), (30, 40), (2000, 500), (100000, 3000000), (900000000, 900000000)]) {
        await tester.pumpWidget(globe(connected: true, up: up, down: down));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: 'up $up down $down');
      }
      await tester.pumpWidget(globe(connecting: true));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(globe());
    });

    testWidgets('keeps going when the Earth is turned by hand, and the dotted Earth is not redrawn for it', (tester) async {
      await tester.pumpWidget(globe(connected: true, down: 100000));
      await tester.drag(find.byType(EarthBackdrop), const Offset(60, 0));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state(tester).flowRunning, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(globe());
      await tester.pumpAndSettle();
    });
  });
}
