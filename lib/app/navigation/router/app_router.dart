import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../presentation/gallery/finalized_component_gallery.dart';
import '../../../presentation/gallery/finalized_screen_gallery.dart';

part 'app_router.g.dart';

abstract final class AppRouter {
  static GoRouter create() => GoRouter(routes: $appRoutes);
}

/// Supplies owned session views without putting live resources in route data.
class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.stylistBuilder,
    required this.catalogBuilder,
    required super.child,
  });

  final WidgetBuilder stylistBuilder;
  final WidgetBuilder catalogBuilder;

  static AppNavigationScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationScope>()!;

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      stylistBuilder != oldWidget.stylistBuilder ||
      catalogBuilder != oldWidget.catalogBuilder;
}

@TypedGoRoute<StylistRoute>(
  path: '/',
  routes: [
    TypedGoRoute<ComponentCatalogRoute>(path: 'catalog'),
    TypedGoRoute<FinalizedComponentsRoute>(path: 'catalog/components'),
    TypedGoRoute<FinalizedScreensRoute>(path: 'catalog/screens'),
  ],
)
class StylistRoute extends GoRouteData with $StylistRoute {
  const StylistRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AppNavigationScope.of(context).stylistBuilder(context);
}

class ComponentCatalogRoute extends GoRouteData with $ComponentCatalogRoute {
  const ComponentCatalogRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AppNavigationScope.of(context).catalogBuilder(context);
}

class FinalizedComponentsRoute extends GoRouteData
    with $FinalizedComponentsRoute {
  const FinalizedComponentsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FinalizedComponentGallery();
}

class FinalizedScreensRoute extends GoRouteData with $FinalizedScreensRoute {
  const FinalizedScreensRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FinalizedScreenGallery();
}
