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

## Verification

```sh
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

## License

Apache-2.0. See [LICENSE](LICENSE).
