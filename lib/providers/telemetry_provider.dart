import 'dart:async';
import 'package:flutter/material.dart';
import '../models/telemetry_data.dart';
import '../services/telemetry_service.dart';
import '../utils/csv_saver.dart';

class TelemetryProvider with ChangeNotifier {
  final TelemetryService _telemetryService = TelemetryService();
  StreamSubscription<TelemetryData>? _subscription;

  // Connection settings
  // String _ip = '192.168.1.100';
  String _ip = 'localhost';
  int _port = 18765;
  bool _isSimulated = false;

  // Connection states
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _errorMessage;

  // Data history
  final List<TelemetryData> _dataHistory = [];
  // Hard cap on retained samples to prevent unbounded memory growth during
  // long sessions. Well above the max display window; live CSV rows are written
  // incrementally so trimming here never drops recorded data.
  static const int _maxHistoryBuffer = 20000;
  // Cumulative count of every packet received this session. Unlike
  // _dataHistory.length (capped at _maxHistoryBuffer), this never trims.
  int _totalSampleCount = 0;
  int _maxDisplayPoints = 1000;
  bool _isSavingCsv = false;
  CsvWriter? _activeCsvWriter;

  // Dynamically discovered metrics
  final List<MetricMetadata> _discoveredMetrics = [];
  final Map<String, bool> _selectedMetrics = {};
  final Map<String, Color> _metricColors = {};
  final Map<String, bool> _metricOnRightAxis = {};

  // Zoom and Pan state for plot area Y-axis and X-axis history
  double _xZoomFactor = 1.0;
  double _yZoomFactor = 1.0;
  double _yPanOffset = 0.0;
  double _xPanOffset = 0.0;

  // UI States
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isSidebarCollapsed = false;
  bool _isLogPanelFolded = true;
  final List<String> _logs = [];
  static const int _maxLogsBuffer = 50;

  // Curated color palette for dynamic assignment
  static const List<Color> _colorPalette = [
    Colors.teal,
    Colors.cyan,
    Colors.blue,
    Colors.lightBlue,
    Colors.indigo,
    Colors.purple,
    Colors.deepPurple,
    Colors.pink,
    Colors.pinkAccent,
    Colors.red,
    Colors.redAccent,
    Colors.deepOrange,
    Colors.orange,
    Colors.orangeAccent,
    Colors.amber,
    Colors.yellow,
    Colors.lime,
    Colors.lightGreen,
    Colors.green,
    Colors.blueGrey,
    Colors.brown,
  ];

  // Getters
  String get ip => _ip;
  int get port => _port;
  bool get isSimulated => _isSimulated;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  List<TelemetryData> get dataHistory => _dataHistory;
  int get totalSampleCount => _totalSampleCount;
  int get maxDisplayPoints => _maxDisplayPoints;
  double get xZoomFactor => _xZoomFactor;
  double get yZoomFactor => _yZoomFactor;
  double get yPanOffset => _yPanOffset;
  double get xPanOffset => _xPanOffset;
  ThemeMode get themeMode => _themeMode;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  List<MetricMetadata> get discoveredMetrics => _discoveredMetrics;
  bool get isSavingCsv => _isSavingCsv;
  bool get isLogPanelFolded => _isLogPanelFolded;
  List<String> get logs => _logs;

  TelemetryProvider();

  void setXZoomFactor(double zoom) {
    _xZoomFactor = zoom.clamp(1.0, 50.0);
    notifyListeners();
  }

  void setYZoomFactor(double zoom) {
    _yZoomFactor = zoom.clamp(0.5, 50.0);
    notifyListeners();
  }

  void setYPanOffset(double pan) {
    _yPanOffset = pan.clamp(-3.0, 3.0);
    notifyListeners();
  }

  void setXPanOffset(double offset) {
    _xPanOffset = offset < 0.0 ? 0.0 : offset;
    notifyListeners();
  }

  void resetZoomAndPan() {
    _xZoomFactor = 1.0;
    _yZoomFactor = 1.0;
    _yPanOffset = 0.0;
    _xPanOffset = 0.0;
    notifyListeners();
  }

  // Setters and Toggles
  void setConnectionSettings(String ip, int port) {
    _ip = ip;
    _port = port;
    notifyListeners();
  }

  void setSimulated(bool value) {
    if (_isSimulated == value) return;
    _isSimulated = value;
    if (_isConnected || _isConnecting) {
      startStream();
    } else {
      notifyListeners();
    }
  }

  void setMaxDisplayPoints(int val) {
    _maxDisplayPoints = val;
    notifyListeners();
  }

  bool isMetricSelected(String key) => _selectedMetrics[key] ?? false;

  void toggleMetric(String key, bool selected) {
    _selectedMetrics[key] = selected;
    notifyListeners();
  }

  Color getMetricColor(String key) => _metricColors[key] ?? Colors.grey;

  void updateMetricColor(String key, Color color) {
    _metricColors[key] = color;
    notifyListeners();
  }

  bool isMetricOnRightAxis(String key) => _metricOnRightAxis[key] ?? false;

