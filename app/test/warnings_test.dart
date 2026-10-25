import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/form_text.dart';
import 'package:omnitun/l10n/l10n.dart';
import 'package:omnitun/main.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';

const _protocolWarning = WarningSpec(code: 'VMESS_LEGACY', text: 'english fallback');
const _fieldWarning = WarningSpec(code: 'TLS_INSECURE', text: 'english fallback');
const _info = WarningSpec(code: 'MUX_LOSSY', text: 'english fallback', risk: false);

/// A mock whose Trojan form carries the warnings the core sends for it.
class _WarnEngine extends MockEngine {
  @override
  Future<List<ProtocolFormSpec>> forms() async => const [
    ProtocolFormSpec(
      protocol: 'trojan',
      label: 'Trojan',
      warnings: [_protocolWarning, _info],
      fields: [
        FormFieldSpec(key: 'name', label: 'Name', kind: 'text'),
        FormFieldSpec(key: 'server', label: 'Server', kind: 'text', required: true),
        FormFieldSpec(key: 'password', label: 'Password', kind: 'secret', required: true),
        FormFieldSpec(key: 'tls.insecure', label: 'Skip certificate check', kind: 'bool', advanced: true, warning: _fieldWarning),
      ],
    ),
  ];

  @override
  Future<List<WarningSpec>> warnings(ProfileInfo profile) async => const [_fieldWarning];
}

Future<ProviderContainer> _start(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(_WarnEngine())],
      child: const OmnitunApp(),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(OmnitunApp)));
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Location'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Add servers'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add a server by hand'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the picker and the editor tell what is wrong with a protocol, and a setting warns only while on', (tester) async {
    await _start(
      tester,
      AppStore.memory({
        'profiles': [
          {'id': 'x', 'name': 'Old', 'protocol': 'trojan', 'server': 'old.example.com', 'port': 443},
        ],
      }),
    );
    await _openPicker(tester);

    // The picker shows the first warning under the protocol, in the app's language.
    expect(find.textContaining('VMess is an older protocol'), findsOneWidget);

    await tester.tap(find.text('Trojan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warning-VMESS_LEGACY')), findsOneWidget);
    expect(find.byKey(const Key('warning-MUX_LOSSY')), findsOneWidget);
    expect(find.byKey(const Key('warning-TLS_INSECURE')), findsNothing);

    // The setting is under "More options"; switching it on shows its warning, off hides it again.
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warning-TLS_INSECURE')), findsOneWidget);
    expect(find.textContaining('certificate is not checked'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warning-TLS_INSECURE')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the share screen shows the warnings of the saved profile', (tester) async {
    final store = AppStore.memory({
      'profiles': [
        {'id': 'x', 'name': 'Old', 'protocol': 'trojan', 'server': 'old.example.com', 'port': 443, 'password': 'pw'},
      ],
    });
    await _start(tester, store);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show servers').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share link or QR'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warning-TLS_INSECURE')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every warning code the core knows has a translated text', (tester) async {
    final l = await _lookup(tester);
    for (final code in const [
      'TLS_INSECURE', 'NO_TLS', 'VMESS_LEGACY', 'SS_PLAIN', 'HYSTERIA1', 'DPI_VISIBLE', 'SSH_VISIBLE', 'DNSTT_SLOW',
      'DNSTT_OPEN', 'MUX_LOSSY', 'FRAGMENT_SIDE', 'ECH_SERVER', 'WG_CHAIN', 'SUB_UNSIGNED',
    ]) {
      final text = warningText(l, WarningSpec(code: code, text: 'fallback'));
      expect(text, isNot('fallback'), reason: code);
      expect(text, isNotEmpty, reason: code);
    }
    // A code from a newer core falls back to the core's own text.
    expect(warningText(l, const WarningSpec(code: 'FUTURE_CODE', text: 'fallback')), 'fallback');
  });
}

Future<AppLocalizations> _lookup(WidgetTester tester) async {
  late AppLocalizations l;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return l;
}
