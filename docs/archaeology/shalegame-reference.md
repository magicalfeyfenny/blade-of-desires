# ShaleGame Reference Architecture

Path: `/Users/magicalfeyfenny/GitHub/ShaleGame`

## Boundary and snapshot

Shale is a Godot/C#/GDScript search-action platformer. It has no root code license, so this report recommends clean-room GameMaker adaptations of contracts and ideas, never direct code copying.

Observed snapshot:

- clean `dev`, exactly `origin/dev`;
- HEAD `f46e3fa2d29a8e0d017dcf4e75e26e7e9cb4cd6d` (`feature: Add projectile penetration (#349)`), 2026-06-21;
- Godot .NET 4.5.1, C#/.NET 8, Forward Plus;
- 1,523 tracked files;
- 215 C# files, 254 GDScript files (227 vendored addon, 27 project-local/non-addon);
- 141 scenes, 99 resources, nine shaders;
- 100 PNG, 39 Aseprite, two ASE, 17 MP3, 15 WAV, four OGG, five TTF;
- 242 static `[Fact]` and two `[Theory]` test methods through xUnit/2dog;
- no build, test, export, or GUI run during this inspection.

Ignored `.godot`, test `bin`, and `obj` trees account for most of the ~492 MB checkout. They are not fresh evidence. A static scan of literal `ext_resource` path declarations in tracked `.tscn` and `.tres` files found none missing; vendored addon examples can still contain non-existent illustrative `res://` strings.

## Project identity and services

Public title is Shale; internal assembly/project identity remains Crossed Dimensions. The main scene is `UI/UIMainMenu/MainMenu.tscn`. Base display is 640x360, viewport stretch, nearest filtering, HDR 2D.

Autoloads:

- `SettingsManager`;
- `ScreenOverlayManager`;
- `DebugHUD`;
- `MusicManager`;
- `SaveManager`;
- `SceneManager`;
- `AreaManager`.

Physics layers explicitly separate player, enemy, freezable, hurtbox, and hitbox. Groups identify Player, Bullet, Enemy, SiracusHole, and SceneMarkers.

The service-node architecture is useful, but the always-loaded DebugHUD creates a serious release boundary described below.

## World data and scenes

Fourteen top-level gameplay/cutscene scenes range from tiny test rooms to editor-authored levels with hundreds of nodes. `CaveLevel.tscn` has 322 nodes, `IceLevel.tscn` 222, and `AetherLake.tscn` 147. There are 30 save points and eight `AreaData` resources.

Transitions use a target scene path plus named `Marker2D` in the `SceneMarkers` group. Puzzle persistence uses structured free-form keys such as `cave/puzzle_seq1/door` and `ice/puzzle2/door`.

Static schema drift is visible: `Assets/AreaData/LabLevel.tres` serializes a `Color` field no longer present in `AreaData.cs`, whose current fields are only title and subtitle.

Large monolithic level scenes are appropriate editor artifacts in Godot but are not a content architecture to copy into GameMaker. Stable scene-marker IDs, area metadata, and persistence keys are the transferable ideas.

## Compositional state machines

Core types are `State`, `StateMachine`, `GdState.gd`, `Character`, character controllers, and character states.

### Mechanics

- A `State` node's children are ordered behaviors.
- Children may be C# states or GDScript nodes.
- C# injects Context and calls `enter`, `exit`, `process`, `physics_process`, and `input` dynamically on GDScript behaviors.
- A behavior may return another state; transition propagates immediately.
- `StateMachine.ChangeState` exits, enters, then recursively follows any state returned by Enter.
- Character brain and movement use separate machines.
- Weapons reuse the same model with idle/wait and behaviors such as fire projectile, release freeze, and play sound.

Movement states cover idle, move, air, split, merge hold, frozen, and noclip. Character velocity is split into input-driven and external-force components; collision changes are apportioned back into external velocity.

Base movement is 192 px/s with 72-pixel jump height. Jump velocity derives from gravity/height; releasing or exhausting sustain applies fourfold gravity. Overlapping jump crystals use an overlap count so one exit cannot revoke a grant supplied by another crystal.

### Strengths and risks

