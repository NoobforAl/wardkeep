import 'dart:async';

import 'package:flutter/material.dart';

/// The loading screen: the shield (assets/shield.png, from scripts/gen-icon.py) on the app's ground, over [child]
/// while the app starts.
///
/// Android's own loading screen already shows the same shield at the same size and place
/// (res/drawable/launch_background.xml), and the picture is decoded while the app starts ([prepare]), so Flutter's
/// first frame has it: the shield is there from the first moment and never jumps or blinks. Then a soft glow and the
/// name come up, a light runs over the shield once, the shield and name fade, and last the ground fades into the
/// app, so the shield never lies over the home screen. With no animations asked for, the app shows at once.
class SplashCover extends StatefulWidget {
  const SplashCover({super.key, required this.child});

  final Widget child;

  static const asset = AssetImage('assets/shield.png');

  /// The shield's side in logical pixels: the same 160 dp as the launch screen's.
  static const side = 160.0;

  /// How long the whole screen lasts once the shield is drawn.
  static const duration = Duration(milliseconds: 1250);

  static ImageProvider? _prepared;

  /// Starts decoding the shield, at the size it is drawn, before runApp; it completes when the picture is ready
  /// or after [limit], whichever is first (the app never waits longer than that for it).
  static Future<void> prepare({Duration limit = const Duration(milliseconds: 500)}) {
    final ratio = WidgetsBinding.instance.platformDispatcher.views.firstOrNull?.devicePixelRatio ?? 0;
    final pixels = (side * (ratio > 1 ? ratio : 3)).round();
    final image = _prepared = ResizeImage(asset, width: pixels, height: pixels);
    final ready = Completer<void>();
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      if (!ready.isCompleted) ready.complete();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener((_, _) => finish(), onError: (_, _) => finish());
    stream.addListener(listener);
    return ready.future.timeout(limit, onTimeout: () {});
  }

  @override
  State<SplashCover> createState() => _SplashCoverState();
}

class _SplashCoverState extends State<SplashCover> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: SplashCover.duration)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _done = true);
      // Shown once: the decoded picture need not stay in the image cache.
      WidgetsBinding.instance.addPostFrameCallback((_) => _image?.evict());
    });
  bool _done = false;
  bool _started = false;
  ImageProvider? _image;

  // The steps of the one animation, as parts of its run.
  late final _glow = _part(0, 0.35, Curves.easeOut);
  late final _name = _part(0.08, 0.4, Curves.easeOutCubic);
  late final _sheen = _part(0.18, 0.62, Curves.easeInOut);
  late final _fadeShield = _part(0.66, 0.8, Curves.easeIn);
  late final _fadeGround = _part(0.8, 1, Curves.easeInOut);

  CurvedAnimation _part(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _controller, curve: Interval(begin, end, curve: curve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done = true;
      return;
    }
    // Decoded at the size it is drawn, not the file's 512 px: by [SplashCover.prepare] when the app called it.
    final pixels = (SplashCover.side * MediaQuery.devicePixelRatioOf(context)).round();
    final image = _image = SplashCover._prepared ?? ResizeImage(SplashCover.asset, width: pixels, height: pixels);
    // Starts once the picture is decoded (at once when it was prepared), so the light does not run over nothing.
    unawaited(precacheImage(image, context).whenComplete(() {
      if (mounted) _controller.forward();
    }));
  }

  @override
  void dispose() {
    for (final animation in [_glow, _name, _sheen, _fadeShield, _fadeGround]) {
      animation.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ground = colors.surface;
    const side = SplashCover.side;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final shown = 1 - _fadeShield.value;
            return IgnorePointer(
              ignoring: _controller.value > 0.8, // the app can be used while the ground fades away
              child: Opacity(
                opacity: 1 - _fadeGround.value,
                child: ColoredBox(
                  color: ground,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // A soft light behind the shield.
                      Opacity(
                        opacity: _glow.value * shown,
                        child: Container(
                          width: side * 2.6,
                          height: side * 2.6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [colors.primary.withValues(alpha: 0.22), colors.primary.withValues(alpha: 0)],
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: shown,
                        child: Transform.scale(
                          scale: 1 + 0.06 * _fadeShield.value,
                          child: ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) {
                              final sheen = -0.25 + 1.5 * _sheen.value;
                              double at(double v) => v.clamp(0.0, 1.0);
                              return LinearGradient(
                                begin: const Alignment(-1, -0.7),
                                end: const Alignment(1, 0.7),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.5),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: [at(sheen - 0.12), at(sheen), at(sheen + 0.12)],
                              ).createShader(bounds);
                            },
                            child: Image(
                              image: _image ?? SplashCover.asset,
                              width: side,
                              height: side,
                              semanticLabel: 'Wardkeep',
                            ),
                          ),
                        ),
                      ),
                      // The name, under the shield (the shield stays in the middle, where the launch screen has it).
                      Transform.translate(
                        offset: Offset(0, side / 2 + 36 + 10 * (1 - _name.value)),
                        child: Opacity(
                          opacity: _name.value * shown,
                          child: Text(
                            'Wardkeep',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
