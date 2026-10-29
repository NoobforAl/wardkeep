import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/groups.dart';
import '../../state/providers.dart';
import '../../state/subscriptions.dart';
import '../../state/usage.dart';
import '../import_file.dart';
import '../widgets/notice.dart';
import '../widgets/profile_subtitle.dart';
import '../widgets/protocol_badge.dart';
import 'location_screen.dart';
import 'profile_editor_screen.dart';
import 'qr_scan_screen.dart';
import 'share_screen.dart';
import 'subscription_screen.dart';
import '../widgets/credentials_dialog.dart';
import '../layout.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final subs = ref.watch(subscriptionsProvider);
    final groups = ref.watch(groupsProvider);
    final selected = ref.watch(selectedProfileIdProvider);
    ref.watch(formsProvider); // loads the editors, so Edit appears in the menus
    final manual = profiles.where((p) => p.group == ProfileInfo.defaultGroup).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profilesTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.addSubscriptionTooltip,
            onPressed: () => Navigator.of(context).push(AppRoute<void>(builder: (_) => const SubscriptionScreen())),
            icon: const Icon(Icons.add_link),
          ),
          IconButton(
            tooltip: context.l10n.testLatencyTooltip,
            onPressed: profiles.isEmpty ? null : () => testAllLatencies(ref),
            icon: const Icon(Icons.speed),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.tooltipMore,
            onSelected: (choice) async {
              if (choice == 'new_group') {
                final name = await _askGroupName(context, context.l10n.menuNewGroup, '', context.l10n.groupCreate);
                if (name != null) ref.read(groupsProvider.notifier).create(name);
              } else if (choice == 'restore_tor') {
                await ref.read(defaultProfileIdProvider.notifier).ensureTorDefaults(force: true);
              } else if (choice == 'delete_all') {
                final l = context.l10n;
                final messenger = ScaffoldMessenger.of(context);
                final sure = await showDialog<bool>(animationStyle: softAnimation, 
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.deleteAllTitle),
                    content: Text(l.deleteAllBody),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.actionDelete)),
                    ],
                  ),
                );
                if (sure != true) return;
                final subsNotifier = ref.read(subscriptionsProvider.notifier);
                for (final sub in [...ref.read(subscriptionsProvider)]) {
                  subsNotifier.remove(sub.id);
                }
                ref.read(profilesProvider.notifier).clearAll();
                await ref.read(defaultProfileIdProvider.notifier).ensureTorDefaults(force: true);
                messenger.showSnackBar(SnackBar(content: Text(l.deletedAllToast)));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'new_group', child: Text(context.l10n.menuNewGroup)),
              PopupMenuItem(
                value: 'delete_all',
                enabled: profiles.any((p) => p.protocol != 'tor') || subs.isNotEmpty,
                child: Text(context.l10n.menuDeleteAll),
              ),
              PopupMenuItem(value: 'restore_tor', child: Text(context.l10n.menuRestoreTor)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showImportSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.actionImport),
      ),
      body: profiles.isEmpty && subs.isEmpty
          ? Center(child: Text(context.l10n.profilesEmptyHint))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      context.l10n.profilesDragHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                if (manual.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _GroupTitle(context.l10n.myProfiles)),
                  _GroupList(group: ProfileInfo.defaultGroup, profiles: manual, selectedId: selected),
                ],
                for (final g in groups) ...[
                  SliverToBoxAdapter(child: _UserGroupHeader(g, profiles.where((p) => p.group == g.id).toList())),
                  if (profiles.any((p) => p.group == g.id))
                    _GroupList(group: g.id, profiles: profiles.where((p) => p.group == g.id).toList(), selectedId: selected)
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          context.l10n.groupEmptyHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
                for (final sub in subs) ...[
                  SliverToBoxAdapter(child: _SubscriptionHeader(sub)),
                  _GroupList(
                    group: sub.id,
                    profiles: profiles.where((p) => p.group == sub.id).toList(),
                    selectedId: selected,
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// One group's profiles, reorderable within the group.
class _GroupList extends ConsumerWidget {
  const _GroupList({required this.group, required this.profiles, required this.selectedId});

  final String group;
  final List<ProfileInfo> profiles;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultId = ref.watch(defaultProfileProvider)?.id;
    return SliverReorderableList(
      itemCount: profiles.length,
      onReorderItem: (from, to) => ref.read(profilesProvider.notifier).reorderInGroup(group, from, to),
      itemBuilder: (context, i) {
        final profile = profiles[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(profile.id),
          index: i,
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              selected: profile.id == selectedId,
              leading: Icon(profile.id == selectedId ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Row(
                children: [
                  Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
                  if (profile.id == defaultId) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: context.l10n.badgeDefault,
                      child: Icon(Icons.star_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ],
              ),
              subtitle: ProfileSubtitle(profile),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LatencyText(profile.latencyMs),
                  const SizedBox(width: 8),
                  ProtocolBadge(profile.protocol),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.tooltipMore,
                    onSelected: (choice) {
                      if (choice == 'edit') {
                        Navigator.of(context).push(AppRoute<void>(builder: (_) => ProfileEditorScreen(profile: profile)));
                      }
                      if (choice == 'share') {
                        Navigator.of(context).push(AppRoute<void>(builder: (_) => ShareScreen(profile: profile)));
                      }
                      if (choice == 'delete') ref.read(profilesProvider.notifier).remove(profile.id);
                      if (choice == 'default') {
                        ref.read(defaultProfileIdProvider.notifier).set(profile.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.defaultSetToast(profile.name))));
                      }
                      if (choice == 'move') unawaited(_moveToGroup(context, ref, profile));
                      if (choice == 'credentials') unawaited(askCredentials(context, ref, profile));
                      if (choice == 'usage') ref.read(profileUsageProvider.notifier).reset(profile.id);
                    },
                    itemBuilder: (_) => [
                      if (ref.read(formsProvider).value?.any((f) => f.protocol == profile.protocol) ?? false)
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(profile.protocol == 'tor' ? context.l10n.menuBridgeSettings : context.l10n.menuEditServer),
                        ),
                      PopupMenuItem(value: 'share', child: Text(context.l10n.menuShare)),
                      PopupMenuItem(value: 'move', child: Text(context.l10n.menuMoveToGroup)),
                      if (profile.id != defaultId) PopupMenuItem(value: 'default', child: Text(context.l10n.menuSetDefault)),
                      if (profile.needsCredentials)
                        PopupMenuItem(value: 'credentials', child: Text(context.l10n.menuCredentials)),
                      if (ref.read(usageOfProvider(profile.id)) > 0)
                        PopupMenuItem(value: 'usage', child: Text(context.l10n.menuResetUsage)),
                      PopupMenuItem(value: 'delete', child: Text(context.l10n.actionDelete)),
                    ],
                  ),
                ],
              ),
              onTap: () => ref.read(selectedProfileIdProvider.notifier).select(profile.id),
            ),
          ),
        );
      },
    );
  }
}

