#!/usr/bin/env python3
"""Validate canonical content packaging for the Blade GameMaker project."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Sequence


DEFAULT_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
PROJECT_DIRECTORY = Path("project/~ blade of desires ~")
PROJECT_FILENAME = "~ blade of desires ~.yyp"
CONTENT_DIRECTORY = Path("content")
CONTENT_LINK = Path("datafiles/content")
STAGE_DIRECTORY = Path("stages")
PRODUCT_CONTRACT = Path("product_contract.json")
LOAD_FAILED = object()


def _add_error(errors: list[str], source: Path | str, field: str, reason: str) -> None:
    """Append one diagnostic bound to its source and logical field."""
    errors.append(f"{source}: {field}: {reason}")


def _object_from_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Build a JSON object while rejecting duplicate member names."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate object key {key!r}")
        result[key] = value
    return result


def _reject_json_constant(value: str) -> None:
    """Reject nonstandard numeric constants in project metadata."""
    raise ValueError(f"nonstandard numeric constant {value}")


def _strip_trailing_commas(text: str) -> str:
    """Remove GameMaker trailing commas without altering quoted strings."""
    output: list[str] = []
    in_string = False
    escaped = False
    index = 0
    while index < len(text):
        character = text[index]
        if in_string:
            output.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
            continue
        if character == '"':
            in_string = True
            output.append(character)
            index += 1
            continue
        if character == ",":
            lookahead = index + 1
            while lookahead < len(text) and text[lookahead].isspace():
                lookahead += 1
            if lookahead < len(text) and text[lookahead] in "]}":
                index += 1
                continue
        output.append(character)
        index += 1
    return "".join(output)


def _load_yyp(path: Path, errors: list[str]) -> Any:
    """Load one UTF-8 GameMaker project file with strict JSON semantics."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        _add_error(errors, path, "file", "must be readable UTF-8 text")
        return LOAD_FAILED
    try:
        value = json.loads(
            _strip_trailing_commas(text),
            object_pairs_hook=_object_from_pairs,
            parse_constant=_reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        _add_error(errors, path, "YYP", f"is malformed: {exc.msg}")
        return LOAD_FAILED
    except ValueError as exc:
        _add_error(errors, path, "YYP", f"is malformed: {exc}")
        return LOAD_FAILED
    if not isinstance(value, dict):
        _add_error(errors, path, "YYP", "must contain a project object")
        return LOAD_FAILED
    return value


def _resolve_directory(path: Path, field: str, errors: list[str]) -> Path | None:
    """Resolve one required directory or report a deterministic diagnostic."""
    try:
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError):
        _add_error(errors, path, field, "must exist and resolve without a symlink loop")
        return None
    if not resolved.is_dir():
        _add_error(errors, path, field, "must resolve to a directory")
        return None
    return resolved


def _validate_content_link(
    project_root: Path,
    content_root: Path,
    content_resolved: Path | None,
    errors: list[str],
) -> None:
    """Require the project content entry to be the one canonical directory link."""
    link = project_root / CONTENT_LINK
    if not os.path.lexists(link):
        _add_error(errors, link, "symlink", "is required")
        return
    if not link.is_symlink():
        _add_error(errors, link, "symlink", "must be a symbolic link, not a copied directory")
        return
    try:
        resolved = link.resolve(strict=True)
    except (OSError, RuntimeError):
        _add_error(errors, link, "symlink", "must resolve to the repository content directory")
        return
    if content_resolved is not None and resolved != content_resolved:
        _add_error(
            errors,
            link,
            "symlink",
            f"must resolve exactly to {content_root}",
        )


def _find_regular_json_copies(project_root: Path, errors: list[str]) -> None:
    """Reject physical JSON copies anywhere below the project datafiles tree."""
    datafiles = project_root / "datafiles"
    if not datafiles.is_dir():
        return
    for current, directory_names, filenames in os.walk(datafiles, followlinks=False):
        current_path = Path(current)
        directory_names[:] = sorted(
            name for name in directory_names if not (current_path / name).is_symlink()
        )
        for filename in sorted(filenames):
            candidate = current_path / filename
            if candidate.suffix.lower() == ".json" and not candidate.is_symlink():
                _add_error(
                    errors,
                    candidate,
                    "file",
                    "regular JSON copies are forbidden below project datafiles",
                )


