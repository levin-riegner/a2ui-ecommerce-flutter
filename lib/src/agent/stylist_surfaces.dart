import '../data/models.dart';

const stylistCatalogId = 'com.example.a2ui_flutter_commerce/catalog';
String euro(num value) => '€${value.toStringAsFixed(2)}';

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
  'price': euro(p.price),
  'brandLine': p.brandLine,
  'tag': tag,
  'swatch': p.swatch,
  'imageAsset': p.imageAsset,
};
Map<String, Object?> _path(String value) => {'path': value};
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
}) {
  final spent = outfit.values.fold<double>(0, (sum, p) => sum + p.price);
  const slots = ['dress', 'layer', 'shoes', 'bag'];
  final extras = [
    'top',
    'bottom',
    'accessory',
  ].where(outfit.containsKey).map((slot) => '$slot: ${outfit[slot]!.name}');
  final dressingData = <String, Object?>{
    'title': 'Your dressing room',
    'brief': [
      occasion.isEmpty ? 'Build a look together' : occasion,
      ...extras,
    ].join(' · '),
    'spent': '${euro(spent)} spent · ${outfit.length} pieces',
    'left': budget == null
        ? 'Set a budget'
        : '${euro((budget - spent).clamp(0, double.infinity))} left',
    'progress': budget == null || budget == 0
        ? 0.0
        : (spent / budget).clamp(0, 1),
    for (final slot in slots) ...{
      '${slot}Name': outfit[slot]?.name ?? '',
      '${slot}Meta': outfit[slot] == null
          ? 'Not yet'
          : '${outfit[slot]!.brand} · ${euro(outfit[slot]!.price)}',
      '${slot}Swatch': outfit[slot]?.swatch ?? '#e4e4e7',
      '${slot}ImageAsset': outfit[slot]?.imageAsset ?? '',
    },
  };
  final dressingComponents = <Map<String, Object?>>[
    {
      'id': 'root',
      'component': 'DressingRoom',
      for (final property in ['title', 'brief', 'spent', 'left', 'progress'])
        property: _path('/$property'),
      for (final slot in slots)
        for (final suffix in ['Name', 'Meta', 'Swatch', 'ImageAsset'])
          '$slot$suffix': _path('/$slot$suffix'),
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
      'component': 'Column',
      'align': 'stretch',
      'children': [
        'message',
        if (picks.isNotEmpty) 'eyebrow',
        for (var i = 0; i < picks.length; i++) 'product-$i',
      ],
    },
    {'id': 'message', 'component': 'StylistMessage', 'text': _path('/message')},
    if (picks.isNotEmpty)
      {'id': 'eyebrow', 'component': 'Eyebrow', 'text': _path('/eyebrow')},
    for (var i = 0; i < picks.length; i++)
      _productComponent(
        picks[i],
        i,
        'recommendations',
        'product',
        'select_product',
      ),
  ];
  final selected = outfit.entries.toList();
  final selectedData = <String, Object?>{
    'message': selected.isEmpty
        ? 'No pieces selected yet.'
        : 'Selected pieces · tap a card to remove it',
    'products': selected.map((entry) => _card(entry.value, entry.key)).toList(),
  };
  final selectedComponents = <Map<String, Object?>>[
    {
      'id': 'root',
      'component': 'Column',
      'align': 'stretch',
      'children': [
        'message',
        for (var i = 0; i < selected.length; i++) 'selected-$i',
      ],
    },
    {'id': 'message', 'component': 'StylistMessage', 'text': _path('/message')},
    for (var i = 0; i < selected.length; i++)
      _productComponent(
        selected[i].value,
        i,
        'products',
        'selected',
        'remove_product',
      ),
  ];
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
    if (turn == 1) create('selected-products'),
    ...update('selected-products', selectedComponents, selectedData),
  ];
}
