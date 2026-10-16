import 'package:a2ui_flutter_commerce/data/stylist/model/outfit_plan.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_brief.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asks for the two PoC clarifiers before searching', () {
    final brief = const StylistBrief().recordMessage('A summer wedding');
    expect(brief.occasion, 'A wedding');
    expect(brief.season, 'summer');
    expect(brief.missingFields, ['dressCode', 'budget']);
    expect(brief.canSearch, isFalse);
    final styled = brief.merge({'dressCode': 'cocktail'});
    expect(styled.missingFields, ['budget']);
    final ready = styled.merge({'budget': 1200});
    expect(ready.canSearch, isTrue);
    expect(ready.missingFields, isEmpty);
  });

  test('normalizes the shapes produced by controls in the original PoC', () {
    final brief = const StylistBrief().merge({
      'dressCode': ['cocktail'],
      'budget': '€1,200',
      'season': 'Summer',
    });
    expect(brief.toMap(), {
      'dressCode': 'cocktail',
      'budget': 1200.0,
      'season': 'summer',
    });
  });

  test('retains a free-form dress code and saved preferences', () {
    final brief = const StylistBrief().merge({
      'dressCode': ' Smart but warm ',
      'palette': 'Black and cream, nothing bright',
      'notes': 'Comfortable shoes; no wool',
    });
    expect(brief.dressCode, 'smart-but-warm');
    expect(brief.planningText, contains('smart but warm'));
    expect(brief.planningText, contains('Black and cream'));
    expect(brief.planningText, contains('no wool'));
  });

  test('typed style and budget settle facts without repeating questions', () {
    final first = const StylistBrief().recordMessage('An interview');
    expect(first.missingFields, ['dressCode', 'budget']);
    final next = first.recordMessage('Smart casual, €900', budget: 900);
    expect(next.occasion, 'An interview');
    expect(next.dressCode, 'smart-casual');
    expect(next.budget, 900);
    expect(next.canSearch, isTrue);
    expect(first.budget, isNull);
  });

  test('hello or an occasion alone does not invent a dress code', () {
    for (final message in ['hello', 'An interview under €900']) {
      final brief = const StylistBrief().recordMessage(message, budget: 900);
      expect(brief.dressCode, isEmpty);
      expect(brief.missingFields, ['dressCode']);
    }
  });

  test('explicit foundation requests remain valid free-form dress codes', () {
    final brief = const StylistBrief().recordMessage(
      'A dress under €200',
      budget: 200,
    );
    expect(brief.dressCode, 'dress');
    expect(brief.canSearch, isTrue);
  });

  test('a season correction replaces the old route fact', () {
    final winter = const StylistBrief().merge({
      'occasion': 'City lunch',
      'dressCode': 'casual',
      'season': 'winter',
      'budget': 900,
    });
    final summer = winter.recordMessage('Actually, summer');
    expect(summer.season, 'summer');
    expect(summer.planningText, isNot(contains('winter')));
    expect(
      OutfitPlan.from(brief: summer.planningText, outfit: {}).slots,
      isNot(contains(ProductCategory.layer)),
    );
    expect(winter.season, 'winter');
  });

  test('typed initial facts do not contaminate later season/style changes', () {
    final winter = const StylistBrief().recordMessage(
      'Winter black tie dinner under €900',
      budget: 900,
    );
    final revised = winter.recordMessage('Actually summer and casual');
    expect(revised.occasion, 'dinner');
    expect(revised.planningText, isNot(contains('winter')));
    expect(revised.planningText, isNot(contains('black tie')));
    expect(OutfitPlan.from(brief: revised.planningText, outfit: {}).slots, [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ]);
  });

  test(
    'asking about a category does not replace an established dress code',
    () {
      final brief = const StylistBrief().merge({'dressCode': 'cocktail'});
      expect(
        brief.recordMessage('Show me different tops').dressCode,
        'cocktail',
      );
    },
  );

  test('all demo journeys are prefilled rather than asking again', () {
    for (final journey in DemoJourney.values) {
      final brief = StylistBrief.fromJourney(journey);
      expect(brief.canSearch, isTrue);
      expect(brief.occasion, journey.title);
      expect(brief.budget, journey.budget);
      expect(brief.season, journey.season.toLowerCase());
    }
    expect(
      OutfitPlan.from(
        brief: StylistBrief.fromJourney(DemoJourney.paris).planningText,
        outfit: {},
      ).nextCategory,
      ProductCategory.dress,
    );
  });

  test('new saved facts replace preferences without losing other facts', () {
    final original = const StylistBrief().merge({
      'occasion': 'Dinner',
      'dressCode': 'cocktail',
      'budget': 1000,
      'palette': 'Black',
      'notes': 'No wool',
    });
    final updated = original.merge({
      'palette': 'Cream',
      'notes': 'Linen please',
    });
    expect(updated.palette, 'Cream');
    expect(updated.notes, 'Linen please');
    expect(updated.occasion, 'Dinner');
    expect(updated.budget, 1000);
    expect(updated.planningText, isNot(contains('No wool')));
    expect(original.palette, 'Black');
    expect(
      updated.merge({'notes': '  ', 'budget': null}).toMap(),
      updated.toMap(),
    );
  });

  test('EUR amounts accept locale separators and preserve cents', () {
    for (final value in ['€1,200.50', '1.200,50 EUR', '1200.50', 1200.5]) {
      expect(const StylistBrief().merge({'budget': value}).budget, 1200.5);
    }
    expect(const StylistBrief().merge({'budget': '€1 200'}).budget, 1200);
  });

  test(
    'invalid saves fail explicitly and leave the old snapshot unchanged',
    () {
      final original = StylistBrief.fromJourney(DemoJourney.berlin);
      for (final patch in <Map<String, Object?>>[
        {'season': 'monsoon'},
        {'budget': 0},
        {'budget': -1},
        {'budget': double.infinity},
        {'budget': double.nan},
        {'budget': true},
        {'budget': 'I think around 900'},
        {
          'palette': {'color': 'black'},
        },
        {
          'dressCode': ['casual', 'formal'],
        },
        {'unexpected': 1},
      ]) {
        expect(() => original.merge(patch), throwsFormatException);
      }
      expect(original.budget, 900);
      expect(original.season, 'spring');
    },
  );

  test('summary shows settled facts and currency without optional notes', () {
    final brief = const StylistBrief().merge({
      'occasion': 'Wedding',
      'dressCode': 'black tie',
      'season': 'autumn',
      'budget': 1200.5,
      'notes': 'No wool',
    });
    expect(brief.summary, 'Wedding · black tie · autumn · under €1200.50');
  });
}
