# A2UI Flutter Commerce Reference

Flutter reference for building responsive commerce experiences with declarative A2UI surfaces. It targets Flutter web, iOS, and Android, with the responsive shell designed to cover compact phone layouts and the wider iPhone Duo showcase frame.

Renders a brief surface, a persistent dressing-room surface, and inline recommendations. The default offline demo reads a fictional local product catalog and bundled product photographs.

## Run

Use the project-pinned SDK for all commands:

```sh
fvm install
fvm flutter pub get

# Web (offline catalog demo)
fvm flutter run -d chrome

# iOS
fvm flutter run -d ios

# Android
fvm flutter run -d android

# Verify the Android artifact without launching a device
fvm flutter build apk --debug
```

The app uses `assets/data/catalog/products.csv` by default. Its `image_asset` column points to 200 bundled JPEGs under `assets/images/products/`; the CSV contains paths, not image bytes. The pinned SDK is recorded in [.fvmrc](.fvmrc); use `fvm flutter` and `fvm dart` so contributors use the same SDK.

Product JPEGs are tracked with Git LFS. Install Git LFS before cloning or run `git lfs install && git lfs pull` in an existing checkout so Flutter receives the image bytes rather than pointer files. CI fetches LFS assets and validates their JPEG signatures before building.

## Architecture and A2UI shape

See [architecture.md](docs/architecture.md) for the layer boundaries, surface lifecycle, message shape, and event flow. Open the **Explore component catalog** action on the landing screen to see the complete 24-component vocabulary in a compact visual index.

## Data sources

The default offline app uses `CsvProductRepository` and reads `assets/data/catalog/products.csv`. `FixtureProductRepository` remains available for small deterministic tests.

The CSV parser handles quoted commas, escaped quotes, and multiline fields. Run `python3 tools/catalog/validate.py assets/data/catalog/products.csv` before publishing catalog changes. Add `--source` once per private source export when checking for source identifiers; the original exports are not part of this repository.

The CSV uses fictional names, brands, descriptions, prices, and IDs. The approved product photographs are reused as local assets, resized and saved without image metadata. Visible marks on products and reverse image search can still identify a photographed item; the image bundle does not provide image-level unlinkability. For future catalog expansion, `tools/catalog/import_images.py` accepts a private, ordered URL file and an explicit `--allowed-host`, then writes renamed JPEGs. Keep that URL file outside the repository; the importer requires Pillow.

The bundled photographs are used with permission for this public demo. They are existing photographs, not presented as AI-generated images. See [NOTICE](NOTICE) for image and project credits.

## Verification

```sh
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

## License

Apache-2.0, including the bundled demo images. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for attribution.
