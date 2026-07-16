import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/telemetry_provider.dart';
import 'widgets/chart_view.dart';
import 'widgets/control_panel.dart';
import 'widgets/sidebar.dart';
import 'widgets/log_panel.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TelemetryProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild when the theme changes, not on every telemetry frame.
    final themeMode =
        context.select<TelemetryProvider, ThemeMode>((p) => p.themeMode);

    // Curated Premium Themes
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep slate blue-black
      colorScheme: ColorScheme.dark(
        primary: Colors.blueAccent[200]!,
        secondary: Colors.purpleAccent[200]!,
        surface: const Color(0xFF131A2C),
        error: Colors.redAccent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C253C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF131A2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF2C354E), width: 1),
        ),
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F6F9), // Soft light grey
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.purple,
        surface: Colors.white,
        error: Colors.red,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
    );

    return MaterialApp(
      title: 'Jetson Telemetry Graph',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TelemetryProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.bolt,
              color: isDark ? Colors.yellowAccent : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text(
              'Telemetry Monitor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Quick status badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: Icon(
                provider.isConnected ? Icons.check_circle : Icons.offline_bolt,
                size: 16,
                color: provider.isConnected ? Colors.green : Colors.grey,
              ),
              label: Text(
                provider.isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF131A2C)
                  : Colors.grey[200],
              side: BorderSide(
                color: provider.isConnected
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
      // Use drawer for narrow layouts
      drawer: !isWide
          ? const Drawer(
              width: 300,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 32.0,
                  bottom: 16.0,
                  left: 8.0,
                  right: 8.0,
                ),
                child: Sidebar(),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Error banner if any connection issue occurs
              if (provider.errorMessage != null)
                _buildErrorBanner(context, provider),

              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left sidebar (dynamic width based on collapse state)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: provider.isSidebarCollapsed ? 64 : 280,
                            clipBehavior: Clip.hardEdge,
                            decoration: const BoxDecoration(),
                            child: const Sidebar(),
                          ),
                          const SizedBox(width: 16),
                          // Right content area (Control panel & Chart)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const ControlPanel(),
                                const SizedBox(height: 16),
                                const Expanded(child: ChartView()),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ControlPanel(),
                          const SizedBox(height: 12),
                          // Helper tip to open sidebar on narrow screens
                          _buildSidebarTip(context, isDark),
                          const SizedBox(height: 12),
                          const Expanded(child: ChartView()),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              const LogPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, TelemetryProvider provider) {
    final isDark = provider.themeMode == ThemeMode.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.red[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            onPressed: () =>
                provider.stopStream(), // stops stream & clears error
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTip(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey[900]!.withValues(alpha: 0.4)
            : Colors.blue[50]!,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: isDark ? Colors.blueAccent[100] : Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Swipe from left or tap top-left menu to configure which metrics are visible.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[300] : Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
