# Alder

Alder is a personal stylist built with Flutter and declarative A2UI surfaces. It targets Flutter web, iOS, and Android, with the responsive shell designed to cover compact phone layouts and the wider iPhone Duo showcase frame.

The personal stylist runs inside Flutter with Genkit Dart. It searches the bundled fictional catalog and builds A2UI recommendations and dressing-room updates locally. Users supply their own provider, model ID, and API key; no separate agent service is required.

## Run

Use the SDK pinned in [.fvmrc](.fvmrc):

```sh
fvm install
fvm flutter pub get
fvm flutter run
```

Choose an iOS or Android device, or use `fvm flutter run -d chrome` for web. Choose **Connect your model**, select Google Gemini, OpenAI, Anthropic, or OpenAI-compatible, then enter a model ID that supports function tools and your API key. Compatible providers also require their API base URL, including its version path (for example `https://your-provider.example/v1`). HTTPS is required for remote providers; loopback HTTP is accepted for local compatible providers. Native operating systems may require additional configuration to permit local HTTP.

iOS builds require the **iOS 27.1 SDK or newer** to use the full Duo display area and reserved regions. Runner enforces this at compilation for simulator and device builds in Debug, Profile, and Release. Select Xcode 27.1 or newer, or select it per command without changing the global Xcode setting:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer \
  fvm flutter run -d <ios-device-id>
```

Use the path to your installed Xcode. The deployment target remains iOS 15.0; the build SDK requirement does not raise the minimum supported OS version.

Connecting loads the bundled catalog and configures Genkit without calling a model or checking the key. Starting a journey, chatting, selecting/removing pieces, and Retry can make paid requests, with at most four model requests per interaction. The app sends requests directly to the chosen provider. Browser use additionally requires that provider to support browser requests (CORS); a native build does not have this browser restriction.

The key stays in memory on the device and is added only to the provider's outgoing HTTP headers. It is not saved to files or browser storage and is never a Genkit flow input or generation option. **New journey → Disconnect model** clears the key and session. Reloading or closing the app requires configuring it again. Never embed keys in source, assets, or `--dart-define` values.

Without a model connection, journeys are disabled and the component gallery remains available. The conversation keeps submitted messages and previous recommendations in order; only the latest completed recommendation accepts input. During a turn, the app displays a loading surface, then previews catalog-validated cards as they become available, with chat/product actions disabled until the full turn succeeds. The final stylist explanation appears after validation. Failed turns remove the preview, show Retry, and retain the previous outfit and completed surfaces. Retrying keeps the original user message without adding a duplicate. No scripted fallback runs in the app.

Once connected, choose a preset journey or enter your own occasion with **Start my look**. Missing style and budget are gathered together; editing those controls makes no model request until **Find options**. Choosing a piece immediately offers the next part of the look. You can also choose or remove pieces in words, refine the brief, and revisit a completed outfit. The dressing room follows the current outfit plan, including tops and bottoms.

Destination forecasts use Open-Meteo geocoding and weather endpoints. Only the named destination is looked up; the app does not request GPS. Verified dates, temperature, and rain probability reach both the weather card and stylist. Unavailable forecasts show a notice; changing the destination clears the previous city's weather. **Refresh forecast** updates only the current response, makes no model request, and preserves the outfit, choices, and history. Forecasts are cached for 15 minutes; previous responses remain read-only. See [the online demo guide](docs/alder-online-demo.md) for the bounded local bridge and offline simulator mode.

Tap the microphone in the occasion or chat composer to dictate, and tap it again to stop. Speech recognition fills the editable draft; sending uses the same GenUI/Genkit text path as typing. Microphone and speech permissions are requested on the first tap. Recognition availability and any remote speech processing depend on the device or browser. Rebuild the native app after installing the speech plugin; hot reload cannot register a new native plugin.

Dictation uses the community-maintained [`speech_to_text`](https://pub.dev/packages/speech_to_text) package, pinned to 7.5.0. Android uses the device’s configured speech recognition service, which can be Google; iOS uses Apple Speech and web uses the browser’s recognition support. This keeps dictation independent of the chosen Genkit model and requires no additional Google Cloud credentials. It does not guarantee offline recognition or a Google recognizer on every platform.

## Genkit developer tools

The app bundles the Dart runtime and official provider plugins. Genkit Dart is currently in preview; package versions are pinned, and HTTP transport injection for the Google and Anthropic plugins is isolated in `genkit_providers.dart` until their factory handles expose it.

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

For free prompt/tool/flow inspection with the same catalog and stylist implementation, install the Genkit CLI on your development machine and run from the repository root:

```sh
npm install -g genkit-cli@1.43.0
genkit start -- fvm dart run tools/genkit/stylist.dart
```

Open `http://localhost:4000` and run `stylistTurn` with `{"message":"A summer dress under €250"}`. This developer entry point always uses an offline preview model, so it requires no key and makes no paid requests. The Flutter app uses BYOK provider plugins and does not expose its connected credentials or live model actions through a reflection server. Node is needed only for the optional developer CLI, not to run or bundle the Flutter app.

