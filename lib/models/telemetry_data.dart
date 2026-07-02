import 'dart:convert';
import 'package:flutter/material.dart';

class TelemetryData {
  final int timestamp;
  final int seq;
  final Map<String, double?> metrics;

  TelemetryData({
    required this.timestamp,
    required this.seq,
    required this.metrics,
  });

  /// Parse TelemetryData from a JSON map
  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    final ts = json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final seq = json['seq'] as int? ?? 0;
    final dMap = json['d'] as Map<String, dynamic>? ?? {};

    final metrics = <String, double?>{};
    for (final entry in dMap.entries) {
      final val = entry.value;
      if (val == null) {
        metrics[entry.key] = null;
      } else if (val is num) {
        metrics[entry.key] = val.toDouble();
      } else {
        metrics[entry.key] = double.tryParse(val.toString());
      }
    }

    return TelemetryData(
      timestamp: ts,
      seq: seq,
      metrics: metrics,
    );
  }

  /// Parse from SSE line (e.g. "data: {...}")
  static TelemetryData? fromSseLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('data:')) return null;
    
    final jsonStr = trimmed.substring(5).trim();
    if (jsonStr.isEmpty) return null;

    try {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return TelemetryData.fromJson(decoded);
    } catch (e) {
      // Failed to parse JSON
      return null;
    }
  }
}

/// Metadata about a telemetry metric
class MetricMetadata {
  final String key;
  final String displayName;
  final String unit;
  final Color defaultColor;
  final bool isPercentage;

  const MetricMetadata({
    required this.key,
    required this.displayName,
    required this.unit,
    required this.defaultColor,
    this.isPercentage = false,
  });
}
