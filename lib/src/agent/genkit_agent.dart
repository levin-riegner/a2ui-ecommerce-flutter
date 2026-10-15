import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

import '../catalog/commerce_catalog.dart';
import '../data/models.dart';
import 'commerce_agent.dart';
import 'conversation_entry.dart';
import 'genkit_providers.dart';
import 'stylist_runtime.dart';
import 'stylist_surfaces.dart';
import 'stylist_presenter.dart';
import 'a2ui_batch_validator.dart';
import 'stylist_input_error.dart';

/// Runs Genkit inside Flutter and publishes catalog-backed A2UI surfaces.
class GenkitAgent extends CommerceAgent {
  GenkitAgent(StylistRuntime runtime, {GenkitProvider? provider})
    : _runtime = runtime,
      // Public injection preserves a private provider field.
      // ignore: prefer_initializing_formals
      _provider = provider {
    controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
    transport = A2uiTransportAdapter(onSend: _handleSend);
    conversation = Conversation(controller: controller, transport: transport);
  }

  final _batchValidator = A2uiBatchValidator(buildCommerceCatalog());

  StylistRuntime? _runtime;
  final GenkitProvider? _provider;
  bool _revoked = false;

  Future<void> resumeLocalState() async {
    final runtime = _runtime;
    if (runtime == null) return;
    final resumed = await runtime.loadLocalState();
    if (resumed ||
        runtime.hasLocalLibrary ||
        runtime.localStorageNotice != null) {
      _hasStarted = true;
      await _enqueue(
        () => _performTurn(
          _AgentTurn(
            action: {
              'name': resumed ? 'resume_session' : 'open_saved_looks',
              'context': <String, Object?>{},
            },
          ),
        ).then<void>((_) {}),
      );
    }
  }

  @override
  int get bagCount => _runtime?.bagCount ?? 0;
  @override
  bool get hasLocalLibrary => true;
  @override
  Future<void> openBag() => _openLibrary('open_bag');

  @override
  Future<void> openSavedLooks() => _openLibrary('open_saved_looks');

  Future<void> _openLibrary(String name) => _enqueue(() async {
    if (await _performTurn(
      _AgentTurn(action: {'name': name, 'context': <String, Object?>{}}),
    )) {
      _hasStarted = true;
      notifyListeners();
    }
  });

  Future<void> disconnect() async {
    if (_revoked) return;
    _supersedeTurn();
    _clearSurfaces();
    _failedTurn = null;
    _connectionError = null;
    _inputError = null;
    if (!_disposed) notifyListeners();
    _revoked = true;
    final runtime = _runtime;
    _runtime = null;
    _provider?.dispose();
    await runtime?.dispose();
  }

  late final A2uiTransportAdapter transport;
  @override
  late final SurfaceController controller;
  @override
  late final Conversation conversation;

  final Set<String> _surfaceIds = {};
  bool _hasStarted = false;
  int _queuedTurns = 0;
  bool _disposed = false;
  String? _connectionError;
  String? _inputError;
  String? _connectionNotice;
  _AgentTurn? _failedTurn;
  Future<void> _pendingTurn = Future<void>.value();
  @override
  DemoJourney? activeJourney;
  @override
  String? latestInlineSurfaceId;
  @override
  String? pendingInlineSurfaceId;
  final List<CommerceConversationEntry> _entries = [];
  int _turnId = 0;
  int _epoch = 0;
  int _interactionGeneration = 0;
  @override
  List<CommerceConversationEntry> get conversationEntries =>
      List.unmodifiable(_entries);

  @override
  bool get hasStarted => _hasStarted;
  @override
  bool get isBusy => _queuedTurns > 0;
  @override
  String? get connectionError => _connectionError;
  @override
  String? get inputError => _inputError;
  @override
  String? get connectionNotice => _connectionNotice;
  @override
  bool get canRetry => _failedTurn != null && !isBusy;
  @override
  bool get hasDressingRoomSurface => _surfaceIds.contains('dressing-room');

