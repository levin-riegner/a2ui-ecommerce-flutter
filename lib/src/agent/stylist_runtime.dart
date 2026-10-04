import 'dart:async';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart' show GenkitPlugin;
import 'package:schemantic/schemantic.dart';

import '../data/models.dart';
import 'stylist_surfaces.dart';

typedef StylistModel = Future<ModelResponse> Function(ModelRequest request);

const _instructions =
    'You are a personal stylist in a fictional demo catalog. '
    'Ask for the occasion and budget if missing. Search products before recommending them, '
    'then call present_products with 1 to 5 IDs from the search results you want to show. '
    'You have four model requests per interaction: use at most two requests for searches, '
    'then present your choices before the final prose response. Omit filters that do not '
    'match the catalog values listed by search_products; broaden a search that returns no products. '
    'Product facts come only from search_products. Never invent names, brands, prices, IDs or images. '
    'Consider the remaining budget and suggest a small coherent set. Your final response should '
    'be concise natural language. The host constructs A2UI cards from your validated choices and '
    'records outfit selections; do not output UI markup or claim a selection happened unless the host says so. '
    'After the host records a selection or removal, briefly acknowledge it without searching '
    'or presenting more products unless the person asks for alternatives.';

SchemanticType<Map<String, dynamic>> _object(Map<String, Object?> schema) =>
    SchemanticType.from(
      jsonSchema: schema,
      parse: (json) => Map<String, dynamic>.from(json as Map),
    );

