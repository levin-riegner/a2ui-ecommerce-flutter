import '../data/models.dart';
import '../data/money.dart';
import 'stylist_constraints.dart';

/// The ordered pieces a look needs, shared by the stylist and dressing room.
///
/// This follows the original PoC's outfit plan: formal occasions start with a
/// dress, everyday looks with separates, and outdoors looks with a layer.
/// Choosing a different foundation changes the route to follow that choice.
class OutfitPlan {
  OutfitPlan._({
    required List<ProductCategory> slots,
    required Set<ProductCategory> selected,
    required Set<ProductCategory> conflicts,
    required this._pendingClarification,
  }) : slots = List.unmodifiable(slots),
       _selected = Set.unmodifiable(selected.difference(conflicts)),
       conflictingCategories = Set.unmodifiable(conflicts),
       displaySlots = List.unmodifiable([
         ...slots,
         ...ProductCategory.values.where(
           (category) =>
               selected.contains(category) && !slots.contains(category),
         ),
       ]);

  factory OutfitPlan.from({
    required String brief,
    required Map<String, Product> outfit,
    StylistConstraints? constraints,
    String? dressCode,
    Iterable<Product>? catalog,
  }) {
    final text = brief.toLowerCase();
    final restrictions =
        constraints ?? const StylistConstraints().recordMessage(brief);
    final selected = outfit.values.map((product) => product.category).toSet();
    final conflicts = outfit.values
        .where((product) => !restrictions.matches(product))
        .map((product) => product.category)
        .toSet();
    final foundations = {...selected, ...restrictions.ownedCategories};
    final hasDress = foundations.contains(ProductCategory.dress);
    final hasSeparates =
        foundations.contains(ProductCategory.top) ||
        foundations.contains(ProductCategory.bottom);
    // Settled style takes precedence over an occasion such as a casual wedding.
    final style = dressCode?.toLowerCase().replaceAll('-', ' ');
    final casual = RegExp(r'\bcasual\b|\brelaxed\b').hasMatch(style ?? text);
    final formal =
        RegExp(
          r'\b(?:dress|cocktail|black.?tie|white.?tie|formal|gala|wedding|ball|evening)\b',
        ).hasMatch(style ?? text) &&
        !casual;
    final outdoors = RegExp(
      r'outdoor|walk|hik|trail|country|rain|weather|camp|festival|ski|sail',
    ).hasMatch(text);
    // The Flutter brief carries the season in text rather than a separate field.
    final cold = RegExp(
      r'autumn|rain|cold|wind|snow|winter|october|november|december|january|february',
    ).hasMatch(text);
    final dressRoute =
        !restrictions.excludedCategories.contains(ProductCategory.dress) &&
        (hasDress ||
            (!hasSeparates &&
                ((formal &&
                        (dressCode == 'dress' ||
                            restrictions.requiredGarmentTypes.containsKey(
                              ProductCategory.dress,
                            ) ||
                            catalog == null ||
                            catalog.any(
                              (p) =>
                                  p.category == ProductCategory.dress &&
                                  restrictions.matches(p),
                            ))) ||
                    restrictions.excludedCategories.contains(
                      ProductCategory.top,
                    ) ||
                    restrictions.excludedCategories.contains(
                      ProductCategory.bottom,
                    ))));

    final List<ProductCategory> slots;
    if (outdoors && !dressRoute) {
      slots = const [
        ProductCategory.layer,
        ProductCategory.shoes,
        ProductCategory.bottom,
        ProductCategory.top,
        ProductCategory.bag,
      ];
    } else if (dressRoute) {
      slots = [
        ProductCategory.dress,
        ProductCategory.shoes,
        if (cold) ProductCategory.layer,
        ProductCategory.bag,
      ];
    } else {
      slots = [
        ProductCategory.top,
        ProductCategory.bottom,
        ProductCategory.shoes,
        if (cold) ProductCategory.layer,
        ProductCategory.bag,
      ];
    }
    return OutfitPlan._(
      slots: slots.where(restrictions.categoryPermitted).toList(),
      selected: selected,
      conflicts: conflicts,
      pendingClarification: restrictions.clarificationRequests.isNotEmpty,
    );
  }

  /// Pieces required for completion, in the order the stylist fills them.
  final List<ProductCategory> slots;

  /// Required pieces plus any optional layer or accessory already chosen.
  /// Optional pieces remain visible without making accessories mandatory.
  final List<ProductCategory> displaySlots;

