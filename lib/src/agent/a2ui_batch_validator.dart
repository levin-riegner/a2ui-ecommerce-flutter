import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog/a2ui_common_schema.dart';

/// Validates a full candidate batch without mutating a live renderer. All schema
/// references are registered locally; validation performs no network requests.
class A2uiBatchValidator {
  A2uiBatchValidator(this.catalog) {
    registry.addSchema(
      Uri.parse(commonTypesSchemaId),
      Schema.fromMap(jsonDecode(commonTypesSchemaJson) as Map<String, Object?>),
    );
    registry.addSchema(
      Uri.parse('https://a2ui.org/specification/v0_9/catalog.json'),
      catalog.fullSchema,
    );
  }

  final Catalog catalog;
  final SchemaRegistry registry = SchemaRegistry();

  void dispose() => registry.dispose();

  void validate(
    List<core.A2uiMessage> events, {
    Map<String, Map<String, Map<String, dynamic>>> current = const {},
    String? latestInlineSurfaceId,
  }) {
    final components = {
      for (final entry in current.entries)
        entry.key: Map<String, Map<String, dynamic>>.from(entry.value),
    };
    final items = {for (final item in catalog.items) item.name: item};
    var inlineId = latestInlineSurfaceId;
    for (final event in events) {
      if (event is core.CreateSurfaceMessage) {
        if (event.catalogId != catalog.catalogId ||
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
          final item = items[component['component']];
          if (id is! String || id.isEmpty || item == null) {
            throw const FormatException('Invalid component');
          }
          final errors = item.dataSchema.validateSync(
            component,
            schemaRegistry: registry,
          );
          if (errors.isNotEmpty) {
            throw const FormatException('Invalid component properties');
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
    for (final surface in components.values) {
      final visiting = <String>{};
      final visited = <String>{};
      void visit(String id) {
        if (!surface.containsKey(id)) {
          throw const FormatException('Unknown child component');
        }
        if (visited.contains(id)) return;
        if (!visiting.add(id)) {
          throw const FormatException('Cyclic child components');
        }
        final component = surface[id]!;
        final children = component['children'];
        if (children is List) {
          for (final child in children) {
            if (child is String) visit(child);
          }
        } else if (children is Map && children['componentId'] is String) {
          visit(children['componentId'] as String);
        }
        if (component['child'] is String) visit(component['child'] as String);
        visiting.remove(id);
        visited.add(id);
      }

      for (final id in surface.keys) {
        visit(id);
      }
    }
  }
}
