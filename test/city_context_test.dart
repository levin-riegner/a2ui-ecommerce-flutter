import 'stylist_wire_helpers.dart';

import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/city_context.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/src/agent/stylist_surfaces.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'stylist_runtime_test.dart' show products;

Map<String, Object?> geo() => {
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
Map<String, Object?> forecast() => {
  'daily_units': {
    'temperature_2m_max': '°C',
    'temperature_2m_min': '°C',
    'precipitation_probability_max': '%',
  },
  'daily': {
    'time': ['2026-10-06', '2026-10-07'],
    'temperature_2m_max': [12.0, 14.0],
    'temperature_2m_min': [8.0, 9.0],
    'precipitation_probability_max': [80, 30],
    'weather_code': [61, 3],
  },
};

class FixtureContext implements CityContextSource {
  bool fail = false;
  final List<String> calls = [];
  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) async {
    calls.add(city);
    if (fail) throw StateError('network unavailable');
    return CityContext(
      city: city.split(',').first,
      country: 'Test country',
      latitude: 52.52,
      longitude: 13.41,
      timezone: 'Europe/Berlin',
      fetchedAt: DateTime.utc(2026, 10, 6),
      days: const [
        {
          'date': '2026-10-06',
          'label': 'Tue',
          'value': '12° / 8°',
          'detail': 'Rain 80%',
          'highC': 12,
          'lowC': 8,
          'rainProbabilityPercent': 80,
          'icon': 'rain',
        },
      ],
    );
  }

  @override
  void dispose() {}
}

Map<String, Object?> inlineData(Map<String, dynamic> turn) {
  final result = <String, Object?>{};
  for (final message in presentedStylistTurn(turn)['messages'] as List) {
    final update = message['updateDataModel'];
    if (update is! Map ||
        !(update['surfaceId'] as String).startsWith('inline-')) {
      continue;
    }
    final path = update['path'];
    if (path == null || path == '/') {
      result.addAll(Map<String, Object?>.from(update['value'] as Map));
    } else {
      result[(path as String).substring(1)] = update['value'];
    }
  }
  return result;
}

