import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_providers.dart';
import 'package:a2ui_flutter_commerce/src/agent/model_settings.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Explicit opt-in only; outside the normal test directory and CI.
/// Default: three real interactions, at most twelve provider requests.
/// STYLIST_LIVE_SEED_PREVIEW=1 scripts only the initial preview turn; later
/// interactions use the registered provider model. This mode tests continuation,
/// and must never be reported as an entirely live journey.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('live Berlin journey advances after selection and reopens removal', () async {
    if (Platform.environment['STYLIST_LIVE_TEST'] != '1') {
      fail('Set STYLIST_LIVE_TEST=1 to authorize this paid smoke test.');
    }
    final settings = <String, String>{};
    final file = File('.env.local');
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final index = line.indexOf('=');
        if (index < 1 || line.trimLeft().startsWith('#')) continue;
        var value = line.substring(index + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        settings[line.substring(0, index).trim()] = value;
      }
    }
    settings.addAll(Platform.environment);
    final key = settings['OPENAI_API_KEY'] ?? '';
    final model = settings['OPENAI_MODEL'] ?? '';
    if (key.isEmpty || model.isEmpty) {
      fail(
        'Provide OPENAI_API_KEY and OPENAI_MODEL in .env.local or the environment.',
      );
    }
    final seededPreview =
        Platform.environment['STYLIST_LIVE_SEED_PREVIEW'] == '1';
    final testRemoval =
        Platform.environment['STYLIST_LIVE_INTERACTIONS'] != '2';
    // The binding normally blocks HTTP. Only this opted-in client bypasses it.
    final client = HttpOverrides.runWithHttpOverrides(
      () => _ProbeClient(IOClient(HttpClient())),
      _LiveHttpOverrides(),
    );
    addTearDown(client.close);
    addTearDown(() {
      stdout.writeln(
        jsonEncode({
          'model': model,
          'initialPreviewSeeded': seededPreview,
          'providerRequests': client.requests,
          'requestLimit': client.requestLimit,
          'tools': client.tools,
          'usage': client.usage,
        }),
      );
    });
    final catalog = parseCatalogProducts(
      await rootBundle.loadString('assets/data/catalog/products.csv'),
    );
    GenkitAgent connected;
    var usePreviewModel = seededPreview;
    if (seededPreview) {
      final connection = GenkitProvider(
        ModelSettings(provider: 'openai', model: model, apiKey: key),
        client: client,
      );
      late final StylistRuntime runtime;
      runtime = StylistRuntime(
        products: catalog,
        plugins: [connection.plugin],
        model: (request) async {
          if (usePreviewModel) return offlineStylistModel(request);
          final action = await runtime.ai.registry.lookupAction(
            g.ActionType.model,
            connection.model.name,
          ) as g.Model?;
          if (action == null) throw StateError('Provider model unavailable');
          return action(request);
        },
        normalizeResponse: connection.normalizeResponse,
        onBeginTurn: connection.beginTurn,
        onModelRequest: connection.prepareRequest,
        onCancelTurn: connection.cancelTurn,
      );
      connected = GenkitAgent(runtime, provider: connection);
    } else {
      connected = await GenkitAgent.connect(
        provider: 'openai',
        model: model,
        apiKey: key,
        client: client,
      );
    }
    addTearDown(() async {
      await connected.disconnect();
      connected.dispose();
    });
    expect(client.requests, 0, reason: 'Setup must make no paid request.');
    Product productFor(String id) => catalog.singleWhere((p) => p.id == id);
    List<Map> recommendationRows() =>
        (connected.controller
                    .contextFor(connected.latestInlineSurfaceId!)
                    .dataModel
                    .getValue<List<Object?>>(DataPath('/recommendations')) ??
                [])
            .cast<Map>();
    List<String> recommendationIds() =>
        recommendationRows().map((card) => card['id'] as String).toList();
    void expectOptionsFor(ProductCategory category) {
      final rows = recommendationRows();
      expect(
        rows,
        isNotEmpty,
        reason: 'The conversation must offer its next step.',
      );
      for (final row in rows) {
        final product = productFor(row['id'] as String);
        expect(product.category, category);
        expect(row['name'], product.name);
        expect(row['imageAsset'], product.imageAsset);
        expect(product.imageAsset, startsWith('assets/images/products/'));
        expect(
          File(product.imageAsset).existsSync(),
          isTrue,
          reason: 'Recommendations must reference a bundled catalog photo.',
        );
      }
    }

    List<Map> dressingSlots() => connected.controller
        .contextFor('dressing-room')
        .dataModel
        .getValue<List<Object?>>(DataPath('/slots'))!
        .cast<Map>();
    void expectNext(ProductCategory category) => expect(
      dressingSlots()
          .where((slot) => slot['state'] == 'Next')
          .map((slot) => slot['category']),
      [category.name],
    );
    String? inlineMessage() => connected.controller
        .contextFor(connected.latestInlineSurfaceId!)
        .dataModel
        .getValue<String>(DataPath('/message'));

    await connected.startJourney(DemoJourney.berlin);
    stdout.writeln(
      jsonEncode({
        'stage': 'initial',
        'requests': client.requests,
        'scriptedPreview': seededPreview,
      }),
    );
    expect(connected.connectionError, isNull);
    expect(connected.latestInlineSurfaceId, 'inline-1');
    expectOptionsFor(ProductCategory.top);
    expectNext(ProductCategory.top);
    if (seededPreview) {
      expect(
        client.requests,
        0,
        reason: 'Seed preview must make no paid request.',
      );
    } else {
      expect(
        client.tools,
        containsAll(['search_products', 'present_products']),
      );
    }
    usePreviewModel = false;
    final id = recommendationIds().first;
    final selectedProduct = productFor(id);
    Future<void> interact(String action) => connected.conversation.sendRequest(
      ChatMessage.user(
        '',
        parts: [
          UiInteractionPart.create(
            jsonEncode({
              'action': {
                'name': action,
                'context': {'productId': id},
              },
            }),
          ),
        ],
      ),
    );
    final requestsBeforeSelection = client.requests;
    await interact('select_product');
    stdout.writeln(
      jsonEncode({'stage': 'selection', 'requests': client.requests}),
    );
    expect(connected.connectionError, isNull);
    expect(
      client.requests,
      greaterThan(requestsBeforeSelection),
      reason: 'Selection continuation must use the real provider, including seed mode.',
    );
    expect(client.tools, containsAll(['search_products', 'present_products']));
    expect(connected.latestInlineSurfaceId, 'inline-2');
    final selected = connected.controller
        .contextFor('selected-products')
        .dataModel;
    expect(selected.getValue<String>(DataPath('/products/0/id')), id);
    final dressing = connected.controller.contextFor('dressing-room').dataModel;
    expect(dressing.getValue<String>(DataPath('/spent')), contains('1 pieces'));
    expectOptionsFor(ProductCategory.bottom);
    expectNext(ProductCategory.bottom);
    expect(recommendationIds(), isNot(contains(id)));
    expect(
      dressing.getValue<String>(DataPath('/left')),
      '€${(900 - selectedProduct.price).toStringAsFixed(2)} left',
    );
    final filled = dressingSlots().singleWhere(
      (slot) => slot['category'] == 'top',
    );
    expect(filled['state'], 'Filled');
    expect(filled['name'], selectedProduct.name);
    expect(filled['imageAsset'], selectedProduct.imageAsset);
    expect(inlineMessage(), contains(selectedProduct.name));
    expect(inlineMessage(), contains('Next, choose bottoms'));
    if (testRemoval) {
      await interact('remove_product');
      stdout.writeln(
        jsonEncode({'stage': 'removal', 'requests': client.requests}),
      );
      expect(connected.connectionError, isNull);
      expect(connected.latestInlineSurfaceId, 'inline-3');
      expect(selected.getValue<List<Object?>>(DataPath('/products')), isEmpty);
      expect(
        dressing.getValue<String>(DataPath('/spent')),
        '€0.00 spent · 0 pieces',
      );
      expect(dressing.getValue<String>(DataPath('/left')), '€900.00 left');
      expectOptionsFor(ProductCategory.top);
      expectNext(ProductCategory.top);
      expect(inlineMessage(), contains('Removed ${selectedProduct.name}'));
    }
    expect(client.requests, lessThanOrEqualTo(client.requestLimit));
    stdout.writeln(
      jsonEncode({
        'model': model,
        'initialPreviewSeeded': seededPreview,
        'realProviderInteractions': seededPreview
            ? testRemoval
                  ? 2
                  : 1
            : testRemoval
            ? 3
            : 2,
        'providerRequests': client.requests,
        'recommendationId': id,
        'selectedThenRemoved': testRemoval,
        'advancedToBottomsAfterSelection': true,
        'reopenedTopAfterRemoval': testRemoval,
        'catalogPhotoFilesVerified': true,
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

class _LiveHttpOverrides extends HttpOverrides {}

class _ProbeClient extends http.BaseClient {
  _ProbeClient(this.inner);
  final http.Client inner;
  int requests = 0;
  final int requestLimit =
      (int.tryParse(Platform.environment['STYLIST_LIVE_MAX_REQUESTS'] ?? '') ??
              12)
          .clamp(1, 12);
  final List<String> tools = [];
  final List<Map<String, Object?>> usage = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (requests >= requestLimit) {
      throw StateError('Smoke-test request limit reached');
    }
    requests++;
    stdout.writeln(
      jsonEncode({'stage': 'provider_request', 'request': requests}),
    );
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    stdout.writeln(
      jsonEncode({
        'stage': 'provider_response',
        'request': requests,
        'status': response.statusCode,
      }),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is Map && body['error'] is Map) {
        final error = body['error'] as Map;
        stdout.writeln(
          jsonEncode({
            'providerError': {
              for (final field in ['type', 'param', 'code'])
                if (error[field] is String &&
                    RegExp(r'^[a-zA-Z0-9_.\[\]-]{1,100}$')
                        .hasMatch(error[field]))
                  field: error[field],
            },
          }),
        );
      }
    }
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
