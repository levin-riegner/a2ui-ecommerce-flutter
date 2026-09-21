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
      'action': A2uiSchemas.action(),
    },
    required: ['options', 'action'],
  ),
  widgetBuilder: (context) {
    final data = _map(context.data);
    final options =
        (data['options'] as List<Object?>?)
            ?.map((option) => option.toString())
            .toList(growable: false) ??
        const <String>[];
    final selected = data['selected']?.toString();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Semantics(
            button: true,
            selected: option == selected,
            label: option,
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () =>
                  _dispatchChoiceGroupAction(context, data['action'], option),
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
              builder: (_, swatch) => InkWell(
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
                      final imageWidth = constraints.maxWidth < 440
                          ? 104.0
                          : 120.0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: imageWidth,
                            height: 76,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _colorFromHex(swatch),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        tag ?? '',
                                        style: Theme.of(buildContext)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.checkroom_outlined,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 76,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Shoes',
                                        style: Theme.of(buildContext)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xffa1a1aa),
                                            ),
                                      ),
                                      Text(
                                        'Choose this',
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
      'dressName': A2uiSchemas.stringReference(),
      'dressMeta': A2uiSchemas.stringReference(),
      'dressSwatch': A2uiSchemas.stringReference(),
      'layerName': A2uiSchemas.stringReference(),
      'layerMeta': A2uiSchemas.stringReference(),
      'layerSwatch': A2uiSchemas.stringReference(),
      'shoesName': A2uiSchemas.stringReference(),
      'shoesMeta': A2uiSchemas.stringReference(),
      'shoesSwatch': A2uiSchemas.stringReference(),
      'bagName': A2uiSchemas.stringReference(),
      'bagMeta': A2uiSchemas.stringReference(),
      'bagSwatch': A2uiSchemas.stringReference(),
    },
    required: [
      'title',
      'brief',
      'spent',
      'left',
      'progress',
      'dressName',
      'dressMeta',
      'dressSwatch',
      'layerName',
      'layerMeta',
      'layerSwatch',
      'shoesName',
      'shoesMeta',
      'shoesSwatch',
      'bagName',
      'bagMeta',
      'bagSwatch',
    ],
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
      value: data['title'],
      builder: (_, title) => BoundString(
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
                value: data['dressName'],
                builder: (_, dressName) => BoundString(
                  dataContext: context.dataContext,
                  value: data['dressMeta'],
                  builder: (_, dressMeta) => BoundString(
                    dataContext: context.dataContext,
                    value: data['dressSwatch'],
                    builder: (_, dressSwatch) => BoundString(
                      dataContext: context.dataContext,
                      value: data['layerName'],
                      builder: (_, layerName) => BoundString(
                        dataContext: context.dataContext,
                        value: data['layerMeta'],
                        builder: (_, layerMeta) => BoundString(
                          dataContext: context.dataContext,
                          value: data['layerSwatch'],
                          builder: (_, layerSwatch) => BoundString(
                            dataContext: context.dataContext,
                            value: data['shoesName'],
                            builder: (_, shoesName) => BoundString(
                              dataContext: context.dataContext,
                              value: data['shoesMeta'],
                              builder: (_, shoesMeta) => BoundString(
                                dataContext: context.dataContext,
                                value: data['shoesSwatch'],
                                builder: (_, shoesSwatch) => BoundString(
                                  dataContext: context.dataContext,
                                  value: data['bagName'],
                                  builder: (_, bagName) => BoundString(
                                    dataContext: context.dataContext,
                                    value: data['bagMeta'],
                                    builder: (_, bagMeta) => BoundString(
                                      dataContext: context.dataContext,
                                      value: data['bagSwatch'],
                                      builder: (_, bagSwatch) => _DressingRoom(
                                        title: title ?? '',
                                        brief: brief ?? '',
                                        spent: spent ?? '',
                                        left: left ?? '',
                                        progress: progress?.toDouble() ?? 0,
                                        pieces: [
                                          _PieceData(
                                            ProductCategory.dress,
                                            'A dress',
                                            dressName ?? '',
                                            dressMeta ?? '',
                                            dressSwatch,
                                            dressName?.isNotEmpty == true
                                                ? 'Filled'
                                                : 'Next',
                                          ),
                                          _PieceData(
                                            ProductCategory.layer,
                                            'A layer over it',
                                            layerName ?? '',
                                            layerMeta ?? '',
                                            layerSwatch,
                                            layerName?.isNotEmpty == true
                                                ? 'Filled'
                                                : 'Empty',
                                          ),
                                          _PieceData(
                                            ProductCategory.shoes,
                                            'Shoes',
                                            shoesName ?? '',
                                            shoesMeta ?? '',
                                            shoesSwatch,
                                            shoesName?.isNotEmpty == true
                                                ? 'Filled'
                                                : 'Choosing on the left',
                                          ),
                                          _PieceData(
                                            ProductCategory.bag,
                                            'A bag',
                                            bagName ?? '',
                                            bagMeta ?? '',
                                            bagSwatch,
                                            bagName?.isNotEmpty == true
                                                ? 'Filled'
                                                : 'Empty',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieceData {
  const _PieceData(
    this.category,
    this.label,
    this.name,
    this.meta,
    this.swatch,
    this.state,
  );

  final ProductCategory category;
  final String label;
  final String name;
  final String meta;
  final String? swatch;
  final String state;
}

class _DressingRoom extends StatelessWidget {
  const _DressingRoom({
    required this.title,
    required this.brief,
    required this.spent,
    required this.left,
    required this.progress,
    required this.pieces,
  });

  final String title;
  final String brief;
  final String spent;
  final String left;
  final double progress;
  final List<_PieceData> pieces;

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
          final rack = fourAcross
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < pieces.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _PieceCard(piece: pieces[index], compact: true),
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PieceCard(piece: pieces.first, compact: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _PieceCard(piece: pieces[1], compact: false),
                          const SizedBox(height: 10),
                          _PieceCard(piece: pieces[2], compact: false),
                          const SizedBox(height: 10),
                          _PieceCard(piece: pieces[3], compact: false),
                        ],
                      ),
                    ),
                  ],
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
      ProductCategory.layer => compact ? 72.0 : 90.0,
      ProductCategory.shoes || ProductCategory.bag => compact ? 52.0 : 64.0,
    };
    final isChoosing = piece.state == 'Choosing on the left';
    final labelColor = filled || isChoosing
        ? const Color(0xff18181b)
        : const Color(0xff71717a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: thumbHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _colorFromHex(piece.swatch),
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
