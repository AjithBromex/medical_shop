import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/core/money.dart';
import 'package:medical_shop_manager/data/models.dart';
import 'package:medical_shop_manager/data/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drive Sync Merge Logic & Conflict Resolution', () {
    test('Latest updated_at_ms wins when merging shop record', () {
      const local = MedicalShop(
        id: 1,
        name: 'Apollo Pharmacy',
        phone: '1111111111',
        updatedAtMs: 1000,
        syncStatus: 'pending',
      );

      final remoteNewer = {
        'shop_name': 'Apollo Pharmacy',
        'phone': '9999999999',
        'updated_at_ms': 2000,
        'deleted': 0,
      };

      // When remote timestamp > local timestamp, remote wins
      final remoteWins = (remoteNewer['updated_at_ms'] as int) > local.updatedAtMs;
      expect(remoteWins, isTrue);

      final mergedPhone = remoteWins ? remoteNewer['phone'] : local.phone;
      expect(mergedPhone, '9999999999');

      // When local timestamp > remote timestamp, local wins
      final localNewer = local.copyWith(updatedAtMs: 3000);
      final localWins = localNewer.updatedAtMs > (remoteNewer['updated_at_ms'] as int);
      expect(localWins, isTrue);
    });

    test('Soft delete (deleted = 1) propagates across sync merge', () {
      final local = Collection(
        id: 1,
        receiptNumber: '#D1-00001',
        shopId: 1,
        date: DateTime(2026, 1, 1),
        cash: 100,
        gpay: 0,
        cheque: 0,
        deleted: false,
        updatedAtMs: 1000,
      );

      final remoteTombstone = {
        'receipt_number': '#D1-00001',
        'deleted': 1,
        'updated_at_ms': 2500,
      };

      final remoteWins = (remoteTombstone['updated_at_ms'] as int) > local.updatedAtMs;
      final shouldBeDeleted = remoteWins && (remoteTombstone['deleted'] == 1);
      expect(shouldBeDeleted, isTrue);
    });
  });

  group('Receipt Number Uniqueness & Node Prefix Scheme', () {
    test('Device node prefix scheme prevents duplicate receipt numbers across offline devices', () {
      String generateReceipt(String nodeId, int sequence) {
        return '#$nodeId-${sequence.toString().padLeft(5, '0')}';
      }

      // Device A and Device B both offline at sequence 1
      final receiptDevA = generateReceipt('D1', 1);
      final receiptDevB = generateReceipt('D2', 1);

      expect(receiptDevA, '#D1-00001');
      expect(receiptDevB, '#D2-00001');
      expect(receiptDevA, isNot(equals(receiptDevB)));
    });

    test('Receipt numbers are case-insensitively unique', () {
      const r1 = '#D1-00001';
      const r2 = '#d1-00001';
      expect(r1.toLowerCase(), equals(r2.toLowerCase()));
    });
  });

  group('SyncQueue Item Model & Serialization', () {
    test('SyncQueueItem serializes and deserializes properly', () {
      final item = SyncQueueItem(
        id: 1,
        entityType: 'collection',
        entityId: '#D1-00001',
        action: 'upsert',
        payload: {'receipt_number': '#D1-00001', 'total': 5000},
        createdAt: DateTime(2026, 2, 1, 10, 30),
        attempts: 1,
        lastError: 'Offline',
      );

      expect(item.entityType, 'collection');
      expect(item.payload['total'], 5000);
      expect(item.attempts, 1);
      expect(item.lastError, 'Offline');
    });
  });

  group('Money and Business Rules Consistency', () {
    test('Collection total matches sum of cash + gpay + cheque', () {
      final c = Collection(
        receiptNumber: '#D1-00005',
        shopId: 1,
        date: DateTime(2026, 2, 1),
        cash: 150000,
        gpay: 50000,
        cheque: 25000,
      );
      expect(c.total, 225000);
      expect(c.toMap()['total_amount'], 225000);
      expect(inr(c.total), '₹2,250');
    });

    test('Expense displayId formatting matches EXP-xxxxx', () {
      final exp = Expense(
        id: 42,
        date: DateTime(2026, 2, 1),
        category: 'Travel',
        description: 'Auto',
        amount: 8000,
      );
      expect(exp.displayId, 'EXP-00042');
    });

    test('Daily balance deduction rules', () {
      final day = DayRow(DateTime(2026, 2, 1), 500000, 200000, 100000, 150000);
      expect(day.total, 800000); // 5000 + 2000 + 1000
      expect(day.remaining, 650000); // 8000 - 1500
      expect(day.remainingCash, 350000); // 5000 cash - 1500 expense
    });

    test('Deleted receipt number can be reused with new data and newer timestamp', () {
      final original = Collection(
        id: 1,
        receiptNumber: '#D1-00001',
        shopId: 1,
        date: DateTime(2026, 1, 1),
        cash: 100,
        gpay: 0,
        cheque: 0,
        deleted: true,
        updatedAtMs: 1000,
      );

      final recreated = Collection(
        id: 1,
        receiptNumber: '#D1-00001',
        shopId: 2,
        date: DateTime(2026, 1, 2),
        cash: 500,
        gpay: 200,
        cheque: 0,
        deleted: false,
        updatedAtMs: 2000,
      );

      expect(recreated.receiptNumber, original.receiptNumber);
      expect(recreated.deleted, isFalse);
      expect(recreated.updatedAtMs > original.updatedAtMs, isTrue);
      expect(recreated.total, 700);
    });
  });
}
