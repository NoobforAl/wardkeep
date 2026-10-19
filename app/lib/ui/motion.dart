import 'package:flutter/material.dart';

/// One feel for everything that changes on its own (a connection coming up, a status turning over): slow
/// enough to follow, never a cut. Nothing moves when the system asks for no animations.
const softCurve = Curves.easeInOutCubic;

/// For dialogs, sheets and expanding rows: they open a little slower than Material's quick default and
/// close a little faster.
const softAnimation = AnimationStyle(
  duration: Duration(milliseconds: 380),
  reverseDuration: Duration(milliseconds: 260),
  curve: softCurve,
  reverseCurve: Curves.easeInCubic,
);

/// [ms] milliseconds, or zero where the system has animations turned off.
Duration soft(BuildContext context, [int ms = 600]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// Content that fades and grows in when [show] turns true, and fades out and closes up when it turns
/// false, instead of popping in and pushing everything under it down in one frame.
class SoftAppear extends StatelessWidget {
  const SoftAppear({
    super.key,
    required this.show,
    required this.child,
    this.ms = 500,
  });

  final bool show;
  final Widget child;
  final int ms;

  @override
  Widget build(BuildContext context) {
    final d = soft(context, ms);
    return AnimatedSize(
      duration: d,
      curve: softCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: show
            ? KeyedSubtree(key: const ValueKey(true), child: child)
            : const SizedBox(key: ValueKey(false), width: double.infinity),
      ),
    );
  }
}

/// Text that cross-fades when [text] changes (a status, a step) instead of being swapped in a frame.
class SoftText extends StatelessWidget {
  const SoftText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.ms = 400,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int ms;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: soft(context, ms),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Text(
        text,
        key: ValueKey('$text${style?.color}'),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
