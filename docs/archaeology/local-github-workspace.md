# Local GitHub Workspace

Source: `/Users/magicalfeyfenny/GitHub/`

## Repository map and worktree qualification

| Repository | Approx. checkout | Audit-time branch/status | Role |
|---|---:|---|---|
| `blade-of-desires` | 1.4 MB before reports/local residual file | local `dev` at `afa43e2`, one behind then-current `origin/dev@2b8532b`; one untracked resource-order file beneath `project/` | Governed destination; publication base `origin/dev@6b938aa` adds the merged GMTL lock |
| `gm-ai-workflow-template` | 2.2 MB | clean `human/32-move-skills-to-correct-directory` | Workflow source; human branch was not modified, reviewed, or validated |
| `tyvnj2` | 6.2 MB | `master`; dirty conversion files and untracked `thpj5.yyp` | Local THPJ5-era VN repository |
| `canned_pears_original` | 23 MB | `main`; user-owned modified `.DS_Store` | Unity team project/prototype |
| `thpj3` | 62 MB | `master`; untracked `.DS_Store` | Local/public THPJ3 mirror |
| `ai-gen-test` | 67 MB | clean `main` | Older Blade/GameMaker experiment |
| `neuro-jam-2` | 99 MB | `main`; roughly 110 conversion/resource metadata changes | Local/public Neuro source plus worktree conversion |
| `ShaleGame` | 492 MB | clean `dev == origin/dev` | Godot/C# action-platformer reference |

All dirty/untracked files predated this report and were treated as user-owned. No cleanup, checkout, build, or project execution occurred.

## Current `blade-of-desires` repository

At audit start, local `dev@afa43e2` was stale by one commit relative to then-current `origin/dev@2b8532badb3443c3eb8433440f8dc576a28ff3bc`; that commit added a minimal GameMaker project and GMTL through `add project file, GMTL (#1)`. No branch was switched and no incoming files were checked out during that read-only pass. This report's publication branch is instead based on current `origin/dev@6b938aa8c4ad9972b8195d58657cca71ba497918`, which also includes the merged GMTL integrity lock from PR #3.

The destination contains:

- repository and contributor policy;
- a risk-tiered issue/branch/draft-PR lifecycle;
- CI workflows and GitHub ruleset recipes;
- repository/PR/metadata validators;
- unit tests for policy, setup, metadata, and templates;
- source/runtime asset roots and `assets/exports.json`;
- canonical `content/` root;
- `project/~ blade of desires ~/`, a GameMaker 2026.0.0.16 GMTL v1.2 demo/test graph;
- local GameMaker production, governed-change, and project-steward skills.

The imported project is 61 files and 5,822 added lines. Its YYP selects 21 resources: fourteen scripts, three demo objects, two rooms, one sprite, and one font. `GMTL_init.gml` identifies GMTL v1.2, released 2026-05-04. It contains GMTL demonstrations/tests, not Blade gameplay.

Current `origin/dev@6b938aa` contains `gmtl.lock.json` and a fail-closed validator for an exact 20-root/47-file read-only import. This identity boundary does not repair GMTL's characterized matcher defects or supply the missing retained upstream MIT notice.

Important boundaries for using this archaeology:

- canonical GameMaker structured data belongs once under `content/` as JSON;
- editable raster/vector/audio/3D sources and runtime derivatives have explicit formats;
- runtime derivatives need manifest entries;
- source files have one responsibility and an 800-line maximum for configured source extensions;
- imported third-party code should be version-locked/read-only;
- this report does not itself extract code or assets.

The audit-time stale local worktree did not contain the 61 incoming project files. Its status collapsed one residual local-only file, `project/~ blade of desires ~/~ blade of desires ~.resource_order`, into the untracked directory display. Separately, then-current `origin/dev` tracked 61 other files at that path. The residual remains user-owned and unmodified on the publication branch.

## `gm-ai-workflow-template`

The template and destination share the same 39-file governance base. Blade's current `origin/dev` additionally contains the 61-file GMTL project import and its merged integrity-lock machinery. Approximately 5,500 base-scaffold lines cover:

