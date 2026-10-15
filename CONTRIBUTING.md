# Contributing

Keep changes small enough to review. Start from [the architecture map](docs/architecture.md), then follow [the extension walkthrough](docs/extending.md) for your change.

## Start locally

Install Git LFS and FVM, then use the pinned Flutter SDK:

```sh
git lfs install
git lfs pull
fvm install
fvm flutter pub get
fvm flutter run -d chrome
```

Choose **Explore component catalog** to inspect widgets and A2UI surfaces without a model key. Gallery actions make no provider requests. Android/iOS are also supported; see [the iOS gate](docs/ios-release-gate.md) before building iOS.

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

Changes to a wire schema must update its decoder, tool schema, presenter/adapter where relevant and focused contract tests. Changes to public exports must pass the transitive import guard. Do not introduce a state-management framework or generic use-case layer to solve a local issue.

See [SECURITY.md](SECURITY.md) for credential handling and [the release gates](docs/open-source-release.md) for licensing and publication.
