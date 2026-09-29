enum DemoJourney {
  paris(
    title: 'Anniversary dinner in Paris',
    brief: 'Autumn · black tie · under €1,500',
    occasion: 'Anniversary dinner',
    season: 'Autumn',
    budget: 1500,
    foundationCategory: ProductCategory.dress,
  ),
  berlin(
    title: 'Berlin first day',
    brief: 'Spring · smart layers · under €900',
    occasion: 'City exploring',
    season: 'Spring',
    budget: 900,
    foundationCategory: ProductCategory.layer,
  ),
  cotswolds(
    title: 'Cotswolds weekend',
    brief: 'Winter · relaxed layers · under €1,200',
    occasion: 'Weekend away',
    season: 'Winter',
    budget: 1200,
    foundationCategory: ProductCategory.layer,
  ),
  lisbon(
    title: 'Lisbon long lunch',
    brief: 'Summer · polished ease · under €750',
    occasion: 'Long lunch',
    season: 'Summer',
    budget: 750,
    foundationCategory: ProductCategory.dress,
  );

  const DemoJourney({
    required this.title,
    required this.brief,
    required this.occasion,
    required this.season,
    required this.budget,
    required this.foundationCategory,
  });

  final String title;
  final String brief;
  final String occasion;
  final String season;
  final double budget;
  final ProductCategory foundationCategory;

  String get catalogOccasion => switch (this) {
    paris => 'celebration',
    berlin => 'work',
    cotswolds => 'weekend',
    lisbon => 'travel',
  };
}

enum ProductCategory { dress, top, bottom, layer, shoes, bag, accessory }

class Product {
  const Product({
    required this.id,
    this.journey,
    required this.category,
    required this.name,
    required this.brand,
    required this.price,
    required this.meta,
    required this.tag,
    required this.swatch,
    this.description = '',
    this.subcategory = '',
    this.color = '',
    this.material = '',
    this.season = '',
    this.occasion = '',
    this.imageAsset = '',
    this.keywords = '',
  });

  final String id;
  final DemoJourney? journey;
  final ProductCategory category;
  final String name;
  final String brand;
  final double price;
  final String meta;
  final String tag;
  final String swatch;
  final String description;
  final String subcategory;
  final String color;
  final String material;
  final String season;
  final String occasion;
  final String imageAsset;
  final String keywords;

  String get priceLabel => '€${price.toStringAsFixed(0)}';

  String get brandLine => '$brand · $meta';
}

class DressingPiece {
  const DressingPiece({
    required this.category,
    required this.label,
    required this.meta,
    required this.swatch,
    required this.state,
  });

  final ProductCategory category;
  final String label;
  final String meta;
  final String swatch;
  final String state;
}
