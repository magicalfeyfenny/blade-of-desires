# Deterministic kernel contract

Issue #7 establishes the project-owned deterministic seam used by later Blade
gameplay systems. The current seam is `blade.simulation.v2`, runs at 60 Hz,
and uses `blade.xoshiro128ss.v1`. It is a simulation foundation, not a complete
game loop or replay service.

## Module ownership

| Module | Single responsibility |
| --- | --- |
| `BladeCanonicalEncoding` | Exact integers, UTF-8 length framing, ordered records, and SHA-1 hashing. |
| `BladeSimulationClock` | Rational 60 Hz accumulation, direct stepping, domain counters, and overrun reports. |
| `BladeInputBindingRegistry` | Versioned stable binding IDs and their movement-axis or action-bit semantics. |
| `BladeInputSnapshot` | Injected semantic input sampling, edge latching, and immutable per-tick values. |
| `BladeRandomStream` | Versioned named PRNG streams and their diagnostics. |
| `BladeRunIdentity` | Typed run-local allocation plus injected content-ID validation. |
| `BladeEventLog` | Closed event schemas, deterministic ordering, canonical records, and channel separation. |
| `BladeSessionHeader` | Construction-time compatibility fields and their canonical header. |
| `BladeDeterministicKernel` | Thin composition, tick dispatch, transcripts, and the final gameplay hash. |

Gameplay code receives time, input, IDs, RNG streams, and an open event tick
through the kernel. It must not poll platform input or call GameMaker's ambient
`random`, `irandom`, or `random_range` functions.

## Clock and presentation updates

The clock represents elapsed microseconds without a rounded tick duration:

```text
accumulator_units += delta_us * 60
available_ticks = accumulator_units div 1_000_000
```

`delta_us` is a nonnegative exact integer. One threshold is therefore exactly
one sixtieth of a second, including across sequences whose individual deltas do
not divide evenly into 1,000,000 microseconds.

`BladeSimulationClockAdvance` runs at most the configured
`max_catch_up_ticks`. It subtracts each executed tick, reports any whole excess
as `dropped_ticks`, adds that number to `total_dropped_ticks`, and removes only
those whole units. The retained `remainder_units` is always less than 1,000,000
and is also the interpolation numerator over denominator 1,000,000. Dropped
wall-time ticks do not advance simulation counters. The returned report exposes
the available, executed, dropped, overrun, remainder, and counter values.

The master simulation counter always advances on an executed tick. The caller
supplies a `BladeClockDomain` mask, or a callback that returns one before each
tick, to advance the independent stage, actor, boss, and combat counters.
Eligibility expresses whether a domain advances; it does not own pause policy.

The numeric bits remain `Stage = 1`, `Actor = 2`, `Boss = 4`, and
`Presentation = 8`. Version 2 adds `Combat = 16`, so `All = 31`. Combat owns
emission, collision, damage, and reward advancement independently from broader
actor behavior.

Callback arguments are GML methods. Bind a named script reference explicitly
with `method(context, script)` before injection; this keeps numeric enum masks
distinct from GameMaker's numeric script references. Invalid deltas, direct
counts, numeric masks, and raw samples fail before clock, input, or presentation
state changes.

Presentation advances once per presentation update, even when no simulation
tick is available. Accumulator catch-up masks out the presentation bit so that
multiple simulation ticks cannot duplicate it. The kernel's direct-step path
likewise samples and marks one presentation update, then runs any requested
number of exact simulation ticks with presentation masked out. The lower-level
single-tick clock API honors an explicitly supplied presentation bit, so direct
callers outside the kernel are responsible for the same rule.

## Input snapshots

`BladeInputRawStateCreate` accepts injected scalar semantics, never platform key
codes. Movement is quantized to `[-1024, 1024]`; optional analog axes are
quantized to `[-32767, 32767]` and forced to zero when absent. The fixed action
bits are fire, bomb, focus, pause, confirm, and cancel. Prompt-device identity is
carried for presentation diagnostics.

The version 1 input-binding registry gives persisted bindings stable identity
without storing platform key or button codes in the deterministic seam. Its
canonical order and semantic mappings are:

| Stable ID | Semantic kind | Mapping |
| --- | --- | --- |
| `input.move_up` | movement | `move_y = -1024` |
| `input.move_down` | movement | `move_y = 1024` |
| `input.move_left` | movement | `move_x = -1024` |
| `input.move_right` | movement | `move_x = 1024` |
| `input.fire` | action | `BladeInputAction.Fire` (`1`) |
| `input.bomb` | action | `BladeInputAction.Bomb` (`2`) |
| `input.focus` | action | `BladeInputAction.Focus` (`4`) |
| `input.pause` | action | `BladeInputAction.Pause` (`8`) |
| `input.confirm` | action | `BladeInputAction.Confirm` (`16`) |
| `input.cancel` | action | `BladeInputAction.Cancel` (`32`) |

`BladeInputBindingRecords` returns all records, or a requested subset, in that
canonical order. Requests containing an unknown or duplicate ID fail closed.
`BladeInputBindingRecord` returns one known record. Both APIs return detached
records, so caller mutation cannot change later lookups. Movement records map to
the existing `move_x` and `move_y` arguments and have no action-bit field. Action
records map one-to-one to the existing six bits and have no movement fields, so
the action mask and gameplay-hash encoding remain unchanged.

