import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'agent/city_context.dart';
import 'agent/genkit_agent.dart';
import 'agent/genkit_providers.dart';
import 'agent/model_settings.dart';
import 'agent/stylist_runtime.dart';
import 'data/catalog_snapshot.dart';
import 'data/local_stylist_store.dart';
import 'data/stylist_store.dart';

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
        CsvCatalogSource(
          readText: () => rootBundle.loadString(bundledCatalogPath),
        ),
    provider: (settings) => GenkitProvider(settings, client: client),
    store: store ?? LocalStylistStore(),
    weather: onlineContext ? () => OpenMeteoCityContextSource() : null,
  );

  final CatalogSource catalog;
  final GenkitProvider Function(ModelSettings) provider;
  final StylistStore? store;
  final CityContextSource Function()? weather;

  Future<GenkitAgent> connect(ModelSettings settings) async {
    GenkitProvider? connection;
    GenkitAgent? agent;
    CityContextSource? cityContext;
    try {
      final snapshot = await catalog.load();
      connection = provider(settings);
      cityContext = weather?.call();
      agent = GenkitAgent(
        StylistRuntime(
          products: snapshot.products,
          catalog: snapshot,
          cityContextSource: cityContext,
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
          store: store,
        ),
        provider: connection,
      );
      await agent.resumeLocalState();
      return agent;
    } catch (_) {
      if (agent != null) {
        agent.dispose();
      } else {
        cityContext?.dispose();
        connection?.dispose();
        settings.clear();
      }
      rethrow;
    }
  }
}

/// Convenience for CLI/demo callers. App widgets receive an injected factory.
Future<GenkitAgent> connectStylist({
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
