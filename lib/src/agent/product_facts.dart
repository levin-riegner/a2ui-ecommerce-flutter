import '../data/models.dart';
import '../data/demo_commerce.dart';
import '../data/money.dart';
import '../data/catalog_semantics.dart';

/// Model-facing DTO. Derived styling classifications are host heuristics,
/// not additional supplier claims or observations of product images.
class ProductFacts {
  const ProductFacts(this.product);
  final Product product;
  Map<String, Object?> toJson() => productFacts(product);
}

Map<String, Object?> productFacts(
  Product product, {
  Map<String, int> demoSold = const {},
}) => {
  'id': product.id,
  'attributes': product.attributes.toMap(),
  'demo_variants': const DemoCommerce()
      .variants(product, sold: demoSold)
      .map((v) => v.toMap())
      .toList(),
  'name': product.name,
  'brand': product.brand,
  'description': product.description,
  'category': product.category.name,
  'gender': product.gender,
  'subcategory': product.subcategory,
  'color': product.color,
  'material': product.material,
  'season': product.season,
  'occasion': product.occasion,
  'keywords': product.keywords,
  'garment_type': catalogGarmentType(product),
  'color_families': productColorFamilies(product).toList(),
  'derived_provenance': {
    'garment_type': 'host_catalog_semantics_v1',
    'color_families': 'host_catalog_semantics_v1',
  },
  'price_eur': eurosFromCents(product.priceCents),
  'image_asset': product.imageAsset,
};
