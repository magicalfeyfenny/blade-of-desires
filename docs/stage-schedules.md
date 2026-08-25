# Stage and encounter schedule contract

`content/stages/` contains Blade's canonical subordinate JSON contract for
deterministic stage schedules and encounter ownership. Version 1 defines a
bounded plan consumed by the GameMaker stage executor. It does not author a
production Stage 1 route, enemy, boss, cutscene, balance value, or story beat.

The checked-in `content/stages/neutral_v1.json` is deliberately neutral. Its
`stage_schedule.*` and `encounter_schedule.*` records exercise timing, typed
ports, owned participants, and completion. They do not map to or redefine the
product contract's `stage.*` or `encounter.*` campaign identities. A future
production-content issue must define that mapping deliberately rather than
inferring it from filenames or display names.

Run the headless validator with:

```sh
python3.12 tools/content/validate_stage_schedules.py content/stages
```

With no path argument, the command validates `content/stages`. It is silent on
success and reports deterministic `source: field.path: reason` diagnostics on
failure.

## Product binding and stable IDs

Every catalog binds the exact authoritative product contract through the
closed pair `product_contract.id` and `product_contract.content_version`.
Validation first validates `content/product_contract.json`, then requires all
loaded catalogs to match it. The product binding appears once at the root of a
normalized plan.

Every catalog, record, node, participant, typed port, signal, cue, type, and
anchor uses the product contract's lowercase dotted stable-ID grammar. All
definitions are globally unique across the complete loaded catalog set and
against every canonical product record ID. Definitions may be referenced
across loaded catalogs, but they may not be redeclared. Display names are
required labels and never resolve identity or ordering.

Stage schedule content uses subordinate namespaces:

| Definition | Namespace |
| --- | --- |
| Catalog | `stage_catalog.*` |
| Stage schedule | `stage_schedule.*` |
| Encounter schedule | `encounter_schedule.*` |
| Node | `stage_node.*` |
| Participant | `participant.*` |
| Named anchor | `anchor.*` |
| Participant kind | `participant_kind.*` |
| Task port and type | `task_port.*`, `task_type.*` |
| Signal and type | `signal.*`, `signal_type.*` |
| Presentation cue and type | `cue.*`, `cue_type.*` |

Version 1 has no implicit extensions. Unknown fields, unknown node kinds,
wrong namespaces, duplicate JSON member names, and nonstandard numeric values
such as `NaN` fail closed.

## Catalog records

A catalog is a closed object containing:

| Field | Meaning |
| --- | --- |
| `schema_version` | Exact integer `1`. |
| `id`, `display_name` | Stable catalog identity and nonempty label. |
| `product_contract` | Exact product `id` and `content_version` binding. |
| `named_anchors` | q10 anchor definitions inside the product gameplay plane. |
| `participant_kind_ids` | Available injected participant spawn-spec types. |
| `task_type_ids` | Available downstream task types. |
| `signal_type_ids` | Available stage-signal types. |
| `cue_type_ids` | Available semantic presentation-cue types. |
| `task_ports` | Typed injected task ports and their completion signals. |
| `signals` | Typed signals and their declared producers. |
| `cues` | Typed semantic presentation cues. |
| `stages` | Nonempty stage schedule list. |
| `encounters` | Nonempty encounter schedule list. |

Registry and definition lists may be empty in a catalog that reuses definitions
from another loaded catalog. The complete loaded union must resolve every
reference.

### Named anchors and q10 placement

Each named anchor has `schema_version`, `id`, `display_name`, `x_q10`, and
`y_q10`. The coordinates are exact integers in 1/1024 logical-pixel units and
must lie inside the product gameplay plane:

```text
189440 <= x_q10 < 465920
0 <= y_q10 < 368640
```

A spawn node selects one anchor and adds its `local_offset_q10`. Each encounter
participant then adds its own relative `local_offset_q10`. The validator proves
the final point for every participant and every spawn node remains inside the
same half-open plane. No node names a GameMaker layer, room coordinate, object,
or singleton.

Participant local offsets and spawn-node local offsets contain exactly `x` and
`y`, each an integer from `-1,000,000` through `1,000,000` q10 units. The
bounded range prevents unreasonably large arithmetic while the final-point
check owns geometric eligibility.

At runtime, `participant_kind_id` resolves through an injected, prevalidated
spawn-spec registry. A resolved spec owns combat content identity, faction,
health, AABB, reward policy, and other combat fields. Stage JSON does not
duplicate those future enemy definitions. Every participant kind and final
position must resolve for the complete encounter batch before any gameplay ID,
event, RNG draw, token, or runtime command is consumed.

