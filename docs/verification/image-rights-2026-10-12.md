# Licensed image verification — 2026-10-12

Baseline: `b3263ce205315599523118e956839207b4a04a90` (PR12). Branch:
`fix/alder-asset-rights`. This evidence covers the fourteen current replacement
photos and preserves gallery coverage; it does not validate a provider call or
clear historical image blobs for publication.

## Checks completed

- `python3 tool/verify_image_rights.py`: passed. Fourteen real PNGs, exact ledger
  scope, pixel dimensions, SHA-256/SHA-1, byte counts, source/author/license credits
  in NOTICE, and current/historical manifest distinction verified offline.
- Pillow fully decoded all fourteen RGB PNGs; no output contained EXIF metadata.
  The original bundled dimensions were retained for every file.
- `fvm flutter test test/finalized_screen_gallery_test.dart
  test/adaptive_screen_layout_test.dart test/widget_test.dart`: **47 passed**.
  Existing gallery checks render all fourteen screen compositions at 466×678,
  669×951 and 951×669, including 3.12× text scaling. Existing landing/adaptive
  behavior and widget interactions passed with the replacement files present.
- `fvm flutter analyze`: **no issues**.
- A temporary Flutter widget-test capture harness loaded Jost/Inter and all photo
  assets, rendered the actual `ReferenceApp` landing and `FinalizedScreenGallery`
  widgets, saved the six PNGs below and asserted no framework exceptions. The
  capture check passed. The temporary harness was removed after capture.
- `fvm flutter build web --release`: passed (23 seconds). All fourteen packaged
  PNGs matched the reviewed ledger SHA-256 values. The build emitted the existing
  CupertinoIcons-family warning; no font configuration was changed by this patch.
- `git diff --check`: passed.

## Visual inspection

[Contact sheet of all fourteen replacements](image-rights/replacement-contact-sheet.jpg)
shows the actual committed PNG content at thumbnail size. No original unlicensed
photo is included in this review artifact.

Actual Flutter captures:

- [Phone landing 466×678](image-rights/landing-466x678.png)
- [Portrait landing 669×951](image-rights/landing-669x951.png)
- [Landscape landing 951×669](image-rights/landing-951x669.png)
- [Start gallery composition](image-rights/gallery-0.png)
- [Paris gallery composition](image-rights/gallery-1.png)
- [Berlin gallery composition](image-rights/gallery-4.png)

All fourteen replacement files decode cleanly. The desktop landing retains
its staggered photograph columns, existing clipping and four-pixel gutters.
Compact landings retain the original responsive behavior (the collage is
hidden); they have no new overflow or unreachable controls. Gallery context
thumbnails show the Paris foliage/café and Berlin gate/studio replacements.
The 47 regression checks preserve layouts/actions across the full gallery.
Weather/map/product placeholders in these captures are original design fixtures,
not live data or backend evidence.

The imagery deliberately changes from anonymous full portraits to clothing and
accessory details. The sixth photo retains the existing top alignment. Paris
now uses real autumn foliage rather than an Eiffel Tower view; the dining image
uses a café table rather than wine/cutlery; the studio is unoccupied. These
visible substitutions are documented in the rights ledger for design review.

## Limits

Native simulator/device screenshots and microphone/provider behavior were not
rerun for an asset-only change. Combined hosting/browser packaging and font/legal
notice checks belong to the hosting sibling. Source rights were reviewed using
the individual author/source pages and explicit licenses; automated hashes alone
cannot establish permissions. The repo's pre-existing product-photo permission
is retained, not newly substantiated or broadened by this audit.
