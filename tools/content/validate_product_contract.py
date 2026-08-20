#!/usr/bin/env python3
"""Validate Blade's canonical product contract before runtime loading exists."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$")
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
REQUIRED_ROOT_FIELDS = {
    "schema_version",
    "id",
    "display_name",
    "content_version",
    "id_grammar",
    "project",
    "campaign",
    "runtime_geometry",
    "product_requirements",
    "ships",
    "stages",
    "encounters",
}
KOLAR_LOADOUT_FIELDS = {
    "weapon",
    "weapon_id",
    "emitter",
    "emitter_id",
    "damage",
    "melee",
    "loadout",
}


def error(errors: list[str], path: str, field: str, reason: str) -> None:
    errors.append(f"{path}: {field}: {reason}")


def validate_record(
    record: Any,
    path: str,
    errors: list[str],
    seen_ids: set[str],
) -> None:
    if not isinstance(record, dict):
        error(errors, path, "record", "must be an object")
        return

    if record.get("schema_version") != 1:
        error(errors, path, "schema_version", "must be 1")

    stable_id = record.get("id")
    if not isinstance(stable_id, str) or not ID_PATTERN.fullmatch(stable_id):
        error(errors, path, "id", "must be a lowercase dotted stable ID")
    elif stable_id in seen_ids:
        error(errors, path, "id", f"duplicates {stable_id}")
    else:
        seen_ids.add(stable_id)

    if not isinstance(record.get("display_name"), str):
        error(errors, path, "display_name", "must be a string")


def records_at(contract: dict[str, Any], field: str) -> list[Any]:
    records = contract.get(field)
    return records if isinstance(records, list) else []


def validate_geometry(geometry: Any, errors: list[str]) -> None:
    path = "runtime_geometry"
    if not isinstance(geometry, dict):
        error(errors, path, "record", "must be an object")
        return

    output = geometry.get("logical_output")
    plane = geometry.get("gameplay_plane")
    if output != {"width": 640, "height": 360}:
        error(errors, path, "logical_output", "must be 640x360")
    expected_plane = {
        "x_min": 185,
        "x_max_exclusive": 455,
        "y_min": 0,
        "y_max_exclusive": 360,
        "width": 270,
        "height": 360,
    }
    if not isinstance(plane, dict) or any(
        plane.get(key) != value for key, value in expected_plane.items()
    ):
        error(
            errors,
            path,
            "gameplay_plane",
            "must be the centered [185,455) x [0,360) 270x360 plane",
        )


def validate_references(contract: dict[str, Any], errors: list[str]) -> None:
    stages = records_at(contract, "stages")
    encounters = records_at(contract, "encounters")
    stage_ids = {
        stage.get("id")
        for stage in stages
        if isinstance(stage, dict) and isinstance(stage.get("id"), str)
    }
    encounter_ids = {
        encounter.get("id")
        for encounter in encounters
        if isinstance(encounter, dict)
        and isinstance(encounter.get("id"), str)
    }

    campaign = contract.get("campaign", {})
    if not isinstance(campaign, dict):
        error(errors, "campaign", "record", "must be an object")
        return

    main_stage_ids = campaign.get("main_stage_ids")
    if not isinstance(main_stage_ids, list):
        error(errors, "campaign", "main_stage_ids", "must be a list")
        main_stage_ids = []
    for index, stage_id in enumerate(main_stage_ids):
        if stage_id not in stage_ids:
            error(errors, "campaign", f"main_stage_ids[{index}]", "is dangling")
    if campaign.get("extra_stage_id") not in stage_ids:
        error(errors, "campaign", "extra_stage_id", "is dangling")

    for index, stage in enumerate(stages):
        if not isinstance(stage, dict):
            continue
        linked_encounters = stage.get("encounter_ids")
        if not isinstance(linked_encounters, list):
            error(errors, f"stages[{index}]", "encounter_ids", "must be a list")
            continue
        for ref_index, encounter_id in enumerate(linked_encounters):
            if encounter_id not in encounter_ids:
                error(
                    errors,
                    f"stages[{index}]",
                    f"encounter_ids[{ref_index}]",
                    "is dangling",
                )

    for index, encounter in enumerate(encounters):
        if not isinstance(encounter, dict):
            continue
        if encounter.get("stage_id") not in stage_ids:
            error(errors, f"encounters[{index}]", "stage_id", "is dangling")


def validate_kolar(contract: dict[str, Any], errors: list[str]) -> None:
    ships = records_at(contract, "ships")
    kolar = next(
        (
            ship
            for ship in ships
            if isinstance(ship, dict) and ship.get("id") == "ship.kolar"
        ),
        None,
    )
    if kolar is None:
        error(errors, "ships", "ship.kolar", "is required as a reserved slot")
        return
    if kolar.get("selection_status") != "deferred":
        error(errors, "ship.kolar", "selection_status", "must be deferred")
    if not isinstance(kolar.get("resolution"), str):
        error(errors, "ship.kolar", "resolution", "must state why it is unresolved")
    for field in sorted(KOLAR_LOADOUT_FIELDS.intersection(kolar)):
        error(errors, "ship.kolar", field, "must remain unresolved")


def validate_contract(contract: Any) -> list[str]:
    """Return stable, field-specific errors for a decoded contract."""
    errors: list[str] = []
    if not isinstance(contract, dict):
        return ["product_contract: record: must be an object"]

    for field in sorted(REQUIRED_ROOT_FIELDS.difference(contract)):
        error(errors, "product_contract", field, "is required")

    if not isinstance(contract.get("content_version"), str) or not VERSION_PATTERN.fullmatch(
        contract.get("content_version", "")
    ):
        error(errors, "product_contract", "content_version", "must use major.minor.patch")

    seen_ids: set[str] = set()
    validate_record(contract, "product_contract", errors, seen_ids)
    for field in ("project", "campaign", "runtime_geometry"):
        validate_record(contract.get(field), field, errors, seen_ids)
    campaign = contract.get("campaign")
    if isinstance(campaign, dict):
        validate_record(campaign.get("progression"), "campaign.progression", errors, seen_ids)

    for collection in ("ships", "stages", "encounters"):
        records = contract.get(collection)
        if not isinstance(records, list):
            error(errors, "product_contract", collection, "must be a list")
            continue
        for index, record in enumerate(records):
            validate_record(record, f"{collection}[{index}]", errors, seen_ids)

    validate_geometry(contract.get("runtime_geometry"), errors)
    validate_references(contract, errors)
    validate_kolar(contract, errors)
    return errors


def validate_file(path: Path) -> list[str]:
    """Load a contract file and report decoding or semantic errors."""
    try:
        contract = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        return [f"{path}: file: unreadable: {exc}"]
    except json.JSONDecodeError as exc:
        return [f"{path}: JSON: invalid: {exc.msg}"]
    return validate_contract(contract)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    errors = validate_file(args.path)
    for item in errors:
        print(item)
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
