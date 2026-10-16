import 'package:http/http.dart' as http;

import '../service/remote/open_meteo_weather_service.dart';
import 'weather_repository.dart';

/// Compatibility constructor for earlier source callers. Production composition
/// injects [OpenMeteoWeatherService] into [WeatherRepository] explicitly.
class OpenMeteoCityContextSource extends WeatherRepository {
  OpenMeteoCityContextSource({http.Client? client, super.now})
    : super(service: OpenMeteoWeatherService(client: client));
}
