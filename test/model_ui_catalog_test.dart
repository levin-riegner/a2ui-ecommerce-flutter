import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/commerce_trace.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/model_ui_catalog.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/stylist_presenter.dart';
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/a2ui_batch_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

const _products = [
  Product(
    id: 'top-a',
    category: ProductCategory.top,
    name: 'Shirt A',
    brand: 'Demo',
    price: 20,
    meta: 'Cotton',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'top-b',
    category: ProductCategory.top,
    name: 'Shirt B',
    brand: 'Demo',
    price: 25,
    meta: 'Cotton',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'bottom-a',
    category: ProductCategory.bottom,
    name: 'Trousers',
    brand: 'Demo',
    price: 20,
    meta: 'Cotton',
    tag: '',
    swatch: '#000000',
  ),
  Product(
    id: 'shoes-a',
    category: ProductCategory.shoes,
    name: 'Shoes',
    brand: 'Demo',
    price: 20,
    meta: '',
    tag: '',
    swatch: '#000000',
  ),
];
const _input = {
  'action': {
    'name': 'find_options',
    'context': {'dressCode': 'casual', 'budget': 500, 'season': 'summer'},
  },
};

void main() {
  test('all model schemas come from the same registered renderer catalog', () {
    final renderer = buildCommerceCatalog();
    final manifest = buildModelUiCatalog(renderer);
    final actual = renderer.toCapabilitiesJson()['components'] as Map;
    expect(manifest.entries.length, 60);
    expect({
      for (final entry in manifest.entries) entry.name: entry.schema,
    }, actual);
    expect(manifest.modelSelectableComponents.toSet(), {
      'ProductCard',
      'ThisOrThat',
      'PicksStrip',
      'AlternativePiece',
    });
    expect(
      manifest.entries.where(
        (entry) => entry.availability == ModelUiAvailability.referenceOnly,
      ),
      isNotEmpty,
    );
    expect(manifest.actionSchema, isNotEmpty);
    expect(
      () => manifest.entries.first.schema['secret'] = 'value',
      throwsUnsupportedError,
    );
  });

  for (final component in ['ProductCard', 'ThisOrThat', 'PicksStrip']) {
    test(
      'actual model choice $component changes the validated rendered graph',
      () async {
        final manifest = buildModelUiCatalog(buildCommerceCatalog());
        final traces = <CommerceTraceEntry>[];
        var sawCatalog = false;
        final runtime = StylistRuntime(
          products: _products,
          uiCatalog: manifest,
          onTrace: traces.add,
          model: (request) async {
            sawCatalog |= request.messages.any(
              (message) =>
                  message.role == Role.system &&
                  message.text.contains(manifest.catalogId) &&
                  message.text.contains('AlternativePiece'),
            );
            final response = await offlineStylistModel(request);
            for (final part in response.message?.content ?? <Part>[]) {
              final tool = part.toolRequest;
              if (tool?.name == 'present_products') {
                tool!.input = {...tool.input as Map, 'component': component};
              }
            }
            return response;
          },
        );
        addTearDown(runtime.dispose);
        final result = await runtime.turn(_input);
        expect(sawCatalog, isTrue);
        expect(result.view.modelSelectedComponent, component);
        final wire = presentStylistResult(result);
        A2uiBatchValidator(buildCommerceCatalog()).validate(
          (wire['messages'] as List)
              .map(
                (raw) => core.A2uiMessage.fromJson(
                  Map<String, dynamic>.from(raw as Map),
                ),
              )
              .toList(),
        );
        final components = (wire['messages'] as List)
            .where((message) => message['updateComponents'] != null)
            .expand(
              (message) => message['updateComponents']['components'] as List,
            )
            .map((entry) => entry['component']);
        expect(components, contains(component));
        expect(result.products.map((product) => product.id), [
          'top-a',
          'top-b',
        ]);
        expect(
          traces
              .where((entry) => entry.kind == CommerceTraceKind.modelResponse)
              .any((entry) => entry.details['component'] == component),
          isTrue,
        );
        expect(
          traces
              .where((entry) => entry.kind == CommerceTraceKind.validation)
              .single
              .details['accepted'],
          isTrue,
        );
        expect(
          traces
              .where((entry) => entry.kind == CommerceTraceKind.modelRequest)
              .every((entry) => entry.details['catalogComponents'] == 60),
          isTrue,
        );
        expect(
          traces
              .where((entry) => entry.kind == CommerceTraceKind.toolResult)
              .map((entry) => entry.details['tool']),
          ['search_products', 'present_products'],
        );
        expect(
          traces
              .where((entry) => entry.kind == CommerceTraceKind.toolResult)
              .every(
                (entry) =>
                    entry.details['accepted'] == true &&
                    entry.details['productCount'] == 2,
              ),
          isTrue,
        );
      },
    );
  }

  test(
    'model can choose AlternativePiece for one eligible replacement',
    () async {
      var adjusting = false;
      final runtime = StylistRuntime(
        products: _products,
        uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
        model: (request) async {
          final response = await offlineStylistModel(request);
          if (adjusting) {
            for (final part in response.message?.content ?? <Part>[]) {
              final tool = part.toolRequest;
              if (tool?.name == 'present_products') {
                tool!.input = {
                  ...tool.input as Map,
                  'component': 'AlternativePiece',
                };
              }
            }
          }
          return response;
        },
      );
      addTearDown(runtime.dispose);
      final opening = await runtime.turn(_input);
      final selection = await runtime.turn({
        'action': {
          'name': 'select_product',
          'context': {'productId': 'top-a'},
        },
      });
      final before = jsonEncode(runtime.outfit);
      adjusting = true;
      final result = await runtime.turn({
        'action': {
          'name': 'adjust_piece',
          'context': {'category': 'top'},
        },
      });
      expect(result.view.modelSelectedComponent, 'AlternativePiece');
      expect(result.products.single.id, 'top-b');
      expect(jsonEncode(runtime.outfit), before);
      final messages = presentStylistResult(result)['messages'] as List;
      A2uiBatchValidator(buildCommerceCatalog()).validate(
        [
              ...presentStylistResult(opening)['messages'] as List,
              ...presentStylistResult(selection)['messages'] as List,
              ...messages,
            ]
            .map(
              (raw) => core.A2uiMessage.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ),
            )
            .toList(),
      );
      expect(
        messages
            .where((message) => message['updateComponents'] != null)
            .expand(
              (message) => message['updateComponents']['components'] as List,
            )
            .any((entry) => entry['component'] == 'AlternativePiece'),
        isTrue,
      );
    },
  );

  test(
    'ineligible model component fails the whole turn without changing outfit',
    () async {
      final traces = <CommerceTraceEntry>[];
      final runtime = StylistRuntime(
        products: _products,
        uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
        onTrace: traces.add,
        model: (request) async {
          final response = await offlineStylistModel(request);
          for (final part in response.message?.content ?? <Part>[]) {
            final tool = part.toolRequest;
            if (tool?.name == 'present_products') {
              tool!.input = {
                ...tool.input as Map,
                'component': 'AlternativePiece',
              };
            }
          }
          return response;
        },
      );
      addTearDown(runtime.dispose);
      final before = jsonEncode(runtime.outfit);
      await expectLater(runtime.turn(_input), throwsA(anything));
      expect(jsonEncode(runtime.outfit), before);
      expect(
        traces
            .where((entry) => entry.kind == CommerceTraceKind.validation)
            .any((entry) => entry.details['accepted'] == false),
        isTrue,
      );
    },
  );

  test('offline model selection is labeled offline and does not expose prompt content', () async {
    final traces = <CommerceTraceEntry>[];
    final runtime = StylistRuntime(
      products: _products,
      uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
      onTrace: traces.add,
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn(_input);
    expect(result.view.modelSelectedComponent, 'PicksStrip');
    final modelEntries = traces.where(
      (entry) =>
          entry.kind == CommerceTraceKind.modelRequest ||
          entry.kind == CommerceTraceKind.modelResponse,
    );
    expect(modelEntries, isNotEmpty);
    expect(
      modelEntries.every((entry) => entry.details['source'] == 'offline'),
      isTrue,
    );
    expect(
      jsonEncode(traces.map((entry) => entry.details).toList()),
      isNot(contains('Shirt A')),
    );
  });

  test('late canceled model response cannot enter the current trace', () async {
    final entered = Completer<void>();
    final response = Completer<ModelResponse>();
    final traces = <CommerceTraceEntry>[];
    final runtime = StylistRuntime(
      products: _products,
      uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
      onTrace: traces.add,
      model: (request) {
        entered.complete();
        return response.future;
      },
    );
    final pending = expectLater(runtime.turn(_input), throwsA(anything));
    await entered.future;
    runtime.cancelActiveTurn();
    response.complete(
      ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'private late response')],
        ),
      ),
    );
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(
      traces.where((entry) => entry.kind == CommerceTraceKind.modelResponse),
      isEmpty,
    );
    await runtime.dispose();
  });

  test('a closed diagnostic consumer cannot fail the commerce turn', () async {
    final runtime = StylistRuntime(
      products: _products,
      uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
      onTrace: (_) => throw StateError('inspector closed'),
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn(_input);
    expect(result.products.length, 2);
    expect(result.view.modelSelectedComponent, 'PicksStrip');
  });

  test(
    'without injected catalog the original presentation contract is retained',
    () async {
      final runtime = StylistRuntime(products: _products);
      addTearDown(runtime.dispose);
      final result = await runtime.turn(_input);
      expect(result.view.modelSelectedComponent, isNull);
      expect(result.view.presentation, 'cards');
    },
  );
}
