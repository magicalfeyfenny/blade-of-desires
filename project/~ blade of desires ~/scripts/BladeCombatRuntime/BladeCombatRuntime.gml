/// @description Sole mutable owner for one run's deterministic combat state.

enum BladeCombatSubjectKind {
    Actor = 1,
    Attack = 2,
    Projectile = 3
}

enum BladeCombatTerminalReason {
    None = 0,
    OutOfBounds = 1,
    Expiration = 2,
    HitBudgetExhausted = 3,
    ProjectileCancellation = 4,
    Defeat = 5,
    OwnerRemoval = 6,
    PhaseChange = 7,
    RoomExit = 8,
    RunCompleted = 9,
    RunAborted = 10,
    RunReset = 11,
    RunLoad = 12
}

/// Throws one field-specific combat-runtime diagnostic.
function _BladeCombatRuntimeFail(_field, _reason) {
    throw("BladeCombatRuntime: " + _field + ": " + _reason);
}

/// Converts one exact numeric value to int64 inside inclusive bounds.
function _BladeCombatRuntimeInteger(_value, _minimum, _maximum, _field) {
    return BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field);
}

/// Accepts only a real Boolean without numeric coercion.
function _BladeCombatRuntimeBoolean(_value, _field) {
    if (typeof(_value) != "bool") {
        _BladeCombatRuntimeFail(_field, "must be a boolean");
    }
    return _value;
}

/// Deep-copies arrays and structs used by public combat snapshots.
function _BladeCombatRuntimeClone(_value) {
    if (is_array(_value)) {
        var _array = [];
        for (var _index = 0; _index < array_length(_value); ++_index) {
            array_push(_array, _BladeCombatRuntimeClone(_value[_index]));
        }
        return _array;
    }
    if (is_struct(_value)) {
        var _copy = {};
        var _names = variable_struct_get_names(_value);
        for (var _index = 0; _index < array_length(_names); ++_index) {
            var _name = _names[_index];
            variable_struct_set(
                _copy, _name,
                _BladeCombatRuntimeClone(variable_struct_get(_value, _name))
            );
        }
        return _copy;
    }
    return _value;
}

/// Returns the stable token for one closed terminal reason.
function BladeCombatTerminalReasonToken(_reason) {
    switch (_BladeCombatRuntimeInteger(
        _reason, BladeCombatTerminalReason.None,
        BladeCombatTerminalReason.RunLoad, "terminal reason"
    )) {
        case BladeCombatTerminalReason.None: return "";
        case BladeCombatTerminalReason.OutOfBounds: return "cleanup.out_of_bounds";
        case BladeCombatTerminalReason.Expiration: return "cleanup.expired";
        case BladeCombatTerminalReason.HitBudgetExhausted: return "cleanup.hit_budget_exhausted";
        case BladeCombatTerminalReason.ProjectileCancellation: return "cancel.projectile_collision";
        case BladeCombatTerminalReason.Defeat: return "outcome.defeated";
        case BladeCombatTerminalReason.OwnerRemoval: return "cleanup.owner_removed";
        case BladeCombatTerminalReason.PhaseChange: return "cancel.phase_change";
        case BladeCombatTerminalReason.RoomExit: return "cleanup.room_exit";
        case BladeCombatTerminalReason.RunCompleted: return "cleanup.run_completed";
        case BladeCombatTerminalReason.RunAborted: return "cleanup.run_aborted";
        case BladeCombatTerminalReason.RunReset: return "cleanup.run_reset";
        case BladeCombatTerminalReason.RunLoad: return "cleanup.run_load";
    }
    _BladeCombatRuntimeFail("terminal reason", "is unreachable");
}

/// Returns the documented priority used when terminal requests compete.
function _BladeCombatRuntimeTerminalPriority(_reason) {
    switch (_reason) {
        case BladeCombatTerminalReason.OutOfBounds: return 10;
        case BladeCombatTerminalReason.Expiration: return 20;
        case BladeCombatTerminalReason.HitBudgetExhausted: return 30;
        case BladeCombatTerminalReason.ProjectileCancellation: return 40;
        case BladeCombatTerminalReason.Defeat: return 50;
        case BladeCombatTerminalReason.OwnerRemoval: return 60;
        case BladeCombatTerminalReason.PhaseChange: return 70;
        case BladeCombatTerminalReason.RoomExit: return 80;
        case BladeCombatTerminalReason.RunCompleted:
        case BladeCombatTerminalReason.RunAborted: return 90;
        case BladeCombatTerminalReason.RunReset: return 100;
        case BladeCombatTerminalReason.RunLoad: return 110;
    }
    _BladeCombatRuntimeFail("terminal reason", "cannot select None");
}

