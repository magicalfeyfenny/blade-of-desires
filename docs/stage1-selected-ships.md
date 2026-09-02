# Stage 1 selected ships

This document records the selected-ship values and live-playtest handoff for
Issues #111 and #112. The values are intentionally playable through the
complete Stage 1 slice; final three-ship balance remains later tuning work.

## Launch and run identity

An ordinary launch opens the 640×360 character selector before gameplay. It
shows exactly the complete routes declared by `stage1_playable_routes` in the
product contract: Ciela, Maynii, and Kolar. Move and confirm use the current config
service's semantic keyboard bindings. Left/right selects Easy, Normal, or Hard;
one accepted confirmation creates a difficulty-bound run record and the Stage 1 room revalidates that record
against packaged content before it creates exactly one player.

The selected record remains in `global.blade_selected_run` for room transition,
death/respawn, and `R` retry. Missing or altered route fields stop the run with
a visible content error; the runtime never substitutes Ciela.

| Selected ship | Fairy identity | Player loadout | Stage 1 midbosses | Shared combo |
| --- | --- | --- | --- | --- |
| `ship.ciela` | river fairy | broad spread; focus tightens | Maynii, Kolar | Root + Ridgeline |
| `ship.maynii` | leaf fairy | tracking unfocused; forward focused | Ciela, Kolar | River + Ridgeline |
| `ship.kolar` | mountain fairy | close-range payoff; useful ranged fire in both focus states | Ciela, Maynii | River + Roots |

## Difficulty and dynamic rank

The selector exposes the identity-only contract records `difficulty.easy`
(Breeze), `difficulty.normal` (Arcade), and `difficulty.hard` (Storm). The
selected identity is retained through room transition, hit/death/respawn, and
`R` retry; a fresh retry recreates rank at `0` while preserving the selected
difficulty. The extra stage remains only
`stage.extra.dreams_of_a_clockwork_angel`, never a fourth difficulty.

Stage 1's authored profiles make the same rank observably easier or harder:

| Difficulty | Hostile speed | Hostile fire | Enemy HP | Point/reward value |
| --- | ---: | ---: | ---: | ---: |
| Easy | 85% | 82% | 85% | 90% |
| Normal | 100% | 100% | 100% | 100% |
| Hard | 115% | 120% | 115% | 110% |

Attempt rank is an integer from `0` to `50`. Every 30 eligible active-play
ticks raises it by one; rank 50 composes to +20% hostile speed, +30% hostile
fire rate, and +50% point/reward value. Normal rank 0 is the compatibility
baseline. Normal Hyper, normal Bomb, hit-response death-bomb Hyper, committed
life loss, and emergency recovery each apply their documented one-shot delta;
the hit-response arbiter accepts only one of those actions per input.

Kolar's Stage 1 route is delivered by Issue #112. Its selected run uses
`loadout.stage1.kolar_close_range`, with a 58-pixel logical close band and
explicitly ranged projectiles that remain useful while unfocused or focused.

## Kolar preliminary values

Kolar's close channel is the strongest focused payoff while her unfocused
formation keeps two ranged projectiles active. Both channels use manual motion
and the shared player-shot lifecycle; close shots end at the declared logical
band and ranged shots remain active until a vertical plane exit.

| Mode | Option centers relative to Kolar | Channel mix | Base damage per shot |
| --- | --- | --- | --- |
| Unfocused | `(-18, 3)`, `(0, 0)`, `(18, 3)` | two ranged at speed 7.0; one close at speed 7.4 | ranged 1.90; close 3.00 |
| Focused | `(-10, -2)`, `(0, -7)`, `(10, -2)` | two close at speed 7.4; one ranged at speed 7.0 | close 3.60; ranged 2.25 |

These are preliminary values for the current slice, not final balance. Proper
authored Kolar player/attack art is tracked separately in Issue #119; the
current implementation keeps deterministic pixel placeholders so the route
remains testable.

## Maynii preliminary values

Maynii uses the same movement, focus speed, hit/death/respawn, Bomb, Hyper,
economy, HUD, pause, and Stage 1 controller as Ciela. Both ships use a 3-pixel
hit radius, 6-pixel body radius, and 14-pixel graze radius; decorative sprite
bounds never define gameplay geometry.

Maynii's shared eight-frame fire cadence emits one shot from each visible
option in stable array order:

| Mode | Option centers relative to Maynii | Base shot | Base damage per shot |
| --- | --- | --- | --- |
| Unfocused | `(-15, 3)`, `(15, 3)` | tracking leaf, speed 6.4, maximum turn 8° per tick | 2.45 |
| Focused | `(-8, -2)`, `(0, -6)`, `(8, -2)` | forward leaf lance, speed 8.0 | 2.15 |

Tracking eligibility requires a live targetable Stage enemy with positive
gameplay hit geometry and a nonempty Stage instance ID. Selection orders by
squared distance, then authored spawn order, then ASCII stable ID. A defeated
or cleaned-up target is resolved again every tick; the shot reacquires the next
eligible target or restores straight 6.4-pixel-per-tick forward travel. It
never retains a stale instance reference and never loses all damage when the
screen is empty.

Player shots remain active after crossing either gameplay-plane side edge and
clean up only after a top or bottom plane exit. Hostile bullets likewise remain
visible while crossing the translucent side UI gutters, but clean up at every
edge of the 640×360 room window. These lifetime boundaries do not change player,
enemy, shot, hurt, or graze geometry.

