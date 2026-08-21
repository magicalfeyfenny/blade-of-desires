/// @description Closed type and reason vocabulary for deterministic gameplay events.

/// Recognizes reason-coded run and room cleanup shared by every combat-owned entity kind.
function _BladeEventSchemaIsBoundaryCleanup(_reason) {
    return _reason == "cleanup.run_load"
        || _reason == "cleanup.run_reset"
        || _reason == "cleanup.run_aborted"
        || _reason == "cleanup.run_completed"
        || _reason == "cleanup.room_exit";
}

/// Recognizes terminal reasons shared by active attacks and projectiles.
function _BladeEventSchemaIsCombatCleanup(_reason) {
    return _BladeEventSchemaIsBoundaryCleanup(_reason)
        || _reason == "cleanup.owner_removed"
        || _reason == "cancel.phase_change";
}

/// Recognizes every reason that may remove a projectile during a combat tick.
function _BladeEventSchemaIsProjectileCleanup(_reason) {
    return _BladeEventSchemaIsCombatCleanup(_reason)
        || _reason == "cleanup.stage_end"
        || _reason == "cleanup.out_of_bounds"
        || _reason == "cleanup.expired"
        || _reason == "cleanup.hit_budget_exhausted"
        || _reason == "cancel.projectile_collision";
}

/// Resolves a supported type and reason to its source and target ID kinds so
/// event relationship validation has one authoritative schema.
function _BladeEventSchemaEndpointKinds(_type, _reason) {
    switch (_type) {
        case "instance.spawned":
            if (_reason == "outcome.scheduled") {
                return [-1, BladeRunIdKind.Instance];
            }
            if (_reason == "outcome.defeat_child") {
                return [BladeRunIdKind.Instance, BladeRunIdKind.Instance];
            }
            break;
        case "attack.started":
            if (_reason == "outcome.input_pressed" || _reason == "outcome.scheduled") {
                return [BladeRunIdKind.Instance, BladeRunIdKind.Attack];
            }
            break;
        case "bullet.spawned":
            if (_reason == "outcome.pattern_emitted") {
                return [BladeRunIdKind.Attack, BladeRunIdKind.Bullet];
            }
            break;
        case "damage.applied":
            if (_reason == "outcome.collision_confirmed") {
                return [BladeRunIdKind.Bullet, BladeRunIdKind.Instance];
            }
            break;
        case "damage.transaction_applied":
            if (_reason == "outcome.collision_confirmed") {
                return [BladeRunIdKind.DamageEvent, BladeRunIdKind.Instance];
            }
            break;
        case "instance.removed":
            if (_reason == "cleanup.stage_end"
                || _reason == "cleanup.owner_removed"
                || _reason == "cleanup.out_of_bounds"
                || _reason == "cancel.phase_change"
                || _reason == "outcome.defeated"
                || _BladeEventSchemaIsBoundaryCleanup(_reason)) {
                return [BladeRunIdKind.Instance, -1];
            }
            break;
        case "attack.cancelled":
            if (_BladeEventSchemaIsCombatCleanup(_reason)) {
                return [BladeRunIdKind.Attack, -1];
            }
            break;
        case "bullet.removed":
            if (_BladeEventSchemaIsProjectileCleanup(_reason)) {
                return [BladeRunIdKind.Bullet, -1];
            }
            break;
        case "damage.cancelled":
            if (_BladeEventSchemaIsCombatCleanup(_reason)) {
                return [BladeRunIdKind.DamageEvent, -1];
            }
            break;
        case "reward.requested":
            if (_reason == "outcome.defeated") {
                return [BladeRunIdKind.Instance, -1];
            }
            break;
        case "presentation.effect":
            if (_reason == "presentation.requested") {
                return [-1, -1];
            }
            break;
    }
    _BladeEventLogFail(
        "type/reason",
        "unknown or invalid pair " + string(_type) + " / " + string(_reason)
    );
}
