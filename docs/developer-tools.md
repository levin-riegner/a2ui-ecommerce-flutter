# Genkit developer tools

The app pins Genkit Dart, its three official provider plugins, and Schemantic to 1.0.0. The integration uses public APIs only. See the [Genkit 1.0 implementation reference](genkit-reference.md) for provider setup, typed tool selection, cancellation, retry policy, transport ownership, and the remaining upstream compatibility exception.

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


See [CONTRIBUTING.md](../CONTRIBUTING.md) for normal offline verification and [the online demo guide](alder-online-demo.md) for the separate local bridge.
