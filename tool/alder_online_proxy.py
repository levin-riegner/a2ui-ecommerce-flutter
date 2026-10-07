"""Loopback-only simulator demo bridge. Keeps provider credentials on the Mac.

Read .env.local without logging credentials. Requires explicit --live consent.
Sessions default to twelve provider requests. The native
app receives a short-lived proxy token, never the provider API key.
"""
import argparse
import hmac
import json
import os
import secrets
import signal
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def settings(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        name, sep, value = line.strip().partition('=')
        if sep and not name.startswith('#'):
            result[name.strip()] = value.strip().strip('\"').strip("'")
    return result


def make_handler(key, model, token, max_requests=12, opener=None):
    if not isinstance(max_requests, int) or isinstance(max_requests, bool) or max_requests < 1:
        raise ValueError('A positive request allowance is required')
    lock = threading.Lock()
    requests = 0
    class NoRedirects(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            raise urllib.error.HTTPError(req.full_url, code, 'Redirect refused', headers, fp)

    opener = opener or urllib.request.build_opener(NoRedirects())

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def reply(self, status, body, *, allowance_exhausted=False):
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            if allowance_exhausted:
                self.send_header('X-Alder-Demo-Error', 'allowance_exhausted')
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            nonlocal requests
            if self.path != '/v1/chat/completions':
                return self.reply(404, {'error': {'message': 'Unknown demo endpoint'}})
            if not hmac.compare_digest(self.headers.get('Authorization', ''), f'Bearer {token}'):
                return self.reply(401, {'error': {'message': 'Demo session unavailable'}})
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 250000:
                    raise ValueError()
                data = json.loads(self.rfile.read(length))
                if data.get('model') != model or data.get('stream') is True:
                    raise ValueError()
            except (ValueError, TypeError, AttributeError):
                return self.reply(400, {'error': {'message': 'Invalid demo request'}})
            with lock:
                if requests >= max_requests:
                    return self.reply(429, {'error': {'message': 'Demo request allowance reached'}}, allowance_exhausted=True)
                requests += 1
                number = requests
            try:
                data['store'] = False
                if model == 'gpt-6-luna':
                    data['reasoning_effort'] = 'none'
                request = urllib.request.Request('https://api.openai.com/v1/chat/completions',
                    data=json.dumps(data).encode(), method='POST',
                    headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'})
                with opener.open(request, timeout=50) as response:
                    body = json.load(response)
                print(json.dumps({'request': number, 'status': 200,
                    'tools': [c.get('function', {}).get('name') for choice in body.get('choices', [])
                              for c in choice.get('message', {}).get('tool_calls', [])]}), flush=True)
                self.reply(200, body)
            except urllib.error.HTTPError as error:
                print(json.dumps({'request': number, 'status': error.code}), flush=True)
                self.reply(error.code, {'error': {'message': 'Provider rejected the demo request'}})
            except Exception:
                print(json.dumps({'request': number, 'status': 'unavailable'}), flush=True)
                self.reply(502, {'error': {'message': 'Provider unavailable'}})

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--port', type=int, default=8788)
    parser.add_argument('--max-requests', type=int, default=12)
    parser.add_argument('--reuse-session', help='Private existing configuration to preserve the app session token')
    parser.add_argument('--env-file', default='.env.local')
    parser.add_argument('--config-file', default='/private/tmp/alder-online-session.json')
    args = parser.parse_args()
    if not args.live or args.max_requests < 1:
        parser.error('Explicit --live required; max requests must be positive')
    config = settings(args.env_file)
    key = config.get('OPENAI_API_KEY', '')
    model = config.get('OPENAI_MODEL', '')
    if not key or not model:
        parser.error('Configure OPENAI_API_KEY and OPENAI_MODEL in ignored .env.local')
    token = secrets.token_urlsafe(32)
    if args.reuse_session:
        previous = json.loads(Path(args.reuse_session).read_text())
        if (previous.get('ALDER_DEMO_PROXY') != f'http://127.0.0.1:{args.port}/v1'
                or previous.get('ALDER_DEMO_MODEL') != model
                or not isinstance(previous.get('ALDER_DEMO_TOKEN'), str)
                or len(previous['ALDER_DEMO_TOKEN']) < 32):
            parser.error('Existing session does not match this demo endpoint and model')
        token = previous['ALDER_DEMO_TOKEN']
    path = Path(args.config_file)
    fd = os.open(path, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump({'ALDER_DEMO_PROXY': f'http://127.0.0.1:{args.port}/v1',
                   'ALDER_DEMO_TOKEN': token, 'ALDER_DEMO_MODEL': model}, file)

    handler = make_handler(key, model, token, args.max_requests)
    server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    print(json.dumps({'proxy': f'http://127.0.0.1:{args.port}/v1',
                     'model': model, 'requestLimit': args.max_requests,
                     'configurationFile': str(path)}), flush=True)
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
