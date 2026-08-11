import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tools.ci.check_format import check_format


ROOT = Path(__file__).resolve().parents[2]


class FormatCheckTests(unittest.TestCase):
    def make_repository(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        subprocess.run(
            ["git", "init", "--quiet"],
            cwd=root,
            check=True,
        )
        return root

    @staticmethod
    def commit(root: Path, message: str) -> str:
        subprocess.run(
            ["git", "add", "--all"],
            cwd=root,
            check=True,
        )
        subprocess.run(
            [
                "git",
                "-c",
                "user.name=Format Test",
                "-c",
                "user.email=format-test@example.invalid",
                "commit",
                "--quiet",
                "-m",
                message,
            ],
            cwd=root,
            check=True,
        )
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    @staticmethod
    def verification(
        files: frozenset[str],
        errors: tuple[str, ...] = (),
    ) -> SimpleNamespace:
        return SimpleNamespace(files=files, errors=errors)

    def test_verified_locked_trailing_whitespace_passes(self):
        root = self.make_repository()
        locked = Path("vendor/GMTL file.gml")
        (root / locked).parent.mkdir(parents=True)
        (root / locked).write_text("clean\n", encoding="utf-8")
        base = self.commit(root, "base")
        (root / locked).write_text("upstream whitespace \n", encoding="utf-8")
        head = self.commit(root, "locked whitespace")

        verification = self.verification(
            frozenset({locked.as_posix()})
        )

        with mock.patch(
            "tools.ci.check_format.verify_gmtl_lock",
            return_value=verification,
        ):
            result = check_format(root, {}, base, head)

        self.assertEqual(result, 0)

    def test_repository_owned_trailing_whitespace_fails(self):
        root = self.make_repository()
        locked = Path("vendor/GMTL file.gml")
        owned = Path("source/game.gml")
        (root / locked).parent.mkdir(parents=True)
        (root / owned).parent.mkdir(parents=True)
        (root / locked).write_text("clean\n", encoding="utf-8")
        (root / owned).write_text("clean\n", encoding="utf-8")
        base = self.commit(root, "base")
        (root / owned).write_text("owned whitespace \n", encoding="utf-8")
        head = self.commit(root, "owned whitespace")

        verification = self.verification(
            frozenset({locked.as_posix()})
        )
        output = io.StringIO()

        with (
            mock.patch(
                "tools.ci.check_format.verify_gmtl_lock",
                return_value=verification,
            ),
            contextlib.redirect_stdout(output),
        ):
            result = check_format(root, {}, base, head)

        self.assertNotEqual(result, 0)
        self.assertIn(owned.as_posix(), output.getvalue())

    def test_lock_error_fails_before_any_exemption(self):
        verification = self.verification(
            frozenset({"vendor/GMTL file.gml"}),
            ("hash mismatch",),
        )
        errors = io.StringIO()

        with (
            mock.patch(
                "tools.ci.check_format.verify_gmtl_lock",
                return_value=verification,
            ),
            mock.patch("tools.ci.check_format.run_diff_check") as diff,
            contextlib.redirect_stderr(errors),
        ):
            result = check_format(Path("."), {}, "base", "head")

        self.assertEqual(result, 1)
        diff.assert_not_called()
        self.assertIn("GMTL lock verification failed", errors.getvalue())

    def test_ci_uses_lock_aware_format_check_at_exact_endpoints(self):
        text = (ROOT / ".github/workflows/ci.yml").read_text(
            encoding="utf-8"
        )
        format_job = text.split("  format:", 1)[1]

        self.assertIn("actions/setup-python@v5", format_job)
        self.assertIn('python-version: "3.12"', format_job)
        self.assertIn(
            "python3 tools/ci/check_format.py \\",
            format_job,
        )
        self.assertIn('--base-ref "$BASE_SHA"', format_job)
        self.assertIn('--head-ref "$HEAD_SHA"', format_job)
        self.assertIn(
            "BASE_SHA: ${{ github.event.pull_request.base.sha }}",
            format_job,
        )
        self.assertIn(
            "HEAD_SHA: ${{ github.event.pull_request.head.sha }}",
            format_job,
        )
        self.assertIn(
            "ref: ${{ github.event.pull_request.head.sha }}",
            format_job,
        )
        self.assertIn("fetch-depth: 0", format_job)
        self.assertNotIn("git diff --check", format_job)


if __name__ == "__main__":
    unittest.main()
