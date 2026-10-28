import 'package:flutter/material.dart';

/// The loading screen: the whole shield (assets/shield.png, from scripts/gen-icon.py) on the app's ground,
/// over [child] while the app starts. The shield grows in, a light runs over it once, then the screen
/// fades away into the app. Android's own loading screen before it is only the ground, without the small
/// round launcher icon. Nothing is shown when the system asks for no animations.
class SplashCover extends StatefulWidget {
  const SplashCover({super.key, required this.child});

  final Widget child;

  static const asset = AssetImage('assets/shield.png');

  @override
  State<SplashCover> createState() => _SplashCoverState();
}

class _SplashCoverState extends State<SplashCover> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _done = true);
      // Shown once: the decoded picture (a megabyte) need not stay in the image cache.
      WidgetsBinding.instance.addPostFrameCallback((_) => SplashCover.asset.evict());
    });
  bool _done = false;
  bool _started = false;

  // The steps of the one animation, as parts of its run.
  late final _grow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
  );
  late final _appear = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.25, curve: Curves.easeOut),
  );
  late final _sheen = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
  );
  late final _leave = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.78, 1, curve: Curves.easeIn),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done = true;
      return;
    }
    // Starts once the picture is decoded, so the shield does not pop in halfway through.
    precacheImage(SplashCover.asset, context).whenComplete(() {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    for (final animation in [_grow, _appear, _sheen, _leave]) {
      animation.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final ground = Theme.of(context).colorScheme.surface;
    final side = (MediaQuery.sizeOf(context).shortestSide * 0.56).clamp(120.0, 280.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => IgnorePointer(
            ignoring: _controller.value > 0.78, // the app can be used while the screen fades away
            child: Opacity(
              opacity: 1 - _leave.value,
              child: ColoredBox(
                color: ground,
                child: Center(
                  child: Opacity(
                    opacity: _appear.value,
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * _grow.value + 0.08 * _leave.value,
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
                              Colors.white.withValues(alpha: 0.42),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: [at(sheen - 0.14), at(sheen), at(sheen + 0.14)],
                          ).createShader(bounds);
                        },
                        child: Image(image: SplashCover.asset, width: side, height: side, semanticLabel: 'Wardkeep'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
