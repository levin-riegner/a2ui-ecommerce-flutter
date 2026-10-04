import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products, textResponse;

ChatMessage select(String id) => ChatMessage.user(
  '',
  parts: [
    UiInteractionPart.create(
      jsonEncode({
        'action': {
          'name': 'select_product',
          'context': {'productId': id},
        },
      }),
    ),
  ],
);

void main() {
  test(
    'bundled agent publishes catalog A2UI and resets outfit on new journeys',
    () async {
      final runtime = StylistRuntime(products: products);
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.lisbon);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(agent.hasSelectedProductsSurface, isTrue);
      expect(agent.hasDressingRoomSurface, isTrue);
      await agent.conversation.sendRequest(select('top-1'));
      expect(runtime.outfit['items'], {'top': 'top-1'});
      expect(agent.latestInlineSurfaceId, 'inline-2');
      await agent.startJourney(DemoJourney.paris);
      expect(runtime.outfit['items'], isEmpty);
      expect(runtime.outfit['budget'], DemoJourney.paris.budget);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(agent.connectionError, isNull);
    },
  );

  testWidgets('failed model turn stays retryable and blocks duplicate input', (
    tester,
  ) async {
    final response = Completer<g.ModelResponse>();
    var calls = 0;
    final agent = GenkitAgent(
      StylistRuntime(
        products: products,
        model: (request) {
          calls++;
          return calls == 1 ? response.future : offlineStylistModel(request);
        },
      ),
    );
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.ensureVisible(find.text(DemoJourney.paris.title));
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Asking your stylist…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    response.completeError(StateError('private provider details'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('private provider details'), findsNothing);
    await agent.conversation.sendRequest(
      ChatMessage.user('Accidental extra message'),
    );
    expect(calls, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 4);
    expect(
      find.text('Offline preview: here are some catalog options.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('retry preserves failed action and existing surfaces without duplicate selection', () async {
    var fail = false;
    var calls = 0;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        calls++;
        if (fail) throw StateError('provider failed');
        return offlineStylistModel(request);
      },
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.lisbon);
    fail = true;
    await agent.conversation.sendRequest(select('top-1'));
    expect(agent.latestInlineSurfaceId, 'inline-1');
    expect(agent.canRetry, isTrue);
    expect(runtime.outfit['items'], isEmpty);
    fail = false;
    final retry = agent.retryLastTurn();
    final duplicate = agent.retryLastTurn();
    final before = calls;
    await Future.wait([retry, duplicate]);
    expect(calls - before, 3);
    expect(agent.latestInlineSurfaceId, 'inline-2');
    expect(runtime.outfit['items'], {'top': 'top-1'});
    expect(agent.connectionError, isNull);
  });

  test('disposing during generation ignores late model response', () async {
    final started = Completer<void>();
    final response = Completer<g.ModelResponse>();
    final agent = GenkitAgent(
      StylistRuntime(
        products: products,
        model: (request) {
          started.complete();
          return response.future;
        },
      ),
    );
    final pending = agent.startJourney(DemoJourney.lisbon);
    await started.future;
    agent.dispose();
    response.complete(textResponse('Late response'));
    await pending;
    expect(agent.latestInlineSurfaceId, isNull);
  });
}