  void toggleMetricAxis(String key) {
    _metricOnRightAxis[key] = !(_metricOnRightAxis[key] ?? false);
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  void toggleLogPanel() {
    _isLogPanelFolded = !_isLogPanelFolded;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Starts listening to the telemetry stream
  Future<void> startStream() async {
    await stopStream();

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Stream<TelemetryData> stream;
      if (_isSimulated) {
        stream = _telemetryService.getSimulatedStream();
      } else {
        stream = _telemetryService.connectStream(_ip, _port);
      }

      _subscription = stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _isConnecting = false;
          }

          // Dynamically discover and register new metrics in the data frame
          _discoverMetricsFromData(data);

          _dataHistory.add(data);
          _totalSampleCount++;

          // Accumulate logs in a list for the UI panel
          _logs.add(data.rawPacket);
          if (_logs.length > _maxLogsBuffer) {
            _logs.removeAt(0);
          }

          // If the log panel is folded, print incoming packet strings to console
          if (_isLogPanelFolded) {
            // ignore: avoid_print
            print(data.rawPacket);
          }
          if (_isSavingCsv && _activeCsvWriter != null) {
            final List<dynamic> row = [
              DateTime.fromMillisecondsSinceEpoch(
                data.timestamp,
              ).toIso8601String(),
              data.timestamp,
              data.seq,
            ];
            for (final metric in _discoveredMetrics) {
              row.add(data.metrics[metric.key]);
            }
            _activeCsvWriter!.writeRow(row);
          }
          // Trim to the retention cap to bound memory on long sessions.
          if (_dataHistory.length > _maxHistoryBuffer) {
            _dataHistory.removeRange(
              0,
              _dataHistory.length - _maxHistoryBuffer,
            );
          }
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error.toString();
          _isConnected = false;
          _isConnecting = false;
          _telemetryService.disconnect();
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
          _telemetryService.disconnect();
          notifyListeners();
        },
      );

      if (_isSimulated) {
        _isConnected = true;
        _isConnecting = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Inspects a telemetry frame to discover and register new metrics
  void _discoverMetricsFromData(TelemetryData data) {
    bool newlyDiscovered = false;

    for (final key in data.metrics.keys) {
      // If we haven't seen this metric key before, register it
      if (!_discoveredMetrics.any((m) => m.key == key)) {
        final displayName = _formatKeyName(key);
        final unit = _detectUnit(key);
        final color =
            _colorPalette[_discoveredMetrics.length % _colorPalette.length];

        // Smart heuristic for axis allocation
        final firstVal = data.metrics[key];
        final isHighValueOrClockOrPower =
            key.contains('clk') ||
            key.contains('pwr') ||
            key.contains('mw') ||
            key.contains('mhz') ||
            (firstVal != null && firstVal > 150);

        final metadata = MetricMetadata(
          key: key,
          displayName: displayName,
          unit: unit,
          defaultColor: color,
        );

        _discoveredMetrics.add(metadata);
        _metricColors[key] = color;
        _metricOnRightAxis[key] = isHighValueOrClockOrPower;

        // Auto-select the first 4 discovered metrics to keep the initial graph clean but active
        _selectedMetrics[key] = _discoveredMetrics.length <= 4;
        newlyDiscovered = true;
      }
    }

    if (newlyDiscovered) {
      // Sort metrics alphabetically by display name to keep the sidebar tidy
      _discoveredMetrics.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
  }

  /// Helper to convert snake_case keys to Title Case (e.g. "cpu0_temp_c" -> "Cpu0 Temp C")
  String _formatKeyName(String key) {
    return key
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  /// Helper to auto-detect units from metric key names
  String _detectUnit(String key) {
    final lower = key.toLowerCase();
    if (lower.endsWith('_c') || lower.contains('temp')) {
      return '°C';
    }
    if (lower.endsWith('_pct') ||
        lower.contains('load') ||
        lower.contains('percent')) {
      return '%';
    }
    if (lower.endsWith('_mhz') ||
        lower.contains('clk') ||
        lower.contains('clock')) {
      return ' MHz';
    }
    if (lower.endsWith('_mw') || lower.contains('power')) {
      return ' mW';
    }
    if (lower.contains('volt') || lower.endsWith('_v')) {
      return ' V';
    }
    if (lower.contains('amp') ||
        lower.contains('current') ||
        lower.endsWith('_a')) {
      return ' A';
    }
    return '';
  }

  /// Stops the telemetry stream
  Future<void> stopStream() async {
    // Close the HTTP client first so any in-flight connection attempt is
    // aborted. Otherwise cancel() deadlocks waiting on a pending send().
    _telemetryService.disconnect();
    await _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }

  /// Clears collected data history (clears the plot) but preserves the metric list and configurations
  void clearData() {
    _dataHistory.clear();
    _totalSampleCount = 0;
    _logs.clear();
    notifyListeners();
  }

  /// Starts recording data for CSV saving by providing an active CsvWriter.
  Future<void> startCsvSaving(CsvWriter writer) async {
    _isSavingCsv = true;
    _activeCsvWriter = writer;

    // Create local copies to prevent ConcurrentModificationError if the stream mutates them during await
    final historyCopy = List<TelemetryData>.from(_dataHistory);
    final metricsCopy = List<MetricMetadata>.from(_discoveredMetrics);

    // Immediately write all existing history to the writer
    for (final data in historyCopy) {
      final List<dynamic> row = [
        DateTime.fromMillisecondsSinceEpoch(data.timestamp).toIso8601String(),
        data.timestamp,
        data.seq,
      ];
      for (final metric in metricsCopy) {
        row.add(data.metrics[metric.key]);
      }
      await _activeCsvWriter?.writeRow(row);
    }

    notifyListeners();
  }

  /// Stops recording data and closes the CsvWriter.
  Future<void> stopCsvSaving() async {
    _isSavingCsv = false;
    await _activeCsvWriter?.close();
    _activeCsvWriter = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _telemetryService.disconnect();
    super.dispose();
  }
}
