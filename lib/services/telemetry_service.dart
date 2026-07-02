import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/telemetry_data.dart';

class TelemetryService {
  http.Client? _client;
  bool _disconnected = false;

  /// Connects to the Jetson telemetry stream and yields [TelemetryData] objects.
  Stream<TelemetryData> connectStream(String ip, int port) async* {
    // Close any previous client
    _client?.close();
    final client = http.Client();
    _client = client;
    _disconnected = false;

    final url = Uri.parse('http://$ip:$port/telemetry');
    final request = http.Request('GET', url)
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache';

    final http.StreamedResponse response;
    try {
      response = await client.send(request);
    } catch (e) {
      // If the user intentionally disconnected, closing the client aborts the
      // in-flight send(). Exit quietly instead of surfacing a connection error.
      if (_disconnected) return;
      throw Exception('Failed to connect to Jetson telemetry server at $ip:$port. '
          'Please verify that the server is running and accessible.');
    }

    if (response.statusCode != 200) {
      throw Exception('Server returned status code ${response.statusCode}');
    }

    final lineStream = response.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lineStream) {
        final data = TelemetryData.fromSseLine(line);
        if (data != null) {
          yield data;
        }
      }
    } catch (e) {
      // A deliberate disconnect force-closes the client, which aborts the
      // in-flight read and surfaces a socket error here. Exit quietly in that
      // case; otherwise propagate the genuine stream failure.
      if (_disconnected) return;
      rethrow;
    }
  }

  /// Closes the active HTTP connection if any.
  void disconnect() {
    _disconnected = true;
    _client?.close();
    _client = null;
  }

  /// Creates a simulated telemetry stream for local testing.
  Stream<TelemetryData> getSimulatedStream() async* {
    int seq = 0;
    final random = Random();

    // Base values for simulation to do a random walk
    double cpu0Temp = 50.0;
    double cpu1Temp = 47.0;
    double gpuTemp = 42.0;
    double socTemp = 45.0;
    double tjTemp = 55.0;

    double cpuLoad = 10.0;
    double gpuLoad = 5.0;

    double cpuClk = 1200.0;
    double gpuClk = 800.0;
    double emcClk = 667.0;

    double pwrCpu = 1500.0;
    double pwrGpu = 800.0;
    double pwrSoc = 1000.0;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      seq++;

      // Apply random walks/fluctuations
      cpu0Temp = (cpu0Temp + (random.nextDouble() - 0.5) * 1.5).clamp(35.0, 85.0);
      cpu1Temp = (cpu1Temp + (random.nextDouble() - 0.5) * 1.5).clamp(35.0, 85.0);
      gpuTemp = (gpuTemp + (random.nextDouble() - 0.5) * 2.0).clamp(30.0, 80.0);
      socTemp = (socTemp + (random.nextDouble() - 0.5) * 1.0).clamp(35.0, 75.0);
      tjTemp = max(cpu0Temp, gpuTemp) + 5.0;

      // Cpu load fluctuates, sometimes spikes
      if (random.nextDouble() > 0.95) {
        cpuLoad = (random.nextDouble() * 50 + 40); // spike
      } else {
        cpuLoad = (cpuLoad + (random.nextDouble() - 0.5) * 8).clamp(2.0, 100.0);
      }

      // Gpu load fluctuates
      if (random.nextDouble() > 0.95) {
        gpuLoad = (random.nextDouble() * 60 + 30); // spike
      } else {
        gpuLoad = (gpuLoad + (random.nextDouble() - 0.5) * 5).clamp(0.0, 100.0);
      }

      // Clocks scale roughly with load
      cpuClk = (1000.0 + (cpuLoad / 100.0) * 1200.0 + (random.nextDouble() - 0.5) * 50).clamp(1000.0, 2200.0);
      gpuClk = (500.0 + (gpuLoad / 100.0) * 800.0 + (random.nextDouble() - 0.5) * 30).clamp(500.0, 1300.0);
      emcClk = (667.0 + (gpuLoad / 100.0) * 400.0).clamp(667.0, 1600.0);

      // Power scales with load and clock
      pwrCpu = (500.0 + (cpuLoad / 100.0) * 4500.0 + (random.nextDouble() - 0.5) * 100).clamp(300.0, 6000.0);
      pwrGpu = (200.0 + (gpuLoad / 100.0) * 5000.0 + (random.nextDouble() - 0.5) * 100).clamp(100.0, 7000.0);
      pwrSoc = (400.0 + (random.nextDouble() - 0.5) * 50).clamp(300.0, 1500.0);
      double pwrTotal = pwrCpu + pwrGpu + pwrSoc + 500.0; // some static board power

      final Map<String, double?> simulatedMetrics = {
        'cpu0_temp_c': cpu0Temp,
        'cpu1_temp_c': cpu1Temp,
        'gpu_temp_c': random.nextDouble() > 0.1 ? gpuTemp : null, // simulate occasional nulls
        'soc_temp_c': socTemp,
        'tj_temp_c': tjTemp,
        'cpu_load_pct': cpuLoad,
        'core0_load_pct': (cpuLoad * 0.8 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core1_load_pct': (cpuLoad * 0.9 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core2_load_pct': (cpuLoad * 0.7 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core3_load_pct': (cpuLoad * 0.6 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core4_load_pct': (cpuLoad * 0.5 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core5_load_pct': (cpuLoad * 0.4 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core6_load_pct': (cpuLoad * 0.3 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'core7_load_pct': (cpuLoad * 0.2 + random.nextDouble() * 10).clamp(0.0, 100.0),
        'gpu_load_pct': random.nextDouble() > 0.15 ? gpuLoad : null,
        'cpu_clk_mhz': cpuClk,
        'gpu_clk_mhz': gpuClk,
        'emc_clk_mhz': emcClk,
        'pwr_cpu_mw': pwrCpu,
        'pwr_gpu_mw': pwrGpu,
        'pwr_soc_mw': pwrSoc,
        'pwr_total_mw': pwrTotal,
      };

      yield TelemetryData(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        seq: seq,
        metrics: simulatedMetrics,
      );
    }
  }
}
