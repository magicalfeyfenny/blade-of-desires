"""Shared fixtures and assertions for stage schedule validator tests."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from tools.content.validate_stage_schedules import (
    normalize_catalog,
    normalize_catalogs,
    validate_catalog,
    validate_catalogs,
)


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/stages/neutral_v1.json"
PRODUCT_CONTRACT_PATH = ROOT / "content/product_contract.json"
GOLDEN_PATH = ROOT / "tools/tests/fixtures/stage_schedule_neutral_plan.json"


class StageScheduleTestCase(unittest.TestCase):
    """Provide detached canonical fixtures and source-bound error assertions."""

    maxDiff = None

    def setUp(self) -> None:
        """Load a fresh catalog, product contract, and normalized golden plan."""
        self.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        self.product_contract = json.loads(PRODUCT_CONTRACT_PATH.read_text(encoding="utf-8"))
        self.golden = json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))

    def errors(self, catalog=None, product_contract=None, source="fixture.json"):
        """Validate one supplied or fresh catalog with explicit product context."""
        candidate = self.catalog if catalog is None else catalog
        context = self.product_contract if product_contract is None else product_contract
        return validate_catalog(candidate, source=source, product_contract=context)

    def assert_error(self, catalog, path, reason, product_contract=None):
        """Require one diagnostic to contain both its field path and reason text."""
        rendered = "\n".join(self.errors(catalog, product_contract))
        self.assertIn(path, rendered)
        self.assertIn(reason, rendered)

    def normalize(self, catalog=None, product_contract=None):
        """Normalize one supplied or fresh catalog through explicit product context."""
        candidate = self.catalog if catalog is None else catalog
        context = self.product_contract if product_contract is None else product_contract
        return normalize_catalog(candidate, product_contract=context)

    def stage(self, catalog=None):
        """Return the sole neutral stage from a supplied or fresh catalog."""
        candidate = self.catalog if catalog is None else catalog
        return candidate["stages"][0]

    def encounter(self, catalog=None):
        """Return the sole neutral encounter from a supplied or fresh catalog."""
        candidate = self.catalog if catalog is None else catalog
        return candidate["encounters"][0]

    def node(self, kind, catalog=None):
        """Return the first node with the requested closed kind token."""
        for node in self.stage(catalog)["nodes"]:
            if node["kind"] == kind:
                return node
        raise AssertionError(f"missing node kind {kind}")

    def renamed_catalog(self, token):
        """Create a globally disjoint equivalent catalog for union-order tests."""
        rendered = json.dumps(self.catalog).replace("neutral_stage", token)
        catalog = json.loads(rendered)
        catalog["id"] = f"stage_catalog.{token}"
        catalog["display_name"] = f"{token} catalog"
        catalog["stages"][0]["id"] = f"stage_schedule.{token}"
        catalog["stages"][0]["display_name"] = f"{token} stage"
        return catalog

    def clone(self, value=None):
        """Return a deep copy of the supplied value or canonical catalog."""
        return copy.deepcopy(self.catalog if value is None else value)


__all__ = [
    "CATALOG_PATH",
    "GOLDEN_PATH",
    "ROOT",
    "StageScheduleTestCase",
    "normalize_catalogs",
    "validate_catalogs",
]
