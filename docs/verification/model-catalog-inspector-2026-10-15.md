# Model catalog and inspector verification — 2026-10-15

This records the initial catalog/inspector implementation at `70d0af2`. The
subsequent [sheet refinement](inspector-sheet-2026-10-15.md) replaces its dropdown
and contains the current UI verification.

Branch: `feat/model-catalog-inspector`, based on the completed Flutter-template
migration at `4d4a43f`. The migration's
[before/after flow record](flutter-template-migration-2026-10-15.md) is the
baseline: host-authoritative outfit, sizes, basket, undo and simulated checkout.
This change keeps those contracts and adds bounded model component selection and
public inspection. The baseline had 648 passing Flutter tests; this version has
676.

## Automated checks

| Check | Result |
| --- | --- |
| Entire offline Flutter suite | 676 passed |
| Python tooling suite | 53 passed; mock localhost servers require normal host socket access |
| Flutter analysis | No issues |
| Architecture import guard | Passed |
| Diff whitespace check | Passed |

The new tests exercise real catalog export, all four model-selectable component
graphs through the actual A2UI validator, invalid-choice rollback, observer
failure isolation, cancellation, full catalog scrolling, and the actual
`ReferenceApp` inspector during blocked generation. Desktop and 390×844 with
2× text size cover direct basket-to-debug switching, retained quantities,
controller/draft identity, zero extra model calls and no layout exceptions.
Privacy canaries cover user prompts, decoded model prose and malicious
tool/component names. These tests use deterministic in-process models, with no
provider credentials or paid requests.

Raw automated/build logs are saved in [logs/](model-catalog-inspector-2026-10-15/logs/).

## Interactive observations

The desktop browser flow used the real offline development entry point with the
production runtime/catalog/presenter/GenUI path. The model fixture chose
`PicksStrip`; the inspector showed the actual decoded choice, accepted
eligibility, tool feedback and published host-bound batch. The catalog displayed
all 60 registrations and expanded the `PicksStrip` property/action schema.
Returning to Experience retained the live room. The outfit flow selected a
shirt, trousers, shoes and backpack, retained M/regular clothing and size 41
shoes, reached four pieces totalling €220 and opened the demo bag.

The final compact browser check cold-loaded at 390×844, opened Exchanges and the
60-entry Catalog, returned to Experience, and selected the shirt. A second
browser brief requested a comparison: the decoded response selected
`ThisOrThat`, and the rendered comparison showed the same two shirt IDs as the
shortlist. Basket controls opened a selected/sized shirt, changed its quantity
from one to two (€35 to €70), switched directly into basket inspection and back.
The automated desktop/large-text phone tests additionally prove basket widget,
quantity, controller and draft retention with zero extra model requests.

The final native offline build was installed and launched on the iPhone Duo
simulator. Accessibility activation started the Berlin journey, opened the
inspector, displayed the 60-entry catalog and restored the live dressing room.
Kelvin reviewed the initial toolbar and requested a compact dropdown that
preserves the original view. The full-width toolbar has been removed: a 44px
top-right menu overlays the unchanged experience. The menu consumes the existing
`DuoLayoutScope` safe-edge calculation; debug content has its own clearance.
Geometry tests compare the exact experience bounds and retained scroll position,
and the live native check verifies the restored dressing room. The production iOS entry point also compiled successfully.

Native interaction used accessibility activation. RocketSim reported a
669×951 accessibility canvas for the landscape 951×669 screen, making HID taps
unreliable; the debug snapshot exposed the expected controls and activation
worked. This record does not claim reliable native coordinate tapping or a full
Duo posture matrix for the inspector.

| Artifact | Check |
| --- | --- |
| Offline web | Debug build, `tool/alder_online_demo.dart`, `ALDER_DEMO_OFFLINE=true` |
| Production iOS | Debug simulator build, default entry point, Xcode 27.1 RC |
| Offline iOS | Debug simulator build, offline entry point; installed and exercised |

[Build fingerprints](model-catalog-inspector-2026-10-15/build-artifacts.json)
identify the final web JavaScript and the actual installed native Dart kernel.
The source digest covers sorted `lib/**/*.dart`, the offline entry point,
`pubspec.lock` and `.fvmrc`, hashing each relative name and file SHA-256.

Screenshots:

- [Restored desktop experience](model-catalog-inspector-2026-10-15/web-desktop-experience.jpg)
- [Compact view menu](model-catalog-inspector-2026-10-15/web-desktop-view-menu.jpg)
- [Desktop decoded model choice](model-catalog-inspector-2026-10-15/web-desktop-model-choice.jpg)
- [Desktop component schema](model-catalog-inspector-2026-10-15/web-desktop-catalog.jpg)
- [Compact exchanges](model-catalog-inspector-2026-10-15/web-mobile-inspector.jpg)
- [Compact catalog](model-catalog-inspector-2026-10-15/web-mobile-catalog.jpg)
- [Restored native experience](model-catalog-inspector-2026-10-15/native-open-experience.png)
- [Native inspector with reserved-edge spacing](model-catalog-inspector-2026-10-15/native-open-inspector.png)

## Scope and limits

All 60 schemas reach the model and inspector; four recommendation components are
live model choices. Other entries are honestly labelled host-controlled or
gallery references. The inspector displays structural summaries of decoded
events and validated host batches, not raw HTTP, prompts or model-authored A2UI.
Only search and presentation tools currently emit tool-result summaries; other
tools remain visible as model-requested names and through the final host result.

The pre-existing debug-web `RenderAnimatedSize was mutated in its own
performLayout` assertion was observed again during outfit selection. The visible
flow continued; this is not an error-free browser-console claim. No paid
provider, physical device, Android runtime, release deployment or public change
was exercised by this verification.
