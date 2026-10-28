import 'dart:math' as math;
import 'dart:ui';

/// The smallest the window can be made: the phone layout's one column still fits (it is tested down to
/// 320 x 568 on a phone).
const minWindowSize = Size(360, 560);

/// Where and how big the desktop window opens, in logical pixels.
///
/// [displays] are the usable areas of the monitors (the work area, without the task bar), the
/// primary one first. [saved] is where the user left the window last time, if they did. A new window
/// is wide enough for the computer layout (side column and globe, see `wideBreakpoint`), sized from the
/// monitor: about 60 % of its width (between 980 and 1240) and 80 % of its height (between 600 and 800),
/// in the middle of the primary monitor. A saved window comes back where it was, unless that is no
/// longer on any monitor (it was on one that is unplugged) or is smaller than the minimum.
Rect openingBounds({required List<Rect> displays, Rect? saved}) {
  assert(displays.isNotEmpty);
  final primary = displays.first;
  if (saved != null && saved.width >= minWindowSize.width && saved.height >= minWindowSize.height) {
    for (final display in displays) {
      if (display.contains(saved.center)) {
        // Never bigger than the monitor it is on, and fully on it.
        final w = math.min(saved.width, display.width), h = math.min(saved.height, display.height);
        final x = saved.left.clamp(display.left, display.right - w).toDouble();
        final y = saved.top.clamp(display.top, display.bottom - h).toDouble();
        return Rect.fromLTWH(x, y, w, h);
      }
    }
  }
  final h = math.min(primary.height, (primary.height * 0.8).clamp(600.0, 800.0));
  final w = math.min(primary.width, (primary.width * 0.6).clamp(980.0, 1240.0));
  return Rect.fromLTWH(primary.left + (primary.width - w) / 2, primary.top + (primary.height - h) / 2, w, h);
}

/// What is kept in the store of a window's place: `{x, y, w, h}`.
Map<String, double> boundsToJson(Rect r) => {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height};

/// The inverse of [boundsToJson]; null for anything that is not a rectangle.
Rect? boundsFromJson(Object? j) {
  if (j is! Map) return null;
  final raw = [for (final k in const ['x', 'y', 'w', 'h']) j[k]];
  if (raw.any((e) => e is! num || !e.toDouble().isFinite)) return null;
  final values = [for (final e in raw) (e as num).toDouble()];
  return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
}

/// The window [start] after its [edge] is dragged by [delta] (logical pixels, the pointer's movement
/// since the drag began). The side opposite the one being dragged stays where it is, the window never
/// gets smaller than [minWindowSize], and a corner moves both of its sides.
Rect resizedBounds(Rect start, ResizeSides sides, Offset delta, {Size min = minWindowSize}) {
  var left = start.left, top = start.top, right = start.right, bottom = start.bottom;
  if (sides.left) left = math.min(start.left + delta.dx, start.right - min.width);
  if (sides.right) right = math.max(start.right + delta.dx, start.left + min.width);
  if (sides.top) top = math.min(start.top + delta.dy, start.bottom - min.height);
  if (sides.bottom) bottom = math.max(start.bottom + delta.dy, start.top + min.height);
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Which sides of the window a grip moves.
class ResizeSides {
  const ResizeSides({this.left = false, this.top = false, this.right = false, this.bottom = false});

  final bool left, top, right, bottom;
}
