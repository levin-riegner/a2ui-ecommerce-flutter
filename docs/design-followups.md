# Design follow-ups

Historical design brief. The [current design ingestion guide](design/README.md) and [component catalog](component-catalog.md) document implemented components; the items below preserve the original request and are not a current gap checklist.

These are intentionally kept as design-system follow-ups rather than runtime dependencies. The component gallery can be reviewed using local previews. Stylist journeys require an agent connection and use bundled product photographs.

## For Ryan / design

1. Create scalable examples from an iPhone 13 mini through the iPhone Duo. Use the public [iOS 27 Figma community file](https://www.figma.com/community/file/1651309003795292092) as a reference for Duo frames and verify the responsive breakpoints against the Flutter web shell.
2. Create a mood board covering colors, typography, iconography, spacing, and image treatment. Convert the selected values into named Flutter theme tokens rather than scattering raw values through components.
3. Create a component library that can be imported as Flutter code. Map each reusable component to the A2UI catalog vocabulary, its schema, its interaction states, and at least one fixture message.

## Acceptance notes

- The portrait layout should keep the dressing room visible while recommendations remain reachable below it.
- The wide layout should preserve the chat column, dressing room, and narrow utility rail without relying on a fixed device width.
- Empty, next, filled, selected, disabled, loading, and error states need explicit component definitions before the catalog is expanded substantially.
- Any exported images, fonts, or icons should be committed as reviewed local assets with a clear license. Avoid expiring design-tool URLs in application code.
