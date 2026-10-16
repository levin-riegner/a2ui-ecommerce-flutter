import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../app/config/app_config.dart';
import '../presentation/stylist/bloc/commerce_session.dart';
import 'stylist_dependencies.dart';

/// An application-owned registry, with constructor injection below the root.
/// Separate registries keep embedded instances and widget tests isolated.
class Dependencies {
  Dependencies._(this._registry);

  factory Dependencies.defaults({http.Client? client}) {
    final registry = GetIt.asNewInstance();
    registry.registerSingleton<AppConfig>(const AppConfig());
    registry.registerLazySingleton<StylistDependencies>(
      () => StylistDependencies.defaults(client: client),
    );
    return Dependencies._(registry);
  }

  final GetIt _registry;

  AppConfig get config => _registry<AppConfig>();
  StylistConnectionFactory get connectionFactory =>
      (settings) => _registry<StylistDependencies>().connect(settings);

  Future<void> dispose() => _registry.reset();
}
