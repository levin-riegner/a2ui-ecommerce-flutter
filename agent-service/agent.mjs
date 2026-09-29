import { randomUUID } from 'node:crypto';
import { searchProducts } from './catalog.mjs';

export const CATALOG_ID = 'com.example.a2ui_flutter_commerce/catalog';
const VERSION = 'v0.9';
const MAX_ROUNDS = 4;

export const TOOLS = [{
  type: 'function', name: 'search_products', description: 'Search the local fictional fashion catalog. Call before offering products. Returns authoritative names, prices, image asset paths and IDs. Use priceMax for the remaining outfit budget.',
  parameters: { type: 'object', properties: {
    query: { type: 'string' }, category: { type: 'string' }, color: { type: 'string' },
    occasion: { type: 'string' }, season: { type: 'string' }, priceMax: { type: 'number' },
    limit: { type: 'integer' },
  }, required: ['query'], additionalProperties: false },
}, {
  type: 'function', name: 'present_products', description: 'Choose 1 to 5 product IDs already returned by search_products for the next A2UI recommendation cards. The host validates every ID and fills card facts from the catalog.',
  parameters: { type: 'object', properties: { productIds: { type: 'array', items: { type: 'string' } } }, required: ['productIds'], additionalProperties: false },
}];

const instructions = `You are a personal stylist in a fictional demo catalog. Ask for the occasion and budget if missing. Search products before recommending them, then call present_products with 1 to 5 IDs from the search results you want to show. Product facts come only from search_products. Never invent names, brands, prices, IDs or images. Consider the remaining budget and suggest a small coherent set. Your final response should be concise natural language. The host constructs the A2UI cards from your validated choices and records outfit selections; do not output UI markup or claim a selection happened unless the host says so.`;

function money(value) { return new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 }).format(value); }
function slotFor(product) {
  const category = product.category.toLowerCase();
  if (category.includes('shoe')) return 'shoes';
  if (category.includes('bag')) return 'bag';
  if (category.includes('dress')) return 'dress';
  if (category.includes('layer') || category.includes('coat') || category.includes('jacket')) return 'layer';
  if (category.includes('top') || category.includes('shirt') || category.includes('blouse')) return 'top';
  if (category.includes('bottom') || category.includes('trouser') || category.includes('skirt')) return 'bottom';
  if (category.includes('accessor')) return 'accessory';
  return category;
}
export function parseBudget(message) {
  const match = message.match(/(?:€|EUR)\s*([0-9][0-9.,\s]*[0-9]|[0-9])|([0-9][0-9.,\s]*[0-9]|[0-9])\s*(?:€|EUR)\b/i);
  if (!match) return null;
  const raw = (match[1] ?? match[2]).replace(/\s/g, '');
  const decimal = raw.match(/[.,](\d{1,2})$/);
  const digits = decimal ? raw.slice(0, -decimal[0].length).replace(/[.,]/g, '') + '.' + decimal[1] : raw.replace(/[.,]/g, '');
  const value = Number(digits);
  return Number.isFinite(value) && value >= 0 ? value : null;
}
function spent(session) { return Object.values(session.outfit).reduce((sum, product) => sum + product.price_eur, 0); }
function safeOutput(response) {
  return (response.output ?? []).flatMap((item) => item.type === 'message' && item.role === 'assistant'
    ? item.content.filter((part) => part.type === 'output_text').map((part) => part.text)
    : []).join('\n').trim();
}

