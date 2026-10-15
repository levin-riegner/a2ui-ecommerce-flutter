import 'dart:convert';

import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'occasion_collage.dart';

final finalizedScreenItems = <CatalogItem>[
  CatalogItem(
    name: 'OccasionCollage',
    dataSchema: S.object(
      description: 'Decorative occasion collage from original code-native geometric artwork.',
      properties: {},
    ),
    exampleData: [
      () => jsonEncode([
        {'id': 'root', 'component': 'OccasionCollage'},
      ]),
    ],
    widgetBuilder: (_) => const FinalizedOccasionCollage(),
  ),
];
