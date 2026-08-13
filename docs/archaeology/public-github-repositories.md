# Public GitHub Repositories

Snapshot: 2026-08-10/11, using GitHub's public repository and comparison APIs.

## Portfolio inventory

| Repository | Relationship | State | Primary language | Default | Declared license |
|---|---|---|---|---|---|
| [aerial_robotics](https://github.com/magicalfeyfenny/aerial_robotics) | Fork with substantive ahead commits | Archived | Python | `master` | None at fork root |
| [bittorrent-simulation](https://github.com/magicalfeyfenny/bittorrent-simulation) | Owned | Archived | Python | `main` | None |
| [blade-of-desires](https://github.com/magicalfeyfenny/blade-of-desires) | Owned | Active | GML | `dev` | None |
| [COVID-19](https://github.com/magicalfeyfenny/COVID-19) | Fork, default branch identical to upstream | Archived | Jupyter | `master` | None reported by API |
| [dash-to-dock](https://github.com/magicalfeyfenny/dash-to-dock) | Fork, identical to upstream | Active fork | JavaScript | `master` | GPL-2.0 |
| [game-recommender](https://github.com/magicalfeyfenny/game-recommender) | Owned | Archived | Python | `main` | None |
| [gm-ai-workflow-template](https://github.com/magicalfeyfenny/gm-ai-workflow-template) | Owned | Active | Python | `dev` | None |
| [Neuro-Gamemaker-SDK](https://github.com/magicalfeyfenny/Neuro-Gamemaker-SDK) | Fork | Active fork | GML | `main` | MIT |
| [neuro-jam-2](https://github.com/magicalfeyfenny/neuro-jam-2) | Owned | Archived | GML | `main` | None |
| [selkies-moon](https://github.com/magicalfeyfenny/selkies-moon) | Owned | Archived | GML | `main` | None |
| [thfgj11](https://github.com/magicalfeyfenny/thfgj11) | Owned | Archived | GML | `main` | None |
| [thfgj7](https://github.com/magicalfeyfenny/thfgj7) | Owned | Archived | GML | `master` | None |
| [thpj3](https://github.com/magicalfeyfenny/thpj3) | Owned | Archived | GML | `master` | None |
| [thpj4](https://github.com/magicalfeyfenny/thpj4) | Owned | Archived | GML | `master` | None |
| [thpj5](https://github.com/magicalfeyfenny/thpj5) | Owned | Archived | GML | `master` | None |
| [thsj2022](https://github.com/magicalfeyfenny/thsj2022) | Owned | Archived | GML | `master` | None |

Public visibility is not a reuse license. Repositories without a declared license should be treated as all-rights-reserved outside the owner's own authorized use; third-party/fork content remains governed by upstream terms.

## Fork provenance

| Fork | Parent | Current default-branch comparison |
|---|---|---|
| `aerial_robotics` | `robowork/aerial_robotics` | 25 commits ahead, 0 behind; adds the autonomy package and changes README |
| `COVID-19` | `CSSEGISandData/COVID-19` | Identical, 0 ahead/0 behind |
| `dash-to-dock` | `micheleg/dash-to-dock` | Identical, 0 ahead/0 behind |
| `Neuro-Gamemaker-SDK` | `noellepunk/Neuro-Gamemaker-SDK` | 0 ahead, 2 behind; Fenny's ExampleProject fix was merged upstream and then propagated into the source package |

Do not count identical forks as authored portfolio systems. They can still be dependency/provenance references.

## `aerial_robotics`

### Authored delta

The fork preserves the upstream MiniHawk ROS/Gazebo/MAVROS stack and adds `robowork_minihawk_autonomy`:

- `CMakeLists.txt` and `package.xml`;
- `launch/auto_arm.launch`;
- `launch/sim_auto.launch`;
- `scripts/auto_arm_node.py` (~363 lines);
- `scripts/sitl_wrapper.py` (~121 lines);
- README instructions and preserved upstream README.

### Mission state sequence

`AutoArmNode.run()` performs:

1. fixed startup delay;
2. wait for flight-controller connection;
3. wait for mission waypoints;
4. request/confirm AUTO;
5. arm;
6. search for a target AprilTag;
7. request/confirm QLOITER;
8. center over the tag with RC override;
9. request/confirm QLAND;
10. release RC override.

The node normalizes a robot namespace, constructs MAVROS names, subscribes to state/waypoints/tag detections, proxies mode/arming services, and publishes 18-channel override messages. Tag offsets are normalized by depth; roll/pitch commands are proportional, rounded, and clamped `1300..1700` around neutral 1500.

`SitlWrapper` validates configured ArduPilot paths, launches `sim_vehicle.py` in its own process group, waits for exit, and on ROS shutdown escalates from SIGINT to SIGTERM after ten seconds.

### Strengths

- Clear high-level sequence with positive state confirmation.
- Namespace and topic construction isolated from mission logic.
- Simulator child process has explicit cleanup escalation.
- Sensor observation, service commands, and actuator override are distinct channels.
- Gains/tolerance/tag ID/rate are launch parameters.

### Static risks

- Most wait loops have no operational timeout despite a `timeout` parameter used for service discovery.
- Tag detection time is stored but never used to reject stale detections.
- Landing is confirmed only by mode, not touchdown/disarm.
- The procedure relies on fixed sleeps and open-loop mode/RC behavior.
- Mode and arm services are requested every tick until state changes.
- There is no explicit mission abort/recovery state graph.
- `.DS_Store` and large duplicated visual/collision STL assets remain tracked.

### Cross-domain adaptation

The game-relevant lesson is not drone control code. It is a command/state architecture:

- issue command;
- observe authoritative state;
- retry under a bounded policy;
- transition only on confirmation;
- time out/fail to a safe state;
- release owned resources on shutdown.

That maps well to asynchronous loading, scene transitions, save operations, boss choreography, and external integrations.

## `bittorrent-simulation`

This is a compact localhost protocol simulation centered on one approximately 12 KB Python program plus requirements and a sample torrent.

### Mechanics

- Parses bencoded torrent metadata.
- Creates a tracker and 21 localhost TCP peers.
- Uses a simple five-byte message header for handshake/request/piece/choke-style messages.
- Simulates random packet drops.
- Tracks peer pieces and upload slots/choking.
- Performs pairwise transfer attempts and prints status.

### Useful ideas

- Explicit peer state and message types.
- Tracker/peer separation.
- Fault injection through packet drop.
- Upload-slot and choke vocabulary.
- A compact simulation loop suitable for seeded experiments.

### Static limits

- No actual piece payload or hash verification.
- No rarest-first scheduling.
- Tracker results are effectively ignored.
- TCP `recv` is not looped to guarantee a full frame.
- Ambient RNG has no seed/replay record.
- 20 upload slots among 21 peers makes choking nearly inert.
- Pairwise transfer is O(n²).
- Daemon threads and shutdown are simplistic.
- Requirements are far broader than the program needs.

Game adaptation: use it as an example of event simulation and fault injection. Do not reuse its network framing as production networking.

## `game-recommender`

This is an approximately 19 KB curses/psycopg application combining UI, controller, SQL, and domain logic in one file.

### User flow

- Search games.
- Rate selected results.
- View ratings.
- Request recommendations.

The PostgreSQL recommendation query computes weighted similarity from genres (2.5), platforms (1.5), publishers (1.25), developers (3), playtime divided by 60, and average rating multiplied by 3.

### Useful ideas

- Simple controller loop around search/rate/recommend states.
- Parameterized SQL rather than interpolated user values.
- Transparent, tunable feature weights.
- Terminal UI as a quick domain prototype.

### Static limits

- Hard-coded database user/name.
- README/code disagree on a `weights` versus `weight` name.
- Weak input and range validation.
- Recommendations are empty until ratings exist.
- Duplicate ratings/order behavior is unclear.
- Multi-table joins can multiply rows and distort sums/averages.
- Disliked games still add positive feature preference.
- Persistence, UI, SQL, and recommendation policy are one module.

Game adaptation: the transparent weighted-feature model could drive accessibility presets, content tagging, adaptive tutorial selection, or recommendation tooling, but should be decomposed and tested against join cardinality.

## `COVID-19`

The fork's default branch is currently byte-identical to upstream. It contains a large data-science corpus and a notebook workflow but no public fork-only delta at this snapshot, so authorship should not be inferred from presence.

The inspected notebook pipeline includes:

- state/day dataset preparation and differencing;
- lag-1 and lag-7 features;
- rolling 7/14-day features;
- chronological train/test split;
- last-observed, rolling, and state-mean baselines;
- 28-step lookback and seven-step horizon;
- GRU variants including raw direct prediction, residual prediction, and state-conditioned consistency;
- checkpoint selection by mean state MAE.

The upstream data footprint is multiple gigabytes. No game assets or runtime systems should be sourced from it.

The cross-domain value is methodological: establish simple baselines, preserve time ordering, compare variants under one metric, record feature derivation, and checkpoint against a declared validation target.

## `dash-to-dock`

The fork is identical to the GPL-2.0 upstream default branch and has no game-specific authored delta. It is a GNOME Shell extension, not an extraction source for Blade. Retain only as public-fork history.

## Active workflow repositories

### `gm-ai-workflow-template`

This is the source of the current repository's governance scaffold. It provides:

- `dev` integration and release-only `main` policy;
- issue-numbered branches and draft PR lifecycle;
- low/high risk paths and thresholds;
- human-created branch isolation;
- exact PR metadata/attestation checks;
- repository structure and asset validation;
- source/runtime/content directories and manifest policy;
- GitHub setup automation for labels, settings, and rulesets;
- unit tests for repository, PR, metadata, templates, and setup behavior.

The value is process architecture, not gameplay. Its `setup_github.py` is designed to configure a generated repository idempotently, while CI checks structure, assets, PR contract, and metadata freshness.

### `blade-of-desires`

The public active repository's default `dev` at publication is `6b938aa8c4ad9972b8195d58657cca71ba497918`. It contains the governed workflow scaffold, the small GameMaker 2026.0.0.16 GMTL v1.2 demo graph imported by PR #1, and the integrity boundary merged by PR #3. The graph has one font, one sprite, three demo objects, two rooms, and fourteen library/demo scripts. It is a testing dependency foothold, not extracted Blade gameplay.

The current default branch locks an exact 20-root/47-file read-only GMTL import with fail-closed validation. The lock does not supply the missing retained upstream notice or repair known matcher defects. The large archaeology archive documented here is planning input, not already extracted game code.

## GameMaker public repositories

### Public authority snapshot

| Repository | Snapshot commit | Public role | Preferred reuse authority |
|---|---|---|---|
| `Neuro-Gamemaker-SDK` | `32b2f4da1134d99e7195da96d1f96a437bd4a27b` | MIT fork containing Fenny's protocol fix in ExampleProject | Current upstream after its two follow-up commits |
| `neuro-jam-2` | `7bd215bc3981b4cb340ebcb992d10049032d1db1` | Original `Signals in the Wind` source/provenance | Public HEAD for game; upstream Input release if adopting Input |
| `selkies-moon` | `cd1f35e35dd8f6b1c36d3df8f4b75006f27e1ca6` | Archived public project history/LFS corpus | Exact selected local graph/docs for characterization, not loose public artifacts |
| `thfgj11` | `03d0274692678107b3d120a33cd8fda7373753b9` | Original `Eirin's Hourai Elixir Hunt` identity | Same implementation as local Double Jammy; count once |
| `thfgj7` | `f15f6431a243184b079609b62ff1077b82700921` | Original `youmu-shoots-a-strange-bird` identity | Same implementation as local THJ7 except README |
| `thpj3` | `4545a9a95e597c6bd0f718596aea0b8f84357269` | Original `Wriggle's Unwriggleable Night` source | Public for jam/provenance; local pack/template for repairs |
| `thpj4` | `018ab442a9523dc8e204b993c318f58d7656c8c2` | Original `Sunflowers in the Rain` source | Public for identity; local pack for generic/JSON evolution |
| `thpj5` | `2b8beb02282430672b81a404e03b371d6cdcd4fd` | Original `Koishi's Lovey-Dovey Couple's Therapy` source | Public for original content/menu; dialogue template for runtime foundation |
| `thsj2022` | `95dc2d3316c5b67d899ae6e3c82b1ee5db6cf819` | Original `Cirno's Yukkuri-Wranglin' Hoedown` source | Public for identity; action pack/template for maintained migration |

Eight game repositories are archived; the SDK fork remains active. Their public visibility establishes provenance/history, not a general reuse license; only the SDK reports MIT through the repository API.

### Neuro GameMaker SDK fork

Fenny's fork contains one authored commit, `32b2f4d`, whose message records two protocol fixes:

- send WebSocket buffers through `network_send_raw(..., network_send_text)` rather than the prior raw framing;
- parse incoming action `data` as JSON and select its `move` field;
- add JSON-schema `type: "object"` to the ExampleProject action;
- update the ExampleProject IDE metadata.

That commit changes only `ExampleProject`: its API object and seven send helpers. It does not update the reusable `NeuroGameAPI` source package. Upstream then merged the fix and made a second commit propagating the equivalent changes into `NeuroGameAPI`. The fork is therefore now two commits behind upstream and should not be selected as the dependency source.

The local Neuro Jam 2 copy contains a separate, partially copied API plugin with numerous lifecycle/protocol defects and no room placement. Do not infer that the public SDK fork validates that dormant integration. If a future issue needs Neuro integration, select a current upstream protocol/release, retain MIT notice, lock it, and test socket/buffer/action lifecycle independently.

### Neuro Jam 2

The public README identifies `Signals in the Wind`, a side-scrolling puzzle platformer where a friendly drone helps the player. Public `main` is the original provenance and canonical committed public-graph authority; the local pack is a newer-schema conversion/reference.

Compared with the local pack:

- all 472 shared GML files are equal after newline normalization;
- the pack is a cleaned/newer-schema subset, not a gameplay fork;
- the public graph retains source files for referenced sprite resources and a specific jam/build README;
- the dirty local Git worktree changes only metadata serialization, not GML.

The full player/drone states, 19,200-pixel level, interactions, checkpoints, Input 8.0.3 host, dialogue, save risks, and dormant API are in [the action/AI report](gamemaker-action-topdown-ai.md) and [the dialogue/input report](gamemaker-dialogue-save-input.md).

### Selkies Moon

The public repository is the archived history of the largest GameMaker project in the corpus. Its API-reported size exceeds one gigabyte because the project includes large asset/LFS history. Do not use GitHub's repository-size number as the selected runtime graph size.

Deep mechanics were bound to the exact local selected graph and current repository documents rather than assuming public `main` equals that working branch. [The Selkies report](selkies-moon-reference.md) covers its stage director, boss descriptors, damage/bullets, practice, persistence, audio, story, asset authority, tests, and documented RNG gap.

### THFGJ11 and Double Jammy

Public THFGJ11 and local `double-jammy` have byte-identical selected implementation and payload. The public repository supplies the original title/history; the local pack is a duplicate, not another iteration.

The game is a 60-second archery target score attack with charge, stored shots, volley release, 79 timeline moments, and five paths. Its valuable idea is a charge/store/release weapon transaction. XOR and timeline index/position errors mean the implementation needs characterization and rewrite. Details are in [the action/AI family report](gamemaker-action-topdown-ai.md).

### THFGJ7 and THJ7

Public THFGJ7 and local THJ7 are implementation-identical; the meaningful difference is README/provenance. The two-act loop first builds score, then changes into a restraint/survival phase. Explicit tuning macros are useful, while incomplete/debug states and global mode coupling are not.

Use the public repository to name the original game and jam context; count the code once.

### THPJ3

Public `master` is the exact original jam authority. Ignoring platform-option metadata and Finder noise, all 189 GML files and all media match top-level `/Users/magicalfeyfenny/GameMakerProjects/thpj3`.

The local pack/template is a real later evolution: player resources are genericized, malformed duplicate metadata is removed, six-line TXT dialogue becomes the shared JSON runtime, dialogue cleanup is added, and the vertical-named template repairs score loading/adds tests. Gameplay remains side-scrolling despite that template name.

The original README/provenance and fan-game identity belong to public Git; reusable focus/options/hyper/emitter/boss behavior should be characterized from the pack/template lineage. See [the shmup report](gamemaker-shmup-stage-boss.md).

### THPJ4 and Sunflowers in the Rain

Public THPJ4 is the direct original counterpart to the local Sunflowers pack:

- public has 179 GML files/2,175 lines; local has 180/2,917;
- 173 relative GML paths are shared: 155 byte-identical and 18 changed;
- six public Wriggle/butterfly event files map exactly after resource/path renames to local Guardian/familiar files;
- the local seventh-only GML file is dialogue Destroy cleanup;
- the 18 changed files are dialogue/UI and timeline calls for TXT-to-JSON migration, not core combat changes;
- 225 same-path PNGs are exact;
- 30 public themed paths and 30 local renamed paths carry byte-identical images;
- all 11 WAV and four MP3 payloads are exact;
- public has 11 TXT dialogue files while local has 11 JSON files.

Public is the original identity/content/provenance authority; the local pack is the evolved generic/JSON code authority. The rename is incomplete—Marisa/Yuuka and themed material remain—so neither is original Blade asset authority. World, weapons, enemies, gates, and bosses are detailed in [the action/AI report](gamemaker-action-topdown-ai.md).

### THPJ5

Public THPJ5 preserves the full original visual novel and a uniquely important 432-line `scr_menu_draw` implementation for title, files, erase, options, gallery, and music room. The local dialogue pack migrates the story to the shared JSON runtime but accidentally contains a zero-byte copy of that renderer. The cleaned dialogue template supplies a shorter 196-line repaired renderer and safer file loading.

Use public history/content to understand the 201-frame content corpus (200 routed chapter frames plus one test frame) and complete menu intent; use the template as the runtime/persistence foundation; retain the public 432-line renderer only as recovery/UX reference. The current local `tyvnj2@dbaa721` is deliberately incomplete after content removal and still references 17 absent resources. [The dialogue report](gamemaker-dialogue-save-input.md) separates all of these authorities.

### THSJ2022

Public THSJ2022 is the original Cirno/Yukkuri jam identity. After mapping the player rename, its gameplay matches the local action pack; the pack's material change is adoption of the shared JSON dialogue runtime and cleanup. The action-boss template then keeps 66 of 68 production GML files byte-identical while hardening options/particles and adding script tests.

The actual game is a 60-second lasso/crowd score attack, not a reusable boss-rush framework. Preserve public provenance, select the maintained template only for its specific source-level repairs, and rewrite the capture state transaction under current architecture.

### Common hosted-repository rules

- archived public repos may preserve a more coherent canonical graph than a local conversion;
- later packs/templates often repair dialogue, menu, persistence, or metadata;
- a unique public implementation should be mined deliberately rather than replaced by name-based assumptions;
- none of the unlicensed game repositories grants third-party reuse merely by being public.
