# Local catalog agent service

This service is required for the Flutter stylist journeys and supplies a model-driven loop over the same sanitized product CSV. The model requests `search_products`, then chooses 1–5 returned IDs with `present_products`. The server validates those IDs and builds A2UI v0.9 cards from catalog facts. The model never supplies product names, prices, or image paths to the UI. Freeform A2UI composition, as used in the React POC, is a later step; this service uses safe fixed components.

## Run

Requires Node 20 or later and `assets/data/catalog/products.csv` with the public catalog schema. From `agent-service/`:

```sh
npm test
OPENAI_API_KEY=... OPENAI_MODEL=... npm start
```

Set the two environment variables on the server only. `PORT` defaults to `8787`, bound to `127.0.0.1`. `CATALOG_CSV` can point to another sanitized CSV with the same columns. For a Flutter web client served from another local origin, set `DEV_ORIGIN` to that exact origin (for example `http://localhost:5173`) to enable its CORS preflight. No model request is made by `npm test`, `/health`, or `/v1/search`; `/v1/turn` calls the configured model.

## API

- `GET /health` checks that the catalog loaded and reports its product count.
- `GET /v1/search?q=blue+dress&category=dress&priceMax=250&limit=6` searches locally. Optional facets are `color`, `occasion`, and `season`. Results are capped at 12.
- `POST /v1/turn` accepts `{ "sessionId": "optional-from-prior-turn", "message": "Summer wedding under €500" }` or `{ "sessionId": "...", "action": { "name": "select_product", "context": { "productId": "demo-0001" } } }`. The example product ID must first have been returned by a search in that session. `remove_product` accepts the same action context. Responses contain `sessionId`, `reply`, `outfit`, `products`, and `messages`.

The `messages` array contains A2UI v0.9 JSON envelopes for `dressing-room`, `inline-N`, and `selected-products` surfaces using `com.example.a2ui_flutter_commerce/catalog`. Flutter parses each envelope with `A2uiMessage.fromJson`, feeds it into its transport, and displays the persistent `selected-products` surface for selected tops, bottoms, and accessories. Tapping one of those cards sends `remove_product`. Product cards bind `imageAsset` to the CSV's relative Flutter asset path. The server does not fetch or serve image bytes.

Session state is in memory for one hour, limited to 100 sessions. Turns for the same session run in order, and a failed model turn does not commit its budget, outfit, or surface changes. The server rejects a selected product ID unless search returned it earlier in that session, and rejects a previously searched presentation choice that exceeds the current remaining budget. It also rejects an outfit selection that would exceed a budget recorded from a `€` or `EUR` amount in the person's message. Top, bottom, and accessory selections have distinct outfit slots and appear as images in `selected-products`; the original dressing room widget currently has four visual slots. Restarting the process clears sessions. The server should remain local or gain authentication and persistent session storage before public deployment.

Flutter's `RemoteAgent` sends chat and card actions to `/v1/turn`, feeds `messages` into its A2UI transport, and retains `sessionId`. Set `AGENT_SERVICE_URL` with `--dart-define` for every stylist run. Without valid configuration, Flutter disables journeys and keeps only the component gallery available. Loading and failed turns have explicit progress and retry states. `StubAgent` is retained only for injected tests and component previews; it is not a runtime fallback.
