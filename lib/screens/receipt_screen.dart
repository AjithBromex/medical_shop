import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import 'collection_form.dart';

const appTitle = 'Oscar Pharma';

class ReceiptScreen extends StatelessWidget {
  final int collectionId;
  const ReceiptScreen({super.key, required this.collectionId});

  Future<pw.Document> _buildPdfDoc(Collection c) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/logo.png');
    } catch (_) {}

    pw.Widget row(String l, String v, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(l, style: pw.TextStyle(font: strong ? bold : font, fontSize: strong ? 14 : 12)),
            pw.Text(v, style: pw.TextStyle(font: strong ? bold : font, fontSize: strong ? 14 : 12)),
          ]),
        );
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (logoImage != null)
            pw.Center(
              child: pw.Container(
                height: 46,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ),
          pw.Center(child: pw.Text(appTitle, style: pw.TextStyle(font: bold, fontSize: 18))),
          pw.Center(child: pw.Text('Collection Receipt', style: pw.TextStyle(font: font, fontSize: 12))),
          pw.Divider(),
          row('Receipt no.', c.receiptNumber),
          row('Collection date', dmy(c.date)),
          row('Medical shop', c.shopName),
          pw.Divider(),
          row('Cash', inr(c.cash)),
          row('Gpay/cheque/CN', inr(c.gpay + c.cheque)),
          pw.Divider(),
          row('Total amount', inr(c.total), strong: true),
          if (c.notes != null && c.notes!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text('Notes: ${c.notes}', style: pw.TextStyle(font: font, fontSize: 11)),
            ),
          pw.Spacer(),
          pw.Text(
            'Recorded on ${c.createdAt == null ? '' : '${dmy(c.createdAt)} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}'}',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
          ),
        ]),
      ),
    ));
    return doc;
  }

  Future<void> _print(Collection c) async {
    final doc = await _buildPdfDoc(c);
    await Printing.layoutPdf(name: '${c.receiptNumber}.pdf', onLayout: (_) => doc.save());
  }

  Future<void> _downloadPdf(BuildContext context, Collection c) async {
    try {
      final doc = await _buildPdfDoc(c);
      final bytes = await doc.save();
      final filename = 'Receipt_${c.receiptNumber.replaceAll('/', '_')}.pdf';
      final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
      if (!shared) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'application/pdf', name: filename)],
          subject: '$appTitle Receipt ${c.receiptNumber}',
        );
      }
      if (context.mounted) {
        toast(context, 'PDF download started: $filename');
      }
    } catch (e) {
      if (context.mounted) toast(context, 'PDF download failed: $e', error: true);
    }
  }

  Future<void> _exportExcel(BuildContext context, Collection c) async {
    try {
      final rows = <List<String>>[
        [appTitle, 'Collection Receipt'],
        [],
        ['Receipt No', c.receiptNumber],
        ['Collection Date', dmy(c.date)],
        ['Medical Shop', c.shopName],
        [],
        ['Payment Method', 'Amount (₹)'],
        ['Cash', c.cash.toStringAsFixed(2)],
        ['Gpay/cheque/CN', (c.gpay + c.cheque).toStringAsFixed(2)],
        ['Total Amount', c.total.toStringAsFixed(2)],
        if (c.notes != null && c.notes!.isNotEmpty) ...[
          [],
          ['Notes', c.notes!],
        ],
        [],
        [
          'Recorded On',
          c.createdAt == null
              ? ''
              : '${dmy(c.createdAt)} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}',
        ],
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      final filename = 'Receipt_${c.receiptNumber.replaceAll('/', '_')}.csv';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
        subject: '$appTitle Receipt ${c.receiptNumber}',
      );
    } catch (e) {
      if (context.mounted) toast(context, 'Excel export failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Loader<Collection?>(
        loader: () => Repository.instance.collectionById(collectionId),
        builder: (context, c) {
          if (c == null) return Scaffold(appBar: AppBar(), body: const EmptyState('That record could not be found.'));
          Widget line(String l, String v, {bool strong = false}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Text(l, style: TextStyle(fontSize: strong ? 17 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w400)),
                  const Spacer(),
                  Text(v, style: TextStyle(fontSize: strong ? 17 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
                ]),
              );
          return Scaffold(
            backgroundColor: AppColors.bgDark,
            appBar: AppBar(
              title: Text('Receipt ${c.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.total),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionForm(existing: c)));
                  },
                ),
                IconButton(
                  tooltip: 'Download PDF',
                  icon: const Icon(Icons.download_rounded, color: AppColors.total),
                  onPressed: () => _downloadPdf(context, c),
                ),
                IconButton(
                  tooltip: 'Export Excel Sheet',
                  icon: const Icon(Icons.table_chart_outlined, color: AppColors.cash),
                  onPressed: () => _exportExcel(context, c),
                ),
                IconButton(
                  tooltip: 'Print receipt',
                  icon: const Icon(Icons.print_outlined, color: AppColors.textPrimary),
                  onPressed: () => _print(c),
                ),
              ],
            ),
            body: PageBody([
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(
                        child: Image.asset(
                          'assets/logo.png',
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(appTitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Collection Receipt', textAlign: TextAlign.center, style: TextStyle(color: AppColors.total, fontWeight: FontWeight.w600, fontSize: 13)),
                      const Divider(height: 32, color: AppColors.border),
                      line('Receipt no.', c.receiptNumber),
                      line('Collection date', dmy(c.date)),
                      line('Medical shop', c.shopName),
                      const Divider(height: 32, color: AppColors.border),
                      line('Cash', inr(c.cash)),
                      line('Gpay/cheque/CN', inr(c.gpay + c.cheque)),
                      const Divider(height: 32, color: AppColors.border),
                      line('Total amount', inr(c.total), strong: true),
                      if (c.notes != null && c.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('Notes: ${c.notes}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (c.createdAt != null)
                        Text(
                          'Recorded on ${dmy(c.createdAt)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    GlassButton(
                      onPressed: () => _print(c),
                      icon: Icons.print_outlined,
                      accentColor: AppColors.total,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Print', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    GlassButton(
                      onPressed: () => _downloadPdf(context, c),
                      icon: Icons.download_rounded,
                      accentColor: AppColors.total,
                      isPrimary: true,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Download PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    GlassButton(
                      onPressed: () => _exportExcel(context, c),
                      icon: Icons.table_chart_outlined,
                      accentColor: AppColors.cash,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Export Excel Sheet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ]),
          );
        },
      );
}
