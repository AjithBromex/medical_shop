import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/sync_queue.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Comprehensive dialog to import data from a backup file (.db or .json)
/// directly into the currently chosen account (and immediately queue for Google Drive sync).
class DataImportDialog extends StatefulWidget {
  const DataImportDialog({super.key});

  @override
  State<DataImportDialog> createState() => _DataImportDialogState();
}

class _DataImportDialogState extends State<DataImportDialog> {
  File? _selectedFile;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  String? _fileExtension;

  int? _foundShops;
  int? _foundCollections;
  int? _foundExpenses;

  bool _isFullRestore = false;
  final _jsonController = TextEditingController();
  bool _showPasteArea = false;
  bool _isImporting = false;
  bool _isInspecting = false;
  String? _statusText;

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'json', 'csv'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final path = result.files.first.path!;
      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        toast(context, 'Selected file does not exist.', error: true);
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedFileName = result.files.first.name;
        _selectedFileSize = result.files.first.size;
        _fileExtension = _selectedFileName?.split('.').last.toLowerCase();
        _isInspecting = true;
        _statusText = 'Inspecting file content...';
        _foundShops = null;
        _foundCollections = null;
        _foundExpenses = null;
      });

      if (_fileExtension == 'db' || _fileExtension == 'sqlite') {
        await _inspectDbFile(file);
      } else if (_fileExtension == 'json') {
        await _inspectJsonFile(file);
      } else {
        setState(() {
          _isInspecting = false;
          _statusText = 'File ready to import: $_selectedFileName';
        });
      }
    } catch (e) {
      setState(() {
        _isInspecting = false;
        _statusText = 'Error inspecting file: $e';
      });
      if (mounted) {
        toast(context, 'Could not read file: $e', error: true);
      }
    }
  }

  Future<void> _inspectDbFile(File file) async {
    try {
      final probe = await openDatabase(file.path, readOnly: true);
      try {
        final tables = (await probe.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
            .map((r) => r['name'] as String)
            .toSet();

        int shops = 0;
        int collections = 0;
        int expenses = 0;

        if (tables.contains('medical_shops')) {
          shops = Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM medical_shops WHERE deleted = 0')) ??
              Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM medical_shops')) ??
              0;
        }
        if (tables.contains('collections')) {
          collections = Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM collections WHERE deleted = 0')) ??
              Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM collections')) ??
              0;
        }
        if (tables.contains('expenses')) {
          expenses = Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM expenses WHERE deleted = 0')) ??
              Sqflite.firstIntValue(await probe.rawQuery('SELECT COUNT(*) FROM expenses')) ??
              0;
        }

        setState(() {
          _isInspecting = false;
          _foundShops = shops;
          _foundCollections = collections;
          _foundExpenses = expenses;
          _statusText = 'Found $shops shops, $collections collections, $expenses expenses.';
        });
      } finally {
        await probe.close();
      }
    } catch (e) {
      setState(() {
        _isInspecting = false;
        _statusText = 'Error reading SQLite file: $e';
      });
    }
  }

  Future<void> _inspectJsonFile(File file) async {
    try {
      final text = await file.readAsString();
      final parsed = jsonDecode(text);

      int shops = 0;
      int collections = 0;
      int expenses = 0;

      List<dynamic> items = [];
      if (parsed is List) {
        items = parsed;
      } else if (parsed is Map) {
        if (parsed['shops'] is List) shops = (parsed['shops'] as List).length;
        if (parsed['collections'] is List) collections = (parsed['collections'] as List).length;
        if (parsed['expenses'] is List) expenses = (parsed['expenses'] as List).length;
        setState(() {
          _isInspecting = false;
          _foundShops = shops;
          _foundCollections = collections;
          _foundExpenses = expenses;
          _statusText = 'Found $shops shops, $collections collections, $expenses expenses.';
        });
        return;
      }

      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if (item.containsKey('receiptNumber') || item.containsKey('receipt_number') || item['_type'] == 'collection') {
          collections++;
        } else if (item.containsKey('category') || item.containsKey('amount') || item['_type'] == 'expense') {
          expenses++;
        } else if (item.containsKey('shop_name') || item.containsKey('name') || item['_type'] == 'shop') {
          shops++;
        }
      }

      setState(() {
        _isInspecting = false;
        _foundShops = shops;
        _foundCollections = collections;
        _foundExpenses = expenses;
        _statusText = 'Found $shops shops, $collections collections, $expenses expenses.';
      });
    } catch (e) {
      setState(() {
        _isInspecting = false;
        _statusText = 'Error parsing JSON file: $e';
      });
    }
  }

  Future<void> _importData() async {
    if (_selectedFile == null && _jsonController.text.trim().isEmpty) {
      toast(context, 'Please select a file to import.', error: true);
      return;
    }

    setState(() {
      _isImporting = true;
      _statusText = _isFullRestore
          ? 'Restoring database into current account...'
          : 'Importing & merging records into current account...';
    });

    try {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final targetDb = await AppDatabase.instance.db;

      int shopsAdded = 0;
      int shopsUpdated = 0;
      int collectionsAdded = 0;
      int collectionsUpdated = 0;
      int expensesAdded = 0;
      int expensesUpdated = 0;

      if (_selectedFile != null && (_fileExtension == 'db' || _fileExtension == 'sqlite')) {
        if (_isFullRestore) {
          // --- FULL RESTORE (Replace account DB with backup file) ---
          final stats = await AppDatabase.instance.restoreAccountFromBackup(_selectedFile!);
          final d = await AppDatabase.instance.db;

          // Re-populate SyncQueue for all active records
          await d.delete('sync_queue');

          final allShops = await d.query('medical_shops', where: 'deleted = 0');
          for (final s in allShops) {
            final name = (s['shop_name'] as String).trim();
            await SyncQueueManager.instance.enqueue(
              entityType: 'shop',
              entityId: name,
              action: 'upsert',
              payload: {
                'shop_name': name,
                'address': s['address'] ?? '',
                'phone': s['phone'] ?? '',
                'notes': s['notes'] ?? '',
                'is_active': s['is_active'] ?? 1,
                'deleted': 0,
                'updated_at_ms': nowMs,
              },
            );
          }

          final allCollections = await d.query('collections', where: 'deleted = 0');
          for (final c in allCollections) {
            final rNo = (c['receipt_number'] as String).trim();
            await SyncQueueManager.instance.enqueue(
              entityType: 'collection',
              entityId: rNo,
              action: 'upsert',
              payload: {
                'receipt_number': rNo,
                'collection_date': c['collection_date'],
                'cash_amount': c['cash_amount'] ?? 0,
                'gpay_amount': c['gpay_amount'] ?? 0,
                'cheque_amount': c['cheque_amount'] ?? 0,
                'total_amount': c['total_amount'] ?? 0,
                'notes': c['notes'] ?? '',
                'deleted': 0,
                'updated_at_ms': nowMs,
              },
            );
          }

          final allExpenses = await d.query('expenses', where: 'deleted = 0');
          for (final e in allExpenses) {
            final id = e['id'] as int;
            final expDisplayId = 'EXP-${id.toString().padLeft(5, '0')}';
            await SyncQueueManager.instance.enqueue(
              entityType: 'expense',
              entityId: expDisplayId,
              action: 'upsert',
              payload: {
                'display_id': expDisplayId,
                'expense_date': e['expense_date'],
                'category': e['category'],
                'description': e['description'],
                'amount': e['amount'],
                'notes': e['notes'] ?? '',
                'deleted': 0,
                'updated_at_ms': nowMs,
              },
            );
          }

          collectionsAdded = stats['collections'] ?? 0;
          shopsAdded = stats['shops'] ?? 0;
          expensesAdded = stats['expenses'] ?? 0;
        } else {
          // --- MERGE & UPDATE from SQLite Database File (.db) ---
          final probe = await openDatabase(_selectedFile!.path, readOnly: true);
          try {
            // Map shops
            final oldShops = await probe.query('medical_shops');
            final Map<int, int> oldToNewShopId = {};

            for (final s in oldShops) {
              final oldId = s['id'] as int?;
              final name = (s['shop_name'] as String?)?.trim() ?? '';
              if (name.isEmpty) continue;

              final existing = await targetDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [name]);
              int targetId;
              if (existing.isEmpty) {
                targetId = await targetDb.insert('medical_shops', {
                  'shop_name': name,
                  'address': s['address'] ?? '',
                  'phone': s['phone'] ?? '',
                  'notes': s['notes'] ?? '',
                  'is_active': s['is_active'] ?? 1,
                  'sync_status': 'pending',
                  'deleted': s['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                });
                shopsAdded++;
              } else {
                targetId = existing.first['id'] as int;
                await targetDb.update(
                  'medical_shops',
                  {
                    'address': s['address'] ?? existing.first['address'],
                    'phone': s['phone'] ?? existing.first['phone'],
                    'notes': s['notes'] ?? existing.first['notes'],
                    'is_active': s['is_active'] ?? existing.first['is_active'] ?? 1,
                    'sync_status': 'pending',
                    'deleted': s['deleted'] ?? 0, // Un-delete if it was soft-deleted!
                    'updated_at_ms': nowMs,
                  },
                  where: 'id = ?',
                  whereArgs: [targetId],
                );
                shopsUpdated++;
              }
              if (oldId != null) oldToNewShopId[oldId] = targetId;

              await SyncQueueManager.instance.enqueue(
                entityType: 'shop',
                entityId: name,
                action: 'upsert',
                payload: {
                  'shop_name': name,
                  'address': s['address'] ?? '',
                  'phone': s['phone'] ?? '',
                  'notes': s['notes'] ?? '',
                  'is_active': s['is_active'] ?? 1,
                  'deleted': s['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                },
              );
            }

            // Fallback shop id if mapping fails
            int fallbackShopId = oldToNewShopId.values.isNotEmpty ? oldToNewShopId.values.first : 1;
            final shopRows = await targetDb.query('medical_shops', limit: 1);
            if (shopRows.isNotEmpty) {
              fallbackShopId = shopRows.first['id'] as int;
            }

            // Map collections
            final oldCollections = await probe.query('collections');
            for (final c in oldCollections) {
              final rNo = (c['receipt_number'] as String?)?.trim() ?? '';
              if (rNo.isEmpty) continue;

              final oldShopId = c['medical_shop_id'] as int?;
              final int targetShopId = oldToNewShopId[oldShopId] ?? fallbackShopId;

              final existing = await targetDb.query('collections', where: 'receipt_number = ?', whereArgs: [rNo]);
              if (existing.isEmpty) {
                await targetDb.insert('collections', {
                  'receipt_number': rNo,
                  'medical_shop_id': targetShopId,
                  'collection_date': c['collection_date'],
                  'cash_amount': c['cash_amount'] ?? 0,
                  'gpay_amount': c['gpay_amount'] ?? 0,
                  'cheque_amount': c['cheque_amount'] ?? 0,
                  'total_amount': c['total_amount'] ?? 0,
                  'notes': c['notes'] ?? '',
                  'sync_status': 'pending',
                  'deleted': c['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                });
                collectionsAdded++;
              } else {
                final row = existing.first;
                await targetDb.update(
                  'collections',
                  {
                    'medical_shop_id': targetShopId,
                    'collection_date': c['collection_date'],
                    'cash_amount': c['cash_amount'] ?? 0,
                    'gpay_amount': c['gpay_amount'] ?? 0,
                    'cheque_amount': c['cheque_amount'] ?? 0,
                    'total_amount': c['total_amount'] ?? 0,
                    'notes': c['notes'] ?? '',
                    'sync_status': 'pending',
                    'deleted': c['deleted'] ?? 0, // Un-delete if it was soft-deleted!
                    'updated_at_ms': nowMs,
                  },
                  where: 'id = ?',
                  whereArgs: [row['id']],
                );
                collectionsUpdated++;
              }

              await SyncQueueManager.instance.enqueue(
                entityType: 'collection',
                entityId: rNo,
                action: 'upsert',
                payload: {
                  'receipt_number': rNo,
                  'collection_date': c['collection_date'],
                  'cash_amount': c['cash_amount'] ?? 0,
                  'gpay_amount': c['gpay_amount'] ?? 0,
                  'cheque_amount': c['cheque_amount'] ?? 0,
                  'total_amount': c['total_amount'] ?? 0,
                  'notes': c['notes'] ?? '',
                  'deleted': c['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                },
              );
            }

            // Map expenses
            final oldExpenses = await probe.query('expenses');
            for (final e in oldExpenses) {
              final date = e['expense_date'] as String? ?? isoDate(DateTime.now());
              final cat = (e['category'] as String?) ?? 'Other';
              final desc = (e['description'] as String?) ?? '';
              final amt = e['amount'] as int? ?? 0;

              final existing = await targetDb.query(
                'expenses',
                where: 'expense_date = ? AND category = ? AND description = ? AND amount = ?',
                whereArgs: [date, cat, desc, amt],
              );
              int expId;
              if (existing.isEmpty) {
                expId = await targetDb.insert('expenses', {
                  'expense_date': date,
                  'category': cat,
                  'description': desc,
                  'amount': amt,
                  'notes': e['notes'] ?? '',
                  'sync_status': 'pending',
                  'deleted': e['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                });
                expensesAdded++;
              } else {
                expId = existing.first['id'] as int;
                await targetDb.update(
                  'expenses',
                  {
                    'notes': e['notes'] ?? existing.first['notes'] ?? '',
                    'sync_status': 'pending',
                    'deleted': e['deleted'] ?? 0, // Un-delete if deleted!
                    'updated_at_ms': nowMs,
                  },
                  where: 'id = ?',
                  whereArgs: [expId],
                );
                expensesUpdated++;
              }

              final expDisplayId = 'EXP-${expId.toString().padLeft(5, '0')}';
              await SyncQueueManager.instance.enqueue(
                entityType: 'expense',
                entityId: expDisplayId,
                action: 'upsert',
                payload: {
                  'display_id': expDisplayId,
                  'expense_date': date,
                  'category': cat,
                  'description': desc,
                  'amount': amt,
                  'notes': e['notes'] ?? '',
                  'deleted': e['deleted'] ?? 0,
                  'updated_at_ms': nowMs,
                },
              );
            }
          } finally {
            await probe.close();
          }
        }
      } else {
        // --- 2. Import from JSON File or Text ---
        String rawText = '';
        if (_selectedFile != null) {
          rawText = await _selectedFile!.readAsString();
        } else {
          rawText = _jsonController.text.trim();
        }

        dynamic parsed;
        try {
          parsed = jsonDecode(rawText);
        } catch (_) {
          final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          parsed = lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
        }

        List<dynamic> items = [];
        if (parsed is List) {
          items = parsed;
        } else if (parsed is Map) {
          if (parsed['shops'] is List) {
            items.addAll((parsed['shops'] as List).map((s) => {...(s as Map), '_type': 'shop'}));
          }
          if (parsed['collections'] is List) {
            items.addAll((parsed['collections'] as List).map((c) => {...(c as Map), '_type': 'collection'}));
          }
          if (parsed['expenses'] is List) {
            items.addAll((parsed['expenses'] as List).map((e) => {...(e as Map), '_type': 'expense'}));
          }
        }

        for (final raw in items) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);

          final bool isCollection = item['_type'] == 'collection' ||
              item.containsKey('receiptNumber') ||
              item.containsKey('receipt_number') ||
              (item.containsKey('cash') && item.containsKey('shopName'));

          final bool isExpense = item['_type'] == 'expense' ||
              item.containsKey('displayId') ||
              item.containsKey('display_id') ||
              (item.containsKey('amount') && item.containsKey('category'));

          final bool isShop = item['_type'] == 'shop' ||
              (item.containsKey('name') && !isCollection && !isExpense);

          if (isShop) {
            final name = (item['name'] ?? item['shop_name'])?.toString().trim();
            if (name != null && name.isNotEmpty) {
              final hit = await targetDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [name]);
              if (hit.isEmpty) {
                await targetDb.insert('medical_shops', {
                  'shop_name': name,
                  'address': item['address'] ?? '',
                  'phone': item['phone'] ?? '',
                  'notes': item['notes'] ?? '',
                  'is_active': (item['active'] == true || item['is_active'] == 1) ? 1 : 0,
                  'sync_status': 'pending',
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                });
                shopsAdded++;
              } else {
                await targetDb.update(
                  'medical_shops',
                  {
                    'address': item['address'] ?? hit.first['address'],
                    'phone': item['phone'] ?? hit.first['phone'],
                    'notes': item['notes'] ?? hit.first['notes'],
                    'is_active': (item['active'] == true || item['is_active'] == 1) ? 1 : (hit.first['is_active'] ?? 1),
                    'sync_status': 'pending',
                    'deleted': 0,
                    'updated_at_ms': nowMs,
                  },
                  where: 'id = ?',
                  whereArgs: [hit.first['id']],
                );
                shopsUpdated++;
              }
              await SyncQueueManager.instance.enqueue(
                entityType: 'shop',
                entityId: name,
                action: 'upsert',
                payload: {
                  'shop_name': name,
                  'address': item['address'] ?? '',
                  'phone': item['phone'] ?? '',
                  'notes': item['notes'] ?? '',
                  'is_active': (item['active'] == true || item['is_active'] == 1) ? 1 : 0,
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                },
              );
            }
          } else if (isCollection) {
            final rNo = (item['receiptNumber'] ?? item['receipt_number'])?.toString().trim();
            final sName = (item['shopName'] ?? item['shop_name'])?.toString().trim();
            if (rNo != null && rNo.isNotEmpty && sName != null && sName.isNotEmpty) {
              final sHit = await targetDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [sName]);
              int sId;
              if (sHit.isEmpty) {
                sId = await targetDb.insert('medical_shops', {
                  'shop_name': sName,
                  'is_active': 1,
                  'sync_status': 'pending',
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                });
                shopsAdded++;
              } else {
                sId = sHit.first['id'] as int;
              }

              final cHit = await targetDb.query('collections', where: 'receipt_number = ?', whereArgs: [rNo]);
              final cash = _asInt(item['cash'] ?? item['cash_amount']);
              final gpay = _asInt(item['gpay'] ?? item['gpay_amount']);
              final cheque = _asInt(item['cheque'] ?? item['cheque_amount']);
              final total = _asInt(item['total'] ?? item['total_amount'] ?? (cash + gpay + cheque));

              String cDate;
              final rawDate = item['date'] ?? item['collection_date'];
              if (rawDate is String) {
                cDate = rawDate.split('T')[0];
              } else {
                cDate = isoDate(DateTime.now());
              }

              if (cHit.isEmpty) {
                await targetDb.insert('collections', {
                  'receipt_number': rNo,
                  'medical_shop_id': sId,
                  'collection_date': cDate,
                  'cash_amount': cash,
                  'gpay_amount': gpay,
                  'cheque_amount': cheque,
                  'total_amount': total,
                  'notes': item['notes'] ?? '',
                  'sync_status': 'pending',
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                });
                collectionsAdded++;
              } else {
                await targetDb.update(
                  'collections',
                  {
                    'medical_shop_id': sId,
                    'collection_date': cDate,
                    'cash_amount': cash,
                    'gpay_amount': gpay,
                    'cheque_amount': cheque,
                    'total_amount': total,
                    'notes': item['notes'] ?? '',
                    'sync_status': 'pending',
                    'deleted': 0,
                    'updated_at_ms': nowMs,
                  },
                  where: 'id = ?',
                  whereArgs: [cHit.first['id']],
                );
                collectionsUpdated++;
              }

              await SyncQueueManager.instance.enqueue(
                entityType: 'collection',
                entityId: rNo,
                action: 'upsert',
                payload: {
                  'receipt_number': rNo,
                  'collection_date': cDate,
                  'cash_amount': cash,
                  'gpay_amount': gpay,
                  'cheque_amount': cheque,
                  'total_amount': total,
                  'notes': item['notes'] ?? '',
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                },
              );
            }
          } else if (isExpense) {
            final cat = (item['category'])?.toString().trim() ?? 'Other';
            final desc = (item['description'])?.toString().trim() ?? '';
            final amt = _asInt(item['amount']);

            String eDate;
            final rawDate = item['date'] ?? item['expense_date'];
            if (rawDate is String) {
              eDate = rawDate.split('T')[0];
            } else {
              eDate = isoDate(DateTime.now());
            }

            final existing = await targetDb.query(
              'expenses',
              where: 'expense_date = ? AND category = ? AND description = ? AND amount = ?',
              whereArgs: [eDate, cat, desc, amt],
            );
            int expId;
            if (existing.isEmpty) {
              expId = await targetDb.insert('expenses', {
                'expense_date': eDate,
                'category': cat,
                'description': desc,
                'amount': amt,
                'notes': item['notes'] ?? '',
                'sync_status': 'pending',
                'deleted': 0,
                'updated_at_ms': nowMs,
              });
              expensesAdded++;
            } else {
              expId = existing.first['id'] as int;
              await targetDb.update(
                'expenses',
                {
                  'notes': item['notes'] ?? existing.first['notes'] ?? '',
                  'sync_status': 'pending',
                  'deleted': 0,
                  'updated_at_ms': nowMs,
                },
                where: 'id = ?',
                whereArgs: [expId],
              );
              expensesUpdated++;
            }

            final expDisplayId = 'EXP-${expId.toString().padLeft(5, '0')}';
            await SyncQueueManager.instance.enqueue(
              entityType: 'expense',
              entityId: expDisplayId,
              action: 'upsert',
              payload: {
                'display_id': expDisplayId,
                'expense_date': eDate,
                'category': cat,
                'description': desc,
                'amount': amt,
                'notes': item['notes'] ?? '',
                'deleted': 0,
                'updated_at_ms': nowMs,
              },
            );
          }
        }
      }

      if (mounted) {
        final state = context.read<AppState>();
        state.changed();

        final totalCollections = collectionsAdded + collectionsUpdated;
        final totalShops = shopsAdded + shopsUpdated;
        final totalExpenses = expensesAdded + expensesUpdated;

        setState(() {
          _isImporting = false;
          _statusText = _isFullRestore
              ? 'Database restored: $collectionsAdded collections, $shopsAdded shops, $expensesAdded expenses.'
              : 'Processed: $totalCollections collections ($collectionsAdded new, $collectionsUpdated updated), $totalShops shops, $totalExpenses expenses.';
        });

        if (_isFullRestore) {
          toast(context, 'Full database restore complete! $collectionsAdded collections loaded and syncing to Google Drive.');
        } else {
          toast(context, 'Success! $totalCollections collections ($collectionsAdded new, $collectionsUpdated updated/restored) queued for Google Drive.');
        }

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusText = 'Import failed: $e';
        });
        toast(context, 'Import failed: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch<AppState>();
    final accountName = state.currentUser?.displayName ?? (state.currentUser?.email ?? 'Offline Local Storage');
    final accountEmail = state.currentUser?.email;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.file_upload_outlined, color: AppColors.total, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Import Data to Account',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Target Account Badge Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      child: const Icon(Icons.account_circle, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Target Account: ',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                              Flexible(
                                child: Text(
                                  accountName,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (accountEmail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              accountEmail,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF475569)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Select a backup file (.db SQLite database, or .json file) to add shops, collections, and expenses to this account:',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),

              // File Selection Box
              InkWell(
                onTap: _isImporting ? null : _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedFile != null
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: _selectedFile != null ? 1.6 : 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                        color: _selectedFile != null ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName != null ? _selectedFileName! : 'Tap to Choose Backup File',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedFile != null
                            ? '${(_selectedFileSize / 1024).toStringAsFixed(1)} KB • ${_fileExtension?.toUpperCase()} file'
                            : 'Supports .db (SQLite backup), .json, or .csv',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isInspecting) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Analyzing file contents...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],

              // Inspected Records Summary Chips
              if (_foundCollections != null || _foundExpenses != null || _foundShops != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF059669)),
                          SizedBox(width: 6),
                          Text(
                            'Records Found in File:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (_foundShops != null)
                            Chip(
                              avatar: const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF0284C7)),
                              label: Text('$_foundShops Shops', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            ),
                          if (_foundCollections != null)
                            Chip(
                              avatar: const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF059669)),
                              label: Text('$_foundCollections Collections', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            ),
                          if (_foundExpenses != null)
                            Chip(
                              avatar: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFFDC2626)),
                              label: Text('$_foundExpenses Expenses', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Mode selection for .db SQLite backup files
              if (_selectedFile != null && (_fileExtension == 'db' || _fileExtension == 'sqlite')) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        child: Text(
                          'Choose Import Strategy:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        groupValue: _isFullRestore,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        activeColor: const Color(0xFF0284C7),
                        title: const Text('Merge & Update Records (Recommended)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Inserts new records and updates/restores any existing or deleted records in this account.', style: TextStyle(fontSize: 11.5)),
                        onChanged: _isImporting ? null : (v) => setState(() => _isFullRestore = v ?? false),
                      ),
                      RadioListTile<bool>(
                        value: true,
                        groupValue: _isFullRestore,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        activeColor: const Color(0xFF0284C7),
                        title: const Text('Full Database Restore', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Overwrites this account with the exact database backup and syncs it to Google Drive.', style: TextStyle(fontSize: 11.5)),
                        onChanged: _isImporting ? null : (v) => setState(() => _isFullRestore = v ?? true),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Paste JSON toggle
              TextButton.icon(
                onPressed: () => setState(() => _showPasteArea = !_showPasteArea),
                icon: Icon(_showPasteArea ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18),
                label: Text(
                  _showPasteArea ? 'Hide JSON text paste' : 'Or paste JSON data directly',
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              if (_showPasteArea) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _jsonController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Paste JSON content here',
                    hintText: '[{"receiptNumber": "#00001", "shopName": "Pharmacy", ...}]',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
              ],

              if (_statusText != null && !_isInspecting) ...[
                const SizedBox(height: 8),
                Text(
                  _statusText!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_isImporting || (_selectedFile == null && _jsonController.text.trim().isEmpty))
              ? null
              : _importData,
          icon: _isImporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.file_upload_outlined, size: 18),
          label: Text(_isImporting
              ? 'Processing...'
              : (_isFullRestore ? 'Restore Database' : 'Import to Account')),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
          ),
        ),
      ],
    );
  }
}

/// Backwards compatibility alias for CloudMigrationDialog
class CloudMigrationDialog extends StatelessWidget {
  const CloudMigrationDialog({super.key});

  @override
  Widget build(BuildContext context) => const DataImportDialog();
}