## Typed ports, signals, and cues

Typed references always repeat both identity and expected type. There is no
untyped string fallback and no free-form version-1 payload.

A task port contains:

```json
{
  "schema_version": 1,
  "id": "task_port.example",
  "display_name": "Example port",
  "type_id": "task_type.example",
  "completion_signal": {
    "signal_id": "signal.example.completed",
    "type_id": "signal_type.example.task_completion"
  }
}
```

A cue contains the common record fields plus `type_id: cue_type.*`. A cue is a
semantic request only. It does not name an asset, sound, layer, Draw callback,
or presentation instance.

A signal contains the common record fields, `type_id`, and one closed source:

```json
{ "kind": "external" }
```

```json
{ "kind": "task_completion", "source_id": "task_port.example" }
```

```json
{ "kind": "encounter_started", "source_id": "encounter_schedule.example" }
```

```json
{ "kind": "encounter_completed", "source_id": "encounter_schedule.example" }
```

Task-completion and encounter-lifecycle source declarations must be reciprocal
with the port or encounter that names the signal. Encounter started and
completed signals must be distinct.

Content declares signal types and producers, but it does not author mutable
delivery tokens. Runtime task requests use `{stage_node_id,
execution_generation}` as occurrence identity. A task-completion delivery must
match the pending request's exact generation in addition to its signal ID and
type. Encounter signals likewise match the active encounter generation.
Duplicate, stale, wrong-type, and already-consumed deliveries fail without
advancing progression or consuming runtime identity.

## Stage schedules and forward graph

A stage schedule contains the common record fields, `entry_node_id`,
`terminal_node_id`, and a nonempty `nodes` list. Each node contains:

- `schema_version`, stable `stage_node.*` ID, and nonempty display name;
- unique `content_order`, contiguous from zero;
- one closed `kind` variant; and
- `next_node_id` for every nonterminal variant.

The entry node must be content order zero. Every `next_node_id` targets a
strictly higher content order, every node is reachable from entry, and exactly
one `complete` node matches `terminal_node_id`. Version 1 has no declared-cycle
shape, branch shape, or implicit fallthrough. All backward edges and cycles are
therefore undeclared and invalid. This deliberate linear boundary makes
same-tick order a content fact rather than an instance-order tie-breaker.

Immediate nodes commit in ascending `content_order` on the same eligible Stage
domain tick until execution reaches a blocker or the terminal. A blocker that
becomes satisfied on a later eligible tick permits its successor to execute on
that same tick. An ineligible or paused Stage tick performs no schedule work and
does not decrement a wait.

Version 1 accepts exactly these node variants:

| Kind | Variant fields | Behavior |
| --- | --- | --- |
| `wait` | `active_ticks`, `next_node_id` | Block for `1..1,000,000` later eligible Stage ticks. Entering on tick T with N completes on eligible tick T+N. |
| `spawn_encounter` | `encounter_id`, `anchor_id`, `local_offset_q10`, `next_node_id` | Submit one prevalidated encounter batch in participant `spawn_order`. |
| `wait_encounter_completion` | `encounter_id`, `next_node_id` | Block on that exact owned encounter generation. |
| `request_task` | typed `task`, `next_node_id` | Submit `{port_id, type_id}` to an injected downstream port. |
| `wait_signal` | typed `signal`, `next_node_id` | Block on an exact ID, type, source, and runtime correlation generation. |
| `emit_presentation_cue` | typed `cue`, `next_node_id` | Emit a semantic `{cue_id, type_id}` request. |
| `complete` | none | Sole explicit terminal; it has no `next_node_id`. |

The three immediate kinds are `spawn_encounter`, `request_task`, and
`emit_presentation_cue`. The three blocker kinds are `wait`,
`wait_encounter_completion`, and `wait_signal`.

Static validation also proves producer-before-wait relationships. An encounter
wait requires a preceding active spawn. A task-completion wait requires a
preceding pending request for that port. An encounter-lifecycle signal wait
requires a preceding spawn of its source encounter. An external signal has an
injected producer boundary. A stage cannot reach `complete` while an encounter
or task remains pending.

## Encounter ownership

An encounter schedule contains the common record fields plus `participants`,
`completion_predicate`, `cleanup_policy`, and `stage_signals`.

Each nonempty participant list uses unique, contiguous `spawn_order` values
from zero. A participant contains:

- stable `participant.*` identity and display name;
- registered `participant_kind.*` spawn-spec type;
- exact `spawn_order`;
- relative `local_offset_q10`; and
- `defeat_disposition`, exactly `remove` or `retain_harmless`.

