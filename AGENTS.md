# Repository guidance

- Never push to `master` or `main`. Work on a feature branch and prefer PRs.
- Preserve unrelated work. Check branch/status before edits; stage only requested files.
- Read [CONTRIBUTING.md](CONTRIBUTING.md) and [the architecture map](docs/architecture.md) before changing boundaries.
- Keep widgets in `commerce_ui.dart` independent of GenUI, Genkit, runtime and galleries. Put schemas/bindings in `*_a2ui.dart`; examples and inspection screens belong to `commerce_gallery.dart`.
- Keep catalog facts, accepted preferences, money and outfit validation host-authoritative. A model proposes IDs/commands; it cannot invent prices, overwrite explicit user facts or authorize checkout.
- Inject source/store/session dependencies through `StylistDependencies` and `CommerceSession`. Native defaults belong in `app_dependencies.dart`.
- Domain contracts and catalog snapshots stay independent of Flutter, provider and renderer SDKs. Run `python3 tool/check_architecture.py` after changing imports.
- Run offline tests by default. Never opt into paid model tests, publish, deploy or push without user authorization. Keep keys out of source, assets, fixtures, logs and tracked environment files.
- See [the extension walkthrough](docs/extending.md) for commands, components and catalog sources. Validate wire input before runtime mutation and validate presentation before commit.
- Run the checks relevant to the change and inspect the actual diff. Saved screenshots/checkpoints do not establish a current native build or physical-device behavior.
- Follow [the release gates](docs/open-source-release.md) before publishing; deleting current files does not clear Git history or historical screenshot rights.
