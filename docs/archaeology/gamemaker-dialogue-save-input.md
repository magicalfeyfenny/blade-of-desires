# GameMaker Dialogue, Cutscene, Menu, Save, and Input Family

## Recommended source hierarchy

For dialogue, use the normalized JSON runtime shared by the cleaned THPJ3, THPJ5, and Sunflowers packs as the behavior seed, and use the standalone dialogue template as the best host reference because it also repairs file loading and menu drawing.

For saving, no archive implementation is production-ready. The dialogue template has the best default-preserving file loader; Neuro has the strongest checkpoint-registry intent; the current system should combine those ideas behind a versioned, validated, atomic project-owned save service.

For input, choose deliberately between a small project-owned action abstraction and a vetted, version-locked upstream Input library. Do not copy Input piecemeal, and do not adopt either incomplete host wrapper found around it.

## The converged JSON dialogue runtime

### Lineage and scale

The strongest sign of deliberate cross-project convergence is a byte-identical dialogue subsystem in:

- `TemplateProjects/gm-packs/shmup/thpj3`;
- `TemplateProjects/gm-packs/dialogue/thpj5`;
- `TemplateProjects/gm-packs/topdown/sunflowers-in-the-rain`;
- their normalized template derivatives.

The shared implementation consists of:

- `scripts/scr_dialogue_start/scr_dialogue_start.gml`, 691 lines;
- `objects/obj_dialogue/Create_0.gml`;
- `objects/obj_dialogue/Step_0.gml`;
- `objects/obj_dialogue/Draw_0.gml`;
- `objects/obj_dialogue/Destroy_0.gml`.

The object events contribute another 278 lines. Dialogue and Sunflowers also share the bordered-text helper.

### Accepted JSON envelopes

The loader accepts a filename with or without `.json` and normalizes several root shapes:

```json
[
  { "name": "Speaker", "text": "Hello" }
]
```

```json
{ "frames": [ ... ] }
```

```json
{ "scene": { "frames": [ ... ] } }
```

```json
{ "scene": [ { "frames": [ ... ] } ] }
```

In the final form, a normalized frame carries:

```json
{
  "name": "Speaker",
  "text": "Dialogue text",
  "display": "adv",
  "speaker_slot": "left",
  "actors": [
    {
      "name": "Actor",
      "emote": 0,
      "slot": "left",
      "x": null,
      "y": null,
      "sprite": null,
      "flip": false,
      "scale": 1,
      "alpha": 1
    }
  ],
  "bg": null,
  "music": null,
  "audio": null,
  "voice": null,
  "auto_duration": null
}
```

The source normalizes aliases including:

- `name` and `speaker_name`;
- `text` and `texttarget`;
- `display` and `display_mode`;
- `speaker_slot` and `active`;
- background, music, audio, and voice variants.

Actors may be objects or raw sprite references. Name/emote combinations can resolve sprites by naming convention. `noname` becomes blank and `___` becomes `???`.

### Presentation modes

| Mode | Source value | Presentation |
|---|---:|---|
| ADV | `0` | Bottom dialogue box with typewriter text and portraits |
| Narrate/fullscreen | `1` | A line fades over a darkened full view |
| NVL | `2` | Large bordered text panel |
| None/silent | `-1` | No text presentation; automatic progression only |

Left, center, and right actor slots are positioned relative to the active view. The renderer reads the active camera's x, y, width, and height; it crossfades background sprites, dims inactive speakers, and draws actors view-relatively. That makes it materially better than the fixed-room original implementations, although its panel offsets and type sizes remain hard-coded.

### Frame application and control flow

Applying a frame can:

- change or loop music;
- play one-shot audio;
- start or stop voice;
- crossfade a background;
- place and dim portraits;
- push a name/text pair into the dialogue log;
- reset the typewriter cursor;
- start automatic advancement.

ADV mode reveals one character every other frame and can play `snd_typewriter` per character. `Z`, Enter, or Space advances; Control skips the current typewriter reveal; `C` toggles auto mode.

The runtime owns and destroys its DS queue and stops voice in Destroy. It can resume from `global.loaded_file["save_linenum"]` and increments that field after an advance.

### Strengths

- Flexible normalization isolates old content variations from rendering.
- Frame and actor structs are much safer than parallel name/emote/text queues.
- View-relative layout survives cameras better than the jam originals.
- ADV, narration, NVL, and silent beats cover several story-presentation needs.
- Per-frame audio, voice, music, background, and portrait data are already content-driven.
- Dialogue log and save-line integration demonstrate useful host hooks.

