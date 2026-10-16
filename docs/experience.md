# Using Alder

## Connection and local state

Connecting loads the bundled catalog and configures Genkit without calling a model or checking the key. Starting a journey, chatting, selecting/removing pieces, and Retry can make paid requests, with at most four model requests per interaction. The app sends requests directly to the chosen provider. Browser use additionally requires that provider to support browser requests (CORS); a native build does not have this browser restriction.

The key stays in memory on the device and is added only to the provider's outgoing HTTP headers. It is not saved to files or browser storage and is never a Genkit flow input or generation option. **New journey → Disconnect model** clears the key and session. Reloading or closing the app requires configuring it again. Never embed keys in source, assets, or `--dart-define` values.

Accepted styling preferences, the current look, saved looks and demo bag quantities are stored locally under `alder.stylist.v1`, separately from the model connection. Reconnecting restores catalog IDs and accepted facts against current prices and restrictions. Start over clears the working look while retaining saved looks and the demo bag. The bag supports quantities, removal, undo and an explicitly simulated checkout. Local demo variants, stock, size guides and delivery scenarios are fictional; no payment, real order or shipment is created. See [product-data-and-demo-commerce.md](product-data-and-demo-commerce.md).

## Styling and recovery

Without a model connection, journeys are disabled and the component gallery remains available. The conversation keeps submitted messages and previous recommendations in order; only the latest completed recommendation accepts input. During a turn, the app displays a loading surface, then streams the final stylist explanation in complete sentences, with chat/product actions disabled until the full turn succeeds. Product cards appear below the explanation after validation, so later prose cannot push an earlier product preview down. Failed turns remove provisional text, show Retry, and retain the previous outfit and completed surfaces. Retrying keeps the original user message without adding a duplicate. No scripted fallback runs in the app.

Once connected, choose a preset journey or enter your own occasion with **Start my look**. Missing style and budget are gathered together; editing those controls makes no model request until **Find options**. Choosing a piece immediately offers the next part of the look. You can also choose or remove pieces in words, refine the brief, and revisit a completed outfit. The dressing room follows the current outfit plan, including tops and bottoms.

Explicit input such as “I have 500 to spend on a casual outfit” is acknowledged and retained as the whole-outfit EUR budget. Item prices do not replace an explicit outfit total, and a model suggestion cannot overwrite an accepted user amount. Foreign-currency budgets receive a correction prompt rather than an implicit conversion. Unknown slider amounts are labeled suggestions. Hard color, material, brand and category restrictions remain enforced through search fallback; already-owned pieces and excluded categories affect the purchase plan. Recommendations favor choices that leave enough budget to finish the required look, and explain the tradeoff when no complete look fits. Correctable input errors preserve the conversation and leave editing enabled.

## Inspecting the experience

Choose **Inspect** at the top right of the dressing-room pane to open a sheet on the right in split layouts, or full screen in compact layouts to follow safe summaries of model exchanges, host tool feedback, validation and published surfaces. **Catalog** shows all 60 registered component schemas and their current availability; four recommendation components can be chosen by the model. Close the sheet to return to the same live dressing room, with its original layout preserved. See [the model catalog and inspector guide](model-ui-inspector.md) for provenance, privacy and the offline demonstration.

## Destination weather

Destination forecasts use Open-Meteo geocoding and weather endpoints. Only the named destination is looked up; the app does not request GPS. Verified dates, temperature, and rain probability reach both the weather card and stylist. Unavailable forecasts show a notice; changing the destination clears the previous city's weather. **Refresh forecast** updates only the current response, makes no model request, and preserves the outfit, choices, and history. Forecasts are cached for 15 minutes; previous responses remain read-only. See [the online demo guide](alder-online-demo.md) for the bounded local bridge and offline simulator mode.

## Dictation

Tap the microphone in the occasion or chat composer to dictate, and tap it again to stop. Speech recognition fills the editable draft; sending uses the same GenUI/Genkit text path as typing. Microphone and speech permissions are requested on the first tap. Recognition availability and any remote speech processing depend on the device or browser. Rebuild the native app after installing the speech plugin; hot reload cannot register a new native plugin.

Dictation uses the community-maintained [`speech_to_text`](https://pub.dev/packages/speech_to_text) package, pinned to 7.5.0. Android uses the device’s configured speech recognition service, which can be Google; iOS uses Apple Speech and web uses the browser’s recognition support. This keeps dictation independent of the chosen Genkit model and requires no additional Google Cloud credentials. It does not guarantee offline recognition or a Google recognizer on every platform.
