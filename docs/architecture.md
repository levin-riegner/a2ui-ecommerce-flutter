# Architecture and A2UI shape

## Architecture

The sample keeps four concerns separate:

- `lib/src/data/` defines domain products, fixture repositories, and a pure Dart CSV parser shared by the app and developer tools.
- `lib/src/catalog/` defines the A2UI component vocabulary and commerce widgets.
- `lib/src/agent/` contains the bundled Genkit runtime, provider adapters, and renderer transport. Scripted agents are available for tests and previews.
- `lib/src/app.dart` owns the responsive shell, model setup, text input, and native layout around the A2UI surfaces.

The setup dialog collects a provider, model ID, API key, and an optional compatible API base URL. `GenkitAgent.connect` loads the bundled catalog and creates an isolated `StylistRuntime` and official provider plugin. Setup makes no network request. There is no service URL, server session token, or Node backend in the app.

`StylistRuntime` defines the `stylistTurn` Genkit flow and catalog search, presentation, brief-saving, and outfit-editing tools. Genkit manages native conversation history and the tool loop. Search ranks local products and caps prices at the available outfit budget, accounting for pieces released by a replacement. Presentation accepts only one to five unique IDs already returned by search, and checks the available budget again. Selection and removal validate host state before model generation; lowering the budget below already-selected spending is rejected. The host constructs commerce A2UI surfaces from authoritative catalog facts rather than accepting model-generated card facts or arbitrary markup.

Each interaction works on a draft of the conversation, seen products, outfit, budget, and turn number. Only a successful complete generation commits it. Generation is serialized per connection, limited to four provider requests and a 60-second turn deadline; the fourth generation requests prose only. Failed or cancelled turns preserve prior state and remain retryable. Starting a new journey clears the previous outfit and surfaces.

`GenkitAgent` parses the complete A2UI batch, validates component/catalog/root references, and feeds it through `A2uiTransportAdapter` into `SurfaceController`. `stylist_surfaces.dart` creates the persistent dressing-room and selected-products surfaces and a new inline recommendation surface per successful turn.

`genkit_providers.dart` configures the official Gemini, OpenAI, Anthropic, and OpenAI-compatible plugins. OpenAI uses Chat Completions with `store: false`. Real keys enter HTTP headers at the transport boundary; plugin configurations contain a placeholder. The transport validates destinations, refuses redirects, sanitizes provider failures before SDK errors/traces, and bounds provider requests. A Dart Zone carries mutable per-turn draft state outside serialized flow context. Disconnect clears the key, cancels outstanding work, disposes the owned HTTP client and Genkit runtime, and discards the session.

The same flow runs in the optional Genkit Developer UI through `tools/genkit/stylist.dart`, using a free offline model. The connected Flutter runtime disables reflection and automatic telemetry. The optional Genkit CLI is a development dependency only. Genkit Dart and its plugins are pinned because the SDK is in preview; Google/Anthropic HTTP injection currently uses their implementation classes behind one adapter.

The Flutter app runs natively and builds for web. Direct browser requests depend on provider CORS support; native apps do not require CORS. Keys must not appear in assets, source, generated bundles, saved browser state, or committed environment files.

## A2UI shape

The catalog includes the basic GenUI catalog plus a small extensible commerce vocabulary:

- `StylistMessage`
- `Eyebrow`
- `ProductCard`
- `ChoiceChip`
- `ChoiceGroup`
- `PrimaryButton`
- `PieceSlot`
- `DressingRoom`
- `BudgetSlider`

The flow is `brief → picks → complete look`. The dressing room is created once and updated through its data model. Recommendation surfaces can be replaced on each turn. This keeps the host-owned responsive shell stable while allowing the agent-generated content to evolve.

`OutfitPlan` derives the required pieces from the brief and selected foundation, following the original React PoC: formal looks start with a dress, ordinary looks use separates, and outdoor looks start with a layer and footwear. Cold-weather looks include a layer. Selecting a dress releases any selected top and bottom; selecting separates releases the dress before checking the resulting budget. Accessories are optional and selected pieces remain visible even when outside the required route.

`StylistBrief` retains occasion, dress code, season, budget, palette, and notes outside model history. Preset journeys supply their known facts. Searching requires a dress code and budget; a host-owned form gathers missing facts together, and its editors update local surface data until one explicit Find options action submits them. The model can use `save_outfit` for typed refinements, `add_to_outfit` for a verbal choice from the last presented cards, and `remove_from_outfit` for a selected product. These tools mutate only the current draft and return the refreshed host plan and budget facts.

The runtime supplies the model with the recorded outfit and the next missing category. A successful selection immediately offers that next category; removing a piece reopens its category. Once all required pieces are selected, the stylist summarizes the completed look and offers to keep or change it. The dressing-room slot list and its current-choice marker come from the same host plan. Host-calculated selection confirmations and budget amounts remain authoritative without replacing the stylist's explanation.

Regression coverage follows every bundled journey through completion and reopens a removed piece, using the real local catalog with a deterministic test model. Widget tests exercise selection buttons, dressing-room slots, and product photographs. The opt-in live test checks that Berlin starts with tops, selecting one presents bottoms, and removing it presents tops again, within three interactions and twelve provider requests. Its optional seeded-preview mode checks only the real selection continuation; network checks run separately from widget rendering.

The protocol boundary is intentionally explicit:

1. The agent emits a `CreateSurfaceMessage` with the catalog ID.
2. The agent emits `UpdateComponentsMessage` entries whose component properties bind to data paths.
3. The agent emits `UpdateDataModelMessage` values for the surface.
4. The Flutter `Surface` resolves the catalog item and renders the registered builder.
5. User actions become structured `UserActionEvent` values and are dispatched back through the transport boundary.

The persistent `dressing-room` surface owns the evolving look. Inline surfaces are versioned per turn (`inline-0`, `inline-1`, and so on) so recommendations can be replaced without losing the persistent surface state.

See [component-catalog.md](component-catalog.md) for the complete 24-component vocabulary and the extension path.
