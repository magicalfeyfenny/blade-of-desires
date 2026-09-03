# Kolar production sprite pack

This note records the authored/runtime boundary for Issue #119. The finished
pixel finish in each `.kra` file is the authority; the matching PNG is the
configured runtime derivative. The preserved front-facing
`assets/runtime/sprites/stage1/kolar_boss.png` remains the midboss asset and is
not part of this replacement.

## Authoring record

- ImageGen draft: [kolar-imagegen-draft.png](kolar-imagegen-draft.png). It is a
  visual exploration only and is not packaged as a runtime asset.
- Final finishing: deliberate hard-edged pixel clusters using a limited
  indigo, violet, icy-cyan, white, and mineral-gold palette, with rose accents
  reserved for hit/defeat feedback.
- Runtime integration: the existing four Kolar filenames remain the package
  seam. The renderer loads their horizontal sheets with the frame counts below.
- The player canvas is six 48x48 frames (288x48); each attack/option frame is
  centered by the dynamic loader and does not define gameplay geometry.

## Frame contract

| Runtime asset | Frame size | Frames | Meaning and timing |
| --- | ---: | ---: | --- |
| `kolar_player.png` | 48x48 | 0 | Active idle; shared with the first active beat. |
| `kolar_player.png` | 48x48 | 1 | Active movement/breathing beat; alternates with frame 0 every 8 simulation ticks. |
| `kolar_player.png` | 48x48 | 2 | Focused player; selected while the shared focus action is held. |
| `kolar_player.png` | 48x48 | 3 | Hit response; selected for the existing hit-response window. |
| `kolar_player.png` | 48x48 | 4 | Defeat; selected for terminal Game Over presentation. |
| `kolar_player.png` | 48x48 | 5 | Respawn; selected during the existing respawn phase. |
| `kolar_option.png` | 16x16 | 0-1 | Unfocused/focused crystal option, selected from the existing formation. |
| `kolar_close_channel.png` | 24x16 | 0-3 | Close-channel muzzle pulse; frame advances every 6 travelled logical pixels. |
| `kolar_ranged_shot.png` | 12x18 | 0-3 | Ranged crystal lance; frame advances every 6 travelled logical pixels. |

The shared lifecycle, 3-pixel hit radius, 6-pixel body radius, 58-pixel close
band, shot damage, and option centers remain in the canonical gameplay/loadout
code. No decorative pixel, art bound, or visual frame is used for collision,
range, target selection, or reward logic.

## Anchors and symmetry

- Every player frame uses a center anchor at `(24,24)`, matching the existing
  player draw origin. The central lower crystal is a visual focus cue only.
- Every option frame uses `(8,8)` as its center. The three option centers come
  only from `BladeKolarOptionFormation`; unfocused and focused art shares the
  same formation points.
- Close-channel frames use `(12,8)` as the muzzle/effect center. Ranged frames
  use `(6,9)` with the bright tip at `(6,1)`. Shot instances still spawn from
  the loadout offsets and keep their existing logical movement and range.
- The left and right player wings are hand-mirrored for a stable rear-facing
  silhouette; no runtime image mirroring is required. The active idle frame is
  intentionally shared as the fallback when a controller is unavailable.
- Attack frames share the same center and silhouette footprint, so animation
  changes do not move the logical projectile origin.

Native and integer-scaled readability across dark, bright, and busy forest
backdrops is recorded in
[kolar-production-contact-sheet.png](kolar-production-contact-sheet.png).
