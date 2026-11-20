import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardkeep/engine/engine.dart';
import 'package:wardkeep/engine/mock_engine.dart';
import 'package:wardkeep/l10n/app_localizations_en.dart';
import 'package:wardkeep/l10n/app_localizations_fa.dart';
import 'package:wardkeep/l10n/errors.dart';
import 'package:wardkeep/l10n/form_text.dart';
import 'package:wardkeep/l10n/l10n.dart';
import 'package:wardkeep/state/providers.dart';
import 'package:wardkeep/state/store.dart';
import 'package:wardkeep/ui/screens/import_screen.dart';
import 'package:wardkeep/ui/screens/subscription_screen.dart';
import 'package:wardkeep/ui/theme.dart';

const _phone = Size(360, 640);
const _desktop = Size(1280, 800);

/// Opens the import page from a button, at [size], [scale] and in [locale]. Returns the store, to look at what
/// was saved.
Future<AppStore> _open(WidgetTester tester, {Size size = _phone, double scale = 1, Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final store = AppStore.memory({'onboarded': true, 'profiles': <Object>[]});
  await tester.pumpWidget(ProviderScope(
    overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero))],
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => showImport(context), child: const Text('open'))),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return store;
}

/// Answers the app's clipboard reads with [text].
void _clipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return text == null ? null : <String, dynamic>{'text': text};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

