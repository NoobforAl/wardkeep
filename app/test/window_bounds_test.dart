import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/state/window_bounds.dart';

/// Where the desktop window opens: sized from the monitor, never off it, and where the user left it.
void main() {
  const fullHd = Rect.fromLTWH(0, 0, 1920, 1040); // 1080 p minus the task bar
  const qhd = Rect.fromLTWH(0, 0, 2560, 1392);
  const laptop = Rect.fromLTWH(0, 0, 1366, 720); // 768 p minus the task bar
  const second = Rect.fromLTWH(-1920, 0, 1536, 816); // a monitor to the left of the primary

  test('opens wide, in the middle of the primary monitor, sized from it', () {
    for (final d in [fullHd, qhd, laptop]) {
      final b = openingBounds(displays: [d]);
      expect(b.width, inInclusiveRange(980, 1240), reason: '$d');
      expect(b.height, inInclusiveRange(600, 800), reason: '$d');
      expect(d.contains(b.topLeft) && d.contains(b.bottomRight), isTrue, reason: 'on the monitor: $b on $d');
      expect((b.center - d.center).distance, lessThan(1), reason: 'centred: $b on $d');
    }
    // A bigger monitor gives a bigger window, up to a limit; a small one a smaller window.
    expect(openingBounds(displays: [qhd]).height, greaterThan(openingBounds(displays: [laptop]).height));
    expect(openingBounds(displays: [qhd]).height, 800);
    expect(openingBounds(displays: [laptop]).height, 600);
  });

  test('a tiny monitor still gets a window that fits on it', () {
    const tiny = Rect.fromLTWH(0, 0, 400, 500);
    final b = openingBounds(displays: [tiny]);
    expect(b.width, lessThanOrEqualTo(400));
    expect(b.height, lessThanOrEqualTo(500));
  });

  test('comes back where the user left it', () {
    const saved = Rect.fromLTWH(300, 120, 700, 900);
    expect(openingBounds(displays: [qhd], saved: saved), saved);
  });

  test('a saved window on the second monitor stays there, if that monitor is still plugged in', () {
    const saved = Rect.fromLTWH(-1700, 40, 500, 700);
    expect(openingBounds(displays: [qhd, second], saved: saved), saved);
    // Unplugged: it opens on the primary monitor instead of off the screen.
    final b = openingBounds(displays: [qhd], saved: saved);
    expect(qhd.contains(b.center), isTrue);
    expect(b, isNot(saved));
  });

  test('a saved window that is too big or hangs off the monitor is pulled back onto it', () {
    final big = openingBounds(displays: [laptop], saved: const Rect.fromLTWH(10, 10, 3000, 3000));
    expect(big.width, lessThanOrEqualTo(laptop.width));
    expect(big.height, lessThanOrEqualTo(laptop.height));
    final hanging = openingBounds(displays: [fullHd], saved: const Rect.fromLTWH(1500, 700, 600, 600));
    expect(hanging.right, lessThanOrEqualTo(fullHd.right));
    expect(hanging.bottom, lessThanOrEqualTo(fullHd.bottom));
    expect(hanging.size, const Size(600, 600));
  });

  test('a saved window below the minimum size is ignored', () {
    final b = openingBounds(displays: [fullHd], saved: const Rect.fromLTWH(100, 100, 200, 300));
    expect(b.width, greaterThanOrEqualTo(minWindowSize.width));
    expect(b.height, greaterThanOrEqualTo(minWindowSize.height));
  });

  test('the store round trip keeps a rectangle and refuses anything else', () {
    const r = Rect.fromLTWH(12.5, -30, 640, 810);
    expect(boundsFromJson(boundsToJson(r)), r);
    expect(boundsFromJson(null), isNull);
    expect(boundsFromJson('x'), isNull);
    expect(boundsFromJson({'x': 1, 'y': 2, 'w': 3}), isNull);
    expect(boundsFromJson({'x': 1, 'y': 2, 'w': 'a', 'h': 4}), isNull);
    expect(boundsFromJson({'x': double.nan, 'y': 2, 'w': 3, 'h': 4}), isNull);
  });

  group('resizing from a grip', () {
    const start = Rect.fromLTRB(100, 100, 600, 900);

    test('each side moves only itself, the opposite side stays', () {
      expect(resizedBounds(start, const ResizeSides(right: true), const Offset(50, 999)), const Rect.fromLTRB(100, 100, 650, 900));
      expect(resizedBounds(start, const ResizeSides(left: true), const Offset(-30, 999)), const Rect.fromLTRB(70, 100, 600, 900));
      expect(resizedBounds(start, const ResizeSides(bottom: true), const Offset(999, 40)), const Rect.fromLTRB(100, 100, 600, 940));
      expect(resizedBounds(start, const ResizeSides(top: true), const Offset(999, -20)), const Rect.fromLTRB(100, 80, 600, 900));
    });

    test('a corner moves both of its sides', () {
      expect(resizedBounds(start, const ResizeSides(bottom: true, right: true), const Offset(10, 20)), const Rect.fromLTRB(100, 100, 610, 920));
      expect(resizedBounds(start, const ResizeSides(top: true, left: true), const Offset(10, 20)), const Rect.fromLTRB(110, 120, 600, 900));
    });

    test('never smaller than the minimum, and the dragged side stops while the other stays put', () {
      final tiny = resizedBounds(start, const ResizeSides(left: true, top: true), const Offset(5000, 5000));
      expect(tiny.size, minWindowSize);
      expect(tiny.bottomRight, start.bottomRight);
      final tiny2 = resizedBounds(start, const ResizeSides(right: true, bottom: true), const Offset(-5000, -5000));
      expect(tiny2.size, minWindowSize);
      expect(tiny2.topLeft, start.topLeft);
    });

    test('no movement changes nothing', () {
      expect(resizedBounds(start, const ResizeSides(left: true, top: true, right: true, bottom: true), Offset.zero), start);
    });
  });
}
