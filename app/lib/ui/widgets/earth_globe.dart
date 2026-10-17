import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import '../../state/geo_data.dart';

/// The land of the Earth as unit vectors, one per land cell of the grid
/// (x east, y north, z towards the viewer when the cell is at 0°N 0°E).
class _Land {
  _Land._(this.xyz);

  final Float32List xyz;

  int get count => xyz.length ~/ 3;

  static final _Land instance = _Land._(_decode());

  static Float32List _decode() {
    final bytes = base64Decode(landGridBase64);
    final out = <double>[];
    for (var row = 0; row < landGridHeight; row++) {
      final lat = (90 - (row + 0.5) * landGridStepDegrees) * math.pi / 180;
      for (var col = 0; col < landGridWidth; col++) {
        final i = row * landGridWidth + col;
        if ((bytes[i >> 3] >> (7 - (i & 7))) & 1 == 0) continue;
        final lon = ((col + 0.5) * landGridStepDegrees - 180) * math.pi / 180;
        out
          ..add(math.cos(lat) * math.sin(lon))
          ..add(math.sin(lat))
          ..add(math.cos(lat) * math.cos(lon));
      }
    }
    return Float32List.fromList(out);
  }
}

/// What the globe shows at one moment: where it looks, and the two places it may mark —
/// where you are (red while unprotected) and where you exit (once connecting or connected).
@immutable
class _Scene {
  const _Scene({
    required this.lat,
    required this.lon,
    this.home,
    this.exit,
    this.homeAlpha = 0,
    this.exitAlpha = 0,
    required this.homeColor,
    required this.exitColor,
  });

  /// The point in the middle of the globe, degrees.
  final double lat, lon;
  final (double, double)? home, exit;

  /// How visible each marker is (0-1).
  final double homeAlpha, exitAlpha;
  final Color homeColor, exitColor;

  bool sameAs(_Scene o) =>
      lat == o.lat &&
      lon == o.lon &&
      home == o.home &&
      exit == o.exit &&
      homeAlpha == o.homeAlpha &&
      exitAlpha == o.exitAlpha &&
      homeColor == o.homeColor &&
      exitColor == o.exitColor;

  /// The same scene, looking [dLat] degrees further north and [dLon] further east.
  _Scene shift(double dLat, double dLon) => _Scene(
    lat: lat + dLat,
    lon: lon + dLon,
    home: home,
    exit: exit,
    homeAlpha: homeAlpha,
    exitAlpha: exitAlpha,
    homeColor: homeColor,
    exitColor: exitColor,
  );

  _Scene withColors(Color homeColor, Color exitColor) => _Scene(
    lat: lat,
    lon: lon,
    home: home,
    exit: exit,
    homeAlpha: homeAlpha,
    exitAlpha: exitAlpha,
    homeColor: homeColor,
    exitColor: exitColor,
  );

  /// In between [a] and [b]. A marker sits where [b] has it (or where [a] had it while it fades out).
  static _Scene lerp(_Scene a, _Scene b, double t) => _Scene(
    lat: a.lat + (b.lat - a.lat) * t,
    lon: a.lon + (b.lon - a.lon) * t,
    home: b.home ?? a.home,
    exit: b.exit ?? a.exit,
    homeAlpha: a.homeAlpha + (b.homeAlpha - a.homeAlpha) * t,
    exitAlpha: a.exitAlpha + (b.exitAlpha - a.exitAlpha) * t,
    homeColor: Color.lerp(a.homeColor, b.homeColor, t)!,
    exitColor: Color.lerp(a.exitColor, b.exitColor, t)!,
  );
}

