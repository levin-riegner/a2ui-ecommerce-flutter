# iOS release gate

Run this gate on a Mac with an installed Xcode providing iOS 27.1 SDK or newer. The deployment target remains iOS 15.0. `ios/Runner/Runner-Bridging-Header.h` enforces the build-SDK requirement for every configuration.

As checked on 2026-10-15, GitHub's documented [macOS 26 Intel image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md) and [macOS 26 ARM image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md) did not list Xcode/iOS 27.1. Hosted images change; verify the actual runner inventory before adding an automated job. Ubuntu CI passes do not count as an iOS build. Until a compatible runner is configured, iOS remains an explicit manual release gate.

Select Xcode per command without changing the machine's global selection:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer   bash tool/verify_ios.sh
```

Use your installed Xcode path. The script verifies the selected SDK and builds the current source for iOS Simulator with the pinned Flutter SDK. It fails if the SDK is missing/too old or the build fails. It neither signs nor publishes an app.

Record the commit/diff, `xcodebuild -version`, SDK version, command and outcome in the release review. Then run the app on the supported simulator and verify connection/gallery, speech permission handling and posture layout where available. Physical-device/glasses behavior requires its own evidence; a successful simulator build cannot establish it.

A future CI job must select an actually installed compatible Xcode, invoke this script and retain the build log. Do not use a fictional runner label or silently skip native compilation while reporting an iOS pass.