/// Asks for a group's name; null when cancelled or left empty.
Future<String?> _askGroupName(BuildContext context, String title, String initial, String action) {
  return showDialog<String>(
    animationStyle: softAnimation,
    context: context,
    builder: (_) => _GroupNameDialog(title: title, initial: initial, action: action),
  );
}

/// The dialog owns its text controller, so it is disposed once the dialog has left the screen.
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({required this.title, required this.initial, required this.action});

  final String title, initial, action;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final name = _controller.text.trim();
    Navigator.pop(context, name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: l.groupNameHint),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(onPressed: _done, child: Text(widget.action)),
      ],
    );
  }
}

/// Moves a server to one of the user's groups, to a new one, or back to "My servers".
Future<void> _moveToGroup(BuildContext context, WidgetRef ref, ProfileInfo p) async {
  final l = context.l10n;
  const fresh = '\u0000new';
  final groups = ref.read(groupsProvider);
  final pick = await showDialog<String>(
    animationStyle: softAnimation,
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l.groupMoveTitle),
      children: [
        if (p.group != ProfileInfo.defaultGroup)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ProfileInfo.defaultGroup),
            child: Text(l.myProfiles),
          ),
        for (final g in groups)
          if (g.id != p.group)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, g.id), child: Text(g.name, overflow: TextOverflow.ellipsis)),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, fresh),
          child: Row(children: [const Icon(Icons.add, size: 18), const SizedBox(width: 8), Text(l.menuNewGroup)]),
        ),
      ],
    ),
  );
  if (pick == null || !context.mounted) return;
  var target = pick;
  if (pick == fresh) {
    final name = await _askGroupName(context, l.menuNewGroup, '', l.groupCreate);
    if (name == null) return;
    target = ref.read(groupsProvider.notifier).create(name).id;
  }
  ref.read(profilesProvider.notifier).moveTo(p.id, target);
}

/// A group of the user's: its name and what can be done with it as a whole.
class _UserGroupHeader extends ConsumerWidget {
  const _UserGroupHeader(this.group, this.members);

  final ProfileGroup group;
  final List<ProfileInfo> members;

  /// The share links of the members, and the names of those that have none (OpenVPN travels as a file).
  Future<(List<String>, List<String>)> _links(WidgetRef ref) async {
    final engine = ref.read(engineProvider);
    final links = <String>[], skipped = <String>[];
    for (final profile in members) {
      try {
        links.add(await engine.exportLink(profile));
      } catch (_) {
        skipped.add(profile.name);
      }
    }
    return (links, skipped);
  }

