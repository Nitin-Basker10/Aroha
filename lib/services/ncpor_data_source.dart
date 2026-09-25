import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ncpor_reading.dart';

/// Reads live station telemetry from the National Polar Data Center portal
/// (https://data.ncpor.res.in) and normalises it for [PolarDataService].
///
/// ## How the source works
///
/// There is no JSON API. Each metric page embeds a JavaScript assignment:
///
/// ```js
/// window.onload = function() {
///   d1 = "[{\"date\":\"2026-09-20 23:59:00\",\"temp\":-22.8}, …]";
/// ```
///
/// so we extract the string literal, unescape it, and `jsonDecode` it.
/// `himadri/ap` omits the `var` keyword, hence the `\b` boundary in the
/// matcher rather than a `var d1` literal.
///
/// ## CORS
///
/// The portal sends **no** `Access-Control-*` headers (verified: OPTIONS
/// returns 200 with none), so a browser build cannot fetch it directly.
/// Point `NCPOR_PROXY` at a same-origin reverse proxy at build time:
///
/// ```
/// flutter run --dart-define=NCPOR_PROXY=https://your.host/npdc-proxy?url=
/// ```
///
/// The prefix receives the percent-encoded target URL. Android and
/// Windows are unaffected — they make the request directly. When the
/// fetch fails for any reason this class returns a reading carrying an
/// [NporReading.error] instead of throwing, so the app stays offline-first.
class NporDataSource {
  NporDataSource({
    http.Client? client,
    String? baseUrl,
    String? proxyPrefix,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl ?? defaultBaseUrl,
       proxyPrefix = proxyPrefix ?? const String.fromEnvironment('NCPOR_PROXY');

  static const String defaultBaseUrl = 'https://data.ncpor.res.in';

  static const Duration defaultTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Duration timeout;

  /// Origin of the NPDC portal, overridable for tests/proxies.
  final String baseUrl;

  /// Optional reverse-proxy prefix; see class docs.
  final String proxyPrefix;

  /// A single portal metric: which page to read, which JSON field holds
  /// the value, and which canonical parameter it maps to.
  ///
  /// Note the per-station path quirks: Bharati's wind lives at `ws` (not
  /// `wind`), and Himadri's pressure field is named `airpres` (not `ap`).
  /// Himadri publishes no wind sensor at all, so there is no wind spec.
  static const Map<String, List<NporMetricSpec>> metrics = {
    'maitri': [
      NporMetricSpec('temp', 'temp', NporReading.paramTemp),
      NporMetricSpec('wind', 'wind', NporReading.paramWind),
      NporMetricSpec('ap', 'ap', NporReading.paramPressure),
      NporMetricSpec('rh', 'rh', NporReading.paramHumidity),
    ],
    'bharati': [
      NporMetricSpec('temp', 'temp', NporReading.paramTemp),
      NporMetricSpec('ws', 'wind', NporReading.paramWind),
      NporMetricSpec('ap', 'ap', NporReading.paramPressure),
      NporMetricSpec('rh', 'rh', NporReading.paramHumidity),
    ],
    'himadri': [
      NporMetricSpec('temp', 'temp', NporReading.paramTemp),
      NporMetricSpec('ap', 'airpres', NporReading.paramPressure),
      NporMetricSpec('rh', 'rh', NporReading.paramHumidity),
    ],
  };

  static bool supports(String stationId) => metrics.containsKey(stationId);

  /// Fetches and parses every parameter for [stationId].
  ///
  /// Never throws. A station with no reachable metrics yields a reading
  /// with `sampleCount == 0` and a non-null [NporReading.error].
  Future<NporReading> fetchReading(String stationId) async {
    final fetchedAt = DateTime.now();
    final specs = metrics[stationId];
    if (specs == null) {
      return NporReading(
        stationId: stationId,
        fetchedAt: fetchedAt,
        error: 'Station not covered by the NPDC portal',
      );
    }

    DateTime? observedAt;
    double? tempC, tempMinC;
    double? windMs, windMaxMs;
    double? pressureHpa, humidityPct;
    final endpoints = <String>[];
    final failures = <String>[];
    var parsed = 0;

    // `String.trimRight()` takes no arguments, so strip trailing slashes
    // with an explicit pattern instead.
    final root = baseUrl.replaceFirst(RegExp(r'/+$'), '');

    // Sequential on purpose: this is a public government portal, so we
    // avoid hammering it with four parallel requests on every poll.
    for (final spec in specs) {
      final path = '/$stationId/${spec.path}';
      final (body, error) = await _get('$root$path');
      if (body == null) {
        failures.add('$path ${error ?? 'unreachable'}');
        continue;
      }

      final rows = parseD1(body);
      if (rows.isEmpty) {
        failures.add('$path empty payload');
        continue;
      }

      // Latest row that actually carries this field, scanning backwards so
      // a gap in one parameter does not hide newer samples behind it.
      Map<String, dynamic>? latest;
      for (var i = rows.length - 1; i >= 0; i--) {
        if (rows[i][spec.field] is num) {
          latest = rows[i];
          break;
        }
      }
      if (latest == null) {
        failures.add('$path missing field "${spec.field}"');
        continue;
      }

      final at = parseNporDate(latest['date']?.toString());
      final value = (latest[spec.field] as num).toDouble();
      endpoints.add(path);
      parsed++;

      if (at != null && (observedAt == null || at.isAfter(observedAt))) {
        observedAt = at;
      }

      switch (spec.param) {
        case NporReading.paramTemp:
          tempC = value;
          tempMinC = _minOver(rows, spec.field);
        case NporReading.paramWind:
          windMs = value;
          windMaxMs = _maxOver(rows, spec.field);
        case NporReading.paramPressure:
          pressureHpa = value;
        case NporReading.paramHumidity:
          humidityPct = value;
      }
    }

    return NporReading(
      stationId: stationId,
      fetchedAt: fetchedAt,
      observedAt: observedAt,
      temperatureC: tempC,
      windSpeedMs: windMs,
      airPressureHpa: pressureHpa,
      relativeHumidityPct: humidityPct,
      temperatureMinC: tempMinC,
      windMaxMs: windMaxMs,
      sampleCount: parsed,
      endpoints: endpoints,
      error: parsed == 0 ? failures.join('; ') : null,
    );
  }

  // ---------------------------------------------------------------------
  // Parsing — static and dependency-free so tests can exercise the exact
  // code the app runs, without touching the network.
  // ---------------------------------------------------------------------

  /// Extracts the JS string literal assigned to [varName] (e.g. `d1`),
  /// honouring backslash escapes. Returns null when there is no such
  /// assignment or the literal is unterminated.
  static String? extractJsStringLiteral(String source, String varName) {
    final match = RegExp('\\b$varName\\s*=\\s*"').firstMatch(source);
    if (match == null) return null;

    final buffer = StringBuffer();
    for (var i = match.end; i < source.length; i++) {
      final ch = source[i];
      if (ch == r'\' && i + 1 < source.length) {
        buffer
          ..write(ch)
          ..write(source[i + 1]);
        i++;
        continue;
      }
      if (ch == '"') return buffer.toString();
      buffer.write(ch);
    }
    return null; // unterminated literal
  }

  /// Fallback for pages that assign a raw array instead of a string:
  /// `d1 = [{"date":…}]`. The payload never nests arrays, so the first
  /// closing bracket terminates it.
  static String? extractRawJsonArray(String source, String varName) {
    final match = RegExp(
      '\\b$varName\\s*=\\s*(\\[[\\s\\S]*?\\])\\s*;',
    ).firstMatch(source);
    return match?.group(1);
  }

  /// Single-pass unescaper for the sequences NPDC actually emits.
  static String unescapeJs(String raw) {
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch != r'\' || i + 1 >= raw.length) {
        buffer.write(ch);
        continue;
      }
      i++;
      switch (raw[i]) {
        case 'n':
          buffer.write('\n');
        case 'r':
          buffer.write('\r');
        case 't':
          buffer.write('\t');
        case 'u':
          if (i + 4 < raw.length) {
            final code = int.tryParse(raw.substring(i + 1, i + 5), radix: 16);
            if (code != null) {
              buffer.writeCharCode(code);
              i += 4;
              break;
            }
          }
          buffer.write(raw[i]);
        default:
          // \" \\ \/ and friends — the escape drops, the char survives.
          buffer.write(raw[i]);
      }
    }
    return buffer.toString();
  }

