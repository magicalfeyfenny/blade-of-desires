# Stage 1 ordinary fae roster

Issue #115 owns the four active ordinary roles in this order:

`enemy.stage1.popcorn < enemy.stage1.mook < enemy.stage1.elite < enemy.stage1.commander`

The profiles deliberately differ in health, defeat window, movement, pre-fire
tell, cadence, projectile family, and fan width. `enemy.stage1.scout` remains a
bounded compatibility alias that resolves to `enemy.stage1.mook`; it is not in
the Stage 1 catalog and never appears in player-facing labels.

The bomb carrier remains a reward-bearing mook variant with the existing
`enemy.bomb_carrier` identity. Its carrier identity is separate from the four
strength tiers so both existing carrier placements remain on the route without
creating a fifth role.

## Authored asset chain

The role atlas and effect atlas are source-authoritative `.kra` files under
`assets/source/sprites/stage1`. Their matching RGBA runtime derivatives are
under `assets/runtime/sprites/stage1` and are mapped in `assets/exports.json`.
The roster atlas uses four 64×96 columns. The effect atlas uses four 64×64
columns and four rows: projectile, tell, hit, and defeat.

The GameMaker renderer loads both runtime derivatives. Gameplay geometry stays
on the canonical product-contract plane; sprite bounds do not define hurt,
graze, emission, or collection geometry.
