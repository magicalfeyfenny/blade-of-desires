# Runtime state ownership

Blade's project-owned runtime layer separates deterministic run state, combat
ownership, pause ownership, mutable per-user configuration, and repository
content. These
boundaries are part of the public contract: callers submit commands to the
owner and consume detached snapshots instead of retaining mutable internal
records.

## Authority and lifetime

| Data | Authority | Lifetime | Persistence |
| --- | --- | --- | --- |
| Application focus, suspension, and shutdown | Persistent `o_blade_application` and `BladeApplicationLifecycle` | One application process | Not persisted; active runs are never serialized at this boundary |
| Ship, difficulty, and input-binding IDs | Product contract and input-binding registry | Repository version | Canonical repository data; never rewritten by the game |
| Run and player state | `BladeRunCoordinator` | One run attempt | Not persisted by this layer |
| Actors, attacks, projectiles, damage, terminals, and reward requests | Coordinator-owned `BladeCombatRuntime` | One run attempt or explicit room boundary | Not persisted by this layer |
| Stage schedule, encounter ownership, typed ports, and stage events | Optional coordinator-owned `BladeStageExecutor` | One attached stage or run reset | Not persisted by this layer |
| Pause tokens and diagnostics | Coordinator-owned `BladePauseRegistry` | One run attempt | Not persisted by this layer |
| Deterministic replay payloads | `BladeReplayRecording` recorder and playback owner | One captured recording or playback run | Canonical `BRP1` text in the replay catalog |
| Saved replay catalog | `BladeReplayCatalog` and the front-end replay pages | Per-user installation and one playback run | `blade-replays/*.brp`; identity comes from the payload hash, not display text or filenames |
| Display, audio, and bindings | `BladeConfigService` | Per-user installation | `blade-config.json` in GameMaker's per-user save area |
| Player profile, progression flags, and arcade records | `BladeProfileService` | Per-user installation | `blade-profile.json` in GameMaker's per-user save area; strict and separate from config |
| Suspended runs and checkpoints | Not implemented | Future subsystem | Must use distinct schemas, filenames, serializers, and services |

## Application lifecycle ownership

`BladeApplicationLifecycle` is the process-level authority for native focus,
platform suspension, and normal desktop shutdown. The persistent
`o_blade_application` object polls `window_has_focus()` and
`os_is_paused()` and exposes a detached observation to room-owned consumers.
The lifecycle states are `Active`, `Suspended`, `ShuttingDown`, and
`Terminated`; every boundary increments an epoch so each input owner can
discard edges captured before the boundary.

The native signals have different lifetimes. GameMaker documents
[`window_has_focus()`](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Cameras_And_Display/The_Game_Window/window_has_focus.htm)
as the current focus state on macOS, Windows, HTML5, and GX.games, while
[`os_is_paused()`](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/OS_And_Compiler/os_is_paused.htm)
is only a one-step focus-loss signal on macOS, Windows, Linux, and HTML5. The
owner therefore keeps the window-focus result as its durable suspension state
and uses the pause signal as supplemental evidence. On desktop,
[`game_end()`](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/General_Game_Control/game_end.htm)
triggers the Game End event at the end of the current step, so normal quit
releases run-owned state before calling it and native window close uses the
same idempotent cleanup path. Mobile quit behavior is platform-specific and
outside this desktop contract.

Focus loss or platform suspension enters `Suspended`. The front end stops
sampling input, and Stage 1's central gameplay gate rejects movement, timers,
combat, rewards, and schedule ticks for the inactive frame and every following
inactive frame. A clean focus return enters `Active`; the affected room owner
resets its live-input latch and discards the first boundary frame before
sampling again. This is distinct from the player pause menu, cutscene
puppeting, terminal Continue/Game Over, and Retry: those remain run-owned
semantic states and do not change application lifecycle state.

