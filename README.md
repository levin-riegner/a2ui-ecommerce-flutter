# A2UI Flutter Commerce Reference

Flutter reference for building responsive commerce experiences with declarative A2UI surfaces. It targets Flutter web, iOS, and Android, with the responsive shell designed to cover compact phone layouts and the wider iPhone Duo showcase frame.

Currently renders a brief surface, a persistent dressing-room surface, and an inline recommendation surface, using deterministic local fixtures so the UI can be reviewed without credentials or a live agent service.

## Run

Use the project-pinned SDK for all commands:

```sh
fvm install
fvm flutter pub get

# Web (default fixture data)
fvm flutter run -d chrome

# iOS
fvm flutter run -d ios

# Android
fvm flutter run -d android

# Optional: exercise the checked-in CSV adapter
fvm flutter run -d chrome --dart-define=USE_CSV_FIXTURES=true

# Verify the Android artifact without launching a device
fvm flutter build apk --debug
```

The app uses deterministic fixtures by default. The `--dart-define` is only needed to switch the repository implementation to CSV for that run. The pinned version is recorded in [.fvmrc](.fvmrc); use `fvm flutter` and `fvm dart` so contributors use the same SDK.

## Architecture and A2UI shape

See [architecture.md](docs/architecture.md) for the layer boundaries, surface lifecycle, message shape, and event flow. Open the **Explore component catalog** action on the landing screen to see the complete 24-component vocabulary in a compact visual index.

## Data sources

The default app uses `FixtureProductRepository`. `CsvProductRepository` demonstrates the local CSV contract and reads `assets/data/products.csv`; it can be replaced by a network-backed implementation without changing the catalog widgets or surface messages.

The CSV parser handles common quoted fields but is intentionally small and does not implement multiline CSV records. A production adapter should use a full CSV parser and validate external data before it reaches an A2UI surface.

## Product catalog and images

`assets/data/catalog/products.csv` provisions 200 fictional products for the next
stylist integration. Its `image_asset` column stores local paths to JPEGs under
`assets/images/products/`; the CSV does not embed image bytes. The existing demo
continues to use its fixture data and original CSV adapter.

Product names, brands, descriptions, prices, and identifiers in the new catalog
are fictional. The bundled photographs are reused with permission, resized, and
saved without image metadata. They are not presented as AI-generated images.
Visible marks and reverse image search may still identify a photographed item.
See [NOTICE](NOTICE) for image and project credits.

Product JPEGs use Git LFS. Install Git LFS before cloning, or run
`git lfs install && git lfs pull` in an existing checkout. CI downloads the image
bytes and checks their JPEG signatures before building.

Run `python3 tools/catalog/validate.py assets/data/catalog/products.csv` before
publishing catalog changes. Add `--source` once per private source export to check
for copied names, vendors, handles, and identifiers. Keep source exports outside
this repository.

For future expansion, `tools/catalog/import_images.py` accepts a private ordered
URL file and an explicit `--allowed-host`, then writes renamed JPEGs. The importer
requires Pillow; keep the URL file outside the repository.

## Verification

```sh
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

## License

Apache-2.0, including the bundled demo images. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for attribution.
