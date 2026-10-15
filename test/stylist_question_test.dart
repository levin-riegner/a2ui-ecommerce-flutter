import 'stylist_wire_helpers.dart';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_brief.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genui/genui.dart' show ChatMessage;

import 'custom_brief_journey_test.dart' show finishTurn;
import 'stylist_runtime_test.dart' show products, action, toolResponse;

const answer =
    'I can help build an outfit from the catalog, compare pieces, or refine a look. What are you dressing for?';

List<Map> inlineComponents(Map<String, dynamic> result) =>
    (presentedStylistTurn(result)['messages'] as List)
        .where(
          (m) =>
              m['updateComponents']?['surfaceId'].toString().startsWith(
                'inline-',
              ) ==
              true,
        )
        .expand((m) => m['updateComponents']['components'] as List)
        .cast<Map>()
        .toList();

ModelResponse prose(String text) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [TextPart(text: text)],
  ),
);

void main() {
  test('greetings and capability questions are not inferred occasions', () {
    for (final text in [
      'What can we do here?',
      'What can you do',
      'Hello',
      'Thanks',
      'What is casual?',
    ]) {
      expect(
        const StylistBrief().recordMessage(text).occasion,
        isEmpty,
        reason: text,
      );
    }
    expect(
      const StylistBrief().recordMessage('A summer wedding').occasion,
      'A wedding',
    );
    final graduation = const StylistBrief().recordMessage(
      'A casual summer outfit for my graduation. My budget is €500.',
    );
    expect(graduation.occasion, 'graduation');
    expect(graduation.sources['occasion'], BriefFactSource.user);
    expect(
      const StylistBrief()
          .recordMessage('I am not attending graduation')
          .occasion,
      isEmpty,
    );
  });

  test(
    'capability question produces one answer with no facts, controls or search',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          calls++;
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({'message': 'What can we do here?'});
      expect(result['intent'], 'capabilities');
      expect(result['brief'], isEmpty);
      expect(result['products'], isEmpty);
      expect(result['reply'], answer);
      expect(inlineComponents(result).map((c) => c['component']), [
        'StylistSection',
        'StylistMessage',
      ]);
      expect(runtime.outfit['budget'], isNull);
      expect(calls, 2);
      final next = await runtime.turn({
        'message': 'A casual summer dress under €500',
      });
      expect(next['brief']['occasion'].toString(), isNot(contains('What can')));
      expect(next['brief']['dressCode'], 'dress');
      expect(next['brief']['budget'], 500);
      expect(next['products'], isNotEmpty);
    },
  );

  test(
    'asking about a style or hypothetical budget does not set either fact',
    () async {
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (request.messages.last.role == Role.user) {
            return toolResponse('respond_to_question', {
              'intent': 'styling_advice',
              'facts': <String>[],
            });
          }
          expect(request.tools, isEmpty);
          return prose('Casual is relaxed everyday dressing.');
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'What is casual? Would a budget of €500 work?',
      });
      expect(result['brief'], isEmpty);
      expect(result['reply'], 'Casual is relaxed everyday dressing.');
      expect(result['products'], isEmpty);
    },
  );

  test(
    'mixed question retains only grounded, explicitly supplied facts',
    () async {
      var asking = true;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (!asking) return offlineStylistModel(request);
          if (request.messages.last.role == Role.user) {
            return toolResponse('respond_to_question', {
              'intent': 'capabilities',
              'facts': ['My budget is €500', 'No wool'],
            });
          }
          return prose(answer);
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'What can we do here? My budget is €500. No wool.',
      });
      expect(result['brief'], {'budget': 500.0});
      expect(result['constraints']['excludedMaterials'], contains('wool'));
      expect(result['reply'], contains('€500'));
      expect(result['reply'], isNot(contains('occasion:')));
      expect(
        inlineComponents(result).any((c) => c['component'] == 'BudgetSlider'),
        isFalse,
      );
      asking = false;
      final next = await runtime.turn({'message': 'A casual dress'});
      expect(next['brief']['budget'], 500);
      expect(next['constraints']['excludedMaterials'], contains('wool'));
    },
  );

  test('invented question facts are rejected by the tool', () async {
    Map? output;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        if (request.messages.last.role == Role.user) {
          return toolResponse('respond_to_question', {
            'intent': 'capabilities',
            'facts': ['My budget is €750'],
          });
        }
        output =
            request.messages.last.content
                    .firstWhere((p) => p.isToolResponse)
                    .toolResponse!
                    .output
                as Map;
        return prose(answer);
      },
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({'message': 'What can we do here?'});
    expect(output, contains('error'));
    expect(result['brief'], isEmpty);
    expect(runtime.outfit['budget'], isNull);
  });

  test(
    'model cannot promote the capability question into an occasion',
    () async {
      Map? output;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (request.messages.last.role == Role.user) {
            return toolResponse('save_outfit', {
              'occasion': 'What can we do here?',
              'occasionEvidence': 'What can we do here?',
            });
          }
          output =
              request.messages.last.content
                      .firstWhere((p) => p.isToolResponse)
                      .toolResponse!
                      .output
                  as Map;
          return prose(answer);
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({'message': 'What can we do here?'});
      expect(output, contains('error'));
      expect(result['brief'], isEmpty);
      expect(result['reply'], isNot(contains('Got it')));
      expect(result['reply'], isNot(contains('Tell me the style')));
    },
  );

  test(
    'model can save a new occasion grounded in the current message',
    () async {
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (request.messages.last.role == Role.user) {
            return toolResponse('save_outfit', {
              'occasion': 'graduation',
              'occasionEvidence': 'my graduation',
            });
          }
          return prose('How formal would you like the look?');
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'Help me dress for my graduation',
      });
      expect(result['brief']['occasion'], 'graduation');
      expect(result['reply'], contains('occasion: graduation'));
    },
  );

  test(
    'questions preserve selected pieces and last presented choices',
    () async {
      var asking = false;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (asking && request.messages.last.role == Role.user) {
            return toolResponse('respond_to_question', {
              'intent': 'styling_advice',
              'facts': <String>[],
            });
          }
          if (asking) return prose('Linen works well in warm weather.');
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A casual summer dress under €500'});
      final selected = await runtime.turn(action('select_product', 'dress-1'));
      final before = Map.of(runtime.outfit);
      final id = (selected['products'] as List).first['id'];
      asking = true;
      final question = await runtime.turn({'message': 'What is linen?'});
      expect(runtime.outfit, before);
      expect(question['brief'], selected['brief']);
      expect(question['products'], isEmpty);
      asking = false;
      await runtime.turn(action('select_product', id));
      expect((runtime.outfit['items'] as Map).values, contains(id));
    },
  );

  testWidgets(
    'capability question renders as chat and can continue into an outfit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final agent = (await tester.runAsync(
        () async => GenkitAgent(StylistRuntime(products: products)),
      ))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.runAsync(() => agent.startBrief('What can we do here?'));
      await finishTurn(tester, agent);
      expect(find.text(answer), findsOneWidget);
      expect(find.text('HOW FORMAL OR RELAXED?'), findsNothing);
      expect(find.text('Find options'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      await tester.runAsync(
        () => agent.conversation.sendRequest(
          ChatMessage.user('A casual dress under €500'),
        ),
      );
      await finishTurn(tester, agent);
      expect(find.text('Add to dressing room'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
