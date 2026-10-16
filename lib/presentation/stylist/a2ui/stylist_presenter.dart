import 'dart:convert';

import '../../../data/stylist/model/stylist_result.dart';
import 'stylist_surfaces.dart';

/// Explicit compatibility adapter for Flutter and existing wire-level tooling.
/// The runtime calls its validator before committing domain state or storage.
Map<String, dynamic> presentStylistResult(StylistTurnResult result) {
  final view = result.view;
  final messages = renderStylistSurfaces(
    turn: view.turn,
    reply: result.reply,
    picks: view.picks,
    outfit: result.outfit,
    budget: result.brief.budget,
    occasion: result.brief.summary,
    plan: view.plan,
    nextCategory: view.nextCategory,
    clarification: view.clarification,
    budgetAdjustment: view.budgetAdjustment,
    cityContext: view.cityContext,
    cityContextNotice: view.cityContextNotice,
    city: view.city,
    presentation: view.presentation,
    adjusting: view.adjusting,
    adjustmentOptions: view.adjustmentOptions,
    adjustmentSelected: view.adjustmentSelected,
    preferences: view.preferences,
    canEditPreferences: view.canEditPreferences,
    ownedCategories: view.ownedCategories,
    showCompletion: view.showCompletion,
    library: view.library,
    inspectProducts: view.inspectProducts,
    changeDirection: view.changeDirection,
    productDetails: view.productDetails,
    selectionOptions: view.selectionOptions,
  );
  // GenUI edits bound form data locally. Its wire graph must own mutable
  // collections rather than sharing the immutable domain snapshot.
  return jsonDecode(
    jsonEncode({
      ...result.toJson(),
      'messages': view.updateCurrentInlineOnly
          ? [
              for (final message in messages)
                if (message['updateComponents'] case final Map update)
                  if (update['surfaceId'] == 'inline-${view.turn}')
                    {
                      'version': 'v0.9',
                      'updateComponents': {
                        'surfaceId': update['surfaceId'],
                        'components': [
                          for (final c in update['components'] as List)
                            if ((c['id'] as String).startsWith('city-')) c,
                        ],
                      },
                    },
              for (final entry in <String, Object?>{
                'cityLabel': view.cityContext?.label ?? view.city,
                'weather': view.cityContext?.weatherCard,
                'contextNotice': view.cityContextNotice ?? '',
              }.entries)
                {
                  'version': 'v0.9',
                  'updateDataModel': {
                    'surfaceId': 'inline-${view.turn}',
                    'path': '/${entry.key}',
                    'value': entry.value,
                  },
                },
            ]
          : messages,
    }),
  ) as Map<String, dynamic>;
}
