/// Shared gameplay geometry and lifecycle state; child objects bind identity.
ship_id = "";
player_kind_id = "";
loadout_id = "";
focused = false;
fire_cooldown = 0;
hit_radius = 3;
body_radius = 6;
// Keep the authored graze band wider than the lethal hurtbox.
graze_radius = BLADE_SURVIVAL_GRAZE_RADIUS;
