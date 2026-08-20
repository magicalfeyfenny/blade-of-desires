import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.content.validate_product_contract import validate_contract, validate_file


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "content/product_contract.json"
MEMORY_SOURCE = "<in-memory>"


class ProductContractValidatorTests(unittest.TestCase):
    def load_contract(self):
        return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))

    def errors(self, contract):
        return validate_contract(contract)

    def assert_error(self, contract, field, reason):
        self.assertIn(f"{MEMORY_SOURCE}: {field}: {reason}", self.errors(contract))

    def ship(self, contract, stable_id):
        return next(ship for ship in contract["ships"] if ship["id"] == stable_id)

    def stage(self, contract, stable_id):
        return next(stage for stage in contract["stages"] if stage["id"] == stable_id)

    def encounter(self, contract, stable_id):
        return next(
            encounter for encounter in contract["encounters"] if encounter["id"] == stable_id
        )

    def test_repository_contract_is_valid_and_versioned(self):
        contract = self.load_contract()

        self.assertEqual(validate_file(CONTRACT_PATH), [])
        self.assertEqual(contract["schema_version"], 1)
        self.assertEqual(contract["content_version"], "1.1.0")
        self.assertEqual(contract["registry_extensions"]["schema_version"], 1)

    def test_diagnostics_bind_file_or_in_memory_source(self):
        contract = self.load_contract()
        contract["project"]["id"] = "project.invented"
        self.assert_error(contract, "project.id", "must be project.blade_of_desires")

        with tempfile.TemporaryDirectory() as directory:
            supplied_path = Path(directory) / "supplied-contract.json"
            supplied_path.write_text(json.dumps(contract), encoding="utf-8")
            errors = validate_file(supplied_path)

        self.assertTrue(errors)
        self.assertTrue(all(item.startswith(f"{supplied_path}: ") for item in errors))
        self.assertIn(
            f"{supplied_path}: project.id: must be project.blade_of_desires",
            errors,
        )

    def test_rejects_malformed_versions_and_ids(self):
        contract = self.load_contract()
        contract["schema_version"] = 2
        self.assert_error(contract, "product_contract.schema_version", "must be 1")

        contract = self.load_contract()
        contract["content_version"] = "next"
        self.assert_error(
            contract,
            "product_contract.content_version",
            "must use major.minor.patch",
        )

        contract = self.load_contract()
        contract["content_version"] = "1.0.0"
        self.assert_error(contract, "product_contract.content_version", "must be at least 1.1.0")

        contract = self.load_contract()
        contract["ships"][0]["id"] = "Ship Maynii"
        self.assert_error(
            contract,
            "ships[0].id",
            "must be a lowercase dotted stable ID",
        )

    def test_rejects_malformed_or_altered_id_grammar(self):
        mutations = [
            None,
            {},
            {"pattern": "", "collision_policy": "globally_unique_and_never_reused"},
            {"pattern": "anything", "collision_policy": "globally_unique_and_never_reused"},
            {"pattern": "^[a-z]+$", "collision_policy": None},
        ]
        for value in mutations:
            with self.subTest(value=value):
                contract = self.load_contract()
                contract["id_grammar"] = value
                self.assertTrue(self.errors(contract))

    def test_rejects_missing_empty_or_wrong_typed_product_requirements(self):
        for value in (None, {}, []):
            with self.subTest(value=value):
                contract = self.load_contract()
                contract["product_requirements"] = value
                self.assertTrue(self.errors(contract))

        for field in self.load_contract()["product_requirements"]:
            for value in (None, "", "   ", []):
                with self.subTest(field=field, value=value):
                    contract = self.load_contract()
                    contract["product_requirements"][field] = value
                    self.assert_error(
                        contract,
                        f"product_contract.product_requirements.{field}",
                        "must be a nonempty string",
                    )

    def test_requires_core_registry_and_rejects_undeclared_records(self):
        contract = self.load_contract()
        contract["ships"] = [ship for ship in contract["ships"] if ship["id"] != "ship.ciela"]
        self.assert_error(contract, "product_contract.ships", "requires core ID ship.ciela")

        contract = self.load_contract()
        invented = copy.deepcopy(contract["ships"][0])
        invented.update({"id": "ship.invented", "display_name": "Invented"})
        contract["ships"].append(invented)
        self.assert_error(contract, "ships[3].id", "is not a core or declared extension ID")

        contract = self.load_contract()
        contract["ships"].append(copy.deepcopy(contract["ships"][0]))
        self.assert_error(contract, "ships[3].id", "duplicates ship.maynii")

    def test_versioned_extension_rule_allows_only_declared_subordinate_records(self):
        contract = self.load_contract()
        extension = {
            "schema_version": 1,
            "id": "ship.guest",
            "display_name": "Guest",
            "selection_status": "available",
            "combat_role": "guest",
            "combat_identity": "Explicit extension fixture.",
        }
        contract["ships"].append(extension)
        contract["registry_extensions"]["ship_ids"].append("ship.guest")
        self.assert_error(
            contract,
            "product_contract.content_version",
            "must advance beyond 1.1.0 when registry extensions are declared",
        )
        contract["content_version"] = "1.1.1"
        self.assertEqual(self.errors(contract), [])

        contract["ships"][3]["combat_role"] = None
        self.assert_error(contract, "ships[3].combat_role", "must be a nonempty string")
        contract["ships"][3]["combat_role"] = "guest"

        contract["registry_extensions"]["ship_ids"].append("ship.guest")
        self.assert_error(
            contract,
            "registry_extensions.ship_ids[1]",
            "duplicates ship.guest",
        )

        contract = self.load_contract()
        contract["ending"] = {"id": "ending.invented"}
        self.assert_error(
            contract,
            "product_contract.ending",
            "is not declared by schema version 1",
        )

    def test_requires_canonical_project_campaign_and_stage_order(self):
        contract = self.load_contract()
        contract["id"] = "contract.invented"
        self.assert_error(contract, "product_contract.id", "must be contract.blade")

        contract = self.load_contract()
        contract["campaign"]["id"] = "campaign.invented"
        self.assert_error(contract, "campaign.id", "must be campaign.blade_main")

        contract = self.load_contract()
        contract["campaign"]["main_stage_ids"].reverse()
        self.assert_error(
            contract,
            "campaign.main_stage_ids",
            "must list the six canonical stages in order",
        )

        contract = self.load_contract()
        contract["campaign"]["main_stage_ids"][1] = contract["campaign"]["main_stage_ids"][0]
        self.assert_error(
            contract,
            "campaign.main_stage_ids[1]",
            f"duplicates {contract['campaign']['main_stage_ids'][0]}",
        )

        contract = self.load_contract()
        contract["campaign"]["extra_stage_id"] = contract["campaign"]["main_stage_ids"][0]
        self.assert_error(
            contract,
            "campaign.extra_stage_id",
            "must be distinct from every main stage",
        )

        contract = self.load_contract()
        contract["stages"][0]["order"] = True
        self.assert_error(contract, "stages[0].order", "must be 1")

    def test_rejects_rewritten_progression_policy(self):
        progression = self.load_contract()["campaign"]["progression"]
        for field in (
            "canonical_ending_condition",
            "continued_ending_condition",
            "extra_stage_unlock_condition",
            "extra_stage_story_condition",
        ):
            with self.subTest(field=field):
                contract = self.load_contract()
                contract["campaign"]["progression"][field] = "rewritten prose"
                self.assertTrue(
                    any(f"campaign.progression.{field}: must be" in item for item in self.errors(contract))
                )
        self.assertEqual(progression["extra_stage_unlock_condition"], "main_campaign_1cc_any_difficulty")

    def test_rejects_missing_or_altered_geometry_semantics(self):
        mutations = {
            "anchor_containment": None,
            "hurtbox_containment": "intersects_plane",
            "coordinate_grid": "floating_unspecified",
            "right_bottom_clamp": "greatest_representable",
            "containment": "inside somehow",
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                contract = self.load_contract()
                contract["runtime_geometry"]["gameplay_plane"][field] = value
                self.assertTrue(
                    any(f"runtime_geometry.gameplay_plane.{field}: must be" in item for item in self.errors(contract))
                )

        contract = self.load_contract()
        del contract["runtime_geometry"]["gameplay_plane"]["anchor_containment"]
        self.assert_error(
            contract,
            "runtime_geometry.gameplay_plane.anchor_containment",
            "is required",
        )

        contract = self.load_contract()
        contract["runtime_geometry"]["logical_output"]["width"] = 641
        self.assert_error(contract, "runtime_geometry.logical_output", "must be 640x360")

        contract = self.load_contract()
        contract["runtime_geometry"]["gameplay_plane"]["width"] = 269
        self.assert_error(
            contract,
            "runtime_geometry.gameplay_plane.width",
            "must equal x_max_exclusive - x_min",
        )

        for field, value in (("x_min", 185.0), ("y_min", False)):
            with self.subTest(field=field, value=value):
                contract = self.load_contract()
                contract["runtime_geometry"]["gameplay_plane"][field] = value
                expected = 185 if field == "x_min" else 0
                self.assert_error(
                    contract,
                    f"runtime_geometry.gameplay_plane.{field}",
                    f"must be {expected}",
                )

        contract = self.load_contract()
        contract["runtime_geometry"]["logical_output"]["width"] = 640.0
        self.assert_error(contract, "runtime_geometry.logical_output", "must be 640x360")

    def test_binds_all_three_ship_roles(self):
        expected = {
            "ship.maynii": "forward_tracking_all_rounder",
            "ship.ciela": "spread_specialist",
            "ship.kolar": "close_range_specialist",
        }
        for stable_id, role in expected.items():
            with self.subTest(stable_id=stable_id):
                contract = self.load_contract()
                ship = self.ship(contract, stable_id)
                ship["combat_role"] = "invented"
                index = contract["ships"].index(ship)
                self.assert_error(contract, f"ships[{index}].combat_role", f"must be {role}")

        contract = self.load_contract()
        self.ship(contract, "ship.kolar")["combat_identity"] = "Collision-only melee ship with zero ranged damage."
        self.assert_error(
            contract,
            "ships[2].combat_identity",
            "must match the canonical ship identity",
        )

    def test_binds_kolar_range_policy_and_rejects_forbidden_variants(self):
        contract = self.load_contract()
        kolar = self.ship(contract, "ship.kolar")
        self.assertEqual(kolar["selection_status"], "available")
        self.assertEqual(kolar["combat_role"], "close_range_specialist")
        self.assertEqual(kolar["range_policy"]["primary_strength"], "close_range_combat")
        self.assertEqual(kolar["range_policy"]["ranged_damage_requirement"], "meaningful")

        mutations = {
            "primary_strength": "collision_only",
            "ranged_damage_requirement": "negligible",
            "forbidden_interpretations": ["collision_only"],
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                contract = self.load_contract()
                self.ship(contract, "ship.kolar")["range_policy"][field] = value
                self.assertTrue(
                    any(f"ships[2].range_policy.{field}: must be" in item for item in self.errors(contract))
                )

        contract = self.load_contract()
        self.ship(contract, "ship.kolar")["selection_status"] = "deferred"
        self.assert_error(contract, "ships[2].selection_status", "must be available")

        contract = self.load_contract()
        self.ship(contract, "ship.kolar")["resolution"] = "Kolar is deferred and her role is unresolved."
        self.assert_error(
            contract,
            "ships[2].resolution",
            "must match the canonical implementation boundary summary",
        )

    def test_keeps_kolar_implementation_deferred_to_issue_23(self):
        for field in ("weapon", "melee", "emitters", "cadence", "damage", "loadout"):
            with self.subTest(field=field):
                contract = self.load_contract()
                self.ship(contract, "ship.kolar")[field] = "invented"
                self.assert_error(
                    contract,
                    f"ships[2].{field}",
                    "is not declared by schema version 1",
                )

        contract = self.load_contract()
        self.ship(contract, "ship.kolar")["implementation_boundary"]["delegated_issue"] = 24
        self.assertTrue(
            any("ships[2].implementation_boundary.delegated_issue: must be 23" in item for item in self.errors(contract))
        )

        contract = self.load_contract()
        self.ship(contract, "ship.kolar")["implementation_boundary"]["unresolved"].remove("final_balance")
        self.assertTrue(
            any("ships[2].implementation_boundary.unresolved: must be" in item for item in self.errors(contract))
        )

    def test_rejects_duplicate_dangling_and_cross_stage_references(self):
        contract = self.load_contract()
        contract["stages"][0]["encounter_ids"].append(contract["stages"][0]["encounter_ids"][0])
        duplicate_id = contract["stages"][0]["encounter_ids"][0]
        self.assert_error(contract, "stages[0].encounter_ids[2]", f"duplicates {duplicate_id}")

        contract = self.load_contract()
        contract["stages"][0]["encounter_ids"][0] = "encounter.missing"
        self.assert_error(contract, "stages[0].encounter_ids[0]", "is dangling")

        contract = self.load_contract()
        encounter = self.encounter(contract, "encounter.stage1.unchosen_elemental_fae")
        encounter["stage_id"] = contract["stages"][1]["id"]
        self.assertTrue(
            any("targets an encounter assigned to stage.stage2" in item for item in self.errors(contract))
        )

        contract = self.load_contract()
        removed_id = contract["stages"][0]["encounter_ids"].pop(0)
        removed = self.encounter(contract, removed_id)
        index = contract["encounters"].index(removed)
        self.assert_error(
            contract,
            f"encounters[{index}].stage_id",
            "is not reciprocated by the declared stage",
        )

    def test_requires_every_core_encounter_even_when_references_are_removed(self):
        contract = self.load_contract()
        removed_id = contract["stages"][0]["encounter_ids"].pop(0)
        contract["encounters"] = [
            encounter for encounter in contract["encounters"] if encounter["id"] != removed_id
        ]
        self.assert_error(
            contract,
            "product_contract.encounters",
            f"requires core ID {removed_id}",
        )

    def test_stage1_seam_no_longer_defers_kolar_role(self):
        contract = self.load_contract()
        encounter = self.encounter(contract, "encounter.stage1.unchosen_elemental_fae")

        self.assertIn("participant IDs remain unresolved", encounter["resolution"])
        self.assertNotIn("Kolar", encounter["resolution"])


if __name__ == "__main__":
    unittest.main()
