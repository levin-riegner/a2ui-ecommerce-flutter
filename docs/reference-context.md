# Reference context

This document records the public-facing decisions behind the starter without copying private project history or credentials into the repository.

## Protocol and renderer

- Treat the catalog as an explicit vocabulary and allowlist. Each component should have a schema, a Flutter builder, stable interaction events, and fixture data.
- Keep the Flutter client focused on rendering and event dispatch. Domain retrieval belongs behind `ProductRepository`; Genkit flows run inside the app through `GenkitAgent`.
- Use separate surfaces for separate responsibilities. This sample keeps the dressing-room state persistent and replaces the inline recommendation surface as the journey advances.
- Model the core journey as `brief → picks → complete look`; keep structured choices and budget changes as explicit events or data-model updates.
- Keep protocol messages and data-model updates testable as exact values. The first test boundary is intentionally small so more component fixtures can be added without coupling them to a service.

Public references:

- [A2UI project](https://github.com/google/A2UI)
- [Genkit](https://genkit.dev/docs/dart/devtools/)
- [Flutter GenUI package](https://pub.dev/packages/genui)
- [Public Flutter travel reference](https://github.com/vpm238/travel-a2ui)

## Design translation

The Figma reference establishes a split experience: a conversational stylist column, a persistent dressing room, and a narrow utility rail on wide layouts. On portrait layouts, the dressing room moves above the conversation so the selected look remains visible while recommendations continue below.

The initial implementation carries over the visual hierarchy and interaction intent with self-contained Flutter primitives:

- light neutral canvas, dark primary actions, compact uppercase eyebrows;
- stylist message followed by a clear next-step recommendation;
- product cards with a reason tag, metadata, price, and selection action;
- dressing-room slots with empty, next, and filled states;
- responsive breakpoints instead of hard-coded device dimensions.

The exact type, spacing, font, icon, and image tokens remain a design-system follow-up in [design-followups.md](design-followups.md).

## Public-safety boundary

- No service account files, API keys, OAuth refresh tokens, internal URLs, private repository names, or private design links belong in this repository.
- The stylist requires BYOK provider/model/key configuration. Genkit Dart runs in the Flutter app, searches the fictional CSV, and calls the selected provider directly. Keys stay in device memory, enter only outgoing HTTP headers, and are cleared on disconnect. Photographs remain bundled. No separate service or service URL is required.
- Scripted agents and deterministic fixtures are restricted to tests and component previews. Missing configuration or failed requests show connection states and never enable a fixture fallback.
- Reused photographs can still reveal real brands or be traced by reverse image search. Review image rights and visible marks before public distribution.
- Before publishing a real connector, add redaction tests and a repository scan for secrets as part of CI.
