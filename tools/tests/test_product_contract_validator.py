import copy
import json
import unittest
from pathlib import Path

from tools.content.validate_product_contract import validate_contract, validate_file


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "content/product_contract.json"


class ProductContractValidatorTests(unittest.TestCase):
    def load_contract(self):
        return json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))

    def test_repository_contract_is_valid(self):
        self.assertEqual(validate_file(CONTRACT_PATH), [])

    def test_rejects_wrong_schema_version_with_field_context(self):
        contract = self.load_contract()
        contract["schema_version"] = 2

        self.assertIn(
            "product_contract: schema_version: must be 1",
            validate_contract(contract),
        )

        contract = self.load_contract()
        contract["content_version"] = "next"
        self.assertIn(
            "product_contract: content_version: must use major.minor.patch",
            validate_contract(contract),
        )

    def test_rejects_duplicate_or_invalid_stable_ids(self):
        duplicate = self.load_contract()
        duplicate["ships"].append(copy.deepcopy(duplicate["ships"][0]))
        self.assertTrue(
            any("duplicates ship.maynii" in item for item in validate_contract(duplicate))
        )

        invalid = self.load_contract()
        invalid["ships"][0]["id"] = "Ship Maynii"
        self.assertTrue(
            any(
                "ships[0]: id: must be a lowercase dotted stable ID" == item
                for item in validate_contract(invalid)
            )
        )

    def test_rejects_dangling_references(self):
        contract = self.load_contract()
        contract["stages"][0]["encounter_ids"][0] = "encounter.missing"

        self.assertIn(
            "stages[0]: encounter_ids[0]: is dangling",
            validate_contract(contract),
        )

    def test_rejects_inconsistent_geometry(self):
        contract = self.load_contract()
        contract["runtime_geometry"]["gameplay_plane"]["x_max_exclusive"] = 456

        self.assertIn(
            "runtime_geometry: gameplay_plane: must be the centered [185,455) x [0,360) 270x360 plane",
            validate_contract(contract),
        )

    def test_rejects_a_kolar_loadout(self):
        contract = self.load_contract()
        contract["ships"][2]["weapon_id"] = "weapon.kolar_laser"

        self.assertIn(
            "ship.kolar: weapon_id: must remain unresolved",
            validate_contract(contract),
        )
