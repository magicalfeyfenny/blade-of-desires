"""Test pattern descriptor schema validation and stable normalization."""

import copy
import json
import random

from tools.content.validate_pattern_descriptors import (
    normalize_catalog,
    normalize_catalogs,
    validate_path,
)
from tools.tests.pattern_descriptor_test_support import (
    CATALOG_PATH,
    GOLDEN_PLAN_PATH,
    PatternDescriptorTestCase,
)


class PatternDescriptorSchemaNormalizationTests(PatternDescriptorTestCase):
    """Exercise the closed descriptor schema and canonical plan representation."""

    def test_checked_in_catalog_validates_and_normalizes(self):
        """The repository catalog matches its exact ordered golden plan."""
        catalog = self.load_catalog()
        file_plan, errors = validate_path(CATALOG_PATH)
        direct_plan = normalize_catalog(catalog)

        self.assertEqual(errors, [])
        self.assertEqual(file_plan, direct_plan)
        self.assertEqual(
            json.dumps(file_plan, indent=2) + "\n",
            GOLDEN_PLAN_PATH.read_text(encoding="utf-8"),
        )
        self.assertEqual(
            direct_plan["product_contract"],
            {"id": "contract.blade", "content_version": "1.3.0"},
        )
        normalized_catalog = direct_plan["catalogs"][0]
        self.assertEqual(normalized_catalog["id"], "pattern_catalog.neutral_fixture")
        self.assertEqual(
            [item["id"] for item in normalized_catalog["descriptors"]],
            [
                "pattern.neutral_fixture.leaf",
                "pattern.neutral_fixture.parent",
            ],
        )
        leaf, parent = normalized_catalog["descriptors"]
        self.assertEqual((leaf["direct_spawn_count"], leaf["maximum_spawn_count"]), (2, 2))
        self.assertEqual(
            (parent["direct_spawn_count"], parent["maximum_spawn_count"]),
            (2, 6),
        )

    def test_display_names_are_required_but_do_not_replace_stable_ids(self):
        """Presentation names remain required metadata independent of identity."""
        catalog = self.load_catalog()
        del catalog["display_name"]
        self.assert_error(catalog, "catalog.display_name", "required")

        catalog = self.load_catalog()
        catalog["descriptors"][0]["display_name"] = "   "
        self.assert_error(catalog, "descriptors[0].display_name", "nonempty")

        catalog = self.load_catalog()
        baseline_ids = [
            item["id"] for item in normalize_catalog(catalog)["catalogs"][0]["descriptors"]
        ]
        catalog["display_name"] = "Renamed fixture catalog"
        catalog["descriptors"][0]["display_name"] = "Renamed leaf"
        renamed_ids = [
            item["id"] for item in normalize_catalog(catalog)["catalogs"][0]["descriptors"]
        ]
        self.assertEqual(renamed_ids, baseline_ids)

    def test_rejects_malformed_schema_shapes_and_unknown_keys(self):
        """Closed schema objects fail on missing, mistyped, or surplus structure."""
        self.assert_error(None, "catalog", "object")

        catalog = self.load_catalog()
        catalog["schema_version"] = 2
        self.assert_error(catalog, "catalog.schema_version", "integer 1")

        catalog = self.load_catalog()
        del catalog["descriptors"]
        self.assert_error(catalog, "catalog.descriptors", "required")

        catalog = self.load_catalog()
        catalog["invented"] = True
        self.assert_error(catalog, "catalog.invented", "not declared")

        catalog = self.load_catalog()
        catalog["descriptors"][0]["invented"] = True
        self.assert_error(catalog, "descriptors[0].invented", "not declared")

        catalog = self.load_catalog()
        descriptor = catalog["descriptors"][0]
        descriptor["speed_tiers_milli_pixels_per_tick"] = descriptor.pop(
            "speed_tiers_q10_per_tick"
        )
        self.assert_error(
            catalog,
            "speed_tiers_milli_pixels_per_tick",
            "not declared",
            "speed_tiers_q10_per_tick",
            "required",
        )

        catalog = self.load_catalog()
        catalog["descriptors"][0] = []
        self.assert_error(catalog, "descriptors[0]", "object")

    def test_rejects_malformed_ids_and_wrong_namespaces(self):
        """Every stable ID obeys its grammar and assigned namespace."""
        for value in ("Pattern Catalog", "pattern.wrong_namespace"):
            with self.subTest(value=value):
                catalog = self.load_catalog()
                catalog["id"] = value
                self.assert_error(catalog, "catalog.id")

        catalog = self.load_catalog()
        catalog["descriptors"][0]["id"] = "anchor.wrong_namespace"
        self.assert_error(catalog, "descriptors[0].id", "pattern.")

        registry_cases = (
            ("named_anchor_ids", "target.wrong", "anchor."),
            ("target_snapshot_ids", "anchor.wrong", "target."),
            ("aim_rule_ids", "target.wrong", "aim_rule."),
            ("bullet_kind_ids", "theme.wrong", "bullet_kind."),
            ("theme_tag_ids", "bullet_kind.wrong", "theme."),
        )
        for registry, value, namespace in registry_cases:
            with self.subTest(registry=registry):
                catalog = self.load_catalog()
                catalog[registry][0] = value
                self.assert_error(catalog, registry, namespace)

    def test_accepts_and_expands_both_origin_variants(self):
        """Emitter and named-anchor origins normalize to one explicit shape."""
        expected = (
            (
                {"kind": "emitter_origin"},
                {"kind": "emitter_origin", "anchor_id": None},
            ),
            (
                {
                    "kind": "named_anchor",
                    "anchor_id": "anchor.neutral_fixture.offset",
                },
                {
                    "kind": "named_anchor",
                    "anchor_id": "anchor.neutral_fixture.offset",
                },
            ),
        )
        for supplied, normalized in expected:
            with self.subTest(kind=supplied["kind"]):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["origin"] = supplied
                self.assert_valid(catalog)
                actual = normalize_catalog(catalog)["catalogs"][0]["descriptors"][0]
                self.assertEqual(actual["origin"], normalized)

    def test_rejects_malformed_origin_variants(self):
        """Origin unions reject wrong containers, kinds, and branch fields."""
        cases = (
            ([], "object"),
            ({"kind": "elsewhere"}, "kind"),
            ({"kind": "named_anchor"}, "anchor_id"),
            (
                {"kind": "emitter_origin", "anchor_id": "anchor.neutral_fixture.offset"},
                "anchor_id",
            ),
            ({"kind": "named_anchor", "anchor_id": 7}, "anchor_id"),
        )
        for supplied, fragment in cases:
            with self.subTest(origin=supplied):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["origin"] = supplied
                self.assert_error(catalog, "origin", fragment)

    def test_accepts_and_expands_all_aim_variants(self):
        """Fixed, snapshot, and rule aims normalize to one explicit shape."""
        variants = (
            (
                {"kind": "fixed_angle", "angle_millidegrees": 1234},
                {
                    "kind": "fixed_angle",
                    "angle_millidegrees": 1234,
                    "target_id": None,
                    "rule_id": None,
                },
            ),
            (
                {
                    "kind": "target_snapshot",
                    "target_id": "target.neutral_fixture.snapshot",
                },
                {
                    "kind": "target_snapshot",
                    "angle_millidegrees": None,
                    "target_id": "target.neutral_fixture.snapshot",
                    "rule_id": None,
                },
            ),
            (
                {"kind": "aim_rule", "rule_id": "aim_rule.neutral_fixture.forward"},
                {
                    "kind": "aim_rule",
                    "angle_millidegrees": None,
                    "target_id": None,
                    "rule_id": "aim_rule.neutral_fixture.forward",
                },
            ),
        )
        for supplied, normalized in variants:
            with self.subTest(kind=supplied["kind"]):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["aim"] = supplied
                self.assert_valid(catalog)
                actual = normalize_catalog(catalog)["catalogs"][0]["descriptors"][0]
                self.assertEqual(actual["aim"], normalized)

    def test_rejects_malformed_aim_variants(self):
        """Aim unions reject wrong containers, kinds, fields, and angle bounds."""
        cases = (
            ([], "object"),
            ({"kind": "elsewhere"}, "kind"),
            ({"kind": "fixed_angle"}, "angle_millidegrees"),
            ({"kind": "fixed_angle", "angle_millidegrees": True}, "integer"),
            ({"kind": "fixed_angle", "angle_millidegrees": -1}, "angle_millidegrees"),
            ({"kind": "fixed_angle", "angle_millidegrees": 360000}, "angle_millidegrees"),
            ({"kind": "target_snapshot"}, "target_id"),
            ({"kind": "aim_rule"}, "rule_id"),
            (
                {
                    "kind": "target_snapshot",
                    "target_id": "target.neutral_fixture.snapshot",
                    "rule_id": "aim_rule.neutral_fixture.forward",
                },
                "rule_id",
            ),
        )
        for supplied, fragment in cases:
            with self.subTest(aim=supplied):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["aim"] = supplied
                self.assert_error(catalog, "aim", fragment)

    def test_rejects_boolean_integer_fields_and_out_of_range_scalars(self):
        """Numeric fields reject booleans and values outside their closed bounds."""
        bounds = {
            "count": (1, 1_000_000),
            "local_angle_millidegrees": (0, 359_999),
            "spread_millidegrees": (0, 360_000),
            "cadence_ticks": (1, 1_000_000),
            "repeat_count": (1, 1_000_000),
            "lifetime_ticks": (1, 1_000_000),
            "acceleration_q10_per_tick_squared": (-1_000_000, 1_000_000),
            "friction_per_mille": (0, 1000),
            "rotation_millidegrees_per_tick": (-360_000, 360_000),
            "cancellation_power": (0, 1_000_000),
            "spawn_budget": (1, 1_000_000),
        }
        for field, (minimum, maximum) in bounds.items():
            with self.subTest(field=field, value=True):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0][field] = True
                self.assert_error(catalog, field, "integer")
            for value in (minimum - 1, maximum + 1):
                with self.subTest(field=field, value=value):
                    catalog = self.leaf_only_catalog()
                    catalog["descriptors"][0][field] = value
                    self.assert_error(catalog, field)

    def test_accepts_scalar_boundaries_when_the_budget_remains_possible(self):
        """Inclusive scalar endpoints remain valid under a satisfiable budget."""
        independent_boundaries = (
            ("local_angle_millidegrees", 359_999),
            ("spread_millidegrees", 360_000),
            ("cadence_ticks", 1_000_000),
            ("lifetime_ticks", 1_000_000),
            ("acceleration_q10_per_tick_squared", -1_000_000),
            ("acceleration_q10_per_tick_squared", 1_000_000),
            ("friction_per_mille", 0),
            ("rotation_millidegrees_per_tick", -360_000),
            ("rotation_millidegrees_per_tick", 360_000),
            ("cancellation_power", 1_000_000),
        )
        for field, value in independent_boundaries:
            with self.subTest(field=field, value=value):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0][field] = value
                self.assert_valid(catalog)

        for field in ("count", "repeat_count"):
            with self.subTest(field=field, value=1_000_000):
                catalog = self.leaf_only_catalog()
                descriptor = catalog["descriptors"][0]
                descriptor.update(count=1, repeat_count=1, spawn_budget=1_000_000)
                descriptor[field] = 1_000_000
                self.assert_valid(catalog)

    def test_speed_tiers_are_bounded_unique_and_sorted(self):
        """Q10 speed tiers reject malformed values and normalize numerically."""
        invalid_tiers = ([], [True], [0], [1_000_001], [1024, 1024], "1024")
        for supplied in invalid_tiers:
            with self.subTest(tiers=supplied):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["speed_tiers_q10_per_tick"] = supplied
                self.assert_error(catalog, "speed_tiers_q10_per_tick")

        catalog = self.leaf_only_catalog()
        descriptor = catalog["descriptors"][0]
        descriptor["speed_tiers_q10_per_tick"] = [1_000_000, 1, 512]
        normalized = normalize_catalog(catalog)["catalogs"][0]["descriptors"][0]
        self.assertEqual(normalized["speed_tiers_q10_per_tick"], [1, 512, 1_000_000])

    def test_angle_distribution_variants_and_full_turn_count_cap(self):
        """Plans classify angle spacing without materializing offsets or aliasing a turn."""
        variants = (
            (1, 0, {"kind": "centered", "rounding": None}),
            (360_000, 360_000, {"kind": "full_turn_half_open", "rounding": "floor"}),
            (
                3,
                1001,
                {
                    "kind": "centered_inclusive",
                    "rounding": "floor_clockwise_remainder",
                },
            ),
        )
        for count, spread, expected in variants:
            with self.subTest(count=count, spread=spread):
                catalog = self.leaf_only_catalog()
                descriptor = catalog["descriptors"][0]
                descriptor.update(count=count, spread_millidegrees=spread, spawn_budget=count)
                normalized = normalize_catalog(catalog)["catalogs"][0]["descriptors"][0]
                self.assertEqual(normalized["angle_distribution"], expected)
                self.assertNotIn("angle_offsets", normalized)

        catalog = self.leaf_only_catalog()
        descriptor = catalog["descriptors"][0]
        descriptor.update(count=360_001, spread_millidegrees=360_000, spawn_budget=360_001)
        self.assert_error(catalog, "count", "360000", "full-turn")

    def test_normalization_is_stable_across_all_unordered_inputs(self):
        """Catalog, descriptor, object, tag, and tier order cannot affect a plan."""
        first = self.expanded_catalog()
        second = self.renamed_catalog(first, "alternate_fixture")
        baseline = normalize_catalogs((("z.json", first), ("a.json", second)))

        permuted_first = copy.deepcopy(first)
        permuted_second = copy.deepcopy(second)
        for catalog in (permuted_first, permuted_second):
            for registry in (
                "named_anchor_ids",
                "target_snapshot_ids",
                "aim_rule_ids",
                "bullet_kind_ids",
                "theme_tag_ids",
                "descriptors",
            ):
                catalog[registry].reverse()
            for descriptor in catalog["descriptors"]:
                descriptor["theme_tag_ids"].reverse()
                descriptor["speed_tiers_q10_per_tick"].reverse()
        permuted_first = self.reverse_object_keys(permuted_first)
        permuted_second = self.reverse_object_keys(permuted_second)
        permuted = normalize_catalogs(
            (("a.json", permuted_second), ("z.json", permuted_first))
        )

        self.assertEqual(
            json.dumps(permuted, separators=(",", ":")),
            json.dumps(baseline, separators=(",", ":")),
        )

    def test_normalized_output_is_detached_from_supplied_documents(self):
        """Neither source nor normalized mutations leak across the API boundary."""
        catalog = self.load_catalog()
        plan = normalize_catalog(catalog)
        plan_before = copy.deepcopy(plan)

        catalog["descriptors"][0]["theme_tag_ids"].append("theme.after_normalize")
        self.assertEqual(plan, plan_before)

        source_after_external_mutation = copy.deepcopy(catalog)
        plan["catalogs"][0]["descriptors"][0]["theme_tag_ids"].append(
            "theme.plan_mutation"
        )
        self.assertEqual(catalog, source_after_external_mutation)

    def test_validation_and_normalization_are_data_only_and_rng_neutral(self):
        """Headless planning leaves global RNG state untouched and emits data only."""
        catalog = self.load_catalog()
        state = random.getstate()
        plan = normalize_catalog(catalog)
        self.assertEqual(random.getstate(), state)

        rendered = json.dumps(plan).lower()
        self.assertNotIn("runtime_instance", rendered)
        self.assertNotIn('"rng"', rendered)


if __name__ == "__main__":
    import unittest

    unittest.main()
