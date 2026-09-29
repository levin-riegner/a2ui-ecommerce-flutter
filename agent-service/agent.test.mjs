import test from 'node:test';
import assert from 'node:assert/strict';
import { productsFromCsv, searchProducts } from './catalog.mjs';
import { createSession, runTurn, CATALOG_ID, parseBudget } from './agent.mjs';
import { corsHeaders, createTurnHandler } from './server.mjs';

const csv = `id,name,brand,description,category,subcategory,color,material,season,occasion,price_eur,image_asset,keywords
p-001,"Blue, Evening Dress",Demo One,"Soft, flowing shape",dress,midi,blue,silk,summer,wedding,180,assets/images/products/p-001.webp,"formal, evening"
p-002,Black Leather Pump,Demo Two,Pointed shoe,shoes,pump,black,leather,summer,wedding,90,assets/images/products/p-002.webp,formal
p-003,Blue Day Dress,Demo Three,Cotton daytime piece,dress,mini,blue,cotton,spring,day,400,assets/images/products/p-003.webp,casual
p-004,Cream Shirt,Demo Four,Soft shirt,top,shirt,cream,cotton,summer,wedding,40,assets/images/products/p-004.webp,formal
p-005,Navy Trouser,Demo Five,Tailored leg,bottom,trouser,navy,cotton,summer,wedding,50,assets/images/products/p-005.webp,formal
p-006,Silver Cuff,Demo Six,Polished detail,accessory,bracelet,silver,metal,summer,wedding,20,assets/images/products/p-006.webp,formal
`;

test('budget parser handles thousands separators and EUR before or after the amount', () => {
  for (const [message, expected] of [
    ['under €1,500', 1500], ['under €1.500', 1500], ['EUR 1,500.50', 1500.5],
    ['1.500,50 EUR', 1500.5], ['500 EUR', 500], ['€500', 500],
  ]) assert.equal(parseBudget(message), expected, message);
});

test('CSV parsing preserves quoted commas and search enforces facets, budget, and limit', () => {
  const products = productsFromCsv(csv);
  assert.equal(products[0].name, 'Blue, Evening Dress');
  assert.deepEqual(searchProducts(products, { query: 'blue dress', category: 'dress', priceMax: 200, limit: 1 }).products.map((p) => p.id), ['p-001']);
  assert.equal(searchProducts(products, { query: 'blue', priceMax: 100 }).total, 0);
});

test('model requests search, host returns facts and builds A2UI; selection requires a returned ID', async () => {
  const products = productsFromCsv(csv);
  const session = createSession();
  const modelCalls = [];
  const callModel = async (request) => {
    modelCalls.push(request);
    if (modelCalls.length === 1) return { output: [{ type: 'function_call', call_id: 'call-1', name: 'search_products', arguments: JSON.stringify({ query: 'blue dress', priceMax: 400 }) }] };
    if (modelCalls.length === 2) return { output: [{ type: 'function_call', call_id: 'call-2', name: 'present_products', arguments: JSON.stringify({ productIds: ['p-001'] }) }] };
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Here is a blue dress for the wedding.' }] }] };
  };
  const first = await runTurn({ session, products, message: 'Wedding outfit under €250', callModel });
  assert.equal(first.products.length, 1);
  assert.equal(first.products[0].id, 'p-001');
  assert.equal(first.messages[3].createSurface.catalogId, CATALOG_ID);
  assert.equal(first.messages[4].updateComponents.components[3].imageAsset.path, '/recommendations/0/imageAsset');
  assert.equal(first.messages[5].updateDataModel.value.recommendations[0].imageAsset, 'assets/images/products/p-001.webp');
  assert.match(modelCalls[1].input.find((item) => item.type === 'function_call_output').output, /p-001/);
  await assert.rejects(runTurn({ session, products, action: { name: 'select_product', context: { productId: 'p-003' } }, callModel }), /not returned/);
  const second = await runTurn({ session, products, action: { name: 'select_product', context: { productId: 'p-001' } }, callModel });
  assert.deepEqual(second.outfit.items, { dress: 'p-001' });
  const dressingData = second.messages.find((m) => m.updateDataModel?.surfaceId === 'dressing-room').updateDataModel.value;
  const dressingComponents = second.messages.find((m) => m.updateComponents?.surfaceId === 'dressing-room').updateComponents.components;
  const selectedData = second.messages.find((m) => m.updateDataModel?.surfaceId === 'selected-products').updateDataModel.value;
  const selectedComponents = second.messages.find((m) => m.updateComponents?.surfaceId === 'selected-products').updateComponents.components;
  assert.match(dressingData.dressMeta, /€180/);
  assert.equal(dressingData.dressImageAsset, 'assets/images/products/p-001.webp');
  assert.equal(dressingComponents[0].dressImageAsset.path, '/dressImageAsset');
  assert.equal(first.messages.some((m) => m.createSurface?.surfaceId === 'selected-products'), true);
  assert.equal(second.messages.some((m) => m.createSurface?.surfaceId === 'selected-products'), false);
  assert.equal(second.messages.some((m) => m.createSurface?.surfaceId === 'dressing-room'), false);
  assert.equal(second.messages.filter((m) => m.createSurface?.surfaceId === 'inline-2').length, 1);
  assert.equal(selectedData.products[0].imageAsset, 'assets/images/products/p-001.webp');
  assert.equal(selectedComponents[2].action.event.name, 'remove_product');
});

