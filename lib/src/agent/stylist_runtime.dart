import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:genkit/genkit.dart';

import '../data/models.dart';
import '../data/demo_commerce.dart';
import '../data/money.dart';
import '../data/catalog_semantics.dart';
import '../data/stylist_store.dart';
import '../data/catalog_snapshot.dart';
import '../data/catalog_search.dart';
import 'product_facts.dart';
import 'stylist_command.dart';
import 'stylist_result.dart';
import 'stylist_schemas.dart';
import 'stylist_tool_error.dart';
import 'city_context.dart';
import 'outfit_plan.dart';
import 'stylist_brief.dart';
import 'stylist_constraints.dart';
import 'stylist_input_error.dart';

const _optionalSearchNotice =
    'There are no matches for those optional search filters. These alternatives still respect your required constraints.';

typedef StylistOutfitPreview = void Function(StylistTurnResult result);

typedef StylistModel = Future<ModelResponse> Function(ModelRequest request);
typedef StylistProgress = void Function(List<Product> products);
typedef StylistTextProgress = void Function(String text);
typedef StylistResultValidator = FutureOr<void> Function(
  StylistTurnResult result,
);

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
    'The host garment audience is authoritative: female, male, or male, female. '
    'Use compatible products only; unisex products support either audience. '
    'Do not infer the wearer identity from images or assume audience from the dress category. '
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
    'That tool updates brief facts only; a saved look requires the host Save look action. '
    'Never claim a saved look, bag change or purchase without a host confirmation. '
    'Product attributes include evidence, confidence and basis; these are catalog descriptions or estimates, never verified fit, composition or weather protection. '
    'Sizes, stock, delivery and checkout are explicitly local demo fixtures. Never describe them as real inventory, measured fit, a paid order or a carrier promise. '
    'Before searching, you MUST save any explicitly supplied occasion or other fact missing from Settled brief. '
    'Mentioning a fact in your reply does not save it. Check the authoritative brief returned by the tool. '
    'When saving an occasion, include occasionEvidence quoting the user\'s actual event and keep the occasion within that quote. '
    'Never save greetings, capability questions or the entire conversation as an occasion. '
    'For combined changes, use apply_outfit_changes once with all brief edits, removals and additions before searching. '
    'Never change an explicit user fact to a suggestion. Hard exclusions must survive every search. '
    'never assume missing dressCode or budget. After an edit, use the updated tool result '
    'to search and present the next category in the same turn. '
    'Save an explicitly mentioned destination city using save_outfit city. '
    'Explicit trip dates use tripStart/tripEnd as YYYY-MM-DD; never invent a date. '
    'Use host city/forecast facts for practical temperature and rain advice. '
    'Never invent weather or claim a forecast covers dates outside its listed dates. '
    'If city context is unavailable, say so; do not replace it with made-up weather.';

double? parseStylistBudget(String message) => parseBriefBudget(message);

