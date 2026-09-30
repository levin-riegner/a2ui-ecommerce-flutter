import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

import '../catalog/commerce_catalog.dart';
import '../data/models.dart';
import 'commerce_agent.dart';

/// Connects Flutter's A2UI renderer to the catalog agent service.
/// Credentials stay on that service; the app receives catalog-backed UI only.
class RemoteAgent extends CommerceAgent {
  RemoteAgent(this._origin, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null {
    controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
    transport = A2uiTransportAdapter(onSend: _handleSend);
    conversation = Conversation(controller: controller, transport: transport);
  }

  final Uri _origin;
  final http.Client _client;
  final bool _ownsClient;
  late final A2uiTransportAdapter transport;
  @override
  late final SurfaceController controller;
  @override
  late final Conversation conversation;

  String? _sessionId;
  final Set<String> _surfaceIds = {};
  bool _hasStarted = false;
  int _queuedTurns = 0;
  bool _disposed = false;
  String? _connectionError;
  String? _connectionNotice;
  _AgentTurn? _failedTurn;
  Future<void> _pendingTurn = Future<void>.value();
  @override
  DemoJourney? activeJourney;
  @override
  String? latestInlineSurfaceId;

  @override
  bool get hasStarted => _hasStarted;
  @override
  bool get isBusy => _queuedTurns > 0;
  @override
  String? get connectionError => _connectionError;
  @override
  String? get connectionNotice => _connectionNotice;
  @override
  bool get canRetry => _failedTurn != null && !isBusy;
  @override
  bool get hasSelectedProductsSurface =>
      _surfaceIds.contains('selected-products');
  @override
  bool get hasDressingRoomSurface => _surfaceIds.contains('dressing-room');

  @override
  Future<void> startJourney(DemoJourney journey) => _enqueue(() async {
    _clearSurfaces();
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return;
    activeJourney = journey;
    _sessionId = null;
    _hasStarted = true;
    notifyListeners();
    await _performTurn(
      _AgentTurn(message: '${journey.title}. ${journey.brief}'),
    );
  });

  void _clearSurfaces() {
    for (final surfaceId in _surfaceIds) {
      transport.addMessage(core.DeleteSurfaceMessage(surfaceId: surfaceId));
    }
    _surfaceIds.clear();
    latestInlineSurfaceId = null;
  }

  Future<void> _handleSend(ChatMessage message) async {
    if (_disposed || isBusy || _connectionError != null) return;
    final action = _actionFrom(message);
    final text = message.text.trim();
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
    if (_disposed) return Future<void>.value();
    _queuedTurns++;
    notifyListeners();
    final next = _pendingTurn.then((_) async {
      try {
        if (_disposed) return;
        _connectionError = null;
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
        'context': Map<String, Object?>.from(action['context'] as Map),
      };
    }
    return null;
  }

  Future<bool> _performTurn(_AgentTurn turn) async {
    try {
      final response = await _client
          .post(
            _origin.resolve('/v1/turn'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              if (_sessionId != null) 'sessionId': _sessionId,
              if (turn.message.isNotEmpty) 'message': turn.message,
              if (turn.action != null) 'action': turn.action,
            }),
          )
          .timeout(const Duration(seconds: 70));
      if (_disposed) return false;
      if (response.statusCode == 404 && _sessionId != null && turn.canRecover) {
        _sessionId = null;
        _clearSurfaces();
        await Future<void>.delayed(Duration.zero);
        if (_disposed) return false;
        final journey = activeJourney!;
        return await _performTurn(
          _AgentTurn(
            message:
                '${journey.title}. ${journey.brief}${turn.message.isEmpty ? '' : ' ${turn.message}'}',
            canRecover: false,
            needsReselection: turn.action != null || turn.needsReselection,
          ),
        );
      }
      if (response.statusCode != 200) {
        _recordFailure(
          turn,
          'Your stylist could not respond. Please try again.',
        );
        return false;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map ||
          payload['sessionId'] is! String ||
          (payload['sessionId'] as String).isEmpty ||
          payload['messages'] is! List ||
          (payload['messages'] as List).isEmpty) {
        throw const FormatException('Incomplete agent response');
      }
      // Parse the whole batch before publishing any part of it to the renderer.
      final events = (payload['messages'] as List).map((raw) {
        if (raw is! Map) throw const FormatException('Invalid A2UI message');
        return core.A2uiMessage.fromJson(Map<String, dynamic>.from(raw));
      }).toList();
      _validateSurfaces(events);
      _sessionId = payload['sessionId'] as String;
      for (final event in events) {
        transport.addMessage(event);
        if (event is core.CreateSurfaceMessage) {
          _surfaceIds.add(event.surfaceId);
          if (event.surfaceId.startsWith('inline-')) {
            latestInlineSurfaceId = event.surfaceId;
          }
        } else if (event is core.DeleteSurfaceMessage) {
          _surfaceIds.remove(event.surfaceId);
          if (event.surfaceId == latestInlineSurfaceId) {
            latestInlineSurfaceId = null;
          }
        }
      }
      if (turn.needsReselection) {
        _connectionNotice =
            'Your stylist session restarted. Please select the piece again.';
      }
      await Future<void>.delayed(Duration.zero);
      return !_disposed;
    } on FormatException {
      if (!_disposed) {
        _recordFailure(
          turn,
          'Your stylist sent an incomplete response. Please try again.',
        );
      }
      return false;
    } catch (_) {
      if (!_disposed) {
        _recordFailure(
          turn,
          'Could not connect to your stylist. Check your connection and try again.',
        );
      }
      return false;
    }
  }

  // Check the candidate definitions without mutating the live renderer. The
  // fixed service must leave both host surfaces usable after each full turn.
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
    final supported = buildCommerceCatalog().items
        .map((item) => item.name)
        .toSet();
    String? inlineId = latestInlineSurfaceId;
    for (final event in events) {
      if (event is core.CreateSurfaceMessage) {
        if (event.catalogId != commerceCatalogId ||
            event.surfaceId.isEmpty ||
            components.containsKey(event.surfaceId)) {
          throw const FormatException('Invalid surface creation');
        }
        components[event.surfaceId] = {};
        if (event.surfaceId.startsWith('inline-')) inlineId = event.surfaceId;
      } else if (event is core.DeleteSurfaceMessage) {
        components.remove(event.surfaceId);
        if (event.surfaceId == inlineId) inlineId = null;
      } else if (event is core.UpdateComponentsMessage) {
        final surface = components[event.surfaceId];
        if (surface == null) throw const FormatException('Unknown surface');
        for (final component in event.components) {
          final id = component['id'];
          if (id is! String ||
              id.isEmpty ||
              !supported.contains(component['component'])) {
            throw const FormatException('Invalid component');
          }
          surface[id] = component;
        }
      } else if (event is core.UpdateDataModelMessage &&
          !components.containsKey(event.surfaceId)) {
        throw const FormatException('Unknown data surface');
      }
    }
    if (inlineId == null ||
        !components.containsKey('dressing-room') ||
        !components.containsKey(inlineId) ||
        components.values.any((surface) => !surface.containsKey('root'))) {
      throw const FormatException('Missing surface root');
    }
  }

  void _recordFailure(_AgentTurn turn, String message) {
    _failedTurn = turn;
    _connectionError = message;
  }

  @override
  void dispose() {
    _disposed = true;
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    if (_ownsClient) _client.close();
    super.dispose();
  }
}

class _AgentTurn {
  const _AgentTurn({
    this.message = '',
    this.action,
    this.canRecover = true,
    this.needsReselection = false,
  });
  final String message;
  final Map<String, Object?>? action;
  final bool canRecover;
  final bool needsReselection;
}
