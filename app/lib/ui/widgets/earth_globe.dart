import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
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
    this.via = const [],
    this.homeAlpha = 0,
    this.exitAlpha = 0,
    required this.homeColor,
    required this.exitColor,
  });

  /// The point in the middle of the globe, degrees.
  final double lat, lon;
  final (double, double)? home, exit;

  /// Places the route passes between [home] and [exit] (the middle relays of a Tor circuit), in order.
  final List<(double, double)> via;

  /// Where the route goes, in order: you, the places in between, the exit (whichever of them are known).
  List<(double, double)> get route => [?home, ...via, ?exit];

  /// How visible each marker is (0-1).
  final double homeAlpha, exitAlpha;
  final Color homeColor, exitColor;

  bool sameAs(_Scene o) =>
      lat == o.lat &&
      lon == o.lon &&
      home == o.home &&
      exit == o.exit &&
      listEquals(via, o.via) &&
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
    via: via,
    homeAlpha: homeAlpha,
    exitAlpha: exitAlpha,
    homeColor: homeColor,
    exitColor: exitColor,
  );

  _Scene withVia(List<(double, double)> via) => _Scene(
    lat: lat,
    lon: lon,
    home: home,
    exit: exit,
    via: via,
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
    via: via,
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
    via: b.exit == null ? a.via : b.via,
    homeAlpha: a.homeAlpha + (b.homeAlpha - a.homeAlpha) * t,
    exitAlpha: a.exitAlpha + (b.exitAlpha - a.exitAlpha) * t,
    homeColor: Color.lerp(a.homeColor, b.homeColor, t)!,
    exitColor: Color.lerp(a.exitColor, b.exitColor, t)!,
  );
}

