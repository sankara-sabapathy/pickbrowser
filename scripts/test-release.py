#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("release_version", pathlib.Path(__file__).with_name("release-version.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVersionTests(unittest.TestCase):
    def test_first_release(self):
        self.assertEqual(module.next_version("0.2.0", [], []), "0.2.0")

    def test_patch(self):
        self.assertEqual(module.next_version("0.2.0", ["v0.2.9", "v0.2.10"], []), "0.2.11")

    def test_minor_bump(self):
        self.assertEqual(module.next_version("0.3.0", ["v0.2.10"], []), "0.3.0")

    def test_retry(self):
        self.assertEqual(module.next_version("0.2.0", ["v0.2.0", "v0.2.1"], ["v0.2.0"]), "0.2.0")

    def test_ignores_nonstable_tags(self):
        self.assertEqual(module.next_version("0.2.0", ["v9.0.0-beta.1", "test", "v1.02.0"], []), "0.2.0")


if __name__ == "__main__":
    unittest.main()
