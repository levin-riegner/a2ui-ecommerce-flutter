import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Explicit opt-in only; never included in the default test directory or CI.
/// Makes at most three interactions / twelve provider requests.
void main() {
  testWidgets(
    'live Berlin journey advances after selection and reopens removal',
    (tester) async {
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
      addTearDown(() {
        // Preserve bounded-request evidence even when a later assertion fails.
        stdout.writeln(
          jsonEncode({
            'model': model,
            'providerRequests': client.requests,
            'tools': client.tools,
            'usage': client.usage,
          }),
        );
      });
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
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: ReferenceApp(agent: connected),
        ),
      );
      final catalog = parseCatalogProducts(
        await rootBundle.loadString('assets/data/catalog/products.csv'),
      );
      Product productFor(String id) => catalog.singleWhere((p) => p.id == id);
      List<String> recommendationIds() =>
          (connected.controller
                      .contextFor(connected.latestInlineSurfaceId!)
                      .dataModel
                      .getValue<List<Object?>>(DataPath('/recommendations')) ??
                  [])
              .map((card) => (card as Map)['id'] as String)
              .toList();
      void expectOptionsFor(ProductCategory category) {
        final ids = recommendationIds();
        expect(
          ids,
          isNotEmpty,
          reason: 'The conversation must offer its next step.',
        );
        expect(
          ids.map((id) => productFor(id).category),
          everyElement(category),
        );
      }

      await tester.runAsync(() => connected.startJourney(DemoJourney.berlin));
      await tester.pumpAndSettle();
      expect(connected.connectionError, isNull);
      expect(
        client.tools,
        containsAll(['search_products', 'present_products']),
      );
      expectOptionsFor(ProductCategory.top);
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
      Future<void> interact(String action) =>
          connected.conversation.sendRequest(
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
      final dressing = connected.controller
          .contextFor('dressing-room')
          .dataModel;
      expect(
        dressing.getValue<String>(DataPath('/spent')),
        contains('1 pieces'),
      );
      expectOptionsFor(ProductCategory.bottom);
      expect(recommendationIds(), isNot(contains(id)));
      expect(
        dressing.getValue<String>(DataPath('/left')),
        '€${(900 - productFor(id!).price).toStringAsFixed(2)} left',
      );
      expect(find.text(name), findsWidgets);
      final screenshotDirectory =
          Platform.environment['STYLIST_LIVE_SCREENSHOT_DIR'];
      if (screenshotDirectory != null) {
        await tester.runAsync(() async {
          final boundary =
              previewKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final snapshot = await boundary.toImage();
          try {
            final png = await snapshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(screenshotDirectory).create(recursive: true);
            await File('$screenshotDirectory/berlin-next-bottoms.png')
                .writeAsBytes(png!.buffer.asUint8List());
          } finally {
            snapshot.dispose();
          }
        });
      }
      await tester.runAsync(() => interact('remove_product'));
      await tester.pumpAndSettle();
      expect(connected.connectionError, isNull);
      expect(selected.getValue<List<Object?>>(DataPath('/products')), isEmpty);
      expect(
        dressing.getValue<String>(DataPath('/spent')),
        '€0.00 spent · 0 pieces',
      );
      expect(dressing.getValue<String>(DataPath('/left')), '€900.00 left');
      expectOptionsFor(ProductCategory.top);
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
          'advancedToBottomsAfterSelection': true,
          'reopenedTopAfterRemoval': true,
          'renderedCatalogPhoto': true,
        }),
      );
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
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