/// Validates the runtime container and its shared run-local owner ID.
function _BladeCombatRuntimeRequire(_runtime) {
    if (!is_struct(_runtime)
        || !variable_struct_exists(_runtime, "__blade_combat_runtime_version")
        || _runtime.__blade_combat_runtime_version != 1) {
        _BladeCombatRuntimeFail("runtime", "expected a version 1 runtime");
    }
    var _arrays = [
        _runtime.actors, _runtime.attacks, _runtime.projectiles,
        _runtime.damage_transactions, _runtime.pending_terminals,
        _runtime.terminal_records, _runtime.reward_requests,
    ];
    for (var _index = 0; _index < array_length(_arrays); ++_index) {
        if (!is_array(_arrays[_index])) {
            _BladeCombatRuntimeFail("runtime", "owned collections must remain arrays");
        }
    }
    BladeRunIdentityGetCounters(_runtime.identity);
    BladeRunIdentityRequireAllocated(
        _runtime.identity, _runtime.event_owner_id, BladeRunIdKind.EventOwner
    );
    if (!is_undefined(_runtime.plane)) BladeCombatPlaneCopy(_runtime.plane);
    return _runtime;
}

/// Resolves decoded or already compiled plane data without retaining caller structs.
function _BladeCombatRuntimePlane(_plane) {
    if (is_undefined(_plane)) return undefined;
    if (is_struct(_plane)
        && variable_struct_exists(_plane, "__blade_combat_plane_version")) {
        return BladeCombatPlaneCopy(_plane);
    }
    return BladeCombatPlaneCreate(_plane);
}

/// Returns an allocated ID's numeric ordinal after shared identity validation.
function _BladeCombatRuntimeIdOrdinal(_runtime, _id, _kind) {
    var _validated = BladeRunIdentityRequireAllocated(_runtime.identity, _id, _kind);
    return int64(string_delete(_validated, 1, string_pos(":", _validated)));
}

/// Finds one active record by its stable ID field, or returns -1.
function _BladeCombatRuntimeFind(_records, _field, _id) {
    for (var _index = 0; _index < array_length(_records); ++_index) {
        if (variable_struct_get(_records[_index], _field) == _id) return _index;
    }
    return -1;
}

/// Reports whether an ID occurs in one scalar string array.
function _BladeCombatRuntimeArrayContains(_values, _needle) {
    for (var _index = 0; _index < array_length(_values); ++_index) {
        if (_values[_index] == _needle) return true;
    }
    return false;
}

/// Validates and recursively detaches a defeat-child specification.
function _BladeCombatRuntimeChildSpec(_runtime, _spec, _depth = 0) {
    if (is_undefined(_spec)) return undefined;
    if (_depth > 8 || !is_struct(_spec)) {
        _BladeCombatRuntimeFail("child specification", "must be a struct of at most 8 generations");
    }
    var _content_id = BladeRunIdentityRequireContent(_runtime.identity, _spec.content_id);
    var _faction = _BladeCombatRuntimeInteger(
        _spec.faction, BladeCombatFaction.Player, BladeCombatFaction.Enemy, "child faction"
    );
    return {
        content_id: _content_id,
        faction: _faction,
        health: _BladeCombatRuntimeInteger(
            _spec.health, 1, int64("2147483647"), "child health"
        ),
        box: _BladeCombatGeometryAabbCopy(_spec.box),
        invulnerable_until_combat_tick: _BladeCombatRuntimeInteger(
            _spec.invulnerable_until_combat_tick,
            0, int64("9223372036854775807"), "child invulnerability"
        ),
        reward_on_defeat: _BladeCombatRuntimeBoolean(
            _spec.reward_on_defeat, "child reward policy"
        ),
        count: _BladeCombatRuntimeInteger(_spec.count, 1, 64, "child count"),
        child_spec: _BladeCombatRuntimeChildSpec(_runtime, _spec.child_spec, _depth + 1),
    };
}

