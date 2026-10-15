# Alder

Alder is a personal stylist built with Flutter and declarative A2UI surfaces. It targets Flutter web, iOS, and Android, with the responsive shell designed to cover compact phone layouts and the wider iPhone Duo showcase frame.

The personal stylist runs inside Flutter with Genkit Dart. It searches the bundled fictional catalog and builds A2UI recommendations and dressing-room updates locally. Users supply their own provider, model ID, and API key; no separate agent service is required.

## Run

Install Git LFS and FVM, then use the SDK pinned in [.fvmrc](.fvmrc):

```sh
git lfs install
git lfs pull
fvm install
fvm flutter pub get
fvm flutter run
```

For a free first run, choose **Explore component catalog**. It needs no API key and its controls make no provider requests. See [CONTRIBUTING.md](CONTRIBUTING.md) for the short development path and [the extension walkthrough](docs/extending.md) for adding a source, command or component.

Choose an iOS or Android device, or use `fvm flutter run -d chrome` for web. Choose **Connect your model**, select Google Gemini, OpenAI, Anthropic, or OpenAI-compatible, then enter a model ID that supports function tools and your API key. Compatible providers also require their API base URL, including its version path (for example `https://your-provider.example/v1`). HTTPS is required for remote providers; loopback HTTP is accepted for local compatible providers. Native operating systems may require additional configuration to permit local HTTP.

iOS builds require the **iOS 27.1 SDK or newer** to use the full Duo display area and reserved regions. Runner enforces this at compilation for simulator and device builds in Debug, Profile, and Release. Select Xcode 27.1 or newer, or select it per command without changing the global Xcode setting:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer \
  fvm flutter run -d <ios-device-id>
