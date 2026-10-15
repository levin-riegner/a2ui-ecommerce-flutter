import 'package:genui/genui.dart';

import 'commerce_widgets.dart';
import 'recommendation_skeleton.dart';
import 'finalized_left_a2ui.dart';
import 'finalized_right_a2ui.dart';
import 'finalized_shared_a2ui.dart';
import 'occasion_collage_a2ui.dart';
import 'stylist_section.dart';

const commerceCatalogId = 'com.example.a2ui_flutter_commerce/catalog';

Catalog buildCommerceCatalog() {
  final base = BasicCatalogItems.asNoAssetCatalog(
    systemPromptFragments: const [
      'This catalog is for a responsive commerce showcase.',
      'Keep the dressing room as a persistent surface while inline recommendations change.',
      'Use ChoiceChip for one-of-many structured choices and ProductCard for recommendations.',
      'Use a short StylistMessage before a row of ProductCard components.',
      'All actions must be explicit event actions with stable names and small JSON contexts.',
    ],
  );
  return base.copyWith(
    catalogId: commerceCatalogId,
    newItems: [
      stylistSectionCatalogItem,
      chipCatalogItem,
      choiceGroupCatalogItem,
      primaryButtonCatalogItem,
      budgetSliderCatalogItem,
      stylistMessageCatalogItem,
      eyebrowCatalogItem,
      productCardCatalogItem,
      recommendationSkeletonCatalogItem,
      recommendationPreviewCatalogItem,
      pieceSlotCatalogItem,
      dressingRoomCatalogItem,
      ...finalizedLeftItems,
      ...finalizedRightItems,
      ...finalizedSharedItems,
      ...finalizedScreenItems,
    ],
  );
}
