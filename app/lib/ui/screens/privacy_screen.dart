import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../insets.dart';

/// The privacy policy: what stays on the device and what the app contacts. PRIVACY.md at the repository's root has
/// the same text; change both together (and [updated]).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  /// When the policy last changed.
  static final updated = DateTime(2026, 11);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final date = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag()).format(updated);
    final sections = <(String, List<String>)>[
      (l.privacyDeviceTitle, [l.privacyDevice]),
      (l.privacyLogsTitle, [l.privacyLogs]),
      (l.privacyAutoTitle, [l.privacyAutoCheck, l.privacyAutoProbe, l.privacyAutoExit, l.privacyAutoDns]),
      (l.privacyAskTitle, [l.privacyAskSubs, l.privacyAskIpdb, l.privacyAskNord, l.privacyAskTor]),
      (l.privacyServersTitle, [l.privacyServers]),
      (l.privacyPermsTitle, [l.privacyPermVpn, l.privacyPermNotify, l.privacyPermCamera, l.privacyPermApps]),
      (l.privacyChangesTitle, [l.privacyChanges]),
    ];
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SelectionArea(
            child: ListView(
              key: const Key('privacy-policy'),
              padding: withBottomInset(context, const EdgeInsets.fromLTRB(24, 8, 24, 32)),
              children: [
                Text(l.privacyIntro, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
                for (final (title, paragraphs) in sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                  ),
                  if (paragraphs.length == 1)
                    Text(paragraphs.single, style: body)
                  else
                    for (final p in paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ', style: body),
                            Expanded(child: Text(p, style: body)),
                          ],
                        ),
                      ),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    l.privacyUpdated(date),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
