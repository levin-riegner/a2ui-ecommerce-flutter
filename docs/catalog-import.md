# Demo catalog curation

This is an outfit proof of concept. Make useful, conservative guesses instead
of requiring a person to approve every synthetic source inconsistency.

- The primary image decides the depicted garment and its visible colour/cut.
- Use product-level material claims when consistent; otherwise use `unspecified`.
- Infer style, seasons and occasions. Do not invent weather performance, exact
  fibre percentages, fit measurements or actual availability.
- Ignore contradictory mock variant options. Alder displays a fictional item,
  not a purchasable SKU. Skip irrelevant categories, broken images and sets that
  span unsupported purchase slots.
- Use explicitly fictional EUR prices. They are demo amounts, not FX conversions
  or offers to sell the source products.
- Preserve user constraints. An unspecified material cannot establish compliance
  with a material exclusion such as “no wool”.

Luna processed all 1,028 imported records: 998 from Everbloom
(`apparel-large-catalog.mock.shop`) and 30 from UrbanVantage
(`apparel-intl.mock.shop`). The pilot supplied 33 usable products; the remaining
978 records supplied another 744. The 251 excluded records include unrelated
goods, children's clothing, unsupported sets and four duplicate images.

The bundled CSV now contains 977 products: the original 200 plus 777 mock items,
`demo-0201` through `demo-0977`. Adult jumpsuits and coveralls use the one-piece
foundation category `dress`; wristwatches use `accessory`. Raw source data,
enrichment results and curation decisions are retained in the ignored local
workspace `.catalog-work/mockshop-20261013/`, with the full pass under `full-run/`.
This enrichment supplies searchable text and structured tags; it does not
generate embeddings or require a vector database.

The original 200 products also received a separate Luna photo-enrichment pass.
It replaced generic descriptions and tags, corrected visible colors and garment
categories, and retained the original IDs, brands, prices and image bytes. Old
fictional material labels were not evidence of fabric composition; all 200 now
use `unspecified`. Photos showing a styled outfit describe the individual item
assigned to that catalog record, without claiming the other pictured garments
are included. The source snapshot, results, image hashes and change summary
remain local under `.catalog-work/original-enrichment-20261013/`.

The conversation model receives matching items as structured JSON from
`search_products`: descriptions, categories, colors, materials, season/occasion
tags, styling keywords, prices and image paths. It reads the enriched text;
the application renders the photos. The enrichment pass performs the image
inspection ahead of time.

The import/enrichment scripts are internal helpers. Their diagnostic flags are
evidence for assistant curation, not a required manual-review workflow. Import
snapshots and prepare file-based Luna jobs with:

```sh
python3 tools/catalog/pipeline.py --workspace .catalog-work/demo import --store apparel-large-catalog.mock.shop
python3 tools/catalog/pipeline.py --workspace .catalog-work/demo prepare --output .catalog-work/demo/batch-01 --limit 50
```

Preparation makes no model requests. Keep source data separate from the public
fixture, which uses synthetic IDs, local JPEGs and fictional EUR prices.

mock.shop content is fictional. Its [source terms](https://demostore.hydrogen.mock.shop/policies/terms-of-service)
permit development against it and prohibit presenting imagery or copy as real
merchandise. Additional images are credited separately in `NOTICE`.
