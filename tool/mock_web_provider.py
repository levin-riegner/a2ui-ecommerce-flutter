"""Loopback-only production web QA with synthetic OpenAI-compatible replies.

No live model, forecast, credential lookup or external requests. Serve the
release build, connect OpenAI-compatible to http://127.0.0.1:8877/v1 using model
alder-mock and the literal non-secret key alder-local-qa-no-secret. GET /__qa
reports counts; POST /__qa/fail-next causes one 503 to exercise explicit Retry.
Never deploy this server or represent its outputs as live model validation.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re


def message_text(message):
    content = message.get('content', '')
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return ' '.join(part.get('text', '') for part in content
                        if isinstance(part, dict) and part.get('type') == 'text')
    return ''


def mock_reply(request):
    messages = request.get('messages', [])
    last = messages[-1] if messages else {}
    tools = request.get('tools', [])
    system = ' '.join(message_text(m) for m in messages
                      if m.get('role') == 'system')
    result = json.loads(last['content']) if last.get('role') == 'tool' else {}
    allowed = {t.get('function', {}).get('name') for t in tools}
    selected = system.partition('Host outfit facts: ')[2].partition('\n')[0]
    removal = re.search(r'id: ([^,]+), name: ([^,]+),', selected)
    remove_requested = (
        last.get('role') == 'user'
        and message_text(last).lower().startswith('remove ')
        and removal
        and removal.group(2).lower() in message_text(last).lower()
        and 'remove_from_outfit' in allowed
    )
    # The host governs admissible categories, product validation and state.
    if remove_requested:
        content, call = None, ('remove_from_outfit', {'productId': removal.group(1)})
    elif not tools or last.get('name') == 'present_products':
        content = 'Mock provider: these are catalog options for local QA.'
        call = None
    elif last.get('role') == 'tool' and 'products' in result:
        ids = [p['id'] for p in result['products'][:2]]
        if ids:
            content, call = None, ('present_products', {'productIds': ids})
        else:
            content, call = 'Mock provider: no catalog options.', None
    elif 'Searching is blocked' in system:
        content, call = 'Mock provider: complete the brief first.', None
    elif 'The outfit is complete.' in system:
        content, call = 'Mock provider: your catalog look is complete.', None
    else:
        category = re.search(r'Next category: (\w+)', system)
        content, call = None, ('search_products', {
            'query': '', 'category': category.group(1) if category else 'dress',
            'limit': 2,
        })
    message = {'role': 'assistant', 'content': content}
    if call:
        name, arguments = call
        message['tool_calls'] = [{
            'id': f'mock-{name}', 'type': 'function',
            'function': {'name': name, 'arguments': json.dumps(arguments)},
        }]
    return {
        'id': 'alder-local-mock', 'object': 'chat.completion', 'created': 1,
        'model': 'alder-mock',
        'choices': [{'index': 0, 'message': message,
                     'finish_reason': 'tool_calls' if call else 'stop'}],
        'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    }


class Handler(SimpleHTTPRequestHandler):
    requests = 0
    fail_next = False

    def log_message(self, *_):
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == '/__qa':
            return self.reply(200, {'mock': True, 'requests': Handler.requests,
                                    'failurePending': Handler.fail_next})
        super().do_GET()

    def do_POST(self):
        if self.path == '/__qa/fail-next':
            Handler.fail_next = True
            return self.reply(200, {'mock': True, 'failurePending': True})
        if self.path != '/v1/chat/completions':
            return self.reply(404, {'error': {'message': 'Unknown QA endpoint'}})
        if self.headers.get('Authorization') != 'Bearer alder-local-qa-no-secret':
            return self.reply(400, {'error': {'message': 'Use the synthetic QA key only'}})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length < 250000:
                raise ValueError()
            request = json.loads(self.rfile.read(length))
            if request.get('model') != 'alder-mock' or request.get('stream'):
                raise ValueError()
            Handler.requests += 1
            if Handler.fail_next:
                Handler.fail_next = False
                return self.reply(503, {'error': {'message': 'Injected mock failure'}})
            return self.reply(200, mock_reply(request))
        except (ValueError, TypeError, KeyError):
            return self.reply(400, {'error': {'message': 'Invalid QA request'}})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web-dir', type=Path, default=Path('build/web'))
    parser.add_argument('--port', type=int, default=8877)
    args = parser.parse_args()
    if not (args.web_dir / 'main.dart.js').is_file():
        parser.error('Build the public web entry point first')
    server = ThreadingHTTPServer(('127.0.0.1', args.port),
                                partial(Handler, directory=str(args.web_dir)))
    print(f'Local mock QA only: http://127.0.0.1:{args.port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
