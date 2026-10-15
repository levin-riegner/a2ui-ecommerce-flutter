import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../layout/adaptive_pane_layout.dart';
import '../layout/stylist_layout.dart';
import '../layout/stylist_message_queue.dart';
import '../layout/stylist_surface_motion.dart';
import 'finalized_left_components.dart';

/// Host-owned spacing for brief sections and recommendation groups. Child
/// bindings and actions remain in their existing catalog components.
final stylistSectionCatalogItem = CatalogItem(
  name: 'StylistSection',
  dataSchema: S.object(
    properties: {
      'children': S.list(items: S.string()),
      'spacing': S.number(),
      'compactCarousel': S.boolean(),
      'collapsed': A2uiSchemas.booleanReference(),
    },
    required: ['children'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map;
    final ids = List<String>.from(data['children'] as List);
    final gap =
        (data['spacing'] as num?)?.toDouble() ?? StylistLayout.sectionGap;
    if (context.id == 'root' &&
        StylistSurfaceScope.isJourneyOf(context.buildContext)) {
      // The host presents this bag above both panes, including its actions.
      final hasBag = context.getComponent('demo-bag') != null;
      return _conversationQueue(context, [
        for (final id in ids)
          if (!isStylistUtilityComponent(id) &&
              (!hasBag ||
                  !(id == 'demo-bag' ||
                      id.startsWith('bag-size-') ||
                      const {
                        'demo-delivery',
                        'preview-demo-checkout',
                        'library-toast',
                      }.contains(id))))
            id,
      ], gap);
    }
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
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: children,
    );
    if (data['collapsed'] == null) return column;
    return BoundBool(
      dataContext: context.dataContext,
      value: data['collapsed'],
      builder: (buildContext, collapsed) => IgnorePointer(
        ignoring: collapsed == true,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('collapsible-${context.id}'),
          tween: Tween(end: collapsed == true ? 0 : 1),
          duration: MediaQuery.disableAnimationsOf(buildContext)
              ? Duration.zero
              : StylistSurfaceMotion.duration,
          curve: Curves.easeOutCubic,
          child: column,
          builder: (_, value, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(opacity: value, child: child),
            ),
          ),
        ),
      ),
    );
  },
);

Widget _conversationQueue(
  CatalogItemContext context,
  List<String> ids,
  double spacing,
) {
  final messageIds = ids
      .where((id) => context.getComponent(id)?.type == 'StylistMessage')
      .toList();

  Widget bindMessages(int index, Map<String, String> messages) {
    if (index < messageIds.length) {
      final id = messageIds[index];
      return BoundString(
        dataContext: context.dataContext,
        value: context.getComponent(id)!.properties['text'],
        builder: (_, text) =>
            bindMessages(index + 1, {...messages, id: text ?? ''}),
      );
    }
    return StylistMessageQueue(
      enabled: StylistSurfaceScope.enqueueMessagesOf(context.buildContext),
      spacing: spacing,
      initiallyVisible: {
        if (StylistSurfaceScope.textAlreadyVisibleOf(context.buildContext))
          for (final id in messageIds)
            for (final (index, _)
                in messages[id]!.split(RegExp(r'\n\s*\n')).indexed)
              '$id-paragraph-$index',
      },
      children: {
        for (final id in ids)
          if (messages.containsKey(id))
            for (final (index, paragraph)
                in messages[id]!.split(RegExp(r'\n\s*\n')).indexed)
              '$id-paragraph-$index': FinalizedStylistMessage(text: paragraph)
          else
            id: context.buildChild(id),
      },
    );
  }

  return bindMessages(0, const {});
}
