import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'commerce_bindings_a2ui.dart' as legacy;
import '../../../shared/design_system/views/commerce/finalized_right_components.dart';

const _hangerLabels = {
  'dress': 'A dress',
  'top': 'A top',
  'bottom': 'Trousers',
  'layer': 'A layer over it',
  'shoes': 'Shoes',
  'bag': 'A bag',
  'accessory': 'An accessory',
};
const _hangerNames = {
  'dress': 'Indra Long Dress',
  'top': 'Silk Camp Shirt',
  'bottom': 'Wide-Leg Wool Trouser',
  'layer': 'Wool Cape',
  'shoes': 'Satin Pointed Pump',
  'bag': 'Le Petit Bambino',
  'accessory': 'Accessory',
};
const _hangerMeta = {
  'dress': 'Zimmermann · €874',
  'top': 'Equipment · €290',
  'bottom': 'The Row · €1,090',
  'layer': 'Max Mara · €1,150',
  'shoes': 'Manolo Blahnik · €545',
  'bag': 'Jacquemus · €425',
  'accessory': 'Optional piece',
};

/// Finalized dressing-room items. Replace the legacy PieceSlot entry
/// when registering this list; do not register both entries with the same name.
final List<CatalogItem> finalizedRightItems = [
  finalizedPieceSlotCatalogItem,
  finalizedDressingRoomCatalogItem,
  for (final spec in _rightSpecs) _rightCatalogItem(spec),
];

/// Finalized hangers with the six original proportions and an accessory fallback.
/// Category-less legacy data
/// intentionally retains the original presentation.
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
  _RightSpec('BagPreview', ['mode'], [], ['items'], [
    'closeAction',
    'removeAction',
    'restoreAction',
    'quantityAction',
    'checkoutAction',
    'sizeAction',
  ]),
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
      Widget room(List<Object?> rows, double progress) => FinalizedDressingRoom(
        values: {
          ...values,
          if (!data.containsKey('slots')) 'title': 'Dressing room',
        },
        progress: progress,
        slots: [
          for (final row in rows)
            if (row is Map) Map<String, Object?>.from(row),
        ],
        onChange: (category) async {
          final action = data['changeAction'];
          final event = action is Map ? action['event'] : null;
          final values = event is Map && event['context'] is Map
              ? await resolveContext(
                  itemContext.dataContext,
                  Map<String, Object?>.from(event['context'] as Map),
                )
              : <String, Object?>{};
          itemContext.dispatchEvent(
            UserActionEvent(
              name: event is Map ? event['name'] as String : 'adjust_piece',
              sourceComponentId: itemContext.id,
              context: {...values, 'category': category},
            ),
          );
        },
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
