"""Verify asset identity/evidence; public release additionally enforces pending gates."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT, *, for_public_release=False):
    manifest = json.loads((root / 'docs/asset-provenance.json').read_text())
    errors = []
    for group in manifest['groups']:
        for evidence in group.get('evidence', []):
            if not (root / evidence).is_file():
                errors.append('Missing provenance evidence: ' + evidence)
        if for_public_release and group.get('release_status') == 'requires_review':
            errors.append('Public redistribution review required: ' + ', '.join(group['paths']))
    restored = set()
    ledger_path = manifest.get('restored_design_assets_ledger')
    if ledger_path:
        ledger = root / ledger_path
        if not ledger.is_file():
            errors.append('Missing restoration ledger: ' + ledger_path)
        else:
            for asset in json.loads(ledger.read_text())['assets']:
                name = asset['path']
                restored.add(name)
                path = root / name
                if not path.is_file():
                    errors.append('Missing restored photograph: ' + name)
                elif hashlib.sha256(path.read_bytes()).hexdigest() != asset['sha256']:
                    errors.append('Restored photograph differs from source: ' + name)
    removed = manifest['removed_unverified_assets']
    for name in removed:
        if (root / name).exists():
            errors.append('Undocumented source photo must not ship: ' + name)
    # Only exact paths recorded in the restoration ledger may be referenced.
    # Dynamic paths cannot establish identity and remain rejected.
    for path in (root / 'lib').rglob('*.dart'):
        for line in path.read_text().splitlines():
            if 'assets/images/occasions/start-' not in line or not ('.png' in line or '${' in line):
                continue
            names = re.findall(r"['\"](assets/images/occasions/start-[^'\"]+\.png)['\"]", line)
            if not names or any(name not in restored for name in names):
                errors.append('Removed image referenced by runtime: ' + str(path.relative_to(root)))
    return sorted(set(errors))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--for-public-release', action='store_true')
    args = parser.parse_args()
    errors = check(for_public_release=args.for_public_release)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(1)
    print('Asset identity/evidence checks passed; use --for-public-release to enforce pending redistribution gates.')
