import 'dart:convert';

import 'package:http/http.dart' as http;

bool isWeatherQuestion(String message) =>
    RegExp(
      r'\b(?:weather|forecast|temperature|rain|snow)\b',
      caseSensitive: false,
    ).hasMatch(message) &&
    RegExp(
      r'^\s*(?:what|how|will|is|tell|show|check|get|can|could|please|do|does|are|weather|forecast|temperature)\b',
      caseSensitive: false,
    ).hasMatch(message) &&
    !RegExp(
      r'\b(?:wear|outfit|dress|clothes|recommend|shop|buy)\b',
      caseSensitive: false,
    ).hasMatch(message);

/// Only destination phrases are recognized; ordinary clothing requests are not locations.
String? parseDestinationCity(String message, {bool allowBare = false}) {
  const words =
      r"[A-Za-zÀ-ž][A-Za-zÀ-ž'’.-]*(?:\s+[A-Za-zÀ-ž][A-Za-zÀ-ž'’.-]*){0,3}?";
  const stop =
      r'(?=\s+(?:for|this|next|today|tomorrow|on|during|under|with|budget|and|in|business|casual|formal)\b|[,;.!?]|$)';
  final explicit = RegExp(
    '\\b(?:in|to|visiting|visit${isWeatherQuestion(message) ? '|for' : ''})\\s+($words)$stop',
    caseSensitive: false,
  ).allMatches(message).toList();
  final heading = RegExp(
    '^\\s*($words)\\s+(?:for\\s+(?:the\\s+)?|this\\s+|next\\s+)(?:weekend|week|trip)\\b',
    caseSensitive: false,
  ).firstMatch(message);
  final match = explicit.isNotEmpty ? explicit.last : heading;
  var location = match?.group(1)?.trim();
  if (location == null &&
      allowBare &&
      RegExp(
        '^$words(?:,\\s*$words)?[.!?]?\$',
        caseSensitive: false,
      ).hasMatch(message.trim())) {
    location = message.trim().replaceFirst(RegExp(r'[.!?]$'), '');
  }
  if (location == null ||
      RegExp(
        r'\b(?:a|an|the|dress|shirt|top|bottom|shoes|jacket|bag|outfit|budget|spend|weather|weekend|today|tomorrow|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|casual|formal|business|winter|summer|spring|autumn|wool|cotton|black|blue|red|rain|yes|no|thanks|please)\b',
        caseSensitive: false,
      ).hasMatch(location)) {
    return null;
  }
  if (match != null) {
    final locationEnd =
        match.start +
        match.group(0)!.indexOf(match.group(1)!) +
        match.group(1)!.length;
    final country = RegExp(
      '^,\\s*($words)$stop',
      caseSensitive: false,
    ).firstMatch(message.substring(locationEnd));
    if (country != null &&
        !RegExp(
          r'\b(?:business|casual|formal|budget|outfit|dress|winter|summer|spring|autumn)\b',
          caseSensitive: false,
        ).hasMatch(country.group(1)!)) {
      location = '$location, ${country.group(1)!.trim()}';
    }
  }
  return location;
}

abstract class CityContextSource {
  Future<CityContext> fetch(String city, {bool refresh = false});
  void dispose();
}

enum ForecastSourceKind { live, fixture, unspecified }

/// Provider attribution is data supplied by the adapter, never inferred from
/// the fact that a value implements CityContextSource.
class ForecastSource {
  const ForecastSource({
    required this.id,
    required this.provider,
    this.locationProvider,
    this.kind = ForecastSourceKind.live,
    this.forecastUrl,
    this.locationUrl,
  });

  const ForecastSource.unspecified()
    : id = 'unspecified',
      provider = null,
      locationProvider = null,
      kind = ForecastSourceKind.unspecified,
      forecastUrl = null,
      locationUrl = null;

  static const openMeteo = ForecastSource(
    id: 'open-meteo',
    provider: 'Open-Meteo',
    locationProvider: 'GeoNames',
    forecastUrl: 'https://open-meteo.com/',
    locationUrl: 'https://www.geonames.org/',
  );

