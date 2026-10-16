"""Prove forbidden imports fail across canonical and transitive boundaries."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_architecture import (
    check, inspect_graph, ui_reject, domain_reject,
    registration_reject, data_reject, runtime_reject,
)


class ArchitectureBoundaryTest(unittest.TestCase):
    def graph(self, files, entry, reject):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            self.write(root, files)
            return inspect_graph(root, entry, 'fixture', reject)

    def write(self, root, files):
        for name, source in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(source)

    def test_transitive_export_cannot_smuggle_renderer_into_widgets(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "export 'presentation/shared/helper.dart';",
            'lib/presentation/shared/helper.dart': "import 'package:genui/genui.dart';",
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('helper.dart -> package:genui/', errors[0])

    def test_public_widgets_reject_bloc_through_helper(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "export 'presentation/shared/helper.dart';",
            'lib/presentation/shared/helper.dart': "import 'package:flutter_bloc/flutter_bloc.dart';",
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('BLoC', errors[0])

    def test_public_widgets_reject_state_controller_by_canonical_path(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "export 'presentation/stylist/bloc/commerce_session.dart';",
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('state controllers', errors[0])

    def test_conditional_import_alternative_is_checked(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "import 'safe.dart' if (dart.library.io) 'package:genkit/genkit.dart';",
            'lib/safe.dart': '',
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)

    def test_same_line_directives_cannot_hide_forbidden_import(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "import 'safe.dart'; export 'package:flutter_bloc/flutter_bloc.dart';",
            'lib/safe.dart': '',
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('BLoC', errors[0])

    def test_domain_values_and_comments_are_allowed(self):
        self.assertEqual(self.graph({
            'lib/data/catalog/model/model.dart': "// import 'package:flutter/material.dart';\n/*\nimport 'package:genui/genui.dart';\n*/\nimport 'dart:collection';",
        }, 'lib/data/catalog/model/model.dart', domain_reject), [])

    def test_domain_shared_declarative_validation_is_allowed(self):
        self.assertEqual(self.graph({
            'lib/data/stylist/model/command.dart': "import 'schemas.dart';",
            'lib/data/stylist/model/schemas.dart': "import 'package:schemantic/schemantic.dart';",
        }, 'lib/data/stylist/model/command.dart', domain_reject), [])

    def test_domain_cannot_import_platform_storage_via_model_helper(self):
        errors = self.graph({
            'lib/data/catalog/model/model.dart': "import 'helper.dart';",
            'lib/data/catalog/model/helper.dart': "import 'package:shared_preferences/shared_preferences.dart';",
        }, 'lib/data/catalog/model/model.dart', domain_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('helper.dart -> package:shared_preferences/', errors[0])

    def test_domain_cannot_import_runtime_adapter(self):
        errors = self.graph({
            'lib/data/stylist/model/model.dart': "import '../service/runtime/stylist_runtime.dart';",
        }, 'lib/data/stylist/model/model.dart', domain_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('not adapters', errors[0])

    def test_domain_cannot_import_transport_sdk(self):
        errors = self.graph({
            'lib/data/weather/model/model.dart': "import 'package:http/http.dart';",
        }, 'lib/data/weather/model/model.dart', domain_reject)
        self.assertEqual(len(errors), 1)

    def test_registration_entrypoint_cannot_pull_opt_in_gallery(self):
        errors = self.graph({
            'lib/commerce_a2ui.dart': "export 'presentation/gallery/finalized_screen_examples.dart';",
        }, 'lib/commerce_a2ui.dart', registration_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('opt-in gallery code', errors[0])

    def test_registration_cannot_pull_provider_through_catalog_helper(self):
        errors = self.graph({
            'lib/commerce_a2ui.dart': "export 'presentation/stylist/a2ui/catalog/helper.dart';",
            'lib/presentation/stylist/a2ui/catalog/helper.dart': "import 'package:genkit/genkit.dart';",
        }, 'lib/commerce_a2ui.dart', registration_reject)
        self.assertEqual(len(errors), 1)

    def test_repository_cannot_smuggle_presentation_through_data_helper(self):
        errors = self.graph({
            'lib/data/weather/repository/weather_repository.dart': "import '../service/helper.dart';",
            'lib/data/weather/service/helper.dart': "import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/stylist_state.dart';",
        }, 'lib/data/weather/repository/weather_repository.dart', data_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('data must not import presentation', errors[0])

    def test_data_cannot_import_composition(self):
        errors = self.graph({
            'lib/data/catalog/repository/repository.dart': "import 'package:a2ui_flutter_commerce/util/dependencies.dart';",
        }, 'lib/data/catalog/repository/repository.dart', data_reject)
        self.assertEqual(len(errors), 1)

    def test_data_service_may_use_http_and_domain_model(self):
        self.assertEqual(self.graph({
            'lib/data/weather/service/service.dart': "import 'package:http/http.dart'; import '../model/model.dart';",
            'lib/data/weather/model/model.dart': '',
        }, 'lib/data/weather/service/service.dart', data_reject), [])

    def test_runtime_allows_genkit_and_pure_ports_but_not_concrete_service(self):
        runtime = 'lib/data/stylist/service/runtime/stylist_runtime.dart'
        allowed = {
            runtime: "import 'package:genkit/genkit.dart';\nimport '../../repository/stylist_store.dart';",
            'lib/data/stylist/repository/stylist_store.dart': '',
        }
        self.assertEqual(self.graph(allowed, runtime, runtime_reject), [])
        denied = {
            runtime: "import 'package:a2ui_flutter_commerce/data/weather/service/remote/open_meteo_weather_service.dart';",
        }
        errors = self.graph(denied, runtime, runtime_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('not concrete adapters', errors[0])

    def test_new_domain_files_are_discovered_without_manual_allowlist(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            self.write(root, {
                'lib/commerce_ui.dart': '',
                'lib/commerce_a2ui.dart': '',
                'lib/data/stylist/repository/stylist_store.dart': '',
                'lib/data/catalog/repository/catalog_search.dart': '',
                'lib/data/stylist/service/runtime/stylist_runtime.dart': '',
                'lib/data/new_feature/model/unlisted.dart': "import 'package:flutter/material.dart';",
            })
            errors = check(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('unlisted.dart -> package:flutter/', errors[0])

    def test_missing_local_dependency_fails(self):
        errors = self.graph({'lib/commerce_ui.dart': "export 'missing.dart';"}, 'lib/commerce_ui.dart', ui_reject)
        self.assertIn('missing local dependency', errors[0])


if __name__ == '__main__':
    unittest.main()
