# Reference architecture start-screen captures

Fresh renders of the current disconnected `ReferenceApp`, captured on 2026-10-15 with the production widget tree and bundled Inter/Jost variable fonts. No provider is configured or called. No context-photo gallery or historical source photograph is shown.

Reproduce from the repository root:

```sh
fvm flutter test tool/export_reference_previews.dart --reporter expanded
```

The exporter uses Flutter's offline widget-test engine and `RepaintBoundary.toImage` at pixel ratio 1. These are current Flutter-rendered artifacts, not simulator/device evidence. It checks for Flutter exceptions and a reachable Connect control before capture. `captures.json` records dimensions, fonts, state and built artwork tiles; built tiles may be outside the visible viewport.

- [Phone-sized start, 466 × 800](start-466x800.png): text-first compact layout, readable examples and fully visible Connect button. The artwork is outside the visible initial viewport, consistent with the existing compact layout.
- [Wide start, 951 × 669](start-951x669.png): original geometric garment art in the staggered collage, alongside the same text and Connect action. Art crops at top/bottom by design; text and controls are not clipped.

Both PNGs were directly inspected. No unintended overflow or text/control clipping was found at these sizes. Other sizes, text scales, native posture and device behavior remain covered separately by their corresponding tests/evidence.

The art is drawn from original source in `lib/src/catalog/occasion_artwork.dart`; no removed Start PNGs or unresolved design context photos are used. These two captures follow the project license. Historical evidence elsewhere retains separate release-review gates documented in [open-source-release.md](../../open-source-release.md).
