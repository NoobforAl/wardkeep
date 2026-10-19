import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/dns_resolvers.dart';
import '../../state/dns_state.dart';
import '../../state/providers.dart';
import '../insets.dart';

/// The translated text for a problem with a typed resolver.
String dnsProblemText(AppLocalizations l, DnsProblem p) => switch (p) {
  DnsProblem.notStamp || DnsProblem.badUrl => l.dnsErrAddress,
  DnsProblem.damaged => l.dnsErrDamaged,
  DnsProblem.unsupported => l.dnsErrUnsupported,
  DnsProblem.relayAsResolver || DnsProblem.notRelay => l.dnsErrRelayStamp,
};

/// What the resolver setting is called in the settings row and on the home screen.
String dnsSummary(AppLocalizations l, SettingsState s) {
  if (isDefaultDns(s.remoteDns)) return '${l.dnsDefault} · ${dnsPresets.first.title}';
  final preset = dnsPresets.where((p) => p.dns == s.remoteDns).firstOrNull;
  if (preset != null) return preset.title;
  return describeDns(s.remoteDns, s.dnsRelay, l.dnsAnonymizedShort);
}

const _customId = 'custom';

/// Which row of the list the stored setting corresponds to.
String dnsSelectedId(String remoteDns) {
  final dns = remoteDns.trim();
  final preset = dnsPresets.where((p) => p.dns == dns).firstOrNull;
  if (preset != null) return 'preset:${preset.id}';
  final entry = dnsEntryForStamp(dns);
  return entry != null ? 'stamp:${entry.name}' : _customId;
}

/// Settings → DNS: the resolver the tunnel uses, DNSCrypt resolvers from the bundled signed list,
/// Anonymized DNSCrypt, and a custom address or DNS stamp.
class DnsScreen extends ConsumerStatefulWidget {
  const DnsScreen({super.key});

  @override
  ConsumerState<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends ConsumerState<DnsScreen> {
  late final TextEditingController _custom;
  DnsCheck? _check;

  @override
  void initState() {
    super.initState();
    final dns = ref.read(settingsProvider).remoteDns;
    _custom = TextEditingController(text: dnsSelectedId(dns) == _customId ? dns : '');
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _set(String dns, {String? relay}) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(remoteDns: dns, dnsRelay: relay ?? s.dnsRelay));
  }

  /// A relay of the resolver's own operator hides nothing, so it is replaced when the resolver changes.
  String _relayFor(String dns) {
    final s = ref.read(settingsProvider);
    if (s.dnsRelay.isEmpty || !isDnsCryptStamp(dns)) return '';
    final resolver = dnsEntryForStamp(dns);
    final current = dnsRelayEntry(s.dnsRelay);
    if (resolver == null || current == null) return s.dnsRelay;
    if (dnsOperatorOf(current.name) != dnsOperatorOf(resolver.name)) return s.dnsRelay;
    return pickRelayFor(resolver)?.stamp ?? '';
  }

  void _pick(String id) {
    if (id == _customId) {
      final text = _custom.text.trim();
      if (text.isNotEmpty && checkDnsSetting(text).ok) _set(text, relay: _relayFor(text));
      setState(() => _check = text.isEmpty ? null : checkDnsSetting(text));
      return;
    }
    final String dns;
    if (id.startsWith('preset:')) {
      dns = dnsPresets.firstWhere((p) => 'preset:${p.id}' == id).dns;
    } else {
      dns = kDnsCryptResolvers.firstWhere((e) => 'stamp:${e.name}' == id).stamp;
    }
    _set(dns, relay: _relayFor(dns));
    setState(() => _check = null);
  }

  void _saveCustom() {
    final text = _custom.text.trim();
    final check = checkDnsSetting(text);
    setState(() => _check = check);
    if (check.ok) _set(text, relay: _relayFor(text));
  }

