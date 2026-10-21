import 'package:flutter/material.dart';

import 'widgets/star_field.dart';

/// From this width (a computer's window, a tablet lying down) the app stops being a phone's one
/// column: the home screen puts the controls beside a large globe and the other pages open as a
/// centred panel. Narrower windows, and every phone, keep the one column.
const wideBreakpoint = 900.0;

/// True when the window is wide enough for the computer layout.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// How wide a page's panel is on a wide window.
const _panelWidth = 680.0;

/// A page of the app. On a phone it is a plain full-screen page; on a wide window the same page
/// is a panel in the middle of the window, over the sky of the home screen, instead of a phone
/// screen stretched to the window's width (rows pulled apart, the back arrow far from the content).
class AppRoute<T> extends MaterialPageRoute<T> {
  AppRoute({required super.builder, super.settings, super.fullscreenDialog});

  @override
  Widget buildContent(BuildContext context) => _PagePanel(child: super.buildContent(context));
}

/// Marks the part of a wide window that has its own Navigator beside the rail: a page opened there
/// fills that part (with the rail still in view) instead of floating over the whole window.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required super.child});

  static bool within(BuildContext context) => context.getInheritedWidgetOfExactType<ShellScope>() != null;

  @override
  bool updateShouldNotify(ShellScope old) => false;
}

/// How wide a page reads well inside the window's content area.
const _shellPageWidth = 560.0;

class _PagePanel extends StatelessWidget {
  const _PagePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return child;
    final scheme = Theme.of(context).colorScheme;
    if (ShellScope.within(context)) {
      return ColoredBox(
        color: scheme.surface,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _shellPageWidth), child: child),
        ),
      );
    }
    final dark = scheme.brightness == Brightness.dark;
    final tall = MediaQuery.sizeOf(context).height >= 640;
    return ColoredBox(
      color: Color.alphaBlend(Colors.black.withValues(alpha: dark ? 0.35 : 0.06), scheme.surface),
      child: CustomPaint(
        painter: const StarFieldPainter(),
        child: Align(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tall ? 20 : 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _panelWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tall ? 20 : 0),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(tall ? 19 : 0), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
