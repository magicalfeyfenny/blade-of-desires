"""Resolve stage catalog references and build deterministic normalized plans."""

from __future__ import annotations

from typing import Any


def _add_error(errors: list[str], source: str, path: str, reason: str) -> None:
    """Append one source- and field-bound diagnostic."""
    errors.append(f"{source}: {path}: {reason}")


def _typed_reference_matches(
    reference: dict[str, str] | None,
    definitions: dict[str, dict[str, Any]],
    id_field: str,
    type_field: str,
    source: str,
    path: str,
    errors: list[str],
) -> dict[str, Any] | None:
    """Resolve a typed reference and reject a mismatched declared type."""
    if reference is None:
        return None
    definition = definitions.get(reference[id_field])
    if definition is None:
        _add_error(
            errors,
            source,
            f"{path}.{id_field}",
            f"references undeclared ID {reference[id_field]}",
        )
        return None
    if reference[type_field] != definition[type_field]:
        _add_error(
            errors,
            source,
            f"{path}.{type_field}",
            f"must match {reference[id_field]} type {definition[type_field]}",
        )
        return None
    return definition


def _validate_typed_definitions(
    registries: dict[str, set[str]],
    task_ports: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    cues: dict[str, dict[str, Any]],
    encounters: dict[str, dict[str, Any]],
    errors: list[str],
) -> None:
    """Resolve task, signal, and cue types plus reciprocal signal producers."""
    for port_id in sorted(task_ports):
        port = task_ports[port_id]
        if port["type_id"] not in registries["task_type"]:
            _add_error(
                errors,
                port["source"],
                f"{port['path']}.type_id",
                f"references undeclared task type ID {port['type_id']}",
            )
        signal = _typed_reference_matches(
            port["completion_signal"],
            signals,
            "signal_id",
            "type_id",
            port["source"],
            f"{port['path']}.completion_signal",
            errors,
        )
        if signal is not None and signal["source_kind"] == "task_completion":
            if signal["source_id"] != port_id:
                _add_error(
                    errors,
                    port["source"],
                    f"{port['path']}.completion_signal.signal_id",
                    f"must reciprocate task port {port_id}",
                )
        elif signal is not None:
            _add_error(
                errors,
                port["source"],
                f"{port['path']}.completion_signal.signal_id",
                "must reference a task_completion signal",
            )
    for signal_id in sorted(signals):
        signal = signals[signal_id]
        if signal["type_id"] not in registries["signal_type"]:
            _add_error(
                errors,
                signal["source"],
                f"{signal['path']}.type_id",
                f"references undeclared signal type ID {signal['type_id']}",
            )
        source_kind = signal["source_kind"]
        source_id = signal["source_id"]
        if source_kind == "task_completion":
            definition = task_ports.get(source_id)
            reference = None if definition is None else definition["completion_signal"]
            if definition is None:
                reason = f"references undeclared task port ID {source_id}"
            elif reference is None or reference["signal_id"] != signal_id:
                reason = f"is not reciprocated by task port {source_id}"
            else:
                reason = None
        elif source_kind in {"encounter_started", "encounter_completed"}:
            definition = encounters.get(source_id)
            field = "started" if source_kind == "encounter_started" else "completed"
            reference = None if definition is None else definition["stage_signals"].get(field)
            if definition is None:
                reason = f"references undeclared encounter ID {source_id}"
            elif reference is None or reference["signal_id"] != signal_id:
                reason = f"is not reciprocated by encounter {source_id} {field} signal"
            else:
                reason = None
        else:
            reason = None
        if reason is not None:
            _add_error(errors, signal["source"], f"{signal['path']}.source.source_id", reason)
    for cue_id in sorted(cues):
        cue = cues[cue_id]
        if cue["type_id"] not in registries["cue_type"]:
            _add_error(
                errors,
                cue["source"],
                f"{cue['path']}.type_id",
                f"references undeclared cue type ID {cue['type_id']}",
            )