The behavior model supports player, weapons, enemies, and bosses without inheritance explosions. Mixed C#/GDScript composition gives designers small editable behaviors.

Risks:

- no transition budget/cycle detection, so Enter cycles can recurse to stack exhaustion;
- state lookup by names such as `Split State` makes editor renames runtime-sensitive;
- dynamic mixed-language calls lose compile-time safety;
- RNG is ambient rather than injected/seeded.

GameMaker adaptation: use explicit state IDs/records and function hooks, validate the state graph, and cap immediate transitions per frame.

## Clone, split, merge, and healing

Primary source: `Characters/CloneableComponent.cs` plus split/merge states.

### Contract

- Split force 768.
- Cooldown 0.5 seconds.
- Immediate release-to-merge window 0.25 seconds.
- Clone damage converts to healing at 0.5 efficiency.
- Healing pool applies over two seconds after merge.
- Transform, velocity decomposition, jump permissions/timing, frozen duration, inventory, and equipped weapon are copied.
- Current and maximum HP split into complementary integer halves.
- Clone input mirrors with `XScale *= -1`.
- Pre-tree and post-tree split signals expose lifecycle seams.
- Merge sums health, records the clone's old instance ID, queues clone deletion, and prevents already-fired clone projectiles from hitting the survivor.
- Merge-hold checks death so healing cannot resurrect a dead character.
- HUD has original/clone/healing bars and an offscreen chevron indicator computed at the viewport edge.

### Static defects

- Clone preparation instantiates a PackedScene inside `Task.Run`; Godot object creation is generally main-thread-bound.
- Worker/main state shares `_isExitingTree` without synchronization and does not cancel an incomplete task.
- Original-component `Merge()` emits `CharacterMerged(Original)` even though that component's `Original` is null. The HUD is connected to the original component and ignores the payload; when merge is invoked on the clone, the clone component later emits the correct original payload, but the HUD is not connected there. The bad payload is therefore real even if the present HUD does not expose it.
- Tests cover division, cooldown, inventory, merge, and healing but not worker-thread preparation or the exact merge payload.

Blade adaptation: the copy/mirror/healing-reserve ideas could become familiars, echo ships, dual forms, or boss reflections. Use synchronous creation, stable faction/entity IDs, explicit ownership transfer, and tested signal payloads.

## Combat components and projectile penetration

Core components separate health, damage payload, freeze, hitbox, hurtbox, and projectile.

### Hit/damage flow

- Health clamps `0..MaxHealth`, exposes alive state, and signals old health.
- Damage carries integer damage, knockback multiplier, and knockback transform.
- Hitbox owns source identity, self-hit policy, ignored groups, optional distance falloff, lifetime, and hit signals.
- Hurtbox owns invulnerability, damage/knockback application, mirror/merged exclusions, and frozen partition.
- Frozen targets receive 25% damage; 75% damages the ice shell.
- Self/mirror damage is zeroed after knockback calculation, allowing rocket movement without self-damage.
- Frozen actors can be moved onto collision layer 5 and become platforms.

### Projectile hierarchy

Projectile owns speed, direction, gravity, hitbox, lifetime, free-on-hit, character/weapon owner, and integer penetration. On projectile collision, equal/stronger penetration is reduced by the weaker projectile's value; the weaker receives its normal hit/free handling; depleted survivors die.

Representative strengths:

| Projectile | Penetration |
|---|---:|
| Dev | 100 |
| Icicle | 8 |
| Seed | 5 |
| Pellet | 3 |
| Ice crystal | 2 |
| Bullet/rocket | 1 |

This integer hierarchy conceptually maps cleanly to Blade bullet cancellation, shields, armor, piercing, and hostile-shot interactions; because Shale has no root code license, it is a clean-room design candidate rather than a direct extraction source.

Static risks:

- direct position integration has no swept collision;
- original and clone projectile owners are distinct despite allied hurtbox rules, so projectiles may cancel each other;
- two null owners compare equal and do not resolve;
- projectile spawn parent has a TODO rather than a world/projectile container;
- Freeze dereferences Health unconditionally and repeated Freeze can duplicate subscriptions;
- debug print sites remain numerous.

Adapt with stable faction IDs, deterministic pair ordering, reason-coded resolution, and swept/substepped motion where required.

