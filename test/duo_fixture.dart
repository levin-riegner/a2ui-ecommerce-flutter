import 'dart:convert';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_products.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';

Future<GenkitAgent> createDuoFixtureAgent({bool withInspector = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final products = parseCatalogProducts(
    await rootBundle.loadString('assets/data/catalog/products.csv'),
  );
  final catalog = buildCommerceCatalog();
  final agent = GenkitAgent(
    StylistRuntime(products: products),
    catalog: catalog,
    inspector: withInspector
        ? CommerceInspectorBloc(catalog: buildModelUiCatalog(catalog))
        : null,
  );
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
