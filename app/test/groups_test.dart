import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardkeep/engine/engine.dart';
import 'package:wardkeep/engine/mock_engine.dart';
import 'package:wardkeep/l10n/app_localizations.dart';
import 'package:wardkeep/state/groups.dart';
import 'package:wardkeep/state/providers.dart';
import 'package:wardkeep/state/store.dart';
import 'package:wardkeep/ui/screens/profiles_screen.dart';
import 'package:wardkeep/ui/theme.dart';

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
      await tester.tap(find.text('Friends')); // the header opens its sheet
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
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Alpha'), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friends').last);
      await tester.pumpAndSettle();
      expect(c.read(profilesProvider).single.group, 'g1');

      // Into a new group.
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Alpha'), matching: find.byIcon(Icons.more_vert)));
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

  group('picking several servers', () {
    final profiles = [_trojan('a', 'Alpha'), _trojan('b', 'Bravo'), _trojan('c', 'Charlie')];

    testWidgets('holding a row opens its menu', (tester) async {
      await _open(tester, {'onboarded': true, 'profiles': profiles});
      await tester.longPress(find.widgetWithText(ListTile, 'Bravo'));
      await tester.pumpAndSettle();
      expect(find.text('Make default'), findsOneWidget);
      expect(find.text('Move to group'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Select from the menu starts picking; the picked ones are deleted together', (tester) async {
      final c = await _open(tester, {'onboarded': true, 'profiles': profiles});
      await tester.longPress(find.widgetWithText(ListTile, 'Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Charlie')); // a tap ticks while picking
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(c.read(selectedProfileIdProvider), isNot('c')); // and chooses nothing

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect([for (final p in c.read(profilesProvider)) p.name], ['Bravo']);
      expect(find.text('2 selected'), findsNothing); // the mode is over
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('picked servers are grouped in one step, into a new group', (tester) async {
      final c = await _open(tester, {'onboarded': true, 'profiles': profiles});
      await tester.longPress(find.widgetWithText(ListTile, 'Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bravo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Move to group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pair');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final pair = c.read(groupsProvider).firstWhere((g) => g.name == 'Pair');
      final byName = {for (final p in c.read(profilesProvider)) p.name: p.group};
      expect(byName['Alpha'], pair.id);
      expect(byName['Bravo'], pair.id);
      expect(byName['Charlie'], isNot(pair.id));
      expect(find.textContaining('selected'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a server that goes while picking is no longer counted, and the mode ends with the last one', (tester) async {
      final c = await _open(tester, {'onboarded': true, 'profiles': profiles});
      await tester.longPress(find.widgetWithText(ListTile, 'Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bravo'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      c.read(profilesProvider.notifier).remove('b'); // its subscription was deleted, say
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      c.read(profilesProvider.notifier).remove('a');
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Charlie'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Select all, and Back leaves the mode without leaving the screen', (tester) async {
      await _open(tester, {'onboarded': true, 'profiles': profiles});
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.binding.handlePopRoute(); // Back
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Alpha'), findsOneWidget); // still on the screen
      await tester.pumpWidget(const SizedBox());
    });
  });
}
