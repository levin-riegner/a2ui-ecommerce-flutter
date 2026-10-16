import 'dart:async';

import 'package:a2ui_flutter_commerce/data/stylist/repository/stylist_repository.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_event.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart' show ChatMessage, ComponentsUpdated;

import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';
import 'stylist_library_test.dart' show completed, libraryCatalog;

Future<void> settleCommands(StylistBloc bloc) async {
  if (bloc.state.isBusy) {
    await bloc.stream
        .firstWhere((state) => !state.isBusy)
        .timeout(const Duration(seconds: 3));
  }
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'direct events publish immutable state and retain the same renderer',
    () async {
      final bloc = StylistBloc(
        StylistRepository(runtime: StylistRuntime(products: products)),
      );
      addTearDown(bloc.close);
      final renderer = bloc.renderer;
      final controller = bloc.controller;
      bloc.add(
        const StylistEvent.briefStarted(message: 'A casual outfit under €500.'),
      );
      expect(bloc.state.isBusy, isTrue);
      await settleCommands(bloc);

      final before = bloc.state;
      expect(before.hasStarted, isTrue);
      expect(before.hasDressingRoomSurface, isTrue);
      expect(before.latestInlineSurfaceId, 'inline-1');
      expect(
        before.conversationEntries.whereType<CommerceUserMessage>(),
        hasLength(1),
      );
      expect(() => before.conversationEntries.clear(), throwsUnsupportedError);

      // Reusing the very same const event still represents two queued commands.
      const event = StylistEvent.savedLooksOpened();
      bloc.add(event);
      bloc.add(event);
      expect(bloc.state.queuedTurns, 2);
      await settleCommands(bloc);
      expect(bloc.renderer, same(renderer));
      expect(bloc.controller, same(controller));
      expect(before.latestInlineSurfaceId, 'inline-1');
      expect(before.conversationEntries, hasLength(2));
      expect(bloc.state.isBusy, isFalse);
    },
  );

  test(
    'all direct command types share one queue and preserve message order',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var hold = false;
      final bloc = StylistBloc(
        StylistRepository(
          runtime: StylistRuntime(
            products: products,
            model: (request) async {
              if (hold && request.tools?.isEmpty == true) {
                if (!entered.isCompleted) entered.complete();
                await release.future;
              }
              return offlineStylistModel(request);
            },
          ),
        ),
      );
      addTearDown(bloc.close);
      await bloc.startBrief('A casual outfit under €500.');
      hold = true;
      bloc.add(
        const StylistEvent.messageSubmitted(message: 'Show me another top.'),
      );
      bloc.add(const StylistEvent.bagOpened());
      bloc.add(
        const StylistEvent.messageSubmitted(message: 'Show me shoes too.'),
      );
      await entered.future;
      expect(bloc.state.queuedTurns, 3);
      expect(
        bloc.state.conversationEntries.whereType<CommerceUserMessage>().map(
          (entry) => entry.text,
        ),
        ['A casual outfit under €500.', 'Show me another top.'],
      );
      release.complete();
      await settleCommands(bloc);
      expect(
        bloc.state.conversationEntries.whereType<CommerceUserMessage>().map(
          (entry) => entry.text,
        ),
        [
          'A casual outfit under €500.',
          'Show me another top.',
          'Show me shoes too.',
        ],
      );
      expect(bloc.connectionError, isNull);
    },
  );

  test(
    'direct restart cancels immediately and rejects late model work',
    () async {
      final entered = Completer<void>();
      final release = Completer<g.ModelResponse>();
      final runtime = StylistRuntime(
        products: products,
        providerModel: g.Model(
          name: 'test/bloc-noncooperative',
          fn: (request, context) async {
            if (request.tools?.isEmpty == true) {
              entered.complete();
              return release.future;
            }
            return offlineStylistModel(request);
          },
        ),
      );
      final bloc = StylistBloc(StylistRepository(runtime: runtime));
      addTearDown(bloc.close);
      bloc.add(
        const StylistEvent.briefStarted(message: 'A casual outfit under €500.'),
      );
      await entered.future;
      bloc.add(const StylistEvent.restartRequested());
      await settleCommands(bloc);
      expect(bloc.state.hasStarted, isFalse);
      expect(bloc.state.conversationEntries, isEmpty);
      expect(bloc.state.pendingInlineSurfaceId, isNull);
      expect(runtime.outfit['items'], isEmpty);
      release.completeError(StateError('Late provider failure'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.connectionError, isNull);
      expect(bloc.state.latestInlineSurfaceId, isNull);
    },
  );

  test('event logs omit user input and action data', () {
    final event = StylistEvent.messageSubmitted(
      message: 'private user facts',
      action: {
        'name': 'test',
        'context': {'private': 'sensitive value'},
      },
    );
    expect(event.toString(), isNot(contains('private')));
    expect(event.toString(), isNot(contains('sensitive')));
  });

  test(
    'repository preserves presentation validation before draft persistence',
    () async {
      final store = MemoryStylistStore();
      final runtime = StylistRuntime(products: products, store: store);
      final repository = StylistRepository(runtime: runtime);
      addTearDown(repository.dispose);
      final result = await repository.turn({
        'message': 'A casual outfit under €500.',
      });
      final before = store.encoded;
      await expectLater(
        repository.turn(
          {
            'action': {
              'name': 'select_product',
              'context': {'productId': result.view.picks.first.id},
            },
          },
          validateResult: (_) async {
            await Future<void>.delayed(Duration.zero);
            throw const FormatException('Rejected presentation');
          },
        ),
        throwsFormatException,
      );
      expect(runtime.outfit['items'], isEmpty);
      expect(store.encoded, before);
    },
  );

  test('repository revokes once and shares shutdown completion', () async {
    final runtime = _CountingRuntime();
    final repository = StylistRepository(runtime: runtime);
    final closing = repository.dispose();
    expect(repository.dispose(), same(closing));
    await closing;
    expect(runtime.disposals, 1);
    expect(() => repository.reset(), throwsStateError);
    expect(() => repository.turn({'message': 'hello'}), throwsStateError);
  });

  test(
    'close drains the SDK Conversation request before disposing its notifier',
    () async {
      final entered = Completer<void>();
      final release = Completer<g.ModelResponse>();
      var block = false;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (block && request.tools?.isEmpty == true) {
            entered.complete();
            return release.future;
          }
          return offlineStylistModel(request);
        },
      );
      final bloc = StylistBloc(StylistRepository(runtime: runtime));
      await bloc.startBrief('A casual outfit under €500.');
      block = true;
      final request = bloc.conversation.sendRequest(
        ChatMessage.user('Show me another top.'),
      );
      await entered.future;
      final closing = bloc.close();
      await expectLater(request, completes);
      await closing;
      expect(bloc.isClosed, isTrue);
      release.completeError(StateError('Late ignored provider failure'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'published bag removal already has the committed basket count',
    () async {
      final store = MemoryStylistStore();
      final seed = await completed(store: store);
      await seed.dispose();
      var calls = 0;
      final bloc = StylistBloc(
        StylistRepository(
          runtime: StylistRuntime(
            products: libraryCatalog,
            store: store,
            onModelRequest: (_) => calls++,
          ),
        ),
      );
      addTearDown(bloc.close);
      await bloc.resumeLocalState();
      await bloc.openBag();
      expect(bloc.bagCount, 1);
      final observedCounts = <int>[];
      final subscription = bloc.controller.surfaceUpdates.listen((update) {
        if (update case ComponentsUpdated(:final definition)) {
          if (definition.components.containsKey('library-toast')) {
            observedCounts.add(bloc.bagCount);
          }
        }
      });
      addTearDown(subscription.cancel);
      bloc.add(
        const StylistEvent.messageSubmitted(
          message: '',
          action: {
            'name': 'remove_bag_item',
            'context': {'productId': 'demo-0092'},
          },
        ),
      );
      await settleCommands(bloc);
      expect(observedCounts, isNotEmpty);
      expect(observedCounts, everyElement(0));
      expect(bloc.bagCount, 0);
      expect(calls, 0);
    },
  );

  test('SDK shutdown failure still closes the renderer and BLoC', () async {
    final runtime = _FailingShutdownRuntime();
    final bloc = StylistBloc(StylistRepository(runtime: runtime));
    await expectLater(bloc.close(), throwsStateError);
    expect(bloc.isClosed, isTrue);
    expect(runtime.disposals, 1);
    expect(
      bloc.renderer.accepts(
        ChatMessage.user('ignored'),
        latestInlineSurfaceId: null,
      ),
      isFalse,
    );
  });
}

class _CountingRuntime extends StylistRuntime {
  _CountingRuntime() : super(products: products);

  int disposals = 0;

  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}

class _FailingShutdownRuntime extends _CountingRuntime {
  @override
  Future<void> dispose() async {
    await super.dispose();
    throw StateError('SDK shutdown failed');
  }
}
