# Product data and local demo commerce

15 October 2026. Implements the missing-data follow-up using the explicitly approved local demo approach. No merchant connection, real inventory, payment or shipment is involved.

## Data available to the stylist

Every CSV product receives structured attributes at load time, through the same pure-Dart parser used by the app, repositories and developer tools. Search results expose these attributes to the LLM along with the original description, exact fictional EUR price and styling audience.

Each attribute contains a value, basis, confidence, evidence field and exact supporting text. `verified` is always false: confidence describes the text classification, not a supplier audit. The classifier uses the garment description before subsequent styling advice, respects negated attributes, and leaves unsupported values unknown.

| Attribute | Current coverage across 977 products |
| --- | ---: |
| Garment length | 185 text-supported labels |
| Silhouette | 362 text-supported labels |
| Sleeve | 299 text-supported labels |
| Neckline | 238 text-supported labels |
| Closure | 347 text-supported labels |
| Estimated layering weight | 407 low-confidence estimates |
| Estimated formality | 977 low-confidence estimates; occasion tags supply the fallback |
| Material | 385 retained catalog claims; 592 unknown |
| Material hints | 14 text mentions on otherwise unknown-material items |
| Verified weather performance | 0; all 977 remain unknown |

Material hints never replace the material field or establish compliance with hard fabric restrictions. Layering weight is an estimate from garment/text evidence; it does not establish waterproofing, insulation or breathability. Original CSV fields and photo bytes are preserved.

Generate the granular report with:

```sh
dart run tool/export_product_data.dart .catalog-work/product-data-20261015/enrichment.json
```

The report contains all 977 products, original context, individual evidence/confidence, unknowns, demo variants and illustrative size guides. It stays in the ignored workspace because these are reproducible derived records rather than a second source catalog.

## Demo sizes, fit and stock

`DemoCommerce` supplies 4,863 stable fictional variants: XS–XL for clothing, EU 36–46 for footwear, and one size for bags/accessories. Product photos, colors, identity and existing prices remain unchanged. Raw Mock.shop options that conflict with the curated items are not reintroduced. Fixtures are labelled `local_demo_fixture`, version `alder-demo-v1`.

The catalog now stores explicit per-product `size_options` values (pipe-separated). The assigned defaults are XS–XL for clothing, EU 36–46 for shoes and One size for bags/accessories; they can be edited independently for each item. These are app catalog assignments, not manufacturer measurements. `DemoCommerce.variants` consumes these configured values before its category fallback for older test fixtures.

Product details shows concise descriptive attributes and the existing size/fit selector. Save size & fit validates and saves the choice. Raw evidence/confidence, generated measurement tables and synthetic stock counts are absent from the customer view. The illustrative guide generator remains only in the developer export; the runtime neither creates nor renders its text. Clothing and shoe preferences are retained separately, including when a new look starts. A typed usual size is acknowledged and offered as a draft when available.

The bag permits one chosen demo size per product. Available stock is tracked per variant; choosing a size or increasing a sized quantity validates against the remaining demo stock. Unsized items may remain in the bag, but checkout requires choosing each size. No size or fit guarantee is inferred from audience labels, pictures or these fixtures.

## Delivery and checkout scenario

The local policy supplies a fictional warehouse, destination/sample destination, dispatch the next day, arrival in three to five calendar days, €3.95 demo shipping and €0 demo tax. DeliveryEstimate displays the scenario with an explicit disclaimer. It is not a carrier quote, real tax calculation or arrival promise.

Preview demo checkout shows exact item totals, size, quantity, shipping and total in integer cents. Complete demo checkout — no payment validates the current quote and stock again, records a simulated receipt, updates local demo stock and clears the bag. The current styling look, audience and item budget remain unchanged. Shipping is shown separately from outfit item spend.

A changed bag or delivery date invalidates an older quote. Duplicate confirmation cannot submit twice. Failed or cancelled persistence leaves the prior committed state intact. No customer address, payment details, real order, reservation or shipping API is used. A receipt can be reopened and survives reconnect/restart.

## Persistence and verification

The existing `alder.stylist.v1` snapshot accepts older saves. It now also retains fit preferences, selected product/bag variants, demo inventory consumption and the last simulated receipt. Product IDs and variants are validated on restore. API keys and conversation/model payloads remain outside storage.

Focused coverage: `test/product_data_demo_commerce_test.dart`, including every product's evidence and variant IDs, negation, styling-advice isolation, typed input, separate shoe/clothing sizes, rendered controls, stock limits, stale quotes, failed-write rollback and restart persistence. Before the architecture port, **501 full-suite tests and seven final focused tests passed**, analysis/formatting were clean, and web/iOS simulator builds succeeded. Those historical checks do not establish a current native build of this port. [Browser and catalog evidence](verification/product-data-2026-10-15/README.md) verifies size selection, demo checkout and receipt recovery after reload at desktop and phone widths. Nothing was installed or deployed.

To replace the demo with real commerce, a merchant must supply variant/SKU mappings, currency/price authority, inventory, measured size/composition data and checkout/delivery services. These fictional fixtures cannot be promoted to verified facts by changing their label.
