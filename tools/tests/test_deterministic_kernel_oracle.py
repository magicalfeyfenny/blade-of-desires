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
    """Rotate one word and mask Python's unbounded integer to the GML width."""
    return ((value << count) | (value >> (32 - count))) & U32_MASK


def _next_u32(state: list[int]) -> int:
    """Advance the reference state so its outputs independently check GML."""
    result = (_rotl32((state[1] * 5) & U32_MASK, 7) * 9) & U32_MASK
    temporary = (state[1] << 9) & U32_MASK

    # These XOR operations are the xoshiro128** transition in reference order;
    # changing their order would read already-updated words and produce a
    # different stream.
    state[2] ^= state[0]
    state[3] ^= state[1]
    state[1] ^= state[2]
    state[0] ^= state[3]
    state[2] ^= temporary
    state[3] = _rotl32(state[3], 11)
    state[:] = [word & U32_MASK for word in state]
    return result


def _derived_state(run_seed: int, stream_name: str) -> list[int]:
    """Derive state from version, seed, and name exactly as the GML constructor."""
    normalized_seed = run_seed % (1 << 32)
    derivation = (
        f"{PRNG_VERSION}\n{normalized_seed}\n{stream_name}\n".encode("utf-8")
    )
    digest = hashlib.sha1(derivation).digest()
    # Only the first 16 digest bytes are needed for four 32-bit state words.
    # Big-endian parsing matches the byte order used by the GML implementation.
    state = []
    for offset in range(0, 16, 4):
        state.append(int.from_bytes(digest[offset : offset + 4], "big"))
    if not any(state):
        # xoshiro cannot advance from an all-zero state, so both implementations
        # replace that one invalid digest result with the same nonzero word.
        state[0] = 0x9E3779B9
    return state


def _length_prefix(value: object) -> str:
    """Stringify a fixture field and byte-prefix it so adjacent goldens stay distinct."""
    text = str(value)
    return f"{len(text.encode('utf-8'))}:{text}"


def _record(prefix: str, *fields: object) -> str:
    """Frame fixture fields in caller-supplied positions for stable golden bytes."""
    return prefix + "".join(_length_prefix(field) for field in fields)


def _event(
    event_id: str,
    tick: int,
    event_type: str,
    reason: str,
    source_id: str,
    target_id: str,
    owner_id: str,
    content_id: str,
    payload: list[tuple[str, str, int]],
) -> str:
    """Sort fixture payload tuples and frame fixed event positions for stable bytes."""
    fields: list[object] = [
        event_id,
        tick,
        event_type,
        reason,
        source_id,
        target_id,
        owner_id,
        content_id,
        len(payload),
    ]
    for key, payload_type, value in sorted(payload):
        fields.extend((key, payload_type, value))
    return _record("E1", *fields)


class DeterministicKernelOracleTests(unittest.TestCase):
    """Checks GameMaker goldens without calling the GML code under test."""

    def test_product_contract_fingerprint_and_fixture_ids(self):
        """Bind the fixture to exact contract bytes and verify its content IDs."""
        contract_path = ROOT / "content" / "product_contract.json"
        contract_bytes = contract_path.read_bytes()
        self.assertEqual(len(contract_bytes), 10_749)
        self.assertEqual(
            hashlib.sha1(contract_bytes).hexdigest(),
            "d9a345101d9fa9971924bb2b9138a39dd5fd7c0b",
        )

        contract = json.loads(contract_bytes)
        stable_ids = set()

        def collect(value):
            """Walk nested values because ID records occur at several schema depths."""
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
        """Lock the raw transition before derivation can obscure an algorithm error."""
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
        """Derive in reverse order to prove state depends only on seed and name."""
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
        """Check signed and int64 boundaries against GML's modulo-2^32 rule."""
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

    def test_integration_fixture_canonical_hashes(self):
        """Rebuild fixture bytes independently so GML changes must match goldens."""
        seed = 0x12345678
        header = _record(
            "H1",
            1,
            "blade.simulation.v1",
            "sha1:d9a345101d9fa9971924bb2b9138a39dd5fd7c0b",
            PRNG_VERSION,
            60,
            seed,
        )
        inputs = _record(
            "I1",
            _record("S1", 1, 1024, 0, 5, 5, 0, 0, 0, 0),
            _record("S1", 2, 1024, 0, 5, 0, 0, 1, 12000, -4000),
            _record("S1", 3, 1024, 0, 4, 0, 1, 0, 0, 0),
            _record("S1", 4, 0, 0, 0, 0, 4, 0, 0, 0),
        )
        clock = _record("C1", 4, 4, 4, 4)

        stream_draws = {
            "stage_schedule": 1,
            "enemy_spawn_variant": 1,
            "pattern_geometry": 2,
            "drop_selection": 1,
        }
        random_records = []
        outputs = {}
        for name, draws in stream_draws.items():
            state = _derived_state(seed, name)
            outputs[name] = [_next_u32(state) for _ in range(draws)]
            random_records.append(_record("RS1", name, *state, draws))
        random_state = _record("R1", *random_records)

        events = _record(
            "L1",
            _event(
                "evt:1",
                1,
                "instance.spawned",
                "outcome.scheduled",
                "",
                "ins:1",
                "own:1",
                "ship.maynii",
                [("x_q10", "q10", 189440), ("y_q10", "q10", 0)],
            ),
            _event(
                "evt:2",
                2,
                "attack.started",
                "outcome.input_pressed",
                "ins:1",
                "atk:1",
                "own:1",
                "ship.maynii",
                [("power", "i32", 3)],
            ),
            _event(
                "evt:3",
                3,
                "bullet.spawned",
                "outcome.pattern_emitted",
                "atk:1",
                "blt:1",
                "own:1",
                "stage.stage1.lost_forest_of_aurei",
                [
                    ("rng_value", "u32", outputs["pattern_geometry"][0]),
                    ("speed_q10", "q10", 2048),
                ],
            ),
            _event(
                "evt:4",
                4,
                "damage.applied",
                "outcome.collision_confirmed",
                "blt:1",
                "ins:2",
                "own:1",
                "encounter.stage1.asahi",
                [("amount", "i32", 10)],
            ),
        )
        state_records = []
        for tick, held in ((1, 5), (2, 5), (3, 4), (4, 0)):
            state_records.append(_record("T1", tick, _record("F1", tick, held)))
        state_transcript = _record("ST1", *state_records)
        gameplay = _record(
            "G1",
            header,
            inputs,
            clock,
            random_state,
            "BRIC1|2|1|1|1|1|4",
            events,
            state_transcript,
        )

        self.assertEqual(
            hashlib.sha1(events.encode()).hexdigest(),
            "a2ca10f5fba445635a90f0400fea807e2299b928",
        )
        self.assertEqual(
            hashlib.sha1(gameplay.encode()).hexdigest(),
            "32634fdd4209262854bf5686b6d848ed840f060c",
        )


if __name__ == "__main__":
    unittest.main()
