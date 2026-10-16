# Inspector sheet refinement — 2026-10-15

This supersedes the dropdown UI from `70d0af2` on `feat/model-catalog-inspector`.
The model catalog, safe diagnostics and Flutter-template boundaries are retained.

**Inspect** opens a Flutter modal sheet over the right-hand pane in split layouts
and fills the screen in compact layouts. The sheet slides up, uses the app's
existing typography and black dressing-room styling, and closes with its labelled
close button, Back or a downward drag. The experience stays mounted underneath.
There is no dropdown or permanent toolbar. The opener stays clear of the room's
brief without changing the room's bounds.

## Executed checks

- 116 inspector, basket, adaptive-layout and Duo tests passed with `--concurrency=1`.
- The final header-clearance adjustment passed all 19 inspector/widget/integration tests.
- Analysis and the architecture import guard passed.
- The final offline iOS Simulator debug build compiled, was installed and exercised.
- No paid provider calls, deployment, push or physical-device checks occurred.

The tests cover exact retained experience geometry and scroll, composer and
renderer identity during pending generation, unchanged basket quantities, zero
additional model calls, phone/large text layouts, full-screen sheet bounds, Back
and drag dismissal, privacy canaries and all 60 catalog registrations.

One pre-existing basket Undo test failed its fixed 30 ms wait during the parallel
run. All 12 basket tests passed in isolation and the complete 116-test set passed
sequentially. No unrelated commerce behavior or tests were changed.

## Native observations

The Berlin offline journey selected the €35 shirt. Inspection opened on the right
with Duo open. Closing Duo while the sheet was open resized it to full screen;
the catalog still showed 60 entries. Closing inspection and reopening Duo restored
the shirt, €35 spent, €665 left, size form and original dressing-room layout.
Native control activation used RocketSim Accessibility; this is not a physical
device or complete posture/keyboard matrix claim.

Installed build: `tool/alder_online_demo.dart`, `ALDER_DEMO_OFFLINE=true`,
Flutter 3.47.4, Xcode 27.1 RC. Final debug Dart kernel SHA-256:
`05f12c2763d6ac0a26b1adf08f1f7dba86d899b3a6d7299685b4ff44ecb66947`.

- [Right-hand sheet](model-catalog-inspector-2026-10-15/native-sheet-duo.png)
- [Full-screen compact sheet](model-catalog-inspector-2026-10-15/native-sheet-phone.png)
- [Restored dressing room](model-catalog-inspector-2026-10-15/native-sheet-room.png)
- [Layout checks](model-catalog-inspector-2026-10-15/logs/sheet-layout-tests.txt)
- [Final inspector checks](model-catalog-inspector-2026-10-15/logs/sheet-final-tests.txt)
- [Analysis](model-catalog-inspector-2026-10-15/logs/sheet-analysis.txt)
- [Offline native build](model-catalog-inspector-2026-10-15/logs/sheet-ios-build.txt)
