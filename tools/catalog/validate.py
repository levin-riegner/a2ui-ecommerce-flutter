#!/usr/bin/env python3
"""Validate a publishable local product fixture before committing it."""

import argparse
import csv
import re
import sys
from pathlib import Path

COLUMNS = ['id', 'name', 'brand', 'description', 'category', 'subcategory', 'color', 'material', 'season', 'occasion', 'price_eur', 'image_asset', 'keywords']
CATEGORIES = {'dress', 'top', 'layer', 'bottom', 'shoes', 'bag', 'accessory'}
FORBIDDEN = re.compile(r'(?:https?://|www\.|cdn\.|gid://)', re.I)
IMAGE_PATH = re.compile(r'^assets/images/products/demo-[0-9]{4}\.jpg$')


def validate(catalog: Path, asset_root: Path, source_files: list[Path], min_products: int = 200) -> list[str]:
    errors = []
    with catalog.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != COLUMNS:
            errors.append(f'CSV schema mismatch: expected {COLUMNS}')
            return errors
        rows = list(reader)
    if len(rows) < min_products:
        errors.append(f'Expected at least {min_products} products, got {len(rows)}')
    ids = [row['id'] for row in rows]
    if len(set(ids)) != len(ids):
        errors.append('Duplicate product IDs')
    source_names = set()
    source_vendors = set()
    source_identifiers = set()
    source_handles = set()
    source_store_terms = set()
    if source_files:
        for source in source_files:
            source_store_terms.update(
                token for token in re.findall(r'[a-z]{5,}', source.stem.casefold())
                if token not in {'products', 'combined', 'export', 'source'}
            )
            with source.open(encoding='utf-8-sig', newline='') as stream:
                for row in csv.DictReader(stream):
                    source_names.add(row.get('Title', '').strip().casefold())
                    source_vendors.add(row.get('Vendor', '').strip().casefold())
                    handle = row.get('Handle', '').strip().casefold()
                    if handle:
                        source_handles.add(handle)
                    for field in ('ID', 'Variant ID', 'Variant Inventory Item ID', 'Variant SKU', 'Variant Barcode'):
                        value = row.get(field, '').strip()
                        if value:
                            source_identifiers.add(value)
    for number, row in enumerate(rows, start=2):
        for field, value in row.items():
            if not value.strip():
                errors.append(f'row {number}: empty {field}')
            if FORBIDDEN.search(value):
                errors.append(f'row {number}: source URL or store marker in {field}')
            if value.strip() in source_identifiers:
                errors.append(f'row {number}: source identifier in {field}')
            if value.strip().casefold() in source_handles:
                errors.append(f'row {number}: source handle in {field}')
            if any(re.search(rf'\b{re.escape(term)}\b', value, re.I) for term in source_store_terms):
                errors.append(f'row {number}: source store term in {field}')
        if not re.fullmatch(r'demo-[0-9]{4}', row['id']):
            errors.append(f'row {number}: invalid synthetic ID')
        if row['category'] not in CATEGORIES:
            errors.append(f'row {number}: invalid category')
        if re.search(r'\b(?:coveralls?|jumpsuits?|rompers?|boilersuits?|overalls)\b', row['subcategory'], re.I) and row['category'] != 'dress':
            errors.append(f'row {number}: one-piece garment must use the dress foundation category')
        if not IMAGE_PATH.fullmatch(row['image_asset']) or row['image_asset'] != f'assets/images/products/{row["id"]}.jpg':
            errors.append(f'row {number}: invalid image asset path')
        elif not (asset_root / row['image_asset']).is_file():
            errors.append(f'row {number}: missing image {row["image_asset"]}')
        else:
            with (asset_root / row['image_asset']).open('rb') as image_stream:
                if image_stream.read(3) != b'\xff\xd8\xff':
                    errors.append(f'row {number}: image is not a JPEG')
        try:
            if float(row['price_eur']) <= 0:
                errors.append(f'row {number}: non-positive price')
        except ValueError:
            errors.append(f'row {number}: invalid price')
        if row['name'].casefold() in source_names:
            errors.append(f'row {number}: source product name reused')
        if row['brand'].casefold() in source_vendors:
            errors.append(f'row {number}: source vendor name reused')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('--asset-root', type=Path, default=Path.cwd())
    parser.add_argument('--source', type=Path, action='append', default=[], help='Optional private source CSV; repeat per file')
    parser.add_argument('--min-products', type=int, default=200, help='Minimum catalog size (default: 200)')
    args = parser.parse_args()
    if args.min_products < 1:
        parser.error('--min-products must be positive')
    errors = validate(args.catalog, args.asset_root, args.source, args.min_products)
    if errors:
        for error in errors[:30]:
            print(error, file=sys.stderr)
        if len(errors) > 30:
            print(f'... plus {len(errors) - 30} more errors', file=sys.stderr)
        return 1
    print('Catalog valid: local images present and synthetic product checks passed')
    if not args.source:
        print('Private-source comparison skipped: pass --source for each original export')
    else:
        print('Private-source comparison found no exact source names, vendors, handles, or identifiers')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
