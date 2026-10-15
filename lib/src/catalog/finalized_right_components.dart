import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'commerce_components.dart';
import 'finalized_shared_components.dart' show FinalizedQuantityStepper;
import '../layout/stylist_layout.dart';
import '../data/money.dart';

const _hangerHeights = <String, double>{
  'dress': 200,
  'top': 100,
  'bottom': 130,
  'layer': 90,
  'shoes': 64,
  'bag': 64,
  'accessory': 82,
};
const _hangerGlyphSizes = <String, double>{
  'dress': 80,
  'top': 70,
  'bottom': 80,
  'layer': 63,
  'shoes': 44.8,
  'bag': 44.8,
  'accessory': 50,
};

/// Category-less legacy data
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
      final identity = ValueKey((state, name, imageAsset, meta));
      return AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        switchInCurve: Curves.easeInOutCubic,
        // Keep the last outfit fully visible underneath the incoming piece.
        // A bound-data update never fades the whole black room to empty.
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: child.key == identity
              ? animation
              : const AlwaysStoppedAnimation(1),
          child: child,
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [
            for (final child in previous)
              ExcludeSemantics(child: IgnorePointer(child: child)),
            ?current,
          ],
        ),
        child: _FinalizedDarkPieceSlot(key: identity, slot: this),
      );
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
        final over =
            budget > 0 &&
            euroAmountExceeds(
              sumEuros([spent, number('proposedSpend')]),
              budget,
            );
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
                    '${formatEuros(spent, omitZeroCents: true)} spent · ${number('pieceCount').toInt()} of ${number('totalPieces').toInt()}',
                    size: 16,
                  ),
                  _rightText(
                    context,
                    '${formatEuros(subtractEuros(budget, spent), omitZeroCents: true)} left',
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
          padding: 10,
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
              const SizedBox(height: 8),
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
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
              const SizedBox(height: 8),
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
                  if (data['saveAction'] != null)
                    _rightLink(context, 'Save look', action('saveAction')),
                  if (data['shareAction'] != null)
                    _rightLink(
                      context,
                      'Share',
                      action('shareAction'),
                      muted: true,
                    ),
                  if (data['resetAction'] != null)
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
  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const Text('No catalog pieces selected');
    final foundation = pieces
        .where((p) => const {'dress', 'top', 'bottom'}.contains(p['category']))
        .toList();
    final extras = pieces.where((p) => !foundation.contains(p)).toList();
    final columns = foundation.isEmpty
        ? [
            pieces.take((pieces.length + 1) ~/ 2).toList(),
            pieces.skip((pieces.length + 1) ~/ 2).toList(),
          ]
        : [foundation, extras];
    final visible = columns.where((column) => column.isNotEmpty).toList();
    return AspectRatio(
      aspectRatio: 248 / 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var column = 0; column < visible.length; column++) ...[
            if (column > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visible[column].length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Expanded(
                      flex:
                          (_hangerHeights[visible[column][i]['category']] ?? 82)
                              .round(),
                      child: Semantics(
                        label: visible[column][i]['name']?.toString(),
                        image: true,
                        child: _rightThumb(
                          visible[column][i],
                          height: double.infinity,
                          radius: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
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
  bool get hostOwned => widget.data['mode'] == 'demo-host';
  String money(double value) => formatEuros(value, omitZeroCents: !hostOwned);
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
      if (update != null && !hostOwned) setState(update);
      widget.onAction!(key, extra);
    };
  }

  VoidCallback? remove(BuildContext context, Map<String, Object?> item) {
    final removeCallback = callback('removeAction', {
      'productId': item['id'],
    }, () => items.remove(item));
    if (removeCallback == null) return null;
    if (hostOwned) return removeCallback;
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
    final total = eurosFromCents(
      items.fold<int>(
        0,
        (n, item) =>
            n + euroCents(item['unitPrice'] as num? ?? 0) * quantity(item),
      ),
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
                child: _rightText(
                  context,
                  '${hostOwned ? 'Demo bag' : 'Your bag'} — $count items',
                  size: 16,
                ),
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
                          updateLocally: !hostOwned,
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
                        money(
                          eurosFromCents(
                            euroCents(item['unitPrice'] as num? ?? 0) *
                                quantity(item),
                          ),
                        ),
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
              _rightText(context, money(total), size: 16),
            ],
          ),
          const SizedBox(height: 14),
          if (!hostOwned)
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

class FinalizedDressingRoom extends StatelessWidget {
  const FinalizedDressingRoom({
    super.key,
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
    final compact =
        CommerceDressingRoomStyle.maybeOf(context)?.compact ?? false;
    final budget = CommerceDressingRoomStyle(
      dark: dark,
      child: CommerceBudgetSummary(
        spent: compact
            ? values['spent']!.replaceFirst(
                RegExp(r'\s+[—·]\s*\d+ of \d+$'),
                '',
              )
            : values['spent']!,
        left: values['left']!,
        progress: progress,
      ),
    );
    Widget roomText(String value, {double size = 14, bool muted = false}) =>
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: size,
            color: dark
                ? (muted ? Colors.white60 : Colors.white)
                : (muted ? const Color(0xff71717a) : const Color(0xff18181b)),
            letterSpacing: 0,
            height: size == 20 || size == 12 ? 1.2 : 1.4,
          ),
        );
    return Container(
      key: const ValueKey('finalized-dressing-room'),
      constraints: BoxConstraints(
        minHeight: CommerceDressingRoomStyle.maybeOf(context)?.minHeight ?? 0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dark ? StylistLayout.roomGutter : 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: dark ? Colors.black : const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
            _roomContextImages(
              CommerceDressingRoomStyle.maybeOf(context)!.contextImages,
            ),
          ],
          const SizedBox(height: 8),
          roomText(values['brief']!, size: 12, muted: true),
          const SizedBox(height: 8),
          if (!compact) ...[
            budget,
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final large = MediaQuery.textScalerOf(context).scale(14) > 21;
              if (dark &&
                  (compact || (constraints.maxWidth >= 520 && !large))) {
                return SingleChildScrollView(
                  key: const ValueKey('dressing-room-rack'),
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
              final gap = dark ? StylistLayout.itemGap : 12.0;
              final columns = ((constraints.maxWidth + gap) / (minimum + gap))
                  .floor()
                  .clamp(1, dark ? 2 : 4);
              final width =
                  (constraints.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(
                spacing: gap,
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
          if (compact) ...[const SizedBox(height: 24), budget],
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
  const _FinalizedDarkPieceSlot({super.key, required this.slot});
  // The pane narrows around the active hinge in Book mode. Keep image height
  // independent of that width so the selected section below does not jump.
  static const imageHeight = StylistLayout.pieceImage;
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
            SizedBox(
              height: imageHeight,
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
                                height: imageHeight,
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
