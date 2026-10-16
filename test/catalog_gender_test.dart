import 'dart:convert';

import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_products.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/data/catalog/repository/product_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const catalog =
    'id,name,brand,description,category,subcategory,gender,color,material,season,occasion,price_eur,image_asset,keywords\n'
    'male-1,Boxy Jacket,Demo,Boxy jacket,layer,jacket,male,black,unspecified,all-season,work,50,assets/male.jpg,boxy\n'
    'female-1,Fitted Jacket,Demo,Fitted jacket,layer,jacket,female,black,unspecified,all-season,work,90,assets/female.jpg,fitted\n'
    'both-1,Neutral Jacket,Demo,Neutral jacket,layer,jacket,"male, female",black,unspecified,all-season,work,80,assets/both.jpg,neutral\n';

void main() {
  test('CSV preserves a quoted two-audience field as one product fact', () {
    final products = parseCatalogProducts(catalog);
    expect(products, hasLength(3));
    expect(products.map((p) => p.gender), ['male', 'female', 'male, female']);
    expect(products.last.name, 'Neutral Jacket');
    expect(products.last.color, 'black');
    expect(products.last.price, 80);
    expect(products.last.imageAsset, 'assets/both.jpg');
  });

  test('audience compatibility includes neutral pieces and fails closed', () {
    final products = parseCatalogProducts(catalog);
    expect(products.first.supportsGender('female'), isFalse);
    expect(products[1].supportsGender('male'), isFalse);
    expect(products.last.supportsGender('female'), isTrue);
    expect(products.last.supportsGender('male'), isTrue);
    expect(products.first.supportsGender('male, female'), isFalse);
    expect(products.last.supportsGender('male, female'), isTrue);
    expect(products.first.supportsGender(''), isTrue);
    expect(products.last.supportsGender('unknown'), isFalse);
  });

  test(
    'repository filters audience before limits and preserves caps',
    () async {
      final repository = CsvProductRepository(bundle: _CatalogBundle());
      expect(
        (await repository.search(
          category: 'layer',
          gender: 'female',
        )).map((p) => p.id),
        ['female-1', 'both-1'],
      );
      expect(
        (await repository.recommendations(
          journey: DemoJourney.berlin,
          category: ProductCategory.layer,
          gender: 'female',
        )).map((p) => p.id).toSet(),
        {'female-1', 'both-1'},
      );
      expect(await repository.search(gender: 'female', maxPrice: 60), isEmpty);
      expect(
        (await repository.search(gender: 'male, female')).single.id,
        'both-1',
      );
    },
  );
}

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(catalog)));
}
