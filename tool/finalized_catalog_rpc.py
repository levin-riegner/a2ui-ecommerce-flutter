"""Sweep the provider-free fixture gallery on the actual Duo simulator."""
import argparse
import json
import pathlib
import time

from duo_simulator_rpc import call


def sweep(base):
    vm = call(base, 'getVM')
    isolate = next(i for i in vm['isolates'] if i['name'] == 'main')['id']
    initial = call(base, 'ext.catalog.capture', isolateId=isolate)
    records = []
    for item in initial['items']:
        for variant in range(item['variants']):
            call(base, 'ext.catalog.select', isolateId=isolate,
                 component=item['name'], variant=variant)
            snapshot = call(base, 'ext.catalog.capture', isolateId=isolate)
            records.append({k: v for k, v in snapshot.items() if k != 'items'})
    return {'native': True, 'providerRequests': 0, 'records': records}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('vm_url')
    parser.add_argument('--output', required=True)
    parser.add_argument('--component')
    parser.add_argument('--variant', type=int, default=0)
    parser.add_argument('--expected-status', choices=['closed', 'partiallyOpen', 'fullyOpen'])
    parser.add_argument('--screens', action='store_true')
    args = parser.parse_args()
    if args.screens:
        vm = call(args.vm_url, 'getVM')
        isolate = next(i for i in vm['isolates'] if i['name'] == 'main')['id']
        examples = json.loads(pathlib.Path('docs/design/export/screens.json').read_text())
        if args.expected_status:
            for _ in range(20):
                state = call(args.vm_url, 'ext.catalog.screen', isolateId=isolate, index=0)
                if state['status'] == args.expected_status:
                    break
                time.sleep(0.25)
            else:
                raise RuntimeError('The requested native posture did not settle')
        result = {'native': True, 'providerRequests': 0, 'records': [
            call(args.vm_url, 'ext.catalog.screen', isolateId=isolate, index=index)
            for index in range(len(examples))]}
    elif args.component:
        vm = call(args.vm_url, 'getVM')
        isolate = next(i for i in vm['isolates'] if i['name'] == 'main')['id']
        call(args.vm_url, 'ext.catalog.select', isolateId=isolate,
             component=args.component, variant=args.variant)
        result = call(args.vm_url, 'ext.catalog.capture', isolateId=isolate)
    else:
        result = sweep(args.vm_url)
    path = pathlib.Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2) + '\n')
    records = result.get('records', [result])
    failures = [r for r in records if r['errors'] or
                (args.expected_status and r['status'] != args.expected_status)]
    print(json.dumps({'states': len(records), 'failures': failures}))
    raise SystemExit(bool(failures))
