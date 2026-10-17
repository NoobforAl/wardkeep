import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/devices.dart';
import '../insets.dart';

/// "My devices": the devices of the Tailscale / Headscale network a connected mesh profile has
/// joined, their addresses and MagicDNS names, whether they are online, and which of them
/// offers its connection to be used as the exit.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(devicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.devicesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _body(context, ref, s),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, DevicesState s) {
    final l = context.l10n;
    final status = s.status;
    if (status == null) {
      final err = s.error;
      if (err == null) return const Center(child: CircularProgressIndicator());
      final notRunning = err is EngineException && err.code == 'NOT_RUNNING';
      return _Message(notRunning ? l.devicesNotConnected : (err is EngineException ? err.message : err.toString()));
    }
    if (!status.running) {
      final login = status.authUrl.isNotEmpty || status.state == 'NeedsLogin';
      return _Message(login ? l.devicesLoginNeeded : l.devicesJoining, busy: !login);
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: withBottomInset(context, const EdgeInsets.only(bottom: 24)),
      children: [
        if (status.network.isNotEmpty || status.domain.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              [status.network, status.domain].where((t) => t.isNotEmpty).join(' · '),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (status.devices.any((d) => d.exitOption))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(l.devicesExitHint, style: Theme.of(context).textTheme.bodyMedium),
          ),
        if (s.exitError != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
            child: Text(describeError(l, s.exitError!), style: TextStyle(color: scheme.onErrorContainer)),
          ),
        if (status.self != null) _DeviceTile(device: status.self!, self: true, busyId: s.busyId),
        for (final d in status.devices) _DeviceTile(device: d, busyId: s.busyId),
        if (status.devices.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l.devicesEmpty, textAlign: TextAlign.center))),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

IconData _osIcon(String os) => switch (os.toLowerCase()) {
  'android' || 'ios' => Icons.smartphone_rounded,
  'windows' || 'linux' || 'macos' => Icons.computer_rounded,
  _ => Icons.devices_other_rounded,
};

/// One device: name, MagicDNS name and address, online state, and the exit button.
class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device, this.self = false, this.busyId});

  final MeshDevice device;
  final bool self;
  final String? busyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final d = device;
    final ctrl = ref.read(devicesProvider.notifier);
    final busy = busyId != null;
    final online = self || d.online;
    final lines = <String>[
      if (d.dnsName.isNotEmpty) d.dnsName,
      if (d.address.isNotEmpty) d.address,
    ];
    final status = self
        ? l.devicesThisDevice
        : d.exit
        ? l.deviceIsExit
        : online
        ? l.deviceOnline
        : (d.lastSeen == null
              ? l.deviceOffline
              : '${l.deviceOffline} · ${l.deviceLastSeen(MaterialLocalizations.of(context).formatShortDate(d.lastSeen!))}');

    Widget? action;
    if (!self && d.exit) {
      action = FilledButton.tonal(onPressed: busy ? null : () => ctrl.useAsExit(''), child: Text(l.deviceStopExit));
    } else if (!self && d.exitOption && online) {
      action = OutlinedButton(onPressed: busy ? null : () => ctrl.useAsExit(d.id), child: Text(l.deviceUseAsExit));
    }

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_osIcon(d.os), size: 32, color: online ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: online ? Colors.green : scheme.outline,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(d.name, overflow: TextOverflow.ellipsis),
      isThreeLine: action != null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) Text(line, textDirection: TextDirection.ltr, overflow: TextOverflow.ellipsis),
          Text(status),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 6), child: busyId == d.id ? const _Busy() : action),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: l.tooltipMore,
        onSelected: (v) async {
          final text = v == 'name' ? (d.dnsName.isEmpty ? d.name : d.dnsName) : d.address;
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.deviceCopied), duration: const Duration(seconds: 2)));
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'name', child: Text(l.deviceCopyName)),
          if (d.address.isNotEmpty) PopupMenuItem(value: 'address', child: Text(l.deviceCopyAddress)),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) =>
      const Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
}
