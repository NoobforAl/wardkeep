import 'dart:io';

import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/ipdb_state.dart';
import '../insets.dart';
import '../widgets/notice.dart';
import 'bypass_screen.dart';
import 'dns_screen.dart';
import 'ipdb_screen.dart';
import 'logs_screen.dart';
import 'network_tiles.dart';
import 'notices_screen.dart';
import 'profiles_screen.dart';
import 'split_tunnel_screen.dart';
import '../layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final bypassEntries = ref.watch(bypassListsProvider).where((b) => b.enabled).fold<int>(0, (n, b) => n + b.entries);
    void open(Widget page) => Navigator.of(context).push(AppRoute<void>(builder: (_) => page));
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
                  value: settings.tunMode,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(tunMode: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lan_outlined),
                  title: Text(l.systemProxy),
                  subtitle: Text(l.systemProxyHint),
                  value: settings.systemProxy,
                  onChanged: settings.tunMode ? null : (v) => ctrl.update((s) => s.copyWith(systemProxy: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: Text(l.autoSwitch),
                  subtitle: Text(l.autoSwitchHint),
                  value: settings.autoFailover,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(autoFailover: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.travel_explore_rounded),
                  title: Text(l.exitTitle),
                  subtitle: Text(l.exitHint),
                  value: settings.showExit,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(showExit: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.devices_other_rounded),
                  title: Text(l.bypassLan),
                  subtitle: Text(l.bypassLanHint),
                  value: settings.bypassLan,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(bypassLan: v)),
                ),
                ...networkTiles(context, ref, settings),
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
                    subtitle: Text(switch (settings.splitMode) {
                      'include' => l.splitSummaryOnly(settings.splitApps.length),
                      'exclude' => l.splitSummaryBypass(settings.splitApps.length),
                      _ => l.splitSummaryOff,
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: settings.tunMode,
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
                  subtitle: Text(dnsSummary(l, settings), textDirection: TextDirection.ltr),
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
                    settings.language.isEmpty
                        ? l.languageSystem
                        : supportedLanguages.where((e) => e.$1 == settings.language).map((e) => e.$2).firstOrNull ??
                              settings.language,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context, ref, settings.language),
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
                        selected: {settings.theme},
                        onSelectionChanged: (v) => ctrl.update((s) => s.copyWith(theme: v.first)),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new_rounded),
                  title: Text(l.stopOnClose),
                  value: settings.stopOnClose,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(stopOnClose: v)),
                ),
                if (Platform.isWindows)
                  SwitchListTile(
                    secondary: const Icon(Icons.web_asset_off_outlined),
                    title: Text(l.keepInTray),
                    subtitle: Text(l.keepInTrayHint),
                    value: settings.keepInTray,
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
              _Header(l.settingsLogging),
              _Group([
                ListTile(
                  key: const Key('debug-logging'),
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(l.debugLogging),
                  subtitle: Text(_loggingSummary(context, settings, ref.watch(loggingModeProvider).value)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLogLevel(context, ref, settings.activeLogLevel()),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.error_outline_rounded),
                  title: Text(l.notifyPopup),
                  subtitle: Text(l.notifyPopupHint),
                  value: settings.notifyPopup,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(notifyPopup: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(l.notifyOs),
                  subtitle: Text(l.notifyOsHint),
                  value: settings.notifyOs,
                  onChanged: (v) => ctrl.update((s) => s.copyWith(notifyOs: v)),
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

/// The name of a log level of "Debug logging" ('' is off).
String _logLevelName(AppLocalizations l, String level) => switch (level) {
  'info' => l.logLevelInfo,
  'debug' => l.logLevelDebug,
  'trace' => l.logLevelTrace,
  _ => l.debugLoggingOff,
};

/// "Debug logging" in a line or two: the level chosen and until when, and the level the core reports.
String _loggingSummary(BuildContext context, SettingsState settings, LoggingMode? core) {
  final l = context.l10n;
  final level = settings.activeLogLevel();
  final until = DateTime.tryParse(settings.logUntil)?.toLocal();
  final chosen = level.isEmpty || until == null
      ? l.debugLoggingOff
      : l.debugLoggingUntil(
          _logLevelName(l, level),
          DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(until),
        );
  if (core == null || core.effectiveLevel.isEmpty) return chosen;
  return '$chosen\n${l.debugLoggingCore(core.effectiveLevel, core.mode)}';
}

/// "Debug logging": off or a level, with what it costs said first.
Future<void> _pickLogLevel(BuildContext context, WidgetRef ref, String current) async {
  final l = context.l10n;
  final picked = await showDialog<String>(animationStyle: softAnimation,
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l.debugLogging),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Notice(tone: NoticeTone.warning, message: l.debugLoggingWarning),
        ),
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            children: [
              for (final level in SettingsState.logLevels)
                RadioListTile<String>(value: level, title: Text(_logLevelName(l, level))),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked != null && picked != current) ref.read(settingsProvider.notifier).setLogLevel(picked);
}

/// The language of the app: the system's, or one of the translations (each shown in its own language).
Future<void> _pickLanguage(BuildContext context, WidgetRef ref, String current) async {
  final l = context.l10n;
  final picked = await showDialog<String>(animationStyle: softAnimation, 
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
