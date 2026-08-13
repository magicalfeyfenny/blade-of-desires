# Selkies Moon Reference Architecture

Path: `/Users/magicalfeyfenny/GameMakerProjects/selkies-moon`

Observed Git snapshot: clean `codex/64-validation-branch-lifecycle` at `a5a056ed0763e9722c6b2687904a23285cdcd6ac`, exactly its configured upstream at inspection time. That work branch differs from integration `origin/dev@ac9ea3e` only in four governance/workflow files; the gameplay, resources, content, and assets characterized here match `origin/dev`. Public release-pinned `origin/main` is separately at `cd1f35e`.

## Why this project is separate

Selkie's Moon is not another jam fragment to strip for parts. It is the mature culmination of many ideas seen in the older games: narrow-playfield shmup combat, rank, focus, sword/cancel mechanics, data-driven stages and bosses, story JSON, 2D-on-3D presentation, asset-source authority, semantic audio, persistence migration, practice, and a substantial regression suite.

For systems it already owns well, the correct question is “what contract should Blade share or adapt?” rather than “which older jam object should be copied?”

This pass was read-only and static. The repository's own validation documents contain historical and hosted evidence, but no GameMaker run was initiated here.

## Project inventory

The selected GameMaker graph contains:

- 21 objects;
- 23 scripts, including 12 imported GMTL v1.1.1c scripts (DAndrëwBox, 2025-09-23) and 11 project-owned modules/tests;
- 77 sprites;
- 30 sounds;
- 5 fonts;
- 5 unique rooms;
- 2 shaders;
- 21 included story JSON files;
- five OBJ/VBUFF stage pairs in the GameMaker data area.

The embedded GMTL copy is third-party test/compatibility evidence, not project-owned extraction code. No retained `LICENSE`, `NOTICE`, or `COPYING` file was found in the Selkies tree. Current Blade's separate v1.2 import now has an exact 20-root/47-file integrity lock, but it still needs a verified retained upstream notice and Blade-owned guards for known matcher defects.

The source-asset tree includes approximately:

- five canonical `.blend` stage scenes;
- 85 `.kra` raster masters;
- 16 MIDI bootstrap/reference files;
- native Logic score projects and a Logic SFX suite described by manifests and cue sheets;
- packed runtime atlases, audio derivatives, and VBUFFs under explicit source/runtime policy;
- original character sketches, portrait briefs, and licensed font-source records.

The 126 statically counted `test`/`it` declarations in `test_bootstrap.gml` are test inventory, not a claim that 126 tests passed in this pass.

## Runtime ownership

### Room flow

```text
obj_app_init (persistent)
  -> rm_title
  -> rm_opening
  -> rm_game (stages 1-5)
  -> rm_ending
  -> rm_credits
  -> rm_title
```

Practice enters `rm_game` from title and returns after completion or abort. `obj_app_init` and `obj_input_manager` persist; room controllers and UI are recreated with their room.

### Five global contracts

| Global | Owner | Purpose |
|---|---|---|
| `global.game_config` | `scr_setup` | Display, scale, fullscreen, FPS, volume, keyboard/gamepad bindings |
| `global.game_save` | `scr_setup` | Per-ship scores, starts, clears, continues |
| `global.game_runtime` | setup/gameplay | Current run, stage, resources, rank, overlays, practice/story requests |
| `global.game_input` | input manager/helpers | Device-neutral movement and action-edge snapshot |
| `global.game_audio` | audio helpers | Room music, Music Room preview ownership, SFX cycling |

`GameRuntimeDataCreateDefault()` is the canonical runtime shape. `GameRuntimeGameplayEnsure()` adds newer fields without overwriting live values. This default-factory plus compatibility-pass model is much stronger than ad hoc `variable_global_exists` initialization scattered through objects.

### Project-owned modules

| Module | Responsibility |
|---|---|
| `scr_setup` | Schemas, defaults, save/config migration, score persistence, display, boot |
| `scr_input_helpers` | Binding maps, labels, collision/swap, snapshots, active device, menu cursor |
| `scr_audio_helpers` | Room music, preview ownership, gain application, semantic SFX entry points |
| `scr_gameplay_helpers` | Constants, practice/pause, rank, stage flow, player, encounters, pickups, enemies |
| `scr_boss_patterns` | Boss descriptor interpretation and spawn primitives |
| `scr_story_helpers` | Story JSON, dialogue state/layout/rendering, ornate UI primitives |
| `scr_stage_3d` | VBUFF loading, camera routes, light/fog, atmosphere |
| `scr_title_helpers` | Title state, characters, practice UI, Music Room, title drawing |
| `scr_ui_crystal` | Clean-backdrop capture, GUI/surface mapping, crystal shader orchestration |
| `scr_test_helpers` | Test isolation and 26-frame visual QA tour |
| `test_bootstrap` | Project regression suite |