/// @func BladeCombatChildSpecCreate(content_id, faction, health, box, invulnerable_until, reward_on_defeat, count, child_spec)
/// Creates caller-owned plain data; runtime registration performs authoritative validation.
function BladeCombatChildSpecCreate(
    _content_id, _faction, _health, _box,
    _invulnerable_until_combat_tick, _reward_on_defeat,
    _count, _child_spec = undefined
) {
    return {
        content_id: _content_id,
        faction: _faction,
        health: _health,
        box: _BladeCombatGeometryAabbCopy(_box),
        invulnerable_until_combat_tick: _invulnerable_until_combat_tick,
        reward_on_defeat: _reward_on_defeat,
        count: _count,
        child_spec: _BladeCombatRuntimeClone(_child_spec),
    };
}

/// Creates one validated full-health actor record over an allocated instance ID.
function _BladeCombatRuntimeActor(
    _runtime, _instance_id, _content_id, _faction, _health, _box,
    _invulnerable_until_combat_tick, _reward_on_defeat, _child_spec,
    _simulation_tick, _combat_tick
) {
    var _validated_id = BladeRunIdentityRequireAllocated(
        _runtime.identity, _instance_id, BladeRunIdKind.Instance
    );
    var _validated_health = _BladeCombatRuntimeInteger(
        _health, 1, int64("2147483647"), "actor health"
    );
    return {
        instance_id: _validated_id,
        content_id: BladeRunIdentityRequireContent(_runtime.identity, _content_id),
        faction: _BladeCombatRuntimeInteger(
            _faction, BladeCombatFaction.Player, BladeCombatFaction.Enemy, "actor faction"
        ),
        health: _validated_health,
        health_max: _validated_health,
        previous_box: _BladeCombatGeometryAabbCopy(_box),
        current_box: _BladeCombatGeometryAabbCopy(_box),
        invulnerable_until_combat_tick: _BladeCombatRuntimeInteger(
            _invulnerable_until_combat_tick,
            0, int64("9223372036854775807"), "actor invulnerability"
        ),
        recent_attack_ids: [],
        reward_on_defeat: _BladeCombatRuntimeBoolean(
            _reward_on_defeat, "actor reward policy"
        ),
        child_spec: _BladeCombatRuntimeChildSpec(_runtime, _child_spec),
        spawn_simulation_tick: _BladeCombatRuntimeInteger(
            _simulation_tick, 0, int64("9223372036854775807"), "actor spawn tick"
        ),
        spawn_combat_tick: _BladeCombatRuntimeInteger(
            _combat_tick, 0, int64("9223372036854775807"), "actor spawn combat tick"
        ),
    };
}

/// @func BladeCombatRuntimeCreate(identity, event_owner_id, gameplay_plane)
/// Creates empty run-owned combat collections and an optional fail-closed emission plane.
function BladeCombatRuntimeCreate(_identity, _event_owner_id, _gameplay_plane = undefined) {
    BladeRunIdentityGetCounters(_identity);
    return {
        __blade_combat_runtime_version: 1,
        identity: _identity,
        event_owner_id: BladeRunIdentityRequireAllocated(
            _identity, _event_owner_id, BladeRunIdKind.EventOwner
        ),
        plane: _BladeCombatRuntimePlane(_gameplay_plane),
        actors: [],
        attacks: [],
        projectiles: [],
        damage_transactions: [],
        pending_terminals: [],
        terminal_records: [],
        reward_requests: [],
        active_tick: undefined,
        active_kernel: undefined,
    };
}

/// @func BladeCombatRuntimeConfigurePlane(runtime, gameplay_plane)
/// Installs one authoritative plane only between ticks and before the first emission.
function BladeCombatRuntimeConfigurePlane(_runtime, _gameplay_plane) {
    _BladeCombatRuntimeRequire(_runtime);
    if (!is_undefined(_runtime.active_tick) || array_length(_runtime.attacks) > 0
        || array_length(_runtime.projectiles) > 0) {
        _BladeCombatRuntimeFail("plane", "can change only between ticks before emission");
    }
    _runtime.plane = _BladeCombatRuntimePlane(_gameplay_plane);
    return BladeCombatPlaneCopy(_runtime.plane);
}

/// @func BladeCombatRuntimePlaneCopy(runtime)
/// Returns the compiled plane for fresh-attempt construction, or undefined when unconfigured.
function BladeCombatRuntimePlaneCopy(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    return is_undefined(_runtime.plane) ? undefined : BladeCombatPlaneCopy(_runtime.plane);
}

