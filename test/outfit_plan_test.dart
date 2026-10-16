import 'package:a2ui_flutter_commerce/data/stylist/model/outfit_plan.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_constraints.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';

Product piece(ProductCategory category, {double price = 50}) => Product(
  id: category.name,
  category: category,
  name: category.name,
  brand: 'Sample',
  price: price,
  meta: '',
  tag: '',
  swatch: '#000000',
);

Map<String, Product> outfitOf(Iterable<ProductCategory> categories) => {
  for (final category in categories) category.name: piece(category),
};

void main() {
  test('Paris dinner in October includes a layer without requiring the word autumn', () {
    final plan = OutfitPlan.from(
      brief: 'Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500',
      outfit: {},
    );
    expect(plan.slots, [
      ProductCategory.dress,
      ProductCategory.shoes,
      ProductCategory.layer,
      ProductCategory.bag,
    ]);
    final selected = outfitOf([
      ProductCategory.dress,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
    final unfinished = OutfitPlan.from(
      brief: 'Paris dinner in October',
      outfit: selected,
    );
    expect(unfinished.complete, isFalse);
    expect(unfinished.nextCategory, ProductCategory.layer);
  });
  test('formal autumn route starts with a dress and includes a layer', () {
    final plan = OutfitPlan.from(
      brief: '${DemoJourney.paris.title}. ${DemoJourney.paris.brief}',
      outfit: {},
    );
    expect(plan.slots, [
      ProductCategory.dress,
      ProductCategory.shoes,
      ProductCategory.layer,
      ProductCategory.bag,
    ]);
    expect(plan.nextCategory, ProductCategory.dress);
    expect(plan.filledCount, 0);
    expect(plan.complete, isFalse);
  });

  test('Berlin starts with separates and a knit advances to bottoms', () {
    final brief = '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}';
    final initial = OutfitPlan.from(brief: brief, outfit: {});
    expect(initial.slots, [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
    final selected = OutfitPlan.from(
      brief: brief,
      outfit: outfitOf([ProductCategory.top]),
    );
    expect(selected.nextCategory, ProductCategory.bottom);
    expect(selected.filledCount, 1);
  });

  test('winter requires a layer while summer leaves it optional', () {
    final winter = OutfitPlan.from(
      brief: '${DemoJourney.cotswolds.title}. ${DemoJourney.cotswolds.brief}',
      outfit: {},
    );
    expect(winter.slots, [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.layer,
      ProductCategory.bag,
    ]);
    final summer = OutfitPlan.from(
      brief: '${DemoJourney.lisbon.title}. ${DemoJourney.lisbon.brief}',
      outfit: {},
    );
    expect(summer.slots, isNot(contains(ProductCategory.layer)));
  });

  test('wet outdoors route leads with jacket then footwear', () {
    final plan = OutfitPlan.from(brief: 'Rainy country walk', outfit: {});
    expect(plan.slots, [
      ProductCategory.layer,
      ProductCategory.shoes,
      ProductCategory.bottom,
      ProductCategory.top,
      ProductCategory.bag,
    ]);
    final afterLayer = OutfitPlan.from(
      brief: 'Rainy country walk',
      outfit: outfitOf([ProductCategory.layer]),
    );
    expect(afterLayer.nextCategory, ProductCategory.shoes);
  });

  test('a selected dress overrides the casual or outdoors route', () {
    for (final brief in ['Summer lunch', 'Summer outdoor festival']) {
      final plan = OutfitPlan.from(
        brief: brief,
        outfit: outfitOf([ProductCategory.dress]),
      );
      expect(plan.slots, [
        ProductCategory.dress,
        ProductCategory.shoes,
        ProductCategory.bag,
      ]);
      expect(plan.nextCategory, ProductCategory.shoes);
    }
  });

  test('a selected top or bottom overrides a formal dress route', () {
    for (final category in [ProductCategory.top, ProductCategory.bottom]) {
      final plan = OutfitPlan.from(
        brief: 'Summer black-tie dinner',
        outfit: outfitOf([category]),
      );
      expect(plan.slots, [
        ProductCategory.top,
        ProductCategory.bottom,
        ProductCategory.shoes,
        ProductCategory.bag,
      ]);
      expect(
        plan.nextCategory,
        category == ProductCategory.top
            ? ProductCategory.bottom
            : ProductCategory.top,
      );
    }
  });

  test('all required pieces complete the look; removal reopens its slot', () {
    final outfit = outfitOf([
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
    final complete = OutfitPlan.from(brief: 'Summer lunch', outfit: outfit);
    expect(complete.complete, isTrue);
    expect(complete.nextCategory, isNull);
    expect(complete.filledCount, 4);

    outfit.remove('bottom');
    final reopened = OutfitPlan.from(brief: 'Summer lunch', outfit: outfit);
    expect(reopened.complete, isFalse);
    expect(reopened.nextCategory, ProductCategory.bottom);
    expect(reopened.filledCount, 3);
    // Existing snapshots do not change when the caller updates its outfit.
    expect(complete.complete, isTrue);
  });

  test(
    'selected optional layer and accessory stay visible after completion',
    () {
      final plan = OutfitPlan.from(
        brief: 'Summer lunch',
        outfit: outfitOf([
          ProductCategory.top,
          ProductCategory.bottom,
          ProductCategory.shoes,
          ProductCategory.bag,
          ProductCategory.layer,
          ProductCategory.accessory,
        ]),
      );
      expect(plan.complete, isTrue);
      expect(plan.filledCount, 4);
      expect(plan.slots, isNot(contains(ProductCategory.accessory)));
      expect(plan.displaySlots, [
        ProductCategory.top,
        ProductCategory.bottom,
        ProductCategory.shoes,
        ProductCategory.bag,
        ProductCategory.layer,
        ProductCategory.accessory,
      ]);
      expect(
        () => plan.slots.add(ProductCategory.accessory),
        throwsUnsupportedError,
      );
    },
  );

  test('switching to a dress releases both separates and their budget', () {
    final outfit = {
      'top': piece(ProductCategory.top, price: 95),
      'bottom': piece(ProductCategory.bottom, price: 110),
      'shoes': piece(ProductCategory.shoes, price: 80),
    };
    final released = removeConflictingFoundation(outfit, ProductCategory.dress);
    expect(released.map((product) => product.category), [
      ProductCategory.top,
      ProductCategory.bottom,
    ]);
    expect(released.fold<double>(0, (sum, item) => sum + item.price), 205);
    expect(outfit.keys, ['shoes']);
  });

  test('switching to separates releases dress and preserves other pieces', () {
    for (final category in [ProductCategory.top, ProductCategory.bottom]) {
      final outfit = outfitOf([
        ProductCategory.dress,
        ProductCategory.bag,
        ProductCategory.accessory,
      ]);
      final released = removeConflictingFoundation(outfit, category);
      expect(released.single.category, ProductCategory.dress);
      expect(outfit.keys, ['bag', 'accessory']);
    }
  });

  test('choosing other categories does not release the foundation', () {
    final outfit = outfitOf([ProductCategory.dress]);
    final released = removeConflictingFoundation(outfit, ProductCategory.shoes);
    expect(released, isEmpty);
    expect(outfit.keys, ['dress']);
  });

  test('explicit casual style overrides a wedding occasion', () {
    final plan = OutfitPlan.from(
      brief: 'Wedding in summer',
      dressCode: 'casual',
      outfit: {},
    );
    expect(plan.nextCategory, ProductCategory.top);
    expect(plan.slots, isNot(contains(ProductCategory.dress)));
    expect(
      OutfitPlan.from(brief: 'A casual wedding', outfit: {}).nextCategory,
      ProductCategory.top,
    );
  });

  test('excluded and owned pieces are not mandatory purchases', () {
    final constraints = const StylistConstraints().recordMessage(
      'No dresses, no bag, I already own shoes',
    );
    final plan = OutfitPlan.from(
      brief: 'Formal summer wedding',
      outfit: {},
      constraints: constraints,
    );
    expect(plan.slots, [ProductCategory.top, ProductCategory.bottom]);
    final complete = OutfitPlan.from(
      brief: 'Formal summer wedding',
      constraints: constraints,
      outfit: outfitOf([ProductCategory.top, ProductCategory.bottom]),
    );
    expect(complete.complete, isTrue);
    expect(complete.filledCount, 2);
  });

  test('owned foundation determines the remaining outfit route', () {
    final constraints = const StylistConstraints().recordMessage(
      'I already own a dress',
    );
    final plan = OutfitPlan.from(
      brief: 'Casual summer lunch',
      outfit: {},
      constraints: constraints,
    );
    expect(plan.slots, [ProductCategory.shoes, ProductCategory.bag]);
  });

  test(
    'full look cost distinguishes affordable and impossible dress choices',
    () {
      final catalog = [
        piece(ProductCategory.dress, price: 300),
        piece(ProductCategory.shoes, price: 100),
        piece(ProductCategory.bag, price: 50),
      ];
      final expensive = assessOutfitSelection(
        candidate: piece(ProductCategory.dress, price: 450),
        outfit: {},
        catalog: catalog,
        brief: 'Summer wedding',
        budget: 500,
      );
      expect(expensive.minimumTotal, 600);
      expect(expensive.feasible, isFalse);
      expect(expensive.explanation, contains('600.00'));
      final affordable = assessOutfitSelection(
        candidate: catalog.first,
        outfit: {},
        catalog: catalog,
        brief: 'Summer wedding',
        budget: 500,
      );
      expect(affordable.minimumTotal, 450);
      expect(affordable.feasible, isTrue);
    },
  );

  test(
    'minimum completion reserves only missing pieces and releases replacements',
    () {
      final selected = {
        'first': piece(ProductCategory.top, price: 95),
        'second': piece(ProductCategory.bottom, price: 110),
        'third': piece(ProductCategory.shoes, price: 80),
      };
      final result = assessOutfitSelection(
        candidate: piece(ProductCategory.dress, price: 200),
        outfit: selected,
        catalog: [piece(ProductCategory.bag, price: 50)],
        brief: 'Summer wedding',
        budget: 350,
      );
      expect(result.minimumTotal, 330);
      expect(result.feasible, isTrue);
      expect(selected.keys, ['first', 'second', 'third']);
    },
  );

  test('owned and excluded categories do not reserve purchase budget', () {
    final result = assessOutfitSelection(
      candidate: piece(ProductCategory.dress, price: 450),
      outfit: {},
      catalog: [],
      brief: 'Summer wedding',
      budget: 500,
      constraints: const StylistConstraints().recordMessage(
        'I already own shoes, no bag',
      ),
    );
    expect(result.minimumTotal, 450);
    expect(result.feasible, isTrue);
  });

  test('unavailable constrained categories differ from exceeding budget', () {
    final result = assessOutfitSelection(
      candidate: piece(ProductCategory.dress, price: 50),
      outfit: {},
      catalog: [piece(ProductCategory.bag)],
      brief: 'Summer wedding',
      budget: 500,
    );
    expect(result.withinBudget, isTrue);
    expect(result.feasible, isFalse);
    expect(result.unavailableCategories, [ProductCategory.shoes]);
    expect(result.explanation, contains('No catalog option'));
  });

  test('new restrictions reopen incompatible required pieces without removing them', () {
    final outfit = outfitOf([
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
    // Only the selected top has a prohibited material; keep the other fixtures
    // verifiably compliant so this test proves count and next-slot behavior.
    final knownMaterials = {
      for (final entry in outfit.entries)
        entry.key: Product(
          id: entry.value.id,
          category: entry.value.category,
          name: entry.value.name,
          brand: 'Sample',
          price: 50,
          meta: '',
          tag: '',
          swatch: '#000000',
          material: entry.value.category == ProductCategory.top
              ? 'wool'
              : 'cotton',
        ),
    };
    final plan = OutfitPlan.from(
      brief: 'Casual summer lunch',
      outfit: knownMaterials,
      constraints: const StylistConstraints().recordMessage('No wool'),
    );
    expect(plan.complete, isFalse);
    expect(plan.nextCategory, ProductCategory.top);
    expect(plan.filledCount, 3);
    expect(plan.conflictingCategories, {ProductCategory.top});
    expect(plan.displaySlots, contains(ProductCategory.top));
    expect(knownMaterials, hasLength(4));
  });

  test('excluded selected extras prevent completion even without an open required slot', () {
    final outfit = outfitOf([
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
    final plan = OutfitPlan.from(
      brief: 'Casual summer lunch',
      outfit: outfit,
      constraints: const StylistConstraints().recordMessage('No bag'),
    );
    expect(plan.slots, [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
    ]);
    expect(plan.filledCount, 3);
    expect(plan.nextCategory, isNull);
    expect(plan.complete, isFalse);
    expect(plan.conflictingCategories, {ProductCategory.bag});
    expect(plan.displaySlots, contains(ProductCategory.bag));
    expect(outfit, hasLength(4));
  });
}
