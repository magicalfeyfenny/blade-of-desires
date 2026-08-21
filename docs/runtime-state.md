# Runtime state ownership

Blade's project-owned runtime layer separates deterministic run state, pause
ownership, mutable per-user configuration, and repository content. These
boundaries are part of the public contract: callers submit commands to the
owner and consume detached snapshots instead of retaining mutable internal
records.

## Authority and lifetime

| Data | Authority | Lifetime | Persistence |
| --- | --- | --- | --- |
| Ship, difficulty, and input-binding IDs | Product contract and input-binding registry | Repository version | Canonical repository data; never rewritten by the game |
| Run and player state | `BladeRunCoordinator` | One run attempt | Not persisted by this layer |
| Pause tokens and diagnostics | Coordinator-owned `BladePauseRegistry` | One run attempt | Not persisted by this layer |
| Display, audio, and bindings | `BladeConfigService` | Per-user installation | `blade-config.json` in GameMaker's per-user save area |
| Career, scores, suspended runs, checkpoints, and replays | Not implemented | Future subsystem | Must use distinct schemas, filenames, serializers, and services |

The config service has no reference to the coordinator or pause registry. Its
closed schema drops run-shaped fields, and the cross-boundary test proves that
saving and loading config neither serializes nor mutates live run, player, or
pause state.

## Run and player ownership

`BladeRunCoordinatorCreate` establishes the sole mutable owner of a run. It
builds a deterministic kernel, run record, player record, and pause registry
from these explicit inputs:

- the content-contract fingerprint and known-content predicate;
- a known `ship.*` ID and `difficulty.*` ID;
- `BladeRunMode.Normal` or `BladeRunMode.Practice`;
- a run seed and maximum catch-up count.

The fingerprint must be lowercase `sha1:` followed by exactly 40 hexadecimal
digits. The seed is an exact integer normalized modulo 2^32 into 0..4294967295.
The catch-up cap defaults to 8. Reset retains the original fingerprint,
predicate, and cap while accepting a new selection, mode, and seed.

Current difficulty role IDs are `difficulty.easy`, `difficulty.normal`, and
`difficulty.hard`. Names such as Breeze, Arcade, and Storm are content display
text, not state identifiers. Equal construction inputs produce equal initial
canonical state without consulting wall-clock time or ambient randomness.

Each fresh attempt owns `own:1` as its run event owner and `ins:1` as its
player. The player starts active at simulation tick zero. Public snapshots,
diagnostics, pause records, and simulation callback arguments are detached;
none exposes the owned kernel or mutable registry.

Run mode and lifecycle are separate:

| Dimension | States | Contract |
| --- | --- | --- |
| Mode | Normal, Practice | Practice executes the same deterministic runtime but can never report a recordable Normal result |
| Run lifecycle | Active, Completed, Aborted | Only Active runs advance; completion and abort are terminal |
| Player lifecycle | Active, Released | Completion and abort release the player at the same authoritative simulation tick |

`BladeRunCoordinatorCanRecordNormalResult` is true only for a completed Normal
run. It does not write career or score data. Invalid lifecycle transitions and
attempts to advance a terminal run fail closed.

Reset first builds and validates an entirely fresh attempt. Only after that
succeeds does it close the old pause boundary and swap the kernel, pause
registry, and state together. Reset is valid from active or terminal state,
accepts a new ship, difficulty, mode, and seed, and restarts all run-local ID
frontiers, including pause token `pau:1`.

The coordinator canonical form binds its run/player selection and lifecycle,
the complete pause canonical form, and the deterministic kernel canonical form.
Callbacks receive only a run snapshot, immutable input snapshot, and detached
tick view. While any advance call is executing, completion, abort, reset, and
nested advance calls are rejected. Pause commands and detached queries remain
legal. A pause acquired by the live eligibility callback constrains that same
tick because registry resolution follows the callback; one acquired by the
simulation callback constrains the next tick. The advancing guard is cleared in
a `finally` block after either success or callback failure, so it cannot strand
the coordinator.

## Pause ownership

A version 1 pause token records:

- stable token ID `pau:<ordinal>`;
- allocated run-local event-owner ID;
- lowercase stable `pause.*` reason;
- a nonzero domain mask;
- authoritative acquisition tick;
- release policy.

Tokens may freeze only `BladeClockDomain.Stage`, `Actor`, and `Boss`.
`Presentation` is deliberately not a pausable token domain; UI and presentation
work can continue while gameplay domains are frozen. Eligibility for each tick
is resolved as the caller's live mask minus the union of all active token
domains. Multiple owners can therefore freeze the same domain, and releasing
one token cannot resume it while another remains.

The coordinator allocates pause owners and derives acquisition, release,
transfer, and cleanup ticks from its own clock. Registry operations reject an
observation earlier than a token's acquisition before mutating state.

