import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/telemetry_provider.dart';
import '../utils/csv_saver.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TelemetryProvider _provider;
  bool _wasSavingCsv = false;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<TelemetryProvider>(context, listen: false);
    _ipController = TextEditingController(text: _provider.ip);
    _portController = TextEditingController(text: _provider.port.toString());
    _wasSavingCsv = _provider.isSavingCsv;
    _provider.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    // Use the cached reference: looking up an ancestor via context in dispose()
    // is unsafe once the element has been deactivated.
    _provider.removeListener(_onProviderChange);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onProviderChange() {
    if (_wasSavingCsv && !_provider.isSavingCsv) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV saving stopped and finalized.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    _wasSavingCsv = _provider.isSavingCsv;
  }

  void _handleConnectToggle(TelemetryProvider provider) {
    if (provider.isConnected || provider.isConnecting) {
      provider.stopStream();
    } else {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 8765;
      provider.setConnectionSettings(ip, port);
      provider.startStream();
    }
  }

  Future<void> _handleSaveCsv(TelemetryProvider provider) async {
    if (provider.isSavingCsv) {
      // Stop saving CSV and close stream
      await provider.stopCsvSaving();
    } else {
      // Start saving CSV - prompt user for destination file immediately
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final fileName = 'jetson_telemetry_$timestamp.csv';

      // Header definition
      final List<String> header = ['ISO_Timestamp', 'Epoch_ms', 'Sequence'];
      for (final metric in provider.discoveredMetrics) {
        header.add('${metric.displayName}${metric.unit.isNotEmpty ? ' (${metric.unit.trim()})' : ''}');
      }

      final writer = await createCsvWriter(
        fileName: fileName,
        header: header,
        context: context,
      );

      if (writer == null) {
        // User cancelled the file picker dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save cancelled.'),
              backgroundColor: Colors.grey,
            ),
          );
        }
        return;
      }

      // Start saving CSV (recording to the open stream/writer)
      await provider.startCsvSaving(writer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV recording started...'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TelemetryProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;
    final cardColor = isDark ? Colors.grey[900]!.withAlpha(200) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Left side: Connection Settings
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status indicator dot
                _buildStatusIndicator(provider),
                const SizedBox(width: 12),
                // IP Address input
                SizedBox(
                  width: 140,
                  height: 40,
                  child: TextField(
                    controller: _ipController,
                    enabled: !provider.isConnected && !provider.isConnecting,
                    decoration: InputDecoration(
                      labelText: 'IP Address',
                      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // Port input
                SizedBox(
                  width: 80,
                  height: 40,
                  child: TextField(
                    controller: _portController,
                    enabled: !provider.isConnected && !provider.isConnecting,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Port',
                      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                // Connect/Disconnect Button
                _buildConnectButton(provider),
              ],
            ),

            // Middle section: Control actions (Clear, Save, Max Points)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear button
                OutlinedButton.icon(
                  onPressed: provider.dataHistory.isEmpty ? null : () => provider.clearData(),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Save CSV button
                ElevatedButton.icon(
                  onPressed: (provider.isSavingCsv || provider.isConnected || provider.dataHistory.isNotEmpty)
                      ? () => _handleSaveCsv(provider)
                      : null,
                  icon: Icon(
                    provider.isSavingCsv ? Icons.stop : Icons.save_alt,
                    size: 18,
                  ),
                  label: Text(provider.isSavingCsv ? 'Stop CSV' : 'Save CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.isSavingCsv ? Colors.redAccent : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 16),
                // Max points slider or selection
                Text(
                  'Points: ${provider.maxDisplayPoints}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
                SizedBox(
                  width: 130, // Increased width for the larger range
                  height: 30,
                  child: Slider(
                    value: provider.maxDisplayPoints.toDouble(),
                    min: 20,
                    max: 5000,
                    label: provider.maxDisplayPoints.toString(),
                    onChanged: (val) => provider.setMaxDisplayPoints(val.round()),
                  ),
                ),
              ],
            ),

            // Right section: Toggles (Theme, Stats)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Theme toggle
                IconButton(
                  onPressed: () => provider.toggleTheme(),
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: isDark ? Colors.amber : Colors.indigo,
                  ),
                  tooltip: 'Toggle Theme',
                ),
                const SizedBox(width: 8),
                // Data count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Samples: ${provider.totalSampleCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.greenAccent : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(TelemetryProvider provider) {
    Color color = Colors.red;
    String tooltip = 'Disconnected';
    bool pulse = false;

    if (provider.isConnected) {
      color = Colors.green;
      tooltip = 'Connected';
    } else if (provider.isConnecting) {
      color = Colors.orange;
      tooltip = 'Connecting...';
      pulse = true;
    }

    Widget dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );

    if (pulse) {
      dot = _PulsingWidget(child: dot);
    }

    return Tooltip(
      message: tooltip,
      child: dot,
    );
  }

  Widget _buildConnectButton(TelemetryProvider provider) {
    final bool isActive = provider.isConnected || provider.isConnecting;
    final Color btnColor = isActive ? Colors.deepOrange : Colors.green;
    final IconData icon = isActive ? Icons.stop : Icons.play_arrow;
    final String text = isActive ? 'Disconnect' : 'Connect';

    return ElevatedButton.icon(
      onPressed: provider.isConnecting && !provider.isConnected
          ? () => provider.stopStream()
          : () => _handleConnectToggle(provider),
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _PulsingWidget extends StatefulWidget {
  final Widget child;
  const _PulsingWidget({required this.child});

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}
