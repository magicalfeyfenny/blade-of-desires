"""Validate closed stage and encounter schedule record shapes."""

from __future__ import annotations

from typing import Any

if __package__:
    from .stage_schedule_plan import _add_error
    from .subordinate_product_contract import ID_PATTERN, ID_PATTERN_TEXT
else:
    from stage_schedule_plan import _add_error
    from subordinate_product_contract import ID_PATTERN, ID_PATTERN_TEXT


MAX_LINEAR_VALUE = 1_000_000
Q10_SCALE = 1_024
COMMON_RECORD_FIELDS = {"schema_version", "id", "display_name"}
CATALOG_FIELDS = COMMON_RECORD_FIELDS | {
    "product_contract",
    "named_anchors",
    "participant_kind_ids",
    "task_type_ids",
    "signal_type_ids",
    "cue_type_ids",
    "task_ports",
    "signals",
    "cues",
    "stages",
    "encounters",
}
REGISTRY_FIELDS = (
    ("participant_kind_ids", "participant_kind"),
    ("task_type_ids", "task_type"),
    ("signal_type_ids", "signal_type"),
    ("cue_type_ids", "cue_type"),
)
NODE_BASE_FIELDS = COMMON_RECORD_FIELDS | {"content_order", "kind"}
NODE_VARIANT_FIELDS = {
    "wait": {"active_ticks", "next_node_id"},
    "spawn_encounter": {"encounter_id", "anchor_id", "local_offset_q10", "next_node_id"},
    "wait_encounter_completion": {"encounter_id", "next_node_id"},
    "request_task": {"task", "next_node_id"},
    "wait_signal": {"signal", "next_node_id"},
    "emit_presentation_cue": {"cue", "next_node_id"},
    "complete": set(),
}


def _validate_object_keys(
    value: Any, fields: set[str], source: str, path: str, errors: list[str]
) -> bool:
    """Require an object with exactly the declared schema fields."""
    if not isinstance(value, dict):
        _add_error(errors, source, path, "must be an object")
        return False
    for key in sorted(fields.difference(value)):
        _add_error(errors, source, f"{path}.{key}", "is required")
    for key in sorted(set(value).difference(fields), key=str):
        _add_error(errors, source, f"{path}.{key}", "is not declared by schema version 1")
    return True


def _validate_schema_version(value: Any, source: str, path: str, errors: list[str]) -> None:
    """Accept only the exact integer schema version one."""
    if type(value) is not int or value != 1:
        _add_error(errors, source, path, "must be integer 1")


def _validate_display_name(
    value: Any, source: str, path: str, errors: list[str]
) -> str | None:
    """Return a nonempty display label without using it as identity."""
    if not isinstance(value, str) or not value.strip():
        _add_error(errors, source, path, "must be a nonempty string")
        return None
    return value


def _validate_stable_id(
    value: Any, namespace: str, source: str, path: str, errors: list[str]
) -> str | None:
    """Validate the shared stable-ID grammar and one required namespace."""
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
    """Claim one definition ID against product and subordinate definitions."""
    if stable_id is None:
        return False
    if stable_id in seen_ids:
        _add_error(errors, source, path, f"duplicates globally defined ID {stable_id}")
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
    """Validate one exact JSON integer inside inclusive limits."""
    if type(value) is not int or value < minimum or value > maximum:
        _add_error(errors, source, path, f"must be an integer from {minimum} through {maximum}")
        return None
    return value


def _validate_id_list(
    value: Any,
    namespace: str,
    source: str,
    path: str,
    errors: list[str],
    *,
    seen_ids: set[str] | None = None,
    require_nonempty: bool = False,
) -> list[str] | None:
    """Validate a unique stable-ID list and optionally claim its definitions."""
    if not isinstance(value, list) or (require_nonempty and not value):
        qualifier = "nonempty " if require_nonempty else ""
        _add_error(errors, source, path, f"must be a {qualifier}list")
        return None
    result: list[str] = []
    local_seen: set[str] = set()
    for index, item in enumerate(value):
        item_path = f"{path}[{index}]"
        stable_id = _validate_stable_id(item, namespace, source, item_path, errors)
        if stable_id is None:
            continue
        if stable_id in local_seen:
            _add_error(errors, source, item_path, f"duplicates {stable_id}")
            continue
        local_seen.add(stable_id)
        if seen_ids is None or _claim_id(stable_id, seen_ids, source, item_path, errors):
            result.append(stable_id)
    return result


