"""Verify the reusable front-end UI asset and GameMaker integration chain."""

from __future__ import annotations

import json
from pathlib import Path
import re
import struct
import tomllib
import unittest
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / "assets/source/ui/blade_frontend_panels.svg"
SOURCE_IMAGE_PATHS = (
    ROOT / "assets/source/ui/blade_frontend_panel_base_generated.png",
    ROOT / "assets/source/ui/blade_frontend_panel_selected_generated.png",
)
RUNTIME_PATH = ROOT / "assets/runtime/ui/blade_frontend_panels.png"
MANIFEST_PATH = ROOT / "assets/exports.json"
POLICY_PATH = ROOT / "PROJECT_POLICY.toml"
PROJECT_PATH = ROOT / "project/~ blade of desires ~/~ blade of desires ~.yyp"
PROJECT_UI_LINK = ROOT / "project/~ blade of desires ~/datafiles/ui"
UI_SCRIPT_PATH = ROOT / "project/~ blade of desires ~/scripts/BladeFrontendUi/BladeFrontendUi.gml"
START_DRAW_PATH = ROOT / "project/~ blade of desires ~/objects/o_blade_start/Draw_64.gml"
SELECT_DRAW_PATH = ROOT / "project/~ blade of desires ~/objects/o_blade_character_select/Draw_64.gml"
LFS_POINTER = re.compile(
    rb"version https://git-lfs\.github\.com/spec/v1\n"
    rb"oid sha256:[0-9a-f]{64}\n"
    rb"size [1-9][0-9]*\n"
)


class FrontendUiAssetTests(unittest.TestCase):
    """Keep the authored UI source, runtime export, and consumers aligned."""

    def setUp(self) -> None:
        """Load the repository-owned manifest, policy, and project metadata."""
        self.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.policy = tomllib.loads(POLICY_PATH.read_text(encoding="utf-8"))
        self.project_text = PROJECT_PATH.read_text(encoding="utf-8")
        self.ui_exports = [
            entry for entry in self.manifest["exports"] if entry["kind"] == "ui"
        ]

    def test_policy_and_manifest_bind_one_editable_source_to_one_runtime_export(self):
        """Require the UI pipeline and its manifest mapping to agree."""
        self.assertEqual(
            self.policy["assets"]["pipelines"]["ui"],
            {
                "source_extensions": [".svg", ".png"],
                "runtime_extensions": [".png"],
            },
        )
        self.assertEqual(len(self.ui_exports), 1)
        self.assertEqual(
            self.ui_exports[0]["sources"],
            [
                "assets/source/ui/blade_frontend_panels.svg",
                "assets/source/ui/blade_frontend_panel_base_generated.png",
                "assets/source/ui/blade_frontend_panel_selected_generated.png",
            ],
        )
        self.assertEqual(
            self.ui_exports[0]["runtime"],
            ["assets/runtime/ui/blade_frontend_panels.png"],
        )
        self.assertEqual(self.ui_exports[0]["completion"], "authored-placeholder")
        self.assertTrue(SOURCE_PATH.is_file())
        self.assertTrue(RUNTIME_PATH.is_file())
        for source_image in SOURCE_IMAGE_PATHS:
            self.assertTrue(source_image.is_file())

    def test_svg_composes_two_generated_panel_frames_from_local_sources(self):
        """Keep the generated artwork and editable sheet layout together."""
        root = ElementTree.fromstring(SOURCE_PATH.read_text(encoding="utf-8"))
        self.assertEqual(root.tag.rsplit("}", 1)[-1], "svg")
        self.assertEqual(root.get("viewBox"), "0 0 256 128")
        self.assertEqual(root.get("width"), "256")
        self.assertEqual(root.get("height"), "128")

        frame_groups = {
            element.get("id"): element
            for element in root
            if element.get("id") in {"base-panel", "selected-panel"}
        }
        self.assertEqual(set(frame_groups), {"base-panel", "selected-panel"})
        for group in frame_groups.values():
            image = group.find("{*}image")
            self.assertIsNotNone(image)
            self.assertIn(image.get("href"), {
                "blade_frontend_panel_base_generated.png",
                "blade_frontend_panel_selected_generated.png",
            })

        self.assertEqual(
            {
                image.get("href")
                for image in root.findall(".//{*}image")
            },
            {
                "blade_frontend_panel_base_generated.png",
                "blade_frontend_panel_selected_generated.png",
            },
        )

    def test_runtime_png_is_the_expected_two_frame_sheet(self):
        """Pin the raster export dimensions used by the dynamic sprite loader."""
        data = RUNTIME_PATH.read_bytes()
        if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            self.assertIsNotNone(LFS_POINTER.fullmatch(data))
            return
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(data[12:16], b"IHDR")
        self.assertEqual(struct.unpack(">II", data[16:24]), (256, 128))
        self.assertEqual(data[25], 6)

    def test_generated_source_pngs_are_square_and_have_transparency(self):
        """Keep each generated panel source suitable for the composed sheet."""
        for source_path in SOURCE_IMAGE_PATHS:
            with self.subTest(source_path=source_path.name):
                data = source_path.read_bytes()
                if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                    self.assertIsNotNone(LFS_POINTER.fullmatch(data))
                    continue
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(data[12:16], b"IHDR")
                self.assertEqual(struct.unpack(">II", data[16:24]), (1254, 1254))
                self.assertEqual(data[25], 6)

    def test_game_maker_project_packages_and_consumes_the_shared_panel_sprite(self):
        """Require one IncludedFile and both front-end consumers to use the helper."""
        self.assertTrue(PROJECT_UI_LINK.is_symlink())
        self.assertEqual(PROJECT_UI_LINK.resolve(), RUNTIME_PATH.parent.resolve())
        self.assertTrue((PROJECT_UI_LINK / RUNTIME_PATH.name).is_file())
        self.assertEqual(
            self.project_text.count('"%Name":"blade_frontend_panels.png"'),
            1,
        )
        self.assertEqual(
            self.project_text.count('"name":"blade_frontend_panels.png"'),
            1,
        )
        self.assertIn(
            '"filePath":"datafiles/ui","name":"blade_frontend_panels.png"',
            self.project_text,
        )

        ui_script = UI_SCRIPT_PATH.read_text(encoding="utf-8")
        for fragment in (
            'BLADE_FRONTEND_UI_FRAME_COUNT 2',
            'BLADE_FRONTEND_UI_FRAME_WIDTH 128',
            'BLADE_FRONTEND_UI_GUIDE_LEFT 24',
            'sprite_add',
            'sprite_nineslice_create',
            'sprite_set_nineslice',
            'draw_sprite_part_ext',
        ):
            self.assertIn(fragment, ui_script)
        self.assertGreaterEqual(ui_script.count("_BladeFrontendUiDrawPart("), 10)

        start_draw = START_DRAW_PATH.read_text(encoding="utf-8")
        selector_draw = SELECT_DRAW_PATH.read_text(encoding="utf-8")
        self.assertGreaterEqual(start_draw.count("BladeFrontendUiDrawPanel"), 3)
        self.assertEqual(selector_draw.count("BladeFrontendUiDrawPanel"), 1)


if __name__ == "__main__":
    unittest.main()
