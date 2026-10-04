# Foldable and iPhone Duo package review

Reviewed **2026-10-04 at approximately 18:00 UTC**. This is a research snapshot; no dependency, lockfile, native configuration, or global Xcode selection was changed.

Integration follow-up: the app now pins `foldable` 1.0.5 behind `DuoLayoutAdapter`. See [native simulator verification](duo-simulator-verification.md) for actual signal checks, reproduction steps and remaining limits; the research table below remains the original package comparison snapshot.

## Recommendation for this app

Keep the reusable component and layout foundation in Flutter: `LayoutBuilder`, `SafeArea`, local constraints, accessible text sizing, and injected display-region data. This preserves the custom design and supports compact phones, wide windows, web, and simulated fold configurations without introducing a navigation framework.

For **actual iOS Duo hinge and posture reporting**, evaluate **`foldable` 1.0.5** behind a small platform adapter. Flutter's current SDK reports native `DisplayFeature` values only on Android; an iOS window getting wider does not supply a hinge rectangle. The pinned Flutter 3.47.4 SDK says the same in `dart:ui/window.dart`. Width-based adaptation and injected hinge tests therefore establish reusable layouts, but do not establish native iPhone Duo fold detection. [Flutter DisplayFeature API](https://api.flutter.dev/flutter/dart-ui/DisplayFeature-class.html)

