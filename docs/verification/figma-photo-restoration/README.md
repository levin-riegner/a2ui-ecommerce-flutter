# Original Figma photograph restoration

Kelvin explicitly requested reversal of the geometric replacements. The ten
original `assets/images/occasions/start-01.png` through `start-10.png` files were
restored from local Git LFS objects at `d67a33b`, without modifying their pixels.
Every SHA-256 and original Figma SHA-1 image hash matches the
[source ledger](../../assets/collage-provenance.json). The app and gallery use
the original ordering, cover fit and special top alignment for image six.
Existing collage geometry and inspector behavior are unchanged.

The public `OccasionArtwork` name is retained for compatibility; its implementation
now displays the supplied photographs. The real app widget test requires all ten
photo assets in the opening mosaic and checks the original crop alignment.

## Verification

- Entire offline Flutter suite: **679 passed** ([log](flutter-tests.txt)).
- Python tooling suite: **56 passed** ([log](python-tests.txt)).
- Flutter analysis: clean ([log](analysis.txt)); architecture import guard passed.
- Asset identity/evidence guard passed. Its public-release mode still reports the
  existing pending Start/design-context photo reviews; restoration does not
  invent a redistribution grant. No publication or push occurred.
- Offline and normal-entry-point iOS Simulator debug builds succeeded. The
  normal entry point was installed and inspected on the open Duo simulator.
  [Native screenshot](native-start.png) confirms photographs replace the drawn
  illustrations and the normal **Connect your model** action is visible.
- [Normal native build log](native-build.txt). Installed debug Dart kernel SHA-256:
  `136c4a3426b6dd212c280c344b33c5d7f84aada81375c4460c5ed0e7e15eda77`.

## Model and data scope

Earlier flow previews used `tool/alder_online_demo.dart` with
`ALDER_DEMO_OFFLINE=true`, an explicitly labelled deterministic model fixture.
The final native preview uses the normal app entry point, with no provider
configured and no paid model request made.

Production supports real providers through `StylistDependencies.connect`.
Its default catalog source reads `assets/data/catalog/products.csv` from the app
bundle. The host loads and validates that catalog before connecting the runtime;
the model searches the loaded facts through host tools. No hosted-CSV URL or HTTP
catalog source is configured by the default composition. The injectable
`CatalogSource` is the extension boundary for a future hosted source.

`tool/export_reference_previews.dart` now writes new photo-based captures into
this folder, keeping the earlier architecture-verification images historical.
