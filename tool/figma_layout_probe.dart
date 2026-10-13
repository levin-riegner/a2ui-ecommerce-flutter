// Repeatable production-layout captures. No provider key or network requests.
// Run: fvm flutter run -d <duo-udid> -t tool/figma_layout_probe.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:a2ui_core/a2ui_core.dart' as core;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:foldable/foldable.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/agent/city_context.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';

import 'duo_simulator_probe.dart' show captureDuoState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final products = parseCatalogProducts(
    await rootBundle.loadString('assets/data/catalog/products.csv'),
  );
  var revision = 0;
  Completer<void>? firstReplyGate;
  Future<void>? firstTurn;
  var agent = GenkitAgent(StylistRuntime(products: products));
  Map<String, Object?> composerGeometry() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final height = view.physicalSize.height / view.devicePixelRatio;
    final composers = <Map<String, Object?>>[];
    final panes = <String, String>{};
    void visit(Element element) {
      for (final name in [
        'occasion-mosaic',
        'portrait-dressing-pane',
        'portrait-conversation-pane',
      ]) {
        if (element.widget.key == ValueKey(name)) {
          final render = element.findRenderObject();
          if (render is RenderBox && render.hasSize) {
            panes[name] = '${render.localToGlobal(Offset.zero) & render.size}';
          }
        }
      }
      if (element.widget is StylistComposer) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.hasSize) {
          final bounds = render.localToGlobal(Offset.zero) & render.size;
          composers.add({
            'bounds': '$bounds',
            'bottomGap': height - bounds.bottom,
          });
        }
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return {
      'nativeBottomInset': view.padding.bottom / view.devicePixelRatio,
      'composers': composers,
      'panes': panes,
    };
  }

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
      return {...record, 'scrolls': scrolls, ...composerGeometry()};
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final snapshot = await FoldablePlatform.instance.getSnapshot();
    return {
      'status': snapshot.status.name,
      'angle': snapshot.angleDegrees,
      'size': '${view.physicalSize / view.devicePixelRatio}',
      'surface': null,
      'agent': identityHashCode(agent),
      ...composerGeometry(),
    };
  }

  void show() => runApp(ReferenceApp(key: ValueKey(revision++), agent: agent));
  show();
  developer.registerExtension('ext.layout.beginFirst', (_, _) async {
    firstReplyGate = Completer<void>();
    agent = GenkitAgent(
      StylistRuntime(
        products: products,
        cityContextSource: _LayoutCityContextSource(),
        model: (request) async {
          await firstReplyGate!.future;
          return offlineStylistModel(request);
        },
      ),
    );
    show();
    firstTurn = agent.startJourney(DemoJourney.berlin);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await capture()),
    );
  });
  developer.registerExtension('ext.layout.finishFirst', (_, _) async {
    firstReplyGate!.complete();
    await firstTurn;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await capture()),
    );
  });
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
  developer.registerExtension('ext.layout.scroll', (_, parameters) async {
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final view = element
            .findAncestorWidgetOfExactType<SingleChildScrollView>();
        if (view?.key == const ValueKey('primary-pane-scroll') ||
            view?.key == const ValueKey('compact-pane-scroll')) {
          final position = (element.state as ScrollableState).position;
          position.jumpTo(
            parameters['edge'] == 'start' ? 0 : position.maxScrollExtent,
          );
        }
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    await Future<void>.delayed(const Duration(milliseconds: 400));
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

class _LayoutCityContextSource implements CityContextSource {
  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) async =>
      _LayoutCityContext();
  @override
  void dispose() {}
}

class _LayoutCityContext extends CityContext {
  _LayoutCityContext()
    : super(
        city: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'Europe/Berlin',
        fetchedAt: DateTime.utc(2026, 10, 13),
        days: [
          for (var i = 0; i < 5; i++)
            {
              'date': '2026-10-${13 + i}',
              'label': ['Tue', 'Wed', 'Thu', 'Fri', 'Sat'][i],
              'value': '12° / 8°',
              'detail': '20% rain',
              'icon': 'day',
              'highlight': i == 0,
            },
        ],
      );
  @override
  Map<String, Object?> get weatherCard => {
    ...super.weatherCard,
    'disclaimer': 'Offline layout fixture — not a live forecast.',
  };
  @override
  Map<String, Object?> get facts => {
    ...super.facts,
    'source': 'Offline layout fixture',
  };
}
