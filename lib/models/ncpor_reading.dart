/// Live station telemetry read from the National Polar Data Center (NPDC)
/// portal operated by NCPOR, Ministry of Earth Sciences —
/// https://data.ncpor.res.in
///
/// NPDC publishes one page per station/parameter carrying a `d1`
/// JavaScript string literal whose contents are a JSON array of
/// `{date, value}` samples. [NporReading] is the parsed, unit-normalised
/// result of those pages for a single station.
///
/// Every measurement is nullable **on purpose**: each station exposes a
/// different parameter set (Himadri reports no wind speed at all, for
/// example). A null means "not reported by the source" and must never be
/// read as a measured zero — a calm station and a station with no anemometer
/// are different facts.
class NporReading {
  /// Which portal parameter a reading came from.
  static const String paramTemp = 'temp';
  static const String paramWind = 'wind';
  static const String paramPressure = 'ap';
  static const String paramHumidity = 'rh';

  final String stationId;

  /// Newest sample timestamp found across all fetched parameters.
  /// Null when nothing parsed — that is the "unavailable" signal.
  final DateTime? observedAt;

  final double? temperatureC;

  /// NPDC reports wind in **metres per second**, unlike [Station.windSpeed]
  /// which is knots. Use [windSpeedKnots] for display.
  final double? windSpeedMs;

  final double? airPressureHpa;
  final double? relativeHumidityPct;

  /// Coldest / windiest sample in the fetched window — used for the
  /// "24h low" / "gust" subtext so those numbers are measured, not typed.
  final double? temperatureMinC;
  final double? windMaxMs;

  /// Number of parameters successfully parsed (0..4).
  final int sampleCount;

  /// When AROHA performed the fetch. Distinct from [observedAt], which is
  /// when the *station* was measured.
  final DateTime fetchedAt;

  /// Portal paths that contributed, e.g. `/maitri/temp`.
  final List<String> endpoints;

  /// Populated when the fetch itself failed (offline, CORS, HTTP error).
  final String? error;

  const NporReading({
    required this.stationId,
    required this.fetchedAt,
    this.observedAt,
    this.temperatureC,
    this.windSpeedMs,
    this.airPressureHpa,
    this.relativeHumidityPct,
    this.temperatureMinC,
    this.windMaxMs,
    this.sampleCount = 0,
    this.endpoints = const [],
    this.error,
  });

  /// Metres/second → knots. `Station.windSpeed` is documented and rendered
  /// as knots (`kt` / `KTS`), so raw portal values must be converted.
  static const double knotsPerMetrePerSecond = 1.9438444924406;

  /// Portal timestamps have no declared timezone, and the observed lag is
  /// ~5h under a UTC reading or ~10h under a local reading. A 24h window
  /// returns the *same* verdict either way, so the status is not an
  /// artefact of a timezone guess.
  static const Duration freshFor = Duration(hours: 24);

  bool get hasData => observedAt != null && sampleCount > 0;

  double? get windSpeedKnots =>
      windSpeedMs == null ? null : windSpeedMs! * knotsPerMetrePerSecond;

  double? get windMaxKnots =>
      windMaxMs == null ? null : windMaxMs! * knotsPerMetrePerSecond;

  /// How old the newest sample is. Never negative: a timestamp in the
  /// future means the source is zone-shifted ahead of us, not that the
  /// reading is from the future.
  Duration get age {
    final at = observedAt;
    if (at == null) return Duration.zero;
    final delta = DateTime.now().difference(at);
    return delta.isNegative ? Duration.zero : delta;
  }

  bool get isStale => !hasData || age > freshFor;

  NporTelemetryStatus get status {
    if (!hasData) return NporTelemetryStatus.unavailable;
    return isStale ? NporTelemetryStatus.stale : NporTelemetryStatus.live;
  }

  /// "21 Sep 23:59" — the portal's own timestamp, unmodified, so operators
  /// can compare it against the source site.
  String get observedLabel {
    final at = observedAt;
    if (at == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${months[at.month - 1]} $hh:$mm';
  }

  /// "4h50m" / "12m" — surfaced instead of hiding the lag behind a
  /// generic LIVE badge.
  String get ageLabel {
    if (!hasData) return '—';
    final a = age;
    if (a.inDays > 0) return '${a.inDays}d ${a.inHours % 24}h';
    if (a.inHours > 0) return '${a.inHours}h ${a.inMinutes % 60}m';
    return '${a.inMinutes}m';
  }

  /// Short human summary of what could and could not be read.
  String get coverageLabel => '$sampleCount/4 params';
}

/// Where a station's displayed telemetry came from.
enum NporTelemetryStatus {
  /// Not attempted yet — shows the seeded mock values.
  idle,

  /// Fetch in flight.
  syncing,

  /// Fresh NPDC samples inside [NporReading.freshFor].
  live,

  /// Samples parsed but older than [NporReading.freshFor]. Values are still
  /// real, just not current — labelled so nobody mistakes them for now.
  stale,

  /// Nothing parsed (offline, CORS, HTTP error). Seeded mock values remain
  /// on screen and are marked as mock rather than passed off as live.
  unavailable,
}
