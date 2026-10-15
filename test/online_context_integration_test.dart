import 'stylist_wire_helpers.dart';

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/city_context.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genkit/genkit.dart' as g;

import 'city_context_test.dart' show FixtureContext, inlineData;
import 'progressive_agent_test.dart' show action;
import 'stylist_runtime_test.dart' show products, toolResponse;

const refresh = {
  'action': {'name': 'refresh_city_context', 'context': <String, Object?>{}},
};

class PendingContext extends FixtureContext {
  final started = Completer<void>();
  final pending = Completer<CityContext>();
  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) {
    if (city.startsWith('Paris')) {
      started.complete();
      return pending.future;
    }
    return super.fetch(city, refresh: refresh);
  }
}

void main() {
  test('refresh keeps current controls and history; historical refresh is rejected', () async {
    final source = FixtureContext();
    var requests = 0;
    final runtime = StylistRuntime(
      products: products,
      cityContextSource: source,
      onModelRequest: (_) => requests++,
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.berlin);
    await agent.conversation.sendRequest(
      action('select_product', {'productId': 'top-1'}, surfaceId: 'inline-1'),
    );
    expect(agent.latestInlineSurfaceId, 'inline-2');
    final before = requests;
    final entries = agent.conversationEntries.toList();
    final room = jsonEncode(
      agent.controller
          .contextFor('dressing-room')
          .dataModel
          .getValue<Object?>(DataPath('/')),
    );
    final oldWeather = jsonEncode(
      agent.controller
          .contextFor('inline-1')
          .dataModel
          .getValue<Object?>(DataPath('/weather')),
    );
    final current = agent.controller.contextFor('inline-2').dataModel;
    final choices = jsonEncode(
      current.getValue<Object?>(DataPath('/recommendations')),
    );
    final reply = current.getValue<String>(DataPath('/message'));
    final next = current.getValue<String>(DataPath('/eyebrow'));
    source.fail = true;
    await agent.conversation.sendRequest(
      action('refresh_city_context', {}, surfaceId: 'inline-2'),
    );
    expect(agent.connectionError, isNull);
    expect(agent.latestInlineSurfaceId, 'inline-2');
    expect(agent.conversationEntries, entries);
    expect(current.getValue<Object?>(DataPath('/weather')), isNull);
    expect(
      current.getValue<String>(DataPath('/contextNotice')),
      contains('Could not load'),
    );
    expect(current.getValue<String>(DataPath('/message')), reply);
    expect(current.getValue<String>(DataPath('/eyebrow')), next);
    expect(
      jsonEncode(current.getValue<Object?>(DataPath('/recommendations'))),
      choices,
    );
    expect(
      jsonEncode(
        agent.controller
            .contextFor('dressing-room')
            .dataModel
            .getValue<Object?>(DataPath('/')),
      ),
      room,
    );
    expect(
      jsonEncode(
        agent.controller
            .contextFor('inline-1')
            .dataModel
            .getValue<Object?>(DataPath('/weather')),
      ),
      oldWeather,
    );
    final calls = source.calls.length;
    await agent.conversation.sendRequest(
      action('refresh_city_context', {}, surfaceId: 'inline-1'),
    );
    expect(source.calls, hasLength(calls));
    source.fail = false;
    await agent.conversation.sendRequest(
      action('refresh_city_context', {}, surfaceId: 'inline-2'),
    );
    expect(current.getValue<Object?>(DataPath('/weather')), isNotNull);
    expect(requests, before);
    await agent.conversation.sendRequest(
      action('select_product', {
        'productId': 'bottom-1',
      }, surfaceId: 'inline-2'),
    );
    expect(agent.connectionError, isNull);
    expect(agent.latestInlineSurfaceId, 'inline-3');
    expect(runtime.outfit['items'], {'top': 'top-1', 'bottom': 'bottom-1'});
  });

  test(
    'refresh preserves an incomplete brief and does not consume a turn',
    () async {
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: FixtureContext(),
      );
      addTearDown(runtime.dispose);
      final first = await runtime.turn({
        'message': 'A work day in Berlin today',
      });
      final data = inlineData(first);
      final updated = await runtime.turn(refresh);
      expect(inlineData(updated), data);
      expect(
        (presentedStylistTurn(updated)['messages'] as List).every(
          (m) => m['createSurface'] == null,
        ),
        isTrue,
      );
      final next = await runtime.turn({
        'action': {
          'name': 'find_options',
          'context': {'dressCode': 'smart casual', 'budget': 900},
        },
      });
      expect(
        (presentedStylistTurn(next)['messages'] as List)
            .where((m) => m['createSurface'] != null)
            .single['createSurface']['surfaceId'],
        'inline-2',
      );
    },
  );

  test('failed destination lookup clears old weather and supplies an honest model notice', () async {
    final source = FixtureContext();
    final prompts = <String>[];
    final runtime = StylistRuntime(
      products: products,
      cityContextSource: source,
      onModelRequest: (r) => prompts.add(r.messages.first.text),
    );
    addTearDown(runtime.dispose);
    runtime.reset(journey: DemoJourney.berlin);
    await runtime.turn({
      'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
    });
    source.fail = true;
    final changed = await runtime.turn({
      'message': 'A smart casual work day in Paris today, budget €900',
    });
    expect(inlineData(changed)['weather'], isNull);
    expect(inlineData(changed)['cityLabel'], 'Paris');
    expect(prompts.last, contains('Could not load the forecast for Paris'));
    expect(prompts.last, isNot(contains('rainProbabilityPercent')));
  });

  test(
    'failed model completion rolls back destination as well as outfit',
    () async {
      final source = FixtureContext();
      var fail = false;
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
        model: (r) async {
          if (fail && r.tools?.isEmpty == true) {
            throw StateError('Failed completion');
          }
          return offlineStylistModel(r);
        },
      );
      addTearDown(runtime.dispose);
      runtime.reset(journey: DemoJourney.berlin);
      await runtime.turn({
        'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
      });
      fail = true;
      await expectLater(
        runtime.turn({
          'message': 'A smart casual day in Paris today, budget €900',
        }),
        throwsA(anything),
      );
      fail = false;
      final restored = await runtime.turn(refresh);
      expect(inlineData(restored)['cityLabel'], 'Berlin, Test country');
      expect(runtime.outfit['items'], isEmpty);
    },
  );

  test('save_outfit supports destinations beyond preset cities before the next model request', () async {
    final source = FixtureContext();
    var save = false;
    var sawNewFacts = false;
    final runtime = StylistRuntime(
      products: products,
      cityContextSource: source,
      model: (r) async {
        if (save) {
          save = false;
          return toolResponse('save_outfit', {'city': 'Kyoto, Japan'});
        }
        sawNewFacts |= r.messages.first.text.contains('Kyoto, Test country');
        return offlineStylistModel(r);
      },
    );
    addTearDown(runtime.dispose);
    runtime.reset(journey: DemoJourney.berlin);
    await runtime.turn({
      'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
    });
    save = true;
    final changed = await runtime.turn({
      'message': 'Change my destination to Kyoto, Japan',
    });
    expect(source.calls, contains('Kyoto, Japan'));
    expect(sawNewFacts, isTrue);
    expect(inlineData(changed)['cityLabel'], 'Kyoto, Test country');
  });

  test(
    'country qualifiers survive repeated mentions of the same city',
    () async {
      final source = FixtureContext();
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
      );
      addTearDown(runtime.dispose);
      runtime.reset(journey: DemoJourney.berlin);
      await runtime.turn({
        'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
      });
      expect(source.calls.last, 'Berlin, Germany');
      await runtime.turn({
        'message': 'A smart casual work day in Berlin, United States today',
      });
      expect(source.calls.last, 'Berlin, United States');
      await runtime.turn({'message': 'Keep the day in Berlin'});
      expect(source.calls.last, 'Berlin, United States');
    },
  );

  test(
    'cancelling a pending forecast permits a new journey before its response',
    () async {
      final source = PendingContext();
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.berlin);
      final old = agent.conversation.sendRequest(
        ChatMessage.user('A smart casual day in Paris today, budget €900'),
      );
      await source.started.future;
      final replacement = agent.startJourney(DemoJourney.lisbon);
      await Future.wait([old, replacement]).timeout(const Duration(seconds: 3));
      expect(agent.connectionError, isNull);
      expect(agent.activeJourney, DemoJourney.lisbon);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(
        agent.controller
            .contextFor('inline-1')
            .dataModel
            .getValue<String>(DataPath('/cityLabel')),
        'Lisbon, Test country',
      );
      source.pending.complete(await FixtureContext().fetch('Paris'));
      await Future<void>.delayed(Duration.zero);
      expect(
        agent.controller
            .contextFor('inline-1')
            .dataModel
            .getValue<String>(DataPath('/cityLabel')),
        'Lisbon, Test country',
      );
    },
  );
}