| Release policy | Normal lifetime behavior |
| --- | --- |
| `Explicit` | Owner releases the token directly; forced owner, room, or run cleanup emits a stable leak diagnostic |
| `OwnerDestroyed` | Owner-destruction cleanup releases the token |
| `RoomExit` | Room-exit cleanup releases the token |
| `RunBoundary` | May cross a room only after transfer to the persistent run owner; every run boundary releases it |

Owner destruction always releases that owner's tokens. A token whose declared
policy required a longer lifetime is diagnosed as a missing transfer. Room
exit retains only `RunBoundary` tokens already held by the run owner and
releases everything else. Completion, abort, reset, and load boundaries release
every token; an unreleased `Explicit` token emits `pause.leaked_token`.
Completion, abort, and reset are coordinator commands. Suspended-run loading is
outside this layer, but a future loader must apply
`BladePauseRegistryRunBoundary(..., BladePauseRunBoundary.Load, ...)` before it
replaces an attempt.

Unknown release and transfer requests, plus release and transfer owner
mismatches, do not consume token IDs or remove tokens. They emit the stable
codes `pause.unknown_release`, `pause.unknown_transfer`,
`pause.release_owner_mismatch`, and `pause.transfer_owner_mismatch`. Each
diagnostic consumes its own `pdiag:<ordinal>` ID and records the token, owner,
requested owner, boundary, and authoritative tick. Boundary commands return
detached reports of released, retained, and diagnostic records.

## Config version 1

The config payload is a closed `blade.config` schema at version 1:

| Group | Fields | Defaults and ranges |
| --- | --- | --- |
| Display | `fullscreen`, `window_scale`, `vsync` | `false`, `2` clamped to 1..6, `true` |
| Audio | `master_gain_percent`, `music_gain_percent`, `sfx_gain_percent` | 100 each, clamped to 0..100 |
| Bindings | `keyboard`, `gamepad` | One supported integer platform code for each stable binding ID |

The closed binding-ID set is `input.move_up`, `input.move_down`,
`input.move_left`, `input.move_right`, `input.fire`, `input.bomb`,
`input.focus`, `input.pause`, `input.confirm`, and `input.cancel`. Defaults use
arrow keys and the gamepad D-pad for movement, Z/face 1 for fire and confirm,
X/face 2 for bomb and cancel, Shift/left shoulder for focus, and
Escape/Start for pause. Shared fire/confirm and bomb/cancel physical defaults
are intentional; stable action identity remains distinct.

Load always starts from a fresh default value and overlays only recognized
version 1 fields. Declared numeric ranges are rounded and clamped; malformed
values fall back to their defaults. Unknown fields and binding IDs are dropped,
and unsupported physical codes fall back per binding. The serializer accepts
only canonical payloads and emits bindings in registry order.

Missing config returns defaults. Unsupported future versions return defaults
and attempt to copy the exact rejected source bytes to a versioned future
backup. Corrupt input is likewise copied exactly; after a successful backup, a
valid `.previous` payload is loaded and its republication is attempted when
available, otherwise defaults remain current. The result reports whether that
republication succeeded. Legacy versions are rejected rather than migrated.
When the live file is absent, load tries a valid `.previous` candidate before a
valid `.tmp` candidate. A normalized current file remains current in memory and
attempts a canonical rewrite; `rewrite_ok` reports whether that rewrite and
prior-live retention succeeded.

## Storage and recovery boundary

`BladeConfigService` accepts an injected six-operation storage adapter:
`exists`, `read_text`, `write_text`, `copy`, `move`, and `remove`. The production
adapter binds those operations to GameMaker file APIs. Service filenames must
be a single relative basename, so `blade-config.json` remains inside the
platform's per-user save area and never mutates `content/` or `assets/`.

For live path `F`, replacement writes `F.tmp`, rereads it for an exact byte
match, moves an existing live file to `F.previous`, and promotes the temporary
candidate. If promotion fails, it attempts to restore the previous file.
Rejected-file backups use the same recoverable target protocol but copy the
source so the rejected live bytes remain untouched. Stable result codes and
recovery paths expose cleanup, archive, promotion, and rollback failures.

This is a failure-recoverable protocol, not a claim of filesystem atomicity.
GameMaker does not provide an overwrite-atomic rename, directory synchronization,
or `fsync` guarantee here. A crash or platform failure can leave `.tmp` or
`.previous`. Load consults those recovery siblings only when the live file is
absent, trying a valid `.previous` payload before a valid `.tmp` payload.

## Validation

The project-owned test entry point is registered without changing locked GMTL
files. Run the GameMaker characterization suite with:

```sh
zsh tools/run_blade_kernel_tests.zsh
```

The suite covers deterministic construction and reset, lifecycle rejection,
callback isolation, overlapping pause ownership and cleanup, presentation while
paused, config defaults/normalization/round trips, exact corrupt/future backups,
injected transaction failures, the production save-area adapter, and the
config/run ownership boundary.