/// Which dot of the route was touched: where you are, a place in between (its number in [EarthBackdrop.via]),
/// or the exit.
enum GlobeSpot { home, via, exit }

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
    this.via = const [],
    this.onSpotTap,
    required this.homeColor,
    required this.exitColor,
    this.connecting = false,
    this.connected = false,
    this.upBps = 0,
    this.downBps = 0,
  });

  /// (latitude, longitude) of where you are, and of the exit; null when not known / not connecting.
  final (double, double)? home, exit;

  /// The places the route passes between you and the exit, in order (a Tor circuit's bridge or guard and
  /// middle relay); each is marked and the arc runs through them.
  final List<(double, double)> via;

  /// Called when a dot on the route is tapped (not when the Earth is dragged): which one, and for
  /// [GlobeSpot.via] its number in [via].
  final void Function(GlobeSpot spot, int index)? onSpotTap;
  final Color homeColor, exitColor;

  /// While connecting, a packet runs from you to the exit and rings spread from the marker; while
  /// connected, the exit breathes and dots stream along the arc. How it looks follows the traffic
  /// ([upBps], [downBps], bytes a second) in four steps, see [_looks]: slow and blue under 10 KB/s, green
  /// up to 1 MB/s, amber up to 10 MB/s, and a red surge above that. Otherwise nothing moves.
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
  // the system does not ask for less motion), at 8 to 20 frames a second, fewer the slower the data
  // moves. Only the overlay on top of the globe is redrawn by it; the dotted Earth underneath is kept.
  final _clock = ValueNotifier<double>(0);

  // A timer, not a Ticker: a running Ticker asks for a new frame at every screen refresh (60 a second) even
  // if the clock does not move, and on a mid-range phone every frame draws the whole screen again (measured:
  // 59 frames a second and a whole processor core). The timer asks for a frame only when the clock moves.
  Timer? _flowTimer;
  final _flowWatch = Stopwatch();
  Duration _flowPeriod = Duration.zero;

  // How fast the data moves, one step each way (with a little hysteresis, so a speed hovering at a limit
  // does not flicker between two looks); the louder way decides the colour, the line and the frame rate.
  _Speed _upStep = _Speed.slow, _downStep = _Speed.slow;
  _Speed get _step => _upStep.index >= _downStep.index ? _upStep : _downStep;

  // The colour of the animation: it glides to the colour of the step instead of jumping.
  Color _tint = _looks.first.color;
  final _arc = _ArcCache();

  Color get _tintTarget => widget.connecting ? widget.exitColor : _looks[_step.index].color;

  /// Every frame costs the same, so the rate is what counts: a slow line moves slowly and needs few frames,
  /// a surge needs more. 66 ms (15 a second) while connecting.
  Duration get _wantedPeriod => widget.connecting ? const Duration(milliseconds: 66) : _looks[_step.index].period;

  void _onFlow(Timer _) {
    _tint = Color.lerp(_tint, _tintTarget, 0.25)!;
    _clock.value = _flowWatch.elapsedMicroseconds / 1e6;
  }

  bool get _animating => widget.connecting || widget.connected;

  void _syncFlow() {
    final run = _animating && !MediaQuery.disableAnimationsOf(context);
    if (run) {
      _upStep = _stepFor(widget.upBps, _upStep);
      _downStep = _stepFor(widget.downBps, _downStep);
      final period = _wantedPeriod;
      if (_flowTimer == null || period != _flowPeriod) {
        if (_flowTimer == null) _tint = _tintTarget;
        _flowTimer?.cancel();
        _flowPeriod = period;
        if (!_flowWatch.isRunning) _flowWatch.start();
        _flowTimer = Timer.periodic(period, _onFlow);
      }
    } else if (_flowTimer != null) {
      _flowTimer!.cancel();
      _flowTimer = null;
      _upStep = _downStep = _Speed.slow;
      _flowWatch
        ..stop()
        ..reset();
    }
  }

  /// The speed step of the animation, 0 (slow) to 3 (fast) (for tests).
  @visibleForTesting
  int get speedStep => _step.index;

  /// Whether the connection animation is running (for tests).
  @visibleForTesting
  bool get flowRunning => _flowTimer?.isActive ?? false;

  /// The animation's clock (for tests).
  @visibleForTesting
  ValueNotifier<double> get clockForTest => _clock;

  /// How often the animation draws a frame (for tests); zero when it does not run.
  @visibleForTesting
  Duration get flowPeriod => flowRunning ? _flowPeriod : Duration.zero;
  double _radius = 150;
  double _moved = 0; // how far the finger has gone since it touched, in pixels
  Offset _tapAt = Offset.zero; // where the finger touched
  Size _size = Size.zero; // the size of the Earth's box

  /// How much the user has zoomed in or out (1 = as it comes), by pinching or with the wheel. Not much
  /// further in than the Earth's own box: a bigger globe only covers the page around it.
  double _userZoom = 1, _zoomStart = 1;
  static const _minZoom = 0.6, _maxZoom = 1.5;

  /// The user's zoom (for tests).
  @visibleForTesting
  double get userZoom => _userZoom;

  /// Whether the Earth is turned or zoomed away from the place it is showing.
  bool get _away => _turnLat.abs() > 0.5 || _turnLon.abs() > 0.5 || (_userZoom - 1).abs() > 0.02;
  DateTime? _lastTap;

  _Scene _flying() => _Scene.lerp(_from, _to, Curves.easeInOutCubic.transform(_fly.value));

  /// What is on screen: the flight plus the user's turn, short of the poles.
  _Scene _shown() {
    final flight = _flying();
    return flight.shift((flight.lat + _turnLat).clamp(-_maxLat, _maxLat) - flight.lat, _turnLon);
  }

  /// Where the middle of the globe is now: (latitude, longitude).
  @visibleForTesting
  (double, double) get shownCentre {
    final shown = _shown();
    return (shown.lat, shown.lon);
  }

  /// How far the user has turned it: (latitude, longitude).
  @visibleForTesting
  (double, double) get turn => (_turnLat, _turnLon);

  void _turnBy(double dLat, double dLon) {
    final flight = _flying();
    _turnLat = (flight.lat + _turnLat + dLat).clamp(-_maxLat, _maxLat) - flight.lat;
    _turnLon += dLon;
  }

  void _onCoast(Duration now) {
    final dt = ((now - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;
    setState(() {
      if (_recentring) {
        final decay = math.exp(-dt * 9);
        _turnLat *= decay;
        _turnLon *= decay;
        _userZoom = 1 + (_userZoom - 1) * decay;
        if (_turnLat.abs() < 0.05 && _turnLon.abs() < 0.05 && (_userZoom - 1).abs() < 0.002) {
          _turnLat = _turnLon = 0;
          _userZoom = 1;
          _coast.stop();
        }
        return;
      }
      _turnBy(_speedLat * dt, _speedLon * dt);
      final decay = math.exp(-dt * 3.5);
      _speedLat *= decay;
      _speedLon *= decay;
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

  void _scaleStart(ScaleStartDetails details) {
    _tapAt = details.localFocalPoint;
    _coast.stop();
    _recentring = false;
    _speedLat = _speedLon = 0;
    _moved = 0;
    _zoomStart = _userZoom;
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      // Two fingers: pinch to zoom (and no longer a tap).
      _moved += 100 * (details.scale - 1).abs();
      setState(() => _userZoom = (_zoomStart * details.scale).clamp(_minZoom, _maxZoom));
      return;
    }
    // One finger: one pixel across the middle of the globe is 1/r radians.
    final perPixel = 180 / math.pi / (_radius * _userZoom);
    _moved += details.focalPointDelta.distance;
    setState(() => _turnBy(details.focalPointDelta.dy * perPixel, -details.focalPointDelta.dx * perPixel));
  }

  void _scaleEnd(ScaleEndDetails details) {
    final perPixel = 180 / math.pi / (_radius * _userZoom);
    final velocity = details.velocity.pixelsPerSecond;
    if (details.pointerCount == 0 && (_userZoom - _zoomStart).abs() < 0.01 && velocity.distance > 80) {
      _speedLat = (velocity.dy * perPixel).clamp(-240.0, 240.0);
      _speedLon = (-velocity.dx * perPixel).clamp(-240.0, 240.0);
      _startCoast();
      return;
    }
    if (details.pointerCount > 0) return; // one finger of a pinch was lifted, the other still holds
    // A touch that hardly moved is a tap (a drag that stops before the finger lifts is not):
    // two taps in a row bring the Earth back.
    if (_moved > kTouchSlop) {
      _lastTap = null;
      return;
    }
    final hit = _spotAt(_tapAt);
    if (hit != null) {
      _lastTap = null;
      widget.onSpotTap?.call(hit.$1, hit.$2);
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

  /// The dot of the route nearest to [at] (within a finger's width), if any is on the visible side.
  (GlobeSpot, int)? _spotAt(Offset at) {
    if (widget.onSpotTap == null || _size.isEmpty) return null;
    final scene = _shown();
    final pr = _Projection(scene, _size, _zoom());
    (GlobeSpot, int)? best;
    var bestDistance = 34.0;
    void test(GlobeSpot spot, int i, (double, double)? place, double alpha) {
      if (place == null || alpha < 0.3) return;
      final u = _Projection.unit(place.$1, place.$2);
      final (p, z) = pr.project(u[0], u[1], u[2]);
      final dist = (p - at).distance;
      if (z > 0.05 && dist < bestDistance) {
        bestDistance = dist;
        best = (spot, i);
      }
    }

    test(GlobeSpot.home, 0, scene.home, scene.homeAlpha);
    for (var i = 0; i < scene.via.length; i++) {
      test(GlobeSpot.via, i, scene.via[i], scene.exitAlpha);
    }
    test(GlobeSpot.exit, 0, scene.exit, scene.exitAlpha);
    return best;
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
      via: widget.via,
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
    } else if (!listEquals(oldWidget.via, widget.via)) {
      // Only the way there changed (a new Tor circuit to the same exit): no flight, the arc just bends.
      _from = _from.withVia(widget.via);
      _to = _to.withVia(widget.via);
    } else if (oldWidget.homeColor != widget.homeColor || oldWidget.exitColor != widget.exitColor) {
      // Only a colour changed (the exit turns from "connecting" to "connected"): no new flight.
      _from = _from.withColors(widget.homeColor, widget.exitColor);
      _to = _to.withColors(widget.homeColor, widget.exitColor);
    }
  }

  @override
  void dispose() {
    _flowTimer?.cancel();
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
        _size = box.biggest;
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
          // Zoomed in, the Earth stays inside the circle it has at the normal zoom, so it neither draws over the
          // page around it nor shows the square edge of its box: the view moves closer, the outline stays round.
          child: ClipOval(
          clipper: const _GlobeOutline(),
          clipBehavior: _userZoom > 1 ? Clip.antiAlias : Clip.none,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The Earth itself: redrawn only when the view changes (a flight, a turn).
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _fly,
                  builder: (context, _) => _GlobeLayer(
                    // While the connection animation runs over the Earth, the still Earth is kept as one
                    // picture instead of being drawn dot by dot on every frame.
                    settle: _animating,
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
                        tint: _tint,
                        up: _upStep,
                        down: _downStep,
                        arc: _arc,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

/// The dotted Earth. While [settle] is set (the connection animation runs over it) and the view has stood
/// still for a moment, the Earth is drawn once into an image and that image is what is painted from then
/// on: drawing nine thousand dots and a halo on every frame, as the animation asks for frames, used more
/// than a whole processor core on a mid-range phone. A flight, a turn or a new size draws it live again.
class _GlobeLayer extends StatefulWidget {
  const _GlobeLayer({required this.painter, required this.settle});

  final _GlobePainter painter;
  final bool settle;

  @override
  State<_GlobeLayer> createState() => _GlobeLayerState();
}

class _GlobeLayerState extends State<_GlobeLayer> {
  ui.Image? _image;
  _GlobePainter? _of; // the view the image shows
  Size _imageSize = Size.zero, _size = Size.zero;
  double _imageRatio = 1, _ratio = 1;
  Timer? _timer;

  /// The glow of the rim and of the markers reaches out of the box: the picture keeps it.
  static const _margin = 64.0;

  bool get _fresh => _image != null && _of!.sameView(widget.painter) && _imageSize == _size && _imageRatio == _ratio;

  void _check() {
    _timer?.cancel();
    if (!widget.settle || _fresh || _size.isEmpty) return;
    // Only once the view has not changed for a moment (a flight or a drag changes it every frame).
    _timer = Timer(const Duration(milliseconds: 220), _render);
  }

  void _render() {
    if (!mounted || _size.isEmpty || _fresh) return;
    final ratio = _ratio, size = _size, painter = widget.painter;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio)
      ..translate(_margin, _margin);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(((size.width + 2 * _margin) * ratio).ceil(), ((size.height + 2 * _margin) * ratio).ceil());
    picture.dispose();
    setState(() {
      _image?.dispose();
      _image = image;
      _of = painter;
      _imageSize = size;
      _imageRatio = ratio;
    });
  }

  @override
  void didUpdateWidget(_GlobeLayer old) {
    super.didUpdateWidget(old);
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        // Not in the build itself: the check starts a timer and may need the size just taken.
        if (!_fresh && widget.settle) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _check() : null);
        final image = _image;
        if (image != null && _fresh) return CustomPaint(size: Size.infinite, painter: _ImagePainter(image, _ratio));
        return CustomPaint(size: Size.infinite, painter: widget.painter);
      },
    );
  }
}

/// The Earth's outline at the normal zoom: the largest circle centred in the box (see [_Projection]).
class _GlobeOutline extends CustomClipper<Rect> {
  const _GlobeOutline();

  @override
  Rect getClip(Size size) => Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2);

  @override
  bool shouldReclip(_GlobeOutline oldClipper) => false;
}

/// Paints a picture of the Earth made at the screen's own pixel size (one pixel of it is one pixel of the screen).
class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image, this.ratio);

  final ui.Image image;
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(1 / ratio);
    canvas.drawImage(image, Offset(-_GlobeLayerState._margin * ratio, -_GlobeLayerState._margin * ratio), Paint()..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image || old.ratio != ratio;
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

/// The points of a route (you, the places in between, the exit) as unit vectors with their lift above the
/// surface: [steps] samples per leg, a leg's end shared with the next leg's start. Legs too short to bend are
/// left out; null when nothing is left to draw.
List<(List<double>, double)>? _routeSamples(List<(double, double)> route, int steps) {
  if (route.length < 2) return null;
  final out = <(List<double>, double)>[];
  for (var i = 0; i + 1 < route.length; i++) {
    final h = _Projection.unit(route[i].$1, route[i].$2), e = _Projection.unit(route[i + 1].$1, route[i + 1].$2);
    final omega = math.acos((h[0] * e[0] + h[1] * e[1] + h[2] * e[2]).clamp(-1.0, 1.0));
    if (omega < 0.02) continue;
    for (var k = out.isEmpty ? 0 : 1; k <= steps; k++) {
      out.add(_arcAt(h, e, omega, k / steps));
    }
  }
  return out.length < 2 ? null : out;
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
    final radius = size.shortestSide / 2 * zoom;
    final center = size.center(Offset.zero);

    // The sea: a dark sphere, lit from above on the left.
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = ui.Gradient.radial(center + Offset(-radius * 0.35, -radius * 0.4), radius * 1.5, [ocean, oceanDeep]),
    );

    final projection = _Projection(scene, size, zoom);
    final project = projection.project;
    const unit = _Projection.unit;

    final land3 = _Land.instance;
    final count = land3.count;
    // Dots in three brightness steps: the rim of the globe is dimmer.
    final near = Float32List(count * 2), mid = Float32List(count * 2), far = Float32List(count * 2);
    var nn = 0, nm = 0, nf = 0;
    final xyz = land3.xyz;
    for (var i = 0; i < count; i++) {
      final (p, z) = project(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2]);
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
    final dot = (radius / 150).clamp(1.6, 3.4);
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
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rim.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      radius + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = rim.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final home = scene.home, exit = scene.exit;
    final scale = (radius / 360).clamp(0.6, 1.2);

    // The path between where you are and where you exit, through the places in between: a dotted arc
    // rising above the surface.
    if (home != null && exit != null) {
      final routeAlpha = math.min(scene.homeAlpha, scene.exitAlpha);
      final samples = routeAlpha > 0.01 ? _routeSamples(scene.route, 56) : null;
      if (samples != null) {
        final paint = Paint()..color = scene.exitColor.withValues(alpha: 0.8 * routeAlpha);
        for (var i = 0; i < samples.length; i += 2) {
          final (v, lift) = samples[i];
          final (p, z) = project(v[0], v[1], v[2], lift);
          if (z > 0) canvas.drawCircle(p, 1.7 * scale, paint);
        }
      }
    }

    void mark((double, double)? at, double alpha, Color color, double size) {
      if (at == null || alpha < 0.01) return;
      final u = unit(at.$1, at.$2);
      final (p, z) = project(u[0], u[1], u[2]);
      if (z <= 0.05) return;
      final glow = 46 * scale * size;
      canvas.drawCircle(
        p,
        glow,
        Paint()..shader = ui.Gradient.radial(p, glow, [color.withValues(alpha: 0.7 * alpha), color.withValues(alpha: 0)]),
      );
      canvas.drawCircle(
        p,
        13 * scale * size,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.9 * alpha),
      );
      canvas.drawCircle(
        p,
        4.2 * scale * size,
        Paint()..color = Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: alpha),
      );
    }

    // Where you are (smaller once you are somewhere else), then where you exit.
    mark(home, scene.homeAlpha, scene.homeColor, exit == null ? 1 : 0.7);
    // The relays in between, smaller: stops on the way.
    for (final at in scene.via) {
      mark(at, scene.exitAlpha, scene.exitColor, 0.55);
    }
    mark(exit, scene.exitAlpha, scene.exitColor, 1);
  }

  /// Whether [other] draws exactly the same picture.
  bool sameView(_GlobePainter? other) =>
      other != null &&
      scene.sameAs(other.scene) &&
      zoom == other.zoom &&
      ocean == other.ocean &&
      oceanDeep == other.oceanDeep &&
      land == other.land &&
      rim == other.rim;

  @override
  bool shouldRepaint(_GlobePainter old) => !sameView(old);
}

