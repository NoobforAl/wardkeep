import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n.dart';
import '../../state/window_bounds.dart';
import '../theme.dart';

/// True once `main` has hidden the system's title bar (Windows, macOS, Linux): the app then draws its
/// own, in its own colours, so the window's buttons look like the rest of the app. Tests leave it false.
bool customTitleBar = false;

/// How a system draws the window's buttons, so the app's own bar looks at home on each.
enum WindowControls {
  /// Minimize, maximize / restore and close in a row on the right, the close one turning red.
  windows,

  /// Traffic lights on the left: close (red), minimize (yellow), full screen (green); their symbols
  /// appear when the pointer is over them, and they go grey when the window is not the active one.
  mac,

  /// Round buttons on the right, as GNOME and KDE draw them.
  linux,
}

/// The buttons of the system the app runs on.
WindowControls windowControlsFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS => WindowControls.mac,
  TargetPlatform.linux => WindowControls.linux,
  _ => WindowControls.windows,
};

/// The app's own title bar for a computer: a strip above the page with a place to drag the window
/// by (double click maximizes it) and the window's buttons, drawn the way the system draws them.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.child, this.controls});

  final Widget child;

  /// Which system's buttons to draw; the running system's when null.
  final WindowControls? controls;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  bool _focused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    }));
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullScreen = false);

  @override
  void onWindowFocus() => setState(() => _focused = true);

  @override
  void onWindowBlur() => setState(() => _focused = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _toggleFullScreen() async {
    final now = !await windowManager.isFullScreen();
    await windowManager.setFullScreen(now);
    if (mounted) setState(() => _fullScreen = now);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final controls = widget.controls ?? windowControlsFor(defaultTargetPlatform);
    final mac = controls == WindowControls.mac;

    final title = Text(
      l.appName,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    final dragArea = Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _toggleMaximize,
        child: DragToMoveArea(
          // macOS centres the title between the lights and the (empty) right side; the others start it at the edge.
          child: mac
              ? Center(child: title)
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(padding: const EdgeInsetsDirectional.only(start: 14), child: title),
                ),
        ),
      ),
    );

    final maximizeTip = _maximized ? l.windowRestore : l.windowMaximize;
    final row = switch (controls) {
      WindowControls.windows => [
        dragArea,
        _CaptionButton(icon: Icons.remove_rounded, tooltip: l.windowMinimize, onPressed: windowManager.minimize),
        _CaptionButton(
          icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          size: _maximized ? 14 : 16,
          tooltip: maximizeTip,
          onPressed: _toggleMaximize,
        ),
        _CaptionButton(icon: Icons.close_rounded, tooltip: l.windowClose, onPressed: windowManager.close, danger: true),
      ],
      WindowControls.mac => [
        _TrafficLights(
          active: _focused,
          fullScreen: _fullScreen,
          closeTip: l.windowClose,
          minimizeTip: l.windowMinimize,
          fullScreenTip: _fullScreen ? l.windowExitFullScreen : l.windowFullScreen,
          onClose: windowManager.close,
          onMinimize: windowManager.minimize,
          onFullScreen: _toggleFullScreen,
        ),
        dragArea,
        // As wide as the lights, so the title is in the middle of the window.
        const SizedBox(width: _TrafficLights.width),
      ],
      WindowControls.linux => [
        dragArea,
        _RoundButton(icon: Icons.remove_rounded, tooltip: l.windowMinimize, onPressed: windowManager.minimize),
        _RoundButton(
          icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          size: _maximized ? 13 : 15,
          tooltip: maximizeTip,
          onPressed: _toggleMaximize,
        ),
        _RoundButton(icon: Icons.close_rounded, tooltip: l.windowClose, onPressed: windowManager.close, danger: true),
        const SizedBox(width: 8),
      ],
    };

    final bar = Column(
      children: [
        Material(
          color: scheme.surface,
          child: SizedBox(height: _barHeight, child: Row(children: row)),
        ),
        Expanded(child: widget.child),
      ],
    );
    // The frame sits above the app's Navigator, so it has no Overlay of its own for the buttons'
    // tooltips: it brings one.
    // Without the system's frame the window has no edge to take hold of, so the edges and corners get
    // thin grips of their own (not while maximized or full screen, when there is nothing to resize; and
    // not on macOS, whose window keeps its own edges when the title bar is hidden).
    if (_maximized || _fullScreen || mac) return Overlay.wrap(child: bar);
    return Overlay.wrap(
      child: Stack(
        children: [
          Positioned.fill(child: bar),
          for (final g in _grips) _Grip(g),
        ],
      ),
    );
  }
}

const _barHeight = 36.0;

/// How thick the grips on the edges are, and how big on the corners.
const _edge = 5.0, _corner = 12.0;

class _GripSpec {
  const _GripSpec(this.sides, this.cursor, {this.left, this.top, this.right, this.bottom, this.width, this.height});

  /// The sides of the window this grip moves.
  final ResizeSides sides;
  final MouseCursor cursor;
  final double? left, top, right, bottom, width, height;
}

