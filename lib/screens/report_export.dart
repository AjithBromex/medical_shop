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

/// Builds a styled PDF for any report with Oscar Pharma branding and triggers download.
Future<void> exportReportPdf(BuildContext context, String kind, Filters f) async {
  try {
    final report = await Repository.instance.buildReport(kind, f);
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/logo.png');
    } catch (_) {}

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

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Container(
                    height: 34,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Text('Oscar Pharma', style: pw.TextStyle(font: bold, fontSize: 16)),
                pw.Text(
                  'Generated: ${dmy(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(report.title, style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (pw.Context ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Oscar Pharma', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (pw.Context ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: allRows,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F3D6E)),
            cellStyle: pw.TextStyle(font: font, fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            textStyleBuilder: (col, cellData, rowNum) {
              if (hasFooter && rowNum == allRows.length) {
                return pw.TextStyle(font: bold, fontSize: 9, color: const PdfColor.fromInt(0xFF0F3D6E));
              }
              return pw.TextStyle(font: font, fontSize: 8.5);
            },
            cellDecoration: (col, cellData, rowNum) {
              if (hasFooter && rowNum == allRows.length) {
                return const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                );
              }
              return const pw.BoxDecoration();
            },
          ),
        ],
      ),
    );

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

