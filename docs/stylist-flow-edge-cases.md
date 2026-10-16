# Stylist flow edge cases

Host behavior and regression coverage for styling, recovery and user actions.

## Architecture rules

Keep the current architecture: Flutter shell → `CommerceSession` / `GenkitAgent` → typed commands and `StylistRuntime` / Genkit tools → immutable `StylistTurnResult` / `StylistViewState` → presenter → host-authored A2UI → GenUI catalog widgets → structured events. Schemas and bindings remain in `*_a2ui.dart`; reusable widgets stay renderer-independent. The model supplies styling guidance and constrained tool requests. The host owns product identity, accepted brief facts, money, variants, mutation validation, cancellation, persistence and UI publication.

Use the existing inline `ChoiceChip`, `ColourPicker`, `FitSize`, `PrimaryButton`, `QuickAdjust` and product components. Do not introduce a size dialog, a second chat engine, a classifier request or a parallel product-state store.

The official [GenUI input and events guide](https://docs.flutter.dev/ai/genui/input-events) describes the event envelope (`surfaceId`, `sourceComponentId`, action name and context). `Surface` attaches the surface ID; catalog components must preserve authored action context. The app also stamps a private chat generation into authored events. The adapter validates and removes it before passing domain actions to the runtime. This is a freshness guard for native events, not an authentication mechanism. Source-less programmatic actions remain the trusted host/test API.

[GenUI component bindings](https://docs.flutter.dev/ai/genui/components) use per-surface observable data. Size/fit selection stays in that surface's data model until its existing Save action commits. Do not copy these drafts into another widget's global state.

[Genkit Dart generation and cancellation](https://genkit.dev/docs/dart/models/) supports cooperative cancellation. Our pinned `genkit` 1.0.0 exposes `CancellationController`, `CancellationToken.whenCancelled` and `CancelledException`. Cancelling cannot force an uncooperative provider future to finish. The runtime races draft generation against cancellation, then rejects late work through the draft's token and the agent epoch. Persistence writes and rollback remain serialized outside that race.

The online docs evolve faster than our pins: `genui` 0.10.3, `a2ui_core` 0.1.1, Genkit/provider plugins/Schemantic 1.0.0. Verify signatures against those installed sources. The newer [full-agent run/session APIs](https://genkit.dev/docs/dart/agents/run/) are not a reason to migrate the existing `stylistTurn` flow during a UX fix.

## Flow matrix

| Trigger or failure | Required behavior | Evidence |
| --- | --- | --- |
| “I changed my mind” without a target | Keep the current look and offer inline change-piece choices plus Start a new look. | `stylist_flow_edges_test.dart` |
| Change the selected dress or shoes | Validate the currently selected category/product; retain it until a valid replacement is accepted. | `stylist_library_test.dart`, `stylist_component_adoption_test.dart` |
| Explicit restart, including during generation | Cancel/supersede the pending turn, persist a blank working look, then clear chat surfaces and show the welcome screen. No model request is needed for the reset. | `stylist_flow_edges_test.dart` |
| Restart with a replacement brief | Clear previous outfit constraints and conversation context before processing the new brief. Negated/quoted restart wording must not erase the look. | `stylist_flow_edges_test.dart` |
| Provider ignores cancellation, then fails late | Restart completes without waiting for the provider; late work cannot publish or commit. | `stylist_flow_edges_test.dart` |
| Restart storage write fails | Keep the existing working look, stored snapshot and usable controls; show the existing recoverable error. | `stylist_flow_edges_test.dart` |
| Old native tap arrives after restart and IDs are reused | Reject the previous chat generation, including events from the stable dressing-room surface. Cancellation epochs and committed UI generations are separate. | `stylist_flow_edges_test.dart`, `progressive_agent_test.dart` |
| User returns to old chat content | Retain readable history, disable historical controls, reject old inline surface IDs at transport. | `conversation_history_test.dart`, `progressive_agent_test.dart` |
| Selected dress requires options while shoes are next | Show a named dress sizing step; defer visible shoe recommendations until the step completes. Do not stream shoe prose into the sizing step. Retain validated next choices in runtime state. | `stylist_flow_edges_test.dart`, `stylist_product_options_test.dart` |
| Shoe sizing | Show available size choices and Save size; do not require Fitted/Regular/Relaxed or overwrite clothing fit. | `stylist_flow_edges_test.dart` |
| Clothing sizing | Show available sizes and fit choices; enable the single Save size & fit action only when both are valid. | `stylist_product_options_test.dart`, `finalized_left_components_test.dart` |
| “What sizes are the shoes?” while only a dress is selected | Resolve the named category; never fall back to the unrelated dress. If several products remain ambiguous, do not choose an arbitrary editor. | `stylist_flow_edges_test.dart` |
| Colour changes available sizes | Resolve the linked catalog product and its own available sizes; reject unrelated colours and invalid size combinations. | `stylist_product_options_test.dart` |
| New look after saving/adding to bag | Reset the working conversation, retain saved looks, bag and usual-size preferences; keep library access on the welcome screen. | `stylist_flow_edges_test.dart`, `stylist_library_test.dart` |
| Budget reduction makes current outfit invalid | Preserve selected pieces as visible conflicts; block invalid completion and offer host-controlled recovery. | `stylist_recovery_test.dart`, `stylist_budget_weather_recovery_test.dart` |
| Hard restriction or audience correction conflicts with picks | Revalidate search, fallback, selection and completion; retain conflicts until explicitly resolved. | `stylist_constraints_test.dart`, `stylist_gender_test.dart` |
| User owns or removes a required category | Recalculate the plan and budget without reintroducing owned pieces. | `outfit_plan_test.dart`, `stylist_component_adoption_test.dart` |
| No matching catalog products / failed weather request | Preserve hard constraints, distinguish optional-filter fallback, allow styling to continue without invented weather. | `stylist_budget_weather_recovery_test.dart`, `stylist_constraints_test.dart` |
| Invalid size, unavailable stock, changed checkout quote | Reject and roll back atomically; keep working look and stored state coherent. | `product_data_demo_commerce_test.dart`, `stylist_library_test.dart` |
| Fold, keyboard, large text or history scroll | Preserve draft, focus and scroll; respect reduced motion and keep the last content reachable above the composer. | `adaptive_screen_layout_test.dart`, `conversation_history_test.dart`, `duo_layout_adapter_test.dart` |

## Regression coverage

The listed tests use deterministic models and the real GenUI/catalog renderer.
They cover cancellation, errors and rollback; they do not verify provider availability
or merchant inventory. Extend these tests when adding new commands or language cases.
`stylist_review_regressions_test.dart` also covers exhausted-product eligibility,
material questions, stock metadata and cent-accurate colour affordability.