The repository also records that several modules have grown too broad and have a characterization-first decomposition plan. Reuse the ownership map and tests; do not reproduce the monoliths.

## Input and stable snapshots

`obj_input_manager` polls in Begin Step so each normal Step reads one stable frame snapshot. Keyboard and controller map into verbs:

| Verb | Keyboard | Controller | Role |
|---|---|---|---|
| movement | arrows | D-pad/left stick | Player and menus |
| fire | Z | face 1 | Volley, charge, confirm |
| bomb | X | face 2 | Bomb, cancel/back |
| autofire | C | face 3 | Continuous current-focus firing |
| focus | Shift | LB/L1 | Slow movement/focused pattern |
| pause | Escape/P | Start | Pause/title confirm |

The last active device owns prompt identity. Neutral gamepad state clears movement without changing that identity. Keyboard and gamepad have separate remap pages; duplicate assignments swap the displaced binding, preserving every action. Hot-plug remains active during remap listening.

Adaptation lesson: one input snapshot and named verbs create an input-determinism/test seam. Full gameplay replay additionally needs a project-owned/versioned seeded RNG, deterministic iteration and tie-breaking, controlled clocks, and content-version binding. Live source still uses ambient `random_range`, `irandom`, and `irandom_range` in gameplay and cosmetic creation, with no owned seed API. Imported Input 8.0.3 is unnecessary unless Blade requires its broader rebinding/accessibility/multiplayer surface.

## Run, stage, and pause state

Normal and practice use one runtime struct. `GameRunStartInitialize()` resets attempt-scoped values. Normal starts at stage 1, power 0, three lives, three bombs, meter 0, and rank 0. Practice applies a normalized request and does not record persistent run statistics.

`obj_scene_manager.scene_state.mode` is the stage machine:

| Mode | Owner behavior |
|---|---|
| `scroll` | Camera advances and the stage director runs |
| `boss_intro` | Clear ordinary combat; optional route dialogue |
| `boss_fight` | Boss controls completion |
| `boss_outro` | Post-defeat dialogue holds stage |
| `stage_clear` | Advance, finish practice, or enter ending |

Pause is a real freeze signal. Dialogue and Continue block pause because they own the same confirmation input. Resume is deferred to End Step so all gameplay objects observe a complete frozen frame. This explicit freeze protocol is a better foundation than deactivating every instance from a pauser object.

## Rank pressure

Rank is clamped `0..50`. It affects:

- wave spawn interval;
- enemy fire interval;
- enemy bullet speed.

It does not alter enemy health, player damage, or phase count. Rank rises every ten seconds of uninterrupted combat, after twelve ordinary defeats, at boss defeat, and when entering Berserk/Hyper. Bombing, death, and continuing lower it. Practice may lock it.

`GameRankPressureCreate()` is the single mapping from rank to cadence/speed multipliers. This is a clean separation between a legible rank value and its effects.

## Player weapons and hit ownership

Both ships produce normalized shot specifications consumed by `obj_player_shot`:

- Moon/Sunset: balanced wide shot and long sword sweep;
- Selkie/Sunrise: wider normal crescent and tighter focused lance;
- power `0..5` affects damage, scale, and color;
- tapping/holding fire produces volleys until a threshold begins sword wind-up;
- autofire avoids charging and respects independently held focus.

The sword uses a swept arc. Each sweep has a unique ID, and each target records the last sweep ID that hit it. This turns “one visual swing, one damage application per target” into a concrete invariant.

Player damage is ignored during invulnerability, death, bombs, dialogue, pause, and Continue. Continue explicitly restores resources, clears meter, lowers rank, increments continues, and respawns. Decline records an eligible normal-run result and returns to title after a delayed game-over state.

## Bullets, bombs, medals, and Berserk

`obj_bullet_parent` applies a stable order:

1. freeze guard;
2. active-bomb cancellation;
3. cancelled-bullet medal conversion;
4. movement;
5. camera-distance culling.

