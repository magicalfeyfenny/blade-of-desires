# Blade product contract

`content/product_contract.json` is the single canonical, machine-consumable
product contract and stable-ID registry for Blade of Desires. Runtime systems
must consume it rather than recreate IDs, geometry, ship identities, campaign
topology, or product requirements in code.

## Authority and provenance

Precedence is deliberately strict:

1. Current explicit Blade product decisions in
   [the system blueprint](archaeology/system-blueprint.md#current-blade-product-decisions).
2. The Blade GDD at
   `/Users/magicalfeyfenny/Documents/My Creations/gamedev/design documents/GDD - blade of desires.txt`
   where those decisions do not supersede it.
3. Archaeology and independent projects as implementation and pacing evidence.
4. The archived one-shot Blade slice only as a feasibility and defect specimen.

The archived slice does not establish product tuning, schedules, ship roles,
art, or a data model. The extraction rationale and issue ordering remain in
[the extraction matrix](archaeology/extraction-matrix.md#proposed-issue-sequence);
the GDD's named campaign route and encounters are transcribed as stable records
without importing its obsolete implementation commitments.

## ID and schema rules

Every canonical record has `schema_version`, `id`, and `display_name`. Stable
IDs match `^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$` and are globally unique
and never reused: a display-name change does not change an ID, and a retired ID
is not reassigned.

`schema_version` describes the shape and interpretation of a record. Removing
or renaming a field, changing its type, or incompatibly changing its meaning
requires a schema-version increment. Additive fields and content-value changes
retain the schema version and advance `content_version`, which versions this
product contract. Version 1.1.0 added structured policy while retaining all
1.0.0 fields and types. Version 1.2.0 added the ordered difficulty identity
registry. Version 1.3.0 records the concrete Maynii-Kolar Stage 1 midboss
resolution for the Ciela slice. Version 1.4.0 adds complete playable-route
records for Ciela and Maynii, including player/loadout identities and exact
unchosen-fae standard/combo mappings. Version 1.5.0 adds Kolar's complete
playable route, deterministic close/ranged loadout binding, and the
Ciela-Maynii River + Roots combo. None of these content changes alters an
existing record's shape, so the schema remains version 1. Consumers reject an
unknown schema version rather than guessing a default.

`registry_extensions` is a versioned policy object, not a canonical record.
Its ship, stage, and encounter ID lists are empty in the core contract. A later
registry-extension record must be explicitly declared in the matching list and
must advance `content_version` beyond the 1.5.0 core baseline; core IDs cannot
be redeclared. The progression record is closed, so an added ending or unknown
root field requires a future schema rule instead of silently extending the
registry.

Subordinate pattern catalogs are separate canonical data rather than
`registry_extensions`. They share this contract's authoritative ID grammar and
global definition-collision policy. Every pattern catalog binds the exact
product `id` and `content_version`; pattern validation checks that binding
against this file and rejects definition collisions against canonical product
record IDs as well as duplicate definitions across the loaded catalog set.
Successful validation produces a separately normalized pattern plan, not a
modified product-contract record.

Subordinate stage and encounter schedule catalogs follow the same composition
boundary. They bind this contract, share its global definition-collision
policy, and normalize into a separate stage plan. Version 1 schedule records
use `stage_schedule.*` and `encounter_schedule.*` identities and deliberately
do not redefine or infer mappings to this contract's campaign `stage.*` and
`encounter.*` records. The neutral schedule is contract and runtime fixture
data, not authored Stage 1 production content.

The product `content_version` versions only the product contract's values. A
catalog cites it as a compatibility binding, but that value does not also
version the subordinate catalog's values. A subordinate pattern or stage-value
change therefore does not silently advance the product version; the catalog
retains its own schema and explicit product binding. The current product
contract remains version `1.5.0`.

The focused validator reports `source: field.path: reason`. File validation
uses the supplied filename and decoded in-memory validation uses the explicit
`<in-memory>` source label. It rejects malformed versions and grammar,
missing or invented core records, duplicate IDs or references, nonreciprocal
topology, invalid geometry policy, malformed requirements, and undeclared ship
fields.

Run it with:

```sh
python3.12 tools/content/validate_product_contract.py content/product_contract.json
```

## Difficulty identity

The closed difficulty registry contains the three role IDs, in canonical order,
`difficulty.easy`, `difficulty.normal`, and `difficulty.hard`. Their current
player-facing `display_name` content is Breeze, Arcade, and Storm. Persisted run
and configuration data uses the role ID; renaming display text never migrates
or replaces that ID.

These records establish identity only. They intentionally contain no bullet
speed, density, HP, rank, score, practice, encounter, or other tuning fields;
Issue #20 owns content-driven difficulty profiles and balance.

There is no `difficulty.extra` identity. Extra remains solely the existing
`stage.extra.dreams_of_a_clockwork_angel` stage identity; campaign progression
remains the authority for its unlock and story conditions.

## Current binding decisions

The logical output is `640x360`; gameplay uses the centered `270x360` plane
`[185,455) x [0,360)`. Gameplay is a vertical 2D shmup and the perspective 3D
world is presentation only.

Normal Stage 1 has exactly three complete playable routes. Selecting Ciela
binds the Maynii-Kolar pair, their two standard patterns, and the Root +
Ridgeline combo. Selecting Maynii binds the Ciela-Kolar pair, Ciela's River
Current and Kolar's existing standard, and the River + Ridgeline combo.
Selecting Kolar binds the Ciela-Maynii pair, their River Current and Leaf Fan
standards, and the unique River + Roots combo. Every route uses
`stage_schedule.stage1.selected_ship_lost_forest`; its generic fae slots map
through the selected run rather than display names. The selected ship is never
also a midboss, and a ship registry entry without a complete route is not
selectable.

Each unchosen fae performs one independently resolved personal attack. After
both personal lives clear, the same two bodies reform behind a two-second
recharge with one synchronized shared combo life. Defeating the combo resumes
the second half of Stage 1. The Kolar route supplies the Ciela-Maynii variant
without changing the established routes.

Geometry uses a binary 1/1024-logical-pixel grid. In grid units, a point anchor
is eligible only when `189440 <= x < 465920` and `0 <= y < 368640`. A declared
half-open hurtbox must have positive extent and be fully contained: its
left/top meet or exceed the plane minima and its right/bottom do not exceed the
exclusive maxima. Right/bottom anchor clamps are therefore `465919` and
`368639`, equivalent to `454.9990234375` and `359.9990234375` logical pixels.
Each emission attempt declares a point-anchor or hurtbox gate and is locked
when that declared gate fails; another attempt or an enemy's earlier position
does not grant authority.

Maynii is the forward-and-tracking all-arounder and Ciela is the spread
specialist. Kolar is the close-range specialist: close-range combat is her
primary strength, and dependable, meaningful ranged damage is mandatory. Her
current Stage 1 implementation uses explicit focus-dependent options, a
58-pixel logical close band, and useful forward ranged fire in both focus
states. Collision-only, melee-only, zero-range, and negligible-ranged
interpretations are forbidden. Final three-ship balance remains later tuning.

The registry also binds the six-stage route, its extra stage, named GDD
encounters, reciprocal stage links, ending selection, and the any-difficulty
main-campaign one-credit-clear extra-stage unlock. Progression conditions use
validated enum tokens rather than behavior-bearing prose. Bosses require a
roughly two-second ring recharge between phases; large bosses may change parts
during transitions.

All six `product_requirements` fields—gameplay, enemy-emission gate, boss-phase
policy, defeat feedback, presentation, and asset authoring—are required
nonempty strings. They bind requirements rather than shipped artwork, tuning,
or an asset export; executable geometry and progression behavior remains in
the structured fields above.
