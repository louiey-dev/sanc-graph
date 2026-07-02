import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_data.dart';
import '../providers/telemetry_provider.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TelemetryProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;
    final cardColor = isDark ? Colors.grey[900]!.withAlpha(200) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final latestData = provider.dataHistory.isNotEmpty ? provider.dataHistory.last : null;

    // Dynamically categorize discovered metrics based on their units
    final Map<String, List<MetricMetadata>> categorizedMetrics = {
      'Temperatures': provider.discoveredMetrics.where((m) => m.unit == '°C').toList(),
      'System Load': provider.discoveredMetrics.where((m) => m.unit == '%').toList(),
      'Clocks': provider.discoveredMetrics.where((m) => m.unit == ' MHz').toList(),
      'Power': provider.discoveredMetrics.where((m) => m.unit == ' mW').toList(),
      'Other': provider.discoveredMetrics.where((m) => 
        m.unit != '°C' && m.unit != '%' && m.unit != ' MHz' && m.unit != ' mW'
      ).toList(),
    };

    // Filter out categories that are empty
    final activeCategories = categorizedMetrics.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width > 900;

    if (isWide && provider.isSidebarCollapsed) {
      return Card(
        elevation: 4,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white70 : Colors.grey[800],
                ),
                tooltip: 'Expand panel',
                onPressed: () => provider.toggleSidebar(),
              ),
              const Divider(),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Text(
                      'Metrics Selector',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Metrics Selector',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isWide ? Icons.chevron_left : Icons.close,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.grey[800],
                    ),
                    tooltip: isWide ? 'Collapse panel' : 'Close panel',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (isWide) {
                        provider.toggleSidebar();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: provider.discoveredMetrics.isEmpty
                  ? _buildEmptyPlaceholder(isDark)
                  : ListView(
                      children: activeCategories.map((category) {
                        return _buildCategoryGroup(
                          context,
                          category.key,
                          category.value,
                          provider,
                          latestData,
                          isDark,
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[450],
            ),
            const SizedBox(height: 12),
            Text(
              'Awaiting Stream...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the stream or simulation to discover metrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGroup(
    BuildContext context,
    String categoryName,
    List<MetricMetadata> metrics,
    TelemetryProvider provider,
    TelemetryData? latestData,
    bool isDark,
  ) {
    return ExpansionTile(
      title: Text(
        categoryName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
      initiallyExpanded: true,
      dense: true,
      childrenPadding: EdgeInsets.zero,
      children: metrics.map((metric) {
        final isSelected = provider.isMetricSelected(metric.key);
        final color = provider.getMetricColor(metric.key);
        final isOnRightAxis = provider.isMetricOnRightAxis(metric.key);
        
        // Get the latest value for this metric
        final latestVal = latestData?.metrics[metric.key];
        final String valueDisplay = latestVal != null 
            ? '${latestVal.toStringAsFixed(1)}${metric.unit}'
            : 'N/A';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                activeColor: color,
                onChanged: (val) {
                  if (val != null) {
                    provider.toggleMetric(metric.key, val);
                  }
                },
              ),
              // Color Picker Circle
              GestureDetector(
                onTap: () => _showColorPickerDialog(context, provider, metric),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white70 : Colors.black26,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Metric Name and Real-time value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metric.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[350] : Colors.grey[850],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      valueDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        color: latestVal != null 
                            ? (isDark ? Colors.greenAccent[100] : Colors.green[700])
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Axis Selector (L/R Toggle)
              Tooltip(
                message: isOnRightAxis ? 'Assigned to Right Y-Axis (2nd)' : 'Assigned to Left Y-Axis (1st)',
                child: InkWell(
                  onTap: () => provider.toggleMetricAxis(metric.key),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOnRightAxis
                          ? Colors.purple.withValues(alpha: 0.15)
                          : Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isOnRightAxis
                            ? Colors.purple.withValues(alpha: 0.4)
                            : Colors.blue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isOnRightAxis ? 'Right' : 'Left',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isOnRightAxis ? Colors.purpleAccent : Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    TelemetryProvider provider,
    MetricMetadata metric,
  ) {
    final List<Color> pickerColors = [
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Color for ${metric.displayName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pickerColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    provider.updateMetricColor(metric.key, color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: provider.getMetricColor(metric.key) == color
                            ? Colors.white
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: provider.getMetricColor(metric.key) == color
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
