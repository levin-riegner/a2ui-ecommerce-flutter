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

The original 200 product photographs and the additional 777 mock.shop images have
separate terms in [NOTICE](../NOTICE). Keep those terms and bundled font licenses.
The Start collage and design-context photographs have their own redistribution
requirements in [asset provenance](asset-provenance.json) and [the release gates](open-source-release.md).

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
