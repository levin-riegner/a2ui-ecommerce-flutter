import 'package:genui/genui.dart';

import 'commerce_widgets.dart';

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
      chipCatalogItem,
      choiceGroupCatalogItem,
      primaryButtonCatalogItem,
      budgetSliderCatalogItem,
      stylistMessageCatalogItem,
      eyebrowCatalogItem,
      productCardCatalogItem,
      pieceSlotCatalogItem,
      dressingRoomCatalogItem,
    ],
  );
}
