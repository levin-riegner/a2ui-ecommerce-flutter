# Genkit 1.0 implementation reference

This is the integration contract for implementers and coding agents working on
Alder. The reference pins `genkit`, `genkit_openai`, `genkit_anthropic`,
`genkit_google_genai`, and `schemantic` to **1.0.0**. Its lockfile resolves
`dotprompt` 2.0.0. Genkit 0.17.0 was the preceding non-prerelease version.
Flutter remains pinned by `.fvmrc`; unrelated GenUI/A2UI packages are unchanged.

## Start with these files

| File | Responsibility |
| --- | --- |
| [`genkit_providers.dart`](../lib/src/agent/genkit_providers.dart) | Public provider factories, model invocation, HTTP ownership, credentials and provider compatibility |
| [`stylist_runtime.dart`](../lib/src/agent/stylist_runtime.dart) | Flow, tools, host validation, conversation history, request limits and transactional state |
| [`app_dependencies.dart`](../lib/src/app_dependencies.dart) | Catalog/provider/weather/store composition and injected connection factory |
| [`genkit_agent.dart`](../lib/src/agent/genkit_agent.dart) | Session lifecycle and validated A2UI delivery to Flutter |
| [`stylist_result.dart`](../lib/src/agent/stylist_result.dart) | Typed domain result and renderer-independent view state |
| [`stylist_presenter.dart`](../lib/src/agent/stylist_presenter.dart) | Explicit domain-to-A2UI conversion before batch validation |
| [`genkit_providers_test.dart`](../test/genkit_providers_test.dart) | Real plugins exercised through mocked HTTP, including provider wire formats |
| [`stylist_runtime_test.dart`](../test/stylist_runtime_test.dart) | Host policy, rollback, cancellation, explicit retries and tool-loop limits |
| [`stylist.dart`](../tools/genkit/stylist.dart) | Offline flow entry point for the optional Developer UI |

## Public APIs and request flow

1. `GenkitProvider` creates the official `openAI(...)`, `anthropic(...)`, or
   `googleAI(...)` plugin with a placeholder key. `plugin.model(modelId)` resolves
   a public `Model` without listing remote models or making a setup request.
2. Its public `Model` wrapper forwards cancellation, context and requested chunks
   to the official model. It contains the provider-specific configuration and
   compatibility handling. The runtime receives this model directly; it does not
   look up private implementation classes or registry internals.
3. `StylistRuntime` registers its host-policy model with `ai.defineModel`, its
   tools with `ai.defineTool`, and the turn with `ai.defineFlow`. `ai.generate`
   owns conversation/tool iteration, with the host wrapper enforcing admissible
   tools, complete responses, four provider calls and cancellation.
4. `ModelRequest` is still mutable in 1.0. The host copies it before changing its
   typed `tools`, `toolChoice` and `messages` fields. Use `ToolChoice.required`,
   `ToolChoice.none` and `ToolChoice.auto`; do not use the old `'any'` string.
   Each plugin translates these to its provider's wire representation, including
   omitting tool choice when there are no declared tools.
5. Tools return `ToolResult.response(...)`. Tool schemas use
   `SchemanticType.from(jsonSchema: ..., parse: ...)` with plain JSON Schema maps.
   The app does not generate Schemantic classes. `json_schema_builder` remains
   necessary for the separate GenUI catalog and must not be removed merely
   because Genkit no longer uses it for generated schemas.
6. The runtime reads `GenerateResult.text`, `.messages` and `.finishReason`.
   Results/chunks are read-only views. Keep mutable outfit and budget state in
   the host's draft, committing only after the whole turn succeeds.

The production connection is assembled by `StylistDependencies.connect` in
`app_dependencies.dart` (`connectStylist` is a developer convenience). Supply
`providerModel: connection.model`, `onBeginTurn: connection.beginTurn` and
`onCancelTurn: connection.cancelTurn` to `StylistRuntime`. Close the connection
and runtime together. `model:` is the deterministic test/offline callback;
connected production requests use the cancellation-aware `providerModel:` path.

The model can call `respond_to_question` first to classify capability questions
or general styling advice. Its structured input includes the intent and exact
quotes of any explicitly supplied outfit facts. The host rejects quotes absent
from the current message, restores the prior brief, and applies only those
quoted facts. This response mode suppresses searches, intake controls and fixed
follow-up prose while preserving selected pieces and the last presented IDs.
It uses the existing four-request tool loop rather than a separate classifier.

Occasion saves require `occasionEvidence` from the current message. The host
also retains explicit event phrases such as "for my graduation"; it no longer
treats arbitrary first messages as occasions. Schema and quote checks establish
shape and grounding, but semantic interpretation still needs conversation tests.

## Transport and credentials

OpenAI and Anthropic expose a public `httpClient:` parameter. The caller owns an
injected client. The connection closes its own default client on disconnect but
leaves externally supplied clients for their caller to close.

