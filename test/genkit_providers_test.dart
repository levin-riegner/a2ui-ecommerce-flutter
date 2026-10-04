import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/genkit_providers.dart';
import 'package:a2ui_flutter_commerce/src/agent/model_settings.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'stylist_runtime_test.dart' show products;

http.Response providerReply(String provider, {String text = 'Ready'}) =>
    http.Response(
      jsonEncode(switch (provider) {
        'anthropic' => {
          'id': 'msg_test',
          'type': 'message',
          'role': 'assistant',
          'model': 'test-model',
          'content': [
            {'type': 'text', 'text': text},
          ],
          'stop_reason': 'end_turn',
          'stop_sequence': null,
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
        'googleai' => {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': text},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 1,
            'candidatesTokenCount': 1,
            'totalTokenCount': 2,
          },
        },
        _ => {
          'id': 'chat_test',
          'object': 'chat.completion',
          'created': 1,
          'model': 'test-model',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': text},
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 1,
            'completion_tokens': 1,
            'total_tokens': 2,
          },
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Response providerToolReply(
  String provider,
  String name,
  Map<String, dynamic> input,
) {
  final body = jsonDecode(providerReply(provider).body) as Map<String, dynamic>;
  if (provider == 'anthropic') {
    body['content'] = [
      {'type': 'tool_use', 'id': 'tool-$name', 'name': name, 'input': input},
    ];
    body['stop_reason'] = 'tool_use';
  } else if (provider == 'googleai') {
    body['candidates'][0]['content']['parts'] = [
      {
        'functionCall': {'name': name, 'args': input},
      },
    ];
  } else {
    body['choices'][0]['message'] = {
      'role': 'assistant',
      'content': null,
      'tool_calls': [
        {
          'id': 'tool-$name',
          'type': 'function',
          'function': {'name': name, 'arguments': jsonEncode(input)},
        },
      ],
    };
    body['choices'][0]['finish_reason'] = 'tool_calls';
  }
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  test(
    'OpenAI Luna disables reasoning for Chat Completions tool calls',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], 'gpt-6-luna');
        expect(body['reasoning_effort'], 'none');
        expect(body['store'], false);
        switch (requests.length) {
          case 1:
            return providerToolReply('openai', 'search_products', {
              'query': 'dress',
            });
          case 2:
            return providerToolReply('openai', 'present_products', {
              'productIds': ['dress-1'],
            });
          default:
            return providerReply('openai');
        }
      });
      final connection = GenkitProvider(
        ModelSettings(
          provider: 'openai',
          model: 'gpt-6-luna',
          apiKey: 'test-key',
        ),
        client: client,
      );
      final runtime = StylistRuntime(
        products: products,
        plugins: [connection.plugin],
        providerModel: connection.model,
        normalizeResponse: connection.normalizeResponse,
        onBeginTurn: connection.beginTurn,
        onModelRequest: connection.prepareRequest,
        onCancelTurn: connection.cancelTurn,
      );
      addTearDown(() async {
        connection.dispose();
        await runtime.dispose();
        client.close();
      });
      final result = await runtime.turn({'message': 'A dress under €100'});
      expect(result['products'].single['id'], 'dress-1');
      expect(requests, hasLength(3));
    },
  );

  for (final provider in ModelSettings.providers) {
    test(
      '$provider official Genkit plugin calls provider directly with an isolated key',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return providerReply(provider);
        });
        final settings = ModelSettings(
          provider: provider,
          model: 'test-model',
          apiKey: 'private-test-key',
          baseUrl: provider == 'openai-compatible'
              ? 'https://compatible.example/v1'
              : null,
        );
        final connection = GenkitProvider(settings, client: client);
        final runtime = StylistRuntime(
          products: products,
          plugins: [connection.plugin],
          providerModel: connection.model,
          normalizeResponse: connection.normalizeResponse,
          onBeginTurn: connection.beginTurn,
          onModelRequest: connection.prepareRequest,
          onCancelTurn: connection.cancelTurn,
        );
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
          client.close();
        });
        expect(requests, isEmpty);
        final result = await runtime.turn({'message': 'Under €100'});
        expect(result['reply'], contains('Ready'));
        expect(requests, hasLength(1));
        final request = requests.single;
        final body = jsonDecode(request.body) as Map;
        if (provider == 'googleai') {
          expect(body.containsKey('toolConfig'), isFalse);
        } else {
          expect(body['tool_choice'], isNull);
        }
        expect(request.body, isNot(contains('private-test-key')));
        expect(request.url.toString(), isNot(contains('private-test-key')));
        expect(request.followRedirects, isFalse);
        if (provider == 'googleai') {
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(request.headers['x-goog-api-key'], 'private-test-key');
        } else if (provider == 'anthropic') {
          expect(
            request.url.toString(),
            'https://api.anthropic.com/v1/messages',
          );
          expect(request.headers['x-api-key'], 'private-test-key');
        } else {
          expect(
            request.url.toString(),
            provider == 'openai-compatible'
                ? 'https://compatible.example/v1/chat/completions'
                : 'https://api.openai.com/v1/chat/completions',
          );
          expect(request.headers['authorization'], 'Bearer private-test-key');
          if (provider == 'openai') {
            expect(jsonDecode(request.body)['store'], false);
            expect(
              jsonDecode(request.body).containsKey('reasoning_effort'),
              false,
            );
          }
        }
        connection.dispose();
        expect(settings.apiKey, isEmpty);
        await expectLater(
          runtime.turn({'message': 'Another look'}),
          throwsA(anything),
        );
        expect(requests, hasLength(1));
      },
    );

    test(
      '$provider native tool wire format searches, presents, selects and removes products',
      () async {
        var round = 0;
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          switch (++round % 3) {
            case 1:
              return providerToolReply(provider, 'search_products', {
                'query': requests.length <= 3 || requests.length > 6
                    ? 'dress'
                    : 'shoes',
                'limit': 1,
              });
            case 2:
              return providerToolReply(provider, 'present_products', {
                'productIds': [
                  requests.length <= 3 || requests.length > 6
                      ? 'dress-1'
                      : 'shoes-1',
                ],
              });
            default:
              return providerReply(provider);
          }
        });
        final connection = GenkitProvider(
          ModelSettings(
            provider: provider,
            model: 'test-model',
            apiKey: 'private-test-key',
            baseUrl: provider == 'openai-compatible'
                ? 'https://compatible.example/v1'
                : null,
          ),
          client: client,
        );
        final runtime = StylistRuntime(
          products: products,
          plugins: [connection.plugin],
          providerModel: connection.model,
          normalizeResponse: connection.normalizeResponse,
          onBeginTurn: connection.beginTurn,
          onModelRequest: connection.prepareRequest,
          onCancelTurn: connection.cancelTurn,
        );
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
          client.close();
        });
        final result = await runtime.turn({'message': 'A dress under €200'});
        expect(result['products'].single['name'], 'Linen dress');
        expect(requests[1].body, contains('image_asset'));
        expect(requests[1].body, contains('price_eur'));
        await runtime.turn({
          'action': {
            'name': 'select_product',
            'context': {'productId': 'dress-1'},
          },
        });
        expect(runtime.outfit['items'], {'dress': 'dress-1'});
        await runtime.turn({
          'action': {
            'name': 'remove_product',
            'context': {'productId': 'dress-1'},
          },
        });
        expect(runtime.outfit['items'], isEmpty);
        expect(requests, hasLength(9));
        expect(
          requests.every((r) => !r.body.contains('private-test-key')),
          isTrue,
        );
      },
    );
    test('$provider optional auto choice reaches the wire unchanged', () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return providerReply(provider);
      });
      final connection = GenkitProvider(
        ModelSettings(
          provider: provider,
          model: 'test-model',
          apiKey: 'private-test-key',
          baseUrl: provider == 'openai-compatible'
              ? 'https://compatible.example/v1'
              : null,
        ),
        client: client,
      );
      final runtime = StylistRuntime(
        products: products,
        plugins: [connection.plugin],
        providerModel: connection.model,
        normalizeResponse: connection.normalizeResponse,
        onBeginTurn: connection.beginTurn,
        onCancelTurn: connection.cancelTurn,
        onModelRequest: (request) {
          request.toolChoice = 'auto';
          connection.prepareRequest(request);
        },
      );
      addTearDown(() async {
        connection.dispose();
        await runtime.dispose();
        client.close();
      });
      await runtime.turn({'message': 'Hello'});
      if (provider == 'googleai') {
        expect(body['toolConfig']['functionCallingConfig']['mode'], 'AUTO');
      } else if (provider == 'anthropic') {
        expect(body['tool_choice'], {'type': 'auto'});
      } else {
        expect(body['tool_choice'], 'auto');
      }
    });

    test(
      '$provider wire preserves forced search, forced presentation and prose choice',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          switch (bodies.length) {
            case 1:
            case 2:
              return providerToolReply(provider, 'search_products', {
                'query': 'dress',
              });
            case 3:
              return providerToolReply(provider, 'present_products', {
                'productIds': ['dress-1'],
              });
            default:
              return providerReply(provider);
          }
        });
        final connection = GenkitProvider(
          ModelSettings(
            provider: provider,
            model: 'test-model',
            apiKey: 'private-test-key',
            baseUrl: provider == 'openai-compatible'
                ? 'https://compatible.example/v1'
                : null,
          ),
          client: client,
        );
        final runtime = StylistRuntime(
          products: products,
          plugins: [connection.plugin],
          providerModel: connection.model,
          normalizeResponse: connection.normalizeResponse,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
          onModelRequest: connection.prepareRequest,
        );
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
          client.close();
        });
        runtime.reset(journey: DemoJourney.paris);
        final result = await runtime.turn({
          'message': '${DemoJourney.paris.title}. ${DemoJourney.paris.brief}',
        });
        expect(result['products'], isNotEmpty);
        expect(bodies, hasLength(4));
        if (provider == 'googleai') {
          expect(
            bodies[0]['toolConfig']['functionCallingConfig']['mode'],
            'ANY',
          );
          expect(
            bodies[2]['toolConfig']['functionCallingConfig']['mode'],
            'ANY',
          );
          expect(
            bodies[3]['toolConfig']['functionCallingConfig']['mode'],
            'NONE',
          );
          expect(
            (bodies[0]['tools'] as List)
                .single['functionDeclarations']
                .single['name'],
            'search_products',
          );
          expect(
            (bodies[2]['tools'] as List)
                .single['functionDeclarations']
                .single['name'],
            'present_products',
          );
        } else if (provider == 'anthropic') {
          expect(bodies[0]['tool_choice'], {'type': 'any'});
          expect(bodies[2]['tool_choice'], {'type': 'any'});
          expect(bodies[3]['tool_choice'], {'type': 'none'});
          expect(
            (bodies[0]['tools'] as List).single['name'],
            'search_products',
          );
          expect(
            (bodies[2]['tools'] as List).single['name'],
            'present_products',
          );
        } else {
          expect(bodies[0]['tool_choice'], 'required');
          expect(bodies[2]['tool_choice'], 'required');
          expect(bodies[3]['tool_choice'], 'none');
          expect(
            (bodies[0]['tools'] as List).single['function']['name'],
            'search_products',
          );
          expect(
            (bodies[2]['tools'] as List).single['function']['name'],
            'present_products',
          );
        }
        expect(
          bodies.every(
            (body) => !jsonEncode(body).contains('private-test-key'),
          ),
          isTrue,
        );
      },
    );

    for (final status in [401, 429, 500, 302]) {
      test(
        '$provider provider status $status is sanitized and never retried',
        () async {
          var calls = 0;
          final client = MockClient((request) async {
            calls++;
            return http.Response(
              'private-test-key provider error',
              status,
              headers: {'location': 'https://other.example/'},
            );
          });
          final connection = GenkitProvider(
            ModelSettings(
              provider: provider,
              model: 'test-model',
              apiKey: 'private-test-key',
              baseUrl: provider == 'openai-compatible'
                  ? 'https://compatible.example/v1'
                  : null,
            ),
            client: client,
          );
          final runtime = StylistRuntime(
            products: products,
            plugins: [connection.plugin],
            providerModel: connection.model,
            normalizeResponse: connection.normalizeResponse,
            onBeginTurn: connection.beginTurn,
            onModelRequest: connection.prepareRequest,
            onCancelTurn: connection.cancelTurn,
          );
          addTearDown(() async {
            connection.dispose();
            await runtime.dispose();
            client.close();
          });
          try {
            await runtime.turn({'message': 'Under €100'});
            fail('Should fail');
          } catch (error) {
            expect(error.toString(), isNot(contains('private-test-key')));
          }
          expect(calls, 1);
          expect(runtime.outfit['budget'], isNull);
        },
      );
    }
  }

  test(
    'compatible destinations reject insecure hosts and embedded credentials',
    () {
      for (final value in [
        'http://remote.example/v1',
        'https://key@host.test/v1',
        'https://host.test/v1?key=secret',
        'https://host.test/v1#secret',
        'file:///tmp',
      ]) {
        expect(providerApiUrl(value), isNull);
      }
      for (final value in [
        'https://host.test/v1',
        'http://localhost:11434/v1',
        'http://127.0.0.1:11434/v1',
        'http://10.0.2.2:11434/v1',
      ]) {
        expect(providerApiUrl(value), isNotNull);
      }
    },
  );

  test('model settings validate required fields and never stringify a key', () {
    expect(
      () => ModelSettings(provider: 'bad', model: 'model', apiKey: 'key'),
      throwsFormatException,
    );
    expect(
      () => ModelSettings(provider: 'openai', model: '', apiKey: 'key'),
      throwsFormatException,
    );
    expect(
      () => ModelSettings(
        provider: 'openai',
        model: 'model',
        apiKey: 'key\nheader',
      ),
      throwsFormatException,
    );
    expect(
      ModelSettings(
        provider: 'openai',
        model: 'model',
        apiKey: 'secret',
      ).toString(),
      isNot(contains('secret')),
    );
  });
}
