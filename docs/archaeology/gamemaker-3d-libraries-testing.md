# GameMaker 3D, Rendering, Libraries, and Testing Family

## Recommended source hierarchy

1. Use `gm-templates/blade-of-desires-3d-template` as the clearest archived baseline for model loaders, projections, billboards, the STG state object, and characterization tests.
2. Use the assembled top-level `blade-of-desires` slice as a one-shot feasibility and defect specimen for composing a perspective scenery pass, narrow 2D playfield, stage content, and UI. It does not independently validate the GDD or set current Blade tuning.
3. Use `fenny-gml-library` as a catalog of cleaned functions, not as a production dependency without new tests and policy alignment.
4. Treat the raw support pack as lineage because it has dual project authority and no tests.
5. Treat the archived GMTL checkout as third-party history. Current `origin/dev@6b938aa` imports GMTL v1.2 inside a demo GameMaker project and protects an exact 20-root/47-file set with a fail-closed read-only lock. The import still needs a verified retained upstream notice and project-owned guards for the matcher defects described below.

## Assembled archived Blade slice

Path: `/Users/magicalfeyfenny/GameMakerProjects/blade-of-desires`

### Shape and composition

- Logical size: `640x360`.
- Centered play lane: `270x360`, x `185..455`.
- 42 objects, 26 scripts, 3 shaders, 116 sprite directories, 18 sounds, 6 fonts, 4 rooms, and 1 timeline on disk.
- Loose duplicates make on-disk counts larger than the selected resource graph in places.

Room flow is `rm_disclaimer -> rm_title -> rm_cutscene -> rm_stage1`. The disclaimer has a definite missing room-creation GML reference. The title places a moon and 148 stars; the moon creates the logo at frame 120. The stage places its controller, player/UI, camera, skybox, 3D floor, and supporting scenery.

The slice combines THPJ3 player/options/bullets/boss vocabulary, a retargeted vertical lane, three ships, four difficulties, a 12-event schedule, perspective 3D scenery, orthographic 2D gameplay/UI, billboards, fog, JSON dialogue, a static STG API, and GMTL v1.1.1c tests.

### Observed one-shot tuning

Core values include logical `640x360`, lane bounds `185..455`, three starting lives/bombs, five maximum lives/bombs, hyper cost 100/max 300, a 40-frame deathbomb window, 60-frame respawn, and 120-frame invulnerability.

| Difficulty | Bullet speed | Enemy HP | Boss HP | Rank gain | Rank cap | Score multiplier |
|---|---:|---:|---:|---:|---:|---:|
| Breeze | 0.9 | 0.9 | 0.88 | 0.5 | 2 | 1 |
| Arcade | 1 | 1 | 1 | 0.85 | 3 | 1.15 |
| Storm | 1.15 | 1.12 | 1.18 | 1.2 | 4 | 1.35 |
| Extra | 1.25 | 1.25 | 1.3 | 1.35 | 4.5 | 1.5 |

| Ship | Focus/unfocus speed | Main / option damage | Forward offset | Focus/unfocus side | Focus/unfocus arc | Option turn | Hyper drain |
|---|---|---|---:|---|---|---:|---:|
| Maynii | 2 / 5 | 5 / 1.2 | 96 | 14 / 70 | 9 / 20 | 3 | 1 |
| Ciela | 2.3 / 5.2 | 4.5 / 1 | 110 | 18 / 54 | 5 / 12 | 9 | 0.95 |
| Kolar | 1.8 / 4.7 | 6 / 1.8 | 118 | 12 / 34 | 0 / 6 | 1 | 1.15 |

These values characterize what the generated slice attempted; they are not canonical-content seeds or current ship/difficulty decisions. The GDD, explicit product decisions, and new playtesting own current tuning. The approximately 779-line `scr_initialize.gml`, which mixes constants, profiles, settings, schedule data, and bootstrap, is likewise a defect specimen rather than an architecture to retain.

