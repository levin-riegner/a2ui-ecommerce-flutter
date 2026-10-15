"""Exercise forbidden imports, including transitive and export regressions."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_architecture import inspect_graph, ui_reject, domain_reject, registration_reject


class ArchitectureBoundaryTest(unittest.TestCase):
    def graph(self, files, entry, reject):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for name, source in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source)
            return inspect_graph(root, entry, 'fixture', reject)

    def test_transitive_export_cannot_smuggle_renderer_into_widgets(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "export 'safe.dart';",
            'lib/safe.dart': "import 'package:genui/genui.dart';",
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('lib/safe.dart -> package:genui/', errors[0])

    def test_conditional_import_alternative_is_checked(self):
        errors = self.graph({
            'lib/commerce_ui.dart': "import 'safe.dart' if (dart.library.io) 'package:genkit/genkit.dart';",
            'lib/safe.dart': '',
        }, 'lib/commerce_ui.dart', ui_reject)
        self.assertEqual(len(errors), 1)

    def test_pure_values_and_comments_are_allowed(self):
        self.assertEqual(self.graph({
            'lib/model.dart': "// import 'package:flutter/material.dart';\n/*\nimport 'package:genui/genui.dart';\n*/\nimport 'dart:collection';",
        }, 'lib/model.dart', domain_reject), [])

    def test_domain_cannot_import_platform_storage_via_another_file(self):
        errors = self.graph({
            'lib/model.dart': "import 'adapter.dart';",
            'lib/adapter.dart': "import 'package:shared_preferences/shared_preferences.dart';",
        }, 'lib/model.dart', domain_reject)
        self.assertEqual(len(errors), 1)

    def test_registration_entrypoint_cannot_pull_opt_in_gallery(self):
        errors = self.graph({
            'lib/commerce_a2ui.dart': "export 'src/catalog/finalized_screen_examples.dart';",
        }, 'lib/commerce_a2ui.dart', registration_reject)
        self.assertEqual(len(errors), 1)
        self.assertIn('opt-in gallery code', errors[0])

    def test_missing_local_dependency_fails(self):
        errors = self.graph({'lib/commerce_ui.dart': "export 'missing.dart';"}, 'lib/commerce_ui.dart', ui_reject)
        self.assertIn('missing local dependency', errors[0])


if __name__ == '__main__':
    unittest.main()
