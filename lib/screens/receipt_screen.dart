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

const _calendarSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
  <rect x="3" y="4" width="18" height="18" rx="2" fill="none" stroke="#0284C7" stroke-width="2"/>
  <line x1="16" y1="2" x2="16" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="8" y1="2" x2="8" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="3" y1="10" x2="21" y2="10" stroke="#0284C7" stroke-width="2"/>
  <circle cx="8" cy="14" r="1" fill="#0284C7"/>
  <circle cx="12" cy="14" r="1" fill="#0284C7"/>
  <circle cx="16" cy="14" r="1" fill="#0284C7"/>
</svg>''';

const _storefrontSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
  <path d="M3 9l2-5h14l2 5v1a3 3 0 0 1-6 0 3 3 0 0 1-6 0 3 3 0 0 1-6 0v-1z" fill="none" stroke="#0284C7" stroke-width="2" stroke-linejoin="round"/>
  <path d="M5 10v10h14V10" fill="none" stroke="#0284C7" stroke-width="2"/>
  <path d="M9 20v-6h6v6" fill="none" stroke="#0284C7" stroke-width="2"/>
</svg>''';

const _cashSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
  <rect x="2" y="6" width="20" height="12" rx="2" fill="none" stroke="#059669" stroke-width="2"/>
  <circle cx="12" cy="12" r="3" fill="none" stroke="#059669" stroke-width="2"/>
  <circle cx="6" cy="12" r="1" fill="#059669"/>
  <circle cx="18" cy="12" r="1" fill="#059669"/>
</svg>''';

const _cardSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
  <rect x="2" y="5" width="20" height="14" rx="2" fill="none" stroke="#0284C7" stroke-width="2"/>
  <line x1="2" y1="10" x2="22" y2="10" stroke="#0284C7" stroke-width="2"/>
  <line x1="6" y1="15" x2="10" y2="15" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
</svg>''';

const _clockSvg = '''<svg viewBox="0 0 24 24" width="14" height="14">
  <circle cx="12" cy="12" r="9" fill="none" stroke="#0284C7" stroke-width="2"/>
  <polyline points="12 7 12 12 15 14" fill="none" stroke="#0284C7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

const _bottomWaveSvg = '''<svg viewBox="0 0 280 110" width="280" height="110">
  <path d="M0 35 C 70 85, 140 10, 240 60 C 265 72, 275 80, 280 85 L 280 110 L 0 110 Z" fill="#D3EAF6" opacity="0.85"/>
  <path d="M0 55 C 80 95, 160 30, 250 80 L 250 110 L 0 110 Z" fill="#C4E7DF" opacity="0.95"/>
</svg>''';

const _watermarkCrossSvg = '''<svg viewBox="0 0 160 160" width="160" height="160">
  <path d="M60 10 h40 v45 h45 v40 h-45 v45 h-40 v-45 h-45 v-40 h45 z" fill="none" stroke="#E3F0F9" stroke-width="9" stroke-linejoin="round"/>
