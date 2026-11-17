import 'package:flutter/material.dart';

/// An item of a popup menu with an icon in front of its text, so the menus of the app look alike. [danger] paints
/// a destructive entry (Delete) in the error colour.
PopupMenuItem<String> iconMenuItem(String value, IconData icon, String label, {bool danger = false, bool enabled = true}) {
  return PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    child: Builder(
      builder: (context) {
        final color = enabled && danger ? Theme.of(context).colorScheme.error : null;
        return Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Flexible(child: Text(label, style: color == null ? null : TextStyle(color: color))),
          ],
        );
      },
    ),
  );
}
