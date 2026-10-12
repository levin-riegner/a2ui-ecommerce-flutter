# Google submission handoff — October 16, 2026

Use this checklist to assemble the requested reviewer package. Status is based on
main `b3263ce` (PR12) and the documentation verification in the
[walkthrough](alder-online-demo.md#verification-evidence). Recheck each item on the
final merged/deployed revision; pending work is not a submission-ready claim.

| Requested item | Evidence available | Remaining handoff check |
| --- | --- | --- |
| Hosted/staging demo | Local Flutter run instructions and a reviewer journey are documented. No verified hosted URL is recorded. | Supply an approved reachable URL, deployed commit/date, fresh-browser evidence and provider/model used. Verify BYOK, recommendations, selection, typed removal, next category and recovery on that exact build. If no live browser run is possible, record the CORS/access blocker and agree the reviewer path. |
| Component catalog | **Explore component catalog** opens without a key. **Finalized Figma components** and **Finalized Figma screens** expose local states/examples; [schemas and replayable A2UI examples](design/README.md) are tracked. | Verify reviewer access in the final hosted build. Label gallery fixtures and services requiring host integration. |
| Public Apache-2 repository | [Repository](https://github.com/levin-riegner/a2ui-ecommerce-flutter), [LICENSE](../LICENSE), [NOTICE](../NOTICE), pinned dependencies and verification workflow exist. GitHub currently reports **private**. | Public access requires the owner's visibility decision. Clear the final bundled-image rights, record third-party notices, fetch LFS assets and scan the final distributable for secrets before release. The code license does not establish permission for every photograph. |
| Figma catalog | The [catalog guide](design/README.md) links the existing source design and maps components, node IDs, states and exports. | Confirm Google reviewers can open the design and inspect the Components page. Repository exports and in-app fixtures do not prove Figma sharing access. |
| Logo | The app uses [alder-wordmark.svg](../assets/images/occasions/alder-wordmark.svg). | Confirm approved branding/rights and supply the file in Google's requested format; an in-app SVG does not confirm a separately delivered logo. |
| Overview | README explains the local Genkit stylist, validated A2UI surfaces, fictional catalog, BYOK and responsive layout. | Include the short overview below with the final links and explicit live-service limitations. |
| Screenshots | [Historical simulator records](verification/) describe earlier builds. | Capture the final build's landing screen, latest recommendations, selected dressing-room piece/next category, and component catalog. Include compact/wide layouts where useful, identify revision/date, and exclude credentials. Existing JSON records are not a fresh screenshot package. |
| Video (optional) | No current video is recorded in this package. | If supplied, record the same walkthrough on the final build and identify live versus fixture interactions. |

## Short overview

Alder is a Flutter personal stylist using Genkit Dart and GenUI/A2UI. A reviewer
connects a tool-capable model with their own API key, describes an occasion and
budget, and builds a look one category at a time. The host validates every product
against a bundled fictional catalog and keeps the selected outfit and totals in a
persistent dressing room. The responsive interface includes a browsable component
catalog with schema-rendered states. Live model calls depend on provider access and
browser CORS; gallery fixtures do not supply checkout, inventory or saved-look
services. Weather availability must be declared for the final build.

## Release decisions still open

- **Hosting:** choose an approved existing hosting project/route and verify the
  resulting URL. Local launch/build success does not establish public access.
- **Image rights:** baseline NOTICE leaves the ten Start collage photographs
  without recorded terms. Four `assets/images/finalized_left/` photos
  (`berlin-landmark`, `creative-studio`, `paris-autumn`, `restaurant`) have Figma
  export provenance but no recorded redistribution grant. Replacement/clearance
  evidence must cover the final bundle, including gallery-only images.
- **Weather:** decide whether the showcase disables weather or uses an approved
  service. Open-Meteo's [free-service terms](https://open-meteo.com/en/terms) exclude
  commercial/promotional use. Resolve display attribution before calling a hosted
  weather path cleared. This checklist does not authorize purchases, new service
  terms or credentials.
- **Access and handoff:** the owner must decide repository visibility and verify
  Figma sharing, logo delivery and final screenshots. No visibility change,
  reviewer invitation or submission is performed by these documentation changes.

## Final reviewer record

- [ ] Hosted/staging URL and deployed commit are recorded and reachable by Google.
- [ ] Provider/model, verification date and live/mock boundaries are recorded.
- [ ] The walkthrough passes on the final build; any failed checks include recovery
      steps and their remaining blocker.
- [ ] The catalog is accessible without BYOK; Figma access is verified separately.
- [ ] Public repository access, Apache-2 code license and final asset notices are ready.
- [ ] Logo, overview and final screenshots are assembled; optional video is identified.
- [ ] Weather/service limitations and unfinished integrations are explicit.
