"""Regression checks for incomplete native simulator evidence."""
import copy
import json
from pathlib import Path
import unittest

from verify_duo_checkpoints import verify


class CheckpointVerificationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        evidence = Path(__file__).resolve().parents[1] / 'docs/verification/duo-simulator-2026-10-04.json'
        cls.recorded = json.loads(evidence.read_text())

    def test_recorded_native_evidence_passes(self):
        self.assertEqual(verify(self.recorded)['geometryVerified'], 48)

    def test_missing_composer_fails_at_any_checkpoint(self):
        for index in range(len(self.recorded)):
            with self.subTest(checkpoint=index):
                incomplete = copy.deepcopy(self.recorded)
                incomplete[index]['probe']['fields'] = []
                with self.assertRaisesRegex(AssertionError, 'expected one composer field'):
                    verify(incomplete)

    def test_duplicate_composer_fails(self):
        duplicate = copy.deepcopy(self.recorded)
        fields = duplicate[-1]['probe']['fields']
        fields.append(copy.deepcopy(fields[0]))
        with self.assertRaisesRegex(AssertionError, 'expected one composer field'):
            verify(duplicate)


if __name__ == '__main__':
    unittest.main()
