#!/usr/bin/env python3
"""Check reviewed image bytes and credits against the rights ledger, offline.

This detects stale/missing assets (including LFS pointers). It cannot prove a
license: authoritative source review is recorded in docs/asset-rights.md.
"""
import hashlib
import json
from pathlib import Path
import struct


def main():
    root = Path(__file__).resolve().parents[1]
    ledger = json.loads((root / 'docs/assets/collage-provenance.json').read_text())
    expected = {f'assets/images/occasions/start-{n:02}.png' for n in range(1, 11)}
    expected.update(f'assets/images/finalized_left/{n}.png' for n in (
        'berlin-landmark', 'creative-studio', 'paris-autumn', 'restaurant'))
    entries = ledger['assets']
    assert len(entries) == 14 and {r['path'] for r in entries} == expected, 'ledger scope'
    notice = (root / 'NOTICE').read_text()
    manifest = json.loads((root / 'docs/design/finalized-screens.json').read_text())
    assert manifest['startCollage']['allTenSourceHashesMatchExistingBundledFiles'] is False
    for row in entries:
        name = row['path']
        data = (root / name).read_bytes()
        assert data.startswith(b'\x89PNG\r\n\x1a\n'), f'{name}: PNG bytes (not LFS pointer)'
        assert data[12:16] == b'IHDR', f'{name}: PNG header'
        size = list(struct.unpack('>II', data[16:24]))
        assert size == row['outputDimensions'], f'{name}: dimensions'
        assert len(data) == row['bytes'], f'{name}: byte count'
        assert hashlib.sha256(data).hexdigest() == row['sha256'], f'{name}: SHA-256'
        assert hashlib.sha1(data).hexdigest() == row['sha1'], f'{name}: SHA-1'
        assert row['sha1'] != row['replacedOriginalSha1'], f'{name}: original not replaced'
        assert row['license'] == 'CC0-1.0', f'{name}: reviewed license'
        for field in ('creator', 'sourcePage', 'licenseEvidence'):
            assert row[field] and row[field] in notice, f'{name}: NOTICE {field}'
        if '/finalized_left/' in name:
            item = next(x for x in manifest['assets'] if x['path'] == name)
            assert item['sha1'] == row['sha1'] and item['bytes'] == row['bytes'], name
            assert item['historicalFigmaSha1'] == row['replacedOriginalSha1'], name
    print('Verified 14 reviewed PNGs, dimensions, hashes, NOTICE credits and manifest.')


if __name__ == '__main__':
    main()
