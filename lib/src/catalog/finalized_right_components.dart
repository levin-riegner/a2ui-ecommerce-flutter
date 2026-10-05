import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'commerce_components.dart';
import 'commerce_widgets.dart' as legacy;
import 'finalized_shared_components.dart' show FinalizedQuantityStepper;

const _hangerLabels = {
  'dress': 'A dress',
  'top': 'A top',
  'bottom': 'Trousers',
  'layer': 'A layer over it',
  'shoes': 'Shoes',
  'bag': 'A bag',
};
const _hangerNames = {
  'dress': 'Indra Long Dress',
  'top': 'Silk Camp Shirt',
  'bottom': 'Wide-Leg Wool Trouser',
  'layer': 'Wool Cape',
  'shoes': 'Satin Pointed Pump',
  'bag': 'Le Petit Bambino',
};
const _hangerMeta = {
  'dress': 'Zimmermann · €874',
  'top': 'Equipment · €290',
  'bottom': 'The Row · €1,090',
  'layer': 'Max Mara · €1,150',
  'shoes': 'Manolo Blahnik · €545',
  'bag': 'Jacquemus · €425',
};

const _hangerHeights = <String, double>{
  'dress': 200,
  'top': 100,
  'bottom': 130,
  'layer': 90,
  'shoes': 64,
  'bag': 64,
};
const _hangerGlyphSizes = <String, double>{
  'dress': 80,
  'top': 70,
  'bottom': 80,
  'layer': 63,
  'shoes': 44.8,
  'bag': 44.8,
};

/// Finalized dressing-room items. Replace the legacy PieceSlot entry
/// when registering this list; do not register both entries with the same name.
final List<CatalogItem> finalizedRightItems = [
  finalizedPieceSlotCatalogItem,
  finalizedDressingRoomCatalogItem,
  for (final spec in _rightSpecs) _rightCatalogItem(spec),
];

/// Finalized hangers for all six verified categories. Category-less legacy data
/// intentionally retains the original presentation.
class FinalizedPieceSlot extends StatelessWidget {
  const FinalizedPieceSlot({
    super.key,
    required this.label,
    required this.meta,
    required this.state,
    this.category = '',
    this.name = '',
    this.swatch,
    this.imageAsset,
    this.onChange,
    this.compactHorizontal = false,
  });

  final String label;
  final String meta;
  final String state;
  final String category;
  final String name;
  final String? swatch;
  final String? imageAsset;
  final VoidCallback? onChange;
  final bool compactHorizontal;

  @override
  Widget build(BuildContext context) {
    if (CommerceDressingRoomStyle.maybeOf(context)?.dark == true) {
      return _FinalizedDarkPieceSlot(slot: this);
    }
    final normalized = category.toLowerCase();
    if (!_hangerHeights.containsKey(normalized)) {
      return CommercePieceSlot(
        label: label,
        meta: meta,
        state: state,
        swatch: swatch,
      );
    }
    final filled = state == 'Filled';
    final next = state == 'Next';
    final largeBadge = MediaQuery.textScalerOf(context).scale(10) > 15;
    final approvedImage =
        imageAsset != null &&
        RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
            .hasMatch(imageAsset!);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _hangerHeights[normalized],
          child: CustomPaint(
            foregroundPainter: filled ? null : _HangerOutline(next: next),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: filled
                    ? commerceColorFromHex(
                        swatch,
                        fallback: const Color(0xffd9d4ca),
                      )
                    : next
                    ? Colors.white
                    : const Color(0xfff4f4f5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (filled)
                      if (approvedImage)
                        CommerceProductImage(
                          imageAsset: imageAsset,
                          swatch: swatch,
                        )
                      else
                        Center(
                          child: SizedBox.square(
                            dimension: _hangerGlyphSizes[normalized],
                            child: FittedBox(
                              child: SvgPicture.asset(
                                'assets/icons/finalized_right/$normalized.svg',
                              ),
                            ),
                          ),
                        ),
                    if (next && !largeBadge)
                      Positioned(
                        top: 6.5,
                        left: 6.5,
                        right: 6.5,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff18181b),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Choosing now',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (next && largeBadge) ...[
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff18181b),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Choosing now',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          filled && name.isNotEmpty ? name : label,
          style: textTheme.labelMedium?.copyWith(
            fontSize: 13,
            fontFamily: 'Inter',
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
            color: filled || next
                ? const Color(0xff18181b)
                : const Color(0xff71717a),
          ),
        ),
        const SizedBox(height: 6),
        if (filled)
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText =
                  MediaQuery.textScalerOf(context).scale(11) > 16.5;
              final details = Text(
                meta,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: const Color(0xff71717a),
                ),
              );
              final change = TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  foregroundColor: const Color(0xff18181b),
                ),
                child: const Text('Change', style: TextStyle(fontSize: 11)),
              );
              return largeText || constraints.maxWidth < 160
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [details, change],
                    )
                  : Row(
                      children: [
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        change,
                      ],
                    );
            },
          )
        else
          Text(
            next ? 'Choosing on the left' : 'Not yet',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: const Color(0xff71717a),
            ),
          ),
      ],
    );
  }
}

class _HangerOutline extends CustomPainter {
  const _HangerOutline({required this.next});
  final bool next;
  @override
  void paint(Canvas canvas, Size size) {
    final width = next ? 1.5 : 1.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset(width / 2, width / 2) &
              Size(
                (size.width - width).clamp(0, double.infinity),
                (size.height - width).clamp(0, double.infinity),
              ),
          const Radius.circular(12),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = next ? const Color(0xff18181b) : const Color(0xffe4e4e7);
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 6).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HangerOutline oldDelegate) => next != oldDelegate.next;
}

final finalizedPieceSlotCatalogItem = CatalogItem(
  name: 'PieceSlot',
  dataSchema: S.object(
    description:
        'A finalized dressing-room hanger. All six garment categories are verified. '
        'Empty is still to find; Next is being chosen; Filled shows a product. '
        'A filled Change action emits a host event for Quick Adjust. '
        'Category-less legacy payloads retain the original presentation.',
    properties: {
      for (final key in [
        'label',
        'meta',
        'state',
        'swatch',
        'category',
        'name',
        'imageAsset',
      ])
        key: A2uiSchemas.stringReference(),
      'changeAction': A2uiSchemas.action(),
    },
    required: ['label', 'meta', 'state', 'swatch'],
  ),
  exampleData: [
    for (final category in ['Dress', 'Top', 'Bottom', 'Layer', 'Shoes', 'Bag'])
      for (final state in ['Empty', 'Next', 'Filled'])
        () => jsonEncode([
          {
            'id': 'root',
            'component': 'PieceSlot',
            'category': category,
            'label': _hangerLabels[category.toLowerCase()],
            'meta': _hangerMeta[category.toLowerCase()],
            'state': state,
            'swatch': '#d9d4ca',
            'name': _hangerNames[category.toLowerCase()],
            'changeAction': {
              'event': {
                'name': 'adjust_piece',
                'context': {'category': category.toLowerCase()},
              },
            },
          },
        ]),
  ],
  widgetBuilder: (context) => _PieceSlotBindings(
    itemContext: context,
    data: Map<String, Object?>.from(context.data as Map),
  ),
);