final _turnSchema = _object({
  'type': 'object',
  'properties': {
    'message': {'type': 'string'},
    'action': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'context': {'type': 'object'},
      },
      'required': ['name', 'context'],
      'additionalProperties': false,
    },
  },
  'additionalProperties': false,
});
final _searchSchema = _object({
  'type': 'object',
  'properties': {
    for (final name in ['query', 'category', 'color', 'occasion', 'season'])
      name: {'type': 'string'},
    'priceMax': {'type': 'number', 'minimum': 0},
    'limit': {'type': 'integer', 'minimum': 1, 'maximum': 12},
  },
  'required': ['query'],
  'additionalProperties': false,
});
final _presentSchema = _object({
  'type': 'object',
  'properties': {
    'productIds': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
  'required': ['productIds'],
  'additionalProperties': false,
});

double? parseStylistBudget(String message) {
  final match = RegExp(
    r'(?:€|EUR)\s*([0-9][0-9.,\s]*[0-9]|[0-9])|([0-9][0-9.,\s]*[0-9]|[0-9])\s*(?:€|EUR\b)',
    caseSensitive: false,
  ).firstMatch(message);
  if (match == null) return null;
  final raw = (match.group(1) ?? match.group(2)!).replaceAll(RegExp(r'\s'), '');
  final decimal = RegExp(r'[.,](\d{1,2})$').firstMatch(raw);
  final digits = decimal == null
      ? raw.replaceAll(RegExp(r'[.,]'), '')
      : '${raw.substring(0, decimal.start).replaceAll(RegExp(r'[.,]'), '')}.${decimal.group(1)}';
  final value = double.tryParse(digits);
  return value != null && value.isFinite && value >= 0 ? value : null;
}

/// Shared by the bundled Flutter agent and the offline Genkit Developer UI.
/// Mutable draft state stays in a Dart Zone, outside serialized flow inputs.
class StylistRuntime {
  StylistRuntime({
    required this.products,
    List<GenkitPlugin> plugins = const [],
    ModelRef? providerModel,
    StylistModel? model,
    ModelResponse Function(ModelResponse)? normalizeResponse,
    bool developerTools = false,
    this.onBeginTurn,
    this.onCancelTurn,
  }) : ai = Genkit(
         plugins: plugins,
         isDevEnv: developerTools,
         promptDir: null,
       ) {
    ai.defineModel(
      name: 'stylist/model',
      fn: (request, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        if (++scope.requests > 4) {
          throw StateError('Model request limit reached');
        }
        if (scope.requests == 3 &&
            scope.picks.isEmpty &&
            scope.searchFoundProducts) {
          // Reserve the last tool-capable request for displaying catalog cards.
          // A third search would leave only the prose-only fourth request.
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': request.tools!
                .where((tool) => tool.name == 'present_products')
                .map((tool) => tool.toJson())
                .toList(),
          });
        } else if (scope.requests == 4) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': [],
            'toolChoice': 'none',
          });
        }
        ModelResponse response;
        if (model != null) {
          response = await model(request);
        } else if (providerModel != null) {
          final action = await ai.registry.lookupAction(
            ActionType.model,
            providerModel.name,
          ) as Model?;
          if (action == null) throw StateError('Model unavailable');
          response = await action(request, cancel: scope.cancel.token);
        } else {
          response = await offlineStylistModel(request);
        }
        response = normalizeResponse?.call(response) ?? response;
        scope.cancel.token.throwIfCancelled();
        if (response.finishReason != FinishReason.stop ||
            response.message == null ||
            !response.message!.content.any(
              (part) => part.isText || part.isToolRequest,
            ) ||
            (scope.requests == 4 &&
                response.message!.content.any((part) => part.isToolRequest))) {
          throw StateError('Incomplete model response');
        }
        return response;
      },
    );
    ai.defineTool(
      name: 'search_products',
      description:
          'Search the local fictional fashion catalog before offering products. '
          'Returns authoritative facts and IDs. Use priceMax for the remaining outfit budget. '
          'Optional facet filters are exact catalog terms: '
          'category (${ProductCategory.values.map((value) => value.name).join(', ')}), '
          'season (${products.map((product) => product.season).where((value) => value.isNotEmpty).toSet().join(', ')}), '
          'occasion (${products.map((product) => product.occasion).where((value) => value.isNotEmpty).toSet().join(', ')}). '
          'Omit a facet when unsure; query accepts free text.',
      inputSchema: _searchSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final state = scope.state;
        final remaining = state.remaining;
        final cap = min(
          remaining,
          (input['priceMax'] as num?)?.toDouble() ?? remaining,
        );
        final found = searchStylistProducts(products, {
          ...input,
          'priceMax': cap,
        });
        if (found.isNotEmpty) scope.searchFoundProducts = true;
        for (final product in found) {
          state.seen[product.id] = product;
        }
        return ToolResult.response({
          'products': found.map(productFacts).toList(),
        });
      },
    );
    ai.defineTool(
      name: 'present_products',
      description: 'Choose 1 to 5 unique IDs returned by search_products for the next A2UI cards. The host validates IDs and fills facts from the catalog.',
      inputSchema: _presentSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final ids = input['productIds'] as List;
        final state = scope.state;
        if (ids.isEmpty ||
            ids.length > 5 ||
            ids.toSet().length != ids.length ||
            ids.any((id) => id is! String || !state.seen.containsKey(id))) {
          return ToolResult.response({
            'error':
                'Choose 1 to 5 unique IDs from this session search results',
          });
        }
        if (ids.any((id) => state.seen[id]!.price > state.remaining)) {
          return ToolResult.response({
            'error': 'Presentation exceeds the remaining budget; search for cheaper options',
          });
        }
        scope.picks = ids.map((id) => state.seen[id]!).toList();
        return ToolResult.response({'presentedIds': ids});
      },
    );
    flow = ai.defineFlow(
      name: 'stylistTurn',
      inputSchema: _turnSchema,
      outputSchema: _object({'type': 'object'}),
      fn: (input, context) => _enqueue(input, cancel: context.cancel),
    );
  }

  final Genkit ai;
  final List<Product> products;
  final void Function()? onBeginTurn;
  final void Function()? onCancelTurn;
  late final Flow<Map<String, dynamic>, Map<String, dynamic>, void, void> flow;
  final _zoneKey = Object();
  _StylistState _state = _StylistState();
  final Set<CancellationController> _active = {};
  bool _disposed = false;
  Future<void> _pending = Future.value();
  _TurnScope get _scope => Zone.current[_zoneKey] as _TurnScope;
  Map<String, Object?> get outfit => {
    'budget': _state.budget,
    'items': {
      for (final entry in _state.outfit.entries) entry.key: entry.value.id,
    },
  };

  void reset() => _state = _StylistState();

  Future<Map<String, dynamic>> turn(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
  }) => flow(input, cancel: cancel);

  Future<Map<String, dynamic>> _enqueue(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
  }) {
    if (_disposed) return Future.error(StateError('Model connection closed'));
    final result = _pending.then((_) => _execute(input, cancel: cancel));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
  }) async {
    if (_disposed) throw StateError('Model connection closed');
    if ((await _turnSchema.validate(input)).isNotEmpty) {
      throw const FormatException('Invalid stylist turn');
    }
    final cancellation = CancellationController();
    final unlink = cancel?.link(cancellation);
    _active.add(cancellation);
    final timer = Timer(
      const Duration(seconds: 60),
      () => cancellation.cancel('Stylist turn timed out'),
    );
    final state = _state.copy();
    final scope = _TurnScope(state, cancellation);
    onBeginTurn?.call();
    final removeCancel = cancellation.token.onCancel(
      () => onCancelTurn?.call(),
    );
    try {
      // A direct Developer UI run reaches this same path with an offline model.
      // The flow queues this turn; ai.run traces the nested work without re-entering it.
      final result = await runZoned(
        () => ai.run('stylistTurn.execute', () => _generateTurn(input, scope)),
        zoneValues: {_zoneKey: scope},
      );
      cancellation.token.throwIfCancelled();
      if (_disposed) throw StateError('Model connection closed');
      _state = state;
      return result;
    } finally {
      timer.cancel();
      removeCancel();
      unlink?.call();
      _active.remove(cancellation);
    }
  }

  Future<Map<String, dynamic>> _generateTurn(
    Map<String, dynamic> input,
    _TurnScope scope,
  ) async {
    final state = scope.state;
    final message = (input['message'] as String?) ?? '';
    final action = input['action'] as Map?;
    if (message.isEmpty && action == null) {
      throw const FormatException('A message or action is required');
    }
    var actionNote = '';
    if (action != null) {
      final id = (action['context'] as Map)['productId'];
      if (action['name'] == 'select_product') {
        final product = state.seen[id];
        if (product == null) {
          throw StateError('Product was not returned by a catalog search');
        }
        final slot = product.category.name;
        if (state.budget != null &&
            state.spent - (state.outfit[slot]?.price ?? 0) + product.price >
                state.budget!) {
          throw StateError('Selection exceeds the outfit budget');
        }
        state.outfit[slot] = product;
        actionNote =
            'The person selected ${product.name} (${euro(product.price)}) for $slot. The host recorded it.';
      } else if (action['name'] == 'remove_product') {
        final slots = state.outfit.keys
            .where((slot) => state.outfit[slot]!.id == id)
            .toList();
        if (slots.isEmpty) throw StateError('Product is not in the outfit');
        state.outfit.remove(slots.single);
        actionNote = 'The person removed product $id from the outfit.';
      } else {
        throw StateError('Unsupported action');
      }
    }
    final budget = parseStylistBudget(message);
    if (budget != null) {
      if (budget < state.spent) {
        throw StateError('Budget is below the selected outfit total');
      }
      state.budget = budget;
    }
    if (message.isNotEmpty) {
      state.occasion = message.substring(0, min(message.length, 120));
    }
    state.turn++;
    final response = await ai.generate(
      model: modelRef('stylist/model'),
      messages: [
        ...state.history,
        Message(
          role: Role.user,
          content: [
            TextPart(
              text: [message, actionNote].where((s) => s.isNotEmpty).join('\n'),
            ),
          ],
        ),
      ],
      system:
          '$_instructions\nBudget: ${state.budget == null ? 'unknown' : euro(state.budget!)}. Already spent: ${euro(state.spent)}.',
      toolNames: ['search_products', 'present_products'],
      maxTurns: 4,
      cancel: scope.cancel.token,
    );
    scope.cancel.token.throwIfCancelled();
    if (response.finishReason != FinishReason.stop) {
      throw StateError('Incomplete model response');
    }
    state.history = response.messages
        .where((message) => message.role != Role.system)
        .toList();
    final reply = response.text.trim().isEmpty
        ? (scope.picks.isEmpty
              ? 'Tell me the occasion and budget, and I can find some options.'
              : 'Here are a few options from the catalog.')
        : response.text.trim();
    return {
      'reply': reply,
      'products': scope.picks.map(productFacts).toList(),
      'outfit': {
        'budget': state.budget,
        'items': {
          for (final entry in state.outfit.entries) entry.key: entry.value.id,
        },
      },
      'messages': renderStylistSurfaces(
        turn: state.turn,
        reply: reply,
        picks: scope.picks,
        outfit: state.outfit,
        budget: state.budget,
        occasion: state.occasion,
      ),
    };
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final cancellation in _active.toList()) {
      cancellation.cancel('Model disconnected');
    }
    _state = _StylistState();
    await ai.shutdown();
  }
}

