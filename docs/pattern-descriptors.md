# Pattern descriptor contract

`content/patterns/` contains the canonical JSON contract for deterministic
pattern plans. Version 1 describes and validates plans only: it does not
schedule runtime work, create GameMaker instances, select live targets, or
define production Blade of Desires attacks or balance.

Run the headless validator with:

```sh
python3.12 tools/content/validate_pattern_descriptors.py content/patterns
```

The command is silent on success and reports deterministic diagnostics on
failure. With no path argument it validates `content/patterns`.

## Stable records and vocabularies

Every catalog and descriptor has `schema_version`, a stable `id`, and a
nonempty `display_name`. Version 1 is the only accepted schema version. IDs
match the product-contract grammar
`^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$`, are globally unique, and are never
reused. A display name may change without changing its record's ID; display
names never resolve references, determine ordering, or affect budgets.

Every catalog also binds the exact product contract it extends through
`product_contract.id` and `product_contract.content_version`. The validator
checks that binding against `content/product_contract.json` before accepting a
plan; it does not guess compatibility from a filename or schema version.

A catalog is a closed object with these fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | Catalog shape and interpretation; exactly integer `1`. |
| `id` | Stable `pattern_catalog.*` ID. |
| `display_name` | Nonempty human-facing catalog label. |
| `product_contract` | Closed `{id, content_version}` binding to the authoritative product contract. |
| `named_anchor_ids` | Registry of available `anchor.*` IDs; may be empty. |
| `target_snapshot_ids` | Registry of available immutable `target.*` snapshot IDs; may be empty. |
| `aim_rule_ids` | Registry of deterministic `aim_rule.*` IDs; may be empty. |
| `bullet_kind_ids` | Registry of `bullet_kind.*` IDs; may be empty. |
| `theme_tag_ids` | Registry of presentation-oriented `theme.*` IDs; may be empty. |
| `descriptors` | Nonempty list of version-1 descriptor records. |

Registry lists may be empty so a catalog can reuse definitions from another
loaded catalog. Listed definitions and descriptor IDs reject duplicates. All
catalog, descriptor, and registry definitions are globally unique across the
complete loaded catalog set. A reference is valid only when the matching
registry or descriptor exists in that loaded union; cross-catalog references
are allowed, but cross-catalog definition redeclarations are not. Unknown
fields and IDs from the wrong namespace fail closed rather than being ignored
or interpreted as extensions.

The repository's initial catalog, `content/patterns/neutral_v1.json`, is an
explicitly neutral contract fixture. Its names and integer values exercise the
vocabulary and child-budget rules; they are not a shipped attack, a difficulty
profile, a character identity, or production tuning.

## Descriptor fields

Each descriptor is a closed object containing every field below:

| Field | Meaning |
| --- | --- |
| `schema_version` | Descriptor shape and interpretation; exactly integer `1`. |
| `id` | Stable `pattern.*` ID. |
| `display_name` | Nonempty human-facing descriptor label. |
| `origin` | Closed origin variant described below. |
| `aim` | Closed aim variant described below. |
| `count` | Number of direct projectiles in each repeat. |
| `local_angle_millidegrees` | Clockwise local offset added to the aim angle. |
| `spread_millidegrees` | Total angular span occupied by the `count` projectile slots. |
| `speed_tiers_q10_per_tick` | Nonempty, unique initial speeds in exact q10 units; normalization sorts them numerically. |
| `cadence_ticks` | Tick distance between repeat starts; the first repeat starts at offset zero. |
| `repeat_count` | Finite number of direct emission repeats. |
| `acceleration_q10_per_tick_squared` | Signed per-tick change to scalar speed in exact 1/1024-logical-pixel units; zero is neutral. |
| `friction_per_mille` | Per-tick velocity-retention factor; `1000` is neutral and `0` retains none. |
| `rotation_millidegrees_per_tick` | Signed per-tick heading change; positive is clockwise. |
| `lifetime_ticks` | Finite projectile lifetime in simulation ticks. Normal expiry occurs at this lifetime. |
| `bullet_kind_id` | Reference to one registered `bullet_kind.*` ID. |
| `theme_tag_ids` | Nonempty, unique references to registered `theme.*` IDs. |
| `cancellation_power` | Nonnegative cancellation-strength value; zero grants no cancellation power. It is not damage. |
| `child` | Closed normal-expiry child invocation described below, or JSON `null`. |
| `spawn_budget` | Declared upper bound for this invocation's complete transitive projectile expansion. |

