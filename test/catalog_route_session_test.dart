import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/app/navigation/router/app_router.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/component_catalog_page.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/stub_agent.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/views/stylist_page.dart';
import 'package:a2ui_flutter_commerce/util/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';

class _OwnedStubAgent extends StubAgent {
  int disposals = 0;
  int requests = 0;

  @override
  Future<void> sendMessage(String message) {
    requests++;
    return super.sendMessage(message);
  }

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

void main() {
  testWidgets('root rebuild preserves external dependency ownership', (
    tester,
  ) async {
    final dependencies = Dependencies.defaults();
    addTearDown(dependencies.dispose);
    final config = dependencies.config;
    await tester.pumpWidget(ReferenceApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const ReferenceApp());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {});
    expect(dependencies.config, same(config));
  });

  testWidgets(
    'typed catalog push and back preserve the owned session, renderer and draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final agent = _OwnedStubAgent();
      await tester.runAsync(() => agent.startJourney(DemoJourney.lisbon));
      var providerRequests = 0;
      final client = MockClient((_) async {
        providerRequests++;
        throw StateError('Catalog navigation must not contact a provider');
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        ReferenceApp(agent: agent, connectionClient: client),
      );
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('stylist-composer'));
      await tester.enterText(composer, 'Keep my unfinished request');
      await tester.pump();
      final pageState = tester.state(find.byType(StylistPage));
      final controller = agent.controller;
      final room = controller.contextFor('dressing-room');
      final roomData = room.dataModel;
      final roomDefinition = room.definition;
      final context = tester.element(composer);
      final router = GoRouter.of(context);

      final closed = const ComponentCatalogRoute().push<void>(context);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/catalog');
      expect(find.byType(ComponentCatalogPage), findsOneWidget);
      expect(agent.disposals, 0);
      expect(agent.requests, 0);
      expect(providerRequests, 0);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await closed;
      expect(router.state.uri.path, '/');
      expect(tester.state(find.byType(StylistPage)), same(pageState));
      expect(
        tester.widget<StylistPage>(find.byType(StylistPage)).agent,
        same(agent),
      );
      expect(agent.controller, same(controller));
      // GenUI creates a lightweight context wrapper on each contextFor call.
      // Its underlying data model and definition must survive navigation.
      expect(
        agent.controller.contextFor('dressing-room').dataModel,
        same(roomData),
      );
      expect(
        agent.controller.contextFor('dressing-room').definition,
        same(roomDefinition),
      );
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Keep my unfinished request',
      );
      expect(agent.disposals, 0);
      expect(agent.requests, 0);
      expect(providerRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(agent.disposals, 1);
    },
  );
}
