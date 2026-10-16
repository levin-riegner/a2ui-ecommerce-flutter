// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$stylistRoute];

RouteBase get $stylistRoute => GoRouteData.$route(
  path: '/',
  hasOverriddenOnExit: false,
  factory: $StylistRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'catalog',
      hasOverriddenOnExit: false,
      factory: $ComponentCatalogRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'catalog/components',
      hasOverriddenOnExit: false,
      factory: $FinalizedComponentsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'catalog/screens',
      hasOverriddenOnExit: false,
      factory: $FinalizedScreensRoute._fromState,
    ),
  ],
);

mixin $StylistRoute on GoRouteData {
  static StylistRoute _fromState(GoRouterState state) => const StylistRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ComponentCatalogRoute on GoRouteData {
  static ComponentCatalogRoute _fromState(GoRouterState state) =>
      const ComponentCatalogRoute();

  @override
  String get location => GoRouteData.$location('/catalog');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FinalizedComponentsRoute on GoRouteData {
  static FinalizedComponentsRoute _fromState(GoRouterState state) =>
      const FinalizedComponentsRoute();

  @override
  String get location => GoRouteData.$location('/catalog/components');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FinalizedScreensRoute on GoRouteData {
  static FinalizedScreensRoute _fromState(GoRouterState state) =>
      const FinalizedScreensRoute();

  @override
  String get location => GoRouteData.$location('/catalog/screens');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
