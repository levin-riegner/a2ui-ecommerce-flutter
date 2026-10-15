"""Check current-tree asset evidence and removed-image references, not rights."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT):
    manifest = json.loads((root / 'docs/asset-provenance.json').read_text())
    errors = []
    for group in manifest['groups']:
        for evidence in group.get('evidence', []):
            if not (root / evidence).is_file():
                errors.append('Missing provenance evidence: ' + evidence)
    removed = manifest['removed_unverified_assets']
    for name in removed:
        if (root / name).exists():
            errors.append('Undocumented source photo must not ship: ' + name)
    # Dynamic paths and references to any other numbered Start PNG are blocked too.
    for path in (root / 'lib').rglob('*.dart'):
        for line in path.read_text().splitlines():
            if 'assets/images/occasions/start-' in line and ('.png' in line or '${' in line):
                errors.append('Removed image referenced by runtime: ' + str(path.relative_to(root)))
    return sorted(set(errors))


if __name__ == '__main__':
    errors = check()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(1)
    print('Current asset manifest passed; archives/history and recorded permission gates still require review.')
