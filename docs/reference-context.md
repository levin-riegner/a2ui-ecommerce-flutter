# Reference context

This document records the public-facing decisions behind the starter without copying private project history or credentials into the repository.

## Protocol and renderer

- Treat the catalog as an explicit vocabulary and allowlist. Each component should have a schema, a Flutter builder, stable interaction events, and fixture data.
- Keep the Flutter client focused on rendering and event dispatch. Domain retrieval belongs behind `ProductRepository`; agent transport belongs behind the stub transport callback.
- Use separate surfaces for separate responsibilities. This sample keeps the dressing-room state persistent and replaces the inline recommendation surface as the journey advances.
- Model the core journey as `brief → picks → complete look`; keep structured choices and budget changes as explicit events or data-model updates.
- Keep protocol messages and data-model updates testable as exact values. The first test boundary is intentionally small so more component fixtures can be added without coupling them to a service.

Public references:

- [A2UI project](https://github.com/google/A2UI)
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
- The client currently uses deterministic fixtures and a checked-in CSV example.
- `USE_CSV_FIXTURES=true` switches the app to the CSV adapter without changing the A2UI catalog or transport code.
- A future live adapter should obtain short-lived, least-privilege data through a trusted service boundary and should keep secrets out of the iOS bundle and generated web assets.
- Before publishing a real connector, add redaction tests and a repository scan for secrets as part of CI.
