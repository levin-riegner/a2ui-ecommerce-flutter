import 'dart:async';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart' show GenkitPlugin;
import 'package:schemantic/schemantic.dart';

import '../data/models.dart';
import 'stylist_surfaces.dart';
import 'outfit_plan.dart';
import 'stylist_brief.dart';

typedef StylistModel = Future<ModelResponse> Function(ModelRequest request);
typedef StylistProgress = void Function(List<Product> products);
typedef StylistResultValidator = void Function(Map<String, dynamic> result);

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
    'A selection is the next conversational turn: explain why the piece works, then search '
    'and present choices for the host next category immediately. A removal reopens that category. '
    'Follow the host outfit plan and retained preferences; do not ask again for settled information. '
    'When complete, explain how the pieces work together and invite keeping the look or swapping '
    'a piece. If nothing fits the budget, ask to raise it or replace a selected piece. '
    'The host displays all financial amounts: do not state prices, spent totals or remaining '
    'amounts in your prose. Focus on styling and the next decision. '
    'For verbal choices (including the second one), call add_to_outfit with an ID from '
    'Last presented IDs. For verbal removal call remove_from_outfit with a selected ID. '
    'Call save_outfit to record explicit changes to style, season, occasion or preferences; '
    'never assume missing dressCode or budget. After an edit, use the updated tool result '
    'to search and present the next category in the same turn.';

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

