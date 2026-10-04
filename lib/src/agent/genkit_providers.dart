import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart' show GenkitPlugin;
// These pinned plugins expose HTTP injection on their implementation classes,
// but not yet on their public factory handles. Keep that preview API here.
// ignore: implementation_imports
import 'package:genkit_anthropic/src/plugin_impl.dart';
// ignore: implementation_imports
import 'package:genkit_google_genai/src/google_api_client.dart';
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
    plugin = switch (settings.provider) {
      'googleai' => GoogleGenAiPluginImpl(
        apiKey: placeholder,
        httpClient: _transport,
      ),
      'anthropic' => AnthropicPluginImpl(
        apiKey: placeholder,
        httpClient: _transport,
      ),
      _ => openAI(
        apiKey: placeholder,
        baseUrl: settings.provider == 'openai-compatible'
            ? settings.baseUrl
            : null,
        httpClient: _transport,
      ),
    };
    model = modelRef(
      '${switch (settings.provider) {
        'googleai' => 'googleai',
        'anthropic' => 'anthropic',
        _ => 'openai',
      }}/${settings.model}',
    );
  }

  final ModelSettings settings;
  final _CredentialTransport _transport;
  late final GenkitPlugin plugin;
  late final ModelRef model;

  void beginTurn() => _transport.beginTurn();
  void cancelTurn() => _transport.cancelTurn();
  ModelResponse normalizeResponse(ModelResponse response) {
    // genkit_openai 0.5.0 maps the SDK's camel-case enum name, whereas its
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
    // The same pinned plugin instance owns the injected SDK client.
    // ignore: invalid_use_of_visible_for_testing_member
    if (plugin case final AnthropicPluginImpl anthropic) anthropic.close();
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
  void beginTurn() {
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
          ..bodyBytes = bytes;
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
      if (settings.provider == 'openai') {
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        body['store'] = false;
        forwarded.body = jsonEncode(body);
      }
    }
    try {
      final response = await inner
          .send(forwarded)
          .timeout(const Duration(seconds: 60));
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