  void _anonymize(bool on) {
    final s = ref.read(settingsProvider);
    if (!on) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(dnsRelay: ''));
      return;
    }
    final resolver = dnsEntryForStamp(s.remoteDns);
    final relay = resolver != null ? pickRelayFor(resolver) : (kDnsRelays.isEmpty ? null : kDnsRelays.first);
    if (relay != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(dnsRelay: relay.stamp));
  }

  Future<void> _chooseRelay() async {
    final l = context.l10n;
    final s = ref.read(settingsProvider);
    final resolver = dnsEntryForStamp(s.remoteDns);
    final op = resolver == null ? null : dnsOperatorOf(resolver.name);
    final picked = await showDialog<String>(animationStyle: softAnimation, 
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.dnsRelayChoose),
        children: [
          SizedBox(
            width: 360,
            height: 360,
            child: ListView(
              children: [
                ListTile(
                  title: Text(l.dnsRelayAutomatic),
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final r in kDnsRelays)
                  // Not the resolver's own operator.
                  if (op == null || dnsOperatorOf(r.name) != op)
                    ListTile(
                      selected: r.stamp == s.dnsRelay,
                      title: Text(r.name, textDirection: TextDirection.ltr),
                      subtitle: r.country.isEmpty ? null : Text(context.countryName(r.country)),
                      onTap: () => Navigator.pop(context, r.stamp),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked.isEmpty) {
      _anonymize(true);
    } else {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(dnsRelay: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final selected = dnsSelectedId(s.remoteDns);
    final dnscrypt = isDnsCryptStamp(s.remoteDns);
    final anonymized = dnscrypt && s.dnsRelay.isNotEmpty;
    final relay = anonymized ? dnsRelayEntry(s.dnsRelay) : null;
    final custom = _custom.text.trim();
    final customCheck = _check ?? (custom.isEmpty ? null : checkDnsSetting(custom));
    final canSave = custom.isNotEmpty && customCheck != null && customCheck.ok && custom != s.remoteDns.trim();

    Widget card(List<Widget> rows) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(clipBehavior: Clip.antiAlias, child: Column(children: rows)),
    );
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 16, 8),
      child: Text(t, style: text.titleSmall?.copyWith(color: scheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.remoteDns)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: withBottomInset(context, const EdgeInsets.only(bottom: 32)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 24, 4),
                child: Text(l.dnsPickerHelp, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) {
                  if (v != null) _pick(v);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    card([
                      for (final p in dnsPresets)
                        RadioListTile<String>(
                          key: ValueKey('dns-preset-${p.id}'),
                          value: 'preset:${p.id}',
                          title: Text(p.isDefault ? l.dnsDefault : p.title),
                          subtitle: Text(p.isDefault ? p.title : p.dns, textDirection: TextDirection.ltr),
                        ),
                    ]),
                    header(l.dnsSectionDnscrypt),
                    card([
                      for (final r in kDnsCryptResolvers)
                        RadioListTile<String>(
                          key: ValueKey('dns-stamp-${r.name}'),
                          value: 'stamp:${r.name}',
                          title: Text(r.name, textDirection: TextDirection.ltr),
                          subtitle: Text(r.country.isEmpty ? 'DNSCrypt' : 'DNSCrypt · ${context.countryName(r.country)}'),
                        ),
                    ]),
                    header(l.dnsCustom),
                    card([
                      RadioListTile<String>(
                        key: const ValueKey('dns-custom'),
                        value: _customId,
                        title: Text(l.dnsCustom),
                        subtitle: selected == _customId && s.remoteDns.trim().isNotEmpty
                            ? Text(describeDns(s.remoteDns, s.dnsRelay, l.dnsAnonymizedShort), textDirection: TextDirection.ltr)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              key: const ValueKey('dns-custom-field'),
                              controller: _custom,
                              keyboardType: TextInputType.url,
                              textDirection: TextDirection.ltr, // an address is left to right in every language
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: l.dnsCustomLabel,
                                hintText: 'https://…  tls://…  sdns://…',
                                errorText: customCheck != null && !customCheck.ok
                                    ? dnsProblemText(l, customCheck.problem!)
                                    : null,
                                errorMaxLines: 3,
                              ),
                              onChanged: (_) => setState(() => _check = null),
                              onSubmitted: (_) => _saveCustom(),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton.tonal(
                                key: const ValueKey('dns-custom-save'),
                                onPressed: canSave ? _saveCustom : null,
                                child: Text(l.actionSave),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              card([
                SwitchListTile(
                  key: const ValueKey('dns-anonymized'),
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: Text(l.dnsAnonymized),
                  subtitle: Text(dnscrypt ? l.dnsAnonymizedHint : l.dnsAnonymizedNeedsDnscrypt),
                  value: anonymized,
                  onChanged: dnscrypt ? _anonymize : null,
                ),
                SoftAppear(
                  show: anonymized,
                  child: ListTile(
                    key: const ValueKey('dns-relay'),
                    leading: const Icon(Icons.alt_route_rounded),
                    title: Text(l.dnsRelay),
                    subtitle: Text(
                      relay == null
                          ? describeDns(s.dnsRelay)
                          : '${relay.name}${relay.country.isEmpty ? '' : ' · ${context.countryName(relay.country)}'}',
                      textDirection: TextDirection.ltr,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseRelay,
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 24, 0),
                child: Text(l.dnsLimits, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "DNS: DNSCrypt · quad9.net": one line in the connected details, only when a resolver other than the
/// default is set.
class DnsLine extends ConsumerWidget {
  const DnsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    if (isDefaultDns(s.remoteDns)) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        l.dnsLine(describeDns(s.remoteDns, s.dnsRelay, l.dnsAnonymizedShort)),
        key: const ValueKey('dns-line'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
