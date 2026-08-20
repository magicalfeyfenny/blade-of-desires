import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
U32_MASK = (1 << 32) - 1
PRNG_VERSION = "blade.xoshiro128ss.v1"
STREAM_NAMES = (
    "stage_schedule",
    "enemy_spawn_variant",
    "pattern_geometry",
    "drop_selection",
    "cosmetic_effects",
)


def _rotl32(value: int, count: int) -> int:
    return ((value << count) | (value >> (32 - count))) & U32_MASK


def _next_u32(state: list[int]) -> int:
    result = (_rotl32((state[1] * 5) & U32_MASK, 7) * 9) & U32_MASK
    temporary = (state[1] << 9) & U32_MASK

    state[2] ^= state[0]
    state[3] ^= state[1]
    state[1] ^= state[2]
    state[0] ^= state[3]
    state[2] ^= temporary
    state[3] = _rotl32(state[3], 11)
    state[:] = [word & U32_MASK for word in state]
    return result


def _derived_state(run_seed: int, stream_name: str) -> list[int]:
    normalized_seed = run_seed % (1 << 32)
    derivation = (
        f"{PRNG_VERSION}\n{normalized_seed}\n{stream_name}\n".encode("utf-8")
    )
    digest = hashlib.sha1(derivation).digest()
    state = [
        int.from_bytes(digest[offset : offset + 4], "big")
        for offset in range(0, 16, 4)
    ]
    if not any(state):
        state[0] = 0x9E3779B9
    return state


class DeterministicKernelOracleTests(unittest.TestCase):
    def test_product_contract_fingerprint_and_fixture_ids(self):
        contract_path = ROOT / "content" / "product_contract.json"
        contract_bytes = contract_path.read_bytes()
        self.assertEqual(len(contract_bytes), 10_418)
        self.assertEqual(
            hashlib.sha1(contract_bytes).hexdigest(),
            "60bbf1e2436c7f0132be5877b2dc38a149d8ea72",
        )

        contract = json.loads(contract_bytes)
        stable_ids = set()

        def collect(value):
            if isinstance(value, dict):
                identifier = value.get("id")
                if isinstance(identifier, str):
                    stable_ids.add(identifier)
                for child in value.values():
                    collect(child)
            elif isinstance(value, list):
                for child in value:
                    collect(child)

        collect(contract)
        self.assertTrue(
            {
                "ship.maynii",
                "stage.stage1.lost_forest_of_aurei",
                "encounter.stage1.asahi",
            }.issubset(stable_ids)
        )

    def test_xoshiro_reference_transition(self):
        state = [1, 2, 3, 4]
        self.assertEqual(
            [_next_u32(state) for _ in range(10)],
            [
                11_520,
                0,
                5_927_040,
                70_819_200,
                2_031_721_883,
                1_637_235_492,
                1_287_239_034,
                3_734_860_849,
                3_729_100_597,
                4_258_142_804,
            ],
        )

    def test_named_stream_derivation_is_order_independent(self):
        expected = {
            "stage_schedule": (
                [0xFEEEFD1F, 0xDEE986F8, 0x78333891, 0x07518874],
                2_254_228_885,
            ),
            "enemy_spawn_variant": (
                [0xF7AB6928, 0x71873CD7, 0xC824D6E7, 0x806944CD],
                1_658_381_939,
            ),
            "pattern_geometry": (
                [0x8F74F4F8, 0x20F1E696, 0xECB65B28, 0x1866B792],
                1_120_154_082,
            ),
            "drop_selection": (
                [0x48E6540D, 0x394AC217, 0xC80D0017, 0x96F888D8],
                302_974_471,
            ),
            "cosmetic_effects": (
                [0x553C4E37, 0xD5B17C88, 0xB4D2A1C9, 0x93B67C63],
                426_898_630,
            ),
        }

        for stream_name in reversed(STREAM_NAMES):
            state = _derived_state(0x12345678, stream_name)
            expected_state, expected_first = expected[stream_name]
            self.assertEqual(state, expected_state)
            self.assertEqual(_next_u32(state), expected_first)

    def test_seed_normalization_boundaries(self):
        cases = {
            0: 0,
            -1: U32_MASK,
            1 << 32: 0,
            (1 << 32) + 1: 1,
            -(1 << 32) - 1: U32_MASK,
            (1 << 63) - 1: U32_MASK,
            -(1 << 63): 0,
        }
        for supplied, expected in cases.items():
            with self.subTest(supplied=supplied):
                self.assertEqual(supplied % (1 << 32), expected)


if __name__ == "__main__":
    unittest.main()