def _validate_encounters(
    encounters: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    participant_kinds: set[str],
    errors: list[str],
) -> None:
    """Validate participant order, all-defeated predicates, and lifecycle signals."""
    for encounter_id in sorted(encounters):
        encounter = encounters[encounter_id]
        source = encounter["source"]
        path = encounter["path"]
        participants = encounter["participants"]
        orders = [item["spawn_order"] for item in participants if item["spawn_order"] is not None]
        if sorted(orders) != list(range(len(participants))):
            _add_error(
                errors,
                source,
                f"{path}.participants",
                "spawn_order values must be unique and contiguous from 0",
            )
        for participant in participants:
            if participant["kind_id"] not in participant_kinds:
                _add_error(
                    errors,
                    participant["source"],
                    f"{participant['path']}.kind_id",
                    f"references undeclared participant kind ID {participant['kind_id']}",
                )
        expected_ids = {participant["id"] for participant in participants if participant["id"]}
        predicate_ids = encounter["completion_participant_ids"]
        if predicate_ids is not None and set(predicate_ids) != expected_ids:
            _add_error(
                errors,
                source,
                f"{path}.completion_predicate.participant_ids",
                "must contain every encounter participant ID exactly once",
            )
        lifecycle_ids: list[str] = []
        for field, source_kind in (
            ("started", "encounter_started"),
            ("completed", "encounter_completed"),
        ):
            reference = encounter["stage_signals"].get(field)
            signal = _typed_reference_matches(
                reference,
                signals,
                "signal_id",
                "type_id",
                source,
                f"{path}.stage_signals.{field}",
                errors,
            )
            if reference is not None:
                lifecycle_ids.append(reference["signal_id"])
            if signal is not None and (
                signal["source_kind"] != source_kind or signal["source_id"] != encounter_id
            ):
                _add_error(
                    errors,
                    source,
                    f"{path}.stage_signals.{field}.signal_id",
                    f"must reference the reciprocal {source_kind} signal",
                )
        if len(lifecycle_ids) == 2 and lifecycle_ids[0] == lifecycle_ids[1]:
            _add_error(
                errors,
                source,
                f"{path}.stage_signals.completed.signal_id",
                "must differ from the started signal",
            )


def _report_stage_graph(
    stage: dict[str, Any],
    encounters: dict[str, dict[str, Any]],
    task_ports: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    cues: dict[str, dict[str, Any]],
    anchors: dict[str, dict[str, Any]],
    plane: tuple[int, int, int, int],
    errors: list[str],
) -> None:
    """Validate one forward-only stage graph and its producer-before-wait state."""
    source = stage["source"]
    path = stage["path"]
    nodes = {node["id"]: node for node in stage["nodes"] if node["id"] is not None}
    ordered = sorted(
        (node for node in stage["nodes"] if node["content_order"] is not None),
        key=lambda item: (item["content_order"], item["id"] or ""),
    )
    orders = [node["content_order"] for node in ordered]
    if orders != list(range(len(stage["nodes"]))):
        _add_error(
            errors,
            source,
            f"{path}.nodes",
            "content_order values must be unique and contiguous from 0",
        )
    entry_id = stage["entry_node_id"]
    terminal_id = stage["terminal_node_id"]
    complete_ids = [node["id"] for node in stage["nodes"] if node["kind"] == "complete"]
    if entry_id not in nodes:
        _add_error(errors, source, f"{path}.entry_node_id", f"references missing node {entry_id}")
    elif nodes[entry_id]["content_order"] != 0:
        _add_error(errors, source, f"{path}.entry_node_id", "must reference content_order 0")
    if len(complete_ids) != 1:
        _add_error(errors, source, f"{path}.nodes", "must contain exactly one complete terminal")
    if terminal_id not in nodes:
        _add_error(
            errors, source, f"{path}.terminal_node_id", f"references missing node {terminal_id}"
        )
    elif nodes[terminal_id]["kind"] != "complete":
        _add_error(errors, source, f"{path}.terminal_node_id", "must reference the complete node")
    elif complete_ids and terminal_id != complete_ids[0]:
        _add_error(errors, source, f"{path}.terminal_node_id", "must name the sole complete node")
    for node in stage["nodes"]:
        next_id = node["next_node_id"]
        if next_id is None:
            continue
        target = nodes.get(next_id)
        if target is None:
            _add_error(
                errors,
                node["source"],
                f"{node['path']}.next_node_id",
                f"references missing node {next_id}",
            )
        elif node["content_order"] is not None and target["content_order"] is not None:
            if target["content_order"] <= node["content_order"]:
                _add_error(
                    errors,
                    node["source"],
                    f"{node['path']}.next_node_id",
                    f"creates an undeclared cycle or backward edge to {next_id}",
                )
    reachable: list[dict[str, Any]] = []
    visited: set[str] = set()
    current_id = entry_id
    while current_id in nodes and current_id not in visited:
        visited.add(current_id)
        node = nodes[current_id]
        reachable.append(node)
        current_id = node["next_node_id"]
        if current_id is None:
            break
    if current_id in visited:
        _add_error(
            errors,
            nodes[current_id]["source"],
            f"{nodes[current_id]['path']}.next_node_id",
            f"creates undeclared cycle through {current_id}",
        )
    for node_id in sorted(set(nodes).difference(visited)):
        node = nodes[node_id]
        _add_error(errors, node["source"], node["path"], "is unreachable from entry_node_id")
    if reachable and reachable[-1]["id"] != terminal_id:
        _add_error(errors, source, f"{path}.terminal_node_id", "is not reached by the stage path")
    _validate_stage_sequence(
        reachable, encounters, task_ports, signals, cues, anchors, plane, errors
    )


