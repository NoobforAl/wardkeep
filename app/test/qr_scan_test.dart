import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/ui/screens/qr_scan_screen.dart';

/// A camera the test drives by hand: it hands its callbacks out and shows nothing.
class _FakeCamera {
  ValueChanged<String>? onCode;
  ValueChanged<String>? onError;
  ValueChanged<Future<void> Function()>? onTorch;

  Widget build(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required ValueChanged<String> onError,
    required ValueChanged<Future<void> Function()> onTorch,
  }) {
    this.onCode = onCode;
    this.onError = onError;
    this.onTorch = onTorch;
    return const ColoredBox(key: Key('camera'), color: Colors.black);
  }
}

void main() {
  late _FakeCamera camera;
  String? popped;

  Future<void> open(WidgetTester tester) async {
    camera = _FakeCamera();
    popped = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(
                context,
              ).push<String>(MaterialPageRoute(builder: (_) => QrScanScreen(camera: camera.build)));
            },
            child: const Text('scan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('pops with the first code read, trimmed, and only once', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('camera')), findsOneWidget);
    expect(find.text('Point the camera at a config QR code'), findsOneWidget);

    camera.onCode!('  vless://abc@example.com:443  ');
    camera.onCode!('trojan://second'); // a frame that was already in flight
    await tester.pumpAndSettle();
    expect(popped, 'vless://abc@example.com:443');
    expect(find.byType(QrScanScreen), findsNothing);
  });

  testWidgets('ignores an empty code', (tester) async {
    await open(tester);
    camera.onCode!('   ');
    await tester.pumpAndSettle();
    expect(find.byType(QrScanScreen), findsOneWidget);
  });

  testWidgets('the torch works once the camera is open', (tester) async {
    await open(tester);
    final torch = find.widgetWithIcon(IconButton, Icons.flashlight_on_outlined);
    expect(tester.widget<IconButton>(torch).onPressed, isNull);

    var toggles = 0;
    camera.onTorch!(() async => toggles++);
    await tester.pump();
    await tester.tap(torch);
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('a camera that cannot be used says why instead of the preview', (tester) async {
    await open(tester);
    camera.onError!('CameraAccessDenied');
    await tester.pump();
    expect(find.text('Camera unavailable: CameraAccessDenied'), findsOneWidget);
    expect(find.byKey(const Key('camera')), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.flashlight_on_outlined)).onPressed, isNull);
  });
}
