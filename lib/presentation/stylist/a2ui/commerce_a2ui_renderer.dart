import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

import 'a2ui_batch_validator.dart';
import 'catalog/commerce_catalog.dart';

/// Owns live GenUI resources and surface provenance, independently of BLoC
/// snapshots. A screen or inspector can switch views without reconnecting.
class CommerceA2uiRenderer {
  CommerceA2uiRenderer({
    required Future<void> Function(ChatMessage) onSend,
    Catalog? catalog,
  }) {
    final registeredCatalog = catalog ?? buildCommerceCatalog();
    componentNames = Set.unmodifiable(
      registeredCatalog.items.map((i) => i.name),
    );
    controller = SurfaceController(catalogs: [registeredCatalog]);
    _validator = A2uiBatchValidator(registeredCatalog);
    _transport = _DrainingA2uiTransport(onSend: onSend);
    conversation = Conversation(controller: controller, transport: transport);
  }

  late final SurfaceController controller;
  late final Set<String> componentNames;
  late final _DrainingA2uiTransport _transport;
  A2uiTransportAdapter get transport => _transport;
  late final Conversation conversation;
  late final A2uiBatchValidator _validator;
  final Set<String> _surfaceIds = {};
  int _interactionGeneration = 0;
  bool _disposed = false;
  Future<void>? _closing;

  Set<String> get surfaceIds => Set.unmodifiable(_surfaceIds);
  bool contains(String id) => _surfaceIds.contains(id);

  void publish(core.A2uiMessage message) {
    if (_disposed) return;
    transport.addMessage(message);
    if (message is core.CreateSurfaceMessage) {
      _surfaceIds.add(message.surfaceId);
    } else if (message is core.DeleteSurfaceMessage) {
      _surfaceIds.remove(message.surfaceId);
    }
  }

  void clear() {
    _interactionGeneration++;
    for (final id in _surfaceIds.toList()) {
      publish(core.DeleteSurfaceMessage(surfaceId: id));
    }
    _surfaceIds.clear();
  }

  /// History and provisional surfaces are read-only even when callers bypass
  /// the widget guards. Generation stamps also reject reused old surface IDs.
  bool accepts(ChatMessage message, {required String? latestInlineSurfaceId}) {
    if (_disposed) return false;
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

  Map<String, Object?>? actionFrom(ChatMessage message) {
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

  List<core.A2uiMessage> parse(Map<String, dynamic> payload) {
    final messages = payload['messages'];
    if (messages is! List) throw const FormatException('Invalid A2UI batch');
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

    return messages.map((raw) {
      if (raw is! Map) throw const FormatException('Invalid A2UI message');
      return core.A2uiMessage.fromJson(
        Map<String, dynamic>.from(
          raw.containsKey('updateComponents') ? stamp(raw) as Map : raw,
        ),
      );
    }).toList();
  }

  /// Validates candidate definitions without publishing a partial batch.
  void validate(
    List<core.A2uiMessage> events, {
    required String? latestInlineSurfaceId,
  }) {
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
    _validator.validate(
      events,
      current: components,
      latestInlineSurfaceId: latestInlineSurfaceId,
    );
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    // Conversation's finally updates its notifier after transport completion.
    // Drain real sends before disposing that notifier or its subscriptions.
    await _transport.drain();
    _validator.dispose();
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    _surfaceIds.clear();
  }
}

/// Tracks the same Futures awaited by the SDK Conversation. The Conversation
/// registers its completion continuation when sendRequest returns; drain adds
/// its waiters later, so the SDK finally runs before drain finishes.
class _DrainingA2uiTransport extends A2uiTransportAdapter {
  _DrainingA2uiTransport({required super.onSend});

  final Set<Future<void>> _pending = {};

  @override
  Future<void> sendRequest(ChatMessage message) {
    final request = super.sendRequest(message);
    _pending.add(request);
    request.then<void>(
      (_) {
        _pending.remove(request);
      },
      onError: (Object _, StackTrace _) {
        _pending.remove(request);
      },
    );
    return request;
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(
        _pending.toList().map(
          (request) =>
              request.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        ),
      );
    }
  }
}
