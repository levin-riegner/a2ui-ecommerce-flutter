"""Validate saved native simulator evidence, independent of Flutter layout code."""
import collections
import itertools
import json
from pathlib import Path
import re
import sys


def numbers(value):
    return list(map(float, re.findall(r'-?\d+(?:\.\d+)?', value)))


def overlaps(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


def verify(rows):
    expected = set(itertools.product(
        ['large', 'maximum'], ['Closed', 'Book', 'Open'], range(4), ['off', 'on'],
    ))
    actual = [(r['textSize'], r['preset'], r['rotation'], r['keyboardRequested'])
              for r in rows]
    assert len(actual) == len(set(actual)) == 48 and set(actual) == expected
    baseline = rows[0]['probe']
    field = baseline['fields'][0]
    layouts = collections.Counter()
    for index, row in enumerate(rows):
        probe = row['probe']
        label = f'checkpoint {index}: {actual[index]}'
        assert row['keyboardVerified'] and row['retained'], label
        assert probe['support'] == 'available', label
        assert probe['status'] == {
            'Closed': 'closed', 'Book': 'partiallyOpen', 'Open': 'fullyOpen',
        }[row['preset']], label
        angle = probe['angle']
        assert 0 <= angle <= 180, label
        if row['preset'] in ('Closed', 'Open'):
            assert abs(angle - (0 if row['preset'] == 'Closed' else 180)) < .1, label
        else:
            assert 0 < angle < 180, label
        for name in ('agent', 'surface', 'journey', 'selected', 'spent'):
            assert probe[name] == baseline[name], (label, name)
        width, height = numbers(probe['size'])
        keyboard = probe['keyboard']
        assert (keyboard > 0) == (row['keyboardRequested'] == 'on'), label
        for current in probe['fields']:
            assert current['draft'] == field['draft'], label
            assert current['state'] == field['state'], label
            if row['textSize'] == 'maximum':
                assert current['textScale'] >= 3, label
            else:
                assert abs(current['textScale'] - 1) < .01, label
            bounds = numbers(current['bounds'])
            assert bounds[0] >= 0 and bounds[1] >= 0, label
            assert bounds[2] <= width + 1 and bounds[3] <= height - keyboard + 1, label
            for region in probe['regions']:
                active_fold = region['kind'] == 'division' and probe['status'] == 'partiallyOpen'
                active_camera = region['kind'] == 'occlusion'
                if region['active'] and (active_fold or active_camera):
                    assert not overlaps(bounds, numbers(region['bounds'])), (label, region)
        if row['preset'] == 'Open':
            assert not any('obstructed-split' in layout for layout in probe['layouts']), label
        for layout in probe['layouts']:
            layouts[layout] += 1
        action = row['action']
        assert action['axResult'] == 0 and action['frontBefore'] == action['frontAfter'], label
    assert any('obstructed-split' in layout for layout in layouts)
    assert any('split-pane' in layout for layout in layouts)
    return {'checkpoints': len(rows), 'keyboardVerified': len(rows),
            'stateRetained': len(rows), 'geometryVerified': len(rows),
            'foregroundUnchanged': len(rows), 'layouts': dict(layouts)}


if __name__ == '__main__':
    print(json.dumps(verify(json.loads(Path(sys.argv[1]).read_text())), indent=2))
