import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';

/// The packet size of the tunnel (TUN mode): below this a packet cannot carry IPv6.
const minMtu = 576;
const maxMtu = 65535;

/// The two network options of the Connection group in Settings: IPv6 on or off, and the tunnel's MTU.
List<Widget> networkTiles(BuildContext context, WidgetRef ref, SettingsState s) {
  final l = context.l10n;
  final ctrl = ref.read(settingsProvider.notifier);
  return [
    SwitchListTile(
      secondary: const Icon(Icons.public_rounded),
      title: Text(l.ipv6Title),
      subtitle: Text(l.ipv6Hint),
      value: s.ipv6,
      onChanged: (v) => ctrl.update((s) => s.copyWith(ipv6: v)),
    ),
    ListTile(
      leading: const Icon(Icons.straighten_rounded),
      title: Text(l.mtuTitle),
      subtitle: Text(s.mtu == 0 ? l.mtuAuto : '${s.mtu}', textDirection: TextDirection.ltr),
      trailing: const Icon(Icons.edit_outlined),
      enabled: s.tunMode,
      onTap: () async {
        final value = await showDialog<int>(animationStyle: softAnimation, context: context, builder: (_) => MtuDialog(s.mtu));
        if (value != null) ctrl.update((s) => s.copyWith(mtu: value));
      },
    ),
  ];
}

/// Asks for the MTU: empty (or Reset) is the default, otherwise a number from [minMtu] to [maxMtu].
class MtuDialog extends StatefulWidget {
  const MtuDialog(this.initial, {super.key});

  final int initial;

  @override
  State<MtuDialog> createState() => _MtuDialogState();
}

class _MtuDialogState extends State<MtuDialog> {
  late final _controller = TextEditingController(text: widget.initial == 0 ? '' : '${widget.initial}');
  bool _bad = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return Navigator.pop(context, 0);
    final n = int.tryParse(text);
    if (n == null || n < minMtu || n > maxMtu) return setState(() => _bad = true);
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.mtuTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mtuHelp),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(hintText: l.mtuAuto, errorText: _bad ? l.mtuInvalid(minMtu, maxMtu) : null),
            onChanged: (_) => _bad ? setState(() => _bad = false) : null,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 0), child: Text(l.actionReset)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(onPressed: _save, child: Text(l.actionSave)),
      ],
    );
  }
}