def _validate_stage_sequence(
    nodes: list[dict[str, Any]],
    encounters: dict[str, dict[str, Any]],
    task_ports: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    cues: dict[str, dict[str, Any]],
    anchors: dict[str, dict[str, Any]],
    plane: tuple[int, int, int, int],
    errors: list[str],
) -> None:
    """Prove references, spawn geometry, and each blocking producer in path order."""
    active_encounters: set[str] = set()
    requested_ports: set[str] = set()
    waited_signals: set[str] = set()
    spawned_ever: set[str] = set()
    for node in nodes:
        source = node["source"]
        path = node["path"]
        kind = node["kind"]
        if kind == "spawn_encounter":
            encounter_id = node["encounter_id"]
            encounter = encounters.get(encounter_id)
            anchor = anchors.get(node["anchor_id"])
            if encounter is None:
                _add_error(
                    errors,
                    source,
                    f"{path}.encounter_id",
                    f"references undeclared encounter {encounter_id}",
                )
            if anchor is None:
                _add_error(
                    errors,
                    source,
                    f"{path}.anchor_id",
                    f"references undeclared anchor {node['anchor_id']}",
                )
            if encounter_id in active_encounters:
                _add_error(
                    errors,
                    source,
                    f"{path}.encounter_id",
                    "cannot spawn a second generation before owned completion",
                )
            if encounter is not None and anchor is not None and node["offset"] is not None:
                _validate_spawn_points(node, encounter, anchor, plane, errors)
            active_encounters.add(encounter_id)
            spawned_ever.add(encounter_id)
        elif kind == "wait_encounter_completion":
            encounter_id = node["encounter_id"]
            if encounter_id not in encounters:
                _add_error(
                    errors,
                    source,
                    f"{path}.encounter_id",
                    f"references undeclared encounter {encounter_id}",
                )
            if encounter_id not in active_encounters:
                _add_error(
                    errors,
                    source,
                    f"{path}.encounter_id",
                    "has no preceding active encounter generation",
                )
            active_encounters.discard(encounter_id)
        elif kind == "request_task":
            port = _typed_reference_matches(
                node["task"], task_ports, "port_id", "type_id", source, f"{path}.task", errors
            )
            if port is not None:
                if port["id"] in requested_ports:
                    _add_error(
                        errors,
                        source,
                        f"{path}.task.port_id",
                        "cannot request a second generation before completion",
                    )
                requested_ports.add(port["id"])
        elif kind == "wait_signal":
            signal = _typed_reference_matches(
                node["signal"],
                signals,
                "signal_id",
                "type_id",
                source,
                f"{path}.signal",
                errors,
            )
            signal_id = None if node["signal"] is None else node["signal"]["signal_id"]
            if signal_id in waited_signals:
                _add_error(errors, source, f"{path}.signal.signal_id", "was already consumed")
            if signal_id is not None:
                waited_signals.add(signal_id)
            if signal is not None and signal["source_kind"] == "task_completion":
                if signal["source_id"] not in requested_ports:
                    _add_error(
                        errors,
                        source,
                        f"{path}.signal.signal_id",
                        "has no preceding pending task request",
                    )
                requested_ports.discard(signal["source_id"])
            elif signal is not None and signal["source_kind"] in {
                "encounter_started",
                "encounter_completed",
            }:
                encounter_id = signal["source_id"]
                if encounter_id not in spawned_ever:
                    _add_error(
                        errors,
                        source,
                        f"{path}.signal.signal_id",
                        "has no preceding encounter producer",
                    )
                if signal["source_kind"] == "encounter_completed":
                    active_encounters.discard(encounter_id)
        elif kind == "emit_presentation_cue":
            _typed_reference_matches(
                node["cue"], cues, "cue_id", "type_id", source, f"{path}.cue", errors
            )
    if nodes and nodes[-1]["kind"] == "complete":
        if active_encounters:
            _add_error(
                errors,
                nodes[-1]["source"],
                nodes[-1]["path"],
                f"cannot complete with active encounters {', '.join(sorted(active_encounters))}",
            )
        if requested_ports:
            _add_error(
                errors,
                nodes[-1]["source"],
                nodes[-1]["path"],
                f"cannot complete with pending task ports {', '.join(sorted(requested_ports))}",
            )


