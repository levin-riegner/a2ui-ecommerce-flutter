# Compact Duo composer — 13 October 2026

The fully open landscape Duo now uses its lower display area for the composer,
with an actual 8-point bottom gap and 16-point side margins. Its 52-point input
pill is at `(16, 609)–(459.5, 661)` in the 951 × 669 native viewport on both the
opening and conversation screens. Compared with the preceding build, the input
is 26 points lower and 32 points wider.

The previous 34-point ambient bottom padding no longer constrains this pane on
the flat landscape inner display. Cover, portrait and Book layouts retain their
native bottom clearance. Bottom cutouts, horizontal fold bounds and the resized
keyboard viewport still constrain the input. Resting conversation content has
16 points above the input, rather than the earlier 32-point gap.

- [Before](before.png).
- [Opening after](after-start.png) / [native geometry](after-start.json).
- [Conversation after](after-brief.png) / [native geometry](after-brief.json).
- [Device Hub frame](after-framed.png): the pill fits inside the rounded display corners.

Captures use production widgets with the offline Genkit diagnostic. No web
preview or paid provider request was used. Glass is still confined to the input
pill, and microphone/send controls retain their sizes.

All 350 Flutter tests pass with a clean analyzer. Added regressions check the
actual opening and conversation input bounds in open landscape, Book, portrait,
cover, keyboard and bottom-cutout scenarios. Existing fold/state retention and
larger-inset tests remain covered.

This supersedes the composer clearance in the
[preceding captures](../duo-composer-clearance-2026-10-13/README.md) and the
32-point resting input gap in the
[earlier padding captures](../duo-padding-2026-10-13/README.md).
