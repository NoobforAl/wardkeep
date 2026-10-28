import 'dart:convert';

/// One record of the log, the same in every part of the app (docs/logging.md §1): what happened ([msg]),
/// how bad it was ([level]), which part said it ([source]) and the context that ties records together
/// ([conn] for one connect attempt, [op], [profile]). Keys the app does not know are kept in [extra].
class LogRecord {
  const LogRecord({
    required this.time,
    required this.level,
    required this.source,
    required this.msg,
    this.target = '',
    this.op = '',
    this.conn = '',
    this.profile = '',
    this.code = '',
    this.err = '',
    this.notify = false,
    this.caller = '',
    this.stack = '',
    this.extra = const {},
  });

  /// A record of the app's own (source `app`), such as "reconnected to the core".
  factory LogRecord.app(String msg, {String level = 'info', String code = '', String err = ''}) =>
      LogRecord(time: DateTime.now(), level: level, source: 'app', msg: msg, code: code, err: err);

  /// The levels from the least to the most severe.
  static const levels = ['trace', 'debug', 'info', 'warn', 'error', 'fatal'];

  /// The keys this class holds in fields of its own; every other key goes to [extra].
  static const knownKeys = {
    'time',
    'level',
    'source',
    'msg',
    'message',
    'target',
    'op',
    'conn',
    'profile',
    'code',
    'err',
    'notify',
    'caller',
    'stack',
  };

  final DateTime time;

  /// One of [levels].
  final String level;

  /// `core`, `sing-box`, `tor`, `dnstt`, `dnscrypt`, `server` or `app`.
  final String source;
  final String msg;
  final String target, op, conn, profile, code, err;

  /// Nothing handled this failure: the user should be told (docs/logging.md §5).
  final bool notify;
  final String caller, stack;

  /// Keys that are not part of the contract (shown as key=value).
  final Map<String, Object?> extra;

  /// Reads a record of the control protocol's `log` event. Older cores send `message` instead of `msg`, and
  /// may leave out everything but the time, the level and the message.
  factory LogRecord.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      return value == null ? '' : '$value';
    }

    final level = normalizeLevel(text('level'));
    final message = json['msg'] ?? json['message'];
    return LogRecord(
      time: DateTime.tryParse(text('time'))?.toLocal() ?? DateTime.now(),
      level: level,
      source: text('source').isEmpty ? 'core' : text('source'),
      msg: message == null ? '' : '$message',
      target: text('target'),
      op: text('op'),
      conn: text('conn'),
      profile: text('profile'),
      code: text('code'),
      err: text('err'),
      notify: json['notify'] == true,
      caller: text('caller'),
      stack: text('stack'),
      extra: {
        for (final entry in json.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// The record as the contract writes it (for an export): `time` in UTC, empty keys left out.
  Map<String, Object?> toJson() => {
    'time': DateTime.fromMillisecondsSinceEpoch(time.millisecondsSinceEpoch, isUtc: true).toIso8601String(),
    'level': level,
    'source': source,
    'msg': msg,
    if (target.isNotEmpty) 'target': target,
    if (op.isNotEmpty) 'op': op,
    if (conn.isNotEmpty) 'conn': conn,
    if (profile.isNotEmpty) 'profile': profile,
    if (code.isNotEmpty) 'code': code,
    if (err.isNotEmpty) 'err': err,
    if (notify) 'notify': true,
    if (caller.isNotEmpty) 'caller': caller,
    if (stack.isNotEmpty) 'stack': stack,
    ...extra,
  };

  /// A known level in lower case; `warning` is `warn`, anything unknown is `info`.
  static String normalizeLevel(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'warning') return 'warn';
    if (lower == 'panic' || lower == 'critical') return 'fatal';
    return levels.contains(lower) ? lower : 'info';
  }

  /// The place of [level] in [levels]: the higher, the more severe.
  int get severity => levels.indexOf(level);

  bool get isError => severity >= levels.indexOf('error');

  /// The local time of day with milliseconds, as the log page shows it.
  String get clock {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Everything besides the time, level, source and message, in the contract's order, then the unknown keys.
  /// The stack is left out: it has lines of its own.
  List<(String key, String value)> get fields => [
    if (target.isNotEmpty) ('target', target),
    if (op.isNotEmpty) ('op', op),
    if (conn.isNotEmpty) ('conn', conn),
    if (profile.isNotEmpty) ('profile', profile),
    if (code.isNotEmpty) ('code', code),
    if (err.isNotEmpty) ('err', err),
    if (notify) ('notify', 'true'),
    if (caller.isNotEmpty) ('caller', caller),
    for (final entry in extra.entries)
      (entry.key, entry.value is String ? entry.value as String : jsonEncode(entry.value)),
  ];

  /// One line of plain text (what "copy all" copies), with the stack below it when there is one.
  String toLine() {
    final rest = fields.map((field) => '${field.$1}=${field.$2}').join(' ');
    final line = '$clock  ${level.toUpperCase().padRight(5)} $source: $msg${rest.isEmpty ? '' : '  $rest'}';
    return stack.isEmpty ? line : '$line\n$stack';
  }

  @override
  String toString() => toLine();
}

/// What the core logs (docs/logging.md §3, `logging.get`): the [level] in use ('' when it is the build's
/// [defaultLevel]), the build [mode] (`release` or `dev`) and when a chosen level ends.
class LoggingMode {
  const LoggingMode({this.level = '', this.defaultLevel = '', this.mode = '', this.until});

  final String level;
  final String defaultLevel;
  final String mode;
  final DateTime? until;

  /// The level records are kept at now.
  String get effectiveLevel => level.isEmpty ? defaultLevel : level;

  factory LoggingMode.fromJson(Map<String, dynamic> json) => LoggingMode(
    level: json['level'] as String? ?? '',
    defaultLevel: json['default'] as String? ?? '',
    mode: json['mode'] as String? ?? '',
    until: DateTime.tryParse(json['until'] as String? ?? '')?.toLocal(),
  );
}
