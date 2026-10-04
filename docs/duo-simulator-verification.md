# iPhone Duo native verification

The app pins `foldable` 1.0.5 and reads Apple's native hinge/posture and reserved-region signals through `DuoLayoutAdapter`. It treats the inner display as one continuous panel. It avoids an active division only while partially open, clears stale division geometry when flat or closed, and leaves normal Material dialogs unchanged.

## Reproduce without provider charges

Use Xcode 27.1 beta and the iOS 27.1 iPhone Duo simulator. No global `xcode-select` change is needed:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer \
  fvm flutter run -d <duo-udid> -t tool/duo_simulator_probe.dart
```

This entry point uses the real app, catalog, A2UI surfaces and deterministic stylist. It starts Berlin with one selected top. It never reads a provider key. It is separate from the production `lib/main.dart` entry point.

Copy the local Dart VM service URL printed by Flutter, then query exact native snapshots:

```sh
python3 tool/duo_simulator_rpc.py '<vm-service-url>' --focus --draft 'Keep this Duo draft'
python3 tool/duo_simulator_rpc.py '<vm-service-url>' --keyboard on
python3 tool/duo_simulator_rpc.py '<vm-service-url>' --keyboard off
python3 tool/duo_simulator_rpc.py '<vm-service-url>'
```

The focus/keyboard extensions are test-only controls in the probe. They operate on the real EditableText and iOS input channel, and never bring Device Hub forward on macOS. Explicit keyboard requests therefore verify native keyboard geometry, rather than proving that iOS preserves focus automatically while changing displays. Device Hub's hardware-keyboard simulation must be disabled for shown-software-keyboard checks; restore its original setting after testing.

Open Device Hub using `devices://device/open?id=<duo-udid>`. Its Closed, Book and Open buttons exercise genuine native postures. Rotate Right exercises all four physical orientations. Selecting a display for a screenshot does not change posture. Device Hub menu actions can require foreground focus; background AX button presses and the probe RPC controls avoid interrupting other work.

`swift tool/duo_device_hub_controls.swift <Device-Hub-pid> 'Rotate Right'` presses only the existing Duo window's button, checks the target app identity and reports foreground identity before/after. It never activates Device Hub or opens menus. The helper also accepts `Closed`, `Book`, `Open` and read-only `list`. Allow transitions to settle before capturing native state.

## Acceptance matrix

For every Closed, Book and Open preset, rotate through portrait, both landscapes and upside-down. The production iPhone orientation list excludes upside-down portrait, so that physical orientation can retain the prior supported app orientation. Test each with the software keyboard hidden and shown, at normal and maximum accessibility text sizes. This is 48 checkpoints; retain the requested physical orientation and actual viewport separately.

At each checkpoint, verify the native posture/angle, actual viewport, active/inactive division, camera geometry, text scale, keyboard inset, field bounds, draft text, EditableText identity, agent identity, selected product and spending. Fully open should not retain an obstructed split; partially open should keep controls clear of the active division. A camera below a keyboard-resized body must not reserve extra visible space.

Native readings on this simulator are cover 466×678 points, inner portrait 669×951 and inner landscape 951×669. Closed is 0°, Open is 180°, and the Book preset settles near 127.78°. Intermediate transition readings and region activity can lag each other; current posture is authoritative.

The widget regressions additionally cover genuine MethodChannel/EventChannel activation errors and resume recovery, stale snapshots, replaced platforms, malformed region geometry, camera islands on all four edges, camera/keyboard overlap, and full session/outfit/draft retention. Native screenshots and per-checkpoint snapshots are the evidence for the simulator sweep, rather than substituting injected widget geometry for hardware signals.

## Limits

This is simulator evidence, not physical-device evidence. Face Up and Face Down sensor menu actions require a foreground menu interaction and are outside the background sweep. The package currently emits Flutter's deprecated application-lifecycle-plugin warning; its eventual UIScene migration remains an upstream maintenance item. Paid-model conversation quality is tested separately from this free native layout probe.

## Recorded run: 2026-10-04

[The saved 48-checkpoint run](verification/duo-simulator-2026-10-04.json) passed native keyboard, state-retention, editable-field geometry and unchanged-foreground checks. Run `python3 tool/verify_duo_checkpoints.py docs/verification/duo-simulator-2026-10-04.json` to audit that evidence independently of the layout implementation. The sweep made 64 verified captures, including 16 repeats after correcting the diagnostic text-scale measurement; the final canonical 48 all use the effective inherited scale. Maximum scaling at 14pt was 3.117647. Earlier hardware-keyboard-suppressed attempts were excluded from the successful run.

Normal text produced four unobstructed split checkpoints when fully open and four divided split checkpoints when partially open; the other 40 checkpoints correctly used one scrollable pane. Inner display readings covered all four UI orientations. The cover retained its previous supported UI orientation for the upside-down rotation input, so it had three distinct UI orientations. Draft, EditableText identity, agent, surface, selected top and spending remained constant in the canonical run. Focus was explicitly requested for keyboard-on checks; automatic focus retention across native display switches is not asserted. The geometry audit concerns the editable text bounds; component tests and representative native screenshots supplement it.

The full suite passed 178 tests, analysis was clean, and production iOS simulator, Android debug and web builds succeeded. Final simulator state: fully open landscape, normal text, software keyboard hidden. Hardware-keyboard simulation was originally enabled and remains disabled on this dedicated simulator to avoid a foreground menu restoration while the user works.