/// How fast the data moves, in four steps. Each has its own look (see [_looks]).
enum _Speed { slow, light, busy, fast }

/// The look of one speed step of the connection animation.
class _Look {
  const _Look({
    required this.from,
    required this.color,
    required this.period,
    required this.dots,
    required this.speed,
    required this.tail,
    required this.gap,
    required this.size,
    required this.alpha,
    required this.lineWidth,
    required this.lineAlpha,
    required this.ringPeriod,
    required this.ringStrength,
    this.surge = false,
  });

  /// Where the step begins, in bytes a second.
  final double from;
  final Color color;

  /// Time between two frames: the slower the data, the slower the motion, the fewer frames it needs.
  final Duration period;

  /// Dots on the line each way, how far one travels in a second (1 = the whole line), the length of its
  /// tail (pieces, and the gap between them as a share of the line), its size and its opacity.
  final int dots, tail;
  final double speed, gap, size, alpha;

  /// The line itself and the rings at the exit (seconds between two, and how strong).
  final double lineWidth, lineAlpha, ringPeriod, ringStrength;

  /// The top step is a different animation, not only a faster one: the line pulses with a halo round it, the
  /// streaks are long, and rings spread from both ends.
  final bool surge;
}

const _looks = [
  // under 10 KB/s: a calm blue line, one slow dot each way
  _Look(
    from: 0,
    color: Color(0xFF5CC8E8),
    period: Duration(milliseconds: 125),
    dots: 1,
    speed: 0.07,
    tail: 3,
    gap: 0.012,
    size: 2.6,
    alpha: 0.55,
    lineWidth: 1.6,
    lineAlpha: 0.22,
    ringPeriod: 4.5,
    ringStrength: 0.30,
  ),
  // 10 KB/s to 1 MB/s: green, a few dots at a steady pace
  _Look(
    from: 10000,
    color: Color(0xFF4ADE80),
    period: Duration(milliseconds: 90),
    dots: 3,
    speed: 0.16,
    tail: 4,
    gap: 0.013,
    size: 3.0,
    alpha: 0.75,
    lineWidth: 2.0,
    lineAlpha: 0.35,
    ringPeriod: 3.4,
    ringStrength: 0.35,
  ),
  // 1 to 10 MB/s: amber, more dots with longer tails, quicker
  _Look(
    from: 1000000,
    color: Color(0xFFFFB02E),
    period: Duration(milliseconds: 66),
    dots: 5,
    speed: 0.32,
    tail: 5,
    gap: 0.016,
    size: 3.4,
    alpha: 0.9,
    lineWidth: 2.6,
    lineAlpha: 0.5,
    ringPeriod: 2.2,
    ringStrength: 0.45,
  ),
  // 10 MB/s and above: red, a surge
  _Look(
    from: 10000000,
    color: Color(0xFFFF3B30),
    period: Duration(milliseconds: 50),
    dots: 7,
    speed: 0.85,
    tail: 7,
    gap: 0.022,
    size: 4.0,
    alpha: 1,
    lineWidth: 3.6,
    lineAlpha: 0.7,
    ringPeriod: 0.9,
    ringStrength: 0.6,
    surge: true,
  ),
];

