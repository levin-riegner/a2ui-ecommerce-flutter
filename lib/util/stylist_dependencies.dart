import '../data/catalog/repository/csv_catalog_source.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/catalog/repository/product_repository.dart';
import '../data/stylist/repository/stylist_repository.dart';
import '../data/stylist/repository/stylist_snapshot_repository.dart';
import '../data/stylist/service/local/shared_preferences_stylist_service.dart';
import '../data/weather/repository/weather_repository.dart';
import '../data/weather/service/remote/open_meteo_weather_service.dart';
import '../presentation/stylist/bloc/stylist_bloc.dart';
import '../data/weather/model/city_context.dart';
import '../data/stylist/service/remote/genkit_providers.dart';
import '../data/stylist/model/model_settings.dart';
import '../data/stylist/service/runtime/stylist_runtime.dart';
import '../data/catalog/model/catalog_snapshot.dart';
import '../data/stylist/repository/stylist_store.dart';
import '../presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import '../presentation/stylist/a2ui/catalog/model_catalog.dart';
import '../presentation/stylist/bloc/commerce_inspector_bloc.dart';

/// The composition boundary owns platform defaults; UI and domain accept ports.
class StylistDependencies {
  const StylistDependencies({
    required this.catalog,
    required this.provider,
    this.store,
    this.weather,
  });

  factory StylistDependencies.defaults({
    http.Client? client,
    bool onlineContext = true,
    CatalogSource? catalog,
    StylistStore? store,
  }) => StylistDependencies(
    catalog:
        catalog ??
        CatalogRepository(
          source: CsvCatalogSource(
            readText: () => rootBundle.loadString(bundledCatalogPath),
          ),
        ),
    provider: (settings) => GenkitProvider(settings, client: client),
    store:
        store ??
        StylistSnapshotRepository(service: SharedPreferencesStylistService()),
    weather: onlineContext
        ? () => WeatherRepository(service: OpenMeteoWeatherService())
        : null,
  );

  final CatalogSource catalog;
  final GenkitProvider Function(ModelSettings) provider;
  final StylistStore? store;
  final CityContextSource Function()? weather;

  Future<StylistBloc> connect(ModelSettings settings) async {
    GenkitProvider? connection;
    StylistBloc? agent;
    CityContextSource? cityContext;
    CommerceInspectorBloc? inspector;
    try {
      final snapshot = await catalog.load();
      connection = provider(settings);
      cityContext = weather?.call();
      final uiCatalog = buildCommerceCatalog();
      final modelCatalog = buildModelUiCatalog(uiCatalog);
      inspector = CommerceInspectorBloc(catalog: modelCatalog);
      agent = StylistBloc(
        StylistRepository(
          runtime: StylistRuntime(
            products: snapshot.products,
            catalog: snapshot,
            cityContextSource: cityContext,
            providerModel: connection.model,
            onBeginTurn: connection.beginTurn,
            onCancelTurn: connection.cancelTurn,
            store: store,
            uiCatalog: modelCatalog,
            onTrace: inspector.record,
          ),
          provider: connection,
        ),
        catalog: uiCatalog,
        inspector: inspector,
      );
      await agent.resumeLocalState();
      return agent;
    } catch (_) {
      if (agent != null) {
        agent.dispose();
      } else {
        await inspector?.close();
        cityContext?.dispose();
        connection?.dispose();
        settings.clear();
      }
      rethrow;
    }
  }
}

/// Convenience for CLI/demo callers. App widgets receive an injected factory.
Future<StylistBloc> connectStylist({
  required String provider,
  required String model,
  required String apiKey,
  String? baseUrl,
  http.Client? client,
  bool onlineContext = false,
  StylistStore? store,
  CatalogSource? catalog,
}) =>
    StylistDependencies.defaults(
      client: client,
      onlineContext: onlineContext,
      store: store,
      catalog: catalog,
    ).connect(
      ModelSettings(
        provider: provider,
        model: model,
        apiKey: apiKey,
        baseUrl: baseUrl,
      ),
    );
