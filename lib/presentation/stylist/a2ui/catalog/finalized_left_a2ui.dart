import '../../../shared/layout/stylist_layout.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../shared/design_system/views/commerce/commerce_components.dart';
import '../../../shared/design_system/views/commerce/finalized_left_components.dart';

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : {};
List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : [];
List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList()
    : [];
String _str(Map<String, Object?> data, String key, [String fallback = '']) =>
    data[key]?.toString() ?? fallback;

final _localWrites = Expando<void Function(String, Object?)>();

void _update(
  CatalogItemContext context,
  Map<String, Object?> raw,
  String field,
  Object? value, {
  String? fallback,
}) {
  final reference = raw[field];
  final path = reference is Map ? reference['path'] : raw['${field}Path'];
  final target = path is String && path.startsWith('/') ? path : fallback;
  if (target != null) context.dataContext.update(DataPath(target), value);
  if (path is! String) _localWrites[context]?.call(field, value);
}

Future<void> _event(
  CatalogItemContext context,
  Object? action,
  Map<String, Object?> values,
) async {
  final event = _map(_map(action)['event']);
  if (event['name'] is! String) return;
  final resolved = await resolveContext(
    context.dataContext,
    _map(event['context']),
  );
  context.dispatchEvent(
    UserActionEvent(
      name: event['name'] as String,
      sourceComponentId: context.id,
      context: {...resolved, ...values},
    ),
  );
}

/// Bound adapters remain separate from presentation. Local writes always use
/// the supplied reference/path; events preserve explicit action context.
class _FinalizedBindings extends StatefulWidget {
  const _FinalizedBindings({
    required this.context,
    required this.kinds,
    required this.builder,
  });
  final CatalogItemContext context;
  final Map<String, String> kinds;
  final Widget Function(Map<String, Object?> raw, Map<String, Object?> resolved)
  builder;
  @override
  State<_FinalizedBindings> createState() => _FinalizedBindingsState();
}

class _FinalizedBindingsState extends State<_FinalizedBindings> {
  final local = <String, Object?>{};
  void write(String field, Object? value) {
    if (mounted) setState(() => local[field] = value);
  }

  @override
  void didUpdateWidget(_FinalizedBindings oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localWrites[oldWidget.context] = null;
    if (oldWidget.context.data != widget.context.data) local.clear();
  }

  @override
  void dispose() {
    _localWrites[widget.context] = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext buildContext) {
    final context = widget.context, kinds = widget.kinds;
    _localWrites[context] = write;
    final raw = _map(context.data), fields = kinds.keys.toList();
    Widget bind(int index, Map<String, Object?> values) {
      if (index == fields.length) {
        return widget.builder(raw, {...values, ...local});
      }
      final field = fields[index];
      Widget next(Object? value) => bind(index + 1, {...values, field: value});
      return switch (kinds[field]) {
        'list' => BoundList(
          dataContext: context.dataContext,
          value: raw[field] ?? const <Object?>[],
          builder: (_, value) => next(value),
        ),
        'number' => BoundNumber(
          dataContext: context.dataContext,
          value: raw[field],
          builder: (_, value) => next(value),
        ),
        'bool' => BoundBool(
          dataContext: context.dataContext,
          value: raw[field] ?? false,
          builder: (_, value) => next(value),
        ),
        _ => BoundString(
          dataContext: context.dataContext,
          value: raw[field],
          builder: (_, value) => next(value),
        ),
      };
    }

    return bind(0, {});
  }
}

Schema _schemaFor(String kind) => switch (kind) {
  'list' => A2uiSchemas.listOrReference(items: S.any()),
  'number' => A2uiSchemas.numberReference(),
  'bool' => A2uiSchemas.booleanReference(),
  _ => A2uiSchemas.stringReference(),
};
CatalogItem _item(
  String name,
  String description,
  Map<String, String> kinds,
  List<String> required,
  Widget Function(
    CatalogItemContext,
    Map<String, Object?>,
    Map<String, Object?>,
  )
  builder, {
  List<String> actions = const [],
  Map<String, Schema> extra = const {},
}) => CatalogItem(
  name: name,
  exampleData: [
    for (final props
        in finalizedLeftFixtures[name] ?? const <Map<String, Object?>>[])
      () => jsonEncode([
        {'id': 'root', 'component': name, ...props},
      ]),
  ],
  dataSchema: S.object(
    description: description,
    properties: {
      for (final entry in kinds.entries) entry.key: _schemaFor(entry.value),
      for (final action in actions) action: A2uiSchemas.action(),
      ...extra,
    },
    required: required,
  ),
  widgetBuilder: (context) => _FinalizedBindings(
    context: context,
    kinds: kinds,
    builder: (raw, values) => builder(context, raw, values),
  ),
);

