# Native Duo polish — 13 October 2026

The later [resting-padding and pill-glass correction](../duo-padding-2026-10-13/README.md)
supersedes the outer composer backdrop in these captures.

Follow-up to the [Figma layout comparison](../figma-layout-2026-10-13/README.md),
using the user's [header blur reference](header-blur-reference.png).

- Product metadata and badges capitalize their first letter: `Tan · Cotton`,
  `Black · Unspecified`, `Evening`. Brand/product names and raw catalog facts
  remain intact, including multiword details such as `Cotton blend`.
- The fixed journey header and composer blur scrolling content beneath them.
  The white wash fades into the page; transparent white avoids a dark gradient
  seam. Controls and the logo remain sharp. The composer has 8 points of inner
  bottom breathing room in addition to the larger of native safe clearance and
  the preferred layout clearance. Keyboard and hinge constraints still win.
- Existing outfit content stays visible while the stylist works. A changed
  slot reveals over its previous contents for 320 ms, keeping the outgoing
  piece fully opaque beneath the incoming piece. Old controls are excluded from
  pointer events and accessibility during the reveal. No loading overlay is
  added. Conversation reveals use 240 ms; Reduce Motion skips the animation.
- GenUI's existing bound-data and action APIs drive the transition. Genkit
  generation, validation, cancellation and outfit commit policy are unchanged.

| Capture | Native evidence |
| --- | --- |
| Before, live journey | [Screenshot](before-native.png) |
| After, open | [Screenshot](after-picks-open.png) / [snapshot](after-picks-open.json) |
| After, Book | [Screenshot](after-picks-book.png) / [snapshot](after-picks-book.json) |
| After, cover | [Screenshot](after-picks-closed.png) / [snapshot](after-picks-closed.json) |
| Select the next piece | [Recording](selection-reveal.mp4) / [final snapshot](after-selection.json) |

Captures use the native iOS 27.1 Duo simulator, not a browser. After captures use
the same production widgets with the repeatable offline Genkit runtime. Before
and after contain different journey text/products. The cover screenshot targets
native display 1; inner screenshots and the recording target display 3.
The final selection snapshot keeps both selected pieces and records the
conversation at its end, 763 / 763 points. No paid provider request was used.

Local checks: 341 Flutter tests, clean analyzer and required formatting, Android
debug and web builds, and native iOS build/run. New tests cover retained outfit
content halfway through the actual bound-data reveal, Reduce Motion, fixed
header scrolling, larger native bottom insets and display-only capitalization.

Reproduce with `tool/figma_layout_probe.dart`. The `ext.layout.stage` service
extension chooses `start`, `brief`, `picks` or `complete`; `ext.layout.select`
selects the first current recommendation through the existing conversation
action and records the updated state. The web preview stays disabled.
