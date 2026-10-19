import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
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
Future<pw.Document> buildReportPdfDocument(Report report, Filters f) async {
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
  final dateRangeStr = '${dmy(minD ?? now)}  to  ${dmy(maxD ?? now)}';

  final headers = report.headers;
  final data = [
    for (final r in report.rows) [for (final v in r) Report.cell(v)],
  ];
  final footer = report.footer != null ? [for (final v in report.footer!) Report.cell(v)] : null;
  final allRows = [
    ...data,
    if (footer != null) footer,
  ];
  final hasFooter = footer != null;

  final isDateRange = report.kind == 'date_range';

  final columnWidths = isDateRange
      ? const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(40),  // #
          1: pw.FixedColumnWidth(85),  // Receipt No.
          2: pw.FixedColumnWidth(85),  // Date
          3: pw.FlexColumnWidth(3.2),  // Customer
          4: pw.FixedColumnWidth(85),  // Cash
          5: pw.FixedColumnWidth(105), // Gpay/cheque/CN
          6: pw.FixedColumnWidth(95),  // Total
          7: pw.FlexColumnWidth(1.5),  // Notes
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
      pageFormat: isDateRange ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
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
                pw.Text('Oscar Pharma', style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColor.fromHex('0F172A'))),
              // Report Generated Badge Card
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0F7FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('DCEAF7'), width: 1),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SvgImage(svg: _reportClockBadgeSvg, width: 20, height: 20),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Report Generated', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('64748B'))),
                        pw.SizedBox(height: 2),
                        pw.Text('$genDate  |  $genTime', style: pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0F172A'))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // 2. Report Title
          pw.Text(
            report.title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 18,
              color: PdfColor.fromHex('0F172A'),
            ),
          ),
          pw.SizedBox(height: 8),

          // 3. Date Range Filter Badge
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F0F7FF'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('DCEAF7'), width: 1),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SvgImage(svg: _reportCalendarSvg, width: 14, height: 14),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      dateRangeStr,
                      style: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColor.fromHex('0F172A')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1, color: PdfColor.fromHex('CBD5E1')),
          pw.SizedBox(height: 12),
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
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: allRows,
          columnWidths: columnWidths,
          cellAlignments: alignments,
          headerAlignments: alignments,
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('0B3558')),
          cellStyle: pw.TextStyle(font: font, fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          border: pw.TableBorder.all(color: PdfColor.fromHex('E2E8F0'), width: 0.6),
          textStyleBuilder: (col, cellData, rowNum) {
            // Footer row
            if (hasFooter && rowNum == allRows.length) {
              if (cellData.startsWith('₹')) {
                return pw.TextStyle(font: bold, fontSize: 11, color: PdfColor.fromHex('087A5B'));
              }
              if (col == 0) {
                return pw.TextStyle(font: bold, fontSize: 10.5, color: PdfColor.fromHex('0F172A'));
              }
              return pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('64748B'));
            }
            // Data rows
            if (isDateRange) {
              if (col == 6) { // Total column
                return pw.TextStyle(font: bold, fontSize: 9, color: PdfColor.fromHex('0F172A'));
              }
              if (col == 1) { // Receipt No
                return pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColor.fromHex('0F172A'));
              }
            }
            return pw.TextStyle(font: font, fontSize: 8.5, color: PdfColor.fromHex('1E293B'));
          },
          cellDecoration: (col, cellData, rowNum) {
            if (hasFooter && rowNum == allRows.length) {
              return pw.BoxDecoration(color: PdfColor.fromHex('E6F5ED'));
            }
            if (rowNum % 2 == 1) {
              return pw.BoxDecoration(color: PdfColor.fromHex('F8FAFC'));
            }
            return const pw.BoxDecoration(color: PdfColors.white);
          },
        ),
      ],
    ),
  );

  return doc;
}

/// Builds a styled PDF for any report with Oscar Pharma branding and triggers download.
Future<void> exportReportPdf(BuildContext context, String kind, Filters f) async {
  try {
    final report = await Repository.instance.buildReport(kind, f);
    final doc = await buildReportPdfDocument(report, f);
    final bytes = await doc.save();
    final filename = '${report.kind}_${isoDate(DateTime.now()).replaceAll('-', '')}.pdf';
    final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
    if (!shared) {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: filename)],
        subject: '${report.title} - Oscar Pharma',
      );
    }
    if (context.mounted) {
      toast(context, 'PDF downloaded: $filename');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Export PDF failed: $e', error: true);
  }
}
