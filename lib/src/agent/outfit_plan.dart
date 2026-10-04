import '../data/models.dart';

/// The ordered pieces a look needs, shared by the stylist and dressing room.
///
/// This follows the original PoC's outfit plan: formal occasions start with a
/// dress, everyday looks with separates, and outdoors looks with a layer.
/// Choosing a different foundation changes the route to follow that choice.
class OutfitPlan {
  OutfitPlan._({
    required List<ProductCategory> slots,
    required Set<ProductCategory> selected,
  }) : slots = List.unmodifiable(slots),
       _selected = Set.unmodifiable(selected),
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
  }) {
    final text = brief.toLowerCase();
    final selected = outfit.values.map((product) => product.category).toSet();
    final hasDress = selected.contains(ProductCategory.dress);
    final hasSeparates =
        selected.contains(ProductCategory.top) ||
        selected.contains(ProductCategory.bottom);
    final formal = RegExp(
      r'cocktail|black.?tie|white.?tie|formal|gala|wedding|ball\b|evening',
    ).hasMatch(text);
    final outdoors = RegExp(
      r'outdoor|walk|hik|trail|country|rain|weather|camp|festival|ski|sail',
    ).hasMatch(text);
    // The Flutter brief carries the season in text rather than a separate field.
    final cold = RegExp(
      r'autumn|rain|cold|wind|snow|winter|november|december|january|february',
    ).hasMatch(text);
    final dressRoute = hasDress || (!hasSeparates && formal);

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
    return OutfitPlan._(slots: slots, selected: selected);
  }

  /// Pieces required for completion, in the order the stylist fills them.
  final List<ProductCategory> slots;

  /// Required pieces plus any optional layer or accessory already chosen.
  /// Optional pieces remain visible without making accessories mandatory.
  final List<ProductCategory> displaySlots;
  final Set<ProductCategory> _selected;

  ProductCategory? get nextCategory {
    for (final category in slots) {
      if (!_selected.contains(category)) return category;
    }
    return null;
  }

  bool get complete => nextCategory == null;

  int get filledCount => slots.where(_selected.contains).length;
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
