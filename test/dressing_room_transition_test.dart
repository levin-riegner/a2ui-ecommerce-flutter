import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products, textResponse;

void main() {
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
      'first-turn imagery stays visible until room ready, failure=$fail',
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
        final originalBounds = tester.getRect(mosaic);
        late Future<void> turn;
        await tester.runAsync(() async {
          turn = agent.startBrief('Dinner in Paris');
          await called.future.timeout(const Duration(seconds: 5));
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Dinner in Paris'), findsOneWidget);
        expect(tester.getRect(mosaic), originalBounds);
        expect(
          find.byKey(const ValueKey('finalized-dressing-room')),
          findsNothing,
        );
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
        if (fail) {
          expect(mosaic, findsOneWidget);
          expect(
            find.byKey(const ValueKey('finalized-dressing-room')),
            findsNothing,
          );
          expect(agent.canRetry, isTrue);
        } else {
          expect(mosaic, findsOneWidget);
          final ready = find.byKey(const ValueKey('dressing-room-ready'));
          final fade = tester.widget<FadeTransition>(
            find
                .ancestor(of: ready, matching: find.byType(FadeTransition))
                .first,
          );
          expect(fade.opacity.value, 0);
          await tester.pump(const Duration(milliseconds: 160));
          expect(fade.opacity.value, greaterThan(0));
          expect(fade.opacity.value, lessThan(1));
          expect(mosaic, findsOneWidget);
          await tester.pumpAndSettle();
          expect(mosaic, findsNothing);
          expect(
            find.byKey(const ValueKey('finalized-dressing-room')),
            findsOneWidget,
          );
        }
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
    return allowRestart;
  }
}
