import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/engine/engine.dart';
import 'package:omnitun/engine/mock_engine.dart';
import 'package:omnitun/state/ipdb.dart';
import 'package:omnitun/state/ipdb_state.dart';
import 'package:omnitun/state/providers.dart';
import 'package:omnitun/state/store.dart';

ProviderContainer _container(Map<String, dynamic> data, List<int> calls) {
  final c = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(AppStore.memory(data)),
      engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
      directLookupProvider.overrideWithValue(() async {
        calls.add(1);
        return const ExitInfo('203.0.113.5', 'IR');
      }),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('where the device is comes from a direct lookup while not connected, and is remembered', () async {
    final calls = <int>[];
    final c = _container({'home_country': 'DE'}, calls);
    expect(c.read(homeProvider)?.country, 'DE'); // the last answer, at once
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    expect(c.read(homeProvider)?.country, 'IR');
    expect(c.read(storeProvider).read<String>('home_country'), 'IR');
  });

  test('nothing is looked up when the user switched address lookups off', () async {
    final calls = <int>[];
    final c = _container({
      'settings': {'show_exit': false},
    }, calls);
    expect(c.read(homeProvider), isNull);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    expect(c.read(homeProvider), isNull);
  });

  _more();
}

class _DbSwitch extends Notifier<IpCountryDb?> {
  @override
  IpCountryDb? build() => null;

  void set(IpCountryDb? db) => state = db;
}

final _dbSwitch = NotifierProvider<_DbSwitch, IpCountryDb?>(_DbSwitch.new);

void _more() {
  test('a country a service got wrong is corrected once the database is loaded', () async {
    final tmp = Directory.systemTemp.createTempSync('home_db');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows keeps a file open a moment longer
      }
    });
    File('${tmp.path}/4.csv').writeAsStringSync('203.0.113.0,203.0.113.255,IR\n');
    File('${tmp.path}/6.csv').writeAsStringSync('');
    await compileIpDb('${tmp.path}/4.csv', '${tmp.path}/6.csv', '${tmp.path}/db.bin');
    final db = IpCountryDb.fromBytes(File('${tmp.path}/db.bin').readAsBytesSync());

    final c = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(AppStore.memory({})),
        engineProvider.overrideWithValue(MockEngine(connectDelay: Duration.zero)),
        // the service says Azerbaijan for an address the registries give to Iran
        directLookupProvider.overrideWithValue(() async => const ExitInfo('203.0.113.5', 'AZ')),
        ipDbActiveProvider.overrideWith((ref) => ref.watch(_dbSwitch)),
      ],
    );
    addTearDown(c.dispose);
    c.read(homeProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(homeProvider)?.country, 'AZ', reason: 'no database yet: the service decides');
    expect(c.read(storeProvider).read<String>('home_country'), 'AZ');

    c.read(_dbSwitch.notifier).set(db);
    expect(c.read(homeProvider)?.country, 'IR', reason: 'the database is there now');
    expect(c.read(storeProvider).read<String>('home_country'), 'IR', reason: 'and that is what is remembered');
  });
}
