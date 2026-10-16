# README captures

Captured on 2026-10-16 from the real Flutter application in the iOS 27.1 iPhone Duo simulator. RocketSim exported the native display with its device frame and transparent background. These are screenshots, not Figma mockups.

Build and run the explicit developer entry point:

```sh
fvm flutter run -d <duo-simulator-id> -t tool/alder_online_demo.dart \
  --dart-define=ALDER_DEMO_OFFLINE=true
```

Enter `A smart casual outfit for Berlin, budget 700 euros` and choose **Start my look**. Wait for the offline recommendations to finish. Capture the conversation/dressing room, then open **Inspect**, and switch to **Catalog** for the other views.

| File | View |
| --- | --- |
| `duo-outfit.png` | Accepted €700 budget, catalog recommendations and dressing-room plan. |
| `duo-inspector.png` | Structural exchange summaries explicitly labelled as offline fixtures. |
| `duo-catalog.png` | Actual renderer catalog and host action contracts. |

The installed build used `tool/alder_online_demo.dart` with `ALDER_DEMO_OFFLINE=true`. It makes no paid provider requests. The screenshots show project UI and catalog photographs subject to [NOTICE](../../../NOTICE); they contain neither the Start collage nor the design-context photographs. Device framing was exported by RocketSim using `screenshot --bezel device3d --background transparent`. All three PNGs were opened and visually checked.

These captures establish simulator rendering only. They do not establish live-provider behavior, physical-device behavior, or complete posture/rotation coverage. Other asset groups and historical media retain the [public-release gates](../../open-source-release.md).
