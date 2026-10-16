import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/data/catalog/repository/csv_catalog_source.dart';
import 'package:a2ui_flutter_commerce/data/catalog/repository/product_repository.dart';
import 'package:a2ui_flutter_commerce/data/catalog/service/local/csv_catalog_service.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_snapshot.dart';
import 'package:a2ui_flutter_commerce/data/stylist/repository/stylist_snapshot_repository.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/local/shared_preferences_stylist_service.dart';
import 'package:a2ui_flutter_commerce/data/weather/repository/weather_repository.dart';
import 'package:a2ui_flutter_commerce/data/weather/service/remote/model/open_meteo_forecast_dto.dart';
import 'package:a2ui_flutter_commerce/data/weather/service/remote/open_meteo_weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'stylist_store_helpers.dart';

const _catalog =
    'id,name,category,price_eur,season,color,gender\n'
    'top,Soft Top,top,1.10,all-season,blue,"male, female"\n'
    'bottom,Blue Jeans,bottom,2.20,summer,blue,"male, female"\n';

Map<String, Object?> _library() => {
  'version': 1,
  'current': {
    'brief': {
      'facts': {'budget': 100},
      'sources': {'budget': 'user'},
      'constraints': <String, Object?>{},
    },
    'items': ['top'],
    'city': 'Berlin',
  },
  'looks': <Object?>[],
  'bag': {'top': 2},
  'nextLookId': 1,
  'unrecognizedOptionalField': {
    'preserve': [true, null, 3.5],
  },
};

Map<String, Object?> _geo() => {
  'results': [
    {
      'name': 'Berlin',
      'country': 'Germany',
      'latitude': 52.52,
      'longitude': 13.41,
      'timezone': 'Europe/Berlin',
    },
  ],
};

Map<String, Object?> _forecast() => {
  'daily_units': {
    'temperature_2m_max': '°C',
    'temperature_2m_min': '°C',
    'precipitation_probability_max': '%',
  },
  'daily': <String, Object?>{
    'time': ['2026-10-15', '2026-10-16'],
    'temperature_2m_max': [12.0, 14.0],
    'temperature_2m_min': [8.0, 9.0],
    'precipitation_probability_max': [80, 30],
    'weather_code': [61, 3],
  },
};

class _DeferredWeatherService implements WeatherService {
  final pending = Completer<OpenMeteoForecastDto>();
  bool disposed = false;
  @override
  Future<OpenMeteoForecastDto> fetch(String city) => pending.future;
  @override
  void dispose() => disposed = true;
}

