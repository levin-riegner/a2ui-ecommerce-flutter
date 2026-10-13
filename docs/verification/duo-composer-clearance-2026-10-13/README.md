# Duo composer clearance — 13 October 2026

The opening and conversation composers now use the same preferred 16-point
bottom clearance. Larger native safe insets take precedence. The conversation
dock no longer adds another 8 points below the input pill.

On the fully open iOS 27.1 Duo simulator, the native bottom inset is 34 points.
Both screens place the 52-point input pill at `(32, 583)–(443.5, 635)` in the
951 × 669 viewport, leaving exactly 34 points below it. The composer stays at
the same vertical position when the first conversation starts.

- [Previously running app](before-running.png): approximately 82 points below the composer.
- [Fresh deployment before this change](before-redeployed.png): approximately 34 points below the opening composer. Redeployment alone removed about 48 points of stale spacing.
- [Updated opening screen](after-start.png) / [native geometry](after-start.json).
- [Updated conversation](after-brief.png) / [native geometry](after-brief.json).

The updated captures use the production widgets with the offline Genkit
diagnostic. No web preview or paid provider request was used. Glass remains
clipped to the input pill; resting spacing above the input is unchanged.

Verification: 344 Flutter tests pass. Added layout regressions check matching
opening/conversation positions with both zero and 34-point native bottom
insets, while the existing larger-inset regression retains 64-point clearance.