test('host rejects unseen presentation IDs and keeps top, bottom, and accessory distinct', async () => {
  const products = productsFromCsv(csv);
  const session = createSession();
  let count = 0;
  const callModel = async () => {
    count++;
    if (count === 1) return { output: [{ type: 'function_call', call_id: 'c1', name: 'search_products', arguments: '{"query":"formal"}' }] };
    if (count === 2) return { output: [{ type: 'function_call', call_id: 'c2', name: 'present_products', arguments: '{"productIds":["p-999"]}' }] };
    if (count === 3) return { output: [{ type: 'function_call', call_id: 'c3', name: 'present_products', arguments: '{"productIds":["p-004","p-005","p-006"]}' }] };
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Three pieces.' }] }] };
  };
  const first = await runTurn({ session, products, message: 'Wedding outfit under €1,500', callModel });
  assert.equal(first.outfit.budget, 1500);
  assert.deepEqual(first.products.map((p) => p.id), ['p-004', 'p-005', 'p-006']);
  assert.match(session.history.find((item) => item.type === 'function_call_output' && item.call_id === 'c2').output, /error/);
  for (const id of ['p-004', 'p-005', 'p-006']) await runTurn({ session, products, action: { name: 'select_product', context: { productId: id } }, callModel });
  assert.deepEqual(Object.keys(session.outfit).sort(), ['accessory', 'bottom', 'top']);
  const last = await runTurn({ session, products, message: 'Show the outfit', callModel });
  const lastDressing = last.messages.find((m) => m.updateDataModel?.surfaceId === 'dressing-room').updateDataModel.value;
  const lastSelected = last.messages.find((m) => m.updateDataModel?.surfaceId === 'selected-products').updateDataModel.value;
  assert.match(lastDressing.brief, /top: Cream Shirt/);
  assert.match(lastDressing.brief, /bottom: Navy Trouser/);
  assert.match(lastDressing.brief, /accessory: Silver Cuff/);
  assert.deepEqual(lastSelected.products.map((p) => p.id), ['p-004', 'p-005', 'p-006']);
});

