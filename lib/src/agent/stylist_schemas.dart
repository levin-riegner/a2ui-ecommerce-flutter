import 'dart:convert';

import 'package:schemantic/schemantic.dart';

import 'stylist_brief.dart';
import '../data/models.dart';

/// Agent-facing JSON contracts; host domain validation remains authoritative.
SchemanticType<Map<String, dynamic>> stylistObjectSchema(
  Map<String, Object?> schema,
) => SchemanticType.from(
  jsonSchema: jsonDecode(jsonEncode(schema)) as Map<String, Object?>,
  parse: (json) => Map<String, dynamic>.from(json as Map),
);

final stylistTurnSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'message': {'type': 'string'},
    'action': stylistCommandSchema.jsonSchema(),
  },
  'additionalProperties': false,
});
final stylistSearchSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    for (final name in ['query', 'category', 'color', 'occasion', 'season'])
      name: {'type': 'string'},
    'gender': {
      'type': 'string',
      'enum': ['male', 'female', 'male, female'],
    },
    'priceMax': {'type': 'number', 'minimum': 0},
    'limit': {'type': 'integer', 'minimum': 1, 'maximum': 12},
  },
  'required': ['query'],
  'additionalProperties': false,
});
final stylistPresentSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'productIds': {
      'type': 'array',
      'items': {'type': 'string', 'minLength': 1},
      'minItems': 1,
      'maxItems': 5,
      'uniqueItems': true,
    },
  },
  'required': ['productIds'],
  'additionalProperties': false,
});

final stylistProductIdSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'productId': {'type': 'string'},
  },
  'required': ['productId'],
  'additionalProperties': false,
});
final stylistBriefProperties = <String, Object?>{
  for (final name in [
    'occasion',
    'occasionEvidence',
    'dressCode',
    'season',
    'palette',
    'notes',
    'city',
  ])
    name: {'type': 'string'},
  for (final name in ['tripStart', 'tripEnd'])
    name: {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}$'},
  'gender': {
    'type': 'string',
    'enum': ['male', 'female', 'male, female'],
  },
  'budget': {'type': 'number', 'exclusiveMinimum': 0},
};
final stylistBriefSchema = stylistObjectSchema({
  'type': 'object',
  'properties': stylistBriefProperties,
  'additionalProperties': false,
});
final stylistChangesSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'brief': stylistBriefSchema.jsonSchema(),
    'clearFields': {
      'type': 'array',
      'items': {'type': 'string', 'enum': StylistBrief.fields.toList()},
      'uniqueItems': true,
    },
    for (final name in ['removeProductIds', 'addProductIds'])
      name: {
        'type': 'array',
        'items': {'type': 'string', 'minLength': 1},
        'uniqueItems': true,
        'maxItems': 7,
      },
  },
  'additionalProperties': false,
});

final stylistQuestionSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'intent': {
      'type': 'string',
      'enum': ['capabilities', 'styling_advice'],
    },
    'facts': {
      'type': 'array',
      'items': {'type': 'string', 'minLength': 1},
      'maxItems': 7,
      'description': 'Exact quotes of explicit new outfit facts, excluding the question itself. Empty for a pure question.',
    },
  },
  'required': ['intent', 'facts'],
  'additionalProperties': false,
});

