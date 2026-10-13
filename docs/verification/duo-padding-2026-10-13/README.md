# Resting padding and input glass — 13 October 2026

The journey reserves 32 points below its fixed header at the beginning of the
conversation, and 32 points between the last response and the input at the end.
Scrolling can still move content beneath the fixed controls. Native safe insets,
keyboard clearance and bottom breathing room remain respected.

The composer dock reserves space without painting glass over its surrounding
area. Blur and the translucent fill are clipped to the 28-point rounded input
pill; text, microphone and send controls remain sharp and retain their hit areas.

Choice labels now display `Casual`, `Smart-casual`, `Business`, `Cocktail`,
`Black-tie` and `Outdoorsy`, and the season choices follow the same casing.
Bound values and submitted actions retain their original lowercase tokens.

- [At the beginning](after-brief-start.png) / [native snapshot](after-brief-start.json)
- [At the end](after-brief-end.png) / [native snapshot](after-brief-end.json)

These are native iOS 27.1 Duo captures using the production widgets and the
offline Genkit diagnostic. No browser preview or paid provider request was used.
The diagnostic's `ext.layout.scroll` extension selects either resting edge.

Verification: 342 Flutter tests and a clean analyzer. The new edge-spacing test
checks an actual rendered conversation at both ends; the multiline composer
test checks that the blur bounds match the input bounds. Existing brief tests
tap the capitalized labels and confirm unchanged action values.

This supersedes the outer composer backdrop shown in the
[earlier native polish captures](../duo-polish-2026-10-13/README.md).
