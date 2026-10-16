import 'package:a2ui_flutter_commerce/data/weather/repository/open_meteo_city_context_source.dart';

import 'dart:convert';

import 'package:a2ui_flutter_commerce/data/weather/model/city_context.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/stylist_presenter.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final fetchedAt = DateTime.utc(2026, 10, 15, 8);
CityContext context({
  ForecastSource source = const ForecastSource.unspecified(),
  List<ForecastDay>? forecastDays,
  DateTime? expiresAt,
}) => CityContext(
  city: 'Berlin',
  country: 'Germany',
  latitude: 52.52,
  longitude: 13.41,
  timezone: 'Europe/Berlin',
  fetchedAt: fetchedAt,
  expiresAt: expiresAt,
  source: source,
  forecastDays:
      forecastDays ??
      [
        ForecastDay(
          date: '2026-10-15',
          highC: 12,
          lowC: 8,
          rainProbabilityPercent: 80,
          weatherCode: 61,
        ),
      ],
);

class InjectedForecast implements CityContextSource {
  InjectedForecast(this.source, {this.forecastDays});
  final ForecastSource source;
  final List<ForecastDay>? forecastDays;
  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) async =>
      context(
        source: source,
        forecastDays: forecastDays,
        expiresAt: fetchedAt.add(const Duration(minutes: 30)),
      );
  @override
  void dispose() {}
}