Menu quit, terminal quit, and the native Game End event all use the same
administrative shutdown path. An active Stage 1 route is aborted with no
completion or reward credit, the run-result ledger records
`cleanup.application_shutdown`, transient gameplay instances are released,
the selected run is cleared, and active replay recording/playback owners are
abandoned. Configuration and profile writes remain owned by their existing
synchronous transactional services; shutdown does not invent a save-anywhere
or suspended-run format. The lifecycle reaches `Terminated` only after these
owners have been released.

The config service has no reference to the coordinator, combat runtime, or
pause registry. Its
closed schema drops run-shaped fields, and the cross-boundary test proves that
saving and loading config neither serializes nor mutates live run, player, or
combat/pause state.

## Replay catalog ownership

`BladeReplayCatalog` owns discovery of the per-user `blade-replays/` directory,
strict BRP1 parsing, metadata projection, and deterministic playback launch.
The canonical replay hash produces a stable `replay.<sha1>` identity; a source
filename is only a storage locator. The catalog exposes `playable`,
`unsupported`, `corrupt`, `missing`, and `unreadable` states so an invalid or
removed source cannot strand the front end. The current BRP1 payload has no
terminal-result or score fields, so the catalog reports those values as
explicitly unavailable rather than deriving them from display text.

The replay catalog page refreshes the detached catalog snapshot on entry. A
playable selection launches the existing `BladeReplayPlayback` owner and opens
a simple playback page; every simulation tick comes from the recorded input
stream and live input is used only for menu Cancel navigation. Catalog
inspection and launch do not rewrite the source payload, profile, records,
unlocks, or configuration. A failed launch returns to the catalog with its
explicit state and a player-facing diagnostic.

## Run and player ownership

`BladeRunCoordinatorCreate` establishes the sole mutable owner of a run. It
builds a deterministic kernel, run record, player record, combat runtime, and
pause registry from these explicit inputs:

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

Stage 1's selected run is a version-2 identity carrying one of those three
difficulties. Its `BladeSurvivalEconomy` owns the attempt-local rank state,
which starts at integer rank `0` for Easy/Normal and `20` for Hard, clamps to
the selected difficulty's `0..25`, `0..50`, or `20..50` bounds, and is recreated
on retry. The rank event stream is canonicalized into the Stage kernel snapshot
and is never written to configuration, career, or replay storage.

The authored rank deltas are fixed and applied once per accepted action: active
play `+1` every 30 eligible ticks; normal Bomb `-3`; committed life loss `-15`;
normal Hyper `+5`; hit-response death-bomb Hyper `-5`; and hit-response
all-stock death-bomb Bomb `-10`. Rank does not advance during hit response,
respawn, pause, result, warning/cutscene, cleanup, or reward collection.
Difficulty and rank compose once over authored Stage 1 hostile speed, fire,
volley density, and pickup/reward values. Authored enemy HP and direct enemy
hit/defeat score remain invariant; Normal at rank zero retains the prior
cadence and volley cardinality.

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

The playable Stage 1 controller keeps terminal-death decisions separate from
the pause menu: the last committed death opens a semantic `Continue? Yes / No`
flow, Yes rebuilds the current room as a fresh attempt with the confirmed ship
and difficulty, and No closes the attempt before showing a fixed Game Over
window and returning to the main menu. Neither decision uses enemy defeat
cleanup or awards another outcome, and neither can be submitted twice.

Stage 1 also owns a version-1 `stage_run_result` boundary separate from the
legacy presentation `Playing / Rewarding / Won / Failed` state:

| Result phase | Authoritative meaning |
| --- | --- |
| `Active` | The attempt may still produce gameplay, defeat, retry, abort, or Game Over events |
| `StageClearCaptured` | The Stage Clear cue has captured one detached result before transient cleanup |
| `RunCompleted` | The schedule's explicit complete node has committed the completed run |

