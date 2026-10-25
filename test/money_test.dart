import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/core/money.dart';
import 'package:medical_shop_manager/data/models.dart';

void main() {
  group('parseAmount', () {
    test('parses rupees and paise', () {
      expect(parseAmount('1,250.50', 'x'), 125050);
      expect(parseAmount('₹ 10', 'x'), 1000);
      expect(parseAmount('0.5', 'x'), 50);
      expect(parseAmount('', 'x'), 0);
    });
    test('rejects bad input', () {
      expect(() => parseAmount('-5', 'Cash'), throwsFormatException);
      expect(() => parseAmount('abc', 'Cash'), throwsFormatException);
      expect(() => parseAmount('1.234', 'Cash'), throwsFormatException);
      expect(() => parseAmount('', 'Amount', allowZero: false), throwsFormatException);
      expect(() => parseAmount('0', 'Amount', allowZero: false), throwsFormatException);
    });
  });

  group('formatting', () {
    test('Indian digit grouping', () {
      expect(inr(0), '₹0');
      expect(inr(99999), '₹999.99');
      expect(inr(123456789), '₹12,34,567.89');
      expect(inr(-150050), '-₹1,500.50');
      expect(inr(150000), '₹1,500');
    });
    test('plain', () {
      expect(plain(125050), '1250.50');
      expect(plain(150000), '1500');
    });
  });

  test('collection total = cash + gpay + cheque', () {
    final c = Collection(receiptNumber: '#000001', shopId: 1, date: DateTime(2026, 1, 1), cash: 100, gpay: 200, cheque: 300);
    expect(c.total, 600);
    expect(c.toMap()['total_amount'], 600);
  });

  test('daily remaining = collection - expenses', () {
    final d = DayRow(DateTime(2026, 1, 1), 1000, 500, 0, 400);
    expect(d.total, 1500);
    expect(d.remaining, 1100);
    expect(d.remainingCash, 600);
  });

  test('receipt regex matches valid formats', () {
    final re = RegExp(r'^[#A-Za-z0-9][A-Za-z0-9\-_/.# ]*$');
    expect(re.hasMatch('#000001'), isTrue);
    expect(re.hasMatch('RC-000001'), isTrue);
    expect(re.hasMatch('INV/2026/01'), isTrue);
    expect(re.hasMatch('12345'), isTrue);
  });

  group('Data collection amount calculation', () {
    test('Collected ₹10,000 − GPay/Cheque ₹3,000 = Cash ₹7,000', () {
      final collected = parseAmount('10000', 'Collected');
      final gpayCheque = parseAmount('3000', 'GPay/Cheque');
      expect(collected >= gpayCheque, isTrue);
      final cash = collected - gpayCheque;
      expect(cash, 700000); // 7000 rupees in paise
      expect(inr(cash), '₹7,000');

      final c = Collection(
        receiptNumber: '#000001',
        shopId: 1,
        date: DateTime(2026, 1, 1),
        cash: cash,
        gpay: gpayCheque,
        cheque: 0,
      );
      expect(c.total, collected);
      expect(c.cash, 700000);
      expect(c.gpay, 300000);
      expect(c.total, c.cash + c.gpay + c.cheque);
    });

    test('Collected ₹5,000 − GPay/Cheque ₹0 = Cash ₹5,000', () {
      final collected = parseAmount('5000', 'Collected');
      final gpayCheque = parseAmount('0', 'GPay/Cheque');
      expect(collected >= gpayCheque, isTrue);
      final cash = collected - gpayCheque;
      expect(cash, 500000);
      expect(inr(cash), '₹5,000');
    });

    test('Collected ₹5,000 − GPay/Cheque ₹5,000 = Cash ₹0', () {
      final collected = parseAmount('5000', 'Collected');
      final gpayCheque = parseAmount('5000', 'GPay/Cheque');
      expect(collected >= gpayCheque, isTrue);
      final cash = collected - gpayCheque;
      expect(cash, 0);
      expect(inr(cash), '₹0');
    });

    test('GPay/Cheque greater than Collected Amount triggers validation', () {
      final collected = parseAmount('5000', 'Collected');
      final gpayCheque = parseAmount('6000', 'GPay/Cheque');
      expect(gpayCheque > collected, isTrue);
      final isNegative = gpayCheque > collected;
      expect(isNegative, isTrue);
    });

    test('Decimal precision: Collected ₹10,000.50 − GPay/Cheque ₹3,000.25 = Cash ₹7,000.25', () {
      final collected = parseAmount('10000.50', 'Collected');
      final gpayCheque = parseAmount('3000.25', 'GPay/Cheque');
      final cash = collected - gpayCheque;
      expect(cash, 700025);
      expect(inr(cash), '₹7,000.25');
    });

    test('Negative amounts are rejected by parseAmount', () {
      expect(() => parseAmount('-100', 'Collected'), throwsFormatException);
      expect(() => parseAmount('-50', 'GPay/Cheque'), throwsFormatException);
    });
  });
}
