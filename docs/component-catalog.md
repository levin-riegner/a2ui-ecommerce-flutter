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
| `ChoiceGroup` | Responsive wrapping choice set | explicit event | string-array/string references |
| `BudgetSlider` | Budget range control | local data-model update | number reference |
| `PrimaryButton` | Primary journey action | explicit event | string reference |
| `ProductCard` | Recommendation selection | explicit event with product ID | string references |
| `PieceSlot` | Reusable empty/next/filled slot primitive | none | string references |
| `DressingRoom` | Persistent outfit summary surface | data-model updates | string/number references |

This gives the starter a 24-component vocabulary: 15 basic components plus 9 commerce components. The custom items are deliberately small and schema-driven; a future component should add its schema, builder, fixture message, interaction behavior, and test together.

## Growth path

The next useful additions are explicit state variants and visual examples for `ProductGrid`, `OutfitSummary`, `ImageWithReason`, `LoadingState`, `ErrorState`, and `ChatInput`. Those should remain catalog items only when the state cannot be expressed clearly with the existing basic vocabulary.
