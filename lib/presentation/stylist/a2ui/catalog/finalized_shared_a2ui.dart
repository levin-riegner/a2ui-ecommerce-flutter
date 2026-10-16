import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'commerce_bindings_a2ui.dart';
import '../../../shared/design_system/views/commerce/finalized_shared_components.dart';

/// Finalized shared catalog, read from exact native Figma properties and SVGs.
/// Accessories extend the original six-category set with a neutral placeholder.
final finalizedSharedItems = <CatalogItem>[
  _chipItem,
  _bagItem,
  _toastItem,
  _stepperItem,
  _occasionItem,
  _lookItem,
  _silhouetteItem,
  _sideBarItem,
  CatalogItem(
    name: 'PrimaryButton',
    exampleData: _examples('PrimaryButton'),
    dataSchema: _originalSchema(primaryButtonCatalogItem),
    widgetBuilder: (context) {
      final data = Map<String, Object?>.from(context.data as Map);
      return BoundString(
        dataContext: context.dataContext,
        value: data['label'],
        builder: (_, label) => BoundBool(
          dataContext: context.dataContext,
          value: data['enabled'] ?? true,
          builder: (_, enabled) => FinalizedPrimaryButton(
            label: label ?? '',
            onPressed: enabled == true && _hasEvent(data['action'])
                ? () => _dispatch(context, data['action'])
                : null,
          ),
        ),
      );
    },
  ),
  CatalogItem(
    name: 'Eyebrow',
    exampleData: _examples('Eyebrow'),
    dataSchema: _originalSchema(
      eyebrowCatalogItem,
      description: 'A small sentence-case label above a question or group.',
    ),
    widgetBuilder: (context) {
      final data = Map<String, Object?>.from(context.data as Map);
      return BoundString(
        dataContext: context.dataContext,
        value: data['text'],
        builder: (_, text) => FinalizedEyebrow(text: text ?? ''),
      );
    },
  ),
];

ObjectSchema _originalSchema(
  CatalogItem item, {
  String? description,
  Set<String> optional = const {},
}) {
  final schema = Map<String, Object?>.from(item.dataSchema.value);
  if (description != null) schema['description'] = description;
  schema['properties'] = Map<String, Object?>.from(schema['properties'] as Map)
    ..remove('component');
  schema['required'] = (schema['required'] as List)
      .where((value) => value != 'component' && !optional.contains(value))
      .toList();
  return ObjectSchema.fromMap(schema);
}

bool _hasEvent(Object? action) =>
    action is Map &&
    action['event'] is Map &&
    (action['event'] as Map)['name'] is String &&
    ((action['event'] as Map)['name'] as String).isNotEmpty;

Future<void> _dispatch(CatalogItemContext context, Object? action) async {
  if (!_hasEvent(action)) return;
  final event = Map<String, Object?>.from((action as Map)['event'] as Map);
  final definition = event['context'];
  final resolved = definition is Map
      ? await resolveContext(
          context.dataContext,
          Map<String, Object?>.from(definition),
        )
      : <String, Object?>{};
  context.dispatchEvent(
    UserActionEvent(
      name: event['name']! as String,
      sourceComponentId: context.id,
      context: resolved,
    ),
  );
}

Map<String, Object?> _data(CatalogItemContext c) =>
    Map<String, Object?>.from(c.data as Map);

Widget _string(
  CatalogItemContext c,
  Object? value,
  Widget Function(String) builder,
) => BoundString(
  dataContext: c.dataContext,
  value: value,
  builder: (_, v) => builder(v ?? ''),
);

Widget _number(
  CatalogItemContext c,
  Object? value,
  Widget Function(num) builder,
) => BoundNumber(
  dataContext: c.dataContext,
  value: value,
  builder: (_, v) => builder(v ?? 0),
);

Future<void> _dispatchValue(
  CatalogItemContext c,
  Object? action,
  Map<String, Object?> extra,
) async {
  if (!_hasEvent(action)) return;
  final e = Map<String, Object?>.from((action as Map)['event'] as Map);
  final definition = e['context'];
  final resolved = definition is Map
      ? await resolveContext(
          c.dataContext,
          Map<String, Object?>.from(definition),
        )
      : <String, Object?>{};
  c.dispatchEvent(
    UserActionEvent(
      name: e['name']! as String,
      sourceComponentId: c.id,
      context: {...resolved, ...extra},
    ),
  );
}