Hyper keeps the same formations and target rules. Its existing shared economy
raises Maynii's preliminary per-shot damage while the shared cadence and
projectile systems retain their established Hyper behavior. Bomb, hit response,
death, respawn, retry, and pause remain controller-owned rather than being
reimplemented in the loadout.

## Selection-aware midboss lifecycle

The selected route maps the schedule's ordered generic fae slots to exact ship
IDs and standard-pattern IDs. Each body owns its Stage instance identity,
movement, hit geometry, health, targetability, attack bullets, personal defeat,
and cleanup. A cleared personal body is retained but harmless until both solos
resolve. The pair then clears only its owned bullets, recharges for 120 ticks,
and reforms with one synchronized 150-HP combo life.

Ciela's six-shot River Current uses staggered banks and changing channel drift;
it does not replay her player spread. River + Ridgeline combines Ciela's moving
six-lane river channel with Kolar's four-crystal answer. The existing Ciela
route retains Maynii's four-leaf standard, Kolar's five-crystal standard, and
their eight-leaf-plus-five-crystal Root + Ridgeline combo.
The Kolar route retains Ciela's River Current and Maynii's Leaf Fan standards,
then adds a seven-bullet river pulse with a delayed three-leaf roots answer
under River + Roots.

Only eligible personal or shared-life defeat reports can advance the route.
Administrative abort, reset, cleanup, or room teardown cannot impersonate a
defeat. Participant bullet cleanup uses `owner_stage_instance_id`, preserving
unrelated hostile patterns.

## Art authority and readability evidence

Maynii's 48×48 player sprite faces away from the camera and preserves the leaf
silhouette and palette of her unchanged 64×64 front-facing boss sprite. Ciela's
unchanged 48×48 player sprite remains rear-facing; her new 64×64 boss sprite is
front-facing. Kolar's current 48×48 rear-facing player, options, close/ranged
shots, and River + Roots combo use crisp deterministic placeholder pixels while
the production visual pack is authored under Issue #119.

Each runtime PNG maps to an editable `.kra` in `assets/exports.json` and one
GameMaker IncludedFile entry. The character KRA files contain a visible
`Pixel finish - runtime authority` layer and a hidden, explicitly non-authority
image-generation reference layer. Full generation renders are not retained or
packaged as competing asset authority.

The contact sheets show both character views, both Maynii modes, and both new
Ciela pattern families over dark and busy backgrounds:

- [native 640×360](validation/issue-111/selected-fairy-art-contact-sheet-640x360.png)
- [integer-scaled 1280×720](validation/issue-111/selected-fairy-art-contact-sheet-1280x720.png)

## Exact-candidate validation and live playtest

From the repository root, validate the exact candidate with:

```sh
python3.12 tools/content/validate_product_contract.py content/product_contract.json
python3.12 tools/content/validate_stage_schedules.py content/stages
python3.12 tools/content/validate_pattern_descriptors.py content/patterns
python3.12 tools/content/validate_gamemaker_content_bundle.py .
python3.12 -m unittest discover -s tools/tests -v
zsh tools/run_blade_kernel_tests.zsh
python3.12 tools/ci/check_repo.py --baseline-ref origin/dev
git diff --check origin/dev...HEAD
```

The live matrix is two complete fresh launches:

1. Selector → Ciela → Maynii/Kolar standards → Root + Ridgeline → Asahi → Stage Clear.
2. Selector → Maynii → tracking unfocused → forward focused → Ciela/Kolar
   standards → River + Ridgeline → Asahi → Stage Clear.

During the Maynii route, exercise movement, focus transitions, Bomb, Hyper,
one normal hit/death/respawn, item pickup, Game Over or Stage Clear retry, and
confirm that Maynii remains selected. Record native 640×360 and normal
integer-scaled 1280×720 captures of the selector, both Maynii shot modes,
Ciela's boss presentation, and River + Ridgeline. The exact candidate commit
and observed results belong in the draft pull request because a tracked file
cannot contain the hash of the commit that contains itself.

Observed on 2026-09-01 with GameMaker runtime `runtime-2026.0.0.23` and Mac
Runner `2026.0.0.32908`:

- The Ciela route completed from a fresh selector launch through the
  Maynii/Kolar pair, Asahi, and Stage Clear.
- Fenny completed and confirmed the Maynii route through Ciela/Kolar and Stage
  Clear, including both shot modes and the corrected projectile lifetime
  behavior. Player shots survived side-plane exits; hostile shots remained in
  the UI gutters and ended at the window edge.
- The exact GameMaker candidate passed 178 of 178 tests. The repository Python
  suite passed 206 of 206 tests, and every content validator passed.
- Recorded runtime windows show the selector at
  [native size](validation/issue-111/selector-640x360-window.png) and
  [integer scale](validation/issue-111/selector-1280x720-window.png), the Ciela
  route's Stage Clear at
  [native size](validation/issue-111/ciela-route-stage-clear-640x360-window.png)
  and [integer scale](validation/issue-111/ciela-route-stage-clear-1280x720-window.png),
  and Maynii's live tracking presentation at
  [integer scale](validation/issue-111/maynii-unfocused-live-1280x720-window.png).
  The native and integer-scaled contact sheets above retain the paired shot,
  Ciela boss, and River + Ridgeline readability evidence.
