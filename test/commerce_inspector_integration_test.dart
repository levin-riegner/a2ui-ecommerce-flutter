import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/commerce_trace.dart';
import 'package:a2ui_flutter_commerce/data/stylist/repository/stylist_repository.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_event.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_shared_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';

Future<void> _drain() => Future<void>.delayed(Duration.zero);

String _diagnostics(CommerceInspectorBloc inspector) => jsonEncode([
  for (final entry in inspector.state.entries)
    {'kind': entry.kind.name, 'details': entry.details},
]);

Future<void> _chooseView(
  WidgetTester tester,
  Finder button,
  String view,
) async {
  await tester.tap(
    view == 'Inspect'
        ? button
        : find.byKey(const ValueKey('commerce-inspector-close')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(_drain);
  await tester.pump();
}

void main() {
  testWidgets(
    'the real session can inspect a pending turn without replacing its draft or renderer',
    (tester) async {
      tester.view.physicalSize = const Size(1456, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Completer<void> entered;
      late Completer<void> release;
      var hold = false;
      var calls = 0;
      // BLoC and Genkit subscriptions must be created in the same real async
      // zone that runs their commands; otherwise fake widget timers can stall
      // an awaited provider request before it reaches the test model.
      final agent = (await tester.runAsync(() async {
        entered = Completer<void>();
        release = Completer<void>();
        final catalog = buildCommerceCatalog();
        final inspector = CommerceInspectorBloc(
          catalog: buildModelUiCatalog(catalog),
        );
        final runtime = StylistRuntime(
          products: products,
          uiCatalog: inspector.catalog,
          onTrace: inspector.record,
          model: (request) async {
            calls++;
            if (hold) {
              hold = false;
              entered.complete();
              await release.future;
            }
            return offlineStylistModel(request);
          },
        );
        final agent = StylistBloc(
          StylistRepository(runtime: runtime),
          catalog: catalog,
          inspector: inspector,
        );
        await agent
            .startBrief('A casual outfit under €500.')
            .timeout(const Duration(seconds: 5));
        return agent;
      }))!;
      final inspector = agent.inspector!;
      addTearDown(() {
        if (!release.isCompleted) release.complete();
        agent.dispose();
      });
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('stylist-composer'));
      await tester.enterText(composer, 'Keep this unsent draft');
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      final controller = agent.controller;
      final room = controller.contextFor('dressing-room').definition.value;
      final latest = agent.latestInlineSurfaceId;
      final roomSurface = find.byKey(const ValueKey('dressing-room-resize'));
      final roomBounds = tester.getRect(roomSurface);
      final inspectBounds = tester.getRect(
        find.byKey(const ValueKey('commerce-inspect-button')),
      );
      final closeBounds = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('dressing-room-side-rail')),
          matching: find.byIcon(Icons.close),
        ),
      );
      expect(inspectBounds.center.dx, closeBounds.center.dx);
      expect(inspectBounds.top, greaterThan(closeBounds.bottom));
      expect(inspectBounds.overlaps(roomBounds), isFalse);
      expect(find.text('Inspect'), findsNothing);
      expect(find.text('Experience'), findsNothing);
      hold = true;
      late Future<void> pending;
      await tester.runAsync(() async {
        pending = agent.sendMessage('Show me another top.');
        await entered.future.timeout(const Duration(seconds: 5));
      });
      await tester.pump();
      expect(agent.isBusy, isTrue);
      final waitingCalls = calls;
      await _chooseView(
        tester,
        find.byKey(const ValueKey('commerce-inspect-button')),
        'Inspect',
      );
      expect(inspector.state.inspecting, isTrue);
      expect(find.text('Under the hood'), findsOneWidget);
      expect(agent.isBusy, isTrue);
      expect(calls, waitingCalls);
      await _chooseView(
        tester,
        find.byKey(const ValueKey('commerce-inspect-button')),
        'Experience',
      );
      expect(inspector.state.inspecting, isFalse);
      expect(agent.controller, same(controller));
      expect(
        agent.controller.contextFor('dressing-room').definition.value,
        same(room),
      );
      expect(agent.latestInlineSurfaceId, latest);
      expect(tester.getRect(roomSurface), roomBounds);
      final retained = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(retained, same(editor));
      expect(retained.widget.controller.text, 'Keep this unsent draft');
      expect(calls, waitingCalls);
      await tester.runAsync(() async {
        release.complete();
        await pending.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(agent.connectionError, isNull);
      final commits = inspector.state.entries.where(
        (entry) => entry.kind == CommerceTraceKind.surfaceCommit,
      );
      expect(commits, isNotEmpty);
      expect(
        commits.every((entry) => entry.details['origin'] == 'hostComposed'),
        isTrue,
      );
      expect(commits.last.details['recommendationChoice'], 'modelSelected');
      expect(commits.last.details['components'], contains('PicksStrip'));
      final responses = inspector.state.entries.where(
        (entry) => entry.kind == CommerceTraceKind.modelResponse,
      );
      expect(responses, isNotEmpty);
      expect(
        responses.every((entry) => entry.details['source'] == 'injected'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final rightPadding in [0.0, 84.0]) {
    testWidgets(
      'compact inspector uses the toolbar after safe inset $rightPadding',
      (tester) async {
        tester.view.physicalSize = Size(rightPadding == 0 ? 390 : 466, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(right: rightPadding);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        var calls = 0;
        final agent = (await tester.runAsync(() async {
          final source = buildCommerceCatalog();
          final inspector = CommerceInspectorBloc(
            catalog: buildModelUiCatalog(source),
          );
          final runtime = StylistRuntime(
            products: products,
            store: MemoryStylistStore(),
            uiCatalog: inspector.catalog,
            onTrace: inspector.record,
            onModelRequest: (_) => calls++,
          );
          final agent = StylistBloc(
            StylistRepository(runtime: runtime),
            catalog: source,
            inspector: inspector,
          );
          await agent.startBrief('A casual outfit under €500.');
          return agent;
        }))!;
        addTearDown(agent.dispose);
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        final room = find.byKey(const ValueKey('finalized-dressing-room'));
        final roomBounds = tester.getRect(room);
        final button = find.byKey(const ValueKey('commerce-inspect-button'));
        final header = find.byKey(const ValueKey('alder-journey-header'));
        expect(find.descendant(of: header, matching: button), findsOneWidget);
        expect(
          find.byKey(const ValueKey('commerce-inspect-circle')),
          findsNothing,
        );
        expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(tester.getRect(header).bottom),
        );
        expect(tester.getRect(button).overlaps(roomBounds), isFalse);
        final beforeCalls = calls;
        await _chooseView(tester, button, 'Inspect');
        expect(
          tester
              .getRect(find.byKey(const ValueKey('commerce-inspector-sheet')))
              .size,
          Size(rightPadding == 0 ? 390 : 466, 844),
        );
        await _chooseView(tester, button, 'Experience');
        expect(tester.getRect(room), roomBounds);
        expect(calls, beforeCalls);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, scale) in [
    (const Size(1456, 840), 1.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets(
      'the actual basket toggles to diagnostics and retains quantities at $size text $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var calls = 0;
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
            uiCatalog: inspector.catalog,
            onTrace: inspector.record,
            onModelRequest: (_) => calls++,
          );
          final agent = StylistBloc(
            StylistRepository(runtime: runtime),
            catalog: catalog,
            inspector: inspector,
          );
          await agent.resumeLocalState();
          await agent.openBag();
          return agent;
        }))!;
        addTearDown(agent.dispose);
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        final inspector = agent.inspector!;
        final controller = agent.controller;
        final inline = agent.latestInlineSurfaceId;
        final dialog = find.byKey(const ValueKey('stylist-bag-dialog'));
        Finder inDialog(Finder matching) =>
            find.descendant(of: dialog, matching: matching);
        Finder inSheet(Finder matching) => find.descendant(
          of: find.byKey(const ValueKey('commerce-inspector-sheet')),
          matching: matching,
        );
        final bag = inDialog(find.byType(FinalizedBagPreview));
        expect(bag, findsOneWidget);
        final bagElement = tester.element(bag);
        final initialBagBounds = tester.getRect(bag);
        final quantity = inDialog(
          find.byKey(const ValueKey('bag-quantity-demo-0092')),
        );
        final before = tester.widget<FinalizedQuantityStepper>(quantity).value;
        expect(before, 1);
        expect(agent.bagCount, before);
        final callsBefore = calls;
        final entriesBefore = inspector.state.entries.length;
        expect(inDialog(find.text('Inspect')), findsNothing);
        expect(inDialog(find.text('Experience')), findsNothing);
        await _chooseView(
          tester,
          inDialog(find.byKey(const ValueKey('commerce-inspect-button'))),
          'Inspect',
        );
        await tester.pumpAndSettle();
        expect(inspector.state.inspecting, isTrue);
        expect(inSheet(find.text('Under the hood')), findsOneWidget);
        final commits = inspector.state.entries.where(
          (entry) => entry.kind == CommerceTraceKind.surfaceCommit,
        );
        expect(commits.last.details['origin'], 'hostComposed');
        expect(commits.last.details['bagCount'], before);
        expect(commits.last.details['components'], contains('BagPreview'));
        final latestCommit = find.descendant(
          of: inSheet(find.byKey(ObjectKey(commits.last))),
          matching: find.text('Host-composed surface'),
        );
        final exchangeList = inSheet(
          find.byKey(const PageStorageKey('commerce-inspector-exchanges')),
        );
        expect(exchangeList, findsOneWidget);
        final scrollable = find.descendant(
          of: exchangeList,
          matching: find.byType(Scrollable),
        );
        expect(scrollable, findsOneWidget);
        await tester.scrollUntilVisible(
          latestCommit,
          250,
          scrollable: scrollable,
          maxScrolls: 20,
        );
        await tester.pumpAndSettle();
        expect(latestCommit.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _chooseView(
          tester,
          inDialog(find.byKey(const ValueKey('commerce-inspect-button'))),
          'Experience',
        );
        await tester.pumpAndSettle();
        expect(tester.element(bag), same(bagElement));
        expect(tester.widget<FinalizedQuantityStepper>(quantity).value, before);
        expect(agent.bagCount, before);
        expect(agent.controller, same(controller));
        expect(agent.latestInlineSurfaceId, inline);
        expect(inspector.state.entries.length, entriesBefore);
        expect(calls, callsBefore);
        expect(calls, 0);
        final bagBounds = tester.getRect(bag);
        expect(bagBounds, initialBagBounds);
        expect(bagBounds.left, greaterThanOrEqualTo(24));
        expect(bagBounds.right, lessThanOrEqualTo(size.width - 24));
        expect(bagBounds.top, greaterThanOrEqualTo(24));
        expect(bagBounds.bottom, lessThanOrEqualTo(size.height - 24));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('basket mutations publish host provenance and committed counts without a model', () async {
    final store = MemoryStylistStore();
    final seed = await completed(store: store);
    await seed.turn({
      'action': {'name': 'add_look_to_bag', 'context': <String, Object?>{}},
    });
    await seed.dispose();
    final catalog = buildCommerceCatalog();
    final inspector = CommerceInspectorBloc(
      catalog: buildModelUiCatalog(catalog),
    );
    var calls = 0;
    final runtime = StylistRuntime(
      products: libraryCatalog,
      store: store,
      uiCatalog: inspector.catalog,
      onTrace: inspector.record,
      onModelRequest: (_) => calls++,
    );
    final agent = StylistBloc(
      StylistRepository(runtime: runtime),
      catalog: catalog,
      inspector: inspector,
    );
    addTearDown(agent.close);
    await agent.resumeLocalState();
    await agent.openBag();
    expect(agent.bagCount, 1);
    agent.add(
      const StylistEvent.messageSubmitted(
        message: '',
        action: {
          'name': 'remove_bag_item',
          'context': {'productId': 'demo-0092'},
        },
      ),
    );
    if (agent.state.isBusy) {
      await agent.stream.firstWhere((state) => !state.isBusy);
    }
    await _drain();
    expect(agent.bagCount, 0);
    expect(calls, 0);
    final commits = inspector.state.entries.where(
      (entry) => entry.kind == CommerceTraceKind.surfaceCommit,
    );
    expect(commits, isNotEmpty);
    expect(commits.last.details['bagCount'], 0);
    expect(commits.last.details['origin'], 'hostComposed');
    expect(commits.last.details['recommendationChoice'], 'hostSelected');
    expect(
      inspector.state.entries.where(
        (entry) => entry.kind == CommerceTraceKind.modelRequest,
      ),
      isEmpty,
    );
  });

  test(
    'a late cancelled model response never appears as a new exchange or commit',
    () async {
      final catalog = buildCommerceCatalog();
      final inspector = CommerceInspectorBloc(
        catalog: buildModelUiCatalog(catalog),
      );
      final entered = Completer<void>();
      final release = Completer<g.ModelResponse>();
      final runtime = StylistRuntime(
        products: products,
        uiCatalog: inspector.catalog,
        onTrace: inspector.record,
        model: (request) async {
          entered.complete();
          return release.future;
        },
      );
      final agent = StylistBloc(
        StylistRepository(runtime: runtime),
        catalog: catalog,
        inspector: inspector,
      );
      addTearDown(agent.close);
      final pending = agent.startBrief('A casual outfit under €500.');
      await entered.future;
      expect(await agent.restartChat(), isTrue);
      await pending;
      await _drain();
      final afterRestart = _diagnostics(inspector);
      release.complete(
        g.ModelResponse(
          finishReason: g.FinishReason.stop,
          message: g.Message(
            role: g.Role.model,
            content: [g.TextPart(text: 'Late private response.')],
          ),
        ),
      );
      await _drain();
      await _drain();
      expect(_diagnostics(inspector), afterRestart);
      expect(
        inspector.state.entries.where(
          (entry) => entry.kind == CommerceTraceKind.modelResponse,
        ),
        isEmpty,
      );
      // Restart itself commits a host-owned reset before clearing surfaces.
      // The abandoned model response must not add another commit to it.
      final resetCommit = inspector.state.entries.singleWhere(
        (entry) => entry.kind == CommerceTraceKind.surfaceCommit,
      );
      expect(resetCommit.details['origin'], 'hostComposed');
      expect(resetCommit.details['recommendationChoice'], 'hostSelected');
      expect(agent.latestInlineSurfaceId, isNull);
      expect(agent.connectionError, isNull);
    },
  );

  test(
    'actual user and decoded model prose are withheld from public diagnostics',
    () async {
      const canary = 'private-canary-auth-Bearer-9137';
      final catalog = buildCommerceCatalog();
      final inspector = CommerceInspectorBloc(
        catalog: buildModelUiCatalog(catalog),
      );
      final runtime = StylistRuntime(
        products: products,
        uiCatalog: inspector.catalog,
        onTrace: inspector.record,
        model: (request) async {
          if (request.tools?.isEmpty == true) {
            return g.ModelResponse(
              finishReason: g.FinishReason.stop,
              message: g.Message(
                role: g.Role.model,
                content: [g.TextPart(text: canary)],
              ),
            );
          }
          return offlineStylistModel(request);
        },
      );
      final agent = StylistBloc(
        StylistRepository(runtime: runtime),
        catalog: catalog,
        inspector: inspector,
      );
      addTearDown(agent.close);
      await agent.startBrief('A casual outfit under €500. $canary');
      await _drain();
      expect(agent.connectionError, isNull);
      expect(_diagnostics(inspector), isNot(contains(canary)));
      final client = inspector.state.entries.firstWhere(
        (entry) => entry.kind == CommerceTraceKind.clientInput,
      );
      expect(client.details['messageContent'], 'withheld');
      final responses = inspector.state.entries.where(
        (entry) => entry.kind == CommerceTraceKind.modelResponse,
      );
      expect(responses.last.details['textCharacters'], canary.length);
      expect(responses.last.details['textContent'], 'withheld');
    },
  );

  for (final attack in ['tool', 'component']) {
    test(
      'untrusted $attack identifiers cannot smuggle prompt or credential text into diagnostics',
      () async {
        const canary = 'private-canary-x-api-key-8271';
        final inspector = CommerceInspectorBloc(
          catalog: buildModelUiCatalog(buildCommerceCatalog()),
        );
        final runtime = StylistRuntime(
          products: products,
          uiCatalog: inspector.catalog,
          onTrace: inspector.record,
          model: (request) async {
            if (attack == 'tool') {
              return g.ModelResponse(
                finishReason: g.FinishReason.stop,
                message: g.Message(
                  role: g.Role.model,
                  content: [
                    g.ToolRequestPart(
                      toolRequest: g.ToolRequest(
                        name: canary,
                        ref: canary,
                        input: {'authorization': canary},
                      ),
                    ),
                  ],
                ),
              );
            }
            final response = await offlineStylistModel(request);
            for (final part in response.message?.content ?? <g.Part>[]) {
              final tool = part.toolRequest;
              if (tool?.name == 'present_products') {
                tool!.input = {...tool.input as Map, 'component': canary};
              }
            }
            return response;
          },
        );
        addTearDown(runtime.dispose);
        addTearDown(inspector.close);
        await expectLater(
          runtime.turn({'message': 'A casual outfit under €500.'}),
          throwsA(anything),
        );
        await _drain();
        expect(_diagnostics(inspector), isNot(contains(canary)));
        expect(_diagnostics(inspector), contains('unrecognized'));
        expect(
          inspector.state.entries.where(
            (entry) => entry.kind == CommerceTraceKind.modelResponse,
          ),
          isNotEmpty,
        );
        expect(runtime.outfit['items'], isEmpty);
      },
    );
  }

  test('the diagnostic component allowlist stays equal to actual selectable registrations', () {
    final manifest = buildModelUiCatalog(buildCommerceCatalog());
    expect(
      CommerceTraceEntry.modelComponents,
      manifest.modelSelectableComponents.toSet(),
    );
  });
}
