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
import '../core/pdf_opener.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/common.dart';

const _reportCalendarSvg = '''<svg viewBox="0 0 24 24" width="16" height="16">
  <rect x="3" y="4" width="18" height="18" rx="2" fill="none" stroke="#0284C7" stroke-width="2"/>
  <line x1="16" y1="2" x2="16" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="8" y1="2" x2="8" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="3" y1="10" x2="21" y2="10" stroke="#0284C7" stroke-width="2"/>
</svg>''';

const _reportClockBadgeSvg = '''<svg viewBox="0 0 24 24" width="22" height="22">
  <rect x="3" y="4" width="18" height="18" rx="2" fill="none" stroke="#0284C7" stroke-width="2"/>
  <line x1="16" y1="2" x2="16" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="8" y1="2" x2="8" y2="6" stroke="#0284C7" stroke-width="2" stroke-linecap="round"/>
  <line x1="3" y1="10" x2="21" y2="10" stroke="#0284C7" stroke-width="2"/>
  <circle cx="17" cy="17" r="4.5" fill="#F0F7FF" stroke="#0284C7" stroke-width="1.5"/>
  <polyline points="17 14.5 17 17 18.5 17" fill="none" stroke="#0284C7" stroke-width="1.5" stroke-linecap="round"/>
</svg>''';

const _reportCashCardSvg = '''<svg viewBox="0 0 28 28" width="28" height="28" fill="none" stroke="#0D9488" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="5" y="6" width="19" height="15" rx="3"/>
  <path d="M3 17V8a3 3 0 0 1 3-3h14"/>
  <path d="M14.5 10v7M12.5 11.5a1.8 1.8 0 0 1 3.5 0c0 1.6-3.5 1.6-3.5 3.2a1.8 1.8 0 0 0 3.5 0"/>
</svg>''';

const _reportExpenseCardSvg = '''<svg viewBox="0 0 28 28" width="28" height="28">
  <path d="M6 3h16v22l-2.5-1.5L17 25l-3-1.5L11 25l-2.5-1.5L6 25V3z" fill="none" stroke="#DC2626" stroke-width="2" stroke-linejoin="round"/>
  <rect x="9.5" y="7" width="9" height="7" rx="1.5" fill="none" stroke="#DC2626" stroke-width="1.6"/>
  <line x1="14" y1="8.5" x2="14" y2="12.5" stroke="#DC2626" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="12" y1="10.5" x2="16" y2="10.5" stroke="#DC2626" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="10" y1="17" x2="18" y2="17" stroke="#DC2626" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="10" y1="20" x2="15" y2="20" stroke="#DC2626" stroke-width="1.6" stroke-linecap="round"/>
</svg>''';

const _reportWalletCardSvg = '''<svg viewBox="0 0 28 28" width="28" height="28">
  <path d="M4 8a3 3 0 0 1 3-3h15a2 2 0 0 1 2 2v2H7a3 3 0 0 0-3 3v10a3 3 0 0 0 3 3h15a2 2 0 0 0 2-2V11" fill="none" stroke="#0A2540" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M17 13h7v6h-7a3 3 0 0 1 0-6z" fill="none" stroke="#0A2540" stroke-width="2"/>
  <circle cx="21" cy="16" r="1" fill="#0A2540"/>
</svg>''';

/// Builds the CSV for a report using the same filters as the screen and opens the share sheet.
/// UTF-8 BOM is added so Excel shows ₹ and other characters correctly.
Future<void> exportReport(BuildContext context, String kind, Filters f) async {
  try {
    final report = await Repository.instance.buildReport(kind, f);
    final rows = <List<String>>[
      report.headers,
      for (final r in report.rows) [for (final v in r) Report.cell(v, csv: true)],
      if (report.footer != null) [for (final v in report.footer!) Report.cell(v, csv: true)],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    final name = '${report.kind}_${isoDate(DateTime.now()).replaceAll('-', '')}.csv';
    await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'text/csv', name: name)], subject: report.title);
  } catch (e) {
    if (context.mounted) toast(context, 'Export failed: $e', error: true);
  }
}

