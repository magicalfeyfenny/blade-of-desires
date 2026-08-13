# GameMaker Assets, Prototypes, and Design Residue

## Purpose

This report covers material that is useful primarily as a focused experiment, asset family, migration fixture, provenance clue, or warning. Several projects are internally inconsistent and should never be bulk-imported. Their value is in one mechanic or design decision at a time.

## `code-refactor-scraps` / Neo Faraii Nights

Path: `TemplateProjects/gm-packs/prototype/code-refactor-scraps`

### Identity and active graph

The README identifies a side-scrolling mode-switching shmup made for Opera “Amaze Me,” June 17–21, 2021. The project is `neo-faraii-nights.yyp`.

Registered active resources include 24 objects, ten scripts, 33 sprites, 17 sounds, five fonts, three rooms, and one timeline. The implementation contains recognizable ancestors of later THPJ3 systems:

- UI controller;
- bomber and deathbomb visuals;
- boss/enemy/bullet parents;
- six bullet-shape children;
- dialogue object and queue loader;
- options and player shots;
- stage controller and title objects;
- `scr_pattern_fire` with the later 13-family pattern vocabulary;
- input/options/particle/score helpers.

`Script10` is empty.

### Resource-graph divergence

The `.yyp` registers 93 resources, or 103 paths including folders/options. Seventy-two loose `.yy` resources are not registered. `tl_stage1_logic.yy` has an empty `momentList`, but 106 loose moment files remain from frames 60 through 10001.

Those moments reference objects such as:

| Symbol | References |
|---|---:|
| `obj_enemy_popcorn` | 69 |
| `obj_enemy_fairy_shotgun` | 17 |
| `obj_enemy_fairy_wave` | 12 |
| `obj_enemy_fairy_burst` | 7 |
| `obj_enemy_fairy_large_ring` | 6 |
| `obj_boss_stage1_mid` | 4 |
| `obj_player` | 4 |
| `obj_enemy_fairy_lane` | 2 |
| `obj_congratulations` | 2 |
| `obj_boss_stage1_final` | 1 |

Many are unregistered or absent from the active object set. Spawns use a 1280x720 horizontal field with x values 1280/1350 and direction 180. Midboss references occur at 1619, 1859, 1969, and 2300; final boss at 3090; endings around 3100/4159; anomalous waves occur at 4160/4161 and popcorn at 10001.

This timeline cannot function as represented by the loose files. Use it to recover pacing history only.

### Systems and risks

- Input/options use DS-map JSON under `working_directory` without versioning or robust ownership.
- Particles create foreground/background systems and cherry rain without a complete lifetime contract.
- Dialogue uses parallel queues rather than frame structs.
- Pattern firing is a horizontal predecessor to the cleaned THPJ3 function.
- Scores append numeric lines; an old read path leaks a handle.
- Menu handling implements essentially its first choice; others end the game.

Best use: lineage for patterns, stage pacing, and mode-switching intent. Do not import its graph, persistence, or loose moments.

## Project Crowblade platformer prototype

Path: `TemplateProjects/gm-packs/prototype/test-platformer`

### Structure

- GameMaker IDE 2023.200-era project;
- rooms: init, disclaimer, title, 1280x1280 game room viewed at 640x360, and loader;
- 15 objects, 14 scripts, 18 sprites, two sounds, six fonts, five rooms, one timeline;
- about 3,416 GML lines;
- 22 loose YY resources outside the project graph.

Large events include title Step (~642 lines), player Step (~383), menu/title Draw (~335), dialogue (~268), pattern firing (~232), and initialization (~241).

### Useful design vocabulary

The title machine covers Continue, New Game, three slots, preview, erase, Music Room, temporary options, save/discard/default, Credits, and Exit. The broad state coverage is a useful UX checklist.

Player intent includes:

- land shadow/mage modes and a placeholder sky mode;
- acceleration, run, sneak, skid, dash;
- double jump, fast fall, hover, slide, wall cling;
- nine-frame input history;
- collision-line probes;
- camera easing and mouse look.

The save prototype uses three JSON-like DS-map slots and room-ordered savepoints. The dialogue V3 format supports three actors and 12 lines per frame.

