# API and A2UI contracts

Alder exposes Dart libraries and an in-process Genkit flow. It does not ship an HTTP application API. This reference describes the current extension boundaries; [architecture](architecture.md) explains ownership and [Genkit reference](genkit-reference.md) covers provider transport.

## Dart entry points

| Import | Intended use |
| --- | --- |
| `package:a2ui_flutter_commerce/commerce_ui.dart` | Reusable Flutter widgets, themes/layouts and explicit-value callbacks; no transitive BLoC, GenUI, Genkit or runtime dependency. |
| `package:a2ui_flutter_commerce/commerce_a2ui.dart` | Catalog registrations, bound-data adapters and schema/example serialization. |
| `package:a2ui_flutter_commerce/commerce_gallery.dart` | Optional examples, component/screen galleries and inspector UI. |

The package is an application with `publish_to: none`. These imports document reuse within a checkout or path dependency; they do not promise a published pub.dev package or versioned SDK stability.

`buildCommerceCatalog()` is the registration source. `buildModelUiCatalog(catalog)` copies its actual property schemas into immutable domain values, with guidance and availability. `export/catalog.json` and `export/examples.json` are generated snapshots; regenerate with `fvm flutter test tool/export_commerce_catalog.dart`. See [the design ingestion guide](design/README.md).

## Composition and session lifetime

[`StylistDependencies`](../lib/util/stylist_dependencies.dart) accepts a `CatalogSource`, provider factory, optional `StylistStore` and weather-source factory. Its `defaults()` constructor assembles bundled CSV loading, Genkit providers, local preferences storage and optional Open-Meteo integration. `connect(ModelSettings)` loads a validated snapshot and builds a `StylistBloc`, repository, runtime, renderer and inspector for that connection.

[`CommerceSession`](../lib/presentation/stylist/bloc/commerce_session.dart) is the BLoC-based shell contract. Shells receive a `StylistConnectionFactory`; accepted sessions belong to the app. `SessionConnection` disposes results arriving after canceled setup. Provider, renderer and subscription handles remain owned resources outside immutable state. Dispose/close the session when its owner ends the connection.

Use constructor injection for a different catalog, storage or weather service. Keep platform defaults in `lib/util/`; do not put credentials in the dependency registry or BLoC state. [Extending the reference](extending.md) walks through each boundary.

## Turn input and result

[`StylistRuntime.turn`](../lib/data/stylist/service/runtime/stylist_runtime.dart) accepts a map validated by `StylistTurnInput.decode` and the shared [schemas](../lib/data/stylist/model/stylist_schemas.dart). Supply a message, a structured action, or both. Unknown top-level keys are rejected and an empty input is invalid.

```json
{"message":"A casual outfit with a whole-outfit budget of €500"}
```

```json
{"action":{"name":"select_product","context":{"productId":"demo-0001"}}}
```

The product ID is an illustrative schema value, not an instruction to bypass recommendation eligibility. Selection still requires an admissible presented product and current host facts.

Optional turn callbacks carry progress, provisional text, outfit previews and result validation outside serialized flow input. The returned [`StylistTurnResult`](../lib/data/stylist/model/stylist_result.dart) has immutable typed fields and `toJson()`/read-only map access:

| Field | Meaning |
| --- | --- |
| `reply`, optional `intent` | Approved reply and response mode. |
| `products` | Catalog-backed recommendation facts. |
| `brief`, `missingFields`, `constraints` | Accepted styling facts, missing intake and retained restrictions. |
| `outfit` | Whole-outfit budget and selected product IDs by category. |
| `catalog` | Revision, EUR currency, complete-snapshot flag and capability declarations. |
| Typed `view` | Renderer-independent plan and presentation intent; adapted explicitly into A2UI. |

`view` is a typed Dart property, not part of the result's JSON map. Result objects contain no live provider or GenUI handles. Product facts are structured text/JSON, including local image paths and labelled derived attributes; image pixels are not sent as conversation input.

## Model tools

The runtime registers seven tools. Each has a closed input schema and a success/error output schema; schema validity is followed by host validation.

| Tool | Input and host behavior |
| --- | --- |
| `respond_to_question` | `intent` (`capabilities` or `styling_advice`) and exact current-message `facts` quotes, maximum seven. Must run before search/edit; answers without advancing the outfit. |
| `search_products` | Required `query`; optional category, color, occasion, season, audience, `priceMax` and `limit` (1–12). Local matching enforces retained facts and the available next-category budget. |
| `present_products` | One to five unique `productIds` already returned by search; optional registered live `component`. Rechecks price, restrictions, audience, presentation eligibility and completion feasibility. |
| `save_outfit` | Partial brief: occasion/evidence, dress code, season, palette, notes, city, audience, positive EUR budget and ISO trip dates. Suggestions cannot overwrite explicit accepted user facts. |
| `add_to_outfit` | `productId`; validates a verbal choice against the last presented products and current outfit. |
| `remove_from_outfit` | `productId`; removes a selected piece in the current draft. |
| `apply_outfit_changes` | Optional `brief`, unique `clearFields`, `removeProductIds` and `addProductIds` (up to seven each). Validates the resulting draft atomically. |

