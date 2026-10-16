"""Local photo restoration preserves identity and separate public-release gates."""
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_release_assets import check


class ReleaseAssetBoundaryTest(unittest.TestCase):
    def inspect(self, files, *, manifest=None, for_public_release=False):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'docs').mkdir()
            (root / 'lib').mkdir()
            (root / 'docs/asset-provenance.json').write_text(json.dumps(manifest or {
                'groups': [{'evidence': ['NOTICE']}],
                'removed_unverified_assets': ['assets/images/occasions/start-01.png'],
            }))
            for name, content in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            return check(root, for_public_release=for_public_release)

    def test_reintroduced_source_photo_is_blocked(self):
        errors = self.inspect({'NOTICE': 'Project terms', 'assets/images/occasions/start-01.png': 'old media'})
        self.assertEqual(len(errors), 1)
        self.assertIn('must not ship', errors[0])

    def test_dynamic_runtime_reference_is_blocked(self):
        errors = self.inspect({'NOTICE': 'Project terms', 'lib/widget.dart': "final path = 'assets/images/occasions/start-${number}.png';"})
        self.assertEqual(len(errors), 1)
        self.assertIn('referenced by runtime', errors[0])

    def test_historical_evidence_does_not_become_a_current_runtime_reference(self):
        self.assertEqual(self.inspect({'NOTICE': 'Project terms', 'docs/example.md': 'assets/images/occasions/start-01.png'}), [])

    def test_missing_evidence_is_reported(self):
        errors = self.inspect({})
        self.assertIn('Missing provenance evidence: NOTICE', errors)

    def restored_fixture(self):
        name = 'assets/images/occasions/start-01.png'
        files = {
            'NOTICE': 'Source terms remain pending public review',
            name: 'original photo bytes',
            'lib/widget.dart': f"final path = '{name}';",
            'docs/restored.json': json.dumps({'assets': [{
                'path': name,
                'sha256': hashlib.sha256(b'original photo bytes').hexdigest(),
            }]}),
        }
        manifest = {
            'groups': [{'paths': [name], 'evidence': ['NOTICE', 'docs/restored.json'], 'release_status': 'requires_review'}],
            'removed_unverified_assets': [],
            'restored_design_assets_ledger': 'docs/restored.json',
        }
        return files, manifest

    def test_explicit_restoration_passes_local_identity_check(self):
        files, manifest = self.restored_fixture()
        self.assertEqual(self.inspect(files, manifest=manifest), [])

    def test_restoration_does_not_clear_public_release_gate(self):
        files, manifest = self.restored_fixture()
        errors = self.inspect(files, manifest=manifest, for_public_release=True)
        self.assertEqual(len(errors), 1)
        self.assertIn('Public redistribution review required', errors[0])

    def test_replacement_bytes_fail_restoration_identity_check(self):
        files, manifest = self.restored_fixture()
        files['assets/images/occasions/start-01.png'] = 'replacement pixels'
        errors = self.inspect(files, manifest=manifest)
        self.assertEqual(len(errors), 1)
        self.assertIn('differs from source', errors[0])


if __name__ == '__main__':
    unittest.main()