/// A dotted Earth behind the home screen, in the manner of Mullvad's: it shows where you
/// are while unprotected, and on connecting it flies (zooming out on the way) to where you
/// exit, with an arc between the two; on disconnecting it flies back. It only moves during
/// the flight (about two seconds), so it costs next to nothing the rest of the time.
///
/// The user can turn it with a finger or a mouse: drag in any direction (it keeps coasting a
/// moment, and the latitude stops short of the poles so it cannot flip over) and double tap
/// to bring it back to the place it is showing. The turn is added on top of the flight and is
/// folded into it when a place changes, so nothing jumps.
class EarthBackdrop extends StatefulWidget {
  const EarthBackdrop({
    super.key,
    this.home,
    this.exit,
    required this.homeColor,
    required this.exitColor,
    this.connecting = false,
    this.connected = false,
    this.upBps = 0,
    this.downBps = 0,
  });

  /// (latitude, longitude) of where you are, and of the exit; null when not known / not connecting.
  final (double, double)? home, exit;
  final Color homeColor, exitColor;

  /// While connecting, a packet runs from you to the exit and rings spread from the marker; while
  /// connected, the exit breathes and dots stream along the arc, each way as fast and as many as the
  /// traffic ([upBps], [downBps], bytes a second) is. Otherwise nothing moves.
  final bool connecting, connected;
  final int upBps, downBps;

  @override
  State<EarthBackdrop> createState() => EarthBackdropState();
}

/// An eager scale (one finger turns, two pinch): it wins the gesture arena at once, so a drag that
/// starts on the Earth turns it even where the page around it could scroll.
class _EagerScale extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class EarthBackdropState extends State<EarthBackdrop> with TickerProviderStateMixin {
  /// The globe at rest, when no place is known: Europe, Africa and the Middle East.
  static const _restLat = 18.0, _restLon = 20.0;

  /// The marked place is shown this many degrees above the middle, clear of the power ring.
  static const _lift = 14.0;

  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  late _Scene _from;
  late _Scene _to;

  /// How far north the globe may be turned, either way.
  static const _maxLat = 75.0;

  // The user's turn, in degrees, added to the flight; and its coasting speed (degrees a second).
  double _turnLat = 0, _turnLon = 0, _speedLat = 0, _speedLon = 0;
  bool _recentring = false;
  Duration _lastTick = Duration.zero;
  late final Ticker _coast = createTicker(_onCoast);

  // The connection animation: a clock in seconds that only runs while connecting or connected (and
  // the system does not ask for less motion), at about 30 frames a second. Only the overlay on top
  // of the globe is redrawn by it; the dotted Earth underneath is kept as it is.
  final _clock = ValueNotifier<double>(0);
  late final Ticker _flow = createTicker(_onFlow);
  Duration _lastFlow = Duration.zero;

  void _onFlow(Duration elapsed) {
    if (elapsed - _lastFlow < const Duration(milliseconds: 30)) return;
    _lastFlow = elapsed;
    _clock.value = elapsed.inMicroseconds / 1e6;
  }

  bool get _animating => widget.connecting || widget.connected;

  void _syncFlow() {
    final run = _animating && !MediaQuery.disableAnimationsOf(context);
    if (run && !_flow.isActive) {
      _lastFlow = Duration.zero;
      _flow.start();
    } else if (!run && _flow.isActive) {
      _flow.stop();
    }
  }

  /// Whether the connection animation is running (for tests).
  @visibleForTesting
  bool get flowRunning => _flow.isActive;
  double _radius = 150;
  double _moved = 0; // how far the finger has gone since it touched, in pixels

  /// How much the user has zoomed in or out (1 = as it comes), by pinching or with the wheel.
  double _userZoom = 1, _zoomStart = 1;
  static const _minZoom = 0.6, _maxZoom = 2.2;

  /// The user's zoom (for tests).
  @visibleForTesting
  double get userZoom => _userZoom;

  /// Whether the Earth is turned or zoomed away from the place it is showing.
  bool get _away => _turnLat.abs() > 0.5 || _turnLon.abs() > 0.5 || (_userZoom - 1).abs() > 0.02;
  DateTime? _lastTap;

