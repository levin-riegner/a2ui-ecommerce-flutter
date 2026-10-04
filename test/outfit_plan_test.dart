import 'package:a2ui_flutter_commerce/src/agent/outfit_plan.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
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
}