class _PieceSlotBindings extends StatelessWidget {
  const _PieceSlotBindings({required this.itemContext, required this.data});
  final CatalogItemContext itemContext;
  final Map<String, Object?> data;
  @override
  Widget build(BuildContext context) {
    const fields = [
      'label',
      'meta',
      'state',
      'swatch',
      'category',
      'name',
      'imageAsset',
    ];
    Widget bind(int index, Map<String, String> values) {
      if (index == fields.length) {
        final action = data['changeAction'];
        final event = action is Map ? action['event'] : null;
        final enabled =
            event is Map &&
            event['name'] is String &&
            (event['name'] as String).isNotEmpty;
        return FinalizedPieceSlot(
          label: values['label']!,
          meta: values['meta']!,
          state: values['state']!,
          swatch: values['swatch'],
          category: values['category']!,
          name: values['name']!,
          imageAsset: values['imageAsset'],
          onChange: enabled
              ? () async {
                  final definition = event['context'];
                  final resolved = definition is Map
                      ? await resolveContext(
                          itemContext.dataContext,
                          Map<String, Object?>.from(definition),
                        )
                      : <String, Object?>{};
                  itemContext.dispatchEvent(
                    UserActionEvent(
                      name: event['name'] as String,
                      sourceComponentId: itemContext.id,
                      context: resolved,
                    ),
                  );
                }
              : null,
        );
      }
      final field = fields[index];
      return BoundString(
        dataContext: itemContext.dataContext,
        value: data[field] ?? '',
        builder: (_, value) => bind(index + 1, {...values, field: value ?? ''}),
      );
    }

    return bind(0, {});
  }
}

typedef FinalizedRightAction = void Function(
  String actionKey,
  Map<String, Object?> context,
);