The clear payload copies the selected route and difficulty, session header and
seed, stage plan identity, run-local identity counters and gameplay hashes,
score, lives, bombs, Hyper state, rank event history, boss resolution, clear
bonus breakdown, and the stage tick at capture. Its transition record uses the
stable alpha destination `destination.stage1.results` and an explicitly
undeclared `next_stage_id`; no room order or presentation label can advance the
run. The Stage executor reaches its explicit `Completed` node while delivering
the clear cue; only after that cue is consumed may the result boundary create
the separate `RunCompleted` record. Duplicate clear and completion signals are
rejected.

The clear boundary applies its authored bonus, captures the detached payload,
then performs non-rewarding actor, projectile, shot, and item cleanup. Retry,
abort, Continue, and Game Over are recorded in the same attempt ledger as
administrative outcomes; cleanup never promotes an encounter or grants a
second result. The payload is runtime state only and is not yet persisted.

Reset first builds and validates an entirely fresh attempt. Only after that
succeeds does it close the old combat and pause boundaries and swap the kernel,
combat runtime, pause registry, and state together. Reset is valid from active
or terminal state, accepts a new ship, difficulty, mode, and seed, and restarts
all run-local ID frontiers, including pause token `pau:1`.

The `BRC3` coordinator canonical form binds its run/player selection and
lifecycle, the complete `BPR2` pause form, the `BCRUNTIME1` combat form, and the
deterministic kernel's `G2` form. When a stage is attached, `BRC3` appends its
complete `BSEXECUTOR1` form; coordinators without a stage retain their existing
bytes.
Callbacks receive only a run snapshot, immutable input snapshot, and detached
tick view. While any advance call is executing, completion, abort, reset, and
nested advance calls are rejected. Pause commands and detached queries remain
legal. A pause acquired by the live eligibility callback constrains that same
tick because registry resolution follows the callback; one acquired by the
simulation callback constrains the next tick. The advancing guard is cleared in
a `finally` block after either success or callback failure, so it cannot strand
the coordinator.

## Stage transaction ownership

`BladeStageExecutor` is the sole mutable schedule owner. The public loader binds
the exact bundled product-contract SHA-1 to the active run, normalizes the raw
stage JSON, fingerprints the normalized plan, and resolves every participant
spawn specification before attachment. It advances after Combat closes on each
eligible Stage tick, allowing same-tick combat terminals to satisfy only their
owned encounter gate. Spawns become available to Combat on the next tick.

Stage pause consumes no stage tick, ID, execution generation, event, or outbox
record, while other eligible domains may continue. Committed nodes own a
separate canonical event stream whose `evt:*` IDs share the kernel identity
frontier. Typed task requests, semantic cues, signals, and events are exposed as
detached cursor reads, never as mutable queues.

Reset constructs and binds fresh stage ownership before swapping attempts.
Terminal run boundaries retain the final stage report. Room exit applies its
authoritative cleanup reason, returns the aborted stage report, and detaches the
executor so the active run may attach another schedule. None of these
administrative reasons can satisfy an encounter's all-defeated predicate or
emit its completion signal.

## Combat transaction ownership

`BladeCombatRuntime` is the only mutable owner of active combat records.
`BladeRunCombatCommands` is the public coordinator-facing seam; snapshots are
detached and omit the shared identity allocator and active kernel tick.
The coordinator opens and closes the runtime around every simulation callback,
and its `BRCF1` callback fragment binds both caller state and the resulting
combat canonical state.

Every emitted attack and projectile records a run-local `atk:<n>` or `blt:<n>`
ID, faction, owner instance, attack relationship, content ID, simulation and
Combat spawn ticks, integer damage, cancellation power/policy, remaining
penetration and hit budget, lifetime, and terminal reason. Enemy requests pass
the same compiled product plane owned by #6 before either ID allocation or
event submission. The half-open point or fully-contained hurtbox rule is
evaluated for every request; previous entry and previous successful emission do
not authorize a later outside attempt.

