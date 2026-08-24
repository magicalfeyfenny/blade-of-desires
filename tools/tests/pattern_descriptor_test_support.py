"""Shared canonical fixtures for pattern descriptor validator tests."""

import copy
import json
import unittest
from pathlib import Path

from tools.content.validate_pattern_descriptors import validate_catalog


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/patterns/neutral_v1.json"
PRODUCT_CONTRACT_PATH = ROOT / "content/product_contract.json"
GOLDEN_PLAN_PATH = ROOT / "tools/tests/fixtures/pattern_descriptor_neutral_plan.json"


class PatternDescriptorTestCase(unittest.TestCase):
    """Provide canonical catalog construction and assertion helpers."""

    def load_catalog(self):
        """Return a detached copy of the checked-in neutral catalog."""
        return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    def load_product_contract(self):
        """Return a detached copy of the canonical product contract."""
        return json.loads(PRODUCT_CONTRACT_PATH.read_text(encoding="utf-8"))

    def descriptor(self, catalog, stable_id):
        """Return one descriptor from a catalog by stable ID."""
        return next(item for item in catalog["descriptors"] if item["id"] == stable_id)

    def child(self, pattern_id):
        """Return the one canonical normal-expiry child invocation."""
        return {
            "pattern_id": pattern_id,
            "trigger": "normal_expiry",
            "origin": "projectile_terminal_position",
        }

    def leaf_only_catalog(self):
        """Return a valid catalog containing only the neutral leaf descriptor."""
        catalog = self.load_catalog()
        catalog["descriptors"] = [
            copy.deepcopy(self.descriptor(catalog, "pattern.neutral_fixture.leaf"))
        ]
        return catalog

    def assert_error(self, catalog, *fragments):
        """Require one validation result to contain every diagnostic fragment."""
        rendered = "\n".join(validate_catalog(catalog))
        self.assertTrue(rendered, "expected validation to fail")
        for fragment in fragments:
            self.assertIn(fragment, rendered)

    def assert_valid(self, catalog):
        """Require a catalog to pass validation without diagnostics."""
        self.assertEqual(validate_catalog(catalog), [])

    def renamed_catalog(self, catalog, token):
        """Create an independent valid catalog with namespaced fixture IDs."""
        renamed = json.loads(json.dumps(catalog).replace("neutral_fixture", token))
        renamed["id"] = f"pattern_catalog.{token}"
        renamed["display_name"] = f"{token} catalog"
        return renamed

    def reverse_object_keys(self, value):
        """Recursively reverse object insertion order without changing values."""
        if isinstance(value, dict):
            return {
                key: self.reverse_object_keys(value[key])
                for key in reversed(tuple(value))
            }
        if isinstance(value, list):
            return [self.reverse_object_keys(item) for item in value]
        return value

    def expanded_catalog(self):
        """Return a valid catalog with sortable registries, tags, and speed tiers."""
        catalog = self.load_catalog()
        catalog["named_anchor_ids"].append("anchor.neutral_fixture.alternate")
        catalog["target_snapshot_ids"].append("target.neutral_fixture.alternate")
        catalog["aim_rule_ids"].append("aim_rule.neutral_fixture.alternate")
        catalog["bullet_kind_ids"].append("bullet_kind.neutral_fixture.alternate")
        catalog["theme_tag_ids"].append("theme.neutral_fixture.alternate")
        leaf = self.descriptor(catalog, "pattern.neutral_fixture.leaf")
        leaf["theme_tag_ids"] = [
            "theme.neutral_fixture.unstyled",
            "theme.neutral_fixture.alternate",
        ]
        leaf["speed_tiers_q10_per_tick"] = [3072, 1024, 2048]
        return catalog
