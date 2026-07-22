import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/telemetry_data.dart';
import '../providers/telemetry_provider.dart';

class ChartView extends StatefulWidget {
  const ChartView({super.key});

  @override
  State<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> {
  Offset? _lastPointerPosition;
  DateTime? _lastClickTime;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TelemetryProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;
    final cardColor = isDark ? Colors.grey[900]!.withAlpha(200) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final history = provider.dataHistory;
    if (history.isEmpty) {
      return _buildEmptyState(context, isDark, cardColor, borderColor);
    }

    // Slice visible history window based on maxDisplayPoints
    final totalHistory = history.length;
    final windowSize = min(provider.maxDisplayPoints, totalHistory);
    final startIndex = max(0, totalHistory - windowSize);
    final visibleData = history.sublist(startIndex);

    // Filter out which metrics are selected
    final selectedKeys = provider.discoveredMetrics
        .map((m) => m.key)
        .where((key) => provider.isMetricSelected(key))
        .toList();

    if (selectedKeys.isEmpty) {
      return _buildNoMetricSelectedState(context, isDark, cardColor, borderColor);
    }

    // Separate selected metrics into Left and Right axes
    final leftKeys = selectedKeys.where((k) => !provider.isMetricOnRightAxis(k)).toList();
    final rightKeys = selectedKeys.where((k) => provider.isMetricOnRightAxis(k)).toList();

    // Calculate Base Min/Max for Left Axis
    double leftAutoMin = double.infinity;
    double leftAutoMax = double.negativeInfinity;

    for (final data in visibleData) {
      for (final key in leftKeys) {
        final val = data.metrics[key];
        if (val != null) {
          if (val < leftAutoMin) leftAutoMin = val;
          if (val > leftAutoMax) leftAutoMax = val;
        }
      }
    }

    // Defaults if no left metrics selected or all values are null
    if (leftAutoMin == double.infinity) leftAutoMin = 0.0;
    if (leftAutoMax == double.negativeInfinity) leftAutoMax = 100.0;

    // Add margin padding to Left Axis base range
    double leftAutoRange = leftAutoMax - leftAutoMin;
    if (leftAutoRange == 0) {
      leftAutoRange = leftAutoMax.abs() == 0 ? 2.0 : leftAutoMax.abs() * 0.2;
      leftAutoMin = leftAutoMin - leftAutoRange / 2;
      leftAutoMax = leftAutoMax + leftAutoRange / 2;
    } else {
      leftAutoMin = leftAutoMin - leftAutoRange * 0.08;
      leftAutoMax = leftAutoMax + leftAutoRange * 0.08;
    }
    leftAutoRange = leftAutoMax - leftAutoMin;

    // Apply Y-Zoom and Y-Pan to Left Axis bounds
    final double leftAutoCenter = (leftAutoMin + leftAutoMax) / 2;
    final double leftCenter = leftAutoCenter - (provider.yPanOffset * (leftAutoRange / 2));
    final double leftZoomedRange = leftAutoRange / provider.yZoomFactor;
    double leftMin = leftCenter - leftZoomedRange / 2;
    double leftMax = leftCenter + leftZoomedRange / 2;
    double leftRange = leftMax - leftMin;

    // Calculate Base Min/Max for Right Axis
    double rightAutoMin = double.infinity;
    double rightAutoMax = double.negativeInfinity;

    for (final data in visibleData) {
      for (final key in rightKeys) {
        final val = data.metrics[key];
        if (val != null) {
          if (val < rightAutoMin) rightAutoMin = val;
          if (val > rightAutoMax) rightAutoMax = val;
        }
      }
    }

    // Defaults if no right metrics selected or all values are null
    if (rightAutoMin == double.infinity) rightAutoMin = 0.0;
    if (rightAutoMax == double.negativeInfinity) rightAutoMax = 100.0;

    // Add margin padding to Right Axis base range
    double rightAutoRange = rightAutoMax - rightAutoMin;
    if (rightAutoRange == 0) {
      rightAutoRange = rightAutoMax.abs() == 0 ? 2.0 : rightAutoMax.abs() * 0.2;
      rightAutoMin = rightAutoMin - rightAutoRange / 2;
      rightAutoMax = rightAutoMax + rightAutoRange / 2;
    } else {
      rightAutoMin = rightAutoMin - rightAutoRange * 0.08;
      rightAutoMax = rightAutoMax + rightAutoRange * 0.08;
    }
    rightAutoRange = rightAutoMax - rightAutoMin;

    // Apply Y-Zoom and Y-Pan to Right Axis bounds
    final double rightAutoCenter = (rightAutoMin + rightAutoMax) / 2;
    final double rightCenter = rightAutoCenter - (provider.yPanOffset * (rightAutoRange / 2));
    final double rightZoomedRange = rightAutoRange / provider.yZoomFactor;
    double rightMin = rightCenter - rightZoomedRange / 2;
    double rightMax = rightCenter + rightZoomedRange / 2;
    double rightRange = rightMax - rightMin;

    // Map data points into LineChartBarData
    final List<LineChartBarData> lineBarsData = [];
    final List<String> addedKeys = [];

    // Scale function for Right Axis to Left Axis
    double scaleRightToLeft(double value) {
      if (rightRange == 0) return leftMin + leftRange / 2;
      return leftMin + ((value - rightMin) / rightRange) * leftRange;
    }

    // Helper to build spots
    for (final key in selectedKeys) {
      final isOnRight = provider.isMetricOnRightAxis(key);
      final List<FlSpot> spots = [];

      for (final data in visibleData) {
        final val = data.metrics[key];
        if (val != null) {
          final double yVal = isOnRight ? scaleRightToLeft(val) : val;
          spots.add(FlSpot(data.seq.toDouble(), yVal));
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: provider.getMetricColor(key),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: provider.getMetricColor(key).withValues(alpha: 0.06),
            ),
          ),
        );
        addedKeys.add(key);
      }
    }

    // X-Axis Min/Max calculation with X-Zoom and X-Pan
    final double rawSeqMin = visibleData.first.seq.toDouble();
    final double rawSeqMax = visibleData.last.seq.toDouble();
    double baseSeqSpan = rawSeqMax - rawSeqMin;
    if (baseSeqSpan <= 0) baseSeqSpan = 1.0;

    // Sequence center (shifted backward by xPanOffset)
    final double rawCenter = (rawSeqMin + rawSeqMax) / 2;
    final double seqCenter = rawCenter - provider.xPanOffset;

    // Zoomed sequence span (smaller span = wider horizontal display!)
    final double zoomedSeqSpan = baseSeqSpan / provider.xZoomFactor;
    final double xMin = seqCenter - (zoomedSeqSpan / 2);
    final double xMax = seqCenter + (zoomedSeqSpan / 2);

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxHeight < 280;
          final bool isVeryCompact = constraints.maxHeight < 140;

          if (isVeryCompact) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Graph area too small',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final padding = isCompact
              ? const EdgeInsets.fromLTRB(12, 10, 16, 8)
              : const EdgeInsets.fromLTRB(16, 24, 24, 16);

          return Padding(
            padding: padding,
            child: Column(
              children: [
                if (!isCompact) ...[
                  _buildChartHeader(context, leftKeys, rightKeys, provider, isDark),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: Listener(
                    onPointerDown: (event) {
                      _lastPointerPosition = event.position;
                      final now = DateTime.now();
                      if (_lastClickTime != null &&
                          now.difference(_lastClickTime!) < const Duration(milliseconds: 300)) {
                        provider.resetZoomAndPan();
                        _lastClickTime = null;
                      } else {
                        _lastClickTime = now;
                      }
                    },
                    onPointerMove: (event) {
                      if (_lastPointerPosition != null) {
                        final Offset delta = event.position - _lastPointerPosition!;
                        _lastPointerPosition = event.position;

                        final double dx = delta.dx;
                        final double dy = delta.dy;

                        // 1. Horizontal Drag -> Pan X-axis timeline history
                        if (dx.abs() > 0.2) {
                          final double seqSpanPerPixel = (xMax - xMin) / 400.0;
                          final double deltaSeq = -dx * seqSpanPerPixel;
                          provider.setXPanOffset(provider.xPanOffset + deltaSeq);
                        }

                        // 2. Vertical Drag -> Pan Y-axis viewport height
                        if (dy.abs() > 0.2) {
                          final double currentPan = provider.yPanOffset;
                          provider.setYPanOffset(currentPan + (dy / 200.0));
                        }
                      }
                    },
                    onPointerUp: (_) => _lastPointerPosition = null,
                    onPointerCancel: (_) => _lastPointerPosition = null,
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final double dy = pointerSignal.scrollDelta.dy;
                        final double dx = pointerSignal.scrollDelta.dx;
                        final double delta = dy != 0 ? dy : dx;

                        if (delta != 0) {
                          final pressed = HardwareKeyboard.instance.logicalKeysPressed;
                          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed ||
                              pressed.contains(LogicalKeyboardKey.shift) ||
                              pressed.contains(LogicalKeyboardKey.shiftLeft) ||
                              pressed.contains(LogicalKeyboardKey.shiftRight);

                          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
                              pressed.contains(LogicalKeyboardKey.control) ||
                              pressed.contains(LogicalKeyboardKey.controlLeft) ||
                              pressed.contains(LogicalKeyboardKey.controlRight);

                          if (isShiftPressed || isCtrlPressed || (dy == 0 && dx != 0)) {
                            // Shift + Scroll OR Ctrl + Scroll: Zoom X-axis inside plot area (xZoomFactor)
                            final double currentZoom = provider.xZoomFactor;
                            double nextZoom = delta < 0 ? (currentZoom * 1.25) : (currentZoom / 1.25);
                            nextZoom = nextZoom.clamp(1.0, 50.0);
                            if ((nextZoom - currentZoom).abs() > 0.001) {
                              provider.setXZoomFactor(nextZoom);
                            }
                          } else {
                            // Mouse Scroll alone: Zoom Y-axis inside plot area (yZoomFactor)
                            final double currentZoom = provider.yZoomFactor;
                            double nextZoom = delta < 0 ? (currentZoom * 1.25) : (currentZoom / 1.25);
                            nextZoom = nextZoom.clamp(0.5, 50.0);
                            if ((nextZoom - currentZoom).abs() > 0.001) {
                              provider.setYZoomFactor(nextZoom);
                            }
                          }
                        }
                      }
                    },
                    child: LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      minX: xMin,
                      maxX: xMax,
                      minY: leftMin,
                      maxY: leftMax,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: leftRange / 5,
                        verticalInterval: max(1.0, (xMax - xMin) / 5),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          axisNameWidget: isCompact
                              ? null
                              : Text(
                                  'Sequence (seq)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                          axisNameSize: isCompact ? 0 : 20,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: isCompact ? 16 : 26,
                            interval: max(1.0, (xMax - xMin) / 5).floorToDouble(),
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 4,
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[450] : Colors.grey[655],
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: (leftKeys.isEmpty || isCompact)
                              ? null
                              : Text(
                                  'Left Axis Metrics',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                          axisNameSize: isCompact ? 0 : 20,
                          sideTitles: SideTitles(
                            showTitles: leftKeys.isNotEmpty,
                            reservedSize: isCompact ? 35 : 50,
                            interval: leftRange / 5,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 4,
                                child: Text(
                                  value.toStringAsFixed(leftRange < 5 ? 1 : 0),
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[450] : Colors.grey[655],
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          axisNameWidget: (rightKeys.isEmpty || isCompact)
                              ? null
                              : Text(
                                  'Right Axis Metrics',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                          axisNameSize: isCompact ? 0 : 20,
                          sideTitles: SideTitles(
                            showTitles: rightKeys.isNotEmpty,
                            reservedSize: isCompact ? 35 : 60,
                            interval: leftRange / 5,
                            getTitlesWidget: (value, meta) {
                              if (leftRange == 0 || rightRange == 0) {
                                return const SizedBox.shrink();
                              }
                              final double norm = (value - leftMin) / leftRange;
                              final double unscaled = rightMin + norm * rightRange;
                              final String label = rightRange < 5
                                  ? unscaled.toStringAsFixed(1)
                                  : unscaled.round().toString();
                              return SideTitleWidget(
                                meta: meta,
                                space: 4,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[450] : Colors.grey[655],
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.95),
                          tooltipBorder: BorderSide(color: borderColor, width: 1),
                          maxContentWidth: 220,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              final barIndex = touchedSpot.barIndex;
                              if (barIndex < 0 || barIndex >= addedKeys.length) return null;
                              final key = addedKeys[barIndex];

                              final MetricMetadata metadata = provider.discoveredMetrics.firstWhere((m) => m.key == key);
                              final isOnRight = provider.isMetricOnRightAxis(key);
                              
                              double realVal = touchedSpot.y;
                              if (isOnRight) {
                                realVal = rightMin +
                                    ((touchedSpot.y - leftMin) / (leftMax - leftMin)) *
                                        (rightMax - rightMin);
                              }

                              return LineTooltipItem(
                                '${metadata.displayName}\n',
                                TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${realVal.toStringAsFixed(2)}${metadata.unit}',
                                    style: TextStyle(
                                      color: provider.getMetricColor(key),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              );
                            }).whereType<LineTooltipItem>().toList();
                          },
                        ),
                      ),
                      lineBarsData: lineBarsData,
                    ),
                  ),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, Color cardColor, Color borderColor) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'No Telemetry Data Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure the IP and Port at the top, then click "Connect".\nOr toggle "Simulation" mode to test the UI immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMetricSelectedState(BuildContext context, bool isDark, Color cardColor, Color borderColor) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_box_outline_blank,
                  size: 48,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'No Metrics Selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please select at least one metric from the left sidebar\nto display it on the graph.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartHeader(
    BuildContext context,
    List<String> leftKeys,
    List<String> rightKeys,
    TelemetryProvider provider,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Real-time Data Visualizer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Reset / Live Button (shown when zoomed in, panned Y, or viewing history)
            if (provider.xZoomFactor != 1.0 || provider.yZoomFactor != 1.0 || provider.yPanOffset != 0.0 || provider.xPanOffset > 0)
              InkWell(
                onTap: () => provider.resetZoomAndPan(),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.xPanOffset > 0 ? Icons.play_arrow : Icons.restart_alt,
                        size: 13,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider.xPanOffset > 0 ? 'Jump to Live' : 'Reset View',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // History Offset Badge
            if (provider.xPanOffset > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 13, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'History: -${provider.xPanOffset.round()} pts',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

            // X-Zoom Scale Control Badge
            Tooltip(
              message: 'X-Axis Zoom | Shift+Wheel or Ctrl+Wheel to zoom X-axis | Click [+] / [-] buttons',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.unfold_more_sharp, size: 12, color: Colors.blueAccent),
                    const SizedBox(width: 3),
                    Text(
                      'X-Zoom: ${provider.xZoomFactor.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => provider.setXZoomFactor((provider.xZoomFactor * 1.25).clamp(1.0, 50.0)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.add_circle_outline, size: 13, color: Colors.blueAccent),
                      ),
                    ),
                    InkWell(
                      onTap: () => provider.setXZoomFactor((provider.xZoomFactor / 1.25).clamp(1.0, 50.0)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.remove_circle_outline, size: 13, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Y-Zoom Scale Control Badge
            Tooltip(
              message: 'Y-Axis Height Scale | Mouse Wheel to zoom Y-axis | Click [+] / [-] buttons',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.height, size: 12, color: Colors.purpleAccent),
                    const SizedBox(width: 3),
                    Text(
                      'Y: ${provider.yZoomFactor.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => provider.setYZoomFactor((provider.yZoomFactor * 1.25).clamp(0.5, 50.0)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.add_circle_outline, size: 13, color: Colors.purpleAccent),
                      ),
                    ),
                    InkWell(
                      onTap: () => provider.setYZoomFactor((provider.yZoomFactor / 1.25).clamp(0.5, 50.0)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.remove_circle_outline, size: 13, color: Colors.purpleAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (leftKeys.isNotEmpty)
              _buildAxisIndicator('Left Axis (1st)', Colors.blue, isDark),
            if (rightKeys.isNotEmpty)
              _buildAxisIndicator('Right Axis (2nd)', Colors.purple, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildAxisIndicator(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