/// Shared by the bundled Flutter agent and the offline Genkit Developer UI.
/// Mutable draft state stays in a Dart Zone, outside serialized flow inputs.
class StylistRuntime {
  StylistRuntime({
    required List<Product> products,
    CatalogSnapshot? catalog,
    Model? providerModel,
    StylistModel? model,
    bool developerTools = false,
    this.cityContextSource,
    this.onBeginTurn,
    this.onModelRequest,
    this.onCancelTurn,
    this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       products = List.unmodifiable(products),
       catalog = catalog,
       ai = Genkit(isDevEnv: developerTools, promptDir: null) {
    if (catalog != null &&
        (catalog.products.length != products.length ||
            products.any((p) => !identical(catalog.byId[p.id], p)))) {
      throw ArgumentError('Runtime products must match the catalog snapshot.');
    }
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
            euroAmountExceeds(scope.state.spent, scope.state.budget!);
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
          // Tool-stage prose can be superseded by later tool results. Only
          // stream the final, tool-free response, without committing its draft.
          final streamText =
              scope.onText != null &&
              request.tools?.isEmpty == true &&
              _selectionOptions(scope) == null &&
              scope.confirmations.isEmpty;
          var text = '';
          var visible = '';
          void publishText() {
            scope.cancel.token.throwIfCancelled();
            // Financial prose is filtered by complete sentence. Never show a
            // partial amount that a later token would force us to retract.
            final boundary = RegExp(r'(?<=[.!?])\s+|\n+')
                .allMatches(text)
                .lastOrNull;
            final guidance = boundary == null
                ? ''
                : _withoutFinancialProse(text.substring(0, boundary.end));
            final next = [
              ..._replyPrefix(scope),
              guidance,
            ].where((part) => part.isNotEmpty).join('\n\n');
            if (next.isNotEmpty && next != visible) {
              visible = next;
              scope.onText!(next);
            }
          }

          if (streamText) publishText();
          response = await providerModel(
            request,
            cancel: scope.cancel.token,
            onChunk: streamText
                ? (chunk) {
                    scope.cancel.token.throwIfCancelled();
                    text = chunk.aggregated == true
                        ? chunk.text
                        : text + chunk.text;
                    publishText();
                  }
                : null,
          );
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
      inputSchema: stylistQuestionSchema,
      outputSchema: stylistToolOutputSchema('respond_to_question'),
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        if (!scope.allowEdits ||
            scope.searches > 0 ||
            scope.confirmations.isNotEmpty) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Answer questions before editing or searching.',
            }).toJson(),
          );
        }
        final quotes = List<String>.from(input['facts'] as List);
        if (quotes.any(
          (quote) => quote.trim().isEmpty || !scope.userMessage.contains(quote),
        )) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Facts must quote the current user message exactly.',
            }).toJson(),
          );
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
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
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
      inputSchema: stylistSearchSchema,
      outputSchema: stylistToolOutputSchema('search_products'),
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final state = scope.state;
        if (!state.briefState.canSearch) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'First save the missing brief fields',
              'missingFields': state.briefState.missingFields,
            }).toJson(),
          );
        }
        if (state
            .briefState
            .productConstraints
            .clarificationRequests
            .isNotEmpty) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error':
                  'Clarify the scope of your restrictions before searching.',
              'clarificationRequests':
                  state.briefState.productConstraints.clarificationRequests,
            }).toJson(),
          );
        }
        if (state.budget != null &&
            euroAmountExceeds(state.spent, state.budget!)) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Apply the requested outfit removals before searching.',
            }).toJson(),
          );
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
          if (state.briefState.gender.isNotEmpty)
            'gender': state.briefState.gender,
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
          constraints: state.briefState.productConstraints,
        );
        if (found.isEmpty && scope.target != null) {
          found = searchStylistProducts(candidates, {
            'query': '',
            'category': scope.target!.name,
            'priceMax': cap,
            'limit': input['limit'] ?? 6,
          }, constraints: state.briefState.productConstraints);
          if (found.isNotEmpty) {
            scope.notices.add(_optionalSearchNotice);
          }
        }
        if (found.isNotEmpty) scope.searchFoundProducts = true;
        for (final product in found) {
          state.seen[product.id] = product;
        }
        return ToolResult.response({
          'products': found.map(productFacts).toList(),
          'catalog': catalogMetadata,
          'nextCategory': scope.target?.name,
          if (scope.notices.isNotEmpty) 'notices': scope.notices.toList(),
        });
      },
    );
    ai.defineTool(
      name: 'present_products',
      description: 'Choose 1 to 5 unique IDs returned by search_products for the next A2UI cards. The host validates IDs and fills facts from the catalog.',
      inputSchema: stylistPresentSchema,
      outputSchema: stylistToolOutputSchema('present_products'),
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final ids = input['productIds'] as List;
        final state = scope.state;
        if (ids.isEmpty ||
            ids.length > 5 ||
            ids.toSet().length != ids.length ||
            ids.any((id) => id is! String || !state.seen.containsKey(id))) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error':
                  'Choose 1 to 5 unique IDs from this session search results',
            }).toJson(),
          );
        }
        if (scope.target != null &&
            ids.any((id) => state.seen[id]!.category != scope.target)) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error':
                  'Present choices for the next category: ${scope.target!.name}',
            }).toJson(),
          );
        }
        if (ids.contains(scope.adjustingProductId)) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Present alternatives to the currently selected piece.',
            }).toJson(),
          );
        }
        if (ids.any(
          (id) =>
              euroAmountExceeds(state.seen[id]!.price, scope.availableBudget),
        )) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Presentation exceeds the remaining budget; search for cheaper options',
            }).toJson(),
          );
        }
        final allowedIds = _recommendableProducts(scope)
            .map((p) => p.id)
            .toSet();
        if (ids.any((id) => !allowedIds.contains(id))) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'These choices violate your constraints or leave insufficient budget when affordable complete-outfit alternatives exist.',
            }).toJson(),
          );
        }
        scope.picks = ids.map((id) => state.seen[id]!).toList();
        scope.onProgress?.call(List<Product>.unmodifiable(scope.picks));
        return ToolResult.response({'presentedIds': ids});
      },
    );
    ai.defineTool(
      name: 'save_outfit',
      description: 'Save explicit garment gender audience, destination city, occasion, dressCode, season, budget, palette or notes from the person. Never invent missing fields. Returns the authoritative next step.',
      inputSchema: stylistBriefSchema,
      outputSchema: stylistToolOutputSchema('save_outfit'),
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
          if (next.budget != null &&
              euroAmountExceeds(scope.state.spent, next.budget!)) {
            return ToolResult.response(
              StylistToolError.fromMap({
                'error': 'Budget is below selected outfit total',
              }).toJson(),
            );
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
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
        }
      },
    );
    ai.defineTool(
      name: 'add_to_outfit',
      description: 'Record a verbal selection using a productId from the last presented choices, including ordinal choices such as the second one. Never select an unpresented ID. Then continue with the returned next category.',
      inputSchema: stylistProductIdSchema,
      outputSchema: stylistToolOutputSchema('add_to_outfit'),
      fn: (input, context) async {
        final scope = _scope;
        scope.cancel.token.throwIfCancelled();
        final id = input['productId'];
        if (!scope.state.lastPresented.contains(id)) {
          return ToolResult.response(
            StylistToolError.fromMap({
              'error': 'Choose an ID from the last presented choices',
            }).toJson(),
          );
        }
        try {
          final product = _recordSelection(scope.state, id);
          scope.confirmations.add('Selected ${product.name}.');
          scope.allowEdits = false;
          scope.picks = [];
          _refreshProgress(scope);
          return ToolResult.response(_progressFacts(scope));
        } on StylistInputError catch (error) {
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
        }
      },
    );
    ai.defineTool(
      name: 'remove_from_outfit',
      description: 'Record a verbal removal using the productId of an item currently in the host outfit. Reopen the removed category immediately.',
      inputSchema: stylistProductIdSchema,
      outputSchema: stylistToolOutputSchema('remove_from_outfit'),
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
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
        }
      },
    );
    ai.defineTool(
      name: 'apply_outfit_changes',
      description: 'Apply all requested brief changes, field clears, product removals and verbal additions together before search. Validate the resulting outfit and budget atomically. Add only IDs from last presented choices.',
      inputSchema: stylistChangesSchema,
      outputSchema: stylistToolOutputSchema('apply_outfit_changes'),
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
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
        } on FormatException catch (error) {
          scope.atomicFailure = StylistInputError(
            code: StylistInputErrorCode.invalidBrief,
            message: error.message,
          );
          return ToolResult.response(
            StylistToolError.fromMap({'error': error.message}).toJson(),
          );
        }
      },
    );
    flow = ai.defineFlow(
      name: 'stylistTurn',
      inputSchema: stylistTurnSchema,
      outputSchema: stylistResultSchema,
      fn: (input, context) => _enqueue(
        input,
        cancel: context.cancel,
        onProgress: Zone.current[_progressKey] as StylistProgress?,
        onText: Zone.current[_textProgressKey] as StylistTextProgress?,
        onOutfitPreview:
            Zone.current[_outfitPreviewKey] as StylistOutfitPreview?,
        validateResult: Zone.current[_validationKey] as StylistResultValidator?,
      ),
    );
  }

  final Genkit ai;
  final List<Product> products;
  final CatalogSnapshot? catalog;
  Map<String, Object?> get catalogMetadata =>
      catalog?.metadata ??
      {
        'revision': 'fixture-local',
        'currency': 'EUR',
        'completeSnapshot': true,
        'capabilities': const CatalogCapabilities().toJson(),
      };
  final CityContextSource? cityContextSource;
  final void Function()? onBeginTurn;
  final void Function(ModelRequest request)? onModelRequest;
  final void Function()? onCancelTurn;
  late final Flow<Map<String, dynamic>, Map<String, dynamic>, void, void> flow;
  final _outfitPreviewKey = Object();
  final _zoneKey = Object();
  final _progressKey = Object();
  final _textProgressKey = Object();
  final _validationKey = Object();
  _StylistState _state = _StylistState();
  final StylistStore? store;
  bool _loadedStore = false;
  bool _resetBeforeLoad = false;
  Map<String, Object?>? _persisted;
  bool _storeWritable = true;
  String? _localStorageNotice;
  String? get localStorageNotice => _localStorageNotice;
  bool get _canPersist => store != null && _storeWritable;
  int get bagCount => _state.bag.values.fold(0, (a, b) => a + b);
  bool get hasLocalLibrary =>
      _state.savedLooks.isNotEmpty || _state.bag.isNotEmpty;
  bool get hasCurrentLook =>
      _state.briefState.toMap().isNotEmpty ||
      _state.briefState.constraints.toMap().isNotEmpty ||
      _state.outfit.isNotEmpty ||
      _state.city.isNotEmpty;

  Map<String, Object?> _lookSnapshot(_StylistState state) => {
    'brief': state.briefState.toSnapshot(),
    'items': state.outfit.values.map((p) => p.id).toList(),
    'city': state.city,
    'fit': {
      'usualSize': state.usualSize,
      'usualSizes': state.usualSizes,
      'preferredFit': state.preferredFit,
    },
    'variants': {
      for (final p in state.outfit.values)
        if (state.productVariants[p.id] != null)
          p.id: state.productVariants[p.id],
    },
  };
  Map<String, Object?> _storeSnapshot(_StylistState state) => {
    'version': 1,
    'current': _lookSnapshot(state),
    'looks': state.savedLooks,
    'bag': state.bag,
    'reviewedBagPieces': state.reviewedBagPieces.toList(),
    'nextLookId': state.nextLookId,
    'bagVariants': state.bagVariants,
    'demoSold': state.demoSold,
    'lastDemoReceipt': state.lastDemoReceipt,
    'nextReceiptId': state.nextReceiptId,
  };

  void _restoreLook(_StylistState state, Map<String, Object?> value) {
    final rawBrief = value['brief'],
        rawIds = value['items'],
        city = value['city'];
    if (rawBrief is! Map ||
        rawIds is! List ||
        rawIds.length > 7 ||
        rawIds.any((id) => id is! String) ||
        rawIds.toSet().length != rawIds.length ||
        city is! String ||
        city.length > 100) {
      throw const FormatException('Saved look is invalid.');
    }
    final brief = StylistBrief.fromSnapshot(
      Map<String, Object?>.from(rawBrief),
    );
    final fit = value['fit'] ?? const {},
        variants = value['variants'] ?? const {};
    if (fit is! Map ||
        variants is! Map ||
        !const [
          '',
          'Fitted',
          'Regular',
          'Relaxed',
        ].contains(fit['preferredFit'] ?? '') ||
        (fit['usualSize'] ?? '') is! String ||
        (fit['usualSize'] as String? ?? '').length > 20 ||
        variants.entries.any(
          (e) => !rawIds.contains(e.key) || e.value is! String,
        )) {
      throw const FormatException('Saved size preferences are invalid.');
    }
    final usualSizes = fit['usualSizes'] ?? const {};
    if (usualSizes is! Map ||
        usualSizes.entries.any(
          (e) =>
              !const {'clothing', 'shoes', 'one_size'}.contains(e.key) ||
              e.value is! String ||
              (e.value as String).length > 20,
        )) {
      throw const FormatException('Saved size groups are invalid.');
    }
    final outfit = <String, Product>{};
    for (final id in rawIds) {
      final product = products.where((p) => p.id == id).firstOrNull;
      if (product == null) {
        throw const FormatException(
          'A saved product is no longer in the catalog.',
        );
      }
      final violations = brief.productConstraints.violations(product);
      if (violations.isNotEmpty) {
        throw FormatException(
          '${product.name} needs review: ${violations.join('; ')}',
        );
      }
      if (outfit.containsKey(product.category.name)) {
        throw const FormatException('Saved look repeats a category.');
      }
      outfit[product.category.name] = product;
      if (variants[id] != null &&
          !commerce.variants(product).any((v) => v.id == variants[id])) {
        throw const FormatException(
          'A saved demo size is no longer available.',
        );
      }
    }
    if (outfit.containsKey('dress') &&
        (outfit.containsKey('top') || outfit.containsKey('bottom'))) {
      throw const FormatException('Saved look has conflicting foundations.');
    }
    final total = sumEuros(outfit.values.map((p) => p.price));
    if (brief.budget != null && euroAmountExceeds(total, brief.budget!)) {
      throw FormatException(
        'Current catalog prices total ${formatEuros(total)}, above this saved look’s ${formatEuros(brief.budget!)} budget.',
      );
    }
    state
      ..briefState = brief
      ..usualSize = fit['usualSize'] as String? ?? ''
      ..usualSizes = Map<String, String>.from(usualSizes)
      ..preferredFit = fit['preferredFit'] as String? ?? ''
      ..productVariants = Map<String, String>.from(variants)
      ..brief = brief.planningText
      ..outfit = outfit
      ..seen = {for (final p in outfit.values) p.id: p}
      ..city = city
      ..cityContext = null
      ..cityContextNotice = null
      ..history = []
      ..lastPresented = []
      ..replacementProductId = null
      ..replacementPriceMax = null
      ..replacementDifferentColor = false;
    state.lastNextCategory = OutfitPlan.from(
      catalog: products,
      brief: brief.planningText,
      dressCode: brief.dressCode,
      constraints: brief.productConstraints,
      outfit: outfit,
    ).nextCategory;
  }

  Future<bool> loadLocalState() async {
    if (_loadedStore || store == null) return hasCurrentLook;
    try {
      return await _restoreLocalState();
    } catch (_) {
      // Preserve the original value, including malformed JSON and newer schema
      // versions. This connection stays session-only; a new connection retries
      // the read instead of silently replacing a library it could not inspect.
      _storeWritable = false;
      _loadedStore = true;
      _localStorageNotice =
          'Your saved styling library could not be opened and has been left unchanged. '
          'You can keep styling in this session; new looks will not be saved on this device.';
      return hasCurrentLook;
    }
  }

  Future<bool> _restoreLocalState() async {
    final value = await store!.read();
    if (value == null) {
      _loadedStore = true;
      return false;
    }
    _persisted = value;
    final looks = value['looks'],
        bag = value['bag'],
        next = value['nextLookId'];
    if (value['version'] != 1 ||
        looks is! List ||
        looks.length > 50 ||
        looks.any(
          (v) =>
              v is! Map ||
              v['id'] is! String ||
              v['name'] is! String ||
              v['snapshot'] is! Map,
        ) ||
        bag is! Map ||
        bag.length > products.length ||
        bag.values.any((q) => q is! int || q < 1 || q > 99) ||
        next is! int ||
        next < 1) {
      throw const FormatException('Saved styling library is invalid.');
    }
    final restored = _state.copy();
    restored.savedLooks = [
      for (final look in looks)
        Map<String, Object?>.unmodifiable(
          Map<String, Object?>.from(look as Map),
        ),
    ];
    restored.bag = {
      for (final e in bag.entries)
        if (products.any((p) => p.id == e.key)) e.key as String: e.value as int,
    };
    restored.nextLookId = next;
    final reviewed = value['reviewedBagPieces'] ?? restored.bag.keys.toList();
    if (reviewed is! List || reviewed.any((id) => id is! String)) {
      throw const FormatException('Invalid reviewed bag pieces.');
    }
    restored.reviewedBagPieces = reviewed.cast<String>().toSet();
    final bagVariants = value['bagVariants'] ?? const {},
        sold = value['demoSold'] ?? const {};
    if (bagVariants is! Map ||
        sold is! Map ||
        bagVariants.entries.any(
          (e) => e.key is! String || e.value is! String,
        ) ||
        sold.entries.any(
          (e) => e.key is! String || e.value is! int || (e.value as int) < 0,
        )) {
      throw const FormatException('Saved demo inventory is invalid.');
    }
    restored.demoSold = Map<String, int>.from(sold);
    restored.bagVariants = {
      for (final e in bagVariants.entries)
        if (restored.bag.containsKey(e.key) &&
            products.any(
              (p) =>
                  p.id == e.key &&
                  commerce.variants(p).any((v) => v.id == e.value),
            ))
          e.key as String: e.value as String,
    };
    restored.nextReceiptId =
        value['nextReceiptId'] is int && (value['nextReceiptId'] as int) > 0
        ? value['nextReceiptId'] as int
        : 1;
    if (value['lastDemoReceipt'] is Map) {
      restored.lastDemoReceipt = Map<String, Object?>.from(
        value['lastDemoReceipt'] as Map,
      );
    }
    var resumed = false;
    if (!_resetBeforeLoad && value['current'] is Map) {
      try {
        _restoreLook(
          restored,
          Map<String, Object?>.from(value['current'] as Map),
        );
        resumed =
            restored.briefState.toMap().isNotEmpty ||
            restored.briefState.constraints.toMap().isNotEmpty ||
            restored.city.isNotEmpty ||
            restored.outfit.isNotEmpty;
      } on FormatException catch (error) {
        restored.libraryNotice =
            'Your previous look needs review: ${error.message}';
      }
    }
    _state = restored;
    _loadedStore = true;
    return resumed;
  }

  final Set<CancellationController> _active = {};
  final DateTime Function() now;
  final commerce = const DemoCommerce();
  bool _disposed = false;
  Future<void> _pending = Future.value();
  _TurnScope get _scope => Zone.current[_zoneKey] as _TurnScope;
  Map<String, Object?> get outfit => {
    'budget': _state.budget,
    'items': {
      for (final entry in _state.outfit.entries) entry.key: entry.value.id,
    },
  };

  void reset({DemoJourney? journey}) {
    _resetBeforeLoad = true;
    final previous = _state;
    _state = _StylistState()
      ..savedLooks = List.of(previous.savedLooks)
      ..bag = Map.of(previous.bag)
      ..reviewedBagPieces = Set.of(previous.reviewedBagPieces)
      ..bagVariants = Map.of(previous.bagVariants)
      ..demoSold = Map.of(previous.demoSold)
      ..lastDemoReceipt = previous.lastDemoReceipt
      ..nextReceiptId = previous.nextReceiptId
      ..usualSize = previous.usualSize
      ..usualSizes = Map.of(previous.usualSizes)
      ..preferredFit = previous.preferredFit
      ..nextLookId = previous.nextLookId
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
  }

  Future<StylistTurnResult> turn(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistTextProgress? onText,
    StylistOutfitPreview? onOutfitPreview,
    StylistResultValidator? validateResult,
  }) => runZoned(
    () async => await flow(input, cancel: cancel) as StylistTurnResult,
    zoneValues: {
      _progressKey: onProgress,
      _textProgressKey: onText,
      _outfitPreviewKey: onOutfitPreview,
      _validationKey: validateResult,
    },
  );

  /// Invalidates draft work without discarding the last committed outfit.
  void cancelActiveTurn() {
    for (final cancellation in _active.toList()) {
      cancellation.cancel('Stylist turn superseded');
    }
  }

  Future<StylistTurnResult> _enqueue(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistTextProgress? onText,
    StylistOutfitPreview? onOutfitPreview,
    StylistResultValidator? validateResult,
  }) {
    if (_disposed) return Future.error(StateError('Model connection closed'));
    final result = _pending.then((_) async {
      await loadLocalState();
      return _execute(
        input,
        cancel: cancel,
        onProgress: onProgress,
        onText: onText,
        onOutfitPreview: onOutfitPreview,
        validateResult: validateResult,
      );
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<StylistTurnResult> _execute(
    Map<String, dynamic> input, {
    CancellationToken? cancel,
    StylistProgress? onProgress,
    StylistTextProgress? onText,
    StylistOutfitPreview? onOutfitPreview,
    StylistResultValidator? validateResult,
  }) async {
    if (_disposed) throw StateError('Model connection closed');
    input = (await StylistTurnInput.decode(input)).toJson();
    final cancellation = CancellationController();
    final unlink = cancel?.link(cancellation);
    _active.add(cancellation);
    final timer = Timer(
      const Duration(seconds: 60),
      () => cancellation.cancel('Stylist turn timed out'),
    );
    final state = _state.copy();
    final scope = _TurnScope(
      state,
      cancellation,
      onProgress,
      onText,
      onOutfitPreview,
    );
    onBeginTurn?.call();
    final removeCancel = cancellation.token.onCancel(
      () => onCancelTurn?.call(),
    );
    try {
      // A direct Developer UI run reaches this same path with an offline model.
      // The flow queues this turn; ai.run traces the nested work without re-entering it.
      final result = await Future.any<StylistTurnResult>([
        runZoned(
          () =>
              ai.run('stylistTurn.execute', () => _generateTurn(input, scope)),
          zoneValues: {_zoneKey: scope},
        ),
        cancellation.token.whenCancelled.then<StylistTurnResult>(
          (_) => throw CancelledException(
            token: cancellation.token,
            reason: cancellation.token.reason,
          ),
        ),
      ]);
      cancellation.token.throwIfCancelled();
      if (_disposed) throw StateError('Model connection closed');
      if ((await stylistResultSchema.validate(result.toJson())).isNotEmpty) {
        throw const FormatException('Invalid stylist result');
      }
      await validateResult?.call(result);
      cancellation.token.throwIfCancelled();
      if (_disposed) throw StateError('Model connection closed');
      if (_canPersist) {
        final previous = _persisted ?? _storeSnapshot(_state);
        final next = _storeSnapshot(state);
        try {
          await store!.write(next);
          cancellation.token.throwIfCancelled();
          if (_disposed) throw StateError('Model connection closed');
          await validateResult?.call(result);
          cancellation.token.throwIfCancelled();
          if (_disposed) throw StateError('Model connection closed');
          _persisted = next;
        } catch (_) {
          try {
            await store!.write(previous);
          } catch (_) {
            /* Keep the working draft uncommitted. */
          }
          cancellation.token.throwIfCancelled();
          if (_disposed) throw StateError('Model connection closed');
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidBrief,
            message: 'Could not update local storage. Your working look is unchanged; try again.',
          );
        }
      }
      _state = state;
      return result;
    } finally {
      timer.cancel();
      removeCancel();
      unlink?.call();
      _active.remove(cancellation);
    }
  }

  Future<StylistTurnResult> _generateTurn(
    Map<String, dynamic> input,
    _TurnScope scope,
  ) async {
    final state = scope.state;
    var message = (input['message'] as String?) ?? '';
    final restart = input['action'] == null
        ? restartStylistBrief(message)
        : null;
    if (restart != null) {
      _libraryAction(scope, 'reset_look', const {});
      message = restart;
      if (message.isNotEmpty) scope.hostReply = null;
    }
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
    if (message.isEmpty && action == null && restart == null) {
      throw const FormatException('A message or action is required');
    }
    var actionNote = '';
    ProductCategory? removedCategory;
    ProductCategory? adjustedCategory;
    if (action == null) {
      final command = _localCommand(message);
      if (RegExp(
        r"^(?:i(?:['’]ve| have)? )?(?:changed? my mind|want a change)[.!?]*$",
        caseSensitive: false,
      ).hasMatch(message.trim())) {
        scope.questionIntent = 'change_direction';
        scope.hostReply =
            'Would you like to change a selected piece or start a new look?';
      }
      if (command != null) {
        if (const {
          'preview_demo_checkout',
          'open_demo_receipt',
        }.contains(command)) {
          _commerceAction(scope, command, const {});
        } else {
          _libraryAction(scope, command, const <String, Object?>{});
        }
      } else if (RegExp(
            r'^(?:what|which|how|does|is|are)\b|^show (?:me )?(?:the )?(?:sizes|stock|details)',
            caseSensitive: false,
          ).hasMatch(message) &&
          RegExp(
            r'\b(?:sizes?|fit|stock|availability|details)\b',
            caseSensitive: false,
          ).hasMatch(message)) {
        final named = state.seen.values
            .where((p) => message.toLowerCase().contains(p.name.toLowerCase()))
            .toList();
        final askedCategory = requestedProductCategory(message);
        final categoryMatches = state.seen.values
            .where((p) => p.category == askedCategory)
            .toList();
        final selected = named.length == 1
            ? named.single
            : askedCategory != null
            ? (categoryMatches.length == 1 ? categoryMatches.single : null)
            : state.outfit.length == 1
            ? state.outfit.values.single
            : null;
        if (selected != null) {
          _commerceAction(scope, 'open_product_details', {
            'productId': selected.id,
          });
        }
      }
      final sizeMatch = RegExp(
        r'\b(?:I (?:usually )?(?:wear|take)|(?:my |usual )?size(?: is)?)\s+(XS|XL|S|M|L|3[6-9]|4[0-6])\b',
        caseSensitive: false,
      ).firstMatch(message);
      final size = sizeMatch?.group(1)?.toUpperCase();
      if (size != null) {
        state.usualSize = size;
        state.usualSizes[int.tryParse(size) == null ? 'clothing' : 'shoes'] =
            size;
        scope.notices.add('Usual size $size noted.');
        if (sizeMatch!.start == 0 &&
            message
                .substring(sizeMatch.end)
                .replaceAll(RegExp(r'[.!?\s]'), '')
                .isEmpty) {
          scope.questionIntent = 'commerce';
          scope.hostReply = 'Your usual size is saved. Choose a size for each piece to confirm your selection.';
        }
      }
    }
    if (action != null) {
      final context = action['context'] as Map;
      if (action['name'] == 'refresh_city_context' &&
          cityContextSource != null &&
          state.city.isNotEmpty) {
        await _loadCityContext(state, refresh: true);
        scope.cancel.token.throwIfCancelled();
        return StylistTurnResult(
          demoSold: state.demoSold,
          reply: state.lastReply,
          intent: 'weather',
          products: const [],
          brief: state.briefState,
          outfit: state.outfit,
          catalog: catalogMetadata,
          view: StylistViewState(
            updateCurrentInlineOnly: true,
            turn: state.turn,
            picks: state.lastPresented.map((id) => state.seen[id]!).toList(),
            clarification:
                state.lastQuestionIntent != null || state.briefState.canSearch
                ? null
                : {
                    'missingFields': state.briefState.missingFields,
                    ...state.briefState.toMap(),
                  },
            plan: OutfitPlan.from(
              catalog: products,
              outfit: state.outfit,
              brief: state.briefState.planningText,
              constraints: state.briefState.productConstraints,
              dressCode: state.briefState.dressCode,
            ),
            nextCategory: state.lastNextCategory,
            budgetAdjustment: _budgetAdjustment(
              state,
              target: state.lastNextCategory,
            ),
            cityContext: state.cityContext,
            cityContextNotice: state.cityContextNotice,
            city: state.city,
          ),
        );
      } else if (const {
        'open_product_details',
        'set_fit_size',
        'set_product_options',
        'choose_product_colour',
        'preview_demo_checkout',
        'confirm_demo_checkout',
        'open_demo_receipt',
      }.contains(action['name'])) {
        _commerceAction(scope, action['name'] as String, context);
      } else if (const {
        'resume_session',
        'open_saved_looks',
        'save_look',
        'restore_look',
        'delete_look',
        'reset_look',
        'open_bag',
        'close_bag',
        'add_look_to_bag',
        'change_bag_quantity',
        'remove_bag_item',
        'restore_bag_item',
        'undo_bag_changes',
      }.contains(action['name'])) {
        _libraryAction(scope, action['name'] as String, context);
      } else if (action['name'] == 'edit_preferences') {
        scope.questionIntent = 'preferences';
        scope.preferencePanel = true;
        scope.hostReply = 'Choose your preferred colors and catalog brands, or mark pieces you already own. Update preferences to apply them together.';
      } else if (const {
        'update_preferences',
        'set_colours',
        'set_brand_preferences',
      }.contains(action['name'])) {
        try {
          final colors = _choiceValues(
            context['colours'],
            catalogColorFamilies.keys,
          );
          final brands = products.map((p) => p.brand).toSet();
          final love = _choiceValues(context['love'], brands);
          final skip = _choiceValues(context['skip'], brands);
          final previous = state.briefState.constraints;
          final nextLove = love ?? previous.preferredBrands;
          final nextSkip = skip ?? previous.excludedBrands;
          if (nextLove.intersection(nextSkip).isNotEmpty) {
            throw const FormatException(
              'A brand cannot be both loved and skipped.',
            );
          }
          Set<ProductCategory>? owned;
          if (context['owned'] != null) {
            final values = context['owned'];
            if (values is! Map ||
                values.keys.any(
                  (key) => !ProductCategory.values.any((c) => c.name == key),
                ) ||
                values.values.any((value) => value is! bool)) {
              throw const FormatException(
                'Choose which categories you already own.',
              );
            }
            owned = {
              for (final c in ProductCategory.values)
                if (values[c.name] == true) c,
            };
          }
          state.briefState = state.briefState.withConstraints(
            previous.copyWith(
              preferredColors: colors,
              preferredBrands: love,
              excludedBrands: skip,
              ownedCategories: owned,
            ),
          );
          final dates = <String, Object?>{
            for (final name in ['tripStart', 'tripEnd'])
              if (context[name] != null) name: context[name],
          };
          state.briefState = state.briefState.merge(
            dates,
            clearFields: {
              for (final entry in dates.entries)
                if (entry.value == '') entry.key,
            },
          );
          adjustedCategory = state.lastNextCategory;
          scope.confirmations.add('Preferences updated.');
        } on FormatException catch (error) {
          throw StylistInputError(
            code: StylistInputErrorCode.invalidBrief,
            message: error.message,
          );
        }
      } else if (action['name'] == 'compare_products') {
        if (state.lastPresented.length != 2 ||
            state.lastPresented.any(
              (id) =>
                  state.seen[id] == null ||
                  !state.briefState.productConstraints.matches(state.seen[id]!),
            )) {
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidSelection,
            message:
                'Choose two current, compatible recommendations to compare.',
          );
        }
        scope.picks = state.lastPresented.map((id) => state.seen[id]!).toList();
        scope.questionIntent = 'comparison';
        scope.presentation = 'compare';
        scope.hostReply = scope.picks
            .map(
              (p) =>
                  '${p.name}: ${p.description.isEmpty ? p.color : p.description}',
            )
            .join('\n\n');
      } else if (action['name'] == 'find_options' ||
          action['name'] == 'update_budget') {
        StylistBrief next;
        try {
          next = state.briefState.merge({
            for (final name
                in action['name'] == 'update_budget'
                    ? ['budget']
                    : ['dressCode', 'season', 'budget', 'gender'])
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
        if (action['name'] == 'update_budget') {
          adjustedCategory = state.lastNextCategory;
        }
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
        if (context['productId'] != null &&
            context['productId'] != selected.id) {
          throw const StylistInputError(
            code: StylistInputErrorCode.invalidAdjustment,
            message:
                'That piece has changed. Choose the currently selected piece.',
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
        state.replacementProductId = selected.id;
        state.replacementPriceMax = _requestsCheaper(adjustment)
            ? _cheaperCeiling(selected)
            : null;
        state.replacementDifferentColor =
            adjustment.toLowerCase() == 'another colour';
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
    if (action == null &&
        RegExp(
          r'\b(?:edit|show|choose|explore)\b[^.!?]*\b(?:colou?rs?|brands?|preferences)\b',
          caseSensitive: false,
        ).hasMatch(message)) {
      scope.questionIntent = 'preferences';
      scope.preferencePanel = true;
      scope.hostReply = 'Choose your preferences, then Update preferences to apply them together.';
    }
    final budget = scope.userBudget;
    final weatherQuestion =
        action == null &&
        (isWeatherQuestion(message) ||
            (state.lastQuestionIntent == 'weather' &&
                state.city.isEmpty &&
                parseDestinationCity(message, allowBare: true) != null));
    if (message.isNotEmpty && !weatherQuestion) {
      if (state.brief.isEmpty) {
        state.brief = message;
      } else if (message != state.brief) {
        state.preferences.add(message);
      }
    }
    try {
      state.briefState = state.briefState.recordMessage(
        weatherQuestion ? '' : message,
        budget: weatherQuestion ? null : budget,
        knownBrands: products.map((product) => product.brand),
      );
    } on FormatException catch (error) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidBrief,
        message: error.message,
      );
    }
    for (final category in state.briefState.constraints.ownedCategories) {
      final selected = state.outfit[category.name];
      if (selected != null) {
        final removed = _recordRemoval(state, selected.id);
        scope.confirmations.add(
          'Use your own ${category.name}; removed ${removed.name} from the shopping total.',
        );
      }
    }
    // Combined removals and a lower budget are validated against the final draft.
    // A budget-only conflict remains a cheap, immediately correctable input error.
    if (!RegExp(
      r'\b(?:remove|drop|reject|discard)\b',
      caseSensitive: false,
    ).hasMatch(message)) {
      _checkBudget(state);
    }
    final mentionedCity = parseDestinationCity(
      message,
      allowBare: state.lastQuestionIntent == 'weather' && state.city.isEmpty,
    );
    if (mentionedCity != null) {
      final parts = mentionedCity.split(',');
      final name = parts.first.trim();
      final country = parts.length > 1 ? parts.skip(1).join(',').trim() : null;
      // A repeated city name must not erase a previously explicit country.
      if (country != null ||
          state.city.split(',').first.toLowerCase() != name.toLowerCase()) {
        state.city = [name, ?country].join(', ');
      }
    }
    if (weatherQuestion) scope.questionIntent = 'weather';
    if (action == null ||
        state.city != scope.beforeInput!.city ||
        scope.questionIntent == 'weather' ||
        action['name'] == 'resume_session') {
      await _loadCityContext(state, refresh: weatherQuestion);
    }
    scope.cancel.token.throwIfCancelled();
    final openingJourney =
        state.catalogOccasion.isNotEmpty && message == state.brief;
    scope.requested =
        adjustedCategory ??
        (openingJourney
            ? null
            : requestedProductCategory(
                message,
                constraints: state.briefState.productConstraints,
              )) ??
        removedCategory;
    if (action == null && _rejectsCheaper(message)) {
      final selected = state.outfit.values
          .where((p) => p.id == state.replacementProductId)
          .firstOrNull;
      state.replacementPriceMax = null;
      if (selected != null) {
        scope.requested = selected.category;
        scope.adjustingProductId = selected.id;
        adjustedCategory = selected.category;
      }
      scope.notices.add('Replacements do not have to be cheaper.');
    } else if (action == null && _requestsCheaper(message)) {
      final category =
          scope.requested ??
          (state.outfit.length == 1
              ? state.outfit.values.single.category
              : null);
      final selected = category == null ? null : state.outfit[category.name];
      if (selected != null) {
        scope.requested = category;
        scope.adjustingProductId = selected.id;
        state.replacementProductId = selected.id;
        state.replacementPriceMax = _cheaperCeiling(selected);
        state.replacementDifferentColor = false;
        adjustedCategory = category;
      }
    } else if (action == null &&
        scope.requested != null &&
        message.isNotEmpty) {
      state.replacementPriceMax = null;
      state.replacementProductId = null;
      state.replacementDifferentColor = false;
    }
    scope.allowEdits =
        adjustedCategory == null && message.isNotEmpty && !openingJourney;
    scope.removing = RegExp(
      r'\b(?:remove|drop|reject|discard)\b',
      caseSensitive: false,
    ).hasMatch(message);
    _refreshProgress(scope, requested: scope.requested);
    if (scope.onOutfitPreview != null &&
        const {
          'select_product',
          'choose_product_colour',
          'set_product_options',
        }.contains(action?['name'])) {
      scope.onOutfitPreview!(
        StylistTurnResult(
          reply: '',
          products: const [],
          brief: state.briefState,
          outfit: state.outfit,
          catalog: catalogMetadata,
          view: StylistViewState(
            turn: state.turn,
            picks: const [],
            plan: scope.plan!,
          ),
        ),
      );
    }
    state.turn++;
    final userTurn = Message(
      role: Role.user,
      content: [
        TextPart(
          text: [message, actionNote].where((s) => s.isNotEmpty).join('\n'),
        ),
      ],
    );
    final openingSizingOptions = _selectionOptions(scope);
    final directReply =
        scope.hostReply ??
        (!scope.needsProducts
            ? (openingSizingOptions?['question'] as String?)
            : null) ??
        (scope.questionIntent == 'weather'
            ? _weatherAnswer(state, message)
            : null);
    final response = directReply != null
        ? null
        : await ai.generate(
            model: modelRef('stylist/model'),
            messages: [...state.history, userTurn],
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
    if (response != null && response.finishReason != FinishReason.stop) {
      throw StateError('Incomplete model response');
    }
    state.history = response == null
        ? [
            ...state.history,
            userTurn,
            Message(
              role: Role.model,
              content: [TextPart(text: directReply!)],
            ),
          ]
        : response.messages
              .where((message) => message.role != Role.system)
              .toList();
    final generatedReply = response == null
        ? directReply!
        : response.text.trim().isEmpty
        ? (scope.picks.isEmpty
              ? 'Tell me the occasion and budget, and I can find some options.'
              : 'Here are a few options from the catalog.')
        : response.text.trim();
    if (scope.needsProducts && scope.picks.isEmpty) {
      throw StateError('Stylist did not present the next outfit choices');
    }
    // Tool selections can change the outfit during generation too.
    final sizingOptions = _selectionOptions(scope);
    // Financial facts belong to the host; retain stylist guidance separately.
    final guidance =
        (sizingOptions?['question'] as String?) ??
        directReply ??
        _withoutFinancialProse(generatedReply);
    final plan = scope.plan!;
    // Side answers do not create new recommendations, but their latest surface
    // keeps already validated choices actionable after history becomes read-only.
    final visiblePicks =
        scope.questionIntent != null &&
            scope.picks.isEmpty &&
            !scope.preferencePanel &&
            !scope.showBag &&
            scope.detailProduct == null &&
            !scope.showCheckout &&
            !scope.showReceipt &&
            !scope.showSavedLooks &&
            scope.questionIntent != 'change_direction'
        ? [
            for (final id in state.lastPresented)
              if (state.seen[id] != null &&
                  state.briefState.productConstraints.matches(
                    state.seen[id]!,
                  ) &&
                  state.replacementPermits(state.seen[id]!))
                state.seen[id]!,
          ]
        : scope.picks;
    final savedOptions =
        action?['name'] == 'set_product_options' ||
        (action?['name'] == 'set_fit_size' &&
            state.outfit.values.any(
              (product) =>
                  product.id == (action?['context'] as Map?)?['productId'],
            ));
    final nextCategory = savedOptions
        ? (visiblePicks.firstOrNull?.category ?? plan.nextCategory)
        : scope.target;
    final nextStep = !state.briefState.canSearch
        ? 'Tell me ${state.briefState.missingFields.map((field) => field == 'dressCode' ? 'the style or dress code' : 'your budget').join(' and ')} so I can find the right pieces.'
        : state.briefState.productConstraints.clarificationRequests.isNotEmpty
        ? state.briefState.productConstraints.clarificationRequests.join(' ')
        : nextCategory == null && plan.complete
        ? 'Your look is complete. Keep it, or tell me which piece you want to swap.'
        : nextCategory == null
        ? 'Remove or replace the selected pieces that conflict with your instructions before completing the look.'
        : scope.needsProducts || savedOptions && visiblePicks.isNotEmpty
        ? 'Next, choose ${_categoryLabel(nextCategory)} to continue the look.'
        : scope.adjustingProductId != null
        ? state.replacementPriceMax != null
              ? 'There are no lower-priced compatible alternatives. Keep this piece or choose a different adjustment.'
              : 'There are no alternatives for that piece within the available budget. '
                    'Keep it, or raise the budget to see more options.'
        : state.briefState.productConstraints.toMap().isNotEmpty
        ? 'There are no ${_categoryLabel(nextCategory)} that satisfy your current constraints and budget. '
              'Change a restriction, use something you own, raise the budget or replace a selected piece.'
        : 'There are no ${_categoryLabel(nextCategory)} in the catalog within the available budget. '
              'Would you like to raise the budget or replace a selected piece?';
    // Selection and sizing are one host-owned conversational step. Model prose
    // can repeat the confirmation, so use the same canonical guidance for taps
    // and selections made by tools.
    final selectionConfirmed = scope.confirmations.any(
      (text) => text.startsWith('Selected '),
    );
    final selectionGuidance = selectionConfirmed
        ? (sizingOptions == null ? nextStep : guidance)
        : null;
    final reply = [
      ..._replyPrefix(scope, selectionGuidance: selectionGuidance),
      if (!selectionConfirmed)
        [
          guidance,
          if (savedOptions) nextStep,
        ].where((text) => text.isNotEmpty).join(' '),
      if (!selectionConfirmed &&
          !savedOptions &&
          sizingOptions == null &&
          scope.questionIntent == null &&
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
    final adjusting = state.outfit.values
        .where((p) => p.id == scope.adjustingProductId)
        .firstOrNull;
    final presentation =
        scope.presentation == 'compare' ||
            RegExp(
              r'\b(?:compare|this or that|which of (?:these|the) two)\b',
              caseSensitive: false,
            ).hasMatch(message)
        ? (scope.picks.length == 2 ? 'compare' : 'strip')
        : adjusting != null
        ? (scope.picks.length == 1
              ? 'alternative'
              : scope.picks.length == 2
              ? 'compare'
              : 'strip')
        : RegExp(
            r'\b(?:browse|shortlist)\b',
            caseSensitive: false,
          ).hasMatch(message)
        ? 'strip'
        : 'cards';
    final alternatives = adjusting == null
        ? const <Product>[]
        : _recommendableProducts(scope)
              .where(
                (p) =>
                    p.category == adjusting.category &&
                    !euroAmountExceeds(p.price, scope.availableBudget),
              )
              .toList();
    final options = sizingOptions;
    final details = _productDetailData(scope);
    final showCityContext =
        scope.beforeInput!.turn == 0 ||
        state.city != scope.beforeInput!.city ||
        weatherQuestion ||
        action?['name'] == 'resume_session';
    return StylistTurnResult(
      demoSold: state.demoSold,
      reply: reply,
      intent: scope.questionIntent,
      products: scope.picks,
      brief: state.briefState,
      outfit: state.outfit,
      catalog: catalogMetadata,
      view: StylistViewState(
        turn: state.turn,
        picks: options != null || details != null ? const [] : visiblePicks,
        clarification:
            (scope.questionIntent != null &&
                    scope.questionIntent != 'resume') ||
                state.briefState.canSearch
            ? null
            : {
                'missingFields': state.briefState.missingFields,
                ...state.briefState.toMap(),
              },
        plan: plan,
        nextCategory: scope.target,
        budgetAdjustment:
            scope.questionIntent == null || scope.questionIntent == 'weather'
            ? _budgetAdjustment(
                state,
                target: scope.target ?? state.lastNextCategory,
              )
            : null,
        cityContext: showCityContext ? state.cityContext : null,
        cityContextNotice: showCityContext ? state.cityContextNotice : null,
        city: state.city,
        inspectProducts: true,
        productDetails: options == null ? details : null,
        selectionOptions: options,
        changeDirection: scope.questionIntent == 'change_direction',
        presentation: presentation,
        adjusting: adjusting,
        adjustmentSelected: adjusting == null
            ? ''
            : state.replacementPriceMax != null
            ? 'Cheaper'
            : state.replacementDifferentColor
            ? 'Another colour'
            : 'Something similar',
        adjustmentOptions: [
          if (adjusting != null &&
              alternatives.any((p) => p.priceCents < adjusting.priceCents))
            'Cheaper',
          if (adjusting != null &&
              alternatives.any((p) => differentCatalogColor(p, adjusting)))
            'Another colour',
          'Something similar',
        ],
        preferences: scope.preferencePanel ? _preferenceData(state) : null,
        canEditPreferences:
            state.briefState.canSearch &&
            (scope.questionIntent == null ||
                const {
                  'resume',
                  'library',
                  'weather',
                }.contains(scope.questionIntent)),
        ownedCategories: state.briefState.constraints.ownedCategories,
        showCompletion:
            !scope.showBag &&
            (scope.questionIntent == null ||
                const {'resume', 'library'}.contains(scope.questionIntent)),
        library:
            const {
              'capabilities',
              'styling_advice',
            }.contains(scope.questionIntent)
            ? null
            : _libraryData(scope),
      ),
    );
  }

  List<Product> _colourVariants(_StylistState state, Product product) {
    if (product.variantGroup.isEmpty || product.color.isEmpty) return [product];
    final otherSpend = sumEuros(
      state.outfit.values.where((p) => p.id != product.id).map((p) => p.price),
    );
    final colours = <String>{product.color.toLowerCase()};
    return [
      product,
      for (final candidate in products)
        if (candidate.id != product.id &&
            candidate.variantGroup == product.variantGroup &&
            candidate.brand == product.brand &&
            candidate.category == product.category &&
            candidate.color.isNotEmpty &&
            candidate.supportsGender(state.briefState.gender) &&
            commerce
                .variants(candidate, sold: state.demoSold)
                .any((v) => v.stock > 0) &&
            state.briefState.productConstraints.matches(candidate) &&
            (state.budget == null ||
                !euroAmountExceeds(
                  sumEuros([otherSpend, candidate.price]),
                  state.budget!,
                )) &&
            colours.add(candidate.color.toLowerCase()))
          candidate,
    ];
  }

  Map<String, Object?>? _selectionOptions(_TurnScope scope) {
    if (scope.questionIntent != null && scope.optionsProduct == null) {
      return null;
    }
    final state = scope.state;
    final product =
        scope.optionsProduct ??
        state.outfit.entries
            .where(
              (entry) =>
                  scope.beforeInput?.outfit[entry.key]?.id != entry.value.id,
            )
            .map((entry) => entry.value)
            .firstOrNull;
    if (product == null) return null;
    final choices = _colourVariants(state, product);
    if (choices.length < 2 &&
        commerce
                .variants(product, sold: state.demoSold)
                .where((v) => v.stock > 0)
                .length <
            2) {
      return null;
    }
    return {
      'productId': product.id,
      'fits': DemoCommerce.fitsFor(product),
      'fit': DemoCommerce.fitsFor(product).isEmpty ? '' : state.preferredFit,
      'question':
          'Choose your ${DemoCommerce.fitsFor(product).isEmpty ? 'size' : 'size and preferred fit'} below.',
      'saveLabel': DemoCommerce.fitsFor(product).isEmpty
          ? 'Save size'
          : 'Save size & fit',
      'choices': [
        for (final choice in choices)
          {
            'id': choice.id,
            'name': choice.name,
            'colour': choice.color,
            'imageAsset': choice.imageAsset,
            'swatch': choice.swatch,
            'price': formatEuros(choice.price),
            'sizes': commerce
                .variants(choice, sold: state.demoSold)
                .where((v) => v.stock > 0)
                .map((v) => v.size)
                .toList(),
            'size':
                _selectedVariant(state, choice)?.size ??
                state.usualSizes[_sizeGroup(choice)] ??
                '',
          },
      ],
    };
  }

  DemoVariant? _selectedVariant(
    _StylistState state,
    Product product, {
    bool bag = false,
  }) => commerce
      .variants(product, sold: state.demoSold)
      .where(
        (v) =>
            v.id ==
            (bag
                ? state.bagVariants[product.id]
                : state.productVariants[product.id]),
      )
      .firstOrNull;

  void _checkDemoStock(_StylistState state, Product product, int quantity) {
    final variant = _selectedVariant(state, product, bag: true);
    if (variant != null && quantity > variant.stock) {
      throw FormatException(
        'Only ${variant.stock} units of demo size ${variant.size} remain for ${product.name}. This is fictional inventory.',
      );
    }
  }

  Map<String, Object?> _checkoutData(_StylistState state) {
    if (state.bag.isEmpty) {
      throw const FormatException('Add pieces to your demo bag first.');
    }
    final lines = <Map<String, Object?>>[];
    for (final entry in state.bag.entries) {
      final product = products.firstWhere((p) => p.id == entry.key);
      final variant = _selectedVariant(state, product, bag: true);
      if (variant == null) {
        throw FormatException(
          'Choose a demo size for ${product.name} before previewing checkout.',
        );
      }
      _checkDemoStock(state, product, entry.value);
      lines.add({
        'productId': product.id,
        'variantId': variant.id,
        'name': product.name,
        'size': variant.size,
        'quantity': entry.value,
        'unitCents': (product.price * 100).round(),
      });
    }
    final delivery = commerce.delivery(today: now(), destination: state.city);
    final subtotal = lines.fold<int>(
      0,
      (sum, p) => sum + (p['unitCents'] as int) * (p['quantity'] as int),
    );
    return {
      'mode': 'local_demo',
      'currency': 'EUR',
      'lines': lines,
      'subtotalCents': subtotal,
      'shippingCents': DemoCommerce.shippingCents,
      'taxCents': 0,
      'totalCents': subtotal + DemoCommerce.shippingCents,
      'delivery': delivery,
      'key': jsonEncode([lines, delivery]),
    };
  }

  void _commerceAction(_TurnScope scope, String name, Map context) {
    final state = scope.state;
    scope.questionIntent = 'commerce';
    try {
      if (name == 'set_product_options' || name == 'choose_product_colour') {
        final current = state.outfit.values
            .where((p) => p.id == context['productId'])
            .firstOrNull;
        if (current == null) {
          throw const FormatException(
            'Choose options for a currently selected piece.',
          );
        }
        final target = _colourVariants(state, current)
            .where(
              (p) => name == 'choose_product_colour'
                  ? displayDetail(p.color) == context['colour']
                  : p.id == (context['colourProductId'] ?? current.id),
            )
            .firstOrNull;
        if (target == null) {
          throw const FormatException('Choose one of the available colours.');
        }
        if (name == 'set_product_options' &&
            (context['size'] is! String ||
                (context['size'] as String).isEmpty)) {
          throw const FormatException('Choose a size to continue.');
        }
        if (target.id != current.id) {
          state.seen[target.id] = target;
          _recordSelection(state, target.id);
        }
        if (name == 'choose_product_colour') {
          scope.optionsProduct = target;
          scope.confirmations.add('Selected ${target.name}.');
          scope.hostReply = 'Choose your size and preferred fit below.';
          return;
        }
        _commerceAction(scope, 'set_fit_size', {
          ...context,
          'productId': target.id,
        });
        scope.detailProduct = null;
        return;
      }
      if (name == 'open_demo_receipt') {
        if (state.lastDemoReceipt == null) {
          throw const FormatException('No simulated checkout receipt yet.');
        }
        scope.showReceipt = true;
        scope.hostReply = 'Your last simulated checkout receipt. No real order or payment was created.';
        return;
      }
      if (name == 'preview_demo_checkout') {
        _checkoutData(state);
        scope.showCheckout = true;
        scope.hostReply = 'Review your local demo checkout. Shipping, tax and delivery are fictional; no payment details are collected.';
        return;
      }
      if (name == 'confirm_demo_checkout') {
        final quote = _checkoutData(state);
        if (context['quoteKey'] != quote['key']) {
          throw const FormatException(
            'Your demo bag or delivery scenario changed. Review checkout again.',
          );
        }
        for (final line in quote['lines'] as List) {
          final id = line['variantId'] as String;
          state.demoSold[id] =
              (state.demoSold[id] ?? 0) + (line['quantity'] as int);
        }
        state.lastDemoReceipt = Map.unmodifiable(
          {
            ...quote,
            'id': 'demo-checkout-${state.nextReceiptId++}',
            'createdAt': now().toUtc().toIso8601String(),
            'status': 'simulated',
          }..remove('key'),
        );
        state.bag.clear();
        state.bagVariants.clear();
        state.bagUndo = null;
        state.bagVariantsUndo = null;
        state.removedBagItems.clear();
        state.removedBagVariants.clear();
        scope.showReceipt = true;
        scope.hostReply = 'Demo checkout complete. Your local demo stock was updated and the bag cleared. No payment, real order or shipment was created.';
        return;
      }
      final id = context['productId'];
      final product = products.where((p) => p.id == id).firstOrNull;
      if (product == null ||
          (!state.seen.containsKey(id) &&
              !state.bag.containsKey(id) &&
              !state.outfit.values.any((p) => p.id == id))) {
        throw const FormatException(
          'Open details for a current recommendation, selected piece or bag item.',
        );
      }
      scope.detailProduct = product;
      if (name == 'set_fit_size') {
        final size = context['size'], fit = context['fit'];
        if (size is! String ||
            size.isEmpty ||
            (DemoCommerce.fitsFor(product).isNotEmpty &&
                !DemoCommerce.fitsFor(product).contains(fit))) {
          throw const FormatException('Choose a size and fit to continue.');
        }
        final variant = commerce
            .variants(product, sold: state.demoSold)
            .where((v) => v.size == size)
            .firstOrNull;
        if (variant == null || variant.stock == 0) {
          throw const FormatException('Choose an available size.');
        }
        if ((state.bag[product.id] ?? 1) > variant.stock) {
          throw FormatException(
            'Reduce the bag quantity to ${variant.stock} before choosing this size.',
          );
        }
        state.productVariants[product.id] = variant.id;
        state.usualSize = variant.size;
        state.usualSizes[_sizeGroup(product)] = variant.size;
        if (state.bag.containsKey(product.id)) {
          state.bagVariants[product.id] = variant.id;
        }
        if (DemoCommerce.fitsFor(product).isNotEmpty) {
          state.preferredFit = fit as String;
        }
        state.bagUndo = null;
        state.bagVariantsUndo = null;
        scope.hostReply =
            'Saved size $size${DemoCommerce.fitsFor(product).isEmpty ? '' : ' and ${state.preferredFit.toLowerCase()} fit'}.';
        scope.detailProduct = null;
      } else {
        scope.hostReply =
            '${product.name}: choose your ${DemoCommerce.fitsFor(product).isEmpty ? 'size' : 'size and preferred fit'}.';
      }
    } on FormatException catch (error) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: error.message,
      );
    }
  }

  Map<String, Object?>? _productDetailData(_TurnScope scope) {
    final p = scope.detailProduct;
    if (p == null) return null;
    final state = scope.state,
        variants = commerce.variants(p, sold: scope.state.demoSold);
    final selected = _selectedVariant(
      state,
      p,
      bag: state.bag.containsKey(p.id),
    );
    final usualSize = state.usualSizes[_sizeGroup(p)] ?? state.usualSize;
    final size =
        selected?.size ??
        (variants.any((v) => v.size == usualSize && v.stock > 0)
            ? usualSize
            : '');
    return {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'attributes': p.attributes.toMap(),
      'sizes': variants.where((v) => v.stock > 0).map((v) => v.size).toList(),
      'size': size,
      'fits': DemoCommerce.fitsFor(p),
      'fit': DemoCommerce.fitsFor(p).isEmpty ? '' : state.preferredFit,
      'question':
          '${p.name}: choose your ${DemoCommerce.fitsFor(p).isEmpty ? 'size' : 'size and preferred fit'}.',
      'saveLabel': DemoCommerce.fitsFor(p).isEmpty
          ? 'Save size'
          : 'Save size & fit',
      'canSave':
          size.isNotEmpty &&
          (DemoCommerce.fitsFor(p).isEmpty ||
              DemoCommerce.fitsFor(p).contains(state.preferredFit)),
      'stockText':
          'Fictional demo stock by size: ${variants.map((v) => '${v.size}: ${v.stock}').join(' · ')}',
    };
  }

  void _addPiecesToBag(_StylistState state, Iterable<Product> pieces) {
    if (pieces.isEmpty ||
        pieces.any((p) => !state.briefState.productConstraints.matches(p))) {
      throw const FormatException(
        'Choose compatible catalog pieces before adding them to the demo bag.',
      );
    }
    _checkBudget(state);
    state.bagUndo = Map.of(state.bag);
    state.bagVariantsUndo = Map.of(state.bagVariants);
    for (final p in pieces) {
      state.bag.putIfAbsent(p.id, () => 1);
      final choices = commerce.variants(p, sold: state.demoSold);
      final selected = _selectedVariant(state, p);
      if (!state.bagVariants.containsKey(p.id)) {
        if (selected != null) {
          state.bagVariants[p.id] = selected.id;
        } else if (choices.length == 1) {
          state.bagVariants[p.id] = choices.single.id;
        }
      }
      _checkDemoStock(state, p, state.bag[p.id]!);
      state.reviewedBagPieces.add(p.id);
    }
    state.removedBagItems.clear();
  }

  void _libraryAction(_TurnScope scope, String name, Map context) {
    final state = scope.state;
    scope.questionIntent = 'library';
    scope.hostReply = 'Your local styling library.';
    Product product(Object? id) => products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw const FormatException(
        'That product is no longer in the catalog.',
      ),
    );
    Map<String, Object?> saved(Object? id) => state.savedLooks.firstWhere(
      (look) => look['id'] == id,
      orElse: () => throw const FormatException(
        'That saved look is no longer available.',
      ),
    );
    try {
      switch (name) {
        case 'save_look':
          final plan = OutfitPlan.from(
            catalog: products,
            brief: state.briefState.planningText,
            dressCode: state.briefState.dressCode,
            constraints: state.briefState.productConstraints,
            outfit: state.outfit,
          );
          if (!plan.complete || !state.briefState.canSearch) {
            throw const FormatException(
              'Complete the look and resolve its restrictions before saving.',
            );
          }
          _checkBudget(state);
          final snapshot = _lookSnapshot(state);
          var look = state.savedLooks
              .where(
                (look) => jsonEncode(look['snapshot']) == jsonEncode(snapshot),
              )
              .firstOrNull;
          if (look == null) {
            if (state.savedLooks.length >= 50) {
              throw const FormatException(
                'Delete a saved look before adding more than 50.',
              );
            }
            final title = state.briefState.occasion.isEmpty
                ? 'Your look'
                : state.briefState.occasion;
            look = {
              'id': 'look-${state.nextLookId++}',
              'name': title.length > 160 ? title.substring(0, 160) : title,
              'snapshot': snapshot,
            };
            state.savedLooks.add(Map.unmodifiable(look));
          }
          state.selectedLookId = look['id'] as String;
          scope.showSavedLooks = true;
          scope.hostReply = _canPersist
              ? 'Look saved on this device.'
              : 'Look kept for this session.';
          scope.toastMessage = scope.hostReply;
          scope.toastAction = 'open_saved_looks';
          scope.toastLabel = 'View looks';
        case 'open_saved_looks':
          scope.showSavedLooks = true;
          scope.hostReply = state.savedLooks.isEmpty
              ? 'No saved looks yet. Complete a look, then save it here.'
              : 'Choose a saved look to restore its pieces and accepted preferences.';
        case 'restore_look':
          final look = saved(context['lookId']);
          if (look['snapshot'] is! Map) {
            throw const FormatException('This saved look needs review.');
          }
          _restoreLook(
            state,
            Map<String, Object?>.from(look['snapshot'] as Map),
          );
          state.selectedLookId = look['id'] as String;
          scope.hostReply =
              'Loaded ${look['name']} using current catalog facts and prices.';
          scope.questionIntent = 'resume';
        case 'delete_look':
          final look = saved(context['lookId']);
          state.savedLooks.remove(look);
          if (state.selectedLookId == look['id']) state.selectedLookId = null;
          scope.showSavedLooks = true;
          scope.hostReply = 'Deleted ${look['name']}.';
        case 'reset_look':
          state
            ..bag = {}
            ..bagVariants = {}
            ..reviewedBagPieces = {}
            ..removedBagItems = {}
            ..removedBagVariants = {}
            ..bagUndo = null
            ..bagVariantsUndo = null
            ..briefState = const StylistBrief()
            ..brief = ''
            ..preferences = []
            ..outfit = {}
            ..productVariants = {}
            ..seen = {}
            ..history = []
            ..lastPresented = []
            ..catalogOccasion = ''
            ..city = ''
            ..cityContext = null
            ..cityContextNotice = null
            ..replacementProductId = null
            ..replacementPriceMax = null
            ..replacementDifferentColor = false
            ..selectedLookId = null
            ..lastNextCategory = null;
          scope.questionIntent = null;
          scope.hostReply =
              'Start a new look. Tell me the occasion, style and budget.';
        case 'resume_session' || 'close_bag':
          scope.questionIntent = 'resume';
          scope.hostReply = 'Your look is ready to continue. Your accepted preferences and budget are retained.';
          scope.picks = [
            for (final id in state.lastPresented)
              if (state.seen[id] != null &&
                  state.briefState.productConstraints.matches(
                    state.seen[id]!,
                  ) &&
                  state.replacementPermits(state.seen[id]!))
                state.seen[id]!,
          ];
        case 'open_bag':
          final additions = state.outfit.values
              .where((p) => !state.reviewedBagPieces.contains(p.id))
              .toList();
          if (additions.isNotEmpty) _addPiecesToBag(state, additions);
          scope.showBag = true;
          scope.hostReply = 'Your local demo bag. Sizes, inventory, delivery and checkout are fictional simulations; no real purchase is available.';
        case 'add_look_to_bag':
          _addPiecesToBag(state, state.outfit.values);
          scope.showBag = true;
          scope.hostReply = 'Added the selected catalog pieces to your demo bag. No purchase has been made.';
          scope.toastMessage = 'Look added to demo bag';
          scope.toastLabel = 'Undo';
          scope.toastAction = 'undo_bag_changes';
        case 'change_bag_quantity':
          final id = context['productId'], quantity = context['quantity'];
          product(id);
          if (!state.bag.containsKey(id) ||
              quantity is! int ||
              quantity < 1 ||
              quantity > 99) {
            throw const FormatException(
              'Choose a bag item and a demo quantity from 1 to 99.',
            );
          }
          _checkDemoStock(state, product(id), quantity);
          state.bag[id as String] = quantity;
          state.bagUndo = null;
          state.removedBagItems.clear();
          scope.showBag = true;
          scope.hostReply = 'Demo bag quantity updated.';
        case 'remove_bag_item':
          final id = context['productId'];
          product(id);
          final quantity = state.bag.remove(id);
          if (quantity == null) {
            throw const FormatException(
              'That product is no longer in your demo bag.',
            );
          }
          state.removedBagItems = {id as String: quantity};
          state.removedBagVariants = {
            if (state.bagVariants[id] != null)
              id: state.bagVariants.remove(id)!,
          };
          state.bagUndo = null;
          scope.showBag = true;
          scope.hostReply = 'Removed ${product(id).name} from the demo bag.';
          scope.toastMessage = 'Item removed';
          scope.toastLabel = 'Undo';
          scope.toastAction = 'restore_bag_item';
          scope.toastContext = {'productId': id, 'quantity': quantity};
        case 'restore_bag_item':
          final id = context['productId'], quantity = context['quantity'];
          product(id);
          if (!state.removedBagItems.containsKey(id) ||
              state.removedBagItems[id] != quantity ||
              state.bag.containsKey(id)) {
            throw const FormatException(
              'That removal can no longer be undone.',
            );
          }
          if (state.removedBagVariants[id] != null) {
            state.bagVariants[id as String] = state.removedBagVariants[id]!;
          }
          _checkDemoStock(state, product(id), quantity as int);
          state.bag[id as String] = state.removedBagItems.remove(id)!;
          state.removedBagVariants.clear();
          state.bagUndo = null;
          scope.showBag = true;
          scope.hostReply = 'Restored ${product(id).name} to the demo bag.';
        case 'undo_bag_changes':
          final previous = state.bagUndo;
          if (previous == null) {
            throw const FormatException(
              'Those bag changes can no longer be undone.',
            );
          }
          state.bag = Map.of(previous);
          state.bagVariants = Map.of(state.bagVariantsUndo ?? const {});
          state.bagVariantsUndo = null;
          state.bagUndo = null;
          state.removedBagItems.clear();
          scope.showBag = true;
          scope.hostReply = 'Undid the look addition to your demo bag.';
      }
      if (state.libraryNotice != null) scope.notices.add(state.libraryNotice!);
    } on FormatException catch (error) {
      throw StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: error.message,
      );
    }
  }

  Map<String, Object?> _libraryData(_TurnScope scope) {
    final state = scope.state;
    final looks = <Map<String, Object?>>[];
    for (final look in state.savedLooks) {
      final snapshot = look['snapshot'];
      final ids = snapshot is Map ? snapshot['items'] : null;
      final pieces = ids is List
          ? products.where((p) => ids.contains(p.id)).toList()
          : const <Product>[];
      looks.add({
        'id': look['id'],
        'label': look['name'],
        'category': pieces.firstOrNull?.category.name ?? 'accessory',
        'imageAsset': pieces.firstOrNull?.imageAsset ?? '',
        'name': look['name'],
        'meta': '${pieces.length} catalog pieces',
      });
    }
    return {
      'persistent': _canPersist,
      'showLooks': scope.showSavedLooks,
      'looks': looks,
      'selectedId': state.selectedLookId ?? '',
      'showBag': scope.showBag,
      'checkout': scope.showCheckout ? _checkoutData(state) : null,
      'receipt': scope.showReceipt ? state.lastDemoReceipt : null,
      'hasReceipt': state.lastDemoReceipt != null,
      'delivery': scope.showBag && state.bag.isNotEmpty
          ? commerce.delivery(today: now(), destination: state.city)
          : null,
      'fitPieces': [
        for (final p in state.outfit.values)
          {
            'id': p.id,
            'name': p.name,
            'size': _selectedVariant(state, p)?.size ?? 'Choose size',
            'note':
                DemoCommerce.fitsFor(p).isEmpty || state.preferredFit.isEmpty
                ? ''
                : '${state.preferredFit} fit',
          },
      ],
      'bagCount': state.bag.values.fold<int>(0, (a, b) => a + b),
      'lookInBag':
          state.outfit.isNotEmpty &&
          state.outfit.values.every((p) => state.bag.containsKey(p.id)),
      'bagItems': [
        for (final e in state.bag.entries)
          for (final p in products.where((p) => p.id == e.key))
            {
              'id': p.id,
              'name': p.name,
              'category': p.category.name,
              'imageAsset': p.imageAsset,
              'swatch': p.swatch,
              'unitPrice': eurosFromCents(p.priceCents),
              'quantity': e.value,
              'meta':
                  '${p.brand} · ${_selectedVariant(state, p, bag: true)?.size ?? 'Choose size'} · fictional inventory',
              'size': _selectedVariant(state, p, bag: true)?.size ?? '',
              'variantId': state.bagVariants[p.id],
              'demoStock': _selectedVariant(state, p, bag: true)?.stock,
            },
      ],
      if (scope.toastMessage != null)
        'toast': {
          'message': scope.toastMessage,
          'label': scope.toastLabel,
          'action': scope.toastAction,
          'context': scope.toastContext,
        },
    };
  }

  Map<String, Object?>? _budgetAdjustment(
    _StylistState state, {
    ProductCategory? target,
  }) {
    if (!state.briefState.canSearch || state.budget == null) return null;
    final plan = OutfitPlan.from(
      catalog: products,
      brief: state.briefState.planningText,
      dressCode: state.briefState.dressCode,
      constraints: state.briefState.productConstraints,
      outfit: state.outfit,
    );
    if (plan.complete) return null;
    final category = target ?? plan.nextCategory;
    if (category == null) return null;
    final candidates = products
        .where(
          (p) =>
              p.category == category &&
              state.briefState.productConstraints.matches(p),
        )
        .toList();
    if (state.outfit.isEmpty &&
        candidates.any((p) => !euroAmountExceeds(p.price, state.budget!))) {
      return null;
    }
    final assessments = candidates
        .map((p) => _assessment(state, p))
        .where((a) => a.violations.isEmpty && a.unavailableCategories.isEmpty)
        .toList();
    if (assessments.isEmpty || assessments.any((a) => a.withinBudget)) {
      return null;
    }
    return {
      'missingFields': ['budget'],
      'budget': state.budget,
      'minimumBudget': max(1, state.spent),
      'adjustBudget': true,
    };
  }

  Map<String, Object?> _preferenceData(_StylistState state) {
    final constraints = state.briefState.productConstraints;
    final category = state.lastNextCategory;
    final cap = category == null
        ? state.budget ?? double.infinity
        : state.remaining == double.infinity
        ? double.infinity
        : sumEuros([state.remaining, state.outfit[category.name]?.price ?? 0]);
    final eligible = products
        .where(
          (p) =>
              constraints.matches(p) &&
              (category == null || p.category == category) &&
              !euroAmountExceeds(p.price, cap),
        )
        .toList();
    final selectedColors = <String>{
      for (final color in constraints.preferredColors)
        for (final entry in catalogColorFamilies.entries)
          if (entry.key == color || entry.value.contains(color))
            displayDetail(entry.key),
    };
    const swatches = {
      'black': '#161616',
      'white': '#f1ece2',
      'grey': '#9a9a9a',
      'beige': '#b8935a',
      'brown': '#473528',
      'blue': '#192c46',
      'green': '#5c6644',
      'red': '#6b1f2e',
      'pink': '#df9eaf',
      'purple': '#8a6d9e',
      'yellow': '#cfb24b',
      'orange': '#b76c43',
    };
    final brands = products.map((p) => p.brand).toSet().toList()..sort();
    return {
      'scope': category == null
          ? 'Current catalog · color families are approximate'
          : '${displayDetail(category.name)} options within your current restrictions and budget · approximate color families',
      'options': [
        for (final entry in catalogColorFamilies.entries)
          if (eligible.any(
                (p) => productColorFamilies(p).contains(entry.key),
              ) ||
              selectedColors.contains(displayDetail(entry.key)))
            {
              'name': displayDetail(entry.key),
              'hex': swatches[entry.key],
              'count': eligible
                  .where((p) => productColorFamilies(p).contains(entry.key))
                  .length,
            },
      ],
      'colours': selectedColors.toList(),
      'brands': brands,
      'love': [
        for (final b in brands)
          if (constraints.preferredBrands.contains(b.toLowerCase())) b,
      ],
      'skip': [
        for (final b in brands)
          if (constraints.excludedBrands.contains(b.toLowerCase())) b,
      ],
      'owned': {
        for (final c in ProductCategory.values)
          c.name: constraints.ownedCategories.contains(c),
      },
      'showDates':
          state.city.isNotEmpty ||
          state.briefState.tripStart.isNotEmpty ||
          RegExp(
            r'\b(?:trip|travel|holiday|visiting)\b',
            caseSensitive: false,
          ).hasMatch(state.briefState.occasion),
      'tripStart': state.briefState.tripStart,
      'tripEnd': state.briefState.tripEnd,
    };
  }

  String _weatherAnswer(_StylistState state, String message) {
    if (state.city.isEmpty) return 'Which city should I check the weather for?';
    final weather = state.cityContext;
    if (weather == null) {
      return cityContextSource == null
          ? 'Live forecasts are unavailable in this connection.'
          : 'I couldn’t load the forecast for ${state.city} just now. Ask me to check again.';
    }
    final explicitDates = RegExp(r'\b\d{4}-\d{2}-\d{2}\b')
        .allMatches(message)
        .map((m) => m.group(0)!)
        .toList();
    final relative = RegExp(
      r'\b(today|tonight|tomorrow)\b',
      caseSensitive: false,
    ).firstMatch(message)?.group(1)?.toLowerCase();
    const weekdayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final weekday = weekdayNames.indexWhere(
      (name) => RegExp('\\b$name\\b', caseSensitive: false).hasMatch(message),
    );
    final explicitDay =
        explicitDates.isNotEmpty || relative != null || weekday >= 0;
    final tripStart = state.briefState.tripStart.isEmpty
        ? state.briefState.tripEnd
        : state.briefState.tripStart;
    final tripEnd = state.briefState.tripEnd.isEmpty
        ? tripStart
        : state.briefState.tripEnd;
    final tripRange = !explicitDay && tripStart.isNotEmpty;
    final weekend =
        !explicitDay &&
        !tripRange &&
        RegExp(
          r'\bweekend\b',
          caseSensitive: false,
        ).hasMatch('$message ${state.briefState.planningText} ${state.brief}');
    final weekendDays = weather.days
        .where(
          (day) =>
              (DateTime.tryParse(day['date'].toString())?.weekday ?? 0) >= 6,
        )
        .toList();
    var requestedDays = weather.days;
    if (explicitDates.isNotEmpty) {
      requestedDays = weather.days
          .where((day) => explicitDates.contains(day['date']))
          .toList();
    } else if (relative != null) {
      // Open-Meteo's daily forecast starts on the destination's local current date.
      final localToday = DateTime.parse(weather.days.first['date'].toString());
      final target = localToday
          .add(Duration(days: relative == 'tomorrow' ? 1 : 0))
          .toIso8601String()
          .substring(0, 10);
      requestedDays = weather.days
          .where((day) => day['date'] == target)
          .toList();
    } else if (weekday >= 0) {
      requestedDays = weather.days
          .where(
            (day) =>
                DateTime.parse(day['date'].toString()).weekday == weekday + 1,
          )
          .toList();
    } else if (tripRange) {
      requestedDays = weather.days
          .where(
            (day) =>
                day['date'].toString().compareTo(tripStart) >= 0 &&
                day['date'].toString().compareTo(tripEnd) <= 0,
          )
          .toList();
    } else if (weekend) {
      requestedDays = weekendDays;
    }
    final days = requestedDays.isNotEmpty ? requestedDays : weather.days;
    final lines = days.map((day) {
      final low = day['lowC'] as num?;
      final high = day['highC'] as num?;
      final rain = day['rainProbabilityPercent'] as num?;
      final temperature = low == null || high == null
          ? 'Temperature unavailable'
          : '${low.toStringAsFixed(0)}–${high.toStringAsFixed(0)}°C';
      final rainText = rain == null
          ? 'Rain forecast unavailable'
          : '${rain.toStringAsFixed(0)}% chance of rain';
      return '${day['label']}, ${day['date']}: $temperature, $rainText.';
    });
    final partialTrip =
        tripRange &&
        requestedDays.isNotEmpty &&
        (tripStart.compareTo(weather.days.first['date'].toString()) < 0 ||
            tripEnd.compareTo(weather.days.last['date'].toString()) > 0);
    return '${weather.label} — forecast (${weather.timezone}):\n${lines.join('\n')}'
        '${requestedDays.isEmpty ? '\n${tripRange
                  ? 'Trip dates are'
                  : weekend
                  ? 'Weekend dates are'
                  : 'The requested day is'} not included in the available forecast yet.' : ''}'
        '${partialTrip ? '\nThe available forecast covers only part of your trip; some dates fall outside its available range.' : ''}'
        '${tripRange && state.briefState.tripStart.isEmpty ? '\nOnly your trip end date is stated, so I checked that day. Share a start date to check the whole trip.' : ''}';
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
    if (!_hasAvailableStock(state, product)) {
      throw const StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: 'That item has sold out. Choose another available piece.',
      );
    }
    final replacing = state.outfit[product.category.name];
    if (!state.replacementPermits(product)) {
      throw const StylistInputError(
        code: StylistInputErrorCode.invalidSelection,
        message: 'Choose a replacement that satisfies the requested price and color adjustment.',
      );
    }
    final nextBrief = _briefForSelection(state, product);
    final violations = nextBrief.productConstraints.violations(product);
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
    final total = sumEuros(candidate.values.map((item) => item.price));
    if (validateFinal &&
        state.budget != null &&
        euroAmountExceeds(total, state.budget!)) {
      throw StylistInputError(
        code: StylistInputErrorCode.budgetConflict,
        message:
            'Selecting ${product.name} would cost ${formatEuros(total)} for the outfit, above your ${formatEuros(state.budget!)} budget. Choose a cheaper piece or replace an existing one.',
      );
    }
    if (validateFinal) _validateSelectionFeasibility(state, product);
    state.outfit = candidate;
    state.reviewedBagPieces.remove(product.id);
    final availableSizes = commerce
        .variants(product, sold: state.demoSold)
        .where((variant) => variant.stock > 0)
        .toList();
    if (availableSizes.length == 1 &&
        _selectedVariant(state, product) == null) {
      state.productVariants[product.id] = availableSizes.single.id;
    }
    state.briefState = nextBrief;
    if (replacing?.id == state.replacementProductId) {
      state.replacementProductId = null;
      state.replacementPriceMax = null;
      state.replacementDifferentColor = false;
    }
    return product;
  }

  void _validateSelectionFeasibility(_StylistState state, Product product) {
    final assessment = _assessment(state, product);
    final prospectiveConstraints = _briefForSelection(
      state,
      product,
    ).productConstraints;
    if (!assessment.feasible &&
        products.any(
          (alternative) =>
              alternative.category == product.category &&
              prospectiveConstraints.matches(alternative) &&
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
    final removed = state.outfit.remove(slots.single)!;
    if (removed.id == state.replacementProductId) {
      state.replacementProductId = null;
      state.replacementPriceMax = null;
      state.replacementDifferentColor = false;
    }
    if (state.briefState.sources['gender'] == BriefFactSource.inferred) {
      final audiences = state.outfit.values
          .map((p) => p.gender)
          .where((g) => g == 'male' || g == 'female')
          .toSet();
      state.briefState = audiences.length == 1
          ? state.briefState.merge({
              'gender': audiences.single,
            }, source: BriefFactSource.inferred)
          : state.briefState.merge({}, clearFields: {'gender'});
    }
    return removed;
  }

  void _refreshProgress(_TurnScope scope, {ProductCategory? requested}) {
    final state = scope.state;
    scope.feasibilityNotice = '';
    for (final product in state.outfit.values) {
      final conflicts = state.briefState.productConstraints.violations(product);
      if (conflicts.isNotEmpty) {
        scope.notices.add(
          'Your selected ${product.name} conflicts with your new instructions: ${conflicts.join('; ')}. Remove or replace it to satisfy them.',
        );
      }
    }
    final plan = OutfitPlan.from(
      catalog: products,
      brief: state.briefState.planningText,
      outfit: state.outfit,
      constraints: state.briefState.productConstraints,
      dressCode: state.briefState.dressCode,
    );
    scope.plan = plan;
    if (requested != null &&
        !state.briefState.productConstraints.categoryPermitted(requested)) {
      requested = null;
    }
    scope.target =
        scope.questionIntent == null &&
            state.briefState.canSearch &&
            state.briefState.productConstraints.clarificationRequests.isEmpty
        ? requested ?? plan.nextCategory
        : null;
    scope.needsProducts =
        scope.target != null &&
        _recommendableProducts(scope).any(
          (product) =>
              product.category == scope.target &&
              product.id != scope.adjustingProductId &&
              state.replacementPermits(product) &&
              !euroAmountExceeds(product.price, scope.availableBudget),
        );
  }

  Map<String, Object?> _facts(Product product) =>
      productFacts(product, demoSold: _scope.state.demoSold);

  Map<String, Object?> _progressFacts(_TurnScope scope) => {
    'catalog': catalogMetadata,
    'brief': scope.state.briefState.toMap(),
    'constraints': scope.state.briefState.productConstraints.toMap(),
    'city': scope.state.city,
    if (scope.state.cityContext != null)
      'cityContext': scope.state.cityContext!.facts,
    'missingFields': scope.state.briefState.missingFields,
    'outfit': scope.state.outfit.values.map(_facts).toList(),
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
        : state.briefState.productConstraints.clarificationRequests.isNotEmpty
        ? 'Searching is blocked. Ask only these scope questions: ${state.briefState.productConstraints.clarificationRequests.join(' ')}.'
        : scope.target == null && plan.complete
        ? 'The outfit is complete. Summarize it, identify any weakest piece, and offer keep or swap.'
        : scope.target == null
        ? 'Selected pieces conflict with the current instructions. Explain which pieces need removal or replacement; do not claim the outfit is complete.'
        : scope.needsProducts
        ? 'Search and present this category now; do not stop at an acknowledgement.'
        : 'No affordable catalog choices for this category. Explain that limit and offer a budget change or replacing a selected piece.';
    return '$_instructions\nRetained original brief: ${state.brief}. '
        'Preferences: ${state.preferences.join('; ')}. Settled brief: ${state.briefState.toMap()}.\n'
        'Hard constraints and preferences: ${state.briefState.productConstraints.toMap()}. '
        'Host notices: ${scope.notices.join(' ')} ${scope.feasibilityNotice}.\n'
        'Budget: ${state.budget == null ? 'unknown' : formatEuros(state.budget!)}. '
        'Already spent: ${formatEuros(state.spent)}. Remaining: ${state.budget == null ? 'unknown' : formatEuros(state.remaining)}.\n'
        'Destination city: ${state.city}. Verified context: ${state.cityContext?.facts ?? state.cityContextNotice ?? 'not loaded'}.\n'
        'Host outfit facts: ${state.outfit.values.map(productFacts).toList()}.\n'
        'Catalog source capabilities: $catalogMetadata. Do not claim unavailable stock, sizes or checkout.\n'
        '${scope.adjustingProductId == null ? '' : 'The person is adjusting ${scope.target?.name}. Keep ${scope.adjustingProductId} selected until a replacement is chosen. Present different product IDs.\n'}'
        'Last presented IDs, in display order: ${state.lastPresented}.\n'
        'Local library: ${state.savedLooks.length} saved looks. Demo bag: ${state.bag.values.fold<int>(0, (a, b) => a + b)} items; no purchases or stock information. Use the host controls to change these.\n'
        'Plan: ${plan.slots.map((slot) => slot.name).join(', ')}. '
        'Progress: ${plan.filledCount} of ${plan.slots.length}.\n'
        'Next category: ${scope.target?.name ?? 'none'}. '
        'Available for next category, including released replacements: ${state.budget == null ? 'unknown' : formatEuros(scope.availableBudget)}. $next '
        'For capability or general advice questions, respond_to_question takes priority over the outfit next step.';
  }

  void _checkBudget(_StylistState state, {StylistBrief? brief}) {
    final budget = (brief ?? state.briefState).budget;
    if (budget != null && euroAmountExceeds(state.spent, budget)) {
      throw StylistInputError(
        code: StylistInputErrorCode.budgetConflict,
        message:
            'Your selected pieces cost ${formatEuros(state.spent)}, above the requested ${formatEuros(budget)} outfit budget. Remove or replace a piece, or keep a higher budget.',
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
      'gender': r'\b(?:gender|audience|male|female|menswear|womenswear|unisex|men|women)\b',
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
    // Catalog audience comes from explicit text or a selected item, never a model default.
    patch = Map.of(patch)..remove('gender');
    if (!RegExp(
      r'\b(?:clear|forget|reset|remove) (?:my |the )?(?:gender|audience)\b',
      caseSensitive: false,
    ).hasMatch(scope.userMessage)) {
      authorized.remove('gender');
    }
    return brief.merge(
      patch,
      source: BriefFactSource.model,
      protectUserFacts: true,
      authorizedFields: authorized,
      clearFields: clearFields.intersection(authorized),
    );
  }

  StylistBrief _briefForSelection(_StylistState state, Product product) {
    final current = state.briefState;
    if (current.sources['gender'] == BriefFactSource.user ||
        (current.gender.isNotEmpty &&
            current.sources['gender'] != BriefFactSource.inferred)) {
      return current;
    }
    final retained = Map<String, Product>.of(state.outfit);
    removeConflictingFoundation(retained, product.category);
    retained.removeWhere(
      (_, selected) => selected.category == product.category,
    );
    if (!const {'male', 'female'}.contains(product.gender)) {
      if (current.sources['gender'] == BriefFactSource.inferred &&
          !retained.values.any(
            (selected) => const {'male', 'female'}.contains(selected.gender),
          )) {
        return current.merge({}, clearFields: {'gender'});
      }
      return current;
    }
    if (retained.values.any(
      (selected) => !selected.supportsGender(product.gender),
    )) {
      return current;
    }
    return current.merge({
      'gender': product.gender,
    }, source: BriefFactSource.inferred);
  }

  OutfitSelectionAssessment _assessment(_StylistState state, Product product) {
    final prospectiveBrief = _briefForSelection(state, product);
    return assessOutfitSelection(
      candidate: product,
      outfit: state.outfit,
      catalog: products.where((p) => _hasAvailableStock(state, p)).toList(),
      brief: prospectiveBrief.planningText,
      dressCode: prospectiveBrief.dressCode,
      constraints: prospectiveBrief.productConstraints,
      budget: state.budget,
    );
  }

  bool _hasAvailableStock(_StylistState state, Product product) =>
      commerce.variants(product, sold: state.demoSold).any((v) => v.stock > 0);

  List<Product> _recommendableProducts(_TurnScope scope) {
    final state = scope.state;
    var candidates = products
        .where(
          (product) =>
              _hasAvailableStock(state, product) &&
              product.id != scope.adjustingProductId &&
              state.briefState.productConstraints.matches(product) &&
              state.replacementPermits(product),
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
      (a, b) => state.briefState.productConstraints
          .preferenceScore(b)
          .compareTo(state.briefState.productConstraints.preferenceScore(a)),
    );
    return candidates;
  }

  List<String> _replyPrefix(_TurnScope scope, {String? selectionGuidance}) {
    final state = scope.state;
    return [
      if (scope.confirmations.isNotEmpty)
        '${scope.confirmations.join(' ')}${state.budget == null ? '' : ' ${formatEuros(state.remaining)} left in your budget.'}${selectionGuidance == null ? '' : ' $selectionGuidance'}',
      if (scope.questionIntent != 'weather') _acknowledgment(scope),
      if (scope.questionIntent == null && scope.feasibilityNotice.isNotEmpty)
        scope.feasibilityNotice,
      ?_localStorageNotice,
      // Search tradeoffs belong with the recommendations, not the sizing form.
      ...scope.notices.where(
        (notice) =>
            notice != _optionalSearchNotice || _selectionOptions(scope) == null,
      ),
      if (scope.adjustingProductId != null && scope.picks.isNotEmpty)
        if (state.replacementPriceMax != null)
          'These replacements cost less. Your current piece stays selected until you choose one.'
        else if (state.replacementDifferentColor)
          'These alternatives use a different color family. Your current piece stays selected until you choose one.',
    ];
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
        parts.add(
          '${switch (entry.key) {
            'gender' => 'styling preference',
            'dressCode' => 'style',
            'tripStart' => 'trip start',
            'tripEnd' => 'trip end',
            _ => entry.key,
          }} cleared',
        );
      } else if (entry.key == 'budget') {
        parts.add('${formatEuros(entry.value as num)} for the whole outfit');
      } else if (entry.key == 'gender') {
        parts.add(
          brief.sources['gender'] == BriefFactSource.inferred
              ? '${brief.genderLabel}, based on your selected piece'
              : brief.genderLabel,
        );
      } else if (entry.key == 'tripStart' || entry.key == 'tripEnd') {
        parts.add(
          '${entry.key == 'tripStart' ? 'trip start' : 'trip end'}: ${entry.value}',
        );
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
        if (const {
          'clarificationRequests',
          'pendingScopeCategories',
        }.contains(key)) {
          continue;
        }
        if (constraints[key].toString() !=
            previousConstraints[key].toString()) {
          final label = _constraintLabel(key);
          parts.add(
            constraints[key] == null
                ? '$label cleared'
                : '$label: ${key == 'requiredGarmentTypes' ? (constraints[key] as Map).values.join(', ') : _constraintDescription(constraints[key]!)}',
          );
        }
      }
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
    'excludedGenderProductTerms' => 'avoid these product styles',
    'categoryConstraints' => 'category restrictions',
    'preferredColors' => 'preferred colors',
    'preferredBrands' => 'preferred brands',
    'requiredGarmentTypes' => 'requested garments',
    _ => 'preferences',
  };

  String _constraintDescription(Object value) {
    if (value is List) return value.join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) {
            final audience = switch (entry.key) {
              'male' => 'men’s',
              'female' => 'women’s',
              'male, female' => 'unisex',
              _ => null,
            };
            if (audience != null) {
              return '$audience ${_constraintDescription(entry.value as Object)}';
            }
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

double _cheaperCeiling(Product product) =>
    eurosFromCents(product.priceCents - 1);

bool _rejectsCheaper(String text) {
  final clause = text
      .split(RegExp(r'[,;.!?]|\b(?:but|and|instead)\b', caseSensitive: false))
      .lastWhere(
        (c) => RegExp(
          r'\b(?:cheaper|less expensive|lower[ -]price)\b',
          caseSensitive: false,
        ).hasMatch(c),
        orElse: () => '',
      );
  return RegExp(
    r"\b(?:not|no|never|don['’]?t|do not)\b(?:\s+\w+){0,4}\s+(?:cheaper|less expensive|lower[ -]price)\b",
    caseSensitive: false,
  ).hasMatch(clause);
}

bool _requestsCheaper(String text) =>
    !_rejectsCheaper(text) &&
    RegExp(
      r'\b(?:cheaper|less expensive|lower[ -]price|reduce (?:the )?price)\b',
      caseSensitive: false,
    ).hasMatch(text);

String? _localCommand(String text) {
  if (restartStylistBrief(text) == '') return 'reset_look';
  for (final entry in const {
    'preview_demo_checkout':
        r'(?:preview (?:demo )?checkout|check out|checkout)',
    'open_demo_receipt':
        r'(?:show|view|open) (?:my |the |last )?(?:demo )?receipt',
    'save_look': r'save (?:this|my|the)(?: current)? (?:look|outfit)',
    'open_saved_looks':
        r'(?:show|open|view) (?:my |the )?(?:saved|session) looks',
    'open_bag': r"(?:(?:show|open|view) (?:my |the |demo )?bag|what(?: is|'s|’s) in (?:my|the|this) bag)",
    'add_look_to_bag':
        r'add (?:this|my|the) (?:look|outfit) to (?:my |the |demo )?bag',
  }.entries) {
    if (RegExp(
      '^(?:please |can you |could you )?${entry.value}(?: please)?[.!?]*\$',
      caseSensitive: false,
    ).hasMatch(text.trim())) {
      return entry.key;
    }
  }
  return null;
}

/// Explicit whole-look restarts only. Vague changes are clarified separately;
/// negated or quoted wording does not match this anchored host command.
String? restartStylistBrief(String text) {
  final match = RegExp(
    r'^(?:(?:please|can (?:you|we)|could (?:you|we))\s+)?(?:start (?:over|again)|start (?:a )?new (?:look|chat)|new (?:look|chat)|restart(?: (?:the |my |this )?(?:chat|look|outfit))?|reset (?:the |my |this )?(?:look|chat|outfit))(?:\s+(?:with|for)\s+(.+?))?(?:\s+please)?[.!?]*$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  return match == null ? null : (match.group(1) ?? '').trim();
}

Set<String>? _choiceValues(Object? input, Iterable<String> allowed) {
  if (input == null) return null;
  final known = allowed.map((v) => v.toLowerCase()).toSet();
  if (input is! List ||
      input.length > known.length ||
      input.any(
        (v) => v is! String || !known.contains(v.trim().toLowerCase()),
      )) {
    throw const FormatException(
      'Choose options from the current catalog controls.',
    );
  }
  return Set.unmodifiable(
    input.cast<String>().map((v) => v.trim().toLowerCase()),
  );
}

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

String _sizeGroup(Product product) => switch (product.category) {
  ProductCategory.shoes => 'shoes',
  ProductCategory.bag || ProductCategory.accessory => 'one_size',
  _ => 'clothing',
};

class _StylistState {
  int turn = 0;
  List<Message> history = [];
  Map<String, Product> seen = {};
  Map<String, Product> outfit = {};
  StylistBrief briefState = const StylistBrief();
  double? get budget => briefState.budgetCents == null
      ? null
      : eurosFromCents(briefState.budgetCents!);
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
  List<Map<String, Object?>> savedLooks = [];
  Map<String, int> bag = {};
  Set<String> reviewedBagPieces = {};
  Map<String, String> productVariants = {},
      bagVariants = {},
      removedBagVariants = {};
  Map<String, String>? bagVariantsUndo;
  Map<String, int> demoSold = {};
  Map<String, Object?>? lastDemoReceipt;
  int nextReceiptId = 1;
  String usualSize = '', preferredFit = '';
  Map<String, String> usualSizes = {};
  Map<String, int> removedBagItems = {};
  Map<String, int>? bagUndo;
  int nextLookId = 1;
  String? selectedLookId;
  String? libraryNotice;
  String? replacementProductId;
  double? replacementPriceMax;
  bool replacementDifferentColor = false;
  bool replacementPermits(Product product) {
    final original = outfit[product.category.name];
    if (original == null || original.id != replacementProductId) return true;
    return (replacementPriceMax == null ||
            !euroAmountExceeds(product.price, replacementPriceMax!)) &&
        (!replacementDifferentColor ||
            differentCatalogColor(original, product));
  }

  int get spentCents => outfit.values.fold(0, (sum, p) => sum + p.priceCents);
  double get spent => eurosFromCents(spentCents);
  double get remaining => budget == null
      ? double.infinity
      : eurosFromCents(max(0, euroCents(budget!) - spentCents));
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
    ..lastPresented = List.of(lastPresented)
    ..savedLooks = List.of(savedLooks)
    ..bag = Map.of(bag)
    ..reviewedBagPieces = Set.of(reviewedBagPieces)
    ..productVariants = Map.of(productVariants)
    ..bagVariants = Map.of(bagVariants)
    ..removedBagVariants = Map.of(removedBagVariants)
    ..bagVariantsUndo = bagVariantsUndo == null
        ? null
        : Map.of(bagVariantsUndo!)
    ..demoSold = Map.of(demoSold)
    ..lastDemoReceipt = lastDemoReceipt
    ..nextReceiptId = nextReceiptId
    ..usualSize = usualSize
    ..usualSizes = Map.of(usualSizes)
    ..preferredFit = preferredFit
    ..removedBagItems = Map.of(removedBagItems)
    ..bagUndo = bagUndo == null ? null : Map.of(bagUndo!)
    ..nextLookId = nextLookId
    ..selectedLookId = selectedLookId
    ..libraryNotice = libraryNotice
    ..replacementProductId = replacementProductId
    ..replacementPriceMax = replacementPriceMax
    ..replacementDifferentColor = replacementDifferentColor;
}

class _TurnScope {
  _TurnScope(
    this.state,
    this.cancel,
    this.onProgress,
    this.onText,
    this.onOutfitPreview,
  );
  final StylistOutfitPreview? onOutfitPreview;
  final _StylistState state;
  final CancellationController cancel;
  final StylistProgress? onProgress;
  final StylistTextProgress? onText;
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
  String presentation = 'cards';
  String? hostReply;
  bool preferencePanel = false;
  bool showSavedLooks = false;
  bool showBag = false;
  bool showCheckout = false, showReceipt = false;
  Product? detailProduct;
  Product? optionsProduct;
  String? toastMessage;
  String toastLabel = '';
  String toastAction = '';
  Map<String, Object?> toastContext = const {};
  List<String> confirmations = [];
  double get availableBudget {
    if (target == null) return state.remaining;
    final candidate = Map<String, Product>.of(state.outfit);
    removeConflictingFoundation(candidate, target!);
    candidate.remove(target!.name);
    final spentCents = candidate.values.fold<int>(
      0,
      (sum, item) => sum + item.priceCents,
    );
    final available = state.budget == null
        ? double.infinity
        : eurosFromCents(max(0, euroCents(state.budget!) - spentCents));
    return state.outfit[target!.name]?.id == state.replacementProductId &&
            state.replacementPriceMax != null
        ? min(available, state.replacementPriceMax!)
        : available;
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

/// Domain policy wraps the same retrieval algorithm used by preview sources.
List<Product> searchStylistProducts(
  List<Product> products,
  Map<String, dynamic> filters, {
  StylistConstraints constraints = const StylistConstraints(),
}) => searchCatalogProducts(
  products,
  query: filters['query'] as String? ?? '',
  category: filters['category'] as String?,
  gender: filters['gender'] as String?,
  color: filters['color'] as String?,
  occasion: filters['occasion'] as String?,
  season: filters['season'] as String?,
  maxPrice: (filters['priceMax'] as num?)?.toDouble(),
  limit: ((filters['limit'] as num?)?.toInt() ?? 6).clamp(1, 12),
  eligible: constraints.matches,
  preferenceScore: constraints.preferenceScore,
);

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