### Definite incoherence

- `OPTIONS_MENU_CHOICE_RESOLUTION` is used while its macro definition is commented out.
- `obj_youmu` references undefined state and movement symbols such as `STATE_NEUTRAL`, `STATE_JUMP`, and `WALK_SPEED`.
- UI/score code references missing Cirno-era objects, fonts, sprites, and variables.
- pattern code references undefined boundary macros.
- cutscene moments at 50/60 are empty.
- position correction after player collision probes is commented out.
- save data has no schema/version/migration/atomic write and one slot uses lowercase `c`.

Best use: menu-state checklist, movement-state vocabulary, and debug-probe presentation. Rewrite each as a small explicit module.

## Magi Charm top-down prototype

Path: `TemplateProjects/gm-packs/prototype/test-topdown`

### Scale

- one 1600x900 room;
- 1280x720 view presented at 1600x900;
- four objects, five scripts, three sprites, one tileset;
- 68 instances: 65 walls, player/test actor, camera, and interactable;
- 65 additional compatibility graphics;
- two referenced note resources are missing.

### Movement and interaction

- Arrow-key eight-direction movement at speed 6.
- Y motion is multiplied by 0.75, producing an elliptical/isometric feel.
- Axis-separated collision resolution compares ellipse-weighted offsets.
- `X` probes a circle centered 64 pixels ahead with radius 48.
- Successful interaction runs a 30-frame timer and turns toward the target.
- Debug Draw shows a `96x72` body ellipse and a forward wedge roughly `192x144`.

The forward interaction volume and matching debug geometry are good mechanic prototypes.

Static defects:

- idle `point_direction(0,0,0,0)` overwrites facing, defaulting interaction right;
- held `X` retriggers instead of an edge action;
- the interactable has no meaningful interface beyond facing/timer;
- camera X eases by one tenth while Y snaps the entire remaining distance;
- `__view_*` scripts are imported compatibility wrappers;
- `__init_global` forces every layer depth to zero.

Adapt the interaction volume, not the compatibility scaffold.

## Faraii Leaf focused shmup prototype

Path: `TemplateProjects/gm-packs/prototype/test-shmup`

The project file `faraii-leaf.yyp` is at the root. It has one 640x360 room shown through a 1280x720 viewport, 20 objects, nine sprites, no script resources, and 41 object-event files totaling about 444 GML lines.

### Tap/hold weapon transformation

The player samples shoot input into a rolling nine-frame array:

- a tap or unstable pattern fires a wide nine-shot fan every three frames plus an unusual alternating-delay forward rack;
- nine identical held frames enter focus/laser mode;
- held mode slows movement to 40%, draws max-blend navy afterimages, and grows a vertical line laser upward by 20 pixels/frame toward -500.

The laser performs rectangle collision with all flying enemies each frame for five damage and retracts its tip to the hit y. A line collision at the tip reveals/destroys hidden ground bees. This input-to-weapon-mode transition is one of the most original small mechanics in the corpus.

### World anchoring and effects

Ground objects store local dx/dy and add `obj_enviro.x/y`; the environment drifts `0.25,0.1` each frame. This cheaply separates a grounded layer from flying actors.

Six environment color schemes can crossfade over 200 frames, though no in-scope stage trigger changes them. A bullet-glow controller caches enemy-bullet IDs and draws rotating additive auras in one pass; stale IDs remain but are guarded with `instance_exists`.

### Incomplete parts

- generator creates an aimed enemy every frame without cap;
- rank is initialized but never changed;
- flying/ground/collectible/boss bases are largely placeholders;
- there is no danger/lives/progression loop;
- hidden bees flash 50 ticks and drop a ground collectible, but the larger economy is absent.

Adapt the sampled mode transition, laser hit contract, ground anchor, and batched glow. Add bounded spawning, ownership, cleanup, deterministic rank, and tests.

## Catalog and empty project

### `fenny-moe`

This is a static 69-line HTML catalog plus 26-line CSS, not a game. It records provenance for:

- Signals in the Wind;
- Koishi Couples Therapy;
- Cirno Yukkuri Wrangling;
- Sunflowers in Rain;
- Youmu Shoots Strange Bird;
- Wriggle Unwriggleable Night;
- Eirin Hourai Elixir Hunt;
- Split + Balance;
- Ghost Who Wants Alone;
- Meaning of Life and Death.

