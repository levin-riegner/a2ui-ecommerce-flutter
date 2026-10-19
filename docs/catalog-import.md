# Demo catalog curation

The [product-data layer](product-data-and-demo-commerce.md) derives evidence-bearing attributes from the retained text and supplies separately labelled local demo variants, stock, size guides and checkout scenarios. It does not overwrite these catalog facts or turn synthetic source options into purchasable SKUs.

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

The bundled CSV contains 977 products: the original 200 plus 777 mock.shop items,
`demo-0201` through `demo-0977`. Adult jumpsuits and coveralls use the one-piece
foundation category `dress`; wristwatches use `accessory`. Keep raw source data
and enrichment results outside the public fixture. Product photographs can guide
searchable descriptions and tags; they cannot establish fibre composition or
measurements. Use `unspecified` where the source does not support a material.

The conversation model receives matching items as structured JSON from
`search_products`: descriptions, categories, colors, materials, season/occasion
tags, styling keywords, prices and image paths. It reads the enriched text;
the application renders the photos. The enrichment pass performs the image
inspection ahead of time.

### Product styling audience

The CSV's `gender` field accepts `male`, `female`, or `male, female`; the combined
value is one quoted CSV field. These labels describe product cut and styling,
not the photographed person's identity or a size/fit guarantee. Validators require
a canonical value for every product.

The import pipeline can download source snapshots and prepare file-based enrichment
jobs in an ignored workspace:

```sh
python3 tools/catalog/pipeline.py --workspace .catalog-work/demo import --store apparel-large-catalog.mock.shop
python3 tools/catalog/pipeline.py --workspace .catalog-work/demo prepare --output .catalog-work/demo/batch-01 --limit 50
```

Preparation makes no model requests. Keep source data separate from the public
fixture, which uses synthetic IDs, local JPEGs and fictional EUR prices.

mock.shop content is fictional. Its [source terms](https://demostore.hydrogen.mock.shop/policies/terms-of-service)
permit development against it and prohibit presenting imagery or copy as real
merchandise. Additional images are credited separately in [catalog and asset sources](catalog-data.md).

### Assigned size options

`assets/data/catalog/products.csv` includes `size_options`, a pipe-separated
list of sizes configured for each product. The initial assignments are
`XS|S|M|L|XL`, `36|37|38|39|40|41|42|43|44|45|46`, or `One size` by category.
Edit the item row to change its offered sizes. These values are catalog choices;
they do not define garment measurements or a manufacturer size chart.

To offer colour variants, optionally append a `variant_group` column. Give only
rows for the same style the same nonempty group value. Each colour retains its
own product ID, image, price and size options; do not group similar-looking
items. Blank/missing groups offer no alternative colours. The selector also
filters the group by brand, garment category, audience, accepted restrictions,
availability and the remaining outfit budget.
