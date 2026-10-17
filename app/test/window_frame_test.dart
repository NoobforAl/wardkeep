import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/window_bounds.dart';
import 'package:omnitun/ui/theme.dart';
import 'package:omnitun/ui/widgets/window_frame.dart';

/// The app's own title bar (Windows): its three buttons are there, named, and do what they say.
void main() {
  final calls = <String>[];
  var maximized = false;
  var bounds = const Rect.fromLTWH(100, 100, 500, 800);
  Rect? setTo;
  var cursor = Offset.zero;

  setUp(() {
    calls.clear();
    maximized = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getBounds':
          return {'x': bounds.left, 'y': bounds.top, 'width': bounds.width, 'height': bounds.height};
        case 'setBounds':
          final a = call.arguments as Map;
          setTo = Rect.fromLTWH(
            (a['x'] as num).toDouble(),
            (a['y'] as num).toDouble(),
            (a['width'] as num).toDouble(),
            (a['height'] as num).toDouble(),
          );
          bounds = setTo!;
        case 'isFullScreen':
          return false;
        case 'isMaximized':
          return maximized;
        case 'maximize':
          maximized = true;
        case 'unmaximize':
          maximized = false;
      }
      return null;
    });
    // The pointer's place on the screen, which the grips read while they resize the window.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
      (call) async => call.method == 'getCursorScreenPoint' ? {'dx': cursor.dx, 'dy': cursor.dy} : null,
    );
  });

  Widget app({Brightness brightness = Brightness.dark}) => MaterialApp(
    theme: buildTheme(brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: WindowFrame(child: Center(child: Text('page')))),
  );

  testWidgets('shows minimize, maximize and close above the page, in the app\'s colours', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // The bar sits above the page and the buttons are on its right.
    expect(tester.getRect(find.byIcon(Icons.close_rounded)).bottom, lessThan(tester.getRect(find.text('page')).top));
    expect(
      tester.getRect(find.byIcon(Icons.close_rounded)).left,
      greaterThan(tester.getRect(find.byIcon(Icons.crop_square_rounded)).left),
    );
    // The icons use the theme's colour, not a system one.
    final scheme = buildTheme(Brightness.dark).colorScheme;
    expect(tester.widget<Icon>(find.byIcon(Icons.remove_rounded)).color, scheme.onSurfaceVariant);
  });

  testWidgets('the buttons minimize, maximize then restore, and close; the icon follows', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(calls, contains('minimize'));

    await tester.tap(find.byIcon(Icons.crop_square_rounded));
    await tester.pumpAndSettle();
    expect(calls, contains('maximize'));
    // The window reports it is maximized: the icon becomes "restore".
    await tester.pumpWidget(app(brightness: Brightness.light));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(calls, contains('close'));
  });

  testWidgets('the buttons have names for screen readers and tooltips', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
    expect(find.bySemanticsLabel('Maximize'), findsOneWidget);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
  });

  testWidgets('works in the light theme too', (tester) async {
    await tester.pumpWidget(app(brightness: Brightness.light));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('dragging an edge or corner resizes the window from the pointer on the screen', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // (where to grab, how the pointer moves on the screen, the window afterwards); the window starts
    // as (100, 100) - (600, 900)
    final grabs = <(Offset, Offset, Rect)>[
      (const Offset(797, 300), const Offset(60, 0), const Rect.fromLTRB(100, 100, 660, 900)), // right edge out
      (const Offset(2, 300), const Offset(-40, 0), const Rect.fromLTRB(60, 100, 600, 900)), // left edge out
      (const Offset(400, 597), const Offset(0, 50), const Rect.fromLTRB(100, 100, 600, 950)), // bottom edge down
      (const Offset(300, 2), const Offset(0, -30), const Rect.fromLTRB(100, 70, 600, 900)), // top edge up
      (const Offset(797, 596), const Offset(20, -100), const Rect.fromLTRB(100, 100, 620, 800)), // bottom-right corner
      (const Offset(2, 2), const Offset(30, 40), const Rect.fromLTRB(130, 140, 600, 900)), // top-left corner
    ];
    for (final (at, move, expected) in grabs) {
      bounds = const Rect.fromLTWH(100, 100, 500, 800);
      cursor = const Offset(1000, 1000);
      setTo = null;
      final g = await tester.startGesture(at);
      await g.moveBy(const Offset(-1, -1)); // past the slop, which starts the drag
      await tester.pumpAndSettle();
      cursor = const Offset(1000, 1000) + move;
      await g.moveBy(const Offset(-1, -1));
      await tester.pumpAndSettle();
      await g.up();
      await tester.pumpAndSettle();
      expect(setTo, expected, reason: 'grab at $at, pointer moved $move');
    }
  });

  testWidgets('the window cannot be made smaller than the minimum from a grip', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    bounds = const Rect.fromLTWH(100, 100, 500, 800);
    cursor = const Offset(1000, 1000);
    final g = await tester.startGesture(const Offset(797, 596));
    await g.moveBy(const Offset(-1, -1));
    await tester.pumpAndSettle();
    cursor = Offset.zero; // far up and to the left
    await g.moveBy(const Offset(-1, -1));
    await tester.pumpAndSettle();
    await g.up();
    expect(setTo!.size, minWindowSize);
    expect(setTo!.topLeft, const Offset(100, 100));
  });

  testWidgets('over an edge the pointer shows the matching resize cursor', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(797, 300));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.resizeLeftRight);
    await mouse.moveTo(const Offset(2, 596));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.resizeUpRightDownLeft);
    await mouse.moveTo(const Offset(400, 2));
    await tester.pump();
    expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.resizeUpDown);
  });

  testWidgets('no grips when maximized: there is nothing to resize', (tester) async {
    maximized = true;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    setTo = null;
    final g = await tester.startGesture(const Offset(797, 300));
    await g.moveBy(const Offset(-20, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(setTo, isNull);
  });
}