test('previously searched product cannot be presented after the budget is lowered', async () => {
  const products = productsFromCsv(csv);
  const session = createSession();
  let count = 0;
  const callModel = async () => {
    count++;
    if (count === 1) return { output: [{ type: 'function_call', call_id: 'search', name: 'search_products', arguments: '{"query":"blue dress"}' }] };
    if (count === 3) return { output: [{ type: 'function_call', call_id: 'present', name: 'present_products', arguments: '{"productIds":["p-001"]}' }] };
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'I will adjust the options.' }] }] };
  };
  await runTurn({ session, products, message: 'A dress under €500', callModel });
  const next = await runTurn({ session, products, message: 'Actually under €50', callModel });
  assert.equal(next.outfit.budget, 50);
  assert.deepEqual(next.products, []);
  assert.match(session.history.find((item) => item.type === 'function_call_output' && item.call_id === 'present').output, /remaining outfit budget/);
});

test('CORS permits only the configured browser origin', () => {
  const allowed = corsHeaders('http://localhost:5173', 'http://localhost:5173');
  assert.equal(allowed['access-control-allow-origin'], 'http://localhost:5173');
  assert.match(allowed['access-control-allow-methods'], /OPTIONS/);
  assert.deepEqual(corsHeaders('http://evil.example', 'http://localhost:5173'), {});
});

test('failed model turn rolls back budget, outfit, and surface counter', async () => {
  const products = productsFromCsv(csv);
  let calls = 0;
  let fail = false;
  const callModel = async () => {
    calls++;
    if (fail) throw new Error('model unavailable');
    if (calls === 1) return { output: [{ type: 'function_call', call_id: 'search', name: 'search_products', arguments: '{"query":"blue dress"}' }] };
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Ready.' }] }] };
  };
  const turn = createTurnHandler({ products, callModel });
  const first = await turn({ message: 'A dress under €500' });
  fail = true;
  await assert.rejects(turn({ sessionId: first.sessionId, message: 'Actually under €20', action: { name: 'select_product', context: { productId: 'p-001' } } }), /model unavailable/);
  fail = false;
  const next = await turn({ sessionId: first.sessionId, message: 'Continue' });
  assert.equal(next.outfit.budget, 500);
  assert.deepEqual(next.outfit.items, {});
  assert.equal(next.messages.find((m) => m.createSurface)?.createSurface.surfaceId, 'inline-2');
});

test('overlapping turns for one session run in order against committed state', async () => {
  const products = productsFromCsv(csv);
  let releaseFirst;
  const firstGate = new Promise((resolve) => { releaseFirst = resolve; });
  const started = [];
  const callModel = async ({ input }) => {
    const current = input.at(-1).content;
    started.push(current);
    if (current === 'First') await firstGate;
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Ready.' }] }] };
  };
  const turn = createTurnHandler({ products, callModel });
  const initial = await turn({ message: 'Start' });
  const first = turn({ sessionId: initial.sessionId, message: 'First' });
  const second = turn({ sessionId: initial.sessionId, message: 'Second' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(started, ['Start', 'First']);
  releaseFirst();
  const [a, b] = await Promise.all([first, second]);
  assert.equal(a.messages.find((m) => m.createSurface)?.createSurface.surfaceId, 'inline-2');
  assert.equal(b.messages.find((m) => m.createSurface)?.createSurface.surfaceId, 'inline-3');
  assert.deepEqual(started, ['Start', 'First', 'Second']);
});

test('existing session is rejected after one hour idle before the model runs', async () => {
  const products = productsFromCsv(csv);
  let current = Date.now();
  let calls = 0;
  const turn = createTurnHandler({ products, now: () => current, callModel: async () => {
    calls++;
    return { output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Ready.' }] }] };
  } });
  const first = await turn({ message: 'Start' });
  current += 3_600_100;
  await assert.rejects(turn({ sessionId: first.sessionId, message: 'Continue' }), (error) => error.status === 404 && /expired/.test(error.message));
  assert.equal(calls, 1);
});

test('CSV rejects duplicate identifiers and unsafe image paths', () => {
  assert.throws(() => productsFromCsv(csv + csv.split('\n')[1] + '\n'), /duplicate/);
  assert.throws(() => productsFromCsv(csv.replace('assets/images/products/p-001.webp', 'https://shop.example/p.jpg')), /image_asset/);
});
