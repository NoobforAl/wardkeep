import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Links and config files that other apps (or the operating system) hand to Wardkeep:
///  - Android: a `vless://…` link tapped anywhere, "Open with" / "Share" on a `.ovpn`, `.conf`,
///    `.json`, `.yaml` or `.txt` file or on some text (see the intent filters in AndroidManifest.xml);
///  - Windows, Linux and macOS: the file or link is the first command-line argument when the system
///    starts the app for it; on Windows, if the app is already open, that second start hands the
///    argument to the open copy and ends.
/// Everything arrives as text for the importer, which already knows every format.
class IncomingShare {
  static const _channel = MethodChannel('omnitun/incoming');

  /// A config file is small; anything bigger is something else.
  static const maxBytes = 2 * 1024 * 1024;

  /// Starts listening (Android) and delivers what was waiting at start-up. Returns whether anything was
  /// delivered, so the first-run introduction can step aside for it.
  ///
  /// A file that could not be read (Android) is not silently dropped: [onProblem] gets the reason's code
  /// ("empty", "too_large", "not_text", "denied", "missing", "unreadable").
  static Future<bool> start(
    Future<void> Function(String text) deliver, {
    List<String> startup = const [],
    Future<void> Function(String code)? onProblem,
  }) async {
    var any = false;
    for (final text in startup) {
      any = true;
      await deliver(text);
    }
    if (Platform.isWindows) {
      // A second start of the app hands its command line to this copy (see windows/runner/main.cpp).
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'arguments') return;
        for (final text in await fromArguments([for (final a in call.arguments as List) a as String])) {
          await deliver(text);
        }
      });
      return any;
    }
    if (!Platform.isAndroid) return any;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') await _take(deliver, onProblem);
    });
    return await _take(deliver, onProblem) || any;
  }

  static Future<bool> _take(
    Future<void> Function(String text) deliver,
    Future<void> Function(String code)? onProblem,
  ) async {
    try {
      final res = await _channel.invokeMapMethod<String, String?>('take');
      final problem = res?['error'];
      if (problem != null) {
        await onProblem?.call(problem);
        return true;
      }
      final text = res?['text'];
      if (text == null || text.trim().isEmpty) return false;
      await deliver(text);
      return true;
    } on MissingPluginException {
      return false;
    }
  }

  /// What the command line asks to open: a share link as it is, a file by its contents.
  /// Arguments that are neither (flags, missing or oversized files) are ignored.
  static Future<List<String>> fromArguments(List<String> args) async {
    final out = <String>[];
    for (final arg in args) {
      if (arg.startsWith('-')) continue;
      if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://\S+$').hasMatch(arg) && !arg.startsWith('file://')) {
        out.add(arg);
        continue;
      }
      try {
        final file = File(arg.startsWith('file://') ? Uri.parse(arg).toFilePath() : arg);
        if (!await file.exists() || await file.length() > maxBytes) continue;
        out.add(utf8.decode(await file.readAsBytes(), allowMalformed: true));
      } catch (_) {
        // not a file we can read
      }
    }
    return out;
  }
}

/// What the app was started with (the command line); empty on phones. Overridden in `main`.
final startupSharesProvider = Provider<List<String>>((ref) => const []);
