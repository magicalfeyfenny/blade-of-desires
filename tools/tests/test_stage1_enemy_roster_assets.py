"""Verify the Issue #115 authored source, runtime, and project asset chain."""

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
ROSTER_ASSETS = {
    "stage1_ordinary_fae_roster": (256, 96),
    "stage1_ordinary_fae_effects": (256, 256),
}
LFS_POINTER = re.compile(
    rb"version https://git-lfs\.github\.com/spec/v1\n"
    rb"oid sha256:([0-9a-f]{64})\n"
    rb"size ([1-9][0-9]*)\n"
)


def materialized_asset(path: Path) -> bytes | None:
    """Return local bytes while accepting one exact hosted LFS pointer."""
    data = path.read_bytes()
    if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        if LFS_POINTER.fullmatch(data) is None:
            raise AssertionError(f"{path} has a malformed Git LFS pointer")
        return None
    return data


def png_info(path: Path, data: bytes) -> tuple[int, int, int, int]:
    """Read dimensions and the alpha-bearing PNG IHDR without Pillow."""
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is not a PNG with an IHDR")
    return struct.unpack(">IIBBB", data[16:27])


class Stage1EnemyRosterAssetTests(unittest.TestCase):
    """Keep authored enemy atlases editable, transparent, and packaged once."""

    def setUp(self) -> None:
        """Load the current manifest, stage catalog, project, and renderer text."""
        self.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.project_text = PROJECT_PATH.read_text(encoding="utf-8")
        self.renderer_text = (
            ROOT
            / "project/~ blade of desires ~/objects/"
            "o_blade_stage1_forest_renderer/Create_0.gml"
        ).read_text(encoding="utf-8")
        self.stage = json.loads(
            (ROOT / "content/stages/stage1_lost_forest_v1.json").read_text(
                encoding="utf-8"
            )
        )
        self.entry = next(
            entry
            for entry in self.manifest["exports"]
            if any(
                source.endswith("stage1_ordinary_fae_roster.kra")
                for source in entry["sources"]
            )
        )

    def test_manifest_pairs_both_atlases_at_authored_placeholder_level(self):
        """Pin the post-retrofit completion field and exact source/runtime pairs."""
        self.assertEqual(self.entry["kind"], "raster")
        self.assertEqual(self.entry["completion"], "authored-placeholder")
        self.assertEqual(
            self.entry["sources"],
            [
                "assets/source/sprites/stage1/stage1_ordinary_fae_roster.kra",
                "assets/source/sprites/stage1/stage1_ordinary_fae_effects.kra",
            ],
        )
        self.assertEqual(
            self.entry["runtime"],
            [
                "assets/runtime/sprites/stage1/stage1_ordinary_fae_roster.png",
                "assets/runtime/sprites/stage1/stage1_ordinary_fae_effects.png",
            ],
        )

    def test_runtime_png_dimensions_alpha_and_kra_authority(self):
        """Require transparent runtime atlases and matching editable authority."""
        for stem, dimensions in ROSTER_ASSETS.items():
            with self.subTest(stem=stem):
                runtime = ROOT / f"assets/runtime/sprites/stage1/{stem}.png"
                source = ROOT / f"assets/source/sprites/stage1/{stem}.kra"
                runtime_data = materialized_asset(runtime)
                source_data = materialized_asset(source)
                self.assertTrue(runtime.is_file())
                self.assertTrue(source.is_file())
                if runtime_data is not None:
                    width, height, bit_depth, color_type = png_info(
                        runtime, runtime_data
                    )[:4]
                    self.assertEqual((width, height), dimensions)
                    self.assertEqual(bit_depth, 8)
                    self.assertEqual(color_type, 6)
                if source_data is None:
                    continue
                with ZipFile(BytesIO(source_data)) as archive:
                    self.assertIn("maindoc.xml", archive.namelist())
                    self.assertIn("mergedimage.png", archive.namelist())
                    self.assertIn("Unnamed/layers/layer2", archive.namelist())
                    root = ElementTree.fromstring(archive.read("maindoc.xml"))
                    image = root.find(".//{*}IMAGE")
                    self.assertIsNotNone(image)
                    self.assertEqual(
                        (int(image.get("width")), int(image.get("height"))),
                        dimensions,
                    )
                    layers = root.findall(".//{*}layer")
                    authority = [
                        layer
                        for layer in layers
                        if layer.get("name")
                        == "Pixel finish - runtime authority"
                        and layer.get("visible") == "1"
                    ]
                    self.assertEqual(len(authority), 1)
                    merged = archive.read("mergedimage.png")
                    self.assertEqual(png_info(source, merged)[:2], dimensions)
                    self.assertEqual(png_info(source, merged)[3], 6)

    def test_project_packages_and_renderer_loads_each_atlas_once(self):
        """Pin one IncludedFile and one dynamic loader reference per derivative."""
        for stem in ROSTER_ASSETS:
            with self.subTest(stem=stem):
                name = f"{stem}.png"
                self.assertEqual(self.project_text.count(f'"%Name":"{name}"'), 1)
                self.assertEqual(self.project_text.count(f'"name":"{name}"'), 1)
                self.assertIn(
                    f'"filePath":"datafiles/sprites/stage1","name":"{name}"',
                    self.project_text,
                )
                self.assertIn(f'"sprites/stage1/{name}"', self.renderer_text)
        self.assertIn("ordinary_enemy_roster_sprite", self.renderer_text)
        self.assertIn("ordinary_enemy_effects_sprite", self.renderer_text)

    def test_stage_catalog_uses_only_active_roles_and_reaches_all_before_midboss(self):
        """Ensure the schedule is role-authored and the retired alias is absent."""
        expected = {
            "participant_kind.stage1.popcorn",
            "participant_kind.stage1.mook",
            "participant_kind.stage1.elite",
            "participant_kind.stage1.commander",
        }
        self.assertTrue(expected.issubset(set(self.stage["participant_kind_ids"])))
        self.assertNotIn("participant_kind.stage1.scout", self.stage["participant_kind_ids"])
        encounters = self.stage["encounters"]
        ordinary_before_midboss = {
            participant["kind_id"]
            for encounter in encounters[:2]
            for participant in encounter["participants"]
        }
        self.assertEqual(
            ordinary_before_midboss,
            {
                "participant_kind.stage1.popcorn",
                "participant_kind.stage1.mook",
                "participant_kind.stage1.elite",
                "participant_kind.stage1.commander",
            },
        )


if __name__ == "__main__":
    unittest.main()
