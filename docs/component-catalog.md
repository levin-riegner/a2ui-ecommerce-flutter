# Component catalog

The app registers the GenUI basic catalog plus nine commerce components. The combined vocabulary is intentionally visible so contributors can add components without guessing where the boundary is.

## Basic catalog components

These come from the GenUI basic catalog and are available to every surface:

`Button`, `Card`, `CheckBox`, `Column`, `ChoicePicker`, `DateTimeInput`, `Divider`, `Icon`, `List`, `Modal`, `Row`, `Slider`, `Tabs`, `Text`, and `TextField`.

## Commerce components

| Component | Purpose | Interaction | Data source |
| --- | --- | --- | --- |
| `StylistMessage` | Warm assistant guidance | none | string reference |
| `Eyebrow` | Compact section label | none | string reference |
| `ChoiceChip` | Structured single-choice prompt | explicit event | string/bool references |
| `ChoiceGroup` | Responsive wrapping choice set | explicit event or local `selectionPath` update | string-array/string references |
| `BudgetSlider` | Budget range control | local data-model update | number reference |
| `PrimaryButton` | Primary journey action | explicit event | string reference |
| `ProductCard` | Recommendation selection or removal | explicit event with product ID; `remove_product` shows Remove | string references |
| `PieceSlot` | Reusable empty/next/filled slot primitive | none | string references |
| `DressingRoom` | Persistent outfit summary with the host's dynamic slot plan | data-model updates | string/number references and slot-list reference |

This gives the starter a 24-component vocabulary: 15 basic components plus 9 commerce components. The custom items are deliberately small and schema-driven; a future component should add its schema, builder, fixture message, interaction behavior, and test together.

`DressingRoom.slots` binds to an ordered list of rows with `category`, `label`, `name`, `meta`, `swatch`, optional `imageAsset`, and `state` (`Empty`, `Next`, or `Filled`). The host's outfit plan supplies required pieces and any selected optional pieces, including tops, bottoms, and accessories. `Next` marks the category currently being considered; a complete look has no next badge. `planCaption` explains progress or completion separately from the budget bar. Slot cards wrap according to their available width.

Older gallery and stub-agent surfaces may continue using the named `dressName`/`dressMeta`/`dressSwatch`/`dressImageAsset` bindings and equivalent layer, shoes, and bag fields. Those fixtures mark the next empty slot through `Choosing on the left` metadata. New stylist surfaces use `slots` and the explicit host plan.

The brief form binds `ChoiceGroup.selected` to its surface data and supplies `selectionPath` to update that value locally. Choosing a style or season makes no model request. `BudgetSlider` similarly updates `/budget`; a suggested budget becomes an outfit fact only when the person submits `Find options`. That button resolves the current dress code, season, and budget together into one `find_options` event.

## Growth path

The next useful additions are explicit state variants and visual examples for `ProductGrid`, `OutfitSummary`, `ImageWithReason`, `LoadingState`, `ErrorState`, and `ChatInput`. Those should remain catalog items only when the state cannot be expressed clearly with the existing basic vocabulary.
