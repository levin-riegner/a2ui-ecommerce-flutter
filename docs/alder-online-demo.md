# Local demonstrations

## Offline model

Run the actual Flutter app, bundled catalog and inspector with a deterministic model:

```sh
fvm flutter run -d chrome -t tool/alder_online_demo.dart \
  --dart-define=ALDER_DEMO_OFFLINE=true
```

Use a device ID from `fvm flutter devices` instead of `chrome` for native builds.
No API key or paid model request is required. This entry point starts at the landing
screen and supports structured product choices; its basic model does not interpret
free-form outfit edits. It does not fetch destination forecasts.

The normal app requires a model connection for styling and has no scripted fallback.

## Bounded local provider bridge

For an explicitly authorized live run, put `OPENAI_API_KEY` and `OPENAI_MODEL` in
ignored `.env.local`, then start the bridge:

```sh
python3 tool/alder_online_proxy.py --live --max-requests 12
```

Select a native device and run:

```sh
fvm flutter run -d <device-id> -t tool/alder_online_demo.dart \
  --dart-define-from-file=/private/tmp/alder-online-session.json
```

The bridge keeps the provider key on the Mac. Its temporary configuration contains
a loopback endpoint, session token and model name. Keep it private. The bridge
binds loopback, authenticates requests, forwards only to a fixed HTTPS destination,
rejects redirects and deletes the configuration on normal shutdown.

This live entry point automatically starts a Berlin styling request under €900;
relaunching can incur another charge. Each interaction permits four provider requests,
and the bridge stops forwarding after its total allowance. Stop both processes when
finished. A fresh bridge resets that allowance.

Live mode uses Open-Meteo destination weather. See [using Alder](experience.md) for
forecast behavior and [developer tools](developer-tools.md) for opt-in provider checks.
