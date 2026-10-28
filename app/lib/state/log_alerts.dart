import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import 'providers.dart';

/// The latest failure nothing handled (a log record with `notify: true`, docs/logging.md §5) that the user is
/// to be told about; the app's root shows it (a red notice, a system notification). The same connection and
/// code are told once.
class LogAlertsController extends Notifier<LogRecord?> {
  /// The most connection + code pairs remembered as told.
  static const _rememberedAlerts = 200;

  final _told = <String>{};

  @override
  LogRecord? build() {
    final subscription = ref.watch(engineProvider).logs.listen(report);
    ref.onDispose(subscription.cancel);
    return null;
  }

  /// Tells [record] when it asks to be told and the same one has not been yet.
  void report(LogRecord record) {
    if (!record.notify) return;
    // A record without a code is told by its message, so two different failures are not taken for one.
    final key = '${record.conn}\u0000${record.code.isEmpty ? record.msg : record.code}';
    if (!_told.add(key)) return;
    if (_told.length > _rememberedAlerts) _told.remove(_told.first);
    state = record;
  }
}

final logAlertsProvider = NotifierProvider<LogAlertsController, LogRecord?>(LogAlertsController.new);
