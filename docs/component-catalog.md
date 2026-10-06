# Component catalog

The app registers the GenUI basic catalog, the finalized Figma component families, and compatible host-owned journey compositions. See [the finalized catalog and ingestion guide](design/README.md) for the current schema export, state fixtures, source mapping and host integration boundaries. The original nine journey contracts below remain supported.

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
| `PieceSlot` | Reusable empty/next/filled slot primitive | explicit Change event | string references |
| `DressingRoom` | Persistent outfit summary with the host's dynamic slot plan | data-model updates and Change event | string/number references and slot-list reference |

The custom items are schema-driven; a future component should add its schema, builder, fixture message, interaction behavior, and test together.

`DressingRoom.slots` binds to an ordered list of rows with `category`, `label`, `name`, `meta`, `swatch`, optional `imageAsset`, and `state` (`Empty`, `Next`, or `Filled`). The host's outfit plan supplies required pieces and any selected optional pieces, including tops, bottoms, and accessories. `Next` marks the category currently being considered; a complete look has no next badge. `planCaption` explains progress or completion separately from the budget bar. Slot cards wrap according to their available width.

Older gallery and stub-agent surfaces may continue using the named `dressName`/`dressMeta`/`dressSwatch`/`dressImageAsset` bindings and equivalent layer, shoes, and bag fields. Those fixtures mark the next empty slot through `Choosing on the left` metadata. New stylist surfaces use `slots` and the explicit host plan.

The brief form binds `ChoiceGroup.selected` to its surface data and supplies `selectionPath` to update that value locally. Choosing a style or season makes no model request. `BudgetSlider` similarly updates `/budget`; a suggested budget becomes an outfit fact only when the person submits `Find options`. That button resolves the current dress code, season, and budget together into one `find_options` event.

## Growth path

The finalized catalog includes chat input, working indicators, product and slot states, look summaries, fit controls, context and bag previews. Add a new item only when its behavior cannot be expressed clearly with the existing vocabulary.

## Reusing the presentation layer

`lib/commerce_ui.dart` exports the commerce presentation widgets and example definitions. The A2UI catalog builders only resolve bound values and dispatch existing events; they render the same `CommerceProductCard`, `CommerceChoice`, `CommercePrimaryButton`, `CommerceBudgetControl`, `CommercePieceSlot`, and `CommerceDressingRoom` used outside GenUI. Presentation widgets take plain values and callbacks, so another screen can use them without a conversation or provider connection.

For native iPhone Duo signals, wrap the screen or `MaterialApp.builder` child in the exported `DuoLayoutAdapter`. `AdaptivePaneLayout` and `AdaptivePage` then consume its safe geometry; they still adapt to ordinary Flutter constraints on other devices and web. Place these layouts at the scaffold-body origin, because reserved rectangles use viewport coordinates. The app already installs the adapter once above its navigator.

`commerceComponentExamples` contains one definition per registered commerce component, with `name`, `description`, and `previewBuilder`. The component gallery consumes these definitions rather than copying their appearance. Preview interactions are local: chips switch selection, the budget slider changes its amount, the product card toggles Choose this/Remove, and the dressing room switches between an incomplete and complete outfit. Disabled controls and empty/next/filled slots remain visible for inspection.

Product cards use their own available width and text scale to switch between a thumbnail row and a vertical card. Names, amounts, reasons, and actions can wrap; they are not confined to a fixed image-height text box. Choice targets are at least 48 logical pixels high. The rack also uses pane width rather than the overall window width, and reduces columns for large text. A narrow pane on a wide screen therefore behaves like a narrow pane on a phone.

The formal wide-screen design uses a black dressing room, light budget meter, a budget above the rack, and a white next-piece badge below the image. Scope that presentation around a surface with `CommerceDressingRoomStyle(dark: true, contextImages: [...], child: surface)`. The default light presentation retains the original compact design and category-specific image heights. `contextImages` accepts screen-owned bundled occasion photographs; it does not invent weather or location data. Next and empty formal slots use the supplied local SVG assets at their original dimensions. Product photographs stay dynamic and resolve only from the bundled public catalog.

The existing nine A2UI component schemas, event names, local choice/budget updates, and legacy named dressing-room bindings remain compatible. Photo upload, fit/size, saved looks, bag quantity, weather and delivery are registered with explicit properties and event contracts; their live services require host integration. See design/README.md for those boundaries.
