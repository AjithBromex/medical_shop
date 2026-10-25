import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class CloudMigrationDialog extends StatefulWidget {
  const CloudMigrationDialog({super.key});

  @override
  State<CloudMigrationDialog> createState() => _CloudMigrationDialogState();
}

class _CloudMigrationDialogState extends State<CloudMigrationDialog> {
  final _jsonController = TextEditingController();
  bool _isImporting = false;
  String? _statusText;

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<void> _importData() async {
    final rawText = _jsonController.text.trim();
    if (rawText.isEmpty) {
      toast(context, 'Please paste your MongoDB export JSON', error: true);
      return;
    }

    setState(() {
      _isImporting = true;
      _statusText = 'Parsing data...';
    });

    try {
      dynamic parsed;
      try {
        parsed = jsonDecode(rawText);
      } catch (e) {
        // If user pasted mongoexport lines without --jsonArray (newline-delimited JSON)
        final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        parsed = lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
      }

      final d = await AppDatabase.instance.db;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      int shopsCount = 0;
      int collectionsCount = 0;
      int expensesCount = 0;

      List<dynamic> items = [];
      if (parsed is List) {
        items = parsed;
      } else if (parsed is Map) {
        // Combined export {shops: [...], collections: [...], expenses: [...]}
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

        // Detect type
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
            final hit = await d.query('medical_shops', where: 'shop_name = ?', whereArgs: [name]);
            if (hit.isEmpty) {
              await d.insert('medical_shops', {
                'shop_name': name,
                'address': item['address'] ?? '',
                'phone': item['phone'] ?? '',
                'notes': item['notes'] ?? '',
                'is_active': (item['active'] == true || item['is_active'] == 1) ? 1 : 0,
                'sync_status': 'pending',
                'deleted': 0,
                'updated_at_ms': nowMs,
              });
              shopsCount++;
            }
          }
        } else if (isCollection) {
          final rNo = (item['receiptNumber'] ?? item['receipt_number'])?.toString().trim();
          final sName = (item['shopName'] ?? item['shop_name'])?.toString().trim();
          if (rNo != null && rNo.isNotEmpty && sName != null && sName.isNotEmpty) {
            final sHit = await d.query('medical_shops', where: 'shop_name = ?', whereArgs: [sName]);
            int sId;
            if (sHit.isEmpty) {
              sId = await d.insert('medical_shops', {
                'shop_name': sName,
                'is_active': 1,
                'sync_status': 'pending',
                'deleted': 0,
                'updated_at_ms': nowMs,
              });
              shopsCount++;
            } else {
              sId = sHit.first['id'] as int;
            }

            final cHit = await d.query('collections', where: 'receipt_number = ?', whereArgs: [rNo]);
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
              await d.insert('collections', {
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
              collectionsCount++;
            }
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

          await d.insert('expenses', {
            'expense_date': eDate,
            'category': cat,
            'description': desc,
            'amount': amt,
            'notes': item['notes'] ?? '',
            'sync_status': 'pending',
            'deleted': 0,
            'updated_at_ms': nowMs,
          });
          expensesCount++;
        }
      }

      if (mounted) {
        context.read<AppState>().changed();
        setState(() {
          _isImporting = false;
          _statusText = 'Imported: $shopsCount shops, $collectionsCount collections, $expensesCount expenses.';
        });
        toast(context, 'Import successful! Syncing to Google Drive...');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusText = 'Import failed: $e';
        });
        toast(context, 'Error parsing JSON: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_download_outlined, color: AppColors.total),
          SizedBox(width: 10),
          Text('Import from Legacy MongoDB'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To transfer existing data from your old MongoDB Atlas database, export it to JSON and paste the JSON content below:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: const SelectableText(
                  'mongoexport --uri="<MONGODB_URI>" --collection=collections --out=collections.json --jsonArray',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _jsonController,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Paste JSON content here',
                  hintText: '[{"receiptNumber": "#00001", "shopName": "Apollo", ...}]',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
              ),
              if (_statusText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusText!,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.gpay),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _isImporting ? null : _importData,
          icon: _isImporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(_isImporting ? 'Importing...' : 'Import & Save to Drive'),
        ),
      ],
    );
  }
}
