"""Regression fixtures for the selected non-UI coverage gate."""

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "coverage_checker", Path(__file__).with_name("check-code-coverage.py")
)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def source_file(path, covered=10, executable=10):
    return {"path": path, "coveredLines": covered, "executableLines": executable}


class CoverageScopeTests(unittest.TestCase):
    def test_all_five_layers_count_while_views_tests_and_build_products_do_not(self):
        included = [source_file(f"/work/HomeStuffInventoryApp/{layer}/Owner.swift")
                    for layer in ("InventoryData", "InventoryLogic", "InventoryPresentation",
                                  "Persistence", "Monetization")]
        included.append(source_file("/work/HomeStuffInventoryApp/InventoryLogic/InventoryBrowseSummaryPreviews.swift"))
        included.append(source_file(r"C:\work\HomeStuffInventoryApp\Monetization\Windows.swift"))
        excluded = [source_file(path, 0, 10000) for path in (
            "/work/HomeStuffInventoryApp/Views/Screen.swift",
            "/work/HomeStuffInventoryApp/Views/PreviewSupport/Fixture.swift",
            "/work/HomeStuffInventoryAppTests/Test.swift",
            "/work/HomeStuffInventoryAppUITests/Test.swift",
            "/work/DerivedData/HomeStuffInventoryApp/Monetization/Generated.swift",
            "/work/Build/HomeStuffInventoryApp/Monetization/Generated.swift",
        )]
        excluded += [source_file("/work/" + path, 0, 10000)
                     for path in checker.EXCLUDED_DEBUG_SUPPORT_FILES]
        self.assertEqual(checker.selected_files(included + excluded), included)

    def test_only_the_two_explicit_debug_support_files_are_excluded(self):
        self.assertEqual(checker.EXCLUDED_DEBUG_SUPPORT_FILES, (
            "HomeStuffInventoryApp/InventoryData/InventorySampleData.swift",
            "HomeStuffInventoryApp/Persistence/InventorySampleDataSeeder.swift",
        ))
        self.assertEqual(checker.excluded_debug_support_issues(Path(__file__).resolve().parents[2]), [])

    def test_debug_support_boundary_rejects_shipping_code_and_release_branches(self):
        debug = "import Foundation\n#if DEBUG\nstruct Fixture {}\n#endif\n"
        self.assertTrue(checker.is_wholly_debug_support(debug))
        self.assertTrue(checker.is_wholly_debug_support(debug.replace("struct Fixture {}", "#if os(iOS)\nstruct Fixture {}\n#endif")))
        for source in ("struct Shipping {}\n" + debug, debug + "struct Shipping {}\n",
                       debug.replace("#endif", "#else\nstruct Shipping {}\n#endif"),
                       debug.replace("#endif", "#elseif RELEASE\nstruct Shipping {}\n#endif")):
            with self.subTest(source=source):
                self.assertFalse(checker.is_wholly_debug_support(source))

    def test_import_prelude_rejects_appended_shipping_statements(self):
        debug = "#if DEBUG\nstruct Fixture {}\n#endif\n"
        for prelude in ("import Foundation\n", "import Foundation.Date // module import\n"):
            self.assertTrue(checker.is_wholly_debug_support(prelude + debug))
        for prelude in ("import Foundation; struct Shipping {}\n",
                        "import Foundation\nimport SwiftData; struct Shipping {}\n"):
            with self.subTest(prelude=prelude):
                self.assertFalse(checker.is_wholly_debug_support(prelude + debug))

    def test_gate_fails_closed_when_an_excluded_file_loses_its_debug_boundary(self):
        with tempfile.TemporaryDirectory() as root:
            for relative in checker.EXCLUDED_DEBUG_SUPPORT_FILES:
                path = Path(root) / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("#if DEBUG\nstruct Fixture {}\n#endif\n")
            broken = checker.EXCLUDED_DEBUG_SUPPORT_FILES[0]
            (Path(root) / broken).write_text("import Foundation; struct Shipping {}\n#if DEBUG\nstruct Fixture {}\n#endif\n")
            self.assertEqual(checker.excluded_debug_support_issues(Path(root)), [broken])
            with patch.object(checker, "excluded_debug_support_issues", return_value=[broken]), \
                 patch("sys.argv", ["check-code-coverage.py", root, "--minimum", "90"]), \
                 patch.object(checker, "load_xccov_report") as report, \
                 contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(checker.main(), 2)
                report.assert_not_called()

    def test_uncovered_monetization_changes_the_unchanged_ninety_percent_gate(self):
        logic = source_file("HomeStuffInventoryApp/InventoryLogic/Owner.swift", 90, 100)
        monetization = source_file("HomeStuffInventoryApp/Monetization/Owner.swift", 0, 100)
        view = source_file("HomeStuffInventoryApp/Views/Screen.swift", 0, 10000)
        with tempfile.TemporaryDirectory() as result_bundle:
            for covered, expected_status, expected_total in ((0, 1, "90/200"), (100, 0, "190/200")):
                with self.subTest(monetization_covered_lines=covered):
                    monetization["coveredLines"] = covered
                    report = {"targets": [{"name": "HomeStuffInventoryApp.app",
                                           "files": [logic, monetization, view]}]}
                    output = io.StringIO()
                    with patch.object(checker, "load_xccov_report", return_value=report), \
                         patch("sys.argv", ["check-code-coverage.py", result_bundle, "--minimum", "90"]), \
                         contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                        self.assertEqual(checker.main(), expected_status)
                    self.assertIn(f"Covered lines: {expected_total}", output.getvalue())
                    self.assertIn("Minimum: 90.00%", output.getvalue())
                    self.assertIn("Monetization", output.getvalue())


if __name__ == "__main__":
    unittest.main()
