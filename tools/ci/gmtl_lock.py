#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable


LOCK_KEYS = {
    "schema_version",
    "name",
    "upstream",
    "version",
    "snapshot_commit",
    "hash_algorithm",
    "metadata_source",
    "resource_root_count",
    "resource_roots",
    "file_count",
    "files",
}
FILE_KEYS = {
    "path",
    "sha256",
    "size",
}
LFS_POINTER = re.compile(
    rb"version https://git-lfs\.github\.com/spec/v1\n"
    rb"oid sha256:([0-9a-f]{64})\n"
    rb"size ([0-9]+)\n"
)
SHA256 = re.compile(r"[0-9a-f]{64}")
COMMIT_SHA = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(
    r"v[0-9]+(?:\.[0-9]+){1,2}(?:[-+][0-9A-Za-z.-]+)?"
)


class DuplicateKeyError(ValueError):
    pass


@dataclass(frozen=True)
class GmtlLockVerification:
    files: frozenset[str]
    errors: tuple[str, ...]


def _reject_duplicate_keys(
    pairs: list[tuple[str, object]],
) -> dict[str, object]:
    result: dict[str, object] = {}

    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(
                f"duplicate JSON key {key!r}"
            )
        result[key] = value

    return result


def _safe_relative_path(value: object) -> str | None:
    if not isinstance(value, str) or not value:
        return None

    if (
        "\\" in value
        or any(ord(character) < 32 for character in value)
    ):
        return None

    path = PurePosixPath(value)

    if (
        path.is_absolute()
        or path.as_posix() != value
        or any(part in {".", ".."} for part in path.parts)
    ):
        return None

    return value


def _tracked_files(root: Path) -> tuple[list[Path], str | None]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=root,
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        return [], f"could not read tracked files: {exc}"

    return (
        [
            Path(value.decode("utf-8"))
            for value in result.stdout.split(b"\0")
            if value
        ],
        None,
    )


def _logical_hash(data: bytes) -> tuple[str, int, str | None]:
    pointer = LFS_POINTER.fullmatch(data)

    if pointer:
        return (
            pointer.group(1).decode("ascii"),
            int(pointer.group(2)),
            None,
        )

    if data.startswith(
        b"version https://git-lfs.github.com/spec/v1"
    ):
        return "", 0, "malformed Git LFS pointer"

    return hashlib.sha256(data).hexdigest(), len(data), None


def _under(path: str, root: str) -> bool:
    return path.startswith(root.rstrip("/") + "/")


def _schema_error(
    errors: list[str],
    lock_path: str,
    message: str,
) -> None:
    errors.append(f"{lock_path}: GMTL lock {message}")


