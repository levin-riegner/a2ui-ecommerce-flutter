# Catalog and asset sources

The app searches `assets/data/catalog/products.csv`, containing 977 fictional
products. `StylistRuntime` validates catalog choices and returns domain results;
`StylistBloc` presents them through `CommerceA2uiRenderer`. Flutter loads photographs
from each product's `image_asset` path.

## Product facts

Names, brands, descriptions, EUR prices and IDs are demo data. Descriptions and
styling tags are best-effort interpretations of photographs, not verified material,
fit, stock or performance claims. Unsupported material values use `unspecified`.
Search uses text matching and filters; it needs no vector database or embeddings.

The `gender` field describes product styling: `male`, `female`, or `male, female`.
Explicit audience requests remain host constraints across search, selection and
budget completion. These labels do not describe the wearer's identity or fit.

[Demo commerce](product-data-and-demo-commerce.md) adds explicitly fictional size,
variant, stock and delivery data. It does not connect to a merchant or take payment.

## Assets and attribution

Project and catalog curation credit belongs to this repository's contributors.

The original product photographs `demo-0001.jpg` through `demo-0200.jpg` in
`assets/images/products/` are included with permission for public use and
redistribution in this demo under the repository's Apache-2.0 license. Authorship
remains with their respective rights holders.

Images `demo-0201.jpg` through `demo-0977.jpg` are generated fictional product
imagery from Shopify's mock.shop reference catalogs, used as demonstration content.
Their [source terms](https://demostore.hydrogen.mock.shop/policies/terms-of-service)
apply separately; the project does not assert an Apache-2.0 license for them.

Jost (Copyright 2020 The Jost Project Authors, https://github.com/indestructible-type)
and Inter (Copyright 2020 The Inter Project Authors, https://github.com/rsms/inter)
are bundled unmodified from Google Fonts under the SIL Open Font License 1.1.
Their full licenses are in `assets/fonts/jost/OFL.txt` and `assets/fonts/inter/OFL.txt`;
they are not covered by the project's Apache license.

The ten Start collage photographs and four design-context photographs come from
the supplied Figma reference. Their source identity and outstanding redistribution
reviews are recorded in [asset provenance](asset-provenance.json) and the
[Start photo ledger](assets/collage-provenance.json). The project does not assert
an Apache-2.0 license for these photographs. Historical screenshots, videos and
Git blobs require their own review.

Visible marks or reverse image search can identify photographed products. Fictional
metadata does not make the images anonymous or imply brand affiliation.

## Import and validation

See [catalog curation](catalog-import.md) for import policy, size options and colour
variant groups. The parser supports quoted commas, escaped quotes and multiline fields.
Validate changes before building:

```sh
python3 tools/catalog/validate.py assets/data/catalog/products.csv
```

Use `--source` for each private source export when checking source identifiers.
Keep raw exports, enrichment results and image URL lists outside the repository.
`CsvProductRepository`, `FixtureProductRepository` and `StubAgent` support explicit
injection in tests and galleries; they are not production fallback modes.
