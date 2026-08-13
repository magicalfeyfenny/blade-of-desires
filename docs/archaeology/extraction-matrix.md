# Extraction Matrix

This matrix ranks what the archive can contribute to Blade. “Extract” means preserve a behavior contract, data shape, fixture, or clearly owned implementation idea through a future governed issue. It does not authorize copying code or assets now.

## Decision rules

1. Prefer the most maintained, complete, and testable iteration of a repeated system.
2. Preserve exact observed behavior as characterization evidence before redesigning it.
3. Adapt contracts and data rather than copying monolithic object events or rooms.
4. Require one runtime owner for time, pause, damage, reward, save, surface, buffer, audio, and content state.
5. Put canonical structured content once under `content/` with schemas, stable IDs, validation, and migration.
6. Keep third-party imports versioned, licensed, locked, and read-only. Current `origin/dev@6b938aa` has a fail-closed lock for GMTL v1.2; its missing retained MIT notice and known matcher defects remain separate readiness concerns.
7. Re-author themed, undocumented, team-owned, or third-party media unless provenance explicitly permits use.
8. Treat every stored test result as historical until reproduced against an exact candidate.

## Priority 0: foundations

| Candidate | Preferred evidence source | Preserve | Repair/rebuild before use | First characterization evidence |
|---|---|---|---|---|
| Fixed simulation clock | Selkies centralized state/input snapshot and documented clock gap; THPJ3 stage/boss pause; Shale fixed-rate test clock | Separate stage, actor, presentation, and real-time domains | One clock service, fixed tick, accumulator/overrun policy, pause tokens, no ambient alarms/timeline time | Tick-order table; pause nesting; replay hash |
| Deterministic RNG streams | Selkies' documented RNG gap; GDD replay intent; seeded texture scripts | Declared seed and reason-specific randomness | Replace every ambient RNG call; own/version the PRNG; stream IDs for stage, emitter, loot, cosmetic | Same seed/input/content produces same events and state hash |
| Input snapshot/action layer | Neuro's Input use; Selkies controls; archived menus | Named actions, device parity, focus/hold/long/repeat concepts | Choose small project layer or vetted Input dependency; fix Neuro's missing gamepad verbs | Keyboard/gamepad matrix and frame snapshot/replay test |
| Canonical content schemas | Blade GDD/current decisions; THPJ3 and legacy pattern corpora; shared dialogue; Selkies stable IDs | Human-readable data and explicit IDs | Split run, ship, difficulty, stage, emitter, boss, dialogue, encounter, audio registries; schema versions | Golden parsing, reference integrity, deterministic normalization |
| Run-state owner | Blade GDD run contract and Selkies session model | Lives, bombs, hyper, score, rank, difficulty, ship, stage state | Eliminate parallel object globals and HUD/save ownership | New/reset/continue/practice lifecycle transitions |
| Damage/destruction transaction | Selkies damage pipeline; Shale hit components; THPJ3/Blade defects | Faction, hurtbox, damage, invulnerability, death, cleanup, reward | Reason-coded destruction and exactly-once reward; no Destroy-side scoring | Kill/offscreen/dialogue/bomb/room-exit reward matrix |
| Stage sequence executor | Blade GDD story beats; THPJ3/Faewind pacing; Selkies routes | Ordered timed events, named anchors, waits, dialogue/boss gates | Author new Blade stages; replace coordinate timeline moments with data nodes and completion predicates | Exact event order/ticks; pause and resume; invalid anchor errors |
| Pattern/emitter executor | THPJ3 13 fixtures; TMoLaD, Tiny Girl, Split+Balance, and Ghost specimens | Pattern vocabulary, parameters, representative bullet counts and trajectories | Deterministic emitter contexts, bounded spawn, ownership, no singleton/literal layer | Preserve all 13 THPJ3 counts plus selected legacy seeded trajectories |
| Boss phase plan | GDD phase/part rules; THPJ3 boss mode; TMoLaD ladder; Selkies plans | Approach/chat/charge/active, two-second recharge ring, phases, timeout, health, transformative part loss | Data-owned phases/parts, explicit boss/stage pause token, child cleanup, defeat transaction | Phase order, recharge duration, timeout/HP/part transition, clear reasons |
| Dialogue service | Converged THPJ3/THPJ5/Sunflowers JSON runtime; dialogue template | Envelope normalization, actors, ADV/narrate/NVL/silent, audio/voice/log/resume | Stable IDs, schema, registries, injected services, choices/conditions/localization | Legacy envelopes normalize identically; 201-frame corpus validation |
| Save/profile service | Dialogue-template loader; Neuro checkpoint intent; Selkies save design | Defaults, slots/previews, stable checkpoint intent, content flags | Versioned typed records, atomic write, migrations, corruption fallback, owned previews | Round-trip, missing/corrupt/future version, checkpoint rename/migration |
| Explicit 3D/2D render passes | Blade 3D template and Selkies; archived slice as defect/feasibility evidence | Perspective scenery then centered 270x360 orthographic gameplay plane and GUI; projections | Shared immutable buffers, offline conversion, state restore, world-space fog, cleanup | Projection round-trip; GPU-state contract; resource lifecycle |

