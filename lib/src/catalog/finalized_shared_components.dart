import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'commerce_widgets.dart';

/// Finalized shared catalog, read from exact native Figma properties and SVGs.
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
        builder: (_, label) => FinalizedPrimaryButton(
          label: label ?? '',
          onPressed: _hasEvent(data['action'])
              ? () => _dispatch(context, data['action'])
              : null,
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

ObjectSchema _originalSchema(CatalogItem item, {String? description}) {
  final schema = Map<String, Object?>.from(item.dataSchema.value);
  if (description != null) schema['description'] = description;
  schema['properties'] = Map<String, Object?>.from(schema['properties'] as Map)
    ..remove('component');
  schema['required'] = (schema['required'] as List)
      .where((value) => value != 'component')
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

/// Figma 53:3126: 44 px black visual, radius 8, Jost 14/1.4.
/// Two transparent pixels on each vertical edge provide a 48 px hit target.
class FinalizedPrimaryButton extends StatelessWidget {
  const FinalizedPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Figma 53:3128: sentence-case Inter Medium, 12 px, zinc-500.
/// Uses the app-bundled Inter font and preserves caller sentence case.
class FinalizedEyebrow extends StatelessWidget {
  const FinalizedEyebrow({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontFamily: 'Inter',
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: const Color(0xff71717a),
    ),
  );
}

const _assetRoot = 'assets/icons/finalized_shared/';
const finalizedCategories = ['dress', 'top', 'bottom', 'layer', 'shoes', 'bag'];

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
  dataSchema: _originalSchema(chipCatalogItem),
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
          onChanged: _hasEvent(d['action'])
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

class FinalizedChip extends StatefulWidget {
  const FinalizedChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onChanged,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  @override
  State<FinalizedChip> createState() => _FinalizedChipState();
}

class _FinalizedChipState extends State<FinalizedChip> {
  late bool selected = widget.selected;
  @override
  void didUpdateWidget(FinalizedChip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: widget.onChanged != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onChanged == null
            ? null
            : () {
                setState(() => selected = !selected);
                widget.onChanged!(selected);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xff18181b) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xff18181b)
                    : const Color(0xffe4e4e7),
              ),
            ),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
                letterSpacing: 0,
                color: selected ? Colors.white : const Color(0xff18181b),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FinalizedBagIcon extends StatelessWidget {
  const FinalizedBagIcon({super.key, required this.count, this.onPressed});
  final int count;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: _build(context),
  );

  Widget _build(BuildContext context) {
    final n = count.clamp(0, 999);
    final exact = [0, 1, 4, 5].contains(n);
    return Semantics(
      label: 'Bag, $n ${n == 1 ? 'item' : 'items'}',
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    children: [
                      SvgPicture.asset(
                        '$_assetRoot${exact ? 'bag-$n' : 'bag-0'}.svg',
                      ),
                      if (!exact)
                        Positioned(
                          right: 0,
                          top: 2,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xff18181b),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              n > 99 ? '99+' : '$n',
                              textScaler: TextScaler.noScaling,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.2,
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
        ),
      ),
    );
  }
}

