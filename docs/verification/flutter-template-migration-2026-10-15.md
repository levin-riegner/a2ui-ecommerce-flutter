# Flutter template migration verification — 15 October 2026

The application now follows the pinned Levin+Riegner Flutter template through feature BLoCs, immutable screen state, repositories/services, scoped dependency composition, typed routes and generated localization. The [template map](../flutter-template.md) explains the retained application-specific behavior and remaining localization scope.

The clean baseline was `68d50f17b4a417b55972b6b343d6d4d768cc580a`. Migration source is local commit `404c87a514c0b7f1519f2c9c09b74ac09ec875a0` on `feat/lr-flutter-template-migration`. The template reference is `a1c80948380f797b5fddc02784622f5ad00d0ec9`. No remote push, deployment, credential configuration or paid provider test was performed.

## Source and build identity

[source-manifest.json](flutter-template-migration-2026-10-15/source-manifest.json) records the hashes of application sources, build manifests and the offline entrypoint/probe. Its file-map fingerprint is `c8bae39b814ea2a83c8dfbe23854a11e0925efe8a32a98b06e76a50f6e94250a`. The files remained unchanged through final tests, builds and UI replay. [build-artifacts.json](flutter-template-migration-2026-10-15/build-artifacts.json) records the actual offline iOS Dart kernel, Android APK and production/offline web JavaScript hashes.

The offline UI build uses `tool/alder_online_demo.dart` with `ALDER_DEMO_OFFLINE=true`, the real host/runtime/GenUI path, bundled catalog and deterministic model callback. Its weather service is disabled. The original baseline binaries were frozen before migration edits. The final web replay uses a separate frozen snapshot and origin, avoiding stale service-worker content.

## Executed checks

| Check | Result | Evidence |
| --- | --- | --- |
| Baseline Flutter tests | 612 passed | [Log](flutter-template-migration-2026-10-15/logs/before-flutter-tests.txt) |
| Final Flutter tests | 648 passed | [Log](flutter-template-migration-2026-10-15/logs/flutter-tests.txt) |
| Baseline / final Python tests | 41 / 53 passed | [Before](flutter-template-migration-2026-10-15/logs/before-python-tests.txt), [after](flutter-template-migration-2026-10-15/logs/python-tests.txt) |
| Static analysis | No issues | [Log](flutter-template-migration-2026-10-15/logs/analyze.txt) |
| Dart formatting | 175 files, zero changes | `dart format --output=none --set-exit-if-changed lib test tools/genkit tool` |
| Generated state/routes | Regeneration wrote zero outputs; generated localization unchanged | [Log](flutter-template-migration-2026-10-15/logs/codegen.txt) |
| Architecture and forbidden-import fixtures | Passed | [Guard](flutter-template-migration-2026-10-15/logs/architecture.txt), Python suite |
| Current assets / catalog | Passed | [Assets](flutter-template-migration-2026-10-15/logs/assets.txt), [catalog](flutter-template-migration-2026-10-15/logs/catalog.txt) |
| Production iOS Simulator debug build | Passed, Xcode 27.1 / SDK 27.1 | [Environment](flutter-template-migration-2026-10-15/logs/ios-environment.txt), [build](flutter-template-migration-2026-10-15/logs/ios-production-build.txt) |
| Offline iOS Simulator debug build and install | Passed | [Build](flutter-template-migration-2026-10-15/logs/ios-offline-build.txt), [install](flutter-template-migration-2026-10-15/logs/ios-install.txt) |
| Production web release build | Passed | [Log](flutter-template-migration-2026-10-15/logs/web-production-build.txt) |
| Offline web debug build | Passed | [Log](flutter-template-migration-2026-10-15/logs/web-offline-build.txt) |
| Android debug APK | Passed | [Log](flutter-template-migration-2026-10-15/logs/android-debug-build.txt) |

Commands used the pinned `.fvm/flutter_sdk/bin/flutter` / `dart`. iOS commands selected `/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer` through `DEVELOPER_DIR`. Production builds used the default entrypoint; UI fixture builds additionally used `-t tool/alder_online_demo.dart --dart-define=ALDER_DEMO_OFFLINE=true`.

Saved text logs normalize carriage returns and trailing terminal padding. Image bytes and their hashes remain unchanged.

## Regressions caught and corrected

- Pending GenUI requests could update a disposed conversation notifier. Session shutdown now releases canceled command waiters, drains the actual transport futures and then disposes renderer resources. A regression uses a real pending `Conversation.sendRequest`; gallery shutdown also covers an uncancellable fixture repository.
- The removal toast could appear before immutable `bagCount` changed. Successful turns now publish the authoritative count before their corresponding surfaces. The test observes the actual surface update and continues to assert zero model calls for local basket operations.
- Rebuilding the app root could change dependency-disposal ownership. Ownership is now captured when the registry is chosen, with a root-rebuild regression.
- Browser UI replay found a text-input configuration assertion on valid brief submission. The same exact action on the frozen baseline did not reproduce it. Submission now releases focus before the outgoing fade. A semantic-activation widget test checks that the original field remains mounted while its input client has closed; final desktop and cold-mobile browser replay confirm the assertion is absent. [Focused tests](flutter-template-migration-2026-10-15/logs/focus-transition-tests.txt).

