import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/data/repository.dart';

void main() {
  group('Receipt Number Sequencing Parsing Logic', () {
    String computeNext(String reference) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(reference.trim());
      if (match == null) return '#000001';
      final prefix = match.group(1) ?? '#';
      final digitsStr = match.group(2)!;
      final padLength = digitsStr.length;
      final currentNum = int.tryParse(digitsStr) ?? 0;
      final nextNum = currentNum + 1;
      return '$prefix${nextNum.toString().padLeft(padLength, '0')}';
    }

    test('#14000 continues to #14001', () {
      expect(computeNext('#14000'), '#14001');
      expect(computeNext('#14001'), '#14002');
    });

    test('#02000 continues to #02001 preserving leading zero and length', () {
      expect(computeNext('#02000'), '#02001');
      expect(computeNext('#02001'), '#02002');
    });

    test('#000004 continues to #000005', () {
      expect(computeNext('#000004'), '#000005');
    });

    test('custom prefixes continue correctly', () {
      expect(computeNext('REC-100'), 'REC-101');
      expect(computeNext('14000'), '14001');
    });
  });
}
