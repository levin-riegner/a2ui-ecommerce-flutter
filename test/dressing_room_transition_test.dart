import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/stub_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/data/catalog/repository/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products, textResponse;

void main() {
  testWidgets('custom brief releases text input before its outgoing fade', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final agent = (await tester.runAsync(
        () async => GenkitAgent(
          StylistRuntime(products: products, model: offlineStylistModel),
        ),
      ))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('custom-brief-occasion'));
      await tester.enterText(field, 'A spring day');
      await tester.pump();
      final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      // Match browser accessibility activation without a pointer tap that might
      // independently dismiss the keyboard on some platforms.
      final submit = tester.getSemantics(
        find.byKey(const ValueKey('stylist-submit-Start my look')),
      );
      submit.owner!.performAction(submit.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(field, findsOneWidget);
      expect(editable.widget.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(agent.hasStarted, isFalse);
      final opacity = tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('stylist-view-fade')),
          )
          .opacity
          .value;
      expect(opacity, allOf(greaterThan(0), lessThan(1)));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        if (!agent.hasStarted || agent.isBusy) {
          await agent.stream
              .firstWhere((state) => state.hasStarted && !state.isBusy)
              .timeout(const Duration(seconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(agent.hasStarted, isTrue);
      expect(agent.isBusy, isFalse);
      expect(agent.connectionError, isNull);
      expect(field, findsNothing);
      expect(find.byKey(const ValueKey('stylist-composer')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  });

  test(
    'gallery restart removes surfaces and ignores pending fixture results',
    () async {
      final repository = _DelayedGalleryRepository();
      final agent = StubAgent(repository: repository);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.paris);
      final pending = agent.sendMessage('Find options');
      await repository.entered.future;
      expect(await agent.restartChat(), isTrue);
      repository.release.complete();
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(agent.hasStarted, isFalse);
      expect(agent.activeJourney, isNull);
      expect(agent.latestInlineSurfaceId, isNull);
      expect(agent.hasDressingRoomSurface, isFalse);
      expect(
        agent.controller.contextFor('dressing-room').definition.value,
        isNull,
      );
      expect(agent.controller.contextFor('inline-0').definition.value, isNull);
    },
  );

  test(
    'gallery close drains requests without waiting for the fixture repository',
    () async {
      final repository = _DelayedGalleryRepository();
      final agent = StubAgent(repository: repository);
      await agent.startJourney(DemoJourney.paris);
      final pending = agent.sendMessage('Find options');
      await repository.entered.future;
      final closing = agent.close();
      expect(agent.close(), same(closing));
      await expectLater(pending, completes);
      await closing;
      expect(agent.isClosed, isTrue);
      // The uncancellable repository is deliberately released after shutdown.
      repository.release.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'X confirms restart and fades between views, reduceMotion=$reducedMotion',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(951, 669);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: reducedMotion);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final agent = _RestartAgent();
        await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(find.byIcon(Icons.more_horiz), findsNothing);
        Future<void> openConfirmation() async {
          await tester.tap(find.byTooltip('New journey').first);
          await tester.pumpAndSettle();
          expect(find.text('Back to start?'), findsOneWidget);
        }

        await openConfirmation();
        expect(agent.restarts, 0);
        await tester.tap(find.text('Keep styling'));
        await tester.pumpAndSettle();
        expect(find.text('Back to start?'), findsNothing);
        expect(find.text('Dressing room'), findsOneWidget);
        expect(agent.restarts, 0);
        await openConfirmation();
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(agent.restarts, 0);
        await openConfirmation();
        await tester.tap(find.text('Back to start'));
        await tester.pump();
        double opacity() => tester
            .widget<FadeTransition>(
              find.byKey(const ValueKey('stylist-view-fade')),
            )
            .opacity
            .value;
        if (!reducedMotion) {
          await tester.pump(const Duration(milliseconds: 120));
          expect(opacity(), allOf(greaterThan(0), lessThan(1)));
          expect(agent.restarts, 0, reason: 'Reset happens after fading out.');
          await tester.pump(const Duration(milliseconds: 140));
          expect(agent.restarts, 1);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          expect(opacity(), allOf(greaterThan(0), lessThan(1)));
        }
        await tester.pumpAndSettle();
        expect(agent.restarts, 1);
        expect(find.text('Where are you going?'), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(opacity(), 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('failed restart fades back to the current look', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final agent = _RestartAgent()..allowRestart = false;
    await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New journey').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Back to start'));
    await tester.tap(find.text('Back to start'));
    await tester.pumpAndSettle();
    expect(agent.restarts, 1);
    expect(find.text('Where are you going?'), findsNothing);
    expect(find.text('Dressing room'), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('stylist-view-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'first long reply stays at the top and later replies follow the end',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(951, 669);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final agent = (await tester.runAsync(
        () async => GenkitAgent(
          StylistRuntime(
            products: products,
            model: (request) async => request.tools?.isEmpty == true
                ? textResponse(
                    List.filled(
                      30,
                      'Here is a detailed catalog styling suggestion.',
                    ).join('\n'),
                  )
                : offlineStylistModel(request),
          ),
        ),
      ))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      await tester.runAsync(() => agent.startJourney(DemoJourney.lisbon));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('primary-pane-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(500));
      expect(scroll.pixels, 0);
      final originalExtent = scroll.maxScrollExtent;
      agent.transport.addMessage(
        core.A2uiMessage.fromJson({
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': agent.latestInlineSurfaceId!,
            'path': '/message',
            'value': List.filled(
              60,
              'Additional renderer detail in the first reply.',
            ).join('\n'),
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(scroll.maxScrollExtent, greaterThan(originalExtent));
      expect(scroll.pixels, 0);
      await tester.runAsync(
        () => agent.conversation.sendRequest(
          ChatMessage.user('Keep these suggestions'),
        ),
      );
      await tester.pumpAndSettle();
      expect(agent.connectionError, isNull);
      expect(scroll.pixels, closeTo(scroll.maxScrollExtent, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'first-turn room stays visible through model response, failure=$fail',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(951, 669);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gates = (await tester.runAsync(
          () async => (Completer<void>(), Completer<g.ModelResponse>()),
        ))!;
        final called = gates.$1;
        final reply = gates.$2;
        late g.ModelRequest firstRequest;
        var calls = 0;
        final agent = (await tester.runAsync(
          () async => GenkitAgent(
            StylistRuntime(
              products: products,
              model: (request) async {
                if (++calls == 1) {
                  firstRequest = request;
                  called.complete();
                  return reply.future;
                }
                return offlineStylistModel(request);
              },
            ),
          ),
        ))!;
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        final mosaic = find.byKey(const ValueKey('occasion-mosaic'));
        late Future<void> turn;
        await tester.runAsync(() async {
          turn = agent.startBrief('Dinner in Paris');
          await called.future.timeout(const Duration(seconds: 5));
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Dinner in Paris'), findsWidgets);
        expect(mosaic, findsNothing);
        final room = find.byKey(const ValueKey('finalized-dressing-room'));
        expect(room, findsOneWidget);
        final roomElement = tester.element(room);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.runAsync(() async {
          if (fail) {
            reply.completeError(StateError('Controlled model failure'));
          } else {
            reply.complete(await offlineStylistModel(firstRequest));
          }
          await turn;
        });
        await tester.pump();
        await tester.pumpAndSettle();
        expect(mosaic, findsNothing);
        expect(room, findsOneWidget);
        expect(tester.element(room), same(roomElement));
        expect(agent.canRetry, fail);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _RestartAgent extends StubAgent {
  int restarts = 0;
  bool allowRestart = true;
  @override
  Future<bool> restartChat() async {
    restarts++;
    return allowRestart ? super.restartChat() : false;
  }
}

class _DelayedGalleryRepository extends FixtureProductRepository {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<Product>> recommendations({
    required DemoJourney journey,
    required ProductCategory category,
    String? gender,
    int limit = 3,
  }) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return super.recommendations(
      journey: journey,
      category: category,
      gender: gender,
      limit: limit,
    );
  }
}
