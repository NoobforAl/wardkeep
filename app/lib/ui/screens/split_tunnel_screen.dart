import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';

class InstalledApp {
  const InstalledApp(this.package, this.label, this.system);

  final String package;
  final String label;
  final bool system;
}

/// Android app list and icons, via the "omnitun/core" channel.
class AndroidApps {
  static const _channel = MethodChannel('omnitun/core');
  static final _icons = <String, Future<Uint8List?>>{};

  static Future<List<InstalledApp>> list() async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('listApps') ?? const [];
    final apps = [
      for (final a in raw) InstalledApp(a['package'] as String, a['label'] as String, a['system'] as bool),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  static Future<Uint8List?> icon(String package) =>
      _icons.putIfAbsent(package, () => _channel.invokeMethod<Uint8List>('appIcon', package));
}

/// Per-app split tunneling: choose which apps use (or bypass) the VPN.
class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  late final Future<List<InstalledApp>> _apps = AndroidApps.list();
  String _query = '';
  bool _showSystem = false;

  void _setMode(String mode) =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(splitMode: mode));

  void _toggle(String package, bool on) {
    ref.read(settingsProvider.notifier).update((settings) {
      final apps = {...settings.splitApps};
      on ? apps.add(package) : apps.remove(package);
      return settings.copyWith(splitApps: apps.toList()..sort());
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selected = settings.splitApps.toSet();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.splitTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'off', label: Text(context.l10n.splitAll)),
                ButtonSegment(value: 'include', label: Text(context.l10n.splitOnlySelected)),
                ButtonSegment(value: 'exclude', label: Text(context.l10n.splitBypassSelected)),
              ],
              selected: {settings.splitMode},
              onSelectionChanged: (v) => _setMode(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              switch (settings.splitMode) {
                'include' => selected.isEmpty
                    ? context.l10n.splitHelpOnlyNone
                    : context.l10n.splitHelpOnly(selected.length),
                'exclude' => context.l10n.splitHelpBypass(selected.length),
                _ => context.l10n.splitHelpOffMode,
              },
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (settings.splitMode != 'off') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.searchApps,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            SwitchListTile(
              dense: true,
              title: Text(context.l10n.showSystemApps),
              value: _showSystem,
              onChanged: (v) => setState(() => _showSystem = v),
            ),
            Expanded(
              child: FutureBuilder<List<InstalledApp>>(
                future: _apps,
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text(context.l10n.couldNotListApps('${snap.error}')));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final apps = snap.data!.where((app) {
                    if (!_showSystem && app.system && !selected.contains(app.package)) return false;
                    return _query.isEmpty ||
                        app.label.toLowerCase().contains(_query) ||
                        app.package.toLowerCase().contains(_query);
                  }).toList()
                    // Selected apps first.
                    ..sort((a, b) => (selected.contains(b.package) ? 1 : 0) - (selected.contains(a.package) ? 1 : 0));
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, i) {
                      final app = apps[i];
                      return CheckboxListTile(
                        value: selected.contains(app.package),
                        onChanged: (v) => _toggle(app.package, v ?? false),
                        secondary: _AppIcon(app.package),
                        title: Text(app.label, overflow: TextOverflow.ellipsis),
                        subtitle: Text(app.package, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon(this.package);

  final String package;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FutureBuilder<Uint8List?>(
        future: AndroidApps.icon(package),
        builder: (context, snap) => snap.data == null
            ? const Icon(Icons.android)
            : Image.memory(snap.data!, gaplessPlayback: true),
      ),
    );
  }
}
