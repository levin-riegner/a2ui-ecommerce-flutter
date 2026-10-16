# Component adoption implementation

15 October 2026, local branch `feat/stylist-input-and-enriched-catalog`. The three implementation batches use the existing 977-product catalog. No push, merge, simulator installation, live-provider request or deployment is included in this work.

| Requirement | Implemented behavior | Evidence |
| --- | --- | --- |
| Exact garment requests | Retains category-specific garment requests; resolves title/subtype/description conflicts; broad requests release narrow types. Audience-qualified exclusions preserve positive garment requests. | Actual catalog jacket requests retain female audience and €500. `stylist_component_adoption_test.dart`. |
| Business/formal relevance | Shared restrictions reject explicit lounge/sleep/activewear and utility-coverall/jumpsuit descriptions. Formal requests without an eligible one-piece use separates. | Business recovery retains the selected shirt and returns non-lounge bottoms; formal male request returns compatible tops. Conservative demo labels, not measured fit/dress-code guarantees. |
| Strictly cheaper replacements | Host price ceiling applies to search, fallback, presentation and selection. Existing piece remains selected until acceptance. Negated cheaper requests release the cap. | Lower-price, equal-price, cached-ID rejection, stale adjustment, negation and rollback checks. |
| QuickAdjust / AlternativePiece / comparisons / shortlists | Filled-slot adjustment, actual supported options, one replacement, explicit two-choice comparison, and larger shortlists. Captions include names/prices. | Actual GenUI comparison selection and filled-slot → Cheaper → single Swap interaction. |
| Color and brand preferences | Draft controls use normalized color families, eligible counts and actual fictional brands. Color Love/brand Love rank softly; Skip remains a hard restriction. Update commits all drafts together. | Actual catalog tests, rendered draft/submission, Gray/Grey and Blue/Navy consistency, invalid update rollback. Swatches are UI approximations. |
| Owned pieces | Category chips release selected purchased pieces and spend; owned requirements remain visible in completed-look metadata. | Runtime and rendered preference checks retain budget and audience. |
| Accessories | Seven-category finalized visuals, actual catalog photos, and neutral accessory placeholder assets. | Component, asset, responsive and optional-accessory completed-look coverage. |
| Dynamic completed look | Look renders supplied pieces only. LookSummary shows catalog subtotal and owned labels; unsupported sharing/checkout actions are hidden. | Actual completed accessory look, restored look, responsive gallery checks. |
| Structured trip dates | Validated ISO start/end dates in retained brief and editable preference drafts. Explicit weather days override retained range; partial forecast coverage is disclosed. | Date validation/rollback, partial-range and end-only date checks; weather retains approved choices and budget recovery. |
| Local saved looks/preferences | Versioned local store retains current brief, provenance, constraints, IDs, city and up to 50 looks. Save/restore/delete/reset bypass the model. Restore revalidates current catalog facts/prices. | Second runtime/store instance, current-price and unknown-ID rejection, zero-model typed commands, rendered save/reset/restore controls. |
| Local demo bag | Persistent host quantities 1–99, count, exact money totals, removal and guarded undo; native bag icon works. Adding a look preserves existing quantities. | Integer/limit validation, idempotence, quantity/remove/undo widget checks, persistence, failed-write/cancellation rollback. No real checkout, stock reservation or delivery. |

## Verification

- Full current Flutter suite: **493 tests passed**. Includes every bundled journey, constraint/audience preservation, retained/inactive surfaces, cancellation, protocol fixtures, component galleries and new adoption/library interactions.
- Flutter analyzer: **no issues**.
- Python suite: **31 tests passed**, including local proxy checks. Catalog validator passed; all 977 catalog records and local product photos remain present.
- Real headless browser: actual app, full catalog, deterministic offline model and production browser storage plugin. Save → add to bag → quantity 2 → full reload → reset → saved-look restore retained female styling, the accepted €500 budget and `demo-0198`. No JavaScript errors. Desktop (1240×1000) and phone (360×900) screenshots inspected; controls remain accessible. [Evidence](verification/component-adoption-2026-10-15/README.md).
- Final normal web and iOS simulator builds passed. Both bundles contain the exact source CSV and all 977 product photos. iOS was built only; no simulator install or device execution was performed.
- Formatting and source diff whitespace checks passed. The web build retains an existing optional CupertinoIcons font warning; actual Material icons and bundled text fonts rendered in the browser proof.

Reproducible source checks:

```sh
flutter test --reporter expanded
flutter analyze
dart format --output=none --set-exit-if-changed lib test
python3 tools/catalog/validate.py assets/data/catalog/products.csv
python3 -m unittest discover -s tool -p 'test_*.py'
git diff --check
```

Focused source evidence: `test/stylist_component_adoption_test.dart`, `test/stylist_library_test.dart`, `test/stylist_budget_weather_recovery_test.dart`, existing constraint/gender/runtime/protocol/component suites. Analysis rationale: [inventory-component-opportunities.md](inventory-component-opportunities.md). Storage contract: `StylistStore` / `LocalStylistStore`, key `alder.stylist.v1`; no credentials or conversation/model history are persisted.

## Deliberate limits

These limits describe this dated adoption pass. [Product data and local demo commerce](product-data-and-demo-commerce.md) subsequently added fictional sizes, stock, delivery and simulated checkout. They remain separate from verified merchant data.

- No supplier API or vector database is needed for these local interactions. Raw catalog descriptions and photos are retained; derived garment/color labels are reproducible approximations.
- 592 materials are unspecified. Sizes, stock, measured fit, technical weather performance and delivery are unknown. Unknown material cannot establish compliance with a material exclusion.
- The bag and prices are fictional demo data. Local preferences storage is not a transactional order database or cross-device account service.
- Components requiring photos, map tiles, fit/variants, delivery or real checkout remain unavailable until the corresponding evidence and adapters exist. Registered gallery examples do not establish those capabilities.
