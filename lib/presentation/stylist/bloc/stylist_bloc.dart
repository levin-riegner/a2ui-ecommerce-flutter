import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

import '../a2ui/commerce_agent.dart';
import 'conversation_entry.dart';
import '../../../data/stylist/repository/stylist_repository.dart';
import '../../../data/stylist/model/stylist_input_error.dart';
import '../../../data/stylist/model/stylist_brief.dart';
import '../../../data/stylist/model/outfit_plan.dart';
import '../a2ui/stylist_presenter.dart';
import '../a2ui/stylist_surfaces.dart';
import '../../../data/catalog/model/models.dart';
import '../a2ui/commerce_a2ui_renderer.dart';
import 'stylist_event.dart';
import 'stylist_state.dart';
import 'commerce_inspector_bloc.dart';
import '../../../data/stylist/model/commerce_trace.dart';

/// Owns session events and immutable screen state. All commands share one
/// serial event handler, including model turns and local basket operations.
/// The runtime remains responsible for domain validation and atomic commits.
class StylistBloc extends CommerceAgent {
  StylistBloc(this._repository, {Catalog? catalog, this.inspector})
    : super(const StylistState(canStartBrief: true, hasLocalLibrary: true)) {
    renderer = CommerceA2uiRenderer(onSend: _handleSend, catalog: catalog);
    on<StylistEvent>(
      _handleEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  late final CommerceA2uiRenderer renderer;
  final StylistRepository _repository;
  @override
  final CommerceInspectorBloc? inspector;
  final Map<int, Completer<Object?>> _requests = {};
  final Map<StylistEvent, Queue<int>> _eventEpochs = HashMap.identity();
  int _nextRequestId = 0;
  int _epoch = 0;
  int _turnId = 0;
  bool _revoked = false;
  bool _disposed = false;
  Future<void>? _closing;
  Emitter<StylistState>? _activeEmitter;
  _AgentTurn? _failedTurn;

  @override
  SurfaceController get controller => renderer.controller;
  A2uiTransportAdapter get transport => renderer.transport;
  @override
  Conversation get conversation => renderer.conversation;

  void _setState(StylistState next) {
    if (_disposed || isClosed) return;
    final handler = _activeEmitter;
    if (handler != null && !handler.isDone) {
      handler(next);
    } else {
      // Admission/cancellation is synchronous so the UI immediately disables
      // duplicate sends, even while another event is waiting on the provider.
      // The synchronous admission guard must run before queued handlers.
      // ignore: invalid_use_of_visible_for_testing_member
      super.emit(next);
    }
  }

  void _publishState() => _setState(
    state.copyWith(
      bagCount: _repository.bagCount,
      hasFailedTurn: _failedTurn != null,
      hasDressingRoomSurface: renderer.contains('dressing-room'),
      surfaceRevision: state.surfaceRevision + 1,
    ),
  );

  set _hasStarted(bool value) => _setState(state.copyWith(hasStarted: value));
  int get _queuedTurns => state.queuedTurns;
  set _queuedTurns(int value) => _setState(state.copyWith(queuedTurns: value));
  set _connectionError(String? value) =>
      _setState(state.copyWith(connectionError: value));
  set _inputError(String? value) =>
      _setState(state.copyWith(inputError: value));
  set _connectionNotice(String? value) =>
      _setState(state.copyWith(connectionNotice: value));
  set activeJourney(DemoJourney? value) =>
      _setState(state.copyWith(activeJourney: value));
  set latestInlineSurfaceId(String? value) =>
      _setState(state.copyWith(latestInlineSurfaceId: value));
  set pendingInlineSurfaceId(String? value) =>
      _setState(state.copyWith(pendingInlineSurfaceId: value));

  void _appendEntry(CommerceConversationEntry entry) => _setState(
    state.copyWith(conversationEntries: [...state.conversationEntries, entry]),
  );

  Future<Object?> _dispatch(StylistEvent Function(int requestId) command) {
    if (_disposed || _revoked || isClosed) return Future.value();
    final requestId = ++_nextRequestId;
    final completion = Completer<Object?>();
    _requests[requestId] = completion;
    add(command(requestId));
    return completion.future;
  }

  @override
  void onEvent(StylistEvent event) {
    // Capture identity when a command enters the queue, not when its handler
    // eventually runs. Restart must invalidate even a noncooperative model now.
    final active = _activeEmitter;
    _activeEmitter = null;
    try {
      if (event is StylistJourneyStarted ||
          event is StylistBriefStarted ||
          event is StylistRestartRequested) {
        _supersedeTurn();
      }
      (_eventEpochs[event] ??= Queue<int>()).add(_epoch);
      _queuedTurns++;
      super.onEvent(event);
    } finally {
      _activeEmitter = active;
    }
  }

  Future<void> _handleEvent(
    StylistEvent event,
    Emitter<StylistState> emit,
  ) async {
    _activeEmitter = emit;
    final epochs = _eventEpochs[event]!;
    final epoch = epochs.removeFirst();
    if (epochs.isEmpty) _eventEpochs.remove(event);
    Object? result;
    Object? failure;
    StackTrace? stack;
    try {
      if (_disposed || _revoked || epoch != _epoch) return;
      _connectionError = null;
      _inputError = null;
      _connectionNotice = null;
      final retry = _failedTurn;
      _failedTurn = null;
      _publishState();
      switch (event) {
        case StylistResumeRequested():
          final resumed = await _repository.loadLocalState();
          if (_disposed || _revoked || epoch != _epoch) return;
          if (resumed ||
              _repository.hasLocalLibrary ||
              _repository.localStorageNotice != null) {
            _hasStarted = true;
            await _performTurn(
              _AgentTurn(
                action: {
                  'name': resumed ? 'resume_session' : 'open_saved_looks',
                  'context': <String, Object?>{},
                },
              ),
            );
          }
        case StylistJourneyStarted(:final journey):
          _clearSurfaces();
          await Future<void>.delayed(Duration.zero);
          if (_disposed || _revoked || epoch != _epoch) return;
          activeJourney = journey;
          _repository.reset(journey: journey);
          _hasStarted = true;
          await _performTurn(
            _AgentTurn(message: '${journey.title}. ${journey.brief}'),
          );
        case StylistBriefStarted(:final message):
          _clearSurfaces();
          await Future<void>.delayed(Duration.zero);
          if (_disposed || _revoked || epoch != _epoch) return;
          activeJourney = null;
          _repository.reset();
          _hasStarted = true;
          await _performTurn(_AgentTurn(message: message));
        case StylistMessageSubmitted(:final message, :final action):
          await _performTurn(_AgentTurn(message: message, action: action));
        case StylistBagOpened():
          await _openLibrary('open_bag');
        case StylistSavedLooksOpened():
          await _openLibrary('open_saved_looks');
        case StylistRetryRequested():
          if (retry != null) await _performTurn(retry);
        case StylistRestartRequested():
          result = false;
          final saved = await _performTurn(
            _AgentTurn(
              action: {'name': 'reset_look', 'context': <String, Object?>{}},
            ),
          );
          if (!saved || epoch != _epoch || _disposed || _revoked) return;
          _clearSurfaces();
          _repository.reset();
          activeJourney = null;
          _hasStarted = false;
          result = true;
      }
    } catch (error, trace) {
      failure = error;
      stack = trace;
    } finally {
      _queuedTurns = _queuedTurns > 0 ? _queuedTurns - 1 : 0;
      _publishState();
      _activeEmitter = null;
      final completion = _requests.remove(event.requestId);
      if (completion != null && !completion.isCompleted) {
        if (failure != null) {
          completion.completeError(failure, stack);
        } else {
          completion.complete(result);
        }
      }
    }
  }

  Future<void> resumeLocalState() async {
    await _dispatch(
      (requestId) => StylistEvent.resumeRequested(requestId: requestId),
    );
  }

  @override
  Future<void> openBag() async {
    await _dispatch(
      (requestId) => StylistEvent.bagOpened(requestId: requestId),
    );
  }

  @override
  Future<void> openSavedLooks() async {
    await _dispatch(
      (requestId) => StylistEvent.savedLooksOpened(requestId: requestId),
    );
  }

  Future<void> _openLibrary(String name) async {
    if (await _performTurn(
      _AgentTurn(action: {'name': name, 'context': <String, Object?>{}}),
    )) {
      _hasStarted = true;
    }
  }

  @override
  Future<void> startJourney(DemoJourney journey) async {
    await _dispatch(
      (requestId) =>
          StylistEvent.journeyStarted(requestId: requestId, journey: journey),
    );
  }

  @override
  Future<void> startBrief(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await _dispatch(
      (requestId) =>
          StylistEvent.briefStarted(requestId: requestId, message: text),
    );
  }

  @override
  Future<bool> restartChat() async {
    return await _dispatch(
          (requestId) => StylistEvent.restartRequested(requestId: requestId),
        ) ==
        true;
  }

  @override
  Future<void> retryLastTurn() async {
    if (_failedTurn == null || isBusy || _disposed) return;
    await _dispatch(
      (requestId) => StylistEvent.retryRequested(requestId: requestId),
    );
  }

  void _clearSurfaces() {
    renderer.clear();
    _setState(
      state.copyWith(
        latestInlineSurfaceId: null,
        pendingInlineSurfaceId: null,
        conversationEntries: const [],
        hasDressingRoomSurface: false,
      ),
    );
  }

  void _supersedeTurn() {
    _epoch++;
    _repository.cancelActiveTurn();
    _clearPending();
  }

  void _clearPending() {
    final id = pendingInlineSurfaceId;
    if (id == null) return;
    renderer.publish(core.DeleteSurfaceMessage(surfaceId: id));
    pendingInlineSurfaceId = null;
  }

  Future<void> _handleSend(ChatMessage message) async {
    if (_disposed ||
        _revoked ||
        !renderer.accepts(
          message,
          latestInlineSurfaceId: latestInlineSurfaceId,
        )) {
      return;
    }
    final action = renderer.actionFrom(message);
    final text = message.text.trim();
    final restart = action?['name'] == 'reset_look'
        ? ''
        : action == null
        ? _repository.restartBrief(text)
        : null;
    if (restart != null) {
      if (await restartChat() && restart.isNotEmpty) await startBrief(restart);
      return;
    }
    if (isBusy || connectionError != null || (action == null && text.isEmpty)) {
      return;
    }
    await _dispatch(
      (requestId) => StylistEvent.messageSubmitted(
        requestId: requestId,
        message: text,
        action: action,
      ),
    );
  }

  void _validateSurfaces(List<core.A2uiMessage> events) =>
      renderer.validate(events, latestInlineSurfaceId: latestInlineSurfaceId);

  void _recordFailure(_AgentTurn turn, String message) {
    _failedTurn = turn;
    _connectionError = message;
  }

  Future<void> disconnect() async {
    if (_revoked) return;
    _supersedeTurn();
    _clearSurfaces();
    _failedTurn = null;
    _connectionError = null;
    _inputError = null;
    _revoked = true;
    _publishState();
    await _repository.dispose();
  }

  @override
  Future<void> close() => _closing ??= _closeResources()
      .whenComplete(() => super.close())
      .whenComplete(_eventEpochs.clear);

  Future<void> _closeResources() async {
    // Revoke immediately; cancellation must not wait behind a running turn.
    try {
      await disconnect();
    } finally {
      _disposed = true;
      // Release cancelled commands before waiting for the SDK Conversation's
      // sendRequest finally blocks; those are awaiting these completions.
      for (final request in _requests.values) {
        if (!request.isCompleted) request.complete();
      }
      _requests.clear();
      await renderer.dispose();
      await inspector?.close();
    }
  }

  @override
  void dispose() => unawaited(close());

  Future<bool> _performTurn(_AgentTurn turn) async {
    final epoch = _epoch;
    // Bag interactions are one flow, not new assistant replies in the chat.
    final replacedEntryId =
        const {
          'open_bag',
          'close_bag',
          'add_look_to_bag',
          'change_bag_quantity',
          'remove_bag_item',
          'restore_bag_item',
          'undo_bag_changes',
        }.contains(turn.action?['name'])
        ? latestInlineSurfaceId
        : null;
    final optionsSurface = turn.action?['name'] == 'set_product_options'
        ? latestInlineSurfaceId
        : null;
    void setOptionsSubmitting(bool submitting) {
      if (optionsSurface == null || _disposed || _revoked || epoch != _epoch) {
        return;
      }
      controller
          .contextFor(optionsSurface)
          .dataModel
          .update(DataPath('/selectionOptions/submitting'), submitting);
    }

    var committed = false;
    setOptionsSubmitting(true);
    final choicesSurface = latestInlineSurfaceId;
    Object? previousChoices;
    core.UpdateComponentsMessage? previousRecommendation;
    void markChoice(Product product) {
      if (choicesSurface == null ||
          _disposed ||
          _revoked ||
          epoch != _epoch ||
          !renderer.contains(choicesSurface)) {
        return;
      }
      final model = controller.contextFor(choicesSurface).dataModel;
      final data = model.getValue<Object?>(DataPath.root);
      if (data is! Map) return;
      final rows = [
        ...?data['recommendations'] as List?,
        ...?data['choices'] as List?,
      ].whereType<Map>();
      if (!rows.any((row) => (row['id'] ?? row['productId']) == product.id)) {
        return;
      }
      final original = controller
          .contextFor(choicesSurface)
          .definition
          .value
          ?.components['recommendations'];
      if (original == null) return;
      final updates = renderer.parse({
        'messages': [
          {
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': choicesSurface,
              'components': [selectedRecommendationComponent(product)],
            },
          },
        ],
      });
      _validateSurfaces(updates);
      previousChoices ??= jsonDecode(jsonEncode(data));
      previousRecommendation ??= core.UpdateComponentsMessage(
        surfaceId: choicesSurface,
        components: [Map<String, dynamic>.from(original.toJson())],
      );
      model.update(DataPath('/selectedProductId'), product.id);
      if (data['recommendations'] is List) {
        // Keep the original typed fact maps readable by GenUI's JSON paths.
        // Spreading a raw Map here produces dynamic keys and blank bindings.
        final cards = data['recommendations'] as List;
        for (var i = 0; i < cards.length; i++) {
          final selected = (cards[i] as Map)['id'] == product.id;
          model.update(DataPath('/recommendations/$i/selected'), selected);
          model.update(DataPath('/recommendations/$i/dimmed'), !selected);
        }
      }
      for (final update in updates) {
        renderer.publish(update);
      }
    }

    Object? previousDressingRoom;
    void publishOutfit(Map<String, Object?> data) {
      if (_disposed ||
          _revoked ||
          epoch != _epoch ||
          !renderer.contains('dressing-room')) {
        return;
      }
      previousDressingRoom ??= jsonDecode(
        jsonEncode(
          controller
              .contextFor('dressing-room')
              .dataModel
              .getValue<Object?>(DataPath('/')),
        ),
      );
      controller
          .contextFor('dressing-room')
          .dataModel
          .update(DataPath.root, data);
    }

    final id = turn.id ??= 'turn-${++_turnId}';
    if (!turn.recorded && turn.message.isNotEmpty) {
      _appendEntry(CommerceUserMessage(id: id, text: turn.message));
      turn.recorded = true;
    }
    final pendingId = 'pending-$id';
    var textAlreadyVisible = false;
    void publishProgress([String? text]) {
      if (_disposed || _revoked || epoch != _epoch) return;
      final messages = renderPendingStylistSurface(
        surfaceId: pendingId,
        text: text,
      );
      for (final raw in messages) {
        final event = core.A2uiMessage.fromJson(Map<String, dynamic>.from(raw));
        if (event is core.CreateSurfaceMessage &&
            renderer.contains(pendingId)) {
          continue;
        }
        renderer.publish(event);
      }
      pendingInlineSurfaceId = pendingId;
      _publishState();
    }

    try {
      inspector?.record(
        CommerceTraceEntry.clientInput(
          messageLength: turn.message.length,
          action: turn.action?['name'] as String?,
        ),
      );
      // Show the normal room from explicit input before waiting for the model.
      // This is presentation only; runtime state still commits atomically.
      if (!renderer.contains('dressing-room') && turn.message.isNotEmpty) {
        try {
          final brief =
              (activeJourney == null
                      ? const StylistBrief()
                      : StylistBrief.fromJourney(activeJourney!))
                  .recordMessage(turn.message);
          final messages = renderStylistSurfaces(
            turn: 1,
            reply: '',
            picks: const [],
            outfit: const {},
            budget: brief.budget,
            occasion: brief.summary,
            plan: OutfitPlan.from(
              brief: brief.planningBrief,
              outfit: const {},
              constraints: brief.productConstraints,
              dressCode: brief.dressCode.isEmpty ? null : brief.dressCode,
            ),
          );
          final events = renderer.parse({'messages': messages});
          _validateSurfaces(events);
          for (final event in events) {
            if (event.toJson().values.whereType<Map>().any(
              (body) => body['surfaceId'] == 'dressing-room',
            )) {
              renderer.publish(event);
            }
          }
        } on FormatException {
          // Let the runtime report invalid input through the existing UI.
        }
      }
      publishProgress(null);
      final result = await _repository.turn(
        {
          if (turn.message.isNotEmpty) 'message': turn.message,
          if (turn.action != null) 'action': turn.action,
        },
        onText: (text) {
          textAlreadyVisible = true;
          publishProgress(text);
        },
        onOutfitPreview: (preview) {
          final updates = presentStylistResult(preview)['messages'] as List;
          final update = updates
              .map((m) => m['updateDataModel'])
              .whereType<Map>()
              .firstWhere((m) => m['surfaceId'] == 'dressing-room');
          publishOutfit(Map<String, Object?>.from(update['value'] as Map));
          if (turn.action?['name'] == 'select_product') {
            final productId = (turn.action!['context'] as Map)['productId'];
            for (final product in preview.outfit.values) {
              if (product.id == productId) markChoice(product);
            }
          }
        },
        validateResult: (payload) {
          if (_disposed || _revoked || epoch != _epoch) {
            throw StateError('Turn superseded');
          }
          _validateSurfaces(
            renderer
                .parse(presentStylistResult(payload))
                .where(
                  (event) =>
                      event is! core.CreateSurfaceMessage ||
                      event.surfaceId != 'dressing-room' ||
                      !renderer.contains(event.surfaceId),
                )
                .toList(),
          );
        },
      );
      if (_disposed || _revoked || epoch != _epoch) return false;
      // Parse the whole batch before publishing any part of it to the renderer.
      final events = renderer
          .parse(presentStylistResult(result))
          .where(
            (event) =>
                event is! core.CreateSurfaceMessage ||
                event.surfaceId != 'dressing-room' ||
                !renderer.contains(event.surfaceId),
          )
          .toList();
      _validateSurfaces(events);
      // State and the published surface must describe the same committed bag.
      // A toast can render before the handler's final cleanup runs.
      _setState(state.copyWith(bagCount: _repository.bagCount));
      for (final product in result.outfit.values) {
        markChoice(product);
      }
      _clearPending();
      for (final event in events) {
        renderer.publish(event);
        if (event is core.CreateSurfaceMessage) {
          if (event.surfaceId.startsWith('inline-')) {
            latestInlineSurfaceId = event.surfaceId;
            final entry = CommerceSurfaceEntry(
              surfaceId: event.surfaceId,
              textAlreadyVisible: textAlreadyVisible,
            );
            if (replacedEntryId != null &&
                state.conversationEntries.any(
                  (entry) =>
                      entry is CommerceSurfaceEntry &&
                      entry.surfaceId == replacedEntryId,
                )) {
              _setState(
                state.copyWith(
                  conversationEntries: [
                    for (final previous in state.conversationEntries)
                      if (previous is CommerceSurfaceEntry &&
                          previous.surfaceId == replacedEntryId)
                        entry
                      else
                        previous,
                  ],
                ),
              );
            } else {
              _appendEntry(entry);
            }
          }
        } else if (event is core.DeleteSurfaceMessage) {
          if (event.surfaceId == latestInlineSurfaceId) {
            latestInlineSurfaceId = null;
          }
        }
      }
      committed = true;
      inspector?.record(
        CommerceTraceEntry.surfaceCommit(
          components: [
            for (final event in events)
              if (event is core.UpdateComponentsMessage)
                for (final component in event.components)
                  if (component['component'] is String)
                    component['component'] as String,
          ],
          registeredComponents: renderer.componentNames,
          messageCount: events.length,
          bagCount: _repository.bagCount,
          modelSelected: result.view.modelSelectedComponent != null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      return !_disposed;
    } on StylistInputError catch (error) {
      if (!_disposed && !_revoked && epoch == _epoch) {
        inspector?.record(
          CommerceTraceEntry.turnFailure(CommerceTurnFailure.inputRejected),
        );
        // The runtime only commits a validated successful turn. Keep the
        // existing surfaces interactive so the person can resolve the conflict.
        _inputError = error.message;
        _failedTurn = null;
      }
      return false;
    } on FormatException {
      if (!_disposed && !_revoked && epoch == _epoch) {
        inspector?.record(
          CommerceTraceEntry.turnFailure(
            CommerceTurnFailure.presentationRejected,
          ),
        );
        _recordFailure(
          turn,
          'Your stylist sent an incomplete response. Please try again.',
        );
      }
      return false;
    } catch (_) {
      if (!_disposed && !_revoked && epoch == _epoch) {
        inspector?.record(
          CommerceTraceEntry.turnFailure(CommerceTurnFailure.unavailable),
        );
        _recordFailure(
          turn,
          _repository.failureMessage ?? 'Your model could not respond. Check your API key, model settings, and connection, then try again.',
        );
      }
      return false;
    } finally {
      if (!committed) setOptionsSubmitting(false);
      if (!committed &&
          previousChoices != null &&
          choicesSurface != null &&
          !_disposed &&
          !_revoked &&
          epoch == _epoch) {
        controller
            .contextFor(choicesSurface)
            .dataModel
            .update(DataPath.root, previousChoices);
        if (previousRecommendation != null) {
          renderer.publish(previousRecommendation!);
        }
      }
      if (!committed &&
          previousDressingRoom is Map &&
          !_disposed &&
          !_revoked &&
          epoch == _epoch) {
        publishOutfit(Map<String, Object?>.from(previousDressingRoom as Map));
      }
      if (epoch == _epoch) _clearPending();
    }
  }
}

class _AgentTurn {
  _AgentTurn({this.message = '', this.action});

  final String message;
  final Map<String, Object?>? action;
  String? id;
  bool recorded = false;
}