Product JPEGs are tracked with Git LFS. Install Git LFS before cloning or run `git lfs install && git lfs pull` in an existing checkout so Flutter receives the image bytes rather than pointer files. CI fetches LFS assets and validates their JPEG signatures before building.

## Architecture and A2UI shape

See [architecture.md](docs/architecture.md) for the layer boundaries, surface lifecycle, message shape, and event flow. Open the **Explore component catalog** action on the landing screen to see the complete 24-component vocabulary in a compact visual index.

Reusable presentation widgets and layouts are exported through `package:a2ui_flutter_commerce/commerce_ui.dart`. The A2UI catalog adapters and interactive component gallery use those same widgets. The gallery includes choice, disabled action, choose/remove, slot, completion, and light/dark dressing-room examples; its controls make no provider requests.

`AdaptivePaneLayout` keeps the composer reachable, stacks the dressing room above the conversation on compact windows, and gives wider panes independent scrolling. Layout decisions use available space and text size; the 669-wide portrait reference stacks, while the 951-wide landscape reference splits and shows the utility rail. `DuoLayoutAdapter` reads native iOS Duo posture and reserved geometry through pinned `foldable` 1.0.5, keeping controls clear of active divisions and camera regions without resetting drafts or outfit state. See the [native simulator verification](docs/duo-simulator-verification.md) for reproduction steps, evidence, and remaining limits.

## Data sources

The bundled `StylistRuntime` searches `assets/data/catalog/products.csv` and publishes A2UI messages through `GenkitAgent`. Flutter renders the bundled product photographs from their `image_asset` paths. `CsvProductRepository`, `FixtureProductRepository`, and `StubAgent` remain available for tests and component previews through explicit agent injection; they are not runtime fallback modes.

The CSV parser handles quoted commas, escaped quotes, and multiline fields. Run `python3 tools/catalog/validate.py assets/data/catalog/products.csv` before publishing catalog changes. Add `--source` once per private source export when checking for source identifiers; the original exports are not part of this repository.

The CSV uses fictional names, brands, descriptions, prices, and IDs. The approved product photographs are reused as local assets, resized and saved without image metadata. Visible marks on products and reverse image search can still identify a photographed item; the image bundle does not provide image-level unlinkability. For future catalog expansion, `tools/catalog/import_images.py` accepts a private, ordered URL file and an explicit `--allowed-host`, then writes renamed JPEGs. Keep that URL file outside the repository; the importer requires Pillow.

The bundled catalog photographs are used with permission for this public demo. They are existing photographs, not presented as AI-generated images. The ten Start collage photographs supplied in the design reference still need recorded source credits and redistribution terms. See [NOTICE](NOTICE) for image and project credits.

## Verification

```sh
fvm dart format lib test tools/genkit tool
python3 -m unittest discover -s tool -p 'test_*.py'
python3 tool/verify_duo_checkpoints.py docs/verification/duo-simulator-2026-10-04.json
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter build web
```

## License

Apache-2.0 for the project and approved bundled catalog photographs. Jost retains its SIL Open Font License in `assets/fonts/jost/OFL.txt`. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for attribution.
