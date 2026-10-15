import 'package:a2ui_flutter_commerce/src/agent/stylist_constraints.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Product product({
  ProductCategory category = ProductCategory.top,
  String color = 'red',
  String material = 'cotton',
  String brand = 'Studio Sample',
  String name = 'Test',
  String subcategory = '',
  String gender = 'male, female',
}) => Product(
  id: 'test',
  category: category,
  name: name,
  subcategory: subcategory,
  gender: gender,
  brand: brand,
  price: 50,
  meta: '',
  tag: '',
  swatch: '#000000',
  color: color,
  material: material,
);

void main() {
  test('audience-qualified exclusions retain type and audience scope', () {
    final constraints = const StylistConstraints()
        .recordMessage("No men's jackets")
        .recordMessage('A winter weekend please');
    expect(constraints.excludedProductTerms, isEmpty);
    expect(constraints.excludedCategories, isEmpty);
    expect(constraints.excludedGenderProductTerms, {
      'male': {'jackets'},
    });
    for (final gender in ['female', 'male, female']) {
      expect(
        constraints.matches(
          product(
            category: ProductCategory.layer,
            name: 'Jacket',
            gender: gender,
          ),
        ),
        isTrue,
      );
    }
    expect(
      constraints.matches(
        product(
          category: ProductCategory.layer,
          name: 'Jacket',
          gender: 'male',
        ),
      ),
      isFalse,
    );
    expect(
      constraints
          .withGender('male')
          .matches(
            product(
              category: ProductCategory.layer,
              name: 'Jacket',
              gender: 'male',
            ),
          ),
      isFalse,
    );
    expect(
      constraints.matches(
        product(category: ProductCategory.layer, name: 'Coat', gender: 'male'),
      ),
      isTrue,
    );
    expect(
      constraints.matches(
        product(
          category: ProductCategory.top,
          name: 'Jacket print shirt',
          gender: 'male',
        ),
      ),
      isTrue,
    );
  });

  test(
    'qualified releases preserve other audiences and global restrictions',
    () {
      final original = const StylistConstraints().recordMessage(
        "No men's jackets, no women's jackets, no wool, no bags",
      );
      final revised = original.recordMessage("Men's jackets are okay now");
      expect(revised.excludedGenderProductTerms, {
        'female': {'jackets'},
      });
      expect(original.excludedGenderProductTerms.keys, {'male', 'female'});
      expect(
        original.recordMessage('Show jackets').excludedGenderProductTerms,
        original.excludedGenderProductTerms,
      );
      expect(
        original
            .recordMessage("Allow men's jackets")
            .excludedGenderProductTerms,
        {
          'female': {'jackets'},
        },
      );
      expect(revised.excludedMaterials, {'wool'});
      expect(revised.excludedCategories, {ProductCategory.bag});
      final released = revised.recordMessage('Jackets are okay now');
      expect(released.excludedGenderProductTerms, isEmpty);
      expect(released.excludedMaterials, {'wool'});
      expect(released.excludedCategories, {ProductCategory.bag});
      expect(
        requestedProductCategory("No men's jackets"),
        ProductCategory.layer,
      );
      expect(requestedProductCategory('No jackets'), isNull);
    },
  );

  test('female, unisex and broader audience exclusions use catalog facts', () {
    for (final (message, audience, category, name) in [
      ('No ladies’ jackets', 'female', ProductCategory.layer, 'Jacket'),
      ('No unisex jackets', 'male, female', ProductCategory.layer, 'Jacket'),
      ("Avoid men's outerwear", 'male', ProductCategory.layer, 'Coat'),
    ]) {
      final constraints = const StylistConstraints().recordMessage(message);
      expect(constraints.categoryPermitted(category), isTrue);
      for (final gender in ['male', 'female', 'male, female']) {
        expect(
          constraints.matches(
            product(category: category, name: name, gender: gender),
          ),
          gender != audience,
          reason: message,
        );
      }
    }
  });

  test('olive restrictions are acknowledged and enforced by color facts', () {
    final required = const StylistConstraints()
        .recordMessage('Only olive')
        .recordMessage('A summer weekend, please');
    expect(required.allowedColors, {'olive'});
    expect(required.matches(product(color: 'olive green')), isTrue);
    expect(required.matches(product(color: 'green')), isFalse);
    expect(
      required.matches(product(color: 'white', name: 'Olive top')),
      isFalse,
    );

    final excluded = const StylistConstraints().recordMessage('No olive');
    expect(excluded.excludedColors, {'olive'});
    expect(excluded.matches(product(color: 'olive')), isFalse);
    expect(excluded.matches(product(color: 'white')), isTrue);
  });

  test('hard material/color instructions survive unrelated turns', () {
    final constraints = const StylistConstraints()
        .recordMessage('No wool and only red')
        .recordMessage('A summer wedding, please');
    expect(constraints.matches(product()), isTrue);
    expect(constraints.matches(product(color: 'blue')), isFalse);
    expect(
      constraints.matches(product(material: '70% wool, 30% cotton')),
      isFalse,
    );
    for (final material in ['', 'unspecified', 'Unknown', 'not specified']) {
      expect(constraints.matches(product(material: material)), isFalse);
      expect(
        constraints.violations(product(material: material)).single,
        contains('unknown'),
      );
    }
  });

  test(
    'hard palette accepts explicit alternatives and rejects other colors',
    () {
      final constraints = const StylistConstraints().recordMessage(
        'Only red or blue',
      );
      expect(constraints.matches(product(color: 'dark red')), isTrue);
      expect(constraints.matches(product(color: 'blue')), isTrue);
      expect(constraints.matches(product(color: 'green')), isFalse);
      expect(constraints.matches(product(color: '')), isFalse);
    },
  );

  test('soft palette preference ranks without excluding alternatives', () {
    final constraints = const StylistConstraints().recordMessage('Prefer red');
    expect(constraints.allowedColors, isEmpty);
    expect(constraints.matches(product(color: 'blue')), isTrue);
    expect(constraints.preferenceScore(product()), 1);
    expect(constraints.preferenceScore(product(color: 'blue')), 0);
  });

  test('explicit corrections replace hard palette and release exclusions', () {
    final original = const StylistConstraints().recordMessage(
      'No wool, only red',
    );
    final revised = original.recordMessage('Wool is okay now, only blue');
    expect(revised.matches(product(color: 'blue', material: 'wool')), isTrue);
    expect(revised.matches(product()), isFalse);
    expect(original.matches(product(color: 'blue', material: 'wool')), isFalse);
    final softened = revised.recordMessage('I prefer red');
    expect(softened.matches(product(color: 'blue', material: 'wool')), isTrue);
    expect(softened.allowedColors, isEmpty);
  });

  test('category negation does not become a search request', () {
    for (final message in [
      'No dresses',
      'I do not need a bag',
      "I don't want shoes",
      'Skip bags',
    ]) {
      expect(requestedProductCategory(message), isNull, reason: message);
    }
    expect(
      requestedProductCategory('No dresses, show me tops'),
      ProductCategory.top,
    );
    expect(
      requestedProductCategory('No dress code, show me shoes'),
      ProductCategory.shoes,
    );
  });

  test('owned pieces satisfy the plan without requesting a purchase', () {
    final constraints = const StylistConstraints().recordMessage(
      'I already own shoes and a bag',
    );
    expect(constraints.ownedCategories, {
      ProductCategory.shoes,
      ProductCategory.bag,
    });
    expect(constraints.skippedCategories, {
      ProductCategory.shoes,
      ProductCategory.bag,
    });
    expect(requestedProductCategory('Use my shoes'), isNull);
    expect(
      constraints.matches(product(category: ProductCategory.bag)),
      isFalse,
    );
    final revised = constraints.recordMessage('I need a new bag');
    expect(revised.ownedCategories, isNot(contains(ProductCategory.bag)));
  });

  test('catalog brand restrictions are enforced including punctuation', () {
    final constraints = const StylistConstraints().recordMessage(
      'No A.P.C. or & Other Stories',
      knownBrands: ['A.P.C.', '& Other Stories', 'Studio Sample'],
    );
    expect(constraints.matches(product(brand: 'A.P.C.')), isFalse);
    expect(constraints.matches(product(brand: '& Other Stories')), isFalse);
    expect(constraints.matches(product()), isTrue);
    expect(
      constraints
          .recordMessage('A.P.C. is fine now')
          .matches(product(brand: 'A.P.C.')),
      isTrue,
    );
  });

  test('category corrections release earlier exclusions', () {
    final excluded = const StylistConstraints().recordMessage(
      'No bags or dresses',
    );
    expect(excluded.excludedCategories, {
      ProductCategory.bag,
      ProductCategory.dress,
    });
    final corrected = excluded.recordMessage('Include a bag');
    expect(corrected.categoryPermitted(ProductCategory.bag), isTrue);
    expect(corrected.categoryPermitted(ProductCategory.dress), isFalse);
    expect(
      requestedProductCategory('Include a bag', constraints: excluded),
      ProductCategory.bag,
    );
  });

  test('restrictions on one sentence do not leak into a preference', () {
    final constraints = const StylistConstraints().recordMessage(
      'No wool. I prefer red.',
    );
    expect(constraints.excludedColors, isEmpty);
    expect(constraints.preferredColors, {'red'});
  });

  test(
    'ownership accepts ordinary phrasing without treating spending as owning',
    () {
      final owned = const StylistConstraints().recordMessage(
        'I have black shoes',
      );
      expect(owned.ownedCategories, {ProductCategory.shoes});
      final buying = const StylistConstraints().recordMessage(
        'I have 500 to spend on shoes',
      );
      expect(buying.ownedCategories, isEmpty);
      final released = owned.recordMessage('I do not own shoes anymore');
      expect(released.ownedCategories, isEmpty);
      expect(released.excludedCategories, isEmpty);
    },
  );

  test(
    'common exclusion phrasing enforces catalog material and category facts',
    () {
      for (final message in [
        'Wool-free please',
        'Free of wool',
        'I am allergic to wool',
      ]) {
        final constraints = const StylistConstraints().recordMessage(message);
        expect(
          constraints.matches(product(material: 'wool')),
          isFalse,
          reason: message,
        );
        expect(
          constraints.matches(product(material: 'cotton')),
          isTrue,
          reason: message,
        );
      }
      expect(requestedProductCategory('Anything except dresses'), isNull);
    },
  );

  test(
    'explicit material restriction clear aliases preserve other restrictions',
    () {
      final original = const StylistConstraints().recordMessage(
        'No wool, only red',
      );
      for (final message in [
        'Forget wool restriction',
        'Clear the wool restriction',
        'Remove the wool restriction',
        'Reset my wool material exclusion',
        'Clear the material restriction on wool',
      ]) {
        final revised = original.recordMessage(message);
        expect(revised.excludedMaterials, isEmpty, reason: message);
        expect(revised.allowedColors, {'red'}, reason: message);
        expect(
          revised.matches(product(material: 'wool')),
          isTrue,
          reason: message,
        );
      }
      expect(original.recordMessage('Remove the wool top').excludedMaterials, {
        'wool',
      });
    },
  );

  test(
    'explicit color and brand restriction clears release their named terms',
    () {
      final original = const StylistConstraints().recordMessage(
        'Only red, no blue, no Acme',
        knownBrands: ['Acme'],
      );
      final redCleared = original.recordMessage(
        'Remove the red color restriction',
      );
      expect(redCleared.allowedColors, isEmpty);
      expect(redCleared.excludedColors, {'blue'});
      final blueCleared = redCleared.recordMessage('Forget the blue exclusion');
      expect(blueCleared.excludedColors, isEmpty);
      expect(blueCleared.excludedBrands, {'acme'});
      final brandCleared = blueCleared.recordMessage(
        'Reset the Acme brand restriction',
      );
      expect(brandCleared.excludedBrands, isEmpty);
      expect(
        brandCleared.matches(product(brand: 'Acme', color: 'green')),
        isTrue,
      );
    },
  );

  test(
    'category color restrictions do not become whole-outfit restrictions',
    () {
      final constraints = const StylistConstraints().recordMessage(
        'Only red shoes',
      );
      expect(constraints.allowedColors, isEmpty);
      expect(
        constraints.categoryConstraints[ProductCategory.shoes]!.allowedColors,
        {'red'},
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.shoes, color: 'blue'),
        ),
        isFalse,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.top, color: 'blue'),
        ),
        isTrue,
      );
      expect(constraints.toMap()['categoryConstraints'], {
        'shoes': {
          'allowedColors': ['red'],
        },
      });
    },
  );

  test(
    'material and brand exclusions apply only to their stated categories',
    () {
      final constraints = const StylistConstraints().recordMessage(
        'No wool tops, avoid Acme bags',
        knownBrands: ['Acme'],
      );
      expect(constraints.excludedCategories, isEmpty);
      expect(constraints.excludedMaterials, isEmpty);
      expect(constraints.excludedBrands, isEmpty);
      expect(
        constraints.matches(
          product(category: ProductCategory.top, material: 'wool'),
        ),
        isFalse,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.layer, material: 'wool'),
        ),
        isTrue,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.bag, brand: 'Acme'),
        ),
        isFalse,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.shoes, brand: 'Acme'),
        ),
        isTrue,
      );
    },
  );

  test(
    'scoped allowed material and brand remain independent of other categories',
    () {
      final constraints = const StylistConstraints().recordMessage(
        'Only cotton tops, only Acme bags',
        knownBrands: ['Acme'],
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.top, material: 'wool'),
        ),
        isFalse,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.layer, material: 'wool'),
        ),
        isTrue,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.bag, brand: 'Studio Sample'),
        ),
        isFalse,
      );
      expect(
        constraints.matches(
          product(category: ProductCategory.bag, brand: 'Acme'),
        ),
        isTrue,
      );
    },
  );

  test('mixed scope asks clarification and persists until both categories are clarified', () {
    final unclear = const StylistConstraints().recordMessage(
      'Only red shoes and blue tops',
    );
    expect(unclear.clarificationRequests, isNotEmpty);
    expect(unclear.allowedColors, isEmpty);
    expect(unclear.categoryConstraints, isEmpty);
    expect(
      unclear.recordMessage('Hello').clarificationRequests,
      unclear.clarificationRequests,
    );
    expect(
      unclear.recordMessage('').clarificationRequests,
      unclear.clarificationRequests,
    );
    final partial = unclear.recordMessage('Only red shoes');
    expect(partial.clarificationRequests, isNotEmpty);
    final clear = partial.recordMessage('Only blue tops');
    expect(clear.clarificationRequests, isEmpty);
    expect(clear.categoryConstraints.keys, {
      ProductCategory.shoes,
      ProductCategory.top,
    });
  });

  test('scoped correction and release leave global and other category rules intact', () {
    final original = const StylistConstraints().recordMessage(
      'No wool, only red shoes, only blue tops',
    );
    final revised = original.recordMessage('Only black shoes');
    expect(revised.categoryConstraints[ProductCategory.shoes]!.allowedColors, {
      'black',
    });
    expect(revised.categoryConstraints[ProductCategory.top]!.allowedColors, {
      'blue',
    });
    expect(revised.excludedMaterials, {'wool'});
    final released = revised.recordMessage(
      'Remove the black restriction for shoes',
    );
    expect(
      released.categoryConstraints.containsKey(ProductCategory.shoes),
      isFalse,
    );
    expect(released.categoryConstraints[ProductCategory.top]!.allowedColors, {
      'blue',
    });
  });

  test('narrow exclusions preserve the broader purchase category', () {
    final constraints = const StylistConstraints().recordMessage(
      'No heels, no boots, no coats',
    );
    expect(constraints.excludedCategories, isEmpty);
    expect(constraints.categoryPermitted(ProductCategory.shoes), isTrue);
    expect(
      constraints.matches(
        product(category: ProductCategory.shoes, name: 'Leather sandals'),
      ),
      isTrue,
    );
    expect(
      constraints.matches(
        product(category: ProductCategory.shoes, name: 'Block heels'),
      ),
      isFalse,
    );
    expect(
      constraints.matches(
        product(category: ProductCategory.shoes, name: 'Leather boots'),
      ),
      isFalse,
    );
    expect(
      constraints.matches(
        product(category: ProductCategory.layer, name: 'Wool jacket'),
      ),
      isTrue,
    );
    expect(
      constraints.matches(
        product(category: ProductCategory.layer, name: 'Wool coat'),
      ),
      isFalse,
    );
    expect(
      requestedProductCategory('Avoid heels', constraints: constraints),
      isNull,
    );
    expect(
      constraints.recordMessage('I want heels').excludedProductTerms,
      isNot(contains('heels')),
    );
    final adjective = const StylistConstraints().recordMessage(
      'Avoid heeled shoes',
    );
    expect(adjective.excludedCategories, isEmpty);
    expect(
      adjective.matches(
        product(category: ProductCategory.shoes, name: 'Heeled sandals'),
      ),
      isFalse,
    );
  });

  test(
    'attribute restrictions on a narrow type ask before widening their scope',
    () {
      final constraints = const StylistConstraints().recordMessage(
        'Only red heels',
      );
      expect(constraints.clarificationRequests, isNotEmpty);
      expect(constraints.categoryConstraints, isEmpty);
      expect(constraints.allowedColors, isEmpty);
    },
  );
}
