# Public-release audit — 2026-10-16

Audited the working tree based on `aad15d9` on `feat/model-catalog-inspector`, using three agents for first-run setup, code quality and documentation. Changes remain local for review. This was an existing Mac checkout with SDK/package caches, not a bootstrap on an empty machine.

## Findings and changes

| Finding | Result |
| --- | --- |
| CI was manual-only. | Added pull-request and feature-branch push triggers; retained the manual trigger and read-only permissions. |
| Startup instructions required generators despite tracked outputs. | Simplified startup; documented toolchains, LFS hydration, no-key gallery, provider configuration and browser CORS. |
| README mixed onboarding, internals and historical detail. | Added the icon and three fresh Duo captures; moved details into linked setup, experience, catalog, developer-tools and API guides. |
| API and current behavior were scattered across documents. | Documented seven model tools, 31 host commands, turn results, public imports and A2UI publication; corrected stale capability claims and workstation-only links. |
| Catalog decoder repeated an already-proven empty-record condition. | Removed the unreachable check. |
| A few comments were stale or verbose. | Shortened two domain comments and removed Flutter scaffold instructions from pubspec; retained useful concise and generated comments. |
| Bag Undo test failed under full-suite load. | Replaced 30 ms sleeps with BLoC completion waits; exercised delayed persistence. Full suite then passed. |

The runtime remains roughly 4,000 lines. A broader split is a maintainability follow-up; the audit found no demonstrated production defect justifying that refactor immediately before release.

## Verification

- Full default Flutter suite: **686 passed** after the bag-test fix.
- Python tool tests: **56 passed**. Loopback-server tests required execution outside the shell sandbox.
- Pinned dependency resolution, static analysis, Dart formatting and generated localization/state/router reproducibility passed.
- Architecture guard, catalog validation, current asset identity checks and diff whitespace passed. All 388 local documentation/image links resolved.
- Android debug APK and production web builds passed.
- Fresh iOS simulator builds of the deterministic offline developer entry points passed; [README screenshots](assets/readme/README.md) were captured from the installed offline app and visually inspected.
- Saved Duo checkpoint verification passed all 48 historical checkpoints; this does not establish a new full posture sweep.

The documented `tool/verify_ios.sh` normal-entry gate also passed with Xcode 27.1 (27A9275) and iOS Simulator SDK 27.1. The simulator build is unsigned and was not published. Installed the normal app, scrolled the landing screen and opened **Explore component catalog** without configuring a provider key. No paid provider requests were made. Provider mocks and offline screenshots do not verify current credentials, browser provider CORS, live model quality, physical dictation or physical-device behavior.

## Still blocks public distribution

`python3 tool/check_release_assets.py --for-public-release` fails for two existing unresolved groups:

- `assets/images/occasions/start-*.png`
- `assets/images/finalized_left/*.png`

Confirm redistribution rights or replace/exclude these assets before publication. Separately choose and review the public-history/export policy for historical screenshots, video and Git blobs. The current asset check cannot clear history. The [release gates](open-source-release.md), [provenance](asset-provenance.json), [NOTICE](../NOTICE) and [security policy](../SECURITY.md) remain authoritative; this audit does not certify historical secret removal or image rights.

No commit, push, publication or deployment was performed.
