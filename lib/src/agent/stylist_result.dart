import 'dart:collection';

import '../data/models.dart';
import 'city_context.dart';
import 'outfit_plan.dart';
import 'product_facts.dart';
import 'stylist_brief.dart';

/// Renderer-independent outcome of a fully validated host turn.
///
/// Map access preserves the developer tooling's domain JSON API. Wire messages
/// are deliberately absent: a renderer must explicitly adapt [view].
class StylistTurnResult extends MapBase<String, dynamic> {
  StylistTurnResult({
    required this.reply,
    this.intent,
    required List<Product> products,
    required StylistBrief brief,
    required Map<String, Product> outfit,
    required this.view,
    required Map<String, Object?> catalog,
    Map<String, int> demoSold = const {},
  }) : products = List.unmodifiable(products),
       brief = StylistBrief.fromSnapshot(brief.toSnapshot()),
       outfit = Map.unmodifiable(outfit),
       _json = _freeze({
         'reply': reply,
         'intent': ?intent,
         'products': products
             .map((p) => productFacts(p, demoSold: demoSold))
             .toList(),
         'brief': brief.toMap(),
         'missingFields': brief.missingFields,
         'constraints': brief.productConstraints.toMap(),
         'outfit': {
           'budget': brief.budget,
           'items': {
             for (final entry in outfit.entries) entry.key: entry.value.id,
           },
         },
         'catalog': catalog,
       }) as Map<String, dynamic>;

  final String reply;
  final String? intent;
  final List<Product> products;
  final StylistBrief brief;
  final Map<String, Product> outfit;
  final StylistViewState view;
  final Map<String, dynamic> _json;

  Map<String, dynamic> toJson() => _json;
  @override
  dynamic operator [](Object? key) => _json[key];
  @override
  Iterable<String> get keys => _json.keys;
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('A turn result is immutable');
  @override
  void clear() => throw UnsupportedError('A turn result is immutable');
  @override
  dynamic remove(Object? key) =>
      throw UnsupportedError('A turn result is immutable');
}

/// Host-approved content and presentation intent, without a wire protocol.
/// A native screen, CLI, or A2UI adapter may consume the same committed result.
class StylistViewState {
  StylistViewState({
    required this.turn,
    required List<Product> picks,
    required this.plan,
    this.nextCategory,
    Map<String, Object?>? clarification,
    Map<String, Object?>? budgetAdjustment,
    this.cityContext,
    this.cityContextNotice,
    this.city = '',
    this.presentation = 'cards',
    this.adjusting,
    List<String> adjustmentOptions = const ['Something similar'],
    this.adjustmentSelected = '',
    Map<String, Object?>? preferences,
    this.canEditPreferences = false,
    Set<ProductCategory> ownedCategories = const {},
    this.showCompletion = true,
    Map<String, Object?>? library,
    this.inspectProducts = false,
    this.changeDirection = false,
    Map<String, Object?>? productDetails,
    Map<String, Object?>? selectionOptions,
    this.updateCurrentInlineOnly = false,
  }) : picks = List.unmodifiable(picks),
       clarification = _freeze(clarification) as Map<String, Object?>?,
       budgetAdjustment = _freeze(budgetAdjustment) as Map<String, Object?>?,
       adjustmentOptions = List.unmodifiable(adjustmentOptions),
       preferences = _freeze(preferences) as Map<String, Object?>?,
       ownedCategories = Set.unmodifiable(ownedCategories),
       library = _freeze(library) as Map<String, Object?>?,
       productDetails = _freeze(productDetails) as Map<String, Object?>?,
       selectionOptions = _freeze(selectionOptions) as Map<String, Object?>?;

  final int turn;
  final List<Product> picks;
  final OutfitPlan plan;
  final ProductCategory? nextCategory;
  final Map<String, Object?>? clarification;
  final Map<String, Object?>? budgetAdjustment;
  final CityContext? cityContext;
  final String? cityContextNotice;
  final String city;
  final String presentation;
  final Product? adjusting;
  final List<String> adjustmentOptions;
  final String adjustmentSelected;
  final Map<String, Object?>? preferences;
  final bool canEditPreferences;
  final Set<ProductCategory> ownedCategories;
  final bool showCompletion;
  final Map<String, Object?>? library;
  final bool inspectProducts, changeDirection;
  final Map<String, Object?>? productDetails, selectionOptions;
  final bool updateCurrentInlineOnly;
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