- `check_repo.py`: source structure, JSON, assets, manifest, and baseline-aware policy;
- `pr_policy.py`: branch/issue/risk/completion rules;
- `pr_metadata.py`: exact metadata state, digest, attestation, and comparison;
- `setup_github.py`: repository settings, labels, branches/rulesets, and idempotent API setup;
- five unit-test modules;
- three reusable local skills;
- CI, auto-merge, human-created, and issue/PR templates.

The workflow's relevant design lessons are:

- separate integration (`dev`) from release (`main`);
- bind validation to exact candidate and metadata state;
- make risk paths/thresholds executable data;
- separate human-created work from agent-governed automation;
- make asset authority and canonical content locations explicit;
- require milestones and handoff evidence.

This is process infrastructure. Do not mix gameplay archaeology into policy modules; the reports should inform bounded future issues.

## ShaleGame

See [ShaleGame reference architecture](shalegame-reference.md) for the deep report.

The highest-value clean-room ideas are Trigger/Activator condition graphs, compositional state behaviors, clone/mirror state transfer, componentized hit/damage/status logic, projectile penetration hierarchy, ordered File Cypher boss sequencing/completion handshakes, suspended-live-scene cutscenes, resumable priority music, and fixed-rate headless integration tests.

The strongest warnings are an always-accessible release DebugHUD, aliased default-save resources, non-atomic/version-1 generic saves, probable off-main-thread scene instantiation, a null merge-signal payload, ambient RNG, mixed/unmanifested asset provenance, and no root code license.

## Canned Pears Unity team prototype

Path: `/Users/magicalfeyfenny/GitHub/canned_pears_original`

### Provenance and boundary

- Remote belongs to `1103-shahnazarian-milana/canned_pears`.
- 63-commit team history includes Fenny, Jonathan Cantlon, and Apollo/Milana Shahnazarian identities.
- Fenny-authored history covers project bootstrap, data/save/options, title UI, scene/game management, early movement/collision/battle integration, audio placeholder, and merge/reintegration work.
- No root README or license exists.

This is a team repository with mixed authorship and no explicit license. Reuse only Fenny-owned work where authorization is clear, or adapt behavior clean-room after team permission. Third-party Unity/TextMeshPro/system-font assets retain their own terms.

### Engine and inventory

- Unity `6000.2.10f1`.
- Universal Render Pipeline 17.2.
- Input System 1.14.2.
- 44 C# files, one of which is a 1,236-line generated Input wrapper; about 3,544 C# lines total.
- Five authored scenes plus three recovery scenes.
- 25 prefabs.
- 172 tracked `.meta`, 34 `.asset`, 14 shaders, four shader graphs, and small audio/sprite set.
- Build scenes are title, basic room, connector, and mantis boss.
- A 9.5 MB Mono crash-memory blob is tracked.

The intended game appears to be a 2D labyrinth/dungeon party RPG with field movement and triggered turn-based encounters.

### Runtime service design

Persistent singleton-style managers cover:

- GameManager and party construction;
- CombatManager and turn order;
- DataManager and options/save;
- HUDManager;
- SceneTransition;
- AudioPlayer;
- Inventory;
- movement/input.

Party members Bil Muri, Aisha Etrenna, and Gerald Mandrakecoven derive from `BaseCharacter`. Enemies include armored wolf, toxic slime, fae bat, sinister eye, crystal shade, drider, Alvar, and sample monster.

`CharacterData` holds HP, ATK, DEF, SPD, initiative, defense/alive/party/leader flags, abilities, and status effects. `BaseCharacter.InitializeStats()` delegates to each concrete `AssignStats()`.

### Field movement and interaction

`movement_manager` uses generated Input System actions:

- horizontal Rigidbody2D velocity only;
- sprite flip from horizontal sign;
- one-unit raycast for interaction;
- default right-facing interaction when horizontal input is neutral.

`InteractionTrigger` can represent boss, NPC, combat, or hazard and can be one-time. Combat triggers instantiate up to three configured enemies at local offsets under the enemy-party container, initialize their stats, make rigidbodies kinematic, disable movement input, and start combat.

