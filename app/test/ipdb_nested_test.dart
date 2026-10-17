import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitun/state/ipdb.dart';

/// The registries list a small allocation inside a bigger one (about 2 % of the ranges of the real data):
/// the database keeps the most specific range for every address.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ipdb_nested'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps a file open a moment longer
    }
  });

  Future<IpCountryDb> compile(String v4, String v6) async {
    File('${tmp.path}/n4.csv').writeAsStringSync(v4);
    File('${tmp.path}/n6.csv').writeAsStringSync(v6);
    await compileIpDb('${tmp.path}/n4.csv', '${tmp.path}/n6.csv', '${tmp.path}/n.bin');
    return IpCountryDb.fromBytes(File('${tmp.path}/n.bin').readAsBytesSync());
  }

  test('the most specific range decides, and the bigger one carries on after it', () async {
    // 10/8 is AA, 10.1/16 inside it is BB, and 10.1.5/24 inside that is CC.
    final db = await compile(
      '10.0.0.0,10.255.255.255,AA\n10.1.0.0,10.1.255.255,BB\n10.1.5.0,10.1.5.255,CC\n11.0.0.0,11.0.0.255,DD\n',
      '2001:db8::,2001:db8:ffff:ffff:ffff:ffff:ffff:ffff,AA\n2001:db8:1::,2001:db8:1:ffff:ffff:ffff:ffff:ffff,BB\n',
    );
    expect(db.lookup('10.0.0.1'), 'AA');
    expect(db.lookup('10.1.0.0'), 'BB');
    expect(db.lookup('10.1.4.255'), 'BB');
    expect(db.lookup('10.1.5.0'), 'CC');
    expect(db.lookup('10.1.5.255'), 'CC');
    expect(db.lookup('10.1.6.0'), 'BB', reason: 'after the innermost range the one around it carries on');
    expect(db.lookup('10.1.255.255'), 'BB');
    expect(db.lookup('10.2.0.0'), 'AA', reason: 'and after that the outermost');
    expect(db.lookup('10.255.255.255'), 'AA');
    expect(db.lookup('11.0.0.5'), 'DD');
    expect(db.lookup('9.255.255.255'), isNull);
    expect(db.lookup('12.0.0.0'), isNull);
    expect(db.lookup('2001:db8::1'), 'AA');
    expect(db.lookup('2001:db8:1::5'), 'BB');
    expect(db.lookup('2001:db8:2::5'), 'AA');
    // A country's blocks leave out what lies inside it but belongs to another country.
    final aa = db.cidrsOf('AA');
    expect(aa, isNot(contains('10.0.0.0/8')));
    expect(aa, containsAll(['10.0.0.0/16', '10.2.0.0/15', '10.128.0.0/9']));
    expect(db.cidrsOf('BB'), containsAll(['10.1.0.0/22', '10.1.4.0/24', '10.1.6.0/23']));
    expect(db.cidrsOf('CC'), ['10.1.5.0/24']);
  });

  test('ranges that only partly overlap, the same range twice and a file out of order are handled', () async {
    final db = await compile('20.0.0.50,20.0.0.99,BB\n20.0.0.0,20.0.0.60,AA\n30.0.0.0,30.0.0.9,CC\n30.0.0.0,30.0.0.9,DD\n', '');
    // AA 0-60 and BB 50-99 overlap on 50-60: the one that starts later (BB) takes the overlap.
    expect(db.lookup('20.0.0.49'), 'AA');
    expect(db.lookup('20.0.0.50'), 'BB');
    expect(db.lookup('20.0.0.60'), 'BB');
    expect(db.lookup('20.0.0.99'), 'BB');
    expect(db.lookup('20.0.0.100'), isNull);
    expect(db.lookup('30.0.0.5'), isNotNull, reason: 'one of the two answers, not nothing');
  });

  test('over a big shuffled sample the answer is always the most specific range that covers the address', () async {
    final rng = Random(7);
    // 300 ranges with different starts, any size (so they nest and overlap), in a random order.
    final starts = (List<int>.generate(4000, (i) => i)..shuffle(rng)).take(300).toList();
    final ranges = [for (final a in starts) (a, a + rng.nextInt(400), 'A${rng.nextInt(6)}')];
    String ip(int n) => '100.64.${n >> 8 & 255}.${n & 255}';
    final db = await compile('${ranges.map((r) => '${ip(r.$1)},${ip(r.$2)},${r.$3}').join('\n')}\n', '');
    var covered = 0;
    for (var n = 0; n < 4500; n++) {
      // the most specific range: the one that starts last (the starts are all different)
      (int, int, String)? best;
      for (final r in ranges) {
        if (r.$1 <= n && n <= r.$2 && (best == null || r.$1 > best.$1)) best = r;
      }
      expect(db.lookup(ip(n)), best?.$3, reason: 'address $n');
      if (best != null) covered++;
    }
    expect(covered, greaterThan(2000));
  });
}
