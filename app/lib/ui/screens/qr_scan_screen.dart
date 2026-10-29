import 'dart:async';

import 'package:camera/camera.dart' show CameraException, FlashMode, availableCameras;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../l10n/l10n.dart';

/// The camera part of [QrScanScreen]: shows the preview and reports what it reads.
///
/// [onCode] gets the text of a QR code, [onError] a short code for a camera that
/// cannot be used (no permission, no camera), and [onTorch] a function that
/// switches the torch once the camera is open. Tests pass a fake.
typedef QrCameraBuilder =
    Widget Function(
      BuildContext context, {
      required ValueChanged<String> onCode,
      required ValueChanged<String> onError,
      required ValueChanged<Future<void> Function()> onTorch,
    });

/// Scans a QR code and pops with its text (a share link or subscription URL).
///
/// The decoder is zxing-cpp (flutter_zxing) on the camera plugin's CameraX
/// backend: no Google ML Kit or Play services in the app.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.camera = zxingCamera});

  final QrCameraBuilder camera;

  /// Whether the camera scanner works on this platform. The camera plugin has
  /// no macOS or desktop backend.
  static bool get supported => const [TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform);

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  String? _error;
  Future<void> Function()? _toggleTorch;

  void _onCode(String text) {
    final value = text.trim();
    if (_done || !mounted || value.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  void _onError(String code) {
    if (mounted) setState(() => _error = code);
  }

  void _onTorch(Future<void> Function() toggle) {
    if (mounted) setState(() => _toggleTorch = toggle);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.scanTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.scanTorch,
            onPressed: error == null ? _toggleTorch : null,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.scanCameraUnavailable(error), textAlign: TextAlign.center),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                widget.camera(context, onCode: _onCode, onError: _onError, onTorch: _onTorch),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 48,
                  child: Text(
                    context.l10n.scanPoint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4)]),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The real camera: flutter_zxing's [ReaderWidget] without its own buttons and overlay.
Widget zxingCamera(
  BuildContext context, {
  required ValueChanged<String> onCode,
  required ValueChanged<String> onError,
  required ValueChanged<Future<void> Function()> onTorch,
}) => _ZxingCamera(onCode: onCode, onError: onError, onTorch: onTorch);

class _ZxingCamera extends StatefulWidget {
  const _ZxingCamera({required this.onCode, required this.onError, required this.onTorch});

  final ValueChanged<String> onCode;
  final ValueChanged<String> onError;
  final ValueChanged<Future<void> Function()> onTorch;

  @override
  State<_ZxingCamera> createState() => _ZxingCameraState();
}

class _ZxingCameraState extends State<_ZxingCamera> {
  /// ReaderWidget waits forever on a device without a camera, so look first.
  late final Future<bool> _hasCamera = availableCameras().then((cameras) => cameras.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _hasCamera.then((has) {
      if (!has) widget.onError('noCamera');
    }, onError: (Object e) => widget.onError(_errorCode(e)));
  }

  static String _errorCode(Object e) => switch (e) {
    // CameraAccessDenied, CameraAccessDeniedWithoutPrompt, CameraAccessRestricted, …
    CameraException(:final code) => code,
    _ => e.runtimeType.toString(),
  };

  void _onController(CameraController? controller, Exception? error) {
    if (error != null || controller == null) {
      widget.onError(error == null ? 'noCamera' : _errorCode(error));
      return;
    }
    widget.onTorch(() async {
      final on = controller.value.flashMode == FlashMode.torch;
      try {
        await controller.setFlashMode(on ? FlashMode.off : FlashMode.torch);
      } on CameraException catch (e) {
        debugPrint('torch: ${e.code}');
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _hasCamera,
    builder: (context, snapshot) => snapshot.data != true
        ? const ColoredBox(color: Colors.black)
        : ReaderWidget(
            codeFormat: Format.qrCode,
            onScan: (code) {
              final text = code.text;
              if (code.isValid && text != null) widget.onCode(text);
            },
            onControllerCreated: _onController,
            // The whole frame is scanned; the white square on top is only a guide.
            cropPercent: 0,
            showScannerOverlay: false,
            showFlashlight: false,
            showGallery: false,
            showToggleCamera: false,
            // Try the next frame right away rather than once a second.
            scanDelay: const Duration(milliseconds: 50),
            tryHarder: true,
          ),
  );
}
