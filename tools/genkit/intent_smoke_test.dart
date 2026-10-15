import 'package:a2ui_flutter_commerce/src/agent/stylist_result.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_presenter.dart';

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/genkit_providers.dart';
import 'package:a2ui_flutter_commerce/src/agent/model_settings.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Explicit opt-in; three interactions and at most eight paid requests.
/// Run: STYLIST_LIVE_TEST=1 fvm flutter test tools/genkit/intent_smoke_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('live agent separates questions from outfit requests', () async {
    if (Platform.environment['STYLIST_LIVE_TEST'] != '1') {
      fail('Set STYLIST_LIVE_TEST=1 to authorize this paid test.');
    }
    final settings = <String, String>{};
    final file = File('.env.local');
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final index = line.indexOf('=');
        if (index < 1 || line.trimLeft().startsWith('#')) continue;
        settings[line.substring(0, index).trim()] = line
            .substring(index + 1)
            .trim()
            .replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      }
    }
    settings.addAll(Platform.environment);
    final key = settings['OPENAI_API_KEY'] ?? '';
    final model = settings['OPENAI_MODEL'] ?? '';
    if (key.isEmpty || model.isEmpty) {
      fail(
        'Configure OPENAI_API_KEY and OPENAI_MODEL in .env.local or the environment.',
      );
    }
    final client = HttpOverrides.runWithHttpOverrides(
      () => _BoundedClient(IOClient(HttpClient())),
      _LiveHttpOverrides(),
    );
    final connection = GenkitProvider(
      ModelSettings(provider: 'openai', model: model, apiKey: key),
      client: client,
    );
    final runtime = StylistRuntime(
      products: parseCatalogProducts(
        await rootBundle.loadString('assets/data/catalog/products.csv'),
      ),
      providerModel: connection.model,
      onBeginTurn: connection.beginTurn,
      onCancelTurn: connection.cancelTurn,
    );
    addTearDown(() async {
      connection.dispose();
      await runtime.dispose();
      client.close();
      stdout.writeln(
        jsonEncode({
          'model': model,
          'providerRequests': client.requests,
          'tools': client.tools,
          'usage': client.usage,
        }),
      );
    });

    void report(String stage, Map<String, dynamic> result) => stdout.writeln(
      jsonEncode({
        'stage': stage,
        'intent': result['intent'],
        'brief': result['brief'],
        'reply': result['reply'],
        'productCount': (result['products'] as List).length,
      }),
    );
    bool hasIntakeControls(StylistTurnResult result) =>
        (presentStylistResult(result)['messages'] as List)
            .where(
              (m) =>
                  m['updateComponents']?['surfaceId'].toString().startsWith(
                    'inline-',
                  ) ==
                  true,
            )
            .expand((m) => m['updateComponents']['components'] as List)
            .any(
              (c) => const [
                'ChoiceGroup',
                'BudgetSlider',
                'PrimaryButton',
              ].contains(c['component']),
            );

    final question = await runtime.turn({'message': 'What can we do here?'});
    report('capability_question', question);
    expect(question['intent'], 'capabilities');
    expect(question['brief'], isEmpty);
    expect(question['products'], isEmpty);
    expect(hasIntakeControls(question), isFalse);
    expect(question['reply'], isNot(contains('occasion:')));
    expect(
      '?'.allMatches(question['reply'] as String).length,
      lessThanOrEqualTo(1),
    );

    final outfit = await runtime.turn({
      'message': 'A casual summer outfit for my graduation. My budget is €500. No wool.',
    });
    report('outfit_request', outfit);
    expect(outfit['brief']['occasion'], contains('graduation'));
    expect(outfit['brief']['budget'], 500);
    expect(outfit['brief']['dressCode'], 'casual');
    expect(outfit['constraints']['excludedMaterials'], contains('wool'));
    expect(outfit['products'], isNotEmpty);
    final before = Map.of(runtime.outfit);

    final advice = await runtime.turn({
      'message': 'What does smart casual mean?',
    });
    report('styling_question', advice);
    expect(advice['intent'], 'styling_advice');
    expect(advice['brief'], outfit['brief']);
    expect(runtime.outfit, before);
    expect(advice['products'], isEmpty);
    expect(hasIntakeControls(advice), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _LiveHttpOverrides extends HttpOverrides {}

class _BoundedClient extends http.BaseClient {
  _BoundedClient(this.inner);
  final http.Client inner;
  int requests = 0;
  final tools = <String>[];
  final usage = <Map<String, Object?>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (requests >= 8) throw StateError('Intent smoke-test allowance reached.');
    requests++;
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(bytes)) as Map;
      for (final choice in (body['choices'] as List?) ?? []) {
        for (final call in (choice['message']['tool_calls'] as List?) ?? []) {
          tools.add(call['function']['name'] as String);
        }
      }
      final tokens = body['usage'] as Map?;
      if (tokens != null) {
        usage.add({
          for (final field in [
            'prompt_tokens',
            'completion_tokens',
            'total_tokens',
          ])
            if (tokens[field] is num) field: tokens[field],
        });
      }
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => inner.close();
}
