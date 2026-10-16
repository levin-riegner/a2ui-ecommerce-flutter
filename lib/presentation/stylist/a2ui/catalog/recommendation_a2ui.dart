import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../shared/design_system/views/commerce/finalized_left_components.dart';

/// A placeholder has no product identity, price or selection controls.
final recommendationSkeletonCatalogItem = CatalogItem(
  name: 'RecommendationSkeleton',
  dataSchema: S.object(properties: {}),
  widgetBuilder: (_) => const _RecommendationSkeleton(),
);

/// Catalog facts can arrive before the stylist's prose. These are previews;
/// selection controls are created only by the committed recommendation surface.
final recommendationPreviewCatalogItem = CatalogItem(
  name: 'RecommendationPreview',
  dataSchema: S.object(
    properties: {'products': A2uiSchemas.listOrReference(items: S.any())},
    required: ['products'],
  ),
  widgetBuilder: (context) => BoundList(
    dataContext: context.dataContext,
    value: (context.data as Map)['products'],
    builder: (context, products) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final raw in products ?? const [])
          if (raw is Map)
            FinalizedProductCard(
              name: '${raw['name'] ?? ''}',
              price: '${raw['price'] ?? ''}',
              brandLine: '${raw['brandLine'] ?? ''}',
              tag: '${raw['tag'] ?? ''}',
              category: '${raw['category'] ?? 'dress'}',
              imageAsset: raw['imageAsset'] as String?,
              swatch: raw['swatch'] as String?,
            ),
      ],
    ),
  ),
);

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Recommendation cards are loading',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _block(context, width: 84, height: 108),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _block(context, height: 16),
                        const SizedBox(height: 10),
                        _block(context, width: 72, height: 12),
                        const SizedBox(height: 10),
                        _block(context, width: 120, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _block(
    BuildContext context, {
    double? width,
    required double height,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
