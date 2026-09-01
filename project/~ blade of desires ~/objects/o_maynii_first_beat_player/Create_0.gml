/// Bind Maynii's identity after the shared player lifecycle is initialized.
event_inherited();
BladeStage1PlayerConfigure(
    id,
    "ship.maynii",
    "player_kind.stage1.maynii",
    "loadout.stage1.maynii_tracking_forward"
);
