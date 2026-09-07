"""Provide the minimal verified imported snapshot for checker integration tests."""

import hashlib
import json
from pathlib import Path


def write_gmtl_fixture(root: Path) -> None:
    """Satisfy Blade's mandatory lock without bypassing any production checks."""
    resource = Path("vendor/gmtl")
    metadata = resource / "GMTL_init.gml"
    payload = (
        b"GameMaker Testing Library\n"
        b"Version: v1.2\n"
        b"https://example.invalid/GMTL\n"
    )
    (root / resource).mkdir(parents=True, exist_ok=True)
    (root / metadata).write_bytes(payload)
    lock = {
        "schema_version": 1,
        "name": "GM-Testing-Library",
        "upstream": "https://example.invalid/GMTL",
        "version": "v1.2",
        "snapshot_commit": "1" * 40,
        "hash_algorithm": "sha256",
        "metadata_source": metadata.as_posix(),
        "resource_root_count": 1,
        "resource_roots": [resource.as_posix()],
        "file_count": 1,
        "files": [{
            "path": metadata.as_posix(),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "size": len(payload),
        }],
    }
    (root / "project").mkdir(exist_ok=True)
    (root / "project/gmtl.lock.json").write_text(
        json.dumps(lock, indent=2) + "\n", encoding="utf-8"
    )