Special bullet children inherit the guard before spiral/redirect motion. Sword and bomb mark cancellation; each bullet performs its own conversion.

One Berserk meter replaces older parallel cancel/point-blank resources:

- slow trickle from sustained attacks;
- larger gain for hits inside Selkie's 108-pixel chakram reach;
- eight points per collected medal;
- small enemies drop one/two medals, large roles five/ten, boss phases five/ten;
- drops launch radially before homing.

At 1,000, Berserk automatically starts, clears bullets, and grants three frames of invulnerability. Attacks become larger, twice-as-fast route-specific sweeps; sword damage doubles again; the meter drains without a second ending cancel. Bombs cancel for 60 frames and grant 120 invulnerability frames.

The useful pattern is one visible economy with explicit gain sources and ordered cancellation, not the exact tuning values by themselves.

## Enemy roster and stage director

`GameStageDirectorStep()` is the sole live wave source. The old timeline/generator is removed. Each stage has four authored identities with a role—chaser, anchor, dancer, or lancer—and redistributed pattern ideas.

| Stage | Roster identity | Pattern vocabulary |
|---:|---|---|
| 1 | Forge Spark, Anvil Familiar, Bellows Imp, Hammer Cherub | fan/spiral, shockwave, hammerfall |
| 2 | Ribbon Hare, Winged Staff, Lavender Knot, Saltwind Pinwheel | gale, kelp wall, ribbon loop, spindrift |
| 3 | Spade Familiar, Dealer Mask, Order Talisman, Chaos Shard | cards/dice, spell circles, mirrored hexes |
| 4 | Clockwork Planet, Astrolabe Eye, Constellation Lance, Bloodstar Heart | pulse/hunt, astrolabe, constellation |
| 5 | Violet Bee, Twilight Mayfly, Thorn Reliquary, Chakram Seraph | thorn, petal, rose, chakram |

`obj_enemy_parent` owns freeze, damage, defeat, score, drop attempts, and default movement. `obj_enemy_variant` selects identity and then role movement/attack. A child calling `event_inherited()` must stop when the parent sets `combat_step_blocked`, preserving pause/destruction atomically.

The lesson for Blade is explicit encounter ownership and one live director, replacing orphan timeline moments and global enemy-count gates.

## Boss descriptors and dual encounter

Boss construction has two layers:

1. `GameBossEncounterInfoCreate()` selects identity and a phase plan.
2. `GameBossPhaseAttackStep()` interprets the active descriptor.

| Encounter | Plan shape |
|---|---|
| Shalmii | 3 phases |
| Aster | 5 phases |
| Mira | 3 personal phases |
| Aisha | 3 personal phases |
| Sisters finale | 1 shared synchronized phase after both personal plans |
| Caelia | 7 phases |
| Route-final Moon/Selkie opponent | 15 phases |

Descriptors carry unique ID, `shot_kind`, cadence, burst count, base angle, angle step, speed, turn/radial speed, spread, redirect interval, and theme. Unknown `shot_kind` fails closed and logs rather than firing a fallback.

Mira and Aisha demonstrate encounter-level coordination:

- separate objects, HP, plans, positions, and HUD bars;
- each defeated sister becomes harmless while the other remains;
- after both personal plans, both switch to one shared descriptor/life pool;
- damage synchronizes across both objects.

This is the strongest boss-director reference in the corpus. Keep descriptor completeness, fail-closed interpretation, and encounter orchestration separate from individual boss instances.

## Story and content data

Twenty-one story JSON files cover opening, stage boss intro/defeat per route, final encounter, and ending. Root may be a frame array or `{frames:[...]}`. Frames use name, text, ordered backgrounds, portraits, and left/center/right positions.

Missing backgrounds skip; missing portraits produce stable placeholder cards. This is useful development/optional-content diagnostics, but required packaged assets should fail pre-play validation rather than silently substitute. Text normalizes to two lines with ellipsis. Files use versioned names to avoid stale GameMaker sandbox copies shadowing updates.

This schema is narrower than the converged THPJ5 normalizer: it omits audio/voice/display modes/choices. Its strengths are stable route/seam naming, safe missing-asset behavior, explicit ordering, and decoupling story/portraits from boss mechanics. Blade should combine those strengths with the richer normalized schema.

## Persistence

`game.sav` and `config.sav` are independent-version JSON payloads. Loading:

1. reads text;
2. parses defensively;
3. rejects and backs up future versions;
4. migrates recognized fields into a fresh default struct;
5. rewrites only when normalization changes the payload.

Automated tests use `automation-` filenames, isolating player data. Config schema includes separate keyboard/gamepad bindings and percentage gains. New persisted fields require default, validator, migration, version, and tests.

This is the best persistence contract in the GameMaker corpus, though the current Blade repository should put only schema/default/migration definitions under `content/save/`. Mutable player config, save, checkpoint, and replay payloads belong in GameMaker per-user storage and are never repository/package source authority.

## Practice normalization

Practice requests include ship, stage `1..5`, segment (`full`, `waves`, `boss`), power `0..5`, rank `0..50`, dynamic-rank flag, lives `1..6`, bombs `0..6`, and meter `0..1000`. Every boundary passes through `GamePracticeConfigNormalize()`.

Practice start/restart/complete/title preserves configuration without recording starts, clears, scores, or continues. It never opens Continue. This is a strong example of separating persistent career statistics from ephemeral training state.

## Three-dimensional stage presentation

`obj_scene_manager` submits true-3D modular models and camera-facing texture billboards in Draw Begin, then restores 2D matrices and disables depth before actors render. Prebuilt VBUFFs replace runtime OBJ parsing. Collision/spawn coordinates remain 2D.

Each stage has two compatible looping routes: travel and downward boss. A separate presentation clock continues while 2D camera movement stops for dialogue or combat and blends between valid routes.

Five stages use authored modeled/texture vocabularies: forge citadel, moonrabbit forest, Vegas illusion stage, deep-space orrery, and infinite violet garden. The point to carry forward is data-driven route continuity and strict restoration of 2D draw state, not the exact scenes.

## UI and audio

The HUD uses side gutters, boss segments, stage notices, rank/resources, and phase-title banners. Ornate story-frame primitives are shared with boss attack titles. `scr_ui_crystal` owns clean-backdrop capture and crystal-pane shader mapping.

Audio routes by room, character stage, boss state, and finale route. One-shots use semantic helpers instead of raw sound IDs. Master/music/SFX gains are independently persisted. Cue sheets define arrangement, editable instrument parts, leitmotif treatment, and loop contracts.

The semantic audio layer and cue-sheet pipeline are stronger reuse candidates than any individual jam track.

## Asset authority

Selkies Moon has the clearest asset-source contract in the corpus:

- KRA is canonical for shipped raster art;
- Blend is canonical for 3D scenes;
- OBJ/MTL is retained interchange and VBUFF is runtime;
- Logic projects are canonical for score and SFX;
- runtime PNG/audio/VBUFF are derivatives;
- manifests own mapping and classification;
- Git LFS storage does not change authority.

Known historical caveats remain documented: some editable sources were recovered after runtime creation, pipeline reproducibility evolved over time, and large binary preservation required LFS policy. Treat current manifests/docs as authority over older archive copies.

## What Blade should adapt

1. Five explicit runtime/config/save/input/audio contracts rather than scattered globals.
2. One per-frame input snapshot with device-neutral verbs.
3. One live stage director and role-based enemy specifications.
4. Descriptor-driven bosses with fail-closed interpreters and unique signatures.
5. Encounter-level coordination for multi-boss phases.
6. Ordered bullet cancellation/conversion/movement/culling.
7. Unique attack/sweep IDs for one-hit-per-target invariants.
8. Rank as one bounded value converted centrally into pressure multipliers.
9. Version/default/validate/migrate/rewrite persistence.
10. Normalized practice data isolated from persistent statistics.
11. Offline VBUFF production and perspective/orthographic pass ownership.
12. Semantic audio commands and manifest-backed editable sources.

## What Blade should not copy wholesale

- the large helper modules before their planned decomposition;
- Selkies-specific story, characters, routes, or art;
- provisional portrait/runtime copies whose authority is documented elsewhere;
- its exact score/rank/meter balance without Blade-specific simulation;
- archived GMTL implementation as project-owned code;
- historical validation counts as current evidence.

Selkies Moon should function as a contract and characterization reference. When an older jam system conflicts with a mature Selkies invariant—stable per-frame input snapshots, fail-closed descriptors, explicit ownership, source manifests, schema migration—the mature invariant is normally the better starting point. Full-runtime determinism remains a documented gap rather than an established invariant.
