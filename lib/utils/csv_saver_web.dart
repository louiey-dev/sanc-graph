import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:csv/csv.dart';

abstract class CsvWriter {
  Future<void> writeRow(List<dynamic> row);
  Future<void> close();
}

class WebCsvWriter implements CsvWriter {
  final String _fileName;
  final List<List<dynamic>> _buffer = [];

  WebCsvWriter(this._fileName);

  @override
  Future<void> writeRow(List<dynamic> row) async {
    _buffer.add(row);
  }

  @override
  Future<void> close() async {
    if (_buffer.isEmpty) return;

    try {
      final csvContent = const ListToCsvConverter().convert(_buffer);
      final jsParts = [csvContent.toJS].toJS;
      final blob = web.Blob(jsParts, web.BlobPropertyBag(type: 'text/csv;charset=utf-8;'));

      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = _fileName;

      web.document.body?.appendChild(anchor);
      anchor.click();
      web.document.body?.removeChild(anchor);
      web.URL.revokeObjectURL(url);
    } catch (e) {
      debugPrint('Error writing/downloading CSV on web: $e');
    }
  }
}

/// Web implementation of continuous CSV writer (buffers and downloads).
Future<CsvWriter?> createCsvWriter({
  required String fileName,
  required List<String> header,
  required BuildContext context,
}) async {
  final writer = WebCsvWriter(fileName);
  await writer.writeRow(header);
  return writer;
}
