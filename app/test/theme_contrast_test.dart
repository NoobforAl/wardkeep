import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/ui/theme.dart';

/// WCAG 2 contrast ratio of two colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;
    final s = buildTheme(brightness).colorScheme;

    test('$name theme: text and its background reach WCAG AA (4.5:1)', () {
      final pairs = <String, (Color, Color)>{
        'onSurface on surface': (s.onSurface, s.surface),
        'onSurface on card (surfaceContainer)': (s.onSurface, s.surfaceContainer),
        'onSurface on dialog (surfaceContainerHigh)': (s.onSurface, s.surfaceContainerHigh),
        'onSurface on menu (surfaceContainerHighest)': (s.onSurface, s.surfaceContainerHighest),
        'onSurfaceVariant on surface (hints, subtitles)': (s.onSurfaceVariant, s.surface),
        'onSurfaceVariant on card': (s.onSurfaceVariant, s.surfaceContainer),
        'onSurfaceVariant on input field': (s.onSurfaceVariant, s.surfaceContainerHigh),
        'onPrimary on primary (Connect button)': (s.onPrimary, s.primary),
        'onPrimaryContainer on primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
        'onSecondaryContainer on secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
        'onError on error (Disconnect button)': (s.onError, s.error),
        'primary on surface (text buttons, links)': (s.primary, s.surface),
        'error on surface (error text)': (s.error, s.surface),
        'onSecondary on secondary': (s.onSecondary, s.secondary),
      };
      final failures = <String>[];
      pairs.forEach((what, p) {
        final ratio = _contrast(p.$1, p.$2);
        if (ratio < 4.5) failures.add('$what: ${ratio.toStringAsFixed(2)}:1');
      });
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('$name theme: the status colours read on the page (3:1 for large text and icons)', () {
      final failures = <String>[];
      for (final status in ConnStatus.values) {
        final ratio = _contrast(statusColor(status, s), s.surface);
        if (ratio < 3) failures.add('${status.name}: ${ratio.toStringAsFixed(2)}:1');
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('$name theme: outlines of inputs and switches are visible (3:1)', () {
      expect(_contrast(s.outline, s.surface), greaterThanOrEqualTo(3), reason: 'outline on surface');
    });
  }
}