  _Scene _flying() => _Scene.lerp(_from, _to, Curves.easeInOutCubic.transform(_fly.value));

  /// What is on screen: the flight plus the user's turn, short of the poles.
  _Scene _shown() {
    final f = _flying();
    return f.shift((f.lat + _turnLat).clamp(-_maxLat, _maxLat) - f.lat, _turnLon);
  }

  /// Where the middle of the globe is now: (latitude, longitude).
  @visibleForTesting
  (double, double) get shownCentre {
    final s = _shown();
    return (s.lat, s.lon);
  }

  /// How far the user has turned it: (latitude, longitude).
  @visibleForTesting
  (double, double) get turn => (_turnLat, _turnLon);

  void _turnBy(double dLat, double dLon) {
    final f = _flying();
    _turnLat = (f.lat + _turnLat + dLat).clamp(-_maxLat, _maxLat) - f.lat;
    _turnLon += dLon;
  }

  void _onCoast(Duration now) {
    final dt = ((now - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;
    setState(() {
      if (_recentring) {
        final k = math.exp(-dt * 9);
        _turnLat *= k;
        _turnLon *= k;
        _userZoom = 1 + (_userZoom - 1) * k;
        if (_turnLat.abs() < 0.05 && _turnLon.abs() < 0.05 && (_userZoom - 1).abs() < 0.002) {
          _turnLat = _turnLon = 0;
          _userZoom = 1;
          _coast.stop();
        }
        return;
      }
      _turnBy(_speedLat * dt, _speedLon * dt);
      final k = math.exp(-dt * 3.5);
      _speedLat *= k;
      _speedLon *= k;
      if (_speedLat.abs() < 1.5 && _speedLon.abs() < 1.5) {
        _speedLat = _speedLon = 0;
        _coast.stop();
      }
    });
  }

  void _startCoast() {
    if (_coast.isActive) return;
    _lastTick = Duration.zero;
    _coast.start();
  }

  void _scaleStart(ScaleStartDetails d) {
    _coast.stop();
    _recentring = false;
    _speedLat = _speedLon = 0;
    _moved = 0;
    _zoomStart = _userZoom;
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      // Two fingers: pinch to zoom (and no longer a tap).
      _moved += 100 * (d.scale - 1).abs();
      setState(() => _userZoom = (_zoomStart * d.scale).clamp(_minZoom, _maxZoom));
      return;
    }
    // One finger: one pixel across the middle of the globe is 1/r radians.
    final perPixel = 180 / math.pi / (_radius * _userZoom);
    _moved += d.focalPointDelta.distance;
    setState(() => _turnBy(d.focalPointDelta.dy * perPixel, -d.focalPointDelta.dx * perPixel));
  }

  void _scaleEnd(ScaleEndDetails d) {
    final perPixel = 180 / math.pi / (_radius * _userZoom);
    final v = d.velocity.pixelsPerSecond;
    if (d.pointerCount == 0 && (_userZoom - _zoomStart).abs() < 0.01 && v.distance > 80) {
      _speedLat = (v.dy * perPixel).clamp(-240.0, 240.0);
      _speedLon = (-v.dx * perPixel).clamp(-240.0, 240.0);
      _startCoast();
      return;
    }
    if (d.pointerCount > 0) return; // one finger of a pinch was lifted, the other still holds
    // A touch that hardly moved is a tap (a drag that stops before the finger lifts is not):
    // two taps in a row bring the Earth back.
    if (_moved > kTouchSlop) {
      _lastTap = null;
      return;
    }
    final now = DateTime.now(), last = _lastTap;
    if (last != null && now.difference(last) < const Duration(milliseconds: 350)) {
      _lastTap = null;
      recentre();
    } else {
      _lastTap = now;
    }
  }

  /// The mouse wheel zooms, a notch at a time.
  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      setState(() => _userZoom = (_userZoom * math.exp(-e.scrollDelta.dy / 400)).clamp(_minZoom, _maxZoom));
    });
  }

  /// Turn the Earth back to the place it is showing.
  void recentre() {
    _recentring = true;
    _speedLat = _speedLon = 0;
    if (_turnLat == 0 && _turnLon == 0 && _userZoom == 1) return;
    _startCoast();
  }

  _Scene _target(double previousLon) {
    final home = widget.home, exit = widget.exit;
    final focus = exit ?? home;
    return _Scene(
      lat: focus == null ? _restLat : (focus.$1 - _lift).clamp(-60.0, 60.0),
      // Turn the short way round.
      lon: focus == null ? previousLon : previousLon + ((focus.$2 - previousLon + 540) % 360) - 180,
      home: home,
      exit: exit,
      // Once there is an exit, where you are fades back and the exit takes over.
      homeAlpha: home == null ? 0 : (exit == null ? 1 : 0.55),
      exitAlpha: exit == null ? 0 : 1,
      homeColor: widget.homeColor,
      exitColor: widget.exitColor,
    );
  }

  @override
  void initState() {
    super.initState();
    _to = _target(_restLon);
    _from = _to;
    _fly.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFlow();
  }

  @override
  void didUpdateWidget(EarthBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlow();
    // The parent rebuilds on every speed and clock tick. The camera travels only when a
    // place changes; deciding that from the computed target would not do, because its
    // longitude is worked out from where the globe is right now and so differs on every
    // rebuild in the middle of a flight (the globe restarted its flight again and again).
    if (oldWidget.home != widget.home || oldWidget.exit != widget.exit) {
      // Start from what is on screen now (the user's turn included), so a change in
      // mid-flight does not jump; from here on the turn is part of the flight.
      final now = _shown();
      _coast.stop();
      _turnLat = _turnLon = _speedLat = _speedLon = 0;
      _from = now;
      _to = _target(now.lon);
      _fly.forward(from: 0);
    } else if (oldWidget.homeColor != widget.homeColor || oldWidget.exitColor != widget.exitColor) {
      // Only a colour changed (the exit turns from "connecting" to "connected"): no new flight.
      _from = _from.withColors(widget.homeColor, widget.exitColor);
      _to = _to.withColors(widget.homeColor, widget.exitColor);
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _clock.dispose();
    _coast.dispose();
    _fly.dispose();
    super.dispose();
  }

  double _zoom() => (1 - 0.18 * math.sin(math.pi * _fly.value)) * _userZoom;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, box) {
        _radius = math.max(40.0, box.biggest.shortestSide / 2);
        return Listener(
          onPointerSignal: _wheel,
          // The button sits beside the gesture area, not in it: the gesture area takes every touch.
          child: Stack(fit: StackFit.expand, children: [
          RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerScale: GestureRecognizerFactoryWithHandlers<_EagerScale>(
              _EagerScale.new,
              (r) => r
                ..onStart = _scaleStart
                ..onUpdate = _scaleUpdate
                ..onEnd = _scaleEnd,
            ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The Earth itself: redrawn only when the view changes (a flight, a turn).
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _fly,
                  builder: (context, _) => CustomPaint(
                    painter: _GlobePainter(
                      scene: _shown(),
                      // Pull back in the middle of a flight, then settle: the camera "travels".
                      zoom: _zoom(),
                      ocean: dark ? const Color(0xFF0B1422) : const Color(0xFFD3DCE8),
                      oceanDeep: dark ? const Color(0xFF060A12) : const Color(0xFFC3CEDD),
                      land: dark ? const Color(0xFF7FA3D6) : const Color(0xFF4B6A99),
                      rim: dark ? const Color(0xFF86A8D8) : const Color(0xFF6E8CB8),
                    ),
                  ),
                ),
              ),
              // The connection animation, on its own layer so the Earth is not redrawn for it.
              if (_animating)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_fly, _clock]),
                    builder: (context, _) => CustomPaint(
                      painter: _FlowPainter(
                        scene: _shown(),
                        zoom: _zoom(),
                        seconds: _clock.value,
                        connecting: widget.connecting,
                        upBps: widget.upBps,
                        downBps: widget.downBps,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
          // Back to the place the Earth is showing; there only once it has been turned or zoomed.
          Positioned(
            right: 2,
            bottom: 2,
            child: AnimatedOpacity(
              opacity: _away ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_away,
                child: IconButton.filledTonal(
                  tooltip: context.l10n.globeRecenter,
                  onPressed: recentre,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                ),
              ),
            ),
          ),
          ]),
        );
      },
    );
  }
}