  /// Selected pieces that violate current restrictions remain visible for
  /// replacement/removal, but cannot satisfy a required slot or complete a look.
  final Set<ProductCategory> conflictingCategories;
  final Set<ProductCategory> _selected;

  ProductCategory? get nextCategory {
    for (final category in slots) {
      if (!_selected.contains(category)) return category;
    }
    return null;
  }

  final bool _pendingClarification;

  bool get complete =>
      nextCategory == null &&
      conflictingCategories.isEmpty &&
      !_pendingClarification;

  int get filledCount => slots.where(_selected.contains).length;
}

/// Minimum cost of finishing after a proposed selection, from known catalog
/// prices and hard constraints. This is an affordability lower bound, not a
/// guarantee of stock, fit, or stylistic compatibility.
class OutfitSelectionAssessment {
  OutfitSelectionAssessment({
    required this.minimumTotal,
    required this.budget,
    required List<ProductCategory> unavailableCategories,
    required List<String> violations,
  }) : unavailableCategories = List.unmodifiable(unavailableCategories),
       violations = List.unmodifiable(violations);

  final double minimumTotal;
  final double? budget;
  final List<ProductCategory> unavailableCategories;
  final List<String> violations;

  bool get withinBudget =>
      budget == null || !euroAmountExceeds(minimumTotal, budget!);
  bool get feasible =>
      violations.isEmpty && unavailableCategories.isEmpty && withinBudget;

  String get explanation {
    if (violations.isNotEmpty) return violations.join('; ');
    if (unavailableCategories.isNotEmpty) {
      return 'No catalog option satisfies your constraints for '
          '${unavailableCategories.map((category) => category.name).join(', ')}. '
          'Change the required pieces or a restriction to complete the outfit.';
    }
    if (!withinBudget) {
      return 'Completing the outfit with this choice needs at least '
          '${formatEuros(minimumTotal)}. Choose a cheaper piece, '
          'use something you own, or change the outfit budget.';
    }
    return '';
  }
}

OutfitSelectionAssessment assessOutfitSelection({
  required Product candidate,
  required Map<String, Product> outfit,
  required Iterable<Product> catalog,
  required String brief,
  String? dressCode,
  StylistConstraints constraints = const StylistConstraints(),
  double? budget,
}) {
  final proposed = Map<String, Product>.of(outfit);
  removeConflictingFoundation(proposed, candidate.category);
  // Category is authoritative even when a caller uses product IDs as map keys.
  proposed.removeWhere((_, product) => product.category == candidate.category);
  proposed[candidate.category.name] = candidate;
  final plan = OutfitPlan.from(
    catalog: catalog,
    brief: brief,
    dressCode: dressCode,
    constraints: constraints,
    outfit: proposed,
  );
  var minimumCents = proposed.values.fold<int>(
    0,
    (sum, product) => sum + product.priceCents,
  );
  final unavailable = <ProductCategory>[];
  final violations = proposed.values.expand(constraints.violations).toList();
  final selected = proposed.values.map((product) => product.category).toSet();
  final available = catalog.where(constraints.matches).toList();
  for (final category in plan.slots.where(
    (category) => !selected.contains(category),
  )) {
    final prices = available
        .where((product) => product.category == category)
        .map((product) => product.priceCents);
    if (prices.isEmpty) {
      unavailable.add(category);
    } else {
      minimumCents += prices.reduce((a, b) => a < b ? a : b);
    }
  }
  return OutfitSelectionAssessment(
    minimumTotal: eurosFromCents(minimumCents),
    budget: budget,
    unavailableCategories: unavailable,
    violations: violations,
  );
}

/// Releases the other foundation when a person switches dress/separates.
///
/// Returns the removed products so callers can account for the released budget.
/// For admission checks, apply this to a draft before committing the selection.
List<Product> removeConflictingFoundation(
  Map<String, Product> outfit,
  ProductCategory selectedCategory,
) {
  final conflicts = switch (selectedCategory) {
    ProductCategory.dress => {ProductCategory.top, ProductCategory.bottom},
    ProductCategory.top || ProductCategory.bottom => {ProductCategory.dress},
    _ => <ProductCategory>{},
  };
  final removed = <Product>[];
  outfit.removeWhere((_, product) {
    if (!conflicts.contains(product.category)) return false;
    removed.add(product);
    return true;
  });
  return removed;
}
