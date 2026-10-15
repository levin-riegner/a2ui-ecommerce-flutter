import 'dart:async';
import 'dart:math';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../data/models.dart';
import 'stylist_surfaces.dart';
import 'city_context.dart';
import 'outfit_plan.dart';
import 'stylist_brief.dart';
import 'stylist_constraints.dart';
import 'stylist_input_error.dart';

typedef StylistModel = Future<ModelResponse> Function(ModelRequest request);
typedef StylistProgress = void Function(List<Product> products);
typedef StylistResultValidator = void Function(Map<String, dynamic> result);

const _instructions =
    'You are a personal stylist in a fictional demo catalog. '
    'First distinguish questions about your capabilities or general styling advice from requests to build or change an outfit. '
    'For a capability question, greeting, or general advice, call respond_to_question before any other tool, '
    'then answer naturally and ask at most one relevant follow-up. Do not force the outfit intake form. '
    'Its facts must be exact quotes of explicit preferences supplied alongside the question; use [] for a pure question. '
    'A mention in a question (such as what is casual or can I spend 500) is not an accepted preference. '
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
    'Before searching, you MUST save any explicitly supplied occasion or other fact missing from Settled brief. '
    'Mentioning a fact in your reply does not save it. Check the authoritative brief returned by the tool. '
    'When saving an occasion, include occasionEvidence quoting the user\'s actual event and keep the occasion within that quote. '
    'Never save greetings, capability questions or the entire conversation as an occasion. '
    'For combined changes, use apply_outfit_changes once with all brief edits, removals and additions before searching. '
    'Never change an explicit user fact to a suggestion. Hard exclusions must survive every search. '
    'never assume missing dressCode or budget. After an edit, use the updated tool result '
    'to search and present the next category in the same turn. '
    'Save an explicitly mentioned destination city using save_outfit city. '
    'Use host city/forecast facts for practical temperature and rain advice. '
    'Never invent weather or claim a forecast covers dates outside its listed dates. '
    'If city context is unavailable, say so; do not replace it with made-up weather.';

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
    'budget': {'type': 'number', 'minimum': 0},
  },
  'additionalProperties': false,
});

final _changesSchema = _object({
  'type': 'object',
  'properties': {
    'brief': {
      'type': 'object',
      'properties': {
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
        'budget': {'type': 'number', 'exclusiveMinimum': 0},
      },
      'additionalProperties': false,
    },
    'clearFields': {
      'type': 'array',
      'items': {'type': 'string', 'enum': StylistBrief.fields.toList()},
      'uniqueItems': true,
    },
    for (final name in ['removeProductIds', 'addProductIds'])
      name: {
        'type': 'array',
        'items': {'type': 'string'},
        'uniqueItems': true,
        'maxItems': 7,
      },
  },
  'additionalProperties': false,
});