  @override
  Future<void> startJourney(DemoJourney journey) {
    final epoch = _supersedeTurn();
    return _enqueue(() async {
      if (epoch != _epoch) return;
      _clearSurfaces();
      await Future<void>.delayed(Duration.zero);
      if (_disposed || _revoked || epoch != _epoch) return;
      activeJourney = journey;
      _runtime?.reset(journey: journey);
      _hasStarted = true;
      notifyListeners();
      await _performTurn(
        _AgentTurn(message: '${journey.title}. ${journey.brief}'),
      );
    });
  }

  @override
  bool get canStartBrief => true;

  @override
  Future<bool> restartChat() async {
    final epoch = _supersedeTurn();
    var restarted = false;
    await _enqueue(() async {
      if (epoch != _epoch) return;
      final saved = await _performTurn(
        _AgentTurn(
          action: {'name': 'reset_look', 'context': <String, Object?>{}},
        ),
      );
      if (!saved || epoch != _epoch || _disposed || _revoked) return;
      _clearSurfaces();
      _runtime?.reset();
      activeJourney = null;
      _hasStarted = false;
      restarted = true;
      notifyListeners();
    });
    return restarted;
  }

  @override
  Future<void> startBrief(String message) {
    final text = message.trim();
    if (text.isEmpty) return Future<void>.value();
    final epoch = _supersedeTurn();
    return _enqueue(() async {
      if (epoch != _epoch) return;
      _clearSurfaces();
      await Future<void>.delayed(Duration.zero);
      if (_disposed || _revoked || epoch != _epoch) return;
      activeJourney = null;
      _runtime?.reset();
      _hasStarted = true;
      notifyListeners();
      await _performTurn(_AgentTurn(message: text));
    });
  }

  void _clearSurfaces() {
    _interactionGeneration++;
    for (final surfaceId in _surfaceIds) {
      if (!_disposed) {
        transport.addMessage(core.DeleteSurfaceMessage(surfaceId: surfaceId));
      }
    }
    _surfaceIds.clear();
    latestInlineSurfaceId = null;
    pendingInlineSurfaceId = null;
    _entries.clear();
  }

  int _supersedeTurn() {
    _epoch++;
    _runtime?.cancelActiveTurn();
    _clearPending();
    return _epoch;
  }

