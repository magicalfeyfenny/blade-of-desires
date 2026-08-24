#!/usr/bin/env python3
"""Validate and normalize deterministic pattern descriptor catalogs."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Sequence

if __package__:
    from .pattern_descriptor_plan import (
        ABSOLUTE_SPAWN_CAP,
        _add_error,
        compute_spawn_counts as _compute_spawn_counts,
        normalize_catalog as _normalize_catalog,
        report_cycles as _report_cycles,
        validate_references as _validate_references,
    )
    from .pattern_product_contract import (
        ID_PATTERN,
        ID_PATTERN_TEXT,
        LOAD_FAILED,
        PRODUCT_CONTRACT_PATH,
        PRODUCT_CONTRACT_SOURCE,
        load_authoritative_product_contract,
        load_strict_json,
        validate_binding as _validate_product_contract_binding,
        validate_catalog_bindings as _validate_catalog_bindings,
        validate_context as _validate_product_contract_context,
    )
else:
    from pattern_descriptor_plan import (
        ABSOLUTE_SPAWN_CAP,
        _add_error,
        compute_spawn_counts as _compute_spawn_counts,
        normalize_catalog as _normalize_catalog,
        report_cycles as _report_cycles,
        validate_references as _validate_references,
    )
    from pattern_product_contract import (
        ID_PATTERN,
        ID_PATTERN_TEXT,
        LOAD_FAILED,
        PRODUCT_CONTRACT_PATH,
        PRODUCT_CONTRACT_SOURCE,
        load_authoritative_product_contract,
        load_strict_json,
        validate_binding as _validate_product_contract_binding,
        validate_catalog_bindings as _validate_catalog_bindings,
        validate_context as _validate_product_contract_context,
    )


IN_MEMORY_SOURCE = "<in-memory>"
INPUTS_SOURCE = "<inputs>"
DEFAULT_PATTERN_PATH = Path("content/patterns")
MAX_LINEAR_VALUE = 1_000_000
FULL_TURN_MILLIDEGREES = 360_000

CATALOG_FIELDS = {
    "schema_version",
    "id",
    "display_name",
    "product_contract",
    "named_anchor_ids",
    "target_snapshot_ids",
    "aim_rule_ids",
    "bullet_kind_ids",
    "theme_tag_ids",
    "descriptors",
}
DESCRIPTOR_INTEGER_RANGES = {
    "count": (1, MAX_LINEAR_VALUE),
    "local_angle_millidegrees": (0, FULL_TURN_MILLIDEGREES - 1),
    "spread_millidegrees": (0, FULL_TURN_MILLIDEGREES),
    "cadence_ticks": (1, MAX_LINEAR_VALUE),
    "repeat_count": (1, MAX_LINEAR_VALUE),
    "lifetime_ticks": (1, MAX_LINEAR_VALUE),
    "acceleration_q10_per_tick_squared": (-MAX_LINEAR_VALUE, MAX_LINEAR_VALUE),
    "friction_per_mille": (0, 1_000),
    "rotation_millidegrees_per_tick": (
        -FULL_TURN_MILLIDEGREES,
        FULL_TURN_MILLIDEGREES,
    ),
    "cancellation_power": (0, MAX_LINEAR_VALUE),
    "spawn_budget": (1, ABSOLUTE_SPAWN_CAP),
}
DESCRIPTOR_FIELDS = {
    "schema_version",
    "id",
    "display_name",
    "origin",
    "aim",
    "speed_tiers_q10_per_tick",
    "bullet_kind_id",
    "theme_tag_ids",
    "child",
} | set(DESCRIPTOR_INTEGER_RANGES)
REGISTRY_FIELDS = (
    ("named_anchor_ids", "anchor"),
    ("target_snapshot_ids", "target"),
    ("aim_rule_ids", "aim_rule"),
    ("bullet_kind_ids", "bullet_kind"),
    ("theme_tag_ids", "theme"),
)


def _validate_object_keys(
    value: Any,
    fields: set[str],
    source: str,
    path: str,
    errors: list[str],
) -> bool:
    """Require an object with exactly the schema fields while reporting every key defect."""
    if not isinstance(value, dict):
        _add_error(errors, source, path, "must be an object")
        return False
    for key in sorted(fields.difference(value)):
        _add_error(errors, source, f"{path}.{key}", "is required")
    for key in sorted(set(value).difference(fields), key=str):
        _add_error(
            errors,
            source,
            f"{path}.{key}",
            "is not declared by schema version 1",
        )
    return True


def _validate_schema_version(
    value: Any, source: str, path: str, errors: list[str]
) -> bool:
    """Accept only integer schema version 1, excluding booleans."""
    if type(value) is not int or value != 1:
        _add_error(errors, source, path, "must be the integer 1")
        return False
    return True


def _validate_display_name(
    value: Any, source: str, path: str, errors: list[str]
) -> str | None:
    """Return a nonempty display name without deriving identity from it."""
    if not isinstance(value, str) or not value.strip():
        _add_error(errors, source, path, "must be a nonempty string")
        return None
    return value


def _validate_stable_id(
    value: Any,
    namespace: str,
    source: str,
    path: str,
    errors: list[str],
) -> str | None:
    """Return a lowercase dotted stable ID in the required namespace."""
    if not isinstance(value, str) or ID_PATTERN.fullmatch(value) is None:
        _add_error(
            errors,
            source,
            path,
            f"must be a lowercase dotted stable ID matching {ID_PATTERN_TEXT}",
        )
        return None
    if not value.startswith(f"{namespace}."):
        _add_error(errors, source, path, f"must use the {namespace}. namespace")
        return None
    return value


def _claim_id(
    stable_id: str | None,
    seen_ids: set[str],
    source: str,
    path: str,
    errors: list[str],
) -> bool:
    """Claim one definition ID or report a repository-wide duplicate."""
    if stable_id is None:
        return False
    if stable_id in seen_ids:
        _add_error(errors, source, path, f"duplicates {stable_id}")
        return False
    seen_ids.add(stable_id)
    return True


def _validate_integer(
    value: Any,
    minimum: int,
    maximum: int,
    source: str,
    path: str,
    errors: list[str],
) -> int | None:
    """Return an integer inside an inclusive deterministic range."""
    if type(value) is not int or not minimum <= value <= maximum:
        _add_error(
            errors,
            source,
            path,
            f"must be an integer from {minimum} through {maximum}",
        )
        return None
    return value


def _validate_id_list(
    value: Any,
    namespace: str,
    source: str,
    path: str,
    errors: list[str],
    seen_definitions: set[str] | None = None,
    require_nonempty: bool = True,
) -> list[str] | None:
    """Validate a unique stable-ID list and optionally require content or claim IDs."""
    if not isinstance(value, list):
        _add_error(errors, source, path, "must be a list")
        return None
    if require_nonempty and not value:
        _add_error(errors, source, path, "must be a nonempty list")
        return None
    result: list[str] = []
    local_ids: set[str] = set()
    for index, item in enumerate(value):
        item_path = f"{path}[{index}]"
        stable_id = _validate_stable_id(item, namespace, source, item_path, errors)
        if stable_id is None:
            continue
        if stable_id in local_ids:
            _add_error(errors, source, item_path, f"duplicates {stable_id}")
            continue
        local_ids.add(stable_id)
        if seen_definitions is not None and not _claim_id(
            stable_id, seen_definitions, source, item_path, errors
        ):
            continue
        result.append(stable_id)
    return result


def _validate_integer_list(
    value: Any,
    minimum: int,
    maximum: int,
    source: str,
    path: str,
    errors: list[str],
) -> list[int] | None:
    """Validate a nonempty unique list of bounded integers."""
    if not isinstance(value, list) or not value:
        _add_error(errors, source, path, "must be a nonempty list")
        return None
    result: list[int] = []
    seen_values: set[int] = set()
    for index, item in enumerate(value):
        item_path = f"{path}[{index}]"
        number = _validate_integer(item, minimum, maximum, source, item_path, errors)
        if number is None:
            continue
        if number in seen_values:
            _add_error(errors, source, item_path, f"duplicates {number}")
            continue
        seen_values.add(number)
        result.append(number)
    return result


def _validate_origin(
    value: Any, source: str, path: str, errors: list[str]
) -> dict[str, Any] | None:
    """Validate an emitter-origin or named-anchor closed variant."""
    if not isinstance(value, dict):
        _add_error(errors, source, path, "must be an object")
        return None
    kind = value.get("kind")
    if kind == "emitter_origin":
        _validate_object_keys(value, {"kind"}, source, path, errors)
        return {"kind": kind, "anchor_id": None}
    if kind == "named_anchor":
        _validate_object_keys(value, {"kind", "anchor_id"}, source, path, errors)
        anchor_id = _validate_stable_id(
            value.get("anchor_id"), "anchor", source, f"{path}.anchor_id", errors
        )
        return {"kind": kind, "anchor_id": anchor_id}
    _validate_object_keys(value, {"kind"}, source, path, errors)
    if "kind" in value:
        _add_error(errors, source, f"{path}.kind", "must be emitter_origin or named_anchor")
    return None


def _validate_aim(
    value: Any, source: str, path: str, errors: list[str]
) -> dict[str, Any] | None:
    """Validate a fixed-angle, target-snapshot, or aim-rule closed variant."""
    if not isinstance(value, dict):
        _add_error(errors, source, path, "must be an object")
        return None
    kind = value.get("kind")
    normalized = {
        "kind": kind,
        "angle_millidegrees": None,
        "target_id": None,
        "rule_id": None,
    }
    if kind == "fixed_angle":
        _validate_object_keys(value, {"kind", "angle_millidegrees"}, source, path, errors)
        normalized["angle_millidegrees"] = _validate_integer(
            value.get("angle_millidegrees"),
            0,
            FULL_TURN_MILLIDEGREES - 1,
            source,
            f"{path}.angle_millidegrees",
            errors,
        )
        return normalized
    if kind == "target_snapshot":
        _validate_object_keys(value, {"kind", "target_id"}, source, path, errors)
        normalized["target_id"] = _validate_stable_id(
            value.get("target_id"), "target", source, f"{path}.target_id", errors
        )
        return normalized
    if kind == "aim_rule":
        _validate_object_keys(value, {"kind", "rule_id"}, source, path, errors)
        normalized["rule_id"] = _validate_stable_id(
            value.get("rule_id"), "aim_rule", source, f"{path}.rule_id", errors
        )
        return normalized
    _validate_object_keys(value, {"kind"}, source, path, errors)
    if "kind" in value:
        _add_error(
            errors,
            source,
            f"{path}.kind",
            "must be fixed_angle, target_snapshot, or aim_rule",
        )
    return None


def _validate_child(
    value: Any, source: str, path: str, errors: list[str]
) -> tuple[dict[str, str] | None, bool]:
    """Validate an optional normal-expiry child invocation with a fixed origin."""
    if value is None:
        return None, True
    fields = {"pattern_id", "trigger", "origin"}
    error_count = len(errors)
    if not _validate_object_keys(value, fields, source, path, errors):
        return None, False
    pattern_id = _validate_stable_id(
        value.get("pattern_id"), "pattern", source, f"{path}.pattern_id", errors
    )
    trigger = value.get("trigger")
    if trigger != "normal_expiry":
        _add_error(errors, source, f"{path}.trigger", "must be normal_expiry")
    origin = value.get("origin")
    if origin != "projectile_terminal_position":
        _add_error(
            errors,
            source,
            f"{path}.origin",
            "must be projectile_terminal_position",
        )
    child = {
        "pattern_id": pattern_id,
        "trigger": trigger,
        "origin": origin,
    }
    return child, len(errors) == error_count and pattern_id is not None


def _validate_descriptor(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    descriptors: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one descriptor locally and index its valid stable identity."""
    if not _validate_object_keys(value, DESCRIPTOR_FIELDS, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "pattern", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    display_name = _validate_display_name(
        value.get("display_name"), source, f"{path}.display_name", errors
    )
    origin = _validate_origin(value.get("origin"), source, f"{path}.origin", errors)
    aim = _validate_aim(value.get("aim"), source, f"{path}.aim", errors)
    integers = {
        field: _validate_integer(
            value.get(field), minimum, maximum, source, f"{path}.{field}", errors
        )
        for field, (minimum, maximum) in DESCRIPTOR_INTEGER_RANGES.items()
    }
    speed_tiers = _validate_integer_list(
        value.get("speed_tiers_q10_per_tick"),
        1,
        MAX_LINEAR_VALUE,
        source,
        f"{path}.speed_tiers_q10_per_tick",
        errors,
    )
    bullet_kind_id = _validate_stable_id(
        value.get("bullet_kind_id"),
        "bullet_kind",
        source,
        f"{path}.bullet_kind_id",
        errors,
    )
    theme_tag_ids = _validate_id_list(
        value.get("theme_tag_ids"),
        "theme",
        source,
        f"{path}.theme_tag_ids",
        errors,
    )
    child, child_is_valid = _validate_child(
        value.get("child"), source, f"{path}.child", errors
    )
    count = integers["count"]
    repeat_count = integers["repeat_count"]
    spread = integers["spread_millidegrees"]
    if (
        count is not None
        and spread == FULL_TURN_MILLIDEGREES
        and count > FULL_TURN_MILLIDEGREES
    ):
        _add_error(
            errors,
            source,
            f"{path}.count",
            f"must not exceed {FULL_TURN_MILLIDEGREES} for a full-turn spread",
        )
    direct_spawn_count = (
        count * repeat_count if count is not None and repeat_count is not None else None
    )
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": display_name,
        "origin": origin,
        "aim": aim,
        **integers,
        "speed_tiers_q10_per_tick": speed_tiers,
        "bullet_kind_id": bullet_kind_id,
        "theme_tag_ids": theme_tag_ids,
        "child": child,
        "child_is_valid": child_is_valid,
        "direct_spawn_count": direct_spawn_count,
    }
    if stable_id is not None and claimed:
        descriptors[stable_id] = entry
    return entry


