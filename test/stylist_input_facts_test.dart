import 'package:a2ui_flutter_commerce/src/agent/stylist_brief.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_brief_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'whole-outfit budget handles plain spending, currency and corrections',
    () {
      for (final message in [
        'I have 500 to spend on an outfit',
        'I have 500 euros to spend',
        'A €120 dress; €500 for the outfit',
        'A €120 dress and €500 for the outfit',
        '€500 for the outfit including €200 shoes',
        '€200 for shoes; €500 for the outfit',
        'Not €750, €500',
        'My budget is 500',
      ]) {
        expect(parseBriefBudget(message), 500, reason: message);
        expect(
          const StylistBrief().recordMessage(message).budget,
          500,
          reason: message,
        );
      }
      expect(parseBriefBudget('€200 for shoes'), isNull);
      expect(parseBriefBudget('A dress under €200'), 200);
      expect(parseBriefBudget('€500 budget and €200 shoes'), 500);
      expect(parseBriefBudget('size 38, 2 pairs of shoes'), isNull);
      expect(parseBriefBudget('€500 or €750'), isNull);
    },
  );

  test('non-EUR budgets cannot silently become EUR facts', () {
    for (final message in [
      r'My budget is $500',
      'My budget is £500',
      'I have 500 USD to spend',
      'I have 500 dollars to spend',
      'GBP 500 for the whole outfit',
      'A dress under £200',
    ]) {
      expect(
        unsupportedBriefBudgetCurrency(message),
        isNotNull,
        reason: message,
      );
      expect(parseBriefBudget(message), isNull, reason: message);
      expect(
        const StylistBrief().recordMessage(message).budget,
        isNull,
        reason: message,
      );
    }
    expect(unsupportedBriefBudgetCurrency('Budget 500 euros'), isNull);
    expect(unsupportedBriefBudgetCurrency(r'Not $500, €300'), isNull);
    expect(parseBriefBudget(r'Not $500, €300'), 300);
    expect(
      unsupportedBriefBudgetCurrency(r'A $120 dress; €500 for the outfit'),
      isNull,
    );
    expect(parseBriefBudget(r'A $120 dress; €500 for the outfit'), 500);
    expect(parseBriefBudget('My budget is -500'), isNull);
  });

  test('budget parsing preserves EUR cents and grouping', () {
    for (final message in ['€1,200.50', '1.200,50 euros', '€1 200,50']) {
      expect(parseBriefBudget(message), 1200.5);
    }
  });

  test('negated styles and categories do not become positive facts', () {
    expect(
      const StylistBrief().recordMessage('Not formal, casual please').dressCode,
      'casual',
    );
    expect(const StylistBrief().recordMessage('No dresses').dressCode, isEmpty);
    expect(
      const StylistBrief().recordMessage('I do not need a bag').dressCode,
      isEmpty,
    );
    expect(
      const StylistBrief().recordMessage('Smart casual').dressCode,
      'smart-casual',
    );
    expect(
      const StylistBrief().recordMessage('Not winter, summer').season,
      'summer',
    );
  });

  test('explicit occasion correction replaces the initial occasion', () {
    final brief = const StylistBrief().recordMessage('An interview');
    expect(
      brief.recordMessage('Actually, a summer wedding').occasion,
      'a wedding',
    );
  });

  test('model proposals cannot replace user facts with defaults', () {
    final user = const StylistBrief().recordMessage(
      'Smart casual, I have 500 to spend',
    );
    final model = user.merge(
      {'budget': 750, 'dressCode': 'formal', 'notes': 'No wool'},
      source: BriefFactSource.model,
      protectUserFacts: true,
    );
    expect(model.budget, 500);
    expect(model.dressCode, 'smart-casual');
    expect(model.notes, 'No wool');
    expect(model.sources['budget'], BriefFactSource.user);
    expect(model.acceptedFactsFromMessage('My budget is 500')['budget'], 500);
    expect(model.sources['notes'], BriefFactSource.model);
    expect(model.recordMessage('Actually, my budget is €300').budget, 300);
    expect(
      model.acceptedFactsFromMessage('Smart casual')['dressCode'],
      'smart-casual',
    );
  });

  test(
    'explicit clearing and replacing preferences do not retain stale facts',
    () {
      final original = const StylistBrief().merge({
        'notes': 'No wool',
        'palette': 'Black',
        'budget': 500,
      });
      final cleared = original.merge({}, clearFields: {'notes', 'palette'});
      expect(cleared.notes, isEmpty);
      expect(cleared.palette, isEmpty);
      expect(cleared.budget, 500);
      expect(cleared.changedFactsSince(original), {
        'palette': null,
        'notes': null,
      });
      expect(original.recordMessage('Clear my notes').notes, isEmpty);
      expect(original.notes, 'No wool');
      expect(
        () => original.merge({}, clearFields: {'unknown'}),
        throwsFormatException,
      );
    },
  );

  test('clarification uses accepted budget and labels unknown defaults', () {
    final known = renderStylistBriefSurface(
      reply: 'Choose a style',
      clarification: {
        'missingFields': ['dressCode'],
        'budget': 500,
      },
    );
    expect(known.data['budget'], 500);
    expect(known.data['budgetIsSuggested'], false);
    final unknown = renderStylistBriefSurface(
      reply: 'Choose your budget',
      clarification: {
        'missingFields': ['budget'],
      },
    );
    expect(unknown.data['budgetIsSuggested'], true);
    expect(
      unknown.components.singleWhere((c) => c['id'] == 'budget-label')['text'],
      contains('Suggested'),
    );
  });
}