## Priority 1: gameplay and presentation systems

| Candidate | Best archive idea | Required adaptation | Important rejection test |
|---|---|---|---|
| Ship profiles/options | GDD/current decisions plus THPJ3 and legacy shot specimens | Canonical ship data: Maynii all-around tracking/forward, Ciela spread, Kolar deliberately unresolved; symmetric focus naming and action input | Profile cannot mutate defaults; Kolar cannot acquire an invented role by schema default |
| Hyper/deathbomb economy | THPJ3 risk/reward: three tiers, accelerated enemy pressure, 40-frame cancel | One meter policy, explicit spend/refund/death transaction, clear difficulty effects | Exactly one cost/outcome for bomb, hyper, deathbomb, and death |
| Rank director | Blade GDD plus Selkies bounded director | One bounded value, named reasons, deterministic multipliers, practice lock | No enemy may change global rank directly |
| Graze | THPJ3 proximity scoring concept | Per-player/per-projectile once-only record, declared reset/recycle semantics | Staying near one bullet cannot score repeatedly |
| Encounter-owned gates | Sunflowers gates and Neuro doors/buttons/levers | Stable encounter ID, member registry, objective completion, explicit gate ownership | Unrelated enemy death cannot open another encounter's gate |
| Trigger/Activator conditions | Shale Trigger/Activator plus Neuro tutorial/talk triggers | Typed predicates/effects, stable IDs, persistent fired state, serialized references | Missing target/predicate reports content error, not silent false |
| Player/drone traversal | Neuro grounded/command/fly/retrieve loop | Small player/drone/interaction states, LOS contract, navigable motion, pre-companion death fallback | Drone cannot cross blocked geometry or target stale instance |
| Interaction highlighting | Neuro silhouette shader and LOS feedback | Project-owned selectable interface, clear valid/invalid cues, draw-state restoration | Highlight cannot leak blend/shader/colour state |
| Player weapon modes | Sunflowers shot/flame/radial laser/missile; Faraii tap/hold laser | Weapon data, ammo policy, emitter/beam components, consistent hit cadence | One beam cannot apply accidental unbounded per-frame damage |
| Clone/split/merge | Shale mirrored clone mechanics | Clean-room component/state transfer with stable identity and deterministic merge | No resource alias, null signal payload, or off-thread scene construction |
| Projectile/status components | Shale penetration and freeze shells | Faction filters, penetration budget, status owner, break event, typed resistances | Penetration and shell damage cannot double-consume or double-reward |
| Camera service | Neuro lead/mouse-look/shake; Selkies route cameras | Logical camera, named anchors, bounded shake channels, projection integration | Dead camera uses correct respawn axis; pause does not corrupt camera |
| Pause ownership | THPJ3 boss/timeline, shared dialogue, THPJ5 snapshot, Shale cutscene stack | Reference-counted/tokenized pause domains and owned surfaces | Releasing dialogue cannot resume a game still paused by menu/cutscene |
| Menu state model | THPJ5 title machine; recovered 432-line renderer; template repair | Data-driven screens, small controller, temporary options transaction | Discard truly rolls back; save mutation is separate from drawing |
| Audio priority/resume | Shale interactive music and Selkies audio ownership | Stable cue registry, priority stack, resume position, group settings | Lower-priority cue cannot interrupt; disposed player cannot resume |
| Dialogue builder | `ai-gen-test/tools/dialogue_builder` interaction model | Schema-derived editor, stable IDs, registry validation, exact runtime preview | Import/export round-trip; quote-safe HTML; invalid root visible |
| Asset export pipeline | Current repository policy; procedural archive scripts as references | Editable source, deterministic converter, runtime derivative, manifest hash | Runtime output without source/manifest is rejected |