These stable IDs name bindable semantics; they are not keyboard scancodes,
gamepad button numbers, or display labels. Default keyboard/gamepad codes,
conflict handling, serialization, and recovery belong to config persistence.
Listening and remap UI belong to the input-settings presentation layer.

The sampler requires exactly one sample for each monotonically consecutive
presentation frame. It compares the new held mask with the previous one and ORs
pressed and released bits into pending latches. A simulation tick whose Actor
domain is ineligible publishes zero edges without consuming the latches. The
first Actor-eligible tick receives all pending edges and clears them; later
catch-up ticks receive no duplicate edge. Current held, movement, and analog
state carry to every published tick. Multiple transitions before an eligible
tick can therefore intentionally publish both a pressed and released bit.

The authoritative snapshot is the immutable string
`BIS1|simulation|presentation|move_x|move_y|held|pressed|released|device|analog_present|analog_x|analog_y`.
`BladeInputSnapshotRead` validates and re-encodes it, then returns a fresh view;
mutating that view cannot change the string or any earlier frame. The gameplay
input transcript re-encodes only simulation frame, movement, action masks, and
analog state. Presentation frame and prompt device do not enter the gameplay
hash.

## Named random streams

The PRNG contract is `blade.xoshiro128ss.v1`. Its state is four unsigned 32-bit
lanes represented as nonnegative `int64` values. All transition arithmetic is
reduced modulo 2^32. Multiplication is implemented from 16-bit halves, and
rotations are masked to 32 bits, avoiding dependence on signed 32-bit overflow.

A supplied exact integer seed is normalized modulo 2^32 into `[0, 2^32)`. A
stream's initial state is derived independently of construction order by hashing
these exact UTF-8 bytes, where `<LF>` is the single byte `0x0A`:

```text
blade.xoshiro128ss.v1<LF><normalized-seed-decimal><LF><stream-name><LF>
```

The first 32 hexadecimal SHA-1 digits become four big-endian 32-bit state lanes.
If all four lanes are zero, lane 0 becomes `0x9E3779B9`. Construction and reset
consume no draw.

For state `[s0, s1, s2, s3]`, `next_u32` returns and performs these transitions
in order, with every lane and intermediate marked `mod 2^32` reduced to 32
bits:

```text
result = rotl32((s1 * 5) mod 2^32, 7) * 9 mod 2^32
t = (s1 << 9) mod 2^32
s2 = s2 xor s0
s3 = s3 xor s1
s1 = s1 xor s2
s0 = s0 xor s3
s2 = s2 xor t
s3 = rotl32(s3, 11)
```

Every `next_u32` transition increments the signed-64-bit draw count once and
fails rather than overflowing its maximum. `next_unit` consumes one draw and
returns `next_u32() / 2^32` in `[0, 1)`.
`next_range(minimum, maximum_exclusive)` requires a positive span no greater
than 2^32 and uses rejection sampling:

```text
limit = 2^32 - (2^32 mod span)
draw until raw < limit
result = minimum + (raw mod span)
```

Each rejected candidate is still a draw. Range endpoints must be exact integers
within GameMaker's exactly representable real-integer bounds.

The closed stream names are `stage_schedule`, `enemy_spawn_variant`,
`pattern_geometry`, `drop_selection`, and `cosmetic_effects`. The first four are
gameplay streams. `cosmetic_effects` has isolated state and draw count and is
excluded from the gameplay hash.

## Content and run-local identity

`content/product_contract.json` from Issue #6 remains the sole canonical
content-ID registry. Production constructs the kernel with a predicate backed
by that loaded contract; `BladeRunIdentity` stores only the injected callable
and never copies a second content-ID list. Unknown and empty content IDs fail
closed.
`BladeRunIdentityAllocateForContent` validates the content ID before it advances
the requested counter. The predicate must likewise be passed as a bound GML
method.

The current raw-file fingerprint is the SHA-1 of the exact bytes of
`content/product_contract.json`:

```text
d9a345101d9fa9971924bb2b9138a39dd5fd7c0b
```

The production bootstrap caller owns hashing and verifying those exact raw
bytes, then supplies the validated session-header form
`sha1:d9a345101d9fa9971924bb2b9138a39dd5fd7c0b`. `BladeSessionHeader` does not
read or re-hash the registry; it validates the lowercase `sha1:<40hex>` syntax
and binds the supplied value. The `H1` header also binds format version 1,
`blade.simulation.v2`, `blade.xoshiro128ss.v1`, tick rate 60, and the normalized
run seed, in that order.

Independent counters start at 1 and produce `ins:<n>`, `atk:<n>`, `blt:<n>`,
`dmg:<n>`, `own:<n>`, and `evt:<n>` for instances, attacks/sweeps, bullets,
damage events, event owners, and deterministic gameplay events. Validation
checks the expected prefix, canonical positive decimal, and that the ordinal was
already allocated. Presentation records use a separate `pev:<n>` sequence.

