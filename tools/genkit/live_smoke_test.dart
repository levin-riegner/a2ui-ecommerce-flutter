import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Explicit opt-in only; never included in the default test directory or CI.
/// Makes at most three interactions / twelve provider requests.
void main() {
  testWidgets('live OpenAI catalog journey, selection, removal, and rendering', (
    tester,
  ) async {
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
    // Widget tests normally block HTTP; enable it only for this opted-in client.
    final client = HttpOverrides.runWithHttpOverrides(
      () => _ProbeClient(IOClient(HttpClient())),
      _LiveHttpOverrides(),
    );
    addTearDown(client.close);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final agent = await tester.runAsync(
      () => GenkitAgent.connect(
        provider: 'openai',
        model: model,
        apiKey: key,
        client: client,
      ),
    );
    expect(agent, isNotNull);
    final connected = agent!;
    expect(client.requests, 0, reason: 'Setup must make no paid request.');
    await tester.pumpWidget(ReferenceApp(agent: connected));
    await tester.runAsync(() => connected.startJourney(DemoJourney.lisbon));
    await tester.pumpAndSettle();
    expect(connected.connectionError, isNull);
    expect(client.tools, containsAll(['search_products', 'present_products']));
    final recommendations = connected.controller
        .contextFor(connected.latestInlineSurfaceId!)
        .dataModel;
    final id = recommendations.getValue<String>(
      DataPath('/recommendations/0/id'),
    );
    final name = recommendations.getValue<String>(
      DataPath('/recommendations/0/name'),
    );
    final image = recommendations.getValue<String>(
      DataPath('/recommendations/0/imageAsset'),
    );
    expect(id, isNotEmpty);
    expect(name, isNotEmpty);
    expect(image, startsWith('assets/images/products/'));
    expect(find.text(name!), findsWidgets);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (widget) =>
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == image,
          ),
      isTrue,
    );
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
    await tester.runAsync(() => interact('select_product'));
    await tester.pumpAndSettle();
    expect(connected.connectionError, isNull);
    final selected = connected.controller
        .contextFor('selected-products')
        .dataModel;
    expect(selected.getValue<String>(DataPath('/products/0/id')), id);
    final dressing = connected.controller.contextFor('dressing-room').dataModel;
    expect(dressing.getValue<String>(DataPath('/spent')), contains('1 pieces'));
    expect(find.text(name), findsWidgets);
    await tester.runAsync(() => interact('remove_product'));
    await tester.pumpAndSettle();
    expect(connected.connectionError, isNull);
    expect(selected.getValue<List<Object?>>(DataPath('/products')), isEmpty);
    expect(
      dressing.getValue<String>(DataPath('/spent')),
      '€0.00 spent · 0 pieces',
    );
    expect(dressing.getValue<String>(DataPath('/left')), '€750.00 left');
    expect(client.requests, lessThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
    // Only counts, tool names, and usage are recorded; never headers or bodies.
    stdout.writeln(
      jsonEncode({
        'model': model,
        'providerRequests': client.requests,
        'tools': client.tools,
        'usage': client.usage,
        'recommendationId': id,
        'selectedThenRemoved': true,
        'renderedCatalogPhoto': true,
      }),
    );
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 4)));
}

class _LiveHttpOverrides extends HttpOverrides {}

class _ProbeClient extends http.BaseClient {
  _ProbeClient(this.inner);
  final http.Client inner;
  int requests = 0;
  final List<String> tools = [];
  final List<Map<String, Object?>> usage = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (++requests > 12) throw StateError('Smoke-test request limit reached');
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
