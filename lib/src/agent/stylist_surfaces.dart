import '../data/models.dart';
import 'outfit_plan.dart';
import 'city_context.dart';
import 'stylist_brief_surface.dart';

const stylistCatalogId = 'com.example.a2ui_flutter_commerce/catalog';
String euro(num value) => '€${value.toStringAsFixed(2)}';
String _budgetEuro(num value) => value == value.roundToDouble()
    ? '€${value.toStringAsFixed(0)}'
    : euro(value);

Map<String, Object?> productFacts(Product product) => {
  'id': product.id,
  'name': product.name,
  'brand': product.brand,
  'description': product.description,
  'category': product.category.name,
  'subcategory': product.subcategory,
  'color': product.color,
  'material': product.material,
  'season': product.season,
  'occasion': product.occasion,
  'price_eur': product.price,
  'image_asset': product.imageAsset,
};

Map<String, Object?> _card(Product p, String tag) => {
  'id': p.id,
  'name': p.name,
  'price': _budgetEuro(p.price),
  'brandLine': p.brandLine,
  'tag': tag,
  'swatch': p.swatch,
  'imageAsset': p.imageAsset,
  'category': p.category.name,
};
Map<String, Object?> _path(String value) => {'path': value};

/// Provisional display only: it never updates the authoritative dressing room
/// and carries no action or model-authored product facts.
List<Map<String, Object?>> renderPendingStylistSurface({
  required String surfaceId,
  List<Product>? picks,
}) => [
  {
    'version': 'v0.9',
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': stylistCatalogId,
      'sendDataModel': true,
    },
  },
  {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': surfaceId,
      'components': [
        {
          'id': 'root',
          'component': 'StylistSection',
          'children': ['status', 'preview'],
        },
        {
          'id': 'status',
          'component': 'StylistMessage',
          'text': _path('/status'),
        },
        {
          'id': 'preview',
          'component': picks == null
              ? 'RecommendationSkeleton'
              : 'RecommendationPreview',
          if (picks != null) 'products': _path('/recommendations'),
        },
      ],
    },
  },
  {
    'version': 'v0.9',
    'updateDataModel': {
      'surfaceId': surfaceId,
      'value': {
        'status': picks == null
            ? 'Preparing your recommendations…'
            : 'Adding styling advice…',
        'recommendations': [
          for (final product in picks ?? const <Product>[])
            _card(
              product,
              product.occasion.isEmpty
                  ? product.category.name
                  : product.occasion,
            ),
        ],
      },
    },
  },
];
Map<String, Object?> _productComponent(
  Product product,
  int index,
  String collection,
  String prefix,
  String action,
) => {
  'id': '$prefix-$index',
  'component': 'ProductCard',
  for (final property in [
    'name',
    'price',
    'brandLine',
    'tag',
    'swatch',
    'imageAsset',
    'category',
  ])
    property: _path('/$collection/$index/$property'),
  'action': {
    'event': {
      'name': action,
      'context': {'productId': product.id},
    },
  },
};

