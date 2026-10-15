import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.catalog import pipeline as catalog


def product(product_id='1'):
    return {'id': 'gid://shopify/Product/' + product_id, 'title': 'Graphite grey linen trousers',
            'description': 'Relaxed linen trousers.', 'category': {'name': 'Pants'},
            'featuredImage': {'url': 'https://cdn.shopify.com/sample.png'},
            'options': [{'name': 'Color', 'values': ['Grey', 'Black']}],
            'variants': {'nodes': [{'availableForSale': True, 'price': {'amount': '78', 'currencyCode': 'USD'}}],
                         'pageInfo': {'hasNextPage': False}}}


def result(record):
    attrs = {name: {'value': [] if name in catalog.LIST_FIELDS else '',
                    'evidence': ['product_description'], 'confidence': 'medium'} for name in catalog.FIELDS}
    attrs['category']['value'] = 'bottom'
    attrs['keywords']['value'] = ['pleated']
    return {'key': record['key'], 'source_fingerprint': record['source_fingerprint'],
            'review_fingerprint': catalog.review_fingerprint(record), 'attributes': attrs,
            'search_document': 'Relaxed pleated trousers.', 'quality_flags': [], 'unknowns': ['Fiber percentages']}


class CatalogPipelineTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        catalog.import_products(self.root, 'apparel.mock.shop', [product()])
        self.record = catalog.records(self.root)[0]

    def save_result(self, value, name='result.json'):
        path = self.root / name
        catalog.write(path, value)
        return path

    def decision(self, action='suppress_claims', terms=None):
        return {'key': self.record['key'], 'source_fingerprint': self.record['source_fingerprint'],
                'action': action, 'terms': terms or ['pleated'], 'reviewer': 'test reviewer',
                'reason': 'Feature is not supported by reviewed evidence'}

    def test_import_is_idempotent_and_prices_remain_native(self):
        original = copy.deepcopy(self.record['source'])
        catalog.accept(self.root, self.save_result(result(self.record)))
        catalog.import_products(self.root, 'apparel.mock.shop', [product()])
        records = catalog.records(self.root)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]['source'], original)
        self.assertEqual(len(records[0]['revisions']), 1)
        self.assertEqual(catalog.state(records[0]), 'candidate')
        self.assertEqual(records[0]['source']['product']['variants']['nodes'][0]['price']['currencyCode'], 'USD')

    def test_color_synonyms_and_source_mismatch(self):
        self.assertFalse(catalog.source_flags(product()))
        p = product()
        p['options'][0]['values'] = ['Olive', 'Taupe', 'Black']
        flags = catalog.source_flags(p)
        self.assertTrue(any(f['code'] == 'title_variant_color_mismatch' and f['blocking'] for f in flags))

    def test_model_cannot_overwrite_prices_or_ids(self):
        for name, value in [('price_eur', 78), ('source', {}), ('product_id', 'invented')]:
            candidate = result(self.record)
            candidate[name] = value
            with self.assertRaises(ValueError):
                catalog.accept(self.root, self.save_result(candidate))
        self.assertEqual(catalog.records(self.root)[0]['revisions'], [])

    def test_source_changes_invalidate_results_and_preserve_old_snapshot(self):
        old_result = result(self.record)
        catalog.accept(self.root, self.save_result(old_result))
        changed = product()
        changed['description'] = 'Updated composition claim.'
        catalog.import_products(self.root, 'apparel.mock.shop', [changed])
        current = catalog.records(self.root)[0]
        self.assertIsNone(catalog.latest(current))
        self.assertEqual(catalog.state(current), 'needs_enrichment')
        self.assertEqual(len(current['revisions']), 1)
        self.assertTrue(list((self.root / 'source-history').rglob('*.json')))
        with self.assertRaises(ValueError):
            catalog.accept(self.root, self.save_result(old_result))

    def test_review_invalidates_old_results_and_suppression_is_enforced(self):
        previous = result(self.record)
        catalog.accept(self.root, self.save_result(previous))
        catalog.apply_review(self.root, [self.decision()])
        current = catalog.records(self.root)[0]
        self.assertIsNone(catalog.latest(current))
        with self.assertRaises(ValueError):
            catalog.accept(self.root, self.save_result(previous))
        with self.assertRaises(ValueError):
            catalog.accept(self.root, self.save_result(result(current)))
        corrected = result(current)
        corrected['attributes']['keywords']['value'] = ['relaxed fit']
        corrected['search_document'] = 'Relaxed linen trousers.'
        catalog.accept(self.root, self.save_result(corrected))
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'candidate')

    def test_exclusion_survives_a_subsequent_suppression_review(self):
        catalog.apply_review(self.root, [self.decision('exclude'), self.decision()])
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'excluded')
        catalog.apply_review(self.root, [self.decision('restore')])
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'needs_enrichment')

    def test_model_cannot_self_clear_source_contradictions(self):
        p = product()
        p['options'][0]['values'] = ['Olive']
        catalog.import_products(self.root, 'apparel.mock.shop', [p])
        current = catalog.records(self.root)[0]
        catalog.accept(self.root, self.save_result(result(current)))
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'needs_review')

    def test_unavailable_title_colors_are_rejected_in_searchable_text(self):
        p = product()
        p['options'][0]['values'] = ['Olive']
        catalog.import_products(self.root, 'apparel.mock.shop', [p])
        candidate = result(catalog.records(self.root)[0])
        candidate['search_document'] = 'Graphite grey pleated trousers.'
        with self.assertRaises(ValueError):
            catalog.accept(self.root, self.save_result(candidate))

    def test_model_cannot_drop_its_previous_blocking_flags(self):
        first = result(self.record)
        first['quality_flags'] = [catalog.flag('unverified_pleats', 'medium', 'details',
                                              'Pleats are not established.', 'image', True)]
        catalog.accept(self.root, self.save_result(first))
        catalog.accept(self.root, self.save_result(result(self.record)))
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'needs_review')
        catalog.apply_review(self.root, [{**self.decision(), 'flag_codes': ['unverified_pleats']}])
        current = catalog.records(self.root)[0]
        self.assertEqual(catalog.state(current), 'needs_enrichment')
        safe = result(current)
        safe['attributes']['keywords']['value'] = ['relaxed fit']
        safe['search_document'] = 'Relaxed linen trousers.'
        catalog.accept(self.root, self.save_result(safe))
        self.assertEqual(catalog.state(catalog.records(self.root)[0]), 'candidate')

    def test_review_cannot_clear_source_flags_with_suppression(self):
        p = product()
        p['options'][0]['values'] = ['Olive']
        catalog.import_products(self.root, 'apparel.mock.shop', [p])
        current = catalog.records(self.root)[0]
        decision = {**self.decision(), 'source_fingerprint': current['source_fingerprint'],
                    'flag_codes': ['title_variant_color_mismatch']}
        with self.assertRaises(ValueError):
            catalog.apply_review(self.root, [decision])

    def test_invalid_review_batch_does_not_apply_partial_decisions(self):
        bad = self.decision()
        bad['source_fingerprint'] = 'old snapshot'
        with self.assertRaises(ValueError):
            catalog.apply_review(self.root, [self.decision('exclude'), bad])
        self.assertEqual(catalog.records(self.root)[0]['reviews'], [])

    def test_invalid_result_batch_does_not_accept_partial_revisions(self):
        bad = result(self.record)
        bad['source_fingerprint'] = 'old snapshot'
        with self.assertRaises(ValueError):
            catalog.accept_many(self.root, [self.save_result(result(self.record), 'good.json'),
                                            self.save_result(bad, 'bad.json')])
        self.assertEqual(catalog.records(self.root)[0]['revisions'], [])

    def test_invalid_source_batch_does_not_partially_import(self):
        with self.assertRaises(ValueError):
            catalog.import_products(self.root, 'apparel.mock.shop', [product('2'), product('2')])
        self.assertEqual(len(catalog.records(self.root)), 1)

    def test_jobs_include_current_flags_reviews_and_prior_enrichment(self):
        catalog.accept(self.root, self.save_result(result(self.record)))
        catalog.apply_review(self.root, [self.decision()])
        current = catalog.records(self.root)[0]
        job = catalog.make_job(current)
        self.assertEqual(job['suppress_terms'], ['pleated'])
        self.assertEqual(job['previous_enrichment']['attributes']['keywords']['value'], ['pleated'])
        self.assertEqual(catalog.prepare(self.root, self.root / 'jobs', 50, True), 1)
        self.assertEqual(catalog.read(self.root / 'jobs' / 'batch.json')['model_calls_made'], 0)

    def test_bad_attributes_and_high_flags_fail_closed(self):
        mutations = [lambda r: r['attributes']['category'].update(value='coat'),
                     lambda r: r['attributes']['material'].update(confidence='100%'),
                     lambda r: r['attributes']['material'].update(evidence=[]),
                     lambda r: r.update(quality_flags=[catalog.flag('mismatch', 'high', 'color', 'Bad', 'image')])]
        for mutate in mutations:
            candidate = result(self.record)
            mutate(candidate)
            with self.assertRaises(ValueError):
                catalog.accept(self.root, self.save_result(candidate))

    def test_duplicate_images_are_flagged_without_dropping_records(self):
        catalog.import_products(self.root, 'other-apparel.mock.shop', [product()])
        summary = catalog.audit(self.root)
        self.assertEqual(summary['imported'], 2)
        self.assertEqual(summary['flag_counts']['shared_image'], 2)
        self.assertFalse(summary['app_published'])

    def test_invalid_prices_and_incomplete_variants_are_held(self):
        p = product()
        p['variants']['nodes'][0]['price']['amount'] = 'NaN'
        p['variants']['pageInfo']['hasNextPage'] = True
        codes = {f['code'] for f in catalog.source_flags(p) if f['blocking']}
        self.assertTrue({'invalid_price', 'incomplete_variants'} <= codes)

    def test_import_host_and_record_key_cannot_escape_workspace(self):
        with self.assertRaises(ValueError):
            catalog.import_products(self.root, 'evil.example', [product()])
        with self.assertRaises(ValueError):
            catalog.record_path(self.root, '../../elsewhere')

    def test_review_and_result_replays_do_not_duplicate_history(self):
        path = self.save_result(result(self.record))
        self.assertTrue(catalog.accept(self.root, path))
        self.assertFalse(catalog.accept(self.root, path))
        catalog.apply_review(self.root, [self.decision(), self.decision()])
        current = catalog.records(self.root)[0]
        self.assertEqual(len(current['revisions']), 1)
        self.assertEqual(len(current['reviews']), 1)


if __name__ == '__main__':
    unittest.main()
