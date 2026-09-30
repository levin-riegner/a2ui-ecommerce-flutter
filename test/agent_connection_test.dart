import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/remote_agent.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _reply({String inlineId = 'inline-1', bool createRoom = true}) =>
    http.Response(
      jsonEncode({
        'sessionId': 'connected-session',
        'messages': [
          if (createRoom) ...[
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
                  {
                    'id': 'root',
                    'component': 'StylistMessage',
                    'text': 'Your dressing room',
                  },
                ],
              },
            },
          ],
          {
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': inlineId,
              'catalogId': commerceCatalogId,
            },
          },
          {
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': inlineId,
              'components': [
                {
                  'id': 'root',
                  'component': 'StylistMessage',
                  'text': 'Your stylist is ready.',
                },
              ],
            },
          },
        ],
      }),
      200,
    );

void main() {
  testWidgets('missing or invalid service configuration disables journeys', (
    tester,
  ) async {
    for (final url in [
      '',
      'file:///tmp/service',
      'https://',
      'https://user:secret@example.test',
    ]) {
      await tester.pumpWidget(
        ReferenceApp(key: ValueKey(url), serviceUrl: url),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stylist unavailable'), findsOneWidget);
      for (final chip in tester.widgetList<ActionChip>(
        find.byType(ActionChip),
      )) {
        expect(chip.onPressed, isNull);
      }
      expect(find.text('Find options'), findsNothing);
      expect(find.text('Explore component catalog'), findsOneWidget);
    }
  });

  testWidgets(
    'connection failure shows retry and disables chat until recovery',
    (tester) async {
      final pending = Completer<http.Response>();
      final requests = <String>[];
      final agent = RemoteAgent(
        Uri.parse('http://localhost:8787'),
        client: MockClient((request) {
          requests.add(request.body);
          return requests.length == 1 ? pending.future : Future.value(_reply());
        }),
      );
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.tap(find.text(DemoJourney.paris.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Connecting to your stylist…'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      // No dressing-room surface exists yet, so the renderer cannot spin forever.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(
        http.Response('provider detail should not reach the UI', 503),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stylist unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[1], requests[0]);
      expect(find.text('Your stylist is ready.'), findsOneWidget);
      expect(find.text('Stylist unavailable'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test('retry preserves failed chat text and session and prevents duplicate retries', () async {
    final requests = <Map<String, dynamic>>[];
    final agent = RemoteAgent(
      Uri.parse('http://localhost:8787'),
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (requests.length == 2) return http.Response('{}', 500);
        return _reply(
          inlineId: 'inline-${requests.length}',
          createRoom: requests.length == 1,
        );
      }),
    );
    addTearDown(agent.dispose);
    await agent.startJourney(DemoJourney.paris);
    await agent.conversation.sendRequest(
      ChatMessage.user('Add a bag under €100'),
    );
    expect(agent.canRetry, isTrue);
    final retry = agent.retryLastTurn();
    final duplicate = agent.retryLastTurn();
    expect(agent.isBusy, isTrue);
    await Future.wait([retry, duplicate]);
    expect(requests, hasLength(3));
    expect(requests[2], requests[1]);
    expect(agent.canRetry, isFalse);
    expect(agent.connectionError, isNull);
  });

  test(
    'malformed response keeps existing surfaces and can be retried',
    () async {
      var turn = 0;
      final agent = RemoteAgent(
        Uri.parse('http://localhost:8787'),
        client: MockClient((_) async {
          if (++turn == 1) return _reply();
          if (turn == 2) {
            return http.Response(
              jsonEncode({
                'sessionId': 'invalid-session',
                'messages': [
                  {
                    'version': 'v0.9',
                    'createSurface': {
                      'surfaceId': 'inline-partial',
                      'catalogId': commerceCatalogId,
                    },
                  },
                  'not an envelope',
                ],
              }),
              200,
            );
          }
          return _reply(inlineId: 'inline-2', createRoom: false);
        }),
      );
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.paris);
      await agent.conversation.sendRequest(ChatMessage.user('More options'));
      expect(agent.latestInlineSurfaceId, 'inline-1');
      expect(
        agent.controller.contextFor('inline-partial').definition.value,
        isNull,
      );
      expect(agent.connectionError, isNotNull);
      await agent.retryLastTurn();
      expect(agent.latestInlineSurfaceId, 'inline-2');
      expect(agent.connectionError, isNull);
    },
  );

  test(
    'incomplete initial surfaces stay retryable without publishing',
    () async {
      for (final variant in [
        'create-only',
        'missing-room',
        'unknown-component',
        'wrong-catalog',
      ]) {
        var calls = 0;
        final agent = RemoteAgent(
          Uri.parse('http://localhost:8787'),
          client: MockClient((_) async {
            if (++calls > 1) return _reply();
            final body = jsonDecode(_reply().body) as Map<String, dynamic>;
            final messages = body['messages'] as List;
            if (variant == 'create-only') {
              messages.removeWhere(
                (m) => (m as Map).containsKey('updateComponents'),
              );
            }
            if (variant == 'missing-room') messages.removeRange(0, 2);
            if (variant == 'unknown-component') {
              messages.last['updateComponents']['components'][0]['component'] =
                  'Unknown';
            }
            if (variant == 'wrong-catalog') {
              messages[0]['createSurface']['catalogId'] = 'unknown';
            }
            return http.Response(jsonEncode(body), 200);
          }),
        );
        await agent.startJourney(DemoJourney.paris);
        expect(agent.canRetry, isTrue, reason: variant);
        expect(agent.latestInlineSurfaceId, isNull);
        expect(agent.hasDressingRoomSurface, isFalse);
        await agent.retryLastTurn();
        expect(agent.connectionError, isNull);
        expect(agent.hasDressingRoomSurface, isTrue);
        agent.dispose();
      }
    },
  );

  test(
    'failed expired action recovery retains reselect notice through retry',
    () async {
      final requests = <Map<String, dynamic>>[];
      final agent = RemoteAgent(
        Uri.parse('http://localhost:8787'),
        client: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (requests.length == 2) return http.Response('{}', 404);
          if (requests.length == 3) return http.Response('{}', 503);
          return _reply();
        }),
      );
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.paris);
      await agent.conversation.sendRequest(
        ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(
              jsonEncode({
                'action': {
                  'name': 'select_product',
                  'context': {'productId': 'p-1'},
                },
              }),
            ),
          ],
        ),
      );
      expect(agent.canRetry, isTrue);
      await agent.retryLastTurn();
      expect(requests, hasLength(4));
      expect(requests[3], requests[2]);
      expect(requests[3].containsKey('action'), isFalse);
      expect(agent.connectionError, isNull);
      expect(agent.connectionNotice, contains('Please select the piece again'));
    },
  );

  testWidgets('keyboard actions are blocked while busy and failed', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    http.Response buttonReply() {
      final body = jsonDecode(
        _reply(inlineId: 'inline-$calls', createRoom: calls == 1).body,
      ) as Map<String, dynamic>;
      (body['messages'] as List).last['updateComponents']['components'] = [
        {
          'id': 'root',
          'component': 'PrimaryButton',
          'label': 'Choose piece',
          'action': {
            'event': {
              'name': 'select_product',
              'context': {'productId': 'p-1'},
            },
          },
        },
      ];
      return http.Response(jsonEncode(body), 200);
    }

    final agent = RemoteAgent(
      Uri.parse('http://localhost:8787'),
      client: MockClient((_) async {
        if (++calls == 2) return pending.future;
        return buttonReply();
      }),
    );
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('Choose piece'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, 2);
    expect(agent.isBusy, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    pending.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await agent.conversation.sendRequest(ChatMessage.user('Accidental action'));
    await tester.pump();
    expect(calls, 2);
    expect(agent.canRetry, isTrue);
    expect(agent.connectionError, isNotNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(agent.connectionError, isNull);
  });

  test('disposing during an agent request ignores its late response', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final agent = RemoteAgent(
      Uri.parse('http://localhost:8787'),
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final turn = agent.startJourney(DemoJourney.paris);
    await started.future;
    agent.dispose();
    response.complete(_reply());
    await turn;
    expect(agent.latestInlineSurfaceId, isNull);
  });
}
