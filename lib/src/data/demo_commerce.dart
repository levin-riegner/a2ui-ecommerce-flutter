import 'models.dart';

/// Coherent fictional commerce data. These are not imported supplier variants.
class DemoVariant {
  const DemoVariant({
    required this.id,
    required this.size,
    required this.stock,
  });
  final String id, size;
  final int stock;
  Map<String, Object?> toMap() => {
    'id': id,
    'size': size,
    'stock': stock,
    'available': stock > 0,
    'source': 'local_demo_fixture',
    'sourceVersion': 'alder-demo-v1',
  };
}

class DemoCommerce {
  const DemoCommerce();
  static const fitPreferences = ['Fitted', 'Regular', 'Relaxed'];
  static List<String> fitsFor(Product product) => switch (product.category) {
    ProductCategory.dress ||
    ProductCategory.top ||
    ProductCategory.bottom ||
    ProductCategory.layer => fitPreferences,
    _ => const [],
  };
  static const currency = 'EUR';
  static const shippingCents = 395;

  List<DemoVariant> variants(
    Product product, {
    Map<String, int> sold = const {},
  }) {
    final sizes = product.sizeOptions.isNotEmpty
        ? product.sizeOptions
        : switch (product.category) {
            ProductCategory.shoes => [for (var i = 36; i <= 46; i++) '$i'],
            ProductCategory.bag || ProductCategory.accessory => ['One size'],
            _ => ['XS', 'S', 'M', 'L', 'XL'],
          };
    final seed = product.id.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    return [
      for (var i = 0; i < sizes.length; i++)
        DemoVariant(
          id: '${product.id}-size-${sizes[i].toLowerCase().replaceAll(' ', '-')}',
          size: sizes[i],
          stock:
              ((i == sizes.length ~/ 2 ? 6 : (seed + i * 3) % 9) -
                      (sold['${product.id}-size-${sizes[i].toLowerCase().replaceAll(' ', '-')}'] ??
                          0))
                  .clamp(0, 99),
        ),
    ];
  }

  Map<String, Object?> sizeGuide(Product product) => {
    'source': 'local_demo_fixture',
    'label': 'Illustrative demo size guide — not measured garment dimensions',
    'unit': 'cm',
    'measurementType': 'illustrative body-size ranges',
    'rows': switch (product.category) {
      ProductCategory.shoes => [
        for (var i = 36; i <= 46; i++)
          {
            'size': '$i',
            'foot_length':
                '${(22.5 + (i - 36) * 0.7).toStringAsFixed(1)} cm (demo)',
          },
      ],
      ProductCategory.bag ||
      ProductCategory.accessory => <Map<String, Object?>>[],
      _ => [
        for (var i = 0; i < 5; i++)
          {
            'size': ['XS', 'S', 'M', 'L', 'XL'][i],
            'chest': '${80 + i * 8}–${87 + i * 8}',
            'waist': '${62 + i * 8}–${69 + i * 8}',
            'hip': '${86 + i * 8}–${93 + i * 8}',
          },
      ],
    },
  };

  Map<String, Object?> delivery({
    required DateTime today,
    required String destination,
  }) {
    final date = DateTime.utc(today.year, today.month, today.day);
    String day(int offset) =>
        date.add(Duration(days: offset)).toIso8601String().substring(0, 10);
    return {
      'source': 'local_demo_policy',
      'origin': 'Demo warehouse',
      'destination': destination.isEmpty ? 'Sample destination' : destination,
      'service': 'Demo standard shipping',
      'dispatchDate': day(1),
      'earliestDate': day(3),
      'latestDate': day(5),
      'shippingCents': shippingCents,
      'taxCents': 0,
      'currency': currency,
      'disclaimer':
          'Fictional delivery scenario; no carrier, tax or arrival guarantee.',
    };
  }
}
