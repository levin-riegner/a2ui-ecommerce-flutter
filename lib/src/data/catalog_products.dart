import 'models.dart';

/// Parses the bundled public catalog for Flutter and the Dart developer tools.
List<Product> parseCatalogProducts(String source) {
  final records = parseCatalogCsv(source);
  if (records.isEmpty) return const [];
  final headers = records.first
      .map((value) => value.replaceFirst('\uFEFF', '').trim())
      .toList();
  final products = <Product>[];
  final seenIds = <String>{};
  for (final values in records.skip(1)) {
    if (values.length != headers.length) continue;
    final row = <String, String>{
      for (var i = 0; i < headers.length; i++) headers[i]: values[i].trim(),
    };
    final id = row['id'] ?? '';
    final name = row['name'] ?? '';
    final price = double.tryParse(row['price_eur'] ?? row['price'] ?? '');
    if (id.isEmpty ||
        name.isEmpty ||
        price == null ||
        !price.isFinite ||
        price < 0 ||
        !seenIds.add(id)) {
      continue;
    }
    final categoryName = row['category'] ?? '';
    final category = _categoryFromName(categoryName);
    if (category == null) continue;
    final color = row['color'] ?? '';
    final material = row['material'] ?? '';
    products.add(
      Product(
        id: id,
        journey: _journeyFromName(row['journey']),
        category: category,
        name: name,
        brand: row['brand'] ?? '',
        price: price,
        meta:
            row['meta'] ??
            [color, material].where((v) => v.isNotEmpty).join(' · '),
        tag: row['tag'] ?? (row['subcategory'] ?? categoryName),
        swatch: row['swatch'] ?? '#e4e4e7',
        description: row['description'] ?? '',
        subcategory: row['subcategory'] ?? '',
        gender: row['gender'] ?? 'male, female',
        color: color,
        material: material,
        season: row['season'] ?? '',
        occasion: row['occasion'] ?? '',
        imageAsset: row['image_asset'] ?? '',
        keywords: [categoryName, row['keywords'] ?? ''].join(' '),
      ),
    );
  }
  return List.unmodifiable(products);
}

DemoJourney? _journeyFromName(String? value) {
  for (final journey in DemoJourney.values) {
    if (journey.name == value) return journey;
  }
  return null;
}

ProductCategory? _categoryFromName(String? value) {
  for (final category in ProductCategory.values) {
    if (category.name == value) return category;
  }
  return null;
}

/// RFC 4180-style records, including escaped quotes and line breaks in cells.
List<List<String>> parseCatalogCsv(String source) {
  final records = <List<String>>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == '"') {
      if (quoted && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      fields.add(field.toString());
      field.clear();
    } else if ((character == '\n' || character == '\r') && !quoted) {
      fields.add(field.toString());
      field.clear();
      if (fields.any((value) => value.isNotEmpty)) records.add(fields);
      fields = <String>[];
      if (character == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index++;
      }
    } else {
      field.write(character);
    }
  }
  fields.add(field.toString());
  if (fields.any((value) => value.isNotEmpty)) records.add(fields);
  return records;
}