Apple's Duo guidance favors adapting existing content with size classes and retaining a continuous experience. Its `UIHingeInteraction` API reports hinge changes and is currently marked **iOS 27.1 beta**. Availability was checked in Apple's documentation JSON, rather than inferred from package marketing or an iOS platform badge. [Apple Duo design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Apple hinge API](https://developer.apple.com/documentation/uikit/uihingeinteraction), [API availability metadata](https://developer.apple.com/tutorials/data/documentation/uikit/uihingeinteraction.json)

If the product later needs native Liquid Glass toolbars and tab bars, separately evaluate **`adaptive_platform_ui`**. If it needs a whole fold-aware layout/navigation framework, compare **`duo_dynamic_sizing`**. Neither is necessary to extract reusable commerce components today.

## Current releases and popularity

Versions and exact publication dates come from the live pub.dev package API. Likes, points, and **30-day download counts** come from `/api/packages/<name>/score`; they are not lifetime totals, weekly downloads, unique users, or proof of reliability. Cached package pages showed some older counts and versions, so the API snapshot takes precedence. Points below are out of 160.

### iPhone Duo and fold-specific candidates

| Package | Latest stable; published UTC | Likes | Points | Downloads / 30 days | Verified scope and fit |
| --- | --- | ---: | ---: | ---: | --- |
| [adaptive_platform_ui](https://pub.dev/packages/adaptive_platform_ui) | 1.0.1; 2026-09-19 | 415 | 160 | 12,707 | Native Android/iOS controls; depends on `foldable`. Publisher describes Duo vertical toolbars and tab bars. Most popular Duo-aware UI candidate in this shortlist; broader than a layout adapter and native platform badges exclude web. |
| [foldable](https://pub.dev/packages/foldable) | 1.0.5; 2026-09-26 | 18 | 160 | 2,341 | iOS native bridge for hinge angle, posture, reserved regions and size classes. Minimal recommendation when retaining our own widgets. Other platforms have an unsupported/no-op path, not native hinge support supplied by this plugin. |
| [duo_dynamic_sizing](https://pub.dev/packages/duo_dynamic_sizing) | 2.0.3; 2026-09-30 | 2 | 160 | 491 | Native iOS/Android hardware bridge plus panes, navigation and simulated poses; web/desktop fallback registrations. Newest runtime Duo candidate reviewed; very small adoption sample. |
| [iphone_duo_ui_pro](https://pub.dev/packages/iphone_duo_ui_pro) | 0.3.0; 2026-09-21 | 4 | 150 | 350 | Native iOS bridge and fold-aware widgets. Duo APIs require an explicit `DUO_SDK_27_1` compile flag; without it only size classes/window size work. Pub score reports legacy native build integration, rather than SwiftPM support. |
| [nitro_fold_duo](https://pub.dev/packages/nitro_fold_duo) | 0.0.1; 2026-09-21 | 2 | 160 | 69 | Native/FFI plugin, SwiftPM tag, Nitro and Signals dependencies; native platform tags omit web. Very early version and extra infrastructure for this app. Not the first choice. |
| [flutter_foldable_kit](https://pub.dev/packages/flutter_foldable_kit) | 1.1.0; 2026-09-11 | 4 | 160 | 114 | Dart layout widgets around fold/display information. Manifest has no native plugin bridge: an iOS badge does not establish access to Apple's hinge APIs. Useful abstractions, but cannot alone fill the native iOS signal gap. |
| [dual_screen](https://pub.dev/packages/dual_screen) | 1.0.4; 2023-04-25 | 154 | 150 | 1,164 | Microsoft's older TwoPane/hinge package. Native sensor implementation is Android-only. Its package description predates Duo; do not treat Surface Duo support as iPhone Duo support. |

By the measured counts, `adaptive_platform_ui` leads the Duo-aware UI shortlist. `foldable` has the strongest adoption among the smaller native signal adapters reviewed. `duo_dynamic_sizing` is newer, but its current usage does not justify calling it the most popular.

### Popular general responsive packages and preview tools

| Package | Latest stable; published UTC | Likes | Points | Downloads / 30 days | Fit |
| --- | --- | ---: | ---: | ---: | --- |
| [flutter_screenutil](https://pub.dev/packages/flutter_screenutil) | 5.9.3; 2024-05-31 | 5,119 | 150 | 373,080 | Most popular general sizing utility reviewed. Design-size scaling is not native hinge/posture support; unnecessary for our constraint-based components. |
| [responsive_framework](https://pub.dev/packages/responsive_framework) | 1.5.1; 2024-08-26 | 3,363 | 150 | 156,308 | Popular Dart breakpoint/resizing framework across iOS/web/desktop. No native Duo signal bridge. Optional for a larger shared breakpoint system; SDK APIs already meet current needs. |
| [responsive_builder](https://pub.dev/packages/responsive_builder) | 0.7.1; 2024-07-03 | 1,736 | 150 | 111,064 | Dart responsive builders, with Provider dependency. Device/width branching does not detect Apple's fold state. |
| [custom_adaptive_scaffold](https://pub.dev/packages/custom_adaptive_scaffold) | 5.3.0; 2026-07-21 | 30 | 160 | 1,222 | Maintained community scaffold/layout fork with split-body utilities. All major platforms; Material navigation scope and no native iOS hinge bridge. |
| [flutter_adaptive_scaffold](https://pub.dev/packages/flutter_adaptive_scaffold) | 0.3.3+1; 2025-05-06 | 952 | 150 | 6,763 | **Discontinued and unlisted.** Do not adopt as a new dependency. |
| [device_lab](https://pub.dev/packages/device_lab) | 0.3.2; 2026-09-29 | 3 | 160 | 275 | Preview/golden tool that injects simulated display features. Useful for a future development gallery; simulation is not native hardware support. Manifest depends on `flutter_test`, so keep it out of the production dependency path. |

Also inspected `duo_motion` 1.0.2 (2026-09-24; 11 likes; 198 downloads) and `duo_animation` 0.1.0 (2026-09-10; 1 like; 85 downloads). Their tilt/shader effects do not solve reusable pane layout or native fold-region reporting. [duo_motion](https://pub.dev/packages/duo_motion), [duo_animation](https://pub.dev/packages/duo_animation)

## Native integration and maintenance review

The app pins Flutter **3.47.4**, Dart **^3.13.3**, and enables Swift Package Manager. Current Runner deployment targets are already **iOS 15.0**, and its Info.plist defines the UIScene configuration. Package metadata minimums below are compatible with the pinned Dart/Flutter versions; this is a manifest check, not a dependency-resolution or native-build result.

### `foldable`: preferred native signal adapter candidate

- Dart ^3.5.0 / Flutter >=3.24.0; SwiftPM and CocoaPods manifests both target iOS 15.0. SwiftPM uses Swift tools 5.9 and the standard local FlutterFramework product. [Manifest](https://github.com/berkaycatak/foldable/blob/main/ios/foldable/Package.swift), [pubspec](https://github.com/berkaycatak/foldable/blob/main/pubspec.yaml)
- Default source uses Objective-C runtime lookup. Typed iOS 27.1 calls are gated behind `FOLDABLE_NATIVE_API` and runtime availability; missing API classes choose an unsupported implementation. This supports source compatibility with an older SDK, but actual hinge reporting still depends on OS/API availability. [Source factory](https://github.com/berkaycatak/foldable/blob/main/ios/foldable/Sources/foldable/FoldableSourceFactory.swift), [native source](https://github.com/berkaycatak/foldable/blob/main/ios/foldable/Sources/foldable/NativeSources.swift)
- Eight Dart test files cover channel/codec, provider subscriptions, size classes, builders and display bridging. Repository snapshot: 12 stars, one open issue, not archived, last push 2026-09-26. No GitHub workflow was present in the tree reviewed. The author reports Duo simulator verification; this review did not run those tests, compile the plugin, or verify physical hardware. [Tests](https://github.com/berkaycatak/foldable/tree/main/test)
- Version 1.0.5 repairs initial-unknown hinge subscriptions; earlier 1.0.x releases repaired stale fold geometry. Small, recent project with meaningful regressions addressed, but limited deployment evidence. [Changelog](https://pub.dev/packages/foldable/changelog)
- Keep `DisplayFeatureBridgeMode.none` initially and translate plugin geometry into our layout adapter. Global `full` bridging changes Material dialog/sheet pane behavior and needs explicit presentation anchors. [Package integration documentation](https://pub.dev/packages/foldable)

### `duo_dynamic_sizing`: broader alternative

Its manifest requires Dart ^3.11.0 / Flutter >=3.41.0. Native iOS SwiftPM targets iOS 15.0. Source includes runtime-gated UIKit hinge lookup, native Android integration, pose simulation and layout widgets. Repository has Dart tests, 14 golden images, and a workflow containing Android APK/iOS simulator build jobs. Presence of those jobs is not evidence that the latest run passed. More extensive infrastructure than `foldable`, but lower current adoption. [SwiftPM manifest](https://github.com/Abojawdat/iPhone-Duo-package-/blob/main/ios/duo_dynamic_sizing/Package.swift), [Native source](https://github.com/Abojawdat/iPhone-Duo-package-/blob/main/ios/duo_dynamic_sizing/Sources/duo_dynamic_sizing/DuoDynamicSizingPlugin.swift), [Tests](https://github.com/Abojawdat/iPhone-Duo-package-/tree/main/test), [CI definition](https://github.com/Abojawdat/iPhone-Duo-package-/blob/main/.github/workflows/ci.yml)

`iphone_duo_ui_pro` is another genuine bridge candidate, but its documented compilation flag and current legacy native integration make it a less direct fit for this SwiftPM starter. The author explicitly reports simulator-only verification. [Setup and build notes](https://pub.dev/packages/iphone_duo_ui_pro)

## Suggested next action

1. Finish extracting our reusable commerce widgets and one adaptive shell, using local constraints and injected geometry. Cover compact/expanded, vertical fold/book, horizontal fold/tabletop, keyboard, large text and retained session/scroll state.
2. Evaluate a pinned `foldable` adapter in an isolated dependency change. Build with the selected SDK and the installed Xcode 27.1 beta using per-command `DEVELOPER_DIR`; use the Duo 27.1 simulator for real channel values. Do not change the global Xcode selection. Verify the plugin's published archive, not only the repository main branch.
3. Check cover/open transitions, active/inactive folds, asymmetric camera-safe areas, state retention and dialogs. This closes the difference between injected Flutter tests and actual native Duo behavior. Physical-device verification remains separate.
4. Consider native toolbar packages only after the formal Figma components clarify the navigation design; they can change the visual system, while hinge data need not.

## Metadata sources

All table values were read from public endpoints of the form `https://pub.dev/api/packages/<name>` and `https://pub.dev/api/packages/<name>/score`. Examples: [foldable version metadata](https://pub.dev/api/packages/foldable), [foldable popularity](https://pub.dev/api/packages/foldable/score), [adaptive_platform_ui metadata](https://pub.dev/api/packages/adaptive_platform_ui), [adaptive_platform_ui popularity](https://pub.dev/api/packages/adaptive_platform_ui/score), [duo_dynamic_sizing metadata](https://pub.dev/api/packages/duo_dynamic_sizing), [duo_dynamic_sizing popularity](https://pub.dev/api/packages/duo_dynamic_sizing/score). Each package link above identifies the exact package behind its API name.

SDK layout guidance: [Flutter adaptive approach](https://docs.flutter.dev/ui/adaptive-responsive/general), [SafeArea and MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery), [Large screens and foldables](https://docs.flutter.dev/ui/adaptive-responsive/large-screens).