/// Fixed, catalog-backed A2UI v0.9 envelopes; models choose IDs, never card facts.
List<Map<String, Object?>> renderStylistSurfaces({
  required int turn,
  required String reply,
  required List<Product> picks,
  required Map<String, Product> outfit,
  required double? budget,
  required String occasion,
  OutfitPlan? plan,
  ProductCategory? nextCategory,
  Map<String, Object?>? clarification,
  CityContext? cityContext,
  String? cityContextNotice,
  String city = '',
}) {
  final spent = outfit.values.fold<double>(0, (sum, p) => sum + p.price);
  final outfitPlan = plan ?? OutfitPlan.from(brief: occasion, outfit: outfit);
  final slots = outfitPlan.displaySlots;
  final next = nextCategory ?? outfitPlan.nextCategory;
  const slotLabels = {
    ProductCategory.dress: 'A dress',
    ProductCategory.top: 'A top',
    ProductCategory.bottom: 'Bottoms',
    ProductCategory.layer: 'A layer over it',
    ProductCategory.shoes: 'Shoes',
    ProductCategory.bag: 'A bag',
    ProductCategory.accessory: 'An accessory',
  };
  final dressingData = <String, Object?>{
    'title': 'Dressing room',
    'brief': occasion.isEmpty ? 'Build a look together' : occasion,
    'planCaption': '',
    'planComplete': outfitPlan.complete,
    'spent':
        '${_budgetEuro(spent)} spent —\u00a0'
        '${outfitPlan.filledCount} of ${outfitPlan.slots.length}',
    'left': budget == null
        ? 'Set a budget'
        : '${_budgetEuro((budget - spent).clamp(0, double.infinity))} left',
    'progress': budget == null || budget == 0
        ? 0.0
        : (spent / budget).clamp(0, 1),
    'slots': [
      for (final slot in slots)
        {
          'category': slot.name,
          'label': slotLabels[slot],
          'name': outfit[slot.name]?.name ?? '',
          'meta': outfit[slot.name] == null
              ? slot == next
                    ? 'Next piece'
                    : 'Not yet'
              : '${outfit[slot.name]!.brand} · ${euro(outfit[slot.name]!.price)}',
          'swatch': outfit[slot.name]?.swatch ?? '#e4e4e7',
          'imageAsset': outfit[slot.name]?.imageAsset ?? '',
          'state': outfit[slot.name] != null
              ? 'Filled'
              : slot == next
              ? 'Next'
              : 'Empty',
        },
    ],
  };
  final dressingComponents = <Map<String, Object?>>[
    {
      'id': 'root',
      'component': 'DressingRoom',
      for (final property in [
        'title',
        'brief',
        'spent',
        'left',
        'progress',
        'slots',
        'planCaption',
      ])
        property: _path('/$property'),
    },
  ];
  final inlineData = <String, Object?>{
    'message': reply,
    'eyebrow': picks.isEmpty ? 'Your stylist' : 'Catalog options',
    'recommendations': picks
        .map((p) => _card(p, p.occasion.isEmpty ? p.category.name : p.occasion))
        .toList(),
  };
  final inlineComponents = <Map<String, Object?>>[
    {
      'id': 'root',
      'component': 'StylistSection',
      'children': [
        'message',
        if (picks.isNotEmpty) 'eyebrow',
        if (picks.isNotEmpty) 'recommendations',
      ],
    },
    {'id': 'message', 'component': 'StylistMessage', 'text': _path('/message')},
    if (picks.isNotEmpty)
      {'id': 'eyebrow', 'component': 'Eyebrow', 'text': _path('/eyebrow')},
    if (picks.isNotEmpty)
      {
        'id': 'recommendations',
        'component': 'StylistSection',
        'spacing': 8,
        'compactCarousel': true,
        'children': [for (var i = 0; i < picks.length; i++) 'product-$i'],
      },
    for (var i = 0; i < picks.length; i++)
      _productComponent(
        picks[i],
        i,
        'recommendations',
        'product',
        'select_product',
      ),
  ];
  if (clarification != null) {
    final briefSurface = renderStylistBriefSurface(
      reply: reply,
      clarification: clarification,
    );
    inlineData
      ..clear()
      ..addAll(briefSurface.data);
    inlineComponents
      ..clear()
      ..addAll(briefSurface.components);
  }
  if (cityContext != null || cityContextNotice != null) {
    inlineData['cityLabel'] = cityContext?.label ?? city;
    inlineData['weather'] = cityContext?.weatherCard;
    inlineData['contextNotice'] = cityContextNotice ?? '';
    final rootChildren = List<String>.from(
      inlineComponents.first['children'] as List,
    );
    inlineComponents.first['children'] = rootChildren;
    rootChildren.insert(1, 'city-context');
    inlineComponents.addAll([
      {
        'id': 'city-context',
        'component': 'StylistSection',
        'spacing': 8,
        'children': [
          'city-location',
          cityContext != null ? 'city-weather' : 'city-context-notice',
        ],
      },
      {
        'id': 'city-location',
        'component': 'Eyebrow',
        'text': _path('/cityLabel'),
      },
      if (cityContext != null)
        {
          'id': 'city-weather',
          'component': 'TypicalWeather',
          for (final property in ['title', 'summary', 'disclaimer', 'days'])
            property: _path('/weather/$property'),
        }
      else
        {
          'id': 'city-context-notice',
          'component': 'StylistMessage',
          'text': _path('/contextNotice'),
        },
    ]);
  }
  Map<String, Object?> create(String id) => {
    'version': 'v0.9',
    'createSurface': {
      'surfaceId': id,
      'catalogId': stylistCatalogId,
      'sendDataModel': true,
    },
  };
  List<Map<String, Object?>> update(
    String id,
    List<Map<String, Object?>> components,
    Map<String, Object?> data,
  ) => [
    {
      'version': 'v0.9',
      'updateComponents': {'surfaceId': id, 'components': components},
    },
    {
      'version': 'v0.9',
      'updateDataModel': {'surfaceId': id, 'value': data},
    },
  ];
  return [
    if (turn == 1) create('dressing-room'),
    ...update('dressing-room', dressingComponents, dressingData),
    create('inline-$turn'),
    ...update('inline-$turn', inlineComponents, inlineData),
  ];
}
