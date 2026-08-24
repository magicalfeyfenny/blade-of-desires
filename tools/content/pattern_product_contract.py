"""Bind pattern catalogs to Blade's validated canonical product contract."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

if __package__:
    from .pattern_descriptor_plan import _add_error
    from .validate_product_contract import (
        ID_PATTERN,
        ID_PATTERN_TEXT,
        VERSION_PATTERN,
        validate_contract as validate_product_contract,
    )
else:
    from pattern_descriptor_plan import _add_error
    from validate_product_contract import (
        ID_PATTERN,
        ID_PATTERN_TEXT,
        VERSION_PATTERN,
        validate_contract as validate_product_contract,
    )


PRODUCT_CONTRACT_PATH = Path(__file__).resolve().parents[2] / "content/product_contract.json"
PRODUCT_CONTRACT_SOURCE = "<product-contract>"
LOAD_FAILED = object()


def _validate_exact_keys(
    value: Any, fields: set[str], source: str, path: str, errors: list[str]
) -> bool:
    """Require an object containing exactly the product-binding fields."""
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


def validate_binding(
    value: Any, source: str, path: str, errors: list[str]
) -> dict[str, str] | None:
    """Validate an exact product-contract identity and content-version binding."""
    if not _validate_exact_keys(value, {"id", "content_version"}, source, path, errors):
        return None
    contract_id = value.get("id")
    if not isinstance(contract_id, str) or ID_PATTERN.fullmatch(contract_id) is None:
        _add_error(
            errors,
            source,
            f"{path}.id",
            f"must be a lowercase dotted stable ID matching {ID_PATTERN_TEXT}",
        )
        contract_id = None
    elif not contract_id.startswith("contract."):
        _add_error(errors, source, f"{path}.id", "must use the contract. namespace")
        contract_id = None
    content_version = value.get("content_version")
    if not isinstance(content_version, str) or VERSION_PATTERN.fullmatch(content_version) is None:
        _add_error(errors, source, f"{path}.content_version", "must use major.minor.patch")
        content_version = None
    if contract_id is None or content_version is None:
        return None
    return {"id": contract_id, "content_version": content_version}


def collect_definition_ids(product_contract: Any) -> set[str]:
    """Collect every canonical record ID from a validated product contract."""
    stable_ids: set[str] = set()
    pending = [product_contract]
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            stable_id = value.get("id")
            if isinstance(stable_id, str):
                stable_ids.add(stable_id)
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)
    return stable_ids


def validate_context(
    product_contract: Any, source: str, errors: list[str]
) -> tuple[dict[str, str] | None, set[str]]:
    """Validate a decoded product contract and return its binding and definition IDs."""
    context_errors = validate_product_contract(product_contract, source=source)
    errors.extend(context_errors)
    if context_errors:
        return None, set()
    binding = {
        "id": product_contract["id"],
        "content_version": product_contract["content_version"],
    }
    return binding, collect_definition_ids(product_contract)


def validate_catalog_bindings(
    catalogs: list[dict[str, Any]],
    authoritative: dict[str, str] | None,
    errors: list[str],
) -> dict[str, str] | None:
    """Require every catalog to share and, when supplied, match one product binding."""
    valid_bindings = [
        catalog["product_contract"]
        for catalog in catalogs
        if catalog["product_contract"] is not None
    ]
    if authoritative is not None:
        expected = authoritative
        reason_kind = "authoritative product contract"
    elif valid_bindings:
        expected = min(valid_bindings, key=lambda item: (item["id"], item["content_version"]))
        reason_kind = "shared catalog binding"
    else:
        return None
    for catalog in catalogs:
        binding = catalog["product_contract"]
        if binding is None:
            continue
        for field in ("id", "content_version"):
            if binding[field] != expected[field]:
                _add_error(
                    errors,
                    catalog["source"],
                    f"catalog.product_contract.{field}",
                    f"must match {reason_kind} value {expected[field]}",
                )
    return {"id": expected["id"], "content_version": expected["content_version"]}


def _object_from_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Build a JSON object while rejecting duplicate member names."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate object key {key!r}")
        result[key] = value
    return result


def _reject_json_constant(value: str) -> None:
    """Reject nonstandard NaN and infinity constants during JSON decoding."""
    raise ValueError(f"nonstandard numeric constant {value}")


def load_strict_json(path: Path, errors: list[str]) -> Any:
    """Decode one strict UTF-8 JSON document or return a shared failure marker."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        _add_error(errors, str(path), "file", "is not readable UTF-8 text")
        return LOAD_FAILED
    try:
        return json.loads(
            text,
            object_pairs_hook=_object_from_pairs,
            parse_constant=_reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        _add_error(errors, str(path), "JSON", f"invalid: {exc.msg}")
    except ValueError as exc:
        _add_error(errors, str(path), "JSON", f"invalid: {exc}")
    return LOAD_FAILED


def load_authoritative_product_contract(errors: list[str]) -> Any:
    """Strictly load Blade's repository-owned canonical product contract."""
    return load_strict_json(PRODUCT_CONTRACT_PATH, errors)
