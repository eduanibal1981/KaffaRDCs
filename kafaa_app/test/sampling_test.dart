import 'package:flutter_test/flutter_test.dart';
import 'package:kafaa_app/data/repositories/audit_repository.dart';

/// The random sample has to be defensible on review: the same pool and
/// seed must always produce the same selection, and it must never quietly
/// return fewer records than the checklist asks for when the pool allows.
void main() {
  List<String> pool(int n) => [for (var i = 1; i <= n; i++) 'REC-$i'];

  group('Random sampling', () {
    test('draws exactly the requested number', () {
      final result = pickSample(pool(50), 10, 'seed-1');
      expect(result.length, 10);
    });

    test('is reproducible for the same seed', () {
      final a = pickSample(pool(50), 10, 'audit-42');
      final b = pickSample(pool(50), 10, 'audit-42');
      expect(a, equals(b));
    });

    test('differs across seeds', () {
      final a = pickSample(pool(200), 10, 'seed-a');
      final b = pickSample(pool(200), 10, 'seed-b');
      expect(a, isNot(equals(b)));
    });

    test('only ever returns members of the pool', () {
      final source = pool(30);
      final result = pickSample(source, 10, 'seed');
      expect(source, containsAll(result));
    });

    test('never repeats a record', () {
      final result = pickSample(pool(40), 15, 'seed');
      expect(result.toSet().length, result.length);
    });

    test('returns the whole pool when it is smaller than the sample', () {
      final result = pickSample(pool(6), 10, 'seed');
      expect(result.length, 6);
    });

    test('de-duplicates and trims a pasted list', () {
      final result = pickSample(
        [' REC-1 ', 'REC-1', 'REC-2', '', '  ', 'REC-3'],
        10,
        'seed',
      );
      expect(result, ['REC-1', 'REC-2', 'REC-3']);
    });

    test('handles an empty pool and a zero size safely', () {
      expect(pickSample(const [], 10, 'seed'), isEmpty);
      expect(pickSample(pool(10), 0, 'seed'), isEmpty);
      expect(pickSample(pool(10), -5, 'seed'), isEmpty);
    });

    test('the default checklist sample of 10 works on a typical roster', () {
      // A centre with 121 registered patients, criterion asking for 10.
      final result = pickSample(pool(121), 10, 'RDC-SEB-2025');
      expect(result.length, 10);
      expect(result.toSet().length, 10);
    });
  });
}
