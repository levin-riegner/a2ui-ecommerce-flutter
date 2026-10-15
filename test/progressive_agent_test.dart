import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products, textResponse;

ChatMessage action(
  String name,
  Map<String, Object?> context, {
  String? surfaceId,
}) => ChatMessage.user(
  '',
  parts: [
    UiInteractionPart.create(
      jsonEncode({
        'action': {'name': name, 'context': context, 'surfaceId': ?surfaceId},
      }),
    ),
  ],
);

void main() {
  test('streams final prose before exposing product cards', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    late void Function(String) emit;
    var prose = '';
    final runtime = StylistRuntime(
      products: products,
      providerModel: g.Model(
        name: 'test/stream',
        fn: (request, context) async {
          if (request.tools?.isEmpty == true) {
            expect(context.streamingRequested, isTrue);
            emit = (text) {
              prose += text;
              context.sendChunk(
                g.ModelResponseChunk(content: [g.TextPart(text: text)]),
              );
            };
            started.complete();
            await finish.future;
            return textResponse(prose);
          }
          expect(context.streamingRequested, isFalse);
          return offlineStylistModel(request);
        },
      ),
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    final pending = agent.startJourney(DemoJourney.lisbon);
    await started.future;
    await Future<void>.delayed(Duration.zero);
    final pendingId = agent.pendingInlineSurfaceId!;
    final surface = agent.controller.contextFor(pendingId);
    expect(surface.definition.value!.components.keys, ['root', 'message']);
    expect(agent.latestInlineSurfaceId, isNull);
    emit('A soft ');
    emit('silhouette. ');
    await Future<void>.delayed(Duration.zero);
    expect(
      surface.dataModel.getValue<String>(DataPath('/reply')),
      contains('A soft silhouette.'),
    );
    emit('It costs €');
    emit('20. ');
    emit('Choose a light layer. ');
    await Future<void>.delayed(Duration.zero);
    final visible = surface.dataModel.getValue<String>(DataPath('/reply'))!;
    expect(visible, contains('Choose a light layer.'));
    expect(visible, isNot(contains('It costs')));
    expect(visible, isNot(contains('€20')));
    expect(runtime.outfit['items'], isEmpty);
    expect(agent.latestInlineSurfaceId, isNull);
    expect(
      agent.conversationEntries.whereType<CommerceSurfaceEntry>(),
      isEmpty,
    );
    finish.complete();
    await pending;
    expect(agent.pendingInlineSurfaceId, isNull);
    expect(agent.latestInlineSurfaceId, 'inline-1');
    expect(agent.connectionError, isNull);
    final finalSurface = agent.controller.contextFor('inline-1');
    expect(
      finalSurface.dataModel.getValue<String>(DataPath('/message')),
      startsWith(visible),
    );
    expect(
      agent.conversationEntries
          .whereType<CommerceSurfaceEntry>()
          .single
          .textAlreadyVisible,
      isTrue,
    );
    expect(agent.controller.contextFor(pendingId).definition.value, isNull);
  });

  test('failed streamed reply removes provisional text and keeps the committed look', () async {
    var fail = false;
    final runtime = StylistRuntime(
      products: products,
      providerModel: g.Model(
        name: 'test/failing-stream',
        fn: (request, context) async {
          if (fail && request.tools?.isEmpty == true) {
            context.sendChunk(
              g.ModelResponseChunk(
                content: [g.TextPart(text: 'A new layer. ')],
              ),
            );
            throw StateError('Connection interrupted');
          }
          return offlineStylistModel(request);
        },
      ),
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.lisbon);
    fail = true;
    await agent.conversation.sendRequest(
      action('select_product', {'productId': 'top-1'}),
    );
    expect(agent.latestInlineSurfaceId, 'inline-1');
    expect(agent.pendingInlineSurfaceId, isNull);
    expect(agent.connectionError, isNotNull);
    expect(runtime.outfit['items'], isEmpty);
    expect(
      agent.conversationEntries.whereType<CommerceSurfaceEntry>(),
      hasLength(1),
    );
  });

  test('failed final prose removes preview and rolls back outfit; retry keeps one user row', () async {
    var failFinal = false;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        if (failFinal && request.tools?.isEmpty == true) {
          throw StateError('Failed final prose');
        }
        return offlineStylistModel(request);
      },
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.lisbon);
    failFinal = true;
    await agent.conversation.sendRequest(
      action('select_product', {'productId': 'top-1'}),
    );
    expect(agent.latestInlineSurfaceId, 'inline-1');
    expect(agent.pendingInlineSurfaceId, isNull);
    expect(runtime.outfit['items'], isEmpty);
    expect(
      agent.conversationEntries.whereType<CommerceSurfaceEntry>().length,
      1,
    );
    failFinal = false;
    await agent.retryLastTurn();
    expect(agent.latestInlineSurfaceId, 'inline-2');
    expect(runtime.outfit['items'], {'top': 'top-1'});
    failFinal = true;
    await agent.conversation.sendRequest(
      ChatMessage.user('Show me different shoes'),
    );
    final userRows = agent.conversationEntries
        .whereType<CommerceUserMessage>()
        .toList();
    expect(userRows.length, 2);
    failFinal = false;
    await agent.retryLastTurn();
    expect(
      agent.conversationEntries.whereType<CommerceUserMessage>().length,
      2,
    );
    expect(
      agent.conversationEntries.whereType<CommerceUserMessage>().last.id,
      userRows.last.id,
    );
  });

  test('rejects historical and unknown surface actions while dressing-room remains active', () async {
    final runtime = StylistRuntime(products: products);
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.lisbon);
    await agent.conversation.sendRequest(
      action('select_product', {'productId': 'top-1'}, surfaceId: 'inline-1'),
    );
    expect(agent.latestInlineSurfaceId, 'inline-2');
    await agent.conversation.sendRequest(
      action('select_product', {'productId': 'top-1'}, surfaceId: 'inline-1'),
    );
    await agent.conversation.sendRequest(
      action('remove_product', {'productId': 'top-1'}, surfaceId: 'unknown'),
    );
    expect(agent.latestInlineSurfaceId, 'inline-2');
    expect(runtime.outfit['items'], {'top': 'top-1'});
    await agent.conversation.sendRequest(
      action('remove_product', {
        'productId': 'top-1',
      }, surfaceId: 'dressing-room'),
    );
    expect(agent.connectionError, isNull);
    expect(runtime.outfit['items'], isEmpty);
    expect(agent.latestInlineSurfaceId, 'inline-3');
  });

  test(
    'disconnect drops provisional surfaces and ignores late provider responses',
    () async {
      final started = Completer<void>();
      final reply = Completer<g.ModelResponse>();
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          started.complete();
          return reply.future;
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      final turn = agent.startJourney(DemoJourney.lisbon);
      await started.future;
      expect(agent.pendingInlineSurfaceId, isNotNull);
      final disconnected = agent.disconnect();
      expect(agent.pendingInlineSurfaceId, isNull);
      expect(agent.conversationEntries, isEmpty);
      reply.complete(textResponse('Late response'));
      await Future.wait([turn, disconnected]);
      expect(agent.latestInlineSurfaceId, isNull);
      expect(agent.connectionError, isNull);
    },
  );

  test(
    'new journey supersedes a pending generation and resets history',
    () async {
      final started = Completer<void>();
      final reply = Completer<g.ModelResponse>();
      var blocked = true;
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          if (blocked) {
            started.complete();
            return reply.future;
          }
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      final oldTurn = agent.startJourney(DemoJourney.lisbon);
      await started.future;
      final newTurn = agent.startJourney(DemoJourney.paris);
      expect(agent.pendingInlineSurfaceId, isNull);
      blocked = false;
      reply.complete(textResponse('Old response'));
      await Future.wait([oldTurn, newTurn]);
      expect(agent.activeJourney, DemoJourney.paris);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(
        agent.conversationEntries.whereType<CommerceUserMessage>().single.text,
        contains(DemoJourney.paris.title),
      );
      expect(
        agent.conversationEntries.whereType<CommerceSurfaceEntry>().length,
        1,
      );
      expect(agent.connectionError, isNull);
    },
  );

  test(
    'superseding during start delay does not invoke the obsolete journey',
    () async {
      final seenBriefs = <String>[];
      final runtime = StylistRuntime(
        products: products,
        onBeginTurn: () {},
        model: (request) async {
          seenBriefs.add(
            request.messages.map((message) => message.text).join(' '),
          );
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      final oldTurn = agent.startJourney(DemoJourney.lisbon);
      await Future<void>.value();
      final newTurn = agent.startJourney(DemoJourney.paris);
      await Future.wait([oldTurn, newTurn]);
      expect(agent.activeJourney, DemoJourney.paris);
      expect(seenBriefs, isNotEmpty);
      expect(
        seenBriefs.every((brief) => !brief.contains(DemoJourney.lisbon.title)),
        isTrue,
      );
      expect(
        agent.conversationEntries.whereType<CommerceUserMessage>().length,
        1,
      );
    },
  );

  test('runtime result rejection rolls back draft selection and callbacks stay per turn', () async {
    final runtime = StylistRuntime(products: products);
    addTearDown(runtime.dispose);
    runtime.reset(journey: DemoJourney.lisbon);
    var firstProgress = 0;
    var secondProgress = 0;
    await runtime.turn({
      'message': '${DemoJourney.lisbon.title}. ${DemoJourney.lisbon.brief}',
    }, onProgress: (_) => firstProgress++);
    await expectLater(
      runtime.turn(
        {
          'action': {
            'name': 'select_product',
            'context': {'productId': 'top-1'},
          },
        },
        onProgress: (_) => secondProgress++,
        validateResult: (_) =>
            throw const FormatException('Invalid final batch'),
      ),
      throwsFormatException,
    );
    expect(firstProgress, 1);
    expect(secondProgress, 1);
    expect(runtime.outfit['items'], isEmpty);
    await runtime.turn({
      'action': {
        'name': 'select_product',
        'context': {'productId': 'top-1'},
      },
    });
    expect(firstProgress, 1);
    expect(secondProgress, 1);
    expect(runtime.outfit['items'], {'top': 'top-1'});
  });
}
