import '../model/city_context.dart';
import '../service/remote/open_meteo_weather_service.dart';

/// Owns freshness and caching policy; services return only transport DTOs.
class WeatherRepository implements CityContextSource {
  WeatherRepository({required WeatherService service, DateTime Function()? now})
    // Public injection keeps the service implementation private.
    // ignore: prefer_initializing_formals
    : _service = service,
      _now = now ?? DateTime.now;

  final WeatherService _service;
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
    if (!refresh && cached != null && cached.isFreshAt(_now())) return cached;
    final dto = await _service.fetch(query);
    if (_disposed) throw StateError('Context source closed');
    final result = dto.toCityContext(fetchedAt: _now().toUtc());
    _cache[query.toLowerCase()] = result;
    return result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cache.clear();
    _service.dispose();
  }
}
