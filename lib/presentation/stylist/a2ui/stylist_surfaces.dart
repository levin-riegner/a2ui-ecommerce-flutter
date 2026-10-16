import '../../../data/catalog/model/models.dart';
import '../../../data/catalog/model/catalog_semantics.dart';
import '../../../data/catalog/model/money.dart';
import '../../../data/stylist/model/outfit_plan.dart';
import '../../../data/weather/model/city_context.dart';
import 'stylist_brief_surface.dart';

const stylistCatalogId = 'com.example.a2ui_flutter_commerce/catalog';
String formatEuros(num value) => '€${value.toStringAsFixed(2)}';
String _budgetEuro(num value) => value == value.roundToDouble()
    ? '€${value.toStringAsFixed(0)}'
    : formatEuros(value);

Map<String, Object?> _card(Product p, String tag) => {
  'id': p.id,
  'name': p.name,
  'price': _budgetEuro(p.price),
  'brandLine': p.brandLine,
  'tag': tag,
  'swatch': p.swatch,
  'imageAsset': p.imageAsset,
  'category': p.category.name,
  'selected': false,
  'dimmed': false,
};
Map<String, Object?> _path(String value) => {'path': value};
Map<String, Object?> _eventAction(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'event': {'name': name, 'context': context},
};
Map<String, Object?> _selectionAction([String? productId]) => {
  'event': {
    'name': 'select_product',
    'context': {'productId': ?productId},
  },
};

/// Collapses an accepted shortlist to a receipt using authoritative facts.
Map<String, Object?> selectedRecommendationComponent(Product product) => {
  ..._card(
    product,
    product.occasion.isEmpty ? product.category.name : product.occasion,
  ),
  'id': 'recommendations',
  'component': 'ProductCard',
  'selected': true,
  'action': _selectionAction(product.id),
};

Map<String, Object?> productChoice(Product product) => {
  'productId': product.id,
  'name': product.name,
  'label': '${product.name} · ${formatEuros(product.price)}',
  'price': formatEuros(product.price),
  'category': product.category.name,
  'imageAsset': product.imageAsset,
  'swatch': product.swatch,
};

