// Verifies AROHA can read live telemetry straight from the National Polar
// Data Center portal, with no browser and therefore no CORS in the way.
//
//   dart run tool/ncpor_smoke.dart
//
// Use this to tell a *portal* outage apart from a *CORS* problem: this
// script succeeding while the web build shows "MOCK TELEMETRY" means the
// portal is fine and the app needs --dart-define=NCPOR_PROXY=…
import 'dart:io';

import 'package:aroha_polar/models/ncpor_reading.dart';
import 'package:aroha_polar/services/ncpor_data_source.dart';

Future<void> main() async {
  final source = NporDataSource();
  stdout.writeln('Base URL : ${source.baseUrl}');
  stdout.writeln(
      'Proxy    : ${source.proxyPrefix.isEmpty ? '(none — direct)' : source.proxyPrefix}');
  stdout.writeln('Freshness: ${NporReading.freshFor.inHours}h window');
  stdout.writeln('');

  var failures = 0;

  for (final stationId in NporDataSource.metrics.keys) {
    final reading = await source.fetchReading(stationId);

    final windKt = reading.windSpeedKnots?.toStringAsFixed(1) ?? 'n/a';
    stdout.writeln(stationId);
    stdout.writeln('  status     : ${reading.status}  (${reading.coverageLabel})');
    stdout
        .writeln('  observed   : ${reading.observedLabel}  (${reading.ageLabel} ago)');
    stdout.writeln('  temperature: ${reading.temperatureC ?? 'n/a'} °C'
        '  (24h low ${reading.temperatureMinC?.toStringAsFixed(1) ?? 'n/a'} °C)');
    stdout.writeln('  wind       : $windKt kt'
        '${reading.windMaxKnots != null ? ' (gust ${reading.windMaxKnots!.toStringAsFixed(0)} kt)' : ''}');
    stdout.writeln('  pressure   : ${reading.airPressureHpa ?? 'n/a'} hPa');
    stdout.writeln('  humidity   : ${reading.relativeHumidityPct ?? 'n/a'} %');
    stdout.writeln('  endpoints  : ${reading.endpoints.join(', ')}');
    if (reading.error != null) {
      failures++;
      stdout.writeln('  ERROR      : ${reading.error}');
    }
    stdout.writeln('');
  }

  if (failures > 0) {
    stdout.writeln('$failures station(s) unreachable.');
    // Exit code 0 either way: this is a diagnostic, not a gate.
  } else {
    stdout.writeln('All stations read successfully from the NPDC portal.');
  }
}
