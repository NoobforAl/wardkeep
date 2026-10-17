import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n.dart';
import '../../state/window_bounds.dart';
import '../theme.dart';

/// True once `main` has hidden the system's title bar (Windows): the app then draws its own, in
/// its own colours, so the window's buttons look like the rest of the app. Tests leave it false.
bool customTitleBar = false;

/// The app's own title bar for a computer: a strip above the page with a place to drag the window
/// by (double click maximizes it) and the minimize, maximize / restore and close buttons.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
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

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final bar = Column(
      children: [
        Material(
          color: scheme.surface,
          child: SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _toggleMaximize,
                    child: const DragToMoveArea(child: SizedBox.expand()),
                  ),
                ),
                _CaptionButton(
                  icon: Icons.remove_rounded,
                  tooltip: l.windowMinimize,
                  onPressed: windowManager.minimize,
                ),
                _CaptionButton(
                  icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                  size: _maximized ? 14 : 16,
                  tooltip: _maximized ? l.windowRestore : l.windowMaximize,
                  onPressed: _toggleMaximize,
                ),
                _CaptionButton(
                  icon: Icons.close_rounded,
                  tooltip: l.windowClose,
                  onPressed: windowManager.close,
                  danger: true,
                ),
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
    // Without the system's frame the window has no edge to take hold of, so the edges and corners get
    // thin grips of their own (not while maximized, when there is nothing to resize).
    if (_maximized) return bar;
    return Stack(
      children: [
        Positioned.fill(child: bar),
        for (final g in _grips) _Grip(g),
      ],
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