Useful intent: one editor-configurable encounter trigger and separate party container. It needs a single encounter-start transaction and explicit trigger/encounter IDs.

### Turn-based combat

`CombatManager` builds a combined list of living player and enemy `BaseCharacter`s, sorts descending initiative, and advances circularly. Player turns select the relevant HUD slot; enemy turns choose a random living player and apply random 8–14 damage, then Invoke the next turn after 0.5 seconds.

Buttons:

- Attack deals fixed 10 to the selected enemy and advances.
- Defend sets `isDefending` and advances.
- Flee clears combat and re-enables field input.
- Start Combat manually rebuilds/starts.

The archetype scripts intend multiple enemy actions, direct/sweeping attacks, buffs, poison, charm, possession, stun, and decoy, but most special effects are comments/placeholders.

### Title and save UI

The UI Toolkit title contains panels for:

- main menu;
- options;
- new-game character selection;
- level-select character selection;
- level selection.

Buttons target Bil/Aisha/Gerald, basic room, or boss scene. Continue is TODO. Fullscreen toggles in `DataManager`.

DataManager uses BinaryFormatter on `user` persistent `save.dat` with one fullscreen boolean. It initializes defaults, reads on Start, and applies fullscreen. A private save method exists but the title toggle does not call it.

### Definite compile/control-flow problems

Static inspection found multiple high-confidence blockers:

- `GameManager.cs` imports `UnityEditor.SearchService` from runtime code, which is unsuitable for player builds.
- It unsubscribes `SceneManager.Sceneloaded`, but the event is `sceneLoaded`; this spelling/case is a compile error.
- `SceneTransition.SelectScene` treats a valid scene as invalid and replaces it with `scn_title` because its validity condition is reversed.
- GameManager calls synchronous `LoadScene` before subscribing to `sceneLoaded`, so even without the typo it can miss the event.
- The initial title call uses `SwitchPanel("title-menu")`, but the switch case is `title-press-menu`; the intended panel setup does nothing.
- BinaryFormatter is obsolete/unsafe, save writes are non-atomic/unversioned, and normal option changes are not saved.
- Interaction starts combat in `TriggerEncounter`, then spawns enemies, then calls StartCombat again. The first turn-order build occurs before enemies exist and two turn sequences can be scheduled.
- Both Party and GameManager have character-spawning responsibilities, creating duplicate-authority risk.
- Lambda subscriptions in movement are removed using new lambda instances, so handlers are not actually unsubscribed.
- `movement_manager.Instance` is never assigned.
- idle movement flips all sprites left because `facingRight` is false at zero.
- HUD enemy selection overwrites selected index before “previous” deselection, then deselects the newly selected target.
- Character UI refreshes every frame and Health also refreshes it, duplicating work.

### Enemy-data defects

- `Random.Range(0,1)` for integers returns only 0, so many advertised second actions are unreachable.
- `Random.Range(0,2)` targets only party slots 0 and 1, never slot 2.
- Alvar uses `Random.Range(0,3)` but includes a `choice == 3` branch, which is unreachable.
- Most enemy classes omit `curHP`, leaving it at zero despite `isAlive=true`.
- Several omit initiative, defaulting to zero.
- Many enemies incorrectly set `inParty=true`, confusing player/enemy turn handling.
- Several player PerformAction logs still say Bil Muri due copy/paste.
- Defend state is never consumed/reset by damage logic.

### Audio and asset concerns

`AudioPlayer` creates a private one-slot AudioSource array but does not populate it from the required AudioSource component in code; `sounds[0]` can remain null. It loops one example music clip and exposes one example SFX.

Assets include two music OGGs, one boss-laugh WAV, one game logo, one slime sprite, Cochin font, Unity/TMP assets, and prefabs/scenes. The boss laugh and music names overlap other archive material, but this repository provides no provenance mapping. Do not adopt them as Blade sources.

### What is worth preserving

- Fenny's title-panel/character/level-selection flow as a UX prototype.
- Editor-configurable encounter trigger categories.
- Party and enemy prefabs with one stat interface.
- Combined initiative list as a turn-order sketch.
- UI Toolkit/UXML separation as a cross-engine presentation reference.
- Team-integration history as a lesson in avoiding duplicate system owners.

