# Finalized Figma quality pass — 2026-10-05

Branch: `feat/finalized-figma-catalog`, based on main `5586800`.

- All 39 Figma component families are registered, alongside compatible journey compositions and the decorative screen collage.
- Runtime-derived export: 57 schemas, 124 component examples and 14 screen examples.
- 247 Flutter tests pass; analyzer and repository formatting checks are clean. Catalog asset checks and three Python checkpoint tests pass. Native Duo debug build and web build pass.
- Native component sweep: 100 states in Closed, Book and Open at actual text scale 3.117647, 300 captures, zero render errors. Evidence: `finalized-catalog-duo-2026-10-05.json`.
- Native screen sweep: all 14 screens in each of Closed, Book and Open at normal and maximum native text sizes, 84 captures, zero render errors. Evidence: `finalized-screens-duo-2026-10-05.json`.
- Independent gallery tests also exercise the cover 466×678, inner portrait 669×951 and inner landscape 951×669 constraints, including maximum text. Native screen records distinguish actual viewport and posture.
- Actual native Change interaction advanced the inline surface while retaining Morrow Draped Top and €35 spending. The composer retained its EditableText identity, focused draft and a real 289-point software keyboard inset. Evidence: `finalized-production-duo-2026-10-05.json`.

## Issues resolved during review

- Enlarged slider targets, preserved external composer controller ownership and draft selection, and removed mock status time from the native production rail.
- Fixed quantity-one removal and Undo, reserved component-ID collision, and actual QuickAdjust category/adjustment payloads.
- Fixed tags/badges that could clip silently at maximum text size; corrected gallery selectors, header/footer scrolling, bounded Start collage rendering and the native send-arrow contrast.
- Brief preview choices update the resolved submission values without resetting its budget or draft.
- Replacement browsing cannot mutate the selected outfit; replacement affordability includes the released piece cost, and current items are excluded from alternatives.

## Right pane background

Corrected on 2026-10-06 after the user clarified the intended Open state: the outer right background is black only in Book mode. Fully open keeps white margins and a white iOS-controls area around the black dressing-room card; Closed/cover remains white. A 320 ms fade follows actual Duo posture, supports mid-transition reversal, and honours Reduce Motion. System indicators, the optional rail and selected-piece headings follow the animated background's contrast.

Native Open and Book screenshots confirmed the two endpoint appearances. The native probe observed three intermediate grey colours in each direction, with the selected top, €35 spend, inline surface and composer identity retained, and no render errors. Evidence: `duo-book-background-2026-10-06.json`. All 57 affected layout/screen tests and analysis pass, including interrupted fades and Reduce Motion.

## Selected-section stability

Corrected on 2026-10-06 after native screenshots showed the selected-piece heading jumping vertically during Open/Book changes. The dark grid now uses 144-point thumbnail heights rather than width-dependent squares. The dressing-room surface animates genuine content-height changes over the same 320 ms as the background, with Reduce Motion disabling the resize animation.

Three native transitions (Open → Book → Open → Book) kept the selected section at y=593 and the dressing-room height at 565 points throughout the sampled frames. Background fades, selected top, €35 spending, inline surface and composer identity were preserved, with zero render errors and no change to foreground application focus. Evidence: `duo-selected-section-2026-10-06.json`. All 75 affected layout/component/screen tests pass, including a bundled-font regression for the vertical anchor and intermediate resize positions after a longer brief. Analysis and changed-file formatting checks pass. These checks used the deterministic native fixture with zero provider requests.

## Source and integration scope

Exact read-only Figma properties/assets were authorized after design-context extraction reached its connector limit. Original screen image bytes were checked against Figma image hashes; source copy and budget inconsistencies are documented in the screen manifest. No Figma nodes were changed.

This run used deterministic local fixtures, with zero provider requests and no iPhone 18 simulator launch. Camera, voice, cart/checkout, saved-look persistence, weather, maps and delivery remain explicit host integrations. Fixture actions and visual examples do not establish live service or physical-device behavior. Device Hub recovery, when needed, briefly restored the Duo window and returned application focus.