### Stage and coordinate adaptation

The stage controller creates the 3D camera, skybox, floor, and eight left/right wall pairs. `bod_stage_x()` maps old THPJ3 coordinates `48..1232` into `185..455`.

| Frame | Event |
|---:|---|
| 60 | Triple popcorn |
| 180 | Lane pair |
| 330 | Wave plus shotgun |
| 480 | Four popcorn |
| 660 | Burst |
| 840 | Large ring |
| 1020 | Midboss |
| 1320 | Wave plus burst |
| 1530 | Shotgun pair |
| 1740 | Four lanes |
| 1980 | Two large rings |
| 2280 | Final boss |

Stage time stops during dialogue, a boss, or clear presentation. The final transition awards a clear bonus, waits 240 frames, and returns to title.

### Definite and likely defects

- `rm_disclaimer.yy` references an absent creation file.
- Boss display names `Petal & Briar` and `Asahi` do not match packaged `Nue` and `Byakuren` dialogue filenames, so dynamically derived boss dialogue is skipped.
- Seed metadata exists, but pattern randomness uses ambient RNG; it is not deterministic replay.
- Vertex buffers and formats are not comprehensively destroyed.
- Some paths reject `undefined` but not invalid `-1` handles.
- Repeated wall instances can own redundant buffers.
- `object_exists(camera)` checks a resource, not a usable camera instance.
- Two stored logs are stale: the 2026-04-08 Igor log records 7 pass, 1 fail, 15 skipped, then an internal GMTL error; the later 2026-04-10 test-results log records 50/50 passing. Neither was reproduced during this audit.

## Model loader and render pipeline

### Vertex and parser surface

The format contains position, normal, UV, color, and alpha. Archived public functions include `init_vertex_format`, `vertex_add_point`, `load_d3d`, `load_obj`, VBUFF save/load helpers, `world_to_screen`, and `screen_to_world`. The curated library renames these to `gm_vertex_format_init`, `gm_model_load_d3d`, `gm_model_load_obj`, `gm_model_cache_*`, `gm_world_to_screen`, and `gm_screen_to_world`.

The D3D loader reads old `100`-format streams, handles records 2 through 9, and ignores 0, 1, and 10 through 15. It is a recovery path for legacy fixtures, not a preferred current source format.

The OBJ loader reads positions, normals, UVs, faces, MTL references, and material selection. MTL support includes diffuse color `Kd` and alpha `d`. It emits the first three vertices of a face.

Static limits:

- polygon faces are not generally triangulated;
- negative indices and broader MTL syntax are not robustly supported;
- parser diagnostics are limited;
- parsing and GameMaker buffer construction are coupled;
- cache validity is existence-based rather than source/version/hash-based.

The current policy calls for `.blend` plus retained `.obj`/`.mtl` export sources to `.vbuff` runtime. The normal production path should therefore be an offline deterministic converter that rejects unsupported input, records source hashes and converter version, and updates `assets/exports.json`.

### Ownership and projection

The standalone template deletes temporary model data after buffer conversion, a real improvement over the support pack. It still does not fully define one owner for each buffer/format, shared-cache lifetime, invalid-ID rejection, cleanup on every exit, or source-change invalidation.

`world_to_screen` and `screen_to_world` are useful for 2D markers, selection rays, lane/world alignment, and debugging. They need tests at view edges, behind-camera points, near/far planes, multiple aspect ratios, and transformed worlds.

### Two-pass rendering

The strongest presentation idea is explicit separation:

1. Configure perspective view/projection and draw scrolling 3D scenery.
2. Restore orthographic `640x360` view/projection.
3. Draw player, bullets, enemies, portraits, and UI in logical 2D coordinates.

Collision stays 2D. The world gains depth without forcing projectile gameplay into 3D physics.