def _validate_offset(value: Any, source: str, path: str, errors: list[str]) -> dict[str, int] | None:
    """Validate one bounded exact q10 local offset."""
    if not _validate_object_keys(value, {"x", "y"}, source, path, errors):
        return None
    x_value = _validate_integer(
        value.get("x"), -MAX_LINEAR_VALUE, MAX_LINEAR_VALUE, source, f"{path}.x", errors
    )
    y_value = _validate_integer(
        value.get("y"), -MAX_LINEAR_VALUE, MAX_LINEAR_VALUE, source, f"{path}.y", errors
    )
    if x_value is None or y_value is None:
        return None
    return {"x": x_value, "y": y_value}


def _validate_typed_reference(
    value: Any,
    id_field: str,
    namespace: str,
    type_namespace: str,
    source: str,
    path: str,
    errors: list[str],
) -> dict[str, str] | None:
    """Validate one exact stable ID plus stable type ID reference pair."""
    if not _validate_object_keys(value, {id_field, "type_id"}, source, path, errors):
        return None
    stable_id = _validate_stable_id(value.get(id_field), namespace, source, f"{path}.{id_field}", errors)
    type_id = _validate_stable_id(
        value.get("type_id"), type_namespace, source, f"{path}.type_id", errors
    )
    if stable_id is None or type_id is None:
        return None
    return {id_field: stable_id, "type_id": type_id}


def _validate_named_anchor(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    plane: tuple[int, int, int, int],
    anchors: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one exact in-plane q10 anchor definition."""
    fields = COMMON_RECORD_FIELDS | {"x_q10", "y_q10"}
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "anchor", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    display_name = _validate_display_name(value.get("display_name"), source, f"{path}.display_name", errors)
    x_q10 = _validate_integer(value.get("x_q10"), plane[0], plane[1] - 1, source, f"{path}.x_q10", errors)
    y_q10 = _validate_integer(value.get("y_q10"), plane[2], plane[3] - 1, source, f"{path}.y_q10", errors)
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": display_name,
        "x_q10": x_q10,
        "y_q10": y_q10,
    }
    if claimed and x_q10 is not None and y_q10 is not None:
        anchors[stable_id] = entry
    return entry


def _validate_task_port(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    task_ports: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one typed injected task-port definition."""
    fields = COMMON_RECORD_FIELDS | {"type_id", "completion_signal"}
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "task_port", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "type_id": _validate_stable_id(
            value.get("type_id"), "task_type", source, f"{path}.type_id", errors
        ),
        "completion_signal": _validate_typed_reference(
            value.get("completion_signal"),
            "signal_id",
            "signal",
            "signal_type",
            source,
            f"{path}.completion_signal",
            errors,
        ),
    }
    if claimed:
        task_ports[stable_id] = entry
    return entry


def _validate_signal(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    signals: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one typed signal and its closed producer-source variant."""
    fields = COMMON_RECORD_FIELDS | {"type_id", "source"}
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "signal", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    source_value = value.get("source")
    source_kind: str | None = None
    source_id: str | None = None
    if isinstance(source_value, dict):
        source_kind = source_value.get("kind")
    variants = {
        "external": (set(["kind"]), None),
        "task_completion": ({"kind", "source_id"}, "task_port"),
        "encounter_started": ({"kind", "source_id"}, "encounter_schedule"),
        "encounter_completed": ({"kind", "source_id"}, "encounter_schedule"),
    }
    if source_kind not in variants:
        _add_error(
            errors,
            source,
            f"{path}.source.kind",
            "must be external, task_completion, encounter_started, or encounter_completed",
        )
    else:
        variant_fields, namespace = variants[source_kind]
        _validate_object_keys(source_value, variant_fields, source, f"{path}.source", errors)
        if namespace is not None:
            source_id = _validate_stable_id(
                source_value.get("source_id"), namespace, source, f"{path}.source.source_id", errors
            )
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "type_id": _validate_stable_id(
            value.get("type_id"), "signal_type", source, f"{path}.type_id", errors
        ),
        "source_kind": source_kind,
        "source_id": source_id,
    }
    if claimed:
        signals[stable_id] = entry
    return entry


def _validate_cue(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    cues: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one typed semantic presentation-cue definition."""
    fields = COMMON_RECORD_FIELDS | {"type_id"}
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "cue", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "type_id": _validate_stable_id(
            value.get("type_id"), "cue_type", source, f"{path}.type_id", errors
        ),
    }
    if claimed:
        cues[stable_id] = entry
    return entry


