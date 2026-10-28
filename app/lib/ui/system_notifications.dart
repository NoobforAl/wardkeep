import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

/// Notifications of the system for failures nothing handled (docs/logging.md §5, setting `notifyOs`):
/// Android's notification shade (MainActivity's "omnitun/notify" channel, on its "errors" channel), the
/// desktop's notification centre (local_notifier). Tapping one opens the log page filtered by its connection.
class SystemNotifications {
  static const _channel = MethodChannel('omnitun/notify');

  void Function(String conn)? _openLogs;
  bool _desktopReady = false;

  static bool get _desktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Listens for taps on the notifications; on Android also asks whether the app was opened by one.
  Future<void> start(void Function(String conn) openLogs) async {
    _openLogs = openLogs;
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openLogs') openLogs(call.arguments as String? ?? '');
    });
    try {
      final conn = await _channel.invokeMethod<String>('takeOpenLogs');
      if (conn != null) openLogs(conn);
    } on MissingPluginException {
      // No Android side (a test).
    } on PlatformException {
      // Nothing to open.
    }
  }

  /// Shows [title] and [body]; a tap opens the log page filtered by [conn]. Fails quietly: the app has told
  /// the user in its own window too, when it is open.
  Future<void> show({required String title, required String body, required String conn}) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('show', {'title': title, 'body': body, 'conn': conn});
      } else if (_desktop) {
        if (!_desktopReady) {
          // Windows needs a Start menu shortcut with the app's id for a notification; this makes one if missing.
          await localNotifier.setup(appName: 'Wardkeep', shortcutPolicy: ShortcutPolicy.requireCreate);
          _desktopReady = true;
        }
        final notification = LocalNotification(title: title, body: body);
        notification.onClick = () async {
          try {
            // The window may be hidden in the tray.
            await windowManager.show();
            await windowManager.focus();
          } catch (_) {}
          _openLogs?.call(conn);
        };
        await notification.show();
      }
    } catch (_) {
      // No notification service (a test, a Linux desktop without one).
    }
  }
}

final systemNotificationsProvider = Provider<SystemNotifications>((ref) => SystemNotifications());
