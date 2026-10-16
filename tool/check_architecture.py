"""Enforce the reference repo's import boundaries without a Flutter runtime."""
from collections import deque
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
_DIRECTIVE = re.compile(r"(?:^|(?<=;))\s*(?:import|export|part(?!\s+of))\s+([^;]+);", re.MULTILINE)
_URI = re.compile(r"['\"]([^'\"]+)['\"]")
_COMMENT_OR_STRING = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/")
# Pure domain ports and shared query policy live beside their implementations.
# Each is checked transitively; this is not an exception for all repositories.
DOMAIN_PORTS = (
    'lib/data/stylist/repository/stylist_store.dart',
    'lib/data/catalog/repository/catalog_search.dart',
)
_PRESENTATION_SDKS = (
    'package:flutter_bloc/', 'package:bloc/', 'package:genui/',
    'package:a2ui_core/', 'package:provider/', 'package:get_it/',
    'package:go_router/',
)
_PROVIDER_SDKS = ('package:genkit',)
_PLATFORM_SDKS = (
    'package:flutter/', 'package:flutter_localizations/',
    'package:shared_preferences', 'package:http/',
)



def imports(path):
    """Include exports, parts and every conditional-import alternative."""
    source = path.read_text()
    source = _COMMENT_OR_STRING.sub(
        lambda match: '\n' * match[0].count('\n') if match[0].startswith(('//', '/*')) else match[0],
        source,
    )
    for match in _DIRECTIVE.finditer(source):
        yield from _URI.findall(match[1])


def local_path(root, source, uri):
    if uri.startswith('package:a2ui_flutter_commerce/'):
        return root / 'lib' / uri.removeprefix('package:a2ui_flutter_commerce/')
    if ':' not in uri:
        return (source.parent / uri).resolve()
    return None


def inspect_graph(root, entry, label, reject):
    root = root.resolve()
    errors = []
    pending = deque([(root / entry, [entry])])
    seen = set()
    while pending:
        source, chain = pending.popleft()
        if source in seen:
            continue
        seen.add(source)
        if not source.is_file():
            errors.append(f'{label}: missing local dependency {" -> ".join(chain)}')
            continue
        for uri in imports(source):
            target = local_path(root, source, uri)
            relative = target.relative_to(root).as_posix() if target and target.is_relative_to(root) else None
            reason = reject(uri, relative)
            if reason:
                errors.append(f'{label}: {" -> ".join(chain)} -> {uri}: {reason}')
            elif target:
                pending.append((target, [*chain, relative or str(target)]))
    return errors


def _is_model(relative):
    return (relative.startswith('lib/data/') and '/model/' in relative
            and '/service/' not in relative)


def _is_composition(relative):
    return relative.startswith('lib/util/') or (
        relative.startswith('lib/app/') and not relative.startswith('lib/app/l10n/')
    )


def ui_reject(uri, relative):
    if uri.startswith((*_PRESENTATION_SDKS, *_PROVIDER_SDKS,
                       'package:schemantic/', 'package:json_schema_builder/')):
        return 'public widgets must not depend on BLoC, provider or renderer SDKs'
    if relative and (
        '/bloc/' in relative
        or relative.startswith(('lib/presentation/stylist/a2ui/',
                                'lib/presentation/gallery/',
                                'lib/presentation/connection/'))
        or _is_composition(relative)
        or (relative.startswith('lib/data/') and not _is_model(relative))
    ):
        return 'public widgets must not include state controllers, data adapters, registrations or galleries'
    return None


def registration_reject(uri, relative):
    if uri.startswith((*_PROVIDER_SDKS, 'package:flutter_bloc/', 'package:bloc/',
                       'package:shared_preferences', 'package:http/',
                       'package:provider/', 'package:get_it/')):
        return 'A2UI registrations must not configure providers, state controllers or storage'
    if relative and (
        '/bloc/' in relative
        or relative.startswith(('lib/presentation/gallery/',
                                'lib/presentation/connection/'))
        or _is_composition(relative)
        or (relative.startswith('lib/data/') and not _is_model(relative))
    ):
        return 'A2UI registrations must not pull runtime, data adapters or opt-in gallery code'
    return None


def domain_reject(uri, relative):
    if uri.startswith((*_PRESENTATION_SDKS, *_PROVIDER_SDKS, *_PLATFORM_SDKS,
                       'dart:io', 'dart:ui', 'dart:html', 'dart:ffi')):
        return 'domain contracts must not depend on Flutter, providers, renderers or platform transports'
    if relative and not (_is_model(relative) or relative in DOMAIN_PORTS):
        return 'domain contracts must depend on values and explicit pure ports, not adapters'
    return None


def data_reject(uri, relative):
    if uri.startswith(_PRESENTATION_SDKS):
        return 'data must not depend on presentation or renderer SDKs'
    if relative and not relative.startswith('lib/data/'):
        return 'data must not import presentation, app configuration or composition'
    return None


def runtime_reject(uri, relative):
    if uri.startswith((*_PRESENTATION_SDKS, *_PLATFORM_SDKS,
                       'dart:io', 'dart:ui', 'dart:html', 'dart:ffi')):
        return 'runtime orchestration must keep renderer and platform adapters outside'
    if relative and not (
        _is_model(relative)
        or relative in DOMAIN_PORTS
        or relative.startswith('lib/data/stylist/service/runtime/')
    ):
        return 'runtime orchestration must use domain values and ports, not concrete adapters'
    return None


def check(root=ROOT):
    root = root.resolve()
    errors = inspect_graph(root, 'lib/commerce_ui.dart', 'commerce_ui', ui_reject)
    errors.extend(inspect_graph(root, 'lib/commerce_a2ui.dart', 'commerce_a2ui', registration_reject))
    model_files = [path.relative_to(root).as_posix()
                   for path in (root / 'lib/data').rglob('*.dart')
                   if _is_model(path.relative_to(root).as_posix())]
    for name in sorted([*model_files, *DOMAIN_PORTS]):
        errors.extend(inspect_graph(root, name, name, domain_reject))
    # Check every data file so a repository cannot hide a reverse dependency
    # in a transport, helper, export or generated/conditional directive.
    for path in sorted((root / 'lib/data').rglob('*.dart')):
        name = path.relative_to(root).as_posix()
        errors.extend(inspect_graph(root, name, name, data_reject))
    runtime = 'lib/data/stylist/service/runtime/stylist_runtime.dart'
    errors.extend(inspect_graph(root, runtime, 'stylist_runtime', runtime_reject))
    return sorted(set(errors))


if __name__ == '__main__':
    problems = check()
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        raise SystemExit(1)
    print('Architecture boundaries passed: transitive public widgets/catalogs, domain models/ports, data direction and runtime adapters.')
