import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../catalog/commerce_catalog.dart';
import '../data/models.dart';
import '../data/product_repository.dart';

class StubAgent extends ChangeNotifier {
  StubAgent({ProductRepository? repository})
    : repository = repository ?? const FixtureProductRepository(),
      catalog = buildCommerceCatalog() {
    controller = SurfaceController(catalogs: [catalog]);
    transport = A2uiTransportAdapter(onSend: _handleSend);
    conversation = Conversation(controller: controller, transport: transport);
  }

  final ProductRepository repository;
  final Catalog catalog;
  late final SurfaceController controller;
  late final A2uiTransportAdapter transport;
  late final Conversation conversation;

  DemoJourney? activeJourney;
  String? latestInlineSurfaceId;
  bool _hasStarted = false;
  int _turn = 0;
  List<Product> _currentRecommendations = const [];
  _AgentStage _stage = _AgentStage.brief;
  Product? _selectedFoundation;

  bool get hasStarted => _hasStarted;

  bool get isBrief => _stage == _AgentStage.brief;

  Future<void> startJourney(DemoJourney journey) async {
    _turn = 0;
    _selectedShoes = null;
    _selectedFoundation = null;
    _stage = _AgentStage.brief;
    activeJourney = journey;
    _hasStarted = true;
    latestInlineSurfaceId = null;
    notifyListeners();

    await _createOrReplaceSurface(
      surfaceId: 'dressing-room',
      components: _dressingRoomComponents(),
      data: _dressingRoomData(showDress: false),
    );
    await _createOrReplaceSurface(
      surfaceId: 'inline-$_turn',
      components: _briefComponents(),
      data: _briefData(),
    );
  }

  Future<void> _handleSend(ChatMessage message) async {
    if (activeJourney == null) return;

    if (_stage == _AgentStage.brief) {
      _stage = _AgentStage.picks;
      final foundation = await repository.recommendations(
        journey: activeJourney!,
        category: activeJourney!.foundationCategory,
        limit: 1,
      );
      _selectedFoundation = foundation.isEmpty ? null : foundation.first;
      final products = await repository.recommendations(
        journey: activeJourney!,
        category: ProductCategory.shoes,
      );
      _currentRecommendations = products;
      await _updateSurface(
        surfaceId: 'dressing-room',
        data: _dressingRoomData(showDress: true),
      );
      await _createOrReplaceSurface(
        surfaceId: 'inline-${++_turn}',
        components: _recommendationComponents(),
        data: _inlineData(products),
      );
      return;
    }

    _turn += 1;
    final action = _actionFrom(message);
    final selectedId = action?['context'] is Map
        ? (action?['context'] as Map)['productId'] as String?
        : null;
    Product? selected;
    if (selectedId != null) {
      for (final product in _currentRecommendations) {
        if (product.id == selectedId) {
          selected = product;
          break;
        }
      }
    }
    if (selected != null) {
      _selectedShoes = selected;
    }

    final nextProducts = await repository.recommendations(
      journey: activeJourney!,
      category: ProductCategory.shoes,
    );
    _currentRecommendations = nextProducts;
    await _updateSurface(
      surfaceId: 'dressing-room',
      data: _dressingRoomData(showDress: true),
    );
    await _createOrReplaceSurface(
      surfaceId: 'inline-$_turn',
      components: _completionComponents(),
      data: _inlineData(nextProducts, completed: true),
    );
  }

  Product? _selectedShoes;

  Map<String, Object?>? _actionFrom(ChatMessage message) {
    for (final part in message.parts.uiInteractionParts) {
      final payload = jsonDecode(part.interaction);
      if (payload is! Map || payload['action'] is! Map) continue;
      return Map<String, Object?>.from(payload['action'] as Map);
    }
    return null;
  }