/// Screen position of points of the globe for one view: the middle of the globe at ([scene].lat,
/// lon), radius from [size] and [zoom].
class _Projection {
  _Projection(_Scene scene, Size size, double zoom)
    : r = size.shortestSide / 2 * zoom,
      c = size.center(Offset.zero),
      _cosLon = math.cos(scene.lon * _deg),
      _sinLon = math.sin(scene.lon * _deg),
      _cosLat = math.cos(scene.lat * _deg),
      _sinLat = math.sin(scene.lat * _deg);

  static const _deg = math.pi / 180;

  final double r;
  final Offset c;
  final double _cosLon, _sinLon, _cosLat, _sinLat;

  /// Screen position and depth (z > 0 faces the viewer) of a point at [k] times the globe's radius.
  (Offset, double) project(double x, double y, double z, [double k = 1]) {
    final x1 = x * _cosLon - z * _sinLon;
    final z1 = x * _sinLon + z * _cosLon;
    final y2 = y * _cosLat - z1 * _sinLat;
    final z2 = y * _sinLat + z1 * _cosLat;
    return (Offset(c.dx + r * k * x1, c.dy - r * k * y2), z2);
  }

  static List<double> unit(double latDeg, double lonDeg) {
    final lat = latDeg * _deg, lon = lonDeg * _deg;
    return [math.cos(lat) * math.sin(lon), math.sin(lat), math.cos(lat) * math.cos(lon)];
  }
}

