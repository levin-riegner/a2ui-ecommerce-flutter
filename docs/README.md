# Documentation

The implementation and shared schemas are the source of truth. The guides below describe the current checkout. Dated audits, plans and verification records preserve the state they inspected; they are not a claim that the current source has passed a live-provider or native-device check.

## Start and use

- [Getting started](getting-started.md): prerequisites, free first run, providers, native builds and troubleshooting.
- [Using Alder](experience.md): styling, accepted facts, recovery, dictation, weather and local state.
- [Catalog and asset sources](catalog-data.md): fictional catalog, retrieval, enrichment and image terms.
- [Product data and demo commerce](product-data-and-demo-commerce.md): evidence-bearing attributes, sizes, fictional stock and simulated checkout.

## Build and extend

- [Architecture](architecture.md): layers, ownership, validation and A2UI lifecycle.
- [Levin+Riegner template map](flutter-template.md): pinned baseline, conventions and deliberate adaptations.
- [API and A2UI contracts](api-reference.md): Dart entry points, turn input/result, tools, commands and surfaces.
- [Genkit integration](genkit-reference.md): pinned providers, transport, cancellation, retries and compatibility handling.
- [Model UI catalog and inspector](model-ui-inspector.md): actual schemas, supported choices and safe exchange summaries.
- [Component catalog](component-catalog.md) and [design ingestion](design/README.md): reusable widgets, schema exports and source mappings.
- [Extending the reference](extending.md): adding sources, commands, components, routes and localization.
- [Contributing](../CONTRIBUTING.md): setup, generators, offline checks and PR conventions.
- [Developer tools](developer-tools.md) and [online/offline demonstration](alder-online-demo.md): reflection, fixtures and separately opted-in paid checks.
- [Catalog curation](catalog-import.md): data preparation, fictional prices and optional variant groups.
- [Flow edge cases](stylist-flow-edge-cases.md): lifecycle, rollback, sizing and recovery matrix.

## Release and evidence

- [2026-10-16 release audit](release-audit-2026-10-16.md): first-run findings, fixes, executed checks and remaining publication blockers.

- [Public-release gates](open-source-release.md), [asset provenance](asset-provenance.json), [photo ledger](assets/collage-provenance.json), [NOTICE](../NOTICE) and [SECURITY.md](../SECURITY.md).
- [iOS release gate](ios-release-gate.md): required SDK and current-source native build procedure.
- [Duo simulator verification](duo-simulator-verification.md): posture matrix and dated evidence.
- [`verification/`](verification/): dated checks and captured artifacts. Read each record's scope and limits before reusing it.

## Historical context and planning

These explain earlier decisions and proposed work. Later implementation can supersede individual gaps or paths; use the current guides and source before acting on a recommendation.

- [Reference context](reference-context.md) and [design follow-ups](design-followups.md).
- [Component library audit](component-library-audit.md), [inventory opportunities](inventory-component-opportunities.md) and [component adoption record](component-adoption-progress.md).
- [Foldable package review](foldable-package-review.md): dated package comparison, not a current package recommendation.
