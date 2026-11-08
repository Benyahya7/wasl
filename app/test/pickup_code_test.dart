import 'package:flutter_test/flutter_test.dart';
import 'package:wasl/core/pickup_code.dart';

void main() {
  group('PickupCode', () {
    test('generates a 4-character code with a letter and a digit', () {
      for (var i = 0; i < 200; i++) {
        final code = PickupCode.generate();
        expect(code.length, 4);
        expect(PickupCode.isValidFormat(code), isTrue);
        expect(code.contains(RegExp(r'[A-Z]')), isTrue);
        expect(code.contains(RegExp(r'[0-9]')), isTrue);
      }
    });

    test('never uses ambiguous characters 0, O, 1, I', () {
      for (var i = 0; i < 500; i++) {
        final code = PickupCode.generate();
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.contains('I'), isFalse);
      }
    });

    test('rejects wrong formats', () {
      expect(PickupCode.isValidFormat(''), isFalse);
      expect(PickupCode.isValidFormat('K7M'), isFalse);
      expect(PickupCode.isValidFormat('K7M22'), isFalse);
      expect(PickupCode.isValidFormat('K0M2'), isFalse); // 0 banned
      expect(PickupCode.isValidFormat('KIM2'), isFalse); // I banned
      expect(PickupCode.isValidFormat('K7M2'), isTrue);
    });

    test('matches case-insensitively', () {
      expect(PickupCode.matches('k7m2', 'K7M2'), isTrue);
      expect(PickupCode.matches(' K7M2 ', 'K7M2'), isTrue);
      expect(PickupCode.matches('K7M3', 'K7M2'), isFalse);
    });

    test('generated codes are not all identical', () {
      final codes = {for (var i = 0; i < 100; i++) PickupCode.generate()};
      expect(codes.length, greaterThan(50));
    });
  });
}
