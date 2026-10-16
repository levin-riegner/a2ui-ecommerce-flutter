import 'dart:convert';

import 'package:genui/genui.dart';

/// Generated from the renderer's actual catalog, never a second schema copy.
Map<String, Object?> exportCommerceCatalog(Catalog catalog) => {
  'format': 'a2ui-v0.9',
  'catalog': catalog.toCapabilitiesJson(),
  'instructions': catalog.systemPromptFragments,
  'examples': [
    for (final item in catalog.items)
      for (var index = 0; index < item.exampleData.length; index++)
        {
          'component': item.name,
          'variant': index,
          'messages': exampleSurfaceMessages(
            catalog,
            item,
            index,
            surfaceId: 'example-${item.name}-$index',
          ),
        },
  ],
};

List<Map<String, Object?>> exampleSurfaceMessages(
  Catalog catalog,
  CatalogItem item,
  int variant, {
  required String surfaceId,
}) {
  final decoded = jsonDecode(item.exampleData[variant]());
  if (decoded is! List ||
      !decoded.any(
        (component) => component is Map && component['id'] == 'root',
      )) {
    throw FormatException('${item.name} example $variant must have a root');
  }
  return [
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': catalog.toCapabilitiesJson()['catalogId'],
        'sendDataModel': true,
      },
    },
    {
      'version': 'v0.9',
      'updateComponents': {'surfaceId': surfaceId, 'components': decoded},
    },
  ];
}
