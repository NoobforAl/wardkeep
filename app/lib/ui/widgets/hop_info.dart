import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../motion.dart';
import '../screens/home_screen.dart' show maskIp;
import 'country_flag.dart';

/// A stop on the route the traffic takes, as the home screen shows it: you, the VPN server, or one relay of a
/// Tor circuit.
enum HopKind { you, server, bridge, entry, relay, exit }

/// The kind of a Tor circuit's hop, from the role the core reports (`bridge`, `guard`, `middle`, `exit`).
HopKind hopKindOfRole(String role) => switch (role) {
  'bridge' => HopKind.bridge,
  'guard' => HopKind.entry,
  'exit' => HopKind.exit,
  _ => HopKind.relay,
};

IconData hopIcon(HopKind kind) => switch (kind) {
  HopKind.you => Icons.my_location_rounded,
  HopKind.server => Icons.dns_rounded,
  HopKind.bridge => Icons.visibility_off_outlined,
  HopKind.entry => Icons.login_rounded,
  HopKind.relay => Icons.swap_horiz_rounded,
  HopKind.exit => Icons.logout_rounded,
};

String hopLabel(AppLocalizations l, HopKind kind) => switch (kind) {
  HopKind.you => l.hopYou,
  HopKind.server => l.hopServer,
  HopKind.bridge => l.torHopBridge,
  HopKind.entry => l.torHopEntry,
  HopKind.relay => l.torHopRelay,
  HopKind.exit => l.torHopExit,
};

String _note(AppLocalizations l, HopKind kind) => switch (kind) {
  HopKind.you => l.hopYouNote,
  HopKind.server => l.hopServerNote,
  HopKind.bridge => l.hopBridgeNote,
  HopKind.entry => l.hopEntryNote,
  HopKind.relay => l.hopRelayNote,
  HopKind.exit => l.hopExitNote,
};

/// The pluggable transport of a Tor profile's bridges ("Snowflake", "Obfs4", "Meek"), null when it has none.
String? _transport(ProfileInfo p) {
  final tor = p.raw['tor'];
  if (tor is! Map) return null;
  String name(String w) {
    final base = w == 'meek_lite' ? 'meek' : w;
    return base.isEmpty ? base : base[0].toUpperCase() + base.substring(1);
  }

  final builtin = tor['builtin'];
  if (builtin is String && builtin.isNotEmpty) return name(builtin);
  final bridges = tor['bridges'];
  if (bridges is List && bridges.isNotEmpty) {
    final first = '${bridges.first}'.trim().split(RegExp(r'\s+')).first;
    // A bridge line starts with its transport, unless it is a plain (vanilla) bridge: an address.
    if (RegExp(r'^[A-Za-z_]+$').hasMatch(first)) return name(first);
  }
  return null;
}

/// What is known about one stop of the route, in a sheet: where it is, what it does with the traffic, and the
/// facts that are known (the server's protocol, address and speed; a bridge's transport; the exit address).
Future<void> showHopInfo(BuildContext context, WidgetRef ref, HopKind kind, {String? country}) {
  final l = context.l10n;
  final state = ref.read(connectionProvider);
  final profile = ref.read(profilesProvider).where((p) => p.id == state.activeProfileId).firstOrNull;
  final exit = ref.read(exitProvider);
  final home = ref.read(homeProvider);

  // Where it is.
  var code = country;
  if (kind == HopKind.you) code = home?.country;
  if (kind == HopKind.server) code = exit?.country ?? (profile == null ? null : ref.read(profileCountryProvider)(profile));
  final hidden = code == null && kind == HopKind.bridge;
  final place = code == null ? (hidden ? l.torHopHidden : l.torHopUnknown) : context.countryName(code);

  // The facts.
  final rows = <(String, String, bool)>[];
  if (code != null) rows.add((l.countryRow, place, false));
  switch (kind) {
    case HopKind.you:
      if (home != null) rows.add((l.hopAddress, maskIp(home.ip), true));
    case HopKind.server:
      if (profile != null) {
        rows.add((l.hopProtocol, profile.protocol.toUpperCase(), true));
        rows.add((l.hopAddress, profile.address, true));
        final ms = profile.latencyMs;
        rows.add((l.hopLatency, ms == null ? l.latencyNotTested : (ms < 0 ? l.latencyUnreachable : l.latencyMs(ms)), false));
      }
      if (exit != null) rows.add((l.hopExitAddress, maskIp(exit.ip), true));
    case HopKind.bridge:
      final t = profile == null ? null : _transport(profile);
      if (t != null) rows.add((l.hopTransport, t, false));
    case HopKind.exit:
      if (exit != null) rows.add((l.hopExitAddress, maskIp(exit.ip), true));
    case HopKind.entry || HopKind.relay:
      break;
  }

  final title = kind == HopKind.server && profile != null ? profile.name : place;
  final note = hidden ? '${_note(l, kind)}\n\n${l.hopHiddenNote}' : _note(l, kind);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: softAnimation,
    builder: (context) => _HopSheet(kind: kind, code: code, title: title, note: note, rows: rows),
  );
}

class _HopSheet extends StatelessWidget {
  const _HopSheet({required this.kind, required this.code, required this.title, required this.note, required this.rows});

  final HopKind kind;
  final String? code;
  final String title;
  final String note;
  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CountryFlag(code, size: 52, icon: hopIcon(kind), label: title),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 12, 4),
                        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(hopIcon(kind), size: 16, color: scheme.onPrimaryContainer),
                            const SizedBox(width: 6),
                            Text(
                              hopLabel(context.l10n, kind),
                              style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(note, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: scheme.outlineVariant),
              for (final (label, value, ltr) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          textDirection: ltr ? TextDirection.ltr : null,
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
