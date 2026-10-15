#!/usr/bin/env bash
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS verification requires macOS with Xcode and iOS SDK 27.1 or newer." >&2
  exit 1
fi
xcodebuild -version
alder_sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
python3 - "$alder_sdk_version" <<'PYSDK'
import sys
version = tuple(int(part) for part in sys.argv[1].split('.')[:2])
if version < (27, 1):
    raise SystemExit('Select Xcode with iOS Simulator SDK 27.1 or newer; found ' + sys.argv[1])
print('Selected iOS Simulator SDK ' + sys.argv[1])
PYSDK
fvm flutter pub get
fvm flutter build ios --simulator --debug
