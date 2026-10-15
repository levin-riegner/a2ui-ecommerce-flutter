"""Enforce the reference repo's import boundaries without a Flutter runtime."""
from collections import deque
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
_DIRECTIVE = re.compile(r"^\s*(?:import|export|part(?!\s+of))\s+([^;]+);", re.MULTILINE)
_URI = re.compile(r"['\"]([^'\"]+)['\"]")
_COMMENT_OR_STRING = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/")
DOMAIN_FILES = (
    'data/models.dart', 'data/money.dart', 'data/catalog_products.dart',
    'data/catalog_semantics.dart', 'data/catalog_snapshot.dart',
    'data/stylist_store.dart', 'agent/stylist_brief.dart',
    'agent/stylist_constraints.dart', 'agent/outfit_plan.dart',
    'agent/stylist_input_error.dart', 'agent/product_facts.dart',
    'agent/stylist_command.dart', 'agent/stylist_result.dart',
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


def ui_reject(uri, relative):
    if uri.startswith(('package:genui/', 'package:a2ui_core/', 'package:genkit', 'package:schemantic/', 'package:json_schema_builder/')):
        return 'presentation must not depend on agent/renderer SDKs'
    if relative and (relative.startswith('lib/src/agent/') or relative.endswith(('_a2ui.dart', '_gallery.dart', '_examples.dart')) or relative == 'lib/src/catalog/catalog_export.dart'):
        return 'presentation must not include runtime, registrations or opt-in galleries'
    return None



def registration_reject(uri, relative):
    if uri.startswith(('package:genkit', 'package:shared_preferences/')):
        return 'A2UI registrations must not configure providers or storage'
    if relative and (relative.startswith('lib/src/agent/') or relative.endswith(('_gallery.dart', '_examples.dart'))):
        return 'A2UI registrations must not pull runtime or opt-in gallery code'
    return None


def domain_reject(uri, relative):
    if uri.startswith(('package:flutter/', 'package:genui/', 'package:a2ui_core/', 'package:genkit', 'package:shared_preferences/')):
        return 'domain contracts must not depend on Flutter, providers, renderers or platform storage'
    if relative and (relative.startswith(('lib/src/catalog/', 'lib/src/layout/', 'lib/src/input/')) or relative.endswith(('stylist_surfaces.dart', 'stylist_brief_surface.dart', 'stylist_presenter.dart', 'local_stylist_store.dart', 'app_dependencies.dart', 'genkit_providers.dart'))):
        return 'domain contracts must depend on values and ports, not adapters'
    return None


def check(root=ROOT):
    root = root.resolve()
    errors = inspect_graph(root, 'lib/commerce_ui.dart', 'commerce_ui', ui_reject)
    errors.extend(inspect_graph(root, 'lib/commerce_a2ui.dart', 'commerce_a2ui', registration_reject))
    for name in DOMAIN_FILES:
        errors.extend(inspect_graph(root, 'lib/src/' + name, name, domain_reject))
    runtime = root / 'lib/src/agent/stylist_runtime.dart'
    if runtime.is_file():
        for uri in imports(runtime):
            relative = local_path(root, runtime, uri)
            relative = relative.relative_to(root).as_posix() if relative else None
            if domain_reject(uri, relative) and not uri.startswith('package:genkit/'):
                errors.append(f'stylist_runtime.dart -> {uri}: orchestration must keep presentation/platform adapters outside the runtime')
    return sorted(set(errors))


if __name__ == '__main__':
    problems = check()
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        raise SystemExit(1)
    print('Architecture boundaries passed: transitive presentation/registration/domain imports and runtime adapters.')
