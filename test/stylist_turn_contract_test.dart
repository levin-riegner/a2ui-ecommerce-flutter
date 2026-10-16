import 'stylist_wire_helpers.dart';

import 'dart:convert';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products, action, toolResponse;

void main() {
  test(
    'plain 500 is acknowledged and cannot become a model suggested 750',
    () async {
      final model = _ToolModel()..queue('save_outfit', {'budget': 750});
      final runtime = StylistRuntime(products: products, model: model.respond);
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'I have 500 to spend on a casual outfit.',
      });
      expect(result['brief']['budget'], 500);
      expect(runtime.outfit['budget'], 500);
      expect(result['reply'], contains('€500'));
      expect(result['reply'], isNot(contains('750')));
      expect(model.outputs['save_outfit']!['brief']['budget'], 500);
      expect(model.calls, lessThanOrEqualTo(4));
    },
  );

  test('an item price does not replace the whole outfit budget', () async {
    final runtime = StylistRuntime(products: products);
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'A €120 dress; €500 for the outfit. Keep the style casual.',
    });
    expect(result['brief']['budget'], 500);
    expect(runtime.outfit['budget'], 500);
    expect(result['reply'], contains('€500'));
    expect(result['reply'], isNot(contains('Budget: €120')));
  });

  test('repeating an accepted budget is acknowledged again', () async {
    final runtime = StylistRuntime(products: products);
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A casual outfit with 500 to spend.'});
    final result = await runtime.turn({'message': 'My budget is still 500.'});
    expect(result['brief']['budget'], 500);
    expect(result['reply'], contains('€500'));
  });

  test('apply_outfit_changes explicitly clears recorded notes', () async {
    final model = _ToolModel()
      ..queue('save_outfit', {'notes': 'comfortable shoes'});
    final runtime = StylistRuntime(products: products, model: model.respond);
    addTearDown(runtime.dispose);
    final initial = await runtime.turn({
      'message': 'A casual outfit under €500; prefer comfortable shoes.',
    });
    expect(initial['brief']['notes'], 'comfortable shoes');
    model.queue('apply_outfit_changes', {
      'clearFields': ['notes'],
    });
    final result = await runtime.turn({'message': 'Discard those notes.'});
    expect(result['brief'], isNot(contains('notes')));
    expect(
      model.outputs['apply_outfit_changes']!['brief'],
      isNot(contains('notes')),
    );
    expect(result['reply'].toString().toLowerCase(), contains('notes'));
  });

  test(
    'one atomic turn removes a selected dress and lowers the budget',
    () async {
      final model = _ToolModel();
      final runtime = StylistRuntime(products: products, model: model.respond);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A casual summer dress under €200.'});
      await runtime.turn(action('select_product', 'dress-1'));
      expect(runtime.outfit['items'], {'dress': 'dress-1'});
      model.queue('apply_outfit_changes', {
        'brief': {'budget': 50},
        'removeProductIds': ['dress-1'],
      });
      final beforeCalls = model.calls;
      final result = await runtime.turn({
        'message': 'Remove the dress and lower my budget to €50.',
      });
      expect(runtime.outfit['items'], isEmpty);
      expect(runtime.outfit['budget'], 50);
      expect(result['brief']['budget'], 50);
      expect(result['reply'], contains('Removed Linen dress.'));
      expect(result['reply'], contains('€50'));
      expect(model.outputs['apply_outfit_changes'], isNot(contains('error')));
      expect(model.calls - beforeCalls, lessThanOrEqualTo(4));
    },
  );

  test(
    'a failed atomic combination rolls back brief, removals and turn history',
    () async {
      final model = _ToolModel();
      final runtime = StylistRuntime(products: products, model: model.respond);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A casual summer dress under €200.'});
      final selected = await runtime.turn(action('select_product', 'dress-1'));
      final before = Map<String, Object?>.from(runtime.outfit);
      model.queue('apply_outfit_changes', {
        'brief': {'budget': 50, 'palette': 'red'},
        'removeProductIds': ['dress-1', 'not-selected'],
      });
      Object? rejection;
      try {
        await runtime.turn({
          'message': 'Remove the dress, change the palette to red and lower my budget to €50.',
        });
      } catch (error) {
        rejection = error;
      }
      expect(rejection, isNotNull);
      expect(runtime.outfit, before);
      expect(model.outputs['apply_outfit_changes'], contains('error'));
      final recovered = await runtime.turn({
        'message': 'Keep my current outfit.',
      });
      expect(recovered['brief'], selected['brief']);
      expect(runtime.outfit, before);
      final surfaceIds = (presentedStylistTurn(recovered)['messages'] as List)
          .where((message) => message['createSurface'] != null)
          .map((message) => message['createSurface']['surfaceId']);
      expect(surfaceIds, contains('inline-3'));
      expect(
        rejection,
        isA<StylistInputError>().having(
          (error) => error.message,
          'safe corrective message',
          isNotEmpty,
        ),
      );
    },
  );

  test(
    'malformed piece actions remain correctable through ordinary input',
    () async {
      final runtime = StylistRuntime(products: products);
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startBrief('A casual outfit under €500.');
      final surface = agent.latestInlineSurfaceId;
      await agent.conversation.sendRequest(
        ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(
              jsonEncode({
                'action': {
                  'name': 'adjust_piece',
                  'context': {'category': 'unknown', 'adjustment': 42},
                },
              }),
            ),
          ],
        ),
      );
      expect(agent.inputError, isNotNull);
      expect(agent.connectionError, isNull);
      expect(agent.canRetry, isFalse);
      expect(agent.latestInlineSurfaceId, surface);
      await agent.conversation.sendRequest(
        ChatMessage.user('My budget is €400.'),
      );
      expect(runtime.outfit['budget'], 400);
      expect(agent.inputError, isNull);
      expect(agent.connectionError, isNull);
    },
  );

  test('rejected atomic changes cannot commit extracted facts when the budget still fits', () async {
    final model = _ToolModel();
    final runtime = StylistRuntime(products: products, model: model.respond);
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A casual summer dress under €200.'});
    final selected = await runtime.turn(action('select_product', 'dress-1'));
    final before = Map<String, Object?>.from(runtime.outfit);
    model.outputs.clear();
    model.queue('apply_outfit_changes', {
      'brief': {'budget': 100, 'season': 'winter'},
      'removeProductIds': ['dress-1', 'not-selected'],
    });
    await expectLater(
      runtime.turn({
        'message': 'Remove the dress, change the season to winter and lower my budget to €100.',
      }),
      throwsA(isA<StylistInputError>()),
    );
    // The model continues normally after the tool rejects the draft. Neither
    // those requests nor a budget that still covers the selected dress can
    // turn the rejected batch into a partially committed successful turn.
    expect(model.outputs['apply_outfit_changes'], contains('error'));
    expect(model.outputs, contains('search_products'));
    expect(runtime.outfit, before);
    final recovered = await runtime.turn({
      'message': 'Keep my current outfit.',
    });
    expect(recovered['brief'], selected['brief']);
    expect(recovered['brief']['season'], 'summer');
    expect(recovered['brief']['budget'], 200);
    expect(runtime.outfit, before);
  });

  test(
    'a rejected atomic edit keeps the existing conversation correctable',
    () async {
      final model = _ToolModel();
      final runtime = StylistRuntime(products: products, model: model.respond);
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startBrief('A casual summer dress under €200.');
      await agent.conversation.sendRequest(
        ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(
              jsonEncode(action('select_product', 'dress-1')),
            ),
          ],
        ),
      );
      final before = Map<String, Object?>.from(runtime.outfit);
      final surface = agent.latestInlineSurfaceId;
      model.queue('apply_outfit_changes', {
        'brief': {'budget': 50, 'palette': 'red'},
        'removeProductIds': ['dress-1', 'not-selected'],
      });
      await agent.conversation.sendRequest(
        ChatMessage.user(
          'Remove the dress, change the palette to red and lower my budget to €50.',
        ),
      );
      expect(runtime.outfit, before);
      expect(agent.latestInlineSurfaceId, surface);
      expect(agent.inputError, isNotNull);
      expect(agent.connectionError, isNull);
      expect(agent.canRetry, isFalse);
      await agent.conversation.sendRequest(
        ChatMessage.user('Keep my current outfit.'),
      );
      expect(runtime.outfit, before);
      expect(agent.inputError, isNull);
      expect(agent.connectionError, isNull);
      expect(agent.latestInlineSurfaceId, isNot(surface));
    },
  );
}

/// Injects one explicit tool proposal, then uses the deterministic offline model.
class _ToolModel {
  String? _nextTool;
  Map<String, dynamic> _nextInput = {};
  int calls = 0;
  final Map<String, Map<dynamic, dynamic>> outputs = {};

  void queue(String name, Map<String, dynamic> input) {
    _nextTool = name;
    _nextInput = input;
  }

  Future<ModelResponse> respond(ModelRequest request) async {
    calls++;
    for (final part in request.messages.last.content) {
      final response = part.toolResponse;
      if (response != null && response.output is Map) {
        outputs[response.name] = Map.of(response.output as Map);
      }
    }
    final name = _nextTool;
    if (name != null) {
      expect(request.tools!.map((tool) => tool.name), contains(name));
      _nextTool = null;
      return toolResponse(name, _nextInput);
    }
    return offlineStylistModel(request);
  }
}
