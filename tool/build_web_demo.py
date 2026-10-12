"""Build the public BYOK entry point without credentials or live weather.

No deploy occurs here. --allow-dirty is for local QA only; a deployable artifact
must be produced from a clean commit after separate hosting/asset clearance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


SECRET_PATTERNS = (
    re.compile(rb"sk-(?:proj-|ant-)?[A-Za-z0-9_-]{24,}"),
    re.compile(rb"AIza[0-9A-Za-z_-]{35}"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
)


def audit_bundle(directory):
    """Reject credential-shaped content, private files, links and debug maps.

    This is a conservative release check, not a proof that arbitrary data is
    public. Asset ownership and data clearance are independent release gates.
    Only file names are included in errors; matching content is never printed.
    """
    files = {}
    for path in sorted(directory.rglob('*')):
        relative = path.relative_to(directory).as_posix()
        if path.is_symlink():
            raise ValueError(f'Unexpected symlink: {relative}')
        if not path.is_file():
            continue
        if (any(part.startswith('.') for part in path.relative_to(directory).parts)
                or path.suffix in {'.map', '.pem', '.key', '.log'}
                or 'session' in path.name.lower()):
            raise ValueError(f'Unexpected private/debug file: {relative}')
        data = path.read_bytes()
        if any(pattern.search(data) for pattern in SECRET_PATTERNS):
            raise ValueError(f'Credential-shaped content: {relative}')
        files[relative] = hashlib.sha256(data).hexdigest()
    for required in ('index.html', 'main.dart.js', 'flutter_bootstrap.js'):
        if required not in files:
            raise ValueError(f'Missing web entry point: {required}')
    return files


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--allow-dirty', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    dirty = bool(git(root, 'status', '--porcelain'))
    if dirty and not args.allow_dirty:
        parser.error('Commit changes first; --allow-dirty permits local QA only')
    revision = git(root, 'rev-parse', 'HEAD')
    # Do not forward process provider credentials to the build or accept an env
    # file/alternate entry point. Personal launchers are never release inputs.
    import os
    environment = {k: v for k, v in os.environ.items()
                   if not re.search(r'API.?KEY|TOKEN|SECRET|PASSWORD', k, re.I)}
    output = root / 'build' / 'web'
    if output.is_symlink():
        parser.error('Release output directory must not be a symlink')
    if output.exists():
        shutil.rmtree(output)
    subprocess.run([
        args.flutter, '--suppress-analytics', 'build', 'web', '--release',
        '--target=lib/main.dart', '--no-source-maps', '--no-web-resources-cdn',
        '--dart-define=ALDER_ENABLE_OPEN_METEO=false',
    ], cwd=root, env=environment, check=True)
    # Flutter's local rebuild marker is not a public web asset.
    (output / '.last_build_id').unlink(missing_ok=True)
    for marker in output.rglob('.gitkeep'):
        if marker.is_symlink() or marker.read_bytes():
            raise ValueError('Unexpected non-empty asset directory marker')
        marker.unlink()
    manifest = {
        'commit': revision,
        'dirty': dirty,
        'entryPoint': 'lib/main.dart',
        'modelMode': 'BYOK',
        'liveWeather': False,
        'catalogPath': '/#/catalog',
        'files': audit_bundle(output),
    }
    (output / 'alder-build.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({key: value for key, value in manifest.items() if key != 'files'}))


if __name__ == '__main__':
    main()
