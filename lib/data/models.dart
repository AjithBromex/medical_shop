import '../core/dates.dart';

class MedicalShop {
  final int? id;
  final String name;
  final String? address;
  final String? phone;
  final String? notes;
  final bool isActive;
  final String syncStatus;
  final int updatedAtMs;
  final bool deleted;

  const MedicalShop({
    this.id,
    required this.name,
    this.address,
    this.phone,
    this.notes,
    this.isActive = true,
    this.syncStatus = 'synced',
    this.updatedAtMs = 0,
    this.deleted = false,
  });

  bool get isPendingSync => syncStatus == 'pending';

  factory MedicalShop.fromMap(Map<String, Object?> m) => MedicalShop(
        id: m['id'] as int?,
        name: m['shop_name'] as String,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        notes: m['notes'] as String?,
        isActive: (m['is_active'] as int?) != 0,
        syncStatus: (m['sync_status'] as String?) ?? 'synced',
        updatedAtMs: (m['updated_at_ms'] as int?) ?? 0,
        deleted: (m['deleted'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'shop_name': name,
        'address': address,
        'phone': phone,
        'notes': notes,
        'is_active': isActive ? 1 : 0,
        'sync_status': syncStatus,
        'updated_at_ms': updatedAtMs,
        'deleted': deleted ? 1 : 0,
      };

  MedicalShop copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? notes,
    bool? isActive,
    String? syncStatus,
    int? updatedAtMs,
    bool? deleted,
  }) =>
      MedicalShop(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        deleted: deleted ?? this.deleted,
      );
}

class ShopRow {
  final MedicalShop shop;
  final int count;
  final int total;
  const ShopRow(this.shop, this.count, this.total);
}

class Collection {
  final int? id;
  final String receiptNumber;
  final int shopId;
  final String shopName;
  final DateTime date;
  final int cash;
  final int gpay;
  final int cheque;
  final String? notes;
  final DateTime? createdAt;
  final String syncStatus;
  final int updatedAtMs;
  final bool deleted;

  const Collection({
    this.id,
    required this.receiptNumber,
    required this.shopId,
    this.shopName = '',
    required this.date,
    required this.cash,
    required this.gpay,
    required this.cheque,
    this.notes,
    this.createdAt,
    this.syncStatus = 'synced',
    this.updatedAtMs = 0,
    this.deleted = false,
  });

  int get total => cash + gpay + cheque;
  bool get isPendingSync => syncStatus == 'pending';

  factory Collection.fromMap(Map<String, Object?> m) => Collection(
        id: m['id'] as int?,
        receiptNumber: m['receipt_number'] as String,
        shopId: m['medical_shop_id'] as int,
        shopName: (m['shop_name'] as String?) ?? '',
        date: parseIso(m['collection_date'] as String),
        cash: m['cash_amount'] as int,
        gpay: m['gpay_amount'] as int,
        cheque: m['cheque_amount'] as int,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] == null ? null : DateTime.tryParse(m['created_at'] as String),
        syncStatus: (m['sync_status'] as String?) ?? 'synced',
        updatedAtMs: (m['updated_at_ms'] as int?) ?? 0,
        deleted: (m['deleted'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'receipt_number': receiptNumber,
        'medical_shop_id': shopId,
        'collection_date': isoDate(date),
        'cash_amount': cash,
        'gpay_amount': gpay,
        'cheque_amount': cheque,
        'total_amount': total,
        'notes': notes,
        'sync_status': syncStatus,
        'updated_at_ms': updatedAtMs,
        'deleted': deleted ? 1 : 0,
      };

  Collection copyWith({
    int? id,
    String? receiptNumber,
    int? shopId,
    String? shopName,
    DateTime? date,
    int? cash,
    int? gpay,
    int? cheque,
    String? notes,
    DateTime? createdAt,
    String? syncStatus,
    int? updatedAtMs,
    bool? deleted,
  }) =>
      Collection(
        id: id ?? this.id,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        shopId: shopId ?? this.shopId,
        shopName: shopName ?? this.shopName,
        date: date ?? this.date,
        cash: cash ?? this.cash,
        gpay: gpay ?? this.gpay,
        cheque: cheque ?? this.cheque,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        deleted: deleted ?? this.deleted,
      );
}

class Expense {
  final int? id;
  final DateTime date;
  final String category;
  final String description;
  final int amount;
  final String? notes;
  final String syncStatus;
  final int updatedAtMs;
  final bool deleted;