## Events and canonical gameplay state

The event type/reason vocabulary is closed. Every event also requires an
allocated `own:<n>` owner and a content ID accepted by the injected Issue #6
predicate.

| Type | Allowed reason or reasons | Source -> target |
| --- | --- | --- |
| `instance.spawned` | `outcome.scheduled`, `outcome.defeat_child` | empty -> `ins`, or parent `ins` -> child `ins` |
| `attack.started` | `outcome.input_pressed`, `outcome.scheduled` | `ins` -> `atk` |
| `bullet.spawned` | `outcome.pattern_emitted` | `atk` -> `blt` |
| `damage.applied` | `outcome.collision_confirmed` | `blt` -> `ins` |
| `damage.transaction_applied` | `outcome.collision_confirmed` | `dmg` -> `ins` |
| `instance.removed` | defeat, owner/room/run cleanup, stage/out-of-bounds cleanup, or phase cancellation | `ins` -> empty |
| `attack.cancelled` | owner/expiration/room/run cleanup or phase cancellation | `atk` -> empty |
| `bullet.removed` | owner/expiration/offscreen/hit-budget/room/run cleanup, stage cleanup, phase change, or projectile cancellation | `blt` -> empty |
| `damage.cancelled` | `cleanup.owner_removed`, `cancel.phase_change` | `dmg` -> empty |
| `reward.requested` | `outcome.defeated` | `ins` -> empty |
| `presentation.effect` | `presentation.requested` | empty -> empty |

The `outcome.*` reasons record successful gameplay facts. Cleanup and
cancellation cannot impersonate success. Unknown type/reason pairs fail before
event-ID allocation. Numeric payload entries are `i32`, `u32`, `q10` (raw
1/1024 units), or `bool01`; their ASCII keys are sorted and duplicates fail.

Canonical data does not rely on struct-key or JSON ordering. A string field is
framed as `<UTF-8-byte-length>:<value>`, and a record is its ASCII version prefix
followed by caller-supplied fields in fixed order. Hashes are lowercase SHA-1 of
the exact canonical UTF-8 bytes.

Ticks begin and commit in strictly increasing order. Before commit, queued
events sort by numeric `order_key`, then ASCII source ID, target ID, owner ID,
type, reason, content ID, and canonical payload; enqueue ordinal is the final
tie-breaker. Gameplay `evt` IDs are allocated only after that sort. An `E1`
record then contains event ID, tick, type, reason, source, target, owner,
content, payload count, and the sorted payload triples. Gameplay and
presentation records enter separate logs. Queue calls return detached diagnostic
copies, and commit rebuilds and revalidates pending records before allocating
any event ID.

The final `G2` gameplay hash includes, in fixed order:

1. the canonical session header;
2. the gameplay input transcript;
3. the `C2` simulation, stage, actor, boss, and combat counters;
4. name, four state lanes, and draw count for each gameplay RNG stream in registry order;
5. all six typed-ID allocation counts;
6. canonical gameplay events; and
7. an `ST1` state transcript containing one `T1` record of simulation tick and callback fragment for every executed tick (the fragment is empty when the callback is absent or returns undefined).

It excludes accumulator remainder and drop diagnostics, presentation frame and
counter, prompt-device identity, the cosmetic stream, and presentation events.
Those values remain available for interpolation, display, effects, and
diagnostics without changing gameplay authority.

## Reset and test entry

`BladeDeterministicKernelReset` clears the accumulator, total dropped-tick count,
all clock counters, input samples and edge latches, typed-ID counters, event
queues and logs, presentation frame, and gameplay transcripts. Every RNG stream
returns to its originally derived state with draw count zero. The
construction-time canonical session header, injected content predicate, and
configured maximum catch-up are retained. Replaying the same seed, supplied
content fingerprint and predicate, input samples, eligibility, draws,
allocations, events, and callback fragments therefore reproduces the same
canonical output.

Run the project-owned GameMaker suite with:

```sh
zsh tools/run_blade_kernel_tests.zsh
```

The harness compiles the VM macOS target with Igor using
`--assetCompiler=--sdlm`, then launches `Mac_Runner` with `--run-test`. The
startup room `r_blade_kernel_tests` runs the project-owned suite once and ends
the game before the GMTL demo. The runner object ignores launches without the
explicit test flag. Compile attempts retry only bounded crash/timeout or
artifact-less-success cases, and both compiler and runner process groups have
configurable timeouts. The harness requires a nonzero all-pass summary and
exactly one `BLADE_KERNEL_TEST_RESULT: PASS` sentinel. The imported, known-red
GMTL demo output and its known-unsound matchers are deliberately not acceptance
evidence.

## Deferred scope

The deterministic kernel itself does not own pause tokens, run/player state,
configuration, or combat transactions; the project-owned runtime layers compose
those systems over its clocks, IDs, events, and transcripts. Save/replay files,
migrations, playback, remapping UI, emitters, stages, encounters, patterns,
bosses, scoring, rank, graze, hyper, deathbomb, player weapons, menus,
rendering, audio, UI, 3D, and assets remain outside this kernel contract. It
does not modify the GMTL vendor boundary or lock.
