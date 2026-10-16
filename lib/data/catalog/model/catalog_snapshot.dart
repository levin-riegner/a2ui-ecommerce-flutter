import 'catalog_products.dart';
import 'models.dart';

const bundledCatalogPath = 'assets/data/catalog/products.csv';
const bundledCatalogRevision = 'alder-demo-v1';

/// Capabilities describe facts a source actually supplies, not UI possibilities.
class CatalogCapabilities {
  const CatalogCapabilities({
    this.stock = false,
    this.sizes = false,
    this.checkout = false,
  });

  final bool stock;
  final bool sizes;
  final bool checkout;

  Map<String, Object?> toJson() => {
    'stock': stock,
    'sizes': sizes,
    'checkout': checkout,
  };
}

/// A complete, validated catalog used for a connection's search and planning.
/// Revision is a source-supplied label, not a cryptographic fingerprint.
class CatalogSnapshot {
  CatalogSnapshot({
    required Iterable<Product> products,
    required this.revision,
    this.currency = 'EUR',
    this.capabilities = const CatalogCapabilities(),
  }) : products = List.unmodifiable(products) {
    if (revision.trim().isEmpty || currency != 'EUR') {
      throw const FormatException(
        'Catalog requires a revision and EUR prices.',
      );
    }
    final index = <String, Product>{};
    for (final product in this.products) {
      if (product.id.trim().isEmpty ||
          index.containsKey(product.id) ||
          !product.price.isFinite ||
          product.price < 0) {
        throw const FormatException(
          'Catalog contains invalid or duplicate products.',
        );
      }
      index[product.id] = product;
    }
    if (index.isEmpty) throw const FormatException('Catalog unavailable');
    byId = Map.unmodifiable(index);
  }

  factory CatalogSnapshot.fromCsv(
    String csv, {
    String revision = bundledCatalogRevision,
  }) {
    final records = parseCatalogCsv(csv);
    if (records.isEmpty) throw const FormatException('Catalog unavailable');
    final headers = records.first
        .map((header) => header.replaceFirst('\uFEFF', '').trim())
        .toList();
    final currencyColumn = headers.indexOf('currency');
    if (headers.toSet().length != headers.length ||
        (!headers.contains('price_eur') &&
            (!headers.contains('price') || currencyColumn < 0))) {
      throw const FormatException(
        'Catalog prices require price_eur or an explicit EUR currency.',
      );
    }
    if (currencyColumn >= 0 &&
        records
            .skip(1)
            .any(
              (row) =>
                  row.length <= currencyColumn ||
                  row[currencyColumn].trim().toUpperCase() != 'EUR',
            )) {
      throw const FormatException('Only EUR catalog prices are supported.');
    }
    final products = parseCatalogProducts(csv);
    // The low-level parser is deliberately tolerant for import previews. A
    // connected snapshot must not silently omit malformed or duplicate rows.
    if (products.length != records.length - 1) {
      throw const FormatException(
        'Catalog contains malformed or duplicate rows.',
      );
    }
    return CatalogSnapshot(products: products, revision: revision);
  }

  final List<Product> products;
  late final Map<String, Product> byId;
  final String revision;
  final String currency;
  final CatalogCapabilities capabilities;

  Map<String, Object?> get metadata => {
    'revision': revision,
    'currency': currency,
    'completeSnapshot': true,
    'capabilities': capabilities.toJson(),
  };
}

abstract interface class CatalogSource {
  Future<CatalogSnapshot> load();
}

class MemoryCatalogSource implements CatalogSource {
  const MemoryCatalogSource(this.snapshot);
  final CatalogSnapshot snapshot;

  @override
  Future<CatalogSnapshot> load() async => snapshot;
}
