import 'package:flutter/material.dart';

/// [base] plus the room the system's bottom bar (gesture bar or the back/home/recents
/// keys) takes when the app draws under it. A list that sets its own padding does not
/// get that room by itself, so its last row could sit behind the bar. While the keyboard
/// is open the Scaffold has already made the body shorter and this is 0.
EdgeInsets withBottomInset(BuildContext context, EdgeInsets base) =>
    base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);

/// A main action pinned under a form: it stays visible above the keyboard and above the
/// system's bottom bar, however long the form is. Use it as `Scaffold.bottomNavigationBar`.
class PinnedAction extends StatelessWidget {
  const PinnedAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
