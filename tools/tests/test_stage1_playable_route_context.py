"""Exercise Stage 1 playable-route bindings against the selected schedule."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from tools.content.validate_stage_schedules import validate_catalog, validate_catalogs


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/stages/stage1_lost_forest_v1.json"
NEUTRAL_CATALOG_PATH = ROOT / "content/stages/neutral_v1.json"
PRODUCT_CONTRACT_PATH = ROOT / "content/product_contract.json"


class Stage1PlayableRouteContextTests(unittest.TestCase):
    """Pin the selector routes to one selection-aware Stage 1 fae duo."""

    def setUp(self) -> None:
        """Load detached canonical Stage 1 and product-contract fixtures."""
        self.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        self.product_contract = json.loads(
            PRODUCT_CONTRACT_PATH.read_text(encoding="utf-8")
        )

    def errors(self, catalog: dict | None = None) -> list[str]:
        """Validate one Stage 1 candidate against the canonical contract."""
        candidate = self.catalog if catalog is None else catalog
        return validate_catalog(
            candidate,
            source="stage1.json",
            product_contract=self.product_contract,
        )

    def clone(self) -> dict:
        """Return a detached Stage 1 catalog candidate."""
        return copy.deepcopy(self.catalog)

    def duo(self, catalog: dict) -> dict:
        """Return the selection-aware fae-duo encounter."""
        return next(
            encounter
            for encounter in catalog["encounters"]
            if encounter["id"] == "encounter_schedule.stage1.selected_fae_duo"
        )

    def test_canonical_routes_resolve_to_selected_schedule_and_two_slots(self):
        """Accept both complete playable routes in the canonical Stage 1 context."""
        self.assertEqual(self.errors(), [])

    def test_semantically_unordered_arrays_do_not_change_route_validity(self):
        """Use authored order fields rather than incidental JSON array order."""
        candidate = self.clone()
        candidate["stages"][0]["nodes"].reverse()
        encounter = self.duo(candidate)
        encounter["participants"].reverse()
        encounter["completion_predicate"]["participant_ids"].reverse()
        self.assertEqual(self.errors(candidate), [])

    def test_route_schedule_must_resolve_in_stage1_catalog(self):
        """Reject a catalog that silently replaces the selected route schedule."""
        candidate = self.clone()
        candidate["stages"][0]["id"] = "stage_schedule.stage1.unselected_forest"
        rendered = "\n".join(self.errors(candidate))
        self.assertIn("stage1_playable_routes[0].stage_schedule_id", rendered)
        self.assertIn("does not resolve in stage_catalog.stage1_lost_forest", rendered)
        self.assertEqual(
            rendered.count("does not resolve in stage_catalog.stage1_lost_forest"),
            1,
        )

    def test_stage1_route_content_requires_canonical_catalog_identity(self):
        """Reject a renamed catalog that still owns all canonical route content."""
        candidate = self.clone()
        candidate["id"] = "stage_catalog.stage1_renamed"
        rendered = "\n".join(self.errors(candidate))
        self.assertIn("catalog.id", rendered)
        self.assertIn("must be stage_catalog.stage1_lost_forest", rendered)

    def test_route_ownership_uses_catalog_membership_not_source_label(self):
        """Reject definitions moved to another catalog with the same source label."""
        stage1 = self.clone()
        other = json.loads(NEUTRAL_CATALOG_PATH.read_text(encoding="utf-8"))
        stage1["stages"][0], other["stages"][0] = (
            other["stages"][0],
            stage1["stages"][0],
        )
        duo_index = next(
            index
            for index, encounter in enumerate(stage1["encounters"])
            if encounter["id"] == "encounter_schedule.stage1.selected_fae_duo"
        )
        stage1["encounters"][duo_index], other["encounters"][0] = (
            other["encounters"][0],
            stage1["encounters"][duo_index],
        )
        rendered = "\n".join(
            validate_catalogs(
                [("same.json", stage1), ("same.json", other)],
                self.product_contract,
            )
        )
        self.assertIn("does not resolve in stage_catalog.stage1_lost_forest", rendered)
        self.assertIn("requires encounter_schedule.stage1.selected_fae_duo", rendered)

    def test_selected_schedule_must_spawn_then_wait_for_duo_once(self):
        """Reject a selected route that never waits for its owned duo to finish."""
        candidate = self.clone()
        wait_node = next(
            node
            for node in candidate["stages"][0]["nodes"]
            if node["kind"] == "wait_encounter_completion"
            and node["encounter_id"]
            == "encounter_schedule.stage1.selected_fae_duo"
        )
        wait_node["encounter_id"] = "encounter_schedule.stage1.midboss_carrier"
        rendered = "\n".join(self.errors(candidate))
        self.assertIn(".nodes", rendered)
        self.assertIn("must spawn then wait", rendered)

    def test_selected_duo_encounter_is_required_by_exact_id(self):
        """Reject a coherent-looking replacement for the canonical fae duo."""
        candidate = self.clone()
        old_id = "encounter_schedule.stage1.selected_fae_duo"
        new_id = "encounter_schedule.stage1.ambient_fae_duo"
        self.duo(candidate)["id"] = new_id
        for signal in candidate["signals"]:
            if signal["source"]["source_id"] == old_id:
                signal["source"]["source_id"] = new_id
        for node in candidate["stages"][0]["nodes"]:
            if node.get("encounter_id") == old_id:
                node["encounter_id"] = new_id
        rendered = "\n".join(self.errors(candidate))
        self.assertIn("catalog.encounters", rendered)
        self.assertIn("requires encounter_schedule.stage1.selected_fae_duo", rendered)

    def test_selected_duo_requires_both_ordered_participant_slots(self):
        """Reject a one-slot route even when its completion predicate is coherent."""
        candidate = self.clone()
        encounter = self.duo(candidate)
        encounter["participants"].pop()
        encounter["completion_predicate"]["participant_ids"].pop()
        rendered = "\n".join(self.errors(candidate))
        self.assertIn(".participants", rendered)
        self.assertIn("ordered fae slots A and B", rendered)

    def test_selected_duo_rejects_duplicate_slot_kinds(self):
        """Keep both runtime slots distinct even when spawn orders remain valid."""
        candidate = self.clone()
        encounter = self.duo(candidate)
        encounter["participants"][1]["kind_id"] = encounter["participants"][0][
            "kind_id"
        ]
        rendered = "\n".join(self.errors(candidate))
        self.assertIn(".participants", rendered)
        self.assertIn("ordered fae slots A and B", rendered)


if __name__ == "__main__":
    unittest.main()
