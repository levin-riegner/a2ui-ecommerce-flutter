import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../stylist/a2ui/catalog/catalog_export.dart';
import '../stylist/a2ui/catalog/commerce_catalog.dart';
import '../stylist/a2ui/catalog/finalized_left_a2ui.dart';
import '../stylist/a2ui/catalog/finalized_right_a2ui.dart';
import '../stylist/a2ui/catalog/finalized_shared_a2ui.dart';

/// Previews the same schemas, bindings and widgets used by model surfaces.
/// No provider connection is needed; actions remain visible for inspection.
class FinalizedComponentGallery extends StatefulWidget {
  const FinalizedComponentGallery({super.key});

  @override
  State<FinalizedComponentGallery> createState() =>
      FinalizedComponentGalleryState();
}

class FinalizedComponentGalleryState extends State<FinalizedComponentGallery> {
  late final Catalog catalog = buildCommerceCatalog();
  late final List<CatalogItem> items = [
    ...finalizedLeftItems,
    ...finalizedRightItems,
    ...finalizedSharedItems,
  ];
  late final SurfaceController controller = SurfaceController(
    catalogs: [catalog],
  );
  late final StreamSubscription<ChatMessage> subscription;
  int itemIndex = 0;
  int variantIndex = 0;
  int revision = 0;
  String lastAction = 'Tap a control to inspect its A2UI action';
  String get surfaceId => 'finalized-preview-$revision';

  @override
  void initState() {
    super.initState();
    subscription = controller.onSubmit.listen((message) {
      if (!mounted) return;
      setState(
        () => lastAction = message.parts
            .where((part) => part.isUiInteractionPart)
            .map((part) => part.asUiInteractionPart?.interaction ?? '')
            .join('\n'),
      );
    });
    _publish();
  }

  void _publish() {
    for (final message in exampleSurfaceMessages(
      catalog,
      items[itemIndex],
      variantIndex,
      surfaceId: surfaceId,
    )) {
      controller.handleMessage(core.A2uiMessage.fromJson(message));
    }
  }

  /// Test-only native probe uses the same selection path as the gallery UI.
  void select(String name, int variant) {
    final index = items.indexWhere((item) => item.name == name);
    if (index < 0 ||
        variant < 0 ||
        variant >= items[index].exampleData.length) {
      throw ArgumentError('Unknown component or variant: $name/$variant');
    }
    controller.handleMessage(
      core.A2uiMessage.fromJson({
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': surfaceId},
      }),
    );
    setState(() {
      itemIndex = index;
      variantIndex = variant;
      revision++;
      lastAction = 'Tap a control to inspect its A2UI action';
      _publish();
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(14) / 14,
      title: const Text('Finalized Figma components', maxLines: 2),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  DropdownButton<int>(
                    itemHeight:
                        56 * MediaQuery.textScalerOf(context).scale(14) / 14,
                    isExpanded: true,
                    value: itemIndex,
                    items: [
                      for (var index = 0; index < items.length; index++)
                        DropdownMenuItem(
                          value: index,
                          child: Text(
                            items[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (index) {
                      if (index != null) select(items[index].name, 0);
                    },
                  ),
                  DropdownButton<int>(
                    itemHeight:
                        56 * MediaQuery.textScalerOf(context).scale(14) / 14,
                    isExpanded: true,
                    value: variantIndex,
                    items: [
                      for (
                        var index = 0;
                        index < items[itemIndex].exampleData.length;
                        index++
                      )
                        DropdownMenuItem(
                          value: index,
                          child: Text('State ${index + 1}'),
                        ),
                    ],
                    onChanged: (index) {
                      if (index != null) select(items[itemIndex].name, index);
                    },
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Surface(
                    key: ValueKey(surfaceId),
                    surfaceContext: controller.contextFor(surfaceId),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                lastAction,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
