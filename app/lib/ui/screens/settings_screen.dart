import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/ipdb_state.dart';
import '../insets.dart';
import 'bypass_screen.dart';
import 'dns_screen.dart';
import 'ipdb_screen.dart';
import 'logs_screen.dart';
import 'network_tiles.dart';
import 'notices_screen.dart';
import 'profiles_screen.dart';
import 'split_tunnel_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final bypassEntries = ref.watch(bypassListsProvider).where((b) => b.enabled).fold<int>(0, (n, b) => n + b.entries);
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: withBottomInset(context, const EdgeInsets.only(bottom: 32)),
            children: [
              _Header(l.settingsServers),
              _Group([
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(l.manageServers),
                  subtitle: Text(l.manageServersHint),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const ProfilesScreen()),
                ),
              ]),
              _Header(l.settingsConnection),
              _Group([
                SwitchListTile(
                  secondary: const Icon(Icons.vpn_lock_rounded),
                  title: Text(l.vpnMode),
                  subtitle: Text(l.vpnModeHint),
                  value: s.tunMode,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(tunMode: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lan_outlined),
                  title: Text(l.systemProxy),
                  subtitle: Text(l.systemProxyHint),
                  value: s.systemProxy,
                  onChanged: s.tunMode ? null : (v) => ctrl.update((s) => s.copyWith(systemProxy: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: Text(l.autoSwitch),
                  subtitle: Text(l.autoSwitchHint),
                  value: s.autoFailover,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(autoFailover: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.travel_explore_rounded),
                  title: Text(l.exitTitle),
                  subtitle: Text(l.exitHint),
                  value: s.showExit,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(showExit: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.devices_other_rounded),
                  title: Text(l.bypassLan),
                  subtitle: Text(l.bypassLanHint),
                  value: s.bypassLan,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(bypassLan: v)),
                ),
                ...networkTiles(context, ref, s),
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded),
                  title: Text(l.bypassTitle),
                  subtitle: Text(bypassEntries == 0 ? l.bypassListsHint : l.bypassListsInUse(bypassEntries)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const BypassScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: Text(l.ipdbTitle),
                  subtitle: Text(ipDbSubtitle(l, ref.watch(ipDbProvider))),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const IpDbScreen()),
                ),
                if (Platform.isAndroid)
                  ListTile(
                    leading: const Icon(Icons.call_split_rounded),
                    title: Text(l.splitTunneling),
                    subtitle: Text(switch (s.splitMode) {
                      'include' => l.splitSummaryOnly(s.splitApps.length),
                      'exclude' => l.splitSummaryBypass(s.splitApps.length),
                      _ => l.splitSummaryOff,
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: s.tunMode,
                    onTap: () => open(const SplitTunnelScreen()),
                  ),
                if (Platform.isAndroid)
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(l.alwaysOnTitle),
                    subtitle: Text(l.alwaysOnHint),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => _openVpnSettings(context),
                  ),
                ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(l.remoteDns),
                  subtitle: Text(dnsSummary(l, s), textDirection: TextDirection.ltr),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const DnsScreen()),
                ),
              ]),
              _Header(l.settingsApp),
              _Group([
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(l.language),
                  subtitle: Text(
                    s.language.isEmpty
                        ? l.languageSystem
                        : supportedLanguages.where((e) => e.$1 == s.language).map((e) => e.$2).firstOrNull ??
                              s.language,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context, ref, s.language),
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l.appearance),
                  // The choice sits under the title, so the title never has to wrap.
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: 'dark',
                            icon: const Icon(Icons.dark_mode_outlined),
                            tooltip: l.themeDark,
                          ),
                          ButtonSegment(
                            value: 'system',
                            icon: const Icon(Icons.brightness_auto_outlined),
                            tooltip: l.themeSystem,
                          ),
                          ButtonSegment(
                            value: 'light',
                            icon: const Icon(Icons.light_mode_outlined),
                            tooltip: l.themeLight,
                          ),
                        ],
                        selected: {s.theme},
                        onSelectionChanged: (v) => ctrl.update((s) => s.copyWith(theme: v.first)),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new_rounded),
                  title: Text(l.stopOnClose),
                  value: s.stopOnClose,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(stopOnClose: v)),
                ),
                if (Platform.isWindows)
                  SwitchListTile(
                    secondary: const Icon(Icons.web_asset_off_outlined),
                    title: Text(l.keepInTray),
                    subtitle: Text(l.keepInTrayHint),
                    value: s.keepInTray,
                    onChanged: (v) => ctrl.update((s) => s.copyWith(keepInTray: v)),
                  ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(l.tooltipLogs),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const LogsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(l.noticesTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(const NoticesScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l.appName),
                  subtitle: Text(l.aboutLine(ref.watch(engineProvider).name)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openVpnSettings(BuildContext context) async {
  final l = context.l10n;
  final opened = await const MethodChannel('omnitun/core').invokeMethod<bool>('openVpnSettings') ?? false;
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.openVpnSettingsFallback)));
  }
}

/// The language of the app: the system's, or one of the translations (each shown in its own language).
Future<void> _pickLanguage(BuildContext context, WidgetRef ref, String current) async {
  final l = context.l10n;
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l.language),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            children: [
              for (final option in [('', l.languageSystem), ...supportedLanguages])
                RadioListTile<String>(value: option.$1, title: Text(option.$2)),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(language: picked));
}

/// A rounded card holding one section's rows.
class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(indent: 56, color: Theme.of(context).colorScheme.outlineVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) divider, children[i]],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