FilledButton _importButton(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'));

void main() {
  // The phone is Android (five cards, the QR scanner among them), the desktop Windows (four, no scanner).
  for (final (name, size, platform) in [
    ('360 px phone', _phone, TargetPlatform.android),
    ('wide desktop', _desktop, TargetPlatform.windows),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final locale in const [Locale('en'), Locale('fa')]) {
        testWidgets('on a $name at text scale $scale in ${locale.languageCode}: nothing overflows, every way in is there', (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          await _open(tester, size: size, scale: scale, locale: locale);
          expect(tester.takeException(), isNull);
          for (final key in ['importPaste', 'importOpenFile', 'importSubscription', 'importTor']) {
            expect(find.byKey(Key(key)), findsOneWidget, reason: key);
          }
          expect(find.byKey(const Key('importScanQr')), platform == TargetPlatform.android ? findsOneWidget : findsNothing);
          // The page scrolls to its end (the formats, opened) without overflowing.
          final formats = find.byKey(const Key('importFormats'));
          await tester.scrollUntilVisible(formats, 100, scrollable: find.byType(Scrollable).first);
          await tester.tap(find.descendant(of: formats, matching: find.byType(ListTile)));
          await tester.pumpAndSettle();
          expect(find.text('rvpn://'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // The pinned Import button is on screen.
          final button = tester.getRect(find.byType(FilledButton).last);
          expect(button.bottom <= size.height && button.top >= 0, isTrue, reason: '$button');
          await tester.pumpWidget(const SizedBox());
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }

  testWidgets('on a wide window the methods and the text field stand side by side, mirrored in Persian', (tester) async {
    await _open(tester, size: _desktop);
    var card = tester.getRect(find.byKey(const Key('importPaste')));
    var field = tester.getRect(find.byKey(const Key('importText')));
    expect(field.left >= card.right, isTrue, reason: 'card $card, field $field');
    expect(field.top, lessThan(card.bottom), reason: 'beside, not under');

    await tester.pumpWidget(const SizedBox());
    await _open(tester, size: _desktop, locale: const Locale('fa'));
    card = tester.getRect(find.byKey(const Key('importPaste')));
    field = tester.getRect(find.byKey(const Key('importText')));
    expect(field.right <= card.left, isTrue, reason: 'right to left: card $card, field $field');
  });

  testWidgets('on a phone the text field is under the methods', (tester) async {
    await _open(tester);
    final card = tester.getRect(find.byKey(const Key('importTor')));
    final field = tester.getRect(find.byKey(const Key('importText')));
    expect(field.top >= card.bottom, isTrue);
  });

  testWidgets('Import is enabled only when there is text; the clear button empties the field', (tester) async {
    await _open(tester);
    expect(_importButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('importText')), '   ');
    await tester.pump();
    expect(_importButton(tester).onPressed, isNull, reason: 'blanks are not text');
    await tester.enterText(find.byKey(const Key('importText')), 'vless://x');
    await tester.pump();
    expect(_importButton(tester).onPressed, isNotNull);
    await tester.ensureVisible(find.byTooltip('Clear'));
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('importText'))).controller!.text, isEmpty);
    expect(_importButton(tester).onPressed, isNull);
  });

  testWidgets('Paste from clipboard fills the field and imports at once', (tester) async {
    final store = await _open(tester);
    _clipboard(tester, 'vless://id@a.example.com:443#Pasted');
    await tester.tap(find.byKey(const Key('importPaste')));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsNothing, reason: 'a full success closes the page');
    expect(find.text('Imported 1 profile'), findsOneWidget);
    expect((store.read<List<Object?>>('profiles') ?? const []).length, 1);
  });

  testWidgets('Paste with nothing on the clipboard says so and imports nothing', (tester) async {
    await _open(tester);
    _clipboard(tester, null);
    await tester.tap(find.byKey(const Key('importPaste')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('importMessage'))).data, 'The clipboard has no text in it.');
    expect(find.byType(ImportScreen), findsOneWidget);
  });

  testWidgets('a subscription URL opens the subscription form instead of being imported', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('importText')), 'https://sub.example.com/list');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsNothing);
    expect(tester.widget<SubscriptionScreen>(find.byType(SubscriptionScreen)).initialUrl, 'https://sub.example.com/list');
  });

  testWidgets('the Tor card offers the three kinds and adds the one picked', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.byKey(const Key('importTor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importTor')));
    await tester.pumpAndSettle();
    expect(find.text('Tor (direct)'), findsOneWidget);
    expect(find.text('Tor + obfs4 bridges'), findsOneWidget);
    await tester.tap(find.text('Tor + Snowflake bridge'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsNothing);
    expect(find.text('Imported 1 profile'), findsOneWidget);
  });

  group('rVPN', () {
    final en = AppLocalizationsEn();
    final fa = AppLocalizationsFa();

    test('the badge says rVPN', () {
      expect(protocolBadge('rvpn'), 'rVPN');
    });

    test('a server key without the address is explained, in every curated language', () {
      final e = EngineException('IMPORT_RVPN_NEEDS_SERVER', 'english');
      expect(describeError(en, e), allOf(contains('prekey-bundle.json'), contains('rvpn://'), contains('rvpn.txt')));
      expect(describeError(fa, e), allOf(isNot('english'), contains('rvpn://')));
    });

    test('the engine\'s rVPN failures have their own words and stand alone', () {
      for (final code in ['RVPN_MISSING', 'RVPN_HANDSHAKE', 'RVPN_UPGRADE', 'RVPN_EXITED', 'RVPN_DESKTOP_TUN']) {
        expect(errorCodeText(en, code), isNotNull, reason: code);
        expect(errorCodeText(fa, code), allOf(isNotNull, isNot(errorCodeText(en, code))), reason: code);
        final state = EngineState(error: 'english', errorCode: code, progress: const ConnectProgress('handshake', 50));
        expect(localizedError(en, state), errorCodeText(en, code), reason: '$code names no stage');
      }
      expect(errorCodeText(en, 'RVPN_MISSING'), contains('wardkeep-rvpn'));
    });

    test('the rVPN warning and editor texts are translated', () {
      const w = WarningSpec(code: 'RVPN_TCP_ONLY', text: 'english');
      expect(warningText(en, w), startsWith('TCP only'));
      expect(warningText(fa, w), isNot('english'));
      for (final label in ['Server key (prekey-bundle.json)', 'Fallback servers']) {
        expect(formLabel(en, label), label);
        expect(formLabel(fa, label), isNot(label));
      }
      for (final help in [
        "The server's secret WebSocket path, such as /api/v1/ws",
        "The contents of the server's prekey-bundle.json",
        'Other names of the same server, tried in order when the first does not answer',
      ]) {
        expect(formHelp(en, help), help);
        expect(formHelp(fa, help), isNot(help));
      }
    });
  });
}
