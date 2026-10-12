import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    'build_web_demo', Path(__file__).with_name('build_web_demo.py'))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class BundleAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ('index.html', 'main.dart.js', 'flutter_bootstrap.js'):
            (self.root / name).write_text('public fixture')
        for name in build.LEGAL_FILES.values():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('license fixture')

    def test_public_bundle_has_content_hashes(self):
        files = build.audit_bundle(self.root)
        self.assertEqual(len(files), 7)
        self.assertEqual(len(files['main.dart.js']), 64)

    def test_credential_error_never_echoes_matching_content(self):
        credential = 'sk-proj-' + 'x' * 40
        (self.root / 'main.dart.js').write_text(credential)
        with self.assertRaises(ValueError) as caught:
            build.audit_bundle(self.root)
        self.assertNotIn(credential, str(caught.exception))
        self.assertIn('main.dart.js', str(caught.exception))

    def test_private_and_debug_files_are_rejected(self):
        for name in ('.env.local', 'main.dart.js.map', 'private-session.json'):
            path = self.root / name
            path.write_text('fixture')
            with self.assertRaises(ValueError):
                build.audit_bundle(self.root)
            path.unlink()

    def test_link_cannot_escape_release_directory(self):
        (self.root / 'linked').symlink_to('/tmp')
        with self.assertRaises(ValueError):
            build.audit_bundle(self.root)

    def test_missing_app_is_rejected(self):
        (self.root / 'main.dart.js').unlink()
        with self.assertRaises(ValueError):
            build.audit_bundle(self.root)

    def test_missing_notices_are_rejected(self):
        (self.root / 'NOTICE.txt').unlink()
        with self.assertRaises(ValueError):
            build.audit_bundle(self.root)


if __name__ == '__main__':
    unittest.main()