The Wriggle entry helps connect Neo Faraii/code scraps to later THPJ3 naming. Use the site as discovery metadata only.

### `test-sheet`

This is a GameMaker IDE 2026 project with one empty black 1366x768 room and no objects, scripts, sprites, sounds, or content. It is only a recent schema/default-project sample.

## Asset families

### Shmup/UI pack

The THPJ3 family contains:

- six bullet silhouettes: ball, bead, blade, card, diamond, pellet;
- player/options/main and option shots;
- bomb/deathbomb and hitbox presentation;
- five fairy/enemy bodies;
- life, bomb, hyper, boss bar, boss phase, and backdrop UI;
- layered forest/ground/sky/star/moon backgrounds;
- six-expression portrait sets for four Touhou characters;
- 18 sounds covering boss/enemy/player/graze/typewriter/music roles;
- six fonts.

This is an excellent mechanic readability and audio-cue taxonomy. The themed art and music require rights/de-theming review.

### Dialogue/UI pack

THPJ5 provides text box/arrow/auto/skip sprites, menu arrows and selector, five backgrounds/title, seven talk portraits, eight fonts, typewriter sound, and placeholder music. Its strongest asset contribution is information architecture and portrait staging.

### Action/top-down pack

Sunflowers includes top-down player directions, four weapon/effect families, enemies and bosses, projectiles, powerups/hearts, ornate HUD/dialogue pieces, map layers, paths, and large sunflower fields. THSJ contributes scalable cursor variants, readable/decorative fonts, controller/menu/text pieces, and crowd/action sprites.

### Neuro platformer pack

Neuro has complete-looking movement sprites, drone, button/door/lever/crates/spikes/savepoint/talkable/trigger utilities, title/command UI, parallax strips, 32 sounds, four fonts, three tilesets, and a highlight shader. Several names are obvious test placeholders. Use visual roles, not names or themed content.

### 3D pack

Blade support contains billboard/cylindrical/fog shaders, skybox/floor textures, simple model fixtures, and diagnostic menu/controller sprites. The render concepts are stronger than the placeholder assets.

## Runtime/source authority

Many GameMaker projects contain runtime PNG/WAV/OGG but no editable `.kra`, `.svg`, `.logicx`, `.mid`, or `.blend` beside them. Some editable sources exist in the separate creation archive or Selkies Moon, but matching must be proven per asset.

Before adoption:

1. establish creator and permission/license;
2. establish original-IP compatibility;
3. locate or recreate an editable source in the current required format;
4. export the current runtime format;
5. record it in `assets/exports.json`;
6. add reproducibility and format checks.

Do not infer permission from a file being present in a jam project or public repository.

## Generated cache and output fingerprints

Top-level GameMaker cache is approximately 174 MB/2,581 files; output is approximately 142 MB/126 files. Matching family names include action, Blade, Blade 3D, dialogue, Sunflowers/top-down, THPJ3, THPJ5, and vertical-shmup.

Additional generated trees include:

- archived Blade cache about 17 MB/497 files;
- archived Blade output about 13 MB/19 files;
- TemplateProjects cache about 79 MB/1,107 files;
- TemplateProjects output about 65 MB/49 files.

Formats include compiled game data, XML, QOI, compressed texture data, WAV, JSON, masks, debug metadata, iOS bundles, and installer scripts. They establish that projects were processed at some historical point; they are not source authority, current build proof, or assets to import.

The Selkies LFS audit/migration trees and bundle were identified but not traversed as gameplay source.

## Avoid list

- Any unregistered resource graph from `code-refactor-scraps`.
- Crowblade's foreign Cirno/Youmu fragments and monolithic event code.
- Magi Charm's global layer-depth rewrite and legacy view wrappers.
- Faraii's one-enemy-per-frame generator.
- Runtime cache/output as editable authority.
- Touhou/Neuro identities and third-party reference images without clearance.
- Duplicate legacy TXT and JSON as coequal content sources.
- Placeholder or garbage-named resources merely because they compile into a project graph.
