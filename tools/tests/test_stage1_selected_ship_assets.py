"""Verify the selected-ship editable, runtime, and GameMaker asset chain."""

from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path
import re
import struct
import unittest
from xml.etree import ElementTree
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets/exports.json"
PROJECT_PATH = ROOT / "project/~ blade of desires ~/~ blade of desires ~.yyp"
ASSETS = {
    "maynii_player": (48, 48),
    "maynii_option": (16, 16),
    "maynii_tracking_shot": (12, 18),
    "maynii_forward_shot": (10, 22),
    "ciela_boss": (64, 64),
    "ciela_current": (24, 24),
    "ciela_kolar_combo": (32, 24),
    "kolar_player": (288, 48),
    "kolar_option": (32, 16),
    "kolar_close_channel": (96, 16),
    "kolar_ranged_shot": (48, 18),
    "ciela_maynii_combo": (32, 24),
}
KOLAR_SHEET_FRAME_COUNTS = {
    "kolar_player": 6,
    "kolar_option": 2,
    "kolar_close_channel": 4,
    "kolar_ranged_shot": 4,
}
GENERATED_CHARACTER_ASSETS = {"maynii_player", "ciela_boss"}
LFS_POINTER = re.compile(
    rb"version https://git-lfs\.github\.com/spec/v1\n"
    rb"oid sha256:([0-9a-f]{64})\n"
    rb"size ([1-9][0-9]*)\n"
)


def materialized_asset(path: Path) -> bytes | None:
    """Return bytes locally while accepting one exact hosted LFS pointer."""
    data = path.read_bytes()
    if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        if LFS_POINTER.fullmatch(data) is None:
            raise AssertionError(f"{path} has a malformed Git LFS pointer")
        return None
    return data


def png_dimensions(path: Path, data: bytes) -> tuple[int, int]:
    """Read one PNG IHDR without adding a non-standard test dependency."""
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is not a PNG with an IHDR")
    return struct.unpack(">II", data[16:24])


class Stage1SelectedShipAssetTests(unittest.TestCase):
    """Keep every new selected-ship sprite editable and packaged once."""

    def setUp(self) -> None:
        """Load the manifest and project text used by repository packaging."""
        self.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.project_text = PROJECT_PATH.read_text(encoding="utf-8")
        raster_entries = [
            entry for entry in self.manifest["exports"] if entry["kind"] == "raster"
        ]
        self.sources = {
            source for entry in raster_entries for source in entry["sources"]
        }
        self.runtime = {
            runtime for entry in raster_entries for runtime in entry["runtime"]
        }

    def test_runtime_pngs_have_exact_dimensions_and_manifest_sources(self):
        """Pin player, boss, option, and attack footprints to their KRA authority."""
        for stem, dimensions in ASSETS.items():
            with self.subTest(stem=stem):
                source = f"assets/source/sprites/stage1/{stem}.kra"
                runtime = f"assets/runtime/sprites/stage1/{stem}.png"
                self.assertIn(source, self.sources)
                self.assertIn(runtime, self.runtime)
                self.assertTrue((ROOT / source).is_file())
                runtime_path = ROOT / runtime
                runtime_data = materialized_asset(runtime_path)
                if runtime_data is not None:
                    self.assertEqual(
                        png_dimensions(runtime_path, runtime_data), dimensions
                    )

    def test_krita_sources_name_runtime_authority_and_hidden_references(self):
        """Retain an editable pixel layer and mark generated character references."""
        for stem in ASSETS:
            with self.subTest(stem=stem):
                path = ROOT / f"assets/source/sprites/stage1/{stem}.kra"
                source_data = materialized_asset(path)
                if source_data is None:
                    continue
                with ZipFile(BytesIO(source_data)) as archive:
                    root = ElementTree.fromstring(archive.read("maindoc.xml"))
                layers = root.findall(".//{*}layer")
                visible_authority = [
                    layer
                    for layer in layers
                    if layer.get("name") == "Pixel finish - runtime authority"
                    and layer.get("visible") == "1"
                ]
                self.assertEqual(len(visible_authority), 1)
                hidden_references = [
                    layer
                    for layer in layers
                    if layer.get("name") == "Image generation reference - hidden"
                    and layer.get("visible") == "0"
                ]
                self.assertEqual(
                    len(hidden_references),
                    1 if stem in GENERATED_CHARACTER_ASSETS else 0,
                )

    def test_every_runtime_png_is_packaged_once_for_gamemaker(self):
        """Require one IncludedFile record for every new runtime derivative."""
        for stem in ASSETS:
            with self.subTest(stem=stem):
                name = f'{stem}.png'
                self.assertEqual(self.project_text.count(f'"%Name":"{name}"'), 1)
                self.assertEqual(self.project_text.count(f'"name":"{name}"'), 1)
                self.assertIn(
                    f'"filePath":"datafiles/sprites/stage1","name":"{name}"',
                    self.project_text,
                )

    def test_kolar_sheets_are_loaded_with_their_frame_contract(self):
        """Keep horizontal sheet dimensions aligned with dynamic loading."""
        renderer = (
            ROOT
            / "project/~ blade of desires ~/objects/"
            "o_blade_stage1_forest_renderer/Create_0.gml"
        ).read_text(encoding="utf-8")
        for stem, frame_count in KOLAR_SHEET_FRAME_COUNTS.items():
            with self.subTest(stem=stem):
                self.assertIn(
                    f'"sprites/stage1/{stem}.png", {frame_count}',
                    renderer,
                )
        selector = (
            ROOT
            / "project/~ blade of desires ~/objects/"
            "o_blade_character_select/Create_0.gml"
        ).read_text(encoding="utf-8")
        self.assertIn('"sprites/stage1/kolar_player.png"', selector)
        self.assertIn("_selector_path, _frame_count", selector)
        self.assertIn("? 6", selector)

    def test_generation_references_are_not_packaged(self):
        """Keep non-authority generation material out of the runtime package."""
        self.assertNotIn("imagegen_reference", self.project_text)


if __name__ == "__main__":
    unittest.main()