### Coupling and omissions

The implementation still assumes:

- raw keyboard keys rather than host input actions;
- direct globals and singleton objects;
- dynamic asset lookup by resource name;
- a particular save-map shape;
- a particular log-array shape;
- specific fonts, sounds, layers, and display metrics.

It has no first-class:

- choice or branch nodes;
- conditions and effects;
- variable interpolation;
- stable content IDs;
- localization keys;
- schema version or migration;
- speaker/portrait manifest;
- validation report with source location;
- deterministic automated progression contract.

### Adaptation contract

Retain the normalized concepts, not the singleton implementation. A current Blade dialogue service should have:

1. A versioned schema under `content/dialogue/`.
2. Stable scene and frame IDs, with save data storing IDs rather than array positions alone.
3. Explicit actor, portrait, audio, music, and background registries.
4. Injected ports for input, audio, save, logging, and asset resolution.
5. Named presentation modes with layout data separated from content.
6. Choices, conditions, variables, and effects represented as validated node types.
7. Localization keys plus optional authoring text.
8. A validator that reports file, scene, frame, field, and reason.
9. Characterization tests for every accepted legacy envelope before any compatibility layer is removed.

## THPJ5 visual-novel host

Source authority:

- populated archived pack: `/Users/magicalfeyfenny/GameMakerProjects/TemplateProjects/gm-packs/dialogue/thpj5`;
- cleaned host: `/Users/magicalfeyfenny/GameMakerProjects/TemplateProjects/gm-templates/dialogue-template`;
- top-level `/Users/magicalfeyfenny/GameMakerProjects/thpj5` is empty;
- the neighboring `thpj5_postjam.AppImage` was identified as an x86-64 ELF by metadata and was never executed.

### Room and chapter flow

```text
rm_initialize
  -> rm_logo
  -> rm_title
  -> rm_loader
  -> rm_scene
  -> rm_ending
```

The ten objects are initializer, logo, title, save loader, scene, dialogue, camera, camera anchor, pauser, and ending.

On room start, the scene chooses a chapter timeline. Each chapter timeline:

1. starts JSON dialogue at moment 2;
2. increments the chapter at moment 20;
3. resets the line number;
4. autosaves;
5. reloads `rm_scene`.

`SCENE_TOTAL` is 5. `tl_scene_c6` and `scene_test.json` therefore appear unreachable or unfinished.

### Content corpus

| File | Frames |
|---|---:|
| `scene_c1` | 17 |
| `scene_c2` | 38 |
| `scene_c3` | 41 |
| `scene_c4` | 68 |
| `scene_c5` | 36 |
| test scene | 1 |
| **Total** | **201** |

The content uses 103 ADV, 92 narrate, and 6 silent frames. It references Koishi, Sanae, Rin, Utsuho, Suwako, Kanako, and Satori, with one `Utusho` typo. Backgrounds include Chireiden, Misty Lake, Moriya, and therapy-room art. These are useful schema and staging examples; their Touhou identity and artwork are not an original-IP asset source.

### Title/menu machine

`obj_title` contains a roughly 567-line mode machine covering:

- press-any-key;
- main menu;
- start;
- options;
- exit;
- three file slots;
- clear-file confirmation;
- temporary option values;
- save or discard option changes;
- dormant gallery and music-room constants.

The packed `scripts/scr_menu_draw/scr_menu_draw.gml` is empty. The dialogue template supplies a 196-line renderer using nested closures for main, file, clear, options, music, gallery, and loading modes. This is a definite reason to prefer the template as the host reference.

The UX coverage is good, but the implementation should become a collection of explicit menu-state descriptors and small controllers rather than another large event.

### Files, options, and slots

The pack persists keyboard bindings to `keyboard.json` and fullscreen/window multiplier to `options.json`. Save files are DS-map JSON with chapter and line, using three named slots plus autosave. The loader waits 20 frames, loads the chosen/default map, and enters the scene. Preview reads each slot and renders `chapter N` and `line N`.

The template repairs `scr_files_load` to:

- preserve/copy defaults;
- detect missing files;
- handle decode failure;
- clear and replace maps more carefully.

It still lacks schema/type/version validation, atomic writes, and migration. Decoded DS-map ownership also remains a concern in neighboring persistence code.

### Pause and log presentation

