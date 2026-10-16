# Levin+Riegner Flutter template adherence

The migration baseline is [`levin-riegner/flutter-template` at `a1c80948380f797b5fddc02784622f5ad00d0ec9`](https://github.com/levin-riegner/flutter-template/tree/a1c80948380f797b5fddc02784622f5ad00d0ec9), the public `master` revision inspected for this migration. This is a source baseline, not an instruction to track later template changes automatically.

The template's [architecture](https://github.com/levin-riegner/flutter-template/blob/a1c80948380f797b5fddc02784622f5ad00d0ec9/docs/ARCHITECTURE.md) specifies BLoC presentation, repository-orchestrated data, services returning DTOs, constructor injection, immutable models and localized presentation errors/copy. Its actual [dependency composition](https://github.com/levin-riegner/flutter-template/blob/a1c80948380f797b5fddc02784622f5ad00d0ec9/lib/util/dependencies.dart), [article repository](https://github.com/levin-riegner/flutter-template/blob/a1c80948380f797b5fddc02784622f5ad00d0ec9/lib/data/article/repository/article_repository.dart) and [app root](https://github.com/levin-riegner/flutter-template/blob/a1c80948380f797b5fddc02784622f5ad00d0ec9/lib/app/app.dart) provide the structural reference.

## Mapping to this application

| Template convention | Application implementation |
| --- | --- |
| `lib/app`, `lib/presentation`, feature-oriented `lib/data`, `lib/util` | The same top-level separation, with commerce/weather/stylist features and explicit A2UI adapters. |
| Feature BLoCs, immutable events/state, widget builders/listeners | `presentation/connection/bloc/` and `presentation/stylist/bloc/`; `CommerceSession` now extends BLoC. Widgets consume state; the runtime owns commerce rules. |
| Constructor-injected dependencies composed through `get_it` | `util/dependencies.dart` uses an app-owned registry; `util/stylist_dependencies.dart` assembles repositories/services and native defaults. Scoped registries keep tests/embedded instances independent. |
| Repository/source policy and DTO-to-domain mapping | Catalog repository shares a validated snapshot; weather repository owns cache/expiry; stylist repository owns runtime/provider lifetime; storage repository maps immutable snapshots. Services own HTTP/CSV/preferences representation. |
| Immutable models and equality | Freezed generates stylist events/state; Equatable supplies connection-state equality. Existing immutable domain models and validated DTOs remain hand-written where generation adds no useful behavior. |
| Typed router | `app/navigation/router/app_router.dart` and generated route helpers expose the stylist and component/screen galleries. Live sessions stay outside route data. |
| Generated localized strings and typed presentation errors | `app/l10n/app_en.arb`, generated `AppLocalizations` and typed connection errors cover fixed shell/form/shared-widget copy. English is the configured locale. See the remaining scope below. |
| Root lifecycle/resource ownership | App owns router, dependency registry and accepted sessions; connection attempts own late results; stylist repository owns provider/runtime shutdown; renderer owns controller/transport cleanup. |
| Shared design system | Existing Figma-derived components/theme/layouts live under `presentation/shared/`, preserving the product's visual design and accessibility behavior. |

The feature boundaries are enforced by `tool/check_architecture.py`. Its fixture tests deliberately introduce forbidden dependencies, so successful checks establish more than agreement with the folder names.

## Deliberate adaptations

- **Duo/foldable orientation:** retain responsive panes, posture events, rotation, keyboard insets and Reduce Motion. The template's portrait-only bootstrap is not appropriate for this experience.
- **Opt-in providers:** connection setup configures a user-selected provider without a model request. Keys remain in memory for that connection; no key enters the app registry, BLoC state, event diagnostics, storage, assets or generated code. Paid/live tests require explicit authorization.
- **No unrelated infrastructure:** the template's authentication, analytics, Firebase, Datadog, Branch, push, app updates and SQL caching are examples of application integrations, not prerequisites for learning A2UI. This migration does not add them.
- **A2UI resource ownership:** GenUI controller/transport handles live in `CommerceA2uiRenderer`, outside immutable screen state. A presentation validator approves candidate surfaces before the host commits a turn. This preserves transaction safety while using BLoC.
- **Command scheduling:** stylist events share a serial handler. Synchronous admission/cancellation guards preserve immediate duplicate-send blocking and supersede stale model results; a simple article-fetch example does not cover those semantics.
- **Existing contracts:** retain public widget/catalog/gallery entrypoints, stable component/action names, cent-accurate money, explicit-user provenance and version-1 local storage. Compatibility constructors such as `GenkitAgent`, `CsvProductRepository`, `OpenMeteoCityContextSource` and `LocalStylistStore` remain for existing callers; production composition uses the new BLoC/repository/service path.
- **English generated copy:** establish localization infrastructure without inventing translations or changing authoritative catalog/model text. New fixed presentation text should use the generated strings.

## Remaining scope and limits

Runtime-authored validation explanations, some host-composed surface copy and domain forecast labels still contain English text. The migration does not claim complete end-to-end localization or a uniform template `DataState`/localized-error conversion across every host message. Moving that copy requires typed notices/parameters at the domain-to-presentation boundary; domain models must remain independent of Flutter localization.

The follow-on [model catalog and public inspector](model-ui-inspector.md) uses these same boundaries. Root composition exports the actual renderer catalog into pure domain values; the runtime accepts bounded component choices and emits closed diagnostic values. A separate presentation BLoC controls inspection without blocking commerce commands. The host still binds facts and validates A2UI before commit. The inspector distinguishes decoded model summaries, offline fixtures and host-composed surfaces.

This document records source structure and intended contracts. Current test/build/native verification must be established from the commands actually run for a change; the migration map and saved screenshots do not prove current behavior.

## Maintaining the baseline

Before adapting a newer template revision, inspect its actual BLoC, data, dependency, routing and localization code and update this map with the pinned commit. Adopt relevant structural changes without copying unrelated services or replacing the Flutter/GenUI/Genkit stack.

Use `fvm flutter gen-l10n` for ARB generation and `fvm dart run build_runner build` for Freezed/typed-router changes. Keep generated outputs reviewable with their source. Run the offline checks in [CONTRIBUTING.md](../CONTRIBUTING.md), including the architecture guard and its negative fixtures.

The migration's [verification record](verification/flutter-template-migration-2026-10-15.md) includes executed checks, build identities, UI evidence and known limits.