/// The step for [bps] bytes a second, coming from step [now]. It goes up at the limit and comes back down only
/// once the speed is a good deal below it, so a speed hovering at a limit does not flicker.
_Speed _stepFor(int bps, _Speed now) {
  var step = now.index;
  while (step < _looks.length - 1 && bps >= _looks[step + 1].from) {
    step++;
  }
  while (step > 0 && bps < _looks[step].from * 0.6) {
    step--;
  }
  return _Speed.values[step];
}

/// The arc between where you are and where you exit, as screen points (null where it is behind the Earth) and
/// as one path. It only changes when the view does, so it is worked out once and not on every frame.
class _Arc {
  _Arc(this.points, this.path);

  static const steps = 48;

  final List<Offset?> points;
  final Path path;

  static _Arc? build(_Scene scene, Size size, double zoom) {
    if (scene.home == null || scene.exit == null) return null;
    final samples = _routeSamples(scene.route, steps);
    if (samples == null) return null;
    final pr = _Projection(scene, size, zoom);
    final points = <Offset?>[];
    final path = Path();
    var pen = false;
    for (final (v, k) in samples) {
      final (p, z) = pr.project(v[0], v[1], v[2], k);
      if (z <= 0) {
        points.add(null);
        pen = false;
      } else {
        points.add(p);
        if (pen) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          pen = true;
        }
      }
    }
    return _Arc(points, path);
  }

  /// The point at [u] along the arc (0 at you, 1 at the exit); null where it is behind the Earth.
  Offset? at(double u) {
    final n = points.length - 1;
    final x = u.clamp(0.0, 1.0) * n;
    final i = math.min(x.floor(), n - 1);
    final a = points[i], b = points[i + 1];
    if (a == null || b == null) return null;
    return Offset.lerp(a, b, x - i);
  }
}