class FinalizedToast extends StatelessWidget {
  const FinalizedToast({
    super.key,
    required this.message,
    required this.actionLabel,
    this.onPressed,
  });
  final String message;
  final String actionLabel;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    child: Semantics(
      liveRegion: true,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              decoration: BoxDecoration(
                color: const Color(0xff18181b),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SvgPicture.asset('${_assetRoot}toast-bag.svg'),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xffa1a1aa)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FinalizedQuantityStepper extends StatefulWidget {
  const FinalizedQuantityStepper({
    super.key,
    required this.value,
    this.max = 99,
    this.onChanged,
    this.onRemove,
  });
  final int value;
  final int max;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onRemove;
  @override
  State<FinalizedQuantityStepper> createState() =>
      _FinalizedQuantityStepperState();
}

class _FinalizedQuantityStepperState extends State<FinalizedQuantityStepper> {
  late int quantity = widget.value.clamp(0, widget.max.clamp(1, 999));
  @override
  void didUpdateWidget(FinalizedQuantityStepper old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.max != widget.max) {
      quantity = widget.value.clamp(0, widget.max.clamp(1, 999));
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xfff4f4f5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _control(
          context,
          '−',
          'Decrease quantity',
          quantity == 0
              ? null
              : quantity == 1
              ? widget.onRemove == null
                    ? null
                    : () {
                        setState(() => quantity = 0);
                        widget.onRemove!();
                      }
              : widget.onChanged == null
              ? null
              : () {
                  setState(() => quantity--);
                  widget.onChanged!(quantity);
                },
        ),
        Semantics(
          liveRegion: true,
          label: 'Quantity $quantity',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        _control(
          context,
          '+',
          'Increase quantity',
          quantity == 0 ||
                  quantity >= widget.max.clamp(1, 999) ||
                  widget.onChanged == null
              ? null
              : () {
                  setState(() => quantity++);
                  widget.onChanged!(quantity);
                },
        ),
      ],
    ),
  );
  Widget _control(
    BuildContext c,
    String text,
    String label,
    VoidCallback? tap,
  ) => Semantics(
    label: label,
    button: true,
    enabled: tap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                text,
                style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FinalizedOccasionTile extends StatelessWidget {
  const FinalizedOccasionTile({
    super.key,
    required this.label,
    this.imageAsset,
    this.onPressed,
  });
  final String label;
  final String? imageAsset;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: _build(context),
  );

  Widget _build(BuildContext context) => Semantics(
    label: label,
    button: onPressed != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 208,
          height: 223,
          child: _dynamicImage(
            imageAsset,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff6b5c54), Color(0xff332b29)],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _dynamicImage(String? path, Widget fallback) {
  if (path == null ||
      !RegExp(
        r'^assets/images/(products|occasions|finalized_shared)/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$',
      ).hasMatch(path)) {
    return fallback;
  }
  return Image.asset(
    path,
    fit: BoxFit.cover,
    errorBuilder: (_, e, s) => fallback,
  );
}

class FinalizedLookTile extends StatelessWidget {
  const FinalizedLookTile({
    super.key,
    required this.category,
    required this.label,
    this.imageAsset,
    this.onPressed,
  });
  final String category;
  final String label;
  final String? imageAsset;
  final VoidCallback? onPressed;
  static const heights = {
    'dress': 240.0,
    'top': 96.0,
    'bottom': 136.0,
    'layer': 150.0,
    'shoes': 64.0,
    'bag': 82.0,
  };
  static const colors = {
    'dress': Color(0xffb8a98e),
    'top': Color(0xff3c3c3f),
    'bottom': Color(0xff5b5a57),
    'layer': Color(0xff3e3a2c),
    'shoes': Color(0xff2b2a28),
    'bag': Color(0xff2a211c),
  };
  static const origins = {
    'dress': Offset(12, 72),
    'top': Offset(25, 13),
    'bottom': Offset(25, 33),
    'layer': Offset(25, 40),
    'shoes': Offset(35, 7),
    'bag': Offset(35, 16),
  };
  static const glyphSizes = {
    'dress': Size(96, 96),
    'top': Size(70, 72),
    'bottom': Size(70, 92),
    'layer': Size(72, 89),
    'shoes': Size(85, 50),
    'bag': Size(76, 66),
  };
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: _build(context),
  );

  Widget _build(BuildContext context) {
    final cat = finalizedCategories.contains(category) ? category : 'dress';
    final glyph = _dynamicImage(
      imageAsset,
      Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: origins[cat]!.dx,
            top: origins[cat]!.dy,
            child: SizedBox(
              width: glyphSizes[cat]!.width,
              height: glyphSizes[cat]!.height,
              child: SvgPicture.asset('${_assetRoot}look-$cat.svg'),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: label,
      button: onPressed != null,
      child: Material(
        color: colors[cat],
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: 120, height: heights[cat], child: glyph),
        ),
      ),
    );
  }
}

class FinalizedGarmentSilhouette extends StatelessWidget {
  const FinalizedGarmentSilhouette({super.key, required this.category});
  final String category;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: _build(context),
  );

  Widget _build(BuildContext context) => Semantics(
    label: '$category placeholder',
    image: true,
    child: SizedBox(
      width: 100,
      height: 100,
      child: SvgPicture.asset(
        '${_assetRoot}silhouette-${finalizedCategories.contains(category) ? category : 'dress'}.svg',
      ),
    ),
  );
}

class FinalizedSideBar extends StatelessWidget {
  const FinalizedSideBar({
    super.key,
    required this.count,
    this.onClose,
    this.onBag,
    this.statusPreview = false,
  });
  final int count;
  final VoidCallback? onClose;
  final VoidCallback? onBag;
  final bool statusPreview;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: _build(context),
  );

  Widget _build(BuildContext context) => Container(
    width: 60,
    height: 669,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(left: BorderSide(color: Color(0xffe4e4e7))),
    ),
    // The expanded bag hit area extends 2px beyond its 44px design slot.
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
    child: Column(
      children: [
        if (statusPreview) ...[
          Container(
            width: 10,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xff111111),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 6),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              '9:41',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.25,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                color: Color(0xff111111),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Semantics(
          label: 'Close stylist',
          button: true,
          enabled: onClose != null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset('${_assetRoot}close.svg'),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        FinalizedBagIcon(count: count, onPressed: onBag),
      ],
    ),
  );
}

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
        'label': 'Occasion photograph',
        'imageAsset': 'assets/images/occasions/start-01.png',
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