def _discover_stage_sources(
    content_root: Path,
    content_resolved: Path | None,
    errors: list[str],
) -> list[Path]:
    """Return canonical immediate stage JSON sources in stable name order."""
    stage_root = content_root / STAGE_DIRECTORY
    if not stage_root.is_dir():
        _add_error(errors, stage_root, "directory", "must exist")
        return []
    try:
        candidates = sorted(stage_root.glob("*.json"), key=lambda path: path.name)
    except OSError:
        _add_error(errors, stage_root, "directory", "must be readable")
        return []
    sources: list[Path] = []
    for candidate in candidates:
        try:
            resolved = candidate.resolve(strict=True)
        except (OSError, RuntimeError):
            _add_error(errors, candidate, "file", "must resolve to a readable source file")
            continue
        if not resolved.is_file():
            _add_error(errors, candidate, "file", "must resolve to a regular source file")
            continue
        if content_resolved is not None:
            try:
                resolved.relative_to(content_resolved)
            except ValueError:
                _add_error(errors, candidate, "file", "must resolve within repository content")
                continue
        sources.append(candidate)
    return sources


def _content_destination(
    value: Any,
    yyp_path: Path,
    field: str,
    errors: list[str],
) -> PurePosixPath | None:
    """Validate and return one conventional datafiles/content destination."""
    if not isinstance(value, str) or not value:
        _add_error(errors, yyp_path, field, "must be a nonempty string")
        return None
    if "\\" in value:
        _add_error(errors, yyp_path, field, "must use forward slashes")
        return None
    destination = PurePosixPath(value)
    if destination.is_absolute() or ".." in destination.parts:
        _add_error(errors, yyp_path, field, "must not be absolute or contain ..")
        return None
    if destination.as_posix() != value:
        _add_error(errors, yyp_path, field, "must use a normalized relative path")
        return None
    if destination.parts[:2] != ("datafiles", "content"):
        _add_error(errors, yyp_path, field, "must be under datafiles/content")
        return None
    return destination


def _included_name(
    value: Any,
    yyp_path: Path,
    field: str,
    errors: list[str],
) -> str | None:
    """Validate one JSON IncludedFile basename."""
    if not isinstance(value, str) or not value:
        _add_error(errors, yyp_path, field, "must be a nonempty JSON basename")
        return None
    if "\\" in value or PurePosixPath(value).name != value or ".." in PurePosixPath(value).parts:
        _add_error(errors, yyp_path, field, "must be a basename without traversal")
        return None
    if not value.lower().endswith(".json"):
        _add_error(errors, yyp_path, field, "must name a JSON file")
        return None
    return value


def _resolve_listed_source(
    project_root: Path,
    content_root: Path,
    content_resolved: Path | None,
    destination: PurePosixPath,
    name: str,
    yyp_path: Path,
    field: str,
    errors: list[str],
) -> Path | None:
    """Resolve one listed JSON through both source and project paths exactly."""
    relative_parts = destination.parts[2:]
    source = content_root.joinpath(*relative_parts, name)
    project_source = project_root.joinpath(*destination.parts, name)
    try:
        source_resolved = source.resolve(strict=True)
    except (OSError, RuntimeError):
        _add_error(errors, yyp_path, field, f"lists missing canonical source {source}")
        return None
    if not source_resolved.is_file():
        _add_error(errors, yyp_path, field, f"must resolve to canonical source file {source}")
        return None
    if content_resolved is not None:
        try:
            source_resolved.relative_to(content_resolved)
        except ValueError:
            _add_error(errors, yyp_path, field, f"source must remain within {content_root}")
            return None
    try:
        project_resolved = project_source.resolve(strict=True)
    except (OSError, RuntimeError):
        _add_error(errors, yyp_path, field, f"project path does not resolve to {source}")
        return None
    if project_resolved != source_resolved:
        _add_error(errors, yyp_path, field, f"project path must resolve exactly to {source}")
        return None
    return source


