# Game-Development Creation Archive

Source: `/Users/magicalfeyfenny/Documents/My Creations/gamedev/`

## Scope and method

This corpus contains design documents, preproduction, photo references, sketches, story files, old GameMaker scenario data, 3D fixtures, source-art packages, and audio rather than one coherent buildable project.

Observed inventory:

- 327 filesystem entries: 260 regular files and 67 directories;
- 232,113,509 logical bytes (`du -sh` reports 222 MiB at the hydrated audit snapshot);
- 80 files under `Escape Velocity`, 175 under `assets`, four under `design documents`, plus the root Finder metadata file;
- zero empty regular files in the stable hydrated corpus, and no regular file carried the `dataless` flag at the audit snapshot. Six package-style Pages directories and three top-level corpus directories still retain FileProvider/pinned extended attributes; those storage-management markers do not negate the confirmed local bytes.

Important extension families include 42 Audacity `.au` fragments, 28 WAV, 27 PNG, 23 JPEG, 18 JPG, 18 OGG, 15 TXT, 13 Krita `.kra`, 12 property lists, 10 Finder metadata files, 9 Audacity `.aup`, 6 ZIP, 6 extensionless Pages document identifiers, 5 `.aup3`, 4 HEIC, four D3D files, three Procreate files, three PSDs, three ICOs, three GIFs, and smaller sets of Pages, MP3, PDF, MTL, Blend, OBJ, and BMP files. Six additional Pages documents are package directories rather than single `.pages` files. No Logic, MIDI, FLAC, SVG, or VBUFF file is present.

All 260 stable regular files now have local bytes, and format-specific inspection succeeded for the families described below. macOS Quick Look rendered the complete visible bodies of all eight Pages documents as ordered per-page PDFs; text extraction and visual checks then retained meaningful order, status colors, and layout. Package metadata, embedded media, ZIP members, and supplementary IWA-string recovery provided cross-checks. This is still not a byte-perfect conversion of Pages internals. Representative images were visually inspected; audio was read for structure, format, and duration only. No authoring application was launched.

## Escape Velocity preproduction

This is the richest non-code design cluster in the archive. It includes:

- a concept/GDD Pages package;
- story and script Pages packages;
- an ideas document;
- character descriptions;
- a resource-list document;
- PSD and Procreate concept art;
- background and CG photo references;
- storyboard sketches;
- a mood-board screenshot and audio reference.

### Narrative concept

Content note: the design explores neglect, rejection, violence, sexual assault, suicide, and an abusive/dependent relationship.

The recovered outline describes a mature, dark visual novel centered on Cass and Ellie. An abandoned building becomes a recurring private location. Their relationship begins as connection between isolated schoolgirls, deepens into romance and rejection of social norms, then escalates through dependence, violence, separation, guilt, and attempts to intervene.

The concept includes metafictional act endings framed like podcast/cast wrap-ups and doll-like presentation. The story outline proposes a comfort/intervention ending; the separate ideas document later considers a comfort “true” ending versus a kill “bad” ending. That branch is an alternate design idea, not an established final direction. This is design history, not a recommendation that current Blade inherit its subject matter.

The useful system/design ideas are:

- act/chapter segmentation;
- strong viewpoint voice;
- repeated locations that change emotional meaning;
- visual-novel scene markup;
- per-act framing devices;
- explicit high-impact end-state choices;
- a resource checklist tied to scene production.

### Story and script material

Recovered story outline:

- two girls meet at school;
- the viewpoint character is gloomy/disaffected and perceived as delinquent;
- the other girl is shy and eccentric;
- intimacy grows around mutual alienation;
- separation and guilt lead to an attempt to save or intervene.

The outline body develops the relationship arc and a proposed ending in which Cass pursues and comforts Ellie before police approach; it outlines the first three Act I chapters while later acts remain much less developed.

The script package is a 17-page, roughly 4,175-word unfinished Act I draft spanning chapters 1–5, not merely a cover preview. It follows Cass from her morning routine and walk to school through a surreal encounter, meeting Ellie, lunch with friends, a friendship/assault-and-bullying flashback, a music-shop visit, and an unfinished re-encounter. It uses implementable production notation for backgrounds, CGs, SFX/BGM, cuts/fades, actor pose/expression/slide/clear, simultaneous lines, text placement/size, click/skip behavior, timed loops, and pipe-delimited sequential click/text beats. Quick Look rendering preserves the visible pages, but extracted text is not a source-format transcription and can interleave revision comments; this is evidence of authored content and authoring vocabulary rather than a publishable script edition.

