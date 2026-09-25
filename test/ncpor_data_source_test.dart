import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aroha_polar/models/ncpor_reading.dart';
import 'package:aroha_polar/services/ncpor_data_source.dart';

/// Realistic NPDC page: `var d1 = "…"` with escaped quotes.
const _maitriTempPage = r'''
<html><head><title>Maitri: Temperature</title></head><body>
<script>
window.onload = function () {
    var d1 = "[{\"date\":\"2026-09-21 23:57:00\",\"temp\":-21.4},{\"date\":\"2026-09-21 23:58:00\",\"temp\":-20.7},{\"date\":\"2026-09-21 23:59:00\",\"temp\":-20.67}]";
    var chartData1 = d1.map(function(item) {
        return { x: parseDate(item.date), y: item.temp };
    });
    chart.render();
}
</script></body></html>
''';

/// `himadri/ap` assigns `d1` with no `var` keyword and names the field
/// `airpres` rather than `ap`.
const _himadriApPage = r'''
<script>
window.onload = function() {
    d1 = "[{\"date\":\"2026-09-21 23:54:00\",\"airpres\":1004.10},{\"date\":\"2026-09-21 23:55:28\",\"airpres\":1005.53}]";
}
</script>
''';

const _maitriWindPage = r'''
<script>
var d1 = "[{\"date\":\"2026-09-21 23:58:00\",\"wind\":12.2},{\"date\":\"2026-09-21 23:59:00\",\"wind\":14.0}]";
</script>
''';

const _maitriRhPage = r'''
<script>
var d1 = "[{\"date\":\"2026-09-21 23:59:00\",\"rh\":56.08}]";
</script>
''';

const _maitriApPage = r'''
<script>
var d1 = "[{\"date\":\"2026-09-21 23:59:00\",\"ap\":943.80}]";
</script>
''';

/// Serves fixture pages by path; anything else 404s.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._pages);

  final Map<String, String> _pages;

  /// Paths requested, so proxy/URL assertions can inspect them.
  final List<Uri> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final page = _pages[request.url.path];
    if (page == null) {
      return http.StreamedResponse(
        Stream.fromIterable([http.Response('not found', 404).bodyBytes]),
        404,
      );
    }
    return http.StreamedResponse(
      Stream.fromIterable([http.Response(page, 200).bodyBytes]),
      200,
    );
  }
}