void _updateBound(CatalogItemContext c, Object? reference, Object value) {
  if (reference is Map &&
      reference['path'] is String &&
      (reference['path'] as String).startsWith('/')) {
    c.dataContext.update(DataPath(reference['path'] as String), value);
  }
}

final _chipItem = CatalogItem(
  name: 'ChoiceChip',
  exampleData: _examples('ChoiceChip'),
  // Bound selected values edit the local draft without dispatching an action.
  dataSchema: _originalSchema(chipCatalogItem, optional: const {'action'}),
  widgetBuilder: (c) {
    final d = _data(c);
    return _string(
      c,
      d['label'],
      (label) => BoundBool(
        dataContext: c.dataContext,
        value: d['selected'] ?? false,
        builder: (_, selected) => FinalizedChip(
          label: label,
          selected: selected == true,
          onChanged: _hasEvent(d['action']) || d['selected'] is Map
              ? (next) {
                  _updateBound(c, d['selected'], next);
                  _dispatchValue(c, d['action'], {'selected': next});
                }
              : null,
        ),
      ),
    );
  },
);

final _bagItem = CatalogItem(
  name: 'BagIcon',
  exampleData: _examples('BagIcon'),
  dataSchema: S.object(
    properties: {
      'count': A2uiSchemas.numberReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['count', 'action'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _number(
      c,
      d['count'],
      (n) => FinalizedBagIcon(
        count: n.toInt(),
        onPressed: _hasEvent(d['action'])
            ? () => _dispatch(c, d['action'])
            : null,
      ),
    );
  },
);

final _toastItem = CatalogItem(
  name: 'Toast',
  exampleData: _examples('Toast'),
  dataSchema: S.object(
    properties: {
      'message': A2uiSchemas.stringReference(),
      'actionLabel': A2uiSchemas.stringReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['message', 'actionLabel', 'action'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _string(
      c,
      d['message'],
      (m) => _string(
        c,
        d['actionLabel'],
        (l) => FinalizedToast(
          message: m,
          actionLabel: l,
          onPressed: _hasEvent(d['action'])
              ? () => _dispatch(c, d['action'])
              : null,
        ),
      ),
    );
  },
);

final _stepperItem = CatalogItem(
  name: 'QuantityStepper',
  exampleData: _examples('QuantityStepper'),
  dataSchema: S.object(
    properties: {
      'value': A2uiSchemas.numberReference(),
      'max': S.integer(minimum: 1, maximum: 999),
      'action': A2uiSchemas.action(),
      'removeAction': A2uiSchemas.action(),
    },
    required: ['value', 'action', 'removeAction'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _number(
      c,
      d['value'],
      (v) => FinalizedQuantityStepper(
        value: v.toInt(),
        max: ((d['max'] as num?)?.toInt() ?? 99).clamp(1, 999),
        onChanged: _hasEvent(d['action'])
            ? (v) {
                _updateBound(c, d['value'], v);
                _dispatchValue(c, d['action'], {'quantity': v});
              }
            : null,
        onRemove: _hasEvent(d['removeAction'])
            ? () {
                _updateBound(c, d['value'], 0);
                _dispatchValue(c, d['removeAction'], {'quantity': 0});
              }
            : null,
      ),
    );
  },
);

final _occasionItem = CatalogItem(
  name: 'OccasionTile',
  exampleData: _examples('OccasionTile'),
  dataSchema: S.object(
    properties: {
      'imageAsset': A2uiSchemas.stringReference(),
      'label': A2uiSchemas.stringReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['label'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _string(
      c,
      d['label'],
      (l) => _string(
        c,
        d['imageAsset'],
        (a) => FinalizedOccasionTile(
          label: l,
          imageAsset: a,
          onPressed: _hasEvent(d['action'])
              ? () => _dispatch(c, d['action'])
              : null,
        ),
      ),
    );
  },
);

final _lookItem = CatalogItem(
  name: 'LookTile',
  exampleData: _examples('LookTile'),
  dataSchema: S.object(
    properties: {
      'category': S.string(enumValues: finalizedCategories),
      'imageAsset': A2uiSchemas.stringReference(),
      'label': A2uiSchemas.stringReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['category', 'label'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _string(
      c,
      d['label'],
      (l) => _string(
        c,
        d['imageAsset'],
        (a) => FinalizedLookTile(
          category: d['category'] as String? ?? 'dress',
          label: l,
          imageAsset: a,
          onPressed: _hasEvent(d['action'])
              ? () => _dispatch(c, d['action'])
              : null,
        ),
      ),
    );
  },
);

final _silhouetteItem = CatalogItem(
  name: 'GarmentSilhouette',
  exampleData: _examples('GarmentSilhouette'),
  dataSchema: S.object(
    properties: {'category': S.string(enumValues: finalizedCategories)},
    required: ['category'],
  ),
  widgetBuilder: (c) => FinalizedGarmentSilhouette(
    category: _data(c)['category'] as String? ?? 'dress',
  ),
);

final _sideBarItem = CatalogItem(
  name: 'SideBar',
  exampleData: _examples('SideBar'),
  dataSchema: S.object(
    properties: {
      'count': A2uiSchemas.numberReference(),
      'closeAction': A2uiSchemas.action(),
      'bagAction': A2uiSchemas.action(),
      'statusPreview': S.boolean(),
    },
    required: ['count', 'closeAction', 'bagAction'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    return _number(
      c,
      d['count'],
      (n) => FinalizedSideBar(
        count: n.toInt(),
        statusPreview: d['statusPreview'] == true,
        onClose: _hasEvent(d['closeAction'])
            ? () => _dispatch(c, d['closeAction'])
            : null,
        onBag: _hasEvent(d['bagAction'])
            ? () => _dispatch(c, d['bagAction'])
            : null,
      ),
    );
  },
);

List<ExampleBuilderCallback> _examples(String name) {
  final action = <String, Object?>{
    'event': {'name': 'open_bag', 'context': <String, Object?>{}},
  };
  final props = switch (name) {
    'ChoiceChip' => [
      for (final selected in [false, true])
        {
          'label': 'Black tie',
          'selected': selected,
          'action': {
            'event': {
              'name': 'choose_formality',
              'context': {'value': 'black-tie'},
            },
          },
        },
    ],
    'PrimaryButton' => [
      {
        'label': 'Find options',
        'action': {
          'event': {
            'name': 'find_options',
            'context': {'occasion': 'Berlin first day'},
          },
        },
      },
    ],
    'Eyebrow' => [
      {'text': 'How formal?'},
    ],
    'BagIcon' => [
      for (final n in [0, 1, 4, 5]) {'count': n, 'action': action},
    ],
    'Toast' => [
      {'message': '4 items added', 'actionLabel': 'View bag', 'action': action},
      {
        'message': 'Item removed',
        'actionLabel': 'Undo',
        'action': {
          'event': {
            'name': 'undo_remove',
            'context': {'productId': 'demo-0001'},
          },
        },
      },
    ],
    'QuantityStepper' => [
      for (final n in [1, 2, 99])
        {
          'value': n,
          'max': 99,
          'action': {
            'event': {
              'name': 'change_quantity',
              'context': {'productId': 'demo-0001'},
            },
          },
          'removeAction': {
            'event': {
              'name': 'remove_bag_item',
              'context': {'productId': 'demo-0001'},
            },
          },
        },
    ],
    'OccasionTile' => [
      {'label': 'Occasion image placeholder'},
      {
        'label': 'Catalog photograph example',
        'imageAsset': 'assets/images/products/demo-0001.jpg',
        'action': {
          'event': {
            'name': 'choose_occasion',
            'context': {'occasion': 'Berlin first day'},
          },
        },
      },
    ],
    'LookTile' => [
      for (final category in finalizedCategories)
        {'category': category, 'label': '$category placeholder'},
      {
        'category': 'dress',
        'label': 'Catalog product photograph',
        'imageAsset': 'assets/images/products/demo-0001.jpg',
      },
    ],
    'GarmentSilhouette' => [
      for (final category in finalizedCategories) {'category': category},
    ],
    'SideBar' => [
      for (final preview in [false, true])
        {
          'count': 4,
          'statusPreview': preview,
          'closeAction': {
            'event': {'name': 'close_stylist', 'context': <String, Object?>{}},
          },
          'bagAction': action,
        },
    ],
    _ => <Map<String, Object?>>[],
  };
  return [
    for (final value in props)
      () => jsonEncode([
        {'id': 'root', 'component': name, ...value},
      ]),
  ];
}
