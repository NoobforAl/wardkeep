import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/bypass_countries.dart';
import '../../state/countries.dart';
import '../../state/country_zones.dart';
import '../../state/ipdb_state.dart';
import '../../state/providers.dart';
import '../insets.dart';
import '../widgets/country_flag.dart';
import 'ipdb_screen.dart';

/// Chooses the countries whose address ranges go around the VPN. A country's ranges come from the
/// offline country database when it is installed, and otherwise from a small list downloaded for each
/// country that is ticked (a few kilobytes).
class BypassCountriesScreen extends ConsumerStatefulWidget {
  const BypassCountriesScreen({super.key});

  @override
  ConsumerState<BypassCountriesScreen> createState() => _BypassCountriesScreenState();
}

class _BypassCountriesScreenState extends ConsumerState<BypassCountriesScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Countries ticked earlier whose list is missing (it failed, or was never fetched) are fetched now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(ipDbProvider).db != null) return;
      for (final c in ref.read(settingsProvider).bypassCountries) {
        ref.read(countryZonesProvider.notifier).ensure(c);
      }
    });
  }

  void _toggle(String code, bool on, {required bool hasDb}) {
    ref.read(settingsProvider.notifier).update((s) {
      final next = [...s.bypassCountries]..remove(code);
      if (on) next.add(code);
      return s.copyWith(bypassCountries: next);
    });
    if (on && !hasDb) ref.read(countryZonesProvider.notifier).ensure(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chosen = ref.watch(settingsProvider.select((s) => s.bypassCountries));
    final counts = ref.watch(countryRangeCountsProvider);
    final zones = ref.watch(countryZonesProvider);
    final hasDb = ref.watch(ipDbProvider.select((s) => s.db != null));
    // Where the selected server is: sending that country around the VPN sends the server's own traffic too.
    final server = ref.watch(selectedProfileProvider);
    final serverCountry = server == null ? null : ref.watch(profileCountryProvider)(server);

    final q = _query.trim().toLowerCase();
    final shown = [
      for (final code in countryNames.keys)
        if (!hasDb || (counts[code] ?? 0) > 0 || chosen.contains(code))
          if (q.isEmpty ||
              code.toLowerCase() == q ||
              context.countryName(code).toLowerCase().contains(q) ||
              (countryNames[code] ?? '').toLowerCase().contains(q))
            code,
    ]..sort((a, b) {
        // Chosen ones first, then by name in the app's language.
        final ca = chosen.contains(a), cb = chosen.contains(b);
        if (ca != cb) return ca ? -1 : 1;
        return context.countryName(a).compareTo(context.countryName(b));
      });

    String? status(String code) {
      if (hasDb) {
        final n = counts[code];
        return n == null ? null : l.bypassRanges(n);
      }
      final z = zones[code];
      if (z == null) return null;
      return switch (z.status) {
        ZoneStatus.loading => l.bypassCountriesDownloading,
        ZoneStatus.ready => l.bypassRanges(z.lines.length),
        ZoneStatus.failed => l.bypassCountriesFailed,
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.bypassCountriesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.bypassCountriesIntro)),
              ),
              if (!hasDb)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  // A notice, not an error: a quiet card the width of the page.
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      color: scheme.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.bypassCountriesZoneIntro)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).push(MaterialPageRoute<void>(builder: (_) => const IpDbScreen())),
                              child: Text(l.bypassCountriesGetDb),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.bypassCountriesSearch),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: withBottomInset(context, const EdgeInsets.only(bottom: 16)),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final code = shown[i];
                    final on = chosen.contains(code);
                    final z = zones[code];
                    final failed = !hasDb && z?.status == ZoneStatus.failed;
                    final text = status(code);
                    final here = on && code == serverCountry;
                    return ListTile(
                      leading: CountryFlag(code),
                      title: Text(context.countryName(code), overflow: TextOverflow.ellipsis),
                      subtitle: (text == null && !here)
                          ? null
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (text != null)
                                  Text(text, style: failed ? TextStyle(color: scheme.error) : null),
                                if (here) Text(l.bypassCountriesYourServer, style: TextStyle(color: scheme.tertiary)),
                              ],
                            ),
                      trailing: !hasDb && z?.status == ZoneStatus.loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Checkbox(value: on, onChanged: (v) => _toggle(code, v ?? false, hasDb: hasDb)),
                      // A ticked country whose list failed is tried again by tapping it.
                      onTap: () => failed && on
                          ? ref.read(countryZonesProvider.notifier).ensure(code)
                          : _toggle(code, !on, hasDb: hasDb),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