  Future<void> _share(BuildContext context, WidgetRef ref, {required bool toFile}) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final (links, skipped) = await _links(ref);
    if (links.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.groupNothingToShare)));
      return;
    }
    final text = groupFileText(group.name, links);
    if (toFile) {
      Uri? saved;
      try {
        saved = await FilePicker.saveFile(
          fileName: groupFileName(group.name),
          bytes: Uint8List.fromList(utf8.encode(text)),
          mimeType: 'text/plain',
          dialogTitle: l.menuShareGroupFile,
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeFileProblem(l, e))));
        return;
      }
      if (saved == null) return; // cancelled
      messenger.showSnackBar(SnackBar(content: Text(l.groupSavedToast(l.serversCount(links.length)))));
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(SnackBar(content: Text(l.groupCopiedToast(l.serversCount(links.length)))));
    }
    if (skipped.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.groupSkipped(skipped.join(', ')))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(group.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
          Text(l.serversCount(members.length), style: theme.textTheme.bodySmall),
          PopupMenuButton<String>(
            tooltip: l.tooltipMore,
            onSelected: (choice) async {
              switch (choice) {
                case 'file':
                  await _share(context, ref, toFile: true);
                case 'copy':
                  await _share(context, ref, toFile: false);
                case 'rename':
                  final name = await _askGroupName(context, l.menuRenameGroup, group.name, l.actionSave);
                  if (name != null) ref.read(groupsProvider.notifier).rename(group.id, name);
                case 'delete':
                  final sure = await showDialog<bool>(
                    animationStyle: softAnimation,
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l.groupDeleteTitle),
                      content: Text(l.groupDeleteBody(l.myProfiles)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.menuDeleteGroup)),
                      ],
                    ),
                  );
                  if (sure == true) ref.read(groupsProvider.notifier).remove(group.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'file', enabled: members.isNotEmpty, child: Text(l.menuShareGroupFile)),
              PopupMenuItem(value: 'copy', enabled: members.isNotEmpty, child: Text(l.menuCopyGroupLinks)),
              PopupMenuItem(value: 'rename', child: Text(l.menuRenameGroup)),
              PopupMenuItem(value: 'delete', child: Text(l.menuDeleteGroup)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subscription name, usage, expiry, last update and actions.
class _SubscriptionHeader extends ConsumerWidget {
  const _SubscriptionHeader(this.sub);

  final Subscription sub;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final count = await ref.read(subscriptionsProvider.notifier).refresh(sub.id);
      messenger.showSnackBar(SnackBar(content: Text(l.subRefreshed(sub.name, count))));
    } catch (_) {
      // The error is shown in the header.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(subscriptionsProvider);
    final refreshing = ref.read(subscriptionsProvider.notifier).isRefreshing(sub.id);
    final theme = Theme.of(context);
    final info = sub.info;
    final l = context.l10n;
    final details = <String>[
      if (info.total > 0) l.subUsageOf(formatBytes(info.used), formatBytes(info.total))
      else if (info.used > 0) l.subUsed(formatBytes(info.used)),
      if (info.expire != null) _expiry(l, info.expire!),
      if (info.verified) l.subSigned,
      if (sub.updatedAt != null) l.subUpdated(_ago(l, sub.updatedAt!)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(sub.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
              refreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: l.refreshTooltip,
                      onPressed: () => _refresh(context, ref),
                      icon: const Icon(Icons.refresh),
                    ),
              PopupMenuButton<String>(
                onSelected: (choice) {
                  if (choice == 'edit') {
                    Navigator.of(context).push(AppRoute<void>(builder: (_) => SubscriptionScreen(existing: sub)));
                  } else if (choice == 'delete') {
                    ref.read(subscriptionsProvider.notifier).remove(sub.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l.subDeleteWithProfiles)),
                ],
              ),
            ],
          ),
          if (info.total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2, bottom: 4),
              child: LinearProgressIndicator(
                value: (info.used / info.total).clamp(0, 1).toDouble(),
                color: info.used >= info.total ? theme.colorScheme.error : null,
              ),
            ),
          if (details.isNotEmpty) Text(details.join(' · '), style: theme.textTheme.bodySmall),
          if (sub.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Text(l.subRefreshFailed(sub.lastErrorText(l)),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }

  static String _expiry(AppLocalizations l, DateTime at) {
    final days = at.difference(DateTime.now()).inDays;
    if (at.isBefore(DateTime.now())) return l.subExpired;
    if (days == 0) return l.subExpiresToday;
    return l.subExpiresIn(days);
  }

  static String _ago(AppLocalizations l, DateTime time) {
    final age = DateTime.now().difference(time);
    if (age.inMinutes < 1) return l.agoJustNow;
    if (age.inHours < 1) return l.agoMinutes(age.inMinutes);
    if (age.inDays < 1) return l.agoHours(age.inHours);
    return l.agoDays(age.inDays);
  }
}

Future<void> showImportSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: softAnimation,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ImportSheet(),
  );
}

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet();

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  final _controller = TextEditingController();
  String? _message;

  /// Why entries failed, one line each (shown under the message), as the core words them.
  List<String> _details = const [];

  /// Whether the message is about an import that worked in part (amber) and not one that failed (red).
  bool _partial = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _controller.text = data!.text!;
  }

  Future<void> _openFile() async {
    try {
      final file = await FilePicker.pickFile(dialogTitle: context.l10n.openTextFile);
      if (file == null) return;
      _controller.text = await readImportFile(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _partial = false;
        _message = describeFileProblem(context.l10n, e);
        _details = const [];
      });
      return;
    }
    await _import();
  }

  Future<void> _scanQr() async {
    final text = await Navigator.of(context).push<String>(
      AppRoute(builder: (_) => const QrScanScreen()),
    );
    if (text == null || !mounted) return;
    _controller.text = text;
    await _import();
  }

  /// Opens the subscription form (replacing this sheet), optionally prefilled.
  void _openSubscription([String url = '']) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(AppRoute<void>(builder: (_) => SubscriptionScreen(initialUrl: url)));
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // A single http(s) or nordvpn:// URL is a subscription link, not a config.
    if (!text.contains('\n') && RegExp(r'^(https?|nordvpn)://\S+$').hasMatch(text)) {
      _openSubscription(text);
      return;
    }
    setState(() {
      _busy = true;
      _partial = false;
      _message = null;
      _details = const [];
    });
    final ImportResult result;
    try {
      result = await ref.read(engineProvider).importText(_controller.text);
    } catch (e) {
      // The core could not be asked at all (it is not running, the connection to it broke): say so.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = context.l10n.importNothing(describeError(context.l10n, e));
      });
      return;
    }
    final added = ref.read(profilesProvider.notifier).addAll(ref.read(groupsProvider.notifier).place(_controller.text, result.profiles));
    if (!mounted) return;
    if (result.profiles.isNotEmpty && result.errors.isEmpty) {
      Navigator.of(context).pop();
      final dupes = result.profiles.length - added;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.importedProfiles(added, dupes)),
      ));
      return;
    }
    // What the core says went wrong with each entry: the errors of a partial import, or the reasons that came
    // along with a failure (without any, the failure's own message is already the message above).
    final failure = result.failure;
    final reasons = failure == null
        ? result.errors
        : (failure.args['details'] ?? '').split('\n').where((l) => l.isNotEmpty).toList();
    setState(() {
      _busy = false;
      _partial = result.profiles.isNotEmpty;
      _details = reasons;
      _message = result.profiles.isEmpty && result.errors.isNotEmpty
          ? context.l10n.importNothing(
              result.failure != null ? describeError(context.l10n, result.failure!) : result.errors.first,
            )
          : context.l10n.importPartial(added, result.errors.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The sheet rises with the keyboard; the form scrolls and the Import button stays
    // pinned under it, so neither the keyboard nor the system bar can cover it.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.importTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(context.l10n.importDescription),
            const SizedBox(height: 4),
            Text(context.l10n.importJsonNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (QrScanScreen.supported)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _scanQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(context.l10n.importScanQr),
                  ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _openFile,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(context.l10n.importOpenFile),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _paste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(context.l10n.importPaste),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _openSubscription,
                  icon: const Icon(Icons.add_link),
                  label: Text(context.l10n.importSubscription),
                ),
                PopupMenuButton<String>(
                  enabled: !_busy,
                  tooltip: context.l10n.importAddTor,
                  onSelected: (kind) {
                    _controller.text = 'tor://$kind';
                    unawaited(_import());
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: '', child: Text(context.l10n.importTorDirect)),
                    PopupMenuItem(value: 'snowflake', child: Text(context.l10n.importTorSnowflake)),
                    PopupMenuItem(value: 'obfs4', child: Text(context.l10n.importTorObfs4)),
                  ],
                  child: IgnorePointer(
                    child: FilledButton.tonalIcon(
                      onPressed: () {},
                      icon: const Icon(Icons.security),
                      label: Text(context.l10n.importTor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'vless://…'),
            ),
            // A failure is a red notice on the sheet itself (a snackbar would be hidden behind it); an import
            // that worked in part is amber.
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Notice(
                  message: _message!,
                  details: _details,
                  detailsTitle: context.l10n.importDetails,
                  tone: _partial ? NoticeTone.warning : NoticeTone.error,
                  messageKey: const Key('importMessage'),
                  detailsKey: const Key('importDetails'),
                ),
              ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _busy ? null : _import, child: Text(context.l10n.actionImport)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