Collision discovery is pure. Swept q10 AABBs produce candidates, then exact
impact fractions sort first; projectile numeric ID and target numeric ID are
the stable tie-breakers. Resolution alone applies integer health changes and
allocates `dmg:<n>` transactions. Faction, invulnerability, zero health,
per-projectile target history, and same-tick attack history reject damage before
allocation. GameMaker instance creation and candidate insertion order therefore
cannot choose the result.

Projectile cancellation is a pure symmetric pair rule. Equal power cancels
both without consuming penetration. Unequal power cancels the weaker member;
the stronger member consumes one penetration and survives only when it had one
available. Ignore policy, matching factions, and nonpositive power do not
interact.

Terminal requests are idempotent and commit by subject kind, then numeric
subject ID. For competing requests on one subject, priority from lowest to
highest is: out of bounds, expiration, exhausted hit budget, projectile
cancellation, defeat, owner removal, phase change, stage end
(`cleanup.stage_end`), room exit, run completion or abort, run reset, then run
load. Administrative cleanup therefore outranks a same-tick defeat and cannot
grant its reward or children. Rewards and recursive
Requests with equal priority use the numeric reason value, then the earliest
simulation tick and Combat tick. Rewards and recursive child declarations are
derived only from a selected zero-health defeat; the
test-only Ghost declaration proves one large defeat creates three medium actors
and their defeats create nine small actors.

Room exit, completion, abort, reset, and load prepare complete reason-coded
boundary plans between ticks and commit them without events, rewards, or child
spawns. `BladeRunCoordinatorLoadBoundary` closes the replaced attempt as
aborted; this is cleanup authority, not suspended-run serialization. Holding
the Combat pause domain freezes emission, projectile motion, collision, damage,
and rewards while Actor poses and Presentation may continue. Administrative
boundaries remain available while Combat is paused.

## Pause ownership

A version 2 pause token records:

- stable token ID `pau:<ordinal>`;
- allocated run-local event-owner ID;
- lowercase stable `pause.*` reason;
- a nonzero domain mask;
- authoritative acquisition tick;
- release policy.

Active tokens use `BPT2` records and the enclosing registry uses `BPR2` because
the closed pausable-domain set changed. Existing diagnostic record shapes keep
their version 1 prefixes.

Tokens may freeze only `BladeClockDomain.Stage`, `Actor`, `Boss`, and `Combat`.
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
Completion, abort, reset, and load cleanup are coordinator commands. Suspended
run serialization remains outside this layer; a future loader must call the
load boundary before it replaces an attempt.

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

## Profile version 1

The profile payload is a separate closed `blade.profile` schema at version 1.
It contains machine-readable `clear_states`, independently persisted
`unlocks`, `achievements`, `cg_flags`, and authoritative arcade `records`.
Display names, room names, resource order, and the configuration payload are
not progression authorities.

`BladeProfileService` is initialized beside `BladeConfigService` but owns a
different filename and storage transaction. A missing profile is an empty
default. Corrupt, unreadable, or future-version bytes report an explicit load
failure and remain untouched; the service cannot silently replace them with a
default profile. Writes stage JSON in a sibling temporary file, reread the
exact bytes, archive the previous live file, promote the candidate, and roll
back when promotion fails.

The current live consumer is the explicit Stage 1 `RunCompleted` boundary.
Only a completed live `BladeStage1RunResult` with a Stage Clear payload can
create a record, and it copies the captured score, ship ID, difficulty ID, and
run seed rather than recalculating economy. Replay, Continue, Retry, abort,
Game Over, cleanup-only, incomplete, and duplicate outcomes are rejected.
Clear states retain the no-continue qualification needed by the product
contract's future `main_campaign_1cc_any_difficulty` rule; the derived
`unlock.extra_stage` flag appears only after all six main-campaign stage IDs
have qualifying clears. Achievement and CG flags have independent service
grant paths so later presentation code can query them without owning
progression or save parsing.

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