`obj_pauser` toggles with `P`, deactivates every instance except itself, captures the application surface, shows the dialogue log, saves with `S`, and returns to title with Escape.

Static concerns include:

- a surface path that uses view width for both dimensions;
- mixed camera/view/port units;
- repeated surface/log-buffer churn;
- raw-key controls outside the project's input map.

The concept—pause the scene, preserve its image, and expose the backlog—is worthwhile. It needs one pause-ownership protocol and centralized surface lifetime.

### Camera and ending

The camera follows the nearest anchor with 20% smoothing and optional mouse look. The ending shows thanks and returns to title after 360 frames.

### Template tests

The template adds file default/round-trip/missing tests, three preview-slot tests, held/pressed input tests, options load, JSON dialogue load, bordered-text smoke, and menu renderer smoke. These are script-level characterization seeds. They do not cover the complete chapter sequence, pause surfaces, corrupt saves, migrations, or all 201 content frames.

### Local `tyvnj2` source-authority qualification

The local repository at `/Users/magicalfeyfenny/GitHub/tyvnj2` preserves three distinct authorities that should not be collapsed:

- commit `7996066` is the initial full game and is the best local authority for the original content graph;
- commit `fc3e14c` deliberately removed content assets to isolate the visual-novel engine;
- current `master` at `dbaa721` converted metadata on top of that incomplete extraction.

The current checkout has only conversion/Finder noise: two dialogue GML files differ by final blank lines, tracked and untracked `.DS_Store` files exist, and untracked `thpj5.yyp` is byte-identical to tracked `tyvnj2.yyp`. Its configured public origin was not resolvable during this snapshot, so cached remote state is not live provenance evidence.

The selected current graph contains about 2,706 GML lines across ten objects, eleven scripts, six rooms, 21 sprites, eight fonts, three sounds, and one timeline. It still references 17 resources that were removed from the graph:

- four backgrounds: Chireiden, Misty Lake, Moriya, and therapy;
- seven talk portraits: Kanako, Koishi, Rin, Sanae, Satori, Suwako, and Utsuho;
- chapter timelines one through six.

Those missing resource references are likely compile blockers by static inspection. Current `dbaa721` is therefore a recovery source, not a runnable host.

Its uniquely valuable fragment is the original 432-line `scr_menu_draw`, which covers title, file, erase, options, and substantial dormant gallery/music presentation. The packed THPJ5 copy accidentally reduces that script to zero bytes; the later dialogue template supplies a smaller 196-line repaired renderer. Preserve the 432-line source as a complete UX inventory and visual reference, but use the template repair as the safer behavioral foundation.

The isolated engine also makes several legacy weaknesses especially visible:

- dialogue consumes fixed 12-line records and initializes parallel queues without a matching Destroy cleanup;
- declared CG, shout, and writer modes have no complete Step transition path;
- backlog initialization appears to index `global.log_text[LOG_LIMIT]` and `global.log_name[LOG_LIMIT]` rather than simply create the arrays;
- the file loader decodes twice, loses ownership of replaced maps, and has no schema or atomic write;
- the pauser creates one surface with width used for both dimensions and repeatedly churns log surfaces.

Use the initial commit for original provenance/content, the pack/template for the migrated runtime, and current `dbaa721` only for deliberate fragment recovery. None supplies a general asset license, and the Touhou-derived content remains unsuitable as original Blade IP.

## Older dialogue formats

### Original THPJ3 six-line frames

The original THPJ3 files encode each frame in six physical lines and feed parallel queues for name, emotion, active speaker, and text. Five files contain 60, 72, 72, 72, and 48 physical lines. The packed/template migration produces five JSON files and 54 total frames.

This format is useful only as a migration fixture. Parallel queues make frame integrity fragile, actor capacity is hard-coded, and presentation data cannot evolve safely.

### Project Crowblade V3 frames

The platformer prototype uses 12 lines per frame:

```text
background
music
sound
display
actor 1 sprite
actor 1 position
actor 2 sprite
actor 2 position
actor 3 sprite
actor 3 position
speaker name
text
```

It supports three actors, typewriter, ADV, narration, no-text, auto, and skip. Its cutscene timeline moments at 50 and 60 are empty. Preserve the format only as conversion-test material.

### THPJ5 numeric legacy frames