  Future<void> _createOrReplaceSurface({
    required String surfaceId,
    required List<Map<String, dynamic>> components,
    required Map<String, Object?> data,
  }) async {
    transport.addMessage(
      core.CreateSurfaceMessage(
        surfaceId: surfaceId,
        catalogId: commerceCatalogId,
        sendDataModel: true,
      ),
    );
    transport.addMessage(
      core.UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: components,
      ),
    );
    transport.addMessage(
      core.UpdateDataModelMessage(surfaceId: surfaceId, value: data),
    );
    // A2uiTransportAdapter delivers messages through a broadcast stream. Let
    // the controller consume the batch before exposing the surface ID to the
    // host shell.
    await Future<void>.delayed(Duration.zero);
    if (surfaceId.startsWith('inline-')) {
      latestInlineSurfaceId = surfaceId;
      notifyListeners();
    }
  }

  Future<void> _updateSurface({
    required String surfaceId,
    required Map<String, Object?> data,
  }) async {
    transport.addMessage(
      core.UpdateDataModelMessage(surfaceId: surfaceId, value: data),
    );
  }

  Map<String, Object?> _inlineData(
    List<Product> products, {
    bool completed = false,
  }) {
    return {
      'message': completed
          ? 'That pair keeps the look refined without competing with the main piece. The dressing room is now ready for a real data connection.'
          : _picksMessage(),
      'eyebrow': completed ? 'Complete look' : _picksEyebrow(),
      'recommendations': [
        for (final product in products)
          {
            'id': product.id,
            'name': product.name,
            'price': product.priceLabel,
            'brandLine': product.brandLine,
            'tag': product.tag,
            'swatch': product.swatch,
          },
      ],
    };
  }

  String _picksMessage() {
    final foundation = _selectedFoundation;
    if (foundation == null) {
      return 'I have a few options ready. Pick the one that feels most like you, and I will keep the dressing room in sync.';
    }
    final remaining = activeJourney!.budget - foundation.price;
    final remainingLabel = '€${remaining.toStringAsFixed(0)}';
    if (activeJourney == DemoJourney.paris) {
      return 'Lovely — the ${foundation.brand} is the most formal of the three and leaves you $remainingLabel. Shoes next: I’d keep them refined and let the main piece do the talking.';
    }
    return 'The ${foundation.name} gives us a strong foundation and leaves you $remainingLabel. Shoes next: choose the pair that feels most like you.';
  }

  String _picksEyebrow() {
    final remaining = activeJourney!.budget - (_selectedFoundation?.price ?? 0);
    return 'Shoes · ${activeJourney!.season.toLowerCase()} · under €${remaining.toStringAsFixed(0)}';
  }

  Map<String, Object?> _briefData() {
    final journey = activeJourney!;
    return {
      'message': journey == DemoJourney.paris
          ? 'Perfect — an anniversary in Paris in October. I’d go elegant, with the option to take it all the way to black tie. Two quick things and I’ll pull options for you.'
          : 'Perfect — let’s build something for ${journey.title.toLowerCase()}. Two quick things and I’ll pull options for you.',
      'occasion': journey.occasion,
      'formality': journey == DemoJourney.paris ? 'Black tie' : 'Smart elegant',
      'season': journey.season,
      'budget': journey.budget,
    };
  }

  Map<String, Object?> _dressingRoomData({required bool showDress}) {
    final journey = activeJourney!;
    final foundation = showDress ? _selectedFoundation : null;
    final dress = foundation?.category == ProductCategory.dress
        ? foundation
        : null;
    final layer = foundation?.category == ProductCategory.layer
        ? foundation
        : null;
    final pieces = [
      if (foundation != null) foundation.price,
      if (_selectedShoes != null) _selectedShoes!.price,
    ];
    final spent = pieces.fold<double>(0, (total, item) => total + item);
    final left = journey.budget - spent;
    return {
      'title': journey.title,
      'brief': journey.brief,
      'spent':
          '€${spent.toStringAsFixed(0)} spent · ${foundation == null ? 0 : 1 + (_selectedShoes == null ? 0 : 1)} of 4',
      'left': '€${left.toStringAsFixed(0)} left',
      'progress': (spent / journey.budget).clamp(0, 1),
      'dressName': dress?.name ?? '',
      'dressMeta': dress == null
          ? 'Choosing on the left'
          : '${dress.brand} · ${dress.priceLabel}',
      'dressSwatch': dress?.swatch ?? '#f4f4f5',
      'layerName': layer?.name ?? '',
      'layerMeta': layer == null
          ? 'Not yet'
          : '${layer.brand} · ${layer.priceLabel}',
      'layerSwatch': layer?.swatch ?? '#f4f4f5',
      'shoesName': _selectedShoes?.name ?? '',
      'shoesMeta': _selectedShoes == null
          ? showDress
                ? 'Choosing on the left'
                : 'Not yet'
          : '${_selectedShoes!.brand} · ${_selectedShoes!.priceLabel}',
      'shoesSwatch': _selectedShoes?.swatch ?? '#f4f4f5',
      'bagName': '',
      'bagMeta': 'Not yet',
      'bagSwatch': '#f4f4f5',
    };
  }

  List<Map<String, dynamic>> _dressingRoomComponents() => const [
    {
      'id': 'root',
      'component': 'DressingRoom',
      'title': {'path': '/title'},
      'brief': {'path': '/brief'},
      'spent': {'path': '/spent'},
      'left': {'path': '/left'},
      'progress': {'path': '/progress'},
      'dressName': {'path': '/dressName'},
      'dressMeta': {'path': '/dressMeta'},
      'dressSwatch': {'path': '/dressSwatch'},
      'layerName': {'path': '/layerName'},
      'layerMeta': {'path': '/layerMeta'},
      'layerSwatch': {'path': '/layerSwatch'},
      'shoesName': {'path': '/shoesName'},
      'shoesMeta': {'path': '/shoesMeta'},
      'shoesSwatch': {'path': '/shoesSwatch'},
      'bagName': {'path': '/bagName'},
      'bagMeta': {'path': '/bagMeta'},
      'bagSwatch': {'path': '/bagSwatch'},
    },
  ];

  List<Map<String, dynamic>> _briefComponents() {
    const formalities = ['Black tie', 'Cocktail', 'Smart elegant'];
    const seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
    return [
      {
        'id': 'root',
        'component': 'Column',
        'align': 'stretch',
        'children': [
          'message',
          'formality-label',
          'formality-options',
          'season-label',
          'season-options',
          'budget',
          'find-options',
        ],
      },
      {
        'id': 'message',
        'component': 'StylistMessage',
        'text': {'path': '/message'},
      },
      {'id': 'formality-label', 'component': 'Eyebrow', 'text': 'How formal?'},
      {
        'id': 'formality-options',
        'component': 'ChoiceGroup',
        'options': formalities,
        'selected': 'Black tie',
        'action': {
          'event': {'name': 'formality_selected'},
        },
      },
      {'id': 'season-label', 'component': 'Eyebrow', 'text': 'Season'},
      {
        'id': 'season-options',
        'component': 'ChoiceGroup',
        'options': seasons,
        'selected': activeJourney!.season,
        'action': {
          'event': {'name': 'season_selected'},
        },
      },
      {
        'id': 'budget',
        'component': 'BudgetSlider',
        'value': {'path': '/budget'},
        'min': 300,
        'max': 2500,
      },
      {
        'id': 'find-options',
        'component': 'PrimaryButton',
        'label': 'Find options',
        'action': {
          'event': {'name': 'find_options'},
        },
      },
    ];
  }

  List<Map<String, dynamic>> _recommendationComponents() => [
    {
      'id': 'root',
      'component': 'Column',
      'align': 'stretch',
      'children': [
        'message',
        'eyebrow',
        ...List.generate(
          _currentRecommendations.length,
          (index) => 'product-$index',
        ),
      ],
    },
    {
      'id': 'message',
      'component': 'StylistMessage',
      'text': {'path': '/message'},
    },
    {
      'id': 'eyebrow',
      'component': 'Eyebrow',
      'text': {'path': '/eyebrow'},
    },
    ..._productComponents(),
  ];

  List<Map<String, dynamic>> _completionComponents() => [
    {
      'id': 'root',
      'component': 'Column',
      'align': 'stretch',
      'children': [
        'message',
        'eyebrow',
        ...List.generate(
          _currentRecommendations.length,
          (index) => 'product-$index',
        ),
      ],
    },
    {
      'id': 'message',
      'component': 'StylistMessage',
      'text': {'path': '/message'},
    },
    {
      'id': 'eyebrow',
      'component': 'Eyebrow',
      'text': {'path': '/eyebrow'},
    },
    ..._productComponents(),
  ];

  List<Map<String, dynamic>> _productComponents() => [
    for (var index = 0; index < _currentRecommendations.length; index++)
      {
        'id': 'product-$index',
        'component': 'ProductCard',
        'name': {'path': '/recommendations/$index/name'},
        'price': {'path': '/recommendations/$index/price'},
        'brandLine': {'path': '/recommendations/$index/brandLine'},
        'tag': {'path': '/recommendations/$index/tag'},
        'swatch': {'path': '/recommendations/$index/swatch'},
        'action': {
          'event': {
            'name': 'select_product',
            'context': {'productId': _currentRecommendations[index].id},
          },
        },
      },
  ];

  @override
  void dispose() {
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    super.dispose();
  }
}

enum _AgentStage { brief, picks }