/// The arc between two places: a point at [u] (0 at [h], 1 at [e]) of the great circle, raised above the
/// surface in the middle; returns the unit vector and the radius factor to project it with.
(List<double>, double) _arcAt(List<double> h, List<double> e, double omega, double u) {
  final k1 = math.sin((1 - u) * omega) / math.sin(omega), k2 = math.sin(u * omega) / math.sin(omega);
  final lift = 1 + 0.16 * math.sin(math.pi * u) * (omega / math.pi).clamp(0.25, 1.0);
  return ([k1 * h[0] + k2 * e[0], k1 * h[1] + k2 * e[1], k1 * h[2] + k2 * e[2]], lift);
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.scene,
    required this.zoom,
    required this.ocean,
    required this.oceanDeep,
    required this.land,
    required this.rim,
  });

  final _Scene scene;
  final double zoom;
  final Color ocean, oceanDeep, land, rim;


  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * zoom;
    final c = size.center(Offset.zero);

    // The sea: a dark sphere, lit from above on the left.
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c + Offset(-r * 0.35, -r * 0.4), r * 1.5, [ocean, oceanDeep]),
    );

    final projection = _Projection(scene, size, zoom);
    final project = projection.project;
    const unit = _Projection.unit;

    final land3 = _Land.instance;
    final n = land3.count;
    // Dots in three brightness steps: the rim of the globe is dimmer.
    final near = Float32List(n * 2), mid = Float32List(n * 2), far = Float32List(n * 2);
    var nn = 0, nm = 0, nf = 0;
    final v = land3.xyz;
    for (var i = 0; i < n; i++) {
      final (p, z) = project(v[i * 3], v[i * 3 + 1], v[i * 3 + 2]);
      if (z <= 0.02) continue;
      if (z > 0.6) {
        near[nn++] = p.dx;
        near[nn++] = p.dy;
      } else if (z > 0.28) {
        mid[nm++] = p.dx;
        mid[nm++] = p.dy;
      } else {
        far[nf++] = p.dx;
        far[nf++] = p.dy;
      }
    }
    final dot = (r / 150).clamp(1.6, 3.4);
    void draw(Float32List pts, int len, double alpha) {
      if (len == 0) return;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(pts, 0, len),
        Paint()
          ..color = land.withValues(alpha: alpha)
          ..strokeWidth = dot
          ..strokeCap = StrokeCap.round,
      );
    }

    draw(far, nf, 0.20);
    draw(mid, nm, 0.38);
    draw(near, nn, 0.58);

    // A cold halo on the rim: the air.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rim.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = rim.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final home = scene.home, exit = scene.exit;
    final s = (r / 360).clamp(0.6, 1.2);

    // The path between where you are and where you exit: a dotted arc rising above the surface.
    if (home != null && exit != null) {
      final a = math.min(scene.homeAlpha, scene.exitAlpha);
      final h = unit(home.$1, home.$2), e = unit(exit.$1, exit.$2);
      final omega = math.acos((h[0] * e[0] + h[1] * e[1] + h[2] * e[2]).clamp(-1.0, 1.0));
      if (a > 0.01 && omega > 0.02) {
        final paint = Paint()..color = scene.exitColor.withValues(alpha: 0.8 * a);
        const steps = 56;
        for (var i = 0; i <= steps; i += 2) {
          final (v, lift) = _arcAt(h, e, omega, i / steps);
          final (p, z) = project(v[0], v[1], v[2], lift);
          if (z > 0) canvas.drawCircle(p, 1.7 * s, paint);
        }
      }
    }

    void mark((double, double)? at, double alpha, Color color, double size) {
      if (at == null || alpha < 0.01) return;
      final u = unit(at.$1, at.$2);
      final (p, z) = project(u[0], u[1], u[2]);
      if (z <= 0.05) return;
      final glow = 46 * s * size;
      canvas.drawCircle(
        p,
        glow,
        Paint()..shader = ui.Gradient.radial(p, glow, [color.withValues(alpha: 0.7 * alpha), color.withValues(alpha: 0)]),
      );
      canvas.drawCircle(
        p,
        13 * s * size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.9 * alpha),
      );
      canvas.drawCircle(
        p,
        4.2 * s * size,
        Paint()..color = Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: alpha),
      );
    }

    // Where you are (smaller once you are somewhere else), then where you exit.
    mark(home, scene.homeAlpha, scene.homeColor, exit == null ? 1 : 0.7);
    mark(exit, scene.exitAlpha, scene.exitColor, 1);
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      !scene.sameAs(old.scene) ||
      zoom != old.zoom ||
      ocean != old.ocean ||
      oceanDeep != old.oceanDeep ||
      land != old.land ||
      rim != old.rim;
}