def verify_gmtl_lock(
    root: Path,
    policy: dict,
    repository_files: Iterable[Path] | None = None,
) -> GmtlLockVerification:
    errors: list[str] = []

    imports = policy.get("imports")
    gmtl = imports.get("gmtl") if isinstance(imports, dict) else None
    lock_value = gmtl.get("lock") if isinstance(gmtl, dict) else None
    lock_path = _safe_relative_path(lock_value)

    if lock_path is None:
        return GmtlLockVerification(
            frozenset(),
            (
                "PROJECT_POLICY.toml: GMTL lock path must be a "
                "normalized repository-relative path",
            ),
        )

    full_lock_path = root / lock_path

    try:
        lock = json.loads(
            full_lock_path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_keys,
        )
    except OSError:
        return GmtlLockVerification(
            frozenset(),
            (f"{lock_path}: GMTL lock is missing or unreadable",),
        )
    except UnicodeDecodeError:
        return GmtlLockVerification(
            frozenset(),
            (f"{lock_path}: GMTL lock must be UTF-8",),
        )
    except (json.JSONDecodeError, DuplicateKeyError) as exc:
        return GmtlLockVerification(
            frozenset(),
            (f"{lock_path}: invalid GMTL lock JSON: {exc}",),
        )

    if not isinstance(lock, dict):
        return GmtlLockVerification(
            frozenset(),
            (f"{lock_path}: GMTL lock must be an object",),
        )

    actual_keys = set(lock)

    if actual_keys != LOCK_KEYS:
        missing = sorted(LOCK_KEYS - actual_keys)
        unexpected = sorted(actual_keys - LOCK_KEYS)
        details: list[str] = []
        if missing:
            details.append(f"missing keys {missing}")
        if unexpected:
            details.append(f"unexpected keys {unexpected}")
        _schema_error(errors, lock_path, "; ".join(details))

    if type(lock.get("schema_version")) is not int or (
        lock.get("schema_version") != 1
    ):
        _schema_error(errors, lock_path, "schema_version must be 1")

    name = lock.get("name")
    if not isinstance(name, str) or not name.strip():
        _schema_error(errors, lock_path, "name must be non-empty")

    upstream = lock.get("upstream")
    if (
        not isinstance(upstream, str)
        or not upstream.startswith("https://")
    ):
        _schema_error(errors, lock_path, "upstream must be an HTTPS URL")

    version = lock.get("version")
    if not isinstance(version, str) or VERSION.fullmatch(version) is None:
        _schema_error(errors, lock_path, "version must be a v-prefixed version")

    snapshot = lock.get("snapshot_commit")
    if not isinstance(snapshot, str) or COMMIT_SHA.fullmatch(snapshot) is None:
        _schema_error(
            errors,
            lock_path,
            "snapshot_commit must be a full lowercase commit SHA",
        )

    if lock.get("hash_algorithm") != "sha256":
        _schema_error(errors, lock_path, "hash_algorithm must be sha256")

    metadata_source = _safe_relative_path(lock.get("metadata_source"))
    if metadata_source is None:
        _schema_error(
            errors,
            lock_path,
            "metadata_source must be a normalized relative path",
        )

    raw_roots = lock.get("resource_roots")
    roots: list[str] = []

    if not isinstance(raw_roots, list) or not raw_roots:
        _schema_error(errors, lock_path, "resource_roots must be a non-empty list")
    else:
        for index, value in enumerate(raw_roots):
            path = _safe_relative_path(value)
            if path is None:
                _schema_error(
                    errors,
                    lock_path,
                    f"resource_roots[{index}] is not a normalized relative path",
                )
            else:
                roots.append(path)

        if roots != sorted(roots):
            _schema_error(errors, lock_path, "resource_roots must be sorted")
        if len(roots) != len(set(roots)):
            _schema_error(errors, lock_path, "resource_roots must be unique")

    root_count = lock.get("resource_root_count")
    if type(root_count) is not int or root_count != len(raw_roots or []):
        _schema_error(
            errors,
            lock_path,
            "resource_root_count must match resource_roots",
        )

    for index, first in enumerate(roots):
        for second in roots[index + 1:]:
            if _under(second, first):
                _schema_error(
                    errors,
                    lock_path,
                    f"resource roots overlap: {first} and {second}",
                )

    raw_files = lock.get("files")
    entries: list[tuple[str, str, int]] = []

    if not isinstance(raw_files, list) or not raw_files:
        _schema_error(errors, lock_path, "files must be a non-empty list")
    else:
        for index, entry in enumerate(raw_files):
            if not isinstance(entry, dict):
                _schema_error(errors, lock_path, f"files[{index}] must be an object")
                continue

            if set(entry) != FILE_KEYS:
                _schema_error(
                    errors,
                    lock_path,
                    f"files[{index}] must contain only path, sha256, and size",
                )

            path = _safe_relative_path(entry.get("path"))
            digest = entry.get("sha256")
            size = entry.get("size")

            if path is None:
                _schema_error(
                    errors,
                    lock_path,
                    f"files[{index}].path is not a normalized relative path",
                )
                continue
            if not isinstance(digest, str) or SHA256.fullmatch(digest) is None:
                _schema_error(
                    errors,
                    lock_path,
                    f"{path} has an invalid sha256",
                )
                continue
            if type(size) is not int or size < 0:
                _schema_error(
                    errors,
                    lock_path,
                    f"{path} has an invalid size",
                )
                continue

            entries.append((path, digest, size))

    entry_paths = [path for path, _, _ in entries]

    if entry_paths != sorted(entry_paths):
        _schema_error(errors, lock_path, "files must be sorted by path")
    if len(entry_paths) != len(set(entry_paths)):
        _schema_error(errors, lock_path, "file paths must be unique")

    file_count = lock.get("file_count")
    if type(file_count) is not int or file_count != len(raw_files or []):
        _schema_error(errors, lock_path, "file_count must match files")

    expected = set(entry_paths)

    for path in entry_paths:
        owners = [resource for resource in roots if _under(path, resource)]
        if len(owners) != 1:
            _schema_error(
                errors,
                lock_path,
                f"{path} must belong to exactly one resource root",
            )

    if metadata_source is not None and metadata_source not in expected:
        _schema_error(
            errors,
            lock_path,
            "metadata_source must be present in files",
        )

    if repository_files is None:
        repository_files, tracked_error = _tracked_files(root)
        if tracked_error:
            _schema_error(errors, lock_path, tracked_error)
    else:
        repository_files = list(repository_files)

    tracked = {
        path.as_posix()
        for path in repository_files
    }
    tracked_owned = {
        path
        for path in tracked
        if any(_under(path, resource) for resource in roots)
    }

    for path in sorted(expected - tracked_owned):
        _schema_error(errors, lock_path, f"locked file is not tracked: {path}")
    for path in sorted(tracked_owned - expected):
        _schema_error(errors, lock_path, f"unrecorded tracked file: {path}")

    on_disk: set[str] = set()

    for resource in roots:
        directory = root / resource
        if directory.is_symlink() or not directory.is_dir():
            _schema_error(
                errors,
                lock_path,
                f"resource root is missing or not a directory: {resource}",
            )
            continue

        for candidate in directory.rglob("*"):
            relative = candidate.relative_to(root).as_posix()
            if candidate.is_symlink():
                _schema_error(
                    errors,
                    lock_path,
                    f"symlinks are forbidden in the locked snapshot: {relative}",
                )
            elif candidate.is_file():
                on_disk.add(relative)

    for path in sorted(expected - on_disk):
        _schema_error(errors, lock_path, f"locked file is missing: {path}")
    for path in sorted(on_disk - expected):
        _schema_error(errors, lock_path, f"unrecorded file under resource root: {path}")

    for path, expected_hash, expected_size in entries:
        full_path = root / path
        if full_path.is_symlink() or not full_path.is_file():
            continue

        try:
            data = full_path.read_bytes()
        except OSError as exc:
            _schema_error(errors, lock_path, f"could not read {path}: {exc}")
            continue

        digest, size, pointer_error = _logical_hash(data)
        if pointer_error:
            _schema_error(errors, lock_path, f"{path}: {pointer_error}")
        elif digest != expected_hash or size != expected_size:
            _schema_error(
                errors,
                lock_path,
                f"integrity mismatch for {path}",
            )

    if metadata_source is not None and (root / metadata_source).is_file():
        try:
            metadata = (root / metadata_source).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            _schema_error(
                errors,
                lock_path,
                f"metadata_source is not readable UTF-8: {exc}",
            )
        else:
            versions = re.findall(
                r"(?m)^[ \t]*Version:[ \t]*(\S+)[ \t]*$",
                metadata,
            )
            if versions != [version]:
                _schema_error(
                    errors,
                    lock_path,
                    "version does not match metadata_source",
                )

            upstream_lines = [
                line.strip()
                for line in metadata.splitlines()
                if line.strip().startswith("https://")
            ]
            if upstream_lines != [upstream]:
                _schema_error(
                    errors,
                    lock_path,
                    "upstream does not match metadata_source",
                )

    verified = frozenset(expected) if not errors else frozenset()
    return GmtlLockVerification(verified, tuple(errors))