def _validate_participant(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
) -> dict[str, Any] | None:
    """Validate one encounter-owned participant and deterministic spawn slot."""
    fields = COMMON_RECORD_FIELDS | {
        "kind_id",
        "spawn_order",
        "local_offset_q10",
        "defeat_disposition",
    }
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "participant", source, f"{path}.id", errors)
    _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    disposition = value.get("defeat_disposition")
    if disposition not in {"remove", "retain_harmless"}:
        _add_error(errors, source, f"{path}.defeat_disposition", "must be remove or retain_harmless")
        disposition = None
    return {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "kind_id": _validate_stable_id(
            value.get("kind_id"), "participant_kind", source, f"{path}.kind_id", errors
        ),
        "spawn_order": _validate_integer(
            value.get("spawn_order"), 0, MAX_LINEAR_VALUE, source, f"{path}.spawn_order", errors
        ),
        "offset": _validate_offset(value.get("local_offset_q10"), source, f"{path}.local_offset_q10", errors),
        "defeat_disposition": disposition,
    }


def _validate_encounter(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    encounters: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one encounter descriptor and collect participant definitions."""
    fields = COMMON_RECORD_FIELDS | {
        "participants",
        "completion_predicate",
        "cleanup_policy",
        "stage_signals",
    }
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "encounter_schedule", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    participants: list[dict[str, Any]] = []
    raw_participants = value.get("participants")
    if not isinstance(raw_participants, list) or not raw_participants:
        _add_error(errors, source, f"{path}.participants", "must be a nonempty list")
    else:
        for index, participant in enumerate(raw_participants):
            entry = _validate_participant(
                participant, source, f"{path}.participants[{index}]", errors, seen_ids
            )
            if entry is not None:
                participants.append(entry)
    predicate = value.get("completion_predicate")
    predicate_ids: list[str] | None = None
    if _validate_object_keys(
        predicate, {"kind", "participant_ids"}, source, f"{path}.completion_predicate", errors
    ):
        if predicate.get("kind") != "all_participants_defeated":
            _add_error(
                errors,
                source,
                f"{path}.completion_predicate.kind",
                "must be all_participants_defeated",
            )
        predicate_ids = _validate_id_list(
            predicate.get("participant_ids"),
            "participant",
            source,
            f"{path}.completion_predicate.participant_ids",
            errors,
            require_nonempty=True,
        )
    cleanup = value.get("cleanup_policy")
    if _validate_object_keys(cleanup, {"on_completion"}, source, f"{path}.cleanup_policy", errors):
        if cleanup.get("on_completion") != "cleanup.stage_end":
            _add_error(
                errors,
                source,
                f"{path}.cleanup_policy.on_completion",
                "must be cleanup.stage_end",
            )
    lifecycle = value.get("stage_signals")
    stage_signals: dict[str, dict[str, str]] = {}
    if _validate_object_keys(lifecycle, {"started", "completed"}, source, f"{path}.stage_signals", errors):
        for field in ("started", "completed"):
            reference = _validate_typed_reference(
                lifecycle.get(field),
                "signal_id",
                "signal",
                "signal_type",
                source,
                f"{path}.stage_signals.{field}",
                errors,
            )
            if reference is not None:
                stage_signals[field] = reference
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "participants": participants,
        "completion_participant_ids": predicate_ids,
        "stage_signals": stage_signals,
    }
    if claimed:
        encounters[stable_id] = entry
    return entry


def _validate_node(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
) -> dict[str, Any] | None:
    """Validate one closed node variant without executing schedule behavior."""
    kind = value.get("kind") if isinstance(value, dict) else None
    variant_fields = NODE_VARIANT_FIELDS.get(kind)
    if variant_fields is None:
        variant_fields = set()
    if not _validate_object_keys(value, NODE_BASE_FIELDS | variant_fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "stage_node", source, f"{path}.id", errors)
    _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    if kind not in NODE_VARIANT_FIELDS:
        _add_error(errors, source, f"{path}.kind", f"must be one of {', '.join(NODE_VARIANT_FIELDS)}")
        kind = None
    entry: dict[str, Any] = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "content_order": _validate_integer(
            value.get("content_order"), 0, MAX_LINEAR_VALUE, source, f"{path}.content_order", errors
        ),
        "kind": kind,
        "active_ticks": None,
        "encounter_id": None,
        "anchor_id": None,
        "offset": None,
        "task": None,
        "signal": None,
        "cue": None,
        "next_node_id": None,
    }
    if kind == "wait":
        entry["active_ticks"] = _validate_integer(
            value.get("active_ticks"), 1, MAX_LINEAR_VALUE, source, f"{path}.active_ticks", errors
        )
    elif kind in {"spawn_encounter", "wait_encounter_completion"}:
        entry["encounter_id"] = _validate_stable_id(
            value.get("encounter_id"),
            "encounter_schedule",
            source,
            f"{path}.encounter_id",
            errors,
        )
        if kind == "spawn_encounter":
            entry["anchor_id"] = _validate_stable_id(
                value.get("anchor_id"), "anchor", source, f"{path}.anchor_id", errors
            )
            entry["offset"] = _validate_offset(
                value.get("local_offset_q10"), source, f"{path}.local_offset_q10", errors
            )
    elif kind == "request_task":
        entry["task"] = _validate_typed_reference(
            value.get("task"), "port_id", "task_port", "task_type", source, f"{path}.task", errors
        )
    elif kind == "wait_signal":
        entry["signal"] = _validate_typed_reference(
            value.get("signal"),
            "signal_id",
            "signal",
            "signal_type",
            source,
            f"{path}.signal",
            errors,
        )
    elif kind == "emit_presentation_cue":
        entry["cue"] = _validate_typed_reference(
            value.get("cue"), "cue_id", "cue", "cue_type", source, f"{path}.cue", errors
        )
    if kind is not None and kind != "complete":
        entry["next_node_id"] = _validate_stable_id(
            value.get("next_node_id"), "stage_node", source, f"{path}.next_node_id", errors
        )
    return entry


def _validate_stage(
    value: Any,
    source: str,
    path: str,
    errors: list[str],
    seen_ids: set[str],
    stages: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    """Validate one stage schedule root and collect all stable node definitions."""
    fields = COMMON_RECORD_FIELDS | {"entry_node_id", "terminal_node_id", "nodes"}
    if not _validate_object_keys(value, fields, source, path, errors):
        return None
    _validate_schema_version(value.get("schema_version"), source, f"{path}.schema_version", errors)
    stable_id = _validate_stable_id(value.get("id"), "stage_schedule", source, f"{path}.id", errors)
    claimed = _claim_id(stable_id, seen_ids, source, f"{path}.id", errors)
    nodes: list[dict[str, Any]] = []
    raw_nodes = value.get("nodes")
    if not isinstance(raw_nodes, list) or not raw_nodes:
        _add_error(errors, source, f"{path}.nodes", "must be a nonempty list")
    else:
        for index, node in enumerate(raw_nodes):
            entry = _validate_node(node, source, f"{path}.nodes[{index}]", errors, seen_ids)
            if entry is not None:
                nodes.append(entry)
    entry = {
        "source": source,
        "path": path,
        "id": stable_id,
        "display_name": _validate_display_name(
            value.get("display_name"), source, f"{path}.display_name", errors
        ),
        "entry_node_id": _validate_stable_id(
            value.get("entry_node_id"), "stage_node", source, f"{path}.entry_node_id", errors
        ),
        "terminal_node_id": _validate_stable_id(
            value.get("terminal_node_id"), "stage_node", source, f"{path}.terminal_node_id", errors
        ),
        "nodes": nodes,
    }
    if claimed:
        stages[stable_id] = entry
    return entry
