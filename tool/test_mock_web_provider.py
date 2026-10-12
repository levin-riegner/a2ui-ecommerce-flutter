import importlib.util
import json
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    'mock_web_provider', Path(__file__).with_name('mock_web_provider.py'))
mock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mock)


class MockProviderTests(unittest.TestCase):
    def test_search_and_presentation_follow_host_state(self):
        reply = mock.mock_reply({
            'tools': [{'function': {'name': 'search_products'}}],
            'messages': [{'role': 'system', 'content': 'Next category: bottom'}],
        })
        call = reply['choices'][0]['message']['tool_calls'][0]['function']
        self.assertEqual(call['name'], 'search_products')
        self.assertEqual(json.loads(call['arguments'])['category'], 'bottom')
        reply = mock.mock_reply({
            'tools': [{'function': {'name': 'present_products'}}],
            'messages': [{'role': 'tool', 'name': 'search_products',
                          'content': json.dumps({'products': [{'id': 'fixture-1'}]})}],
        })
        call = reply['choices'][0]['message']['tool_calls'][0]['function']
        self.assertEqual(json.loads(call['arguments'])['productIds'], ['fixture-1'])

    def test_completion_is_explicitly_mock_and_has_no_tools(self):
        reply = mock.mock_reply({'messages': [], 'tools': []})
        message = reply['choices'][0]['message']
        self.assertIn('Mock provider', message['content'])
        self.assertNotIn('tool_calls', message)

    def test_synthetic_removal_uses_only_selected_host_id(self):
        reply = mock.mock_reply({
            'tools': [{'function': {'name': 'remove_from_outfit'}}],
            'messages': [
                {'role': 'system', 'content':
                 'Host outfit facts: [{id: fixture-1, name: Fixture Top, brand: Fixture}].\n'},
                {'role': 'user', 'content': [{'type': 'text',
                 'text': 'Remove the top named Fixture Top from my outfit'}]},
            ],
        })
        call = reply['choices'][0]['message']['tool_calls'][0]['function']
        self.assertEqual(call['name'], 'remove_from_outfit')
        self.assertEqual(json.loads(call['arguments']), {'productId': 'fixture-1'})


if __name__ == '__main__':
    unittest.main()