## Priority 2: selective effects and content references

| Candidate | Source | Keep as | Conditions |
|---|---|---|---|
| Hidden ground targets | Faraii bee/laser interaction | Mechanic prototype | Stable ground/world transform and bounded reveal feedback |
| Batched bullet glow | Faraii glow controller | Rendering optimization/effect reference | Registry removes stale IDs; blend state restored; performance measured |
| Master-spark beam | Sunflowers | Boss effect and expansion-timing reference | Beam hit cadence, telegraph, bounds, and cleanup tested |
| Homing familiar | Sunflowers Guardian | Summon/escort pattern reference | Encounter ownership and capped instances |
| Water-as-ammo | LD42 | Environment/resource design seed | Complete damage/collection/feedback loop first |
| Polarity combat | GMC Jam 7 | Damage-channel and stance idea | Symmetric invulnerability, readable channel state, explicit formula |
| Charge/store/volley bow | Double Jammy | Weapon timing idea | Replace timeline-position mistakes and XOR conditions |
| LOS/search AI | LD21 | Perception-state vocabulary | Move collision/state mutation out of Draw; spatial queries and tests |
| Pseudo-3D wrap arena | LD22/Twinblade | Movement/presentation reference | Correct angle units, one player authority, draw-state discipline |
| Camera-local world | LD23 | Transform experiment | One logical world space plus explicit render conversion |
| Route choreography | THPJ3, Sunflowers, Neuro, Selkies | Cadence/beat reference | Convert coordinates/moments to named anchors and data events |
| Procedural palette families | Archived Blade generators | Disposable palette/seed experiments only | Do not treat one-shot generated art as Blade authority; use governed image generation and KRA-to-PNG production assets |
| RTS and strategy notes | Scanned design document | Design vocabulary | Prototype independently; document is concept evidence, not implementation |

## Preferred authority by repeated lineage

| Family | Original/provenance authority | Reusable-system authority | Do not confuse with authority |
|---|---|---|---|
| TMoLaD / GMC Jam 3 | Either identical selected implementation; preserve project identity separately | Neither is a maintained template; characterize then rewrite | Duplicate payload is not two independent systems |
| THPJ3 | Public/local `4545a9a` for original jam | Packed THPJ3 for migration; vertical template for fixed score/tests | Original TXT dialogue and stale late timeline moments |
| THPJ5 | Initial local `tyvnj2@7996066` or public full-game history for original content | Dialogue template for loader/runtime/menu repair | Current isolated `dbaa721` as a whole; pack's empty menu renderer |
| THSJ2022 | Public jam repository for provenance | Local action pack for shared dialogue; action-boss template for maintained script fixes/tests | Template name “boss” does not make the game a boss-rush architecture |
| Archived Blade | Local `ai-gen-test@a5fc25a` for one-shot generated code/history | Feasibility questions and defect fixtures only; use the GDD/current decisions for product authority and independent projects for mechanics | Its tuning, 12-event schedule, ship roles, art, or data model as corroborated Blade requirements; converted GameMakerProjects copy as a separate iteration |
| Neuro Jam 2 | Public/local `7bd215b` | Same gameplay plus clean-room rewrite; source Input upstream if adopted | Dirty metadata conversion as gameplay; dormant Neuro API as production SDK |
| Sunflowers | Packed jam game for authored content | Top-down template for three repaired scripts | 1,063 sunflower room placements as a world pipeline |
| Selkies Moon | Tracked selected graph and current project docs | Mature culmination patterns, adapted by explicit contract | Loose unregistered duplicates and historical runner logs |
| ShaleGame | Clean `dev@f46e3fa` for observed design | Clean-room behavioral adaptation only | Direct code import without a root license |
| Current Blade GMTL | `origin/dev@6b938aa`, v1.2 import plus exact 20-root/47-file fail-closed lock | Preserve the verified read-only boundary; restore/verify MIT notice and guard known broken matchers with project tests | Integrity lock as proof of matcher correctness/license retention; archived v1.1.1c as current authority |