```

Use the path to your installed Xcode. The deployment target remains iOS 15.0; the build SDK requirement does not raise the minimum supported OS version. Run [the iOS release gate](docs/ios-release-gate.md) on a compatible Mac; Ubuntu CI and saved simulator checkpoints do not compile iOS.

Connecting loads the bundled catalog and configures Genkit without calling a model or checking the key. Starting a journey, chatting, selecting/removing pieces, and Retry can make paid requests, with at most four model requests per interaction. The app sends requests directly to the chosen provider. Browser use additionally requires that provider to support browser requests (CORS); a native build does not have this browser restriction.

The key stays in memory on the device and is added only to the provider's outgoing HTTP headers. It is not saved to files or browser storage and is never a Genkit flow input or generation option. **New journey → Disconnect model** clears the key and session. Reloading or closing the app requires configuring it again. Never embed keys in source, assets, or `--dart-define` values.

Accepted styling preferences, the current look, saved looks and demo bag quantities are stored locally under `alder.stylist.v1`, separately from the model connection. Reconnecting restores catalog IDs and accepted facts against current prices and restrictions. Start over clears the working look while retaining saved looks and the demo bag. The bag supports quantities, removal, undo and an explicitly simulated checkout. Local demo variants, stock, size guides and delivery scenarios are fictional; no payment, real order or shipment is created. See [product-data-and-demo-commerce.md](docs/product-data-and-demo-commerce.md) and [component-adoption-progress.md](docs/component-adoption-progress.md).

Without a model connection, journeys are disabled and the component gallery remains available. The conversation keeps submitted messages and previous recommendations in order; only the latest completed recommendation accepts input. During a turn, the app displays a loading surface, then streams the final stylist explanation in complete sentences, with chat/product actions disabled until the full turn succeeds. Product cards appear below the explanation after validation, so later prose cannot push an earlier product preview down. Failed turns remove provisional text, show Retry, and retain the previous outfit and completed surfaces. Retrying keeps the original user message without adding a duplicate. No scripted fallback runs in the app.

Once connected, choose a preset journey or enter your own occasion with **Start my look**. Missing style and budget are gathered together; editing those controls makes no model request until **Find options**. Choosing a piece immediately offers the next part of the look. You can also choose or remove pieces in words, refine the brief, and revisit a completed outfit. The dressing room follows the current outfit plan, including tops and bottoms.

Explicit input such as “I have 500 to spend on a casual outfit” is acknowledged and retained as the whole-outfit EUR budget. Item prices do not replace an explicit outfit total, and a model suggestion cannot overwrite an accepted user amount. Foreign-currency budgets receive a correction prompt rather than an implicit conversion. Unknown slider amounts are labeled suggestions. Hard color, material, brand and category restrictions remain enforced through search fallback; already-owned pieces and excluded categories affect the purchase plan. Recommendations favor choices that leave enough budget to finish the required look, and explain the tradeoff when no complete look fits. Correctable input errors preserve the conversation and leave editing enabled.

Destination forecasts use Open-Meteo geocoding and weather endpoints. Only the named destination is looked up; the app does not request GPS. Verified dates, temperature, and rain probability reach both the weather card and stylist. Unavailable forecasts show a notice; changing the destination clears the previous city's weather. **Refresh forecast** updates only the current response, makes no model request, and preserves the outfit, choices, and history. Forecasts are cached for 15 minutes; previous responses remain read-only. See [the online demo guide](docs/alder-online-demo.md) for the bounded local bridge and offline simulator mode.

Tap the microphone in the occasion or chat composer to dictate, and tap it again to stop. Speech recognition fills the editable draft; sending uses the same GenUI/Genkit text path as typing. Microphone and speech permissions are requested on the first tap. Recognition availability and any remote speech processing depend on the device or browser. Rebuild the native app after installing the speech plugin; hot reload cannot register a new native plugin.

Dictation uses the community-maintained [`speech_to_text`](https://pub.dev/packages/speech_to_text) package, pinned to 7.5.0. Android uses the device’s configured speech recognition service, which can be Google; iOS uses Apple Speech and web uses the browser’s recognition support. This keeps dictation independent of the chosen Genkit model and requires no additional Google Cloud credentials. It does not guarantee offline recognition or a Google recognizer on every platform.

## Genkit developer tools

The app pins Genkit Dart, its three official provider plugins, and Schemantic to 1.0.0. The integration uses public APIs only. See the [Genkit 1.0 implementation reference](docs/genkit-reference.md) for provider setup, typed tool selection, cancellation, retry policy, transport ownership, and the remaining upstream compatibility exception.

For an explicitly opted-in live OpenAI smoke test, put `OPENAI_API_KEY` and `OPENAI_MODEL` in the ignored `.env.local` file or your process environment, then run:

```sh
STYLIST_LIVE_TEST=1 fvm flutter test tools/genkit/live_smoke_test.dart
```

This test makes paid requests: at most three interactions and twelve provider requests. It checks real search/presentation tool calls, catalog-backed cards and photo files, selection/removal, next-category progression, and dressing-room totals. Rendering is covered separately by the normal widget tests. It reports request counts and provider token usage without logging credentials. It is excluded from the default test suite and CI. OpenAI Platform API keys work with this Chat Completions integration; ChatGPT Admin tokens for Codex or Workspace Agents are not interchangeable with those keys.

To check one real selection continuation with an offline initial preview and a three-request cap:

```sh
STYLIST_LIVE_TEST=1 STYLIST_LIVE_SEED_PREVIEW=1 STYLIST_LIVE_INTERACTIONS=2 STYLIST_LIVE_MAX_REQUESTS=3 fvm flutter test tools/genkit/live_smoke_test.dart
```

This narrower mode verifies that selecting a seeded top produces real model-generated bottom options. It does not test an entirely live journey or removal.

To try question handling with the configured live model:

```sh
STYLIST_LIVE_TEST=1 fvm flutter test tools/genkit/intent_smoke_test.dart
```

This bounded test makes at most eight paid requests across a capability question, an outfit request, and a styling question. It checks that questions show no intake controls, explicit occasion/budget/exclusion facts persist, and advice does not change the brief. Free runtime and phone-width widget coverage is in `test/stylist_question_test.dart`.

For free prompt/tool/flow inspection with the same catalog and stylist implementation, install the Genkit CLI on your development machine and run from the repository root:

```sh
npm install -g genkit-cli@1.43.0
genkit start -- fvm dart run tools/genkit/stylist.dart
```

Open `http://localhost:4000` and run `stylistTurn` with `{"message":"A summer dress under €250"}`. This developer entry point always uses an offline preview model, so it requires no key and makes no paid requests. The Flutter app uses BYOK provider plugins and does not expose its connected credentials or live model actions through a reflection server. Node is needed only for the optional developer CLI, not to run or bundle the Flutter app.

Product JPEGs are tracked with Git LFS. Install Git LFS before cloning or run `git lfs install && git lfs pull` in an existing checkout so Flutter receives the image bytes rather than pointer files. CI fetches LFS assets and validates their JPEG signatures before building.

## Architecture and A2UI shape

