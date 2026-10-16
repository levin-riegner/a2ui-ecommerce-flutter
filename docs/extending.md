# Extending the reference

Follow the [pinned Levin+Riegner Flutter template map](flutter-template.md) and [architecture](architecture.md): feature BLoCs own presentation events/state, repositories coordinate data, services decode external representations, and constructors receive dependencies from the app root. Keep commerce validation in the host runtime and live GenUI resources in the renderer adapter.

## Add a catalog source

1. Implement the `CatalogSource.load()` port from `lib/data/catalog/model/catalog_snapshot.dart`. Return a complete `CatalogSnapshot` with stable product IDs, a source-supplied revision, EUR currency and honest capability flags.
2. Put transport access and external DTOs under `lib/data/catalog/service/`. Map DTOs to domain values at the repository boundary; the CSV path uses `CsvCatalogService`, `CatalogCsvDto` and `CsvCatalogSource`. `CatalogRepository` shares a validated snapshot across load/search calls.
3. Inject the source/repository through `StylistDependencies` in `lib/util/stylist_dependencies.dart`; leave native asset loading at that composition boundary. Runtime and preview repositories must share query policy rather than independently implementing filters.
4. Keep importer tolerance separate from connected validation. A connected snapshot rejects duplicate/invalid IDs, malformed rows and invalid prices. CSV prices must use `price_eur`, or a generic `price` column with explicit `currency=EUR`; non-EUR declarations are rejected. Missing stock/sizes must not become invented availability.
5. Verify a fake source through the real composition path. Confirm search/presentation/selection use that snapshot and that failed connection setup releases owned resources without making a paid request.

Preview queries require every query word and preserve source order. Conversational queries rank any matching word. Both share `lib/data/catalog/repository/catalog_search.dart` facets, audience checks and cent-accurate caps; their query policies are explicit.

Catalog prices and identities remain authoritative. `productFacts()` adds labelled host-derived styling classifications for model tools, not supplier claims. Currency calculations convert each amount to integer cents through `lib/data/catalog/model/money.dart`; do not sum or multiply raw price doubles.

## Add a host command or tool

1. Add its stable wire name to `StylistCommandKind` in `lib/data/stylist/model/stylist_command.dart`. Validate context through the shared declarative schema in `stylist_schemas.dart`, then decode it through `StylistCommand`. Unknown names and malformed values must fail before mutation.
2. Expose the corresponding tool schema from those shared schemas. Keep required fields, limits and additional-property policy consistent with the host decoder. Tool errors are structured results, not prose that a caller must parse.
3. Apply the command to the draft in `lib/data/stylist/service/runtime/stylist_runtime.dart`. Preserve explicit-user provenance and catalog restrictions. Failed/cancelled turns retain the committed outfit, library and surfaces.
4. Return `StylistTurnResult`/`StylistViewState`. Only `presentStylistResult` in `lib/presentation/stylist/a2ui/stylist_presenter.dart` converts that result to A2UI. It returns detached mutable JSON for bound surface drafts; renderer edits must not mutate the immutable domain result.
5. Dispatch presentation intent through `StylistEvent` and `StylistBloc`; keep budget calculations and commerce decisions out of widgets and BLoC state setters. `StylistRepository` owns runtime/provider lifetime. The presenter/batch validator must approve the result through the validation callback before the runtime commits it; a later UI listener is too late.
6. Test valid input, malformed/unknown input and rollback. Reuse field schemas for tools and surface actions, route both through domain validation, and test numeric boundaries/negation/corrections when accepted preferences change.

Use existing host commands for local library/bag/weather actions. Deterministic local operations need not make a model request. Preserve serial event processing, cancellation epochs and stale-surface guards when introducing asynchronous work.

## Add a reusable component

1. Put the widget under `lib/presentation/shared/design_system/views/commerce/`. Accept explicit values and callbacks; import no BLoC, GenUI, Genkit, repository or runtime classes.
2. Put its `CatalogItem`, schema, bound-data readers and event translation under `lib/presentation/stylist/a2ui/catalog/` in `*_a2ui.dart`. Register it in `buildCommerceCatalog()`. Reuse the widget rather than building a second renderer.
3. Export the widget from `commerce_ui.dart`, the registration from `commerce_a2ui.dart`, and optional examples/inspection screens from `commerce_gallery.dart`.
4. Put fixed presentation strings in `lib/app/l10n/app_en.arb`; consume `context.l10n`. Do not translate product facts, model responses or IDs by treating them as localization keys. Domain code must not import Flutter localization.
5. Test observable widget behavior and replay the adapter through the real `SurfaceController`. Disabled/historical controls must reject pointer, keyboard and accessibility actions.
6. Regenerate vocabulary/examples with `fvm flutter test tool/export_commerce_catalog.dart` when schemas/examples change. Update relevant design/export documentation, then run the import guard.

The production composition exports all registrations into the model instructions and public inspector from the same catalog instance. A registration is not automatically a live model choice: assign honest availability and guidance in `model_catalog.dart`, and add eligibility, presenter and diagnostic coverage before extending `present_products.component`. See [the model catalog and inspector guide](model-ui-inspector.md). The host still composes and validates A2UI; structural summaries are not raw model output.

## Add presentation state, routes or fixed copy

Use feature `BlocProvider`, builders/listeners and immutable state under `lib/presentation/`. The stylist feature uses Freezed events/state; connection state uses Equatable. Keep controllers, provider handles, completion objects and credentials outside state. Preserve redacted event/state diagnostics when changing generated classes.

Register dependencies in the app-owned `Dependencies`/`StylistDependencies` composition, then inject constructors. Do not call `get_it` from reusable widgets or domain models. Add typed routes in `lib/app/navigation/router/app_router.dart`; route data must not carry live sessions or secrets.

Run `fvm flutter gen-l10n` after ARB changes and `fvm dart run build_runner build` after generated state/events/routes change. Include generated outputs in the same change. Existing immutable domain classes can stay hand-written.

## Add a different shell or renderer

`CommerceSession` is the BLoC-based connection/session command contract. The app accepts an injected `StylistConnectionFactory` and owns accepted-session disposal. `SessionConnection` disposes results that arrive after canceled setup; credentials remain transient and redacted.

GenUI-specific handles live in `CommerceAgent` and `CommerceA2uiRenderer`. A different renderer consumes `StylistTurnResult` without parsing A2UI back into domain state. Keep posture, dictation, focus, scrolling and animation in presentation adapters/widgets. Preserve Duo orientation and pane behavior rather than copying the template's portrait-only startup.

## Check the boundaries

`python3 tool/check_architecture.py` walks imports, exports, parts and conditional alternatives. It checks public widgets/catalog registrations transitively, discovers domain model files, protects explicit pure ports/query policy, rejects reverse data-to-presentation/composition dependencies and keeps concrete platform/renderer adapters outside the runtime.

Schemantic is a pure declarative wire-validation dependency shared by commands/tools. Genkit is an intentional runtime/provider-service dependency; neither makes it acceptable to import a provider or renderer SDK into domain models. Run the relevant offline checks from [CONTRIBUTING.md](../CONTRIBUTING.md), and verify native behavior separately when platform dependencies change.
