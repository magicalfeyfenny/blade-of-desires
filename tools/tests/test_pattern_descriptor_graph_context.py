"""Test pattern descriptor graph, product-context, and file boundaries."""

import copy
import io
import json
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from tools.content.validate_pattern_descriptors import (
    main,
    normalize_catalog,
    normalize_catalogs,
    validate_catalogs,
    validate_path,
)
from tools.tests.pattern_descriptor_test_support import PatternDescriptorTestCase


class PatternDescriptorGraphContextTests(PatternDescriptorTestCase):
    """Exercise references, recursive plans, bindings, and strict file loading."""

    def test_product_contract_binding_is_closed_shared_and_authoritative(self):
        """Catalog bindings match each other and the canonical product contract."""
        malformed = (
            (None, "object"),
            ({"id": "contract.blade"}, "content_version"),
            ({"id": "Contract Blade", "content_version": "1.2.0"}, "stable ID"),
            ({"id": "contract.blade", "content_version": "next"}, "major.minor.patch"),
            (
                {"id": "contract.blade", "content_version": "1.2.0", "extra": True},
                "not declared",
            ),
        )
        for binding, reason in malformed:
            with self.subTest(binding=binding):
                catalog = self.load_catalog()
                catalog["product_contract"] = binding
                self.assert_error(catalog, "product_contract", reason)

        first = self.load_catalog()
        self.assertEqual(
            validate_catalogs(
                (("catalog.json", first),), self.load_product_contract()
            ),
            [],
        )
        second = self.renamed_catalog(first, "binding_mismatch")
        second["product_contract"]["content_version"] = "1.2.1"
        rendered = "\n".join(validate_catalogs((("a.json", first), ("b.json", second))))
        self.assertIn("catalog.product_contract.content_version", rendered)
        self.assertIn("1.3.0", rendered)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mismatched.json"
            path.write_text(json.dumps(second), encoding="utf-8")
            plan, errors = validate_path(path)
        self.assertIsNone(plan)
        self.assertIn("catalog.product_contract.content_version", "\n".join(errors))
        self.assertIn("1.3.0", "\n".join(errors))

        invented = self.load_catalog()
        invented["product_contract"] = {
            "id": "contract.other",
            "content_version": "9.9.9",
        }
        rendered = "\n".join(validate_catalogs((("invented.json", invented),)))
        self.assertIn("authoritative product contract", rendered)
        self.assertIn("contract.blade", rendered)
        with self.assertRaisesRegex(ValueError, "authoritative product contract"):
            normalize_catalog(invented)

    def test_rejects_missing_registry_and_child_references(self):
        """Every descriptor reference must resolve in its declared registry."""
        cases = (
            ("origin", {"kind": "named_anchor", "anchor_id": "anchor.missing"}, "anchor.missing"),
            ("aim", {"kind": "target_snapshot", "target_id": "target.missing"}, "target.missing"),
            ("aim", {"kind": "aim_rule", "rule_id": "aim_rule.missing"}, "aim_rule.missing"),
            ("bullet_kind_id", "bullet_kind.missing", "bullet_kind.missing"),
            ("theme_tag_ids", ["theme.missing"], "theme.missing"),
            ("child", self.child("pattern.missing"), "pattern.missing"),
        )
        for field, supplied, missing_id in cases:
            with self.subTest(field=field, missing_id=missing_id):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0][field] = supplied
                self.assert_error(catalog, field, missing_id)

    def test_child_is_null_or_the_one_fixed_semantic_invocation(self):
        """Child plans detach the fixed trigger/origin object and reject variants."""
        plan = normalize_catalog(self.load_catalog())["catalogs"][0]["descriptors"]
        self.assertIsNone(plan[0]["child"])
        self.assertEqual(plan[1]["child"], self.child("pattern.neutral_fixture.leaf"))

        invalid = (
            ([], "object"),
            ({}, "pattern_id"),
            ({**self.child("pattern.neutral_fixture.leaf"), "extra": True}, "extra"),
            (
                {**self.child("pattern.neutral_fixture.leaf"), "trigger": "on_spawn"},
                "normal_expiry",
            ),
            (
                {**self.child("pattern.neutral_fixture.leaf"), "origin": "emitter"},
                "projectile_terminal_position",
            ),
        )
        for child, reason in invalid:
            with self.subTest(child=child):
                catalog = self.leaf_only_catalog()
                catalog["descriptors"][0]["child"] = child
                self.assert_error(catalog, "child", reason)

    def test_cross_catalog_references_allow_empty_local_registries(self):
        """One catalog may consume globally declared IDs while declaring none locally."""
        provider = self.load_catalog()
        consumer = self.renamed_catalog(self.leaf_only_catalog(), "consumer_fixture")
        registries = (
            "named_anchor_ids",
            "target_snapshot_ids",
            "aim_rule_ids",
            "bullet_kind_ids",
            "theme_tag_ids",
        )
        for registry in registries:
            consumer[registry] = []
        descriptor = consumer["descriptors"][0]
        descriptor["origin"] = {
            "kind": "named_anchor",
            "anchor_id": "anchor.neutral_fixture.offset",
        }
        descriptor["aim"] = {
            "kind": "target_snapshot",
            "target_id": "target.neutral_fixture.snapshot",
        }
        descriptor["bullet_kind_id"] = "bullet_kind.neutral_fixture.projectile"
        descriptor["theme_tag_ids"] = ["theme.neutral_fixture.unstyled"]
        descriptor["child"] = self.child("pattern.neutral_fixture.leaf")
        descriptor["spawn_budget"] = 6

        plan = normalize_catalogs((("provider.json", provider), ("consumer.json", consumer)))
        normalized = next(item for item in plan["catalogs"] if item["id"] == consumer["id"])
        self.assertTrue(all(normalized[field] == [] for field in registries))
        self.assertEqual(normalized["descriptors"][0]["maximum_spawn_count"], 6)

    def test_rejects_duplicate_catalog_members_and_cross_catalog_ids(self):
        """Registries, tags, tiers, descriptors, and catalogs reject duplicates."""
        for registry in (
            "named_anchor_ids",
            "target_snapshot_ids",
            "aim_rule_ids",
            "bullet_kind_ids",
            "theme_tag_ids",
        ):
            with self.subTest(registry=registry):
                catalog = self.load_catalog()
                catalog[registry].append(catalog[registry][0])
                self.assert_error(catalog, registry, "duplicates")

        catalog = self.load_catalog()
        catalog["descriptors"].append(copy.deepcopy(catalog["descriptors"][0]))
        self.assert_error(catalog, "descriptors[2].id", "duplicates")

        catalog = self.leaf_only_catalog()
        catalog["descriptors"][0]["theme_tag_ids"] *= 2
        self.assert_error(catalog, "theme_tag_ids", "duplicates")

        catalog = self.leaf_only_catalog()
        catalog["descriptors"][0]["speed_tiers_q10_per_tick"] = [1024, 1024]
        self.assert_error(catalog, "speed_tiers_q10_per_tick", "duplicates")

        catalog = self.load_catalog()
        rendered = "\n".join(validate_catalogs((('first.json', catalog), ('second.json', catalog))))
        self.assertIn("duplicates", rendered)

    def test_rejects_local_and_cross_catalog_cycles(self):
        """Child graphs fail closed for self, local, and cross-catalog cycles."""
        catalog = self.leaf_only_catalog()
        catalog["descriptors"][0]["child"] = self.child("pattern.neutral_fixture.leaf")
        self.assert_error(catalog, "cycle", "pattern.neutral_fixture.leaf")

        catalog = self.load_catalog()
        self.descriptor(catalog, "pattern.neutral_fixture.leaf")["child"] = self.child(
            "pattern.neutral_fixture.parent"
        )
        self.assert_error(
            catalog,
            "cycle",
            "pattern.neutral_fixture.leaf",
            "pattern.neutral_fixture.parent",
        )

        first = self.renamed_catalog(self.leaf_only_catalog(), "cycle_a")
        second = self.renamed_catalog(self.leaf_only_catalog(), "cycle_b")
        first["descriptors"][0]["child"] = self.child("pattern.cycle_b.leaf")
        second["descriptors"][0]["child"] = self.child("pattern.cycle_a.leaf")
        rendered = "\n".join(validate_catalogs((("a.json", first), ("b.json", second))))
        self.assertIn("cycle", rendered)
        self.assertIn("pattern.cycle_a.leaf", rendered)
        self.assertIn("pattern.cycle_b.leaf", rendered)

    def test_rejects_budget_underflow_and_absolute_spawn_overflow(self):
        """Budgets cover full trees and arithmetic cannot exceed the absolute cap."""
        catalog = self.leaf_only_catalog()
        catalog["descriptors"][0]["spawn_budget"] = 1
        self.assert_error(catalog, "spawn_budget", "2")

        catalog = self.load_catalog()
        self.descriptor(catalog, "pattern.neutral_fixture.parent")["spawn_budget"] = 5
        self.assert_error(catalog, "spawn_budget", "6")

        catalog = self.leaf_only_catalog()
        descriptor = catalog["descriptors"][0]
        descriptor.update(count=1_000_000, repeat_count=1_000_000, spawn_budget=1_000_000)
        self.assert_error(catalog, "absolute cap", "1000000")

    def test_malformed_json_and_cli_errors_include_the_file_source(self):
        """File and CLI failures bind deterministic diagnostics to their source."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "broken.json"
            path.write_text('{"schema_version": 1,', encoding="utf-8")
            plan, errors = validate_path(path)
            self.assertIsNone(plan)
            self.assertTrue(all(str(path) in error for error in errors))
            self.assertIn("JSON", "\n".join(errors))

            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = main([str(path)])
            self.assertEqual(result, 1)
            self.assertIn(str(path), stdout.getvalue() + stderr.getvalue())

    def test_strict_json_rejects_duplicate_keys_and_nonstandard_numbers(self):
        """Strict decoding rejects ambiguous keys, NaN, and infinities by source."""
        cases = (
            ('{"schema_version": 1, "schema_version": 1}', "duplicate object key"),
            ('{"schema_version": NaN}', "nonstandard numeric constant NaN"),
            ('{"schema_version": Infinity}', "nonstandard numeric constant Infinity"),
            ('{"schema_version": -Infinity}', "nonstandard numeric constant -Infinity"),
        )
        with tempfile.TemporaryDirectory() as directory:
            for index, (document, reason) in enumerate(cases):
                with self.subTest(reason=reason):
                    path = Path(directory) / f"strict-{index}.json"
                    path.write_text(document, encoding="utf-8")
                    plan, errors = validate_path(path)
                    self.assertIsNone(plan)
                    self.assertTrue(
                        all(error.startswith(f"{path}: JSON: invalid:") for error in errors)
                    )
                    self.assertIn(reason, "\n".join(errors))

    def test_file_validation_preserves_source_bound_schema_diagnostics(self):
        """Well-formed invalid files retain their concrete source in diagnostics."""
        catalog = self.load_catalog()
        catalog["schema_version"] = 2
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid-catalog.json"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            plan, errors = validate_path(path)

        self.assertIsNone(plan)
        self.assertTrue(errors)
        self.assertTrue(all(error.startswith(f"{path}: ") for error in errors))
        self.assertIn("catalog.schema_version", "\n".join(errors))

    def test_no_catalog_inputs_fail_without_an_empty_plan(self):
        """Plural entry points reject an absent catalog set explicitly."""
        errors = validate_catalogs(())
        self.assertTrue(errors)
        self.assertIn("input", "\n".join(errors).lower())
        with self.assertRaises(ValueError):
            normalize_catalogs(())

    def test_cli_without_a_path_validates_the_canonical_directory(self):
        """The command-line default validates the checked-in catalog directory."""
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = main([])
        self.assertEqual(result, 0)
        self.assertEqual(stdout.getvalue() + stderr.getvalue(), "")


if __name__ == "__main__":
    import unittest

    unittest.main()
