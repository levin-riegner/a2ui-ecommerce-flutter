import 'package:a2ui_flutter_commerce/src/agent/stylist_result.dart';

import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' show CancellationToken;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products;

ChatMessage _pieceAction(String name, String id) => ChatMessage.user(
  '',
  parts: [
    UiInteractionPart.create(
      jsonEncode({
        'action': {
          'name': name,
          'surfaceId': 'dressing-room',
          'context': {'productId': id},
        },
      }),
    ),
  ],
);

void main() {
  test(
    'a budget conflict preserves the outfit and allows a corrective turn',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          calls++;
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.lisbon);
      await agent.conversation.sendRequest(
        _pieceAction('select_product', 'top-1'),
      );
      final before = Map<String, dynamic>.from(runtime.outfit);
      final surface = agent.latestInlineSurfaceId;
      final callsBeforeConflict = calls;

      await agent.conversation.sendRequest(
        ChatMessage.user('My budget is €20'),
      );

      expect(agent.inputError, isNotEmpty);
      expect(agent.connectionError, isNull);
      expect(agent.canRetry, isFalse);
      expect(agent.isBusy, isFalse);
      expect(agent.pendingInlineSurfaceId, isNull);
      expect(agent.latestInlineSurfaceId, surface);
      expect(runtime.outfit, before);
      expect(calls, callsBeforeConflict);
      expect(
        agent.conversationEntries.whereType<CommerceUserMessage>().last.text,
        'My budget is €20',
      );

      // Retry must not replay an instruction that needs a different decision.
      await agent.retryLastTurn();
      expect(calls, callsBeforeConflict);
      await agent.conversation.sendRequest(
        _pieceAction('remove_product', 'top-1'),
      );
      expect(runtime.outfit['items'], isEmpty);
      expect(agent.inputError, isNull);
      expect(agent.connectionError, isNull);
      await agent.conversation.sendRequest(
        ChatMessage.user('My budget is €100'),
      );
      expect(runtime.outfit['budget'], 100);
      expect(agent.inputError, isNull);
    },
  );

  testWidgets(
    'budget recovery stays visible and the composer accepts a correction',
    (tester) async {
      final runtime = StylistRuntime(products: products);
      final agent = GenkitAgent(runtime);
      final start = agent.startJourney(DemoJourney.lisbon);
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      await start;
      final selection = agent.conversation.sendRequest(
        _pieceAction('select_product', 'top-1'),
      );
      await tester.pumpAndSettle();
      await selection;
      final conflict = agent.conversation.sendRequest(
        ChatMessage.user('My budget is €20'),
      );
      await tester.pumpAndSettle();
      await conflict;

      expect(find.text('Update your outfit'), findsOneWidget);
      expect(find.text('Stylist unavailable'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('API key'), findsNothing);
      final composer = find.byKey(const ValueKey('stylist-composer'));
      expect(tester.widget<TextField>(composer).enabled, isTrue);

      await tester.enterText(composer, 'My budget is €100');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(runtime.outfit['budget'], 100);
      expect(runtime.outfit['items'], {'top': 'top-1'});
      expect(agent.inputError, isNull);
      expect(find.text('Update your outfit'), findsNothing);
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'a provider failure during correction remains explicitly retryable',
    () async {
      var fail = false;
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          calls++;
          if (fail) throw StateError('private provider details');
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.lisbon);
      await agent.conversation.sendRequest(
        _pieceAction('select_product', 'top-1'),
      );
      await agent.conversation.sendRequest(
        ChatMessage.user('My budget is €20'),
      );
      expect(agent.inputError, isNotNull);
      final before = Map<String, dynamic>.from(runtime.outfit);
      final committedSurface = agent.latestInlineSurfaceId;
      fail = true;
      final beforeFailure = calls;
      await agent.conversation.sendRequest(
        ChatMessage.user('My budget is €100'),
      );
      expect(calls - beforeFailure, 1);
      expect(agent.inputError, isNull);
      expect(agent.connectionError, isNotNull);
      expect(
        agent.connectionError,
        isNot(contains('private provider details')),
      );
      expect(agent.canRetry, isTrue);
      expect(runtime.outfit, before);
      expect(agent.latestInlineSurfaceId, committedSurface);
      await agent.conversation.sendRequest(
        ChatMessage.user('Accidental duplicate'),
      );
      expect(calls - beforeFailure, 1);
      fail = false;
      final beforeRetry = calls;
      await agent.retryLastTurn();
      expect(calls - beforeRetry, lessThanOrEqualTo(4));
      expect(runtime.outfit['budget'], 100);
      expect(runtime.outfit['items'], {'top': 'top-1'});
      expect(agent.connectionError, isNull);
      expect(agent.inputError, isNull);
      expect(agent.canRetry, isFalse);
    },
  );

  testWidgets(
    'a rejected initial instruction can be corrected without a surface',
    (tester) async {
      final agent = GenkitAgent(_FirstTurnInputErrorRuntime());
      final start = agent.startBrief('An unsupported instruction');
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      await start;
      expect(agent.latestInlineSurfaceId, isNull);
      final composer = find.byKey(const ValueKey('stylist-composer'));
      expect(tester.widget<TextField>(composer).enabled, isTrue);
      expect(find.text('Update your outfit'), findsOneWidget);
      await tester.enterText(composer, 'A casual outfit under €200');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(agent.inputError, isNull);
      expect(agent.connectionError, isNull);
      expect(agent.latestInlineSurfaceId, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

// Exercise first-turn recovery independently of any particular input parser.
// The corrected turn still passes through the real offline runtime and renderer.
class _FirstTurnInputErrorRuntime extends StylistRuntime {
  _FirstTurnInputErrorRuntime() : super(products: products);

  bool _reject = true;

  @override
  Future<StylistTurnResult> turn(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistTextProgress? onText,
    StylistOutfitPreview? onOutfitPreview,
    StylistResultValidator? validateResult,
  }) {
    if (_reject) {
      _reject = false;
      return Future.error(
        const StylistInputError(
          code: StylistInputErrorCode.invalidBrief,
          message: 'Please describe the outfit you need.',
        ),
      );
    }
    return super.turn(
      input,
      cancel: cancel,
      onProgress: onProgress,
      onText: onText,
      onOutfitPreview: onOutfitPreview,
      validateResult: validateResult,
    );
  }
}