/// Provisional display only: it never updates the authoritative dressing room
/// and carries no action or model-authored product facts.
List<Map<String, Object?>> renderPendingStylistSurface({
  required String surfaceId,
  String? text,
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
          'children': [if (text?.isNotEmpty == true) 'message'],
        },
        {
          'id': 'message',
          'component': 'StylistMessage',
          'text': _path('/reply'),
        },
      ],
    },
  },
  {
    'version': 'v0.9',
    'updateDataModel': {
      'surfaceId': surfaceId,
      'value': {'reply': text ?? ''},
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
    'selected',
    'dimmed',
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
  Map<String, Object?>? budgetAdjustment,
  CityContext? cityContext,
  String? cityContextNotice,
  String city = '',
  String presentation = 'cards',
  Product? adjusting,
  List<String> adjustmentOptions = const ['Something similar'],
  String adjustmentSelected = '',
  Map<String, Object?>? preferences,
  bool canEditPreferences = false,
  Set<ProductCategory> ownedCategories = const {},
  bool showCompletion = true,
  bool changeDirection = false,
  Map<String, Object?>? library,
  bool inspectProducts = false,
  Map<String, Object?>? productDetails,
  Map<String, Object?>? selectionOptions,
}) {
  final spent = sumEuros(outfit.values.map((p) => p.price));
  final outfitPlan = plan ?? OutfitPlan.from(brief: occasion, outfit: outfit);
  final slots = outfitPlan.displaySlots;
  final next = nextCategory ?? outfitPlan.nextCategory;
  final slotLabels = {
    ProductCategory.dress:
        outfit['dress'] != null &&
            catalogGarmentType(outfit['dress']!) != 'dress'
        ? 'A one-piece'
        : 'A dress',
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
        : '${_budgetEuro(subtractEuros(budget, spent).clamp(0, double.infinity))} left',
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
              : '${outfit[slot.name]!.brand} · ${formatEuros(outfit[slot.name]!.price)}',
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
      'changeAction': _eventAction('adjust_piece'),
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
    'selectedProductId': '',
    'selectionOptions': ?selectionOptions,
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
  if (picks.isNotEmpty &&
      (presentation == 'compare' && picks.length == 2 ||
          presentation == 'strip' ||
          presentation == 'alternative' && picks.length == 1)) {
    inlineComponents.removeWhere(
      (c) => c['id'] == 'recommendations' || c['component'] == 'ProductCard',
    );
    inlineData['choices'] = picks.map(productChoice).toList();
    if (presentation == 'compare') {
      inlineComponents.add({
        'id': 'recommendations',
        'component': 'ThisOrThat',
        'options': _path('/choices'),
        'question': 'Which works better for you?',
        'picked': _path('/selectedProductId'),
        'action': _selectionAction(),
      });
    } else if (presentation == 'alternative') {
      final product = picks.single;
      final saving = adjusting == null ? 0.0 : adjusting.price - product.price;
      inlineComponents.add({
        'id': 'recommendations',
        'component': 'AlternativePiece',
        'title': saving > 0
            ? 'Save ${formatEuros(saving)} with this replacement'
            : 'A replacement option',
        'productId': product.id,
        'category': product.category.name,
        'name': product.name,
        'meta': '${product.brand} · ${formatEuros(product.price)}',
        'imageAsset': product.imageAsset,
        'swatch': product.swatch,
        'action': _selectionAction(product.id),
      });
    } else {
      inlineComponents.add({
        'id': 'recommendations',
        'component': 'PicksStrip',
        'products': _path('/choices'),
        'category': picks.first.category.name,
        'selectedProductId': _path('/selectedProductId'),
        'action': _selectionAction(),
      });
    }
  }
  if (clarification == null && adjusting != null) {
    inlineData['adjustment'] = {
      'productId': adjusting.id,
      'productName': adjusting.name,
      'category': adjusting.category.name,
      'imageAsset': adjusting.imageAsset,
    };
    (inlineComponents.first['children'] as List).insert(1, 'quick-adjust');
    inlineComponents.add({
      'id': 'quick-adjust',
      'component': 'QuickAdjust',
      for (final key in ['productId', 'productName', 'category', 'imageAsset'])
        key: _path('/adjustment/$key'),
      'options': adjustmentOptions,
      'selected': adjustmentSelected,
      'action': {
        'event': {'name': 'adjust_piece', 'context': <String, Object?>{}},
      },
    });
  }
  if (clarification == null && preferences != null) {
    inlineData.addAll({
      'preferenceScope': preferences['scope'],
      'paletteOptions': preferences['options'],
      'preferredColours': preferences['colours'],
      'catalogBrands': preferences['brands'],
      'lovedBrands': preferences['love'],
      'skippedBrands': preferences['skip'],
      'ownedPieces': preferences['owned'],
      if (preferences['tripStart'] != '') 'tripStart': preferences['tripStart'],
      if (preferences['tripEnd'] != '') 'tripEnd': preferences['tripEnd'],
    });
    (inlineComponents.first['children'] as List).add('preferences');
    inlineComponents.addAll([
      {
        'id': 'preferences',
        'component': 'StylistSection',
        'children': [
          'preference-scope',
          'palette',
          'brands',
          'owned-label',
          for (final c in ProductCategory.values) 'owned-${c.name}',
          if (preferences['showDates'] == true) ...[
            'trip-start',
            'trip-end',
            'clear-trip',
          ],
          'update-preferences',
        ],
      },
      {
        'id': 'preference-scope',
        'component': 'Eyebrow',
        'text': _path('/preferenceScope'),
      },
      {
        'id': 'palette',
        'component': 'ColourPicker',
        'options': _path('/paletteOptions'),
        'selected': _path('/preferredColours'),
        'selectedPath': '/preferredColours',
        'question': 'Colors you prefer — these rank options; your hard restrictions stay in place.',
      },
      {
        'id': 'brands',
        'component': 'BrandPreferences',
        'brands': _path('/catalogBrands'),
        'love': _path('/lovedBrands'),
        'skip': _path('/skippedBrands'),
        'allowCustomBrands': false,
        'lovePath': '/lovedBrands',
        'skipPath': '/skippedBrands',
      },
      {
        'id': 'owned-label',
        'component': 'Eyebrow',
        'text': 'Use pieces you already own',
      },
      for (final c in ProductCategory.values)
        {
          'id': 'owned-${c.name}',
          'component': 'ChoiceChip',
          'label': c == ProductCategory.dress
              ? 'One-piece'
              : displayDetail(c.name),
          'selected': _path('/ownedPieces/${c.name}'),
        },
      {
        'id': 'update-preferences',
        'component': 'PrimaryButton',
        'label': 'Update preferences',
        'action': {
          'event': {
            'name': 'update_preferences',
            'context': {
              'colours': _path('/preferredColours'),
              'love': _path('/lovedBrands'),
              'skip': _path('/skippedBrands'),
              'owned': _path('/ownedPieces'),
              if (preferences['showDates'] == true) ...{
                'tripStart': _path('/tripStart'),
                'tripEnd': _path('/tripEnd'),
              },
            },
          },
        },
      },
      if (preferences['showDates'] == true) ...[
        {
          'id': 'trip-start',
          'component': 'DateTimeInput',
          'label': 'Trip start',
          'variant': 'date',
          'value': _path('/tripStart'),
        },
        {
          'id': 'trip-end',
          'component': 'DateTimeInput',
          'label': 'Trip end',
          'variant': 'date',
          'value': _path('/tripEnd'),
        },
        {
          'id': 'clear-trip',
          'component': 'PrimaryButton',
          'label': 'Clear trip dates',
          'action': {
            'event': {
              'name': 'update_preferences',
              'context': {'tripStart': '', 'tripEnd': ''},
            },
          },
        },
      ],
    ]);
  } else if (clarification == null && canEditPreferences) {
    (inlineComponents.first['children'] as List).add('edit-preferences');
    inlineComponents.add({
      'id': 'edit-preferences',
      'component': 'PrimaryButton',
      'label': city.isNotEmpty
          ? 'Preferences & trip dates'
          : 'Colors, brands & owned pieces',
      'action': {
        'event': {'name': 'edit_preferences', 'context': <String, Object?>{}},
      },
    });
  }
  if (clarification == null && outfitPlan.complete && showCompletion) {
    inlineData['look'] = {
      'name': 'Your look',
      'meta':
          '${outfit.length} catalog pieces · ${formatEuros(spent)}'
          '${ownedCategories.isEmpty ? '' : ' · Owned: ${ownedCategories.map((c) => c == ProductCategory.dress ? 'one-piece' : c.name).join(', ')}'}',
      'pieces': [
        for (final product in outfit.values)
          {
            'id': product.id,
            'category': product.category.name,
            'name': product.name,
            'meta': '${product.brand} · ${formatEuros(product.price)}',
            'imageAsset': product.imageAsset,
            'swatch': product.swatch,
          },
      ],
    };
    (inlineComponents.first['children'] as List).addAll(<String>[
      if (outfit.isNotEmpty) 'completed-look',
      'look-summary',
    ]);
    inlineComponents.addAll([
      if (outfit.isNotEmpty)
        {
          'id': 'completed-look',
          'component': 'Look',
          'base': outfit.containsKey('dress') ? 'Dress' : 'Separates',
          'pieces': _path('/look/pieces'),
        },
      {
        'id': 'look-summary',
        'component': 'LookSummary',
        'name': _path('/look/name'),
        'meta': _path('/look/meta'),
        'pieces': _path('/look/pieces'),
        if (library != null) ...{
          'saveAction': _eventAction('save_look'),
          'resetAction': _eventAction('reset_look'),
        },
      },
    ]);
    if (library != null && outfit.isNotEmpty) {
      (inlineComponents.first['children'] as List).add('add-look-to-bag');
      inlineComponents.add({
        'id': 'add-look-to-bag',
        'component': 'AddToBagButton',
        'state': library['lookInBag'] == true ? 'Added' : 'Default',
        'label': library['lookInBag'] == true
            ? 'These pieces are in your demo bag'
            : 'Add look to demo bag · ${formatEuros(spent)}',
        'total': formatEuros(spent),
        'pieceCount': outfit.length,
        'action': _eventAction('add_look_to_bag'),
      });
    }
  }

  if (clarification == null &&
      presentation == 'cards' &&
      picks.length == 2 &&
      picks.first.category == picks.last.category) {
    (inlineComponents.first['children'] as List).add('compare-options');
    inlineComponents.add({
      'id': 'compare-options',
      'component': 'PrimaryButton',
      'label': 'Compare these two',
      'action': {
        'event': {'name': 'compare_products', 'context': <String, Object?>{}},
      },
    });
  }
  if (changeDirection) {
    final ids = <String>[];
    for (final entry in outfit.entries) {
      final id = 'change-${entry.key}';
      ids.add(id);
      inlineComponents.add({
        'id': id,
        'component': 'ChoiceChip',
        'label': 'Change ${entry.value.name}',
        'action': _eventAction('adjust_piece', {'category': entry.key}),
      });
    }
    ids.add('restart-chat');
    inlineComponents.add({
      'id': 'restart-chat',
      'component': 'ChoiceChip',
      'label': 'Start a new look',
      'action': _eventAction('reset_look'),
    });
    (inlineComponents.first['children'] as List).addAll(ids);
  }
  if (inspectProducts &&
      clarification == null &&
      productDetails == null &&
      selectionOptions == null &&
      !changeDirection) {
    for (final p in {
      for (final p in [...outfit.values, ...picks]) p.id: p,
    }.values) {
      final id = 'details-${p.id}';
      (inlineComponents.first['children'] as List).add(id);
      inlineComponents.add({
        'id': id,
        'component': 'PrimaryButton',
        'label': 'Details & sizes · ${p.name}',
        'action': _eventAction('open_product_details', {'productId': p.id}),
      });
    }
  }
  if (selectionOptions != null) {
    final choices = (selectionOptions['choices'] as List).cast<Map>();
    final selected = choices.first;
    final sizes = List<String>.from(selected['sizes'] as List);
    final preferred = selected['size'] as String;
    inlineData['selectionOptions'] = {
      ...selectionOptions,
      'submitting': false,
      'size': sizes.contains(preferred)
          ? preferred
          : sizes.length == 1
          ? sizes.single
          : '',
      'selectedColours': [displayDetail(selected['colour'] as String)],
      'sizes': sizes,
      'canSave':
          sizes.contains(preferred) &&
          ((selectionOptions['fits'] as List).isEmpty ||
              (selectionOptions['fits'] as List).contains(
                selectionOptions['fit'],
              )),
    };
    // Reuse the catalog's selectors in the conversation, before the next set
    // of recommendations. Colour changes request the linked row's own sizes.
    (inlineComponents.first['children'] as List).insert(1, 'selection-options');
    inlineComponents.addAll([
      {
        'id': 'selection-options',
        'component': 'StylistSection',
        'collapsed': _path('/selectionOptions/submitting'),
        'children': [
          if (choices.length > 1) 'selection-colour',
          'selection-fit',
          'selection-save',
        ],
      },
      if (choices.length > 1)
        {
          'id': 'selection-colour',
          'component': 'ColourPicker',
          'question': 'Choose your colour.',
          'singleSelect': true,
          'options': [
            for (final choice in choices)
              {
                'name': displayDetail(choice['colour'] as String),
                'hex': choice['swatch'],
              },
          ],
          'selected': _path('/selectionOptions/selectedColours'),
          'selectedPath': '/selectionOptions/selectedColours',
          'action': _eventAction('choose_product_colour', {
            'productId': selectionOptions['productId'],
          }),
        },
      {
        'id': 'selection-fit',
        'component': 'FitSize',
        'sizes': _path('/selectionOptions/sizes'),
        'fits': _path('/selectionOptions/fits'),
        'size': _path('/selectionOptions/size'),
        'fit': _path('/selectionOptions/fit'),
        'sizePath': '/selectionOptions/size',
        'fitPath': '/selectionOptions/fit',
        'canSavePath': '/selectionOptions/canSave',
        'sizeLabel': 'SIZE',
        // The conversation already asks this; the form owns only the controls.
        'question': '',
      },
      {
        'id': 'selection-save',
        'component': 'PrimaryButton',
        'enabled': _path('/selectionOptions/canSave'),
        'label': _path('/selectionOptions/saveLabel'),
        'action': _eventAction('set_product_options', {
          'productId': selectionOptions['productId'],
          'colourProductId': selected['id'],
          'size': _path('/selectionOptions/size'),
          'fit': _path('/selectionOptions/fit'),
        }),
      },
    ]);
  }
  if (productDetails != null) {
    inlineData['productDetails'] = productDetails;
    (inlineComponents.first['children'] as List).add('product-details');
    inlineComponents.add({
      'id': 'product-details',
      'component': 'StylistSection',
      'children': ['detail-fit', 'apply-demo-size'],
    });
    inlineComponents.addAll([
      {
        'id': 'detail-fit',
        'component': 'FitSize',
        'sizes': _path('/productDetails/sizes'),
        'fits': _path('/productDetails/fits'),
        'size': _path('/productDetails/size'),
        'fit': _path('/productDetails/fit'),
        'sizePath': '/productDetails/size',
        'fitPath': '/productDetails/fit',
        'canSavePath': '/productDetails/canSave',
        'sizeLabel': 'SIZE',
        'question': _path('/productDetails/question'),
      },
      {
        'id': 'apply-demo-size',
        'component': 'PrimaryButton',
        'enabled': _path('/productDetails/canSave'),
        'label': _path('/productDetails/saveLabel'),
        'action': _eventAction('set_fit_size', {
          'productId': productDetails['id'],
          'size': _path('/productDetails/size'),
          'fit': _path('/productDetails/fit'),
        }),
      },
    ]);
  }
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
    rootChildren.insert(0, 'city-context');
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
  if (clarification == null && budgetAdjustment != null) {
    final controls = renderStylistBriefSurface(
      reply: '',
      clarification: budgetAdjustment,
    );
    inlineData.addAll({
      for (final entry in controls.data.entries)
        if (entry.key != 'message') entry.key: entry.value,
    });
    (inlineComponents.first['children'] as List).add('brief-controls');
    inlineComponents.addAll(
      controls.components.where(
        (component) =>
            component['id'] != 'root' && component['id'] != 'message',
      ),
    );
  }
  if (library != null) {
    (inlineComponents.first['children'] as List).add('local-library');
    inlineComponents.add({
      'id': 'local-library',
      'component': 'StylistSection',
      'children': ['saved-looks-button', 'bag-button'],
    });
    inlineComponents.addAll([
      {
        'id': 'saved-looks-button',
        'component': 'PrimaryButton',
        'label': library['persistent'] == true
            ? 'Saved looks'
            : 'Session looks',
        'action': _eventAction('open_saved_looks'),
      },
      {
        'id': 'bag-button',
        'component': 'PrimaryButton',
        'label': 'Demo bag (${library['bagCount']})',
        'action': _eventAction('open_bag'),
      },
    ]);
    if (library['showLooks'] == true) {
      final looks = (library['looks'] as List).cast<Map>();
      inlineData['savedLooks'] = looks;
      (inlineComponents.first['children'] as List).add('saved-looks');
      inlineComponents.add({
        'id': 'saved-looks',
        'component': 'SavedLooksRail',
        'title': library['persistent'] == true
            ? 'Saved on this device'
            : 'Looks for this session',
        'selectedId': library['selectedId'],
        'looks': _path('/savedLooks'),
        'action': _eventAction('restore_look'),
      });
      for (var i = 0; i < looks.length; i++) {
        (inlineComponents.first['children'] as List).add('delete-look-$i');
        inlineComponents.add({
          'id': 'delete-look-$i',
          'component': 'PrimaryButton',
          'label': 'Delete ${looks[i]['label']}',
          'action': _eventAction('delete_look', {'lookId': looks[i]['id']}),
        });
      }
    }
    if (library['showBag'] == true) {
      inlineData['bagItems'] = library['bagItems'];
      (inlineComponents.first['children'] as List).add('demo-bag');
      inlineComponents.add({
        'id': 'demo-bag',
        'component': 'BagPreview',
        'mode': 'demo-host',
        'items': _path('/bagItems'),
        'closeAction': _eventAction('close_bag'),
        'removeAction': _eventAction('remove_bag_item'),
        'restoreAction': _eventAction('restore_bag_item'),
        'quantityAction': _eventAction('change_bag_quantity'),
        'sizeAction': _eventAction('open_product_details'),
        'checkoutAction': _eventAction('preview_demo_checkout'),
      });
      for (final item in library['bagItems'] as List) {
        final id = 'bag-size-${item['id']}';
        (inlineComponents.first['children'] as List).add(id);
        inlineComponents.add({
          'id': id,
          'component': 'PrimaryButton',
          'label':
              '${item['size'] == '' ? 'Choose' : 'Change'} size · ${item['name']}',
          'action': _eventAction('open_product_details', {
            'productId': item['id'],
          }),
        });
      }
      if (library['delivery'] case final Map delivery) {
        (inlineComponents.first['children'] as List).addAll(<String>[
          'demo-delivery',
          'preview-demo-checkout',
        ]);
        inlineComponents.addAll([
          {
            'id': 'demo-delivery',
            'component': 'DeliveryEstimate',
            'headline':
                'Demo delivery: ${delivery['earliestDate']}–${delivery['latestDate']}',
            'detail':
                '${delivery['origin']} → ${delivery['destination']} · ${delivery['service']}. ${delivery['disclaimer']}',
          },
          {
            'id': 'preview-demo-checkout',
            'component': 'PrimaryButton',
            'label': 'Preview demo checkout',
            'action': _eventAction('preview_demo_checkout'),
          },
        ]);
      }
    }
    if (productDetails == null &&
        selectionOptions == null &&
        outfitPlan.complete &&
        picks.isEmpty &&
        !changeDirection &&
        outfit.isNotEmpty &&
        library['showBag'] != true &&
        library['checkout'] == null &&
        library['receipt'] == null) {
      inlineData['fitPieces'] = library['fitPieces'];
      (inlineComponents.first['children'] as List).add('fit-notes');
      inlineComponents.add({
        'id': 'fit-notes',
        'component': 'FitNotes',
        'title': 'Your selected sizes',
        'pieces': _path('/fitPieces'),
        'action': _eventAction('open_product_details'),
      });
    }
    if (library['checkout'] case final Map quote) {
      (inlineComponents.first['children'] as List).addAll(<String>[
        'checkout-summary',
        'checkout-delivery',
        'confirm-demo-checkout',
        'checkout-back',
      ]);
      final lines = quote['lines'] as List;
      inlineComponents.addAll([
        {
          'id': 'checkout-summary',
          'component': 'StylistMessage',
          'text':
              'LOCAL DEMO CHECKOUT\n${lines.map((line) => '${line['name']} · ${line['size']} × ${line['quantity']}').join('\n')}\nSubtotal: ${formatEuros((quote['subtotalCents'] as int) / 100)}\nDemo shipping: ${formatEuros((quote['shippingCents'] as int) / 100)}\nDemo tax: €0.00 (fictional)\nDemo total: ${formatEuros((quote['totalCents'] as int) / 100)}\nNo payment details, real order or shipment.',
        },
        {
          'id': 'checkout-delivery',
          'component': 'DeliveryEstimate',
          'headline':
              'Fictional arrival ${quote['delivery']['earliestDate']}–${quote['delivery']['latestDate']}',
          'detail': quote['delivery']['disclaimer'],
        },
        {
          'id': 'confirm-demo-checkout',
          'component': 'PrimaryButton',
          'label': 'Complete demo checkout — no payment',
          'action': _eventAction('confirm_demo_checkout', {
            'quoteKey': quote['key'],
          }),
        },
        {
          'id': 'checkout-back',
          'component': 'PrimaryButton',
          'label': 'Back to demo bag',
          'action': _eventAction('open_bag'),
        },
      ]);
    }
    if (library['receipt'] case final Map receipt) {
      (inlineComponents.first['children'] as List).add('demo-receipt');
      inlineData['demoReceipt'] = receipt;
      inlineComponents.add({
        'id': 'demo-receipt',
        'component': 'StylistMessage',
        'text':
            'SIMULATED RECEIPT · ${receipt['id']}\n${(receipt['lines'] as List).map((line) => '${line['name']} · ${line['size']} × ${line['quantity']}').join('\n')}\nDemo total: ${formatEuros((receipt['totalCents'] as int) / 100)}\nNo payment taken, real order placed or shipment booked.',
      });
    }
    if (library['hasReceipt'] == true) {
      (inlineComponents.first['children'] as List).add('view-demo-receipt');
      inlineComponents.add({
        'id': 'view-demo-receipt',
        'component': 'PrimaryButton',
        'label': 'View last demo receipt',
        'action': _eventAction('open_demo_receipt'),
      });
    }
    if (library['toast'] case final Map toast) {
      (inlineComponents.first['children'] as List).add('library-toast');
      inlineComponents.add({
        'id': 'library-toast',
        'component': 'Toast',
        'message': toast['message'],
        'actionLabel': toast['label'],
        'action': _eventAction(
          toast['action'] as String,
          Map<String, Object?>.from(toast['context'] as Map),
        ),
      });
    }
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
