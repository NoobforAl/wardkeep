import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/l10n/app_localizations.dart';
import 'package:omnitun/state/groups.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';
import 'package:omnitun/ui/screens/profiles_screen.dart';
import 'package:omnitun/ui/theme.dart';

Map<String, dynamic> _trojan(String id, String name, {String group = 'default'}) =>
    {'id': id, 'name': name, 'protocol': 'trojan', 'server': '$id.example.com', 'port': 443, 'password': 'pw', 'group': group};

ProviderContainer _container(Map<String, dynamic> data) {
  final c = ProviderContainer(overrides: [
    storeProvider.overrideWithValue(AppStore.memory(data)),
    engineProvider.overrideWithValue(MockEngine()),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<ProviderContainer> _open(WidgetTester tester, Map<String, dynamic> data) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = MockEngine();
  await tester.pumpWidget(ProviderScope(
    overrides: [storeProvider.overrideWithValue(AppStore.memory(data)), engineProvider.overrideWithValue(engine)],
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ProfilesScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ProfilesScreen)));
}

void main() {
  group('a group file', () {
    test('starts with the group name and carries one link a line', () {
      final text = groupFileText('Work servers', ['trojan://a@h:1#A', 'tor://snowflake']);
      expect(text, '# Wardkeep group: Work servers\ntrojan://a@h:1#A\ntor://snowflake\n');
      expect(groupNameInText(text), 'Work servers');
    });

    test('is recognised whatever the line ends or byte order mark', () {
      expect(groupNameInText('\u{feff}# Wardkeep group: Mine\r\ntrojan://x'), 'Mine');
      expect(groupNameInText('\n\n  # Wardkeep group:   Spaced out  \nx'), 'Spaced out');
    });

    test('is not mistaken for another text', () {
      expect(groupNameInText('trojan://x@h:1#A'), isNull);
      expect(groupNameInText('# some other comment\ntrojan://x'), isNull);
      expect(groupNameInText('# Wardkeep group:   \ntrojan://x'), isNull);
      expect(groupNameInText('trojan://x\n# Wardkeep group: late'), isNull);
    });

    test('a name with line breaks cannot add lines of its own', () {
      final text = groupFileText('a\nb', ['x']);
      expect(text.split('\n').first, '# Wardkeep group: a b');
    });

    test('is saved under a file name that is safe to write', () {
      expect(groupFileName('Work'), 'Work.txt');
      expect(groupFileName('a/b\\c:d*e?'), 'a_b_c_d_e_.txt');
      expect(groupFileName('  '), 'group.txt');
    });
  });

  group('the groups of the user', () {
    test('a server moves into a group and back, and a deleted group gives its servers back', () {
      final c = _container({
        'profiles': [_trojan('a', 'A'), _trojan('b', 'B'), _trojan('c', 'C')],
      });
      final g = c.read(groupsProvider.notifier).create('Friends');
      c.read(profilesProvider.notifier).moveTo('b', g.id);
      expect(c.read(profilesProvider).firstWhere((p) => p.id == 'b').group, g.id);
      expect(c.read(profilesProvider).where((p) => p.group == ProfileInfo.defaultGroup).map((p) => p.id), ['a', 'c']);

      c.read(profilesProvider.notifier).moveTo('b', ProfileInfo.defaultGroup);
      expect(c.read(profilesProvider).every((p) => p.group == ProfileInfo.defaultGroup), isTrue);

      c.read(profilesProvider.notifier).moveTo('a', g.id);
      c.read(groupsProvider.notifier).remove(g.id);
      expect(c.read(groupsProvider), isEmpty);
      expect(c.read(profilesProvider).map((p) => p.id), containsAll(['a', 'b', 'c']));
      expect(c.read(profilesProvider).every((p) => p.group == ProfileInfo.defaultGroup), isTrue);
    });

    test('moving a server into a group and out again leaves the order of the list as it was', () {
      final c = _container({
        'profiles': [_trojan('a', 'A'), _trojan('b', 'B'), _trojan('c', 'C'), _trojan('d', 'D')],
      });
      final g = c.read(groupsProvider.notifier).create('Friends');
      c.read(profilesProvider.notifier).moveTo('b', g.id);
      expect(c.read(profilesProvider).map((p) => p.id), ['a', 'b', 'c', 'd']);
      c.read(groupsProvider.notifier).remove(g.id);
      expect(c.read(profilesProvider).map((p) => p.id), ['a', 'b', 'c', 'd']);
    });

    test('a name is not made twice, and groups are kept between runs', () {
      final data = <String, dynamic>{};
      final store = AppStore.memory(data);
      ProviderContainer make() => ProviderContainer(overrides: [storeProvider.overrideWithValue(store), engineProvider.overrideWithValue(MockEngine())]);
      final c = make();
      addTearDown(c.dispose);
      final a = c.read(groupsProvider.notifier).create('  Friends ');
      final b = c.read(groupsProvider.notifier).create('friends');
      expect(b.id, a.id);
      expect(c.read(groupsProvider), hasLength(1));
      c.read(groupsProvider.notifier).rename(a.id, 'Family');

      final again = make();
      addTearDown(again.dispose);
      expect(again.read(groupsProvider).map((g) => g.name), ['Family']);
    });

    test('a server added to a group stays in it when a subscription refreshes', () {
      final c = _container({
        'profiles': [_trojan('a', 'A', group: 'sub1'), _trojan('b', 'B', group: 'sub1')],
      });
      final g = c.read(groupsProvider.notifier).create('Keep');
      c.read(profilesProvider.notifier).moveTo('a', g.id);
      c.read(profilesProvider.notifier).replaceGroup('sub1', [
        ProfileInfo.fromJson(_trojan('a', 'A')),
        ProfileInfo.fromJson(_trojan('b', 'B')),
        ProfileInfo.fromJson(_trojan('c', 'C')),
      ]);
      final byId = {for (final p in c.read(profilesProvider)) p.id: p.group};
      expect(byId, {'a': g.id, 'b': 'sub1', 'c': 'sub1'});
    });

    test('an import of a group file lands in a group of that name, a plain import does not', () {
      final c = _container({});
      final fromFile = [ProfileInfo.fromJson(_trojan('a', 'A')), ProfileInfo.fromJson(_trojan('b', 'B'))];
      final placed = c.read(groupsProvider.notifier).place('# Wardkeep group: Shared\ntrojan://x', fromFile);
      final g = c.read(groupsProvider).single;
      expect(g.name, 'Shared');
      expect(placed.map((p) => p.group), [g.id, g.id]);

      // The same file again goes to the same group.
      c.read(groupsProvider.notifier).place('# Wardkeep group: shared\ntrojan://x', fromFile);
      expect(c.read(groupsProvider), hasLength(1));

      final plain = c.read(groupsProvider.notifier).place('trojan://x', fromFile);
      expect(plain.map((p) => p.group), [ProfileInfo.defaultGroup, ProfileInfo.defaultGroup]);
    });
  });

  group('the groups on the servers screen', () {
    testWidgets('shows a group with its servers, and its menu copies the links as a group file', (tester) async {
      final clip = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final c = await _open(tester, {
        'onboarded': true,
        'groups': [
          {'id': 'g1', 'name': 'Friends'},
          {'id': 'g2', 'name': 'Empty one'},
        ],
        'profiles': [_trojan('a', 'Alpha'), _trojan('b', 'Bravo', group: 'g1')],
      });
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Empty one'), findsOneWidget);
      expect(find.textContaining('Move to group'), findsOneWidget); // the hint of the empty group

      // The group's menu: copy its links.
      await tester.tap(find.descendant(of: find.ancestor(of: find.text('Friends'), matching: find.byType(Row)).first, matching: find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy links'));
      await tester.pumpAndSettle();
      expect(clip, hasLength(1));
      expect(clip.single, startsWith('# Wardkeep group: Friends\ntrojan://'));
      expect(clip.single, contains('#Bravo'));
      expect(clip.single, isNot(contains('Alpha')));
      expect(c.read(profilesProvider), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a server is moved into a group from its menu, and the group can be made on the way', (tester) async {
      final c = await _open(tester, {
        'onboarded': true,
        'groups': [
          {'id': 'g1', 'name': 'Friends'},
        ],
        'profiles': [_trojan('a', 'Alpha')],
      });
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Alpha'), matching: find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friends').last);
      await tester.pumpAndSettle();
      expect(c.read(profilesProvider).single.group, 'g1');

      // Into a new group.
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Alpha'), matching: find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Brand new');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final created = c.read(groupsProvider).firstWhere((g) => g.name == 'Brand new');
      expect(c.read(profilesProvider).single.group, created.id);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
