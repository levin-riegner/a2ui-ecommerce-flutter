import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../data/models.dart';
import 'commerce_components.dart';

Map<String, Object?> _map(Object value) =>
    Map<String, Object?>.from(value as Map);

Future<void> _dispatchAction(CatalogItemContext context, Object? action) async {
  if (action is! Map || action['event'] is! Map) return;
  final event = _map(action['event']!);
  final name = event['name'];
  if (name is! String) return;
  final contextDefinition = event['context'];
  final resolvedContext = contextDefinition is Map
      ? await resolveContext(context.dataContext, _map(contextDefinition))
      : <String, Object?>{};
  context.dispatchEvent(
    UserActionEvent(
      name: name,
      sourceComponentId: context.id,
      context: resolvedContext,
    ),
  );
}

final chipCatalogItem = CatalogItem(
  name: 'ChoiceChip',
  dataSchema: S.object(
    description: 'A compact single-choice control for a structured prompt.',
    properties: {
      'label': A2uiSchemas.stringReference(),
      'selected': A2uiSchemas.booleanReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['label', 'action'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return BoundString(
      dataContext: context.dataContext,
      value: data['label'],
      builder: (_, label) => BoundBool(
        dataContext: context.dataContext,
        value: data['selected'] ?? false,
        builder: (_, selected) => CommerceChoice(
          label: label ?? '',
          selected: selected == true,
          onPressed: () => _dispatchAction(context, data['action']),
        ),
      ),
    );
  },
);

final choiceGroupCatalogItem = CatalogItem(
  name: 'ChoiceGroup',
  dataSchema: S.object(
    description: 'A wrapping group of single-select commerce chips.',
    properties: {
      'options': A2uiSchemas.stringArrayReference(),
      'selected': A2uiSchemas.stringReference(),
      'selectionPath': S.string(
        description:
            'Optional local data-model path updated before form submission.',
      ),
      'action': A2uiSchemas.action(),
    },
    required: ['options'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return BoundList(
      dataContext: context.dataContext,
      value: data['options'],
      builder: (_, options) => BoundString(
        dataContext: context.dataContext,
        value: data['selected'],
        builder: (_, selected) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in (options ?? const <Object?>[]).map(
              (value) => value.toString(),
            ))
              CommerceChoice(
                label: option,
                selected: option == selected,
                onPressed: () {
                  final selectionPath = data['selectionPath'];
                  if (selectionPath is String &&
                      selectionPath.startsWith('/')) {
                    context.dataContext.update(DataPath(selectionPath), option);
                  } else {
                    _dispatchChoiceGroupAction(context, data['action'], option);
                  }
                },
              ),
          ],
        ),
      ),
    );
  },
);

void _dispatchChoiceGroupAction(
  CatalogItemContext context,
  Object? action,
  String value,
) {
  if (action is! Map || action['event'] is! Map) return;
  final event = _map(action['event']!);
  final name = event['name'];
  if (name is! String) return;
  context.dispatchEvent(
    UserActionEvent(
      name: name,
      sourceComponentId: context.id,
      context: {'value': value},
    ),
  );
}