## Explicit avoid list

Do not select these as foundations:

- original six-/eleven-/twelve-line dialogue formats except as migration fixtures;
- current incomplete `tyvnj2` graph;
- Neuro's inline dialogue or dormant Neuro API plugin;
- Escape Velocity's broken host bootstrap;
- Faraii's every-frame unbounded generator;
- Sunflowers' global “no enemies anywhere” gate condition;
- score granted in generic Destroy events;
- repeating THPJ3 graze without a per-bullet flag;
- raw DS-map/buffer persistence lifecycles;
- raw keys and global singletons in content/gameplay systems;
- coordinate-heavy room/timeline content copied wholesale;
- runtime OBJ/D3D parsing and existence-only VBUFF caches;
- cached/generated GameMaker output as source authority;
- the broad process-killing local GMTL runner;
- imported library fragments copied without notices/version boundary;
- Touhou, Neuro, team, font, audio, or third-party art without ownership clearance;
- any historical green log represented as a fresh test run.

## Proposed issue sequence

Each row below should become a separate bounded issue; this report does not create or authorize them.

1. Record authoritative Blade content IDs/contracts and current product decisions: centered gameplay plane, ship roles with Kolar deferred, in-plane enemy firing, boss recharge/part rules, render/UI/art requirements, and GDD story seams.
2. Implement deterministic clock, versioned RNG streams, immutable input snapshots, stable IDs, and reason-coded replay events.
3. Implement run/player state, pause-domain ownership, and the isolated config/persistence skeleton.
4. Implement damage/destruction/reward transactions, projectile identity, deterministic cleanup/cancellation, and the in-plane firing gate.
5. Implement the declarative emitter executor and characterize the THPJ3 cardinalities plus selected TMoLaD/Tiny Girl/Split+Balance/Ghost trajectories.
6. Implement stage executor, encounter registry, and boss phase/part plan using named anchors and recharge telegraphs.
7. Implement Maynii, Ciela, focus/options/hyper/deathbomb, and score/rank/graze on those foundations; leave Kolar unimplemented pending a chosen role.
8. Implement two-pass render lifecycle, camera-facing light billboards, and offline model conversion/manifest path.
9. Implement dialogue runtime, then save/profile/replay services and only then any authoring tool.
10. Re-author or clear provenance for selected art, audio, fonts, 3D assets, ornate UI, and the high-quality Stage 1 forest before importing runtime derivatives.

The GMTL integrity lock is already merged at `origin/dev@6b938aa`. Retained-license remediation and project-owned matcher guards remain separate dependency work and must not modify the vendor snapshot.

## Definition of “ready to extract”

A candidate is ready only when a future issue has:

- named source authority and exact revision/path;
- a behavior contract and preserved characterization fixtures;
- known defects explicitly excluded or tested;
- dependency/license/asset ownership decision;
- canonical data schema and ID ownership where applicable;
- target module owner and event/lifetime boundaries;
- deterministic validation plan;
- bounded resource/source changes consistent with repository policy;
- no reliance on a stored binary, cache, output log, or ambient global state.