/// Host-fed finalized right-panel presentation. It never requests a backend.
class FinalizedRightComponent extends StatelessWidget {
  const FinalizedRightComponent({
    super.key,
    required this.component,
    required this.data,
    this.onAction,
  });
  final String component;
  final Map<String, Object?> data;
  final FinalizedRightAction? onAction;
  String text(String key) => data[key]?.toString() ?? '';
  double number(String key) => (data[key] as num?)?.toDouble() ?? 0;
  List<Map<String, Object?>> rows(String key) => [
    for (final row in data[key] as List? ?? [])
      if (row is Map) Map<String, Object?>.from(row),
  ];
  VoidCallback? action(String key, [Map<String, Object?> extra = const {}]) {
    final definition = data[key];
    final event = definition is Map ? definition['event'] : null;
    return onAction != null &&
            event is Map &&
            event['name'] is String &&
            (event['name'] as String).isNotEmpty
        ? () => onAction!(key, extra)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    switch (component) {
      case 'BudgetMeter':
        final spent = number('spent');
        final budget = number('budget');
        final over = spent + number('proposedSpend') > budget && budget > 0;
        return Semantics(
          label: over ? 'Over budget' : 'Outfit budget',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _rightText(
                    context,
                    '€${spent.toStringAsFixed(0)} spent · ${number('pieceCount').toInt()} of ${number('totalPieces').toInt()}',
                    size: 16,
                  ),
                  _rightText(
                    context,
                    '€${(budget - spent).toStringAsFixed(0)} left',
                    size: 16,
                    muted: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: budget > 0 ? (spent / budget).clamp(0, 1) : 0,
                  minHeight: 6,
                  color: over
                      ? const Color(0xffc9a227)
                      : const Color(0xff18181b),
                  backgroundColor: const Color(0xffe4e4e7),
                ),
              ),
              if (over)
                _rightText(context, 'Over budget', size: 12, muted: true),
            ],
          ),
        );
      case 'AddToBagButton':
        final added = text('state') == 'Added';
        final label = text('label').isNotEmpty
            ? text('label')
            : added
            ? 'Added to your bag · ${number('pieceCount').toInt()} items'
            : text('state') == 'Partial'
            ? 'Add the ${number('pieceCount').toInt()} piece so far · ${text('total')}'
            : 'Add the look to your bag · ${text('total')}';
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: TextButton(
            onPressed: added ? null : action('action'),
            style: TextButton.styleFrom(
              backgroundColor: added ? const Color(0xfff4f4f5) : Colors.white,
              foregroundColor: const Color(0xff18181b),
              disabledForegroundColor: const Color(0xff18181b),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                _rightIcon(added ? 'check' : 'bag-outline'),
                _rightText(context, label, size: 16),
              ],
            ),
          ),
        );
      case 'TypicalWeather':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _rightText(
                    context,
                    text('title'),
                    size: 13,
                    inter: true,
                    medium: true,
                  ),
                  _rightText(
                    context,
                    text('summary'),
                    size: 12,
                    inter: true,
                    muted: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final large =
                      MediaQuery.textScalerOf(context).scale(11) > 16.5;
                  final count = large ? 2 : 5;
                  final width =
                      (constraints.maxWidth - (count - 1) * 6) / count;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final day in rows('days'))
                        SizedBox(
                          width: width,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: day['highlight'] == true
                                  ? const Color(0xfff4f4f5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _rightText(
                                  context,
                                  day['label']?.toString() ?? '',
                                  size: 11,
                                  inter: true,
                                  muted: true,
                                ),
                                const SizedBox(height: 3),
                                if ([
                                  'day',
                                  'evening',
                                  'rain',
                                ].contains(day['icon']))
                                  _rightIcon('weather-${day['icon']}'),
                                const SizedBox(height: 3),
                                _rightText(
                                  context,
                                  day['value']?.toString() ?? '',
                                  size: 13,
                                  inter: true,
                                  medium: true,
                                ),
                                const SizedBox(height: 3),
                                _rightText(
                                  context,
                                  day['detail']?.toString() ?? '',
                                  size: 10,
                                  inter: true,
                                  muted: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _rightText(
                context,
                text('disclaimer'),
                size: 11,
                inter: true,
                muted: true,
              ),
            ],
          ),
        );
      case 'MapCard':
        return FinalizedMapCard(
          label: text('label'),
          mapAsset: text('mapAsset'),
          onPressed: action('action'),
        );
      case 'ContextStrip':
        return _contextStrip(context);
      case 'Look':
        return FinalizedLook(base: text('base'), pieces: rows('pieces'));
      case 'LookSummary':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rightText(context, text('name'), size: 16),
                      _rightText(context, text('meta'), size: 12, muted: true),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final piece in rows('pieces'))
                        _rightThumb(
                          piece,
                          width: 28,
                          height: 36,
                          glyphSize: 18,
                          radius: 5,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _rightLink(context, 'Save look', action('saveAction')),
                  _rightLink(
                    context,
                    'Share',
                    action('shareAction'),
                    muted: true,
                  ),
                  _rightLink(
                    context,
                    'Start over',
                    action('resetAction'),
                    muted: true,
                  ),
                ],
              ),
            ],
          ),
        );
      case 'DeliveryEstimate':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rightText(context, text('headline'), size: 16),
              const SizedBox(height: 6),
              _rightText(context, text('detail'), size: 12, muted: true),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in rows('pieces'))
                    Semantics(
                      label: '${item['label']}: ${item['status']}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xfff4f4f5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item['status'] == 'late'
                                    ? const Color(0xffc9a227)
                                    : item['status'] == 'unknown'
                                    ? const Color(0xffa1a1aa)
                                    : const Color(0xff2e7d4f),
                              ),
                            ),
                            _rightText(
                              context,
                              item['label']?.toString() ?? '',
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      case 'SavedLooksRail':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _rightText(
              context,
              text('title').isEmpty ? 'Your looks' : text('title'),
              size: 16,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final options = rows('looks');
                final width = MediaQuery.textScalerOf(context).scale(12) > 18
                    ? 140.0
                    : (constraints.maxWidth - 20) / 3;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < options.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i == options.length - 1 ? 0 : 10,
                          ),
                          child: SizedBox(
                            width: width,
                            child: Semantics(
                              selected: options[i]['id'] == text('selectedId'),
                              button: true,
                              child: InkWell(
                                onTap: action('action', {
                                  'lookId': options[i]['id'],
                                }),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              options[i]['id'] ==
                                                  text('selectedId')
                                              ? const Color(0xff18181b)
                                              : const Color(0xffe4e4e7),
                                          width:
                                              options[i]['id'] ==
                                                  text('selectedId')
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      child: _rightThumb(
                                        options[i],
                                        height: 72,
                                        glyphSize: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _rightText(
                                      context,
                                      options[i]['label']?.toString() ?? '',
                                      size: 12,
                                      muted:
                                          options[i]['id'] !=
                                          text('selectedId'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      case 'FitNotes':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rightText(
                context,
                text('title').isEmpty ? 'Sizes' : text('title'),
                size: 16,
              ),
              for (final piece in rows('pieces'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rightText(
                              context,
                              piece['name']?.toString() ?? '',
                              size: 14,
                            ),
                            _rightText(
                              context,
                              piece['note']?.toString() ?? '',
                              size: 12,
                              muted: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: action('action', {
                          'productId': piece['id'],
                          'size': piece['size'],
                        }),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xfff4f4f5),
                          shape: const StadiumBorder(),
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(piece['size']?.toString() ?? ''),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'AlternativePiece':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rightText(context, text('title'), size: 16),
              const SizedBox(height: 8),
              _rightProductRow(
                context,
                data,
                actionLabel: 'Swap',
                onPressed: action('action'),
                imageWidth: 44,
                imageHeight: 52,
              ),
            ],
          ),
        );
      case 'IfWeatherTurns':
        return _RightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rightText(
                context,
                text('verdict'),
                size: 13,
                inter: true,
                medium: true,
              ),
              const SizedBox(height: 10),
              _rightText(
                context,
                text('condition'),
                size: 12,
                inter: true,
                muted: true,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      MediaQuery.textScalerOf(context).scale(12) > 18 ||
                          constraints.maxWidth < 300
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in rows('products'))
                        SizedBox(
                          width: width,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xfff4f4f5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _rightProductRow(
                              context,
                              item,
                              actionLabel: '+',
                              onPressed: action('action', {
                                'productId': item['id'],
                              }),
                              imageWidth: 40,
                              imageHeight: 48,
                              inter: true,
                              glyphSize: 30,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      case 'BagPreview':
        return FinalizedBagPreview(data: data, onAction: onAction);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _contextPhoto(int index, bool known) {
    final asset = text(index == 0 ? 'photoA' : 'photoB');
    final allowed = RegExp(
      r'^assets/images/(occasions|finalized_left|finalized_right)/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$',
    ).hasMatch(asset);
    return allowed
        ? Image.asset(asset, fit: BoxFit.cover)
        : SvgPicture.asset(
            'assets/icons/finalized_right/context-${index == 0 ? 'place' : 'venue'}-${known ? 'known' : 'unknown'}.svg',
            fit: BoxFit.cover,
          );
  }

  Widget _contextStrip(BuildContext context) {
    final known = text('location') == 'Known';
    final large = MediaQuery.textScalerOf(context).scale(13) > 19.5;
    final photos = [
      for (var index = 0; index < 2; index++)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(height: 48, child: _contextPhoto(index, known)),
        ),
    ];
    if (!known) {
      return Row(
        children: [
          Expanded(child: photos[0]),
          const SizedBox(width: 8),
          Expanded(child: photos[1]),
        ],
      );
    }
    final map = FinalizedMapCard(
      label: text('venue'),
      mini: true,
      onPressed: action('mapAction'),
    );
    final weather = InkWell(
      onTap: action('weatherAction'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffe4e4e7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rightText(context, 'Usually', size: 9, inter: true, muted: true),
            _rightText(
              context,
              text('temperatures'),
              size: 13,
              inter: true,
              medium: true,
            ),
            _rightText(
              context,
              text('rain'),
              size: 9,
              inter: true,
              muted: true,
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (large ? 8 : 42)) / (large ? 2 : 4);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < 4; index++)
              SizedBox(
                width: width + (!large && index == 3 ? 18 : 0),
                child: [...photos, map, weather][index],
              ),
          ],
        );
      },
    );
  }
}

Widget _rightText(
  BuildContext context,
  String value, {
  double size = 14,
  bool muted = false,
  bool medium = false,
  bool inter = false,
}) => Text(
  value,
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontFamily: inter ? 'Inter' : 'Jost',
    fontSize: size,
    fontWeight: medium ? FontWeight.w500 : FontWeight.w400,
    color: muted ? const Color(0xff71717a) : const Color(0xff18181b),
    letterSpacing: 0,
    height: 1.25,
  ),
);
Widget _rightIcon(String name) =>
    SvgPicture.asset('assets/icons/finalized_right/$name.svg');
Widget _rightLink(
  BuildContext context,
  String label,
  VoidCallback? action, {
  bool muted = false,
}) => TextButton(
  onPressed: action,
  style: TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(48, 48),
    foregroundColor: muted ? const Color(0xff71717a) : const Color(0xff18181b),
  ),
  child: Text(label),
);

class _RightCard extends StatelessWidget {
  const _RightCard({required this.child, this.padding = 14, this.radius = 12});
  final Widget child;
  final double padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xffe4e4e7)),
    ),
    child: child,
  );
}

