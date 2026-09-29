import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:a2ui_flutter_commerce/src/agent/remote_agent.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';

List<Map<String, Object?>> _surfaceMessages(
  String inlineId, {
  required bool createPersistent,
}) => [
  if (createPersistent)
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 'dressing-room',
        'catalogId': commerceCatalogId,
      },
    },
  {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'dressing-room',
      'components': [
        {'id': 'root', 'component': 'StylistMessage', 'text': 'Dressing room'},
      ],
    },
  },
  if (createPersistent)
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 'selected-products',
        'catalogId': commerceCatalogId,
      },
    },
  {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'selected-products',
      'components': [
        {'id': 'root', 'component': 'StylistMessage', 'text': 'Selected'},
      ],
    },
  },
  {
    'version': 'v0.9',
    'createSurface': {'surfaceId': inlineId, 'catalogId': commerceCatalogId},
  },
  {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': inlineId,
      'components': [
        {'id': 'root', 'component': 'StylistMessage', 'text': 'Options'},
      ],
    },
  },
];

void main() {
  test(
    'remote stylist forwards session and feeds returned A2UI surfaces',
    () async {
      final requests = <Map<String, dynamic>>[];
      var turn = 0;
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/turn');
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(input);
        final newJourney = !input.containsKey('sessionId');
        turn = newJourney ? 1 : turn + 1;
        return http.Response(
          jsonEncode({
            'sessionId': 'demo-session',
            'messages': _surfaceMessages(
              'inline-$turn',
              createPersistent: newJourney,
            ),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final agent = RemoteAgent(
        Uri.parse('http://127.0.0.1:8787'),
        client: client,
      );
      addTearDown(agent.dispose);

      await agent.startJourney(DemoJourney.paris);
      expect(requests.single['message'], contains('Anniversary dinner'));
      expect(requests.single.containsKey('sessionId'), isFalse);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(agent.hasSelectedProductsSurface, isTrue);
      expect(
        agent.controller.contextFor('inline-1').definition.value,
        isNotNull,
      );

      await agent.conversation.sendRequest(ChatMessage.user('Under €300'));
      expect(requests.last['sessionId'], 'demo-session');
      expect(requests.last['message'], 'Under €300');
      expect(agent.latestInlineSurfaceId, 'inline-2');
      expect(
        agent.controller.contextFor('inline-2').definition.value,
        isNotNull,
      );

      await agent.startJourney(DemoJourney.berlin);
      expect(requests.last.containsKey('sessionId'), isFalse);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(
        agent.controller.contextFor('inline-1').definition.value,
        isNotNull,
      );
    },
  );

  test(
    'overlapping chat turns use the session returned by the prior turn',
    () async {
      final requests = <Map<String, dynamic>>[];
      final releaseSecondTurn = Completer<void>();
      final secondTurnStarted = Completer<void>();
      final client = MockClient((request) async {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(input);
        final turn = requests.length;
        if (turn == 2) {
          secondTurnStarted.complete();
          await releaseSecondTurn.future;
        }
        return http.Response(
          jsonEncode({
            'sessionId': 'session-$turn',
            'messages': _surfaceMessages(
              'inline-$turn',
              createPersistent: turn == 1,
            ),
          }),
          200,
        );
      });
      final agent = RemoteAgent(
        Uri.parse('http://127.0.0.1:8787'),
        client: client,
      );
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.paris);

      final second = agent.conversation.sendRequest(ChatMessage.user('First'));
      await secondTurnStarted.future;
      final third = agent.conversation.sendRequest(ChatMessage.user('Second'));
      expect(requests, hasLength(2));
      releaseSecondTurn.complete();
      await Future.wait([second, third]);

      expect(requests, hasLength(3));
      expect(requests[1]['sessionId'], 'session-1');
      expect(requests[2]['sessionId'], 'session-2');
    },
  );

  test('expired session restarts with the current text', () async {
    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final input = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(input);
      if (requests.length == 2) {
        return http.Response(
          jsonEncode({'error': 'Unknown or expired session'}),
          404,
        );
      }
      return http.Response(
        jsonEncode({
          'sessionId': 'session-${requests.length}',
          'messages': _surfaceMessages(
            'inline-${requests.length}',
            createPersistent: true,
          ),
        }),
        200,
      );
    });
    final agent = RemoteAgent(
      Uri.parse('http://127.0.0.1:8787'),
      client: client,
    );
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.paris);
    await agent.conversation.sendRequest(ChatMessage.user('Under €300'));

    expect(requests, hasLength(3));
    expect(requests[1]['sessionId'], 'session-1');
    expect(requests[2].containsKey('sessionId'), isFalse);
    expect(requests[2]['message'], contains('Under €300'));
    expect(agent.hasSelectedProductsSurface, isTrue);
  });
}
