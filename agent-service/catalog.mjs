import { readFile } from 'node:fs/promises';

export const HEADERS = ['id', 'name', 'brand', 'description', 'category', 'subcategory', 'color', 'material', 'season', 'occasion', 'price_eur', 'image_asset', 'keywords'];

export function parseCsv(source) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (quoted) {
      if (char === '"' && source[i + 1] === '"') { field += '"'; i++; }
      else if (char === '"') quoted = false;
      else field += char;
    } else if (char === '"') quoted = true;
    else if (char === ',') { row.push(field); field = ''; }
    else if (char === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (char !== '\r') field += char;
  }
  if (quoted) throw new Error('Unclosed CSV quote');
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

export function productsFromCsv(source) {
  const [header, ...rows] = parseCsv(source);
  if (!header || HEADERS.some((name) => !header.includes(name))) throw new Error(`Catalog CSV requires: ${HEADERS.join(', ')}`);
  const ids = new Set();
  return rows.filter((row) => row.some(Boolean)).map((row, index) => {
    if (row.length !== header.length) throw new Error(`Catalog row ${index + 2} has ${row.length} fields, expected ${header.length}`);
    const value = Object.fromEntries(header.map((name, column) => [name, row[column].trim()]));
    const price = Number(value.price_eur);
    if (!value.id || ids.has(value.id) || !value.name || !Number.isFinite(price) || price < 0) {
      throw new Error(`Invalid or duplicate product on catalog row ${index + 2}`);
    }
    if (!/^assets\/images\/products\/[a-zA-Z0-9_-]+\.(?:webp|jpg|jpeg|png)$/.test(value.image_asset)) {
      throw new Error(`Invalid image_asset on catalog row ${index + 2}`);
    }
    ids.add(value.id);
    return { ...value, price_eur: price };
  });
}

export async function loadCatalog(path) {
  return productsFromCsv(await readFile(path, 'utf8'));
}

const words = (value) => String(value ?? '').toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, ' ').trim().split(/\s+/).filter(Boolean);

export function searchProducts(products, filters = {}) {
  const maxPrice = filters.priceMax === undefined || filters.priceMax === '' ? Infinity : Number(filters.priceMax);
  if (!Number.isFinite(maxPrice) && maxPrice !== Infinity) throw new Error('priceMax must be a number');
  const limit = Math.min(12, Math.max(1, Number(filters.limit) || 6));
  const query = words(filters.query ?? filters.q);
  const matchesFacet = (product, key) => !filters[key] || words(product[key]).some((word) => words(filters[key]).includes(word));
  const ranked = products.filter((product) =>
    product.price_eur <= maxPrice && ['category', 'color', 'occasion', 'season'].every((key) => matchesFacet(product, key))
  ).map((product) => {
    const title = words(`${product.name} ${product.category} ${product.subcategory} ${product.color}`);
    const all = words(`${product.name} ${product.brand} ${product.description} ${product.category} ${product.subcategory} ${product.color} ${product.material} ${product.season} ${product.occasion} ${product.keywords}`);
    return { product, score: query.reduce((score, word) => score + (title.includes(word) ? 3 : all.includes(word) ? 1 : 0), 0) };
  }).filter(({ score }) => !query.length || score > 0);
  ranked.sort((a, b) => b.score - a.score || a.product.price_eur - b.product.price_eur || a.product.id.localeCompare(b.product.id));
  return { products: ranked.slice(0, limit).map(({ product }) => product), total: ranked.length };
}
