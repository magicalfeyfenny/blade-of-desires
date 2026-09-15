# Stage 1 cutscene contract

Stage 1 cutscenes are controller-owned, fixed-tick sequences. The stage
executor remains the authority for the authored route; a cutscene suspends the
route at its current node and resumes it after an explicit `finish` command.

## Runtime state

The controller keeps three distinguishable pieces of state:

| State | Meaning |
| --- | --- |
| `Inactive` | Ordinary Stage 1 gameplay owns the tick. |
| `Running` | A move, action, wait, or finish command owns the tick. |
| `DialogueWaiting` | Dialogue is visible and only semantic Confirm or Cancel may dismiss it. |

`stage_suspended` reports route suspension separately from `pause_menu`. Pause
cannot open during an active cutscene, but the two systems retain separate
owners and transitions.

## Current vertical slice

The production route starts `sequence.stage1.asahi_intro` when Asahi is
spawned at the World Tree:

1. Move `actor.stage1.asahi` to the authored combat anchor.
2. Play the declared `solar_arrival` action for a fixed duration.
3. Show Asahi's speaker ID, display name, and dialogue text until interaction.
4. Finish and release temporary control so the existing Asahi entry resumes.

Entering the sequence performs administrative cleanup of ordinary enemies,
hostile bullets, player shots, and existing rewards. It does not call defeat
resolution, score conversion, Hyper awards, or other combat reward paths.

Declared actors use stable machine IDs and temporary `cutscene_controlled`,
`cutscene_action_id`, and `cutscene_action_ticks` fields. Their targetability
and temporary fields are snapshotted and restored by `finish`; disappearance
during a sequence aborts and releases all remaining ownership.

## Native boundary

GameMaker Sequences remain useful for authored timeline playback and pause, but
this slice also needs controller-owned Stage ticks, administrative cleanup,
actor ownership, and an interaction-gated dialogue boundary. Those contracts
stay in the small explicit GML command state machine rather than being hidden
inside a general visual-novel framework or a second route scheduler.
