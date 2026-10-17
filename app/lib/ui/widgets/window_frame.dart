import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n.dart';
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
    return Column(
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
  }
}

const _barHeight = 36.0;

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