  final String id;
  final String? provider;
  final String? locationProvider;
  final ForecastSourceKind kind;
  final String? forecastUrl;
  final String? locationUrl;

  String get attribution => provider == null
      ? 'Forecast source not specified'
      : '$provider forecast${locationProvider == null ? '' : ' / $locationProvider location'}';

  String get disclaimer => provider == null
      ? 'Forecast source not specified. Forecasts can change.'
      : '${kind == ForecastSourceKind.live
                ? 'Live'
                : kind == ForecastSourceKind.fixture
                ? 'Fixture'
                : 'Provided'} forecast from $provider. '
            '${locationProvider == null ? '' : 'Location: $locationProvider. '}'
            'Not historical averages; forecasts can change.';

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider,
    'locationProvider': locationProvider,
    'kind': kind.name,
    if (forecastUrl != null) 'forecastUrl': forecastUrl,
    if (locationUrl != null) 'locationUrl': locationUrl,
  };
}

/// Daily values have fixed units: Celsius, percent, and optional WMO code.
/// Missing measurements stay null and are never replaced with zero.
class ForecastDay {
  ForecastDay({
    required String date,
    num? highC,
    num? lowC,
    num? rainProbabilityPercent,
    this.weatherCode,
    this.highlight = false,
    String? icon,
  }) : date = _forecastDate(date),
       highC = highC == null ? null : _number(highC, -100, 70),
       lowC = lowC == null ? null : _number(lowC, -100, 70),
       rainProbabilityPercent = rainProbabilityPercent == null
           ? null
           : _number(rainProbabilityPercent, 0, 100),
       icon =
           icon ??
           (weatherCode == null
               ? ''
               : _rainCodes.contains(weatherCode)
               ? 'rain'
               : 'day') {
    if (this.lowC != null && this.highC != null && this.lowC! > this.highC!) {
      throw const FormatException('Forecast low exceeds high.');
    }
    if (weatherCode != null && !_weatherCodes.contains(weatherCode)) {
      throw const FormatException('Invalid WMO weather code.');
    }
  }

  /// Legacy map input ends here. Typed values are the source of card labels.
  factory ForecastDay.fromMap(Map<String, Object?> value) {
    final rawDate = value['date'];
    final code = value['weatherCode'];
    if (rawDate is! String ||
        (code != null &&
            (code is! num || !code.isFinite || code != code.round()))) {
      throw const FormatException('Invalid forecast day.');
    }
    num? measurement(String key) {
      final raw = value[key];
      if (raw == null) return null;
      if (raw is! num) {
        throw const FormatException('Invalid forecast measurement.');
      }
      return raw;
    }

    return ForecastDay(
      date: rawDate,
      highC: measurement('highC'),
      lowC: measurement('lowC'),
      rainProbabilityPercent: measurement('rainProbabilityPercent'),
      weatherCode: (code as num?)?.toInt(),
      highlight: value['highlight'] == true,
      icon: value['icon'] is String ? value['icon'] as String : null,
    );
  }

  final String date;
  final double? highC;
  final double? lowC;
  final double? rainProbabilityPercent;
  final int? weatherCode;
  final bool highlight;
  final String icon;

  static const units = {
    'temperature': '°C',
    'rainProbability': '%',
    'weatherCode': 'WMO',
  };
  String get label => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][DateTime.parse(date).weekday - 1];
  List<String> get missingFields => [
    if (highC == null) 'highC',
    if (lowC == null) 'lowC',
    if (rainProbabilityPercent == null) 'rainProbabilityPercent',
    if (weatherCode == null) 'weatherCode',
  ];
  Map<String, Object?> toMap() => {
    'date': date,
    'label': label,
    'highC': highC,
    'lowC': lowC,
    'rainProbabilityPercent': rainProbabilityPercent,
    if (weatherCode != null) 'weatherCode': weatherCode,
    'value': highC == null || lowC == null
        ? 'Temperature unavailable'
        : '${highC!.round()}° / ${lowC!.round()}°',
    'detail': rainProbabilityPercent == null
        ? 'Rain forecast unavailable'
        : 'Rain ${rainProbabilityPercent!.round()}%',
    'icon': icon,
    if (highlight) 'highlight': true,
  };
}