## Before and after UI replay

Actual controls drove the frozen baseline and final application. No domain/RPC mutation was used to substitute for interaction. Native replay used RocketSim on the Duo simulator. Web replay used Chrome at a confirmed 1456×840 desktop view and a cold-loaded 390×844 mobile view. Browser screenshots have those logical pixel dimensions; baseline desktop DPR was 2 and final desktop DPR was 1, so this is a layout/content comparison rather than a pixel-equality test.

All three final journeys completed the same four-piece €220 look: shirt M/Regular, trousers M/Regular, shoes 41 and a one-size backpack. Changing the shirt quantity to two produced €255 subtotal; remove/Undo retained the chosen sizes; simulated delivery added €3.95 and checkout showed €258.95 with an explicitly simulated receipt. Reset returned to welcome. Mobile also verified bag retention across reset and that a €505 intake draft stayed local until **Find options** committed it.

Native replay retained **Keep this Duo draft** through closed → open → book → closed postures. The completed €220 look remained visible in the open and book layouts; its marker was outside the final closed chat view. A new request was visibly pending before reset; after confirmation and a five-second wait, the welcome screen remained visible without a late reply.

| Matched checkpoint | Before | Final |
| --- | --- | --- |
| Duo cover, completed look and sizes | [PNG](flutter-template-migration-2026-10-15/before-native-cover-complete.png) | [PNG](flutter-template-migration-2026-10-15/after-native-cover-complete.png) |
| Duo open, retained draft and look | [PNG](flutter-template-migration-2026-10-15/before-native-open-draft-retained.png) | [PNG](flutter-template-migration-2026-10-15/after-native-open-draft-retained.png) |
| Desktop, completed look and sizes | [JPEG](flutter-template-migration-2026-10-15/before-web-desktop-complete.jpg) | [JPEG](flutter-template-migration-2026-10-15/after-web-desktop-complete.jpg) |
| Mobile, completed look and sizes | [JPEG](flutter-template-migration-2026-10-15/before-web-mobile-complete.jpg) | [JPEG](flutter-template-migration-2026-10-15/after-web-mobile-complete.jpg) |
| Desktop, simulated receipt | [JPEG](flutter-template-migration-2026-10-15/before-web-desktop-receipt.jpg) | [JPEG](flutter-template-migration-2026-10-15/after-web-desktop-receipt.jpg) |
| Mobile, simulated receipt | [JPEG](flutter-template-migration-2026-10-15/before-web-mobile-receipt.jpg) | [JPEG](flutter-template-migration-2026-10-15/after-web-mobile-receipt.jpg) |

The primary agent visually inspected the four final layout/draft captures against their baseline counterparts. [ui-evidence.json](flutter-template-migration-2026-10-15/ui-evidence.json) records the replay outcomes, image hashes, decoded dimensions and limits. Original image bytes are preserved; browser images originally saved with `.png` names were identified as JPEG and given the correct extension here.

The exact first-submit check and the full final desktop/mobile flows show zero text-input configuration assertions after the fix. The full desktop console recorded one occurrence of the known `RenderAnimatedSize` assertion; mobile recorded five. See [desktop](flutter-template-migration-2026-10-15/logs/web-desktop-console-errors.json), [mobile](flutter-template-migration-2026-10-15/logs/web-mobile-console-errors.json), and the [controlled baseline](flutter-template-migration-2026-10-15/logs/web-submit-baseline-errors.json) / [migration before fix](flutter-template-migration-2026-10-15/logs/web-submit-migration-before-fix-errors.json) comparison. A browser automation transport timeout interrupted an earlier desktop attempt; that incomplete attempt was discarded and the complete final desktop flow was repeated on a fresh tab.

## Limits

Runtime-authored notices, some host surface copy and forecast labels still contain English; the [template map](../flutter-template.md) records this explicitly. The bounded model-facing UI catalog and educational inspector remain the next stage.

The baseline already reproduced `RenderAnimatedSize` mutation assertions in Flutter web debug mode. The final cold-mobile replay still reproduces that existing issue while the visible journey completes. The newly observed text-input assertion is fixed. The production web compiler also emits a Cupertino font-family warning; its build succeeds. This record does not claim an error-free web debug console.

Native interaction evidence is from the Duo simulator, with no physical-device or Android runtime claim. Its cover hardware/status area can obscure the first basket remove control, as it did before migration; the lower-item remove/Undo path was exercised. Native VM exception and request counters were unavailable and are not inferred. Storage/provider contracts are covered by offline tests; no live provider or merchant transaction was exercised.
