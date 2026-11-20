import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../state/groups.dart';
import '../../state/providers.dart';
import '../../state/subscriptions.dart';
import '../../state/usage.dart';
import '../import_file.dart';
import '../widgets/action_sheet.dart';
import '../widgets/menu_item.dart';
import '../widgets/profile_subtitle.dart';
import '../widgets/protocol_badge.dart';
import 'import_screen.dart';
import 'location_screen.dart';
import 'profile_editor_screen.dart';
import 'share_screen.dart';
import 'subscription_screen.dart';
import '../widgets/credentials_dialog.dart';
import '../layout.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  /// Whether several servers are being picked, and which ones.
  bool _selecting = false;
  final Set<String> _picked = {};

  void _startSelecting([Iterable<String> ids = const []]) => setState(() {
        _selecting = true;
        _picked.addAll(ids);
      });

  void _stopSelecting() => setState(() {
        _selecting = false;
        _picked.clear();
      });

  void _toggle(String id) => setState(() {
        if (!_picked.remove(id)) _picked.add(id);
        // Un-ticking the last one ends the mode, as in the system's own lists.
        if (_picked.isEmpty) _selecting = false;
      });

  Future<void> _deletePicked() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final servers = l.serversCount(_picked.length);
    final sure = await showDialog<bool>(
      animationStyle: softAnimation,
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(l.bulkDeleteTitle),
        content: Text(l.bulkDeleteBody(servers)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    ref.read(profilesProvider.notifier).removeMany({..._picked});
    _stopSelecting();
    messenger.showSnackBar(SnackBar(content: Text(l.bulkDeletedToast(servers))));
  }

  Future<void> _movePicked() async {
    final all = ref.read(profilesProvider);
    final chosen = all.where((p) => _picked.contains(p.id)).toList();
    final moved = await _moveToGroup(context, ref, chosen);
    if (moved && mounted) _stopSelecting();
  }

  /// What a server's menu (the three dots, or holding the row) offers.
  Future<void> _serverActions(ProfileInfo profile) async {
    final l = context.l10n;
    final defaultId = ref.read(defaultProfileProvider)?.id;
    final hasEditor = ref.read(formsProvider).value?.any((f) => f.protocol == profile.protocol) ?? false;
    final choice = await showActionSheet(
      context,
      header: ListTile(
        title: Text(profile.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: ProfileSubtitle(profile),
        trailing: ProtocolBadge(profile.protocol),
      ),
      actions: [
        if (hasEditor)
          ActionItem('edit', Icons.edit_outlined, profile.protocol == 'tor' ? l.menuBridgeSettings : l.menuEditServer),
        ActionItem('share', Icons.qr_code_2_rounded, l.menuShare),
        ActionItem('move', Icons.drive_file_move_outline, l.menuMoveToGroup),
        if (profile.id != defaultId) ActionItem('default', Icons.star_outline_rounded, l.menuSetDefault),
        if (profile.needsCredentials) ActionItem('credentials', Icons.key_outlined, l.menuCredentials),
        if (ref.read(usageOfProvider(profile.id)) > 0) ActionItem('usage', Icons.restart_alt_rounded, l.menuResetUsage),
        ActionItem('select', Icons.checklist_rounded, l.menuSelect),
        ActionItem('delete', Icons.delete_outline_rounded, l.actionDelete, danger: true),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'edit':
        unawaited(Navigator.of(context).push(AppRoute<void>(builder: (_) => ProfileEditorScreen(profile: profile))));
      case 'share':
        unawaited(Navigator.of(context).push(AppRoute<void>(builder: (_) => ShareScreen(profile: profile))));
      case 'move':
        unawaited(_moveToGroup(context, ref, [profile]));
      case 'default':
        ref.read(defaultProfileIdProvider.notifier).set(profile.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.defaultSetToast(profile.name))));
      case 'credentials':
        unawaited(askCredentials(context, ref, profile));
      case 'usage':
        ref.read(profileUsageProvider.notifier).reset(profile.id);
      case 'select':
        _startSelecting([profile.id]);
      case 'delete':
        ref.read(profilesProvider.notifier).remove(profile.id);
    }
  }

  AppBar _selectionBar(List<ProfileInfo> profiles) {
    final l = context.l10n;
    return AppBar(
      leading: IconButton(tooltip: l.actionCancel, onPressed: _stopSelecting, icon: const Icon(Icons.close_rounded)),
      title: Text(l.selectedCount(_picked.length)),
      actions: [
        IconButton(
          tooltip: l.selectAll,
          onPressed: () => setState(() => _picked.addAll(profiles.map((p) => p.id))),
          icon: const Icon(Icons.select_all_rounded),
        ),
        IconButton(
          tooltip: l.menuMoveToGroup,
          onPressed: _picked.isEmpty ? null : _movePicked,
          icon: const Icon(Icons.drive_file_move_outline),
        ),
        IconButton(
          tooltip: l.actionDelete,
          color: Theme.of(context).colorScheme.error,
          onPressed: _picked.isEmpty ? null : _deletePicked,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  AppBar _normalBar(List<ProfileInfo> profiles, List<Subscription> subs) {
    final l = context.l10n;
    return AppBar(
      title: Text(l.profilesTitle),
      actions: [
        IconButton(
          tooltip: l.addSubscriptionTooltip,
          onPressed: () => Navigator.of(context).push(AppRoute<void>(builder: (_) => const SubscriptionScreen())),
          icon: const Icon(Icons.add_link),
        ),
        IconButton(
          tooltip: l.testLatencyTooltip,
          onPressed: profiles.isEmpty ? null : () => testAllLatencies(ref),
          icon: const Icon(Icons.speed),
        ),
        PopupMenuButton<String>(
          tooltip: l.tooltipMore,
          position: PopupMenuPosition.under,
          onSelected: (choice) async {
            if (choice == 'select') {
              _startSelecting();
            } else if (choice == 'new_group') {
              final name = await _askGroupName(context, l.menuNewGroup, '', l.groupCreate);
              if (name != null) ref.read(groupsProvider.notifier).create(name);
            } else if (choice == 'restore_tor') {
              await ref.read(defaultProfileIdProvider.notifier).ensureTorDefaults(force: true);
            } else if (choice == 'delete_all') {
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              final sure = await showDialog<bool>(
                animationStyle: softAnimation,
                context: context,
                builder: (context) => AlertDialog(
                  icon: const Icon(Icons.delete_sweep_outlined),
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
            iconMenuItem('select', Icons.checklist_rounded, l.menuSelect, enabled: profiles.isNotEmpty),
            iconMenuItem('new_group', Icons.create_new_folder_outlined, l.menuNewGroup),
            iconMenuItem('restore_tor', Icons.restore_rounded, l.menuRestoreTor),
            const PopupMenuDivider(),
            iconMenuItem(
              'delete_all',
              Icons.delete_sweep_outlined,
              l.menuDeleteAll,
              danger: true,
              enabled: profiles.any((p) => p.protocol != 'tor') || subs.isNotEmpty,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final subs = ref.watch(subscriptionsProvider);
    final groups = ref.watch(groupsProvider);
    final selected = ref.watch(selectedProfileIdProvider);
    ref.watch(formsProvider); // loads the editors, so Edit appears in the menus
    final manual = profiles.where((p) => p.group == ProfileInfo.defaultGroup).toList();
    final picked = _selecting ? _picked : null;

    // A server that goes while picking (its subscription deleted, say) is no longer picked; with none left the mode ends.
    ref.listen(profilesProvider, (_, next) {
      if (!_selecting) return;
      final present = {for (final p in next) p.id};
      if (_picked.every(present.contains)) return;
      setState(() {
        _picked.removeWhere((id) => !present.contains(id));
        if (_picked.isEmpty) _selecting = false;
      });
    });

    _GroupList list(String group, List<ProfileInfo> members) => _GroupList(
          group: group,
          profiles: members,
          selectedId: selected,
          picked: picked,
          onToggle: _toggle,
          onActions: _serverActions,
        );

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopSelecting();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar(profiles) : _normalBar(profiles, subs),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => showImport(context),
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
                      child: Text(context.l10n.profilesHintActions, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                  if (manual.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _GroupTitle(context.l10n.myProfiles)),
                    list(ProfileInfo.defaultGroup, manual),
                  ],
                  for (final g in groups) ...[
                    SliverToBoxAdapter(
                      child: _UserGroupHeader(
                        g,
                        profiles.where((p) => p.group == g.id).toList(),
                        onSelectMembers: _startSelecting,
                      ),
                    ),
                    if (profiles.any((p) => p.group == g.id))
                      list(g.id, profiles.where((p) => p.group == g.id).toList())
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
                    SliverToBoxAdapter(
                      child: _SubscriptionHeader(sub, onSelectMembers: () => _startSelecting(profiles.where((p) => p.group == sub.id).map((p) => p.id))),
                    ),
                    list(sub.id, profiles.where((p) => p.group == sub.id).toList()),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
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

/// One group's profiles, reorderable within the group by the handle at the end of each row.
class _GroupList extends ConsumerWidget {
  const _GroupList({
    required this.group,
    required this.profiles,
    required this.selectedId,
    required this.picked,
    required this.onToggle,
    required this.onActions,
  });

  final String group;
  final List<ProfileInfo> profiles;
  final String? selectedId;

  /// The servers ticked while several are being picked; null when they are not.
  final Set<String>? picked;
  final void Function(String id) onToggle;
  final void Function(ProfileInfo profile) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultId = ref.watch(defaultProfileProvider)?.id;
    final scheme = Theme.of(context).colorScheme;
    final picking = picked != null;
    return SliverReorderableList(
      itemCount: profiles.length,
      onReorderItem: (from, to) => ref.read(profilesProvider.notifier).reorderInGroup(group, from, to),
      itemBuilder: (context, i) {
        final profile = profiles[i];
        final ticked = picked?.contains(profile.id) ?? false;
        return Material(
          key: ValueKey(profile.id),
          type: MaterialType.transparency,
          child: ListTile(
            selected: picking ? ticked : profile.id == selectedId,
            leading: picking
                ? Checkbox(value: ticked, onChanged: (_) => onToggle(profile.id))
                : Icon(profile.id == selectedId ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Row(
              children: [
                Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
                if (profile.id == defaultId) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.l10n.badgeDefault,
                    child: Icon(Icons.star_rounded, size: 18, color: scheme.primary),
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
                if (!picking) ...[
                  IconButton(
                    tooltip: context.l10n.tooltipMore,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onActions(profile),
                    icon: const Icon(Icons.more_vert),
                  ),
                  if (profiles.length > 1)
                    ReorderableDragStartListener(
                      index: i,
                      child: Semantics(
                        label: context.l10n.reorderHandle,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.drag_indicator_rounded, size: 22, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ],
            ),
            onTap: picking ? () => onToggle(profile.id) : () => ref.read(selectedProfileIdProvider.notifier).select(profile.id),
            // Holding a row opens its menu (or ticks it while several are being picked).
            onLongPress: picking
                ? () => onToggle(profile.id)
                : () {
                    unawaited(HapticFeedback.selectionClick());
                    onActions(profile);
                  },
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

/// Moves servers to one of the user's groups, to a new one, or back to "My servers": a sheet lists the places, so
/// several servers can be grouped in one step. True when they were moved.
Future<bool> _moveToGroup(BuildContext context, WidgetRef ref, List<ProfileInfo> servers) async {
  final l = context.l10n;
  const fresh = '\u0000new';
  final groups = ref.read(groupsProvider);
  final all = ref.read(profilesProvider);
  // A place the servers are all in already is no use to pick.
  bool allIn(String group) => servers.every((p) => p.group == group);
  final pick = await showModalBottomSheet<String>(
    context: context,
    sheetAnimationStyle: softAnimation,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l.groupMoveTitle, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(servers.length == 1 ? servers.first.name : l.serversCount(servers.length), overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (!allIn(ProfileInfo.defaultGroup))
                  ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: Text(l.myProfiles),
                    trailing: Text(l.serversCount(all.where((p) => p.group == ProfileInfo.defaultGroup).length)),
                    onTap: () => Navigator.pop(context, ProfileInfo.defaultGroup),
                  ),
                for (final g in groups)
                  if (!allIn(g.id))
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(g.name, overflow: TextOverflow.ellipsis),
                      trailing: Text(l.serversCount(all.where((p) => p.group == g.id).length)),
                      onTap: () => Navigator.pop(context, g.id),
                    ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(l.menuNewGroup),
                  onTap: () => Navigator.pop(context, fresh),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (pick == null || !context.mounted) return false;
  var target = pick;
  var targetName = pick == ProfileInfo.defaultGroup ? l.myProfiles : groups.where((g) => g.id == pick).map((g) => g.name).firstOrNull ?? '';
  if (pick == fresh) {
    final name = await _askGroupName(context, l.menuNewGroup, '', l.groupCreate);
    if (name == null) return false;
    final group = ref.read(groupsProvider.notifier).create(name);
    target = group.id;
    targetName = group.name;
  }
  ref.read(profilesProvider.notifier).moveMany({for (final p in servers) p.id}, target);
  if (context.mounted && servers.length > 1) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bulkMovedToast(l.serversCount(servers.length), targetName))));
  }
  return true;
}

/// A group of the user's: its name and what can be done with it as a whole.
class _UserGroupHeader extends ConsumerWidget {
  const _UserGroupHeader(this.group, this.members, {required this.onSelectMembers});

  final ProfileGroup group;
  final List<ProfileInfo> members;

  /// Starts picking servers with this group's members ticked.
  final void Function(Iterable<String> ids) onSelectMembers;

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

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final choice = await showActionSheet(
      context,
      header: ListTile(
        leading: Icon(Icons.folder_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(group.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.serversCount(members.length)),
      ),
      actions: [
        ActionItem('select', Icons.checklist_rounded, l.menuSelect, enabled: members.isNotEmpty),
        ActionItem('file', Icons.save_alt_rounded, l.menuShareGroupFile, enabled: members.isNotEmpty),
        ActionItem('copy', Icons.link_rounded, l.menuCopyGroupLinks, enabled: members.isNotEmpty),
        ActionItem('rename', Icons.drive_file_rename_outline_rounded, l.menuRenameGroup),
        ActionItem('delete', Icons.folder_delete_outlined, l.menuDeleteGroup, danger: true),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'select':
        onSelectMembers(members.map((p) => p.id));
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
            icon: const Icon(Icons.folder_delete_outlined),
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    // The whole header answers a tap or a hold, like a server's row.
    return InkWell(
      onTap: () => _actions(context, ref),
      onLongPress: () => _actions(context, ref),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(group.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
            Text(l.serversCount(members.length), style: theme.textTheme.bodySmall),
            IconButton(
              tooltip: l.tooltipMore,
              onPressed: () => _actions(context, ref),
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscription name, usage, expiry, last update and actions.
class _SubscriptionHeader extends ConsumerWidget {
  const _SubscriptionHeader(this.sub, {required this.onSelectMembers});

  final Subscription sub;

  /// Starts picking servers with this subscription's servers ticked.
  final VoidCallback onSelectMembers;

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final choice = await showActionSheet(
      context,
      header: ListTile(
        leading: Icon(Icons.cloud_sync_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(sub.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.serversCount(ref.read(profilesProvider).where((p) => p.group == sub.id).length)),
      ),
      actions: [
        ActionItem('refresh', Icons.refresh_rounded, l.refreshTooltip),
        ActionItem('select', Icons.checklist_rounded, l.menuSelect),
        ActionItem('edit', Icons.edit_outlined, l.actionEdit),
        ActionItem('delete', Icons.delete_outline_rounded, l.subDeleteWithProfiles, danger: true),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'refresh':
        await _refresh(context, ref);
      case 'select':
        onSelectMembers();
      case 'edit':
        unawaited(Navigator.of(context).push(AppRoute<void>(builder: (_) => SubscriptionScreen(existing: sub))));
      case 'delete':
        ref.read(subscriptionsProvider.notifier).remove(sub.id);
    }
  }

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

    return InkWell(
      onLongPress: () => _actions(context, ref),
      child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 4, 4),
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
              IconButton(
                tooltip: l.tooltipMore,
                onPressed: () => _actions(context, ref),
                icon: const Icon(Icons.more_vert),
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
