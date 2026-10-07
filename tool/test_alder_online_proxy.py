"""Exercise the credential boundary without contacting a real provider."""
import io
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from alder_online_proxy import make_handler


class FakeProvider:
    def __init__(self):
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        return io.BytesIO(b'{"choices": []}')


class DemoBridgeTest(unittest.TestCase):
    def setUp(self):
        self.provider = FakeProvider()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), make_handler(
            'provider-secret', 'gpt-6-luna', 'session-secret', 2, self.provider))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def send(self, *, token='session-secret', model='gpt-6-luna', path='/v1/chat/completions'):
        request = urllib.request.Request(self.url + path,
            data=json.dumps({'model': model, 'messages': []}).encode(),
            headers={'Authorization': f'Bearer {token}'})
        try:
            response = urllib.request.urlopen(request, timeout=2)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read().decode()

    def test_injects_provider_key_only_at_fixed_upstream_and_caps_requests(self):
        self.assertEqual(self.send()[0], 200)
        self.assertEqual(self.send()[0], 200)
        status, headers, body = self.send()
        self.assertEqual(status, 429)
        self.assertEqual(headers['X-Alder-Demo-Error'], 'allowance_exhausted')
        self.assertNotIn('provider-secret', body)
        self.assertEqual(len(self.provider.requests), 2)
        request = self.provider.requests[0]
        self.assertEqual(request.full_url, 'https://api.openai.com/v1/chat/completions')
        self.assertEqual(request.get_header('Authorization'), 'Bearer provider-secret')
        data = json.loads(request.data)
        self.assertFalse(data['store'])
        self.assertEqual(data['reasoning_effort'], 'none')
        self.assertNotIn('provider-secret', request.data.decode())

    def test_invalid_auth_path_or_model_never_reaches_provider(self):
        self.assertEqual(self.send(token='wrong')[0], 401)
        self.assertEqual(self.send(path='/anything')[0], 404)
        self.assertEqual(self.send(model='other')[0], 400)
        self.assertEqual(self.provider.requests, [])


class DefaultAllowanceDemoBridgeTest(DemoBridgeTest):
    def setUp(self):
        self.provider = FakeProvider()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), make_handler(
            'provider-secret', 'gpt-6-luna', 'session-secret', opener=self.provider))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'

    def test_injects_provider_key_only_at_fixed_upstream_and_caps_requests(self):
        for _ in range(12):
            status, headers, body = self.send()
            self.assertEqual(status, 200)
            self.assertNotIn('X-Alder-Demo-Error', headers)
            self.assertNotIn('provider-secret', body)
        status, headers, _ = self.send()
        self.assertEqual(status, 429)
        self.assertEqual(headers['X-Alder-Demo-Error'], 'allowance_exhausted')
        self.assertEqual(len(self.provider.requests), 12)


class AllowanceValidationTest(unittest.TestCase):
    def test_unbounded_or_invalid_allowance_is_rejected(self):
        for limit in [None, 0, -1, True]:
            with self.subTest(limit=limit), self.assertRaises(ValueError):
                make_handler('key', 'model', 'token', limit)
