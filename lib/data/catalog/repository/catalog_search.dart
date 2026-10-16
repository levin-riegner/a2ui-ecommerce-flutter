import '../model/catalog_semantics.dart';
import '../model/models.dart';
import '../model/money.dart';

/// Preview filtering requires every word; conversational retrieval ranks any
/// matching word. Preview retains source order; both share facet/currency rules.
enum CatalogQueryMode { allWords, anyWord }

List<String> catalogWords(Object? value) => '$value'
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

List<Product> searchCatalogProducts(
  Iterable<Product> products, {
  String query = '',
  String? category,
  String? gender,
  String? color,
  String? occasion,
  String? season,
  double? maxPrice,
  int limit = 12,
  CatalogQueryMode queryMode = CatalogQueryMode.anyWord,
  bool Function(Product)? eligible,
  int Function(Product)? preferenceScore,
}) {
  if (limit <= 0) return const [];
  final words = catalogWords(query);
  bool facet(String value, String? wanted) =>
      wanted == null ||
      wanted.trim().isEmpty ||
      catalogWords(value).any(catalogWords(wanted).contains);
  final ranked = <({Product product, int score})>[];
  for (final product in products) {
    if (!product.supportsGender(gender ?? '') ||
        (category != null &&
            category.trim().isNotEmpty &&
            product.category.name != category.trim().toLowerCase()) ||
        (color != null &&
            color.trim().isNotEmpty &&
            !matchesCatalogColor(product.color, color)) ||
        !facet(product.occasion, occasion) ||
        (!facet(product.season, season) &&
            product.season.toLowerCase() != 'all-season') ||
        (maxPrice != null && euroAmountExceeds(product.price, maxPrice)) ||
        (eligible != null && !eligible(product))) {
      continue;
    }
    final title = catalogWords(
      '${product.name} ${product.category.name} ${product.subcategory} ${product.color}',
    );
    final all = catalogWords(
      '${product.name} ${product.brand} ${product.description} ${product.category.name} ${product.subcategory} ${product.color} ${product.material} ${product.season} ${product.occasion} ${product.keywords}',
    );
    if (queryMode == CatalogQueryMode.allWords && !words.every(all.contains)) {
      continue;
    }
    final score = words.fold<int>(
      0,
      (sum, word) =>
          sum +
          (title.contains(word)
              ? 3
              : all.contains(word)
              ? 1
              : 0),
    );
    if (words.isNotEmpty && score == 0) {
      continue;
    }
    ranked.add((product: product, score: score));
  }
  if (queryMode == CatalogQueryMode.allWords) {
    return ranked
        .take(limit)
        .map((entry) => entry.product)
        .toList(growable: false);
  }
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final preference = (preferenceScore?.call(b.product) ?? 0).compareTo(
      preferenceScore?.call(a.product) ?? 0,
    );
    if (preference != 0) return preference;
    final price = euroCents(a.product.price)
        .compareTo(euroCents(b.product.price));
    return price != 0 ? price : a.product.id.compareTo(b.product.id);
  });
  return ranked
      .take(limit)
      .map((entry) => entry.product)
      .toList(growable: false);
}