The document set is chronological rather than one synchronized source: character brief (2024-07-15), GDD (2024-07-22), ideas and story (2024-08-23), resource ledger (2024-09-24), and the current script package (2026-01-30). Page references in the ledger still align with the visible 17-page script, but its status colors remain a historical snapshot. The ideas file explicitly marks Chel's contributions in purple and Fenny's in orange and asks collaborators to comment rather than overwrite; most visible ideas are Chel's, while the stolen-textbook/bedroom-visit and bunny-plush entries are Fenny's. Do not flatten this collaborative provenance into sole authorship.

### Character descriptions

The two principal design briefs describe:

- a 15/16-year-old short, stocky, gremlin/futch-presenting viewpoint girl with long dark hair, large round glasses, a brown duster, fingerless gloves, loose uniform, sneakers, disaffected temperament, and otaku interests;
- a 15/16-year-old taller, lithe, anxious girl with pink eyes, long hair, legwarmers, and clip-on bunny ears that visually communicate emotion;
- scarlet school uniforms and plaid skirts as shared school identity.

The emotive-ear idea is particularly useful as animation/UI design vocabulary: a readable secondary silhouette can communicate state without dialogue.

### Production checklist

The recovered resource list divides work into:

- backgrounds;
- CGs;
- sprites and expression variants;
- sprite effects;
- sound effects;
- status/color planning.

It inventories 11 backgrounds, five numbered CG concepts with variants, expression groups for Cass, Ellie, Kate, Riley, Timothy, and Camille, two parameterized sprite effects, and seven SFX slots. Locations include Cass's bedroom/ceiling, home hallway, street, school hall/classroom/cafeteria/exterior, a bowl-of-ramen scene, downtown, and the music shop. Green means production-ready, red needs detail/storyboarding, black means completed, and strikeout means discarded. First-script-appearance page references create a useful chain from scene draft to asset record and production status.

It references an old private Gitea location. That URL is provenance history, not a live dependency.

The nine-page GDD calls the project version 0.1 and “a visual novel by Studio TinyLeaf.” Its substantive overview specifies a single-player linear story from Cass's point of view; text over scene/character images; theoretical voice plus music/SFX; UI hiding; same-chapter backlog; normal and fast auto-read; autosave; many exact-point bookmarks; and progress flags that unlock chapter starts, scene replay, illustration gallery, and music gallery. Gameplay, UI, systems, tools/formats, challenges, and marketing sections remain blank placeholders. These are design requirements, not proof of implementation.

### Visual references

- `BG1` is a bedroom-ceiling photo with a ceiling fan and window. It is a location/light/composition reference, not finished runtime art.
- `BG3` is a pencil hallway/foyer storyboard showing the front door, side refrigerator/living room, shoes, and tile-to-carpet transition. It is useful for scene blocking and background-production planning.
- `CG1` is a staged mirror/self-grooming photo reference, not final illustration.
- the ideas package contains an original-looking staged stuffed-rabbit photo used to explore plush/doll pose and symbolic-CG staging; it remains reference material rather than runtime art.
- the mood-board image shows a visual-novel character over a fiery photographic background, demonstrating portrait/background/dialogue composition; it is third-party reference material.

The character document embeds eight full-size visual/text references and reduced derivatives; at least seven are clearly third-party imagery or published/reference material. The resource package's BG3 is byte-identical to the standalone storyboard, while its full-resolution BG1 and CG1 are near-lossless encodings of the standalone JPEGs. These duplicates establish one reference workflow, not additional independent masters.

### What to preserve

Preserve the preproduction method:

1. scene/act outline;
2. character silhouette and expression hooks;
3. recurring-location list;
4. resource checklist by scene;
5. storyboard/photo-reference stage;
6. final source/runtime asset production as a separate stage.

Do not place reference photos or mood-board imagery into runtime assets, and do not treat a PSD/Procreate file as provenance for every external image embedded in it.

## Historical Blade design document

The readable Blade GDD is a substantial design-history source. It describes:

- six main stages plus an extra stage;
- forest, river, desert, city, burning forest, ash, and extra city/facility environments;
- playable Maynii, Ciela, and Kolar;
- named bosses and story progression;
- a 3:4 playfield;
- focus movement and a small hitbox;
- enemies firing only when visible and with readable tells;
- multiple tiers of hit/explosion feedback;
- boss phases and timeouts;
- bombs and a three-tier hyper system;
- score, point value, rank, extends, continues, and endings;
- deterministic replay intent;
- 2D gameplay over 3D presentation;
- a magitek visual identity;
- audio and market/source-format planning.

