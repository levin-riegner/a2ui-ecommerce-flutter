# Model UI catalog and public inspector

In a connected session, **Inspect** at the top right opens diagnostics in a
sheet that slides up over the right-hand pane in a split layout, or fills the
screen in a compact layout. Close the sheet, swipe it down or use Back to return.
The original dressing room and basket stay mounted underneath, retaining their
size, scroll position and quantities. Opening or closing inspection neither sends
a message nor calls a model. The sheet uses the dressing room's black background,
rounded corners and app typography. It is available to everyone.

## One catalog, explicit limits

`buildCommerceCatalog()` registers 60 components. `buildModelUiCatalog(catalog)`
copies their actual property schemas, action bindings and instructions into
immutable, renderer-independent values. Root composition gives the original
catalog to `CommerceA2uiRenderer` and the exported values to `StylistRuntime` and
`CommerceInspectorBloc`. There is no second hand-written property schema.

Every registration is visible under **Inspect → Catalog**, with use guidance and
an availability label. All 60 schemas and the shared host-action contract reach
the model instructions. Registration does not grant permission to perform an
action or make a component eligible in the live experience.

The model can currently propose these recommendation components through the
existing `present_products` tool:

| Component | Eligibility and effect |
| --- | --- |
| `ProductCard` | One to five searched products, shown as individual cards. |
| `PicksStrip` | One to five searched products, shown as a compact shortlist. |
| `ThisOrThat` | Exactly two searched products, shown as a comparison. |
| `AlternativePiece` | Exactly one replacement while adjusting a selected piece. |

The optional `component` argument chooses a real registered Flutter component;
the host binds catalog facts and known actions. It takes precedence over the
older host presentation heuristic. If omitted, that heuristic still applies and
the inspector labels the recommendation as host-selected. This is bounded model
composition, not arbitrary model-authored A2UI or arbitrary property injection.

The remaining entries are labelled **Host controlled** or **Reference only ·
gallery**. For example, basket controls, size forms, loading states and the
persistent dressing room follow validated host state. A gallery registration is
not a claim that the model can request that screen in a live turn.

Product IDs must have appeared in search. Existing audience, preference, budget,
outfit-completion and checkout rules still apply. An ineligible component fails
the turn before commit. The presenter builds the complete A2UI batch, and the
renderer validates schemas, roots and references before state/storage commit and
publication. No additional model round trip is introduced; the four-request
limit remains.

## Reading exchanges accurately

**Exchanges** shows the latest 100 events, newest first, in connection-local
memory. The inspector uses its own BLoC so toggling does not wait behind a model
request in the commerce command queue.

- **Client → host:** a submitted message or known action; message content and
  action contexts are withheld.
- **Host → model / Model → host:** structural summaries of actual decoded SDK
  requests and responses, including known tools, safe component choice and
  counts. Response entries precede validation, so a proposal is not a commit.
- **Host → model tool feedback:** actual search/presentation tool outcomes and
  counts; tool content is withheld.
- **Host validation:** eligibility of a proposed recommendation component.
- **Turn not committed:** a safe failure category, distinct from a component
  eligibility decision; exception content is withheld.
- **Host-composed surface:** a structural summary of the validated batch actually
  published to Flutter, with the committed basket count. If applicable, its title
  identifies the model-selected recommendation. The dressing room, forms, facts
  and actions remain host-composed even in that batch.

The app runs the host in Flutter and calls the provider directly. “Host → model”
does not imply a separate application server. **Connected provider**, **Injected
model**, and **Offline fixture · no provider call** identify the source. A fixture
response is not evidence of a successful paid-provider request.

This view is deliberately not a raw HTTP capture, full prompt viewer, raw model
A2UI transcript or wire replay. It reconstructs readable summaries from actual
typed events. Prompt text, user messages, model prose, free-form tool arguments,
product/context content, authentication headers and credentials cannot enter
the closed trace vocabulary. Unknown model-supplied identifiers become
`unrecognized`. Requests and responses are not persisted or exported. Canceled
late responses are checked before recording and cannot appear as new exchanges.

## Extend and verify

Register a component and its examples through the usual
[extension walkthrough](extending.md). The schema automatically reaches the
manifest; separately decide whether it should become host-controlled or a safe
model choice. A new model choice needs eligibility rules, a real presenter path,
diagnostic allowlist coverage and actual renderer validation. Do not expose
checkout authorization or free-form prices as model properties.

Run the offline contract and UI checks:

```sh
fvm flutter test test/model_ui_catalog_test.dart test/commerce_inspector_test.dart test/commerce_inspector_integration_test.dart
python3 tool/check_architecture.py
```

For a no-credential interactive build using the same runtime, catalog and
inspector, run:

```sh
fvm flutter run -d chrome -t tool/alder_online_demo.dart --dart-define=ALDER_DEMO_OFFLINE=true
```

The deterministic fixture demonstrates the tool loop and component choices; it
does not establish provider quality. See the [verification record](verification/model-catalog-inspector-2026-10-15.md)
for the tested builds, interactions and remaining limits.
