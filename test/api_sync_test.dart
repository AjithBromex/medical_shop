import 'package:flutter_test/flutter_test.dart';
import 'package:medical_shop_manager/data/api_service.dart';
import 'package:medical_shop_manager/data/models.dart';
import 'package:medical_shop_manager/data/mongo_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiService initializes with valid baseUrl', () {
    expect(ApiService.instance.baseUrl, isNotEmpty);
    expect(ApiService.instance.baseUrl.startsWith('http'), isTrue);
  });

  test('MongoDatabase singleton exists and has required methods', () {
    expect(MongoDatabase.instance, isNotNull);
    // Verifies instance can be referenced without errors
    expect(MongoDatabase.instance.syncAtlasToLocal, isNotNull);
  });

  test('MedicalShop model creates and converts to map properly', () {
    final s = MedicalShop(id: 1, name: 'Apollo Pharmacy', phone: '9876543210', address: 'Main Road', isActive: true);
    expect(s.name, 'Apollo Pharmacy');
    expect(s.toMap()['shop_name'], 'Apollo Pharmacy');
  });

  test('Expense model creates and converts properly', () {
    final e = Expense(id: 5, date: DateTime(2026, 2, 1), category: 'Travel', description: 'Bus fare', amount: 5000);
    expect(e.displayId, 'EXP-00005');
    expect(e.toMap()['amount'], 5000);
  });
}
