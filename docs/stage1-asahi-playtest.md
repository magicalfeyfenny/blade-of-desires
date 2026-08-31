# Stage 1 Asahi playtest handoff

This handoff covers the development/playtest candidate for Issue #20. The
exact candidate commit is recorded in the draft pull request body because a
tracked file cannot contain the hash of the commit that contains itself.

## Controls and launch

Launch the GameMaker project normally. The ordinary development launch enters
the Ciela/normal Stage 1 route directly; it requires no source edit, room
change, or developer setup.

- Arrow keys: move Ciela.
- Shift: focus movement and show the precise hit area.
- Z: fire.
- X: use the highest stocked Hyper, otherwise use a Bomb. During hit response,
  X spends all remaining Bomb stock as an emergency defense.
- R: retry from Stage Clear or Game Over.
- Escape: exit from Stage Clear or Game Over.

## Boss reproduction

Clear the two forest halves and the Maynii-and-Kolar encounter, then continue
to the World Tree. The route removes remaining ordinary actors and bullets,
shows the Asahi warning, and starts the World Tree camera orbit before Asahi
enters.

1. `SOLAR WALTZ` is the 20-second first life. Its aimed seven-flame fans gather
   behind a visible sun-ring tell.
2. Defeat or time out the first life to enter the non-damageable 120-tick
   (two-second at 60 Hz) ring recharge.
3. `CROWN OF DAWN` is the 25-second second life. Its rotating 16-ray crown
   leaves a two-ray gap and alternates with an aimed three-flame answer.
4. Defeat or time out the second life to resolve Asahi exactly once, clear her
   attacks, and reach the Stage Clear bonus. The result separates base,
   remaining-life, and remaining-Bomb bonuses and retains direct retry/exit.

The presentation camera continues orbiting the modeled, textured World Tree
through both lives. Ciela, Asahi, bullets, hurtboxes, collision, and input stay
on the unchanged canonical 2D plane.

## Candidate validation

Tested on 2026-08-31 with GameMaker runtime `runtime-2026.0.0.23` and macOS VM
runner `GameMaker v2026.0.0.32908`.

Run these commands from the repository root against the exact pull-request
head:

```sh
python3.12 tools/content/validate_product_contract.py content/product_contract.json
python3.12 tools/content/validate_stage_schedules.py content/stages
python3.12 tools/content/validate_gamemaker_content_bundle.py .
python3.12 -m unittest discover -s tools/tests -v
zsh tools/run_blade_kernel_tests.zsh
python3.12 tools/ci/check_repo.py --baseline-ref origin/dev
git diff --check origin/dev...HEAD
```

The GameMaker suite must end with exactly one
`BLADE_KERNEL_TEST_RESULT: PASS` sentinel.

## Practical observations and limitations

- A normal candidate build was launched without special arguments. Game Over,
  `R` retry, and continued normal input were observed directly.
- The complete forest-to-Asahi-to-Stage-Clear presentation was also observed
  in a disposable local build with a command-line playtest assist. The assist
  only granted invulnerability and resolved each encounter after a visible
  hold; it did not skip schedule nodes or replace the World Tree camera,
  Asahi presentation, recharge, result, retry, or exit paths. Its temporary
  source was removed before the candidate commit.
- This milestone covers the declared Ciela/normal path on the supported macOS
  VM runner. Broader ship and difficulty matrices remain outside Issue #20.
- The handoff creates no release build, tag, GitHub Release, deployment,
  upload, `main` promotion, or publication.
