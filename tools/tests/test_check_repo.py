import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.ci.check_repo import (
    new_policy_errors,
    validate_assets,
    validate_structure,
)

ROOT = Path(__file__).resolve().parents[2]


class RepositoryPolicyTests(unittest.TestCase):
    @staticmethod
    def structure_policy() -> dict:
        return {
            "structure": {
                "max_source_lines": 800,
                "source_extensions": [".gml"],
                "forbidden_generic_stems": ["helpers"],
            }
        }

    @staticmethod
    def asset_policy() -> dict:
        return {
            "assets": {
                "source_root": "assets/source",
                "runtime_root": "assets/runtime",
                "manifest": "assets/exports.json",
                "plain_runtime_svg": True,
                "pipelines": {
                    "raster": {
                        "source_extensions": [".kra"],
                        "runtime_extensions": [".png"],
                    },
                },
            }
        }

    def validate_fixture_manifest(self, entry: dict) -> list[str]:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = Path("assets/source/test.kra")
            runtime = Path("assets/runtime/test.png")
            (root / source).parent.mkdir(parents=True)
            (root / runtime).parent.mkdir(parents=True)
            (root / source).write_bytes(b"source")
            (root / runtime).write_bytes(b"runtime")
            (root / "assets/exports.json").write_text(
                json.dumps({"version": 1, "exports": [entry]}),
                encoding="utf-8",
            )
            errors: list[str] = []
            validate_assets(
                root,
                self.asset_policy(),
                [Path("assets/exports.json"), source, runtime],
                errors,
            )
            return errors

    def test_inherited_errors_do_not_block(self):
        inherited = "source/legacy.gml: 900 lines exceeds limit 800"

        self.assertEqual(
            new_policy_errors([inherited], [inherited]),
            [],
        )

    def test_new_errors_still_block(self):
        inherited = "source/legacy.gml: 900 lines exceeds limit 800"
        introduced = "content/new.json: invalid JSON"

        self.assertEqual(
            new_policy_errors(
                [inherited, introduced],
                [inherited],
            ),
            [introduced],
        )

    def test_an_additional_duplicate_error_still_blocks(self):
        repeated = "assets/runtime/shared.png: runtime export mapped more than once"

        self.assertEqual(
            new_policy_errors([repeated, repeated], [repeated]),
            [repeated],
        )

    def test_unstable_diagnostic_details_remain_inherited(self):
        examples = (
            (
                "source/legacy.gml: 950 lines exceeds limit 800",
                "source/legacy.gml: 900 lines exceeds limit 800",
            ),
            (
                "content/legacy.json: invalid JSON: line 4 column 2",
                "content/legacy.json: invalid JSON: line 3 column 9",
            ),
            (
                "assets/exports.json: export 1 has unknown kind legacy",
                "assets/exports.json: export 0 has unknown kind legacy",
            ),
        )

        for current, baseline in examples:
            with self.subTest(current=current):
                self.assertEqual(
                    new_policy_errors([current], [baseline]),
                    [],
                )

    def test_changed_violating_file_must_not_worsen(self):
        baseline = "source/legacy.gml: 801 lines exceeds limit 800"
        current = "source/legacy.gml: 5000 lines exceeds limit 800"

        self.assertEqual(
            new_policy_errors(
                [current],
                [baseline],
                {"source/legacy.gml"},
            ),
            [current],
        )

    def test_asset_validation_reads_the_selected_root(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "assets/exports.json"
            manifest.parent.mkdir(parents=True)
            manifest.write_text(
                json.dumps({"version": 2, "exports": []}),
                encoding="utf-8",
            )
            errors: list[str] = []

            validate_assets(
                root,
                self.asset_policy(),
                [Path("assets/exports.json")],
                errors,
            )

        self.assertEqual(len(errors), 1)
        self.assertTrue(errors[0].startswith("assets/exports.json:"))

    def test_asset_manifest_marks_every_registered_path(self):
        manifest = json.loads(
            (ROOT / "assets/exports.json").read_text(encoding="utf-8")
        )
        marked_paths = {
            path
            for entry in manifest["exports"]
            if entry.get("completion") == "authored-placeholder"
            for field in ("sources", "runtime")
            for path in entry[field]
        }
        registered_paths = {
            path
            for entry in manifest["exports"]
            for field in ("sources", "runtime")
            for path in entry[field]
        }

        self.assertTrue(manifest["exports"])
        self.assertEqual(marked_paths, registered_paths)

    def test_asset_validation_accepts_each_governance_completion_level(self):
        entry = {
            "kind": "raster",
            "sources": ["assets/source/test.kra"],
            "runtime": ["assets/runtime/test.png"],
        }

        for completion in (
            "deterministic-placeholder",
            "authored-placeholder",
            "final",
        ):
            with self.subTest(completion=completion):
                candidate = {**entry, "completion": completion}
                self.assertEqual(self.validate_fixture_manifest(candidate), [])

    def test_asset_validation_rejects_missing_or_unknown_completion_level(self):
        entry = {
            "kind": "raster",
            "sources": ["assets/source/test.kra"],
            "runtime": ["assets/runtime/test.png"],
        }

        for completion in (None, "unreviewed"):
            with self.subTest(completion=completion):
                candidate = {
                    **entry,
                    **({} if completion is None else {"completion": completion}),
                }
                errors = self.validate_fixture_manifest(candidate)
                self.assertEqual(len(errors), 1)
                self.assertIn("invalid completion level", errors[0])

    def test_missing_manifest_error_is_root_independent(self):
        results: list[list[str]] = []

        for _ in range(2):
            with tempfile.TemporaryDirectory() as temporary:
                errors: list[str] = []
                validate_assets(
                    Path(temporary),
                    self.asset_policy(),
                    [],
                    errors,
                )
                results.append(errors)

        self.assertEqual(results[0], results[1])
        self.assertEqual(len(results[0]), 1)
        self.assertTrue(results[0][0].startswith("assets/exports.json:"))

    def test_verified_locked_839_line_gml_passes_line_limit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = Path("vendor/GMTL_demo_tests.gml")
            (root / path).parent.mkdir(parents=True)
            (root / path).write_text(
                "upstream line\n" * 839,
                encoding="utf-8",
            )
            errors: list[str] = []

            validate_structure(
                root,
                self.structure_policy(),
                [path],
                errors,
                frozenset({path.as_posix()}),
            )

        self.assertEqual(errors, [])

    def test_repository_owned_over_limit_gml_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = Path("source/game.gml")
            (root / path).parent.mkdir(parents=True)
            (root / path).write_text(
                "owned line\n" * 801,
                encoding="utf-8",
            )
            errors: list[str] = []

            validate_structure(
                root,
                self.structure_policy(),
                [path],
                errors,
            )

        self.assertEqual(
            errors,
            [f"{path}: 801 lines exceeds limit 800"],
        )

    def test_locked_file_still_receives_other_structure_checks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = Path("vendor/helpers.gml")
            (root / path).parent.mkdir(parents=True)
            (root / path).write_text(
                "upstream line\n" * 839,
                encoding="utf-8",
            )
            errors: list[str] = []

            validate_structure(
                root,
                self.structure_policy(),
                [path],
                errors,
                frozenset({path.as_posix()}),
            )

        self.assertEqual(
            errors,
            [f"{path}: generic source filename is forbidden"],
        )

    def test_invalid_baseline_ref_fails_closed(self):
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools/ci/check_repo.py"),
                "--baseline-ref",
                "definitely-not-a-real-ref",
            ],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(result.stderr)

    def test_ci_compares_repository_policy_to_exact_base(self):
        text = (ROOT / ".github/workflows/ci.yml").read_text(
            encoding="utf-8"
        )
        match = re.search(
            r"(?ms)^  repository-policy:\n(.*?)(?=^  tests:|\Z)",
            text,
        )
        self.assertIsNotNone(match)
        repository_job = match.group(1)

        self.assertIn(
            "--baseline-ref \"$BASE_SHA\"",
            repository_job,
        )
        self.assertIn(
            "BASE_SHA: ${{ github.event.pull_request.base.sha }}",
            repository_job,
        )
        self.assertIn("fetch-depth: 0", repository_job)
        self.assertNotIn("ref:", repository_job)


if __name__ == "__main__":
    unittest.main()
