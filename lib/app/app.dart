import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../util/dependencies.dart';
import '../presentation/gallery/component_catalog_page.dart';
import '../presentation/stylist/views/stylist_page.dart';
import '../presentation/stylist/bloc/commerce_session.dart';
import '../presentation/shared/layout/duo_layout_adapter.dart';
import '../presentation/shared/design_system/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'navigation/router/app_router.dart';

class ReferenceApp extends StatefulWidget {
  const ReferenceApp({
    super.key,
    this.agent,
    this.connectionClient,
    this.connectionFactory,
    this.sessionBuilder,
    this.dependencies,
  });

  /// Injection for tests and component previews. The app disposes this agent.
  final CommerceSession? agent;
  final Dependencies? dependencies;
  final http.Client? connectionClient;
  final StylistConnectionFactory? connectionFactory;
  final Widget Function(CommerceSession session, VoidCallback onNewJourney)?
  sessionBuilder;

  @override
  State<ReferenceApp> createState() => _ReferenceAppState();
}

class _ReferenceAppState extends State<ReferenceApp> {
  CommerceSession? agent;
  late final Dependencies _dependencies;
  late final bool _ownsDependencies;
  late final router = AppRouter.create();

  @override
  void initState() {
    super.initState();
    agent = widget.agent;
    _ownsDependencies = widget.dependencies == null;
    _dependencies =
        widget.dependencies ??
        Dependencies.defaults(client: widget.connectionClient);
  }

  @override
  void didUpdateWidget(covariant ReferenceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.agent, oldWidget.agent)) {
      final previous = agent;
      agent = widget.agent;
      if (!identical(previous, agent)) previous?.dispose();
    }
  }

  @override
  void dispose() {
    agent?.dispose();
    router.dispose();
    if (_ownsDependencies) _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationScope(
      stylistBuilder: (context) => _buildHome(),
      catalogBuilder: (context) =>
          ComponentCatalogPage(onBack: () => Navigator.of(context).pop()),
      child: MaterialApp.router(
        title: _dependencies.config.title,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => DuoLayoutAdapter(child: child!),
        routerConfig: router,
      ),
    );
  }

  Widget _buildHome() => StylistPage(
    key: ObjectKey(agent),
    agent: agent,
    connectionFactory:
        widget.connectionFactory ?? _dependencies.connectionFactory,
    sessionBuilder: widget.sessionBuilder,
    onConnected: (value) => setState(() => agent = value),
    onDisconnect: widget.agent == null && agent != null
        ? () {
            final previous = agent;
            setState(() => agent = null);
            previous?.dispose();
          }
        : null,
  );
}
