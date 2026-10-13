# Provided photo provenance and restoration

Restoration reviewed 2026-10-12; permission scope confirmed 2026-10-13.
Baseline: main `b3263ce205315599523118e956839207b4a04a90`.

Kelvin requested that all fourteen provided Figma photographs be retained and
that no new assets be used. The ten Start collage photos and four screen photos
are restored byte for byte to the baseline, together with the Figma manifest.
NOTICE records the owner's confirmed permission scope. Replacement photographs, CC0 credits, replacement screenshots
and the replacement-specific verifier have been removed from the current tree.
The earlier replacement build and its visual evidence are superseded.

On 2026-10-13 Kelvin confirmed that the existing permission for these fourteen
provided Figma photographs covers hosted demo display and public source
redistribution, including Git/LFS history. Evidence is his reply to the
permission-scope question in this task: “Hosted demo display and public source
redistribution, including Git/LFS history.” This records the project owner's
confirmation of existing permission. The granting party, photographer credits
and any named per-photo license or credit conditions have not been supplied.
Figma hashes document provenance separately. The existing catalog-photo
permission in NOTICE applies to `assets/images/products/` and is not broadened
by this audit.

## Item-by-item ledger

All fourteen rows share the owner-confirmed permission scope. Separate per-photo
creator and named-license records have not been supplied. Full SHA-256, original dimensions, byte counts
and source node IDs are in [the machine-readable ledger](assets/collage-provenance.json).
The recorded Figma SHA-1 values below match the restored PNG bytes.

| Original asset | Figma image SHA-1 | Recorded source nodes | Permission record |
| --- | --- | --- | --- |
| `assets/images/occasions/start-01.png` | `3945d1fd61750f40a135f490f90c7e5a5604ea96` | 175:3675 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-02.png` | `4fd5fede40aabe214bb882553dc9975f74c2345b` | 175:3674 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-03.png` | `32853108429201af800a679baf2a893c64658fe3` | 175:3676 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-04.png` | `538f9a28fc1178f821287e636df1fafb16ee71ee` | 175:3677 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-05.png` | `6877e62bb0b5a408997abfbff83117f0849230a8` | 175:3681 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-06.png` | `3d750ea812a2336984e5a7ed39aab050b8ee1419` | 175:3679 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-07.png` | `303b16c3ac188eaaa2dbc0c7a0fda932014542b3` | 175:3678 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-08.png` | `663f9e0912decaa8871b9ab9bbdfd3ce1d68190a` | 178:4231 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-09.png` | `b4a7298315b14c2b92c56098031033a1140613f0` | 178:4232 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/occasions/start-10.png` | `25437d290bbe1dab3fae2776f3f832372289e47d` | 178:4233 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/finalized_left/berlin-landmark.png` | `c0f941460e58112a2a51f296c2d2e50511db3305` | 203:5018, 203:5683, 203:5124, 203:5446, 203:6060, 204:6514, 204:6687, 204:7235, 204:7480 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/finalized_left/paris-autumn.png` | `309b2b6019a2d6035f919d51363fa794abc8d1f3` | 186:4472, 186:4531, 204:7863, 205:8068 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/finalized_left/creative-studio.png` | `b80fc6c65c0fd789a564035a77b184788ab34be1` | 203:5019, 203:5684, 203:5125, 203:5447, 203:6061, 204:6515, 204:6688, 204:7236, 204:7481 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |
| `assets/images/finalized_left/restaurant.png` | `0843e6efd9bc4690940de28ad0095b2fa77226f4` | 186:4473, 186:4532, 204:7864, 205:8069 | Owner-confirmed hosted demo display and public source redistribution, including Git/LFS. |

## Restoration verification

All fourteen PNGs fully decode and match the baseline commit: the ten collage
files match their Git LFS SHA-256 objects and byte counts, and the four screen
photos match ordinary Git blobs. They also match the preserved primary checkout
byte for byte. The four screen-photo hashes and ten collage hashes agree with
`docs/design/finalized-screens.json`. Embedded image metadata does not record a
photographer or a copyright/license grant.

The existing gallery, adaptive layout and widget tests pass (47 tests), including
all fourteen gallery surfaces at three viewport sizes and enlarged text. A local
`fvm flutter build web --release` succeeds, and all fourteen packaged PNGs match
the restored originals’ SHA-256 and byte counts. This local artifact uses baseline
app configuration; it is not a public release or weather-service clearance.

## Accurate documentation wording

> Alder retains the fourteen original photographs supplied in its Figma design
> reference. On 2026-10-13 the project owner confirmed that existing permission
> covers hosted demo display and public source redistribution, including Git/LFS
> history. This confirmation is recorded in the photo ledger; Figma hashes
> document provenance. Photographer credits and any named per-photo license
> conditions have not been supplied. This review does not relicense the photos
> as CC0 or Apache-2.0.

[The weather-service review](weather-service-review.md) remains separate. No
replacement-image plan, purchase or new service has been authorized by this
restoration.