This document records intent corresponding to many values and systems later visible in Selkies Moon. The archived Blade slice was a direct one-shot interpretation of this GDD, so similarity there is lineage, not independent corroboration. The GDD remains design vocabulary and product authority, not proof that either project implemented every system exactly as written.

### High-value design contracts

- **Movement and layering:** gameplay lives on a 3:4 plane, eight-direction movement normalizes diagonals by `sqrt(2)/2`, momentum changes instantly, and focus supplies the precision speed. The stated visual stack puts enemy bullets over hitbox, particles, point items, player, enemies, player shots, and 3D details. That is a useful rendering/collision contract even if the exact layer order later evolves.
- **Historical player identity:** the recovered GDD describes Maynii as spread/tracking, Ciela as motion-turning/short-range, and Kolar as straight/laser-or-bomb. It explicitly binds focus to speed and hitbox visibility while separately defining ship-specific shot/option behaviors; later implementations experiment with focus-sensitive formations. These older role notes are now superseded by the current product decision: Maynii is the tracking/forward all-rounder, Ciela is the spread attacker, and Kolar remains deliberately unresolved with melee only a candidate. Preserve finalized roles as data-owned loadouts rather than object subclasses; see the [system blueprint](system-blueprint.md#current-blade-product-decisions).
- **Enemy fairness:** enemies should not shoot before they are visible, should telegraph attacks, and should remain killable before the first volley when the encounter intends that reward. Popcorn, mook, elite, commander, and boss tiers define increasing time-to-kill, field control, cleanup, and explosion severity.
- **Boss phases:** human-scale bosses use readable shields/positions, phase-change poses and dead air; screen-scale bosses visibly lose parts. A timeout advances the phase, while the last timeout becomes a survival pressure pattern before surrender. This is a content contract, not yet evidence of a particular phase-data model.
- **Bomb and hyper policy:** bombs clear bullets and cover roughly five seconds of invulnerability. Hyper shares the activation button, has three tiers, darkens presentation, amplifies offense and scoring, can increase enemy intensity, clears/protects briefly on entry, and is cancelled by bombing. This explicitly makes hyper a risk/reward mode rather than a simple super weapon.
- **Deathbomb transaction:** a hit creates a short frozen response window. A bomb response consumes the full bomb stock for a powered bomb; available hyper instead produces tier three regardless of partial gauge. Failure commits the death, resets position/resources without power-down, and applies the score penalty.
- **Score economy:** point-item value compounds through collection; grazing creates small items and hyper; hits/kills and enemy tier contribute; hyper multiplies hits, kills, and cancels; bombs suppress drops and drain about 20% of bonus value; death drains about 50%; stage bonuses score survival, bomb restraint, graze, items, and final resources. These should become explicit reason-coded score events and tested formulas.
- **Difficulty and rank:** four respectful difficulty bands vary density, speed, and pattern availability. Rank increases with time and hyper up to a difficulty cap, increases bullets and point generation, and drops with bomb/death penalties. Difficulty profile and dynamic rank are separate axes.
- **Run outcomes:** continuing resets current score/point value and increments a run counter while retaining prior score segments for high-score consideration. A no-continue clear earns the canonical ending and difficulty-specific CG; any continue gives the alternate ending. The extra stage unlocks after any-difficulty 1CC and uses a fixed challenge near the third main difficulty.
- **High scores and replay:** a score entry retains name, score, ship, furthest progress, and continue count at capture time. No-continue clears may save a replay consisting of the run seed plus per-tick inputs/timing. That is strong intent, but it still requires an owned PRNG algorithm, stable tick contract, deterministic ordering, and state-hash verification to become a working replay system.

### Historical assumptions to replace

The document's historical tool chain names GameMaker, GarageBand, LMMS, Procreate, Krita, Blender, Audacity, and Model Creator; shared formats include PSD, OBJ/MTL, OGG, and WAV, while tool-specific formats include D3D/AUP/KRA/Procreate/Blend. It anticipated VBUFF plus JSON saves/scores/options/replays, a private Gitea host, a three-stage demo, itch-first distribution, and later storefront expansion. These are useful provenance clues, not current policy. Canonical structured data now belongs under `content/`, and current asset pipelines require role-specific editable/runtime formats plus `assets/exports.json`.

## Project Faewind

The recovered Faewind document specifies a vertical shmup:

- target one approximately 15-minute stage, with an aspirational five-stage/one-hour expansion;
- Unity/Linux as the original tool/platform idea;
- a new enemy or meaningful wave change every 15–30 seconds;
- roughly 10–20 unique standard enemy types and 20–25 boss patterns;
- high contrast and projectile readability;
- plot secondary to pacing;
- explicit avoidance of dead air.

It further requires a hook beyond competent shooting, a difficulty near Touhou that the team can playtest internally, no more than one repeat of any attack pattern across the stage (at most two occurrences), and a five-minute stage-mechanics/ten-minute boss-mechanics budget. Its encounter vocabulary includes landscape structures, popcorn, fighters, bombers, a mechanically unusual midboss, and a plot-significant stage boss; silhouettes should communicate enemy tier. Automatic/skippable dialogue must not obstruct play. Scoring, themes, plot, and several enemy details remain explicit TODOs, so the document is a living generic brief rather than a finished design.

The most useful contribution is pacing discipline. Convert it into stage-content lint rules:

- every segment has a declared start/end and intensity;
- maximum unintentional quiet interval;
- each new enemy/pattern receives a readable introduction;
- boss phases declare pattern identity, duration, and escalation role;
- content review reports repeated or unused patterns.

The old Unity/Linux choice is not an architectural requirement for current Blade.

## Scanned RTS concept sheet

The PDF is one portrait-metadata page containing a sideways landscape scan of a handwritten “initial RTS” concept dated 2013-07-29. Visual inspection found:

- control towers that reveal dig locations;
- resource extraction by digging;
- tower influence radii and possible mobility;
- procedural island or grid-map ideas;
- land, flying, and naval unit categories;
- terrain-specific traversal;
- a starting hero, three miners, two troops, and an initial large/base tower per faction;
- tower-type spawning constraints, a slow movable/non-attacking base tower, and type-dependent hero bonuses;
- rough hero/archetype sketches.

The crossed-out handwritten revisions make exact multipliers, map dimensions, and the third unit-type label uncertain. This is a mechanic sketch, not an implemented system. Its useful abstractions are dig-site reveal sources, territory/influence radii, resource nodes, traversal channels, terrain generation, structure matchups, and hero auras. Those can inform encounter-map or overworld design, but no code should be inferred from the sheet.

## Legacy scenario and story data

The archive contains several textual content formats:

- THPJ3 six-line frames: five files and 54 records split 10/12/8/12/12;
- THPJ5 numeric 12-line frames: 201 total records, comprising 200 routed chapter frames and one test frame;
- THSJ seven-line frames: 11 records carrying active side, background ID, left/right emote-and-actor pairs, and text;
- a 35-line Neuro cutscene outline that specifies the drone's threat, approach, scan/recognition conversation, retargeting, and transition into follow behavior;
- the Escape Velocity screenplay-like markup.

These are useful as migration and validator fixtures. They demonstrate the need to retain speaker, text, display mode, actors/positions, background, music, sound, and story progress while converting to one canonical JSON schema.

Touhou and Neuro-themed content should not become original-IP Blade content. Use the formats and sequencing examples, not protected identities or unreviewed art.

## Two-dimensional art and asset studies

### Hydrated editable-source map

| Family | Editable/source evidence | Derived or reference evidence | Interpretation |
|---|---|---|---|
| Escape Velocity | Three Procreate archives and three layered PSD counterparts | Three storyboard/reference JPEGs, Pages-embedded photos, mood-board PNG | The Procreate files retain 3 paint/top-level layers plus background, thumbnails, tile data, and timelapse segments. The PSDs retain corresponding background plus three named/content layers rather than being flattened. Bunny/POV canvases are `1640x2360`; Cass/Ellie stores `2032x1728` with orientation 4 and renders/exports portrait as `1728x2032`. Visual/composite comparison strongly pairs each PSD with its Procreate document (`girls_height_comparison.psd` corresponds to Cass/Ellie), but no explicit export manifest proves the operation. Procreate is the richer candidate authority, its author fields are blank, and references remain separate. |
| THPJ5 | Eight `1280x720` Krita 4.2.9 files with 3–6 layers | Seven `1280x720` PNGs and six numeric scenario files | Chireiden/Moriya/Office PNGs are pixel-identical to merged KRA output; portraits/logo/title are alpha-export variants of opaque merged art; Utsuho lacks a PNG. KRA creator fields attribute Jennifer Hogueison, which is provenance evidence rather than a license grant; license fields are empty. |
| THSJ archive | Three Krita files with matching PNG names | `1280x1280` arena, two `640x360` screens, icon, five OGG exports | The archive directory is literally named `thsj2020-assets` while the related project lineage is named THSJ2022. Preserve that naming discrepancy as provenance instead of silently rewriting history. |
| THJ11 | Two `640x360` Krita files | Matching title/end PNGs, a `64x64` icon in BMP/PNG/ICO forms | This is the cleanest name-aligned raster source/export pair in the hydrated archive, though it is still themed fan-game work and has no license manifest. |
| THPJ3 | No editable raster master found | Three `498x298` GIF previews, `64x64` icon, 15 WAV cues, five scenario files | Useful release-history and cue-taxonomy evidence; weak source-authority evidence for direct asset import. |
| Neuro Jam 2 | No editable art/audio master found | Nine PNGs, 13 WAVs, four OGGs, one cutscene outline | Strong production-reference cluster, but runtime/reference files alone do not satisfy current source ownership. |

All 13 Krita files are readable ZIP-based documents with valid canvas metadata; layer counts range from two to seven. The three Procreate files likewise expose document metadata and Quick Look thumbnails without launching Procreate. No `LICENSE`, `COPYING`, `NOTICE`, credits manifest, or source/export manifest was found anywhere in this creation archive, so file authorship and reuse permission remain a separate review.

The root `assets/leaf.png` is a `64x64` RGBA leaf mark byte-identical to both registered image layers of local `tyvnj2/sprites/spr_logo`; that project's logo/ending objects draw it and its options identify Studio TinyLeaf. This is useful brand/provenance linkage across the archive, not reusable Blade authority without an editable source and explicit permission.

### THPJ5

Representative readable assets are `1280x720`. A Koishi portrait is hand-drawn on transparency; a Chireiden background is a hand-drawn checkered neon hall. They support:

- full-screen portrait staging;
- transparent character art over fixed backgrounds;
- expressive color separation;
- portrait-over-background staging inside a 16:9 composition. Dialogue-UI placement evidence comes from the corresponding GameMaker runtime, not these bare images.

They remain Touhou fan-game art and need provenance/rights review.

### Neuro

A representative `2560x1600` transparent canvas contains a comparatively small, sparse purple ruined-city pixel silhouette. It is useful as a palette/parallax concept, not evidence of a finished full-canvas production scene. A `214x153` title-composition image is duplicated byte-for-byte under two filenames; another `80x40` image is only “no data” text.

### THJ11

The inspected title is a hand-drawn `640x360` “Eirin’s Hourai Elixir Hunt” composition. It is historical title-layout and lettering reference.

### THSJ and THPJ3

The THSJ folder contains three matched KRA/PNG arena/title/victory studies, an icon, five AUP3/OGG pairs, and one scenario file. The THPJ3 folder contains an icon, three gameplay-preview GIFs, 15 WAV cues, and five scenarios, but no editable raster master. The previews can evidence presentation in context; they are not separable portrait/cursor/bullet/effect masters. Every candidate still needs provenance and an export-manifest relationship before adoption.

## Three-dimensional fixtures

Readable legacy D3D files include:

- a centered 64-unit billboard;
- a 64-unit wall/cube;
- a standing `64x128` billboard;
- a 32-unit skybox cube with atlas UVs.

The centered billboard is two triangles/six listed vertices and four unique vertex tuples. The standing billboard duplicates one quad exactly—12 listed vertices/four triangles but still only four unique tuples—making it a useful de-duplication regression fixture, not geometry to reproduce. Wall and skybox each contain 36 vertex records/12 triangles; the skybox uses a cross-atlas UV layout. The Blender file is a Blender 3.0.1 default-cube project. Its OBJ has eight positions, 14 UV coordinates, six normals, and six quad faces; its one-material MTL records diffuse/specular/alpha values but no texture map.

The OBJ and MTL are byte-identical across the 3D templates, the converted GameMakerProjects Blade copy, and canonical `ai-gen-test@a5fc25a`. The creation-archive skybox and wall D3D files match the 3D templates and converted GameMakerProjects copy, but not canonical `ai-gen-test`; they are template-era fixtures, not exact authority for that one-shot repository snapshot. The `256x256` skybox texture is likewise pixel-identical to the 3D template era but differs from the later generated archived-Blade texture. The two billboard files have no same-named reference in the inspected code corpora, so they are standalone fixtures rather than proven production assets.

Use these as parser/converter fixtures:

- known triangle/quad count;
- known bounds and orientation;
- UV atlas expectations;
- billboard pivot/origin cases;
- OBJ/MTL-to-VBUFF golden output.

Do not retain D3D as a production runtime source. Current policy expects `.blend` source, retained `.obj`/`.mtl` export sources, and `.vbuff` runtime.

## Audio inventory and format findings

There are 47 playable audio files: 28 WAV, 18 OGG, and one MP3. Nine AUP projects, five AUP3 projects, and 42 AU blocks add 56 editable/support files, for 103 audio-related files total.

### THPJ3

- 15 WAV files;
- stereo 44.1 kHz, 16-bit integer;
- durations 0.162540–3.173039 seconds.

These are compact projectile, hit, graze, death, bomb, and UI cues. Only `snd_boss_laugh.wav` exposes a creator tag (Jennifer Hogueison); the other 14 carry no readable creator/license attribution, so that one tag cannot be generalized.

### THSJ2022

- five stereo 44.1 kHz OGG files;
- music 45.731701 and 52.070748 seconds;
- SFX 0.905578–1.555737 seconds.

The five `.aup3` files are SQLite-backed editable Audacity projects. Static database evidence matches their stored sample lengths to the paired OGGs within sub-microsecond rounding. They still do not match the current Logic-based source policy.

### Neuro

- 13 WAV and four OGG files;
- stereo 192 kHz legacy audio media with no editable audio project found here;
- music roughly 19.2, 20.2, 38.4, and 54.9 seconds;
- SFX/ambience roughly 1.7–6.87 seconds.

The four music files identify FL Studio as encoder but provide no title/artist/comment, and no FL Studio project is present. The similarly named cancel and hurt/death variants are distinct PCM, not duplicate copies. Locate or recreate editable sources, then produce the repository's 48 kHz stereo runtime formats rather than copying these files as-is.

### THJ11

- OGG runtime files, stereo 44.1 kHz;
- music about 70.39 seconds;
- SFX roughly 0.27–1.39 seconds;
- nine Audacity `.aup` projects and 42 `_data/*.au` fragments. Eight effects use two blocks apiece; the approximately 70-second music project uses 26.

Each AUP references a complete, non-orphaned block set and its sample count matches the paired OGG duration. Both AUP tags and OGG metadata identify `magicalfeyfenny`, which is useful creator-provenance evidence but not an explicit license. These files still do not satisfy the current role-specific Logic source/runtime policy: music requires MIDI plus Logic source to 48 kHz stereo FLAC, while sound effects require Logic source to 48 kHz stereo WAV.

### Escape mood board

The approximately 172.6-second 44.1 kHz stereo MP3 is a reference track whose embedded metadata credits external authors (`szak`, `ryo`, and `H.B STUDIO`). It is not production music authority.

## Source/runtime asset decisions

For any candidate asset:

1. Identify creator and license/permission.
2. Identify the actual editable source (`.kra`, `.blend`, `.logicx`, `.mid`, `.svg`).
3. Decide whether the asset is original-IP compatible.
4. Produce the required runtime format.
5. Record the source-to-runtime mapping in `assets/exports.json`.
6. Add format, dimension/rate/channel, and reproducibility checks.

Reference photos, mood boards, formerly cloud-hosted copies, generated caches, and old runtime exports should never silently become source masters.

## Best extraction candidates from this corpus

| Candidate | Preserve | Do not preserve |
|---|---|---|
| Blade GDD | stage vocabulary, ships, phase/timeout, rank/hyper, deterministic intent, 2D-on-3D | obsolete tool/store/file assumptions |
| Faewind | wave cadence, pattern budget, readability, no-dead-air rule | old engine choice as mandate |
| Escape preproduction | scene/resource checklist, recurring locations, storyboard/reference workflow, expressive silhouette accessories | unreviewed reference imagery or subject matter by default |
| Legacy story files | conversion fixtures and schema coverage | parallel canonical formats |
| RTS sheet | reveal/influence/resource/traversal concepts | claims of implemented behavior |
| D3D/OBJ/Blend samples | parser and golden-conversion fixtures | D3D production pipeline |
| Audio clusters | cue taxonomy and provenance clues | 44.1/192 kHz runtime copies or Audacity fragments as current masters |
