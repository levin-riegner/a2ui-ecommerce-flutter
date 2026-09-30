# Architecture and A2UI shape

## Architecture

The sample keeps five concerns separate:

- `lib/src/data/` defines `ProductRepository`, deterministic fixture data, and a searchable local CSV catalog adapter.
- `lib/src/catalog/` defines the A2UI catalog vocabulary and Flutter widgets for commerce-specific components.
- `lib/src/agent/` contains the required remote transport and a scripted agent for tests and previews.
- `agent-service/` contains the model tool loop and catalog search over the same sanitized CSV.
- `lib/src/app.dart` owns the responsive host shell, text input, and native layout decisions around the A2UI surfaces.

`ProductRepository` provides catalog reads for test fixtures and previews. Production stylist journeys require `AGENT_SERVICE_URL`; the app creates only `RemoteAgent` from that configuration. Missing or invalid configuration disables journeys, while the component gallery stays available. The host displays pending turns and connection errors, disables interactions until a turn completes, and retries failed requests without substituting fixtures. `RemoteAgent` sends chat and surface actions to `/v1/turn`, retains the server session ID, parses A2UI envelopes, and feeds them to the same `SurfaceController`. Keep service credentials, tokens, and provider-specific configuration on a trusted server or in a local development secret store. Never put them in Flutter assets, source code, generated web bundles, or committed environment files.

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

The protocol boundary is intentionally explicit:

1. The agent emits a `CreateSurfaceMessage` with the catalog ID.
2. The agent emits `UpdateComponentsMessage` entries whose component properties bind to data paths.
3. The agent emits `UpdateDataModelMessage` values for the surface.
4. The Flutter `Surface` resolves the catalog item and renders the registered builder.
5. User actions become structured `UserActionEvent` values and are dispatched back through the transport boundary.

The persistent `dressing-room` surface owns the evolving look. Inline surfaces are versioned per turn (`inline-0`, `inline-1`, and so on) so recommendations can be replaced without losing the persistent surface state.

See [component-catalog.md](component-catalog.md) for the complete 24-component vocabulary and the extension path.