/// @func BladeCombatRuntimeRegisterActor(runtime, instance_id, content_id, faction, health, box, invulnerable_until, reward_on_defeat, child_spec, simulation_tick, combat_tick)
/// Attaches one already allocated run actor between ticks without inventing another identity source.
function BladeCombatRuntimeRegisterActor(
    _runtime, _instance_id, _content_id, _faction, _health, _box,
    _invulnerable_until_combat_tick = 0, _reward_on_defeat = false,
    _child_spec = undefined, _simulation_tick = 0, _combat_tick = 0
) {
    _BladeCombatRuntimeRequire(_runtime);
    if (!is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("actor", "registration must occur between ticks");
    }
    var _actor = _BladeCombatRuntimeActor(
        _runtime, _instance_id, _content_id, _faction, _health, _box,
        _invulnerable_until_combat_tick, _reward_on_defeat, _child_spec,
        _simulation_tick, _combat_tick
    );
    if (_BladeCombatRuntimeFind(_runtime.actors, "instance_id", _actor.instance_id) >= 0) {
        _BladeCombatRuntimeFail("actor", "duplicate " + _actor.instance_id);
    }
    var _ordinal = _BladeCombatRuntimeIdOrdinal(
        _runtime, _actor.instance_id, BladeRunIdKind.Instance
    );
    var _insert = array_length(_runtime.actors);
    for (var _index = 0; _index < array_length(_runtime.actors); ++_index) {
        if (_ordinal < _BladeCombatRuntimeIdOrdinal(
            _runtime, _runtime.actors[_index].instance_id, BladeRunIdKind.Instance
        )) {
            _insert = _index;
            break;
        }
    }
    array_insert(_runtime.actors, _insert, _actor);
    return _BladeCombatRuntimeClone(_actor);
}

/// @func BladeCombatRuntimeSpawnActor(runtime, content_id, faction, health, box, invulnerable_until, reward_on_defeat, child_spec, simulation_tick, combat_tick)
/// Validates all actor fields before allocating its run-local instance ID.
function BladeCombatRuntimeSpawnActor(
    _runtime, _content_id, _faction, _health, _box,
    _invulnerable_until_combat_tick = 0, _reward_on_defeat = false,
    _child_spec = undefined, _simulation_tick = 0, _combat_tick = 0
) {
    _BladeCombatRuntimeRequire(_runtime);
    if (!is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("actor", "spawn must occur between ticks");
    }
    var _validated_content = BladeRunIdentityRequireContent(_runtime.identity, _content_id);
    var _validated_faction = _BladeCombatRuntimeInteger(
        _faction, BladeCombatFaction.Player, BladeCombatFaction.Enemy, "actor faction"
    );
    var _validated_health = _BladeCombatRuntimeInteger(
        _health, 1, int64("2147483647"), "actor health"
    );
    var _validated_box = _BladeCombatGeometryAabbCopy(_box);
    var _validated_invulnerability = _BladeCombatRuntimeInteger(
        _invulnerable_until_combat_tick,
        0, int64("9223372036854775807"), "actor invulnerability"
    );
    var _validated_reward = _BladeCombatRuntimeBoolean(
        _reward_on_defeat, "actor reward policy"
    );
    var _validated_child = _BladeCombatRuntimeChildSpec(_runtime, _child_spec);
    var _validated_simulation_tick = _BladeCombatRuntimeInteger(
        _simulation_tick, 0, int64("9223372036854775807"), "actor spawn tick"
    );
    var _validated_combat_tick = _BladeCombatRuntimeInteger(
        _combat_tick, 0, int64("9223372036854775807"), "actor spawn combat tick"
    );
    var _instance_id = BladeRunIdentityAllocateForContent(
        _runtime.identity, BladeRunIdKind.Instance, _validated_content
    );
    return BladeCombatRuntimeRegisterActor(
        _runtime, _instance_id, _validated_content, _validated_faction,
        _validated_health, _validated_box,
        _validated_invulnerability, _validated_reward,
        _validated_child, _validated_simulation_tick, _validated_combat_tick
    );
}