class CityContext {
  CityContext({
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required DateTime fetchedAt,
    DateTime? expiresAt,
    this.source = const ForecastSource.unspecified(),
    List<Map<String, Object?>>? days,
    List<ForecastDay>? forecastDays,
  }) : fetchedAt = fetchedAt.toUtc(),
       expiresAt = expiresAt?.toUtc(),
       forecastDays = List.unmodifiable(
         forecastDays ?? (days ?? const []).map(ForecastDay.fromMap),
       ) {
    _number(latitude, -90, 90);
    _number(longitude, -180, 180);
    _text(city);
    _text(country);
    _text(timezone);
    if ((days == null) == (forecastDays == null) || this.forecastDays.isEmpty) {
      throw const FormatException('Supply one nonempty daily forecast.');
    }
    if (this.expiresAt != null && !this.expiresAt!.isAfter(this.fetchedAt)) {
      throw const FormatException('Forecast expiry must follow retrieval.');
    }
    for (var index = 1; index < this.forecastDays.length; index++) {
      if (this.forecastDays[index - 1].date.compareTo(
            this.forecastDays[index].date,
          ) >=
          0) {
        throw const FormatException(
          'Forecast dates must increase without duplicates.',
        );
      }
    }
  }
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;
  final DateTime fetchedAt;
  final DateTime? expiresAt;
  final ForecastSource source;
  final List<ForecastDay> forecastDays;

  /// Compatibility wire view for the existing host and A2UI presentation.
  List<Map<String, Object?>> get days => List.unmodifiable(
    forecastDays.map((day) => Map<String, Object?>.unmodifiable(day.toMap())),
  );

  bool isFreshAt(DateTime now) =>
      !now.toUtc().isBefore(fetchedAt) &&
      expiresAt != null &&
      now.toUtc().isBefore(expiresAt!);

  String get label => '$city, $country';
  Map<String, Object?> get facts => {
    'location': label,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'source': source.attribution,
    'provenance': source.toJson(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'units': ForecastDay.units,
    'coverage': {
      'startDate': forecastDays.first.date,
      'endDate': forecastDays.last.date,
      'dates': forecastDays.map((day) => day.date).toList(),
    },
    'forecast': days,
    'missingMeasurements': {
      for (final day in forecastDays)
        if (day.missingFields.isNotEmpty) day.date: day.missingFields,
    },
  };
  Map<String, Object?> get weatherCard => {
    'title': '$city — forecast',
    'summary': '${forecastDays.first.date} · $timezone',
    'disclaimer': source.disclaimer,
    'days': days,
  };
}

String _forecastDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Invalid forecast date.');
  }
  return value;
}

const _weatherCodes = {
  0,
  1,
  2,
  3,
  45,
  48,
  51,
  53,
  55,
  56,
  57,
  61,
  63,
  65,
  66,
  67,
  71,
  73,
  75,
  77,
  80,
  81,
  82,
  85,
  86,
  95,
  96,
  99,
};
const _rainCodes = {
  51,
  53,
  55,
  56,
  57,
  61,
  63,
  65,
  66,
  67,
  80,
  81,
  82,
  95,
  96,
  99,
};

