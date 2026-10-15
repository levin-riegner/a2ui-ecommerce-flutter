"""A current-tree check must reject reintroduced unresolved images, not archives."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_release_assets import check


class ReleaseAssetBoundaryTest(unittest.TestCase):
    def inspect(self, files):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'docs').mkdir()
            (root / 'lib').mkdir()
            (root / 'docs/asset-provenance.json').write_text(json.dumps({
                'groups': [{'evidence': ['NOTICE']}],
                'removed_unverified_assets': ['assets/images/occasions/start-01.png'],
            }))
            for name, content in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            return check(root)

    def test_reintroduced_source_photo_is_blocked(self):
        errors = self.inspect({'NOTICE': 'Project terms', 'assets/images/occasions/start-01.png': 'old media'})
        self.assertEqual(len(errors), 1)
        self.assertIn('must not ship', errors[0])

    def test_dynamic_runtime_reference_is_blocked(self):
        errors = self.inspect({'NOTICE': 'Project terms', 'lib/widget.dart': "final path = 'assets/images/occasions/start-${number}.png';"})
        self.assertEqual(len(errors), 1)
        self.assertIn('referenced by runtime', errors[0])

    def test_historical_evidence_does_not_become_a_current_runtime_reference(self):
        self.assertEqual(self.inspect({'NOTICE': 'Project terms', 'docs/verification/old.md': 'assets/images/occasions/start-01.png'}), [])

    def test_missing_evidence_is_reported(self):
        errors = self.inspect({})
        self.assertIn('Missing provenance evidence: NOTICE', errors)


if __name__ == '__main__':
    unittest.main()