function render(session, reply, picks) {
  const surfaceId = `inline-${session.turn}`;
  const data = { message: reply, eyebrow: picks.length ? 'Catalog options' : 'Your stylist', recommendations: picks.map((product) => ({
    id: product.id, name: product.name, price: money(product.price_eur),
    brandLine: `${product.brand} · ${product.color} · ${product.material}`,
    tag: product.occasion || product.category, swatch: '#e4e4e7', imageAsset: product.image_asset,
  })) };
  const components = [
    { id: 'root', component: 'Column', align: 'stretch', children: ['message', ...(picks.length ? ['eyebrow'] : []), ...picks.map((_, index) => `product-${index}`)] },
    { id: 'message', component: 'StylistMessage', text: { path: '/message' } },
    ...(picks.length ? [{ id: 'eyebrow', component: 'Eyebrow', text: { path: '/eyebrow' } }] : []),
    ...picks.map((product, index) => ({
      id: `product-${index}`, component: 'ProductCard',
      name: { path: `/recommendations/${index}/name` }, price: { path: `/recommendations/${index}/price` },
      brandLine: { path: `/recommendations/${index}/brandLine` }, tag: { path: `/recommendations/${index}/tag` },
      swatch: { path: `/recommendations/${index}/swatch` }, imageAsset: { path: `/recommendations/${index}/imageAsset` },
      action: { event: { name: 'select_product', context: { productId: product.id } } },
    })),
  ];
  const extras = ['top', 'bottom', 'accessory'].filter((slot) => session.outfit[slot]).map((slot) => `${slot}: ${session.outfit[slot].name}`);
  const dressingData = { title: 'Your dressing room', brief: [session.occasion || 'Build a look together', ...extras].join(' · '),
    spent: `${money(spent(session))} spent · ${Object.keys(session.outfit).length} pieces`,
    left: session.budget === null ? 'Set a budget' : `${money(Math.max(0, session.budget - spent(session)))} left`,
    progress: session.budget ? Math.min(1, spent(session) / session.budget) : 0,
  };
  for (const slot of ['dress', 'layer', 'shoes', 'bag']) {
    const product = session.outfit[slot];
    dressingData[`${slot}Name`] = product?.name ?? '';
    dressingData[`${slot}Meta`] = product ? `${product.brand} · ${money(product.price_eur)}` : 'Not yet';
    dressingData[`${slot}Swatch`] = '#e4e4e7';
    dressingData[`${slot}ImageAsset`] = product?.image_asset ?? '';
  }
  const dressingComponents = [{ id: 'root', component: 'DressingRoom',
    title: { path: '/title' }, brief: { path: '/brief' }, spent: { path: '/spent' },
    left: { path: '/left' }, progress: { path: '/progress' },
    ...Object.fromEntries(['dress', 'layer', 'shoes', 'bag'].flatMap((slot) => ['Name', 'Meta', 'Swatch', 'ImageAsset'].map((suffix) => [`${slot}${suffix}`, { path: `/${slot}${suffix}` }]))),
  }];
  const create = (id) => ({ version: VERSION, createSurface: { surfaceId: id, catalogId: CATALOG_ID, sendDataModel: true } });
  const componentsMessage = (id, value) => ({ version: VERSION, updateComponents: { surfaceId: id, components: value } });
  const dataMessage = (id, value) => ({ version: VERSION, updateDataModel: { surfaceId: id, value } });
  const selected = Object.entries(session.outfit).map(([slot, product]) => ({ slot, product }));
  const selectedData = {
    message: selected.length ? 'Selected pieces · tap a card to remove it' : 'No pieces selected yet.',
    products: selected.map(({ slot, product }) => ({
      id: product.id, name: product.name, price: money(product.price_eur),
      brandLine: `${product.brand} · ${product.color} · ${product.material}`,
      tag: slot, swatch: '#e4e4e7', imageAsset: product.image_asset,
    })),
  };
  const selectedComponents = [
    { id: 'root', component: 'Column', align: 'stretch', children: ['message', ...selected.map((_, index) => `selected-${index}`)] },
    { id: 'message', component: 'StylistMessage', text: { path: '/message' } },
    ...selected.map(({ product }, index) => ({
      id: `selected-${index}`, component: 'ProductCard',
      name: { path: `/products/${index}/name` }, price: { path: `/products/${index}/price` },
      brandLine: { path: `/products/${index}/brandLine` }, tag: { path: `/products/${index}/tag` },
      swatch: { path: `/products/${index}/swatch` }, imageAsset: { path: `/products/${index}/imageAsset` },
      action: { event: { name: 'remove_product', context: { productId: product.id } } },
    })),
  ];
  return [...(session.turn === 1 ? [create('dressing-room')] : []), componentsMessage('dressing-room', dressingComponents), dataMessage('dressing-room', dressingData),
    create(surfaceId), componentsMessage(surfaceId, components), dataMessage(surfaceId, data),
    ...(session.turn === 1 ? [create('selected-products')] : []), componentsMessage('selected-products', selectedComponents), dataMessage('selected-products', selectedData)];
}

