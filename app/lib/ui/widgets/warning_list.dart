import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../../l10n/form_text.dart';
import '../../l10n/l10n.dart';
import 'notice.dart';

/// What the user should know about a protocol or a setting (easy to recognise, not encrypted, slow): a risk is
/// an amber [Notice], a plain "good to know" is one quiet line. Shows nothing when there is nothing to say.
class WarningList extends StatelessWidget {
  const WarningList(this.warnings, {super.key});

  final List<WarningSpec> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: w.risk
                ? Notice(key: Key('warning-${w.code}'), message: warningText(l, w), tone: NoticeTone.warning)
                : Row(
                    key: Key('warning-${w.code}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Expanded(
                        child: Text(
                          warningText(l, w),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