`count` is the total direct-projectile count per repeat. Speed tiers do not
multiply that count. A consumer assigns sorted tiers by zero-based projectile
slot modulo the number of tiers. The validator keeps an integer angle plan and
never expands it into runtime objects.

Let `base` be the resolved aim angle plus `local_angle_millidegrees`, reduced
modulo `360000`, and let projectile slot `i` use `0 <= i < count`:

- For `count == 1`, `offset_0 = 0`; the sole projectile is centered on `base`.
- For `count > 1` and `spread_millidegrees == 360000`,
  `offset_i = floor(i * 360000 / count)`. This is a half-open full turn and
  never duplicates its first direction. `count > 360000` is rejected for a
  full-turn spread so every slot can occupy a distinct millidegree.
- For a partial spread with `count > 1`, let
  `left = -(spread_millidegrees // 2)` and
  `offset_i = left + floor(i * spread_millidegrees / (count - 1))`. The first
  and last offsets preserve the exact endpoint span, while each division
  remainder is allocated clockwise. An odd spread is centered between two
  millidegree grid units, so its clockwise edge is one unit farther from zero.

Each projectile heading is `(base + offset_i) mod 360000`. The normalized
`angle_distribution` records the selected rule without materializing an angle
array: `{kind: "centered", rounding: null}` for `count == 1`,
`{kind: "full_turn_half_open", rounding: "floor"}` for a full turn, and
`{kind: "centered_inclusive", rounding: "floor_clockwise_remainder"}` for a
partial spread.

Acceleration, friction, and rotation describe projectile motion after
emission. On each eligible motion tick, scalar speed updates in this exact
order:

```text
retained = trunc_toward_zero(speed_q10 * friction_per_mille / 1000)
speed_q10 = retained + acceleration_q10_per_tick_squared
heading_millidegrees =
    (heading_millidegrees + rotation_millidegrees_per_tick) mod 360000
```

There is no fractional residual carry between ticks. Issue #32 must use this
fixed-point order; it may define the surrounding spatial-integration order,
but it may not substitute floating-point or frame-rate-dependent tuning.

## Origin and aim variants

Origin objects accept exactly one of these shapes:

```json
{ "kind": "emitter_origin" }
```

`emitter_origin` uses the position supplied to the descriptor invocation. It
does not search a room, layer, or singleton owner.

```json
{ "kind": "named_anchor", "anchor_id": "anchor.example" }
```

`named_anchor` resolves `anchor_id` through `named_anchor_ids`. Resolution is
an input to later execution; validation does not look up an instance or a
coordinate.

Aim objects accept exactly one of these shapes:

```json
{ "kind": "fixed_angle", "angle_millidegrees": 0 }
```

`fixed_angle` supplies its declared angle as the base aim. The descriptor's
local angle is then an additional clockwise offset.

```json
{ "kind": "target_snapshot", "target_id": "target.example" }
```

`target_snapshot` references a target position captured immutably at the
invocation boundary. It cannot follow later target movement or choose a target
from instance order.

```json
{ "kind": "aim_rule", "rule_id": "aim_rule.example" }
```

`aim_rule` selects a registered deterministic rule. The rule may consume only
the explicit execution inputs defined by the future emitter contract; it may
not consult presentation state, ambient instance order, or ambient RNG.

The normalized origin always has `kind` and `anchor_id`, with `anchor_id` set
to a string only for `named_anchor` and otherwise to `null`. The normalized
aim always has `kind`, `angle_millidegrees`, `target_id`, and `rule_id`; exactly
the field selected by the variant is non-null.

## Integer units and ranges

All numeric fields are JSON integers. JSON booleans are not integers for this
contract. Values outside these inclusive ranges are rejected:

