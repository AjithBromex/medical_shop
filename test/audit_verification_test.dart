import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/core/dates.dart';
import 'package:medical_shop_manager/core/money.dart';
import 'package:medical_shop_manager/data/repository.dart';

void main() {
  group('Security: CSV / Formula Injection Prevention', () {
    test('prepends single quote to cells starting with formula characters in CSV mode', () {
      expect(Report.cell('=1+1', csv: true), "'=1+1");
      expect(Report.cell('+SUM(A1:A10)', csv: true), "'+SUM(A1:A10)");
      expect(Report.cell('-200', csv: true), "'-200");
      expect(Report.cell('@SUM(A1)', csv: true), "'@SUM(A1)");
      expect(Report.cell('|cmd', csv: true), "'|cmd");
      expect(Report.cell('%COMSPEC%', csv: true), "'%COMSPEC%");
    });

    test('escapes formula injection even when preceded by leading whitespace', () {
      expect(Report.cell('   =cmd|/C calc!A0', csv: true), "'   =cmd|/C calc!A0");
      expect(Report.cell(' \t +123', csv: true), "' \t +123");
    });

    test('does not escape benign text or when not in CSV mode', () {
      expect(Report.cell('MedPlus Pharmacy', csv: true), 'MedPlus Pharmacy');
      expect(Report.cell('=1+1', csv: false), '=1+1');
      expect(Report.cell('', csv: true), '');
      expect(Report.cell(null, csv: true), '');
    });
  });

  group('Input Validation: Leading Decimal & Money Parsing', () {
    test('parses leading decimal amounts correctly', () {
      expect(parseAmount('.50', 'Amount'), 50);
      expect(parseAmount('.5', 'Amount'), 50);
      expect(parseAmount('0.50', 'Amount'), 50);
      expect(parseAmount('1250.75', 'Amount'), 125075);
      expect(parseAmount('1000', 'Amount'), 100000);
      expect(parseAmount('₹1,500.25', 'Amount'), 150025);
    });

    test('rejects negative amounts, invalid characters, and excessive precision', () {
      expect(() => parseAmount('-50', 'Amount'), throwsA(isA<FormatException>()));
      expect(() => parseAmount('abc', 'Amount'), throwsA(isA<FormatException>()));
      expect(() => parseAmount('10.999', 'Amount'), throwsA(isA<FormatException>()));
    });
  });

  group('Resilience: Safe Date Parsing', () {
    test('safely parses valid ISO dates', () {
      final d = parseIso('2026-11-08');
      expect(d.year, 2026);
      expect(d.month, 11);
      expect(d.day, 8);
    });

    test('gracefully handles malformed or corrupted date strings without crashing', () {
      final fallback1 = parseIso('');
      expect(fallback1, isA<DateTime>());

      final fallback2 = parseIso('corrupted-date-xyz');
      expect(fallback2, isA<DateTime>());

      final monthStr = monthLabel('invalid');
      expect(monthStr, isA<String>());
    });
  });
}