/// Validates and detaches one attack/projectile payload before any ID allocation.
function _BladeCombatRuntimeOffenseSpec(_spec) {
    if (!is_struct(_spec)) {
        _BladeCombatRuntimeFail("offense specification", "must be a struct");
    }
    return {
        damage: _BladeCombatRuntimeInteger(
            _spec.damage, 1, int64("2147483647"), "damage"
        ),
        cancellation_policy: _BladeCombatRuntimeInteger(
            _spec.cancellation_policy,
            BladeCombatCancellationPolicy.Ignore,
            BladeCombatCancellationPolicy.Symmetric,
            "cancellation policy"
        ),
        cancellation_power: _BladeCombatRuntimeInteger(
            _spec.cancellation_power, 0, int64("2147483647"), "cancellation power"
        ),
        penetration: _BladeCombatRuntimeInteger(
            _spec.penetration, 0, int64("2147483647"), "penetration"
        ),
        hit_budget: _BladeCombatRuntimeInteger(
            _spec.hit_budget, 1, int64("2147483647"), "hit budget"
        ),
        lifetime_combat_ticks: _BladeCombatRuntimeInteger(
            _spec.lifetime_combat_ticks, 1, int64("2147483647"), "combat lifetime"
        ),
    };
}

/// @func BladeCombatOffenseSpecCreate(damage, cancellation_policy, cancellation_power, penetration, hit_budget, lifetime_combat_ticks)
/// Creates plain caller-owned offense data validated again at the runtime boundary.
function BladeCombatOffenseSpecCreate(
    _damage, _cancellation_policy, _cancellation_power,
    _penetration, _hit_budget, _lifetime_combat_ticks
) {
    return {
        damage: _damage,
        cancellation_policy: _cancellation_policy,
        cancellation_power: _cancellation_power,
        penetration: _penetration,
        hit_budget: _hit_budget,
        lifetime_combat_ticks: _lifetime_combat_ticks,
    };
}

/// Requires one currently open tick containing the requested domain bit.
function _BladeCombatRuntimeRequireTick(_runtime, _domain, _field) {
    _BladeCombatRuntimeRequire(_runtime);
    if (is_undefined(_runtime.active_tick)
        || (_runtime.active_tick.domain_mask & _domain) == 0) {
        _BladeCombatRuntimeFail(_field, "requires its eligible simulation tick");
    }
    return _runtime.active_tick;
}

/// Queues one gameplay event through the currently owned kernel tick.
function _BladeCombatRuntimeQueueEvent(
    _runtime, _order, _type, _reason,
    _source_id, _target_id, _content_id, _payload = []
) {
    if (is_undefined(_runtime.active_kernel)) {
        _BladeCombatRuntimeFail("event", "requires an active kernel tick");
    }
    return BladeKernelQueueEvent(
        _runtime.active_kernel, BladeEventChannel.Gameplay, _order,
        _type, _reason, _source_id, _target_id,
        _runtime.event_owner_id, _content_id, _payload
    );
}

/// Begins one coordinator-owned tick and prepares eligible motion history.
function _BladeCombatRuntimeBeginTick(_runtime, _kernel, _tick) {
    _BladeCombatRuntimeRequire(_runtime);
    _BladeKernelRequire(_kernel);
    if (!is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("tick", "the prior combat tick remains open");
    }
    var _view = _BladeRunCoordinatorTickView(_tick);
    _runtime.active_tick = _view;
    _runtime.active_kernel = _kernel;
    if ((_view.domain_mask & BladeClockDomain.Combat) != 0) {
        for (var _index = 0; _index < array_length(_runtime.actors); ++_index) {
            _runtime.actors[_index].previous_box = _BladeCombatGeometryAabbCopy(
                _runtime.actors[_index].current_box
            );
            _runtime.actors[_index].recent_attack_ids = [];
        }
        for (var _index = 0; _index < array_length(_runtime.projectiles); ++_index) {
            _runtime.projectiles[_index].previous_box = _BladeCombatGeometryAabbCopy(
                _runtime.projectiles[_index].current_box
            );
        }
    }
    return _BladeCombatRuntimeClone(_view);
}

/// Clears only transient tick references after a rejected client callback.
function _BladeCombatRuntimeCancelTick(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    _runtime.active_tick = undefined;
    _runtime.active_kernel = undefined;
}

