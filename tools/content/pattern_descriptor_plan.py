"""Resolve pattern descriptor graphs and build deterministic normalized plans."""

from __future__ import annotations

from typing import Any


ABSOLUTE_SPAWN_CAP = 1_000_000


def _add_error(errors: list[str], source: str, path: str, reason: str) -> None:
    """Append one source- and field-bound diagnostic."""
    errors.append(f"{source}: {path}: {reason}")


def _child_pattern_id(descriptor: dict[str, Any]) -> str | None:
    """Return the referenced child pattern ID when a child invocation exists."""
    child = descriptor["child"]
    return None if child is None else child["pattern_id"]


def validate_references(
    descriptors: dict[str, dict[str, Any]],
    registries: dict[str, set[str]],
    errors: list[str],
) -> None:
    """Resolve every descriptor reference against all loaded catalog definitions."""
    for stable_id in sorted(descriptors):
        descriptor = descriptors[stable_id]
        source = descriptor["source"]
        path = descriptor["path"]
        origin = descriptor["origin"]
        if origin is not None and origin["kind"] == "named_anchor":
            anchor_id = origin["anchor_id"]
            if anchor_id is not None and anchor_id not in registries["anchor"]:
                _add_error(
                    errors,
                    source,
                    f"{path}.origin.anchor_id",
                    f"references undeclared anchor ID {anchor_id}",
                )
        aim = descriptor["aim"]
        if aim is not None and aim["kind"] == "target_snapshot":
            target_id = aim["target_id"]
            if target_id is not None and target_id not in registries["target"]:
                _add_error(
                    errors,
                    source,
                    f"{path}.aim.target_id",
                    f"references undeclared target snapshot ID {target_id}",
                )
        if aim is not None and aim["kind"] == "aim_rule":
            rule_id = aim["rule_id"]
            if rule_id is not None and rule_id not in registries["aim_rule"]:
                _add_error(
                    errors,
                    source,
                    f"{path}.aim.rule_id",
                    f"references undeclared aim rule ID {rule_id}",
                )
        bullet_kind_id = descriptor["bullet_kind_id"]
        if bullet_kind_id is not None and bullet_kind_id not in registries["bullet_kind"]:
            _add_error(
                errors,
                source,
                f"{path}.bullet_kind_id",
                f"references undeclared bullet kind ID {bullet_kind_id}",
            )
        if descriptor["theme_tag_ids"] is not None:
            for index, theme_id in enumerate(descriptor["theme_tag_ids"]):
                if theme_id not in registries["theme"]:
                    _add_error(
                        errors,
                        source,
                        f"{path}.theme_tag_ids[{index}]",
                        f"references undeclared theme tag ID {theme_id}",
                    )
        child_id = _child_pattern_id(descriptor)
        if descriptor["child_is_valid"] and child_id is not None and child_id not in descriptors:
            _add_error(
                errors,
                source,
                f"{path}.child.pattern_id",
                f"references missing child descriptor {child_id}",
            )


def report_cycles(
    descriptors: dict[str, dict[str, Any]], errors: list[str]
) -> set[str]:
    """Report each child-reference cycle once and return every cyclic descriptor ID."""
    visited: set[str] = set()
    cycle_nodes: set[str] = set()
    for start_id in sorted(descriptors):
        if start_id in visited:
            continue
        chain: list[str] = []
        positions: dict[str, int] = {}
        current_id: str | None = start_id
        while current_id is not None and current_id in descriptors and current_id not in visited:
            if current_id in positions:
                cycle = chain[positions[current_id] :]
                first_id = min(cycle)
                first_index = cycle.index(first_id)
                ordered_cycle = cycle[first_index:] + cycle[:first_index]
                descriptor = descriptors[first_id]
                _add_error(
                    errors,
                    descriptor["source"],
                    f"{descriptor['path']}.child.pattern_id",
                    f"creates recursive cycle {' -> '.join(ordered_cycle + [first_id])}",
                )
                cycle_nodes.update(cycle)
                break
            positions[current_id] = len(chain)
            chain.append(current_id)
            child_id = _child_pattern_id(descriptors[current_id])
            if not descriptors[current_id]["child_is_valid"] or child_id not in descriptors:
                current_id = None
            else:
                current_id = child_id
        visited.update(chain)
    return cycle_nodes