/// City-level destination context. Never requests the person's GPS location.
/// The public endpoint is for private/non-commercial prototyping; production
/// commercial deployments must configure an appropriately licensed service.
class OpenMeteoCityContextSource implements CityContextSource {
  OpenMeteoCityContextSource({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _now;
  final Map<String, CityContext> _cache = {};
  bool _disposed = false;

  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) async {
    if (_disposed) throw StateError('Context source closed');
    final query = city.trim();
    if (query.length < 2 ||
        query.length > 100 ||
        query.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const FormatException('Enter a city name');
    }
    final cached = _cache[query.toLowerCase()];
    if (!refresh && cached != null && cached.isFreshAt(_now())) {
      return cached;
    }
    final geo = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '1',
        'language': 'en',
        'format': 'json',
      }),
    );
    final locations = geo['results'];
    if (locations is! List || locations.isEmpty || locations.first is! Map) {
      throw const FormatException('City not found');
    }
    final place = Map<String, Object?>.from(locations.first as Map);
    final lat = _number(place['latitude'], -90, 90);
    final lon = _number(place['longitude'], -180, 180);
    final name = _text(place['name']);
    final country = _text(place['country']);
    final zone = _text(place['timezone']);
    final forecast = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'timezone': zone,
        'forecast_days': '5',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      }),
    );
    final daily = forecast['daily'];
    final units = forecast['daily_units'];
    if (daily is! Map ||
        units is! Map ||
        units['temperature_2m_max'] != '°C' ||
        units['temperature_2m_min'] != '°C' ||
        units['precipitation_probability_max'] != '%') {
      throw const FormatException('Forecast unavailable');
    }
    final dates = daily['time'];
    if (dates is! List || dates.isEmpty || dates.length > 5) {
      throw const FormatException('Forecast unavailable');
    }
    final columns = [
      'temperature_2m_max',
      'temperature_2m_min',
      'precipitation_probability_max',
      'weather_code',
    ];
    for (final key in columns) {
      if (daily[key] is! List || (daily[key] as List).length != dates.length) {
        throw const FormatException('Forecast unavailable');
      }
    }
    final days = <ForecastDay>[];
    for (var i = 0; i < dates.length; i++) {
      final date = DateTime.tryParse('${dates[i]}');
      if (date == null ||
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('${dates[i]}') ||
              date.toIso8601String().substring(0, 10) != dates[i])) {
        throw const FormatException('Forecast unavailable');
      }
      final high = _number(daily['temperature_2m_max'][i], -100, 70);
      final low = _number(daily['temperature_2m_min'][i], -100, 70);
      final rain = _number(daily['precipitation_probability_max'][i], 0, 100);
      final code = _number(daily['weather_code'][i], 0, 99);
      if (code != code.roundToDouble() ||
          !_weatherCodes.contains(code) ||
          (i > 0 &&
              date.difference(DateTime.parse('${dates[i - 1]}')) !=
                  const Duration(days: 1))) {
        throw const FormatException('Forecast unavailable');
      }
      if (low > high) throw const FormatException('Forecast unavailable');
      days.add(
        ForecastDay(
          date: dates[i] as String,
          highC: high,
          lowC: low,
          rainProbabilityPercent: rain,
          weatherCode: code.toInt(),
          highlight: i == 0,
        ),
      );
    }
    final fetchedAt = _now().toUtc();
    final result = CityContext(
      city: name,
      country: country,
      latitude: lat,
      longitude: lon,
      timezone: zone,
      fetchedAt: fetchedAt,
      expiresAt: fetchedAt.add(const Duration(minutes: 15)),
      source: ForecastSource.openMeteo,
      forecastDays: days,
    );
    if (_disposed) throw StateError('Context source closed');
    _cache[query.toLowerCase()] = result;
    return result;
  }

  Future<Map<String, Object?>> _get(Uri uri) async {
    if (_disposed) throw StateError('Context source closed');
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 8)),
    ).timeout(const Duration(seconds: 8));
    if (_disposed ||
        response.statusCode != 200 ||
        response.bodyBytes.length > 150000) {
      throw StateError('City context unavailable');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map || json['error'] == true) {
      throw const FormatException('City context unavailable');
    }
    return Map<String, Object?>.from(json);
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    _client.close();
  }
}

double _number(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('Invalid context data');
  }
  return value.toDouble();
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 150) {
    throw const FormatException('Invalid location');
  }
  return value.trim();
}