void main() {
  group('NPDC page parsing', () {
    test('extracts a var-declared d1 literal and ignores data1 reads', () {
      final literal = NporDataSource.extractJsStringLiteral(
        _maitriTempPage,
        'd1',
      );
      expect(literal, isNotNull);
      expect(literal, startsWith(r'[{\"date\"'));
      // Must not have latched onto `chartData1` further down the page.
      expect(literal, isNot(contains('chartData1')));
    });

    test('extracts d1 when the var keyword is omitted', () {
      final rows = NporDataSource.parseD1(_himadriApPage);
      expect(rows, hasLength(2));
      expect(rows.last['airpres'], 1005.53);
    });

    test('parseD1 unescapes quotes and yields typed rows', () {
      final rows = NporDataSource.parseD1(_maitriTempPage);
      expect(rows, hasLength(3));
      expect(rows.first['date'], '2026-09-21 23:57:00');
      expect(rows.last['temp'], -20.67);
      expect(rows.last['temp'], isA<double>());
    });

    test('parseD1 returns empty for a page with no payload', () {
      expect(
        NporDataSource.parseD1('<html><body>nothing here</body></html>'),
        isEmpty,
      );
    });

    test('handles a raw (unstringified) JSON array fallback', () {
      const page =
          r'script>d1 = [{"date":"2026-09-21 23:59:00","temp":-1.5}];</script';
      final rows = NporDataSource.parseD1(page);
      expect(rows, hasLength(1));
      expect(rows.single['temp'], -1.5);
    });

    test('unescapeJs handles escapes beyond quotes', () {
      expect(NporDataSource.unescapeJs(r'a\"b\\c\nd'), 'a"b\\c\nd');
      expect(NporDataSource.unescapeJs(r'A'), 'A');
    });

    test('parseNporDate normalises the space separator', () {
      final parsed = NporDataSource.parseNporDate('2026-09-20 23:59:00');
      expect(parsed, DateTime(2026, 9, 20, 23, 59));
      expect(NporDataSource.parseNporDate(''), isNull);
      expect(NporDataSource.parseNporDate(null), isNull);
      expect(NporDataSource.parseNporDate('not a date'), isNull);
    });
  });

  group('Unit normalisation', () {
    test('converts m/s to the knots the Station model documents', () {
      // 10 m/s ≈ 19.44 kt.
      expect(NporDataSource.msToKnots(10), closeTo(19.4384, 0.0001));
      expect(NporDataSource.msToKnots(0), 0);
    });

    test('NporReading.windSpeedKnots matches the converter', () {
      final reading = NporReading(
        stationId: 'maitri',
        windSpeedMs: 14.0,
        fetchedAt: DateTime(2026, 9, 22),
      );
      expect(reading.windSpeedKnots, closeTo(27.21, 0.01));
    });

    test('a station with no anemometer reports null, not zero', () {
      final reading = NporReading(
        stationId: 'himadri',
        fetchedAt: DateTime(2026, 9, 22),
      );
      expect(reading.windSpeedKnots, isNull);
      expect(reading.windSpeedMs, isNull);
    });
  });

  group('Freshness and status', () {
    NporReading readingAt(DateTime? observedAt, {int samples = 1}) =>
        NporReading(
          stationId: 'maitri',
          observedAt: observedAt,
          temperatureC: observedAt == null ? null : -20.0,
          sampleCount: samples,
          fetchedAt: DateTime.now(),
        );

    test('no samples → unavailable, never LIVE', () {
      expect(readingAt(null).status, NporTelemetryStatus.unavailable);
      expect(
        readingAt(DateTime.now(), samples: 0).status,
        NporTelemetryStatus.unavailable,
      );
    });

    test('recent samples are live', () {
      final r = readingAt(DateTime.now().subtract(const Duration(hours: 2)));
      expect(r.status, NporTelemetryStatus.live);
      expect(r.isStale, isFalse);
    });

    test('samples past the freshness window are stale', () {
      final r = readingAt(DateTime.now().subtract(const Duration(hours: 30)));
      expect(r.status, NporTelemetryStatus.stale);
      expect(r.isStale, isTrue);
    });

    test('verdict is identical under either plausible source timezone', () {
      // Portal timestamps have no declared zone. Observed lag is ~5h if
      // they are UTC and ~10h if local — both must classify the same way,
      // otherwise the status is an artefact of a timezone guess.
      for (final lag in [const Duration(hours: 5), const Duration(hours: 10)]) {
        final r = readingAt(DateTime.now().subtract(lag));
        expect(
          r.status,
          NporTelemetryStatus.live,
          reason: 'lag $lag should read as live',
        );
      }
    });

    test('age never reports a future timestamp as negative', () {
      final r = readingAt(DateTime.now().add(const Duration(hours: 3)));
      expect(r.age, Duration.zero);
      expect(r.status, NporTelemetryStatus.live);
    });

    test('labels expose the real observation time and lag', () {
      final r = readingAt(DateTime(2026, 9, 21, 23, 59));
      expect(r.observedLabel, '21 Sep 23:59');
      expect(r.ageLabel, isNot(equals('—')));
      expect(r.coverageLabel, '1/4 params');
      expect(readingAt(null).observedLabel, '—');
    });
  });

  group('fetchReading over HTTP', () {
    Map<String, String> maitriPages() => {
      '/maitri/temp': _maitriTempPage,
      '/maitri/wind': _maitriWindPage,
      '/maitri/ap': _maitriApPage,
      '/maitri/rh': _maitriRhPage,
    };

    test('assembles all four parameters for Maitri', () async {
      final client = _FakeClient(maitriPages());
      final source = NporDataSource(
        client: client,
        baseUrl: 'https://npdc.test',
      );

      final reading = await source.fetchReading('maitri');

      expect(reading.error, isNull);
      expect(reading.sampleCount, 4);
      expect(reading.temperatureC, -20.67);
      expect(reading.windSpeedMs, 14.0);
      expect(reading.airPressureHpa, 943.80);
      expect(reading.relativeHumidityPct, 56.08);
      expect(reading.observedAt, DateTime(2026, 9, 21, 23, 59));
      expect(reading.hasData, isTrue);
      // Wind converted for display, min/max derived from the window.
      expect(reading.windSpeedKnots, closeTo(27.21, 0.01));
      expect(reading.temperatureMinC, -21.4);
      expect(reading.windMaxKnots, closeTo(27.21, 0.01));
      expect(client.requests, hasLength(4));
    });

    test('Himadri omits wind rather than reporting a false calm', () async {
      final client = _FakeClient({
        '/himadri/temp': _maitriTempPage,
        '/himadri/ap': _himadriApPage,
        '/himadri/rh': _maitriRhPage,
      });
      final source = NporDataSource(
        client: client,
        baseUrl: 'https://npdc.test',
      );

      final reading = await source.fetchReading('himadri');

      expect(reading.sampleCount, 3);
      expect(reading.windSpeedMs, isNull);
      expect(reading.windSpeedKnots, isNull);
      expect(reading.airPressureHpa, 1005.53);
      // Never a wind request for a station with no anemometer.
      expect(client.requests.any((u) => u.path.contains('wind')), isFalse);
    });

    test('unreachable portal yields an error, not an exception', () async {
      final client = _FakeClient(const {});
      final source = NporDataSource(
        client: client,
        baseUrl: 'https://npdc.test',
      );

      final reading = await source.fetchReading('maitri');

      expect(reading.sampleCount, 0);
      expect(reading.error, isNotNull);
      expect(reading.status, NporTelemetryStatus.unavailable);
      expect(reading.hasData, isFalse);
    });

    test('a station outside the portal is rejected up front', () async {
      final client = _FakeClient(const {});
      final source = NporDataSource(
        client: client,
        baseUrl: 'https://npdc.test',
      );

      final reading = await source.fetchReading('gangotri');

      expect(NporDataSource.supports('gangotri'), isFalse);
      expect(reading.error, contains('not covered'));
      expect(client.requests, isEmpty);
    });

    test('all three app stations are covered', () {
      expect(NporDataSource.supports('maitri'), isTrue);
      expect(NporDataSource.supports('bharati'), isTrue);
      expect(NporDataSource.supports('himadri'), isTrue);
    });

    test('Bharati wind is read from its ws path', () {
      final bharati = NporDataSource.metrics['bharati']!;
      final wind = bharati.firstWhere((m) => m.param == NporReading.paramWind);
      expect(wind.path, 'ws');
      expect(wind.field, 'wind');
    });

    test('requests go through the configured CORS proxy', () async {
      final client = _FakeClient(maitriPages());
      final source = NporDataSource(
        client: client,
        baseUrl: 'https://npdc.test',
        proxyPrefix: 'https://proxy.test/?url=',
      );

      await source.fetchReading('maitri');

      final first = client.requests.first;
      expect(first.toString(), startsWith('https://proxy.test/?url='));
      // Target survives percent-encoding intact.
      expect(
        Uri.decodeComponent(first.toString().split('url=')[1]),
        contains('/maitri/temp'),
      );
    });
  });
}
