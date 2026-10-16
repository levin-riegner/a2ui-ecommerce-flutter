import '../../../model/city_context.dart';

/// Validated external location fields, separate from the host forecast model.
class OpenMeteoLocationDto {
  const OpenMeteoLocationDto({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  factory OpenMeteoLocationDto.fromJson(Map<String, Object?> json) {
    final locations = json['results'];
    if (locations is! List || locations.isEmpty || locations.first is! Map) {
      throw const FormatException('City not found');
    }
    final place = Map<String, Object?>.from(locations.first as Map);
    return OpenMeteoLocationDto(
      name: _text(place['name']),
      country: _text(place['country']),
      latitude: _number(place['latitude'], -90, 90),
      longitude: _number(place['longitude'], -180, 180),
      timezone: _text(place['timezone']),
    );
  }

  final String name, country, timezone;
  final double latitude, longitude;
}

class ForecastDayDto {
  const ForecastDayDto({
    required this.date,
    required this.highC,
    required this.lowC,
    required this.rainProbabilityPercent,
    required this.weatherCode,
    required this.highlight,
  });

  final String date;
  final double highC, lowC, rainProbabilityPercent;
  final int weatherCode;
  final bool highlight;

  ForecastDay toForecastDay() => ForecastDay(
    date: date,
    highC: highC,
    lowC: lowC,
    rainProbabilityPercent: rainProbabilityPercent,
    weatherCode: weatherCode,
    highlight: highlight,
  );
}

/// Open-Meteo wire columns are validated before mapping to host-owned facts.
class OpenMeteoForecastDto {
  OpenMeteoForecastDto({
    required this.location,
    required List<ForecastDayDto> days,
  }) : days = List.unmodifiable(days);

  factory OpenMeteoForecastDto.fromJson({
    required OpenMeteoLocationDto location,
    required Map<String, Object?> forecast,
  }) {
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
    final days = <ForecastDayDto>[];
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
          !ForecastDay.supportsWeatherCode(code.toInt()) ||
          (i > 0 &&
              date.difference(DateTime.parse('${dates[i - 1]}')) !=
                  const Duration(days: 1))) {
        throw const FormatException('Forecast unavailable');
      }
      if (low > high) throw const FormatException('Forecast unavailable');
      days.add(
        ForecastDayDto(
          date: dates[i] as String,
          highC: high,
          lowC: low,
          rainProbabilityPercent: rain,
          weatherCode: code.toInt(),
          highlight: i == 0,
        ),
      );
    }
    return OpenMeteoForecastDto(location: location, days: days);
  }

  final OpenMeteoLocationDto location;
  final List<ForecastDayDto> days;

  CityContext toCityContext({required DateTime fetchedAt}) => CityContext(
    city: location.name,
    country: location.country,
    latitude: location.latitude,
    longitude: location.longitude,
    timezone: location.timezone,
    fetchedAt: fetchedAt,
    expiresAt: fetchedAt.add(const Duration(minutes: 15)),
    source: ForecastSource.openMeteo,
    forecastDays: days.map((day) => day.toForecastDay()).toList(),
  );
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
