// Repeatable production-layout captures. No provider key or network requests.
// Run: fvm flutter run -d <duo-udid> -t tool/figma_layout_probe.dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:a2ui_core/a2ui_core.dart' as core;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:foldable/foldable.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';

import 'duo_simulator_probe.dart' show captureDuoState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final products = parseCatalogProducts(
    await rootBundle.loadString('assets/data/catalog/products.csv'),
  );
  var revision = 0;
  var agent = GenkitAgent(StylistRuntime(products: products));
  Future<void> selectFirst() async {
    final rows = agent.controller
        .contextFor(agent.latestInlineSurfaceId!)
        .dataModel
        .getValue<List<Object?>>(DataPath('/recommendations'));
    if (rows == null || rows.isEmpty) return;
    await agent.conversation.sendRequest(
      ChatMessage.user(
        '',
        parts: [
          UiInteractionPart.create(
            jsonEncode({
              'action': {
                'name': 'select_product',
                'context': {'productId': (rows.first as Map)['id']},
              },
            }),
          ),
        ],
      ),
    );
  }

  Future<Map<String, Object?>> capture() async {
    if (agent.hasDressingRoomSurface) {
      final record = await captureDuoState(agent);
      final scrolls = <Map<String, Object?>>[];
      void visit(Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final position = (element.state as ScrollableState).position;
          if (position.axis == Axis.vertical && position.hasContentDimensions) {
            scrolls.add({
              'pixels': position.pixels,
              'max': position.maxScrollExtent,
            });
          }
        }
        element.visitChildElements(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildElements(visit);
      return {...record, 'scrolls': scrolls};
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final snapshot = await FoldablePlatform.instance.getSnapshot();
    return {
      'status': snapshot.status.name,
      'angle': snapshot.angleDegrees,
      'size': '${view.physicalSize / view.devicePixelRatio}',
      'surface': null,
      'agent': identityHashCode(agent),
    };
  }

  void show() => runApp(ReferenceApp(key: ValueKey(revision++), agent: agent));
  show();
  developer.registerExtension('ext.layout.stage', (_, parameters) async {
    agent = GenkitAgent(StylistRuntime(products: products));
    final stage = parameters['stage'] ?? 'start';
    if (stage == 'brief') {
      await agent.startBrief('An anniversary dinner in Paris');
    } else if (stage != 'start') {
      await agent.startJourney(DemoJourney.berlin);
      final count = stage == 'complete' ? 4 : 1;
      for (var i = 0; i < count; i++) {
        await selectFirst();
      }
    }
    show();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await capture()),
    );
  });
  developer.registerExtension(
    'ext.duo.capture',
    (_, _) async =>
        developer.ServiceExtensionResponse.result(jsonEncode(await capture())),
  );
  developer.registerExtension('ext.layout.select', (_, _) async {
    await selectFirst();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await capture()),
    );
  });
  // Renderer-only bound-data growth exercises following without model calls.
  developer.registerExtension('ext.layout.grow', (_, parameters) async {
    final id = agent.latestInlineSurfaceId!;
    final lines = int.parse(parameters['lines']!).clamp(1, 40);
    agent.transport.addMessage(
      core.A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': id,
          'path': '/message',
          'value': List.filled(
            lines,
            'Validated catalog styling detail.',
          ).join('\n'),
        },
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await capture()),
    );
  });
}