</svg>''';

class ReceiptScreen extends StatelessWidget {
  final int collectionId;
  const ReceiptScreen({super.key, required this.collectionId});

  Future<pw.Document> buildPdfDoc(Collection c) => _buildPdfDoc(c);

  Future<pw.Document> _buildPdfDoc(Collection c) async {
    final doc = pw.Document();
    pw.Font font = pw.Font.helvetica();
    pw.Font bold = pw.Font.helveticaBold();
    pw.Font? scriptFont;

    try {
      font = await PdfGoogleFonts.notoSansRegular();
      bold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {}

    try {
      scriptFont = await PdfGoogleFonts.dancingScriptBold();
    } catch (_) {}

    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/logo.png');
    } catch (_) {}

    final recordedStr = c.createdAt == null
        ? dmy(c.date)
        : '${dmy(c.createdAt)} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            // Decorative bottom left waves
            pw.Positioned(
              left: 0,
              bottom: 0,
              child: pw.SvgImage(
                svg: _bottomWaveSvg,
                width: 220,
                height: 85,
              ),
            ),
            // Decorative watermark cross at bottom right
            pw.Positioned(
              right: -15,
              bottom: -15,
              child: pw.SvgImage(
                svg: _watermarkCrossSvg,
                width: 140,
                height: 140,
              ),
            ),
            // Main content
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // 1. Logo
                  if (logoImage != null)
                    pw.Center(
                      child: pw.Container(
                        height: 64,
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ),

                  // 2. Title with lines: — Collection Receipt —
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(width: 44, height: 1, color: PdfColor.fromHex('475569')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                        child: pw.Text(
                          'Collection Receipt',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 16,
                            color: PdfColor.fromHex('0F172A'),
                          ),
                        ),
                      ),
                      pw.Container(width: 44, height: 1, color: PdfColor.fromHex('475569')),
                    ],
                  ),
                  pw.SizedBox(height: 14),

                  // 3. Metadata Card (Light blue rounded container)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F0F7FF'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      border: pw.Border.all(color: PdfColor.fromHex('DCEAF7'), width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Row 1: Receipt No & Collection Date
                        pw.Row(
                          children: [
                            // Receipt No
                            pw.Expanded(
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 28,
                                    height: 28,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('E0EEFA'),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                    ),
                                    child: pw.Center(
                                      child: pw.Text(
                                        '#',
                                        style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 14,
                                          color: PdfColor.fromHex('0284C7'),
                                        ),
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Receipt No.', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
                                      pw.Text(c.receiptNumber, style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('0F172A'))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            pw.Container(width: 1, height: 26, color: PdfColor.fromHex('DCEAF7')),
                            pw.SizedBox(width: 12),
                            // Collection Date
                            pw.Expanded(
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 28,
                                    height: 28,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('E0EEFA'),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                    ),
                                    child: pw.Center(
                                      child: pw.SvgImage(svg: _calendarSvg, width: 16, height: 16),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Collection Date', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
                                      pw.Text(dmy(c.date), style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('0F172A'))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.Container(height: 1, color: PdfColor.fromHex('DCEAF7'), margin: const pw.EdgeInsets.symmetric(vertical: 8)),
                        // Row 2: Customer
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 28,
                              height: 28,
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('E0EEFA'),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Center(
                                child: pw.SvgImage(svg: _storefrontSvg, width: 16, height: 16),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Customer', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
                                pw.Text(c.shopName, style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('0F172A'))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // 4. Payment Details Card
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 1),
                    ),
                    child: pw.Column(
                      children: [
                        // Navy Header
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('0B3558'),
                            borderRadius: const pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(7),
                              topRight: pw.Radius.circular(7),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('PAYMENT DETAILS', style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white, letterSpacing: 0.8)),
                              pw.Text('AMOUNT', style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white, letterSpacing: 0.8)),
                            ],
                          ),
                        ),
                        // Body Rows
                        pw.Padding(
                          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: pw.Column(
                            children: [
                              // Cash Row
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Row(
                                    children: [
                                      pw.Container(
                                        width: 26,
                                        height: 26,
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor.fromHex('E8F7F0'),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                        ),
                                        child: pw.Center(child: pw.SvgImage(svg: _cashSvg, width: 14, height: 14)),
                                      ),
                                      pw.SizedBox(width: 10),
                                      pw.Text('Cash', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('1E293B'))),
                                    ],
                                  ),
                                  pw.Text(inr(c.cash), style: pw.TextStyle(font: bold, fontSize: 11.5, color: PdfColor.fromHex('0F172A'))),
                                ],
                              ),
                              pw.Container(height: 1, color: PdfColor.fromHex('F1F5F9'), margin: const pw.EdgeInsets.symmetric(vertical: 8)),
                              // Gpay Row
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Row(
                                    children: [
                                      pw.Container(
                                        width: 26,
                                        height: 26,
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor.fromHex('EBF5FE'),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                        ),
                                        child: pw.Center(child: pw.SvgImage(svg: _cardSvg, width: 14, height: 14)),
                                      ),
                                      pw.SizedBox(width: 10),
                                      pw.Text('Gpay/cheque/CN', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('1E293B'))),
                                    ],
                                  ),
                                  pw.Text(inr(c.gpay + c.cheque), style: pw.TextStyle(font: bold, fontSize: 11.5, color: PdfColor.fromHex('0F172A'))),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              // Total Amount Banner
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('E6F5ED'),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                                  border: pw.Border.all(color: PdfColor.fromHex('C0E8D3'), width: 1),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Text(
                                      'TOTAL AMOUNT',
                                      style: pw.TextStyle(font: bold, fontSize: 11.5, color: PdfColor.fromHex('087A5B'), letterSpacing: 0.5),
                                    ),
                                    pw.Spacer(),
                                    pw.Container(width: 1, height: 20, color: PdfColor.fromHex('C0E8D3'), margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
                                    pw.Text(
                                      inr(c.total),
                                      style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColor.fromHex('087A5B')),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // 5. Recorded on
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 22,
                        height: 22,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('EBF3FC'),
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(child: pw.SvgImage(svg: _clockSvg, width: 12, height: 12)),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Recorded on', style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColor.fromHex('64748B'))),
                          pw.Text(recordedStr, style: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColor.fromHex('0F172A'))),
                        ],
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(child: pw.Container(height: 1, color: PdfColor.fromHex('E2E8F0'))),
                    ],
                  ),
                  if (c.notes != null && c.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 1),
                      ),
                      child: pw.Text('Notes: ${c.notes}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromHex('475569'))),
                    ),
                  ],

                  pw.Spacer(),

                  // 6. Thank You Footer
                  pw.Center(
                    child: pw.Text(
                      'Thank You',
                      style: pw.TextStyle(
                        font: scriptFont ?? bold,
                        fontSize: 26,
                        color: PdfColor.fromHex('165B7E'),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      'FOR YOUR CONTINUED SUPPORT',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 7.5,
                        color: PdfColor.fromHex('64748B'),
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        ['Customer', c.shopName],
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

          final recordedStr = c.createdAt == null
              ? dmy(c.date)
              : '${dmy(c.createdAt)} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}';

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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0F172A),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Logo
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Title with lines: — Collection Receipt —
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 40, height: 1.2, color: const Color(0xFF64748B)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'Collection Receipt',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Container(width: 40, height: 1.2, color: const Color(0xFF64748B)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Metadata Card (Light blue rounded container)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCEAF7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Receipt No
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0EEFA),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            '#',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Receipt No.',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                              Text(
                                                c.receiptNumber,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: const Color(0xFFDCEAF7)),
                                  const SizedBox(width: 12),
                                  // Collection Date
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0EEFA),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF0284C7)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Collection Date',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                              Text(
                                                dmy(c.date),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFDCEAF7)),
                              // Row 2: Customer
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0EEFA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Customer',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        Text(
                                          c.shopName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Payment Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x080F172A),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // Navy Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                color: const Color(0xFF0B3558),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'PAYMENT DETAILS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      'AMOUNT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    // Cash Row
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F7F0),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Cash',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                        ),
                                        const Spacer(),
                                        Text(
                                          inr(c.cash),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                    // Gpay Row
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEBF5FE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF0284C7)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Gpay/cheque/CN',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                        ),
                                        const Spacer(),
                                        Text(
                                          inr(c.gpay + c.cheque),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Total Amount Banner
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F5ED),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFC0E8D3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'TOTAL AMOUNT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: Color(0xFF087A5B),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(width: 1, height: 24, color: const Color(0xFFC0E8D3)),
                                          const SizedBox(width: 14),
                                          Text(
                                            inr(c.total),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF087A5B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 5. Recorded on
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEBF3FC),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Recorded on', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text(
                                  recordedStr,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),
                        if (c.notes != null && c.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text('Notes: ${c.notes}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // 6. Thank You Footer
                        const Center(
                          child: Text(
                            'Thank You',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontStyle: FontStyle.italic,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF165B7E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'FOR YOUR CONTINUED SUPPORT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
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