## Inventory and weapon states

`ItemData` contains name, multiline description, and icon. `Weapon` delegates to a state machine and exposes primary/secondary input, target direction, and selection state. Inventory discovers weapon children, assigns ownership, cycles/selects slots, signals add/remove/equipped, mirrors new items, and rebuilds a clone's inventory on split.

Weapons include pellet shooter, rocket launcher, Heart of Siracus, and developer weapon. Heart fires freeze crystals and releases tracked frozen targets on secondary action.

Weaknesses:

- `InventoryComponent.cs` is 546 lines covering discovery, selection, clone sync, signals, and persistence;
- persistence stores scene paths, brittle under renames;
- mirror matching uses node names;
- Godot node duplication assumes every desired runtime/editor property and connection survives.

Transfer the inventory/equipment events and weapon state concept, not scene-path persistence or name matching.

## Enemies and bosses

Enemy scenes include bats, bugs, goats, ice variants, bee/nest, plant turret, scuttler, turret, and a generic spawner. Most combine Character, EnemyController, separate brain/movement machines, health/hurtbox, and weapon components.

Reusable behaviors seek a group with distance/raycast visibility, apply controller fire, aim, and patrol with wall/ledge probes. The spawner creates within 1,000 units and despawns outside, then respawns after death.

Spawner risks: it resolves one player only at Ready, may select original/clone by unstable group order, and chooses a spawn parent using a scene-layout-sensitive grandparent heuristic.

### Boss system

`BossSystem` loads a PackedScene, spawns at a marker, drives title card, persists defeat by key, emits spawn/defeat, and can drop an item. Boss rooms integrate cameras, doors, music, triggers, save points, and titles.

Drill and Siracus have rich state families. File Cypher is the most transferable sequencer:

- phase change at 50% HP;
- one second between attacks, three-second stagger;
- phase 1: BurstGun, GroundSlam, BurstGun, HomingMissiles;
- phase 2: BulletHell, SwitchPressure, BulletHell, SpiralBulletHell, PhaseTwoStagger, SwitchPressure;
- phase 2 moves between two air markers at 180 px/s;
- vulnerability depends on pressure switches or explicit stagger;
- bullet hell uses 16 shots/ring, three rings, 0.25 seconds between rings;
- burst gun uses three bursts of three.

`SecuritySystem` and `SummonClone` are fully implemented state nodes but absent from live sequences; special handling for SummonClone is therefore unreachable. They are iteration evidence, not live encounter behavior.

Adapt phase arrays, completion handshakes, thresholds, tracks, vulnerability gates, and stagger windows as validated JSON. Require every implemented attack to be reachable or explicitly test-only.

## Trigger and Activator logic

This is Shale's highest-value clean-room concept.

- `Trigger` is a logical active/inactive source with optional SaveKey and sticky state.
- `Activator` listens to several triggers and emits activation/deactivation.
- Sticky activators can persist their own key.
- Read-only activators may initialize a door from an authoritative boss/progression flag without overwriting it.
- `ActivationLogicActivator` supports all, any, exactly one, and none.
- Visual, collision, and music listeners are separate from logical state.
- Concrete triggers cover presence, hitbox, boss, cutscene, title, and jump/dash crystals.

This supports levers, pressure switches, shootable targets, dual-switch doors, moving platforms, and other puzzles.

Risks:

- persistence writes only to in-memory SaveFile until a save point flushes;
- saved Trigger state loads without `initial:true`, so startup signals depend on Ready order;
- save keys are free-form and unvalidated.

Blade adaptation: canonical JSON trigger/condition/activation records, stable registry keys, deterministic initialization phases, and separate visual/audio/collision listeners.

## Save, scene, and cutscene management

### Save data

`SaveFile` is a version-1 Godot Resource containing name, timestamp, obsolete autosave flag, and generic dictionary. Typed fields store player scene, weapon scene paths, and equipped index. Files are `user://saves/save_{timestamp}.tres`; save points record scene/position/inventory/state and heal players.

High-confidence static defects:

- `CreateNewSave` mutates cached `default-save.tres` without duplication, allowing new saves to alias/leak state;
- one-second filenames can collide;
- ResourceSaver errors are ignored;
- writes are non-atomic/unchecksummed/unbacked-up;
- Version has no migration logic;
- generic conversions can throw despite Try-style naming;
- save-loader buttons are detached but never freed;
- `CloseSaveLoader()` iterates `_loadButtons` even when the collection may not have been initialized by `Open`, adding a null-path to the detached-button lifetime problem;
- simply opening the loader mutates a default resource;
- missing player can null-dereference at save point.

This is a warning case, not a save foundation.

### Standard transitions

SceneManager caches PackedScenes, optionally pauses, fades to black, changes scene, applies marker/position callback, unpauses, and fades out. Public sync wrappers discard tasks and ordinary transitions lack an in-progress guard, so overlapping triggers can race.

### Suspend-and-restore cutscenes

The best scene-management idea:

1. remove current gameplay scene from tree without destroying it;
2. instantiate cutscene as current;
3. run it;
4. free cutscene;
5. reattach the exact gameplay instance;
6. optionally reposition player and consume trigger.

Signals expose CutsceneLoaded and GameplayResumed; a playback-speed seam accelerates tests.

GameMaker cannot copy the exact tree operation, but can preserve a live controller/state snapshot or overlay cutscene without destroying room-owned state.

## Dialogue and interactions

There are 48 dialogue resources. A frame stores speaker, text, background, portraits, and portrait positions; a reel is an ordered array. DialoguePlayer queues reels/frames, DialogueBox types one character every 0.025 seconds, and CutscenePlayer sequences animation or dialogue steps.

Current renderer only displays portrait element zero; serialized background and portrait-position fields are unused. Choices, branches, localization, voice, and stable record IDs are absent. An alternate dialogue iterator is dormant.

Interactables use 0.5-second hold by default, reject clones/NPCs, and signal progress/prompt. Priority is declared but no central overlap resolver uses it.

Risks:

- dialogue advances in keyboard-only `_UnhandledKeyInput`;
- interaction calls global `Input.ActionRelease`, interfering with other listeners;
- listener assumes one original player and a fixed HUD path;
- duplicate dialogue implementations increase ambiguity.

Adapt the cutscene step queue and hold-progress signals. Prefer Blade's richer JSON dialogue plan for content.

## Settings, input, and accessibility

Input has WASD movement, Shift split, Space jump, mouse fire, wheel cycle, 1/2/3 slots, E interact, pause, and numerous debug keys. No gamepad events are configured.

Settings persist window mode, shake, VFX, HDR 2D, and assist speed snapped to 0.1 in `0.5..1.0`. Rebindings persist key/mouse details; debug/UI actions are excluded.

Weaknesses:

- no gamepad serialization;
- existing bindings are erased before every replacement is validated;
- schema/version/atomicity absent;
- one event per action in UI;
- no conflict detection or restore defaults.

The assist-speed composition and action-oriented binding model are useful; persistence should be stricter.

## Determinism boundary

Multiple boss, enemy, and feedback systems construct ambient `RandomNumberGenerator` instances without a project-owned seed/stream service: four Siracus behavior components, Drill boss behavior, IcicleBees, and `ScreenOverlayManager` are observed examples. The fixed-rate test fixture and File Cypher's ordered arrays are valuable seams, but full gameplay replay determinism is not established.

## Audio stack

Music priorities are Low 0, Background 1, Boss 2. One track per priority remains cached; highest active is audible. Lower layers fade, pause, and survive for a 15-second grace period so they can resume without restarting. Fade duration is three seconds. Interactive tracks can select named clips; Ice has Sparse and Full Orchestra.

Buses include Master with low-pass, Music, Ambient, and reverb SFX. Screen feedback drives the Master low-pass temporarily.

Static defects:

- playing null stores then dereferences null;
- StopTrack assumes non-null;
- zero fade duration divides by zero;
- music provenance is undocumented.

Adapt the priority/resume/grace model with explicit stop/null commands and cue JSON.

## Rendering and feedback

Nine shaders cover water refraction/reflection, black-to-alpha, damage flash/vignette, dash ghost, luminance keying, multiply scroll, pause blur, and screen-light response. Levels use layered parallax, HDR materials, water, particles, local lights, and editor parallax preview.