def _validate_spawn_points(
    node: dict[str, Any],
    encounter: dict[str, Any],
    anchor: dict[str, Any],
    plane: tuple[int, int, int, int],
    errors: list[str],
) -> None:
    """Require every anchor, node offset, and participant offset sum inside the plane."""
    x_min, x_max, y_min, y_max = plane
    for participant in encounter["participants"]:
        if participant["offset"] is None:
            continue
        x_q10 = anchor["x_q10"] + node["offset"]["x"] + participant["offset"]["x"]
        y_q10 = anchor["y_q10"] + node["offset"]["y"] + participant["offset"]["y"]
        if not (x_min <= x_q10 < x_max and y_min <= y_q10 < y_max):
            _add_error(
                errors,
                node["source"],
                f"{node['path']}.local_offset_q10",
                f"places participant {participant['id']} outside the product gameplay plane",
            )


def validate_context(
    catalogs: list[dict[str, Any]],
    registries: dict[str, set[str]],
    anchors: dict[str, dict[str, Any]],
    task_ports: dict[str, dict[str, Any]],
    signals: dict[str, dict[str, Any]],
    cues: dict[str, dict[str, Any]],
    stages: dict[str, dict[str, Any]],
    encounters: dict[str, dict[str, Any]],
    plane: tuple[int, int, int, int],
    errors: list[str],
) -> None:
    """Validate every cross-document reference and deterministic stage invariant."""
    _validate_typed_definitions(registries, task_ports, signals, cues, encounters, errors)
    _validate_encounters(encounters, signals, registries["participant_kind"], errors)
    for stage_id in sorted(stages):
        _report_stage_graph(
            stages[stage_id], encounters, task_ports, signals, cues, anchors, plane, errors
        )


def _normalize_typed_reference(
    value: dict[str, str], id_field: str
) -> dict[str, str]:
    """Copy one typed reference in its schema-defined field order."""
    return {id_field: value[id_field], "type_id": value["type_id"]}


def _normalize_source(signal: dict[str, Any]) -> dict[str, Any]:
    """Expand a signal source to one fixed nullable representation."""
    return {
        "kind": signal["source_kind"],
        "task_port_id": signal["source_id"] if signal["source_kind"] == "task_completion" else None,
        "encounter_id": (
            signal["source_id"]
            if signal["source_kind"] in {"encounter_started", "encounter_completed"}
            else None
        ),
    }