See [architecture.md](docs/architecture.md) for the layer boundaries, surface lifecycle, message shape, and event flow. Open the **Explore component catalog** action on the landing screen to see the complete 24-component vocabulary in a compact visual index.

Reusable presentation widgets and layouts are exported through `package:a2ui_flutter_commerce/commerce_ui.dart`, with no transitive GenUI/Genkit dependency. Import `commerce_a2ui.dart` for A2UI registrations and `commerce_gallery.dart` for optional examples and inspection screens. The adapters and galleries use those same widgets. The gallery includes choice, disabled action, choose/remove, slot, completion, and light/dark dressing-room examples; its controls make no provider requests.

`AdaptivePaneLayout` keeps the composer reachable, stacks the dressing room above the conversation on compact windows, and gives wider panes independent scrolling. Layout decisions use available space and text size; the 669-wide portrait reference stacks, while the 951-wide landscape reference splits and shows the utility rail. `DuoLayoutAdapter` reads native iOS Duo posture and reserved geometry through pinned `foldable` 1.0.5, keeping controls clear of active divisions and camera regions without resetting drafts or outfit state. See the [native simulator verification](docs/duo-simulator-verification.md) for reproduction steps, evidence, and remaining limits.

## Data sources

The bundled `StylistRuntime` searches `assets/data/catalog/products.csv` and publishes A2UI messages through `GenkitAgent`. Flutter renders the bundled product photographs from their `image_asset` paths. `CsvProductRepository`, `FixtureProductRepository`, and `StubAgent` remain available for tests and component previews through explicit agent injection; they are not runtime fallback modes.

The CSV parser handles quoted commas, escaped quotes, and multiline fields. Run `python3 tools/catalog/validate.py assets/data/catalog/products.csv` before publishing catalog changes. Add `--source` once per private source export when checking for source identifiers; the original exports are not part of this repository.

The CSV uses fictional names, brands, descriptions, prices, and IDs. The approved product photographs are reused as local assets, resized and saved without image metadata. Visible marks on products and reverse image search can still identify a photographed item; the image bundle does not provide image-level unlinkability. For future catalog expansion, `tools/catalog/import_images.py` accepts a private, ordered URL file and an explicit `--allowed-host`, then writes renamed JPEGs. Keep that URL file outside the repository; the importer requires Pillow.

The bundled catalog contains 977 products: the original 200 plus 777 curated from mock.shop. All 1,028 records imported from Everbloom and UrbanVantage were processed with Luna; unrelated goods, children's clothing, unsupported sets and duplicate images were skipped. The original photographs are used with permission for this public demo. The additional images are generated mock content, with photo-led styling guesses and fictional EUR prices. Conflicting source variants are omitted; this is an outfit demo, not live stock. The Start collage uses original code-native geometric artwork. Removed source photographs, historical verification media and the remaining design context photos have separate [public-release gates](docs/open-source-release.md). See [NOTICE](NOTICE) and [asset provenance](docs/asset-provenance.json) for credits and evidence limits.

Catalog expansion uses [best-effort demo curation](docs/catalog-import.md): use the pictured item, infer useful style tags, omit unsupported claims and skip broken records. Raw sources and enrichment history remain local for traceability; no manual review interface is required.

All 977 products have photo-based descriptions and styling tags, including a separate Luna pass over the original 200. Original IDs, prices and photographs are preserved; unsupported original material labels are replaced with `unspecified`. Search passes matching product descriptions and styling keywords to the LLM as structured text facts. Images are inspected during enrichment and displayed in the cards; local retrieval uses word matching and filters without a vector database.

Every product also has a styling audience: `male`, `female`, or `male, female`. Explicit menswear, womenswear, and unisex requests are retained. Selecting a piece with one audience establishes the outfit's audience when none was specified, so a female dress leads to female-compatible jackets and accessories, including neutral pieces. Explicit unisex requests return only products supporting both audiences. Search fallback, presentation, and budget completion enforce this preference. These labels describe product styling, not the wearer's identity or size/fit.

## Verification

```sh
python3 tool/check_architecture.py
python3 tool/check_release_assets.py
fvm dart format lib test tools/genkit tool
python3 -m unittest discover -s tool -p 'test_*.py'
python3 tool/verify_duo_checkpoints.py docs/verification/duo-simulator-2026-10-04.json
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter build web
```

## License

Apache-2.0 for the project, original code-native artwork and original approved catalog photographs. Additional mock.shop imagery remains subject to its source terms. Jost retains its SIL Open Font License in `assets/fonts/jost/OFL.txt`. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for attribution.
