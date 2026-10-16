import 'package:a2ui_flutter_commerce/util/stylist_dependencies.dart';

import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_products.dart';
import 'package:flutter/services.dart';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:flutter/material.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/commerce_trace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const proxy = String.fromEnvironment('ALDER_DEMO_PROXY');
  const token = String.fromEnvironment('ALDER_DEMO_TOKEN');
  const model = String.fromEnvironment('ALDER_DEMO_MODEL');
  const offline = bool.fromEnvironment('ALDER_DEMO_OFFLINE');
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
            model: offlineStylistModel,
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
  runApp(ReferenceApp(agent: agent));
  if (!offline) {
    await agent.startBrief(
      'A smart casual work day in Berlin today, budget €900. '
      'Help me choose an outfit for the current weather.',
    );
  }
}
