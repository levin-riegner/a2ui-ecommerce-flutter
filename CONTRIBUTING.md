# Contributing

Keep changes small enough to review. Start from [the architecture map](docs/architecture.md), and [the pinned Flutter template map](docs/flutter-template.md), then follow [the extension walkthrough](docs/extending.md) for your change.

## Start locally

Install Git LFS and FVM, then run from the cloned repository. `.fvmrc` pins Flutter 3.47.4; the app has no backend or Node prerequisite.

```sh
git lfs install
git lfs pull
fvm install
fvm flutter pub get
fvm flutter run -d chrome
```

Choose **Explore component catalog** to inspect widgets and A2UI surfaces without a model key. Gallery actions make no provider requests. Generated localization, routes and state are checked in; code generation is only needed when their source changes.

The first setup downloads the SDK, packages and LFS images. Run `fvm flutter doctor -v` to check your platform tools. Android requires its SDK and accepted licenses; iOS requires a Mac and an Xcode with iOS SDK 27.1 or newer. See [the iOS gate](docs/ios-release-gate.md) before building iOS. Browser model requests depend on provider CORS support; the native builds avoid that browser restriction. See [the getting-started guide](docs/getting-started.md) for connection settings and troubleshooting.

## Architecture and generated files

Follow the Levin+Riegner template's feature BLoC, repository/service and constructor-injection conventions. Keep domain validation in `lib/data/`, renderer resources in `lib/presentation/stylist/a2ui/`, and native defaults in `lib/util/stylist_dependencies.dart`. Do not add another state-management framework or generic use-case layer for a local feature.

Fixed presentation strings belong in `lib/app/l10n/app_en.arb`. Run `fvm flutter gen-l10n` after editing them. Run `fvm dart run build_runner build` when Freezed events/state or typed routes change, and include the resulting generated files. Existing hand-written immutable domain models do not need rewriting merely to use a generator. Provider credentials must never enter state, event text, generated serialization or persisted data.

## Check a change

```sh
python3 tool/check_architecture.py
python3 tool/check_release_assets.py
python3 -m unittest discover -s tool -p 'test_*.py'
fvm dart format --output=none --set-exit-if-changed lib test tools/genkit tool
fvm flutter analyze
fvm flutter test
```

Run `python3 tools/catalog/validate.py assets/data/catalog/products.csv` for catalog/asset changes. CI also builds Android debug and web. For native dependencies or releases, run the separate iOS gate on a compatible Mac. Default tests use fakes/offline models. Live provider tests in `tools/genkit/` require explicit opt-in and can incur charges.

## Open a PR

Use a feature branch. Never push to `main` or `master`. Describe the concrete problem, changes and resulting behavior in short bullets. Preserve unrelated changes and note any platform/provider behavior you could not verify. Reviewers should be able to follow one data path and its tests without reading the full runtime.

Changes to a wire schema must update its decoder, tool schema, presenter/adapter where relevant and focused contract tests. Changes to public exports must pass the transitive import guard. Keep BLoC presentation state separate from host commerce rules and live renderer resources.

See [SECURITY.md](SECURITY.md) for credential handling and [the release gates](docs/open-source-release.md) for licensing and publication.
