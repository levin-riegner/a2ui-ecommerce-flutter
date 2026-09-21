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
}

enum ProductCategory { dress, layer, shoes, bag }

class Product {
  const Product({
    required this.id,
    required this.journey,
    required this.category,
    required this.name,
    required this.brand,
    required this.price,
    required this.meta,
    required this.tag,
    required this.swatch,
  });

  final String id;
  final DemoJourney journey;
  final ProductCategory category;
  final String name;
  final String brand;
  final double price;
  final String meta;
  final String tag;
  final String swatch;

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