Widget _rightThumb(
  Map<String, Object?> item, {
  double? width,
  double height = 56,
  double glyphSize = 28,
  double radius = 8,
}) {
  final category = item['category']?.toString().toLowerCase() ?? '';
  final image = item['imageAsset']?.toString();
  final approved =
      image != null &&
      RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
          .hasMatch(image);
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: commerceColorFromHex(
          item['swatch'],
          fallback: const Color(0xffd9d4ca),
        ),
        child: approved
            ? CommerceProductImage(
                imageAsset: image,
                swatch: item['swatch']?.toString(),
              )
            : _hangerHeights.containsKey(category)
            ? Center(
                child: SizedBox.square(
                  dimension: glyphSize,
                  child: FittedBox(child: _rightIcon(category)),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
}

Widget _rightProductRow(
  BuildContext context,
  Map<String, Object?> item, {
  required String actionLabel,
  VoidCallback? onPressed,
  double imageWidth = 56,
  double imageHeight = 56,
  double glyphSize = 28,
  bool inter = false,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rightText(
          context,
          item['name']?.toString() ?? '',
          size: inter ? 12 : 14,
          inter: inter,
        ),
        _rightText(
          context,
          item['meta']?.toString() ?? '',
          size: inter ? 11 : 12,
          muted: true,
          inter: inter,
        ),
      ],
    );
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: actionLabel == 'Swap' ? const Color(0xff18181b) : null,
        foregroundColor: actionLabel == 'Swap'
            ? Colors.white
            : const Color(0xff18181b),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
      ),
      child: Text(actionLabel),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rightThumb(
          item,
          width: imageWidth,
          height: imageHeight,
          glyphSize: glyphSize,
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              MediaQuery.textScalerOf(context).scale(12) > 18 ||
                  constraints.maxWidth < 200
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, button],
                )
              : Row(
                  children: [
                    Expanded(child: details),
                    button,
                  ],
                ),
        ),
      ],
    );
  },
);

class FinalizedLook extends StatelessWidget {
  const FinalizedLook({super.key, required this.base, this.pieces = const []});
  final String base;
  final List<Map<String, Object?>> pieces;
  Map<String, Object?> piece(String category, String swatch) =>
      pieces.firstWhere(
        (p) => p['category']?.toString().toLowerCase() == category,
        orElse: () => {'category': category, 'swatch': swatch},
      );
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 248 / 240,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxHeight / 240;
        Widget tile(String category, double h, String swatch, double glyph) =>
            _rightThumb(
              piece(category, swatch),
              height: h * scale,
              glyphSize: glyph * scale,
              radius: 10,
            );
        return Row(
          children: [
            Expanded(
              child: base == 'Separates'
                  ? Column(
                      children: [
                        tile('top', 96, '#3c3c3f', 70),
                        SizedBox(height: 8 * scale),
                        tile('bottom', 136, '#5b5a57', 70),
                      ],
                    )
                  : tile('dress', 240, '#b8a98e', 96),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Column(
                children: [
                  tile('layer', 78, '#3e3a2c', 48),
                  SizedBox(height: 8 * scale),
                  tile('shoes', 64, '#2b2a28', 50),
                  SizedBox(height: 8 * scale),
                  tile('bag', 82, '#2a211c', 50),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class FinalizedBagPreview extends StatefulWidget {
  const FinalizedBagPreview({super.key, required this.data, this.onAction});
  final Map<String, Object?> data;
  final FinalizedRightAction? onAction;
  @override
  State<FinalizedBagPreview> createState() => _FinalizedBagPreviewState();
}

class _FinalizedBagPreviewState extends State<FinalizedBagPreview> {
  late List<Map<String, Object?>> items;
  void load() {
    items = [
      for (final row in widget.data['items'] as List? ?? [])
        if (row is Map) Map<String, Object?>.from(row),
    ];
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(FinalizedBagPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.data['items']) !=
        jsonEncode(widget.data['items'])) {
      load();
    }
  }

  int quantity(Map<String, Object?> item) =>
      (item['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
  VoidCallback? callback(
    String key,
    Map<String, Object?> extra,
    VoidCallback? update,
  ) {
    final action = widget.data[key];
    final event = action is Map ? action['event'] : null;
    if (widget.onAction == null ||
        event is! Map ||
        event['name'] is! String ||
        (event['name'] as String).isEmpty) {
      return null;
    }
    return () {
      if (update != null) setState(update);
      widget.onAction!(key, extra);
    };
  }

  VoidCallback? remove(BuildContext context, Map<String, Object?> item) {
    final removeCallback = callback('removeAction', {
      'productId': item['id'],
    }, () => items.remove(item));
    if (removeCallback == null) return null;
    return () {
      final index = items.indexOf(item);
      removeCallback();
      final undo = callback('restoreAction', {
        'productId': item['id'],
        'quantity': quantity(item),
      }, () => items.insert(index.clamp(0, items.length), item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['name']} removed'),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(
      0,
      (n, item) =>
          n + ((item['unitPrice'] as num?)?.toDouble() ?? 0) * quantity(item),
    );
    final count = items.fold<int>(0, (n, item) => n + quantity(item));
    return _RightCard(
      padding: 18,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _rightText(context, 'Your bag — $count items', size: 16),
              ),
              IconButton(
                tooltip: 'Close bag',
                onPressed: callback('closeAction', {}, null),
                icon: _rightIcon('close'),
              ),
            ],
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rightThumb(item, width: 56, height: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rightText(
                              context,
                              item['name']?.toString() ?? '',
                              size: 14,
                            ),
                            _rightText(
                              context,
                              item['meta']?.toString() ?? '',
                              size: 12,
                              muted: true,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove ${item['name']}',
                        onPressed: remove(context, item),
                        icon: _rightIcon('remove'),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: FinalizedQuantityStepper(
                          key: ValueKey('bag-quantity-${item['id']}'),
                          value: quantity(item),
                          max: 99,
                          onChanged:
                              callback('quantityAction', {}, null) == null
                              ? null
                              : (next) {
                                  callback('quantityAction', {
                                    'productId': item['id'],
                                    'quantity': next,
                                  }, () => item['quantity'] = next)!();
                                },
                          onRemove: remove(context, item),
                        ),
                      ),
                      _rightText(
                        context,
                        '€${(((item['unitPrice'] as num?)?.toDouble() ?? 0) * quantity(item)).toStringAsFixed(0)}',
                        size: 14,
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xffe4e4e7), height: 1),
                ],
              ),
            ),
          if (items.isEmpty)
            _rightText(context, 'Your bag is empty', size: 14, muted: true),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              _rightText(context, 'Subtotal', size: 16, muted: true),
              _rightText(context, '€${total.toStringAsFixed(0)}', size: 16),
            ],
          ),
          const SizedBox(height: 14),
          CommercePrimaryButton(
            label: 'Check out',
            onPressed: items.isEmpty
                ? null
                : callback('checkoutAction', {}, null),
          ),
          const SizedBox(height: 14),
          _rightLink(
            context,
            'Keep styling',
            callback('closeAction', {}, null),
            muted: true,
          ),
        ],
      ),
    );
  }
}

