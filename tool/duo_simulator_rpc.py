"""Query the test-only Duo probe through its local Dart VM service."""
import argparse
import json
import urllib.parse
import urllib.request


def call(base, method, **params):
    url = base.rstrip('/') + '/' + method + '?' + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=10) as response:
        message = json.load(response)
    if 'error' in message:
        raise RuntimeError(message['error'])
    return message['result']


def capture(base, *, focus=False, draft=None, keyboard=None):
    vm = call(base, 'getVM')
    isolate = next(i for i in vm['isolates'] if i['name'] == 'main')
    params = {'isolateId': isolate['id']}
    if draft is not None:
        params['draft'] = draft
    method = 'ext.duo.focus' if focus else 'ext.duo.capture'
    if keyboard is not None:
        method = 'ext.duo.keyboard'
        params['visible'] = 'true' if keyboard == 'on' else 'false'
    return call(base, method, **params)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('vm_url')
    parser.add_argument('--focus', action='store_true')
    parser.add_argument('--draft')
    parser.add_argument('--keyboard', choices=['on', 'off'])
    args = parser.parse_args()
    print(json.dumps(capture(args.vm_url, focus=args.focus, draft=args.draft,
                             keyboard=args.keyboard)))