`ScreenOverlayManager` owns fades, vignette, audio muffle, time scale, shake, VFX gates, freeze timers, and test-speed seams. Current resource values allow time scale down to 0.016 for severe hit stop.

These are strong feedback primitives. Blade should centralize them behind deterministic commands and avoid direct global time/audio mutations from arbitrary effects.

## Release debug defect

`DebugHUD` is always autoloaded. `DebugManager.HasDebugAccess()` returns true. It exposes god mode, noclip, invisibility, HUD hiding, save inspector/writes, reloads, and DevWeapon. Debug input remains in production config, exports use all resources, and presets include debug symbols.

Static conclusion: debug controls are not restricted to editor/debug builds. This is a concrete example of why Blade needs one fail-closed debug capability gate and export tests.

## Tests and CI

The test stack uses 2dog/2dog.xunit 0.1.16-pre, xUnit 2.9.3, Shouldly 4.3.0, Microsoft.NET.Test.Sdk 18.0.1, coverlet 6.0.4, and VS runner. A headless fixture embeds Godot at fixed 60 Hz, disables parallelism, preloads assemblies, supplies native paths, and accelerates cutscene/fade clocks. Dummy audio is configured separately by `.github/workflows/2dog-tests.yml` through `GODOT_AUDIO_DRIVER=Dummy`.

The main `CrossedDimensions.csproj` marks NSubstitute 5.3.0 as a runtime-only dependency even though NSubstitute is a mocking library, and no tracked C# use was found. This appears to be an unused production dependency and packaging-surface risk by static inspection; no build/export was run.

Tracked `global.json` selects .NET SDK 8.0.122 with `rollForward: latestFeature`, and direct package references have exact versions, but no `packages.lock.json` or other NuGet lock file was found. SDK selection is constrained yet may roll forward, and transitive package resolution is not locked.

Large families cover clone integration, dialogue, cutscene, interaction, inventory, hurtbox/projectile combat, bosses, and transitions. CI is configured to import Godot headlessly, run tests, publish TRX, and generate coverage; it was not run during this audit.

Static CI concerns:

- README branch description is stale;
- coverage check reports success even without summary and has no threshold;
- export commands use `continue-on-error`;
- solution Release maps main game project to Debug;
- export presets include debug symbols;
- 495 vendored gdUnit4 v6.1.1 files are no longer the xUnit/2dog test suite but the addon remains enabled in `project.godot`;
- both export presets use `all_resources`, so enabled legacy test/addon content may be packaged; this is a static inference because no export was run.

The transferable lesson is the fixed-rate nonparallel engine fixture, accelerated presentation seams, and scene-level integration coverage—not the framework dependency itself.

## Assets and provenance

`Assets` has 398 tracked files: many sprite families retain Aseprite masters beside PNG exports. Content covers player, enemies, bosses, items, props, tiles, portraits, parallax, particles, audio, UI, and dialogue.

Hygiene/provenance issues:

- no source/export manifest;
- extensionless file that is actually PNG plus a separate `.png`;
- three tracked editor temp scenes;
- mixed `Backgrounds`/`backgrounds` naming;
- no Git LFS policy;
- root code has no license;
- audio attribution does not map cleanly to every present file;
- music has no explicit license record;
- Terminus fonts are OFL, while `calamity.ttf` lacks adjacent license;
- vendored gdUnit4 is MIT; Parallax preview has no found license in repo.

Use this as evidence for Blade's stricter source/runtime/manifest/license rules.

## Ranked clean-room adaptations

1. Trigger/Activator condition graph.
2. State/behavior composition with transition-cycle protection.
3. Projectile penetration/cancellation hierarchy.
4. Hitbox/Hurtbox/Damage/status-shell separation.
5. Priority resumable music layers.
6. Suspend-and-restore cutscene lifecycle.
7. Data-driven cutscene step queue.
8. Input versus external-force velocity decomposition.
9. Clone/mirror/healing-reserve ideas for echoes/familiars.
10. Boss sequencer thresholds, completion handshakes, vulnerability, and stagger.
11. Fixed-60-Hz engine integration tests with accelerated presentation clocks.
12. Assist settings and strict action rebinding.
