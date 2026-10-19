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
}