const catalog = [
  Product(
    id: 'shirt',
    category: ProductCategory.top,
    name: 'Shirt',
    brand: 'Demo',
    price: 10,
    meta: '',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'trousers',
    category: ProductCategory.bottom,
    name: 'Trousers',
    brand: 'Demo',
    price: 15,
    meta: '',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'shoes',
    category: ProductCategory.shoes,
    name: 'Shoes',
    brand: 'Demo',
    price: 20,
    meta: '',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'bag',
    category: ProductCategory.bag,
    name: 'Bag',
    brand: 'Demo',
    price: 20,
    meta: '',
    tag: '',
    swatch: '#000000',
  ),
];
void main() {
  for (final source in const [
    ForecastSource(
      id: 'fixture-a',
      provider: 'Forecast Fixture A',
      locationProvider: 'Location Fixture A',
      kind: ForecastSourceKind.fixture,
    ),
    ForecastSource(
      id: 'fixture-b',
      provider: 'Forecast Fixture B',
      locationProvider: 'Location Fixture B',
      kind: ForecastSourceKind.fixture,
    ),
  ]) {
    test(
      '${source.id} attribution reaches model facts and host cards without Open-Meteo claims',
      () async {
        final requests = <String>[];
        final runtime = StylistRuntime(
          products: catalog,
          cityContextSource: InjectedForecast(source),
          onModelRequest: (request) =>
              requests.add(jsonEncode(request.toJson())),
        );
        addTearDown(runtime.dispose);
        final result = await runtime.turn({
          'message': 'A casual outfit in Berlin under €100',
        });
        final facts = result.view.cityContext!.facts;
        expect(
          facts['source'],
          '${source.provider} forecast / ${source.locationProvider} location',
        );
        expect((facts['provenance'] as Map)['id'], source.id);
        expect((facts['provenance'] as Map)['kind'], 'fixture');
        expect(requests.join(), contains(source.provider));
        expect(requests.join(), contains('expiresAt'));
        expect(requests.join(), isNot(contains('Open-Meteo')));
        final presented = presentStylistResult(result);
        final inline =
            (presented['messages'] as List).lastWhere(
                  (message) =>
                      message['updateDataModel']?['surfaceId'].startsWith(
                        'inline-',
                      ) ==
                      true,
                )['updateDataModel']['value']
                as Map;
        expect(
          inline['weather']['disclaimer'],
          contains('Fixture forecast from ${source.provider}'),
        );
        expect(
          inline['weather']['disclaimer'],
          contains(source.locationProvider),
        );
        expect(inline['weather']['disclaimer'], isNot(contains('GeoNames')));
      },
    );
  }

  test('a weather question reports unavailable injected measurements without invented numbers', () async {
    final runtime = StylistRuntime(
      products: catalog,
      cityContextSource: InjectedForecast(
        const ForecastSource(
          id: 'partial-fixture',
          provider: 'Partial fixture',
          kind: ForecastSourceKind.fixture,
        ),
        forecastDays: [ForecastDay(date: '2026-10-15')],
      ),
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'What is the weather in Berlin today?',
    });
    expect(result.reply, contains('Temperature unavailable'));
    expect(result.reply, contains('Rain forecast unavailable'));
    expect(result.reply, isNot(contains('0%')));
    expect(result.reply, isNot(contains('0°C')));
    expect(result.view.cityContext!.forecastDays.single.highC, isNull);
  });

  test('legacy map boundary freezes typed facts and leaves unknown provenance, expiry and measurements explicit', () {
    final raw = <String, Object?>{
      'date': '2026-10-15',
      'highC': 12,
      'label': 'Wrong label',
      'value': 'Invented temperature',
    };
    final value = CityContext(
      city: 'Berlin',
      country: 'Germany',
      latitude: 52.52,
      longitude: 13.41,
      timezone: 'Europe/Berlin',
      fetchedAt: fetchedAt,
      days: [raw],
    );
    raw['highC'] = 999;
    expect(value.forecastDays.single.highC, 12);
    expect(value.forecastDays.single.lowC, isNull);
    expect(value.forecastDays.single.label, 'Thu');
    expect(value.days.single['value'], 'Temperature unavailable');
    expect(value.days.single['detail'], 'Rain forecast unavailable');
    expect(value.days.single['icon'], '');
    expect(value.facts['expiresAt'], isNull);
    expect(value.isFreshAt(fetchedAt), false);
    expect(value.facts['units'], {
      'temperature': '°C',
      'rainProbability': '%',
      'weatherCode': 'WMO',
    });
    expect(value.facts['coverage'], {
      'startDate': '2026-10-15',
      'endDate': '2026-10-15',
      'dates': ['2026-10-15'],
    });
    expect((value.facts['missingMeasurements'] as Map)['2026-10-15'], [
      'lowC',
      'rainProbabilityPercent',
      'weatherCode',
    ]);
    expect(value.facts['source'], 'Forecast source not specified');
    expect(value.weatherCard['disclaimer'], isNot(contains('Live')));
    expect(value.weatherCard['disclaimer'], isNot(contains('Open-Meteo')));
    expect(() => value.days.single['highC'] = 999, throwsUnsupportedError);
    expect(() => value.forecastDays.clear(), throwsUnsupportedError);
  });

  test('production adapter supplies explicit attribution, units, coverage and exact cache expiry', () async {
    var now = fetchedAt;
    var calls = 0;
    final adapter = OpenMeteoCityContextSource(
      now: () => now,
      client: MockClient((request) async {
        calls++;
        final payload = request.url.host.startsWith('geocoding')
            ? {
                'results': [
                  {
                    'name': 'Berlin',
                    'country': 'Germany',
                    'latitude': 52.52,
                    'longitude': 13.41,
                    'timezone': 'Europe/Berlin',
                  },
                ],
              }
            : {
                'daily_units': {
                  'temperature_2m_max': '°C',
                  'temperature_2m_min': '°C',
                  'precipitation_probability_max': '%',
                },
                'daily': {
                  'time': ['2026-10-15'],
                  'temperature_2m_max': [12],
                  'temperature_2m_min': [8],
                  'precipitation_probability_max': [80],
                  'weather_code': [61],
                },
              };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(adapter.dispose);
    final first = await adapter.fetch('Berlin');
    expect(first.source, ForecastSource.openMeteo);
    expect(first.facts['source'], 'Open-Meteo forecast / GeoNames location');
    expect(first.facts['expiresAt'], '2026-10-15T08:15:00.000Z');
    expect(first.facts['missingMeasurements'], isEmpty);
    expect(first.days.single['value'], '12° / 8°');
    expect(
      first.weatherCard['disclaimer'],
      contains('Live forecast from Open-Meteo. Location: GeoNames.'),
    );
    expect(
      first.isFreshAt(fetchedAt.subtract(const Duration(seconds: 1))),
      false,
    );
    now = fetchedAt.add(const Duration(minutes: 14, seconds: 59));
    expect(await adapter.fetch('Berlin'), same(first));
    expect(calls, 2);
    now = fetchedAt.add(const Duration(minutes: 15));
    expect(await adapter.fetch('Berlin'), isNot(same(first)));
    expect(calls, 4);
  });

  test('typed and legacy forecast inputs reject invalid dates, measurements, ordering and expiry', () {
    for (final value in <Map<String, Object?>>[
      {'date': '2026-02-31'},
      {'date': ''},
      {'date': 'tomorrow'},
      {'date': '2026-10-15', 'highC': double.nan},
      {'date': '2026-10-15', 'highC': 8, 'lowC': 12},
      {'date': '2026-10-15', 'rainProbabilityPercent': 101},
      {'date': '2026-10-15', 'weatherCode': 4},
      {'date': '2026-10-15', 'weatherCode': 61.5},
    ]) {
      expect(() => ForecastDay.fromMap(value), throwsFormatException);
    }
    expect(() => context(forecastDays: []), throwsFormatException);
    expect(
      () => context(
        forecastDays: [
          ForecastDay(date: '2026-10-15'),
          ForecastDay(date: '2026-10-15'),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => context(
        forecastDays: [
          ForecastDay(date: '2026-10-16'),
          ForecastDay(date: '2026-10-15'),
        ],
      ),
      throwsFormatException,
    );
    expect(() => context(expiresAt: fetchedAt), throwsFormatException);
  });
}
