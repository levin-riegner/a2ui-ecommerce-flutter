// Native simulator entry point. Uses the real app and catalog with the free
// deterministic provider; never reads a provider key or makes paid requests.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foldable/foldable.dart';
import 'package:genui/genui.dart';

Future<GenkitAgent> createDuoFixtureAgent() async {
  WidgetsFlutterBinding.ensureInitialized();
  final products = parseCatalogProducts(
    await rootBundle.loadString('assets/data/catalog/products.csv'),
  );
  final agent = GenkitAgent(StylistRuntime(products: products));
  await agent.startJourney(DemoJourney.berlin);
  final options = agent.controller
      .contextFor(agent.latestInlineSurfaceId!)
      .dataModel
      .getValue<List<Object?>>(DataPath('/recommendations'))!;
  final id = (options.first as Map)['id'];
  await agent.conversation.sendRequest(
    ChatMessage.user(
      '',
      parts: [
        UiInteractionPart.create(
          jsonEncode({
            'action': {
              'name': 'select_product',
              'context': {'productId': id},
            },
          }),
        ),
      ],
    ),
  );
  return agent;
}

Future<void> main() async {
  final agent = await createDuoFixtureAgent();
  runApp(ReferenceApp(agent: agent));
  developer.registerExtension('ext.duo.capture', (method, parameters) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await captureDuoState(agent)),
    );
  });
  // Test-only focus request works around simulator tools that target only the
  // cover framebuffer. Keyboard geometry still comes from the real iOS view.
  developer.registerExtension('ext.duo.focus', (method, parameters) async {
    void focus(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        final state = element.state as EditableTextState;
        if (parameters['draft'] case final String draft) {
          state.widget.controller.text = draft;
        }
        state.widget.focusNode.requestFocus();
      }
      element.visitChildElements(focus);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(focus);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await captureDuoState(agent)),
    );
  });
  developer.registerExtension('ext.duo.keyboard', (method, parameters) async {
    final visible = parameters['visible'] == 'true';
    void updateFocus(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        final node = (element.state as EditableTextState).widget.focusNode;
        if (visible) {
          node.requestFocus();
        } else {
          node.unfocus();
        }
      }
      element.visitChildElements(updateFocus);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(updateFocus);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await SystemChannels.textInput.invokeMethod<void>(
      visible ? 'TextInput.show' : 'TextInput.hide',
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return developer.ServiceExtensionResponse.result(
      jsonEncode(await captureDuoState(agent)),
    );
  });
  String? previous;
  Timer.periodic(const Duration(seconds: 1), (_) async {
    final record = await captureDuoState(agent);
    final encoded = jsonEncode(record);
    if (encoded != previous) {
      previous = encoded;
      debugPrint('DUO_PROBE $encoded');
    }
  });
}

Future<Map<String, Object?>> captureDuoState(GenkitAgent agent) async {
  final snapshot = await FoldablePlatform.instance.getSnapshot();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final fields = <Map<String, Object?>>[];
  final layouts = <String>[];
  final backgrounds = <Map<String, Object?>>[];
  final panels = <String, Object?>{};
  void visit(Element element) {
    final widget = element.widget;
    if (widget.key is ValueKey &&
        const {
          'dressing-room-resize',
          'selected-pieces-section',
        }.contains((widget.key as ValueKey).value)) {
      final render = element.findRenderObject();
      if (render is RenderBox && render.hasSize) {
        panels[(widget.key as ValueKey).value as String] = {
          'top': render.localToGlobal(Offset.zero).dy,
          'height': render.size.height,
        };
      }
    }
    if (widget is ColoredBox &&
        widget.key == const ValueKey('secondary-pane-background')) {
      backgrounds.add({
        'color': widget.color.toARGB32().toRadixString(16).padLeft(8, '0'),
        'bounds': '${element.findRenderObject()?.paintBounds}',
      });
    }
    if (widget.key is ValueKey &&
        const {
          'compact-pane-layout',
          'split-pane-layout',
          'obstructed-split-layout',
        }.contains((widget.key as ValueKey).value)) {
      layouts.add(widget.key.toString());
    }
    if (element is StatefulElement && element.state is EditableTextState) {
      final state = element.state as EditableTextState;
      final render = element.findRenderObject();
      final box = render is RenderBox && render.hasSize ? render : null;
      fields.add({
        'draft': state.widget.controller.text,
        'focus': state.widget.focusNode.hasFocus,
        'textScale': MediaQuery.textScalerOf(element).scale(14) / 14,
        'bounds': box == null
            ? null
            : '${box.localToGlobal(Offset.zero) & box.size}',
        'state': identityHashCode(state),
      });
    }
    element.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return {
    'status': snapshot.status.name,
    'angle': snapshot.angleDegrees,
    'support': snapshot.capabilities.supportLevel.name,
    'strategy': snapshot.capabilities.strategy,
    'size': '${view.physicalSize / view.devicePixelRatio}',
    'keyboard': view.viewInsets.bottom / view.devicePixelRatio,
    'sizeClass': snapshot.horizontalSizeClass.name,
    'regions': snapshot.regions
        .map(
          (r) => {
            'kind': r.kind.name,
            'active': r.isActive,
            'bounds': '${r.bounds}',
          },
        )
        .toList(),
    'fields': fields,
    'layouts': layouts,
    'backgrounds': backgrounds,
    'panels': panels,
    'surface': agent.latestInlineSurfaceId,
    'journey': agent.activeJourney?.name,
    'agent': identityHashCode(agent),
    'spent': agent.controller
        .contextFor('dressing-room')
        .dataModel
        .getValue<String>(DataPath('/spent')),
    'selected':
        (agent.controller
                    .contextFor('dressing-room')
                    .dataModel
                    .getValue<List<Object?>>(DataPath('/slots')) ??
                [])
            .cast<Map>()
            .where((slot) => slot['state'] == 'Filled')
            .map((slot) => slot['name'])
            .toList(),
  };
}
