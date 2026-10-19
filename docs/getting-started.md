# Getting started

Alder runs its host runtime, local catalog and GenUI renderer inside Flutter. A normal checkout needs no Node service, database, Firebase project or cloud deployment.

## Prerequisites

- Git and Git LFS. Install LFS before cloning, or hydrate an existing checkout with `git lfs install` and `git lfs pull`. Product JPEGs and Start collage PNGs must contain real image bytes, not LFS pointers.
- FVM and the Flutter version pinned in [`.fvmrc`](../.fvmrc). Run `fvm install`, then `fvm flutter doctor -v` to check your platform toolchain.
- Chrome for web; Android SDK and a device/emulator for Android; macOS and compatible Xcode for iOS. This repository contains Android, iOS and web targets.

From the repository root:

```sh
git lfs install
git lfs pull
fvm install
fvm flutter pub get
fvm flutter devices
fvm flutter run -d chrome
```

Generated localization, Freezed and route sources are checked in. A new checkout does not require running build_runner. Contributor generation commands are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## First run without credentials

Scroll down on the landing screen and choose **Explore component catalog** on the landing screen. Its widgets, sample surfaces and controls make no provider requests. The gallery demonstrates components; it is separate from a connected stylist journey.

For a deterministic connected demonstration, use the explicit [offline developer entry point](alder-online-demo.md). The normal app has no scripted fallback when a model is missing or fails. The offline developer entry point can still use the public weather service; it is free of paid model calls, rather than a guarantee of zero networking.

## Connect a model

Choose **Connect your model**, select Google Gemini, OpenAI, Anthropic or OpenAI-compatible, and enter a model ID supporting function tools and a provider API key. There is no default provider/model/key in the public app. OpenAI-compatible connections also require the API base URL, including its version path, such as `https://your-provider.example/v1`.

Remote providers require HTTPS; loopback HTTP is accepted for local compatible endpoints. Native operating systems may require additional configuration for cleartext local HTTP. Web requires the provider to allow browser requests through CORS; a working native connection does not establish browser support.

Connecting loads the catalog and configures Genkit locally. It neither verifies the key nor sends a model request. Starting a journey, chatting, selecting/removing products and Retry can invoke the provider, with at most four model requests per interaction. Provider availability, quotas and charges depend on your account and model.

The app calls the selected provider directly. The key remains in device memory, is inserted into outgoing provider headers and is cleared by **New journey → Disconnect model**. Reloading requires configuring it again. Never embed a key in source, assets or `--dart-define` values. Accepted preferences, saved looks and demo bag state are stored separately; see [using Alder](experience.md).

## Native platforms

For Android, configure the Android SDK and accept the licenses reported by `fvm flutter doctor -v`. The Android project targets Java 17 compatibility; use the toolchain selected by Flutter/Android Studio. Select an available device with `fvm flutter run -d <device-id>`.

For iOS, select Xcode providing **iOS 27.1 SDK or newer**. The build checks this for Debug, Profile and Release, including simulator builds. The deployment target remains iOS 15.0. Follow [the iOS gate](ios-release-gate.md); use your installed Xcode path when setting `DEVELOPER_DIR`.

Dictation requests microphone/speech permissions on first use. Recognition depends on the device/browser and can use remote processing. Rebuild native applications after changing plugins; hot reload cannot register a native plugin. Simulator UI tests do not establish physical microphone transcription.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Missing images or invalid JPEG bytes | Run `git lfs pull` and the catalog/release-asset checks in CONTRIBUTING. |
| Connected, but the first message fails | Setup does not verify credentials. Check the key, model ID, tool support, quota and provider error. |
| Native works, browser fails | Check provider CORS support; do not weaken browser security or put keys in a public proxy. |
| iOS SDK build failure | Select Xcode with iOS 27.1 or newer and run the iOS gate. |
| Dictation unavailable | Check platform recognition support and permissions; rebuild after plugin changes. |
| Failed turn | Retry explicitly; the host retains the previous committed look. |

See [using Alder](experience.md) for preferences, weather, local storage and recovery, and [developer tools](developer-tools.md) for bounded opt-in provider tests.
