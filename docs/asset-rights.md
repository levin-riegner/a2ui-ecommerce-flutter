# Image rights ledger

Reviewed 2026-10-12 against main `b3263ce`. The current ten collage files and four
finalized gallery photos are replaced with individually sourced **CC0-1.0**
photographs. No commercial licensing purchases or accounts were needed.

The baseline NOTICE expressly left the ten collage photos unlicensed. Figma
node/image hashes and embedded EXIF established no creator, license or grant
for any of the fourteen originals. A design export is not permission to
redistribute. No original was preserved as a current bundled photo because its
rights could not be substantiated. The primary checkout and its originals were
not modified. The replacements retain every filename and original pixel size.

## Fourteen individual decisions

| Bundled file | Replacement and credited creator | Authoritative source / CC0 evidence | Original decision |
| --- | --- | --- | --- |
| `occasions/start-01.png` | Wedding dress detail — Joanna Malinowska | [source](https://freestocks.org/photo/wedding-dress-detail/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-02.png` | Female wearing a coat on a sunny autumn afternoon closeup 4 — Joanna Malinowska | [source](https://freestocks.org/photo/female-wearing-a-coat-on-a-sunny-autumn-afternoon-closeup-4/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-03.png` | Tie — freestocks.org | [source](https://freestocks.org/photo/tie/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-04.png` | Scarf in female hand — Joanna Malinowska | [source](https://freestocks.org/photo/scarf-female-hand/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-05.png` | Stylish fall outfit 2 — Joanna Malinowska | [source](https://freestocks.org/photo/stylish-fall-outfit-2/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-06.png` | Backless dress in the woods — freestocks.org | [source](https://freestocks.org/photo/backless-dress-woods/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-07.png` | Fall lace up boots — Joanna Malinowska | [source](https://freestocks.org/photo/fall-lace-boots/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-08.png` | Sunglasses on a table — Joanna Malinowska | [source](https://freestocks.org/photo/sunglasses-on-a-table/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-09.png` | Espadrilles — freestocks.org | [source](https://freestocks.org/photo/espadrilles/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `occasions/start-10.png` | Wedding shoes 2 — Joanna Malinowska | [source](https://freestocks.org/photo/wedding-shoes-2/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |
| `finalized_left/berlin-landmark.png` | Brandenburger Tor Berlin, 2024 — Affe2011 | [source](https://commons.wikimedia.org/wiki/File:Brandenburger_Tor_Berlin,_2024.jpg), [license evidence](https://commons.wikimedia.org/wiki/File:Brandenburger_Tor_Berlin,_2024.jpg) | Rights unsubstantiated; replaced |
| `finalized_left/paris-autumn.png` | Tree in autumn yellow, Paris — Gerda Arendt | [source](https://commons.wikimedia.org/wiki/File:Tree_in_autumn_yellow,_Paris.jpg), [license evidence](https://commons.wikimedia.org/w/index.php?title=File:Tree_in_autumn_yellow,_Paris.jpg&oldid=1213930735) | Rights unsubstantiated; replaced |
| `finalized_left/creative-studio.png` | Blue Photo Studio, backplate DSC_0564 — Sergej Majboroda / Poly Haven | [source](https://polyhaven.com/a/blue_photo_studio), [license evidence](https://polyhaven.com/license) | Rights unsubstantiated; replaced |
| `finalized_left/restaurant.png` | Latte and a cheesecake on a café table — Joanna Malinowska | [source](https://freestocks.org/photo/latte-and-a-cheesecake-on-a-cafe-table/), [license evidence](https://freestocks.org/terms-of-use/) | Rights unsubstantiated; replaced |

Full machine-readable provenance is in [collage-provenance.json](assets/collage-provenance.json):
source download URL and SHA-256, source dimensions and crop coordinates, output
dimensions/SHA-256/SHA-1/bytes, and each replaced original’s SHA-1. This links the
license finding to the actual distributed bytes. A hash verifies identity, not
permission. Credit is recorded in [NOTICE](../NOTICE).

## License and selection basis

[freestocks.org](https://freestocks.org/terms-of-use/) publishes its own team’s
photos under CC0 and permits personal/commercial copying and modification. Its
terms prohibit selling the photos themselves or reposting them on another free
stock-photo website. Alder bundles transformed illustrations within an app;
it is neither a stock-photo service nor a sale of photo files. The selected
pages name Joanna Malinowska or freestocks.org as author.

The two Wikimedia Commons files have the photographers’ own-work CC0 grants
on their file pages. [Poly Haven](https://polyhaven.com/license) licenses its
own/donated assets for commercial redistribution under CC0; the studio image
uses an actual downloadable backplate, not a website example render.

All replacement licenses are [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Credit is retained voluntarily; no replacement is asserted to be authored by
Alder or granted under the catalog’s separate Apache permission. CC0 does not
grant trademark/publicity rights. We selected clothing/details without
identifiable faces or visible product logos, and an empty studio; we do not
invent or claim model/property releases or endorsement.

## Visual changes and regressions

The collage keeps its three columns, 4-pixel gaps, stagger, cover crop and
top-aligned sixth image. Contemporary fabric, clothing and accessories replace
the anonymous fashion portraits. Original images are not reproduced in these
review artifacts. Every filename remains usable by the live landing screen,
OccasionCollage gallery and photo-upload fixture.

Gallery subjects remain illustrative Berlin landmark, Paris autumn, studio
and dining context. The Paris photo now shows actual Jardin Villemin autumn
foliage rather than the Eiffel Tower; the dining photo shows a café tabletop
rather than a formal wine setting; the studio is empty rather than a model
shoot. These are documented content substitutions, not venue/weather evidence.

Validation results and rendered previews are recorded in
[image-rights verification](verification/image-rights-2026-10-12.md).

## Audit boundaries and remaining owner decisions

- Product JPEGs remain covered by the pre-existing demo-photo permission
  assertion in NOTICE. This task did not independently obtain or broaden that
  grant; keep the owner’s underlying permission evidence available.
- Jost and Inter retain their bundled SIL OFL 1.1 licenses. README’s old license
  paragraph named only Jost; the documentation sibling is correcting scope.
- Historical Figma manifests are origin/style evidence; current files and rights
  are in the replacement ledger. The original hashes remain explicitly historical.
- Previous image bytes still exist in Git history/LFS and in untouched user
  checkouts. Replacing current assets does not grant rights to those historical
  blobs. Before any repository visibility change or public history publication,
  the owner must decide on a clean public export/history or obtain original
  permissions. This task did not rewrite history or change visibility.
- Hosted weather is a separate unresolved choice in
  [weather-service-review.md](weather-service-review.md). CC BY weather data does
  not grant commercial access to Open-Meteo’s free hosted endpoints.
