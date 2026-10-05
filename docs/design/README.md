# Finalized Figma catalog

Source: [Ecomm GenUI iPhone Duo](https://www.figma.com/design/mG3g0dRExJiLZ6oWRM4CRg/Ecomm-GenUI-iPhone-Duo?node-id=4-1125).

The Components page defines 39 families: 15 chat/input, 14 dressing-room/context,
and 10 shared. The runtime also retains the host-owned DressingRoom composition,
ChoiceGroup form control and GenUI basic components. Entries with existing names
replace their legacy renderer while retaining the journey schemas.

## Ingestion

`export/catalog.json` is generated directly from `buildCommerceCatalog()` using
GenUI's `toCapabilitiesJson()`. It contains the catalog ID, actual component JSON
schemas and client functions. Use this as the model's vocabulary.

`export/examples.json` contains the same capabilities and replayable A2UI v0.9
`createSurface` / `updateComponents` messages. These are executable examples,
not a separate approximation of the schema. Regenerate both files with:

```sh
fvm flutter test tool/export_commerce_catalog.dart
```

The in-app **Catalog components → Finalized Figma components** gallery uses
SurfaceController and Surface to render those same examples. Selecting a state
creates a fresh surface. Actions are displayed as resolved JSON; the gallery
does not connect a model or a commerce service.

## Source contracts

`finalized-left.json`, `finalized-right.json` and `finalized-shared.json` map
Figma node IDs, states, exact assets, properties, events and host responsibilities
to reusable Flutter renderers. The left source was extracted with Figma design
context. After the connector quota was reached, the user authorized exact
read-only Plugin API properties, usage notes and original asset exports for the
remaining families. No Figma nodes were edited.

Static SVGs retain their exported geometry. Four screen photos are exported
original image bytes with Figma image-hash verification; the original Start
collage already matches the bundled photos. Jost and Inter are bundled locally.
Product images in real journeys remain the approved catalog assets.

## Behavior boundaries

The production journey preserves local brief changes until submission,
selected outfit/budget accounting and explicit select/remove events. Change on a
filled piece requests affordable alternatives while keeping the current outfit
until a replacement is selected. This browsing turn cannot mutate the outfit.

The additional catalog events are explicit integration contracts. Camera/photo
selection, voice capture, saved-look persistence, checkout, stock, delivery,
weather and geocoding require a host integration; preview fixtures are not live
services. Do not infer service availability from a successful fixture action.

Copied product names, photos and spending values in some Figma screen examples
conflict with their visible brief. Source discrepancies are recorded in the
screen manifest. Executable fixtures retain consistent money and outfit state.
