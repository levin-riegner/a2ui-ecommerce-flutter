import 'dart:convert';

import 'stylist_result.dart';
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
  );
  // GenUI edits bound form data locally. Its wire graph must own mutable
  // collections rather than sharing the immutable domain snapshot.
  return jsonDecode(
    jsonEncode({
      ...result.toJson(),
      'messages': view.updateCurrentInlineOnly
          ? messages.where((message) {
              final update =
                  message['updateComponents'] ?? message['updateDataModel'];
              return update is Map &&
                  update['surfaceId'] == 'inline-${view.turn}';
            }).toList()
          : messages,
    }),
  ) as Map<String, dynamic>;
}