final primaryButtonCatalogItem = CatalogItem(
  name: 'PrimaryButton',
  dataSchema: S.object(
    description: 'A single primary action button.',
    properties: {
      'label': A2uiSchemas.stringReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['label', 'action'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return BoundString(
      dataContext: context.dataContext,
      value: data['label'],
      builder: (_, label) => CommercePrimaryButton(
        label: label ?? '',
        onPressed: () => _dispatchAction(context, data['action']),
      ),
    );
  },
);

final budgetSliderCatalogItem = CatalogItem(
  name: 'BudgetSlider',
  dataSchema: S.object(
    description:
        'A bounded budget control that updates the surface data model.',
    properties: {
      'value': A2uiSchemas.numberReference(),
      'min': S.number(),
      'max': S.number(),
    },
    required: ['value', 'min', 'max'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    final min = (data['min'] as num?)?.toDouble() ?? 0;
    final max = (data['max'] as num?)?.toDouble() ?? 2000;
    return BoundNumber(
      dataContext: context.dataContext,
      value: data['value'],
      builder: (_, value) => CommerceBudgetControl(
        value: (value ?? min).toDouble(),
        min: min,
        max: max,
        onChanged: (next) =>
            context.dataContext.update(DataPath('/budget'), next),
      ),
    );
  },
);

final stylistMessageCatalogItem = CatalogItem(
  name: 'StylistMessage',
  dataSchema: S.object(
    description: 'A warm assistant message that ends with a next step.',
    properties: {'text': A2uiSchemas.stringReference()},
    required: ['text'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return BoundString(
      dataContext: context.dataContext,
      value: data['text'],
      builder: (_, text) => CommerceStylistMessage(text: text ?? ''),
    );
  },
);

final eyebrowCatalogItem = CatalogItem(
  name: 'Eyebrow',
  dataSchema: S.object(
    description: 'A small uppercase section label.',
    properties: {'text': A2uiSchemas.stringReference()},
    required: ['text'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return BoundString(
      dataContext: context.dataContext,
      value: data['text'],
      builder: (_, text) => CommerceEyebrow(text: text ?? ''),
    );
  },
);

bool _isRemoval(Object? action) =>
    action is Map &&
    action['event'] is Map &&
    (action['event'] as Map)['name'] == 'remove_product';

final productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  dataSchema: S.object(
    description: 'A selectable recommendation card with a reason tag.',
    properties: {
      'name': A2uiSchemas.stringReference(),
      'price': A2uiSchemas.stringReference(),
      'brandLine': A2uiSchemas.stringReference(),
      'tag': A2uiSchemas.stringReference(),
      'swatch': A2uiSchemas.stringReference(),
      'imageAsset': A2uiSchemas.stringReference(),
      'action': A2uiSchemas.action(),
    },
    required: ['name', 'price', 'brandLine', 'tag', 'swatch', 'action'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return _BoundStrings(
      context: context,
      data: data,
      fields: const [
        'name',
        'price',
        'brandLine',
        'tag',
        'swatch',
        'imageAsset',
      ],
      builder: (values) => CommerceProductCard(
        name: values['name']!,
        price: values['price']!,
        brandLine: values['brandLine']!,
        tag: values['tag']!,
        swatch: values['swatch'],
        imageAsset: values['imageAsset'],
        removal: _isRemoval(data['action']),
        onPressed: () => _dispatchAction(context, data['action']),
      ),
    );
  },
);

final pieceSlotCatalogItem = CatalogItem(
  name: 'PieceSlot',
  dataSchema: S.object(
    description: 'A dressing-room slot that can be empty, next, or filled.',
    properties: {
      'label': A2uiSchemas.stringReference(),
      'meta': A2uiSchemas.stringReference(),
      'state': A2uiSchemas.stringReference(),
      'swatch': A2uiSchemas.stringReference(),
    },
    required: ['label', 'meta', 'state', 'swatch'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return _BoundStrings(
      context: context,
      data: data,
      fields: const ['label', 'meta', 'state', 'swatch'],
      builder: (values) => CommercePieceSlot(
        label: values['label']!,
        meta: values['meta']!,
        state: values['state']!,
        swatch: values['swatch'],
      ),
    );
  },
);

final dressingRoomCatalogItem = CatalogItem(
  name: 'DressingRoom',
  dataSchema: S.object(
    description: 'A persistent host-owned dressing-room summary surface.',
    properties: {
      'title': A2uiSchemas.stringReference(),
      'brief': A2uiSchemas.stringReference(),
      'spent': A2uiSchemas.stringReference(),
      'left': A2uiSchemas.stringReference(),
      'progress': A2uiSchemas.numberReference(),
      'slots': A2uiSchemas.listOrReference(
        description: 'The host-planned dressing-room slots, in journey order.',
        items: S.object(
          properties: {
            for (final field in [
              'category',
              'label',
              'name',
              'meta',
              'swatch',
              'imageAsset',
              'state',
            ])
              field: S.string(),
          },
          required: ['category', 'label', 'name', 'meta', 'swatch', 'state'],
        ),
      ),
      'planCaption': A2uiSchemas.stringReference(),
      for (final slot in ['dress', 'layer', 'shoes', 'bag'])
        for (final suffix in ['Name', 'Meta', 'Swatch', 'ImageAsset'])
          '$slot$suffix': A2uiSchemas.stringReference(),
    },
    required: ['title', 'brief', 'spent', 'left', 'progress'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    return _DressingRoomBindings(context: context, data: data);
  },
);

class _DressingRoomBindings extends StatelessWidget {
  const _DressingRoomBindings({required this.context, required this.data});
  final CatalogItemContext context;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext buildContext) => _BoundStrings(
    context: context,
    data: data,
    fields: const ['brief', 'spent', 'left', 'planCaption'],
    builder: (values) => BoundNumber(
      dataContext: context.dataContext,
      value: data['progress'],
      builder: (_, progress) {
        Widget room(List<CommercePieceData> pieces) => CommerceDressingRoom(
          brief: values['brief']!,
          spent: values['spent']!,
          left: values['left']!,
          progress: progress?.toDouble() ?? 0,
          planCaption: values['planCaption']!,
          pieces: pieces,
        );
        if (data.containsKey('slots')) {
          return BoundList(
            dataContext: context.dataContext,
            value: data['slots'],
            builder: (_, rows) => room([
              for (final row in rows ?? const <Object?>[])
                if (row is Map && _slotCategory(row['category']) != null)
                  CommercePieceData(
                    _slotCategory(row['category'])!,
                    row['label']?.toString() ?? '',
                    row['name']?.toString() ?? '',
                    row['meta']?.toString() ?? '',
                    row['swatch']?.toString(),
                    row['state']?.toString() ?? 'Empty',
                    imageAsset: row['imageAsset']?.toString() ?? '',
                  ),
            ]),
          );
        }
        // Older showcase fixtures bind the original four named slots.
        return _LegacyPieceBindings(
          context: context,
          data: data,
          builder: room,
        );
      },
    ),
  );
}

ProductCategory? _slotCategory(Object? value) {
  for (final category in ProductCategory.values) {
    if (category.name == value) return category;
  }
  return null;
}

class _LegacyPieceBindings extends StatelessWidget {
  const _LegacyPieceBindings({
    required this.context,
    required this.data,
    required this.builder,
  });

  final CatalogItemContext context;
  final Map<String, Object?> data;
  final Widget Function(List<CommercePieceData>) builder;

  @override
  Widget build(BuildContext buildContext) {
    const labels = {
      'dress': 'A dress',
      'layer': 'A layer over it',
      'shoes': 'Shoes',
      'bag': 'A bag',
    };
    final fields = [
      for (final slot in labels.keys)
        for (final suffix in ['Name', 'Meta', 'Swatch', 'ImageAsset'])
          '$slot$suffix',
    ];
    Widget bind(int index, Map<String, String> values) {
      if (index < fields.length) {
        final field = fields[index];
        return BoundString(
          dataContext: context.dataContext,
          value: data[field],
          builder: (_, value) =>
              bind(index + 1, {...values, field: value ?? ''}),
        );
      }
      final next = labels.keys
          .where(
            (slot) =>
                values['${slot}Name']!.isEmpty &&
                values['${slot}Meta'] == 'Choosing on the left',
          )
          .firstOrNull;
      return builder([
        for (final entry in labels.entries)
          CommercePieceData(
            _slotCategory(entry.key)!,
            entry.value,
            values['${entry.key}Name']!,
            values['${entry.key}Meta']!,
            values['${entry.key}Swatch'],
            values['${entry.key}Name']!.isNotEmpty
                ? 'Filled'
                : entry.key == next
                ? 'Next'
                : 'Empty',
            imageAsset: values['${entry.key}ImageAsset']!,
          ),
      ]);
    }

    return bind(0, {});
  }
}

/// Keeps the A2UI binding adapter separate from reusable presentation widgets.
class _BoundStrings extends StatelessWidget {
  const _BoundStrings({
    required this.context,
    required this.data,
    required this.fields,
    required this.builder,
  });
  final CatalogItemContext context;
  final Map<String, Object?> data;
  final List<String> fields;
  final Widget Function(Map<String, String>) builder;
  @override
  Widget build(BuildContext buildContext) {
    Widget bind(int index, Map<String, String> values) {
      if (index == fields.length) return builder(values);
      final field = fields[index];
      return BoundString(
        dataContext: context.dataContext,
        value: data[field],
        builder: (_, value) => bind(index + 1, {...values, field: value ?? ''}),
      );
    }

    return bind(0, {});
  }
}