def compute_spawn_counts(
    descriptors: dict[str, dict[str, Any]],
    cycle_nodes: set[str],
    errors: list[str],
) -> dict[str, int]:
    """Compute bounded recursive spawn maxima and enforce both budget limits."""
    maximums: dict[str, int] = {}
    unresolved: set[str] = set(cycle_nodes)
    for start_id in sorted(descriptors):
        if start_id in maximums or start_id in unresolved:
            continue
        chain: list[str] = []
        current_id = start_id
        child_maximum: int | None = None
        while True:
            if current_id in maximums:
                child_maximum = maximums[current_id]
                break
            if current_id in unresolved:
                break
            descriptor = descriptors[current_id]
            if descriptor["direct_spawn_count"] is None or not descriptor["child_is_valid"]:
                break
            chain.append(current_id)
            child_id = _child_pattern_id(descriptor)
            if child_id is None:
                child_maximum = 0
                break
            if child_id not in descriptors:
                break
            current_id = child_id
        if child_maximum is None:
            unresolved.update(chain)
            continue
        for stable_id in reversed(chain):
            direct_count = descriptors[stable_id]["direct_spawn_count"]
            if direct_count > ABSOLUTE_SPAWN_CAP // (1 + child_maximum):
                total = ABSOLUTE_SPAWN_CAP + 1
            else:
                total = direct_count * (1 + child_maximum)
            maximums[stable_id] = total
            child_maximum = total
    for stable_id in sorted(maximums):
        descriptor = descriptors[stable_id]
        maximum = maximums[stable_id]
        source = descriptor["source"]
        path = descriptor["path"]
        if maximum > ABSOLUTE_SPAWN_CAP:
            _add_error(
                errors,
                source,
                f"{path}.spawn_budget",
                f"recursive maximum exceeds absolute cap {ABSOLUTE_SPAWN_CAP}",
            )
        budget = descriptor["spawn_budget"]
        if budget is not None and maximum > budget:
            if maximum > ABSOLUTE_SPAWN_CAP:
                reason = f"recursive maximum exceeds spawn_budget {budget}"
            else:
                reason = f"recursive maximum {maximum} exceeds spawn_budget {budget}"
            _add_error(errors, source, f"{path}.spawn_budget", reason)
    return maximums


def _angle_distribution(descriptor: dict[str, Any]) -> dict[str, str | None]:
    """Describe the deterministic authored-span distribution without expanding slots."""
    if descriptor["count"] == 1:
        return {"kind": "centered", "rounding": None}
    if descriptor["spread_millidegrees"] == 360_000:
        return {"kind": "full_turn_half_open", "rounding": "floor"}
    return {
        "kind": "centered_inclusive",
        "rounding": "floor_clockwise_remainder",
    }


def _normalize_descriptor(
    descriptor: dict[str, Any], maximum_spawn_count: int
) -> dict[str, Any]:
    """Build one detached descriptor plan with fixed fields and stable list ordering."""
    return {
        "schema_version": 1,
        "id": descriptor["id"],
        "display_name": descriptor["display_name"],
        "origin": {
            "kind": descriptor["origin"]["kind"],
            "anchor_id": descriptor["origin"]["anchor_id"],
        },
        "aim": {
            "kind": descriptor["aim"]["kind"],
            "angle_millidegrees": descriptor["aim"]["angle_millidegrees"],
            "target_id": descriptor["aim"]["target_id"],
            "rule_id": descriptor["aim"]["rule_id"],
        },
        "count": descriptor["count"],
        "local_angle_millidegrees": descriptor["local_angle_millidegrees"],
        "spread_millidegrees": descriptor["spread_millidegrees"],
        "angle_distribution": _angle_distribution(descriptor),
        "speed_tiers_q10_per_tick": sorted(descriptor["speed_tiers_q10_per_tick"]),
        "cadence_ticks": descriptor["cadence_ticks"],
        "repeat_count": descriptor["repeat_count"],
        "acceleration_q10_per_tick_squared": descriptor[
            "acceleration_q10_per_tick_squared"
        ],
        "friction_per_mille": descriptor["friction_per_mille"],
        "rotation_millidegrees_per_tick": descriptor["rotation_millidegrees_per_tick"],
        "lifetime_ticks": descriptor["lifetime_ticks"],
        "bullet_kind_id": descriptor["bullet_kind_id"],
        "theme_tag_ids": sorted(descriptor["theme_tag_ids"]),
        "cancellation_power": descriptor["cancellation_power"],
        "child": (
            None
            if descriptor["child"] is None
            else {
                "pattern_id": descriptor["child"]["pattern_id"],
                "trigger": descriptor["child"]["trigger"],
                "origin": descriptor["child"]["origin"],
            }
        ),
        "spawn_budget": descriptor["spawn_budget"],
        "direct_spawn_count": descriptor["direct_spawn_count"],
        "maximum_spawn_count": maximum_spawn_count,
    }


def normalize_catalog(
    catalog: dict[str, Any], maximums: dict[str, int]
) -> dict[str, Any]:
    """Build one detached catalog plan ordered only by stable identities."""
    descriptor_entries = sorted(catalog["descriptors"], key=lambda item: item["id"])
    return {
        "schema_version": 1,
        "id": catalog["id"],
        "display_name": catalog["display_name"],
        "named_anchor_ids": sorted(catalog["named_anchor_ids"]),
        "target_snapshot_ids": sorted(catalog["target_snapshot_ids"]),
        "aim_rule_ids": sorted(catalog["aim_rule_ids"]),
        "bullet_kind_ids": sorted(catalog["bullet_kind_ids"]),
        "theme_tag_ids": sorted(catalog["theme_tag_ids"]),
        "descriptors": [
            _normalize_descriptor(descriptor, maximums[descriptor["id"]])
            for descriptor in descriptor_entries
        ],
    }