The version-1 completion predicate is exactly:

```json
{
  "kind": "all_participants_defeated",
  "participant_ids": []
}
```

The list must contain every encounter participant ID exactly once. Normalized
order is participant spawn order. Only the selected Issue #9
`outcome.defeated` terminal for every registered participant satisfies the
predicate. Unrelated actors and global enemy or boss counts are never queried.
Cleanup, owner removal, room exit, run abort, reset, load, and any other
terminal reason cannot impersonate defeat or encounter completion.

`defeat_disposition: retain_harmless` retains only an encounter terminal view.
The defeated combat actor is removed through the ordinary terminal transaction;
the retained view cannot collide, emit, take damage, reward again, or hold a
gate.

The cleanup policy is closed to:

```json
{ "on_completion": "cleanup.stage_end" }
```

It applies to remaining encounter-owned participants after successful
completion. Abort, reset, load, room, and run boundaries continue to use their
authoritative Issue #9 terminal reasons; authored content cannot replace those
reasons with a success token.

`stage_signals.started` and `stage_signals.completed` are exact typed signal
references. Runtime emits each once for the corresponding encounter generation
and only after the authoritative transition has committed.

## Deterministic normalization

Successful validation produces one detached plan:

```json
{
  "schema_version": 1,
  "product_contract": {
    "id": "contract.blade",
    "content_version": "1.2.0"
  },
  "catalogs": []
}
```

Catalogs are ordered lexically by catalog ID. Within a catalog, anchors, bare
registries, task ports, signals, cues, stages, and encounters are ordered by
stable identity. Stage nodes use `content_order`; encounter participants use
`spawn_order`; completion participant IDs follow participant spawn order.
Duplicate authored entries fail rather than disappearing during sorting.

Normalized signal sources always contain exactly `kind`, `task_port_id`, and
`encounter_id`. Unselected fields are JSON `null`. The shared product binding
appears only at the plan root. Every other record retains its version-1 values
in schema-defined field order.

The product `content_version` remains a compatibility binding, not a version of
subordinate schedule values. A runtime replay or state hash must therefore bind
the canonical normalized stage-plan bytes, or a hash of those exact bytes, in
addition to the product-contract fingerprint. A stage-only content change must
not be invisible merely because `content/product_contract.json` did not change.

## Failure-before-side-effects boundary

The Python validator and normalizer are pure boundaries over decoded data. They
create no GameMaker instances, allocate no run-local IDs, advance no clocks,
draw no RNG, acquire no pause token, and submit no runtime command.

Runtime follows the same two-phase rule:

1. validate and normalize the complete loaded catalog union;
2. resolve every anchor, participant spawn spec, typed port, signal, and cue for
   the selected stage into one detached plan;
3. only after the whole preflight succeeds, create the executor and allocate or
   commit in deterministic content and spawn order.

Any failure in phases one or two leaves gameplay ID frontiers, task generations,
event queues, pause ownership, RNG draw counts, and command sinks unchanged.
Validation never attempts partial repair, default inference, or best-effort
execution.

## GameMaker runtime ownership

The GameMaker project bundles both `content/product_contract.json` and every
canonical `content/stages/*.json` file as Included Files. Public attachment
loads those JSON bytes, requires the bundled product file's exact SHA-1 to equal
the active run header fingerprint, verifies the catalog's product ID and
content version, and fingerprints the normalized stage plan separately. A
resolver then validates every selected-stage participant spawn specification
and final position before the executor is attached. Attachment allocates no
participant or event IDs and emits no command.

`BladeRunCoordinator` optionally owns one executor. On an eligible tick Combat
commits first, so the stage observes same-tick owned defeats; the stage then
advances while the kernel event-log tick remains open. A stage spawn therefore
becomes combat-eligible on the following Combat tick. Pausing the Stage domain
freezes stage ticks, execution generations, events, and outboxes while other
eligible domains, including Combat, may continue.

Each committed node appends one canonical stage event and consumes one shared
run-local `evt:*` ID. Stage events have a dedicated canonical stream, while the
shared identity frontier prevents collisions with ordinary gameplay events.
Task requests, semantic cues, signals, and stage events are append-only
outboxes read through consumer-owned cursors; reading or mutating a detached
result cannot acknowledge or change executor state.

Run reset restarts the same plan as fresh ownership and revalidates every spawn
spec against the new kernel and combat runtime before replacing the old
attempt. Abort, load, completion, and room-exit cleanup reconcile combat
terminal provenance before marking an active stage aborted. Room exit then
detaches that stage so the still-active run may attach the next schedule.
