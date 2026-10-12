# Provided photo provenance and restoration

Reviewed 2026-10-12 against main `b3263ce205315599523118e956839207b4a04a90`.

Kelvin requested that all fourteen provided Figma photographs be retained and
that no new assets be used. The ten Start collage photos and four screen photos
are restored byte for byte to the baseline. NOTICE and the Figma manifest are
also restored. Replacement photographs, CC0 credits, replacement screenshots
and the replacement-specific verifier have been removed from the current tree.
The earlier replacement build and its visual evidence are superseded.

Kelvin reports prior authorization for the provided photos. The repository does
not yet record the granting party, required credits or whether that permission
covers hosted display and public source redistribution, including Git/LFS
history. This is a record of the information available, not a request to change
or replace these photos. Figma image hashes verify provenance; they do not
specify a license. The existing catalog-photo permission in NOTICE applies to
`assets/images/products/` and is not broadened by this audit.

## Item-by-item ledger

All rows have the same permission status because no separate per-photo license
or creator record was located. Full SHA-256, original dimensions, byte counts
and source node IDs are in [the machine-readable ledger](assets/collage-provenance.json).
The recorded Figma SHA-1 values below match the restored PNG bytes.

| Original asset | Figma image SHA-1 | Recorded source nodes | Permission record |
| --- | --- | --- | --- |
| `assets/images/occasions/start-01.png` | `3945d1fd61750f40a135f490f90c7e5a5604ea96` | 175:3675 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-02.png` | `4fd5fede40aabe214bb882553dc9975f74c2345b` | 175:3674 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-03.png` | `32853108429201af800a679baf2a893c64658fe3` | 175:3676 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-04.png` | `538f9a28fc1178f821287e636df1fafb16ee71ee` | 175:3677 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-05.png` | `6877e62bb0b5a408997abfbff83117f0849230a8` | 175:3681 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-06.png` | `3d750ea812a2336984e5a7ed39aab050b8ee1419` | 175:3679 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-07.png` | `303b16c3ac188eaaa2dbc0c7a0fda932014542b3` | 175:3678 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-08.png` | `663f9e0912decaa8871b9ab9bbdfd3ce1d68190a` | 178:4231 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-09.png` | `b4a7298315b14c2b92c56098031033a1140613f0` | 178:4232 | Owner-reported prior authorization; scope record pending. |
| `assets/images/occasions/start-10.png` | `25437d290bbe1dab3fae2776f3f832372289e47d` | 178:4233 | Owner-reported prior authorization; scope record pending. |
| `assets/images/finalized_left/berlin-landmark.png` | `c0f941460e58112a2a51f296c2d2e50511db3305` | 203:5018, 203:5683, 203:5124, 203:5446, 203:6060, 204:6514, 204:6687, 204:7235, 204:7480 | Owner-reported prior authorization; scope record pending. |
| `assets/images/finalized_left/paris-autumn.png` | `309b2b6019a2d6035f919d51363fa794abc8d1f3` | 186:4472, 186:4531, 204:7863, 205:8068 | Owner-reported prior authorization; scope record pending. |
| `assets/images/finalized_left/creative-studio.png` | `b80fc6c65c0fd789a564035a77b184788ab34be1` | 203:5019, 203:5684, 203:5125, 203:5447, 203:6061, 204:6515, 204:6688, 204:7236, 204:7481 | Owner-reported prior authorization; scope record pending. |
| `assets/images/finalized_left/restaurant.png` | `0843e6efd9bc4690940de28ad0095b2fa77226f4` | 186:4473, 186:4532, 204:7864, 205:8069 | Owner-reported prior authorization; scope record pending. |

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
> reference at the project owner's request. The owner reports prior
> authorization. Figma hashes document provenance; the granting party, credit
> requirements and permission's hosted-display/public-source redistribution
> scope remain to be recorded. These photos are not newly described as CC0 or
> Apache-2.0 by this review.

[The weather-service review](weather-service-review.md) remains separate. No
replacement-image plan, purchase or new service has been authorized by this
restoration.