  const Expense({
    this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    this.notes,
    this.syncStatus = 'synced',
    this.updatedAtMs = 0,
    this.deleted = false,
  });

  String get displayId => 'EXP-${(id ?? 0).toString().padLeft(5, '0')}';
  bool get isPendingSync => syncStatus == 'pending';

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        date: parseIso(m['expense_date'] as String),
        category: m['category'] as String,
        description: m['description'] as String,
        amount: m['amount'] as int,
        notes: m['notes'] as String?,
        syncStatus: (m['sync_status'] as String?) ?? 'synced',
        updatedAtMs: (m['updated_at_ms'] as int?) ?? 0,
        deleted: (m['deleted'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'expense_date': isoDate(date),
        'category': category,
        'description': description,
        'amount': amount,
        'notes': notes,
        'sync_status': syncStatus,
        'updated_at_ms': updatedAtMs,
        'deleted': deleted ? 1 : 0,
      };

  Expense copyWith({
    int? id,
    DateTime? date,
    String? category,
    String? description,
    int? amount,
    String? notes,
    String? syncStatus,
    int? updatedAtMs,
    bool? deleted,
  }) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        category: category ?? this.category,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        notes: notes ?? this.notes,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        deleted: deleted ?? this.deleted,
      );
}

class Totals {
  final int cash, gpay, cheque, count;
  const Totals(this.cash, this.gpay, this.cheque, this.count);
  int get total => cash + gpay + cheque;
  static const zero = Totals(0, 0, 0, 0);
}

class ShopBreakdown {
  final int id;
  final String name;
  final bool active;
  final int cash, gpay, cheque, count;
  const ShopBreakdown(this.id, this.name, this.active, this.cash, this.gpay, this.cheque, this.count);
  int get total => cash + gpay + cheque;
}

class PeriodRow {
  final String key;
  final String label;
  final int cash, gpay, cheque, count;
  const PeriodRow(this.key, this.label, this.cash, this.gpay, this.cheque, this.count);
  int get total => cash + gpay + cheque;
}

class DayRow {
  final DateTime date;
  final int cash, gpay, cheque, expenses;
  const DayRow(this.date, this.cash, this.gpay, this.cheque, this.expenses);
  int get total => cash + gpay + cheque;
  int get remaining => total - expenses;
  int get remainingCash => cash - expenses;
}

class CategoryTotal {
  final String category;
  final int total;
  final int count;
  const CategoryTotal(this.category, this.total, this.count);
}

const Object _keep = Object();

/// Filters shared by history, expenses, analysis and reports.
class Filters {
  final String? q;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? shopId;
  final String? category;
  final String? method; // cash | gpay | cheque
  const Filters({this.q, this.dateFrom, this.dateTo, this.shopId, this.category, this.method});

  Filters copyWith({
    Object? q = _keep,
    Object? dateFrom = _keep,
    Object? dateTo = _keep,
    Object? shopId = _keep,
    Object? category = _keep,
    Object? method = _keep,
  }) =>
      Filters(
        q: identical(q, _keep) ? this.q : q as String?,
        dateFrom: identical(dateFrom, _keep) ? this.dateFrom : dateFrom as DateTime?,
        dateTo: identical(dateTo, _keep) ? this.dateTo : dateTo as DateTime?,
        shopId: identical(shopId, _keep) ? this.shopId : shopId as int?,
        category: identical(category, _keep) ? this.category : category as String?,
        method: identical(method, _keep) ? this.method : method as String?,
      );

  /// Swaps the dates if they are reversed.
  Filters normalized() {
    if (dateFrom != null && dateTo != null && dateFrom!.isAfter(dateTo!)) {
      return copyWith(dateFrom: dateTo, dateTo: dateFrom);
    }
    return this;
  }

  bool get isEmpty => q == null && dateFrom == null && dateTo == null && shopId == null && category == null && method == null;
}