Everything needs a clean-room, compile-tested rewrite before use. The current merged snapshot should not be treated as a runnable foundation.

## Local GameMaker mirrors

### `ai-gen-test`: one-shot historical Blade integration specimen

- Clean local `main` at `a5fc25af44afb2c76042aeca385c74d7979090fa`; its configured Blade origin and cached `origin/main` are stale. The commit is not present in the live public Blade repository.
- Fourteen commits from 2026-04-08 through 2026-04-10 document player renaming, GMTL, 2D/3D composition, title/settings/audio/CRT work, procedural stage families, and JSON dialogue authoring.
- Compared with `/Users/magicalfeyfenny/GameMakerProjects/blade-of-desires`, all 223 shared GML files are semantically identical after newline normalization. The archive adds only `blade-of-desires.resource_order` and a historical Igor log.
- Its selected graph has 215 resources: 115 sprites, 18 sounds, six fonts, 42 objects, 26 scripts, three shaders, four rooms, and one timeline, plus five dialogue JSON and four model/geometry files.
- Relative to the vertical-shmup template, it adds the 3D world/camera/shader/model path, three ship/four difficulty profiles, active scripted stage schedule, Blade-specific tests, procedural textures, and dialogue builder.

Use `a5fc25a` for historical code/provenance and feasibility/defect questions only. It was generated as a one-shot interpretation of the GDD, so its tuning, schedule, roles, and data model are not independent product authority. Use the GDD, current decisions, cleaner templates, and current repository policy when adapting behavior. Its GameMakerProjects sibling is a converted archive, not a separate gameplay iteration.

### `neuro-jam-2`: committed gameplay versus conversion worktree

- Public/local `main` at `7bd215bc3981b4cb340ebcb992d10049032d1db1` is the committed authority.
- The worktree has 109 tracked metadata files changed plus untracked Reddit options; no GML is edited. The changes are GameMaker schema/serialization conversion and must not be mistaken for gameplay evolution.
- All 472 GML files shared with the local pack are equal after newline normalization. The public checkout retains the source files needed by referenced sprites and has the stronger provenance README.
- The pack is a cleaned, newer-schema subset with identical gameplay. Prefer public HEAD for original source authority and the pack only when intentionally studying its conversion.

The detailed platformer, drone, Input, checkpoint, and API findings are in [Action, top-down, platformer, and AI](gamemaker-action-topdown-ai.md) and [Dialogue, cutscene, menu, save, and input](gamemaker-dialogue-save-input.md).

### `thpj3`: original jam authority versus repaired pack

- The actual project root is `/Users/magicalfeyfenny/GitHub/thpj3/thpj3`.
- Clean project source at public `master` commit `4545a9a95e597c6bd0f718596aea0b8f84357269`; only a repository-root `.DS_Store` is untracked.
- All 189 GML files and all media match top-level `/Users/magicalfeyfenny/GameMakerProjects/thpj3` exactly. Their differences are GameMaker metadata schema/options.
- The genericized pack changes 36 shared GML files, replaces Wriggle-specific player resources and six-line TXT dialogue with JSON/shared runtime, and removes malformed duplicate metadata.

Use public Git for the original game's content and provenance. Use the pack/vertical template for repaired reusable systems and tests.

### `tyvnj2`: deliberately incomplete VN extraction

- Current `master` at `dbaa721185aa8562534f51a8ee85f8594e934123` follows initial full-game commit `7996066` and content-removal commit `fc3e14c`.
- The configured live repository is not publicly resolvable; remote relationships are cached-only.
- Current worktree differences are Finder/metadata/newline noise plus a duplicate untracked YYP.
- Current selected source still references four removed backgrounds, seven removed portraits, and six removed chapter timelines. It is statically incomplete and likely does not compile.
- Its unique 432-line original `scr_menu_draw` is valuable recovery evidence: the pack version is empty and the dialogue-template rewrite is only 196 lines.

Use initial `7996066` for original content, the pack/template for the migrated runtime, and current `dbaa721` only to recover deliberately isolated engine fragments.