The floor creates a 128-wide grid extending to roughly y 6400. The stage places wall pairs and forest, river, desert, city, ash, and blaze texture studies. Skybox and wall geometry should become shared immutable models with per-instance transforms/material parameters.

## Shaders

### Billboards

`shd_billboard` removes view/world rotation so a card faces the camera in all axes. `shd_billboard_cylindrical` preserves upright orientation and rotates horizontally. Both fragment shaders discard alpha below `0.1`.

The first suits particles and fully facing cards; the second suits characters, trees, columns, and props that should remain upright.

### Fog

Static inspection suggests `shd_fog` treats transformed/clip-space position as world position and measures from the origin rather than camera position. Rewrite it around explicit world-space position and camera position, then test near, transition, far, translated-camera, and rotated-camera cases.

### Draw-state discipline

Billboard and fog helpers reset some state but do not provide a complete push/pop contract. Each render pass should own all consumed state, or each primitive should document and restore exactly what it changes.

## Support pack and standalone template

The raw `gm-packs/support/blade-of-desires` contains six objects, four scripts, three shaders, ten sprites, one font, and six rooms. Core resources are `obj_2Dobj`, `obj_3Dobj`, `obj_camera_3D`, `obj_init`, `obj_skybox`, `obj_test_3Dfloor`, `lib_3D`, `lib_STG`, `lib_shaders`, and `scr_init`.

`rm_init` enters `rm_game`; opening/menu/ending/credits are shells. The directory contains both `GAME.yyp` and `blade-of-desires.yyp`, creating authority ambiguity, and has no tests.

The standalone `gm-templates/blade-of-desires-3d-template` preserves that surface and adds normalized metadata, GMTL, project test support, `test_blade_3d`, `test_blade_stg_init`, and `test_coverage_meta`.

Observed source-diff repairs:

- delete temporary `model_data` after conversion;
- change the `Miss` guard from `&& is_respawning` to `&& !is_respawning`;
- normalize packaging and project authority.

Its 2026-04-10 log reports 17/17 tests: eight 3D/shader, eight STG, and one coverage test. That is useful historical evidence, not a fresh run.

## Static STG state API

The original surface includes scene enter/exit, pause, pause/interstitial menus, respawn, bomb/autobomb/hyper, life/bomb extends, graze, miss, and continue. The original `ShowInterstital` name contains a spelling error.

The curated `gm_stg_state` constructor holds mode, ship, stage/section, lives, bombs, hyper, score, continues, rank, point value, pause/scene/respawn/bomb/hyper/invulnerability flags, and logical playfield geometry. It provides explicit state-changing methods and overflow scoring.

Static concerns:

- extend-threshold macros are not connected to score progression;
- `use_hyper` rejects exactly 100 because it checks `<= 100`;
- hyper sets `is_bombing` without a full update/expiry lifecycle;
- pause, respawn, invulnerability, and scene flags lack ownership/timers;
- repeat graze still grants reduced hyper rather than strict graze-once;
- string states/menu IDs are not validated;
- no deterministic reason/event log exists.

Use this as vocabulary for a tested run-state service with commands, events, timers, pause tokens, and score reason codes.

## Fenny GML library

Path: `TemplateProjects/fenny-gml-library`

Six curated files total about 1,096 lines:

| Module | Main surface | Lineage |
|---|---|---|
| `gm_math.gml` | `gm_approach` | Neuro approach helper |
| `gm_camera.gml` | `gm_camera_shake` constructor | Neuro shake decoupled from `obj_camera` |
| `gm_draw.gml` | outlined text, transformed text, pie, billboards, fog update | Neuro, THPJ5, Blade |
| `gm_data.gml` | JSON text/buffer/default helpers and score files | Neuro, Escape, THPJ5, THSJ |
| `gm_3d.gml` | vertex formats, D3D/OBJ/MTL, VBUFF cache, projections | Blade `lib_3D` |
| `gm_stg.gml` | shmup run-state constructor | Blade `lib_STG` |