final _productIdSchema = _object({
  'type': 'object',
  'properties': {
    'productId': {'type': 'string'},
  },
  'required': ['productId'],
  'additionalProperties': false,
});
final _briefSchema = _object({
  'type': 'object',
  'properties': {
    for (final name in ['occasion', 'dressCode', 'season', 'palette', 'notes'])
      name: {'type': 'string'},
    'budget': {'type': 'number', 'minimum': 0},
  },
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
    this.onModelRequest,
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
        final needsPicks = scope.needsProducts && scope.picks.isEmpty;
        final forceSearch =
            needsPicks && scope.searches == 0 && !scope.allowEdits;
        final forcePresentation =
            needsPicks && scope.searchFoundProducts && scope.requests == 3;
        if (scope.requests == 4 ||
            scope.picks.isNotEmpty ||
            (scope.adjustingProductId != null && !scope.needsProducts) ||
            (scope.target == null &&
                scope.plan?.complete == true &&
                !scope.allowEdits)) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': [],
            'toolChoice': 'none',
          });
        } else if (scope.plan?.complete == true &&
            scope.allowEdits &&
            (scope.target == null || scope.removing)) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': request.tools!
                .where(
                  (tool) => [
                    'save_outfit',
                    'add_to_outfit',
                    'remove_from_outfit',
                  ].contains(tool.name),
                )
                .map((tool) => tool.toJson())
                .toList(),
          });
        } else if (forceSearch || forcePresentation) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': request.tools!
                .where(
                  (tool) =>
                      tool.name ==
                      (forceSearch ? 'search_products' : 'present_products'),
                )
                .map((tool) => tool.toJson())
                .toList(),
            'toolChoice': 'any',
          });
        } else if (needsPicks && scope.searchFoundProducts) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'toolChoice': 'any',
          });
        }
        if ((scope.searches > 0 || scope.adjustingProductId != null) &&
            request.tools?.isNotEmpty == true) {
          request = ModelRequest.fromJson({
            ...request.toJson(),
            'tools': request.tools!
                .where(
                  (tool) => [
                    'search_products',
                    'present_products',
                  ].contains(tool.name),
                )
                .map((tool) => tool.toJson())
                .toList(),
          });
        }
        // Tool edits update the same draft; every subsequent model request sees
        // the revised plan and financial facts rather than stale opening state.
        request = ModelRequest.fromJson({
          ...request.toJson(),
          'messages': request.messages
              .map(
                (message) => message.role == Role.system
                    ? Message(
                        role: Role.system,
                        content: [TextPart(text: _systemFor(scope))],
                      ).toJson()
                    : message.toJson(),
              )
              .toList(),
        });
        onModelRequest?.call(request);
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
        final allowedTools =
            request.tools?.map((tool) => tool.name).toSet() ?? <String>{};
        if (response.message!.content.any(
          (part) =>
              part.isToolRequest &&
              !allowedTools.contains(part.toolRequest!.name),
        )) {
          throw StateError('Stylist requested an unavailable tool');
        }
        if (request.toolChoice == 'any' &&
            !response.message!.content.any((part) => part.isToolRequest)) {
          throw StateError('Stylist did not continue the outfit journey');
        }
        return response;
      },
    );
    ai.defineTool(
      name: 'search_products',
      description:
          'Search the local fictional fashion catalog before offering products. '
          'Returns authoritative facts and IDs. Use priceMax for the host available next-category budget, which refunds replaced pieces. '
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
        if (!state.briefState.canSearch) {
          return ToolResult.response({
            'error': 'First save the missing brief fields',
            'missingFields': state.briefState.missingFields,
          });
        }
        scope.searches++;
        final available = scope.availableBudget;
        final cap = min(
          available,
          (input['priceMax'] as num?)?.toDouble() ?? available,
        );
        final filters = <String, dynamic>{
          ...input,
          if (scope.target != null) 'category': scope.target!.name,
          'priceMax': cap,
        };
        // The first search uses the settled journey facets; subsequent searches
        // may broaden them, while the next outfit category remains authoritative.
        if (scope.searches == 1) {
          if (state.catalogOccasion.isNotEmpty &&
              !filters.containsKey('occasion')) {
            filters['occasion'] = state.catalogOccasion;
          }
          if (state.season.isNotEmpty && !filters.containsKey('season')) {
            filters['season'] = state.season;
          }
        }
        final candidates = scope.adjustingProductId == null
            ? products
            : products.where((p) => p.id != scope.adjustingProductId).toList();
        var found = searchStylistProducts(candidates, filters);
        if (found.isEmpty && scope.target != null) {
          found = searchStylistProducts(candidates, {
            'query': input['query'],
            'category': scope.target!.name,
            'priceMax': cap,
            'limit': input['limit'] ?? 6,
          });
        }
        if (found.isNotEmpty) scope.searchFoundProducts = true;
        for (final product in found) {
          state.seen[product.id] = product;
        }
        return ToolResult.response({
          'products': found.map(productFacts).toList(),
          'nextCategory': scope.target?.name,
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
        if (scope.target != null &&
            ids.any((id) => state.seen[id]!.category != scope.target)) {
          return ToolResult.response({
            'error':
                'Present choices for the next category: ${scope.target!.name}',
          });
        }
        if (ids.contains(scope.adjustingProductId)) {
          return ToolResult.response({
            'error': 'Present alternatives to the currently selected piece.',
          });
        }
        if (ids.any((id) => state.seen[id]!.price > scope.availableBudget)) {
          return ToolResult.response({
            'error': 'Presentation exceeds the remaining budget; search for cheaper options',
          });
        }
        scope.picks = ids.map((id) => state.seen[id]!).toList();
        scope.onProgress?.call(List<Product>.unmodifiable(scope.picks));
        return ToolResult.response({'presentedIds': ids});
      },
    );
    ai.defineTool(
      name: 'save_outfit',
      description: 'Save explicit occasion, dressCode, season, budget, palette or notes from the person. Never invent missing fields. Returns the authoritative next step.',
      inputSchema: _briefSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        try {
          final next = scope.state.briefState.merge(
            Map<String, Object?>.from(input),
          );
          if (next.budget != null && next.budget! < scope.state.spent) {
            return ToolResult.response({
              'error': 'Budget is below selected outfit total',
            });
          }
          scope.state.briefState = next;
          scope.allowEdits = false;
          _refreshProgress(scope, requested: scope.requested);
          return ToolResult.response(_progressFacts(scope));
        } on FormatException catch (error) {
          return ToolResult.response({'error': error.message});
        }
      },
    );
    ai.defineTool(
      name: 'add_to_outfit',
      description: 'Record a verbal selection using a productId from the last presented choices, including ordinal choices such as the second one. Never select an unpresented ID. Then continue with the returned next category.',
      inputSchema: _productIdSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final id = input['productId'];
        if (!scope.state.lastPresented.contains(id)) {
          return ToolResult.response({
            'error': 'Choose an ID from the last presented choices',
          });
        }
        try {
          final product = _recordSelection(scope.state, id);
          scope.confirmations.add('Selected ${product.name}.');
          scope.allowEdits = false;
          scope.picks = [];
          _refreshProgress(scope);
          return ToolResult.response(_progressFacts(scope));
        } on StateError catch (error) {
          return ToolResult.response({'error': error.message});
        }
      },
    );
    ai.defineTool(
      name: 'remove_from_outfit',
      description: 'Record a verbal removal using the productId of an item currently in the host outfit. Reopen the removed category immediately.',
      inputSchema: _productIdSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        try {
          final removed = _recordRemoval(scope.state, input['productId']);
          scope.confirmations.add('Removed ${removed.name}.');
          scope.allowEdits = false;
          scope.picks = [];
          _refreshProgress(scope, requested: removed.category);
          return ToolResult.response(_progressFacts(scope));
        } on StateError catch (error) {
          return ToolResult.response({'error': error.message});
        }
      },
    );
    flow = ai.defineFlow(
      name: 'stylistTurn',
      inputSchema: _turnSchema,
      outputSchema: _object({'type': 'object'}),
      fn: (input, context) => _enqueue(
        input,
        cancel: context.cancel,
        onProgress: Zone.current[_progressKey] as StylistProgress?,
        validateResult: Zone.current[_validationKey] as StylistResultValidator?,
      ),
    );
  }

  final Genkit ai;
  final List<Product> products;
  final void Function()? onBeginTurn;
  final void Function(ModelRequest request)? onModelRequest;
  final void Function()? onCancelTurn;
  late final Flow<Map<String, dynamic>, Map<String, dynamic>, void, void> flow;
  final _zoneKey = Object();
  final _progressKey = Object();
  final _validationKey = Object();
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

  void reset({DemoJourney? journey}) => _state = _StylistState()
    ..brief = journey == null ? '' : '${journey.title}. ${journey.brief}'
    ..briefState = journey == null
        ? const StylistBrief()
        : StylistBrief.fromJourney(journey)
    ..catalogOccasion = journey?.catalogOccasion ?? '';

  Future<Map<String, dynamic>> turn(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistResultValidator? validateResult,
  }) => runZoned(
    () => flow(input, cancel: cancel),
    zoneValues: {_progressKey: onProgress, _validationKey: validateResult},
  );

  /// Invalidates draft work without discarding the last committed outfit.
  void cancelActiveTurn() {
    for (final cancellation in _active.toList()) {
      cancellation.cancel('Stylist turn superseded');
    }
  }

  Future<Map<String, dynamic>> _enqueue(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistResultValidator? validateResult,
  }) {
    if (_disposed) return Future.error(StateError('Model connection closed'));
    final result = _pending.then(
      (_) => _execute(
        input,
        cancel: cancel,
        onProgress: onProgress,
        validateResult: validateResult,
      ),
    );
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistResultValidator? validateResult,
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
    final scope = _TurnScope(state, cancellation, onProgress);
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
      validateResult?.call(result);
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
    ProductCategory? removedCategory;
    ProductCategory? adjustedCategory;
    if (action != null) {
      final context = action['context'] as Map;
      if (action['name'] == 'find_options') {
        final next = state.briefState.merge({
          for (final name in ['dressCode', 'season', 'budget'])
            if (context[name] != null) name: context[name],
        });
        if (next.budget != null && next.budget! < state.spent) {
          throw StateError('Budget is below the selected outfit total');
        }
        state.briefState = next;
        actionNote = 'The person confirmed the brief: ${next.toMap()}.';
      } else if (action['name'] == 'select_product') {
        final product = _recordSelection(state, context['productId']);
        scope.confirmations.add('Selected ${product.name}.');
        actionNote =
            'The person selected ${product.name} for ${product.category.name}. The host recorded it.';
      } else if (action['name'] == 'remove_product') {
        final removed = _recordRemoval(state, context['productId']);
        removedCategory = removed.category;
        scope.confirmations.add('Removed ${removed.name}.');
        actionNote = 'The person removed ${removed.name} from the outfit.';
      } else if (action['name'] == 'adjust_piece') {
        final rawCategory = context['category'];
        final matches = rawCategory is String
            ? ProductCategory.values.where(
                (category) => category.name == rawCategory.trim().toLowerCase(),
              )
            : const <ProductCategory>[];
        if (matches.length != 1) {
          throw const FormatException('Invalid category for adjustment');
        }
        adjustedCategory = matches.single;
        final selected = state.outfit[adjustedCategory.name];
        if (selected == null || selected.category != adjustedCategory) {
          throw StateError('No selected piece for this category');
        }
        final rawAdjustment = context['adjustment'];
        if (rawAdjustment != null &&
            (rawAdjustment is! String || rawAdjustment.trim().length > 120)) {
          throw const FormatException('Invalid piece adjustment');
        }
        final adjustment = (rawAdjustment as String?)?.trim() ?? '';
        final preference = adjustment.isEmpty
            ? ''
            : '${adjustedCategory.name} replacement preference: $adjustment';
        if (preference.isNotEmpty && !state.preferences.contains(preference)) {
          state.preferences.add(preference);
        }
        scope.adjustingProductId = selected.id;
        actionNote =
            'The person wants alternatives to ${selected.name} for ${adjustedCategory.name}. '
            '${preference.isEmpty ? '' : '$preference. '}'
            'Keep the selected piece and the rest of the outfit until they choose a replacement.';
      } else {
        throw StateError('Unsupported action');
      }
    }
    final budget = parseStylistBudget(message);
    if (budget != null) {
      if (budget < state.spent) {
        throw StateError('Budget is below the selected outfit total');
      }
      state.briefState = state.briefState.merge({'budget': budget});
    }
    if (message.isNotEmpty) {
      if (state.brief.isEmpty) {
        state.brief = message;
      } else if (message != state.brief) {
        state.preferences.add(message);
      }
    }
    state.briefState = state.briefState.recordMessage(message, budget: budget);
    final openingJourney =
        state.catalogOccasion.isNotEmpty && message == state.brief;
    scope.requested =
        adjustedCategory ??
        (openingJourney ? null : _requestedCategory(message)) ??
        removedCategory;
    scope.allowEdits =
        adjustedCategory == null && message.isNotEmpty && !openingJourney;
    scope.removing = RegExp(
      r'\b(?:remove|drop|reject|discard)\b',
      caseSensitive: false,
    ).hasMatch(message);
    _refreshProgress(scope, requested: scope.requested);
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
      system: _systemFor(scope),
      toolNames: [
        'search_products',
        'present_products',
        'save_outfit',
        'add_to_outfit',
        'remove_from_outfit',
      ],
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
    final generatedReply = response.text.trim().isEmpty
        ? (scope.picks.isEmpty
              ? 'Tell me the occasion and budget, and I can find some options.'
              : 'Here are a few options from the catalog.')
        : response.text.trim();
    if (scope.needsProducts && scope.picks.isEmpty) {
      throw StateError('Stylist did not present the next outfit choices');
    }
    // Financial facts belong to the host; retain stylist guidance separately.
    final guidance = _withoutFinancialProse(generatedReply);
    final plan = scope.plan!;
    final hostFacts = scope.confirmations.isEmpty
        ? ''
        : '${scope.confirmations.join(' ')}${state.budget == null ? '' : ' ${euro(state.remaining)} left in your budget.'}';
    final nextStep = !state.briefState.canSearch
        ? 'Tell me ${state.briefState.missingFields.map((field) => field == 'dressCode' ? 'the style or dress code' : 'your budget').join(' and ')} so I can find the right pieces.'
        : scope.target == null && plan.complete
        ? 'Your look is complete. Keep it, or tell me which piece you want to swap.'
        : scope.needsProducts
        ? 'Next, choose ${_categoryLabel(scope.target!)} to continue the look.'
        : scope.adjustingProductId != null
        ? 'There are no alternatives for that piece within the available budget. '
              'Keep it, or raise the budget to see more options.'
        : 'There are no ${_categoryLabel(scope.target!)} in the catalog within the available budget. '
              'Would you like to raise the budget or replace a selected piece?';
    final reply = [
      hostFacts,
      guidance,
      if (scope.confirmations.isNotEmpty ||
          plan.complete ||
          !scope.needsProducts)
        nextStep,
    ].where((text) => text.isNotEmpty).join('\n\n');
    state.lastPresented = scope.picks.map((product) => product.id).toList();
    if (state.history.isNotEmpty && state.history.last.role == Role.model) {
      state.history[state.history.length - 1] = Message(
        role: Role.model,
        content: [TextPart(text: reply)],
      );
    }
    return {
      'reply': reply,
      'products': scope.picks.map(productFacts).toList(),
      'brief': state.briefState.toMap(),
      'missingFields': state.briefState.missingFields,
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
        occasion: state.briefState.summary,
        clarification: state.briefState.canSearch
            ? null
            : {
                'missingFields': state.briefState.missingFields,
                ...state.briefState.toMap(),
              },
        plan: plan,
        nextCategory: scope.target,
      ),
    };
  }

  Product _recordSelection(_StylistState state, Object? id) {
    final product = state.seen[id];
    if (product == null) {
      throw StateError('Product was not returned by a catalog search');
    }
    final candidate = Map<String, Product>.of(state.outfit);
    removeConflictingFoundation(candidate, product.category);
    candidate[product.category.name] = product;
    final total = candidate.values.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    if (state.budget != null && total > state.budget!) {
      throw StateError('Selection exceeds the outfit budget');
    }
    state.outfit = candidate;
    return product;
  }

  Product _recordRemoval(_StylistState state, Object? id) {
    final slots = state.outfit.keys
        .where((slot) => state.outfit[slot]!.id == id)
        .toList();
    if (slots.isEmpty) throw StateError('Product is not in the outfit');
    return state.outfit.remove(slots.single)!;
  }

  void _refreshProgress(_TurnScope scope, {ProductCategory? requested}) {
    final state = scope.state;
    final plan = OutfitPlan.from(
      brief: state.briefState.planningText,
      outfit: state.outfit,
    );
    scope.plan = plan;
    scope.target = state.briefState.canSearch
        ? requested ?? plan.nextCategory
        : null;
    scope.needsProducts =
        scope.target != null &&
        products.any(
          (product) =>
              product.category == scope.target &&
              product.id != scope.adjustingProductId &&
              product.price <= scope.availableBudget,
        );
  }

  Map<String, Object?> _progressFacts(_TurnScope scope) => {
    'brief': scope.state.briefState.toMap(),
    'missingFields': scope.state.briefState.missingFields,
    'outfit': scope.state.outfit.values.map(productFacts).toList(),
    'spent': scope.state.spent,
    'remaining': scope.state.budget == null ? null : scope.state.remaining,
    'availableForNextCategory': scope.state.budget == null
        ? null
        : scope.availableBudget,
    'nextCategory': scope.target?.name,
    'complete': scope.plan!.complete,
  };

  String _systemFor(_TurnScope scope) {
    final state = scope.state;
    final plan = scope.plan!;
    final next = !state.briefState.canSearch
        ? 'Searching is blocked. Ask only for missing fields: ${state.briefState.missingFields.join(', ')}. Save explicit answers with save_outfit.'
        : scope.target == null && plan.complete
        ? 'The outfit is complete. Summarize it, identify any weakest piece, and offer keep or swap.'
        : scope.needsProducts
        ? 'Search and present this category now; do not stop at an acknowledgement.'
        : 'No affordable catalog choices for this category. Explain that limit and offer a budget change or replacing a selected piece.';
    return '$_instructions\nRetained original brief: ${state.brief}. '
        'Preferences: ${state.preferences.join('; ')}. Settled brief: ${state.briefState.toMap()}.\n'
        'Budget: ${state.budget == null ? 'unknown' : euro(state.budget!)}. '
        'Already spent: ${euro(state.spent)}. Remaining: ${state.budget == null ? 'unknown' : euro(state.remaining)}.\n'
        'Host outfit facts: ${state.outfit.values.map(productFacts).toList()}.\n'
        '${scope.adjustingProductId == null ? '' : 'The person is adjusting ${scope.target?.name}. Keep ${scope.adjustingProductId} selected until a replacement is chosen. Present different product IDs.\n'}'
        'Last presented IDs, in display order: ${state.lastPresented}.\n'
        'Plan: ${plan.slots.map((slot) => slot.name).join(', ')}. '
        'Progress: ${plan.filledCount} of ${plan.slots.length}.\n'
        'Next category: ${scope.target?.name ?? 'none'}. '
        'Available for next category, including released replacements: ${state.budget == null ? 'unknown' : euro(scope.availableBudget)}. $next';
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

ProductCategory? _requestedCategory(String message) {
  final text = message.toLowerCase().replaceAll(
    RegExp(r'\bdress[ -]*code\b|\bdressing[ -]*code\b'),
    'style',
  );
  final matches = <ProductCategory>[];
  for (final entry in {
    ProductCategory.dress: r'\bdress(?:es)?\b',
    ProductCategory.top: r'\b(?:tops?|shirts?|knits?|blouses?)\b',
    ProductCategory.bottom:
        r'\b(?:bottoms?|trousers?|pants?|shorts?|skirts?)\b',
    ProductCategory.layer: r'\b(?:layers?|jackets?|coats?|outerwear)\b',
    ProductCategory.shoes:
        r'\b(?:shoes?|boots?|sandals?|heels?|trainers?|sneakers?)\b',
    ProductCategory.bag: r'\b(?:bags?|totes?|handbags?)\b',
    ProductCategory.accessory:
        r'\b(?:accessor(?:y|ies)|jewell?ery|scarves?|belts?)\b',
  }.entries) {
    if (RegExp(entry.value).hasMatch(text)) matches.add(entry.key);
  }
  // Broad multi-category briefs follow the planner; one requested category can
  // deliberately jump ahead or reopen a settled slot for alternatives.
  return matches.length == 1 ? matches.single : null;
}

String _categoryLabel(ProductCategory category) => switch (category) {
  ProductCategory.dress => 'a dress',
  ProductCategory.top => 'a top',
  ProductCategory.bottom => 'bottoms',
  ProductCategory.layer => 'a layer',
  ProductCategory.shoes => 'shoes',
  ProductCategory.bag => 'a bag',
  ProductCategory.accessory => 'an accessory',
};

String _withoutFinancialProse(String text) => text
    .split(RegExp(r'(?<=[.!?])\s+|\n+'))
    .where(
      (sentence) => !RegExp(
        r'€|\bEUR\b|\beuros?\b|\$\d|\b(?:remaining|left|spent|budget|total|cost)\b[^.!?]*\d|\d[^.!?]*\b(?:left|remaining|spent)\b',
        caseSensitive: false,
      ).hasMatch(sentence),
    )
    .join(' ')
    .trim();

class _StylistState {
  int turn = 0;
  List<Message> history = [];
  Map<String, Product> seen = {};
  Map<String, Product> outfit = {};
  StylistBrief briefState = const StylistBrief();
  double? get budget => briefState.budget;
  String brief = '';
  List<String> preferences = [];
  String catalogOccasion = '';
  String get season => briefState.season;
  List<String> lastPresented = [];
  double get spent => outfit.values.fold(0, (sum, p) => sum + p.price);
  double get remaining =>
      budget == null ? double.infinity : max(0, budget! - spent);
  _StylistState copy() => _StylistState()
    ..turn = turn
    ..history = List.of(history)
    ..seen = Map.of(seen)
    ..outfit = Map.of(outfit)
    ..briefState = briefState
    ..brief = brief
    ..preferences = List.of(preferences)
    ..catalogOccasion = catalogOccasion
    ..lastPresented = List.of(lastPresented);
}

class _TurnScope {
  _TurnScope(this.state, this.cancel, this.onProgress);
  final _StylistState state;
  final CancellationController cancel;
  final StylistProgress? onProgress;
  int requests = 0;
  bool searchFoundProducts = false;
  int searches = 0;
  OutfitPlan? plan;
  ProductCategory? target;
  bool needsProducts = false;
  bool allowEdits = false;
  bool removing = false;
  ProductCategory? requested;
  String? adjustingProductId;
  List<String> confirmations = [];
  double get availableBudget {
    if (target == null) return state.remaining;
    final candidate = Map<String, Product>.of(state.outfit);
    removeConflictingFoundation(candidate, target!);
    candidate.remove(target!.name);
    final spent = candidate.values.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    return state.budget == null
        ? double.infinity
        : max(0, state.budget! - spent);
  }

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
  } else if (result?.name == 'search_products') {
    content = [TextPart(text: 'Offline preview: try another catalog search.')];
  } else if (request.messages
      .where((message) => message.role == Role.system)
      .any((message) => message.text.contains('Searching is blocked'))) {
    content = [TextPart(text: 'Let’s settle the brief first.')];
  } else {
    content = [
      ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'search_products',
          ref: 'preview-search',
          input: {
            'query': '',
            'category':
                RegExp(r'Next category: (\w+)')
                    .firstMatch(
                      request.messages
                          .where((message) => message.role == Role.system)
                          .map((message) => message.text)
                          .join(' '),
                    )
                    ?.group(1) ??
                'dress',
            'limit': 2,
          },
        ),
      ),
    ];
  }
  return ModelResponse(
    finishReason: FinishReason.stop,
    message: Message(role: Role.model, content: content),
  );
}
