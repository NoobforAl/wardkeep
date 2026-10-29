import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/l10n/app_localizations_en.dart';
import 'package:omnitun/l10n/errors.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/import_file.dart';
import 'package:omnitun/ui/incoming_import.dart';
import 'package:omnitun/ui/screens/profiles_screen.dart';
import 'package:omnitun/ui/widgets/notice.dart';
import 'package:omnitun/ui/theme.dart';

/// An engine whose import says what the test wants.
class _Engine extends MockEngine {
  _Engine(this.answer) : super(connectDelay: Duration.zero);

  final Future<ImportResult> Function(String text) answer;

  @override
  Future<ImportResult> importText(String text) => answer(text);
}

void main() {
  final l = AppLocalizationsEn();

  group('reading a config file', () {
    test('plain text, UTF-8 with a byte order mark, and UTF-16 either way round', () {
      expect(decodeImportFile(utf8.encode('{"a": "سلام"}')), '{"a": "سلام"}');
      expect(decodeImportFile([0xEF, 0xBB, 0xBF, ...utf8.encode('vless://x')]), 'vless://x');
      const text = '{"a": "é — 😀"}';
      final units = text.codeUnits;
      final le = [0xFF, 0xFE, for (final u in units) ...[u & 0xFF, u >> 8]];
      final be = [0xFE, 0xFF, for (final u in units) ...[u >> 8, u & 0xFF]];
      expect(decodeImportFile(le), text);
      expect(decodeImportFile(be), text);
    });

    test('an empty file, a blank one, a binary one and one in another encoding are refused, each for its own reason', () {
      ImportFileProblem problem(List<int> bytes) {
        try {
          decodeImportFile(bytes);
        } on ImportFileException catch (e) {
          return e.problem;
        }
        fail('read ${bytes.length} bytes');
      }

      expect(problem(const []), ImportFileProblem.empty);
      expect(problem(utf8.encode(' \r\n\t ')), ImportFileProblem.empty);
      expect(problem([0xEF, 0xBB, 0xBF]), ImportFileProblem.empty);
      expect(problem(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D]), ImportFileProblem.notText, reason: 'a PNG');
      expect(problem(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0])), ImportFileProblem.notText, reason: 'a ZIP');
      expect(problem(const [0x76, 0x6C, 0xE9, 0x73, 0x73]), ImportFileProblem.notText, reason: 'Latin-1 text is not valid UTF-8');
      expect(problem(List.filled(importMaxBytes + 1, 65)), ImportFileProblem.tooLarge);
    });

    test('every reason is worded for the user, and an unknown error is still explained', () {
      expect(describeFileProblem(l, const ImportFileException(ImportFileProblem.empty)), l.importFileEmpty);
      expect(describeFileProblem(l, const ImportFileException(ImportFileProblem.tooLarge)), contains('8 MB'));
      expect(describeFileProblem(l, const ImportFileException(ImportFileProblem.notText)), l.importFileNotText);
      expect(describeFileProblem(l, const PathAccessException('/x', OSError('denied', 13))), l.importFileNoPermission);
      expect(describeFileProblem(l, const PathNotFoundException('/x', OSError('gone', 2))), l.importFileMissing);
      expect(describeFileProblem(l, const FileSystemException('read failed', '/x', OSError('Access is denied', 5))), l.importFileNoPermission);
      expect(describeFileProblem(l, StateError('disk on fire')), allOf(startsWith('Could not read the file'), contains('disk on fire')));
    });
  });

  group('the core\'s JSON failures, in words', () {
    String say(String code, Map<String, String> args) => describeError(l, EngineException(code, 'english', args));

    test('a syntax error names the line, the column and the character', () {
      expect(
        say('IMPORT_JSON_SYNTAX', {'line': '3', 'column': '26', 'found': "'x'"}),
        "This is not valid JSON: unexpected 'x' at line 3, column 26.",
      );
    });

    test('a cut-off text, a JSON without servers and a text that is too large', () {
      expect(say('IMPORT_JSON_END', {'line': '9', 'column': '1'}), allOf(contains('line 9, column 1'), contains('too early')));
      expect(say('IMPORT_JSON_NO_SERVER', {'found': ''}), isNot(contains('holds')));
      expect(say('IMPORT_JSON_NO_SERVER', {'found': 'outbounds: direct'}), contains('it holds outbounds: direct'));
      expect(say('IMPORT_TOO_LARGE', {'limit': '8'}), contains('8 MB'));
    });
  });

  testWidgets('a file another app sent that cannot be read is a red notification that says why', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox()),
    ));
    for (final (code, words) in [
      ('empty', 'The file is empty.'),
      ('not_text', 'not text that Wardkeep can read'),
      ('denied', 'not allowed to read'),
      ('too_large', 'limit is 8 MB'),
      ('missing', 'was not found'),
    ]) {
      await importSharedProblem(navigator, code);
      await tester.pump();
      expect(find.textContaining(words), findsOneWidget, reason: code);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(bar.backgroundColor, theme.noticeBackground(NoticeTone.error), reason: code);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();
    }
  });

  group('the import sheet', () {
    Future<void> open(WidgetTester tester, Future<ImportResult> Function(String) answer) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore.memory({'onboarded': true, 'profiles': <Object>[]});
      await tester.pumpWidget(ProviderScope(
        overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(_Engine(answer))],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(child: TextButton(onPressed: () => showImportSheet(context, ref), child: const Text('open'))),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> importText(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).last, text);
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();
    }

    String message(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('importMessage'))).data!;

    /// The notice's own box (its edge and its fill) round the message.
    BoxDecoration box(WidgetTester tester) => tester
        .widget<Container>(find.ancestor(of: find.byKey(const Key('importMessage')), matching: find.byType(Container)).first)
        .decoration! as BoxDecoration;

    ThemeData theme(WidgetTester tester) => Theme.of(tester.element(find.byKey(const Key('importMessage'))));

    testWidgets('says that JSON works, as text or as a file', (tester) async {
      await open(tester, (_) async => const ImportResult([], []));
      expect(find.textContaining('JSON config'), findsOneWidget);
      expect(find.text('Open file'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
    });

    testWidgets('a JSON syntax error is shown with its line and column, in the user\'s words', (tester) async {
      await open(tester, (_) async {
        final failure = EngineException('IMPORT_JSON_SYNTAX', 'invalid JSON', {'line': '3', 'column': '26', 'found': "'x'"});
        return ImportResult(const [], const ['invalid JSON'], failure: failure);
      });
      await importText(tester, '{"a" x}');
      expect(message(tester), "Nothing imported: This is not valid JSON: unexpected 'x' at line 3, column 26.");
      expect(find.byKey(const Key('importDetails')), findsNothing, reason: 'the English message is not shown twice');
      // a failure is a red notice: red edge, a red-tinted fill, a red icon
      final red = theme(tester).colorScheme.error;
      expect((box(tester).border! as Border).top.color, red.withValues(alpha: 0.65));
      expect(box(tester).color, theme(tester).noticeBackground(NoticeTone.error));
      expect(HSLColor.fromColor(box(tester).color!).hue, closeTo(HSLColor.fromColor(red).hue, 20), reason: 'the fill leans red');
      expect(tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color, red);
      expect(find.text('Import'), findsOneWidget, reason: 'the sheet stays open so the text can be fixed');
    });

    testWidgets('a server that is wrong keeps its reason under the message', (tester) async {
      await open(tester, (_) async {
        final failure = EngineException('IMPORT_NOTHING', 'no valid profiles', {'details': 'bad: missing user id\nworse: no port'});
        return ImportResult(const [], const ['bad: missing user id', 'worse: no port'], failure: failure);
      });
      await importText(tester, '{}');
      expect(message(tester), startsWith('Nothing imported'));
      expect(find.descendant(of: find.byKey(const Key('importDetails')), matching: find.text('bad: missing user id')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('importDetails')), matching: find.text('worse: no port')), findsOneWidget);
    });

    testWidgets('a partial import says how many failed and why', (tester) async {
      await open(tester, (_) async {
        final profile = ProfileInfo(id: 'a', name: 'A', protocol: 'trojan', server: 'a.example.com', port: 443);
        return ImportResult([profile], const ['#2: not a config, an outbound or a link']);
      });
      await importText(tester, '[1, 2]');
      expect(message(tester), 'Imported 1, failed 1');
      expect(find.text('#2: not a config, an outbound or a link'), findsOneWidget);
      expect((box(tester).border! as Border).top.color, connectingAmber.withValues(alpha: 0.65), reason: 'partly worked: amber, not red');
    });

    testWidgets('when the core cannot be asked at all, the sheet says so instead of waiting for ever', (tester) async {
      await open(tester, (_) async => throw StateError('lost connection to the core'));
      await importText(tester, '{}');
      expect(message(tester), allOf(startsWith('Nothing imported'), contains('lost connection to the core')));
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Import')).onPressed, isNotNull, reason: 'it can be tried again');
    });
  });
}
