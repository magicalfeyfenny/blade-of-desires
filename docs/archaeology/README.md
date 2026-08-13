# Project Archaeology Index

This archive characterizes the reusable systems, assets, experiments, and design material found in four source corpora:

- `/Users/magicalfeyfenny/GameMakerProjects/`
- `/Users/magicalfeyfenny/GitHub/`
- `/Users/magicalfeyfenny/Documents/My Creations/gamedev/`
- the public repositories owned or forked by `magicalfeyfenny` on GitHub

The source corpora were treated as read-only. The reports are characterization and planning evidence, not permission to copy third-party or Touhou-derived material and not proof that an archived project currently builds or runs.

## Start here

- [Corpus map and method](corpus-map-and-method.md) — scope, confidence labels, inventory, lineage map, and generated-output boundaries.
- [Cross-corpus system blueprint](system-blueprint.md) — the recommended combination of the strongest ideas into a coherent Blade architecture.
- [Extraction matrix](extraction-matrix.md) — ranked candidates, preferred source, required repairs, dependencies, ownership concerns, and proposed characterization tests.

## GameMaker families

- [Shmup, stage, boss, and scoring family](gamemaker-shmup-stage-boss.md) — TMoLaD, GMC Jam 3/7, THPJ3, the archived Blade slice, Faraii prototypes, vertical templates, bullets, rank, hyper, stage schedules, and bosses.
- [Action, top-down, platformer, and AI family](gamemaker-action-topdown-ai.md) — THSJ2022, Sunflowers, Neuro Jam 2, Ludum Dare projects, Twinblade, prototypes, encounter gates, movement, hazards, enemies, and camera transforms.
- [Dialogue, cutscene, menu, save, and input family](gamemaker-dialogue-save-input.md) — THPJ5, the converged JSON dialogue runtime, legacy formats, title/menu state machines, persistence experiments, pausing, and Input 8.0.3.
- [3D, rendering, libraries, and testing family](gamemaker-3d-libraries-testing.md) — Blade 3D lineage, model loaders, billboards, two-pass rendering, the Fenny GML library, GMTL, template tooling, and static test evidence.
- [Assets, prototypes, and design residue](gamemaker-assets-prototypes.md) — asset families, runtime/source authority, orphan resources, catalogs, empty projects, caches, outputs, and what should remain historical reference only.
- [Selkies Moon reference architecture](selkies-moon-reference.md) — the mature systems already present in the largest GameMaker project and the parts that should be treated as a culmination rather than reimplemented from older jams.

## Expanded local and hosted corpora

- [Local GitHub workspace](local-github-workspace.md) — GameMaker mirrors, the current workflow scaffold and GMTL v1.2 demo import, ShaleGame, the Canned Pears Unity prototype, dirty-worktree qualifications, and local/public duplication.
- [ShaleGame reference architecture](shalegame-reference.md) — Godot/C# state composition, clone/merge, triggers, combat components, bosses, cutscene suspension, audio priority, testing, and clean-room adaptation candidates.
- [Game-development creation archive](gamedev-creation-archive.md) — design documents, Escape Velocity preproduction, Blade and Faewind design history, sketches, 3D fixtures, audio, story formats, and the scanned RTS concept sheet.
- [Public GitHub repositories](public-github-repositories.md) — all public repositories, fork provenance, archive state, systems, substantive authored deltas, and non-game research projects.

## Reading the reports

Across the reports, claims are interpreted through four evidence categories:

- **Observed** — read directly from source, metadata, content, or an asset.
- **Static inference** — the likely behavior or failure mode implied by source; not a runtime claim.
- **Historical evidence** — a stored log, generated artifact, or prior build fingerprint; never treated as fresh validation.
- **Adaptation** — a proposed design for this repository, not an extracted implementation.

Source-authority paths are absolute or relative to the corpus root named by that report; links within this report directory are relative. “Prefer” means “best archaeological starting point,” not “copy wholesale.” Imported dependencies, third-party work, fan-game assets, and team repositories still require provenance and license review before reuse.