const _text = {'type': 'string'};
const _id = {'type': 'string', 'minLength': 1};
const _texts = {'type': 'array', 'items': _text};
final _category = {
  'type': 'string',
  'enum': ProductCategory.values.map((c) => c.name).toList(),
};
final _nullableCategory = {
  'anyOf': [
    _category,
    {'type': 'null'},
  ],
};
final _nullableAmount = {
  'type': ['number', 'null'],
};
final _briefFacts = {
  'type': 'object',
  'properties': {
    for (final entry in stylistBriefProperties.entries)
      if (entry.key != 'occasionEvidence' && entry.key != 'city')
        entry.key: entry.value,
  },
  'additionalProperties': false,
};
final _catalog = {
  'type': 'object',
  'properties': {
    'revision': _id,
    'currency': {'const': 'EUR'},
    'completeSnapshot': {'const': true},
    'capabilities': {
      'type': 'object',
      'properties': {
        for (final k in ['stock', 'sizes', 'checkout']) k: {'type': 'boolean'},
      },
      'required': ['stock', 'sizes', 'checkout'],
      'additionalProperties': false,
    },
  },
  'required': ['revision', 'currency', 'completeSnapshot', 'capabilities'],
  'additionalProperties': false,
};
final productFactsJsonSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    for (final k in [
      'id',
      'name',
      'brand',
      'description',
      'gender',
      'subcategory',
      'color',
      'material',
      'season',
      'occasion',
      'keywords',
      'garment_type',
      'image_asset',
    ])
      k: _text,
    'attributes': {'type': 'object'},
    'demo_variants': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'id': _id,
          'size': _id,
          'stock': {'type': 'integer', 'minimum': 0},
          'available': {'type': 'boolean'},
          'source': {'const': 'local_demo_fixture'},
          'sourceVersion': _id,
        },
        'required': [
          'id',
          'size',
          'stock',
          'available',
          'source',
          'sourceVersion',
        ],
        'additionalProperties': false,
      },
    },
    'category': _category,
    'color_families': _texts,
    'price_eur': {'type': 'number', 'minimum': 0},
    'derived_provenance': {
      'type': 'object',
      'properties': {
        for (final k in ['garment_type', 'color_families'])
          k: {'const': 'host_catalog_semantics_v1'},
      },
      'required': ['garment_type', 'color_families'],
      'additionalProperties': false,
    },
  },
  'required': [
    'id',
    'name',
    'brand',
    'description',
    'category',
    'gender',
    'subcategory',
    'color',
    'material',
    'season',
    'occasion',
    'keywords',
    'garment_type',
    'color_families',
    'price_eur',
    'image_asset',
    'derived_provenance',
  ],
  'additionalProperties': false,
};
final _products = {'type': 'array', 'items': productFactsJsonSchema};
final stylistResultSchema = stylistObjectSchema({
  'type': 'object',
  'properties': {
    'reply': _text,
    'intent': _text,
    'products': _products,
    'brief': _briefFacts,
    'missingFields': _texts,
    'constraints': {'type': 'object'},
    'outfit': {
      'type': 'object',
      'properties': {
        'budget': _nullableAmount,
        'items': {'type': 'object', 'additionalProperties': _id},
      },
      'required': ['budget', 'items'],
      'additionalProperties': false,
    },
    'catalog': _catalog,
  },
  'required': [
    'reply',
    'products',
    'brief',
    'missingFields',
    'constraints',
    'outfit',
    'catalog',
  ],
  'additionalProperties': false,
});

/// Each tool exposes its successful response and a corrective failure response.
/// Domain handlers retain ownership of catalog, source and budget invariants.
SchemanticType<Map<String, dynamic>> stylistToolOutputSchema(String name) {
  final success = switch (name) {
    'respond_to_question' => {
      'intent': {
        'type': 'string',
        'enum': ['capabilities', 'styling_advice'],
      },
      'brief': _briefFacts,
      'instruction': _text,
    },
    'search_products' => {
      'products': _products,
      'nextCategory': _nullableCategory,
      'notices': _texts,
      'catalog': _catalog,
    },
    'present_products' => {
      'presentedIds': stylistPresentSchema.jsonSchema()['properties'] is Map
          ? (stylistPresentSchema.jsonSchema()['properties']
                as Map)['productIds']
          : _texts,
    },
    _ => {
      'brief': _briefFacts,
      'constraints': {'type': 'object'},
      'city': _text,
      'cityContext': {'type': 'object'},
      'missingFields': _texts,
      'outfit': _products,
      'spent': {'type': 'number', 'minimum': 0},
      'remaining': _nullableAmount,
      'availableForNextCategory': _nullableAmount,
      'nextCategory': _nullableCategory,
      'complete': {'type': 'boolean'},
      'catalog': _catalog,
    },
  };
  return stylistObjectSchema({
    'oneOf': [
      {
        'type': 'object',
        'properties': success,
        'required': success.keys
            .where((k) => !const ['notices', 'cityContext'].contains(k))
            .toList(),
        'additionalProperties': false,
      },
      {
        'type': 'object',
        'properties': {
          'error': {'type': 'string', 'minLength': 1},
          'code': {
            'type': 'string',
            'enum': ['invalid_input'],
          },
          'missingFields': _texts,
          'clarificationRequests': _texts,
        },
        'required': ['error', 'code'],
        'additionalProperties': false,
      },
    ],
  });
}

