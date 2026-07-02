import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/telemetry_data.dart';
import '../providers/telemetry_provider.dart';

class ChartView extends StatelessWidget {
  const ChartView({super.key});

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

    // Slice history to show only the last maxDisplayPoints
    final startIndex = max(0, history.length - provider.maxDisplayPoints);
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

    // Calculate Min/Max for Left Axis
    double leftMin = double.infinity;
    double leftMax = double.negativeInfinity;

    for (final data in visibleData) {
      for (final key in leftKeys) {
        final val = data.metrics[key];
        if (val != null) {
          if (val < leftMin) leftMin = val;
          if (val > leftMax) leftMax = val;
        }
      }
    }

    // Defaults if no left metrics selected or all values are null
    if (leftMin == double.infinity) leftMin = 0.0;
    if (leftMax == double.negativeInfinity) leftMax = 100.0;
    
    // Add padding to Left Axis
    double leftRange = leftMax - leftMin;
    if (leftRange == 0) leftRange = 1.0;
    leftMin = (leftMin - leftRange * 0.08).clamp(double.negativeInfinity, double.infinity);
    leftMax = leftMax + leftRange * 0.08;

    // Calculate Min/Max for Right Axis
    double rightMin = double.infinity;
    double rightMax = double.negativeInfinity;

    for (final data in visibleData) {
      for (final key in rightKeys) {
        final val = data.metrics[key];
        if (val != null) {
          if (val < rightMin) rightMin = val;
          if (val > rightMax) rightMax = val;
        }
      }
    }

    // Defaults if no right metrics selected or all values are null
    if (rightMin == double.infinity) rightMin = 0.0;
    if (rightMax == double.negativeInfinity) rightMax = 1000.0;

    // Add padding to Right Axis
    double rightRange = rightMax - rightMin;
    if (rightRange == 0) rightRange = 10.0;
    rightMin = (rightMin - rightRange * 0.08).clamp(0.0, double.infinity); // Power/Clock shouldn't be negative
    rightMax = rightMax + rightRange * 0.08;

    // Map data points into LineChartBarData
    final List<LineChartBarData> lineBarsData = [];
    final List<String> addedKeys = [];

    // Scale function for Right Axis to Left Axis
    double scaleRightToLeft(double value) {
      if (rightMax == rightMin) return leftMin + (leftMax - leftMin) / 2;
      return leftMin + ((value - rightMin) / (rightMax - rightMin)) * (leftMax - leftMin);
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

    // X-Axis Min/Max
    final double xMin = visibleData.first.seq.toDouble();
    final double xMax = visibleData.last.seq.toDouble();

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: Column(
          children: [
            // Chart Header / Legend summary
            _buildChartHeader(context, leftKeys, rightKeys, provider, isDark),
            const SizedBox(height: 16),
            // The Graph
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: xMin,
                  maxX: xMax,
                  minY: leftMin,
                  maxY: leftMax,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (leftMax - leftMin) / 5,
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
                    // Top titles: hide
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    // Bottom titles: Sequence (X-Axis)
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Sequence (seq)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      axisNameSize: 20,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: max(1.0, (xMax - xMin) / 5).floorToDouble(),
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: isDark ? Colors.grey[450] : Colors.grey[655],
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Left titles: Left Y-Axis metrics
                    leftTitles: AxisTitles(
                      axisNameWidget: leftKeys.isNotEmpty
                          ? Text(
                              'Left Axis Metrics',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            )
                          : null,
                      axisNameSize: 20,
                      sideTitles: SideTitles(
                        showTitles: leftKeys.isNotEmpty,
                        reservedSize: 50,
                        interval: leftRange / 5,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                color: isDark ? Colors.grey[450] : Colors.grey[655],
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Right titles: Right Y-Axis metrics (unscaled display)
                    rightTitles: AxisTitles(
                      axisNameWidget: rightKeys.isNotEmpty
                          ? Text(
                              'Right Axis Metrics',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            )
                          : null,
                      axisNameSize: 20,
                      sideTitles: SideTitles(
                        showTitles: rightKeys.isNotEmpty,
                        reservedSize: 60,
                        interval: leftRange / 5,
                        getTitlesWidget: (value, meta) {
                          // Unscale the value from Left axis range back to Right axis range
                          double unscaled = rightMin +
                              ((value - leftMin) / (leftMax - leftMin)) *
                                  (rightMax - rightMin);
                          
                          // Handle negative values due to padding
                          if (unscaled < 0) unscaled = 0;

                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              unscaled.toStringAsFixed(0),
                              style: TextStyle(
                                color: isDark ? Colors.grey[450] : Colors.grey[655],
                                fontSize: 10,
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
                          
                          // Unscale if it's on the right axis
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
          ],
        ),
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 80,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No Telemetry Data Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure the IP and Port at the top, then click "Connect".\nOr toggle "Simulation" mode to test the UI immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_box_outline_blank,
                size: 80,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No Metrics Selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select at least one metric from the left sidebar\nto display it on the graph.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
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
        // Simple axis allocation indicator
        Wrap(
          spacing: 8,
          children: [
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