The design archive contains the numeric THPJ5 story format as 12-line records: background, music, sound, display, three actor sprite/position pairs, speaker, and text. The six files contain exactly 201 frames: chapters 1–5 contribute 17, 38, 41, 68, and 36 frames, while the test file contributes one. It is valuable for verifying that migration retains actor placement and display choices; it should not remain a second canonical authority next to JSON.

### THSJ narration blocks

THSJ2022 contains 11 older seven-line records. Each stores the previously active side, background ID, left emote/name, right emote/name, and text; `#` inside text represents a line break. The corpus exercises narration with unnamed actors, one-sided speech, two visible actors, and background changes. Its dialogue/cutscene behavior belongs in the compatibility-fixture set, while the shared normalized runtime should remain the foundation.

## Neuro Jam 2 dialogue and cutscenes

Neuro's dialogue is independent of the converged runtime. `scripts/dialogue_script/dialogue_script.gml` is a 373-line in-code struct/DS-queue system with eight scenes and 27 frames. The ordinary level route uses 24; the intro struct is superseded by `obj_textintro`, and a test scene is development residue.

It supports:

- ADV bottom-box text;
- fullscreen line fades;
- sprite-array actors;
- background crossfade;
- looping music;
- one-shot audio;
- Input-based `X` advancement.

Its scene and talkable parents pause their own timeline while dialogue exists and resume afterward. This pause handshake is a useful choreography contract.

Weaknesses include:

- a global dialogue queue without visible destruction;
- a declared `DISPLAY.NOTEXT` mode with no Step transition path;
- fullscreen typing that loops across the source string while a separate reveal length advances;
- content embedded in code rather than canonical JSON;
- no reason to choose it over the stronger shared normalizer.

Use Neuro's drone-reveal timing as sequence design reference, not its dialogue engine.

## Save and checkpoint experiments

### Dialogue-template slots

Strength: understandable chapter/line data, autosave, three slots, and previews.

Do not preserve:

- filename inconsistencies;
- unversioned DS maps;
- weak type validation;
- non-atomic writes;
- direct coupling to the dialogue object's current line.

### Project Crowblade slots

The prototype has `test_save_A`, `test_save_B`, and `test_save_c`, each storing a DS-map with `save_point`. A loader waits 20 frames, and four room-ordered savepoints assign numeric IDs. `V` writes at a savepoint.

The title state vocabulary—continue, new game, slots, preview, erase confirmation, temporary options, defaults, music room, credits—is better than the persistence implementation. The lowercase third-slot filename, modal `show_message`, absent schema/migration, and unclear DS-map lifetime should not survive.

### Neuro checkpoint registry

Neuro's JSON is shaped as:

```json
{
  "game": {
    "save_point": null,
    "default_start_room": null,
    "time": 0,
    "lv1_scene_played": false,
    "lv1_endscene_played": false
  },
  "options": {
    "fullscreen": false,
    "vsync": false,
    "volume_music": 1,
    "volume_sound": 1
  },
  "save_points": {
    "rooms": [],
    "position": { "x": [], "y": [] },
    "names": []
  }
}
```

`generate_savepoints()` reconciles persisted parallel arrays with room instances, assigns tags, and can synthesize missing savepoint instances. Loading places the player and marks the checkpoint as spawned-in. A save screenshot is captured for title preview.

The intent—stable world checkpoints that survive room edits—is strong. The implementation has no schema version or corruption migration, uses parallel arrays, and risks deleting an already-deleted buffer on repeated save. Dynamically loaded preview sprites have no visible disposal. New Game resets only `game`, leaving the savepoint registry and options.

Adapt the registry as records keyed by stable checkpoint ID:

```json
{
  "schema_version": 1,
  "checkpoint_id": "stage_1.bridge_entrance",
  "visited": ["stage_1.start", "stage_1.bridge_entrance"],
  "story_flags": {},
  "run_state": {},
  "options_profile_id": "default"
}
```

Validate IDs against content, migrate by schema version, write atomically, and own screenshot lifetime explicitly.

### Escape Velocity host data wrapper

This wrapper is definitely not reusable:

- `save_default` points to the options object rather than save data;
- save size is derived from options;
- fullscreen is forced true when applying settings;
- voice gain uses sound volume;
- async load never parses the loaded buffer;
- default JSON is stringified twice;
- audio-group async events are not matched to the expected request.

## Input 8.0.3

### Identity and scale

Input 8.0.3, dated 2024-12-03 and authored by Juju Adams and Alynne Keith, appears in both Escape Velocity and Neuro. It is MIT-licensed with SDL/Chromium notices and mapping data.