/// Keeps the [_Arc] of the view it was made for.
class _ArcCache {
  _Scene? _scene;
  double _zoom = 0;
  Size _size = Size.zero;
  _Arc? _arc;

  _Arc? of(_Scene scene, Size size, double zoom) {
    final cached = _scene;
    if (cached != null && cached.sameAs(scene) && _zoom == zoom && _size == size) return _arc;
    _scene = scene;
    _zoom = zoom;
    _size = size;
    return _arc = _Arc.build(scene, size, zoom);
  }
}

/// The connection animation drawn over the Earth (see [EarthBackdrop]): a packet and rings while
/// connecting; while connected a breathing exit, a line along the arc and dots streaming each way, in the look
/// of the speed step ([_looks]): from one slow blue dot to a red, pulsing surge. Cheap on purpose (a few dozen
/// dots, no blur, one reused paint, the arc worked out once): it redraws 8 to 20 times a second while it runs.
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.scene,
    required this.zoom,
    required this.seconds,
    required this.connecting,
    required this.tint,
    required this.up,
    required this.down,
    required this.arc,
  });

  final _Scene scene;
  final double zoom, seconds;
  final bool connecting;
  final Color tint;
  final _Speed up, down;
  final _ArcCache arc;

  static double _fract(double x) => x - x.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final pr = _Projection(scene, size, zoom);
    final scale = (pr.r / 360).clamp(0.6, 1.2);
    final home = scene.home, exit = scene.exit;
    final look = _looks[math.max(up.index, down.index)];
    final paint = Paint();

    // Rings spreading from a marker, [period] seconds apart ([phase] shifts them).
    void rings((double, double)? at, double period, double strength, [double phase = 0]) {
      if (at == null) return;
      final u = _Projection.unit(at.$1, at.$2);
      final (p, z) = pr.project(u[0], u[1], u[2]);
      if (z <= 0.05) return;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (var i = 0; i < 2; i++) {
        final ph = _fract(seconds / period + phase + i / 2);
        paint.color = tint.withValues(alpha: strength * math.pow(1 - ph, 1.6).toDouble());
        canvas.drawCircle(p, (8 + 46 * ph) * scale, paint);
      }
    }

    if (connecting) {
      // Someone is knocking: rings at the place being reached (or where you are, for Tor).
      rings(exit ?? home, 1.6, 0.7);
    } else {
      // Connected: the exit breathes, as fast as the traffic is; in a surge it is answered from your end.
      rings(exit, look.ringPeriod, look.ringStrength);
      if (look.surge) rings(home, look.ringPeriod, look.ringStrength * 0.7, 0.5);
    }

    final line = arc.of(scene, size, zoom);
    if (line == null) return;
    final lineAlpha = math.min(scene.homeAlpha, scene.exitAlpha);
    if (lineAlpha < 0.01) return;

    // The line itself, while connected: a thin glow along the path the data takes; in a surge it is thick,
    // pulses, and has a halo.
    if (!connecting) {
      final pulse = look.surge ? 0.75 + 0.25 * math.sin(seconds * 2 * math.pi * 2.2) : 1.0;
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (look.surge) {
        paint
          ..strokeWidth = look.lineWidth * 3.2 * scale
          ..color = tint.withValues(alpha: 0.16 * lineAlpha * pulse);
        canvas.drawPath(line.path, paint);
      }
      paint
        ..strokeWidth = look.lineWidth * scale
        ..color = tint.withValues(alpha: look.lineAlpha * lineAlpha * pulse);
      canvas.drawPath(line.path, paint);
    }

    // A dot with a tail of [tail] pieces [gap] apart, travelling along the arc towards [dir] (+1 from you to
    // the exit, -1 back).
    void comet(double u, int dir, Color color, int tail, double gap, double alpha, double size) {
      paint.style = PaintingStyle.fill;
      for (var k = 0; k < tail; k++) {
        final p = line.at(u - dir * k * gap);
        if (p == null) continue;
        final fade = 1 - k / tail;
        paint.color = color.withValues(alpha: alpha * lineAlpha * fade);
        canvas.drawCircle(p, size * scale * (0.55 + 0.45 * fade), paint);
      }
    }

    if (connecting) {
      // One packet after another from you to the exit.
      comet(_fract(seconds / 1.3), 1, tint, 5, 0.014, 0.95, 3.6);
      comet(_fract(seconds / 1.3 + 0.5), 1, tint, 5, 0.014, 0.55, 2.8);
      return;
    }

    // Traffic: dots each way, as many and as quick as that way's own step; down (from the exit to you) in a
    // light tone of the animation's colour, up (from you) in a paler one.
    void stream(_Speed step, int dir, Color color, double phase) {
      final stepLook = _looks[step.index];
      for (var i = 0; i < stepLook.dots; i++) {
        final u = _fract(seconds * stepLook.speed + phase + i / stepLook.dots);
        comet(dir > 0 ? u : 1 - u, dir, color, stepLook.tail, stepLook.gap, stepLook.alpha, stepLook.size);
      }
    }

    stream(down, -1, Color.lerp(tint, Colors.white, 0.35)!, 0);
    stream(up, 1, Color.lerp(tint, Colors.white, 0.6)!, 0.37);
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
