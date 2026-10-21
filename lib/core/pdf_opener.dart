import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/common.dart';

/// Saves the PDF to disk and directly launches it in an external PDF viewer
/// (such as Google Drive PDF Viewer, Adobe Acrobat, etc.) instead of showing the share sheet.
Future<void> openPdfWithExternalViewer({
  required BuildContext context,
  required Uint8List bytes,
  required String filename,
  String? title,
}) async {
  try {
    // 1. Write bytes to temporary cache directory so OpenFilex can launch it via its FileProvider
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$filename');
    await tempFile.writeAsBytes(bytes, flush: true);

    // 2. Also save to public Downloads directory if accessible so user has a persistent copy
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final downloadFile = File('${downloadDir.path}/$filename');
          await downloadFile.writeAsBytes(bytes, flush: true);
        }
      }
    } catch (_) {
      // Scoped storage fallback; temp file is still valid
    }

    // 3. Open directly with default/external PDF app (Drive PDF Viewer, Acrobat, etc.)
    final result = await OpenFilex.open(tempFile.path, type: 'application/pdf');

    if (result.type != ResultType.done) {
      // If external viewer is not installed or couldn't be opened, fallback to share
      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/pdf', name: filename)],
        subject: title ?? filename,
      );
    } else {
      if (context.mounted) {
        toast(context, 'Opened: $filename');
      }
    }
  } catch (e) {
    if (context.mounted) {
      toast(context, 'Could not open PDF: $e', error: true);
    }
  }
}