export function createSession() {
  return { id: randomUUID(), turn: 0, history: [], seen: new Map(), outfit: {}, budget: null, occasion: '', updatedAt: Date.now() };
}

export async function runTurn({ session, products, message = '', action, callModel }) {
  if (!message && !action) throw new Error('message or action is required');
  let actionNote = '';
  if (action) {
    const productId = String(action.context?.productId ?? '');
    if (action.name === 'select_product') {
      const product = session.seen.get(productId);
      if (!product) throw new Error('Product was not returned by a search in this session');
      const slot = slotFor(product);
      if (session.budget !== null && spent(session) - (session.outfit[slot]?.price_eur ?? 0) + product.price_eur > session.budget) {
        throw new Error('Selection exceeds the outfit budget');
      }
      session.outfit[slot] = product;
      actionNote = `The person selected ${product.name} (${money(product.price_eur)}) for ${slot}. The host recorded it.`;
    } else if (action.name === 'remove_product') {
      const slot = Object.keys(session.outfit).find((key) => session.outfit[key].id === productId);
      if (!slot) throw new Error('Product is not in the outfit');
      delete session.outfit[slot];
      actionNote = `The person removed product ${productId} from the outfit.`;
    } else throw new Error('Unsupported action');
  }
  const budget = parseBudget(message);
  if (budget !== null) session.budget = budget;
  if (message) session.occasion = message.slice(0, 120);
  session.turn++;
  const input = [...session.history, { role: 'user', content: [message, actionNote].filter(Boolean).join('\n') }];
  let picks = [], reply = '';
  for (let round = 0; round < MAX_ROUNDS; round++) {
    const response = await callModel({ instructions: `${instructions}\nBudget: ${session.budget === null ? 'unknown' : money(session.budget)}. Already spent: ${money(spent(session))}.`, input,
      tools: TOOLS, tool_choice: round === MAX_ROUNDS - 1 ? 'none' : 'auto' });
    const output = response.output ?? [];
    input.push(...output);
    reply = safeOutput(response) || reply;
    const calls = output.filter((item) => item.type === 'function_call');
    if (!calls.length) break;
    for (const call of calls) {
      let args;
      try { args = JSON.parse(call.arguments || '{}'); } catch { args = {}; }
      let result;
      if (call.name === 'present_products') {
        const ids = args.productIds;
        const remaining = session.budget === null ? Infinity : Math.max(0, session.budget - spent(session));
        if (!Array.isArray(ids) || ids.length < 1 || ids.length > 5 || new Set(ids).size !== ids.length || ids.some((id) => typeof id !== 'string' || !session.seen.has(id))) {
          result = { error: 'Choose 1 to 5 unique IDs from this session search results' };
        } else if (ids.some((id) => session.seen.get(id).price_eur > remaining)) {
          result = { error: 'Selected presentation exceeds the remaining outfit budget; search for cheaper options' };
        } else {
          picks = ids.map((id) => session.seen.get(id));
          result = { presentedIds: ids };
        }
      } else if (call.name === 'search_products') {
        const remaining = session.budget === null ? Infinity : Math.max(0, session.budget - spent(session));
        const cap = args.priceMax === undefined ? remaining : Math.min(remaining, Number(args.priceMax));
        result = searchProducts(products, { ...args, priceMax: cap, limit: args.limit });
        for (const product of result.products) session.seen.set(product.id, product);
      } else result = { error: 'Unknown tool' };
      input.push({ type: 'function_call_output', call_id: call.call_id, output: JSON.stringify(result) });
    }
  }
  session.history = input;
  session.updatedAt = Date.now();
  if (!reply) reply = picks.length ? 'Here are a few options from the catalog.' : 'Tell me the occasion and budget, and I can find some options.';
  return { sessionId: session.id, reply, outfit: { budget: session.budget, items: Object.fromEntries(Object.entries(session.outfit).map(([slot, product]) => [slot, product.id])) },
    products: picks, messages: render(session, reply, picks) };
}