Map<String, Object?> _context(
  Map<String, Object?> properties, [
  List<String> required = const [],
]) => {
  'type': 'object',
  'properties': properties,
  'required': required,
  'additionalProperties': false,
};
final stylistCommandContexts = <String, Map<String, Object?>>{
  for (final name in [
    'resume_session',
    'open_saved_looks',
    'save_look',
    'reset_look',
    'open_bag',
    'close_bag',
    'add_look_to_bag',
    'undo_bag_changes',
    'edit_preferences',
    'compare_products',
    'refresh_city_context',
  ])
    name: _context({}),
  for (final name in ['select_product', 'remove_product', 'remove_bag_item'])
    name: _context({'productId': _id}, ['productId']),
  for (final name in ['restore_look', 'delete_look'])
    name: _context({'lookId': _id}, ['lookId']),
  for (final name in ['change_bag_quantity', 'restore_bag_item'])
    name: _context(
      {
        'productId': _id,
        'quantity': {'type': 'integer', 'minimum': 1, 'maximum': 99},
      },
      ['productId', 'quantity'],
    ),
  'preview_demo_checkout': _context({}),
  'open_demo_receipt': _context({}),
  'confirm_demo_checkout': _context({'quoteKey': _id}, ['quoteKey']),
  'open_product_details': _context({'productId': _id}, ['productId']),
  'set_fit_size': _context(
    {'productId': _id, 'size': _id, 'fit': _text},
    ['productId', 'size'],
  ),
  'choose_product_colour': _context(
    {'productId': _id, 'colour': _id, 'colours': _texts},
    ['productId', 'colour'],
  ),
  'set_product_options': _context(
    {'productId': _id, 'colourProductId': _id, 'size': _id, 'fit': _text},
    ['productId', 'size'],
  ),
  'adjust_piece': _context(
    {
      'category': _category,
      'productId': _id,
      'adjustment': {'type': 'string', 'maxLength': 120},
    },
    ['category'],
  ),
  'find_options': _context({
    for (final k in ['dressCode', 'season', 'budget', 'gender'])
      k: stylistBriefProperties[k],
  }),
  'update_budget': _context(
    {'budget': stylistBriefProperties['budget']},
    ['budget'],
  ),
  for (final name in [
    'update_preferences',
    'set_colours',
    'set_brand_preferences',
  ])
    name: _context({
      for (final k in ['colours', 'love', 'skip']) k: _texts,
      'owned': {
        'type': 'object',
        'properties': {
          for (final c in ProductCategory.values) c.name: {'type': 'boolean'},
        },
        'additionalProperties': false,
      },
      'tripStart': _text,
      'tripEnd': _text,
    }),
};
final stylistCommandSchema = stylistObjectSchema({
  'oneOf': [
    for (final entry in stylistCommandContexts.entries)
      {
        'type': 'object',
        'properties': {
          'name': {'const': entry.key},
          'context': entry.value,
        },
        'required': ['name', 'context'],
        'additionalProperties': false,
      },
  ],
});