final finalizedLeftItems = <CatalogItem>[
  _item(
    'UserMessage',
    'Right-aligned customer message; use actual typed or tapped text.',
    {'text': 'string'},
    ['text'],
    (_, raw, value) => FinalizedUserMessage(text: _str(value, 'text')),
  ),
  _item(
    'StylistMessage',
    'Plain assistant text with one idea and an explicit next step.',
    {'text': 'string'},
    ['text'],
    (_, raw, value) => FinalizedStylistMessage(text: _str(value, 'text')),
  ),
  _item(
    'ChatInput',
    'Bound draft and send action. Voice is disabled unless the host supplies microphoneAction.',
    {'value': 'string', 'placeholder': 'string'},
    ['value', 'action'],
    (context, raw, value) => FinalizedChatInput(
      value: _str(value, 'value'),
      placeholder: _str(value, 'placeholder', 'Tell me about the occasion…'),
      onChanged: (text) => _update(context, raw, 'value', text),
      onSend: (text) => _event(context, raw['action'], {'text': text}),
      onMicrophone: raw['microphoneAction'] == null
          ? null
          : () => _event(context, raw['microphoneAction'], {}),
    ),
    actions: ['action', 'microphoneAction'],
    extra: {'valuePath': S.string()},
  ),
  _item(
    'Suggestion',
    'Tappable example brief sends its exact text as a user message.',
    {'text': 'string'},
    ['text', 'action'],
    (context, raw, value) => FinalizedSuggestion(
      text: _str(value, 'text'),
      onPressed: () =>
          _event(context, raw['action'], {'text': _str(value, 'text')}),
    ),
    actions: ['action'],
  ),
  _item(
    'BudgetSlider',
    'Bound outfit budget. Retains value/min/max compatibility; default write path /budget.',
    {'value': 'number'},
    ['value', 'min', 'max'],
    (context, raw, value) => FinalizedBudgetSlider(
      value: (value['value'] as num?)?.toDouble() ?? 0,
      min: (raw['min'] as num?)?.toDouble() ?? 0,
      max: (raw['max'] as num?)?.toDouble() ?? 2000,
      onChanged: (next) {
        _update(context, raw, 'value', next, fallback: '/budget');
        _event(context, raw['action'], {'value': next});
      },
    ),
    actions: ['action'],
    extra: {'min': S.number(), 'max': S.number(), 'valuePath': S.string()},
  ),
  _item(
    'ProductCard',
    'Recommendation with six image proportions, Default/Selected states; stable select_product/remove_product actions.',
    {
      for (final field in [
        'name',
        'price',
        'brandLine',
        'tag',
        'swatch',
        'imageAsset',
        'category',
      ])
        field: 'string',
      'selected': 'bool',
      'dimmed': 'bool',
    },
    ['name', 'price', 'brandLine', 'tag', 'swatch', 'action'],
    (context, raw, value) {
      final removal =
          _map(_map(raw['action'])['event'])['name'] == 'remove_product';
      return FinalizedProductCard(
        name: _str(value, 'name'),
        price: _str(value, 'price'),
        brandLine: _str(value, 'brandLine'),
        tag: _str(value, 'tag'),
        swatch: _str(value, 'swatch'),
        imageAsset: _str(value, 'imageAsset'),
        category: _str(value, 'category', 'dress'),
        selected: value['selected'] == true || removal,
        dimmed: value['dimmed'] == true,
        removal: removal,
        onPressed: () => _event(context, raw['action'], {}),
      );
    },
    actions: ['action'],
  ),
  _item(
    'PicksStrip',
    'Image-only product choices with real product IDs, category proportion and selected state.',
    {'products': 'list', 'category': 'string', 'selectedProductId': 'string'},
    ['products', 'action'],
    (context, raw, value) => FinalizedPicksStrip(
      products: _rows(value['products']),
      category: _str(value, 'category', 'dress'),
      selectedProductId: _str(value, 'selectedProductId'),
      onSelected: (id) {
        if (!StylistSurfaceScope.isJourneyOf(context.buildContext)) {
          _update(context, raw, 'selectedProductId', id);
        }
        _event(context, raw['action'], {'productId': id});
      },
    ),
    actions: ['action'],
    extra: {'selectedProductIdPath': S.string()},
  ),
  _item(
    'ThisOrThat',
    'Two product options, picked None/A/B, one tap returns a real product ID.',
    {'options': 'list', 'picked': 'string', 'question': 'string'},
    ['options', 'action'],
    (context, raw, value) => FinalizedThisOrThat(
      options: _rows(value['options']),
      picked: _str(value, 'picked'),
      question: _str(value, 'question', 'Which do you prefer?'),
      onSelected: (id) {
        if (!StylistSurfaceScope.isJourneyOf(context.buildContext)) {
          _update(context, raw, 'picked', id);
        }
        _event(context, raw['action'], {'productId': id});
      },
    ),
    actions: ['action'],
    extra: {'pickedPath': S.string()},
  ),
  _item(
    'ColourPicker',
    'Multi-select named colours, ring and dot, explicit selected array event.',
    {'options': 'list', 'selected': 'list', 'question': 'string'},
    ['selected'],
    (context, raw, value) => FinalizedColourPicker(
      options: raw.containsKey('options')
          ? _rows(value['options'])
          : finalizedColourOptions,
      selected: _strings(value['selected']),
      question: _str(
        value,
        'question',
        'Any colours you’re drawn to? Pick a few.',
      ),
      singleSelect: raw['singleSelect'] == true,
      onChanged: (colours) {
        _update(context, raw, 'selected', colours);
        _event(context, raw['action'], {
          'colours': colours,
          if (raw['singleSelect'] == true) 'colour': colours.single,
        });
      },
    ),
    actions: ['action'],
    extra: {'selectedPath': S.string(), 'singleSelect': S.boolean()},
  ),
  _item(
    'PhotoUpload',
    'Host-owned capture/library boundary. Never invent an upload or image analysis; choose/use/replace are explicit events. Bundled catalog imageAsset is a fixture only.',
    {
      'state': 'string',
      'photoId': 'string',
      'imageAsset': 'string',
      'description': 'string',
    },
    ['state', 'chooseAction'],
    (context, raw, value) => FinalizedPhotoUpload(
      uploaded: _str(value, 'state') == 'Uploaded',
      photo: _str(value, 'imageAsset').isEmpty
          ? null
          : CommerceProductImage(imageAsset: _str(value, 'imageAsset')),
      description: _str(value, 'description'),
      onChoose: () => _event(context, raw['chooseAction'], {}),
      onUse: raw['useAction'] == null
          ? null
          : () => _event(context, raw['useAction'], {
              'photoId': _str(value, 'photoId'),
            }),
      onReplace: raw['replaceAction'] == null
          ? null
          : () => _event(context, raw['replaceAction'], {
              'photoId': _str(value, 'photoId'),
            }),
    ),
    actions: ['chooseAction', 'useAction', 'replaceAction'],
  ),
  _item(
    'FitSize',
    'Usual size and preferred fit bind separately; host persists and applies to product availability/fit notes.',
    {
      'sizes': 'list',
      'fits': 'list',
      'size': 'string',
      'fit': 'string',
      'question': 'string',
      'sizeLabel': 'string',
    },
    ['size', 'fit'],
    (context, raw, value) => FinalizedFitSize(
      sizes: raw.containsKey('sizes')
          ? _strings(value['sizes'])
          : const ['34', '36', '38', '40', '42'],
      fits: raw.containsKey('fits')
          ? _strings(value['fits'])
          : const ['Fitted', 'True to size', 'Relaxed'],
      size: _str(value, 'size'),
      fit: _str(value, 'fit'),
      question: raw.containsKey('question')
          ? _str(value, 'question')
          : 'Your usual size, and how you like it to sit?',
      sizeLabel: raw.containsKey('sizeLabel')
          ? _str(value, 'sizeLabel')
          : 'DRESS SIZE',
      onSize: (size) {
        _update(context, raw, 'size', size);
        _update(
          context,
          raw,
          'canSave',
          _strings(value['sizes']).contains(size) &&
              (_strings(value['fits']).isEmpty ||
                  _strings(value['fits']).contains(_str(value, 'fit'))),
        );
        _event(context, raw['action'], {
          'size': size,
          'fit': _str(value, 'fit'),
        });
      },
      onFit: (fit) {
        _update(context, raw, 'fit', fit);
        _update(
          context,
          raw,
          'canSave',
          _strings(value['sizes']).contains(_str(value, 'size')) &&
              (_strings(value['fits']).isEmpty ||
                  _strings(value['fits']).contains(fit)),
        );
        _event(context, raw['action'], {
          'size': _str(value, 'size'),
          'fit': fit,
        });
      },
    ),
    actions: ['action'],
    extra: {
      'sizePath': S.string(),
      'fitPath': S.string(),
      'canSavePath': S.string(),
    },
  ),
  _item(
    'OccasionTimeline',
    'Editable activity/time/location segments. Host reruns recommendations from changed segments.',
    {'segments': 'list', 'selected': 'string'},
    ['segments', 'action'],
    (context, raw, value) => FinalizedOccasionTimeline(
      segments: _rows(value['segments']),
      selected: _str(value, 'selected'),
      onEdit: (segment) {
        final segments = _rows(value['segments'])
            .map((old) => old['id'] == segment['id'] ? segment : old)
            .toList();
        _update(context, raw, 'segments', segments);
        _update(context, raw, 'selected', segment['id']);
        _event(context, raw['action'], {'segment': segment});
      },
    ),
    actions: ['action'],
    extra: {'segmentsPath': S.string(), 'selectedPath': S.string()},
  ),
  _item(
    'QuickAdjust',
    'Change one selected piece, preserving the other outfit pieces; host-owned recommendation rerun.',
    {
      'productId': 'string',
      'productName': 'string',
      'imageAsset': 'string',
      'category': 'string',
      'options': 'list',
      'selected': 'string',
    },
    ['productId', 'productName', 'action'],
    (context, raw, value) => FinalizedQuickAdjust(
      productName: _str(value, 'productName'),
      imageAsset: _str(value, 'imageAsset'),
      category: _str(value, 'category', 'dress'),
      options: raw.containsKey('options')
          ? _strings(value['options'])
          : const [
              'Cheaper',
              'Dressier',
              'Warmer',
              'Another colour',
              'Shorter',
              'Something similar',
            ],
      selected: _str(value, 'selected'),
      onSelected: (adjustment) {
        _update(context, raw, 'selected', adjustment);
        _event(context, raw['action'], {
          'productId': _str(value, 'productId'),
          'category': _str(value, 'category', 'dress'),
          'adjustment': adjustment,
        });
      },
    ),
    actions: ['action'],
    extra: {'selectedPath': S.string()},
  ),
  _item(
    'BrandPreferences',
    'Disjoint love/skip lists. Love biases and skip filters host search; host owns cross-visit persistence.',
    {
      'brands': 'list',
      'love': 'list',
      'skip': 'list',
      'allowCustomBrands': 'bool',
    },
    ['love', 'skip'],
    (context, raw, value) => FinalizedBrandPreferences(
      brands: {
        ..._strings(value['brands']),
        ..._strings(value['love']),
        ..._strings(value['skip']),
        if (!raw.containsKey('brands')) ...const [
          'The Row',
          'Toteme',
          'Zimmermann',
          'COS',
          'Gucci',
          'Balenciaga',
        ],
      }.toList(),
      love: _strings(value['love']),
      skip: _strings(value['skip']),
      allowCustomBrands:
          !raw.containsKey('allowCustomBrands') ||
          value['allowCustomBrands'] == true,
      onChanged: (love, skip) {
        _update(context, raw, 'love', love);
        _update(context, raw, 'skip', skip);
        _event(context, raw['action'], {'love': love, 'skip': skip});
      },
    ),
    actions: ['action'],
    extra: {'lovePath': S.string(), 'skipPath': S.string()},
  ),
  _item(
    'StylistWorking',
    'Honest host/provider work description; omit progress when no measured fraction is available.',
    {'text': 'string', 'progress': 'number'},
    ['text'],
    (_, raw, value) => FinalizedStylistWorking(
      text: _str(value, 'text'),
      progress: (value['progress'] as num?)?.toDouble(),
    ),
  ),
];

