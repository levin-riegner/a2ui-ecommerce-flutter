import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../layout/adaptive_pane_layout.dart';
import '../layout/stylist_layout.dart';

/// Host-owned spacing for brief sections and recommendation groups. Child
/// bindings and actions remain in their existing catalog components.
final stylistSectionCatalogItem = CatalogItem(
  name: 'StylistSection',
  dataSchema: S.object(
    properties: {
      'children': S.list(items: S.string()),
      'spacing': S.number(),
      'compactCarousel': S.boolean(),
    },
    required: ['children'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map;
    final ids = List<String>.from(data['children'] as List);
    final gap =
        (data['spacing'] as num?)?.toDouble() ?? StylistLayout.sectionGap;
    final children = [for (final id in ids) context.buildChild(id)];
    if (data['compactCarousel'] == true &&
        !AdaptivePaneScope.isSplitOf(context.buildContext) &&
        MediaQuery.textScalerOf(context.buildContext).scale(14) <= 21) {
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          key: const ValueKey('recommendation-carousel'),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - 24).clamp(280, 436),
                  child: child,
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: children,
    );
  },
);