The Escape pack exposes 332 script resources:

- 235 public `input_*` scripts;
- 95 internal `__input_*` scripts;
- two host scripts.

Neuro carries 330 Input scripts plus its own game scripts. Treat each copy as one dependency, not hundreds of independent extraction candidates.

### Capability surface

The library supports:

- held, pressed, released, repeated, long, and double checks;
- scalar, axis, 2D, direction, and distance input;
- keyboard, mouse, gamepad, touch, virtual buttons, and direct sources;
- action/verb groups and asymmetric profiles;
- binding creation, removal, swapping, collision checks, and scan workflows;
- profile import/export/verification;
- player assignment, joining, copying, swapping, and disconnect;
- device hotswap and gamepad-type databases;
- cursor movement, translation, and geometric constraints;
- icons and accessibility color support;
- multiplayer source ownership;
- vibration envelopes, pulses, curves, LEDs, motion, and trigger effects;
- system-level serialization and reset.

Representative API includes `input_check`, `input_check_pressed`, `input_check_repeat`, `input_value`, `input_xy`, `input_binding_scan_start`, `input_binding_set_safe`, `input_player_import`, `input_profile_export`, `input_cursor_limit_boundary`, `input_system_verify`, and `input_vibrate_adsr`.

### Escape configuration

Escape's wrapper configures four players, hotswap, keyboard/mouse grouping, four alternate bindings, repeat/long/double/chord timing, cursor speed, thresholds, touch, vibration, SDL mapping, and verbs such as advance, reverse, skip, menu, log, save/load, quicksave/quickload, fullscreen, help, and hide UI.

The host dialogue checks an `interact` verb that is not configured; gamepad and touch bindings are empty.

### Neuro configuration defect

Neuro's keyboard profile maps arrows, interact, climb/drop, jump/recall, command, and pause. Its gamepad profile instead defines generic accept/cancel/action/special/aim/shoot. Because asymmetric profiles are allowed, gameplay gamepad actions are effectively absent except pause until the profile is repaired.

### Adoption decision

Input is a capable choice if Blade requires rebinding, multiple devices, accessibility, hotswap, cursor emulation, or multiplayer. It also brings hundreds of GameMaker resources, mapping databases, notices, and an imported-code maintenance boundary.

If adopted:

1. source it from a vetted upstream release;
2. lock exact version and dependency files;
3. keep imported code read-only;
4. preserve licenses and controller databases;
5. expose only project-owned named actions to game code;
6. test keyboard/gamepad parity for every required action;
7. prevent content and UI from calling `input_*` directly.

If Blade needs only one player and a modest action set, a smaller project-owned snapshot/action service is likely easier to fit, test, and maintain.

## Menu and pause design vocabulary to preserve

Across THPJ5, Crowblade, Neuro, and the archived Blade slice, the useful UX vocabulary is:

- press-start gate;
- main menu;
- new run / continue;
- multiple save slots and preview;
- erase confirmation;
- temporary options with save/discard/default;
- fullscreen, scale, vsync, and volume categories;
- music room/gallery/credits as optional modules;
- pause snapshot;
- dialogue backlog;
- hold-to-confirm destructive or long-latency actions;
- configurable return-to-title countdown.

Represent this as data-driven menu definitions plus explicit state transitions. Keep save mutation, audio preview, display application, and navigation in separate services.

## Characterization tests to carry forward

1. Every accepted dialogue envelope normalizes to the same canonical frame.
2. Invalid root, actor, display, asset ID, or duration reports a stable validation error.
3. ADV, narration, NVL, and silent frames advance correctly under manual, skip, and auto controls.
4. Pausing and dialogue each acquire/release a pause token without resuming another owner's pause.
5. Voice stops on advance, skip, scene exit, and dialogue destruction.
6. Background crossfade and actor slots use logical view coordinates at multiple aspect ratios.
7. Save resume uses stable frame IDs and survives inserted dialogue frames.
8. Choice and condition evaluation is deterministic and serializable.
9. Save writes are atomic; corrupt and future-version files fail safely.
10. Checkpoint IDs survive room reorder; deleted IDs migrate to a declared fallback.
11. Preview screenshots and dynamic sprites are disposed on replacement and title exit.
12. Every project action has keyboard and gamepad behavior or an explicit unsupported-device declaration.
13. Imported Input code remains unchanged while project-owned adapters and tests can evolve.
