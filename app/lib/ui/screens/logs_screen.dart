import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../import_file.dart';
import '../theme.dart';

/// The log page: the latest records of the core and the app, the newest at the bottom. They can be narrowed
/// to a level and up, and to one connect attempt ([conn], what "View logs" on a failure opens it with).
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key, this.conn = ''});

  /// Only the records of this connect attempt; '' for all.
  final String conn;

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  /// The least severe level shown.
  String _minimumLevel = LogRecord.levels.first;
  late String _conn = widget.conn;

  List<LogRecord> _visible(List<LogRecord> records) {
    final minimum = LogRecord.levels.indexOf(_minimumLevel);
    return [
      for (final record in records)
        if (record.severity >= minimum && (_conn.isEmpty || record.conn == _conn)) record,
    ];
  }

  Future<void> _export(List<LogRecord> records) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final jsonLines = '${records.map((record) => jsonEncode(record.toJson())).join('\n')}\n';
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'wardkeep-log.jsonl',
        bytes: Uint8List.fromList(utf8.encode(jsonLines)),
        mimeType: 'application/jsonl',
        dialogTitle: l.logsExport,
      );
      if (saved != null) messenger.showSnackBar(SnackBar(content: Text(l.logsSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFileProblem(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final logs = _visible(ref.watch(logsProvider));
    final filtered = _minimumLevel != LogRecord.levels.first || _conn.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tooltipLogs),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.logsLevel,
            icon: Icon(_minimumLevel == LogRecord.levels.first ? Icons.filter_list_rounded : Icons.filter_list_alt),
            initialValue: _minimumLevel,
            onSelected: (level) => setState(() => _minimumLevel = level),
            itemBuilder: (_) => [
              for (final level in LogRecord.levels)
                PopupMenuItem(
                  value: level,
                  child: Text(
                    level == LogRecord.levels.first ? l.logsLevelAll : level.toUpperCase(),
                    style: TextStyle(color: logLevelColor(Theme.of(context), level)),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: context.l10n.actionCopyAll,
            onPressed: logs.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: logs.map((record) => record.toLine()).join('\n'))),
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: l.logsExport,
            onPressed: logs.isEmpty ? null : () => _export(logs),
            icon: const Icon(Icons.save_alt_rounded),
          ),
          IconButton(
            tooltip: context.l10n.actionClear,
            onPressed: logs.isEmpty ? null : () => ref.read(logsProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_conn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  key: const Key('logs-conn-filter'),
                  avatar: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l.logsConnection(_conn)),
                  onDeleted: () => setState(() => _conn = ''),
                ),
              ),
            ),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text(filtered ? l.logsNoMatch : context.l10n.logsEmpty))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _LogLine(logs[logs.length - 1 - i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The colour a level is shown in: errors red, warnings amber, the chatty levels dimmed.
Color logLevelColor(ThemeData theme, String level) => switch (level) {
  'fatal' || 'error' => theme.colorScheme.error,
  'warn' => connectingAmber,
  'info' => theme.colorScheme.primary,
  _ => theme.colorScheme.onSurfaceVariant,
};

/// One record: time, level, source and message, then key=value for the rest, and the stack below.
class _LogLine extends StatelessWidget {
  const _LogLine(this.record);

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final translated = record.code.isEmpty ? null : logRecordText(context.l10n, record);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SelectableText.rich(
        TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          children: [
            TextSpan(text: '${record.clock}  ', style: dim),
            TextSpan(
              text: record.level.toUpperCase().padRight(5),
              style: TextStyle(color: logLevelColor(theme, record.level), fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' ${record.source}: ', style: dim),
            TextSpan(text: record.msg),
            for (final (key, value) in record.fields)
              TextSpan(text: '  $key=$value', style: dim),
            if (translated != null && translated != record.msg) TextSpan(text: '\n  $translated', style: dim),
            if (record.stack.isNotEmpty) TextSpan(text: '\n${record.stack}', style: dim),
          ],
        ),
      ),
    );
  }
}
