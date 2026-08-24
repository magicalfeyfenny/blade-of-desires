"""Exercise stage graph, cross-catalog, and strict file-boundary validation."""

from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from tools.content.validate_stage_schedules import (
    main,
    validate_catalogs,
    validate_path,
)
from tools.tests.stage_schedule_test_support import (
    CATALOG_PATH,
    StageScheduleTestCase,
    normalize_catalogs,
)


class StageScheduleGraphContextTests(StageScheduleTestCase):
    """Pin product binding, graph proofs, typed producers, and strict loading."""

    def test_product_binding_is_closed_shared_and_authoritative(self):
        """Require every catalog to match the fully validated repository contract."""
        cases = []
        candidate = self.clone()
        candidate["product_contract"].pop("content_version")
        cases.append((candidate, "product_contract.content_version", "required"))
        candidate = self.clone()
        candidate["product_contract"]["extra"] = True
        cases.append((candidate, "product_contract.extra", "not declared"))
        candidate = self.clone()
        candidate["product_contract"]["content_version"] = "1.2.1"
        cases.append((candidate, "product_contract.content_version", "authoritative"))
        for catalog, path, reason in cases:
            with self.subTest(path=path):
                self.assert_error(catalog, path, reason)

        altered_product = self.clone(self.product_contract)
        altered_product["project"]["id"] = "project.invented"
        rendered = "\n".join(self.errors(product_contract=altered_product))
        self.assertIn("project.id", rendered)
        self.assertIn("project.blade_of_desires", rendered)

        alpha = self.renamed_catalog("alpha_binding")
        omega = self.renamed_catalog("omega_binding")
        omega["product_contract"]["content_version"] = "1.2.1"
        rendered = "\n".join(
            validate_catalogs([("alpha.json", alpha), ("omega.json", omega)], self.product_contract)
        )
        self.assertIn("omega.json", rendered)
        self.assertIn("authoritative product contract", rendered)

    def test_global_definitions_reject_local_and_cross_catalog_duplicates(self):
        """Do not let array position or catalog boundaries hide reused identities."""
        candidate = self.clone()
        candidate["signals"][1]["id"] = candidate["signals"][0]["id"]
        self.assert_error(candidate, "signals[1].id", "duplicates globally defined ID")

        alpha = self.renamed_catalog("alpha_duplicate")
        duplicate = self.clone(alpha)
        duplicate["id"] = "stage_catalog.omega_duplicate"
        rendered = "\n".join(
            validate_catalogs([("alpha.json", alpha), ("omega.json", duplicate)], self.product_contract)
        )
        self.assertIn("duplicates globally defined ID", rendered)

    def test_cross_catalog_typed_references_resolve_from_the_loaded_union(self):
        """Allow reusable definitions without permitting cross-catalog redeclaration."""
        alpha = self.renamed_catalog("alpha_union")
        omega = self.renamed_catalog("omega_union")
        cue_node = self.node("emit_presentation_cue", omega)
        cue_node["cue"] = {
            "cue_id": "cue.alpha_union.ready",
            "type_id": "cue_type.alpha_union.semantic",
        }
        errors = validate_catalogs(
            [("omega.json", omega), ("alpha.json", alpha)], self.product_contract
        )
        self.assertEqual(errors, [])
        plan = normalize_catalogs(
            [("omega.json", omega), ("alpha.json", alpha)], self.product_contract
        )
        self.assertEqual([item["id"] for item in plan["catalogs"]], sorted(item["id"] for item in plan["catalogs"]))

    def test_dangling_or_mistyped_anchor_encounter_task_signal_and_cue_fail(self):
        """Resolve every runtime-facing reference by exact stable ID and declared type."""
        cases = []
        candidate = self.clone()
        self.node("spawn_encounter", candidate)["anchor_id"] = "anchor.missing"
        cases.append((candidate, ".anchor_id", "undeclared anchor"))
        candidate = self.clone()
        self.node("spawn_encounter", candidate)["encounter_id"] = "encounter_schedule.missing"
        cases.append((candidate, ".encounter_id", "undeclared encounter"))
        candidate = self.clone()
        candidate["task_type_ids"].append("task_type.neutral_stage.other")
        self.node("request_task", candidate)["task"]["type_id"] = "task_type.neutral_stage.other"
        cases.append((candidate, ".task.type_id", "must match"))
        candidate = self.clone()
        candidate["signal_type_ids"].append("signal_type.neutral_stage.other")
        self.node("wait_signal", candidate)["signal"]["type_id"] = "signal_type.neutral_stage.other"
        cases.append((candidate, ".signal.type_id", "must match"))
        candidate = self.clone()
        candidate["cue_type_ids"].append("cue_type.neutral_stage.other")
        self.node("emit_presentation_cue", candidate)["cue"]["type_id"] = "cue_type.neutral_stage.other"
        cases.append((candidate, ".cue.type_id", "must match"))
        for catalog, path, reason in cases:
            with self.subTest(path=path):
                self.assert_error(catalog, path, reason)

    def test_task_and_encounter_lifecycle_signals_require_reciprocal_sources(self):
        """Reject signals whose producer declaration disagrees with the consumer record."""
        candidate = self.clone()
        task_signal = next(
            item for item in candidate["signals"] if item["source"]["kind"] == "task_completion"
        )
        task_signal["source"]["source_id"] = "task_port.missing"
        self.assert_error(candidate, ".source.source_id", "undeclared task port")

        candidate = self.clone()
        started = next(
            item for item in candidate["signals"] if item["source"]["kind"] == "encounter_started"
        )
        started["source"]["kind"] = "encounter_completed"
        self.assert_error(candidate, ".stage_signals.started.signal_id", "reciprocal encounter_started")

        candidate = self.clone()
        self.encounter(candidate)["stage_signals"]["completed"] = self.clone(
            self.encounter(candidate)["stage_signals"]["started"]
        )
        self.assert_error(candidate, ".stage_signals.completed.signal_id", "must differ")

    def test_stage_graph_requires_contiguous_order_forward_reachability_and_one_terminal(self):
        """Reject ambiguous order, dead nodes, backward cycles, and terminal confusion."""
        candidate = self.clone()
        self.stage(candidate)["nodes"][1]["content_order"] = 0
        self.assert_error(candidate, ".nodes", "unique and contiguous")

        candidate = self.clone()
        first = self.stage(candidate)["nodes"][0]
        first["next_node_id"] = self.stage(candidate)["nodes"][2]["id"]
        self.assert_error(candidate, "nodes[1]", "unreachable")

        candidate = self.clone()
        self.node("wait_signal", candidate)["next_node_id"] = self.stage(candidate)["entry_node_id"]
        self.assert_error(candidate, ".next_node_id", "undeclared cycle")

        candidate = self.clone()
        self.stage(candidate)["entry_node_id"] = self.stage(candidate)["nodes"][1]["id"]
        self.assert_error(candidate, ".entry_node_id", "content_order 0")

        candidate = self.clone()
        extra = {
            "schema_version": 1,
            "id": "stage_node.neutral_stage.extra_complete",
            "display_name": "Extra complete",
            "content_order": 8,
            "kind": "complete",
        }
        self.stage(candidate)["nodes"].append(extra)
        self.assert_error(candidate, ".nodes", "exactly one complete")

    def test_graph_rejects_dangling_next_and_nonterminal_terminal_pointer(self):
        """Require every next edge and the explicit terminal pointer to resolve exactly."""
        candidate = self.clone()
        self.node("wait", candidate)["next_node_id"] = "stage_node.missing"
        self.assert_error(candidate, ".next_node_id", "references missing node")

        candidate = self.clone()
        self.stage(candidate)["terminal_node_id"] = self.node("wait", candidate)["id"]
        self.assert_error(candidate, ".terminal_node_id", "complete node")

    def test_encounter_predicate_spawn_order_and_cleanup_are_fail_closed(self):
        """Make owned participant defeat the only possible encounter-success predicate."""
        candidate = self.clone()
        self.encounter(candidate)["completion_predicate"]["participant_ids"].pop()
        self.assert_error(candidate, ".completion_predicate.participant_ids", "every encounter participant")

        candidate = self.clone()
        self.encounter(candidate)["completion_predicate"]["kind"] = "global_enemy_count_zero"
        self.assert_error(candidate, ".completion_predicate.kind", "all_participants_defeated")

        candidate = self.clone()
        self.encounter(candidate)["participants"][1]["spawn_order"] = 0
        self.assert_error(candidate, ".participants", "unique and contiguous")

        candidate = self.clone()
        self.encounter(candidate)["cleanup_policy"]["on_completion"] = "outcome.defeated"
        self.assert_error(candidate, ".cleanup_policy.on_completion", "cleanup.stage_end")

        candidate = self.clone()
        self.encounter(candidate)["participants"][1]["defeat_disposition"] = "keep_dangerous"
        self.assert_error(candidate, ".defeat_disposition", "remove or retain_harmless")

    def test_every_final_participant_spawn_point_must_remain_in_plane(self):
        """Validate anchor plus node plus participant q10 offsets as one final point."""
        candidate = self.clone()
        candidate["named_anchors"][0]["x_q10"] = 189440
        self.node("spawn_encounter", candidate)["local_offset_q10"]["x"] = 0
        self.encounter(candidate)["participants"][0]["local_offset_q10"]["x"] = -1
        self.assert_error(candidate, ".local_offset_q10", "outside the product gameplay plane")

        candidate = self.clone()
        candidate["named_anchors"][0]["x_q10"] = 465919
        self.encounter(candidate)["participants"][1]["local_offset_q10"]["x"] = 1
        self.assert_error(candidate, ".local_offset_q10", "outside the product gameplay plane")

    def test_blocking_nodes_require_a_preceding_matching_producer(self):
        """Reject waits that could only be satisfied by ambient or stale generations."""
        candidate = self.clone()
        wait_ticks = self.node("wait", candidate)
        wait_ticks["next_node_id"] = self.node("wait_encounter_completion", candidate)["id"]
        rendered = "\n".join(self.errors(candidate))
        self.assertIn("no preceding active encounter generation", rendered)

        candidate = self.clone()
        wait_encounter = self.node("wait_encounter_completion", candidate)
        wait_encounter["next_node_id"] = self.node("wait_signal", candidate)["id"]
        rendered = "\n".join(self.errors(candidate))
        self.assertIn("no preceding pending task request", rendered)

        self.assertEqual(self.errors(), [])

    def test_pending_encounters_and_tasks_make_complete_impossible(self):
        """Require explicit owned completion before the sole stage terminal."""
        candidate = self.clone()
        spawn = self.node("spawn_encounter", candidate)
        spawn["next_node_id"] = self.stage(candidate)["terminal_node_id"]
        self.assertIn("active encounters", "\n".join(self.errors(candidate)))

        candidate = self.clone()
        request = self.node("request_task", candidate)
        request["next_node_id"] = self.stage(candidate)["terminal_node_id"]
        self.assertIn("pending task ports", "\n".join(self.errors(candidate)))

    def test_strict_json_rejects_duplicate_keys_and_nonstandard_numbers(self):
        """Fail before schema validation when JSON syntax can hide ambiguous values."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            duplicate = root / "duplicate.json"
            duplicate.write_text('{"schema_version":1,"schema_version":1}', encoding="utf-8")
            _, errors = validate_path(duplicate)
            self.assertIn("duplicate object key", "\n".join(errors))

            nonstandard = root / "nonstandard.json"
            nonstandard.write_text('{"schema_version":NaN}', encoding="utf-8")
            _, errors = validate_path(nonstandard)
            self.assertIn("nonstandard numeric constant", "\n".join(errors))

    def test_file_cli_and_empty_input_diagnostics_are_source_bound(self):
        """Keep default discovery and failure diagnostics deterministic and actionable."""
        self.assertIn("requires at least one", "\n".join(validate_catalogs([], self.product_contract)))
        plan, errors = validate_path(CATALOG_PATH)
        self.assertEqual(errors, [])
        self.assertEqual(plan, self.golden)

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = main([])
        self.assertEqual(result, 0)
        self.assertEqual(output.getvalue(), "")

        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.json"
            _, errors = validate_path(missing)
            self.assertIn(str(missing), "\n".join(errors))


if __name__ == "__main__":
    unittest.main()
