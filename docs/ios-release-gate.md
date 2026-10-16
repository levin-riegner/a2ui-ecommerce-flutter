# iOS release gate

Use macOS with Xcode providing iOS Simulator SDK 27.1 or newer. The deployment
target remains iOS 15.0; `ios/Runner/Runner-Bridging-Header.h` enforces the build-SDK
requirement in every configuration.

Select your installed Xcode for the command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tool/verify_ios.sh
```

The script checks the SDK and builds the current source for iOS Simulator with
the pinned Flutter SDK. It fails when the SDK is missing, too old, or compilation
fails. It does not sign or publish an app.

Run the app to check connection, the no-key gallery, speech permissions and the
layouts supported by your target device. Simulator compilation does not establish
physical dictation or device behavior.

CI currently builds Android and web. An iOS job needs a runner with a compatible
Xcode installation and must run the same script.
