import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

from tools.content.validate_gamemaker_content_bundle import main, validate_repository


ROOT = Path(__file__).resolve().parents[2]
PROJECT_DIRECTORY = Path("project/~ blade of desires ~")
PROJECT_FILENAME = "~ blade of desires ~.yyp"


class TemporaryContentBundleTests(unittest.TestCase):
    """Exercise content packaging failures in isolated repository fixtures."""

    def setUp(self):
        """Create one canonical stage source, link, and GameMaker entry."""
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.content = self.root / "content"
        self.stage_source = self.content / "stages/neutral_v1.json"
        self.stage_source.parent.mkdir(parents=True)
        self.stage_source.write_text("{}\n", encoding="utf-8")
        self.project = self.root / PROJECT_DIRECTORY
        self.datafiles = self.project / "datafiles"
        self.datafiles.mkdir(parents=True)
        self.link = self.datafiles / "content"
        self.link.symlink_to("../../../content", target_is_directory=True)
        self.yyp = self.project / PROJECT_FILENAME
        self.valid_entry = {
            "$GMIncludedFile": "",
            "%Name": self.stage_source.name,
            "CopyToMask": -1,
            "filePath": "datafiles/content/stages",
            "name": self.stage_source.name,
            "resourceType": "GMIncludedFile",
            "resourceVersion": "2.0",
        }
        self.write_yyp([self.valid_entry])

    def tearDown(self):
        """Release the temporary repository fixture."""
        self.temporary.cleanup()

    def write_yyp(self, entries):
        """Write a minimal GameMaker project using its normal trailing commas."""
        lines = ["{", '  "IncludedFiles":[']
        lines.extend(
            f"    {json.dumps(entry, separators=(',', ':'))}," for entry in entries
        )
        lines.extend(['  ],', '  "name":"fixture",', "}"])
        self.yyp.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def errors(self):
        """Return validation errors for the current temporary fixture."""
        return validate_repository(self.root)

    def assert_has(self, field, reason):
        """Assert that one deterministic diagnostic contains both fragments."""
        self.assertTrue(
            any(field in error and reason in error for error in self.errors()),
            self.errors(),
        )

    def test_valid_bundle_and_trailing_comma_yyp_are_accepted(self):
        """The canonical link and one exact stage entry validate silently."""
        self.assertEqual(self.errors(), [])

    def test_missing_content_link_is_rejected(self):
        """The project may not omit its canonical content link."""
        self.link.unlink()
        self.assert_has("symlink", "is required")

    def test_broken_content_link_is_rejected(self):
        """A present but broken directory link does not package content."""
        self.link.unlink()
        self.link.symlink_to("../../../missing-content", target_is_directory=True)
        self.assert_has("symlink", "must resolve to the repository content directory")

    def test_wrong_content_link_target_is_rejected(self):
        """A link to a second content tree cannot replace canonical content."""
        alternate = self.root / "alternate-content/stages"
        alternate.mkdir(parents=True)
        (alternate / self.stage_source.name).write_text("{}\n", encoding="utf-8")
        self.link.unlink()
        self.link.symlink_to("../../../alternate-content", target_is_directory=True)
        self.assert_has("symlink", "must resolve exactly")

    def test_duplicate_stage_entry_is_rejected(self):
        """Each canonical stage source must have exactly one IncludedFile entry."""
        self.write_yyp([self.valid_entry, self.valid_entry])
        self.assert_has("IncludedFiles[1]", "duplicates IncludedFiles[0]")
        self.assert_has("neutral_v1.json", "found 2")

    def test_missing_stage_entry_is_rejected(self):
        """An unrepresented canonical stage source fails closed."""
        self.write_yyp([])
        self.assert_has("neutral_v1.json", "found 0")

    def test_name_and_path_traversal_are_rejected(self):
        """Neither IncludedFile field may escape its conventional directory."""
        mutations = [
            ("name", "../neutral_v1.json", "basename without traversal"),
            ("filePath", "datafiles/content/../stages", "contain .."),
        ]
        for field, value, reason in mutations:
            with self.subTest(field=field):
                entry = dict(self.valid_entry)
                entry[field] = value
                self.write_yyp([entry])
                self.assert_has(f"IncludedFiles[0].{field}", reason)

    def test_wrong_copy_mask_is_rejected(self):
        """Canonical content must be included on every target."""
        entry = dict(self.valid_entry)
        entry["CopyToMask"] = 0
        self.write_yyp([entry])
        self.assert_has("IncludedFiles[0].CopyToMask", "must be integer -1")

    def test_wrong_content_subdirectory_is_rejected(self):
        """The YYP directory must match the canonical source subdirectory."""
        entry = dict(self.valid_entry)
        entry["filePath"] = "datafiles/content/patterns"
        self.write_yyp([entry])
        self.assert_has("IncludedFiles[0]", "lists missing canonical source")
        self.assert_has("neutral_v1.json", "found 0")

    def test_unlisted_yyp_source_is_rejected(self):
        """An IncludedFile cannot invent a source absent from repository content."""
        entry = dict(self.valid_entry)
        entry["name"] = "ghost.json"
        entry["%Name"] = "ghost.json"
        self.write_yyp([self.valid_entry, entry])
        self.assert_has("IncludedFiles[1]", "lists missing canonical source")

    def test_json_path_outside_canonical_content_is_rejected(self):
        """JSON IncludedFiles cannot use a legacy copied-data directory."""
        entry = dict(self.valid_entry)
        entry["filePath"] = "datafiles/stages"
        self.write_yyp([entry])
        self.assert_has("IncludedFiles[0].filePath", "must be under datafiles/content")

    def test_regular_json_copy_below_datafiles_is_rejected(self):
        """A physical JSON copy cannot coexist with the canonical content link."""
        copied = self.datafiles / "cache/copied.json"
        copied.parent.mkdir()
        copied.write_text("{}\n", encoding="utf-8")
        self.assert_has(str(copied), "regular JSON copies are forbidden")

    def test_malformed_included_files_shape_is_rejected(self):
        """IncludedFiles must remain the expected project array."""
        self.yyp.write_text('{"IncludedFiles":{},}\n', encoding="utf-8")
        self.assert_has("IncludedFiles", "must be an array")

    def test_malformed_yyp_is_rejected(self):
        """Syntax errors outside IncludedFiles also invalidate the project file."""
        self.yyp.write_text('{"IncludedFiles":[], "broken": ]}\n', encoding="utf-8")
        self.assert_has("YYP", "is malformed")

    def test_duplicate_yyp_member_is_rejected(self):
        """Duplicate YYP keys cannot hide an alternate IncludedFiles array."""
        self.yyp.write_text(
            '{"IncludedFiles":[],"IncludedFiles":[],}\n', encoding="utf-8"
        )
        self.assert_has("YYP", "duplicate object key")

    def test_cli_is_silent_on_success_and_nonzero_on_failure(self):
        """The command emits nothing on success and diagnostics on failure."""
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            success = main([str(self.root)])
        self.assertEqual(success, 0)
        self.assertEqual(stdout.getvalue(), "")
        self.assertEqual(stderr.getvalue(), "")

        self.link.unlink()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            failure = main([str(self.root)])
        self.assertEqual(failure, 1)
        self.assertIn("symlink", stderr.getvalue())


class RepositoryContentBundleTests(unittest.TestCase):
    """Pin the checked-in repository's canonical GameMaker content bundle."""

    def test_repository_content_bundle_is_valid(self):
        """The live project links and lists every canonical stage source exactly once."""
        self.assertEqual(validate_repository(ROOT), [])


if __name__ == "__main__":
    unittest.main()
