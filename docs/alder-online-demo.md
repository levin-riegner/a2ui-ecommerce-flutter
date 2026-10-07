# Alder online demo

Alder uses the existing Genkit stylist, bundled fictional catalog, and Flutter
GenUI/A2UI renderer. Open-Meteo destination lookup and a five-day forecast feed
both the weather card and model facts. The destination is a named city, not GPS.
Application code constructs the layouts from validated products.

## Free native verification

This explicit developer mode runs the real app with the deterministic offline
model and live, free forecast endpoints. It starts at the landing page and delays
model responses so the loading/validated preview can be inspected. It requires
no provider credentials and makes no paid model calls.

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer \
fvm flutter run -d 473AFAD8-39CA-4DA6-8D3A-443070830101 \
  -t tool/alder_online_demo.dart --dart-define=ALDER_DEMO_OFFLINE=true --no-pub
```

Select another available device ID if necessary. This is a developer entry point;
the normal app still requires a model connection and has no scripted fallback.
The local `ext.alder.capture` VM extension reports UI errors, conversation rows,
forecast, pending surface, and offline request count without recording credentials.
The basic offline model does not interpret verbal outfit edits. An offline-only
`ext.alder.remove` extension accepts a selected `productId` and sends the normal
A2UI removal event for native regression checks; that is a simulated user action.

## Bounded live demonstration

Live model calls require explicit approval for a bounded run. Put
`OPENAI_API_KEY` and `OPENAI_MODEL` in the ignored `.env.local` file. After approval,
start the development bridge:

```sh
python3 tool/alder_online_proxy.py --live --max-requests 12
```

In another terminal:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer \
fvm flutter run -d 473AFAD8-39CA-4DA6-8D3A-443070830101 \
  -t tool/alder_online_demo.dart \
  --dart-define-from-file=/private/tmp/alder-online-session.json --no-pub
```

The entry point starts a smart casual Berlin work-day brief under €900. This is
one paid interaction; relaunching starts another. Each turn permits at most four
provider requests. The bridge defaults to a session allowance of twelve requests
and rejects non-positive/unbounded allowances. Stop both processes when finished.
Keep session files, provider keys, VM URLs, and auth evidence private.

The Mac holds the provider key. The app receives a temporary bridge token and model
name. The bridge binds loopback, authenticates that token, forwards only to a fixed
HTTPS endpoint, rejects redirects, sanitizes provider errors, and deletes its
private session file on normal shutdown. It is local development tooling.
Exhausting its allowance shows a specific message; an upstream provider 429 keeps
the normal provider error. Restarting the bridge replenishes the allowance and is
another live run that needs authorization.

## Interaction checks

1. Dictate an occasion into an editable draft, review/edit it, then send. Recognition
   availability and permissions depend on the device; simulator permission checks
   and mocked speech callbacks do not establish physical microphone transcription.
2. Inspect loading and catalog-validated recommendation previews, then final guidance.
3. Choose/remove products and verify the next category, dressing-room slots, and budget.
4. Change the destination (for example, ask for Paris today). Preset cities and common
   demo destinations can be resolved before generation; the stylist can save any
   explicit city using `save_outfit`. Include the country for ambiguous names.
5. Refresh the latest forecast. It makes no model call and changes no recommendations,
   clarification controls, outfit, conversation rows, or previous responses. Previous
   response controls remain read-only.
6. If lookup fails, the current destination shows an unavailable notice rather than
   retaining the previous city's forecast. A failed model turn rolls back the entire
   draft. Cancellation discards pending forecast results and releases a new journey.

The source validates coordinates, units, consecutive dates, WMO codes, and daily
columns, caches results for 15 minutes, and bypasses the cache on explicit refresh.
Forecast dates are supplied to the model; they are not historical seasonal averages
or evidence for travel dates outside that range.

Forecast attribution: [Open-Meteo forecast API](https://open-meteo.com/en/docs),
[Open-Meteo geocoding / GeoNames](https://open-meteo.com/en/docs/geocoding-api).
The public service is used for private prototyping under its
[terms](https://open-meteo.com/en/terms); commercial hosting requires an appropriately
licensed service.

## Evidence boundaries

The preserved October 6 notes describe an older live Duo run. They are historical
and do not validate this combined implementation. The normal Flutter/Python suites
use offline models and mocked HTTP; Android/web builds verify compilation. Current
[native simulator evidence and remaining gaps](verification/alder-online-simulator-2026-10-07.json)
are recorded separately. The combined checkout passed 311 Flutter tests and eight
Python tests, formatting, analyzer, catalog validation, saved checkpoint validation,
and Android/web builds. Live-provider
behavior, physical microphone transcription, real inventory, production hosting,
and unrestricted model-generated layouts are separate work.