def _validate_catalog_document(
    value: Any,
    source: str,
    errors: list[str],
    seen_ids: set[str],
    registries: dict[str, set[str]],
    descriptors: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one catalog root and collect its definitions for global checks."""
    path = "catalog"
    if not _validate_object_keys(value, CATALOG_FIELDS, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(
        value.get("id"), "pattern_catalog", source, f"{path}.id", errors
    )
    _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    display_name = _validate_display_name(
        value.get("display_name"), source, f"{path}.display_name", errors
    )
    product_binding = _validate_product_contract_binding(
        value.get("product_contract"),
        source,
        f"{path}.product_contract",
        errors,
    )
    normalized_registries: dict[str, list[str] | None] = {}
    for field, namespace in REGISTRY_FIELDS:
        values = _validate_id_list(
            value.get(field),
            namespace,
            source,
            f"{path}.{field}",
            errors,
            seen_ids,
            require_nonempty=False,
        )
        normalized_registries[field] = values
        if values is not None:
            registries[namespace].update(values)
    descriptor_entries: list[dict[str, Any]] = []
    raw_descriptors = value.get("descriptors")
    if not isinstance(raw_descriptors, list) or not raw_descriptors:
        _add_error(errors, source, f"{path}.descriptors", "must be a nonempty list")
    else:
        for index, descriptor in enumerate(raw_descriptors):
            entry = _validate_descriptor(
                descriptor,
                source,
                f"{path}.descriptors[{index}]",
                errors,
                seen_ids,
                descriptors,
            )
            if entry is not None:
                descriptor_entries.append(entry)
    return {
        "source": source,
        "schema_version": value.get("schema_version"),
        "id": stable_id,
        "display_name": display_name,
        "product_contract": product_binding,
        **normalized_registries,
        "descriptors": descriptor_entries,
    }


def _prepare_documents(
    documents: Sequence[tuple[str, Any]], errors: list[str]
) -> list[tuple[str, int, Any]]:
    """Materialize and source-sort decoded catalog documents for stable validation."""
    materialized = list(documents)
    if not materialized:
        _add_error(errors, INPUTS_SOURCE, "catalogs", "requires at least one catalog document")
        return []
    prepared: list[tuple[str, int, Any]] = []
    for index, item in enumerate(materialized):
        if not isinstance(item, (tuple, list)) or len(item) != 2:
            _add_error(
                errors,
                INPUTS_SOURCE,
                f"catalogs[{index}]",
                "must be a source and decoded document pair",
            )
            continue
        source, document = item
        prepared.append((str(source), index, document))
    return sorted(prepared, key=lambda item: (item[0], item[1]))


def validate_and_normalize_catalogs(
    documents: Sequence[tuple[str, Any]],
    product_contract: Any | None = None,
    *,
    product_contract_source: str = PRODUCT_CONTRACT_SOURCE,
) -> tuple[dict[str, Any] | None, list[str]]:
    """Validate decoded catalogs against product context into one stable plan."""
    errors: list[str] = []
    authoritative_binding: dict[str, str] | None = None
    seen_ids: set[str] = set()
    if product_contract is None:
        product_contract = load_authoritative_product_contract(errors)
        product_contract_source = str(PRODUCT_CONTRACT_PATH)
    if product_contract is not LOAD_FAILED:
        authoritative_binding, seen_ids = _validate_product_contract_context(
            product_contract, product_contract_source, errors
        )
    prepared = _prepare_documents(documents, errors)
    if not prepared:
        return None, sorted(errors)
    registries = {namespace: set() for _, namespace in REGISTRY_FIELDS}
    descriptors: dict[str, dict[str, Any]] = {}
    catalogs: list[dict[str, Any]] = []
    for source, _, document in prepared:
        catalog = _validate_catalog_document(
            document, source, errors, seen_ids, registries, descriptors
        )
        if catalog is not None:
            catalogs.append(catalog)
    shared_binding = _validate_catalog_bindings(catalogs, authoritative_binding, errors)
    _validate_references(descriptors, registries, errors)
    cycle_nodes = _report_cycles(descriptors, errors)
    maximums = _compute_spawn_counts(descriptors, cycle_nodes, errors)
    if errors:
        return None, sorted(errors)
    normalized_catalogs = [
        _normalize_catalog(catalog, maximums)
        for catalog in sorted(catalogs, key=lambda item: item["id"])
    ]
    return {
        "schema_version": 1,
        "product_contract": shared_binding,
        "catalogs": normalized_catalogs,
    }, []


def validate_catalogs(
    documents: Sequence[tuple[str, Any]], product_contract: Any | None = None
) -> list[str]:
    """Return diagnostics using supplied context or the canonical product contract."""
    _, errors = validate_and_normalize_catalogs(documents, product_contract)
    return errors


def normalize_catalogs(
    documents: Sequence[tuple[str, Any]], product_contract: Any | None = None
) -> dict[str, Any]:
    """Return a canonically context-bound plan or raise every diagnostic."""
    plan, errors = validate_and_normalize_catalogs(documents, product_contract)
    if errors:
        raise ValueError("\n".join(errors))
    if plan is None:
        raise ValueError(f"{INPUTS_SOURCE}: catalogs: normalization produced no plan")
    return plan


def validate_catalog(
    catalog: Any,
    source: str = IN_MEMORY_SOURCE,
    product_contract: Any | None = None,
) -> list[str]:
    """Return diagnostics for one catalog using canonical context by default."""
    return validate_catalogs([(source, catalog)], product_contract)


def normalize_catalog(
    catalog: Any,
    source: str = IN_MEMORY_SOURCE,
    product_contract: Any | None = None,
) -> dict[str, Any]:
    """Return a detached canonically bound plan or raise ValueError."""
    return normalize_catalogs([(source, catalog)], product_contract)


def _discover_catalog_paths(path: Path, errors: list[str]) -> list[Path]:
    """Resolve a JSON file or recursively discover sorted JSON files in a directory."""
    if not path.exists():
        _add_error(errors, str(path), "input", "does not exist")
        return []
    if path.is_file():
        if path.suffix != ".json":
            _add_error(errors, str(path), "input", "must be a .json file or directory")
            return []
        return [path]
    if not path.is_dir():
        _add_error(errors, str(path), "input", "must be a .json file or directory")
        return []
    try:
        paths = sorted(candidate for candidate in path.rglob("*.json") if candidate.is_file())
    except OSError:
        _add_error(errors, str(path), "input", "could not enumerate JSON catalog documents")
        return []
    if not paths:
        _add_error(errors, str(path), "input", "contains no JSON catalog documents")
    return paths


def validate_path(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    """Load catalogs and the canonical product contract into one validated plan."""
    path = Path(path)
    errors: list[str] = []
    product_contract = load_authoritative_product_contract(errors)
    paths = _discover_catalog_paths(path, errors)
    documents: list[tuple[str, Any]] = []
    for catalog_path in paths:
        catalog = load_strict_json(catalog_path, errors)
        if catalog is not LOAD_FAILED:
            documents.append((str(catalog_path), catalog))
    plan: dict[str, Any] | None = None
    if documents and product_contract is not LOAD_FAILED:
        plan, validation_errors = validate_and_normalize_catalogs(
            documents,
            product_contract,
            product_contract_source=str(PRODUCT_CONTRACT_PATH),
        )
        errors.extend(validation_errors)
    elif product_contract is not LOAD_FAILED:
        _validate_product_contract_context(
            product_contract, str(PRODUCT_CONTRACT_PATH), errors
        )
    if errors:
        return None, sorted(errors)
    return plan, []


def main(argv: Sequence[str] | None = None) -> int:
    """Validate the requested catalog path and print deterministic failures."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT_PATTERN_PATH)
    args = parser.parse_args(argv)
    _, errors = validate_path(args.path)
    for diagnostic in errors:
        print(diagnostic)
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