def _validate_included_files(
    project: dict[str, Any],
    yyp_path: Path,
    project_root: Path,
    content_root: Path,
    content_resolved: Path | None,
    product_source: Path,
    stage_sources: list[Path],
    errors: list[str],
) -> None:
    """Validate canonical JSON entries plus exact product and stage coverage."""
    included_files = project.get("IncludedFiles")
    if not isinstance(included_files, list):
        _add_error(errors, yyp_path, "IncludedFiles", "must be an array")
        return
    product_count = 0
    stage_counts = {source.name: 0 for source in stage_sources}
    seen_destinations: dict[tuple[str, str], int] = {}
    for index, entry in enumerate(included_files):
        entry_field = f"IncludedFiles[{index}]"
        if not isinstance(entry, dict):
            _add_error(errors, yyp_path, entry_field, "must be an object")
            continue
        raw_name = entry.get("name")
        raw_path = entry.get("filePath")
        content_intent = (
            isinstance(raw_name, str) and raw_name.lower().endswith(".json")
        ) or (
            isinstance(raw_path, str)
            and (raw_path == "datafiles/content" or raw_path.startswith("datafiles/content/"))
        )
        if not content_intent:
            continue
        name = _included_name(raw_name, yyp_path, f"{entry_field}.name", errors)
        destination = _content_destination(
            raw_path, yyp_path, f"{entry_field}.filePath", errors
        )
        mask_valid = type(entry.get("CopyToMask")) is int and entry.get("CopyToMask") == -1
        if not mask_valid:
            _add_error(errors, yyp_path, f"{entry_field}.CopyToMask", "must be integer -1")
        if name is None or destination is None:
            continue
        key = (destination.as_posix(), name)
        if key in seen_destinations:
            _add_error(
                errors,
                yyp_path,
                entry_field,
                f"duplicates IncludedFiles[{seen_destinations[key]}] destination {key[0]}/{name}",
            )
        else:
            seen_destinations[key] = index
        source = _resolve_listed_source(
            project_root,
            content_root,
            content_resolved,
            destination,
            name,
            yyp_path,
            entry_field,
            errors,
        )
        if (
            source is not None
            and mask_valid
            and destination.parts[2:] == ()
            and name == product_source.name
        ):
            product_count += 1
        if (
            source is not None
            and mask_valid
            and destination.parts[2:] == STAGE_DIRECTORY.parts
            and name in stage_counts
        ):
            stage_counts[name] += 1
    if product_count != 1:
        _add_error(
            errors,
            product_source,
            "IncludedFiles",
            "must have exactly one valid datafiles/content entry; "
            f"found {product_count}",
        )
    for source in stage_sources:
        count = stage_counts[source.name]
        if count == 0:
            _add_error(
                errors,
                source,
                "IncludedFiles",
                "must have exactly one valid datafiles/content/stages entry; found 0",
            )
        elif count > 1:
            _add_error(
                errors,
                source,
                "IncludedFiles",
                f"must have exactly one valid datafiles/content/stages entry; found {count}",
            )


def validate_repository(
    repository_root: Path = DEFAULT_REPOSITORY_ROOT,
) -> list[str]:
    """Validate the repository-to-GameMaker canonical content bundle boundary."""
    root = Path(repository_root)
    project_root = root / PROJECT_DIRECTORY
    content_root = root / CONTENT_DIRECTORY
    yyp_path = project_root / PROJECT_FILENAME
    errors: list[str] = []
    content_resolved = _resolve_directory(content_root, "directory", errors)
    _validate_content_link(project_root, content_root, content_resolved, errors)
    _find_regular_json_copies(project_root, errors)
    stage_sources = _discover_stage_sources(content_root, content_resolved, errors)
    product_source = content_root / PRODUCT_CONTRACT
    project = _load_yyp(yyp_path, errors)
    if project is not LOAD_FAILED:
        _validate_included_files(
            project,
            yyp_path,
            project_root,
            content_root,
            content_resolved,
            product_source,
            stage_sources,
            errors,
        )
    return sorted(set(errors))


def main(argv: Sequence[str] | None = None) -> int:
    """Run the bundle validator and remain silent when validation succeeds."""
    parser = argparse.ArgumentParser(
        description="Validate Blade's canonical GameMaker content bundle."
    )
    parser.add_argument(
        "repository_root",
        nargs="?",
        type=Path,
        default=DEFAULT_REPOSITORY_ROOT,
        help="repository root (defaults to the current Blade checkout)",
    )
    arguments = parser.parse_args(argv)
    errors = validate_repository(arguments.repository_root)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