/// @func BladeCombatRuntimeSetActorBox(runtime, instance_id, box)
/// Updates an actor pose on Actor time while retaining combat-owned hurtbox history.
function BladeCombatRuntimeSetActorBox(_runtime, _instance_id, _box) {
    _BladeCombatRuntimeRequireTick(_runtime, BladeClockDomain.Actor, "actor pose");
    var _index = _BladeCombatRuntimeFind(_runtime.actors, "instance_id", _instance_id);
    if (_index < 0) _BladeCombatRuntimeFail("actor", "unknown active " + string(_instance_id));
    _runtime.actors[_index].current_box = _BladeCombatGeometryAabbCopy(_box);
    return _BladeCombatRuntimeClone(_runtime.actors[_index]);
}

/// Allocates one attack/projectile pair only after all validation and any enemy gate pass.
function _BladeCombatRuntimeEmit(
    _runtime, _owner_id, _faction, _spec, _projectile_box,
    _requires_gate, _gate_kind = undefined, _gate_geometry = undefined
) {
    var _tick = _BladeCombatRuntimeRequireTick(
        _runtime, BladeClockDomain.Combat, "emission"
    );
    var _owner_index = _BladeCombatRuntimeFind(_runtime.actors, "instance_id", _owner_id);
    if (_owner_index < 0) {
        _BladeCombatRuntimeFail("emission owner", "must be an active actor");
    }
    var _owner = _runtime.actors[_owner_index];
    var _validated_faction = _BladeCombatRuntimeInteger(
        _faction, BladeCombatFaction.Player, BladeCombatFaction.Enemy, "emission faction"
    );
    if (_owner.faction != _validated_faction) {
        _BladeCombatRuntimeFail("emission faction", "must match its owner");
    }
    var _validated_spec = _BladeCombatRuntimeOffenseSpec(_spec);
    var _box = _BladeCombatGeometryAabbCopy(_projectile_box);
    if (_requires_gate) {
        if (_validated_faction != BladeCombatFaction.Enemy) {
            _BladeCombatRuntimeFail("enemy emission", "requires the enemy faction");
        }
        if (is_undefined(_runtime.plane)) {
            _BladeCombatRuntimeFail("enemy emission", "requires a configured product plane");
        }
        if (!BladeCombatEmissionGateAllows(
            _runtime.plane, _gate_kind, _gate_geometry
        )) {
            return { authorized: false, attack_id: "", projectile_id: "" };
        }
    }

    var _attack_id = BladeRunIdentityAllocate(_runtime.identity, BladeRunIdKind.Attack);
    var _projectile_id = BladeRunIdentityAllocate(
        _runtime.identity, BladeRunIdKind.Bullet
    );
    var _attack = {
        attack_id: _attack_id,
        faction: _validated_faction,
        owner_entity_id: _owner.instance_id,
        content_id: _owner.content_id,
        spawn_simulation_tick: _tick.simulation_tick,
        spawn_combat_tick: _tick.combat_tick,
        damage: _validated_spec.damage,
        cancellation_policy: _validated_spec.cancellation_policy,
        cancellation_power: _validated_spec.cancellation_power,
        penetration_remaining: _validated_spec.penetration,
        hit_budget_remaining: _validated_spec.hit_budget,
        lifetime_combat_ticks: _validated_spec.lifetime_combat_ticks,
        terminal_reason: BladeCombatTerminalReason.None,
    };
    var _projectile = {
        projectile_id: _projectile_id,
        attack_id: _attack_id,
        faction: _validated_faction,
        owner_entity_id: _owner.instance_id,
        content_id: _owner.content_id,
        spawn_simulation_tick: _tick.simulation_tick,
        spawn_combat_tick: _tick.combat_tick,
        damage: _validated_spec.damage,
        cancellation_policy: _validated_spec.cancellation_policy,
        cancellation_power: _validated_spec.cancellation_power,
        penetration_remaining: _validated_spec.penetration,
        hit_budget_remaining: _validated_spec.hit_budget,
        lifetime_combat_ticks: _validated_spec.lifetime_combat_ticks,
        terminal_reason: BladeCombatTerminalReason.None,
        previous_box: _BladeCombatGeometryAabbCopy(_box),
        current_box: _BladeCombatGeometryAabbCopy(_box),
        hit_target_ids: [],
    };
    array_push(_runtime.attacks, _attack);
    array_push(_runtime.projectiles, _projectile);
    _BladeCombatRuntimeQueueEvent(
        _runtime, 100, "attack.started", "outcome.scheduled",
        _owner.instance_id, _attack_id, _owner.content_id,
        [BladeEventPayload("damage", "i32", _validated_spec.damage)]
    );
    _BladeCombatRuntimeQueueEvent(
        _runtime, 110, "bullet.spawned", "outcome.pattern_emitted",
        _attack_id, _projectile_id, _owner.content_id,
        [BladeEventPayload("damage", "i32", _validated_spec.damage)]
    );
    return {
        authorized: true,
        attack_id: _attack_id,
        projectile_id: _projectile_id,
    };
}

