import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/data/stylist/repository/stylist_repository.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_store_helpers.dart';

void main() {
  testWidgets('iPhone 17 completion stays singular through bag and inspect', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    var modelCalls = 0;
    final agent = (await tester.runAsync(() async {
      final store = MemoryStylistStore();
      final seed = await completed(store: store);
      await seed.dispose();
      final catalog = buildCommerceCatalog();
      final inspector = CommerceInspectorBloc(
        catalog: buildModelUiCatalog(catalog),
      );
      final runtime = StylistRuntime(
        products: libraryCatalog,
        store: store,
        onModelRequest: (_) => modelCalls++,
      );
      final agent = StylistBloc(
        StylistRepository(runtime: runtime),
        catalog: catalog,
        inspector: inspector,
      );
      await agent.resumeLocalState();
      return agent;
    }))!;
    addTearDown(agent.dispose);
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.pumpAndSettle();
    final entryCount = agent.conversationEntries.length;
    final summary = find.byWidgetPredicate(
      (w) => w is FinalizedRightComponent && w.component == 'LookSummary',
    );
    expect(summary, findsOneWidget);
    expect(find.text('Save look'), findsNothing);
    expect(find.textContaining('Saved looks'), findsNothing);
    expect(find.text('Your selected sizes'), findsNothing);
    final root = agent.controller
        .contextFor(agent.latestInlineSurfaceId!)
        .definition
        .value!
        .components['root']!;
    expect((root.properties['children'] as List).last, 'add-look-to-bag');

    Future<void> tapAction(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final settled = agent.stream
            .firstWhere((state) => !state.isBusy)
            .timeout(const Duration(seconds: 5));
        await tester.tap(finder);
        await settled;
      });
      await tester.pumpAndSettle();
      expect(agent.connectionError, isNull);
      expect(agent.inputError, isNull);
    }

    await tapAction(find.text('Add look to demo bag · €230.00'));
    for (var cycle = 0; cycle < 3; cycle++) {
      if (cycle > 0) {
        await tester.runAsync(agent.openBag);
        await tester.pumpAndSettle();
      }
      final bag = find.byType(FinalizedBagPreview);
      expect(bag, findsOneWidget);
      final footer = tester.getRect(find.byKey(const ValueKey('bag-footer')));
      expect(footer.bottom, closeTo(tester.getRect(bag).bottom - 18, .1));
      expect(find.text('Check out').hitTestable(), findsOneWidget);
      final inspect = find.descendant(
        of: find.byKey(const ValueKey('stylist-bag-dialog')),
        matching: find.byKey(const ValueKey('commerce-inspect-button')),
      );
      await tester.tap(inspect);
      await tester.pumpAndSettle();
      final close = find.byKey(const ValueKey('commerce-inspector-close'));
      expect(tester.getRect(close).top, greaterThanOrEqualTo(62 + 12));
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      await tapAction(find.widgetWithText(OutlinedButton, 'Keep styling'));
      expect(find.byType(FinalizedBagPreview), findsNothing);
      expect(agent.conversationEntries.length, entryCount);
      expect(
        agent.renderer.surfaceIds,
        unorderedEquals(['dressing-room', agent.latestInlineSurfaceId]),
      );
      expect(summary, findsOneWidget);
      expect(find.text('Save look'), findsNothing);
      expect(find.text('Your selected sizes'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(agent.bagCount, 1);
    expect(modelCalls, 0);
  });
}