Strengths:

- Small named functions are easier to assess than whole projects.
- `gm_camera_shake` removes one camera singleton assumption.
- `gm_draw_pie` uses named arguments and closes the exact final arc.
- JSON helpers close files and delete their buffers.
- `gm_3d` namespaces its vertex format instead of relying on `global.vertex_format`.
- `SOURCES.md` records origin and explicitly rejected systems.

Limits:

- shake uses ambient `random_range`, so it is not replay deterministic;
- JSON writes are not atomic and parse errors are not structured;
- defaults are copied but not schema-merged or migrated;
- score logs append indefinitely without version/integrity metadata;
- 3D parser/cache limits remain;
- draw helpers rely on ambient render state;
- STG state is not a complete coordinator;
- no test project is attached directly to these six files.

No `LICENSE`, `COPYING`, or `NOTICE` was found in this library root. `SOURCES.md` records source paths and transformations; it does not establish authorship or reuse permission. The library is an extraction shortlist, not a drop-in dependency: reuse remains conditional on confirmed Fenny ownership/authorization or a clean-room implementation of the characterized behavior.

## Template generation workspace

`TemplateProjects` separates preserved `gm-packs`, normalized `gm-templates`, the curated library, a GMTL vendor checkout, common/per-template tests, build tools, and historical test results.

### `build_gm_templates.py`

This script is over 1,600 lines and handles:

- permissive GameMaker JSON and trailing commas;
- legacy type and metadata upgrades;
- font, sound, object, sprite, timeline, and room modernization;
- script resource generation;
- path/project reference rewriting;
- patch overlays and inline fixes;
- GMTL integration and patching;
- archive-clutter removal;
- folder, placeholder, options, README, index, and validation generation;
- preservation/restoration of each template's `.git` metadata.

It contains important migration knowledge but violates the destination's one-responsibility/800-line source policy as a unit. If adapted, split parsing, schema migration, graph validation, patch application, packaging, and report generation.

The generated `validation.tsv` records zero missing resources, folders, internal YY references, and internal YYP references for its five-template generated snapshot. It has no exact source-revision binding and proves neither current graph consistency nor gameplay/build behavior.

### `run_template_tests.zsh`

The runner knows five templates, can rebuild, invokes macOS Igor with a pinned runtime path, creates test-enable markers, parses GMTL totals/duration, fails on compilation/run errors/failures/zero tests/skips, and writes logs plus `latest.tsv`.

Operational concern: it finds processes with `pgrep -f 'Mac_Runner|YoYo Runner'`, then uses normal and forced kill in cleanup and a 30-second watchdog. That can match unrelated runner processes. It also writes caches, outputs, markers, logs, and summaries. It was deliberately not run.

The present `latest.tsv` contains only one escaped-tab dialogue row, so it is not a current five-template health report. Individual April 2026 logs remain lineage evidence.

## GM Testing Library archive

Path: `TemplateProjects/vendor/GM-Testing-Library/GM-Testing-Library`

Observed identity:

- GMTL v1.1.1c, released 2025-09-23;
- author DAndrëwBox;
- MIT license;
- GameMaker 2023.4+/2024 target;
- 13 scripts, two demo objects, one sprite, one font, and one room;
- seven historical packages from beta1 through v1.1.1c.

Organization API includes `suite`, `describe`, `section`, `it`, `test`, `skip`, `each`, and before/after all/each hooks. Simulation covers keyboard, mouse, gamepad, frame waits, object events, time sources, and `call_later`. Matchers cover identity/equality, return values, length/property, ordering, truthiness, containment, and negation.

The library wraps keyboard, mouse, gamepad, time-source, and delayed-callback functions while retaining `original_*` aliases.

Known static defects and limits:

- `toHaveReturnedWith` can pass on callability without executing/comparing in its nominal success branch;
- truthiness defaults make some non-positive values satisfy contradictory expectations;
- property checks can confuse present false/zero values with absence;
- README suite syntax differs from the one-argument implementation;
- documentation and demo disagree about nested `describe`;
- mouse simulation has GUI-scale caveats;
- asynchronous testing is absent;
- coverage is commented/TODO;
- the demo intentionally includes failures and skips and is not a green framework self-test.

### Dependency boundary for current Blade

At audit start, the stale local checkout was at `afa43e253d75ea098ed70c63db42090443d86b46`, one commit behind the then-current `origin/dev@2b8532badb3443c3eb8433440f8dc576a28ff3bc`. That remote-tracking commit added 61 files and 5,822 lines under `project/~ blade of desires ~/`: a GameMaker 2026.0.0.16 project containing GMTL v1.2, its demo font/sprite/objects, two rooms, and test/demo scripts.

This publication branch instead begins at current `origin/dev@6b938aa8c4ad9972b8195d58657cca71ba497918`, which also contains the merged GMTL integrity boundary: `gmtl.lock.json`, a fail-closed validator, and the exact 20-root/47-file read-only lock. The older commit IDs remain audit-snapshot evidence, not a description of the publication base.

Current `GMTL_init.gml` identifies v1.2, released 2026-05-04. Compared with the archived v1.1.1c surface, it adds simulated async events through `simulateAsyncEvent`/`async_load_map`, spies, `toThrow`, `toHaveBeenCalled*`, nested/lifecycle demonstrations, and function-coverage machinery. The third demo object exercises async behavior and coverage is enabled by default.

Static inspection also finds that the imported demo deliberately includes failures/skips and sets `gmtl_run_at_start=true`; it is not a green self-test. Serious matcher defects persist: `toHaveReturnedWith` can mark any callable successful without executing/comparing it; instance `toHaveProperty(key)` treats false/zero values as absent; and default truthiness uses an overbroad undefined/value expression. Until repaired or narrowly guarded by project-owned tests, these defects can create false-green results.

The current v1.2 subtree contains no retained MIT `LICENSE` or `NOTICE`, although the archived v1.1.1c vendor checkout carries MIT licensing evidence. The merged lock proves import identity, not matcher correctness or license retention. Remaining dependency remediation must restore/verify the upstream notice and guard the known false-green matchers with Blade-owned tests outside the vendor set. The archive's v1.1.1c source is compatibility evidence only; it must not replace the v1.2 import by accident.

## Recommended current rendering architecture

- `RenderWorldPass`: owns perspective camera/projection and every 3D scenery state change.
- `RenderGameplayPass`: owns orthographic logical coordinates and gameplay sprites.
- `RenderGuiPass`: owns UI, dialogue, pause, and accessibility overlays.
- `ModelRegistry`: stable IDs to immutable VBUFF assets with one lifetime owner.
- `BillboardRenderer`: explicit spherical/cylindrical mode, material, transform, and state contract.
- `ProjectionService`: tested world/screen conversions.

Asset flow:

```text
.blend
  -> deterministic .obj + .mtl exports
  -> validated offline conversion
  -> versioned .vbuff
  -> assets/exports.json mapping
```

The converter should reject unsupported geometry rather than truncate it, and record source hashes, converter version, vertex format, counts, bounds, and output hash.

## Characterization tests to carry forward

1. Buffer creation, sharing, invalid IDs, and cleanup on every exit path.
2. OBJ triangles/quads/ngons, negative indices, missing normals/UVs, materials, and malformed input.
3. Cache invalidation after source or converter changes.
4. World/screen round trips and off-camera/behind-camera cases.
5. Perspective-to-orthographic draw-state restoration.
6. Spherical and cylindrical billboard orientation under camera translation/rotation.
7. Fog under translated and rotated cameras.
8. Stage schedule determinism and coordinate remapping.
9. Run-state commands, events, score reasons, pause ownership, and exact threshold behavior.
10. Imported dependency lock integrity without changing imported files.