/// @func BladeCombatRuntimeEnemyEmit(runtime, owner_id, spec, projectile_box, gate_kind, gate_geometry)
/// Routes every enemy attempt through the central plane gate before allocation or events.
function BladeCombatRuntimeEnemyEmit(
    _runtime, _owner_id, _spec, _projectile_box, _gate_kind, _gate_geometry
) {
    return _BladeCombatRuntimeEmit(
        _runtime, _owner_id, BladeCombatFaction.Enemy,
        _spec, _projectile_box, true, _gate_kind, _gate_geometry
    );
}

/// @func BladeCombatRuntimePlayerEmit(runtime, owner_id, spec, projectile_box)
/// Creates one player-owned attack/projectile pair without applying the enemy plane rule.
function BladeCombatRuntimePlayerEmit(_runtime, _owner_id, _spec, _projectile_box) {
    return _BladeCombatRuntimeEmit(
        _runtime, _owner_id, BladeCombatFaction.Player,
        _spec, _projectile_box, false
    );
}

/// @func BladeCombatRuntimeMoveProjectile(runtime, projectile_id, box)
/// Updates one active projectile only on eligible Combat time.
function BladeCombatRuntimeMoveProjectile(_runtime, _projectile_id, _box) {
    _BladeCombatRuntimeRequireTick(_runtime, BladeClockDomain.Combat, "projectile motion");
    var _index = _BladeCombatRuntimeFind(
        _runtime.projectiles, "projectile_id", _projectile_id
    );
    if (_index < 0) {
        _BladeCombatRuntimeFail("projectile", "unknown active " + string(_projectile_id));
    }
    _runtime.projectiles[_index].current_box = _BladeCombatGeometryAabbCopy(_box);
    return _BladeCombatRuntimeClone(_runtime.projectiles[_index]);
}

/// @func BladeCombatRuntimeRequestTerminal(runtime, subject_kind, subject_id, reason)
/// Queues one idempotent reason request for the current Combat tick.
function BladeCombatRuntimeRequestTerminal(
    _runtime, _subject_kind, _subject_id, _reason
) {
    var _tick = _BladeCombatRuntimeRequireTick(
        _runtime, BladeClockDomain.Combat, "terminal request"
    );
    return _BladeCombatResolutionQueueTerminal(
        _runtime, _subject_kind, _subject_id, _reason,
        _tick.simulation_tick, _tick.combat_tick
    );
}

/// Completes one internal tick through deterministic resolution and clears transient ownership.
function _BladeCombatRuntimeEndTick(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    if (is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("tick", "no combat tick is open");
    }
    try {
        return BladeCombatResolutionEndTick(_runtime);
    } finally {
        _runtime.active_tick = undefined;
        _runtime.active_kernel = undefined;
    }
}

/// @func BladeCombatRuntimeSnapshot(runtime)
/// Returns detached combat collections while omitting the identity and transient kernel reference.
function BladeCombatRuntimeSnapshot(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    return {
        plane: is_undefined(_runtime.plane)
            ? undefined : BladeCombatPlaneCopy(_runtime.plane),
        actors: _BladeCombatRuntimeClone(_runtime.actors),
        attacks: _BladeCombatRuntimeClone(_runtime.attacks),
        projectiles: _BladeCombatRuntimeClone(_runtime.projectiles),
        damage_transactions: _BladeCombatRuntimeClone(_runtime.damage_transactions),
        pending_terminals: _BladeCombatRuntimeClone(_runtime.pending_terminals),
        terminal_records: _BladeCombatRuntimeClone(_runtime.terminal_records),
        reward_requests: _BladeCombatRuntimeClone(_runtime.reward_requests),
        tick_open: !is_undefined(_runtime.active_tick),
    };
}
