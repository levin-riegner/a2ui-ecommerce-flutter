import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Future<void> finishTurn(WidgetTester tester, GenkitAgent agent) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (!agent.isBusy) break;
  }
  await tester.pumpAndSettle();
  expect(agent.isBusy, isFalse);
  expect(agent.connectionError, isNull);
}

void main() {
  testWidgets(
    'custom occasion reaches one brief form then actual catalog picks',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final catalog = (await tester.runAsync(
        () => CsvProductRepository().search(limit: 250),
      ))!;
      var calls = 0;
      final runtime = StylistRuntime(
        products: catalog,
        model: (request) {
          calls++;
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      await tester.pumpWidget(ReferenceApp(agent: agent));
      final start = find.byKey(const ValueKey('stylist-submit-Start my look'));
      expect(tester.widget<IconButton>(start).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('custom-brief-occasion')),
        'A spring day in Berlin',
      );
      await tester.pump();
      await tester.tap(start);
      await finishTurn(tester, agent);
      expect(agent.hasStarted, isTrue);
      expect(agent.activeJourney, isNull);
      expect(find.text('Where are you going?'), findsNothing);
      expect(find.text('HOW FORMAL OR RELAXED?'), findsOneWidget);
      expect(find.text('BUDGET FOR THE WHOLE OUTFIT'), findsOneWidget);
      expect(find.text('Find options'), findsOneWidget);
      expect(runtime.outfit['budget'], isNull);
      expect(runtime.outfit['items'], isEmpty);
      final callsBefore = calls;
      await tester.ensureVisible(find.text('smart-casual'));
      await tester.tap(find.text('smart-casual'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(45, 0));
      await tester.pumpAndSettle();
      expect(calls, callsBefore);
      expect(runtime.outfit['budget'], isNull);
      final submittedBudget = agent.controller
          .contextFor('inline-1')
          .dataModel
          .getValue<num>(DataPath('/budget'));
      await tester.ensureVisible(find.text('Find options'));
      await tester.tap(find.text('Find options'));
      await finishTurn(tester, agent);
      expect(calls, greaterThan(callsBefore));
      expect(
        runtime.outfit['budget'],
        closeTo(submittedBudget!.toDouble(), 0.005),
      );
      expect(
        agent.controller
            .contextFor('dressing-room')
            .dataModel
            .getValue<String>(DataPath('/brief')),
        contains('smart casual'),
      );
      final currentSurface = find.byKey(ValueKey(agent.latestInlineSurfaceId));
      expect(
        find.descendant(
          of: currentSurface,
          matching: find.text('Find options'),
        ),
        findsNothing,
      );
      // The submitted brief stays readable in the inactive conversation history.
      expect(find.text('Find options'), findsOneWidget);
      final previousSurface = find.byKey(
        const ValueKey('conversation-surface-inline-1'),
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: previousSurface,
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      final data = agent.controller
          .contextFor(agent.latestInlineSurfaceId!)
          .dataModel;
      final id = data.getValue<String>(DataPath('/recommendations/0/id'));
      final name = data.getValue<String>(DataPath('/recommendations/0/name'));
      expect(id, isNotNull);
      expect(catalog.where((product) => product.id == id), hasLength(1));
      expect(find.text(name!), findsOneWidget);
      expect(find.text('Add to dressing room'), findsWidgets);
      expect(find.text('Dressing room'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Starting an example replaces the prior brief and selected outfit.
      await tester.tap(find.byTooltip('New journey').first);
      await tester.pumpAndSettle();
      final parisExample = find.textContaining(
        'Anniversary dinner at a smart restaurant',
      );
      await Scrollable.ensureVisible(
        tester.element(parisExample),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(parisExample);
      await finishTurn(tester, agent);
      expect(agent.activeJourney, isNull);
      expect(runtime.outfit['budget'], 1500);
      expect(runtime.outfit['items'], isEmpty);
      expect(
        agent.controller
            .contextFor('dressing-room')
            .dataModel
            .getValue<String>(DataPath('/brief')),
        allOf(
          contains('Anniversary dinner'),
          contains('Paris in October'),
          contains('black tie'),
        ),
      );
      expect(find.text('A spring day in Berlin'), findsNothing);
    },
  );

  testWidgets('custom occasion entry remains usable at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final agent = GenkitAgent(StylistRuntime(products: []));
    await tester.pumpWidget(ReferenceApp(agent: agent));
    final occasion = find.byKey(const ValueKey('custom-brief-occasion'));
    await tester.ensureVisible(occasion);
    await tester.enterText(occasion, 'A weekend away');
    await tester.pump();
    final button = find.byKey(const ValueKey('stylist-submit-Start my look'));
    await tester.ensureVisible(button);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
