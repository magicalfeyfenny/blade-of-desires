"""Verify front-end room re-entry does not dereference retired test state."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
START_CREATE_PATH = (
    ROOT / "project/~ blade of desires ~/objects/o_blade_start/Create_0.gml"
)


class FrontendRoomLifecycleTests(unittest.TestCase):
    """Keep the title room safe after GMTL startup cleanup."""

    def test_start_room_guards_gmtl_suite_cleanup_on_reentry(self):
        """Require safe lookup of GMTL state after its suites are deleted."""
        start_create = START_CREATE_PATH.read_text(encoding="utf-8")
        self.assertIn(
            'variable_struct_get(\n'
            '            global.__gmtl_internal,\n'
            '            "suites"\n'
            '        )',
            start_create,
        )
        self.assertIn("is_struct(_gmtl_suites)", start_create)
        self.assertIn(
            'variable_struct_exists(_gmtl_suites, "list")',
            start_create,
        )
        self.assertIn(
            'variable_struct_set(_gmtl_suites, "list", []);',
            start_create,
        )
        self.assertNotIn(
            "global.__gmtl_internal.suites.list",
            start_create,
            "room re-entry must not dereference retired GMTL state",
        )


if __name__ == "__main__":
    unittest.main()
