import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/bypass_countries.dart';
import '../../state/countries.dart';
import '../../state/ipdb_state.dart';
import '../../state/providers.dart';
import '../insets.dart';
import '../widgets/country_flag.dart';
import 'ipdb_screen.dart';

/// Chooses the countries whose address ranges go around the VPN. The ranges come from the offline
/// country database, so without it the screen offers to get it instead.
class BypassCountriesScreen extends ConsumerStatefulWidget {
  const BypassCountriesScreen({super.key});

  @override
  ConsumerState<BypassCountriesScreen> createState() => _BypassCountriesScreenState();
}

class _BypassCountriesScreenState extends ConsumerState<BypassCountriesScreen> {
  String _query = '';

  void _toggle(String code, bool on) {
    ref.read(settingsProvider.notifier).update((s) {
      final next = [...s.bypassCountries]..remove(code);
      if (on) next.add(code);
      return s.copyWith(bypassCountries: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chosen = ref.watch(settingsProvider.select((s) => s.bypassCountries));
    final counts = ref.watch(countryRangeCountsProvider);
    final hasDb = ref.watch(ipDbProvider.select((s) => s.db != null));

    final q = _query.trim().toLowerCase();
    final shown = [
      for (final code in countryNames.keys)
        if (hasDb ? (counts[code] ?? 0) > 0 || chosen.contains(code) : chosen.contains(code))
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
                                Expanded(child: Text(l.bypassCountriesNeedDb)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
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
              if (hasDb)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l.bypassCountriesSearch,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: withBottomInset(context, const EdgeInsets.only(bottom: 16)),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final code = shown[i];
                    final on = chosen.contains(code);
                    final n = counts[code];
                    return CheckboxListTile(
                      value: on,
                      onChanged: (v) => _toggle(code, v ?? false),
                      secondary: CountryFlag(code),
                      title: Text(context.countryName(code), overflow: TextOverflow.ellipsis),
                      subtitle: n == null ? null : Text(l.bypassRanges(n)),
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
