import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/ui/widgets/earth_globe.dart';

const _tehran = (35.7, 51.4);
const _berlin = (52.5, 13.4);

/// The home screen rebuilds the globe on every speed and clock tick. The globe must fly once
/// per change of place and stay still otherwise.
void main() {
  _flowTests();
  Widget globe({(double, double)? home, (double, double)? exit, Color exitColor = Colors.amber}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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

  group('the still Earth under the animation', () {
    // While the animation runs the still Earth is one picture, not nine thousand dots drawn on every frame.
    Finder cached() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_ImagePainter');
    Finder live() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_GlobePainter');

    testWidgets('becomes a picture once the view has stood still, and is drawn live again when it moves', (tester) async {
      await tester.pumpWidget(globe(connected: true, down: 100000));
      expect(live(), findsOneWidget, reason: 'drawn live at first');
      await tester.pump(const Duration(milliseconds: 100));
      expect(cached(), findsNothing, reason: 'not yet: the view has only just stopped');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(cached(), findsOneWidget);
      expect(live(), findsNothing);

      // turning it by hand draws it live again, and it settles again afterwards
      await tester.drag(find.byType(EarthBackdrop), const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(live(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(cached(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is never made while nothing animates', (tester) async {
      await tester.pumpWidget(globe());
      await tester.pump(const Duration(seconds: 2));
      expect(cached(), findsNothing);
      expect(live(), findsOneWidget);
    });
  });

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

    testWidgets('asks for a frame only when its clock moves: 8 a second when calm, more the faster the data moves', (tester) async {
      await tester.pumpWidget(globe(connected: true));
      await tester.pump(const Duration(seconds: 1)); // the Earth settles into its picture
      await tester.pump(const Duration(seconds: 1));
      expect(state(tester).flowPeriod, const Duration(milliseconds: 125));
      // Between two ticks nothing asks for a frame: a Ticker would ask at every screen refresh.
      expect(tester.binding.hasScheduledFrame, isFalse);
      var frames = 0;
      void count(Duration _) => frames++;
      tester.binding.addPersistentFrameCallback(count);
      await tester.pump(const Duration(seconds: 2));
      // pump() draws one frame; the timer's ticks schedule the others (the test binding runs them on pump only),
      // so what is checked is the number of clock changes seen by the overlay in two seconds.
      final clock = state(tester).clockForTest;
      final start = clock.value;
      var changes = 0;
      clock.addListener(() => changes++);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(changes, inInclusiveRange(15, 17), reason: 'about 8 a second for two seconds');
      expect(clock.value, greaterThan(start));

      await tester.pumpWidget(globe(connecting: true));
      expect(state(tester).flowPeriod, const Duration(milliseconds: 66));
      await tester.pumpWidget(globe());
      expect(state(tester).flowPeriod, Duration.zero);
      expect(frames, greaterThan(0));
    });

    testWidgets('has four speed steps, under 10 KB/s, to 1 MB/s, to 10 MB/s and above, each with its own frame rate', (tester) async {
      for (final (down, step, ms) in [
        (0, 0, 125),
        (9999, 0, 125),
        (10000, 1, 90),
        (800000, 1, 90),
        (1000000, 2, 66),
        (9000000, 2, 66),
        (10000000, 3, 50),
        (900000000, 3, 50),
      ]) {
        await tester.pumpWidget(globe(connected: true, down: down));
        expect(state(tester).speedStep, step, reason: '$down bytes a second');
        expect(state(tester).flowPeriod, Duration(milliseconds: ms), reason: '$down bytes a second');
        await tester.pumpWidget(globe()); // a new connection starts again from the slow step
        expect(state(tester).speedStep, 0);
      }
      // the louder way decides
      await tester.pumpWidget(globe(connected: true, up: 12000000, down: 100));
      expect(state(tester).speedStep, 3);
      await tester.pumpWidget(globe());
    });

    testWidgets('a speed hovering at a limit does not flicker between two steps', (tester) async {
      await tester.pumpWidget(globe(connected: true, down: 12000000));
      expect(state(tester).speedStep, 3);
      await tester.pumpWidget(globe(connected: true, down: 9000000));
      expect(state(tester).speedStep, 3, reason: 'still above 60 % of the limit');
      await tester.pumpWidget(globe(connected: true, down: 5000000));
      expect(state(tester).speedStep, 2);
      await tester.pumpWidget(globe(connected: true, down: 1200000));
      expect(state(tester).speedStep, 2);
      await tester.pumpWidget(globe(connected: true, down: 400000));
      expect(state(tester).speedStep, 1);
      await tester.pumpWidget(globe());
    });

    testWidgets('does not run when the system asks for less motion', (tester) async {
      await tester.pumpWidget(globe(connected: true, down: 500000, reduce: true));
      expect(state(tester).flowRunning, isFalse);
    });

    testWidgets('paints for every traffic level, with nothing moving too, without errors', (tester) async {
      for (final (up, down) in [(0, 0), (30, 40), (2000, 500), (100000, 3000000), (100000, 30000000), (900000000, 900000000)]) {
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

/// Zoom and the way back: pinch or wheel zooms, and a button (there only when the Earth is away from the place
/// it shows) brings it back.
void zoomTests() {
  Widget globe() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: EarthBackdrop(home: _tehran, homeColor: Colors.red, exitColor: Colors.amber),
      ),
    ),
  );
  EarthBackdropState state(WidgetTester tester) => tester.state<EarthBackdropState>(find.byType(EarthBackdrop));

  group('zooming the Earth', () {
    testWidgets('two fingers apart zoom in, together zoom out, within limits', (tester) async {
      await tester.pumpWidget(globe());
      final centre = tester.getCenter(find.byType(EarthBackdrop));
      final a = await tester.startGesture(centre + const Offset(-30, 0), pointer: 1);
      final b = await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(state(tester).userZoom, greaterThan(1.5), reason: 'the fingers went from 60 to 120 apart');
      await a.moveBy(const Offset(-400, 0));
      await b.moveBy(const Offset(400, 0));
      await tester.pump();
      expect(state(tester).userZoom, lessThanOrEqualTo(2.2), reason: 'the zoom has a limit');
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      // and pinching in
      final c = await tester.startGesture(centre + const Offset(-100, 0), pointer: 3);
      final d = await tester.startGesture(centre + const Offset(100, 0), pointer: 4);
      await c.moveBy(const Offset(90, 0));
      await d.moveBy(const Offset(-90, 0));
      await tester.pump();
      expect(state(tester).userZoom, lessThan(2.2));
      await c.up();
      await d.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the mouse wheel zooms, and does not push the zoom past its limits', (tester) async {
      await tester.pumpWidget(globe());
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      final at = tester.getCenter(find.byType(EarthBackdrop));
      await tester.sendEventToBinding(mouse.hover(at));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
      await tester.pump();
      expect(state(tester).userZoom, greaterThan(1.3), reason: 'scrolling up zooms in');
      for (var i = 0; i < 20; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, -300)));
      }
      await tester.pump();
      expect(state(tester).userZoom, lessThanOrEqualTo(2.2));
      for (var i = 0; i < 40; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
      }
      await tester.pump();
      expect(state(tester).userZoom, greaterThanOrEqualTo(0.6));
    });

    testWidgets('a button appears once the Earth is away, and brings it, turn and zoom, back', (tester) async {
      await tester.pumpWidget(globe());
      final button = find.byIcon(Icons.my_location_rounded);
      double opacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: button, matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacity(), 0, reason: 'nothing to go back to yet');

      await tester.drag(find.byType(EarthBackdrop), const Offset(80, 30));
      await tester.pumpAndSettle();
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.byType(EarthBackdrop))));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(state(tester).turn, isNot((0.0, 0.0)));
      expect(state(tester).userZoom, isNot(1.0));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(state(tester).turn, (0.0, 0.0));
      expect(state(tester).userZoom, 1.0);
      expect(opacity(), 0, reason: 'back where it started: the button goes away again');
    });

    testWidgets('a pinch is not a tap (two taps bring it back, a pinch must not)', (tester) async {
      await tester.pumpWidget(globe());
      final centre = tester.getCenter(find.byType(EarthBackdrop));
      final a = await tester.startGesture(centre + const Offset(-30, 0), pointer: 1);
      final b = await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final zoomed = state(tester).userZoom;
      expect(zoomed, greaterThan(1.3));
      // another touch right after must not count as the second tap of a double tap
      await tester.tap(find.byType(EarthBackdrop));
      await tester.pumpAndSettle();
      expect(state(tester).userZoom, zoomed);
    });
  });
}

  zoomTests();
}
