import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

import '../catalog/commerce_catalog.dart';
import '../data/models.dart';
import 'commerce_agent.dart';

/// Connects Flutter's A2UI renderer to the local catalog agent service.
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
  int _localTurn = 0;
  bool _hasStarted = false;
  bool _hasSelectedProductsSurface = false;
  Future<void> _pendingTurn = Future<void>.value();
  @override
  DemoJourney? activeJourney;
  @override
  String? latestInlineSurfaceId;

  @override
  bool get hasStarted => _hasStarted;

  @override
  bool get hasSelectedProductsSurface => _hasSelectedProductsSurface;

  @override
  Future<void> startJourney(DemoJourney journey) async {
    return _enqueue(() async {
      _clearSurfaces();
      await Future<void>.delayed(Duration.zero);
      activeJourney = journey;
      _sessionId = null;
      _localTurn = 0;
      _hasStarted = true;
      notifyListeners();
      await _performTurn(message: '${journey.title}. ${journey.brief}');
    });
  }

  void _clearSurfaces() {
    for (final surfaceId in _surfaceIds) {
      transport.addMessage(core.DeleteSurfaceMessage(surfaceId: surfaceId));
    }
    _surfaceIds.clear();
    latestInlineSurfaceId = null;
    _hasSelectedProductsSurface = false;
  }

  Future<void> _handleSend(ChatMessage message) async {
    final action = _actionFrom(message);
    final text = message.text.trim();
    if (action == null && text.isEmpty) return;
    await _enqueue(() => _performTurn(message: text, action: action));
  }

  Future<void> _enqueue(Future<void> Function() turn) {
    final next = _pendingTurn.then((_) => turn());
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

  Future<void> _performTurn({
    String message = '',
    Map<String, Object?>? action,
    bool canRecover = true,
  }) async {
    try {
      final requestBody = <String, Object?>{
        if (_sessionId != null) 'sessionId': _sessionId,
        if (message.isNotEmpty) 'message': message,
      };
      if (action != null) requestBody['action'] = action;
      final response = await _client
          .post(
            _origin.resolve('/v1/turn'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 70));
      Object? payload;
      try {
        payload = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode == 200) rethrow;
      }
      if (response.statusCode == 404 && _sessionId != null && canRecover) {
        _sessionId = null;
        _clearSurfaces();
        await Future<void>.delayed(Duration.zero);
        final journey = activeJourney;
        if (journey != null) {
          await _performTurn(
            message:
                '${journey.title}. ${journey.brief}${message.isEmpty ? '' : ' $message'}',
            canRecover: false,
          );
          if (action != null) {
            _showError(
              'The stylist session expired. Please select the product again.',
            );
          }
          return;
        }
      }
      if (response.statusCode != 200) {
        final detail = payload is Map && payload['error'] is String
            ? payload['error'] as String
            : 'HTTP ${response.statusCode}';
        _showError('Stylist service error: $detail');
        return;
      }
      if (payload is! Map) {
        throw const FormatException('Catalog agent response is incomplete');
      }
      final data = Map<String, Object?>.from(payload);
      if (data['sessionId'] is! String || data['messages'] is! List) {
        throw const FormatException('Catalog agent response is incomplete');
      }
      _sessionId = data['sessionId'] as String;
      for (final raw in data['messages'] as List) {
        if (raw is! Map) throw const FormatException('Invalid A2UI message');
        final envelope = Map<String, dynamic>.from(raw);
        final event = core.A2uiMessage.fromJson(envelope);
        transport.addMessage(event);
        if (event is core.CreateSurfaceMessage) {
          _surfaceIds.add(event.surfaceId);
          if (event.surfaceId.startsWith('inline-')) {
            latestInlineSurfaceId = event.surfaceId;
          } else if (event.surfaceId == 'selected-products') {
            _hasSelectedProductsSurface = true;
          }
        }
      }
      await Future<void>.delayed(Duration.zero);
      notifyListeners();
    } catch (_) {
      _showError(
        'Could not reach the local stylist service. Check that it is running and try again.',
      );
    }
  }

  void _showError(String message) {
    final surfaceId = 'inline-error-${++_localTurn}';
    transport.addMessage(
      core.CreateSurfaceMessage(
        surfaceId: surfaceId,
        catalogId: commerceCatalogId,
        sendDataModel: true,
      ),
    );
    transport.addMessage(
      core.UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: [
          {
            'id': 'root',
            'component': 'StylistMessage',
            'text': {'path': '/message'},
          },
        ],
      ),
    );
    transport.addMessage(
      core.UpdateDataModelMessage(
        surfaceId: surfaceId,
        value: {'message': message},
      ),
    );
    latestInlineSurfaceId = surfaceId;
    _surfaceIds.add(surfaceId);
    notifyListeners();
  }

  @override
  void dispose() {
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
