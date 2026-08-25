#!/usr/bin/env python3
"""Validate and normalize deterministic stage and encounter schedule catalogs."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Sequence

if __package__:
    from .stage_schedule_plan import (
        _add_error,
        normalize_catalog as _normalize_catalog,
        validate_context as _validate_stage_context,
    )
    from .stage_schedule_schema import (
        CATALOG_FIELDS,
        REGISTRY_FIELDS,
        _claim_id,
    )
    from . import stage_schedule_schema as _schema
    from .subordinate_product_contract import (
        LOAD_FAILED,
        PRODUCT_CONTRACT_PATH,
        PRODUCT_CONTRACT_SOURCE,
        load_authoritative_product_contract,
        load_strict_json,
        validate_binding as _validate_product_binding,
        validate_context as _validate_product_context,
        validate_document_bindings as _validate_catalog_bindings,
    )
else:
    from stage_schedule_plan import (
        _add_error,
        normalize_catalog as _normalize_catalog,
        validate_context as _validate_stage_context,
    )
    import stage_schedule_schema as _schema
    from stage_schedule_schema import CATALOG_FIELDS, REGISTRY_FIELDS, _claim_id
    from subordinate_product_contract import (
        LOAD_FAILED,
        PRODUCT_CONTRACT_PATH,
        PRODUCT_CONTRACT_SOURCE,
        load_authoritative_product_contract,
        load_strict_json,
        validate_binding as _validate_product_binding,
        validate_context as _validate_product_context,
        validate_document_bindings as _validate_catalog_bindings,
    )


IN_MEMORY_SOURCE = "<in-memory>"
INPUTS_SOURCE = "<inputs>"
DEFAULT_STAGE_PATH = Path("content/stages")
Q10_SCALE = 1_024


def _validate_record_list(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    validator: Any,
    *args: Any,
    require_nonempty: bool = False,
) -> list[dict[str, Any]]:
    """Validate a list of closed records with stable source paths."""
    if not isinstance(value, list) or (require_nonempty and not value):
        qualifier = "nonempty " if require_nonempty else ""
        _add_error(errors, source, path, f"must be a {qualifier}list")
        return []
    result: list[dict[str, Any]] = []
    for index, item in enumerate(value):
        entry = validator(item, source, f"{path}[{index}]", errors, *args)
        if entry is not None:
            result.append(entry)
    return result


def _validate_catalog_document(
    value: Any,
    source: str,
    errors: list[str],
    seen_ids: set[str],
    plane: tuple[int, int, int, int],
    registries: dict[str, set[str]],
    anchors: dict[str, dict[str, Any]],
    task_ports: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    cues: dict[str, dict[str, Any]],
    stages: dict[str, dict[str, Any]],
    encounters: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one catalog root and collect its global definitions."""
    path = "catalog"
    if not _schema._validate_object_keys(value, CATALOG_FIELDS, source, path, errors):
        return None
    _schema._validate_schema_version(
        value.get("schema_version"), source, f"{path}.schema_version", errors
    )
    stable_id = _schema._validate_stable_id(
        value.get("id"), "stage_catalog", source, f"{path}.id", errors
    )
    _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    local_registries: dict[str, list[str]] = {}
    for field, namespace in REGISTRY_FIELDS:
        ids = _schema._validate_id_list(
            value.get(field),
            namespace,
            source,
            f"{path}.{field}",
            errors,
            seen_ids=seen_ids,
        )
        local_registries[field] = [] if ids is None else ids
        registries[namespace].update(local_registries[field])
    named_anchors = _validate_record_list(
        value.get("named_anchors"),
        source,
        f"{path}.named_anchors",
        errors,
        _schema._validate_named_anchor,
        seen_ids,
        plane,
        anchors,
    )
    local_ports = _validate_record_list(
        value.get("task_ports"),
        source,
        f"{path}.task_ports",
        errors,
        _schema._validate_task_port,
        seen_ids,
        task_ports,
    )
    local_signals = _validate_record_list(
        value.get("signals"),
        source,
        f"{path}.signals",
        errors,
        _schema._validate_signal,
        seen_ids,
        signals,
    )
    local_cues = _validate_record_list(
        value.get("cues"),
        source,
        f"{path}.cues",
        errors,
        _schema._validate_cue,
        seen_ids,
        cues,
    )
    local_encounters = _validate_record_list(
        value.get("encounters"),
        source,
        f"{path}.encounters",
        errors,
        _schema._validate_encounter,
        seen_ids,
        encounters,
        require_nonempty=True,
    )
    local_stages = _validate_record_list(
        value.get("stages"),
        source,
        f"{path}.stages",
        errors,
        _schema._validate_stage,
        seen_ids,
        stages,
        require_nonempty=True,
    )
    return {
        "source": source,
        "schema_version": value.get("schema_version"),
        "id": stable_id,
        "display_name": _schema._validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "product_contract": _validate_product_binding(
            value.get("product_contract"), source, f"{path}.product_contract", errors
        ),
        "named_anchors": named_anchors,
        **local_registries,
        "task_ports": local_ports,
        "signals": local_signals,
        "cues": local_cues,
        "stages": local_stages,
        "encounters": local_encounters,
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


def _product_plane(product_contract: dict[str, Any]) -> tuple[int, int, int, int]:
    """Return the validated product gameplay plane in exact q10 coordinates."""
    plane = product_contract["runtime_geometry"]["gameplay_plane"]
    return (
        plane["x_min"] * Q10_SCALE,
        plane["x_max_exclusive"] * Q10_SCALE,
        plane["y_min"] * Q10_SCALE,
        plane["y_max_exclusive"] * Q10_SCALE,
    )


def validate_and_normalize_catalogs(
    documents: Sequence[tuple[str, Any]],
    product_contract: Any | None = None,
    *,
    product_contract_source: str = PRODUCT_CONTRACT_SOURCE,
) -> tuple[dict[str, Any] | None, list[str]]:
    """Validate decoded catalogs against product context into one stable plan."""
    errors: list[str] = []
    if product_contract is None:
        product_contract = load_authoritative_product_contract(errors)
        product_contract_source = str(PRODUCT_CONTRACT_PATH)
    authoritative_binding: dict[str, str] | None = None
    seen_ids: set[str] = set()
    plane = (0, 0, 0, 0)
    if product_contract is not LOAD_FAILED:
        authoritative_binding, seen_ids = _validate_product_context(
            product_contract, product_contract_source, errors
        )
        if authoritative_binding is not None:
            plane = _product_plane(product_contract)
    prepared = _prepare_documents(documents, errors)
    if not prepared:
        return None, sorted(errors)
    registries = {namespace: set() for _, namespace in REGISTRY_FIELDS}
    anchors: dict[str, dict[str, Any]] = {}
    task_ports: dict[str, dict[str, Any]] = {}
    signals: dict[str, dict[str, Any]] = {}
    cues: dict[str, dict[str, Any]] = {}
    stages: dict[str, dict[str, Any]] = {}
    encounters: dict[str, dict[str, Any]] = {}
    catalogs: list[dict[str, Any]] = []
    for source, _, document in prepared:
        catalog = _validate_catalog_document(
            document,
            source,
            errors,
            seen_ids,
            plane,
            registries,
            anchors,
            task_ports,
            signals,
            cues,
            stages,
            encounters,
        )
        if catalog is not None:
            catalogs.append(catalog)
    shared_binding = _validate_catalog_bindings(catalogs, authoritative_binding, errors)
    if not errors:
        _validate_stage_context(
            catalogs,
            registries,
            anchors,
            task_ports,
            signals,
            cues,
            stages,
            encounters,
            plane,
            errors,
        )
    if errors:
        return None, sorted(errors)
    return {
        "schema_version": 1,
        "product_contract": shared_binding,
        "catalogs": [
            _normalize_catalog(catalog)
            for catalog in sorted(catalogs, key=lambda item: item["id"])
        ],
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
    """Load stage catalogs and the canonical product contract into one plan."""
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
        _validate_product_context(product_contract, str(PRODUCT_CONTRACT_PATH), errors)
    if errors:
        return None, sorted(errors)
    return plan, []


def main(argv: Sequence[str] | None = None) -> int:
    """Validate the requested catalog path and print deterministic failures."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT_STAGE_PATH)
    args = parser.parse_args(argv)
    _, errors = validate_path(args.path)
    for diagnostic in errors:
        print(diagnostic)
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
