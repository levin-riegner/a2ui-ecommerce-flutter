import csv
import tempfile
import unittest
from pathlib import Path

from tools.catalog.validate import COLUMNS, validate


class CatalogValidatorTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        image = self.root / 'assets/images/products/demo-0001.jpg'
        image.parent.mkdir(parents=True)
        image.write_bytes(b'\xff\xd8\xff')
        self.catalog = self.root / 'products.csv'

    def check(self, category, subcategory, name='Fictional Workwear Item'):
        row = dict.fromkeys(COLUMNS, 'demo')
        row.update(id='demo-0001', name=name, category=category,
                   subcategory=subcategory, price_eur='75',
                   image_asset='assets/images/products/demo-0001.jpg')
        with self.catalog.open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=COLUMNS)
            writer.writeheader()
            writer.writerow(row)
        return validate(self.catalog, self.root, [], min_products=1)

    def test_one_piece_garments_cannot_fill_separate_piece_slots(self):
        for subtype in ['coverall', 'coveralls', 'jumpsuit', 'romper',
                        'boilersuit', 'overalls']:
            with self.subTest(subtype=subtype):
                self.assertEqual(self.check('dress', subtype), [])
                for category in ['layer', 'top', 'bottom']:
                    errors = self.check(category, subtype)
                    self.assertTrue(any('dress foundation' in e for e in errors))

    def test_accessory_names_can_reference_a_one_piece_garment(self):
        self.assertEqual(self.check('accessory', 'belt', 'Jumpsuit Belt'), [])


if __name__ == '__main__':
    unittest.main()
