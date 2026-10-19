import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import 'providers.dart';

/// A group the user made: a name for a set of servers they keep together (and can share as a file).
class ProfileGroup {
  const ProfileGroup({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ProfileGroup.fromJson(Map<String, dynamic> j) => ProfileGroup(id: j['id'] as String, name: j['name'] as String);
}

/// The first line of a group's text file. An import that starts with it puts what it brings into the group of
/// that name, so a shared group arrives as a group.
const groupFileHeader = '# Wardkeep group: ';

/// The text of a group's file: the header, then one share link per line (the core reads such a list as it is).
String groupFileText(String name, Iterable<String> links) => '$groupFileHeader${name.replaceAll(RegExp(r'[\r\n]+'), ' ')}\n${links.join('\n')}\n';

/// The group name a text starts with, or null when it has no [groupFileHeader] as its first line.
String? groupNameInText(String text) {
  for (final line in const LineSplitter().convert(text.startsWith('\u{feff}') ? text.substring(1) : text)) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (!t.startsWith(groupFileHeader.trim())) return null;
    final name = t.substring(groupFileHeader.trim().length).trim();
    return name.isEmpty ? null : name;
  }
  return null;
}

/// A file name for a group's text file.
String groupFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_').trim();
  return '${clean.isEmpty ? 'group' : clean}.txt';
}

/// The user's groups, persisted. A server is in a group when its `group` is the group's ID; the servers of no group
/// are "My servers" ([ProfileInfo.defaultGroup]).
class GroupsController extends Notifier<List<ProfileGroup>> {
  static const _key = 'groups';

  @override
  List<ProfileGroup> build() {
    final saved = ref.read(storeProvider).read<List<dynamic>>(_key) ?? const [];
    final out = <ProfileGroup>[];
    for (final raw in saved) {
      try {
        out.add(ProfileGroup.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (_) {
        // Skip entries written by an incompatible version.
      }
    }
    return out;
  }

  void _save(List<ProfileGroup> next) {
    state = next;
    ref.read(storeProvider).write(_key, [for (final g in next) g.toJson()]);
  }

  ProfileGroup? named(String name) {
    final n = name.trim().toLowerCase();
    for (final g in state) {
      if (g.name.toLowerCase() == n) return g;
    }
    return null;
  }

  /// A new group called [name]; the existing one when there already is a group of that name.
  ProfileGroup create(String name) {
    name = name.trim();
    final have = named(name);
    if (have != null) return have;
    final id = 'g-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final g = ProfileGroup(id: id, name: name);
    _save([...state, g]);
    return g;
  }

  void rename(String id, String name) {
    name = name.trim();
    if (name.isEmpty) return;
    _save([for (final g in state) g.id == id ? ProfileGroup(id: id, name: name) : g]);
  }

  /// Removes the group; its servers go back to the default group, none is deleted.
  void remove(String id) {
    ref.read(profilesProvider.notifier).ungroup(id);
    _save(state.where((g) => g.id != id).toList());
  }

  /// What an import brings, put in the group the text names (made when it is new); unchanged when it names none.
  List<ProfileInfo> place(String text, List<ProfileInfo> profiles) {
    final name = groupNameInText(text);
    if (name == null || profiles.isEmpty) return profiles;
    final g = create(name);
    return [for (final p in profiles) p.group == ProfileInfo.defaultGroup ? p.inGroup(g.id) : p];
  }
}

final groupsProvider = NotifierProvider<GroupsController, List<ProfileGroup>>(GroupsController.new);
