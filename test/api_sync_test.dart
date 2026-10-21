import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/data/api_service.dart';
import 'package:medical_shop_manager/data/models.dart';
import 'package:medical_shop_manager/data/mongo_database.dart';
import 'package:medical_shop_manager/data/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiService initializes with valid baseUrl and supports hosted URLs', () {
    expect(ApiService.instance.baseUrl, isNotEmpty);
    expect(ApiService.instance.baseUrl.startsWith('http'), isTrue);
    expect(ApiService.defaultHostedUrl.startsWith('https://'), isTrue);
  });

  test('MongoDatabase and SyncQueueManager singletons exist and initialize', () {
    expect(MongoDatabase.instance, isNotNull);
    expect(SyncQueueManager.instance, isNotNull);
    expect(MongoDatabase.instance.syncAtlasToLocal, isNotNull);
  });

  test('MedicalShop model creates and tracks syncStatus', () {
    const s1 = MedicalShop(id: 1, name: 'Apollo Pharmacy', phone: '9876543210', address: 'Main Road', isActive: true);
    expect(s1.syncStatus, 'synced');
    expect(s1.isPendingSync, isFalse);

    const s2 = MedicalShop(id: 2, name: 'Care Pharmacy', syncStatus: 'pending');
    expect(s2.syncStatus, 'pending');
    expect(s2.isPendingSync, isTrue);
    expect(s2.toMap()['sync_status'], 'pending');
  });

  test('Collection model creates and tracks syncStatus', () {
    final c1 = Collection(
      receiptNumber: '#000001',
      shopId: 1,
      date: DateTime(2026, 1, 1),
      cash: 100,
      gpay: 200,
      cheque: 300,
      syncStatus: 'pending',
    );
    expect(c1.total, 600);
    expect(c1.isPendingSync, isTrue);
    expect(c1.toMap()['sync_status'], 'pending');

    final c2 = Collection.fromMap(c1.toMap());
    expect(c2.isPendingSync, isTrue);
  });

  test('Expense model creates and tracks syncStatus', () {
    final e = Expense(
      id: 5,
      date: DateTime(2026, 2, 1),
      category: 'Travel',
      description: 'Bus fare',
      amount: 5000,
      syncStatus: 'pending',
    );
    expect(e.displayId, 'EXP-00005');
    expect(e.isPendingSync, isTrue);
    expect(e.toMap()['sync_status'], 'pending');

    final e2 = Expense.fromMap(e.toMap());
    expect(e2.isPendingSync, isTrue);
  });
}
