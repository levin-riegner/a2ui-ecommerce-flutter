import 'dart:io';

import 'package:a2ui_flutter_commerce/src/data/catalog_snapshot.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_search.dart';
import 'package:a2ui_flutter_commerce/src/data/product_repository.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const csv =
    'id,name,category,price_eur,season,color,gender\n'
    'top,Soft Top,top,1.10,all-season,blue,"male, female"\n'
    'bottom,Blue Jeans,bottom,2.20,summer,blue,"male, female"\n';

class TextBundle extends CachingAssetBundle {
  TextBundle(this.text);
  final String text;
  @override
  Future<String> loadString(String key, {bool cache = true}) async => text;
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  test('asset and file adapters decode the same complete snapshot', () async {
    final asset = await CsvProductRepository(bundle: TextBundle(csv))
        .loadSnapshot();
    final directory = await Directory.systemTemp.createTemp('alder-catalog-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/products.csv');
    await file.writeAsString(csv);
    final disk = await CsvCatalogSource(readText: file.readAsString).load();
    expect(disk.products.map((p) => p.id), asset.products.map((p) => p.id));
    expect(disk.metadata, asset.metadata);
    expect(() => disk.products.clear(), throwsUnsupportedError);
    expect(() => disk.byId.clear(), throwsUnsupportedError);
  });

  test(
    'a snapshot rejects duplicate IDs, malformed rows and non-EUR sources',
    () {
      expect(
        () => CatalogSnapshot.fromCsv(
          '$csv'
          'top,Duplicate,top,2,summer,blue,"male, female"\n',
        ),
        throwsFormatException,
      );
      expect(
        () => CatalogSnapshot.fromCsv('${csv}bad,row\n'),
        throwsFormatException,
      );
      final snapshot = CatalogSnapshot.fromCsv(csv);
      expect(
        () => CatalogSnapshot(
          products: snapshot.products,
          revision: 'test',
          currency: 'USD',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'an alternate source drives repository and runtime without asset loading',
    () async {
      final snapshot = CatalogSnapshot.fromCsv(csv, revision: 'alternate-v1');
      final repository = CsvProductRepository(
        source: MemoryCatalogSource(snapshot),
      );
      expect(identical(await repository.loadSnapshot(), snapshot), isTrue);
      final runtime = StylistRuntime(
        products: snapshot.products,
        catalog: snapshot,
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A casual outfit under EUR 100',
      });
      expect(result['catalog'], snapshot.metadata);
    },
  );

  test('both query policies share facets and exact-cent caps', () async {
    final snapshot = CatalogSnapshot.fromCsv(csv);
    final repository = CsvProductRepository(
      source: MemoryCatalogSource(snapshot),
    );
    final strict = await repository.search(
      category: 'top',
      season: 'summer',
      maxPrice: 1.10,
    );
    final conversational = searchStylistProducts(snapshot.products, {
      'query': '',
      'category': 'top',
      'season': 'summer',
      'priceMax': 1.10,
    });
    expect(strict.map((p) => p.id), conversational.map((p) => p.id));
    expect(strict.single.id, 'top');
    expect(
      searchCatalogProducts(
        snapshot.products,
        query: 'soft jeans',
        queryMode: CatalogQueryMode.allWords,
      ),
      isEmpty,
    );
    expect(
      searchCatalogProducts(
        snapshot.products,
        query: 'soft jeans',
      ).map((p) => p.id).toSet(),
      {'top', 'bottom'},
    );
  });
  test(
    'connected snapshots never relabel unspecified or foreign prices as EUR',
    () {
      for (final source in [
        'id,name,category,price,currency\na,Shirt,top,10,USD\n',
        'id,name,category,price\na,Shirt,top,10\n',
        'id,name,category,price_eur,currency\na,Shirt,top,10,GBP\n',
      ]) {
        expect(() => CatalogSnapshot.fromCsv(source), throwsFormatException);
      }
      final explicit = CatalogSnapshot.fromCsv(
        'id,name,category,price,currency\na,Shirt,top,10,EUR\n',
      );
      expect(explicit.products.single.price, 10);
      expect(explicit.currency, 'EUR');
    },
  );
}
