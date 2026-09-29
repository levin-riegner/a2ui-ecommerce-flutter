#!/usr/bin/env python3
"""Import approved source images into the synthetic local catalog.

The URL file is private and contains one URL per CSV product, in row order.
Every run refreshes all assets so a changed row order cannot retain stale images.
No source URL, filename, or image metadata is copied into the output.
"""

import argparse
import csv
import io
import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from PIL import Image, ImageOps

MAX_DOWNLOAD_BYTES = 20_000_000
MAX_IMAGE_SIDE = 1400


def import_one(product_id: str, image_asset: str, url: str, root: Path, allowed_host: str) -> str:
    if not re.fullmatch(r'demo-[0-9]{4}', product_id) or image_asset != f'assets/images/products/{product_id}.jpg':
        raise ValueError('unexpected asset path')
    parsed = urlparse(url)
    if parsed.scheme != 'https' or parsed.netloc != allowed_host:
        raise ValueError('unexpected image host')
    destination = root / image_asset
    request = Request(url, headers={'User-Agent': 'A2UI-demo-image-import/1.0'})
    with urlopen(request, timeout=30) as response:
        if response.geturl() != url:
            raise ValueError('image URL redirected')
        data = response.read(MAX_DOWNLOAD_BYTES + 1)
    if len(data) > MAX_DOWNLOAD_BYTES:
        raise ValueError('image too large')

    with Image.open(io.BytesIO(data)) as image:
        image.load()
        image = ImageOps.exif_transpose(image)
        image.thumbnail((MAX_IMAGE_SIDE, MAX_IMAGE_SIDE), Image.Resampling.LANCZOS)
        if 'A' in image.getbands():
            canvas = Image.new('RGB', image.size, 'white')
            canvas.paste(image, mask=image.getchannel('A'))
            image = canvas
        else:
            image = image.convert('RGB')
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix('.tmp')
        try:
            image.save(temporary, format='JPEG', quality=85, optimize=True)
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    return 'imported'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('private_url_file', type=Path)
    parser.add_argument('--allowed-host', required=True, help='Approved HTTPS host for the private image URLs')
    parser.add_argument('--asset-root', type=Path, default=Path.cwd())
    args = parser.parse_args()

    with args.catalog.open(encoding='utf-8-sig', newline='') as stream:
        products = list(csv.DictReader(stream))
    urls = args.private_url_file.read_text(encoding='utf-8').splitlines()
    if len(products) != len(urls):
        parser.error('URL count does not match catalog product count')

    imported = 0
    errors = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {
            pool.submit(import_one, row['id'], row['image_asset'], url, args.asset_root, args.allowed_host): row['id']
            for row, url in zip(products, urls, strict=True)
        }
        for future in as_completed(futures):
            try:
                future.result()
                imported += 1
            except Exception as error:
                errors.append(f'{futures[future]}: {type(error).__name__}')
    print(f'Images imported: {imported}; failed: {len(errors)}')
    for error in sorted(errors):
        print(error)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
