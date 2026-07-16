import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/telemetry_provider.dart';

class LogPanel extends StatefulWidget {
  const LogPanel({super.key});

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  int _lastLogCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _autoScroll) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TelemetryProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;

    // Detect new logs to trigger auto-scroll
    if (provider.logs.length != _lastLogCount) {
      _lastLogCount = provider.logs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final cardColor = isDark ? const Color(0xFF131A2C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C354E) : Colors.grey[300]!;
    final consoleBg = isDark ? const Color(0xFF070B13) : const Color(0xFFF0F2F5);
    final logTextColor = isDark ? Colors.greenAccent[200]! : Colors.green[800]!;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar (always visible)
          InkWell(
            onTap: () => provider.toggleLogPanel(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 18,
                    color: isDark ? Colors.blueAccent[100] : Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Incoming Telemetry Logs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (provider.isConnected ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (provider.isConnected ? Colors.green : Colors.grey).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${provider.logs.length} stored',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: provider.isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // If unfolded, show log controls
                  if (!provider.isLogPanelFolded) ...[
                    // Auto-scroll toggle
                    Tooltip(
                      message: 'Toggle Auto-scroll',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _autoScroll = !_autoScroll;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: _autoScroll
                                ? Colors.blueAccent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _autoScroll
                                  ? Colors.blueAccent.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: _autoScroll
                                    ? (isDark ? Colors.blueAccent[100] : Colors.blueAccent)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Auto',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _autoScroll
                                      ? (isDark ? Colors.blueAccent[100] : Colors.blueAccent)
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Copy All logs button
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy all logs',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () {
                        if (provider.logs.isEmpty) return;
                        final allLogs = provider.logs.join('\n');
                        Clipboard.setData(ClipboardData(text: allLogs));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logs copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // Clear logs button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      tooltip: 'Clear logs',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => provider.clearLogs(),
                    ),
                  ],
                  // Fold / Unfold Arrow
                  Icon(
                    provider.isLogPanelFolded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          // Scrollable log content (visible only when unfolded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: provider.isLogPanelFolded ? 0 : 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: consoleBg,
              border: Border(
                top: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: provider.isLogPanelFolded
                ? const SizedBox.shrink()
                : provider.logs.isEmpty
                    ? Center(
                        child: Text(
                          'No logs yet. Start the stream to view raw JSON packets.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: provider.logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: SelectableText(
                                provider.logs[index],
                                style: TextStyle(
                                  color: logTextColor,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
