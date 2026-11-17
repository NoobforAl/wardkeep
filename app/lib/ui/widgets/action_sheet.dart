import 'package:flutter/material.dart';

import '../motion.dart';

/// One entry of a bottom sheet of actions (a server's, a group's, a subscription's).
class ActionItem {
  const ActionItem(this.value, this.icon, this.label, {this.danger = false, this.enabled = true});

  final String value, label;
  final IconData icon;
  final bool danger, enabled;
}

/// A bottom sheet of actions under a [header] (what the actions are about); the chosen [ActionItem.value], or null.
/// Reached by the three dots and by holding a row, so both show the same thing.
Future<String?> showActionSheet(BuildContext context, {required Widget header, required List<ActionItem> actions}) {
  return showModalBottomSheet<String>(
    context: context,
    sheetAnimationStyle: softAnimation,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final a in actions)
                    ListTile(
                      enabled: a.enabled,
                      leading: Icon(a.icon, color: a.danger ? scheme.error : null),
                      title: Text(a.label, style: a.danger ? TextStyle(color: scheme.error) : null),
                      onTap: () => Navigator.pop(context, a.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