Google's 1.0 public `googleAI` factory does **not** expose `httpClient:`. Each
Google model invocation is therefore enclosed in the documented
[`http.runWithClient`](https://pub.dev/documentation/http/1.6.0/http/runWithClient.html)
scope. Its client factory returns a fresh non-closing wrapper over the
connection's transport. Plugin cleanup cannot close the shared connection.
The scope covers the invoked asynchronous operation, not the widget tree or
future Flutter callbacks: Flutter does not guarantee a callback's Zone.
This depends on the pinned plugin constructing its clients with `http.Client()`;
recheck that assumption and the provider tests when upgrading it. Prefer a
public `httpClient:` argument if a later Google plugin supplies one.

Only the transport inserts real keys. It validates destination origin and path,
rejects redirects, removes credential query parameters, creates an abortable
request and sanitizes failures before they reach the SDK. Do not put real keys
in model configuration, flow inputs, trace context, assets or persistent state.
Connection setup is network-free; model discovery is deliberately not called.

OpenAI's `store: false` is enforced at this boundary because the pinned plugin's
Chat Completions options do not expose it. The Luna tool-call configuration uses
the public `OpenAIChatOptions(reasoningEffort: 'none')` schema, not a raw request
rewrite. Other models and compatible hosts do not inherit that setting.

## Retries and cancellation

Genkit 1.0 **registers** its built-in retry middleware; it does not apply it to
every generation. Retry execution is opt-in via `use: [retry(...)]`. Alder
explicitly uses `use: const []`: a failed turn rolls back and the user may retry.
Do not silently add model/tool retries; they alter request budgets and can replay
state-changing tools. If a different application needs automatic retry, define
its idempotency and call budget first and use Genkit's public `retry` API with
`Duration` delays, `StatusCode` values and `noRetryModel`, not `RetryPlugin`.

The turn's `CancellationController` token reaches `ai.generate` and the provider
model call. The connection also aborts HTTP when a turn is cancelled or the
connection is closed. The runtime rejects late responses and discards the draft.
The 60-second turn deadline and four-request cap remain host policy; SDK retries
must never silently expand them.

## Remaining upstream exception

The published `genkit_openai` 1.0.0 non-streaming converter passes the SDK enum's
`.name` (`toolCalls`) to a mapping expecting `tool_calls`. The narrow
`_normalizeResponse` adapter accepts only an unknown finish reason accompanied
by real tool requests and raw `choices[0].finish_reason == 'tool_calls'`.
Length-limited, blocked or arbitrary unknown responses remain failures. Both
OpenAI and compatible-host tool journeys exercise this exception. Remove it
only after verifying a newer plugin handles the wire response itself. Do not
generalize it to treat every unknown finish reason as success.

## Validation and extension rules

Run from the repository root:

```sh
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/genkit_providers_test.dart test/stylist_runtime_test.dart
fvm flutter test
fvm flutter build apk --debug
fvm flutter build web
```

Provider tests run the actual pinned SDK converters against simulated HTTP.
They check forced search/presentation, prose-only completion, headers, redaction,
redirect handling, errors without automatic retries, cancellation, recovery,
client ownership and finish-reason rejection. Full-suite tests additionally
cover progressive surfaces, state isolation, rollback and complete journeys.
These checks do not prove live provider availability or device behavior.

For a new provider or a future SDK upgrade, preserve these invariants and add
provider wire fixtures to the existing tests. Use stable public imports; avoid
`src/` imports, test-only APIs, experimental agent/session APIs, and deprecated
members. Keep the Genkit stack coordinated in the manifest and lockfile. Inspect
the shipped package source when hosted documentation is older than the release.
Never edit cached packages to make this app pass.

The optional live smoke test is documented in the README and requires explicit
authorization for paid requests. The Developer UI entry point uses the offline
model only; it must not expose connected credentials through reflection.

## Upstream references

The UI listens to GenUI's public `SurfaceContext.definition` for quick surface
reveals and preserves the existing `Surface` and bound controls. Bound data can
change layout without an agent notification, so bottom-following observes actual
rendered geometry. It follows only while the user is up to date and respects
Reduce Motion. This does not add or change Genkit requests. See the
[renderer capture and comparison](verification/figma-layout-2026-10-13/README.md)
and [GenUI SurfaceContext API](https://pub.dev/documentation/genui/latest/genui/SurfaceContext-class.html).

- [Genkit version history](https://pub.dev/packages/genkit/versions)
- [Genkit 1.0 changes](https://pub.dev/packages/genkit/versions/1.0.0/changelog)
- [Genkit public API](https://pub.dev/documentation/genkit/1.0.0/genkit/)
- [Anthropic public API](https://pub.dev/documentation/genkit_anthropic/1.0.0/genkit_anthropic/)
- [Google public API](https://pub.dev/documentation/genkit_google_genai/1.0.0/genkit_google_genai/)
- [OpenAI public API](https://pub.dev/documentation/genkit_openai/1.0.0/genkit_openai/)