class _StylistState {
  int turn = 0;
  List<Message> history = [];
  Map<String, Product> seen = {};
  Map<String, Product> outfit = {};
  double? budget;
  String occasion = '';
  double get spent => outfit.values.fold(0, (sum, p) => sum + p.price);
  double get remaining =>
      budget == null ? double.infinity : max(0, budget! - spent);
  _StylistState copy() => _StylistState()
    ..turn = turn
    ..history = List.of(history)
    ..seen = Map.of(seen)
    ..outfit = Map.of(outfit)
    ..budget = budget
    ..occasion = occasion;
}

class _TurnScope {
  _TurnScope(this.state, this.cancel);
  final _StylistState state;
  final CancellationController cancel;
  int requests = 0;
  bool searchFoundProducts = false;
  List<Product> picks = [];
}

List<String> _words(Object? value) => '$value'
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((s) => s.isNotEmpty)
    .toList();
List<Product> searchStylistProducts(
  List<Product> products,
  Map<String, dynamic> filters,
) {
  final query = _words(filters['query'] ?? '');
  bool facet(String value, String name) =>
      filters[name] == null ||
      filters[name] == '' ||
      _words(value).any(_words(filters[name]).contains);
  final matches = products.where(
    (p) =>
        p.price <=
            ((filters['priceMax'] as num?)?.toDouble() ?? double.infinity) &&
        facet(p.category.name, 'category') &&
        facet(p.color, 'color') &&
        facet(p.occasion, 'occasion') &&
        facet(p.season, 'season'),
  );
  final ranked = matches
      .map((p) {
        final title = _words(
          '${p.name} ${p.category.name} ${p.subcategory} ${p.color}',
        );
        final all = _words(
          '${p.name} ${p.brand} ${p.description} ${p.category.name} ${p.subcategory} ${p.color} ${p.material} ${p.season} ${p.occasion} ${p.keywords}',
        );
        final score = query.fold<int>(
          0,
          (score, word) =>
              score +
              (title.contains(word)
                  ? 3
                  : all.contains(word)
                  ? 1
                  : 0),
        );
        return (product: p, score: score);
      })
      .where((entry) => query.isEmpty || entry.score > 0)
      .toList();
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final price = a.product.price.compareTo(b.product.price);
    return price != 0 ? price : a.product.id.compareTo(b.product.id);
  });
  return ranked
      .take(((filters['limit'] as num?)?.toInt() ?? 6).clamp(1, 12))
      .map((entry) => entry.product)
      .toList();
}

/// Free deterministic provider for development and tests; never selected by BYOK setup.
Future<ModelResponse> offlineStylistModel(ModelRequest request) async {
  final last = request.messages.last;
  final responses = last.content.where((p) => p.isToolResponse).toList();
  final result = last.role == Role.tool && responses.isNotEmpty
      ? responses.last.toolResponse
      : null;
  final List<Part> content;
  if (request.tools == null ||
      request.tools!.isEmpty ||
      result?.name == 'present_products') {
    content = [
      TextPart(text: 'Offline preview: here are some catalog options.'),
    ];
  } else if (result?.name == 'search_products' &&
      ((result!.output as Map)['products'] as List).isNotEmpty) {
    content = [
      ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'present_products',
          ref: 'preview-present',
          input: {
            'productIds': ((result.output as Map)['products'] as List)
                .take(2)
                .map((p) => (p as Map)['id'])
                .toList(),
          },
        ),
      ),
    ];
  } else if (result != null) {
    content = [TextPart(text: 'Offline preview: try another catalog search.')];
  } else {
    content = [
      ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'search_products',
          ref: 'preview-search',
          input: {'query': 'dress', 'limit': 2},
        ),
      ),
    ];
  }
  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(role: Role.model, content: content),
  );
}