// The corners come last, so they sit above the edges where the two meet.
const _grips = <_GripSpec>[
  _GripSpec(ResizeSides(left: true), SystemMouseCursors.resizeLeftRight, left: 0, top: _corner, bottom: _corner, width: _edge),
  _GripSpec(ResizeSides(right: true), SystemMouseCursors.resizeLeftRight, right: 0, top: _corner, bottom: _corner, width: _edge),
  _GripSpec(ResizeSides(top: true), SystemMouseCursors.resizeUpDown, top: 0, left: _corner, right: _corner, height: _edge),
  _GripSpec(ResizeSides(bottom: true), SystemMouseCursors.resizeUpDown, bottom: 0, left: _corner, right: _corner, height: _edge),
  _GripSpec(ResizeSides(top: true, left: true), SystemMouseCursors.resizeUpLeftDownRight, left: 0, top: 0, width: _corner, height: _corner),
  _GripSpec(ResizeSides(top: true, right: true), SystemMouseCursors.resizeUpRightDownLeft, right: 0, top: 0, width: _corner, height: _corner),
  _GripSpec(ResizeSides(bottom: true, left: true), SystemMouseCursors.resizeUpRightDownLeft, left: 0, bottom: 0, width: _corner, height: _corner),
  _GripSpec(ResizeSides(bottom: true, right: true), SystemMouseCursors.resizeUpLeftDownRight, right: 0, bottom: 0, width: _corner, height: _corner),
];

/// One grip. The window is resized from here instead of by the system's own sizing loop: while the
/// pointer is down the window's bounds are set from where the pointer is on the screen (not in the
/// window, which moves under it when the left or top edge is dragged).
class _Grip extends StatefulWidget {
  const _Grip(this.spec);

  final _GripSpec spec;

  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  Rect? _start;
  Offset? _from;
  bool _busy = false;

  Future<void> _begin() async {
    _start = null;
    final bounds = await windowManager.getBounds();
    _from = await screenRetriever.getCursorScreenPoint();
    _start = bounds;
  }

  Future<void> _move() async {
    final start = _start, from = _from;
    if (start == null || from == null || _busy) return;
    _busy = true;
    try {
      final now = await screenRetriever.getCursorScreenPoint();
      if (_start == null) return;
      await windowManager.setBounds(resizedBounds(start, widget.spec.sides, now - from));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Positioned(
      left: spec.left,
      top: spec.top,
      right: spec.right,
      bottom: spec.bottom,
      width: spec.width,
      height: spec.height,
      child: MouseRegion(
        cursor: spec.cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _begin(),
          onPanUpdate: (_) => _move(),
          onPanEnd: (_) => _start = null,
          onPanCancel: () => _start = null,
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 16,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  /// The close button: it turns red under the pointer.
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = !_hover
        ? Colors.transparent
        : widget.danger
            ? disconnectRed
            : scheme.surfaceContainerHigh;
    final foreground = _hover && widget.danger ? Colors.white : scheme.onSurfaceVariant;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: widget.tooltip,
            excludeSemantics: true,
            child: Container(
              width: 46,
              height: _barHeight,
              alignment: Alignment.center,
              color: background,
              child: Icon(widget.icon, size: widget.size, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// macOS's three lights. Their symbols show while the pointer is anywhere over the three, not over one.
class _TrafficLights extends StatefulWidget {
  const _TrafficLights({
    required this.active,
    required this.fullScreen,
    required this.closeTip,
    required this.minimizeTip,
    required this.fullScreenTip,
    required this.onClose,
    required this.onMinimize,
    required this.onFullScreen,
  });

  /// The width the three lights take, with their margin.
  static const width = 78.0;

  final bool active, fullScreen;
  final String closeTip, minimizeTip, fullScreenTip;
  final VoidCallback onClose, onMinimize, onFullScreen;

  @override
  State<_TrafficLights> createState() => _TrafficLightsState();
}

class _TrafficLightsState extends State<_TrafficLights> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A window that is not the active one has no colours, only grey, until the pointer comes.
    final idle = scheme.brightness == Brightness.dark ? const Color(0xFF4D4D4F) : const Color(0xFFCFCFD1);
    Widget light(Color color, IconData icon, String tip, VoidCallback onTap, {double glyph = 9}) {
      final lit = widget.active || _hover;
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Semantics(
            button: true,
            label: tip,
            excludeSemantics: true,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lit ? color : idle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.18), width: 0.5),
              ),
              child: _hover ? Icon(icon, size: glyph, color: Colors.black.withValues(alpha: 0.6)) : null,
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        width: _TrafficLights.width,
        height: _barHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 13),
          child: Row(
            spacing: 8,
            children: [
              light(const Color(0xFFFF5F57), Icons.close_rounded, widget.closeTip, widget.onClose),
              light(const Color(0xFFFEBC2E), Icons.remove_rounded, widget.minimizeTip, widget.onMinimize),
              light(
                const Color(0xFF28C840),
                widget.fullScreen ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                widget.fullScreenTip,
                widget.onFullScreen,
                glyph: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round window button (Linux): a soft disc that darkens under the pointer; the close one turns red.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 15,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final bool danger;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _hover
        ? (widget.danger ? disconnectRed : scheme.outlineVariant)
        : scheme.surfaceContainerHigh.withValues(alpha: 0.7);
    final foreground = _hover && widget.danger ? Colors.white : scheme.onSurfaceVariant;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: widget.tooltip,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, color: background),
                child: Icon(widget.icon, size: widget.size, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
