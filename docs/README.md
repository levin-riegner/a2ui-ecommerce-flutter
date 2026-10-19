# Documentation

Start with setup and the experience guide, then use the architecture and API references to extend the app.

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

## Release

- [Catalog and asset sources](catalog-data.md), [asset provenance](asset-provenance.json) and [photo ledger](assets/collage-provenance.json).
- [iOS release gate](ios-release-gate.md): required SDK and native build procedure.