  /// Parses an NPDC page into its sample rows. Empty list when the page
  /// carries no usable `d1` payload.
  static List<Map<String, dynamic>> parseD1(String source) {
    final literal =
        extractJsStringLiteral(source, 'd1') ??
        extractRawJsonArray(source, 'd1');
    if (literal == null) return const [];

    final decoded = jsonDecode(unescapeJs(literal));
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// NPDC writes `2026-09-20 23:59:00`; [DateTime.parse] needs the `T`
  /// separator, so normalise before parsing.
  static DateTime? parseNporDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final iso = value.contains('T') ? value : value.replaceFirst(' ', 'T');
    return DateTime.tryParse(iso);
  }

  /// Metres/second → knots, matching `Station.windSpeed`'s unit.
  static double msToKnots(double metresPerSecond) =>
      metresPerSecond * NporReading.knotsPerMetrePerSecond;

  // ---------------------------------------------------------------------

  double? _minOver(List<Map<String, dynamic>> rows, String field) {
    double? min;
    for (final row in rows) {
      final v = row[field];
      if (v is num && (min == null || v < min)) min = v.toDouble();
    }
    return min;
  }

  double? _maxOver(List<Map<String, dynamic>> rows, String field) {
    double? max;
    for (final row in rows) {
      final v = row[field];
      if (v is num && (max == null || v > max)) max = v.toDouble();
    }
    return max;
  }

  Future<(String?, String?)> _get(String url) async {
    final target = proxyPrefix.isEmpty
        ? url
        : '$proxyPrefix${Uri.encodeComponent(url)}';
    try {
      final response = await _client.get(Uri.parse(target)).timeout(timeout);
      if (response.statusCode != 200) {
        return (null, 'HTTP ${response.statusCode}');
      }
      return (response.body, null);
    } on Exception catch (e) {
      // Typically a CORS failure or DNS/socket error on web. Surfaced on
      // the reading so the UI can say "mock telemetry" honestly.
      return (null, e.runtimeType.toString());
    }
  }
}

/// One portal metric path (see [NporDataSource.metrics]).
class NporMetricSpec {
  final String path;
  final String field;
  final String param;

  const NporMetricSpec(this.path, this.field, this.param);
}