Tool failures return corrective `error`/`code` values and, when relevant, missing fields or clarification requests. A rejected proposal is not committed commerce state. Use [the model inspector](model-ui-inspector.md) to follow decoded exchanges, validation and actual published surfaces.

## Host action vocabulary

[`StylistCommandKind`](../lib/data/stylist/model/stylist_command.dart) defines stable wire names. The shared `stylistCommandContexts` map is the exact payload authority: both the envelope and each context reject unknown fields.

| Actions | Context |
| --- | --- |
| `resume_session`, `open_saved_looks`, `save_look`, `reset_look`, `open_bag`, `close_bag`, `add_look_to_bag`, `undo_bag_changes`, `edit_preferences`, `compare_products`, `refresh_city_context` | Empty object. |
| `select_product`, `remove_product`, `remove_bag_item`, `open_product_details` | Required `productId`. |
| `restore_look`, `delete_look` | Required `lookId`. |
| `change_bag_quantity`, `restore_bag_item` | `productId` and integer `quantity` from 1 to 99. |
| `find_options` | Optional dress code, season, positive EUR budget and canonical audience; retained facts must still be sufficient to search. |
| `update_budget` | Required positive EUR `budget`. |
| `adjust_piece` | Required category; optional product ID and adjustment text, maximum 120 characters. |
| `update_preferences`, `set_colours`, `set_brand_preferences` | Optional `colours`, `love`, `skip`, category-keyed boolean `owned`, and trip-date strings. Domain validation checks actual values/dates. |
| `set_fit_size` | Required product ID and size; optional fit. |
| `choose_product_colour` | Required product ID and colour; optional colours list. |
| `set_product_options` | Required product ID and size; optional colour product ID and fit. |
| `preview_demo_checkout`, `open_demo_receipt` | Empty object. |
| `confirm_demo_checkout` | Required current host `quoteKey`. |

These are host UI commands, not additional model tools. Registration does not grant a model checkout authority. Some commands make deterministic local updates; others continue the model turn. See [demo commerce](product-data-and-demo-commerce.md) for fictional variants, stock, quote invalidation and simulated receipts.

## A2UI publication and actions

The presenter converts `StylistViewState` into approved A2UI v0.9 messages:

1. `CreateSurfaceMessage` establishes a surface with the catalog ID.
2. `UpdateComponentsMessage` declares component IDs and properties/bindings.
3. `UpdateDataModelMessage` supplies the bound values.
4. GenUI `Surface` resolves registered builders into the same reusable Flutter widgets.
5. `UserActionEvent` carries a structured action back through the renderer/session boundary.

The persistent `dressing-room` surface follows the host outfit. Versioned inline surfaces retain completed conversation history; only the current eligible surface accepts actions. Loading/provisional prose has no actions. Local choice and slider bindings edit surface drafts without provider calls until an explicit submit action.

Of 60 registered components, the model can choose four through `present_products.component`: `ProductCard` (1–5 products), `PicksStrip` (1–5), `ThisOrThat` (exactly two) and `AlternativePiece` (one replacement during adjustment). Other registrations are host-controlled or gallery references. The model proposes the component and IDs; the host supplies prices, properties and actions. See [component catalog](component-catalog.md) for bindings and legacy compatibility.

## Safety and failure contract

Each turn is serial and transactional: copied conversation, brief, outfit and seen IDs commit only after model completion and presentation validation. The host caps a turn at four provider requests and 60 seconds. Cancellation invalidates late responses; failure removes provisional content and retains the previous committed look. Retry is explicit and does not duplicate the submitted user message. There is no automatic paid retry or scripted production fallback.

Money arithmetic uses integer cents. Catalog identity, user fact provenance, restrictions and checkout validation remain host-owned. The local version-1 snapshot retains validated catalog IDs/preferences/demo state, excluding credentials and conversation payloads. This is local demo persistence, not a real order database.

When extending a contract, change its shared schema, decoder, tool/handler, presenter and focused tests together. Run the checks in [CONTRIBUTING.md](../CONTRIBUTING.md), including `python3 tool/check_architecture.py`; provider wire fixtures and real renderer tests cover different boundaries.