Map<String, Object?> _action(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'event': {'name': name, 'context': context},
};
const _exampleCards = [
  {
    'category': 'dress',
    'name': 'Indra Long Dress',
    'price': '€874',
    'brandLine': 'Zimmermann · Tan · Silk · Long',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'paris-dress-1',
  },
  {
    'category': 'top',
    'name': 'Silk Cami Shir',
    'price': '€290',
    'brandLine': 'Equipment · Ivory · Silk',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-top',
  },
  {
    'category': 'bottom',
    'name': 'Wide-leg Wool Trouser',
    'price': '€1,090',
    'brandLine': 'The Row · Black · Wool',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-bottom',
  },
  {
    'category': 'layer',
    'name': 'Wool Cape',
    'price': '€1,150',
    'brandLine': 'Max Mara · Camel · Wool',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-layer',
  },
  {
    'category': 'shoes',
    'name': 'Satin Pointed Pump',
    'price': '€545',
    'brandLine': 'Manolo Blahnik · Black · Satin · 70mm',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'paris-shoes-1',
  },
  {
    'category': 'bag',
    'name': 'Le Petit Bambino',
    'price': '€425',
    'brandLine': 'Jacquemus · Black · Leather',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-bag',
  },
];

/// A2UI v0.9 flat component fixtures, consumed by CatalogItem.exampleData and
/// the exported runtime catalog. Placeholder recommendations are labelled as
/// design examples; host products continue to supply their actual catalog IDs.
final finalizedLeftFixtures = <String, List<Map<String, Object?>>>{
  'UserMessage': [
    {
      'text': 'Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500',
    },
  ],
  'StylistMessage': [
    {
      'text': 'Perfect — anniversary in Paris in October. I’ll aim for something elegant with the option to go full black tie. Two quick things and I’ll pull options.',
    },
  ],
  'ChatInput': [
    {'value': '', 'action': _action('send_message')},
    {'value': 'A summer wedding in Lisbon', 'action': _action('send_message')},
  ],
  'Suggestion': [
    {
      'text': 'A summer wedding in Lisbon in late June: outdoor ceremony, cocktail dress code, around €1,200 for the whole outfit',
      'action': _action('send_message'),
    },
  ],
  'BudgetSlider': [
    {'value': 1500, 'min': 0, 'max': 3750},
  ],
  'ProductCard': [
    for (final row in _exampleCards)
      for (final selected in [false, true])
        {
          ...Map<String, Object?>.from(row)..remove('productId'),
          'selected': selected,
          'action': _action(selected ? 'remove_product' : 'select_product', {
            'productId': row['productId'],
          }),
        },
    {
      'name': 'Morrow Draped Top',
      'price': '€35',
      'brandLine': 'Fable Wardrobe · Brown',
      'category': 'top',
      'tag': 'Approved catalog image',
      'swatch': '#b8a98e',
      'imageAsset': 'assets/images/products/demo-0047.jpg',
      'action': _action('select_product', {'productId': 'demo-0047'}),
    },
  ],
  'PicksStrip': [
    for (final category in ['dress', 'top', 'shoes'])
      {
        'category': category,
        'selectedProductId': '',
        'products': [
          for (var i = 0; i < 3; i++)
            {
              'productId': 'design-$category-$i',
              'name': 'Design example ${i + 1}',
              'swatch': ['#b8a98e', '#3b3a38', '#e6e1d6'][i],
            },
        ],
        'action': _action('select_product'),
      },
  ],
  'ThisOrThat': [
    for (final picked in ['', 'option-a', 'option-b'])
      {
        'picked': picked,
        'options': [
          {
            'productId': 'option-a',
            'label': 'A · Satin pump',
            'category': 'shoes',
            'swatch': '#2b2a28',
          },
          {
            'productId': 'option-b',
            'label': 'B · Kitten heel',
            'category': 'shoes',
            'swatch': '#3a3835',
          },
        ],
        'action': _action('select_product'),
      },
  ],
  'ColourPicker': [
    {
      'selected': ['Black', 'Navy', 'Chocolate'],
      'action': _action('set_colours'),
    },
  ],
  'PhotoUpload': [
    {'state': 'Empty', 'chooseAction': _action('choose_photo')},
    {
      'state': 'Uploaded',
      'photoId': 'design-example-only',
      'description': 'Warm undertone · dark hair · you wear a lot of black — camel and olive would lift it.',
      'chooseAction': _action('choose_photo'),
      'useAction': _action('use_photo'),
      'replaceAction': _action('replace_photo'),
    },
  ],
  'FitSize': [
    {'size': '38', 'fit': 'True to size', 'action': _action('set_fit_size')},
  ],
  'OccasionTimeline': [
    {
      'segments': [
        {
          'id': 'ceremony',
          'time': '15:00',
          'label': 'Ceremony',
          'location': 'Outdoors',
        },
        {
          'id': 'drinks',
          'time': '17:30',
          'label': 'Drinks',
          'location': 'Terrace',
        },
        {
          'id': 'dinner',
          'time': '20:00',
          'label': 'Dinner',
          'location': 'Indoors',
        },
      ],
      'selected': 'ceremony',
      'action': _action('edit_occasion_segment'),
    },
  ],
  'QuickAdjust': [
    {
      'productId': 'paris-dress-1',
      'productName': 'Indra Long Dress',
      'category': 'dress',
      'action': _action('adjust_piece'),
    },
  ],
  'BrandPreferences': [
    {
      'love': ['The Row', 'Toteme'],
      'skip': ['Balenciaga'],
      'action': _action('set_brand_preferences'),
    },
  ],
  'StylistWorking': [
    {'text': 'Looking through 1,240 dresses under €1,500…', 'progress': .4},
    {'text': 'Looking for pieces that work together…'},
  ],
};