const _mapGeometry = <String, List<double>>{
  '53:2883': [0, 40, 351, 97.1043701171875],
  '53:2884': [40, 0, 10, 150],
  '53:2885': [120, 0, 37.7373046875, 150],
  '53:2886': [0, 95, 351, 55],
  '53:2887': [209.0943603515625, 0, 28.86181640625, 150],
  '53:2888': [300, 0, 12.9761962890625, 150],
  '53:2889': [0, 118, 351, 32],
  '53:2890': [163.5, 52, 16, 22],
  '53:3097': [0, 14, 77.25, 24.77703857421875],
  '53:3098': [22, 0, 12.340362548828125, 48],
  '53:3099': [46.41947937011719, 0, 8.573211669921875, 48],
  '53:3100': [0, 34, 77.25, 14],
  '53:3101': [33, 6, 14, 16],
};

/// The design's placeholder streets; a host can supply a bundled map snapshot.
/// Street/pin assets are exact read-only Figma exports, never a screen capture.
class FinalizedMapCard extends StatelessWidget {
  const FinalizedMapCard({
    super.key,
    required this.label,
    this.mapAsset = '',
    this.mini = false,
    this.onPressed,
  });
  final String label;
  final String mapAsset;
  final bool mini;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final w = mini ? 77.25 : 351.0;
    final h = mini ? 48.0 : 150.0;
    final approved = RegExp(
      r'^assets/images/finalized_right/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$',
    ).hasMatch(mapAsset);
    return Semantics(
      label: label.isEmpty ? 'Occasion map' : label,
      button: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(mini ? 8 : 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(mini ? 8 : 12),
          child: AspectRatio(
            aspectRatio: w / h,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xffedefea)),
                  if (approved)
                    Image.asset(mapAsset, fit: BoxFit.cover)
                  else
                    for (final entry in _mapGeometry.entries)
                      if (mini
                          ? !entry.key.startsWith('53:28')
                          : entry.key.startsWith('53:28'))
                        Positioned(
                          left: entry.value[0] / w * constraints.maxWidth,
                          top: entry.value[1] / h * constraints.maxHeight,
                          width: entry.value[2] / w * constraints.maxWidth,
                          height: entry.value[3] / h * constraints.maxHeight,
                          child: SvgPicture.asset(
                            'assets/icons/finalized_right/map-${entry.key.replaceAll(':', '-')}.svg',
                            fit: BoxFit.fill,
                          ),
                        ),
                  if (label.isNotEmpty)
                    Positioned(
                      left: mini ? 5 : 12,
                      bottom: mini ? 5 : 12,
                      right: 12,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: mini ? 5 : 10,
                            vertical: mini ? 2 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: mini ? 9 : 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xff18181b),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RightSpec {
  const _RightSpec(
    this.name,
    this.strings,
    this.numbers,
    this.lists,
    this.actions,
  );
  final String name;
  final List<String> strings, numbers, lists, actions;
}

const _rightSpecs = [
  _RightSpec(
    'BudgetMeter',
    [],
    ['spent', 'budget', 'pieceCount', 'totalPieces', 'proposedSpend'],
    [],
    [],
  ),
  _RightSpec(
    'AddToBagButton',
    ['state', 'label', 'total'],
    ['pieceCount'],
    [],
    ['action'],
  ),
  _RightSpec(
    'TypicalWeather',
    ['title', 'summary', 'disclaimer'],
    [],
    ['days'],
    [],
  ),
  _RightSpec('MapCard', ['label', 'mapAsset'], [], [], ['action']),
  _RightSpec(
    'ContextStrip',
    ['location', 'venue', 'temperatures', 'rain', 'photoA', 'photoB'],
    [],
    [],
    ['mapAction', 'weatherAction'],
  ),
  _RightSpec('Look', ['base'], [], ['pieces'], []),
  _RightSpec('LookSummary', ['name', 'meta'], [], ['pieces'], [
    'saveAction',
    'shareAction',
    'resetAction',
  ]),
  _RightSpec('DeliveryEstimate', ['headline', 'detail'], [], ['pieces'], []),
  _RightSpec('SavedLooksRail', ['title', 'selectedId'], [], ['looks'], [
    'action',
  ]),
  _RightSpec('FitNotes', ['title'], [], ['pieces'], ['action']),
  _RightSpec(
    'AlternativePiece',
    ['title', 'productId', 'category', 'name', 'meta', 'imageAsset', 'swatch'],
    [],
    [],
    ['action'],
  ),
  _RightSpec('IfWeatherTurns', ['verdict', 'condition'], [], ['products'], [
    'action',
  ]),
  _RightSpec(
    'BagPreview',
    [],
    [],
    ['items'],
    [
      'closeAction',
      'removeAction',
      'restoreAction',
      'quantityAction',
      'checkoutAction',
    ],
  ),
];

CatalogItem _rightCatalogItem(_RightSpec spec) => CatalogItem(
  name: spec.name,
  dataSchema: S.object(
    description:
        'Finalized Figma ${spec.name}. Host-provided data; all actions are explicit stable JSON events. Weather, delivery, venue and stock values must be supplied by the host.',
    properties: {
      for (final key in spec.strings) key: A2uiSchemas.stringReference(),
      for (final key in spec.numbers) key: A2uiSchemas.numberReference(),
      for (final key in spec.lists)
        key: A2uiSchemas.listOrReference(
          items: S.object(
            properties: {
              for (final field in [
                'id',
                'category',
                'label',
                'name',
                'meta',
                'imageAsset',
                'swatch',
                'note',
                'size',
                'status',
                'icon',
                'value',
                'detail',
              ])
                field: S.string(),
              'quantity': S.integer(minimum: 1, maximum: 99),
              'unitPrice': S.number(minimum: 0),
              'highlight': S.boolean(),
            },
          ),
        ),
      for (final key in spec.actions) key: A2uiSchemas.action(),
    },
  ),
  exampleData: [
    for (final fixture in finalizedRightFixtures.where(
      (f) => f['component'] == spec.name,
    ))
      () => jsonEncode([
        {...fixture, 'id': 'root'},
      ]),
  ],
  widgetBuilder: (context) => _RightBindings(itemContext: context, spec: spec),
);

class _RightBindings extends StatelessWidget {
  const _RightBindings({required this.itemContext, required this.spec});
  final CatalogItemContext itemContext;
  final _RightSpec spec;
  @override
  Widget build(BuildContext context) {
    final source = Map<String, Object?>.from(itemContext.data as Map);
    final keys = [...spec.strings, ...spec.numbers, ...spec.lists];
    Future<void> dispatch(String key, Map<String, Object?> extra) async {
      final a = source[key];
      final e = a is Map ? a['event'] : null;
      if (e is! Map || e['name'] is! String) return;
      final definition = e['context'];
      final resolved = definition is Map
          ? await resolveContext(
              itemContext.dataContext,
              Map<String, Object?>.from(definition),
            )
          : <String, Object?>{};
      itemContext.dispatchEvent(
        UserActionEvent(
          name: e['name'] as String,
          sourceComponentId: itemContext.id,
          context: {...resolved, ...extra},
        ),
      );
    }

    Widget bind(int index, Map<String, Object?> values) {
      if (index == keys.length) {
        return FinalizedRightComponent(
          component: spec.name,
          data: {...source, ...values},
          onAction: dispatch,
        );
      }
      final key = keys[index];
      final value = source[key];
      if (spec.strings.contains(key)) {
        return BoundString(
          dataContext: itemContext.dataContext,
          value: value ?? '',
          builder: (_, v) => bind(index + 1, {...values, key: v ?? ''}),
        );
      }
      if (spec.numbers.contains(key)) {
        return BoundNumber(
          dataContext: itemContext.dataContext,
          value: value ?? 0,
          builder: (_, v) => bind(index + 1, {...values, key: v ?? 0}),
        );
      }
      return BoundList(
        dataContext: itemContext.dataContext,
        value: value ?? const [],
        builder: (_, v) => bind(index + 1, {...values, key: v ?? const []}),
      );
    }

    return bind(0, {});
  }
}

Map<String, Object?> _rightEvent(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'event': {'name': name, 'context': context},
};
const _fixturePieces = [
  {
    'id': 'design-dress',
    'category': 'dress',
    'name': 'Indra Long Dress',
    'meta': 'Zimmermann · 38',
    'swatch': '#b8a98e',
    'unitPrice': 874,
    'quantity': 1,
  },
  {
    'id': 'design-shoes',
    'category': 'shoes',
    'name': 'Satin Pointed Pump',
    'meta': 'Manolo Blahnik · 39',
    'swatch': '#2b2a28',
    'unitPrice': 545,
    'quantity': 1,
  },
  {
    'id': 'design-layer',
    'category': 'layer',
    'name': 'Wool Cape',
    'meta': 'Max Mara · S',
    'swatch': '#5a4a3a',
    'unitPrice': 450,
    'quantity': 1,
  },
  {
    'id': 'design-bag',
    'category': 'bag',
    'name': 'Le Petit Bambino',
    'meta': 'Jacquemus',
    'swatch': '#2a211c',
    'unitPrice': 425,
    'quantity': 1,
  },
];

/// Literal v0.9 component definitions for native previews and catalog examples.
/// Prices/stock/weather are clearly marked design fixtures in the manifest.
final List<Map<String, Object?>> finalizedRightFixtures = [
  {
    'component': 'BudgetMeter',
    'spent': 874,
    'budget': 1500,
    'pieceCount': 1,
    'totalPieces': 4,
    'proposedSpend': 0,
  },
  for (final state in ['Default', 'Added', 'Partial'])
    {
      'component': 'AddToBagButton',
      'state': state,
      'pieceCount': state == 'Partial' ? 1 : 4,
      'total': state == 'Partial' ? '€874' : '€1,925',
      'action': _rightEvent('add_look_to_bag', {'lookId': 'design-paris'}),
    },
  {
    'component': 'TypicalWeather',
    'title': 'Paris, mid-October — usually',
    'summary': 'Evenings around 10°',
    'disclaimer': 'Based on past years, not a live forecast — I’ll check closer to the day.',
    'days': [
      {'label': 'Day', 'icon': 'day', 'value': '16°', 'detail': 'typical high'},
      {
        'label': 'Evening',
        'icon': 'evening',
        'value': '10°',
        'detail': 'typical low',
        'highlight': true,
      },
      {'label': 'Rain', 'icon': 'rain', 'value': '4 in 10', 'detail': 'days'},
      {'label': 'Wind', 'value': 'Light', 'detail': '8 km/h'},
      {'label': 'Sunset', 'value': '18:52', 'detail': 'on the 18th'},
    ],
  },
  {
    'component': 'MapCard',
    'label': 'Le Clarence · Paris 8e',
    'mapAsset': '',
    'action': _rightEvent('open_venue_map', {'venueId': 'design-clarence'}),
  },
  for (final location in ['Known', 'Unknown'])
    {
      'component': 'ContextStrip',
      'location': location,
      'venue': location == 'Known' ? 'Paris 8e' : '',
      'temperatures': '16° / 10°',
      'rain': 'Rain 4 in 10',
      'mapAction': _rightEvent('expand_map'),
      'weatherAction': _rightEvent('expand_weather'),
    },
  for (final base in ['Dress', 'Separates'])
    {'component': 'Look', 'base': base, 'pieces': _fixturePieces},
  {
    'component': 'LookSummary',
    'name': 'Paris anniversary',
    'meta': '4 pieces · €2,294 · saved 18 Sep',
    'pieces': _fixturePieces,
    'saveAction': _rightEvent('save_look', {'lookId': 'design-paris'}),
    'shareAction': _rightEvent('share_look', {'lookId': 'design-paris'}),
    'resetAction': _rightEvent('start_over'),
  },
  {
    'component': 'DeliveryEstimate',
    'headline': 'All 4 in stock · arrives Thu 16 Oct',
    'detail': 'Two days before the dinner. Free returns until 30 Oct.',
    'pieces': [
      {'label': 'Dress', 'status': 'on_time'},
      {'label': 'Shoes', 'status': 'on_time'},
      {'label': 'Cape · 3–5 days', 'status': 'late'},
      {'label': 'Bag', 'status': 'on_time'},
    ],
  },
  {
    'component': 'SavedLooksRail',
    'title': 'Your looks',
    'selectedId': 'design-paris',
    'looks': [
      {
        'id': 'design-paris',
        'label': 'Paris · 18 Oct',
        'category': 'dress',
        'swatch': '#b8a98e',
      },
      {
        'id': 'design-berlin',
        'label': 'Berlin · first day',
        'category': 'top',
        'swatch': '#3c3c3f',
      },
      {
        'id': 'design-cotswolds',
        'label': 'Cotswolds',
        'category': 'layer',
        'swatch': '#3e3a2c',
      },
    ],
    'action': _rightEvent('select_look'),
  },
  {
    'component': 'FitNotes',
    'title': 'Sizes',
    'pieces': [
      {
        'id': 'design-dress',
        'name': 'Indra Long Dress',
        'note': 'Runs long — you’re 168cm, hem will hit the ankle',
        'size': '38',
      },
      {
        'id': 'design-shoes',
        'name': 'Satin Pointed Pump',
        'note': 'True to size',
        'size': '39',
      },
      {
        'id': 'design-layer',
        'name': 'Wool Cape',
        'note': 'One size, generous',
        'size': 'S',
      },
    ],
    'action': _rightEvent('change_size'),
  },
  {
    'component': 'AlternativePiece',
    'title': 'If the cape is too much',
    'productId': 'design-alternative',
    'category': 'layer',
    'name': 'Tailored Wool Coat',
    'meta': 'Toteme · €690 · +€240',
    'swatch': '#8a8f86',
    'action': _rightEvent('swap_product', {
      'productId': 'design-alternative',
      'replaces': 'design-layer',
    }),
  },
  {
    'component': 'IfWeatherTurns',
    'verdict': 'Yes — the dress and the pumps work for 11° and a short walk.',
    'condition': 'If it turns colder or wet, add one of these:',
    'products': [
      {
        'id': 'design-layer',
        'category': 'layer',
        'name': 'Wool cape',
        'meta': '€450',
        'swatch': '#5a4a3a',
      },
      {
        'id': 'design-scarf',
        'category': 'accessory',
        'name': 'Silk scarf',
        'meta': '€390',
        'swatch': '#8a2e3b',
      },
    ],
    'action': _rightEvent('add_weather_piece'),
  },
  {
    'component': 'BagPreview',
    'items': _fixturePieces,
    'closeAction': _rightEvent('close_bag'),
    'quantityAction': _rightEvent('set_bag_quantity'),
    'removeAction': _rightEvent('remove_bag_product'),
    'restoreAction': _rightEvent('restore_bag_product'),
    'checkoutAction': _rightEvent('checkout_bag'),
  },
];

/// Production dressing room composes the same finalized hangers as the catalog.
/// Its host-owned slots, named legacy fields and state continue to bind in place.
final finalizedDressingRoomCatalogItem = CatalogItem(
  name: 'DressingRoom',
  dataSchema: legacy.dressingRoomCatalogItem.dataSchema,
  exampleData: [
    () => jsonEncode([
      {
        'id': 'root',
        'component': 'DressingRoom',
        'title': 'Dressing room',
        'brief': 'Paris anniversary · mid-October',
        'spent': '€874 spent · 1 of 4',
        'left': '€626 left',
        'progress': 874 / 1500,
        'planCaption': 'Dress · layer · shoes · bag',
        'slots': [
          for (final piece in _fixturePieces)
            {
              'category': piece['category'],
              'label': _hangerLabels[piece['category']],
              'name': piece['category'] == 'dress' ? piece['name'] : '',
              'meta': piece['category'] == 'dress'
                  ? 'Zimmermann · €874'
                  : 'Not yet',
              'swatch': piece['swatch'],
              'state': piece['category'] == 'dress'
                  ? 'Filled'
                  : piece['category'] == 'layer'
                  ? 'Next'
                  : 'Empty',
            },
        ],
      },
    ]),
  ],
  widgetBuilder: (context) => _FinalizedRoomBindings(itemContext: context),
);

class _FinalizedRoomBindings extends StatelessWidget {
  const _FinalizedRoomBindings({required this.itemContext});
  final CatalogItemContext itemContext;
  @override
  Widget build(BuildContext context) {
    final data = Map<String, Object?>.from(itemContext.data as Map);
    final fields = [
      'title',
      'brief',
      'spent',
      'left',
      'planCaption',
      if (!data.containsKey('slots'))
        for (final slot in ['dress', 'layer', 'shoes', 'bag'])
          for (final suffix in ['Name', 'Meta', 'Swatch', 'ImageAsset'])
            '$slot$suffix',
    ];
    Widget bind(int index, Map<String, String> values) {
      if (index < fields.length) {
        final key = fields[index];
        return BoundString(
          dataContext: itemContext.dataContext,
          value: data[key] ?? '',
          builder: (_, v) => bind(index + 1, {...values, key: v ?? ''}),
        );
      }
      Widget room(List<Object?> rows, double progress) =>
          _FinalizedDressingRoom(
            values: {
              ...values,
              if (!data.containsKey('slots')) 'title': 'Dressing room',
            },
            progress: progress,
            slots: [
              for (final row in rows)
                if (row is Map) Map<String, Object?>.from(row),
            ],
            onChange: (category) => itemContext.dispatchEvent(
              UserActionEvent(
                name: 'adjust_piece',
                sourceComponentId: itemContext.id,
                context: {'category': category},
              ),
            ),
          );
      return BoundNumber(
        dataContext: itemContext.dataContext,
        value: data['progress'] ?? 0,
        builder: (_, progress) {
          if (data.containsKey('slots')) {
            return BoundList(
              dataContext: itemContext.dataContext,
              value: data['slots'],
              builder: (_, rows) => room(rows ?? [], progress?.toDouble() ?? 0),
            );
          }
          final next = ['dress', 'layer', 'shoes', 'bag']
              .where(
                (s) =>
                    values['${s}Name']!.isEmpty &&
                    values['${s}Meta'] == 'Choosing on the left',
              )
              .firstOrNull;
          return room([
            for (final slot in ['dress', 'layer', 'shoes', 'bag'])
              {
                'category': slot,
                'label': _hangerLabels[slot],
                'name': values['${slot}Name'],
                'meta': values['${slot}Meta'],
                'swatch': values['${slot}Swatch'],
                'imageAsset': values['${slot}ImageAsset'],
                'state': values['${slot}Name']!.isNotEmpty
                    ? 'Filled'
                    : next == slot
                    ? 'Next'
                    : 'Empty',
              },
          ], progress?.toDouble() ?? 0);
        },
      );
    }

    return bind(0, {});
  }
}

class _FinalizedDressingRoom extends StatelessWidget {
  const _FinalizedDressingRoom({
    required this.values,
    required this.progress,
    required this.slots,
    required this.onChange,
  });
  final Map<String, String> values;
  final double progress;
  final List<Map<String, Object?>> slots;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    final dark = CommerceDressingRoomStyle.maybeOf(context)?.dark ?? false;
    Widget roomText(String value, {double size = 14, bool muted = false}) =>
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: size,
            color: dark
                ? (muted ? Colors.white60 : Colors.white)
                : (muted ? const Color(0xff71717a) : const Color(0xff18181b)),
            letterSpacing: 0,
            height: 1.25,
          ),
        );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dark ? 24 : 20, vertical: 16),
      decoration: BoxDecoration(
        color: dark ? Colors.black : const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          roomText(
            values['title']!.isEmpty ? 'Dressing room' : values['title']!,
            size: 20,
          ),
          if (CommerceDressingRoomStyle.maybeOf(context)
                  ?.contextImages
                  .isNotEmpty ??
              false) ...[
            const SizedBox(height: 10),
            _roomContextImages(
              CommerceDressingRoomStyle.maybeOf(context)!.contextImages,
            ),
          ],
          const SizedBox(height: 10),
          roomText(values['brief']!, size: 12, muted: true),
          if (values['planCaption']!.isNotEmpty) ...[
            const SizedBox(height: 8),
            roomText(values['planCaption']!, size: 10, muted: true),
          ],
          const SizedBox(height: 14),
          CommerceDressingRoomStyle(
            dark: dark,
            child: CommerceBudgetSummary(
              spent: values['spent']!,
              left: values['left']!,
              progress: progress,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final large = MediaQuery.textScalerOf(context).scale(14) > 21;
              if (dark && constraints.maxWidth >= 520 && !large) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < slots.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: index == slots.length - 1 ? 0 : 16,
                          ),
                          child: SizedBox(
                            width: 240,
                            child: FinalizedPieceSlot(
                              key: ValueKey(
                                'dressing-slot-${slots[index]['category']}',
                              ),
                              compactHorizontal: true,
                              category:
                                  slots[index]['category']?.toString() ?? '',
                              label: slots[index]['label']?.toString() ?? '',
                              name: slots[index]['name']?.toString() ?? '',
                              meta: slots[index]['meta']?.toString() ?? '',
                              swatch: slots[index]['swatch']?.toString(),
                              state:
                                  slots[index]['state']?.toString() ?? 'Empty',
                              imageAsset: slots[index]['imageAsset']
                                  ?.toString(),
                              onChange: () => onChange(
                                slots[index]['category']?.toString() ?? '',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              final minimum = large
                  ? 240.0
                  : dark
                  ? 120.0
                  : 140.0;
              final columns = ((constraints.maxWidth + 12) / (minimum + 12))
                  .floor()
                  .clamp(1, dark ? 2 : 4);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final slot in slots)
                    SizedBox(
                      width: width,
                      child: FinalizedPieceSlot(
                        key: ValueKey('dressing-slot-${slot['category']}'),
                        category: slot['category']?.toString() ?? '',
                        label: slot['label']?.toString() ?? '',
                        name: slot['name']?.toString() ?? '',
                        meta: slot['meta']?.toString() ?? '',
                        swatch: slot['swatch']?.toString(),
                        state: slot['state']?.toString() ?? 'Empty',
                        imageAsset: slot['imageAsset']?.toString(),
                        onChange: () =>
                            onChange(slot['category']?.toString() ?? ''),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roomContextImages(List<String> images) => Row(
    children: [
      for (var index = 0; index < images.length && index < 2; index++) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 48,
              child: Image.asset(images[index], fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    ],
  );
}

class _FinalizedDarkPieceSlot extends StatelessWidget {
  const _FinalizedDarkPieceSlot({required this.slot});
  final FinalizedPieceSlot slot;
  @override
  Widget build(BuildContext context) {
    final filled = slot.state == 'Filled';
    final next = slot.state == 'Next';
    final image = slot.imageAsset;
    final approved =
        image != null &&
        RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
            .hasMatch(image);
    final labelStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Colors.white, fontSize: 14, letterSpacing: 0);
    if (slot.compactHorizontal) {
      final thumb = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox.square(
          dimension: 88,
          child: Container(
            decoration: BoxDecoration(
              color: filled ? Colors.white : Colors.white10,
              gradient: next
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66ffffff), Color(0x99ffffff)],
                    )
                  : null,
            ),
            child: filled
                ? (approved
                      ? CommerceProductImage(
                          imageAsset: image,
                          swatch: slot.swatch,
                        )
                      : _rightThumb(
                          {'category': slot.category, 'swatch': slot.swatch},
                          height: 88,
                          glyphSize: 48,
                        ))
                : Center(
                    child: _rightIcon(
                      next ? 'dark-choosing-dots' : 'dark-locked-piece',
                    ),
                  ),
          ),
        ),
      );
      return Semantics(
        button: filled,
        label: filled ? 'Change ${slot.name}' : null,
        child: InkWell(
          onTap: filled ? slot.onChange : null,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filled && slot.name.isNotEmpty ? slot.name : slot.label,
                        style: labelStyle?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (next)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Choosing now',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.black, fontSize: 12),
                          ),
                        )
                      else
                        Text(
                          filled ? slot.meta : 'Not yet',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white60, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: filled,
      label: filled ? 'Change ${slot.name}' : null,
      child: InkWell(
        onTap: filled ? slot.onChange : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: filled ? Colors.white : Colors.white10,
                    gradient: next
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x66ffffff), Color(0x99ffffff)],
                          )
                        : null,
                  ),
                  child: filled
                      ? (approved
                            ? CommerceProductImage(
                                imageAsset: image,
                                swatch: slot.swatch,
                              )
                            : _rightThumb(
                                {
                                  'category': slot.category,
                                  'swatch': slot.swatch,
                                },
                                height: 168,
                                glyphSize: 70,
                              ))
                      : Center(
                          child: _rightIcon(
                            next ? 'dark-choosing-dots' : 'dark-locked-piece',
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filled && slot.name.isNotEmpty ? slot.name : slot.label,
              style: labelStyle,
            ),
            const SizedBox(height: 4),
            if (next)
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Choosing now',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              )
            else
              Text(
                filled ? slot.meta : 'Not yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
