# Issue 91 Kolar characterization

Issue #91 closes the remaining characterization gap around the Kolar runtime delivered by Issue #112. It does not introduce another weapon system or replace the shared Stage 1 player lifecycle.

## Binding vertical-slice values

These values are preliminary acceptance thresholds for the current Stage 1 slice and remain subject to Fenny's playtest and later three-ship balance work.

| Fixture | Base Hyper tier | Distance | Window | Target HP / threshold |
| --- | ---: | ---: | ---: | ---: |
| Equal-duration close/far comparison | 0 | close `58`, far `59` | 120 ticks | close damage must be at least `1.75x` far damage in both focus states |
| Representative far target | 0 | `59` | 120 ticks | 33 HP |
| Stage 1-shaped commander | 0 | `59` | 180 ticks | 45 HP |
| Forced-separation boss | 0 | `59` | 240 ticks | 66 HP |

The base shared fire cadence emits immediately and then every eight simulation ticks. At Hyper tier 0 this yields 15 volleys in 120 ticks, 23 in 180 ticks, and 30 in 240 ticks.

Kolar's current raw per-volley damage is:

| Focus state | Close-band channels | Ranged channels | Close-band total | Far total | Close/far ratio |
| --- | --- | --- | ---: | ---: | ---: |
| Unfocused | one `3.00` close shot | two `1.90` ranged shots | `6.80` | `3.80` | `1.789x` |
| Focused | two `3.60` close shots | one `2.25` ranged shot | `9.45` | `2.25` | `4.20x` |

The declared `1.75x` margin is intentionally below the weaker unfocused ratio so small later tuning can occur without silently destroying Kolar's close-range-specialist identity.

At the weakest focused ranged floor, the fixtures receive `33.75` damage in 120 ticks, `51.75` in 180 ticks, and `67.50` in 240 ticks. Each representative target is therefore defeatable without entering the 58-pixel close band, while the same windows retain a substantially larger close-range payoff.

## Identity and determinism

Kolar remains a three-option loadout. Her projectile commands contain no Maynii tracking state and their authored lateral velocity is bounded to `0.24` pixels per tick rather than adopting Ciela's broad five-shot spread. Close shots use the 58-pixel logical range limit; ranged shots have no close-band range limit.

`BladeKolarLoadoutTests` now locks:

- both focus-state formations and channel mixes;
- stable command order and Hyper-sensitive canonical volley data;
- nearest-target, spawn-order, stable-ID, cleanup, and close-band selection behavior;
- the 58/59-pixel close-band boundary;
- the declared close-versus-far sustained-damage margin;
- representative far-target, commander, and forced-separation ranged-only viability;
- the base eight-tick cadence;
- absence of Maynii tracking and Ciela broad-spread identity;
- a quantized first-four-tick focused projectile trajectory golden.

Kolar continues to use the shared selected-run, combat, economy, cleanup, pause, death/respawn, retry, and Stage 1 route machinery already exercised by the repository-wide suites and the Issue #112 integration tests. Damage still resolves through `BladeFirstBeatApplyPlayerShot`, which routes midboss/boss damage through their owners and awards hit economy through `BladeSurvivalAwardEnemyHit`; cleanup remains reason-distinct from defeat/reward paths.

## Validation target

Run the exact candidate through the repository's established validation set:

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

The tracked thresholds above are acceptance characterization, not final balance authority.
