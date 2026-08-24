"""Exercise closed stage schema variants and deterministic normalization."""

from __future__ import annotations

import json
import random
import unittest

from tools.content.validate_stage_schedules import validate_and_normalize_catalogs
from tools.tests.stage_schedule_test_support import (
    GOLDEN_PATH,
    StageScheduleTestCase,
    normalize_catalogs,
)


class StageScheduleSchemaNormalizationTests(StageScheduleTestCase):
    """Pin every version-one shape, range, and normalized ordering rule."""

    def test_checked_in_catalog_validates_and_matches_exact_golden(self):
        """Keep canonical content and the byte-oriented normalized fixture aligned."""
        self.assertEqual(self.errors(), [])
        plan = self.normalize()
        self.assertEqual(plan, self.golden)
        rendered = json.dumps(plan, indent=2) + "\n"
        self.assertEqual(rendered, GOLDEN_PATH.read_text(encoding="utf-8"))

    def test_catalog_and_record_shapes_are_closed_and_versioned(self):
        """Reject missing, invented, and wrong-version fields at each record layer."""
        cases = []
        candidate = self.clone()
        candidate["extra"] = True
        cases.append((candidate, "catalog.extra", "not declared"))
        candidate = self.clone()
        candidate.pop("cues")
        cases.append((candidate, "catalog.cues", "required"))
        candidate = self.clone()
        candidate["schema_version"] = True
        cases.append((candidate, "catalog.schema_version", "integer 1"))
        candidate = self.clone()
        self.stage(candidate)["nodes"][0]["payload"] = {}
        cases.append((candidate, "nodes[0].payload", "not declared"))
        candidate = self.clone()
        self.encounter(candidate)["participants"][0]["schema_version"] = 2
        cases.append((candidate, "participants[0].schema_version", "integer 1"))
        for catalog, path, reason in cases:
            with self.subTest(path=path):
                self.assert_error(catalog, path, reason)

    def test_display_names_are_required_but_never_resolve_identity(self):
        """Require labels while keeping all graph and type references ID-owned."""
        candidate = self.clone()
        candidate["display_name"] = " "
        self.assert_error(candidate, "catalog.display_name", "nonempty string")

        renamed = self.clone()
        renamed["display_name"] = "Changed catalog label"
        self.stage(renamed)["display_name"] = "Changed stage label"
        self.node("spawn_encounter", renamed)["display_name"] = "Changed spawn label"
        self.assertEqual(self.errors(renamed), [])
        self.assertEqual(
            self.normalize(renamed)["catalogs"][0]["stages"][0]["id"],
            "stage_schedule.neutral_fixture",
        )

    def test_every_definition_and_reference_uses_its_exact_namespace(self):
        """Reject malformed IDs and namespace substitutions before graph resolution."""
        cases = []
        candidate = self.clone()
        candidate["id"] = "Stage Catalog"
        cases.append((candidate, "catalog.id", "lowercase dotted"))
        candidate = self.clone()
        candidate["named_anchors"][0]["id"] = "signal.neutral_stage.anchor"
        cases.append((candidate, "named_anchors[0].id", "anchor. namespace"))
        candidate = self.clone()
        self.node("request_task", candidate)["task"]["port_id"] = "signal.neutral_stage.task"
        cases.append((candidate, ".task.port_id", "task_port. namespace"))
        candidate = self.clone()
        self.encounter(candidate)["participants"][0]["id"] = "participant"
        cases.append((candidate, "participants[0].id", "lowercase dotted"))
        for catalog, path, reason in cases:
            with self.subTest(path=path):
                self.assert_error(catalog, path, reason)

    def test_integer_fields_reject_booleans_and_out_of_range_values(self):
        """Keep q10 coordinates, offsets, orders, and waits exact and bounded."""
        cases = []
        candidate = self.clone()
        candidate["named_anchors"][0]["x_q10"] = True
        cases.append((candidate, "x_q10", "integer"))
        candidate = self.clone()
        candidate["named_anchors"][0]["x_q10"] = 465920
        cases.append((candidate, "x_q10", "465919"))
        candidate = self.clone()
        self.node("wait", candidate)["active_ticks"] = 0
        cases.append((candidate, "active_ticks", "1 through 1000000"))
        candidate = self.clone()
        self.node("spawn_encounter", candidate)["local_offset_q10"]["x"] = 1000001
        cases.append((candidate, "local_offset_q10.x", "-1000000 through 1000000"))
        candidate = self.clone()
        self.encounter(candidate)["participants"][0]["spawn_order"] = False
        cases.append((candidate, "spawn_order", "integer"))
        for catalog, path, reason in cases:
            with self.subTest(path=path):
                self.assert_error(catalog, path, reason)

    def test_all_seven_node_variants_have_one_exact_shape(self):
        """Exercise every bounded node vocabulary member and reject variant leakage."""
        normalized = self.normalize()["catalogs"][0]["stages"][0]["nodes"]
        self.assertEqual(
            [node["kind"] for node in normalized],
            [
                "emit_presentation_cue",
                "wait",
                "spawn_encounter",
                "wait_encounter_completion",
                "request_task",
                "wait_signal",
                "wait_signal",
                "complete",
            ],
        )
        candidate = self.clone()
        self.node("complete", candidate)["next_node_id"] = self.stage(candidate)["entry_node_id"]
        self.assert_error(candidate, ".next_node_id", "not declared")
        candidate = self.clone()
        self.node("request_task", candidate)["payload"] = {"freeform": True}
        self.assert_error(candidate, ".payload", "not declared")
        candidate = self.clone()
        self.node("wait", candidate)["kind"] = "timeline"
        self.assert_error(candidate, ".kind", "must be one of")

    def test_typed_references_preserve_exact_id_and_type_pairs(self):
        """Normalize port, signal, and cue pairs without display or string inference."""
        catalog = self.normalize()["catalogs"][0]
        self.assertEqual(
            catalog["task_ports"][0]["completion_signal"],
            {
                "signal_id": "signal.neutral_stage.task_completed",
                "type_id": "signal_type.neutral_stage.task_completion",
            },
        )
        nodes = {node["kind"]: node for node in catalog["stages"][0]["nodes"]}
        self.assertEqual(
            nodes["request_task"]["task"],
            {
                "port_id": "task_port.neutral_stage.probe",
                "type_id": "task_type.neutral_stage.probe",
            },
        )
        self.assertEqual(
            nodes["emit_presentation_cue"]["cue"],
            {"cue_id": "cue.neutral_stage.ready", "type_id": "cue_type.neutral_stage.semantic"},
        )

    def test_normalization_ignores_authored_order_except_explicit_order_fields(self):
        """Sort unordered definitions while retaining content and spawn semantics."""
        shuffled = self.clone()
        for field in (
            "participant_kind_ids",
            "task_type_ids",
            "signal_type_ids",
            "cue_type_ids",
            "named_anchors",
            "task_ports",
            "signals",
            "cues",
            "stages",
            "encounters",
        ):
            shuffled[field].reverse()
        self.stage(shuffled)["nodes"].reverse()
        self.encounter(shuffled)["participants"].reverse()
        self.encounter(shuffled)["completion_predicate"]["participant_ids"].reverse()
        self.assertEqual(self.normalize(shuffled), self.golden)

        alpha = self.renamed_catalog("alpha_stage")
        omega = self.renamed_catalog("omega_stage")
        first = normalize_catalogs(
            [("z.json", omega), ("a.json", alpha)], self.product_contract
        )
        second = normalize_catalogs(
            [("a.json", alpha), ("z.json", omega)], self.product_contract
        )
        self.assertEqual(first, second)
        self.assertEqual(
            [catalog["id"] for catalog in first["catalogs"]],
            ["stage_catalog.alpha_stage", "stage_catalog.omega_stage"],
        )

    def test_normalized_output_is_detached_from_all_supplied_documents(self):
        """Prevent later caller mutation from changing a previously accepted plan."""
        supplied = self.clone()
        product = self.clone(self.product_contract)
        plan, errors = validate_and_normalize_catalogs([("fixture.json", supplied)], product)
        self.assertEqual(errors, [])
        supplied["signals"][0]["display_name"] = "mutated"
        product["id"] = "contract.mutated"
        self.assertEqual(plan, self.golden)

    def test_validation_and_normalization_are_data_only_and_rng_neutral(self):
        """Produce plain detached data without consuming ambient Python RNG state."""
        before = random.getstate()
        plan = self.normalize()
        after = random.getstate()
        self.assertEqual(before, after)
        self.assertIsInstance(plan, dict)
        json.dumps(plan, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
