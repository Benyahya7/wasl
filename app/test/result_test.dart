import 'package:flutter_test/flutter_test.dart';
import 'package:wasl/core/result.dart';

void main() {
  group('Result', () {
    test('Ok folds to the value branch', () {
      const r = Ok<int>(42);
      expect(r.fold((v) => 'ok $v', (m) => 'err $m'), 'ok 42');
    });

    test('Err folds to the message branch', () {
      const r = Err<int>('network down');
      expect(r.fold((v) => 'ok $v', (m) => 'err $m'), 'err network down');
    });

    test('guard converts a throw into a readable Err', () async {
      final r = await guard<int>(() async {
        throw Exception('boom');
      });
      expect(r, isA<Err<int>>());
      expect(r.fold((_) => '', (m) => m), contains('boom'));
    });

    test('guard passes a success through as Ok', () async {
      final r = await guard<int>(() async => 7);
      expect(r, isA<Ok<int>>());
      expect(r.fold((v) => v, (_) => -1), 7);
    });
  });
}
