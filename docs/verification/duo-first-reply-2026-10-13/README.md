# First reply, forecast and Duo portrait — 13 October 2026

The previous portrait layout selected the largest unobstructed region when the
hinge divided the viewport horizontally, discarding the other display. Native
captures now show imagery/dressing room above the fold and conversation below
it, with independent scrolling. Open posture divides at the physical midpoint;
Book posture uses the native hinge bounds rather than treating the viewport as
one scrolling page. Camera, keyboard and bottom insets remain respected.

- [Before portrait](before-portrait.png).
- Book portrait: [opening](portrait-book-start.png), [awaiting the model](portrait-book-waiting.png), [first reply](portrait-book-reply.png).
- Open portrait: [opening](portrait-open-start.png), [first reply](portrait-open-reply.png).
- [Final API-configured portrait deployment](portrait-final-deployment.png): adds a 16-point resting inset below the fold and sizes opening content to its own display region, avoiding the earlier full-viewport minimum height.
- Landscape: [awaiting the model](landscape-waiting.png), [first reply](landscape-reply.png), [native reveal recording](first-room-reveal.mp4).

Each screenshot has a corresponding JSON geometry record. In Book portrait,
the upper pane ends at `y=455.5`, the lower pane starts at `y=495.5`, and the
40-point hinge remains clear. The opening upper pane contains the mosaic rather
than an empty screen. Open portrait uses the physical `y=475.5` midpoint.

Starting a conversation previously replaced the opening imagery before the
`dressing-room` GenUI surface had a renderable root. The app now retains that
imagery while waiting, then reveals the populated room over it in 320 ms.
Outgoing imagery stays opaque below the incoming room, has no active controls
or semantics, and no right-side loading overlay is added. Later room updates
keep the existing piece transitions. Reduce Motion disables the reveal.
This fixes application state/layout behavior in the same supported simulator
configuration; it does not depend on a release build.

Only the first reply starts at the beginning, including subsequent bound-data
growth in that reply. Manual scrolling restores the existing follow behavior;
later replies follow the latest content when the person is keeping up. Native
first-reply captures record scroll position `0` even when content overflows.

Forecasts retain their supplied data and automatic cache handling. The redundant
refresh button is removed. Location and weather use an 8-point section gap;
the weather card uses 10-point padding and tighter internal spacing. Forecast
failure text no longer directs the person to the removed control.

These captures use production widgets, the offline model and an explicitly
labelled weather layout fixture. No paid model or live forecast request was
made for this evidence. `ext.layout.beginFirst` holds the first model response;
`ext.layout.finishFirst` releases it for repeatable transition recording.

Verification: 355 Flutter tests pass with a clean analyzer. Regressions cover
delayed and failed first responses, the room's intermediate reveal, renderer
growth with the first reply anchored at the top, later reply following, compact
forecast rendering, both portrait postures and retained session/draft state.
