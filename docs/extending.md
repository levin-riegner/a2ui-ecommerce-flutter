# Extending the reference

The app uses a small custom architecture aligned with Flutter's [architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) and [Compass case study](https://docs.flutter.dev/app-architecture/case-study). It keeps Flutter's ChangeNotifier model and constructor injection. Adopting another scaffold or state-management library is not required to add a source, tool or widget.

## Add a catalog source

1. Implement `CatalogSource.load()` in `lib/src/data/catalog_snapshot.dart` or a new source adapter. Return a complete `CatalogSnapshot` with stable product IDs, a source-supplied revision, EUR currency and honest capability flags.
2. Inject it into `StylistDependencies`; leave native asset loading in `app_dependencies.dart`. The connected runtime and fixture repositories must use the shared catalog query policy, not independent filtering logic.
3. Keep importer tolerance separate from connected validation. A connected snapshot rejects duplicate/invalid IDs, malformed rows and invalid prices. CSV prices must use `price_eur`, or a generic `price` column with an explicit `currency=EUR`; non-EUR declarations are rejected. Do not silently treat omitted stock or sizes as known availability.
4. Verify the alternate source with a fake source and the real composition path. Confirm search/presentation/selection use that snapshot and that a failed load releases owned connection resources without a paid request.

Preview queries require every query word and preserve source order. Conversational queries rank any matching word. Both policies share `data/catalog_search.dart` facets, audience checks and cent-accurate caps; their query policies are explicit.

Catalog prices and identities remain authoritative. `productFacts()` adds labelled host-derived styling classifications for model tools. Those heuristics are not supplier claims. Currency calculations convert each amount to integer cents through `data/money.dart`; do not sum or multiply raw price doubles.

## Add a host command or tool

1. Add its stable wire name to `StylistCommandKind`, validate its context in the shared command schema and decode it through `StylistCommand`. Unknown names and malformed values fail before mutation.
2. Expose the corresponding tool schema from `stylist_schemas.dart`. Keep required fields, limits and additional-property policy consistent with the host decoder. Tool errors are structured results, not prose that a caller must parse.
3. Apply the command to the runtime draft. Preserve explicit-user provenance and catalog restrictions. A failed/cancelled turn must retain the committed outfit, library and surfaces.
4. Return a `StylistTurnResult`/`StylistViewState`. Only `presentStylistResult` converts that result into A2UI; the runtime does not render widgets or wire surfaces. The presenter returns a detached mutable JSON graph for GenUI-bound drafts. Renderer edits must never mutate the immutable domain result.
5. Add focused cases for valid input, malformed/unknown input and rollback. Reuse shared field schemas for tools and surface actions, and route both paths through the same domain validation. Test numeric boundaries and negation/corrections when accepted preferences change.

Use existing host commands for local library/bag/weather actions. Do not route deterministic local operations through a model merely to reuse the tool loop.

## Add a reusable component

1. Put the widget in a presentation file such as `finalized_left_components.dart`. Accept explicit values and callbacks; import no GenUI, Genkit or runtime classes.
2. Put its `CatalogItem`, schema, bound-data readers and event translation in `*_a2ui.dart`. Register it in `buildCommerceCatalog()`. Reuse the widget; do not build a second renderer.
3. Export the widget from `commerce_ui.dart`, the registration from `commerce_a2ui.dart`, and optional examples/inspection screens through `commerce_gallery.dart`.
4. Test the widget's observable behavior and replay the adapter through the real `SurfaceController`. Disabled and historical controls must reject pointer, keyboard and accessibility actions.
5. Regenerate vocabulary/examples with `fvm flutter test tool/export_commerce_catalog.dart` when catalog schemas/examples change. Update relevant design/export documentation, then run `python3 tool/check_architecture.py`.

The import guard walks transitive imports and exports, including conditional alternatives. A widget cannot hide an SDK dependency behind a helper or barrel export. Domain contracts cannot pull in Flutter, provider or storage adapters. Genkit remains an intentional orchestration dependency of `StylistRuntime`; it is not a widget or domain-value dependency.

## Add a different shell or renderer

Use `CommerceSession` for connection state and text/session commands. The app receives a `StylistConnectionFactory` and owns accepted-session disposal. GenUI-specific surfaces live in `CommerceAgent` and renderer widgets. A different renderer consumes `StylistTurnResult`; it does not parse A2UI back into domain state. Keep native posture/dictation adapters outside domain logic.
