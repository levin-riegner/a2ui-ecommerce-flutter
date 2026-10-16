import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model/open_meteo_forecast_dto.dart';

abstract interface class WeatherService {
  Future<OpenMeteoForecastDto> fetch(String city);
  void dispose();
}

/// City-level remote transport. Never requests the person's GPS location.
/// The public endpoint is for private/non-commercial prototyping; production
/// commercial deployments must configure an appropriately licensed service.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  bool _disposed = false;

  @override
  Future<OpenMeteoForecastDto> fetch(String city) async {
    final location = OpenMeteoLocationDto.fromJson(
      await _get(
        Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': city,
          'count': '1',
          'language': 'en',
          'format': 'json',
        }),
      ),
    );
    final forecast = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        'timezone': location.timezone,
        'forecast_days': '5',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      }),
    );
    return OpenMeteoForecastDto.fromJson(
      location: location,
      forecast: forecast,
    );
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
    _client.close();
  }
}
