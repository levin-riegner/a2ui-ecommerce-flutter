# Repository guidance

- Never push to `master` or `main`. Work on a feature branch and prefer PRs.
- Preserve unrelated work. Check branch/status before edits; stage only requested files.
- Read [CONTRIBUTING.md](CONTRIBUTING.md), [the architecture map](docs/architecture.md) and [the pinned Flutter template map](docs/flutter-template.md) before changing boundaries.
- Follow the Levin+Riegner Flutter template: feature BLoCs/events/immutable state in `lib/presentation/`, repositories/services/DTOs in `lib/data/`, and root composition in `lib/util/`. Keep animation, focus and scroll controllers local to widgets.
- Keep public widgets in `commerce_ui.dart` independent of BLoC, GenUI, Genkit, runtime, data adapters and galleries. Put schemas/bindings in `lib/presentation/stylist/a2ui/`; examples and inspection screens belong to `commerce_gallery.dart`.
- Keep catalog facts, accepted preferences, money and outfit validation host-authoritative. A model proposes IDs/commands; it cannot invent prices, overwrite explicit user facts or authorize checkout.
- Inject repositories/services/session dependencies through constructors. `Dependencies` owns the app registry; native defaults belong in `lib/util/stylist_dependencies.dart`. Keep credentials out of global registries, BLoC state and event diagnostics.
- Domain contracts and catalog snapshots stay independent of Flutter, provider and renderer SDKs. Data must not import presentation or app composition. Shared declarative wire schemas live with domain models; Genkit orchestration stays in the runtime service. Run `python3 tool/check_architecture.py` after changing imports.
- Use generated localization for fixed presentation strings and typed errors mapped at the UI boundary. Preserve existing dynamic model/catalog content and host validation; do not add Flutter localization dependencies to domain code.
- Run offline tests by default. Never opt into paid model tests, publish, deploy or push without user authorization. Keep keys out of source, assets, fixtures, logs and tracked environment files.
- See [the extension walkthrough](docs/extending.md) for commands, components and catalog sources. Validate wire input before runtime mutation and validate presentation before commit.
- Run the checks relevant to the change and inspect the actual diff. Saved screenshots/checkpoints do not establish a current native build or physical-device behavior.
- Follow [the release gates](docs/open-source-release.md) before publishing; deleting current files does not clear Git history or historical screenshot rights.
