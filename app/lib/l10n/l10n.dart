import 'package:flutter/widgets.dart';

import '../engine/engine.dart';
import '../state/countries.dart';
import '../state/country_names.dart';
import '../ui/theme.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.something`: the app's translations.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// A country's name in the language of the app (English where there is no translation).
  String countryName(String code) =>
      countryNamesByLanguage[Localizations.localeOf(this).languageCode]?[code] ?? countryNames[code] ?? code;
}

/// What to show as a profile's address (Tor has no server).
String profileAddress(BuildContext context, ProfileInfo p) => p.protocol == 'tor' ? context.l10n.torNetwork : p.address;

/// The languages the app is translated into. The first is the fallback.
const supportedLanguages = <(String code, String name)>[
  ('en', 'English'),
  ('fa', 'فارسی'),
  ('ru', 'Русский'),
  ('zh', '中文'),
  ('ar', 'العربية'),
  ('es', 'Español'),
  ('hi', 'हिन्दी'),
  ('fr', 'Français'),
  ('pt', 'Português'),
  ('ur', 'اردو'),
  ('id', 'Bahasa Indonesia'),
  ('tr', 'Türkçe'),
  ('vi', 'Tiếng Việt'),
];

/// Words a failure the way the core described it, in the user's language.
/// Falls back to the core's English message for anything unusual.
String? localizedError(AppLocalizations l, EngineState s) {
  final message = s.error;
  if (message == null) return null;
  final code = s.errorCode;
  final reason = code == null ? null : errorCodeText(l, code);
  if (code == 'NO_NETWORK') return l.statusNoInternet;
  if (reason == null) return message;
  // Messages that name no stage (permission, the Tor texts) stand alone.
  const standalone = {
    'NO_PERMISSION',
    'CORE_LOST',
    'TOR_TIMEOUT',
    'TOR_BRIDGE_TIMEOUT',
    'TOR_BAD_BRIDGE',
    'TOR_MISSING',
    'TOR_EXITED',
    'DNSTT_EXITED',
    'ENGINE_FATAL',
    'PANIC',
    'INTERNAL',
    'TOR_STREAM_FAILED',
  };
  final stage = s.progress?.stage;
  if (standalone.contains(code) || stage == null) return reason;
  return l.errorFailed(stageLabel(l, stage), reason);
}

/// The translation of a connection failure's code (the engine's `ErrorCode`, also the `code` of a log
/// record), or null for a code that has none.
String? errorCodeText(AppLocalizations l, String code) => switch (code) {
    'TIMEOUT' => l.errTimeout,
    'REFUSED' => l.errRefused,
    'RESET' => l.errReset,
    'NO_ROUTE' => l.errNoRoute,
    'NETWORK_UNREACHABLE' => l.errNetworkUnreachable,
    'DNS_FAILED' => l.errDns,
    'TLS_ERROR' => l.errTls,
    'AUTH_FAILED' => l.errAuth,
    'CLOSED' => l.errClosed,
    'CERT_DATE' => l.errCertDate,
    'CERT_UNTRUSTED' => l.errCertUntrusted,
    'CERT_NAME' => l.errCertName,
    'TLS_KEYS' => l.errTlsKeys,
    'REALITY_REJECTED' => l.errReality,
    'NO_HANDSHAKE' => l.errNoHandshake,
    'UDP_BLOCKED' => l.errUdpBlocked,
    'PORT_IN_USE' => l.errPortInUse,
    'TOR_TIMEOUT' => l.errTorTimeout,
    'TOR_BRIDGE_TIMEOUT' => l.errTorBridgeTimeout,
    'TOR_BAD_BRIDGE' => l.errTorBadBridge,
    'TOR_MISSING' => l.errTorMissing,
    'NO_PERMISSION' => l.errPermission,
    'CORE_LOST' => l.errCoreLost,
    'NO_NETWORK' => l.statusNoInternet,
    'TOR_EXITED' => l.errTorExited,
    'DNSTT_EXITED' => l.errDnsttExited,
    'ENGINE_FATAL' => l.errEngineFatal,
    'PANIC' || 'INTERNAL' => l.errPanic,
    'TOR_STREAM_FAILED' => l.errTorStreamFailed,
    _ => null,
  };
