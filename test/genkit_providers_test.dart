import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/genkit_providers.dart';
import 'package:a2ui_flutter_commerce/src/agent/model_settings.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
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
        providerModel: connection.model,
        onBeginTurn: connection.beginTurn,
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
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
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
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
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
    for (final choice in ['auto', 'none']) {
      test(
        '$provider explicit $choice choice retains declared tools',
        () async {
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
            providerModel: connection.model,
            onBeginTurn: connection.beginTurn,
            onCancelTurn: connection.cancelTurn,
            onModelRequest: (request) {
              request.toolChoice = ToolChoice(choice);
            },
          );
          addTearDown(() async {
            connection.dispose();
            await runtime.dispose();
            client.close();
          });
          await runtime.turn({'message': 'Hello'});
          expect(body['tools'], isNotEmpty);
          if (provider == 'googleai') {
            expect(
              body['toolConfig']['functionCallingConfig']['mode'],
              choice.toUpperCase(),
            );
          } else if (provider == 'anthropic') {
            expect(body['tool_choice'], {'type': choice});
          } else {
            expect(body['tool_choice'], choice);
          }
        },
      );
    }

    test(
      '$provider wire preserves forced search, forced presentation and prose choice',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          final declared = body['tools'] as List? ?? [];
          if (declared.isEmpty) {
            expect(body.containsKey('tool_choice'), isFalse);
            expect(body.containsKey('toolConfig'), isFalse);
          }
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
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
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
        runtime.reset();
        await runtime.turn({'message': 'Hello'});
        expect(bodies, hasLength(5));
        if (provider == 'googleai') {
          expect(bodies.last.containsKey('toolConfig'), isFalse);
        } else {
          expect(bodies.last['tool_choice'], isNull);
        }
        if (provider == 'googleai') {
          expect(
            bodies[0]['toolConfig']['functionCallingConfig']['mode'],
            'ANY',
          );
          expect(
            bodies[2]['toolConfig']['functionCallingConfig']['mode'],
            'ANY',
          );
          expect(bodies[3].containsKey('toolConfig'), isFalse);
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
          expect(bodies[3].containsKey('tool_choice'), isFalse);
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
          expect(bodies[3].containsKey('tool_choice'), isFalse);
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

    test('$provider cancellation aborts HTTP and a later turn can succeed', () async {
      final client = _AbortableProviderClient(provider);
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
        providerModel: connection.model,
        onBeginTurn: connection.beginTurn,
        onCancelTurn: connection.cancelTurn,
      );
      addTearDown(() async {
        connection.dispose();
        await runtime.dispose();
        client.close();
      });
      final failed = expectLater(
        runtime.turn({'message': 'Under €100'}),
        throwsA(anything),
      );
      await client.started.future;
      connection.cancelTurn();
      await client.aborted.future;
      await failed;
      expect(runtime.outfit['budget'], isNull);
      expect(client.calls, 1);
      expect(client.closed, isFalse);

      final recovered = await runtime.turn({'message': 'Under €100'});
      expect(recovered['reply'], contains('Ready'));
      expect(client.calls, 2);
      // Per-call SDK cleanup must not close a borrowed client, even for Google.
      expect(client.closed, isFalse);
      connection.dispose();
      expect(
        client.closed,
        isFalse,
        reason: 'Injected clients belong to the caller',
      );
    });

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
            providerModel: connection.model,
            onBeginTurn: connection.beginTurn,
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
    'concurrent Google invocations keep HTTP scopes and keys isolated',
    () async {
      final bothStarted = Completer<void>();
      var started = 0;
      final runtimes = <StylistRuntime>[];
      for (final key in ['connection-a', 'connection-b']) {
        final client = MockClient((request) async {
          expect(request.headers['x-goog-api-key'], key);
          if (++started == 2) bothStarted.complete();
          await bothStarted.future;
          expect(request.body, isNot(contains(key)));
          return providerReply('googleai', text: key);
        });
        final connection = GenkitProvider(
          ModelSettings(provider: 'googleai', model: 'test-model', apiKey: key),
          client: client,
        );
        final runtime = StylistRuntime(
          products: products,
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
        );
        runtimes.add(runtime);
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
          client.close();
        });
      }
      final results = await Future.wait([
        for (final runtime in runtimes) runtime.turn({'message': 'Under €100'}),
      ]);
      expect(results[0]['reply'], contains('connection-a'));
      expect(results[1]['reply'], contains('connection-b'));
      expect(started, 2);
    },
  );

  for (final reason in ['length', 'content_filter', 'unknown']) {
    test(
      'OpenAI $reason tool response is not normalized into success',
      () async {
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          final body = jsonDecode(
            providerToolReply('openai', 'search_products', {
              'query': 'dress',
            }).body,
          ) as Map<String, dynamic>;
          body['choices'][0]['finish_reason'] = reason;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final connection = GenkitProvider(
          ModelSettings(
            provider: 'openai',
            model: 'test-model',
            apiKey: 'test-key',
          ),
          client: client,
        );
        final runtime = StylistRuntime(
          products: products,
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
        );
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
          client.close();
        });
        await expectLater(
          runtime.turn({'message': 'Dress under €100'}),
          throwsA(anything),
        );
        expect(calls, 1);
        expect(runtime.outfit['budget'], isNull);
      },
    );
  }

  test(
    'a retired allowance response cannot contaminate the next turn',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final connection = GenkitProvider(
        ModelSettings(
          provider: 'openai-compatible',
          model: 'test-model',
          apiKey: 'private-test-key',
          baseUrl: 'http://127.0.0.1:8788/v1',
        ),
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final runtime = StylistRuntime(
        products: products,
        providerModel: connection.model,
        onBeginTurn: connection.beginTurn,
        onCancelTurn: connection.cancelTurn,
      );
      addTearDown(() async {
        connection.dispose();
        await runtime.dispose();
      });
      final failure = expectLater(
        runtime.turn({'message': 'Under €100'}),
        throwsA(anything),
      );
      await started.future;
      connection.cancelTurn();
      connection.beginTurn();
      response.complete(
        http.Response(
          '{}',
          429,
          headers: {'x-alder-demo-error': 'allowance_exhausted'},
        ),
      );
      await failure;
      expect(connection.failureMessage, isNull);
    },
  );

  for (final scenario in ['local-cap', 'provider-limit', 'remote-header']) {
    test(
      'demo allowance hint is restricted to local bridge: $scenario',
      () async {
        final connection = GenkitProvider(
          ModelSettings(
            provider: 'openai-compatible',
            model: 'test-model',
            apiKey: 'private-test-key',
            baseUrl: scenario == 'remote-header'
                ? 'https://compatible.example/v1'
                : 'http://127.0.0.1:8788/v1',
          ),
          client: MockClient(
            (request) async => http.Response(
              'private-test-key must never appear',
              429,
              headers: scenario == 'provider-limit'
                  ? {}
                  : {'x-alder-demo-error': 'allowance_exhausted'},
            ),
          ),
        );
        final runtime = StylistRuntime(
          products: products,
          providerModel: connection.model,
          onBeginTurn: connection.beginTurn,
          onCancelTurn: connection.cancelTurn,
        );
        addTearDown(() async {
          connection.dispose();
          await runtime.dispose();
        });
        await expectLater(
          runtime.turn({'message': 'Under €100'}),
          throwsA(anything),
        );
        expect(
          connection.failureMessage,
          scenario == 'local-cap' ? contains('request allowance') : isNull,
        );
        connection.beginTurn();
        expect(connection.failureMessage, isNull);
      },
    );
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

/// Emulates an HTTP implementation that honours AbortableRequest, without a socket.
class _AbortableProviderClient extends http.BaseClient {
  _AbortableProviderClient(this.provider);
  final String provider;
  final started = Completer<void>();
  final aborted = Completer<void>();
  var calls = 0;
  var closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(closed, isFalse);
    await request.finalize().drain<void>();
    if (++calls == 1) {
      expect(request, isA<http.AbortableRequest>());
      final abort = (request as http.AbortableRequest).abortTrigger;
      expect(abort, isNotNull);
      started.complete();
      await abort;
      aborted.complete();
      throw http.RequestAbortedException(request.url);
    }
    final response = providerReply(provider);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      200,
      headers: response.headers,
    );
  }

  @override
  void close() => closed = true;
}