void main() {
  test(
    'CSV service mapping and repeated queries share one validated snapshot',
    () async {
      var reads = 0;
      final repository = CatalogRepository(
        source: CsvCatalogSource.service(
          CsvCatalogService(
            readText: () async {
              reads++;
              return _catalog;
            },
            revision: 'migration-test',
          ),
        ),
      );
      final snapshots = await Future.wait([
        repository.load(),
        repository.loadSnapshot(),
      ]);
      expect(snapshots.first, same(snapshots.last));
      expect(snapshots.first.revision, 'migration-test');
      expect(
        (await repository.search(category: 'top', maxPrice: 1.10)).single.id,
        'top',
      );
      expect(await repository.search(category: 'top', maxPrice: 1.09), isEmpty);
      expect(reads, 1);
    },
  );

  test(
    'catalog source failure is retried without retaining a failed snapshot',
    () async {
      var reads = 0;
      final repository = CatalogRepository(
        source: CsvCatalogSource(
          readText: () async {
            if (++reads == 1) throw StateError('temporary read failure');
            return _catalog;
          },
        ),
      );
      await expectLater(repository.load(), throwsStateError);
      expect((await repository.load()).products, hasLength(2));
      await repository.search();
      expect(reads, 2);
    },
  );

  test(
    'typed storage repository preserves the existing JSON and key',
    () async {
      final originalPlatform = SharedPreferencesAsyncPlatform.instance;
      final platform = MemoryPreferencePlatform();
      SharedPreferencesAsyncPlatform.instance = platform;
      addTearDown(
        () => SharedPreferencesAsyncPlatform.instance = originalPlatform,
      );
      final repository = StylistSnapshotRepository(
        service: SharedPreferencesStylistService(),
      );
      final original = _library();
      await repository.write(original);
      expect(platform.values.keys, ['alder.stylist.v1']);
      expect(jsonDecode(platform.values['alder.stylist.v1']!), original);
      final snapshot = (await repository.readSnapshot())!;
      expect(snapshot.version, 1);
      expect(snapshot.bag, {'top': 2});
      expect(snapshot.current!['city'], 'Berlin');
      expect(snapshot.toJson(), original);
      expect(() => snapshot.bag.clear(), throwsUnsupportedError);
      expect(() => snapshot.current!.clear(), throwsUnsupportedError);
      expect(
        () => (snapshot.current!['items'] as List).clear(),
        throwsUnsupportedError,
      );
      original['bag'] = {'top': 99};
      expect(snapshot.bag['top'], 2);
      await repository.writeSnapshot(snapshot);
      expect(await repository.read(), snapshot.toJson());
    },
  );

  test(
    'newer storage version and malformed documents are left unchanged',
    () async {
      final originalPlatform = SharedPreferencesAsyncPlatform.instance;
      final platform = MemoryPreferencePlatform();
      SharedPreferencesAsyncPlatform.instance = platform;
      addTearDown(
        () => SharedPreferencesAsyncPlatform.instance = originalPlatform,
      );
      final repository = StylistSnapshotRepository(
        service: SharedPreferencesStylistService(),
      );
      final newer = _library()..['version'] = 2;
      final encoded = jsonEncode(newer);
      platform.values['alder.stylist.v1'] = encoded;
      expect((await repository.readSnapshot())!.version, 2);
      expect(platform.values['alder.stylist.v1'], encoded);
      for (final invalid in ['{broken', '[]', '{"version":1}']) {
        platform.values['alder.stylist.v1'] = invalid;
        await expectLater(repository.read(), throwsFormatException);
        expect(platform.values['alder.stylist.v1'], invalid);
      }
    },
  );

  test(
    'snapshot copies nested values and preserves omitted optional fields',
    () {
      final raw = _library();
      final snapshot = StylistSnapshot.fromJson(raw);
      (raw['bag'] as Map)['top'] = 99;
      ((raw['current'] as Map)['items'] as List).add('bottom');
      expect(snapshot.bag, {'top': 2});
      expect(snapshot.current!['items'], ['top']);
      expect(snapshot.toJson().containsKey('bagVariants'), isFalse);
      expect(snapshot.toJson().containsKey('reviewedBagPieces'), isFalse);
    },
  );

  test(
    'weather repository maps DTOs, caches facts and honors refresh/expiry',
    () async {
      var requests = 0;
      var now = DateTime.utc(2026, 10, 15);
      final service = OpenMeteoWeatherService(
        client: MockClient((request) async {
          requests++;
          expect(request.followRedirects, isFalse);
          return http.Response(
            jsonEncode(
              request.url.host.startsWith('geocoding') ? _geo() : _forecast(),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final repository = WeatherRepository(service: service, now: () => now);
      addTearDown(repository.dispose);
      final first = await repository.fetch(' Berlin ');
      expect(first.source.provider, 'Open-Meteo');
      expect(first.forecastDays.first.highC, 12);
      expect(first.expiresAt, now.add(const Duration(minutes: 15)));
      expect(await repository.fetch('berlin'), same(first));
      expect(requests, 2);
      await repository.fetch('Berlin', refresh: true);
      expect(requests, 4);
      now = now.add(const Duration(minutes: 16));
      await repository.fetch('Berlin');
      expect(requests, 6);
    },
  );

  for (final bad in ['units', 'columns', 'date', 'code', 'sequence', 'range']) {
    test('weather DTO rejects invalid $bad before producing domain facts', () {
      final json = _forecast();
      final daily = json['daily'] as Map;
      switch (bad) {
        case 'units':
          (json['daily_units'] as Map)['temperature_2m_max'] = '°F';
        case 'columns':
          daily['weather_code'] = [];
        case 'date':
          daily['time'] = ['2026-02-31', '2026-10-16'];
        case 'code':
          daily['weather_code'] = [4, 3];
        case 'sequence':
          daily['time'] = ['2026-10-15', '2026-10-17'];
        case 'range':
          daily['precipitation_probability_max'] = [101, 30];
      }
      expect(
        () => OpenMeteoForecastDto.fromJson(
          location: OpenMeteoLocationDto.fromJson(_geo()),
          forecast: json,
        ),
        throwsFormatException,
      );
    });
  }

  test(
    'disposed weather repository rejects late completion and disposes service',
    () async {
      final service = _DeferredWeatherService();
      final repository = WeatherRepository(service: service);
      final pending = repository.fetch('Berlin');
      final rejection = expectLater(pending, throwsStateError);
      repository.dispose();
      service.pending.complete(
        OpenMeteoForecastDto.fromJson(
          location: OpenMeteoLocationDto.fromJson(_geo()),
          forecast: _forecast(),
        ),
      );
      await rejection;
      expect(service.disposed, isTrue);
      await expectLater(repository.fetch('Berlin'), throwsStateError);
    },
  );
}
