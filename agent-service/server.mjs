import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { loadCatalog, searchProducts } from './catalog.mjs';
import { createSession, runTurn } from './agent.mjs';

const DEFAULT_CATALOG = fileURLToPath(new URL('../assets/data/catalog/products.csv', import.meta.url));
const MAX_BODY_BYTES = 16_384;

export function corsHeaders(origin, allowedOrigin) {
  if (!origin || !allowedOrigin || origin !== allowedOrigin) return {};
  return { 'access-control-allow-origin': origin, 'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type', 'vary': 'Origin' };
}

function json(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  response.end(JSON.stringify(body));
}

async function bodyOf(request) {
  let data = '';
  for await (const chunk of request) {
    data += chunk;
    if (data.length > MAX_BODY_BYTES) throw new Error('Request body is too large');
  }
  return JSON.parse(data || '{}');
}

export function openAiModel({ apiKey, model, fetchImpl = fetch }) {
  if (!apiKey || !model) throw new Error('Set OPENAI_API_KEY and OPENAI_MODEL on the server');
  return async ({ instructions, input, tools, tool_choice }) => {
    const response = await fetchImpl('https://api.openai.com/v1/responses', {
      method: 'POST', headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
      body: JSON.stringify({ model, instructions, input, tools, tool_choice, store: false }),
      signal: AbortSignal.timeout(60_000),
    });
    const body = await response.json();
    if (!response.ok) throw new Error(`Model request failed (${response.status}): ${body.error?.message ?? 'unknown error'}`);
    return body;
  };
}

/** Serialize turns for one conversation and commit state only after a full model turn succeeds. */
export function createTurnHandler({ products, callModel, now = Date.now }) {
  const sessions = new Map();
  const pending = new Map();
  const execute = async (input) => {
    const original = input.sessionId ? sessions.get(input.sessionId) : createSession();
    if (!original || (input.sessionId && now() - original.updatedAt > 3_600_000)) {
      if (input.sessionId) sessions.delete(input.sessionId);
      const error = new Error('Unknown or expired session');
      error.status = 404;
      throw error;
    }
    const draft = structuredClone(original);
    const model = callModel ?? openAiModel({ apiKey: process.env.OPENAI_API_KEY, model: process.env.OPENAI_MODEL });
    const result = await runTurn({ session: draft, products, message: input.message, action: input.action, callModel: model });
    sessions.set(draft.id, draft);
    for (const [id, value] of sessions) if (now() - value.updatedAt > 3_600_000) sessions.delete(id);
    if (sessions.size > 100) sessions.delete(sessions.keys().next().value);
    return result;
  };
  return async (input) => {
    if (!input.sessionId) return execute(input);
    const id = input.sessionId;
    const previous = pending.get(id) ?? Promise.resolve();
    let release;
    const gate = new Promise((resolve) => { release = resolve; });
    pending.set(id, gate);
    await previous;
    try { return await execute(input); }
    finally {
      release();
      if (pending.get(id) === gate) pending.delete(id);
    }
  };
}

export async function makeServer({ catalogPath = DEFAULT_CATALOG, callModel, devOrigin = process.env.DEV_ORIGIN } = {}) {
  const products = await loadCatalog(resolve(catalogPath));
  const turn = createTurnHandler({ products, callModel });
  return createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost');
      const origin = request.headers.origin;
      if (origin && devOrigin && origin !== devOrigin) return json(response, 403, { error: 'Origin not allowed' });
      for (const [name, value] of Object.entries(corsHeaders(origin, devOrigin))) response.setHeader(name, value);
      if (request.method === 'OPTIONS' && ['/v1/turn', '/v1/search'].includes(url.pathname)) {
        response.writeHead(204); response.end(); return;
      }
      if (request.method === 'GET' && url.pathname === '/health') return json(response, 200, { ok: true, products: products.length });
      if (request.method === 'GET' && url.pathname === '/v1/search') {
        return json(response, 200, searchProducts(products, Object.fromEntries(url.searchParams)));
      }
      if (request.method !== 'POST' || url.pathname !== '/v1/turn') return json(response, 404, { error: 'Not found' });
      const input = await bodyOf(request);
      const result = await turn(input);
      return json(response, 200, result);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const clientError = /required|Unsupported|exceeds|not returned|not in the outfit|too large|priceMax|Unexpected token|JSON/.test(message);
      return json(response, error?.status ?? (clientError ? 400 : 500), { error: message });
    }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await makeServer({ catalogPath: process.env.CATALOG_CSV || DEFAULT_CATALOG });
  const port = Number(process.env.PORT || 8787);
  server.listen(port, '127.0.0.1', () => console.log(`Catalog agent listening on http://127.0.0.1:${port}`));
}