  void _clearPending() {
    final id = pendingInlineSurfaceId;
    if (id == null) return;
    if (!_disposed) {
      transport.addMessage(core.DeleteSurfaceMessage(surfaceId: id));
    }
    _surfaceIds.remove(id);
    pendingInlineSurfaceId = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _handleSend(ChatMessage message) async {
    if (_disposed || _revoked) return;
    if (!_acceptsInteractions(message)) return;
    final action = _actionFrom(message);
    final text = message.text.trim();
    final restart = action?['name'] == 'reset_look'
        ? ''
        : action == null
        ? restartStylistBrief(text)
        : null;
    if (restart != null) {
      if (await restartChat() && restart.isNotEmpty) await startBrief(restart);
      return;
    }
    if (isBusy || _connectionError != null) return;
    if (action == null && text.isEmpty) return;
    await _enqueue(
      () => _performTurn(_AgentTurn(message: text, action: action)),
    );
  }

  @override
  Future<void> retryLastTurn() async {
    final turn = _failedTurn;
    if (turn == null || isBusy || _disposed) return;
    await _enqueue(() => _performTurn(turn));
  }

  Future<void> _enqueue(Future<void> Function() turn) {
    if (_disposed || _revoked) return Future<void>.value();
    final epoch = _epoch;
    _queuedTurns++;
    notifyListeners();
    final next = _pendingTurn.then((_) async {
      try {
        if (_disposed || _revoked || epoch != _epoch) return;
        _connectionError = null;
        _inputError = null;
        _connectionNotice = null;
        _failedTurn = null;
        notifyListeners();
        await turn();
      } finally {
        _queuedTurns--;
        if (!_disposed) notifyListeners();
      }
    });
    _pendingTurn = next.catchError((Object _) {});
    return next;
  }

  Map<String, Object?>? _actionFrom(ChatMessage message) {
    for (final part in message.parts.uiInteractionParts) {
      final decoded = jsonDecode(part.interaction);
      if (decoded is! Map || decoded['action'] is! Map) continue;
      final action = Map<String, Object?>.from(decoded['action'] as Map);
      if (action['name'] is! String || action['context'] is! Map) continue;
      return {
        'name': action['name'],
        'context': Map<String, Object?>.from(action['context'] as Map)
          ..remove('_chatGeneration'),
      };
    }
    return null;
  }

  // History and provisional surfaces are read-only even if a caller bypasses
  // the widget's interaction guards. Dressing-room actions remain current.
  bool _acceptsInteractions(ChatMessage message) {
    for (final part in message.parts.uiInteractionParts) {
      try {
        final decoded = jsonDecode(part.interaction);
        if (decoded is! Map || decoded['action'] is! Map) return false;
        final action = decoded['action'] as Map;
        final surfaceId = action['surfaceId'] ?? decoded['surfaceId'];
        final context = action['context'];
        if (action['sourceComponentId'] != null &&
            (context is! Map ||
                context['_chatGeneration'] != _interactionGeneration)) {
          return false;
        }
        if (surfaceId != null &&
            (surfaceId is! String ||
                !_surfaceIds.contains(surfaceId) ||
                (surfaceId != latestInlineSurfaceId &&
                    surfaceId != 'dressing-room'))) {
          return false;
        }
      } on FormatException {
        return false;
      }
    }
    return true;
  }

  Future<bool> _performTurn(_AgentTurn turn) async {
    final epoch = _epoch;
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
    void markChoice(String productId) {
      if (choicesSurface == null ||
          _disposed ||
          _revoked ||
          epoch != _epoch ||
          !_surfaceIds.contains(choicesSurface)) {
        return;
      }
      final model = controller.contextFor(choicesSurface).dataModel;
      final data = model.getValue<Object?>(DataPath.root);
      if (data is! Map) return;
      final rows = [
        ...?data['recommendations'] as List?,
        ...?data['choices'] as List?,
      ].whereType<Map>();
      if (!rows.any((row) => (row['id'] ?? row['productId']) == productId)) {
        return;
      }
      previousChoices ??= jsonDecode(jsonEncode(data));
      model.update(DataPath('/selectedProductId'), productId);
      if (data['recommendations'] is List) {
        model.update(DataPath('/recommendations'), [
          for (final row in data['recommendations'] as List)
            {
              ...row as Map,
              'selected': row['id'] == productId,
              'dimmed': row['id'] != productId,
            },
        ]);
      }
    }

    Object? previousDressingRoom;
    void publishOutfit(Map<String, Object?> data) {
      if (_disposed ||
          _revoked ||
          epoch != _epoch ||
          !_surfaceIds.contains('dressing-room')) {
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
      _entries.add(CommerceUserMessage(id: id, text: turn.message));
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
            _surfaceIds.contains(pendingId)) {
          continue;
        }
        transport.addMessage(event);
      }
      _surfaceIds.add(pendingId);
      pendingInlineSurfaceId = pendingId;
      notifyListeners();
    }

    try {
      final runtime = _runtime;
      if (runtime == null) throw StateError('Model disconnected');
      publishProgress(null);
      final result = await runtime.turn(
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
            markChoice((turn.action!['context'] as Map)['productId'] as String);
          }
        },
        validateResult: (payload) {
          if (_disposed || _revoked || epoch != _epoch) {
            throw StateError('Turn superseded');
          }
          _validateSurfaces(_parseEvents(presentStylistResult(payload)));
        },
      );
      if (_disposed || _revoked || epoch != _epoch) return false;
      // Parse the whole batch before publishing any part of it to the renderer.
      final events = _parseEvents(presentStylistResult(result));
      _validateSurfaces(events);
      for (final product in result.outfit.values) {
        markChoice(product.id);
      }
      _clearPending();
      for (final event in events) {
        transport.addMessage(event);
        if (event is core.CreateSurfaceMessage) {
          _surfaceIds.add(event.surfaceId);
          if (event.surfaceId.startsWith('inline-')) {
            latestInlineSurfaceId = event.surfaceId;
            _entries.add(
              CommerceSurfaceEntry(
                surfaceId: event.surfaceId,
                textAlreadyVisible: textAlreadyVisible,
              ),
            );
          }
        } else if (event is core.DeleteSurfaceMessage) {
          _surfaceIds.remove(event.surfaceId);
          if (event.surfaceId == latestInlineSurfaceId) {
            latestInlineSurfaceId = null;
          }
        }
      }
      committed = true;
      await Future<void>.delayed(Duration.zero);
      return !_disposed;
    } on StylistInputError catch (error) {
      if (!_disposed && !_revoked && epoch == _epoch) {
        // The runtime only commits a validated successful turn. Keep the
        // existing surfaces interactive so the person can resolve the conflict.
        _inputError = error.message;
        _failedTurn = null;
      }
      return false;
    } on FormatException {
      if (!_disposed && !_revoked && epoch == _epoch) {
        _recordFailure(
          turn,
          'Your stylist sent an incomplete response. Please try again.',
        );
      }
      return false;
    } catch (_) {
      if (!_disposed && !_revoked && epoch == _epoch) {
        _recordFailure(
          turn,
          _provider?.failureMessage ?? 'Your model could not respond. Check your API key, model settings, and connection, then try again.',
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

  List<core.A2uiMessage> _parseEvents(Map<String, dynamic> payload) {
    final messages = payload['messages'];
    if (messages is! List) throw const FormatException('Invalid A2UI batch');
    return messages.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid A2UI message');
      // Authored actions carry committed-chat provenance, independently of the
      // cancellation epoch. Failed resets leave the prior controls usable.
      Object? stamp(Object? value) {
        if (value is List) return value.map(stamp).toList();
        if (value is! Map) return value;
        return <String, dynamic>{
          for (final entry in value.entries)
            entry.key as String:
                entry.key == 'event' &&
                    entry.value is Map &&
                    (entry.value as Map)['name'] is String
                ? <String, dynamic>{
                    ...Map<String, dynamic>.from(entry.value as Map),
                    'context': <String, dynamic>{
                      ...?((entry.value as Map)['context'] as Map?),
                      '_chatGeneration': _interactionGeneration,
                    },
                  }
                : stamp(entry.value),
        };
      }

      return core.A2uiMessage.fromJson(
        Map<String, dynamic>.from(
          raw.containsKey('updateComponents') ? stamp(raw) as Map : raw,
        ),
      );
    }).toList();
  }

  // Check the candidate definitions without mutating the live renderer. The
  // bundled stylist must leave both host surfaces usable after each full turn.
  void _validateSurfaces(List<core.A2uiMessage> events) {
    final components = <String, Map<String, Map<String, dynamic>>>{};
    for (final id in _surfaceIds) {
      final definition = controller.contextFor(id).definition.value;
      if (definition != null) {
        components[id] = {
          for (final entry in definition.components.entries)
            entry.key: Map<String, dynamic>.from(entry.value.toJson()),
        };
      }
    }
    _batchValidator.validate(
      events,
      current: components,
      latestInlineSurfaceId: latestInlineSurfaceId,
    );
  }

  void _recordFailure(_AgentTurn turn, String message) {
    _failedTurn = turn;
    _connectionError = message;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _batchValidator.dispose();
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    unawaited(disconnect());
    super.dispose();
  }
}

class _AgentTurn {
  _AgentTurn({this.message = '', this.action});
  final String message;
  final Map<String, Object?>? action;
  String? id;
  bool recorded = false;
}
