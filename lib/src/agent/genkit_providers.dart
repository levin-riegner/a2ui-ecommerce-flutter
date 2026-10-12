import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;

import 'model_settings.dart';

class GenkitProvider {
  GenkitProvider(this.settings, {http.Client? client})
    : _transport = _CredentialTransport(
        settings,
        client ?? http.Client(),
        client == null,
      ) {
    const placeholder = 'byok-runtime-key';
    final plugin = switch (settings.provider) {
      'googleai' => googleAI(apiKey: placeholder),
      'anthropic' => anthropic(apiKey: placeholder, httpClient: _transport),
      _ => openAI(
        apiKey: placeholder,
        baseUrl: settings.provider == 'openai-compatible'
            ? settings.baseUrl
            : null,
        httpClient: _transport,
      ),
    };
    // Resolve through Genkit's public plugin API; setup performs no HTTP.
    final providerModel = plugin.model(settings.model);
    model = Model(
      name: providerModel.name,
      customOptions: providerModel.customOptions,
      fn: (request, context) {
        if (settings.provider == 'openai' && settings.model == 'gpt-6-luna') {
          // This model supports Chat Completions tools without reasoning.
          // Use the plugin's public options rather than patching its wire JSON.
          request = ModelRequest.fromJson(request.toJson())
            ..config = {
              ...?request.config,
              ...OpenAIChatOptions(reasoningEffort: 'none').toJson(),
            };
        }
        Future<ModelResponse> invoke() async => _normalizeResponse(
          await providerModel(
            request,
            cancel: context.cancel,
            context: context.context,
            onChunk: context.streamingRequested ? context.sendChunk : null,
          ),
        );

        // Google 1.0 has no public httpClient argument. Scope the documented
        // package:http client factory to this invocation, including its async
        // work, rather than importing the plugin's test-only implementation.
        // Each borrowed client can be closed by the plugin without closing the
        // connection-owned transport. No Flutter callbacks depend on this Zone.
        return settings.provider == 'googleai'
            ? http.runWithClient(invoke, () => _BorrowedClient(_transport))
            : invoke();
      },
    );
  }

  final ModelSettings settings;
  final _CredentialTransport _transport;
  late final Model model;

  String? get failureMessage => _transport.failureMessage;

  void beginTurn() => _transport.beginTurn();
  void cancelTurn() => _transport.cancelTurn();
  ModelResponse _normalizeResponse(ModelResponse response) {
    // genkit_openai 1.0.0 still maps the SDK's camel-case enum name, whereas its
    // converter expects the wire value "tool_calls". Accept only that explicit
    // finish reason with real tool requests; truncated output stays rejected.
    if ((settings.provider == 'openai' ||
            settings.provider == 'openai-compatible') &&
        response.finishReason == FinishReason.unknown &&
        response.message?.content.any((part) => part.isToolRequest) == true &&
        response.raw is Map) {
      final choices = (response.raw as Map)['choices'];
      if (choices is List &&
          choices.isNotEmpty &&
          (choices.first as Map)['finish_reason'] == 'tool_calls') {
        return ModelResponse.fromJson({
          ...response.toJson(),
          'finishReason': 'stop',
        });
      }
    }
    return response;
  }

  void dispose() {
    settings.clear();
    _transport.close();
  }
}

/// Actual credentials enter HTTP only; Genkit inputs/config/traces see a placeholder.
class _CredentialTransport extends http.BaseClient {
  _CredentialTransport(this.settings, this.inner, this.ownsClient);
  final ModelSettings settings;
  final http.Client inner;
  final bool ownsClient;
  bool _closed = false;
  bool _cancelled = false;
  int _requests = 0;
  int _epoch = 0;
  Completer<void> _abort = Completer<void>();
  String? failureMessage;

  void beginTurn() {
    failureMessage = null;
    _epoch++;
    _abort = Completer<void>();
    _requests = 0;
    _cancelled = false;
  }

  void cancelTurn() {
    _cancelled = true;
    if (!_abort.isCompleted) _abort.complete();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed || _cancelled || settings.apiKey.isEmpty || ++_requests > 4) {
      throw StateError('Model request unavailable');
    }
    final epoch = _epoch;
    final expected = switch (settings.provider) {
      'googleai' => Uri.parse('https://generativelanguage.googleapis.com/'),
      'anthropic' => Uri.parse('https://api.anthropic.com/v1/'),
      'openai-compatible' => providerApiUrl(settings.baseUrl!)!,
      _ => Uri.parse('https://api.openai.com/v1/'),
    };
    if (request.method != 'POST' ||
        request.url.origin != expected.origin ||
        !request.url.path.startsWith(
          expected.path.endsWith('/') ? expected.path : '${expected.path}/',
        )) {
      throw StateError('Unexpected provider destination');
    }
    final bytes = await request.finalize().toBytes();
    final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (settings.provider == 'openai') {
      body['store'] = false;
    }
    final query = Map<String, String>.from(request.url.queryParameters)
      ..remove('key');
    final forwarded =
        http.AbortableRequest(
            request.method,
            query.isEmpty
                ? Uri.parse(request.url.toString().split('?').first)
                : request.url.replace(queryParameters: query),
            abortTrigger: _abort.future,
          )
          ..followRedirects = false
          ..headers.addAll(request.headers)
          ..body = jsonEncode(body);
    forwarded.headers.remove('authorization');
    forwarded.headers.remove('x-api-key');
    forwarded.headers.remove('x-goog-api-key');
    if (settings.provider == 'anthropic') {
      forwarded.headers['x-api-key'] = settings.apiKey;
      forwarded.headers['anthropic-dangerous-direct-browser-access'] = 'true';
    } else if (settings.provider == 'googleai') {
      forwarded.headers['x-goog-api-key'] = settings.apiKey;
    } else {
      forwarded.headers['authorization'] = 'Bearer ${settings.apiKey}';
    }
    try {
      final response = await inner
          .send(forwarded)
          .timeout(const Duration(seconds: 60));
      if (!_closed &&
          !_cancelled &&
          epoch == _epoch &&
          settings.provider == 'openai-compatible' &&
          const {'127.0.0.1', 'localhost', '::1'}.contains(expected.host) &&
          response.statusCode == 429 &&
          response.headers['x-alder-demo-error'] == 'allowance_exhausted') {
        failureMessage = 'This demo has reached its request allowance. Start a new demo session to continue.';
      }
      if (_closed ||
          _cancelled ||
          epoch != _epoch ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw StateError('Model provider request failed');
      }
      return response;
    } catch (_) {
      // Provider bodies, request URLs, and credentials never enter SDK errors or traces.
      throw StateError('Model provider request failed');
    }
  }

  @override
  void close() {
    _closed = true;
    cancelTurn();
    if (ownsClient) inner.close();
  }
}

/// A plugin may close its per-request client; the connection owns the transport.
class _BorrowedClient extends http.BaseClient {
  _BorrowedClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {}
}