/// Builds the styled PDF document for any report matching the premium layout.
Future<pw.Document> buildReportPdfDocument(Report report, Filters f, {int? expenseTotal}) async {
  final doc = pw.Document();
  pw.Font font = pw.Font.helvetica();
  pw.Font bold = pw.Font.helveticaBold();

  try {
    font = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {}

  pw.ImageProvider? logoImage;
  try {
    logoImage = await imageFromAssetBundle('assets/logo.png');
  } catch (_) {}

  final now = DateTime.now();
  final genDate = dmy(now);
  final genTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  DateTime? minD = f.dateFrom;
  DateTime? maxD = f.dateTo;
  for (final r in report.rows) {
    for (final v in r) {
      if (v is DateTime) {
        minD = (minD == null || v.isBefore(minD)) ? v : minD;
        maxD = (maxD == null || v.isAfter(maxD)) ? v : maxD;
      }
    }
  }
  final dateRangeStr = '${dmy(minD ?? now)} to ${dmy(maxD ?? now)}';

  final isDateRange = report.kind == 'date_range';

  final headers = [
    for (final h in report.headers)
      if (h == 'Gpay/NEFT/Others' || h == 'Gpay/cheque/CN' || h == 'Gpay/Cheque/CK' || h == 'Gpay/cheque/CK')
        'Gpay/\nNEFT/Others'
      else if (h == 'Receipt No.')
        'Receipt\nNo.'
      else
        h,
  ];
  final data = [
    for (final r in report.rows) [
      for (var i = 0; i < r.length; i++)
        if (isDateRange && i == 1)
          Report.cell(r[i]).replaceFirst(RegExp(r'^#'), '')
        else
          Report.cell(r[i])
    ],
  ];
  final footer = report.footer != null ? [for (final v in report.footer!) Report.cell(v)] : null;
  final allRows = [
    ...data,
    if (footer != null) footer,
  ];
  final hasFooter = footer != null;

  // Compute summary totals for date_range
  int totalCashPaise = 0;
  if (isDateRange) {
    if (footer != null && footer.length > 4) {
      final cashVal = footer[4];
      try {
        totalCashPaise = parseAmount(cashVal, 'Cash', allowZero: true);
      } catch (_) {}
    } else {
      for (final r in report.rows) {
        if (r.length > 4) {
          final c = r[4];
          if (c is Money) {
            totalCashPaise += c.paise;
          } else {
            try {
              totalCashPaise += parseAmount(Report.cell(c), 'Cash', allowZero: true);
            } catch (_) {}
          }
        }
      }
    }
  }

  int expensePaise = expenseTotal ?? 0;
  if (expenseTotal == null && isDateRange) {
    try {
      expensePaise = await Repository.instance.expenseTotal(f.dateFrom ?? minD, f.dateTo ?? maxD);
    } catch (_) {
      expensePaise = 0;
    }
  }
  final remainingCashPaise = totalCashPaise - expensePaise;

  final columnWidths = isDateRange
      ? const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(44),  // # (fits "Total" cleanly on one line)
          1: pw.FixedColumnWidth(56),  // Receipt No.
          2: pw.FixedColumnWidth(64),  // Date
          3: pw.FlexColumnWidth(2.0),  // Customer
          4: pw.FixedColumnWidth(58),  // Cash
          5: pw.FixedColumnWidth(72),  // Gpay/NEFT/Others
          6: pw.FixedColumnWidth(60),  // Total
          7: pw.FixedColumnWidth(66),  // Notes (fits "pending" without wrapping)
        }
      : null;

  final headerAlignments = isDateRange
      ? const <int, pw.AlignmentGeometry>{
          0: pw.Alignment.center,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
          5: pw.Alignment.center,
          6: pw.Alignment.center,
          7: pw.Alignment.center,
        }
      : null;

  final alignments = isDateRange
      ? const <int, pw.AlignmentGeometry>{
          0: pw.Alignment.center,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.centerLeft,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
          7: pw.Alignment.center,
        }
      : null;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 1. Top row: Logo on left, "Report Generated" card on right
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  height: 48,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              else
                pw.Text('Oscar Pharma', style: pw.TextStyle(font: bold, fontSize: 20, color: PdfColor.fromHex('061D38'))),
              // Report Generated Badge Card
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0F7FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SvgImage(svg: _reportClockBadgeSvg, width: 22, height: 22),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Report Generated', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColor.fromHex('64748B'))),
                        pw.SizedBox(height: 2),
                        pw.Text('$genDate  |  $genTime', style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('0A1931'))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // 2. Report Title
          pw.Text(
            report.title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 24,
              color: PdfColor.fromHex('0A1931'),
            ),
          ),
          pw.SizedBox(height: 10),

          // 3. Date Range Filter Badge
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0F7FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SvgImage(svg: _reportCalendarSvg, width: 15, height: 15),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      dateRangeStr,
                      style: pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0A1931')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1.5, color: PdfColor.fromHex('063970')),
          pw.SizedBox(height: 14),
        ],
      ),
      footer: (pw.Context ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Oscar Pharma', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
        ],
      ),
      build: (pw.Context ctx) => [
        pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('CBDDF0'), width: 1.2),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.TableHelper.fromTextArray(
              headers: headers,
              data: allRows,
              columnWidths: columnWidths,
              cellAlignments: alignments,
              headerAlignments: headerAlignments,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('063970')),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 9),
              cellStyle: pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0A1931')),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 8.5),
              border: pw.TableBorder.all(color: PdfColor.fromHex('D5E3F2'), width: 0.8),
              textStyleBuilder: (col, cellData, rowNum) {
                // Footer row (last row)
                if (hasFooter && rowNum == allRows.length) {
                  if (col == 0) {
                    return pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0A1931'));
                  }
                  if (col >= 4 && col <= 6) {
                    return pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('047857'));
                  }
                  if (col == 7) {
                    return pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('EF4444'));
                  }
                  return pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0A1931'));
                }
                // Data rows: Strong, bold, prominent text
                if (isDateRange) {
                  if (col == 7) {
                    final text = cellData?.toString().trim() ?? '';
                    if (text == '-' || text.isEmpty) {
                      return pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('EF4444'));
                    }
                    return pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColor.fromHex('DC2626'));
                  }
                  if (col == 6) { // Total column
                    return pw.TextStyle(font: bold, fontSize: 11.5, color: PdfColor.fromHex('0A1931'));
                  }
                  if (col == 2) { // Date column
                    return pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('0A1931'));
                  }
                  return pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('0A1931'));
                }
                return pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('0A1931'));
              },
              cellDecoration: (col, cellData, rowNum) {
                if (hasFooter && rowNum == allRows.length) {
                  return pw.BoxDecoration(color: PdfColor.fromHex('EAF7F4'));
                }
                return const pw.BoxDecoration(color: PdfColors.white);
              },
            ),
          ),
        ),
        if (isDateRange) ...[
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              // 1. Total Cash Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F0FDF9'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 44,
                        height: 44,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('D1FAE5'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.SvgImage(svg: _reportCashCardSvg, width: 26, height: 26),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Total Cash',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColor.fromHex('0F172A')),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            inr(totalCashPaise),
                            style: pw.TextStyle(font: bold, fontSize: 19, color: PdfColor.fromHex('0D9488')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),

              // 2. Expense Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('FFF5F5'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 44,
                        height: 44,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('FEE2E2'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.SvgImage(svg: _reportExpenseCardSvg, width: 26, height: 26),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Expense',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColor.fromHex('0F172A')),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            inr(expensePaise),
                            style: pw.TextStyle(font: bold, fontSize: 19, color: PdfColor.fromHex('DC2626')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),

              // 3. Remaining Cash Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('EFF6FF'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 44,
                        height: 44,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('DBEAFE'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.SvgImage(svg: _reportWalletCardSvg, width: 26, height: 26),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Remaining Cash',
                            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColor.fromHex('0F172A')),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            inr(remainingCashPaise),
                            style: pw.TextStyle(font: bold, fontSize: 19, color: PdfColor.fromHex('0A2540')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  return doc;
}

/// Builds a styled PDF for any report with Oscar Pharma branding, saves it, and directly opens it in an external PDF viewer (e.g. Drive PDF viewer).
Future<void> exportReportPdf(BuildContext context, String kind, Filters f) async {
  try {
    final report = await Repository.instance.buildReport(kind, f);
    int? expenseTotal;
    if (kind == 'date_range') {
      DateTime? minD = f.dateFrom;
      DateTime? maxD = f.dateTo;
      for (final r in report.rows) {
        for (final v in r) {
          if (v is DateTime) {
            minD = (minD == null || v.isBefore(minD)) ? v : minD;
            maxD = (maxD == null || v.isAfter(maxD)) ? v : maxD;
          }
        }
      }
      try {
        expenseTotal = await Repository.instance.expenseTotal(minD, maxD);
      } catch (_) {}
    }
    final doc = await buildReportPdfDocument(report, f, expenseTotal: expenseTotal);
    final bytes = await doc.save();
    final filename = '${report.kind}_${isoDate(DateTime.now()).replaceAll('-', '')}.pdf';
    if (!context.mounted) return;
    await openPdfWithExternalViewer(
      context: context,
      bytes: bytes,
      filename: filename,
      title: '${report.title} - Oscar Pharma',
    );
  } catch (e) {
    if (context.mounted) toast(context, 'Export PDF failed: $e', error: true);
  }
}

/// Directly opens the print preview dialog for the report.
Future<void> printReportPdf(BuildContext context, String kind, Filters f) async {
  try {
    final report = await Repository.instance.buildReport(kind, f);
    int? expenseTotal;
    if (kind == 'date_range') {
      DateTime? minD = f.dateFrom;
      DateTime? maxD = f.dateTo;
      for (final r in report.rows) {
        for (final v in r) {
          if (v is DateTime) {
            minD = (minD == null || v.isBefore(minD)) ? v : minD;
            maxD = (maxD == null || v.isAfter(maxD)) ? v : maxD;
          }
        }
      }
      try {
        expenseTotal = await Repository.instance.expenseTotal(minD, maxD);
      } catch (_) {}
    }
    final doc = await buildReportPdfDocument(report, f, expenseTotal: expenseTotal);
    await Printing.layoutPdf(
      name: '${report.kind}_${isoDate(DateTime.now()).replaceAll('-', '')}.pdf',
      onLayout: (_) => doc.save(),
    );
  } catch (e) {
    if (context.mounted) toast(context, 'Print failed: $e', error: true);
  }
}

