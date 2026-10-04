import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../data/models.dart';

Color _colorFromHex(Object? value, {Color fallback = const Color(0xffe4e4e7)}) {
  final raw = value?.toString().replaceFirst('#', '');
  if (raw == null || (raw.length != 6 && raw.length != 8)) return fallback;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return fallback;
  return Color(raw.length == 6 ? 0xff000000 | parsed : parsed);
}

Widget _productImage(String? path, String? swatch) {
  final fallback = ColoredBox(
    color: _colorFromHex(swatch),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, color: Colors.white70),
    ),
  );
  // Product imagery must resolve from the bundled public catalog, never from a
  // URL or an arbitrary path supplied in an A2UI message.
  if (path == null ||
      !RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
          .hasMatch(path)) {
    return fallback;
  }
  return Image.asset(
    path,
    fit: BoxFit.contain,
    width: double.infinity,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, error, stackTrace) => fallback,
  );
}

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
      builder: (buildContext, label) => BoundBool(
        dataContext: context.dataContext,
        value: data['selected'] ?? false,
        builder: (_, selected) => Semantics(
          button: true,
          selected: selected == true,
          label: label ?? '',
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => _dispatchAction(context, data['action']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: selected == true
                    ? const Color(0xff18181b)
                    : Colors.white,
                border: Border.all(
                  color: selected == true
                      ? const Color(0xff18181b)
                      : const Color(0xffe4e4e7),
                ),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label ?? '',
                style: TextStyle(
                  color: selected == true
                      ? Colors.white
                      : const Color(0xff18181b),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
              Semantics(
                button: true,
                selected: option == selected,
                label: option,
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    final selectionPath = data['selectionPath'];
                    if (selectionPath is String &&
                        selectionPath.startsWith('/')) {
                      context.dataContext.update(
                        DataPath(selectionPath),
                        option,
                      );
                    } else {
                      _dispatchChoiceGroupAction(
                        context,
                        data['action'],
                        option,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: option == selected
                          ? const Color(0xff18181b)
                          : Colors.white,
                      border: Border.all(
                        color: option == selected
                            ? const Color(0xff18181b)
                            : const Color(0xffe4e4e7),
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        color: option == selected
                            ? Colors.white
                            : const Color(0xff18181b),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
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
      builder: (_, label) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _dispatchAction(context, data['action']),
          child: Text(label ?? ''),
        ),
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
      builder: (buildContext, value) {
        final current = (value ?? min).toDouble().clamp(min, max);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Budget for the whole outfit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(buildContext).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '€${current.toStringAsFixed(0)}',
                  style: Theme.of(buildContext).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Slider(
              value: current,
              min: min,
              max: max,
              divisions: ((max - min) / 50).round().clamp(1, 100),
              label: '€${current.toStringAsFixed(0)}',
              onChanged: (next) =>
                  context.dataContext.update(DataPath('/budget'), next),
            ),
          ],
        );
      },
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
      builder: (buildContext, text) => Text(
        text ?? '',
        style: Theme.of(buildContext).textTheme.bodyLarge
            ?.copyWith(height: 1.35, color: const Color(0xff18181b)),
      ),
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
      builder: (buildContext, text) => Text(
        text ?? '',
        style: Theme.of(buildContext).textTheme.labelSmall
            ?.copyWith(color: const Color(0xff71717a)),
      ),
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
    return BoundString(
      dataContext: context.dataContext,
      value: data['name'],
      builder: (_, name) => BoundString(
        dataContext: context.dataContext,
        value: data['price'],
        builder: (_, price) => BoundString(
          dataContext: context.dataContext,
          value: data['brandLine'],
          builder: (buildContext, brandLine) => BoundString(
            dataContext: context.dataContext,
            value: data['tag'],
            builder: (_, tag) => BoundString(
              dataContext: context.dataContext,
              value: data['swatch'],
              builder: (_, swatch) => BoundString(
                dataContext: context.dataContext,
                value: data['imageAsset'],
                builder: (_, imageAsset) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _dispatchAction(context, data['action']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xffe4e4e7)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final imageExtent = constraints.maxWidth < 360
                            ? 92.0
                            : 112.0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: imageExtent,
                              height: imageExtent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: _productImage(imageAsset, swatch),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SizedBox(
                                height: imageExtent,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name ?? '',
                                            style: Theme.of(buildContext)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          price ?? '',
                                          style: Theme.of(buildContext)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      brandLine ?? '',
                                      style: Theme.of(buildContext)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xff71717a),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tag ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(buildContext)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isRemoval(data['action'])
                                              ? 'Remove'
                                              : 'Choose this',
                                          style: Theme.of(buildContext)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
    return BoundString(
      dataContext: context.dataContext,
      value: data['label'],
      builder: (_, label) => BoundString(
        dataContext: context.dataContext,
        value: data['meta'],
        builder: (_, meta) => BoundString(
          dataContext: context.dataContext,
          value: data['state'],
          builder: (_, state) => BoundString(
            dataContext: context.dataContext,
            value: data['swatch'],
            builder: (buildContext, swatch) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffe4e4e7))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _colorFromHex(swatch),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: state == 'Filled'
                        ? const Icon(Icons.check, color: Colors.white70)
                        : const Icon(Icons.add, color: Color(0xffa1a1aa)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label ?? '',
                          style: Theme.of(buildContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta ?? '',
                          style: Theme.of(buildContext).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xff71717a)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    state ?? '',
                    style: Theme.of(buildContext).textTheme.labelSmall
                        ?.copyWith(color: const Color(0xff71717a)),
                  ),
                ],
              ),
            ),
          ),
        ),
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
  Widget build(BuildContext buildContext) {
    return BoundString(
      dataContext: context.dataContext,
      value: data['brief'],
      builder: (_, brief) => BoundString(
        dataContext: context.dataContext,
        value: data['spent'],
        builder: (_, spent) => BoundString(
          dataContext: context.dataContext,
          value: data['left'],
          builder: (_, left) => BoundNumber(
            dataContext: context.dataContext,
            value: data['progress'],
            builder: (_, progress) => BoundString(
              dataContext: context.dataContext,
              value: data['planCaption'],
              builder: (_, caption) {
                Widget room(List<_PieceData> pieces) => _DressingRoom(
                  brief: brief ?? '',
                  spent: spent ?? '',
                  left: left ?? '',
                  progress: progress?.toDouble() ?? 0,
                  planCaption: caption ?? '',
                  pieces: pieces,
                );
                if (data.containsKey('slots')) {
                  return BoundList(
                    dataContext: context.dataContext,
                    value: data['slots'],
                    builder: (_, rows) => room([
                      for (final row in rows ?? const <Object?>[])
                        if (row is Map &&
                            _slotCategory(row['category']) != null)
                          _PieceData(
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
          ),
        ),
      ),
    );
  }
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
  final Widget Function(List<_PieceData>) builder;

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
          _PieceData(
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

class _PieceData {
  const _PieceData(
    this.category,
    this.label,
    this.name,
    this.meta,
    this.swatch,
    this.state, {
    this.imageAsset = '',
  });

  final ProductCategory category;
  final String label;
  final String name;
  final String meta;
  final String? swatch;
  final String state;
  final String imageAsset;
}

class _DressingRoom extends StatelessWidget {
  const _DressingRoom({
    required this.brief,
    required this.spent,
    required this.left,
    required this.progress,
    required this.pieces,
    required this.planCaption,
  });

  final String brief;
  final String spent;
  final String left;
  final double progress;
  final List<_PieceData> pieces;
  final String planCaption;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = MediaQuery.sizeOf(context).width < 900;
          final fourAcross = portrait || constraints.maxWidth >= 520;
          final innerPadding = fourAcross ? 18.0 : 20.0;
          final occasionWidth = portrait && constraints.maxWidth < 520
              ? 112.0
              : 246.0;
          final budget = _BudgetSummary(
            spent: spent,
            left: left,
            progress: progress,
          );
          final rack = LayoutBuilder(
            builder: (_, rackConstraints) {
              final columns = fourAcross
                  ? (rackConstraints.maxWidth / 105).floor().clamp(1, 4)
                  : (rackConstraints.maxWidth / 140).floor().clamp(1, 2);
              final cardWidth =
                  (rackConstraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final piece in pieces)
                    SizedBox(
                      width: cardWidth,
                      child: _PieceCard(piece: piece, compact: fourAcross),
                    ),
                ],
              );
            },
          );
          return Padding(
            padding: EdgeInsets.all(innerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fourAcross)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dressing room',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              brief,
                              maxLines: portrait ? 2 : null,
                              overflow: portrait
                                  ? TextOverflow.ellipsis
                                  : TextOverflow.clip,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xff71717a)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _OccasionTiles(width: occasionWidth, height: 44),
                    ],
                  )
                else ...[
                  Text(
                    'Dressing room',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  const _OccasionTiles(width: double.infinity, height: 60),
                  const SizedBox(height: 12),
                  Text(
                    brief,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xff71717a)),
                  ),
                ],
                if (planCaption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    planCaption,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 14),
                if (progress == 0) ...[
                  budget,
                  const SizedBox(height: 14),
                  rack,
                ] else ...[
                  rack,
                  const SizedBox(height: 14),
                  budget,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OccasionTiles extends StatelessWidget {
  const _OccasionTiles({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tileWidth = width == double.infinity ? null : width;
    return SizedBox(
      width: tileWidth,
      height: height,
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff8c7359), Color(0xff4d3d33)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff593329), Color(0xff1f1414)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({
    required this.spent,
    required this.left,
    required this.progress,
  });

  final String spent;
  final String left;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: [
            Text(spent, style: Theme.of(context).textTheme.labelSmall),
            Text(
              left,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: const Color(0xff71717a)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: const Color(0xffe4e4e7),
            color: const Color(0xff18181b),
          ),
        ),
      ],
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.piece, required this.compact});

  final _PieceData piece;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final filled = piece.name.isNotEmpty;
    final thumbHeight = switch (piece.category) {
      ProductCategory.dress => compact ? 118.0 : 200.0,
      ProductCategory.layer ||
      ProductCategory.top ||
      ProductCategory.bottom => compact ? 92.0 : 132.0,
      ProductCategory.shoes ||
      ProductCategory.bag ||
      ProductCategory.accessory => compact ? 76.0 : 100.0,
    };
    final isChoosing =
        piece.state == 'Next' || piece.state == 'Choosing on the left';
    final labelColor = filled || isChoosing
        ? const Color(0xff18181b)
        : const Color(0xff71717a);
    return Column(
      key: ValueKey('dressing-slot-${piece.category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: thumbHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: filled ? Colors.white : _colorFromHex(piece.swatch),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChoosing
                  ? const Color(0xff18181b)
                  : filled
                  ? Colors.transparent
                  : const Color(0xffe4e4e7),
              width: isChoosing ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (filled)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _productImage(piece.imageAsset, piece.swatch),
                  ),
                ),
              if (isChoosing)
                Positioned(
                  left: 7,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff18181b),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Choosing now',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          filled ? piece.name : piece.label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: labelColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          filled
              ? piece.meta
              : isChoosing
              ? piece.meta
              : 'Not yet',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: const Color(0xff71717a)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
