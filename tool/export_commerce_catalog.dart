// Run with: fvm flutter test tool/export_commerce_catalog.dart
import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/catalog_export.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/finalized_screen_examples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export the runtime catalog and replayable A2UI examples', () {
    final bundle = exportCommerceCatalog(buildCommerceCatalog());
    final directory = Directory('docs/design/export')
      ..createSync(recursive: true);
    final catalog = bundle['catalog'] as Map;
    File('${directory.path}/catalog.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(catalog));
    File('${directory.path}/examples.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(bundle));
    File('${directory.path}/screens.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert([
        for (final screen in finalizedScreenExamples)
          {
            'id': screen.id,
            'sourceNode': screen.nodeId,
            'sourceIssues': screen.sourceIssues,
            'panes': {
              for (final pane in {
                'chat': screen.chatComponents(),
                'room': screen.roomComponents(),
                if (screen.hasOverlay) 'overlay': screen.overlayComponents(),
              }.entries)
                pane.key: [
                  {
                    'version': 'v0.9',
                    'createSurface': {
                      'surfaceId': '${screen.id}-${pane.key}',
                      'catalogId': commerceCatalogId,
                    },
                  },
                  {
                    'version': 'v0.9',
                    'updateComponents': {
                      'surfaceId': '${screen.id}-${pane.key}',
                      'components': pane.value,
                    },
                  },
                  {
                    'version': 'v0.9',
                    'updateDataModel': {
                      'surfaceId': '${screen.id}-${pane.key}',
                      'value': screen.data,
                    },
                  },
                ],
            },
          },
      ]),
    );
    stdout.writeln(
      'Exported ${(catalog['components'] as Map).length} component schemas '
      'and ${(bundle['examples'] as List).length} replayable examples.',
    );
  });
}
