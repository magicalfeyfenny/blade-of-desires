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

Every record has `schema_version`, `id`, and `display_name`. IDs use lowercase
dotted segments; each segment starts with a letter and continues with lowercase
letters, digits, or underscores. IDs are globally unique and permanent: a
display-name change never changes an ID, and a retired ID is never reassigned.

`content_version` versions the complete contract. Consumers must reject an
unknown schema version rather than guessing a default. The focused validator
reports the file/field/reason for malformed versions, duplicate or malformed
IDs, dangling references, invalid playfield geometry, and any Kolar loadout.

Run it with:

```sh
python3.12 tools/content/validate_product_contract.py content/product_contract.json
```

## Current binding decisions

The logical output is `640x360`; gameplay uses the centered `270x360` plane
`[185,455) x [0,360)`. Gameplay is a vertical 2D shmup and the perspective 3D
world is presentation only. Enemy emission is permitted only while the declared
anchor or hurtbox lies inside that plane.

Maynii is the forward-and-tracking all-arounder and Ciela is the spread
specialist. Kolar has a stable reserved ID but is deferred: this contract does
not select a weapon, emitter, damage value, or melee commitment for her.

The registry also binds the six-stage route, its extra stage, named GDD
encounters, ending selection, and the any-difficulty one-credit-clear extra
stage unlock. Bosses require a roughly two-second ring recharge between phases;
large bosses may change parts during transitions. Stage 1 and the visual/UI
requirements are product requirements, not shipped artwork or an asset export.
