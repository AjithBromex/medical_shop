import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/pdf_opener.dart';
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
      final fontData = await rootBundle.load('assets/DancingScript.ttf');
      scriptFont = pw.Font.ttf(fontData);
    } catch (_) {
      try {
        scriptFont = await PdfGoogleFonts.dancingScriptBold();
      } catch (_) {}
    }

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
                width: 250,
                height: 95,
              ),
            ),
            // Decorative watermark cross at bottom right
            pw.Positioned(
              right: -10,
              bottom: -10,
              child: pw.SvgImage(
                svg: _watermarkCrossSvg,
                width: 155,
                height: 155,
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
                                      pw.Text('Gpay/NEFT/Others', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('1E293B'))),
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

  Future<void> _shareReceipt(BuildContext context, Collection c) async {
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
    } catch (e) {
      if (context.mounted) toast(context, 'Share failed: $e', error: true);
    }
  }

  Future<void> _downloadPdf(BuildContext context, Collection c) async {
    try {
      final doc = await _buildPdfDoc(c);
      final bytes = await doc.save();
      final filename = 'Receipt_${c.receiptNumber.replaceAll('/', '_')}.pdf';
      if (!context.mounted) return;
      await openPdfWithExternalViewer(
        context: context,
        bytes: bytes,
        filename: filename,
        title: '$appTitle Receipt ${c.receiptNumber}',
      );
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
        ['Gpay/NEFT/Others', (c.gpay + c.cheque).toStringAsFixed(2)],
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (c == null) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
              appBar: AppBar(
                backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
                elevation: 0,
                iconTheme: IconThemeData(color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
              ),
              body: const EmptyState('That record could not be found.'),
            );
          }

          final recordedStr = c.createdAt == null
              ? dmy(c.date)
              : '${dmy(c.createdAt)} ${c.createdAt!.hour.toString().padLeft(2, '0')}:${c.createdAt!.minute.toString().padLeft(2, '0')}';

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
              elevation: 0,
              iconTheme: IconThemeData(color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
              title: Text(
                'Receipt ${c.receiptNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Share Receipt',
                  icon: const Icon(Icons.share_rounded, color: AppColors.total),
                  onPressed: () => _shareReceipt(context, c),
                ),
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
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Background wave curves & watermark cross
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: _ReceiptBackgroundPainter(),
                          ),
                        ),
                        // Main Receipt Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Logo
                              Center(
                                child: Image.asset(
                                  'assets/logo.png',
                                  height: 64,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 2. Title with lines: — Collection Receipt —
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 44, height: 1.2, color: const Color(0xFF475569)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'Collection Receipt',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Container(width: 44, height: 1.2, color: const Color(0xFF475569)),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 3. Metadata Card (Light blue rounded container)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F7FF),
                                  borderRadius: BorderRadius.circular(12),
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
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0EEFA),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  '#',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: Color(0xFF0284C7),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Receipt No.',
                                                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                    ),
                                                    Text(
                                                      c.receiptNumber,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(width: 1, height: 28, color: const Color(0xFFDCEAF7)),
                                        const SizedBox(width: 10),
                                        // Collection Date
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0EEFA),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF0284C7)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Collection Date',
                                                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                    ),
                                                    Text(
                                                      dmy(c.date),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13,
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
                                    const Divider(height: 18, color: Color(0xFFDCEAF7)),
                                    // Customer Row
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0EEFA),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF0284C7)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Customer',
                                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                              ),
                                              Text(
                                                c.shopName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
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
                              const SizedBox(height: 14),

                              // 4. Payment Details Card
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    // Navy Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      color: const Color(0xFF0B3558),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'PAYMENT DETAILS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          Text(
                                            'AMOUNT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                      child: Column(
                                        children: [
                                          // Cash Row
                                          Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE8F7F0),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF059669)),
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Cash',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                              ),
                                              const Spacer(),
                                              Text(
                                                inr(c.cash),
                                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                                          // Gpay Row
                                          Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEBF5FE),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.credit_card_outlined, size: 16, color: Color(0xFF0284C7)),
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Gpay/NEFT/Others',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                              ),
                                              const Spacer(),
                                              Text(
                                                inr(c.gpay + c.cheque),
                                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Total Amount Banner
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6F5ED),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFC0E8D3)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Text(
                                                  'TOTAL AMOUNT',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    color: Color(0xFF087A5B),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(width: 1, height: 20, color: const Color(0xFFC0E8D3)),
                                                const SizedBox(width: 12),
                                                Text(
                                                  inr(c.total),
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w900,
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
                              const SizedBox(height: 12),

                              // 5. Recorded on
                              Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEBF3FC),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recorded on', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                      Text(
                                        recordedStr,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                ],
                              ),
                              if (c.notes != null && c.notes!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text('Notes: ${c.notes}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                                ),
                              ],
                              const SizedBox(height: 26),

                              // 6. Thank You Footer
                              const Center(
                                child: Text(
                                  'Thank You',
                                  style: TextStyle(
                                    fontFamily: 'DancingScript',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF165B7E),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Center(
                                child: Text(
                                  'FOR YOUR CONTINUED SUPPORT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.2,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
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
                      onPressed: () => _shareReceipt(context, c),
                      icon: Icons.share_rounded,
                      accentColor: AppColors.total,
                      isPrimary: true,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Share Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    GlassButton(
                      onPressed: () => _downloadPdf(context, c),
                      icon: Icons.download_rounded,
                      accentColor: AppColors.total,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Download PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    GlassButton(
                      onPressed: () => _print(c),
                      icon: Icons.print_outlined,
                      accentColor: AppColors.textPrimary,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Print', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    GlassButton(
                      onPressed: () => _exportExcel(context, c),
                      icon: Icons.table_chart_outlined,
                      accentColor: AppColors.cash,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: const Text('Export Excel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ]),
          );
        },
      );
}

class _ReceiptBackgroundPainter extends CustomPainter {
  const _ReceiptBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Watermark cross at bottom right
    final crossPaint = Paint()
      ..color = const Color(0xFFE3F0F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeJoin = StrokeJoin.round;

    final crossPath = Path();
    canvas.save();
    const crossBox = 160.0;
    const crossW = 145.0;
    const scaleC = crossW / crossBox;
    canvas.translate(size.width - (crossW * 0.85), size.height - (crossW * 0.85));
    canvas.scale(scaleC, scaleC);

    crossPath.moveTo(60, 10);
    crossPath.relativeLineTo(40, 0);
    crossPath.relativeLineTo(0, 45);
    crossPath.relativeLineTo(45, 0);
    crossPath.relativeLineTo(0, 40);
    crossPath.relativeLineTo(-45, 0);
    crossPath.relativeLineTo(0, 45);
    crossPath.relativeLineTo(-40, 0);
    crossPath.relativeLineTo(0, -45);
    crossPath.relativeLineTo(-45, 0);
    crossPath.relativeLineTo(0, -40);
    crossPath.relativeLineTo(45, 0);
    crossPath.close();

    canvas.drawPath(crossPath, crossPaint);
    canvas.restore();

    // 2. Waves at bottom left
    canvas.save();
    final waveW = size.width * 0.70;
    final scaleW = waveW / 280.0;
    final waveH = 110.0 * scaleW;
    canvas.translate(0, size.height - waveH);
    canvas.scale(scaleW, scaleW);

    // Wave 1: light blue
    final wave1Paint = Paint()
      ..color = const Color(0xFFD3EAF6).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final wave1 = Path()
      ..moveTo(0, 35)
      ..cubicTo(70, 85, 140, 10, 240, 60)
      ..cubicTo(265, 72, 275, 80, 280, 85)
      ..lineTo(280, 110)
      ..lineTo(0, 110)
      ..close();
    canvas.drawPath(wave1, wave1Paint);

    // Wave 2: mint green
    final wave2Paint = Paint()
      ..color = const Color(0xFFC4E7DF).withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final wave2 = Path()
      ..moveTo(0, 55)
      ..cubicTo(80, 95, 160, 30, 250, 80)
      ..lineTo(250, 110)
      ..lineTo(0, 110)
      ..close();
    canvas.drawPath(wave2, wave2Paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