| Field | Inclusive range | Unit or rule |
| --- | ---: | --- |
| `schema_version` | `1` | Version token. |
| `count` | `1..1,000,000` | Projectiles per repeat. |
| `local_angle_millidegrees` | `0..359,999` | `360,000` millidegrees is one full turn. |
| fixed `angle_millidegrees` | `0..359,999` | Base clockwise angle. |
| `spread_millidegrees` | `0..360,000` | Zero through one complete turn. |
| each `speed_tiers_q10_per_tick` entry | `1..1,000,000` | Exact 1/1024 logical pixels per tick. |
| `cadence_ticks` | `1..1,000,000` | Simulation ticks between repeat starts. |
| `repeat_count` | `1..1,000,000` | Finite repeat count. |
| `acceleration_q10_per_tick_squared` | `-1,000,000..1,000,000` | Exact 1/1024 logical pixels per tick squared. |
| `friction_per_mille` | `0..1,000` | Thousandths of velocity retained per tick. |
| `rotation_millidegrees_per_tick` | `-360,000..360,000` | Signed heading change per tick. |
| `lifetime_ticks` | `1..1,000,000` | Finite simulation ticks before normal expiry. |
| `cancellation_power` | `0..1,000,000` | Abstract cancellation strength. |
| `spawn_budget` | `1..1,000,000` | Maximum transitive projectile count. |

Angles are already canonical integers in version 1; the validator rejects an
out-of-range angle instead of silently wrapping an authored error. Consumers
reduce additions such as base plus local angle modulo `360,000`.

## References, cycles, and spawn budgets

Descriptor references form a directed graph with at most one child edge from
each descriptor. Missing child descriptors and all recursive cycles, including
self-cycles, are rejected before budget comparison.

The child field is either `null` or exactly:

```json
{
  "pattern_id": "pattern.example.child",
  "trigger": "normal_expiry",
  "origin": "projectile_terminal_position"
}
```

Each direct projectile invokes that child exactly once and only when it reaches
`lifetime_ticks` by normal lifetime expiry. A hit, cancellation, cleanup,
reset, abort, or any other removal does not invoke the child. The parent's
terminal position supplies the child invocation's emitter origin. The child
runs on the same eligible tick, after the parent's terminal record, in the
ascending numeric order of the stable parent-projectile IDs. These are the
only version-1 trigger and child-origin tokens.

For one descriptor invocation:

```text
direct_spawn_count = count * repeat_count

maximum_spawn_count = direct_spawn_count                         (no child)
maximum_spawn_count = direct_spawn_count * (1 + child maximum)   (with child)
```

Budget accounting conservatively assumes every direct projectile reaches
normal expiry and therefore causes its one child invocation, even though a
runtime hit or cancellation may prevent that invocation. A descendant's
declared budget does not inflate its computed maximum. Every descriptor must declare
`spawn_budget >= maximum_spawn_count`, and no declared budget may exceed
`1,000,000`. A computed maximum above that limit is therefore impossible and
is rejected even if intermediate multiplication would otherwise continue.

The neutral leaf fixture emits `2 * 1 = 2` projectiles and declares budget
`2`. The neutral parent emits two direct projectiles, each accounting for one
leaf invocation, so its maximum is `2 * (1 + 2) = 6` and its declared budget
is `6`.

## Deterministic normalization

Validation produces exactly one top-level plan object without relying on
source filenames or authored JSON ordering:

```json
{
  "schema_version": 1,
  "product_contract": {
    "id": "contract.blade",
    "content_version": "1.3.0"
  },
  "catalogs": []
}
```

The shared product binding appears once at the plan root. Each item in
`catalogs` retains its identity, display name, registries, and descriptors
without repeating that binding. Each normalized descriptor retains every
authored descriptor field plus
`angle_distribution`, `direct_spawn_count`, and `maximum_spawn_count`. Within
that representation:

- catalogs are ordered lexically by catalog ID;
- every registry is ordered lexically by stable ID;
- descriptors are ordered lexically by descriptor ID;
- descriptor theme tags are ordered lexically;
- q10 speed tiers are ordered numerically;
- origin and aim variants receive the explicit nullable keys described above;
- `angle_distribution` receives the exact `kind` and `rounding` pair selected
  by the count and spread rules;
- descriptor fields have one schema-defined order; and
- `direct_spawn_count` and `maximum_spawn_count` are added from the checked
  integer graph.

Duplicate array entries fail rather than disappearing during sorting. JSON
object iteration order, directory enumeration and filename order, authored
descriptor order, GameMaker instance order, and presentation state cannot
alter the normalized plan.

The validator is a pure headless boundary over decoded JSON. It creates no
GameMaker or runtime instances, resolves no room resources, advances no clock,
and consumes no RNG. Validating the same loaded records produces the same plan
and diagnostics regardless of ambient game or presentation state.