final _questionSchema = _object({
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

double? parseStylistBudget(String message) => parseBriefBudget(message);

/// Shared by the bundled Flutter agent and the offline Genkit Developer UI.
/// Mutable draft state stays in a Dart Zone, outside serialized flow inputs.
class StylistRuntime {
  StylistRuntime({
    required this.products,
    Model? providerModel,
    StylistModel? model,
    bool developerTools = false,
    this.cityContextSource,
    this.onBeginTurn,
    this.onModelRequest,
    this.onCancelTurn,
  }) : ai = Genkit(isDevEnv: developerTools, promptDir: null) {
    ai.defineModel(
      name: 'stylist/model',
      fn: (request, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        if (++scope.requests > 4) {
          throw StateError('Model request limit reached');
        }
        // ModelRequest remains mutable in 1.0; copy once before applying host
        // policy so the generator's input is not changed behind its back.
        request = ModelRequest.fromJson(request.toJson());
        final needsPicks = scope.needsProducts && scope.picks.isEmpty;
        final forceSearch =
            needsPicks && scope.searches == 0 && !scope.allowEdits;
        final forcePresentation =
            needsPicks && scope.searchFoundProducts && scope.requests == 3;
        final budgetConflict =
            scope.state.budget != null &&
            scope.state.spent > scope.state.budget!;
        if (budgetConflict && scope.requests < 4) {
          request.tools = request.tools!
              .where(
                (tool) => [
                  'apply_outfit_changes',
                  'remove_from_outfit',
                  'save_outfit',
                  'respond_to_question',
                ].contains(tool.name),
              )
              .toList();
          request.toolChoice = ToolChoice.required;
        } else if (scope.questionIntent != null ||
            scope.requests == 4 ||
            scope.picks.isNotEmpty ||
            (scope.adjustingProductId != null && !scope.needsProducts) ||
            (scope.target == null &&
                scope.plan?.complete == true &&
                !scope.allowEdits)) {
          request.tools = [];
          request.toolChoice = ToolChoice.none;
        } else if (scope.plan?.complete == true &&
            scope.allowEdits &&
            (scope.target == null || scope.removing)) {
          request.tools = request.tools!
              .where(
                (tool) => [
                  'save_outfit',
                  'apply_outfit_changes',
                  'add_to_outfit',
                  'remove_from_outfit',
                  'respond_to_question',
                ].contains(tool.name),
              )
              .toList();
        } else if (forceSearch || forcePresentation) {
          request.tools = request.tools!
              .where(
                (tool) =>
                    tool.name ==
                    (forceSearch ? 'search_products' : 'present_products'),
              )
              .toList();
          request.toolChoice = ToolChoice.required;
        } else if (needsPicks && scope.searchFoundProducts) {
          request.toolChoice = ToolChoice.required;
        }
        if (!budgetConflict &&
            (scope.searches > 0 || scope.adjustingProductId != null) &&
            request.tools?.isNotEmpty == true) {
          request.tools = request.tools!
              .where(
                (tool) =>
                    ['search_products', 'present_products'].contains(tool.name),
              )
              .toList();
        }
        // Tool edits update the same draft; every subsequent model request sees
        // the revised plan and financial facts rather than stale opening state.
        request.messages = request.messages
            .map(
              (message) => message.role == Role.system
                  ? Message(
                      role: Role.system,
                      content: [TextPart(text: _systemFor(scope))],
                    )
                  : message,
            )
            .toList();
        onModelRequest?.call(request);
        ModelResponse response;
        if (model != null) {
          response = await model(request);
        } else if (providerModel != null) {
          response = await providerModel(request, cancel: scope.cancel.token);
        } else {
          response = await offlineStylistModel(request);
        }
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
        if (request.toolChoice == ToolChoice.required &&
            !response.message!.content.any((part) => part.isToolRequest)) {
          throw StateError('Stylist did not continue the outfit journey');
        }
        return response;
      },
    );
    ai.defineTool(
      name: 'respond_to_question',
      description: 'Answer a capability question, greeting or general styling question without searching or advancing the outfit. Call first. Include only exact quotes of explicitly stated outfit facts alongside the question; facts is empty for pure questions. Returns the response mode; write your answer after this tool.',
      inputSchema: _questionSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        if (!scope.allowEdits ||
            scope.searches > 0 ||
            scope.confirmations.isNotEmpty) {
          return ToolResult.response({
            'error': 'Answer questions before editing or searching.',
          });
        }
        final quotes = List<String>.from(input['facts'] as List);
        if (quotes.any(
          (quote) => quote.trim().isEmpty || !scope.userMessage.contains(quote),
        )) {
          return ToolResult.response({
            'error': 'Facts must quote the current user message exactly.',
          });
        }
        try {
          var brief = scope.previousBrief;
          for (final quote in quotes) {
            brief = brief.recordMessage(
              quote,
              knownBrands: products.map((p) => p.brand),
            );
          }
          _checkBudget(scope.state, brief: brief);
          final before = scope.beforeInput!;
          scope.state
            ..briefState = brief
            ..brief = before.brief
            ..preferences = List.of(before.preferences)
            ..city = before.city
            ..cityContext = before.cityContext
            ..cityContextNotice = before.cityContextNotice;
          final accepted = quotes.join('\n');
          if (accepted.isNotEmpty) {
            if (scope.state.brief.isEmpty) {
              scope.state.brief = accepted;
            } else {
              scope.state.preferences.add(accepted);
            }
          }
          scope.userMessage = accepted;
          scope.questionIntent = input['intent'] as String;
          scope.allowEdits = false;
          scope.notices.clear();
          _refreshProgress(scope);
          return ToolResult.response({
            'intent': scope.questionIntent,
            'brief': brief.toMap(),
            'instruction': 'Answer the question naturally. Ask at most one relevant follow-up. No outfit intake controls or product search this turn.',
          });
        } on FormatException catch (error) {
          return ToolResult.response({'error': error.message});
        }
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
        if (state.briefState.constraints.clarificationRequests.isNotEmpty) {
          return ToolResult.response({
            'error': 'Clarify the scope of your restrictions before searching.',
            'clarificationRequests':
                state.briefState.constraints.clarificationRequests,
          });
        }
        if (state.budget != null && state.spent > state.budget!) {
          return ToolResult.response({
            'error': 'Apply the requested outfit removals before searching.',
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
        final candidates = _recommendableProducts(scope);
        var found = searchStylistProducts(
          candidates,
          filters,
          constraints: state.briefState.constraints,
        );
        if (found.isEmpty && scope.target != null) {
          found = searchStylistProducts(candidates, {
            'query': '',
            'category': scope.target!.name,
            'priceMax': cap,
            'limit': input['limit'] ?? 6,
          }, constraints: state.briefState.constraints);
          if (found.isNotEmpty) {
            scope.notices.add(
              'There are no matches for those optional search filters. These alternatives still respect your required constraints.',
            );
          }
        }
        if (found.isNotEmpty) scope.searchFoundProducts = true;
        for (final product in found) {
          state.seen[product.id] = product;
        }
        return ToolResult.response({
          'products': found.map(productFacts).toList(),
          'nextCategory': scope.target?.name,
          if (scope.notices.isNotEmpty) 'notices': scope.notices.toList(),
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
        final allowedIds = _recommendableProducts(scope)
            .map((p) => p.id)
            .toSet();
        if (ids.any((id) => !allowedIds.contains(id))) {
          return ToolResult.response({
            'error': 'These choices violate your constraints or leave insufficient budget when affordable complete-outfit alternatives exist.',
          });
        }
        scope.picks = ids.map((id) => state.seen[id]!).toList();
        scope.onProgress?.call(List<Product>.unmodifiable(scope.picks));
        return ToolResult.response({'presentedIds': ids});
      },
    );
    ai.defineTool(
      name: 'save_outfit',
      description: 'Save explicit destination city, occasion, dressCode, season, budget, palette or notes from the person. Never invent missing fields. Returns the authoritative next step.',
      inputSchema: _briefSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        try {
          final patch = Map<String, Object?>.from(input);
          final city = patch.remove('city');
          if (city != null &&
              (city is! String ||
                  city.trim().length < 2 ||
                  city.length > 100)) {
            throw const FormatException('Enter a city name');
          }
          final next = _mergeModelBrief(scope, scope.state.briefState, patch);
          if (next.budget != null && next.budget! < scope.state.spent) {
            return ToolResult.response({
              'error': 'Budget is below selected outfit total',
            });
          }
          scope.state.briefState = next;
          if (city is String) {
            scope.state.city = city.trim();
            await _loadCityContext(scope.state);
            scope.cancel.token.throwIfCancelled();
          }
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
        } on StylistInputError catch (error) {
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
        } on StylistInputError catch (error) {
          return ToolResult.response({'error': error.message});
        }
      },
    );
    ai.defineTool(
      name: 'apply_outfit_changes',
      description: 'Apply all requested brief changes, field clears, product removals and verbal additions together before search. Validate the resulting outfit and budget atomically. Add only IDs from last presented choices.',
      inputSchema: _changesSchema,
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final state = scope.state;
        final draft = state.copy();
        final confirmations = <String>[];
        try {
          if (!(input['brief'] is Map && (input['brief'] as Map).isNotEmpty) &&
              !['clearFields', 'removeProductIds', 'addProductIds'].any(
                (name) =>
                    input[name] is List && (input[name] as List).isNotEmpty,
              )) {
            throw const FormatException(
              'Provide the requested outfit changes before applying them.',
            );
          }
          final patch = Map<String, Object?>.from(
            input['brief'] as Map? ?? const {},
          );
          final city = patch.remove('city');
          draft.briefState = _mergeModelBrief(
            scope,
            draft.briefState,
            patch,
            clearFields: (input['clearFields'] as List? ?? const [])
                .cast<String>()
                .toSet(),
          );
          if (city != null &&
              (city is! String ||
                  city.trim().length < 2 ||
                  city.length > 100)) {
            throw const FormatException('Enter a city name');
          }
          for (final id in input['removeProductIds'] as List? ?? const []) {
            confirmations.add('Removed ${_recordRemoval(draft, id).name}.');
          }
          // Check all additions against the final budget, without publishing partial changes.
          final addedCategories = <ProductCategory>{};
          for (final id in input['addProductIds'] as List? ?? const []) {
            if (!state.lastPresented.contains(id)) {
              throw const StylistInputError(
                code: StylistInputErrorCode.invalidSelection,
                message: 'Choose a product from the current recommendations.',
              );
            }
            final product = draft.seen[id];
            if (product != null && !addedCategories.add(product.category)) {
              throw const StylistInputError(
                code: StylistInputErrorCode.invalidSelection,
                message: 'Choose one product per outfit category.',
              );
            }
            confirmations.add(
              'Selected ${_recordSelection(draft, id, validateFinal: false).name}.',
            );
          }
          _checkBudget(draft);
          for (final id in input['addProductIds'] as List? ?? const []) {
            _validateSelectionFeasibility(draft, draft.seen[id]!);
          }
          if (city is String) {
            draft.city = city.trim();
            await _loadCityContext(draft);
            scope.cancel.token.throwIfCancelled();
          }
          state.briefState = draft.briefState;
          state.outfit = draft.outfit;
          state.city = draft.city;
          state.cityContext = draft.cityContext;
          state.cityContextNotice = draft.cityContextNotice;
          scope.confirmations.addAll(confirmations);
          scope.atomicFailure = null;
          scope.allowEdits = false;
          scope.picks = [];
          _refreshProgress(scope, requested: scope.requested);
          return ToolResult.response(_progressFacts(scope));
        } on StylistInputError catch (error) {
          scope.atomicFailure = error;
          return ToolResult.response({'error': error.message});
        } on FormatException catch (error) {
          scope.atomicFailure = StylistInputError(
            code: StylistInputErrorCode.invalidBrief,
            message: error.message,
          );
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
  final CityContextSource? cityContextSource;
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
    ..catalogOccasion = journey?.catalogOccasion ?? ''
    ..city = switch (journey) {
      DemoJourney.paris => 'Paris, France',
      DemoJourney.berlin => 'Berlin, Germany',
      DemoJourney.lisbon => 'Lisbon, Portugal',
      DemoJourney.cotswolds => 'Cotswolds, United Kingdom',
      null => '',
    };

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
    final unsupportedCurrency = unsupportedBriefBudgetCurrency(message);
    if (unsupportedCurrency != null) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidBrief,
        message:
            'You entered a $unsupportedCurrency budget. This local catalog uses EUR; enter your outfit budget in euros. No currency conversion has been applied.',
      );
    }
    scope.userMessage = message;
    scope.userBudget = parseStylistBudget(message);
    scope.previousBrief = state.briefState;
    scope.beforeInput = state.copy();
    final action = input['action'] as Map?;
    if (message.isEmpty && action == null) {
      throw const FormatException('A message or action is required');
    }
    var actionNote = '';
    ProductCategory? removedCategory;
    ProductCategory? adjustedCategory;
    if (action != null) {
      final context = action['context'] as Map;
      if (action['name'] == 'refresh_city_context' &&
          cityContextSource != null &&
          state.city.isNotEmpty) {
        await _loadCityContext(state, refresh: true);
        scope.cancel.token.throwIfCancelled();
        return {
          'messages':
              renderStylistSurfaces(
                turn: state.turn,
                reply: state.lastReply,
                picks: state.lastPresented
                    .map((id) => state.seen[id]!)
                    .toList(),
                outfit: state.outfit,
                budget: state.budget,
                occasion: state.briefState.summary,
                clarification:
                    state.lastQuestionIntent != null ||
                        state.briefState.canSearch
                    ? null
                    : {
                        'missingFields': state.briefState.missingFields,
                        ...state.briefState.toMap(),
                      },
                plan: OutfitPlan.from(
                  brief: state.briefState.planningText,
                  outfit: state.outfit,
                  constraints: state.briefState.constraints,
                  dressCode: state.briefState.dressCode,
                ),
                nextCategory: state.lastNextCategory,
                cityContext: state.cityContext,
                cityContextNotice: state.cityContextNotice,
                city: state.city,
              ).where((message) {
                final update =
                    message['updateComponents'] ?? message['updateDataModel'];
                return update is Map &&
                    update['surfaceId'] == 'inline-${state.turn}';
              }).toList(),
        };
      } else if (action['name'] == 'find_options') {
        StylistBrief next;
        try {
          next = state.briefState.merge({
            for (final name in ['dressCode', 'season', 'budget'])
              if (context[name] != null) name: context[name],
          });
        } on FormatException catch (error) {
          throw StylistInputError(
            code: StylistInputErrorCode.invalidBrief,
            message: error.message,
          );
        }
        _checkBudget(state, brief: next);
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
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidAdjustment,
            message: 'Choose a selected outfit category to change.',
          );
        }
        adjustedCategory = matches.single;
        final selected = state.outfit[adjustedCategory.name];
        if (selected == null || selected.category != adjustedCategory) {
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidAdjustment,
            message: 'Choose a piece that is currently in your outfit.',
          );
        }
        final rawAdjustment = context['adjustment'];
        if (rawAdjustment != null &&
            (rawAdjustment is! String || rawAdjustment.trim().length > 120)) {
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidAdjustment,
            message:
                'Describe the piece adjustment in 120 characters or fewer.',
          );
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
        throw const StylistInputError(
          code: StylistInputErrorCode.unsupportedAction,
          message: 'This action is not available in the local catalog yet. You can continue editing your outfit.',
        );
      }
    }
    final budget = scope.userBudget;
    if (message.isNotEmpty) {
      if (state.brief.isEmpty) {
        state.brief = message;
      } else if (message != state.brief) {
        state.preferences.add(message);
      }
    }
    try {
      state.briefState = state.briefState.recordMessage(
        message,
        budget: budget,
        knownBrands: products.map((product) => product.brand),
      );
    } on FormatException catch (error) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidBrief,
        message: error.message,
      );
    }
    // Combined removals and a lower budget are validated against the final draft.
    // A budget-only conflict remains a cheap, immediately correctable input error.
    if (!RegExp(
      r'\b(?:remove|drop|reject|discard)\b',
      caseSensitive: false,
    ).hasMatch(message)) {
      _checkBudget(state);
    }
    final mentionedCity = RegExp(
      r'\bin\s+(Berlin|Paris|Lisbon|Oxford)(?:,\s*(Germany|France|Portugal|United Kingdom|United States|USA|[A-Z]{2})\b)?\b',
      caseSensitive: false,
    ).firstMatch(message);
    if (mentionedCity != null) {
      final name = mentionedCity.group(1)!;
      final country = mentionedCity.group(2);
      // A repeated city name must not erase a previously explicit country.
      if (country != null ||
          state.city.split(',').first.toLowerCase() != name.toLowerCase()) {
        state.city = [name, ?country].join(', ');
      }
    }
    await _loadCityContext(state);
    scope.cancel.token.throwIfCancelled();
    final openingJourney =
        state.catalogOccasion.isNotEmpty && message == state.brief;
    scope.requested =
        adjustedCategory ??
        (openingJourney
            ? null
            : requestedProductCategory(
                message,
                constraints: state.briefState.constraints,
              )) ??
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
        'respond_to_question',
        'search_products',
        'present_products',
        'save_outfit',
        'add_to_outfit',
        'remove_from_outfit',
        'apply_outfit_changes',
      ],
      maxTurns: 4,
      // Retries are opt-in in Genkit 1.0. Keep each turn bounded; a failed
      // turn rolls back and the user can explicitly retry it.
      use: const [],
      cancel: scope.cancel.token,
    );
    scope.cancel.token.throwIfCancelled();
    _checkBudget(state);
    if (scope.atomicFailure != null) throw scope.atomicFailure!;
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
    final acknowledgment = _acknowledgment(scope);
    final nextStep = !state.briefState.canSearch
        ? 'Tell me ${state.briefState.missingFields.map((field) => field == 'dressCode' ? 'the style or dress code' : 'your budget').join(' and ')} so I can find the right pieces.'
        : state.briefState.constraints.clarificationRequests.isNotEmpty
        ? state.briefState.constraints.clarificationRequests.join(' ')
        : scope.target == null && plan.complete
        ? 'Your look is complete. Keep it, or tell me which piece you want to swap.'
        : scope.target == null
        ? 'Remove or replace the selected pieces that conflict with your instructions before completing the look.'
        : scope.needsProducts
        ? 'Next, choose ${_categoryLabel(scope.target!)} to continue the look.'
        : scope.adjustingProductId != null
        ? 'There are no alternatives for that piece within the available budget. '
              'Keep it, or raise the budget to see more options.'
        : state.briefState.constraints.toMap().isNotEmpty
        ? 'There are no ${_categoryLabel(scope.target!)} that satisfy your current constraints and budget. '
              'Change a restriction, use something you own, or replace a selected piece.'
        : 'There are no ${_categoryLabel(scope.target!)} in the catalog within the available budget. '
              'Would you like to raise the budget or replace a selected piece?';
    final reply = [
      hostFacts,
      acknowledgment,
      if (scope.feasibilityNotice.isNotEmpty) scope.feasibilityNotice,
      ...scope.notices,
      guidance,
      if (scope.questionIntent == null &&
          (scope.confirmations.isNotEmpty ||
              plan.complete ||
              !scope.needsProducts) &&
          (state.briefState.canSearch || guidance.isEmpty))
        nextStep,
    ].where((text) => text.isNotEmpty).join('\n\n');
    state.lastReply = reply;
    state.lastQuestionIntent = scope.questionIntent;
    if (scope.questionIntent == null) {
      state.lastNextCategory = scope.target;
      state.lastPresented = scope.picks.map((product) => product.id).toList();
    }
    if (state.history.isNotEmpty && state.history.last.role == Role.model) {
      state.history[state.history.length - 1] = Message(
        role: Role.model,
        content: [TextPart(text: reply)],
      );
    }
    return {
      'reply': reply,
      if (scope.questionIntent != null) 'intent': scope.questionIntent,
      'products': scope.picks.map(productFacts).toList(),
      'brief': state.briefState.toMap(),
      'missingFields': state.briefState.missingFields,
      'constraints': state.briefState.constraints.toMap(),
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
        clarification:
            scope.questionIntent != null || state.briefState.canSearch
            ? null
            : {
                'missingFields': state.briefState.missingFields,
                ...state.briefState.toMap(),
              },
        plan: plan,
        nextCategory: scope.target,
        cityContext: state.cityContext,
        cityContextNotice: state.cityContextNotice,
        city: state.city,
      ),
    };
  }

  Product _recordSelection(
    _StylistState state,
    Object? id, {
    bool validateFinal = true,
  }) {
    final product = state.seen[id];
    if (product == null) {
      throw const StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: 'Choose a product from the current catalog recommendations.',
      );
    }
    final violations = state.briefState.constraints.violations(product);
    if (violations.isNotEmpty) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message:
            '${product.name} does not satisfy your instructions: ${violations.join('; ')}.',
      );
    }
    final candidate = Map<String, Product>.of(state.outfit);
    removeConflictingFoundation(candidate, product.category);
    candidate[product.category.name] = product;
    final total = candidate.values.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    if (validateFinal && state.budget != null && total > state.budget!) {
      throw StylistInputError(
        code: StylistInputErrorCode.budgetConflict,
        message:
            'Selecting ${product.name} would cost ${euro(total)} for the outfit, above your ${euro(state.budget!)} budget. Choose a cheaper piece or replace an existing one.',
      );
    }
    if (validateFinal) _validateSelectionFeasibility(state, product);
    state.outfit = candidate;
    return product;
  }

  void _validateSelectionFeasibility(_StylistState state, Product product) {
    final assessment = _assessment(state, product);
    if (!assessment.feasible &&
        products.any(
          (alternative) =>
              alternative.category == product.category &&
              state.briefState.constraints.matches(alternative) &&
              _assessment(state, alternative).feasible,
        )) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: assessment.explanation,
      );
    }
  }

  Product _recordRemoval(_StylistState state, Object? id) {
    final slots = state.outfit.keys
        .where((slot) => state.outfit[slot]!.id == id)
        .toList();
    if (slots.isEmpty) {
      throw const StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: 'That piece is not currently in your outfit. Choose one of your selected pieces to remove.',
      );
    }
    return state.outfit.remove(slots.single)!;
  }

  void _refreshProgress(_TurnScope scope, {ProductCategory? requested}) {
    final state = scope.state;
    scope.feasibilityNotice = '';
    for (final product in state.outfit.values) {
      final conflicts = state.briefState.constraints.violations(product);
      if (conflicts.isNotEmpty) {
        scope.notices.add(
          'Your selected ${product.name} conflicts with your new instructions: ${conflicts.join('; ')}. Remove or replace it to satisfy them.',
        );
      }
    }
    final plan = OutfitPlan.from(
      brief: state.briefState.planningText,
      outfit: state.outfit,
      constraints: state.briefState.constraints,
      dressCode: state.briefState.dressCode,
    );
    scope.plan = plan;
    if (requested != null &&
        !state.briefState.constraints.categoryPermitted(requested)) {
      requested = null;
    }
    scope.target =
        scope.questionIntent == null &&
            state.briefState.canSearch &&
            state.briefState.constraints.clarificationRequests.isEmpty
        ? requested ?? plan.nextCategory
        : null;
    scope.needsProducts =
        scope.target != null &&
        _recommendableProducts(scope).any(
          (product) =>
              product.category == scope.target &&
              product.id != scope.adjustingProductId &&
              product.price <= scope.availableBudget,
        );
  }

  Map<String, Object?> _progressFacts(_TurnScope scope) => {
    'brief': scope.state.briefState.toMap(),
    'constraints': scope.state.briefState.constraints.toMap(),
    'city': scope.state.city,
    if (scope.state.cityContext != null)
      'cityContext': scope.state.cityContext!.facts,
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
    final next = scope.questionIntent != null
        ? 'This turn answers a ${scope.questionIntent} question. Answer it directly; ask at most one relevant follow-up. Do not ask for missing outfit fields or suggest a search.'
        : !state.briefState.canSearch
        ? 'Searching is blocked. Ask only for missing fields: ${state.briefState.missingFields.join(', ')}. Save explicit answers with save_outfit.'
        : state.briefState.constraints.clarificationRequests.isNotEmpty
        ? 'Searching is blocked. Ask only these scope questions: ${state.briefState.constraints.clarificationRequests.join(' ')}.'
        : scope.target == null && plan.complete
        ? 'The outfit is complete. Summarize it, identify any weakest piece, and offer keep or swap.'
        : scope.target == null
        ? 'Selected pieces conflict with the current instructions. Explain which pieces need removal or replacement; do not claim the outfit is complete.'
        : scope.needsProducts
        ? 'Search and present this category now; do not stop at an acknowledgement.'
        : 'No affordable catalog choices for this category. Explain that limit and offer a budget change or replacing a selected piece.';
    return '$_instructions\nRetained original brief: ${state.brief}. '
        'Preferences: ${state.preferences.join('; ')}. Settled brief: ${state.briefState.toMap()}.\n'
        'Hard constraints and preferences: ${state.briefState.constraints.toMap()}. '
        'Host notices: ${scope.notices.join(' ')} ${scope.feasibilityNotice}.\n'
        'Budget: ${state.budget == null ? 'unknown' : euro(state.budget!)}. '
        'Already spent: ${euro(state.spent)}. Remaining: ${state.budget == null ? 'unknown' : euro(state.remaining)}.\n'
        'Destination city: ${state.city}. Verified context: ${state.cityContext?.facts ?? state.cityContextNotice ?? 'not loaded'}.\n'
        'Host outfit facts: ${state.outfit.values.map(productFacts).toList()}.\n'
        '${scope.adjustingProductId == null ? '' : 'The person is adjusting ${scope.target?.name}. Keep ${scope.adjustingProductId} selected until a replacement is chosen. Present different product IDs.\n'}'
        'Last presented IDs, in display order: ${state.lastPresented}.\n'
        'Plan: ${plan.slots.map((slot) => slot.name).join(', ')}. '
        'Progress: ${plan.filledCount} of ${plan.slots.length}.\n'
        'Next category: ${scope.target?.name ?? 'none'}. '
        'Available for next category, including released replacements: ${state.budget == null ? 'unknown' : euro(scope.availableBudget)}. $next '
        'For capability or general advice questions, respond_to_question takes priority over the outfit next step.';
  }

  void _checkBudget(_StylistState state, {StylistBrief? brief}) {
    final budget = (brief ?? state.briefState).budget;
    if (budget != null && state.spent > budget) {
      throw StylistInputError(
        code: StylistInputErrorCode.budgetConflict,
        message:
            'Your selected pieces cost ${euro(state.spent)}, above the requested ${euro(budget)} outfit budget. Remove or replace a piece, or keep a higher budget.',
      );
    }
  }

  StylistBrief _mergeModelBrief(
    _TurnScope scope,
    StylistBrief brief,
    Map<String, Object?> patch, {
    Set<String> clearFields = const {},
  }) {
    patch = Map.of(patch);
    final occasionEvidence = patch.remove('occasionEvidence');
    final proposedOccasion = patch['occasion'];
    if (proposedOccasion != null &&
        (brief.sources['occasion'] != BriefFactSource.user ||
            proposedOccasion != brief.occasion) &&
        (proposedOccasion is! String ||
            proposedOccasion.contains('?') ||
            occasionEvidence is! String ||
            occasionEvidence.trim().isEmpty ||
            !scope.userMessage.contains(occasionEvidence) ||
            !occasionEvidence.toLowerCase().contains(
              proposedOccasion.toLowerCase(),
            ))) {
      throw const FormatException(
        'Save only a stated occasion, supported by an exact quote from the current message.',
      );
    }
    final authorized = <String>{};
    for (final entry in {
      'occasion': r'\b(?:occasion|actually|instead|wedding|dinner|interview|party|lunch|trip|holiday)\b',
      'dressCode': r'\b(?:style|dress code|formal|casual|cocktail|black.?tie|relaxed|smart)\b',
      'season': r'\b(?:season|spring|summer|autumn|winter)\b',
      'palette':
          r'\b(?:palette|colou?r|blue|red|black|white|navy|cream|green)\b',
      'notes': r'\b(?:notes|prefer|avoid|no|without|comfortable|heels|wool)\b',
      'budget': r'\b(?:budget|spend|under|limit|euros?)\b|€|\bEUR\b',
    }.entries) {
      if (RegExp(
        entry.value,
        caseSensitive: false,
      ).hasMatch(scope.userMessage)) {
        authorized.add(entry.key);
      }
    }
    // Facts explicitly extracted this turn are already current; the model cannot
    // reinterpret them to a different value or silently clear them.
    final extracted = scope.previousBrief.recordMessage(
      scope.userMessage,
      knownBrands: products.map((product) => product.brand),
    );
    for (final field in extracted.changedFactsSince(scope.previousBrief).keys) {
      if (extracted.sources[field] == BriefFactSource.user &&
          extracted.toMap().containsKey(field)) {
        authorized.remove(field);
      }
    }
    authorized.removeAll(
      extracted.acceptedFactsFromMessage(scope.userMessage).keys,
    );
    if (scope.userBudget != null) authorized.remove('budget');
    if (patch['budget'] != null &&
        brief.budget == null &&
        !authorized.contains('budget')) {
      throw const FormatException(
        'Ask for the outfit budget instead of suggesting one as a fact.',
      );
    }
    if (patch['dressCode'] != null &&
        brief.dressCode.isEmpty &&
        !authorized.contains('dressCode')) {
      throw const FormatException(
        'Ask for the style or dress code instead of assuming it.',
      );
    }
    return brief.merge(
      patch,
      source: BriefFactSource.model,
      protectUserFacts: true,
      authorizedFields: authorized,
      clearFields: clearFields.intersection(authorized),
    );
  }

  OutfitSelectionAssessment _assessment(_StylistState state, Product product) =>
      assessOutfitSelection(
        candidate: product,
        outfit: state.outfit,
        catalog: products,
        brief: state.briefState.planningText,
        dressCode: state.briefState.dressCode,
        constraints: state.briefState.constraints,
        budget: state.budget,
      );

  List<Product> _recommendableProducts(_TurnScope scope) {
    final state = scope.state;
    var candidates = products
        .where(
          (product) =>
              product.id != scope.adjustingProductId &&
              state.briefState.constraints.matches(product),
        )
        .toList();
    if (scope.target != null) {
      final category = candidates
          .where((product) => product.category == scope.target)
          .toList();
      final feasible = category
          .where((product) => _assessment(state, product).feasible)
          .toList();
      if (feasible.isNotEmpty) {
        final allowed = feasible.map((product) => product.id).toSet();
        candidates = candidates
            .where(
              (product) =>
                  product.category != scope.target ||
                  allowed.contains(product.id),
            )
            .toList();
      } else if (category.isNotEmpty && state.briefState.canSearch) {
        final assessments =
            category.map((product) => _assessment(state, product)).toList()
              ..sort((a, b) => a.minimumTotal.compareTo(b.minimumTotal));
        final explanation = assessments.first.explanation;
        scope.feasibilityNotice = explanation;
      }
    }
    candidates.sort(
      (a, b) => state.briefState.constraints
          .preferenceScore(b)
          .compareTo(state.briefState.constraints.preferenceScore(a)),
    );
    return candidates;
  }

  String _acknowledgment(_TurnScope scope) {
    final brief = scope.state.briefState;
    final facts = {
      ...brief.changedFactsSince(scope.previousBrief),
      ...brief.acceptedFactsFromMessage(scope.userMessage),
    };
    final parts = <String>[];
    for (final entry in facts.entries) {
      if (entry.value == null) {
        parts.add('${entry.key == 'dressCode' ? 'style' : entry.key} cleared');
      } else if (entry.key == 'budget') {
        parts.add('${euro(entry.value as num)} for the whole outfit');
      } else if (brief.sources[entry.key] != BriefFactSource.inferred) {
        parts.add(
          '${entry.key == 'dressCode' ? 'style' : entry.key}: ${entry.value.toString().replaceAll('-', ' ')}',
        );
      }
    }
    final constraints = brief.constraints.toMap();
    if (constraints.toString() !=
        scope.previousBrief.constraints.toMap().toString()) {
      final previousConstraints = scope.previousBrief.constraints.toMap();
      for (final key in {...previousConstraints.keys, ...constraints.keys}) {
        if (key == 'clarificationRequests') continue;
        if (constraints[key].toString() !=
            previousConstraints[key].toString()) {
          final label = _constraintLabel(key);
          parts.add(
            constraints[key] == null
                ? '$label cleared'
                : '$label: ${_constraintDescription(constraints[key]!)}',
          );
        }
      }
    }
    if (RegExp(
      r'\b(?:size|fit|stock|availability)\b',
      caseSensitive: false,
    ).hasMatch(scope.userMessage)) {
      scope.notices.add(
        'I have noted your sizing or availability request, but this local catalog cannot verify sizes, fit, or stock.',
      );
    }
    return parts.isEmpty ? '' : 'Got it — ${parts.join('; ')}.';
  }

  String _constraintLabel(String key) => switch (key) {
    'excludedCategories' => 'skip',
    'ownedCategories' => 'already owned',
    'allowedColors' => 'only these colors',
    'excludedColors' => 'avoid colors',
    'excludedMaterials' => 'avoid materials',
    'allowedMaterials' => 'only these materials',
    'excludedBrands' => 'avoid brands',
    'allowedBrands' => 'only these brands',
    'excludedProductTerms' => 'avoid these product types',
    'categoryConstraints' => 'category restrictions',
    _ => 'preferred colors',
  };

  String _constraintDescription(Object value) {
    if (value is List) return value.join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) {
            final label = value.values.any((v) => v is Map)
                ? entry.key.toString()
                : _constraintLabel(entry.key.toString());
            return '$label: ${_constraintDescription(entry.value as Object)}';
          })
          .join('; ');
    }
    return value.toString();
  }

  Future<void> _loadCityContext(
    _StylistState state, {
    bool refresh = false,
  }) async {
    final source = cityContextSource;
    if (source == null || state.city.isEmpty) {
      return;
    }
    state.cityContext = null;
    final cancel = _scope.cancel.token;
    cancel.throwIfCancelled();
    try {
      state.cityContext = await Future.any<CityContext>([
        source.fetch(state.city, refresh: refresh),
        cancel.whenCancelled.then((_) {
          cancel.throwIfCancelled();
          throw StateError('Context fetch cancelled');
        }),
      ]);
      cancel.throwIfCancelled();
      state.cityContextNotice = null;
    } catch (_) {
      cancel.throwIfCancelled();
      state.cityContextNotice =
          'Could not load the forecast for ${state.city}. Your stylist can continue without it.';
    }
  }

  Future<void> dispose() async {
    cityContextSource?.dispose();
    _disposed = true;
    for (final cancellation in _active.toList()) {
      cancellation.cancel('Model disconnected');
    }
    _state = _StylistState();
    await ai.shutdown();
  }
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
  String city = '';
  String lastReply = '';
  String? lastQuestionIntent;
  ProductCategory? lastNextCategory;
  CityContext? cityContext;
  String? cityContextNotice;
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
    ..city = city
    ..lastReply = lastReply
    ..lastQuestionIntent = lastQuestionIntent
    ..lastNextCategory = lastNextCategory
    ..cityContext = cityContext
    ..cityContextNotice = cityContextNotice
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
  String userMessage = '';
  double? userBudget;
  StylistBrief previousBrief = const StylistBrief();
  _StylistState? beforeInput;
  String? questionIntent;
  final Set<String> notices = {};
  String feasibilityNotice = '';
  StylistInputError? atomicFailure;
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
  Map<String, dynamic> filters, {
  StylistConstraints constraints = const StylistConstraints(),
}) {
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
        facet(p.season, 'season') &&
        constraints.matches(p),
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
    final preference = constraints
        .preferenceScore(b.product)
        .compareTo(constraints.preferenceScore(a.product));
    if (preference != 0) return preference;
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
  if (result?.name == 'respond_to_question') {
    content = [
      TextPart(
        text: 'I can help build an outfit from the catalog, compare pieces, or refine a look. What are you dressing for?',
      ),
    ];
  } else if (last.role == Role.user &&
      request.tools?.any((tool) => tool.name == 'respond_to_question') ==
          true &&
      RegExp(
        r'^(?:what can (?:we do here|you do)|hello|hi)[?.!]*$',
        caseSensitive: false,
      ).hasMatch(last.text.trim())) {
    content = [
      ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'respond_to_question',
          ref: 'preview-question',
          input: {'intent': 'capabilities', 'facts': <String>[]},
        ),
      ),
    ];
  } else if (request.tools == null ||
      request.tools!.isEmpty ||
      (!request.tools!.any((tool) => tool.name == 'search_products') &&
          request.messages.any(
            (message) =>
                message.role == Role.system &&
                message.text.contains('The outfit is complete.'),
          )) ||
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
    final fields =
        RegExp(r'Ask only for missing fields: ([^.]+)')
            .firstMatch(
              request.messages
                  .where((m) => m.role == Role.system)
                  .map((m) => m.text)
                  .join(' '),
            )
            ?.group(1)
            ?.split(', ') ??
        const ['dressCode', 'budget'];
    content = [
      TextPart(
        text:
            'Tell me ${fields.map((field) => field == 'dressCode' ? 'the style or dress code' : 'your budget').join(' and ')} so I can find the right pieces.',
      ),
    ];
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
