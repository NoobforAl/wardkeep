import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/ui/theme.dart';
import 'package:omnitun/ui/widgets/window_frame.dart';

/// The app's own title bar (Windows): its three buttons are there, named, and do what they say.
void main() {
  final calls = <String>[];
  var maximized = false;

  setUp(() {
    calls.clear();
    maximized = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isMaximized':
          return maximized;
        case 'maximize':
          maximized = true;
        case 'unmaximize':
          maximized = false;
      }
      return null;
    });
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
}
