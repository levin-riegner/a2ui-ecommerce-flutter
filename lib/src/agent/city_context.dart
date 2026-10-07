import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class CityContextSource {
  Future<CityContext> fetch(String city, {bool refresh = false});
  void dispose();
}

class CityContext {
  const CityContext({
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.fetchedAt,
    required this.days,
  });
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;
  final DateTime fetchedAt;
  final List<Map<String, Object?>> days;

  String get label => '$city, $country';
  Map<String, Object?> get facts => {
    'location': label,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'source': 'Open-Meteo forecast / GeoNames location',
    'fetchedAt': fetchedAt.toIso8601String(),
    'forecast': days,
  };
  Map<String, Object?> get weatherCard => {
    'title': '$city — forecast',
    'summary': '${days.first['date']} · $timezone',
    'disclaimer':
        'Live forecast from Open-Meteo. Location: GeoNames. '
        'Not historical averages; forecasts can change.',
    'days': days,
  };
}

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
    if (!refresh &&
        cached != null &&
        !_now().toUtc().isBefore(cached.fetchedAt) &&
        _now().toUtc().difference(cached.fetchedAt) <
            const Duration(minutes: 15)) {
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
    final days = <Map<String, Object?>>[];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
          !{
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
          }.contains(code) ||
          (i > 0 &&
              date.difference(DateTime.parse('${dates[i - 1]}')) !=
                  const Duration(days: 1))) {
        throw const FormatException('Forecast unavailable');
      }
      if (low > high) throw const FormatException('Forecast unavailable');
      days.add({
        'date': dates[i],
        'label': weekdays[date.weekday - 1],
        'highC': high,
        'lowC': low,
        'rainProbabilityPercent': rain,
        'weatherCode': code,
        'value': '${high.round()}° / ${low.round()}°',
        'detail': 'Rain ${rain.round()}%',
        'icon':
            {
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
            }.contains(code)
            ? 'rain'
            : 'day',
        'highlight': i == 0,
      });
    }
    final result = CityContext(
      city: name,
      country: country,
      latitude: lat,
      longitude: lon,
      timezone: zone,
      fetchedAt: _now().toUtc(),
      days: List.unmodifiable(days),
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
