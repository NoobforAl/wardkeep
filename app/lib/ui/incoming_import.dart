import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/errors.dart';
import '../l10n/l10n.dart';
import '../state/groups.dart';
import '../state/providers.dart';
import 'import_file.dart';
import 'screens/subscription_screen.dart';
import 'widgets/notice.dart';
import 'layout.dart';

/// Tells the user why a file another app sent could not be read ([code] is the Android side's reason), in a
/// red notification.
Future<void> importSharedProblem(GlobalKey<NavigatorState> navigator, String code) async {
  final context = navigator.currentContext;
  if (context == null) return;
  final l = context.l10n;
  final why = switch (code) {
    'empty' => l.importFileEmpty,
    'too_large' => l.importTooLarge(importMaxBytes >> 20),
    'not_text' => l.importFileNotText,
    'denied' => l.importFileNoPermission,
    'missing' => l.importFileMissing,
    _ => l.couldNotReadFile(code),
  };
  showNoticeSnackBar(context, l.importNothing(why));
}

/// Imports what another app sent: a subscription link opens the subscription form, anything else
/// (share links, config files, bridge lines) goes through the importer and is saved at once. A failure is a
/// red notification that says why; a partial import is an amber one.
Future<void> importShared(GlobalKey<NavigatorState> navigator, WidgetRef ref, String text) async {
  final context = navigator.currentContext;
  if (context == null) return;
  final l = context.l10n;
  text = text.trim();
  if (text.isEmpty) return;

  // A single http(s) or nordvpn:// URL is a subscription, not a config.
  if (!text.contains('\n') && RegExp(r'^(https?|nordvpn)://\S+$').hasMatch(text)) {
    navigator.currentState?.push(AppRoute<void>(builder: (_) => SubscriptionScreen(initialUrl: text)));
    return;
  }

  try {
    final result = await ref.read(engineProvider).importText(text);
    final added = ref.read(profilesProvider.notifier).addAll(ref.read(groupsProvider.notifier).place(text, result.profiles));
    if (!context.mounted) return;
    // The first thing that went wrong with an entry, after the headline: "bad: no user id".
    final failure = result.failure;
    final reasons = failure == null ? result.errors : (failure.args['details'] ?? '').split('\n').where((s) => s.isNotEmpty);
    final reason = reasons.isEmpty ? '' : '\n${reasons.first}';
    if (result.profiles.isEmpty) {
      final headline = l.importNothing(
        failure != null ? describeError(l, failure) : (result.errors.isEmpty ? '–' : result.errors.first),
      );
      showNoticeSnackBar(context, failure != null ? headline + reason : headline);
    } else if (result.errors.isNotEmpty) {
      showNoticeSnackBar(context, l.importPartial(added, result.errors.length) + reason, tone: NoticeTone.warning);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.importedProfiles(added, result.profiles.length - added))),
      );
    }
  } catch (e) {
    if (context.mounted) showNoticeSnackBar(context, l.importNothing(describeError(l, e)));
  }
}
