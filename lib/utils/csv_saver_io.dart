import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

abstract class CsvWriter {
  Future<void> writeRow(List<dynamic> row);
  Future<void> close();
}

class IoCsvWriter implements CsvWriter {
  final io.IOSink _sink;

  IoCsvWriter(this._sink);

  @override
  Future<void> writeRow(List<dynamic> row) async {
    final line = const ListToCsvConverter().convert([row]);
    _sink.write(line);
    _sink.write(const ListToCsvConverter().eol);
  }

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}

/// Native implementation of continuous CSV writer.
Future<CsvWriter?> createCsvWriter({
  required String fileName,
  required List<String> header,
  required BuildContext context,
}) async {
  try {
    final String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Telemetry CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      final file = io.File(outputFile);
      final sink = file.openWrite(mode: io.FileMode.write);
      final writer = IoCsvWriter(sink);
      // Write header immediately
      await writer.writeRow(header);
      return writer;
    }
    return null;
  } catch (e) {
    debugPrint('Error creating CSV writer on native: $e');
    return null;
  }
}
