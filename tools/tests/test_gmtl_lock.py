import hashlib
import json
import tempfile
import tomllib
import unittest
from pathlib import Path

from tools.ci.gmtl_lock import verify_gmtl_lock


ROOT = Path(__file__).resolve().parents[2]


class GmtlLockTests(unittest.TestCase):
    LOCK_PATH = Path("project/gmtl.lock.json")
    RESOURCE_ROOT = Path("vendor/gmtl")
    METADATA_PATH = RESOURCE_ROOT / "GMTL_init.gml"
    DEMO_PATH = RESOURCE_ROOT / "GMTL_demo_tests.gml"

    def make_root(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / self.RESOURCE_ROOT).mkdir(parents=True)
        (root / self.METADATA_PATH).write_text(
            "GameMaker Testing Library\n"
            "Version: v1.2\n"
            "https://example.invalid/GMTL\n",
            encoding="utf-8",
        )
        (root / self.DEMO_PATH).write_text(
            "upstream demo\n",
            encoding="utf-8",
        )
        return root

    @staticmethod
    def entry(root: Path, path: Path) -> dict:
        data = (root / path).read_bytes()
        return {
            "path": path.as_posix(),
            "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data),
        }

    def lock(self, root: Path) -> dict:
        files = sorted(
            [
                self.entry(root, self.METADATA_PATH),
                self.entry(root, self.DEMO_PATH),
            ],
            key=lambda entry: entry["path"],
        )
        return {
            "schema_version": 1,
            "name": "GM-Testing-Library",
            "upstream": "https://example.invalid/GMTL",
            "version": "v1.2",
            "snapshot_commit": "1" * 40,
            "hash_algorithm": "sha256",
            "metadata_source": self.METADATA_PATH.as_posix(),
            "resource_root_count": 1,
            "resource_roots": [self.RESOURCE_ROOT.as_posix()],
            "file_count": len(files),
            "files": files,
        }

    def write_lock(self, root: Path, lock: dict) -> None:
        path = root / self.LOCK_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(lock, indent=2) + "\n",
            encoding="utf-8",
        )

    @staticmethod
    def policy() -> dict:
        return {
            "imports": {
                "gmtl": {
                    "lock": "project/gmtl.lock.json",
                }
            }
        }

    def verify(
        self,
        root: Path,
        lock: dict,
        repository_files: list[Path] | None = None,
    ):
        self.write_lock(root, lock)
        tracked = repository_files or [
            self.METADATA_PATH,
            self.DEMO_PATH,
        ]
        return verify_gmtl_lock(
            root,
            self.policy(),
            tracked,
        )

    def assert_lock_failure(self, result, text: str) -> None:
        self.assertFalse(result.files)
        self.assertTrue(result.errors)
        self.assertIn(
            text,
            "\n".join(result.errors),
        )

    def test_valid_snapshot_grants_exact_inventory(self):
        root = self.make_root()
        result = self.verify(root, self.lock(root))

        self.assertEqual(result.errors, ())
        self.assertEqual(
            result.files,
            frozenset(
                {
                    self.METADATA_PATH.as_posix(),
                    self.DEMO_PATH.as_posix(),
                }
            ),
        )

    def test_added_locked_file_fails_closed(self):
        root = self.make_root()
        added = self.RESOURCE_ROOT / "added.gml"
        (root / added).write_text("added\n", encoding="utf-8")
        result = self.verify(
            root,
            self.lock(root),
            [self.METADATA_PATH, self.DEMO_PATH, added],
        )

        self.assert_lock_failure(result, "unrecorded")

    def test_removed_locked_file_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        (root / self.DEMO_PATH).unlink()
        result = self.verify(root, lock, [self.METADATA_PATH])

        self.assert_lock_failure(result, "locked file is missing")

    def test_renamed_locked_file_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        renamed = self.RESOURCE_ROOT / "renamed.gml"
        (root / self.DEMO_PATH).rename(root / renamed)
        result = self.verify(
            root,
            lock,
            [self.METADATA_PATH, renamed],
        )

        errors = "\n".join(result.errors)
        self.assertFalse(result.files)
        self.assertIn("locked file is missing", errors)
        self.assertIn("unrecorded", errors)

    def test_modified_locked_file_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        (root / self.DEMO_PATH).write_text(
            "modified\n",
            encoding="utf-8",
        )
        result = self.verify(root, lock)

        self.assert_lock_failure(result, "integrity mismatch")

    def test_wrong_version_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        lock["version"] = "v9.9"
        result = self.verify(root, lock)

        self.assert_lock_failure(
            result,
            "version does not match metadata_source",
        )

    def test_wrong_upstream_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        lock["upstream"] = "https://wrong.invalid/GMTL"
        result = self.verify(root, lock)

        self.assert_lock_failure(
            result,
            "upstream does not match metadata_source",
        )

    def test_wrong_hash_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        lock["files"][0]["sha256"] = "0" * 64
        result = self.verify(root, lock)

        self.assert_lock_failure(result, "integrity mismatch")

    def test_wrong_inventory_count_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        lock["file_count"] = 47
        result = self.verify(root, lock)

        self.assert_lock_failure(result, "file_count must match files")

    def test_canonical_lfs_pointer_verifies_logical_content(self):
        root = self.make_root()
        payload = b"logical LFS payload"
        digest = hashlib.sha256(payload).hexdigest()
        pointer = (
            "version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{digest}\n"
            f"size {len(payload)}\n"
        ).encode("ascii")
        (root / self.DEMO_PATH).write_bytes(pointer)
        lock = self.lock(root)
        demo_entry = next(
            entry
            for entry in lock["files"]
            if entry["path"] == self.DEMO_PATH.as_posix()
        )
        demo_entry["sha256"] = digest
        demo_entry["size"] = len(payload)
        result = self.verify(root, lock)

        self.assertEqual(result.errors, ())
        self.assertIn(self.DEMO_PATH.as_posix(), result.files)

    def test_malformed_lfs_pointer_fails_closed(self):
        root = self.make_root()
        lock = self.lock(root)
        (root / self.DEMO_PATH).write_text(
            "version https://git-lfs.github.com/spec/v1\n"
            "oid sha256:not-a-hash\n",
            encoding="ascii",
        )
        result = self.verify(root, lock)

        self.assert_lock_failure(result, "malformed Git LFS pointer")

    def test_repository_lock_is_exact_and_verified(self):
        policy = tomllib.loads(
            (ROOT / "PROJECT_POLICY.toml").read_text(encoding="utf-8")
        )
        lock = json.loads(
            (ROOT / "project/gmtl.lock.json").read_text(encoding="utf-8")
        )
        result = verify_gmtl_lock(ROOT, policy)

        self.assertEqual(lock["resource_root_count"], 20)
        self.assertEqual(lock["file_count"], 47)
        self.assertEqual(result.errors, ())
        self.assertEqual(len(result.files), 47)


if __name__ == "__main__":
    unittest.main()
