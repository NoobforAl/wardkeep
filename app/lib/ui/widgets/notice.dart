import 'package:flutter/material.dart';

import '../theme.dart';

/// What a notice is about: something failed (red), or worked only in part (amber).
enum NoticeTone { error, warning }

extension NoticeColors on ThemeData {
  /// The colour of a notice's icon and edge.
  Color noticeColor(NoticeTone tone) => tone == NoticeTone.error ? colorScheme.error : connectingAmber;

  /// Its background: the colour tinted into the surface, so it reads as red (or amber) on a dark theme and on
  /// a light one, and the text on it keeps the normal text colour and its contrast.
  Color noticeBackground(NoticeTone tone) =>
      Color.alphaBlend(noticeColor(tone).withValues(alpha: colorScheme.brightness == Brightness.dark ? 0.2 : 0.14), colorScheme.surface);
}

/// A failure told on the page itself (where a snackbar would be hidden, as under a bottom sheet): an icon, the
/// message, and below it, optionally, one line for each thing that went wrong, which can be selected and copied.
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.message,
    this.details = const [],
    this.detailsTitle,
    this.tone = NoticeTone.error,
    this.messageKey,
    this.detailsKey,
  });

  final String message;
  final List<String> details;

  /// A heading above [details].
  final String? detailsTitle;
  final NoticeTone tone;
  final Key? messageKey, detailsKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.noticeColor(tone);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.noticeBackground(tone),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Icon(tone == NoticeTone.error ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: color, size: 22),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, key: messageKey, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                  if (details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        key: detailsKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (detailsTitle != null)
                            Text(detailsTitle!, style: theme.textTheme.labelLarge?.copyWith(color: color)),
                          for (final line in details)
                            SelectableText(line, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failure as a snackbar, in the same red (or amber) as [Notice]; stays a little longer than a plain one,
/// because there is something to read.
void showNoticeSnackBar(BuildContext context, String message, {NoticeTone tone = NoticeTone.error}) {
  final theme = Theme.of(context);
  final color = theme.noticeColor(tone);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      backgroundColor: theme.noticeBackground(tone),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: 0.65))),
      content: Row(
        children: [
          Icon(tone == NoticeTone.error ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface))),
        ],
      ),
    ));
}
