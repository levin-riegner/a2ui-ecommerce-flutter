# Figma layout comparison — 13 October 2026

Source: [Designs section 205:7995](https://www.figma.com/design/mG3g0dRExJiLZ6oWRM4CRg/Ecomm-GenUI-iPhone-Duo?node-id=205-7995&m=dev).
Before captures use main `b3263ce`; after captures use this PR's production
widgets on the iOS 27.1 iPhone Duo simulator. PNGs retain native resolution.

The comparison focuses on spacing, typography, geometry and responsive layout.
Product names, images, prices, budgets and narrative copy remain runtime data.
The repeatable journey captures use the existing offline Genkit runtime and
catalog; the original live Belfast brief is also retained as a baseline.

| View | Figma | Before | After |
| --- | --- | --- | --- |
| Start, open | [Reference](figma-start.png) | [Main](before-start-open.png) | [PR](after-start-open.png) |
| Brief, open | [Reference](figma-brief.png) | [Live Belfast brief](before-live-brief-open.png) | [Paris brief](after-brief-open.png) |
| Picks, open | [Reference](figma-picks.png) | [Main](before-picks-open.png) | [PR](after-picks-open.png) |
| Complete, open | [Reference](figma-complete.png) | [Main](before-complete-open.png) | [PR](after-complete-open.png) |
| Complete, Book | [Reference](figma-book.png) | [Main](before-complete-book.png) | [PR](after-complete-book.png) |
| Picks, portrait | [Reference](figma-portrait.png) | [Main](before-picks-portrait.png) | [PR](after-picks-portrait.png) |

Cover checks: [start](after-start-closed.png), [brief](after-brief-closed.png),
[picks](after-picks-closed.png). Original live brief:
[Book](before-live-brief-book.png), [cover](before-live-brief-closed.png).

## Measurements and behavior

- Conversation gutters increase from 8 to 32 points on the inner display;
  cover uses 16. Header heights are 80 landscape / 56 compact, with a centered
  compact logo. The landscape composer is 52 points tall with 32 bottom clearance.
- The open dressing room starts at y=12 and fills 645 points vertically.
  Its content inset is 24; selected images are 168 high, with 8 horizontal
  and 16 vertical spacing. The rail reserves the native camera/status area.
- All recommendation categories use a 104-square image and consistent card
  padding. Sections use explicit 8 / 16 / 24 point gaps; captions use the
  Designs page's uppercase Jost treatment.
- Portrait keeps the room above the independently scrolling conversation,
  with a fixed 32-point gap and horizontal recommendation cards. The native
  status area is 82 points versus 32 in the Figma mockup, so the room has less
  vertical space and scrolls internally if needed. Cover, large text and
  obstructed layouts retain their accessible single-scroll fallback.
- Chat follows renderer growth when within 48 points of the end, using a
  120 ms scroll. Scrolling up leaves the reading position unchanged. New and
  updated component definitions reveal over 160 ms with a subtle fade and
  4-point translation. Reduce Motion skips both animations.

After captures show the latest turn because following is now enabled; before
captures may show earlier history. History remains present. The brief pair has
different runtime content. Figma's sample map, checkout and saved-look controls
do not represent existing host integrations and are outside this styling change.

## Renderer evidence

[Native recording](renderer-growth-portrait.mp4) resets the picks stage, then
updates bound message data twice through A2UI without notifying the agent or
making provider requests. [The final snapshot](after-renderer-growth-portrait.json)
records the conversation at 446.5 / 446.5 points and the room at its fixed bounds.
Screenshot JSON files record native posture, occlusions, room bounds, selections
and scroll positions.

`SurfaceContext.definition` remains the public GenUI render signal; data-model
bindings update through the existing `Surface`. Layout notifications follow
geometry changes from both component definitions and bound-data updates.
Surface identity and existing action bindings are preserved. Genkit generation,
host validation, cancellation and request policy remain unchanged.

Local verification: 337 Flutter tests, clean analyzer and formatting, web and
Android debug builds, native iOS run, catalog validator, 8 Python tests and 48
saved Duo checkpoint assertions. A further 66 targeted layout/history/Duo tests
passed after the final portrait bounds guard. Provider tests use the pinned
Genkit SDK with simulated HTTP; these captures do not establish live provider
quality or physical-device behavior.

## Reproduce

```sh
fvm flutter run -d <duo-udid> -t tool/figma_layout_probe.dart
```

Use the printed Dart VM service URL with `tool.duo_simulator_rpc.call`:

```python
from tool.duo_simulator_rpc import call

base = '<local Dart VM service URL>'
isolate = next(i['id'] for i in call(base, 'getVM')['isolates'] if i['name'] == 'main')
state = call(base, 'ext.layout.stage', isolateId=isolate, stage='picks')
# Stages: start, brief, picks, complete. Renderer-only growth:
state = call(base, 'ext.layout.grow', isolateId=isolate, lines='12')
```

Capture each settled native posture with RocketSim. This diagnostic entry point
has no provider credentials and uses the production shell, catalog and surfaces.