void main() {
  test('destination stays Paris when the brief also contains in October', () {
    expect(
      parseDestinationCity(
        'Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500',
      ),
      'Paris',
    );
    expect(parseDestinationCity('Dinner in Paris, October'), 'Paris');
    expect(
      parseDestinationCity('Dinner in Paris, France in October'),
      'Paris, France',
    );
    expect(parseDestinationCity('October', allowBare: true), isNull);
    expect(parseDestinationCity('Trip to Cape May'), 'Cape May');
  });
  test(
    'online geocoding and forecast values are validated and cached',
    () async {
      var requests = 0;
      var now = DateTime.utc(2026, 10, 6);
      final source = OpenMeteoCityContextSource(
        now: () => now,
        client: MockClient((r) async {
          requests++;
          expect(r.followRedirects, isFalse);
          if (r.url.host.startsWith('geocoding')) {
            expect(r.url.queryParameters['name'], 'Berlin, Germany');
            return http.Response(jsonEncode(geo()), 200);
          }
          expect(r.url.host, 'api.open-meteo.com');
          expect(r.url.queryParameters['timezone'], 'Europe/Berlin');
          return http.Response(
            jsonEncode(forecast()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.dispose);
      final first = await source.fetch('Berlin, Germany');
      expect(first.label, 'Berlin, Germany');
      expect(first.days.first['value'], '12° / 8°');
      expect(first.weatherCard['title'], 'Berlin — forecast');
      expect(await source.fetch('Berlin, Germany'), same(first));
      expect(requests, 2);
      now = now.add(const Duration(minutes: 16));
      await source.fetch('Berlin, Germany');
      expect(requests, 4);
      await source.fetch('Berlin, Germany', refresh: true);
      expect(requests, 6);
    },
  );

  for (final bad in [
    'units',
    'columns',
    'coordinates',
    'not-found',
    'date',
    'http',
    'weather-code',
    'sequence',
  ]) {
    test('invalid $bad data never produces invented weather', () async {
      final source = OpenMeteoCityContextSource(
        client: MockClient((r) async {
          final g = geo();
          final f = forecast();
          if (bad == 'coordinates') {
            ((g['results'] as List).first as Map)['latitude'] = 999;
          }
          if (bad == 'not-found') g['results'] = [];
          if (bad == 'units') {
            (f['daily_units'] as Map)['temperature_2m_max'] = '°F';
          }
          if (bad == 'weather-code') {
            (f['daily'] as Map)['weather_code'] = [4, 3];
          }
          if (bad == 'sequence') {
            (f['daily'] as Map)['time'] = ['2026-10-06', '2026-10-08'];
          }
          if (bad == 'columns') (f['daily'] as Map)['weather_code'] = [];
          if (bad == 'date') {
            (f['daily'] as Map)['time'] = ['2026-02-31', '2026-10-07'];
          }
          return http.Response(
            jsonEncode(r.url.host.startsWith('geocoding') ? g : f),
            bad == 'http' ? 503 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.dispose);
      await expectLater(source.fetch('Berlin'), throwsA(anything));
    });
  }

  test(
    'live context reaches both model facts and A2UI, with no extra view',
    () async {
      final source = FixtureContext();
      final requests = <String>[];
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
        onModelRequest: (r) => requests.add(jsonEncode(r.toJson())),
      );
      addTearDown(runtime.dispose);
      runtime.reset(journey: DemoJourney.berlin);
      final turn = await runtime.turn({
        'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
      });
      final data = inlineData(turn);
      expect((data['weather'] as Map)['title'], 'Berlin — forecast');
      expect(data['cityLabel'], 'Berlin, Test country');
      expect(requests.first, contains('rainProbabilityPercent'));
      expect(requests.first, contains('12'));
      expect(source.calls, hasLength(1));
      expect(
        (presentedStylistTurn(turn)['messages'] as List).any(
          (m) => '$m'.contains('selected-products'),
        ),
        isFalse,
      );
      final count = requests.length;
      final before = jsonEncode(runtime.outfit);
      await runtime.turn({
        'action': {
          'name': 'refresh_city_context',
          'context': <String, Object?>{},
        },
      });
      expect(requests.length, count);
      expect(jsonEncode(runtime.outfit), before);
      expect(source.calls, hasLength(2));
      source.fail = true;
      final failure = await runtime.turn({
        'action': {
          'name': 'refresh_city_context',
          'context': <String, Object?>{},
        },
      });
      expect(inlineData(failure)['weather'], isNull);
      expect(inlineData(failure)['contextNotice'], contains('Could not load'));
      expect(jsonEncode(runtime.outfit), before);
      source.fail = false;
      final changed = await runtime.turn({
        'message':
            'Actually this is a smart casual day in Paris today, budget €900',
      });
      expect(
        (inlineData(changed)['weather'] as Map)['title'],
        'Paris — forecast',
      );
    },
  );

  test(
    'runtime rechecks the source cache and reloads expired forecasts',
    () async {
      var now = DateTime.utc(2026, 10, 6);
      var networkRequests = 0;
      final source = OpenMeteoCityContextSource(
        now: () => now,
        client: MockClient((request) async {
          networkRequests++;
          return http.Response(
            jsonEncode(
              request.url.host.startsWith('geocoding') ? geo() : forecast(),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
      );
      addTearDown(runtime.dispose);
      runtime.reset(journey: DemoJourney.berlin);
      await runtime.turn({
        'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
      });
      await runtime.turn({'message': 'Keep the same destination'});
      expect(networkRequests, 2);
      now = now.add(const Duration(minutes: 16));
      await runtime.turn({'message': 'Suggest another option'});
      expect(networkRequests, 4);
    },
  );

  test('a disposed source never serves a cached forecast', () async {
    final source = OpenMeteoCityContextSource(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.host.startsWith('geocoding') ? geo() : forecast(),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await source.fetch('Berlin');
    source.dispose();
    await expectLater(source.fetch('Berlin'), throwsStateError);
  });

  for (final size in [const Size(466, 678), const Size(951, 669)]) {
    testWidgets(
      'online A2UI widgets render at $size without changing the room',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = SurfaceController(
          catalogs: [buildCommerceCatalog()],
        );
        final sent = <ChatMessage>[];
        final transport = A2uiTransportAdapter(
          onSend: (message) async => sent.add(message),
        );
        final conversation = Conversation(
          controller: controller,
          transport: transport,
        );
        addTearDown(() {
          conversation.dispose();
          controller.dispose();
        });
        final context = await FixtureContext().fetch('Berlin');
        final messages = renderStylistSurfaces(
          turn: 1,
          reply: 'Choose a layer for this forecast.',
          picks: [products.first],
          outfit: {},
          budget: 900,
          occasion: 'Berlin work day',
          cityContext: context,
        );
        for (final message in messages) {
          transport.addMessage(
            core.A2uiMessage.fromJson(Map<String, dynamic>.from(message)),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Surface(surfaceContext: controller.contextFor('inline-1')),
                    Surface(
                      surfaceContext: controller.contextFor('dressing-room'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Berlin — forecast'), findsOneWidget);
        expect(find.text('12° / 8°'), findsOneWidget);
        expect(find.text('Refresh forecast'), findsNothing);
        expect(find.text('Dressing room'), findsOneWidget);
        expect(find.textContaining('Selected pieces'), findsNothing);
        expect(sent, isEmpty);
        final location = tester.getRect(find.text(context.label));
        final weather = tester.getRect(find.text('Berlin — forecast'));
        expect(weather.top - location.bottom, lessThanOrEqualTo(20));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