def _normalize_node(node: dict[str, Any]) -> dict[str, Any]:
    """Copy one validated stage node with stable variant field ordering."""
    result: dict[str, Any] = {
        "schema_version": 1,
        "id": node["id"],
        "display_name": node["display_name"],
        "content_order": node["content_order"],
        "kind": node["kind"],
    }
    kind = node["kind"]
    if kind == "wait":
        result["active_ticks"] = node["active_ticks"]
    elif kind == "spawn_encounter":
        result["encounter_id"] = node["encounter_id"]
        result["anchor_id"] = node["anchor_id"]
        result["local_offset_q10"] = dict(node["offset"])
    elif kind == "wait_encounter_completion":
        result["encounter_id"] = node["encounter_id"]
    elif kind == "request_task":
        result["task"] = _normalize_typed_reference(node["task"], "port_id")
    elif kind == "wait_signal":
        result["signal"] = _normalize_typed_reference(node["signal"], "signal_id")
    elif kind == "emit_presentation_cue":
        result["cue"] = _normalize_typed_reference(node["cue"], "cue_id")
    if kind != "complete":
        result["next_node_id"] = node["next_node_id"]
    return result


def normalize_catalog(catalog: dict[str, Any]) -> dict[str, Any]:
    """Build one detached catalog ordered by identities and explicit order fields."""
    return {
        "schema_version": 1,
        "id": catalog["id"],
        "display_name": catalog["display_name"],
        "named_anchors": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "x_q10": item["x_q10"],
                "y_q10": item["y_q10"],
            }
            for item in sorted(catalog["named_anchors"], key=lambda value: value["id"])
        ],
        "participant_kind_ids": sorted(catalog["participant_kind_ids"]),
        "task_type_ids": sorted(catalog["task_type_ids"]),
        "signal_type_ids": sorted(catalog["signal_type_ids"]),
        "cue_type_ids": sorted(catalog["cue_type_ids"]),
        "task_ports": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "type_id": item["type_id"],
                "completion_signal": _normalize_typed_reference(
                    item["completion_signal"], "signal_id"
                ),
            }
            for item in sorted(catalog["task_ports"], key=lambda value: value["id"])
        ],
        "signals": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "type_id": item["type_id"],
                "source": _normalize_source(item),
            }
            for item in sorted(catalog["signals"], key=lambda value: value["id"])
        ],
        "cues": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "type_id": item["type_id"],
            }
            for item in sorted(catalog["cues"], key=lambda value: value["id"])
        ],
        "stages": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "entry_node_id": item["entry_node_id"],
                "terminal_node_id": item["terminal_node_id"],
                "nodes": [
                    _normalize_node(node)
                    for node in sorted(item["nodes"], key=lambda value: value["content_order"])
                ],
            }
            for item in sorted(catalog["stages"], key=lambda value: value["id"])
        ],
        "encounters": [
            _normalize_encounter(item)
            for item in sorted(catalog["encounters"], key=lambda value: value["id"])
        ],
    }


def _normalize_encounter(encounter: dict[str, Any]) -> dict[str, Any]:
    """Copy one encounter with deterministic participant and predicate ordering."""
    participants = sorted(encounter["participants"], key=lambda item: item["spawn_order"])
    return {
        "schema_version": 1,
        "id": encounter["id"],
        "display_name": encounter["display_name"],
        "participants": [
            {
                "schema_version": 1,
                "id": item["id"],
                "display_name": item["display_name"],
                "kind_id": item["kind_id"],
                "spawn_order": item["spawn_order"],
                "local_offset_q10": dict(item["offset"]),
                "defeat_disposition": item["defeat_disposition"],
            }
            for item in participants
        ],
        "completion_predicate": {
            "kind": "all_participants_defeated",
            "participant_ids": [item["id"] for item in participants],
        },
        "cleanup_policy": {"on_completion": "cleanup.stage_end"},
        "stage_signals": {
            field: _normalize_typed_reference(encounter["stage_signals"][field], "signal_id")
            for field in ("started", "completed")
        },
    }
