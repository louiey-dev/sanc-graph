import 'package:flutter/widgets.dart';

abstract class CsvWriter {
  Future<void> writeRow(List<dynamic> row);
  Future<void> close();
}

/// Stub function for saving CSV files. Will be overridden by platform-specific implementations.
Future<bool> saveCsvFile({
  required String csvContent,
  required String fileName,
  required BuildContext context,
}) {
  throw UnsupportedError('Cannot save CSV on this platform.');
}

/// Stub function for creating a CSV writer. Will be overridden by platform-specific implementations.
Future<CsvWriter?> createCsvWriter({
  required String fileName,
  required List<String> header,
  required BuildContext context,
}) {
  throw UnsupportedError('Cannot create CSV writer on this platform.');
}
