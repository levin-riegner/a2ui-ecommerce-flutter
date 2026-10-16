import 'package:a2ui_flutter_commerce/util/stylist_dependencies.dart';

// Explicit development entry point; no provider credentials in the app binary.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_products.dart';
import 'package:flutter/services.dart';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/commerce_trace.dart';

import 'duo_simulator_probe.dart' show captureDuoState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const proxy = String.fromEnvironment('ALDER_DEMO_PROXY');
  const token = String.fromEnvironment('ALDER_DEMO_TOKEN');
  const model = String.fromEnvironment('ALDER_DEMO_MODEL');
  const offline = bool.fromEnvironment('ALDER_DEMO_OFFLINE');
  var modelRequests = 0;
  if (!offline && (proxy.isEmpty || token.isEmpty || model.isEmpty)) {
    runApp(const ReferenceApp());
    return;
  }
  final uiCatalog = buildCommerceCatalog();
  final inspector = offline
      ? CommerceInspectorBloc(catalog: buildModelUiCatalog(uiCatalog))
      : null;
  final agent = offline
      ? GenkitAgent(
          StylistRuntime(
            products: parseCatalogProducts(
              await rootBundle.loadString('assets/data/catalog/products.csv'),
            ),
            model: (request) async {
              await Future<void>.delayed(const Duration(milliseconds: 700));
              return offlineStylistModel(request);
            },
            onModelRequest: (_) => modelRequests++,
            uiCatalog: inspector!.catalog,
            onTrace: inspector.record,
            modelSource: CommerceModelSource.offline,
          ),
          catalog: uiCatalog,
          inspector: inspector,
        )
      : await connectStylist(
          provider: 'openai-compatible',
          model: model,
          apiKey: token,
          baseUrl: proxy,
          onlineContext: true,
        );
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    previous?.call(details);
  };
  runApp(ReferenceApp(agent: agent));
  developer.registerExtension('ext.alder.capture', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        if (agent.hasDressingRoomSurface) ...await captureDuoState(agent),
        'errors': errors,
        'offlineModel': offline,
        'modelRequests': modelRequests,
        'busy': agent.isBusy,
        'pendingSurface': agent.pendingInlineSurfaceId,
        'entries': agent.conversationEntries
            .map(
              (entry) => switch (entry) {
                CommerceUserMessage(:final id) => id,
                CommerceSurfaceEntry(:final surfaceId) => surfaceId,
              },
            )
            .toList(),
        'connectionError': agent.connectionError,
        'context': agent.latestInlineSurfaceId == null
            ? null
            : agent.controller
                  .contextFor(agent.latestInlineSurfaceId!)
                  .dataModel
                  .getValue<Object?>(DataPath('/weather')),
      }),
    );
  });
  // Test-only injection for the removal event: the simple offline model does
  // not interpret verbal edits. Never expose this in a live provider session.
  if (offline) {
    developer.registerExtension('ext.alder.remove', (method, params) async {
      await agent.conversation.sendRequest(
        ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(
              jsonEncode({
                'action': {
                  'surfaceId': 'dressing-room',
                  'name': 'remove_product',
                  'context': {'productId': params['productId']},
                },
              }),
            ),
          ],
        ),
      );
      return developer.ServiceExtensionResponse.result(
        jsonEncode(await captureDuoState(agent)),
      );
    });
  }
  // Offline verification starts at the landing page to exercise the real UI.
  if (!offline) {
    await agent.startBrief(
      'A smart casual work day in Berlin today, budget €900. '
      'Help me choose an outfit for the current weather.',
    );
  }
}
