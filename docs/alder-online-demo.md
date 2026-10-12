# Alder reviewer walkthrough

Alder is a Flutter personal stylist using Genkit Dart and GenUI/A2UI. The model
searches a bundled fictional catalog; the host validates product IDs, prices and
image paths before constructing recommendation and dressing-room surfaces.
There is no live inventory, checkout or separate agent service.

The landing screen has full-sentence occasion examples and a custom occasion
composer. Follow the typed journey below; it does not rely on the removed preset
journey buttons. Hosted/staging access is tracked in the
[October 16 handoff checklist](google-reviewer-checklist.md). No verified hosted
URL is recorded yet.

## Setup and key safety

For a local build, use [README setup](../README.md#run), including Git LFS and
the pinned Flutter SDK. Launch web with `fvm flutter run -d chrome`, or select a
supported native device with `fvm flutter devices` and `fvm flutter run -d <device-id>`.
iOS requires the iOS 27.1 build SDK described in README.

1. Open **Connect your model**. Choose **Provider**, enter **Model ID** and your
   **API key**, then press **Connect model**. Use a model with function-tool support.
   **OpenAI-compatible** also requires **Provider API base URL**, including its
   version path. Remote endpoints require HTTPS; loopback HTTP is accepted for
   local development, subject to native platform restrictions.
2. Connecting loads the catalog and configures the provider. It does not send a
   model request or validate authentication. The first journey request can still
   fail because of an invalid key, model access, quota or transport restrictions.
3. Web additionally requires the provider to allow browser requests through CORS.
   A successful local/native test does not establish hosted browser compatibility.
   If the chosen provider blocks browser access, use a supported native build to
   review the live journey and the browser gallery to review components.

The key is masked, remains in memory, and is sent directly to the selected
provider in request headers. It is not saved to files or browser storage.
Starting a journey, submitting chat, selecting or removing pieces, changing a slot,
and **Retry** may incur provider charges; each interaction is capped at four
model requests. Editing clarification controls and exploring the catalog do
not request generation.

Use **New journey → Disconnect model** to clear the connection and session.
Reloading/closing the app requires configuring it again. Keep credentials out
of source, assets, build defines, screenshots and shared logs. Connect before
recording screenshots so the key-entry form is excluded.

## Reproducible review journey

After connecting, type this in **Your occasion**:

> A smart casual work day in Berlin, Germany today, budget €900. Build a look with a top, bottoms, shoes and a bag.

1. Use the send arrow labelled **Start my look**. Wait for the turn to finish.
   A working surface may precede catalog-validated card previews; previews and
   chat/product actions stay disabled until the complete turn succeeds.
   Expect top recommendations with bundled photos, fictional names, brands and
   euro prices, plus a **Dressing room** with outfit slots and a €900 budget.
2. Choose a top using **Add to dressing room** on a recommendation. Record its
   displayed name and price. When the continuation succeeds, expect that top's
   photo/name in the filled slot, spending equal to its catalog price, remaining
   budget equal to €900 minus that price, and bottom recommendations. The next
   slot is marked **Choosing now**. Scroll the conversation to the latest cards;
   previous responses remain readable but their controls are inactive.
3. Send `Remove the top named <selected product name> from my outfit`, replacing
   the placeholder with the exact displayed name. Removal uses a model tool call.
   When it succeeds, expect the top slot to reopen, spending to return to €0,
   remaining budget to return to €900, and top recommendations to resume. Check
   the slot and totals to confirm the edit; generated prose alone is insufficient.
4. Select a top again, then select bottoms, shoes and a bag from each latest
   response. If the saved brief adds a required layer, follow that slot too. Each
   successful selection keeps the other pieces and advances the category. A
   completed look has filled required slots and no next-piece badge.
5. To inspect replacement behavior, tap a filled dressing-room slot's photo/name.
   Its accessibility action is **Change** followed by the product name. Expect
   alternatives for that category while the current item and totals remain until
   a replacement is selected. This changes a piece rather than removing it as in
   step 3; there is no separate selected-products list below the dressing room.

Exact products, ordering, descriptions and verbal-edit interpretation vary by
provider and model. The checks above describe validated state transitions, not
an identical transcript or a guarantee that every model will complete a turn.
No scripted fallback takes over after a live failure. If no affordable option
exists, revise the budget or selected pieces rather than expecting invented stock.

For the clarification path, start another journey with `A spring day in Berlin`.
The missing-style/budget form shows **How formal or relaxed?**, **smart-casual**,
**BUDGET FOR THE WHOLE OUTFIT** and **Find options**. Select the style and adjust
the slider, then submit **Find options** once. Those edits stay local until
submission. If the full Berlin prompt already supplies the required facts,
this form need not appear.

## Component catalog

On the landing screen, scroll below the occasion examples and open
**Explore component catalog**. It works before connecting a model. From a journey,
use the close icon with tooltip **New journey** to return to the landing screen.

**Catalog components** shows the commerce vocabulary and GenUI basic primitives.
Open **Finalized Figma components** to inspect the schema-rendered families and
states, and **Finalized Figma screens** for composed examples. Gallery interactions
are local fixtures. Photo upload, fit/size, saved looks, bag quantity, delivery and
checkout examples do not establish live services. The
[Figma catalog guide and schema exports](design/README.md) document the contracts.

## Pending web demo integration

[Draft PR14](https://github.com/levin-riegner/a2ui-ecommerce-flutter/pull/14), reviewed
source `7eae0a331ab163cc9c1e5c304181285c8cecbf2a`, prepares a direct `/#/catalog`
route and a [release builder](https://github.com/levin-riegner/a2ui-ecommerce-flutter/blob/7eae0a331ab163cc9c1e5c304181285c8cecbf2a/tool/build_web_demo.py).
These are pending changes, not a verified hosted deployment. For the reviewer
package, integrate the hosting changes with the restored original Figma assets
and accurate notices, complete FVM setup, then build from a clean commit:

```sh
python3 tool/build_web_demo.py --flutter .fvm/flutter_sdk/bin/flutter
```

The builder uses `lib/main.dart` in BYOK mode, excludes source maps, filters
credential-named environment variables, scans the bundle for credential-shaped
content, and sets `ALDER_ENABLE_OPEN_METEO=false`. It records the source commit,
entry point, weather mode, catalog path and file hashes in generated
`build/web/alder-build.json`. It includes the app's `LICENSE.txt`, `NOTICE.txt` and
`licenses/Inter-OFL.txt` / `licenses/Jost-OFL.txt`, separately from Flutter's package
notices. `--allow-dirty` is for local QA only. The heuristic scan does not establish
asset rights or prove that arbitrary data is safe to publish.

The reviewed earlier local artifact at `8a8f201` has 330 matching file hashes, clean input,
`modelMode: BYOK`, `liveWeather: false` and `catalogPath: /#/catalog`. The web form
discloses **Live weather is unavailable in this web demo.** Do not enable public
weather requests without the service decision described below. This builder
prepares files only; it does not deploy or choose a hosting project.
Rebuild and recheck the final combined commit after the original-asset decision
is reflected. The replacement-based `b33cf8c` build/export is superseded and must
not be deployed. The earlier local QA artifact is not the final reviewer package.

The hosting task's local Chrome record exercised the same Berlin prompt, direct
catalog open/refresh without a key, zero-request connection setup, a €35 top
advancing to bottoms, injected 503 rollback, explicit Retry, a synthetic removal
tool refund/reopened top, and a four-piece €255 look with €645 left. Reviewed
screenshots show the catalog and selected-top/next-bottom states. Replies came
from a loopback synthetic HTTP provider; there were zero real model calls.
Local same-origin QA does not validate real-provider CORS, authentication,
natural-language interpretation, weather or a deployed build. Those local images
are QA evidence, not the final submission screenshot package.

## Original Figma imagery and permission record

Use the ten original Start collage photos and four original gallery photos
provided through Figma, as Kelvin requested. The replacement-image approach and
its clearance evidence are superseded. Kelvin has stated that prior authorization
exists; the repository currently records provenance but not that authorization's
scope for hosted display or public repository redistribution.

Record that scope, including existing Git/LFS photo bytes, with accurate credits
and notices before asserting public redistribution readiness. Figma source/hash
verification establishes origin rather than an image license. The existing
product-photo permission is retained; Jost and Inter keep their OFL licenses.
Hosting code/tests remain separate from the image restoration. Rebuild and verify
the final package with the original files after restoration is reflected.

## Recovery and live context

- A failed model turn discards its pending preview and draft outfit edits, retains
  previously completed surfaces and the last committed outfit, and offers **Retry**.
  Retry repeats that interaction without duplicating the submitted user message;
  it can make more paid requests. Check provider access/quota before retrying.
- To change provider/model/key, return through **New journey**, disconnect, and
  configure again. Starting a new brief resets the outfit and conversation;
  returning to the landing screen alone keeps the connection.
- Baseline `b3263ce` uses Open-Meteo geocoding and a five-day forecast for
  the named city, without GPS. Forecasts are current dated facts, not conditions
  for a future trip outside the returned date range. Dates, values and availability
  change between runs; weather is not a fixed assertion for the journey above.
- **Refresh forecast**, when available, refreshes only the latest response. It
  makes no model request and preserves the outfit, choices and history. The cache
  lasts 15 minutes; previous response controls remain read-only. A lookup failure
  shows an unavailable notice and clears the old city's forecast. A failed model
  turn rolls back its destination change along with the outfit draft.

Hosted weather needs a separate service and attribution decision. Open-Meteo's
[terms](https://open-meteo.com/en/terms) restrict the free service to non-commercial
use and list commercial products/promotional activities as commercial use. A
hosted ecommerce showcase must not assume eligibility. If the final build disables
weather, record that limitation in the handoff; an unavailable notice is not a
verified forecast. Review attribution against the
[forecast API](https://open-meteo.com/en/docs) and
[geocoding/GeoNames documentation](https://open-meteo.com/en/docs/geocoding-api).

Dictation is optional. Type the journey for reproducibility. Microphone/speech
permissions, recognition availability and remote processing depend on the device
or browser; simulator permission checks do not establish physical transcription.

## Verification evidence

On current main `b3263ce` (PR12), 130 existing offline Flutter tests passed for
BYOK masking/configuration, custom briefs, catalog access, selection/progression,
typed edit tool contracts, Change, rollback/retry, progressive surfaces, history,
forecast refresh/failure and responsive layout. Reproduce those focused checks:

```sh
fvm flutter test \
  test/byok_test.dart test/custom_brief_journey_test.dart \
  test/stylist_journey_integration_test.dart test/dressing_room_progression_test.dart \
  test/stylist_adjust_piece_test.dart test/progressive_agent_test.dart \
  test/conversation_history_test.dart test/reusable_components_test.dart \
  test/finalized_catalog_integration_test.dart test/online_context_integration_test.dart \
  test/widget_test.dart test/stylist_runtime_test.dart \
  test/agent_connection_test.dart test/adaptive_screen_layout_test.dart
```

These tests render the actual app widgets and use offline models or mocked HTTP.
The typed-removal tests supply explicit model tool responses; they do not prove
natural-language interpretation by a live provider. No live provider requests,
hosted-browser success or physical dictation are claimed here; PR14's local
synthetic browser evidence is recorded separately above.
The [October 7 simulator record](verification/alder-online-simulator-2026-10-07.json)
is historical evidence for an older revision. Repeat the walkthrough on the final
deployed commit and record provider/model, date, result and limitations without keys.

## Optional developer verification

The normal app requires BYOK. For explicit offline-model inspection, run the
developer entry point on a supported native device:

```sh
fvm flutter run -d <device-id> \
  -t tool/alder_online_demo.dart --dart-define=ALDER_DEMO_OFFLINE=true
```

This mode starts at the landing page and delays deterministic responses. It makes
no paid model calls, but still attempts live weather requests under the service
conditions above. Its basic offline model does not interpret verbal outfit edits.
The offline-only `ext.alder.remove` VM extension sends a normal removal event for
regression checks; using it is a simulated action, not the live step 3 result.
`ext.alder.capture` reports UI errors and state without recording credentials.

For a deliberately bounded live developer run, the existing local bridge reads
`OPENAI_API_KEY` and `OPENAI_MODEL` from ignored `.env.local` or the process
environment:

```sh
python3 tool/alder_online_proxy.py --live --max-requests 12
```

In another terminal, select the supported native device:

```sh
fvm flutter run -d <device-id> -t tool/alder_online_demo.dart \
  --dart-define-from-file=/private/tmp/alder-online-session.json
```

This live entry point automatically starts a Berlin work-day brief under €900;
relaunching makes another paid interaction. Each turn permits four provider
requests and the bridge enforces the positive session allowance. Keep keys,
session tokens/files and VM URLs private, and stop both processes when finished.
The Mac holds the provider key; the app receives a temporary bridge token. The
authenticated loopback bridge forwards only to its fixed HTTPS endpoint and is
development tooling, not the hosted demo. Exhaustion shows a specific allowance
error; restarting replenishes the allowance for another run.
