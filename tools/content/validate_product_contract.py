#!/usr/bin/env python3
"""Validate Blade's canonical product contract before runtime loading exists."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


IN_MEMORY_SOURCE = "<in-memory>"
ID_PATTERN_TEXT = r"^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$"
ID_PATTERN = re.compile(ID_PATTERN_TEXT)
VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
CORE_CONTENT_VERSION = (1, 2, 0)
CORE_CONTENT_VERSION_TEXT = "1.2.0"
COMMON_RECORD_FIELDS = {"schema_version", "id", "display_name"}
REQUIRED_ROOT_FIELDS = COMMON_RECORD_FIELDS | {
    "content_version",
    "id_grammar",
    "project",
    "campaign",
    "runtime_geometry",
    "product_requirements",
    "difficulties",
    "ships",
    "stages",
    "encounters",
}
ALLOWED_ROOT_FIELDS = REQUIRED_ROOT_FIELDS | {"registry_extensions"}
PRODUCT_REQUIREMENT_FIELDS = {
    "gameplay",
    "enemy_emission_gate",
    "boss_phase_policy",
    "defeat_feedback",
    "presentation",
    "asset_authoring",
}
CORE_DIFFICULTY_IDS = (
    "difficulty.easy",
    "difficulty.normal",
    "difficulty.hard",
)
MAIN_STAGE_IDS = (
    "stage.stage1.lost_forest_of_aurei",
    "stage.stage2.waters_of_unyielding_life",
    "stage.stage3.under_the_vultures_shadow",
    "stage.stage4.assault_on_the_desert_rose",
    "stage.stage5.banner_of_the_bloody_lion",
    "stage.stage6.blade_of_desires",
)
EXTRA_STAGE_ID = "stage.extra.dreams_of_a_clockwork_angel"
CORE_SHIP_ROLES = {
    "ship.maynii": "forward_tracking_all_rounder",
    "ship.ciela": "spread_specialist",
    "ship.kolar": "close_range_specialist",
}
CORE_SHIP_IDENTITIES = {
    "ship.maynii": "All-around ship with dependable forward damage and tracking coverage.",
    "ship.ciela": "Spread specialist with broad field coverage.",
    "ship.kolar": "Close-range specialist whose primary payoff comes from fighting near targets while retaining dependable, meaningful ranged damage.",
}
KOLAR_RESOLUTION = (
    "The role and ranged-damage floor are binding; exact implementation and "
    "tuning remain delegated to Issue #23."
)
CORE_STAGE_ORDERS = {stage_id: index for index, stage_id in enumerate(MAIN_STAGE_IDS, 1)}
CORE_STAGE_ORDERS[EXTRA_STAGE_ID] = "extra"
CORE_ENCOUNTERS = {
    "encounter.stage1.unchosen_elemental_fae": (MAIN_STAGE_IDS[0], "midboss"),
    "encounter.stage1.asahi": (MAIN_STAGE_IDS[0], "boss"),
    "encounter.stage2.great_turtle_of_aurei": (MAIN_STAGE_IDS[1], "boss"),
    "encounter.stage2.lia": (MAIN_STAGE_IDS[1], "boss"),
    "encounter.stage3.galatine": (MAIN_STAGE_IDS[2], "boss"),
    "encounter.stage3.ai_wanderer_of_duality": (MAIN_STAGE_IDS[2], "boss"),
    "encounter.stage4.divine_armor_bes_mk4": (MAIN_STAGE_IDS[3], "boss"),
    "encounter.stage4.durandal": (MAIN_STAGE_IDS[3], "boss"),
    "encounter.stage5.raptor_rx_588_surtr": (MAIN_STAGE_IDS[4], "boss"),
    "encounter.stage5.jackson": (MAIN_STAGE_IDS[4], "boss"),
    "encounter.stage6.mira": (MAIN_STAGE_IDS[5], "boss"),
    "encounter.extra.ai_keeper_of_duality": (EXTRA_STAGE_ID, "boss"),
    "encounter.extra.desire_mechanical_fae": (EXTRA_STAGE_ID, "boss"),
}
PROGRESSION_VALUES = {
    "canonical_ending_condition": "main_campaign_no_continue",
    "continued_ending_condition": "main_campaign_continue_used",
    "extra_stage_unlock_condition": "main_campaign_1cc_any_difficulty",
    "extra_stage_story_condition": "canonical_ending_complete",
}
CONTAINMENT_SUMMARY = (
    "The plane is half-open. Point anchors must lie inside it, and declared "
    "hurtboxes must be fully contained. Coordinates use a binary "
    "1/1024-logical-pixel grid; clamp right and bottom coordinates to the "
    "exclusive maximum minus one grid step."
)
GEOMETRY_POLICY = {
    "containment": CONTAINMENT_SUMMARY,
    "anchor_containment": "point_inside_half_open_plane",
    "hurtbox_containment": "fully_contained_in_half_open_plane",
    "coordinate_grid": "binary_fixed_1_1024_logical_pixel",
    "right_bottom_clamp": "exclusive_max_minus_one_grid_step",
}
KOLAR_RANGE_POLICY = {
    "primary_strength": "close_range_combat",
    "ranged_damage_requirement": "meaningful",
    "forbidden_interpretations": [
        "collision_only",
        "melee_only",
        "zero_range",
        "negligible_ranged_damage",
    ],
}
KOLAR_IMPLEMENTATION_BOUNDARY = {
    "delegated_issue": 23,
    "unresolved": [
        "weapon_form",
        "melee_choice",
        "emitters",
        "option_formation",
        "cadence",
        "damage_values",
        "distance_bands",
        "final_balance",
    ],
}


def error(errors: list[str], source: str, field: str, reason: str) -> None:
    errors.append(f"{source}: {field}: {reason}")


def nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_keys(
    value: Any,
    required: set[str],
    allowed: set[str],
    source: str,
    field: str,
    errors: list[str],
) -> bool:
    if not isinstance(value, dict):
        error(errors, source, field, "must be an object")
        return False
    for key in sorted(required.difference(value)):
        error(errors, source, f"{field}.{key}", "is required")
    for key in sorted(set(value).difference(allowed), key=str):
        error(errors, source, f"{field}.{key}", "is not declared by schema version 1")
    return True


def validate_record(
    record: Any,
    source: str,
    field: str,
    errors: list[str],
    seen_ids: set[str],
) -> str | None:
    if not isinstance(record, dict):
        error(errors, source, field, "must be an object")
        return None
    if type(record.get("schema_version")) is not int or record["schema_version"] != 1:
        error(errors, source, f"{field}.schema_version", "must be 1")
    stable_id = record.get("id")
    if not isinstance(stable_id, str) or not ID_PATTERN.fullmatch(stable_id):
        error(errors, source, f"{field}.id", "must be a lowercase dotted stable ID")
        stable_id = None
    elif stable_id in seen_ids:
        error(errors, source, f"{field}.id", f"duplicates {stable_id}")
    else:
        seen_ids.add(stable_id)
    if not nonempty_text(record.get("display_name")):
        error(errors, source, f"{field}.display_name", "must be a nonempty string")
    return stable_id


def validate_text_table(
    value: Any,
    fields: set[str],
    source: str,
    path: str,
    errors: list[str],
) -> None:
    if not validate_keys(value, fields, fields, source, path, errors):
        return
    for field in sorted(fields):
        if not nonempty_text(value.get(field)):
            error(errors, source, f"{path}.{field}", "must be a nonempty string")


def validate_id_grammar(value: Any, source: str, errors: list[str]) -> None:
    fields = {"pattern", "collision_policy"}
    validate_text_table(value, fields, source, "product_contract.id_grammar", errors)
    if not isinstance(value, dict):
        return
    expected = {
        "pattern": ID_PATTERN_TEXT,
        "collision_policy": "globally_unique_and_never_reused",
    }
    for field, expected_value in expected.items():
        if value.get(field) != expected_value:
            error(errors, source, f"product_contract.id_grammar.{field}", f"must be {expected_value}")


def validate_extensions(value: Any, source: str, errors: list[str]) -> dict[str, set[str]]:
    result = {"ships": set(), "stages": set(), "encounters": set()}
    if value is None:
        return result
    fields = {"schema_version", "ship_ids", "stage_ids", "encounter_ids"}
    if not validate_keys(value, fields, fields, source, "registry_extensions", errors):
        return result
    if type(value.get("schema_version")) is not int or value["schema_version"] != 1:
        error(errors, source, "registry_extensions.schema_version", "must be 1")
    core = {
        "ships": set(CORE_SHIP_ROLES),
        "stages": set(CORE_STAGE_ORDERS),
        "encounters": set(CORE_ENCOUNTERS),
    }
    for collection in result:
        field = f"{collection[:-1]}_ids" if collection != "encounters" else "encounter_ids"
        items = value.get(field)
        if not isinstance(items, list):
            error(errors, source, f"registry_extensions.{field}", "must be a list")
            continue
        for index, stable_id in enumerate(items):
            item_path = f"registry_extensions.{field}[{index}]"
            if not isinstance(stable_id, str) or not ID_PATTERN.fullmatch(stable_id):
                error(errors, source, item_path, "must be a lowercase dotted stable ID")
            elif not stable_id.startswith(f"{collection[:-1]}."):
                error(errors, source, item_path, f"must use the {collection[:-1]}. namespace")
            elif stable_id in core[collection]:
                error(errors, source, item_path, "must not redeclare a core ID")
            elif stable_id in result[collection]:
                error(errors, source, item_path, f"duplicates {stable_id}")
            else:
                result[collection].add(stable_id)
    return result


def collect_records(
    contract: dict[str, Any],
    collection: str,
    source: str,
    errors: list[str],
    seen_ids: set[str],
) -> dict[str, tuple[str, dict[str, Any]]]:
    records = contract.get(collection)
    if not isinstance(records, list):
        error(errors, source, f"product_contract.{collection}", "must be a list")
        return {}
    indexed: dict[str, tuple[str, dict[str, Any]]] = {}
    for index, record in enumerate(records):
        path = f"{collection}[{index}]"
        stable_id = validate_record(record, source, path, errors, seen_ids)
        if stable_id is not None and stable_id not in indexed and isinstance(record, dict):
            indexed[stable_id] = (path, record)
    return indexed


def validate_registry(
    indexed: dict[str, tuple[str, dict[str, Any]]],
    core_ids: set[str],
    extension_ids: set[str],
    collection: str,
    source: str,
    errors: list[str],
) -> None:
    for stable_id in sorted(core_ids.difference(indexed)):
        error(errors, source, f"product_contract.{collection}", f"requires core ID {stable_id}")
    for stable_id in sorted(set(indexed).difference(core_ids | extension_ids)):
        path, _ = indexed[stable_id]
        error(errors, source, f"{path}.id", "is not a core or declared extension ID")
    for stable_id in sorted(extension_ids.difference(indexed)):
        field = f"{collection[:-1]}_ids" if collection != "encounters" else "encounter_ids"
        error(errors, source, f"registry_extensions.{field}", f"declares missing {stable_id}")


def validate_difficulties(
    value: Any,
    source: str,
    errors: list[str],
    seen_ids: set[str],
) -> None:
    """Validate the closed, ordered difficulty identity registry without tuning."""
    path = "product_contract.difficulties"
    if not isinstance(value, list):
        error(errors, source, path, "must be a list")
        return

    present_ids: set[str] = set()
    for index, record in enumerate(value):
        record_path = f"difficulties[{index}]"
        stable_id = validate_record(record, source, record_path, errors, seen_ids)
        if isinstance(record, dict):
            validate_keys(
                record,
                COMMON_RECORD_FIELDS,
                COMMON_RECORD_FIELDS,
                source,
                record_path,
                errors,
            )
        if stable_id is None:
            continue
        present_ids.add(stable_id)
        if stable_id not in CORE_DIFFICULTY_IDS:
            error(errors, source, f"{record_path}.id", "is not a canonical difficulty ID")
        if index >= len(CORE_DIFFICULTY_IDS):
            error(errors, source, f"{record_path}.id", "is additional; the difficulty registry is closed")
        elif stable_id != CORE_DIFFICULTY_IDS[index]:
            expected = CORE_DIFFICULTY_IDS[index]
            error(errors, source, f"{record_path}.id", f"must be {expected} at canonical position {index}")

    for stable_id in CORE_DIFFICULTY_IDS:
        if stable_id not in present_ids:
            error(errors, source, path, f"requires core ID {stable_id}")


def validate_campaign(value: Any, source: str, errors: list[str], seen_ids: set[str]) -> None:
    fields = COMMON_RECORD_FIELDS | {"main_stage_ids", "extra_stage_id", "progression"}
    if not validate_keys(value, fields, fields, source, "campaign", errors):
        return
    if value.get("id") != "campaign.blade_main":
        error(errors, source, "campaign.id", "must be campaign.blade_main")
    main_ids = value.get("main_stage_ids")
    if not isinstance(main_ids, list):
        error(errors, source, "campaign.main_stage_ids", "must be a list")
    else:
        seen: set[str] = set()
        for index, stage_id in enumerate(main_ids):
            if not isinstance(stage_id, str):
                error(errors, source, f"campaign.main_stage_ids[{index}]", "must be a stable ID string")
            elif stage_id in seen:
                error(errors, source, f"campaign.main_stage_ids[{index}]", f"duplicates {stage_id}")
            else:
                seen.add(stage_id)
        if main_ids != list(MAIN_STAGE_IDS):
            error(errors, source, "campaign.main_stage_ids", "must list the six canonical stages in order")
        if value.get("extra_stage_id") in main_ids:
            error(errors, source, "campaign.extra_stage_id", "must be distinct from every main stage")
    if value.get("extra_stage_id") != EXTRA_STAGE_ID:
        error(errors, source, "campaign.extra_stage_id", f"must be {EXTRA_STAGE_ID}")
    progression = value.get("progression")
    progression_fields = COMMON_RECORD_FIELDS | set(PROGRESSION_VALUES)
    if validate_keys(progression, progression_fields, progression_fields, source, "campaign.progression", errors):
        validate_record(progression, source, "campaign.progression", errors, seen_ids)
        if progression.get("id") != "progression.blade_endings":
            error(errors, source, "campaign.progression.id", "must be progression.blade_endings")
        for field, expected in PROGRESSION_VALUES.items():
            if progression.get(field) != expected:
                error(errors, source, f"campaign.progression.{field}", f"must be {expected}")


def validate_geometry(value: Any, source: str, errors: list[str]) -> None:
    fields = COMMON_RECORD_FIELDS | {"logical_output", "gameplay_plane"}
    if not validate_keys(value, fields, fields, source, "runtime_geometry", errors):
        return
    if value.get("id") != "geometry.blade_playfield":
        error(errors, source, "runtime_geometry.id", "must be geometry.blade_playfield")
    output = value.get("logical_output")
    output_fields = {"width", "height"}
    if validate_keys(output, output_fields, output_fields, source, "runtime_geometry.logical_output", errors):
        if any(type(output.get(key)) is not int for key in output_fields) or output != {"width": 640, "height": 360}:
            error(errors, source, "runtime_geometry.logical_output", "must be 640x360")
    plane_fields = {
        "x_min", "x_max_exclusive", "y_min", "y_max_exclusive", "width", "height"
    } | set(GEOMETRY_POLICY)
    plane = value.get("gameplay_plane")
    if not validate_keys(plane, plane_fields, plane_fields, source, "runtime_geometry.gameplay_plane", errors):
        return
    expected_bounds = {
        "x_min": 185,
        "x_max_exclusive": 455,
        "y_min": 0,
        "y_max_exclusive": 360,
        "width": 270,
        "height": 360,
    }
    for field, expected in expected_bounds.items():
        if type(plane.get(field)) is not int or plane.get(field) != expected:
            error(errors, source, f"runtime_geometry.gameplay_plane.{field}", f"must be {expected}")
    for field, expected in GEOMETRY_POLICY.items():
        if plane.get(field) != expected:
            error(errors, source, f"runtime_geometry.gameplay_plane.{field}", f"must be {expected}")
    numeric = all(type(plane.get(field)) is int for field in expected_bounds)
    if numeric and plane["width"] != plane["x_max_exclusive"] - plane["x_min"]:
        error(errors, source, "runtime_geometry.gameplay_plane.width", "must equal x_max_exclusive - x_min")
    if numeric and plane["height"] != plane["y_max_exclusive"] - plane["y_min"]:
        error(errors, source, "runtime_geometry.gameplay_plane.height", "must equal y_max_exclusive - y_min")


def validate_ships(
    indexed: dict[str, tuple[str, dict[str, Any]]], source: str, errors: list[str]
) -> None:
    standard_fields = COMMON_RECORD_FIELDS | {"selection_status", "combat_role", "combat_identity"}
    kolar_fields = standard_fields | {"range_policy", "implementation_boundary", "resolution"}
    for stable_id, (path, ship) in indexed.items():
        allowed = kolar_fields if stable_id == "ship.kolar" else standard_fields
        validate_keys(ship, allowed, allowed, source, path, errors)
        if not nonempty_text(ship.get("combat_identity")):
            error(errors, source, f"{path}.combat_identity", "must be a nonempty string")
        if stable_id in CORE_SHIP_ROLES:
            if ship.get("selection_status") != "available":
                error(errors, source, f"{path}.selection_status", "must be available")
            expected_role = CORE_SHIP_ROLES[stable_id]
            if ship.get("combat_role") != expected_role:
                error(errors, source, f"{path}.combat_role", f"must be {expected_role}")
            if ship.get("combat_identity") != CORE_SHIP_IDENTITIES[stable_id]:
                error(errors, source, f"{path}.combat_identity", "must match the canonical ship identity")
        else:
            for field in ("selection_status", "combat_role"):
                if not nonempty_text(ship.get(field)):
                    error(errors, source, f"{path}.{field}", "must be a nonempty string")
    kolar_entry = indexed.get("ship.kolar")
    if kolar_entry is None:
        return
    path, kolar = kolar_entry
    range_policy = kolar.get("range_policy")
    range_fields = set(KOLAR_RANGE_POLICY)
    if validate_keys(range_policy, range_fields, range_fields, source, f"{path}.range_policy", errors):
        for field, expected in KOLAR_RANGE_POLICY.items():
            if range_policy.get(field) != expected:
                error(errors, source, f"{path}.range_policy.{field}", f"must be {expected}")
    boundary = kolar.get("implementation_boundary")
    boundary_fields = set(KOLAR_IMPLEMENTATION_BOUNDARY)
    if validate_keys(boundary, boundary_fields, boundary_fields, source, f"{path}.implementation_boundary", errors):
        for field, expected in KOLAR_IMPLEMENTATION_BOUNDARY.items():
            if boundary.get(field) != expected:
                error(errors, source, f"{path}.implementation_boundary.{field}", f"must be {expected}")
    if kolar.get("resolution") != KOLAR_RESOLUTION:
        error(errors, source, f"{path}.resolution", "must match the canonical implementation boundary summary")


def validate_stages_and_encounters(
    stages: dict[str, tuple[str, dict[str, Any]]],
    encounters: dict[str, tuple[str, dict[str, Any]]],
    source: str,
    errors: list[str],
) -> None:
    stage_fields = COMMON_RECORD_FIELDS | {"order", "environment", "encounter_ids"}
    encounter_fields = COMMON_RECORD_FIELDS | {"stage_id", "kind", "resolution"}
    stage_refs: dict[str, list[str]] = {}
    for stable_id, (path, stage) in stages.items():
        validate_keys(stage, stage_fields, stage_fields, source, path, errors)
        if not nonempty_text(stage.get("environment")):
            error(errors, source, f"{path}.environment", "must be a nonempty string")
        if stable_id in CORE_STAGE_ORDERS:
            expected_order = CORE_STAGE_ORDERS[stable_id]
            if type(stage.get("order")) is not type(expected_order) or stage.get("order") != expected_order:
                error(errors, source, f"{path}.order", f"must be {expected_order}")
        elif not (type(stage.get("order")) is int and stage["order"] > 0) and not nonempty_text(stage.get("order")):
            error(errors, source, f"{path}.order", "must be a positive integer or nonempty category")
        refs = stage.get("encounter_ids")
        if not isinstance(refs, list):
            error(errors, source, f"{path}.encounter_ids", "must be a list")
            stage_refs[stable_id] = []
            continue
        stage_refs[stable_id] = [ref for ref in refs if isinstance(ref, str)]
        seen: set[str] = set()
        for index, encounter_id in enumerate(refs):
            ref_path = f"{path}.encounter_ids[{index}]"
            if not isinstance(encounter_id, str):
                error(errors, source, ref_path, "must be a stable ID string")
            elif encounter_id in seen:
                error(errors, source, ref_path, f"duplicates {encounter_id}")
            else:
                seen.add(encounter_id)
            if isinstance(encounter_id, str) and encounter_id not in encounters:
                error(errors, source, ref_path, "is dangling")
            elif isinstance(encounter_id, str):
                target_stage = encounters[encounter_id][1].get("stage_id")
                if target_stage != stable_id:
                    error(errors, source, ref_path, f"targets an encounter assigned to {target_stage}")
    for stable_id, (path, encounter) in encounters.items():
        validate_keys(encounter, COMMON_RECORD_FIELDS | {"stage_id", "kind"}, encounter_fields, source, path, errors)
        stage_id = encounter.get("stage_id")
        if not isinstance(stage_id, str):
            error(errors, source, f"{path}.stage_id", "must be a stable ID string")
        elif stage_id not in stages:
            error(errors, source, f"{path}.stage_id", "is dangling")
        elif stable_id not in stage_refs.get(stage_id, []):
            error(errors, source, f"{path}.stage_id", "is not reciprocated by the declared stage")
        if not nonempty_text(encounter.get("kind")):
            error(errors, source, f"{path}.kind", "must be a nonempty string")
        if "resolution" in encounter and not nonempty_text(encounter.get("resolution")):
            error(errors, source, f"{path}.resolution", "must be a nonempty string")
        expected = CORE_ENCOUNTERS.get(stable_id)
        if expected is not None:
            expected_stage, expected_kind = expected
            if stage_id != expected_stage:
                error(errors, source, f"{path}.stage_id", f"must be {expected_stage}")
            if encounter.get("kind") != expected_kind:
                error(errors, source, f"{path}.kind", f"must be {expected_kind}")


def validate_contract(contract: Any, source: str = IN_MEMORY_SOURCE) -> list[str]:
    """Return stable source- and field-specific errors for a decoded contract."""
    errors: list[str] = []
    if not isinstance(contract, dict):
        return [f"{source}: product_contract: must be an object"]
    validate_keys(contract, REQUIRED_ROOT_FIELDS, ALLOWED_ROOT_FIELDS, source, "product_contract", errors)
    content_version = contract.get("content_version")
    parsed_content_version: tuple[int, int, int] | None = None
    if not isinstance(content_version, str) or not VERSION_PATTERN.fullmatch(content_version):
        error(errors, source, "product_contract.content_version", "must use major.minor.patch")
    else:
        parsed_content_version = tuple(int(part) for part in content_version.split("."))
        if parsed_content_version < CORE_CONTENT_VERSION:
            error(
                errors,
                source,
                "product_contract.content_version",
                f"must be at least {CORE_CONTENT_VERSION_TEXT}",
            )
    validate_id_grammar(contract.get("id_grammar"), source, errors)
    validate_text_table(
        contract.get("product_requirements"),
        PRODUCT_REQUIREMENT_FIELDS,
        source,
        "product_contract.product_requirements",
        errors,
    )
    seen_ids: set[str] = set()
    validate_record(contract, source, "product_contract", errors, seen_ids)
    if contract.get("id") != "contract.blade":
        error(errors, source, "product_contract.id", "must be contract.blade")
    project = contract.get("project")
    if validate_keys(project, COMMON_RECORD_FIELDS, COMMON_RECORD_FIELDS, source, "project", errors):
        validate_record(project, source, "project", errors, seen_ids)
        if project.get("id") != "project.blade_of_desires":
            error(errors, source, "project.id", "must be project.blade_of_desires")
    campaign = contract.get("campaign")
    validate_record(campaign, source, "campaign", errors, seen_ids)
    validate_campaign(campaign, source, errors, seen_ids)
    geometry = contract.get("runtime_geometry")
    validate_record(geometry, source, "runtime_geometry", errors, seen_ids)
    validate_geometry(geometry, source, errors)
    extensions = validate_extensions(contract.get("registry_extensions"), source, errors)
    if any(extensions.values()) and (
        parsed_content_version is None or parsed_content_version <= CORE_CONTENT_VERSION
    ):
        error(
            errors,
            source,
            "product_contract.content_version",
            f"must advance beyond {CORE_CONTENT_VERSION_TEXT} when registry extensions are declared",
        )
    ships = collect_records(contract, "ships", source, errors, seen_ids)
    stages = collect_records(contract, "stages", source, errors, seen_ids)
    encounters = collect_records(contract, "encounters", source, errors, seen_ids)
    validate_registry(ships, set(CORE_SHIP_ROLES), extensions["ships"], "ships", source, errors)
    validate_registry(stages, set(CORE_STAGE_ORDERS), extensions["stages"], "stages", source, errors)
    validate_registry(encounters, set(CORE_ENCOUNTERS), extensions["encounters"], "encounters", source, errors)
    validate_ships(ships, source, errors)
    validate_stages_and_encounters(stages, encounters, source, errors)
    validate_difficulties(contract.get("difficulties"), source, errors, seen_ids)
    return errors


def validate_file(path: Path) -> list[str]:
    """Load a contract file and report decoding or semantic errors."""
    try:
        contract = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        return [f"{path}: file: unreadable: {exc}"]
    except json.JSONDecodeError as exc:
        return [f"{path}: JSON: invalid: {exc.msg}"]
    return validate_contract(contract, source=str(path))


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
