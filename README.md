# A2UI Flutter Commerce Reference

Flutter reference for building responsive commerce experiences with declarative A2UI surfaces. It targets Flutter web, iOS, and Android, with the responsive shell designed to cover compact phone layouts and the wider iPhone Duo showcase frame.

The personal stylist requires an agent connection. The agent searches the fictional catalog and sends A2UI recommendations and dressing-room updates to Flutter. Missing configuration or connection failures are shown explicitly; the app does not switch to a scripted stylist.

## Run

Use the SDK pinned in [.fvmrc](.fvmrc):

```sh
fvm install
fvm flutter pub get
```

Start the service in [agent-service/](agent-service/) with your own server-side credentials. Starting a journey, sending a message, selecting or removing a product, and retrying a failed turn can make a paid model request.

```sh
# Terminal 1: local agent service (requires Node 20 or later).
cd agent-service
DEV_ORIGIN=http://localhost:5173 OPENAI_API_KEY=... OPENAI_MODEL=... npm start

# Terminal 2: Flutter web client.
fvm flutter run -d chrome --web-port 5173 \
  --dart-define=AGENT_SERVICE_URL=http://127.0.0.1:8787
```

Use the same `AGENT_SERVICE_URL` define for iOS and Android. For an Android emulator, use `http://10.0.2.2:8787` to reach the host. For native devices and production builds, use an HTTPS service reachable from the device. The included service binds to loopback and is intended for local development; configure the Flutter URL for your environment. Keep credentials on the service.

Without a valid HTTP(S) service URL, journey controls are disabled and the app shows that the stylist needs a connection. The component gallery remains available. During an agent turn, the app shows progress and disables chat and product actions. Failed turns show a Retry action that resends the original message or selection; a restarted session asks you to select the piece again.

Product JPEGs are tracked with Git LFS. Install Git LFS before cloning or run `git lfs install && git lfs pull` in an existing checkout so Flutter receives the image bytes rather than pointer files. CI fetches LFS assets and validates their JPEG signatures before building.

## Architecture and A2UI shape

See [architecture.md](docs/architecture.md) for the layer boundaries, surface lifecycle, message shape, and event flow. Open the **Explore component catalog** action on the landing screen to see the complete 24-component vocabulary in a compact visual index.

## Data sources

The agent service searches `assets/data/catalog/products.csv` and sends A2UI messages through `RemoteAgent`. Flutter renders the bundled product photographs from their `image_asset` paths. `CsvProductRepository`, `FixtureProductRepository`, and `StubAgent` remain available for tests and component previews through explicit agent injection; they are not runtime fallback modes.

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