/// How strong a flow of [bps] bytes a second looks, 0 (nothing) to 1 (a megabyte a second or more).
double _flowLevel(int bps) => bps < 50 ? 0 : ((math.log(bps) / math.ln10 - 1.7) / 4.3).clamp(0.0, 1.0);

/// The connection animation drawn over the Earth (see [EarthBackdrop]): a packet and rings while
/// connecting; a breathing exit, a faint line along the arc and dots streaming each way as fast and
/// as many as the traffic is, while connected. Cheap on purpose (a few dozen dots): it redraws
/// about 30 times a second while it runs.
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.scene,
    required this.zoom,
    required this.seconds,
    required this.connecting,
    required this.upBps,
    required this.downBps,
  });

  final _Scene scene;
  final double zoom, seconds;
  final bool connecting;
  final int upBps, downBps;

  static double _fract(double x) => x - x.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final pr = _Projection(scene, size, zoom);
    final s = (pr.r / 360).clamp(0.6, 1.2);
    final home = scene.home, exit = scene.exit;

    // Rings spreading from a marker, [period] seconds apart.
    void rings((double, double)? at, Color color, double period, double strength) {
      if (at == null) return;
      final u = _Projection.unit(at.$1, at.$2);
      final (p, z) = pr.project(u[0], u[1], u[2]);
      if (z <= 0.05) return;
      for (var i = 0; i < 2; i++) {
        final ph = _fract(seconds / period + i / 2);
        canvas.drawCircle(
          p,
          (8 + 46 * ph) * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = color.withValues(alpha: strength * math.pow(1 - ph, 1.6).toDouble()),
        );
      }
    }

    if (connecting) {
      // Someone is knocking: rings at the place being reached (or where you are, for Tor).
      if (exit != null) {
        rings(exit, scene.exitColor, 1.6, 0.7);
      } else {
        rings(home, scene.exitColor, 1.6, 0.7);
      }
    } else {
      // Connected: the exit breathes slowly.
      rings(exit, scene.exitColor, 3.6, 0.35);
    }

    if (home == null || exit == null) return;
    final a = math.min(scene.homeAlpha, scene.exitAlpha);
    final h = _Projection.unit(home.$1, home.$2), e = _Projection.unit(exit.$1, exit.$2);
    final omega = math.acos((h[0] * e[0] + h[1] * e[1] + h[2] * e[2]).clamp(-1.0, 1.0));
    if (a < 0.01 || omega < 0.02) return;

    Offset? at(double u, {double lift = 0}) {
      final (v, k) = _arcAt(h, e, omega, u.clamp(0.0, 1.0));
      final (p, z) = pr.project(v[0], v[1], v[2], k + lift);
      return z > 0 ? p : null;
    }

    // The line itself, while connected: a thin glow along the path the data takes.
    if (!connecting) {
      final path = Path();
      var pen = false;
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final p = at(i / steps);
        if (p == null) {
          pen = false;
        } else if (pen) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          pen = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * s
          ..strokeCap = StrokeCap.round
          ..color = scene.exitColor.withValues(alpha: 0.5 * a),
      );
    }

    // A dot with a short tail, travelling along the arc towards [dir] (+1 from you to the exit, -1 back).
    void comet(double u, int dir, Color color, double alpha, double size) {
      for (var k = 0; k < 5; k++) {
        final p = at(u - dir * k * 0.014);
        if (p == null) continue;
        final fade = 1 - k / 5;
        canvas.drawCircle(
          p,
          size * s * (0.55 + 0.45 * fade),
          Paint()..color = color.withValues(alpha: alpha * a * fade),
        );
      }
    }

    if (connecting) {
      // One packet after another from you to the exit.
      comet(_fract(seconds / 1.3), 1, scene.exitColor, 0.95, 3.6);
      comet(_fract(seconds / 1.3 + 0.5), 1, scene.exitColor, 0.55, 2.8);
      return;
    }

    // Traffic: dots each way, more and faster the more is moving; when nothing moves, one slow dot
    // each way, so the tunnel is seen to be alive.
    void stream(int bps, int dir, Color color, double phase) {
      final level = _flowLevel(bps);
      final n = bps < 50 ? 1 : 2 + (level * 8).round();
      final speed = bps < 50 ? 0.12 : 0.25 + 0.75 * level;
      final alpha = bps < 50 ? 0.4 : 0.7 + 0.3 * level;
      for (var i = 0; i < n; i++) {
        final u = _fract(seconds * speed + phase + i / n);
        comet(dir > 0 ? u : 1 - u, dir, color, alpha, 3.0 + 1.2 * level);
      }
    }

    // Down (from the exit to you) in the exit's colour, up (from you) in a pale blue.
    stream(downBps, -1, Color.lerp(scene.exitColor, Colors.white, 0.35)!, 0);
    stream(upBps, 1, const Color(0xFFBFD6F5), 0.37);
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
