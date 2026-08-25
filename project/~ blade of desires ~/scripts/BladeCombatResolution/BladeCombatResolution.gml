/// @description Deterministic resolution procedures over the run-owned combat runtime.

/// Validates one terminal subject kind and maps it to the shared identity kind.
function _BladeCombatResolutionIdentityKind(_subject_kind) {
    switch (_BladeCombatRuntimeInteger(
        _subject_kind, BladeCombatSubjectKind.Actor,
        BladeCombatSubjectKind.Projectile, "terminal subject kind"
    )) {
        case BladeCombatSubjectKind.Actor: return BladeRunIdKind.Instance;
        case BladeCombatSubjectKind.Attack: return BladeRunIdKind.Attack;
        case BladeCombatSubjectKind.Projectile: return BladeRunIdKind.Bullet;
    }
    _BladeCombatRuntimeFail("terminal subject kind", "is unreachable");
}

/// Rejects terminal reasons that cannot apply to the selected subject kind.
function _BladeCombatResolutionReason(_subject_kind, _reason) {
    var _kind = _BladeCombatResolutionIdentityKind(_subject_kind);
    var _validated = _BladeCombatRuntimeInteger(
        _reason, BladeCombatTerminalReason.OutOfBounds,
        BladeCombatTerminalReason.StageEnd, "terminal reason"
    );
    if (_validated == BladeCombatTerminalReason.Defeat
        && _kind != BladeRunIdKind.Instance) {
        _BladeCombatRuntimeFail("terminal reason", "defeat requires an actor");
    }
    if ((_validated == BladeCombatTerminalReason.ProjectileCancellation
            || _validated == BladeCombatTerminalReason.HitBudgetExhausted
            || _validated == BladeCombatTerminalReason.OutOfBounds)
        && _kind != BladeRunIdKind.Bullet) {
        _BladeCombatRuntimeFail("terminal reason", "requires a projectile");
    }
    if (_validated == BladeCombatTerminalReason.Expiration
        && _kind == BladeRunIdKind.Instance) {
        _BladeCombatRuntimeFail("terminal reason", "actor expiration is not declared");
    }
    return _validated;
}

/// @func BladeCombatResolutionQueueTerminal(runtime, subject_kind, subject_id, reason, simulation_tick, combat_tick)
/// Queues one detached idempotent request without selecting a winner early.
function _BladeCombatResolutionQueueTerminal(
    _runtime, _subject_kind, _subject_id, _reason,
    _simulation_tick, _combat_tick
) {
    _BladeCombatRuntimeRequire(_runtime);
    var _identity_kind = _BladeCombatResolutionIdentityKind(_subject_kind);
    var _validated_reason = _BladeCombatResolutionReason(_subject_kind, _reason);
    var _request = {
        subject_kind: int64(_subject_kind),
        subject_id: BladeRunIdentityRequireAllocated(
            _runtime.identity, _subject_id, _identity_kind
        ),
        reason: _validated_reason,
        simulation_tick: _BladeCombatRuntimeInteger(
            _simulation_tick, 0, int64("9223372036854775807"), "terminal simulation tick"
        ),
        combat_tick: _BladeCombatRuntimeInteger(
            _combat_tick, 0, int64("9223372036854775807"), "terminal combat tick"
        ),
    };
    for (var _index = 0; _index < array_length(_runtime.pending_terminals); ++_index) {
        var _existing = _runtime.pending_terminals[_index];
        if (_existing.subject_kind == _request.subject_kind
            && _existing.subject_id == _request.subject_id
            && _existing.reason == _request.reason) {
            return { queued: false, request: _BladeCombatRuntimeClone(_existing) };
        }
    }
    array_push(_runtime.pending_terminals, _request);
    return { queued: true, request: _BladeCombatRuntimeClone(_request) };
}

/// Reports whether any terminal request already targets one active subject.
function _BladeCombatResolutionPending(_runtime, _subject_kind, _subject_id) {
    for (var _index = 0; _index < array_length(_runtime.pending_terminals); ++_index) {
        var _request = _runtime.pending_terminals[_index];
        if (_request.subject_kind == _subject_kind
            && _request.subject_id == _subject_id) return true;
    }
    return false;
}

/// Applies cancellation pairs before hit discovery so cancelled bullets cannot deal later damage.
function _BladeCombatResolutionCancellation(_runtime, _tick) {
    for (var _left_index = 0;
        _left_index < array_length(_runtime.projectiles); ++_left_index) {
        var _left = _runtime.projectiles[_left_index];
        if (_BladeCombatResolutionPending(
            _runtime, BladeCombatSubjectKind.Projectile, _left.projectile_id
        )) continue;
        for (var _right_index = _left_index + 1;
            _right_index < array_length(_runtime.projectiles); ++_right_index) {
            if (_BladeCombatResolutionPending(
                _runtime, BladeCombatSubjectKind.Projectile, _left.projectile_id
            )) break;
            var _right = _runtime.projectiles[_right_index];
            if (_BladeCombatResolutionPending(
                _runtime, BladeCombatSubjectKind.Projectile, _right.projectile_id
            ) || !BladeCombatAabbOverlaps(_left.current_box, _right.current_box)) continue;
            var _outcome = BladeCombatCancellationResolve(_left, _right);
            if (!_outcome.interacted) continue;
            var _first_index = _BladeCombatRuntimeFind(
                _runtime.projectiles, "projectile_id", _outcome.first.projectile_id
            );
            var _second_index = _BladeCombatRuntimeFind(
                _runtime.projectiles, "projectile_id", _outcome.second.projectile_id
            );
            _runtime.projectiles[_first_index].penetration_remaining
                = _outcome.first.penetration_after;
            _runtime.projectiles[_second_index].penetration_remaining
                = _outcome.second.penetration_after;
            if (_outcome.first.cancelled) _BladeCombatResolutionQueueTerminal(
                _runtime, BladeCombatSubjectKind.Projectile,
                _outcome.first.projectile_id,
                BladeCombatTerminalReason.ProjectileCancellation,
                _tick.simulation_tick, _tick.combat_tick
            );
            if (_outcome.second.cancelled) _BladeCombatResolutionQueueTerminal(
                _runtime, BladeCombatSubjectKind.Projectile,
                _outcome.second.projectile_id,
                BladeCombatTerminalReason.ProjectileCancellation,
                _tick.simulation_tick, _tick.combat_tick
            );
        }
    }
}

/// Discovers all opposing-faction swept candidates without mutating health.
function _BladeCombatResolutionDiscoverHits(_runtime) {
    var _candidates = [];
    for (var _projectile_index = 0;
        _projectile_index < array_length(_runtime.projectiles); ++_projectile_index) {
        var _projectile = _runtime.projectiles[_projectile_index];
        if (_BladeCombatResolutionPending(
            _runtime, BladeCombatSubjectKind.Projectile, _projectile.projectile_id
        )) continue;
        for (var _actor_index = 0;
            _actor_index < array_length(_runtime.actors); ++_actor_index) {
            var _actor = _runtime.actors[_actor_index];
            if (_projectile.faction == _actor.faction) continue;
            var _candidate = BladeCombatGeometrySweep(
                _projectile.projectile_id, _actor.instance_id,
                _projectile.previous_box, _projectile.current_box,
                _actor.previous_box, _actor.current_box
            );
            if (!is_undefined(_candidate)) array_push(_candidates, _candidate);
        }
    }
    return BladeCombatGeometrySortCandidates(_candidates);
}

/// Applies accepted sorted hits exactly once and queues any resulting terminal reasons.
function _BladeCombatResolutionDamage(_runtime, _tick, _candidates) {
    for (var _index = 0; _index < array_length(_candidates); ++_index) {
        var _candidate = _candidates[_index];
        var _projectile_index = _BladeCombatRuntimeFind(
            _runtime.projectiles, "projectile_id", _candidate.projectile_id
        );
        var _actor_index = _BladeCombatRuntimeFind(
            _runtime.actors, "instance_id", _candidate.target_id
        );
        if (_projectile_index < 0 || _actor_index < 0) continue;
        var _projectile = _runtime.projectiles[_projectile_index];
        var _actor = _runtime.actors[_actor_index];
        if (_BladeCombatResolutionPending(
                _runtime, BladeCombatSubjectKind.Projectile, _projectile.projectile_id
            )
            || _projectile.faction == _actor.faction
            || _actor.health <= 0
            || _tick.combat_tick < _actor.invulnerable_until_combat_tick
            || _BladeCombatRuntimeArrayContains(
                _projectile.hit_target_ids, _actor.instance_id
            )
            || _BladeCombatRuntimeArrayContains(
                _actor.recent_attack_ids, _projectile.attack_id
            )) continue;

        var _before = _actor.health;
        var _applied = min(_before, _projectile.damage);
        var _damage_id = BladeRunIdentityAllocate(
            _runtime.identity, BladeRunIdKind.DamageEvent
        );
        _actor.health -= _applied;
        array_push(_actor.recent_attack_ids, _projectile.attack_id);
        array_push(_projectile.hit_target_ids, _actor.instance_id);
        _projectile.hit_budget_remaining -= int64(1);
        var _transaction = {
            damage_id: _damage_id,
            projectile_id: _projectile.projectile_id,
            attack_id: _projectile.attack_id,
            target_id: _actor.instance_id,
            simulation_tick: _tick.simulation_tick,
            combat_tick: _tick.combat_tick,
            requested_amount: _projectile.damage,
            applied_amount: _applied,
            health_before: _before,
            health_after: _actor.health,
        };
        array_push(_runtime.damage_transactions, _transaction);
        _BladeCombatRuntimeQueueEvent(
            _runtime, 200, "damage.transaction_applied",
            "outcome.collision_confirmed", _damage_id, _actor.instance_id,
            _actor.content_id,
            [
                BladeEventPayload("applied", "i32", _applied),
                BladeEventPayload("health_after", "i32", _actor.health),
                BladeEventPayload("health_before", "i32", _before),
            ]
        );
        if (_actor.health == 0) _BladeCombatResolutionQueueTerminal(
            _runtime, BladeCombatSubjectKind.Actor, _actor.instance_id,
            BladeCombatTerminalReason.Defeat,
            _tick.simulation_tick, _tick.combat_tick
        );
        if (_projectile.hit_budget_remaining == 0) _BladeCombatResolutionQueueTerminal(
            _runtime, BladeCombatSubjectKind.Projectile, _projectile.projectile_id,
            BladeCombatTerminalReason.HitBudgetExhausted,
            _tick.simulation_tick, _tick.combat_tick
        );
    }
}

/// Queues lifetime, offscreen, and owner-removal reasons after damage discovery.
function _BladeCombatResolutionAutomaticTerminals(_runtime, _tick) {
    for (var _index = 0; _index < array_length(_runtime.attacks); ++_index) {
        var _attack = _runtime.attacks[_index];
        if (_tick.combat_tick - _attack.spawn_combat_tick
            >= _attack.lifetime_combat_ticks) {
            _BladeCombatResolutionQueueTerminal(
                _runtime, BladeCombatSubjectKind.Attack, _attack.attack_id,
                BladeCombatTerminalReason.Expiration,
                _tick.simulation_tick, _tick.combat_tick
            );
        }
    }
    for (var _index = 0; _index < array_length(_runtime.projectiles); ++_index) {
        var _projectile = _runtime.projectiles[_index];
        if (!is_undefined(_runtime.plane)
            && !BladeCombatAabbIntersectsPlane(
                _runtime.plane, _projectile.current_box
            )) {
            _BladeCombatResolutionQueueTerminal(
                _runtime, BladeCombatSubjectKind.Projectile,
                _projectile.projectile_id,
                BladeCombatTerminalReason.OutOfBounds,
                _tick.simulation_tick, _tick.combat_tick
            );
        }
        if (_tick.combat_tick - _projectile.spawn_combat_tick
            >= _projectile.lifetime_combat_ticks) {
            _BladeCombatResolutionQueueTerminal(
                _runtime, BladeCombatSubjectKind.Projectile,
                _projectile.projectile_id,
                BladeCombatTerminalReason.Expiration,
                _tick.simulation_tick, _tick.combat_tick
            );
        }
    }
    var _actor_requests = _BladeCombatRuntimeClone(_runtime.pending_terminals);
    for (var _request_index = 0;
        _request_index < array_length(_actor_requests); ++_request_index) {
        var _request = _actor_requests[_request_index];
        if (_request.subject_kind != BladeCombatSubjectKind.Actor) continue;
        for (var _index = 0; _index < array_length(_runtime.attacks); ++_index) {
            if (_runtime.attacks[_index].owner_entity_id == _request.subject_id) {
                _BladeCombatResolutionQueueTerminal(
                    _runtime, BladeCombatSubjectKind.Attack,
                    _runtime.attacks[_index].attack_id,
                    BladeCombatTerminalReason.OwnerRemoval,
                    _request.simulation_tick, _request.combat_tick
                );
            }
        }
        for (var _index = 0; _index < array_length(_runtime.projectiles); ++_index) {
            if (_runtime.projectiles[_index].owner_entity_id == _request.subject_id) {
                _BladeCombatResolutionQueueTerminal(
                    _runtime, BladeCombatSubjectKind.Projectile,
                    _runtime.projectiles[_index].projectile_id,
                    BladeCombatTerminalReason.OwnerRemoval,
                    _request.simulation_tick, _request.combat_tick
                );
            }
        }
    }
}

/// Reports whether one request outranks the current winner for the same subject.
function _BladeCombatResolutionRequestWins(_candidate, _current) {
    var _candidate_priority = _BladeCombatRuntimeTerminalPriority(_candidate.reason);
    var _current_priority = _BladeCombatRuntimeTerminalPriority(_current.reason);
    if (_candidate_priority != _current_priority) {
        return _candidate_priority > _current_priority;
    }
    if (_candidate.reason != _current.reason) return _candidate.reason > _current.reason;
    if (_candidate.simulation_tick != _current.simulation_tick) {
        return _candidate.simulation_tick < _current.simulation_tick;
    }
    return _candidate.combat_tick < _current.combat_tick;
}

/// Selects one winner per subject and sorts winners by kind then numeric ID.
function _BladeCombatResolutionWinners(_runtime, _requests) {
    var _winners = [];
    for (var _index = 0; _index < array_length(_requests); ++_index) {
        var _candidate = _requests[_index];
        var _winner_index = -1;
        for (var _scan = 0; _scan < array_length(_winners); ++_scan) {
            if (_winners[_scan].subject_kind == _candidate.subject_kind
                && _winners[_scan].subject_id == _candidate.subject_id) {
                _winner_index = _scan;
                break;
            }
        }
        if (_winner_index < 0) {
            array_push(_winners, _BladeCombatRuntimeClone(_candidate));
        } else if (_BladeCombatResolutionRequestWins(
            _candidate, _winners[_winner_index]
        )) {
            _winners[_winner_index] = _BladeCombatRuntimeClone(_candidate);
        }
    }
    var _sorted = [];
    for (var _index = 0; _index < array_length(_winners); ++_index) {
        var _winner = _winners[_index];
        var _ordinal = _BladeCombatRuntimeIdOrdinal(
            _runtime, _winner.subject_id,
            _BladeCombatResolutionIdentityKind(_winner.subject_kind)
        );
        var _insert = array_length(_sorted);
        for (var _scan = 0; _scan < array_length(_sorted); ++_scan) {
            var _scan_ordinal = _BladeCombatRuntimeIdOrdinal(
                _runtime, _sorted[_scan].subject_id,
                _BladeCombatResolutionIdentityKind(_sorted[_scan].subject_kind)
            );
            if (_winner.subject_kind < _sorted[_scan].subject_kind
                || (_winner.subject_kind == _sorted[_scan].subject_kind
                    && _ordinal < _scan_ordinal)) {
                _insert = _scan;
                break;
            }
        }
        array_insert(_sorted, _insert, _winner);
    }
    return _sorted;
}

/// Returns one subject's active collection, ID field, index, and content ID.
function _BladeCombatResolutionSubject(_runtime, _request) {
    var _records;
    var _id_field;
    switch (_request.subject_kind) {
        case BladeCombatSubjectKind.Actor:
            _records = _runtime.actors;
            _id_field = "instance_id";
            break;
        case BladeCombatSubjectKind.Attack:
            _records = _runtime.attacks;
            _id_field = "attack_id";
            break;
        case BladeCombatSubjectKind.Projectile:
            _records = _runtime.projectiles;
            _id_field = "projectile_id";
            break;
    }
    var _index = _BladeCombatRuntimeFind(_records, _id_field, _request.subject_id);
    return {
        records: _records,
        id_field: _id_field,
        index: _index,
        record: _index < 0 ? undefined : _records[_index],
    };
}

/// Queues the generic event corresponding to one selected normal-tick terminal.
function _BladeCombatResolutionTerminalEvent(_runtime, _terminal) {
    var _type;
    switch (_terminal.subject_kind) {
        case BladeCombatSubjectKind.Actor: _type = "instance.removed"; break;
        case BladeCombatSubjectKind.Attack: _type = "attack.cancelled"; break;
        case BladeCombatSubjectKind.Projectile: _type = "bullet.removed"; break;
    }
    _BladeCombatRuntimeQueueEvent(
        _runtime, 400 + _terminal.subject_kind,
        _type, BladeCombatTerminalReasonToken(_terminal.reason),
        _terminal.subject_id, "", _terminal.content_id, []
    );
}

/// Removes every selected subject while preserving unselected allocation order.
function _BladeCombatResolutionRemoveSelected(
    _records, _id_field, _kind, _winners
) {
    var _remaining = [];
    for (var _index = 0; _index < array_length(_records); ++_index) {
        var _remove = false;
        var _id = variable_struct_get(_records[_index], _id_field);
        for (var _winner_index = 0;
            _winner_index < array_length(_winners); ++_winner_index) {
            if (_winners[_winner_index].subject_kind == _kind
                && _winners[_winner_index].subject_id == _id) {
                _remove = true;
                break;
            }
        }
        if (!_remove) array_push(_remaining, _records[_index]);
    }
    return _remaining;
}

/// Commits stable winners, then derives defeat-only rewards and child actors.
function _BladeCombatResolutionCommit(
    _runtime, _requests, _emit_events, _derive_defeat
) {
    var _winners = _BladeCombatResolutionWinners(_runtime, _requests);
    var _child_plans = [];
    var _reward_plans = [];
    var _selected = [];
    for (var _index = 0; _index < array_length(_winners); ++_index) {
        var _winner = _winners[_index];
        var _subject = _BladeCombatResolutionSubject(_runtime, _winner);
        if (_subject.index < 0) continue;
        if (_winner.subject_kind != BladeCombatSubjectKind.Actor) {
            _subject.record.terminal_reason = _winner.reason;
        }
        var _terminal = _BladeCombatRuntimeClone(_winner);
        _terminal.content_id = _subject.record.content_id;
        array_push(_runtime.terminal_records, _terminal);
        array_push(_selected, _terminal);
        if (_emit_events) _BladeCombatResolutionTerminalEvent(_runtime, _terminal);
        if (_derive_defeat
            && _winner.subject_kind == BladeCombatSubjectKind.Actor
            && _winner.reason == BladeCombatTerminalReason.Defeat) {
            if (_subject.record.health != 0) {
                _BladeCombatRuntimeFail("defeat", "requires zero actor health");
            }
            if (_subject.record.reward_on_defeat) {
                array_push(_reward_plans, {
                    source_actor_id: _subject.record.instance_id,
                    content_id: _subject.record.content_id,
                    simulation_tick: _winner.simulation_tick,
                    combat_tick: _winner.combat_tick,
                });
            }
            if (!is_undefined(_subject.record.child_spec)) {
                array_push(_child_plans, {
                    parent_actor_id: _subject.record.instance_id,
                    parent_content_id: _subject.record.content_id,
                    spec: _BladeCombatRuntimeClone(_subject.record.child_spec),
                    simulation_tick: _winner.simulation_tick,
                    combat_tick: _winner.combat_tick,
                });
            }
        }
    }
    _runtime.actors = _BladeCombatResolutionRemoveSelected(
        _runtime.actors, "instance_id", BladeCombatSubjectKind.Actor, _selected
    );
    _runtime.attacks = _BladeCombatResolutionRemoveSelected(
        _runtime.attacks, "attack_id", BladeCombatSubjectKind.Attack, _selected
    );
    _runtime.projectiles = _BladeCombatResolutionRemoveSelected(
        _runtime.projectiles, "projectile_id", BladeCombatSubjectKind.Projectile, _selected
    );
    _runtime.pending_terminals = [];

    var _children = [];
    for (var _plan_index = 0;
        _plan_index < array_length(_child_plans); ++_plan_index) {
        var _plan = _child_plans[_plan_index];
        for (var _ordinal = 1; _ordinal <= _plan.spec.count; ++_ordinal) {
            var _child_id = BladeRunIdentityAllocateForContent(
                _runtime.identity, BladeRunIdKind.Instance, _plan.spec.content_id
            );
            var _child = _BladeCombatRuntimeActor(
                _runtime, _child_id, _plan.spec.content_id,
                _plan.spec.faction, _plan.spec.health, _plan.spec.box,
                _plan.spec.invulnerable_until_combat_tick,
                _plan.spec.reward_on_defeat, _plan.spec.child_spec,
                _plan.simulation_tick, _plan.combat_tick
            );
            array_push(_runtime.actors, _child);
            array_push(_children, _child);
            if (_emit_events) _BladeCombatRuntimeQueueEvent(
                _runtime, 500, "instance.spawned", "outcome.defeat_child",
                _plan.parent_actor_id, _child.instance_id,
                _child.content_id, [BladeEventPayload("child_ordinal", "i32", _ordinal)]
            );
        }
    }
    for (var _index = 0; _index < array_length(_reward_plans); ++_index) {
        var _reward = _reward_plans[_index];
        _reward.reason = BladeCombatTerminalReason.Defeat;
        array_push(_runtime.reward_requests, _reward);
        if (_emit_events) _BladeCombatRuntimeQueueEvent(
            _runtime, 600, "reward.requested", "outcome.defeated",
            _reward.source_actor_id, "", _reward.content_id, []
        );
    }
    return {
        terminals: _BladeCombatRuntimeClone(_selected),
        children: _BladeCombatRuntimeClone(_children),
        rewards: _BladeCombatRuntimeClone(_reward_plans),
    };
}

/// @func BladeCombatResolutionEndTick(runtime)
/// Runs cancellation, swept discovery, damage, automatic cleanup, and one stable commit.
function BladeCombatResolutionEndTick(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    var _tick = _runtime.active_tick;
    if ((_tick.domain_mask & BladeClockDomain.Combat) != 0) {
        _BladeCombatResolutionCancellation(_runtime, _tick);
        var _candidates = _BladeCombatResolutionDiscoverHits(_runtime);
        _BladeCombatResolutionDamage(_runtime, _tick, _candidates);
        _BladeCombatResolutionAutomaticTerminals(_runtime, _tick);
        _BladeCombatResolutionCommit(
            _runtime, _runtime.pending_terminals, true, true
        );
    }
    return BladeCombatRuntimeCanonical(_runtime);
}

/// @func BladeCombatRuntimeBoundaryPlan(runtime, reason, simulation_tick, combat_tick)
/// Prepares complete administrative cleanup between ticks without mutating combat state.
function BladeCombatRuntimeBoundaryPlan(
    _runtime, _reason, _simulation_tick, _combat_tick
) {
    _BladeCombatRuntimeRequire(_runtime);
    if (!is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("boundary", "must occur between ticks");
    }
    var _validated_reason = _BladeCombatRuntimeInteger(
        _reason, BladeCombatTerminalReason.RoomExit,
        BladeCombatTerminalReason.RunLoad, "boundary reason"
    );
    if (_validated_reason < BladeCombatTerminalReason.RoomExit
        || _validated_reason > BladeCombatTerminalReason.RunLoad) {
        _BladeCombatRuntimeFail("boundary", "requires a room or run cleanup reason");
    }
    var _requests = [];
    var _collections = [
        { records: _runtime.actors, field: "instance_id", kind: BladeCombatSubjectKind.Actor },
        { records: _runtime.attacks, field: "attack_id", kind: BladeCombatSubjectKind.Attack },
        { records: _runtime.projectiles, field: "projectile_id", kind: BladeCombatSubjectKind.Projectile },
    ];
    for (var _collection_index = 0;
        _collection_index < array_length(_collections); ++_collection_index) {
        var _collection = _collections[_collection_index];
        for (var _index = 0; _index < array_length(_collection.records); ++_index) {
            array_push(_requests, {
                subject_kind: _collection.kind,
                subject_id: variable_struct_get(_collection.records[_index], _collection.field),
                reason: _validated_reason,
                simulation_tick: _BladeCombatRuntimeInteger(
                    _simulation_tick, 0, int64("9223372036854775807"), "boundary tick"
                ),
                combat_tick: _BladeCombatRuntimeInteger(
                    _combat_tick, 0, int64("9223372036854775807"), "boundary combat tick"
                ),
            });
        }
    }
    return {
        __blade_combat_boundary_plan_version: 1,
        reason: _validated_reason,
        requests: _BladeCombatRuntimeClone(_requests),
    };
}

/// @func BladeCombatRuntimeCommitBoundary(runtime, plan)
/// Commits one prevalidated nonrewarding administrative cleanup and returns its report.
function BladeCombatRuntimeCommitBoundary(_runtime, _plan) {
    _BladeCombatRuntimeRequire(_runtime);
    if (!is_undefined(_runtime.active_tick)) {
        _BladeCombatRuntimeFail("boundary", "must occur between ticks");
    }
    if (!is_struct(_plan)
        || !variable_struct_exists(_plan, "__blade_combat_boundary_plan_version")
        || _plan.__blade_combat_boundary_plan_version != 1) {
        _BladeCombatRuntimeFail("boundary plan", "expected a version 1 plan");
    }
    var _reason = _BladeCombatRuntimeInteger(
        _plan.reason, BladeCombatTerminalReason.RoomExit,
        BladeCombatTerminalReason.RunLoad, "boundary plan reason"
    );
    if (!is_array(_plan.requests)) {
        _BladeCombatRuntimeFail("boundary plan", "requests must remain an array");
    }
    for (var _index = 0; _index < array_length(_plan.requests); ++_index) {
        var _request = _plan.requests[_index];
        if (!is_struct(_request) || _request.reason != _reason) {
            _BladeCombatRuntimeFail(
                "boundary plan", "every request must retain the plan reason"
            );
        }
        var _kind = _BladeCombatResolutionIdentityKind(_request.subject_kind);
        BladeRunIdentityRequireAllocated(_runtime.identity, _request.subject_id, _kind);
        _BladeCombatRuntimeInteger(
            _request.simulation_tick, 0, int64("9223372036854775807"),
            "boundary plan simulation tick"
        );
        _BladeCombatRuntimeInteger(
            _request.combat_tick, 0, int64("9223372036854775807"),
            "boundary plan combat tick"
        );
    }
    var _result = _BladeCombatResolutionCommit(
        _runtime, _plan.requests, false, false
    );
    return {
        reason: _reason,
        terminals: _result.terminals,
        rewards: [],
        children: [],
    };
}

/// Encodes one q10 box in fixed edge order.
function _BladeCombatRuntimeAabbCanonical(_box) {
    var _copy = _BladeCombatGeometryAabbCopy(_box);
    return BladeCanonicalRecord("BBOX1", [
        string(_copy.left_q10), string(_copy.top_q10),
        string(_copy.right_q10_exclusive), string(_copy.bottom_q10_exclusive),
    ]);
}

/// Encodes one optional recursive defeat-child declaration.
function _BladeCombatRuntimeChildCanonical(_runtime, _spec) {
    if (is_undefined(_spec)) return "";
    var _copy = _BladeCombatRuntimeChildSpec(_runtime, _spec);
    return BladeCanonicalRecord("BCHILD1", [
        _copy.content_id, string(_copy.faction), string(_copy.health),
        _BladeCombatRuntimeAabbCanonical(_copy.box),
        string(_copy.invulnerable_until_combat_tick),
        _copy.reward_on_defeat ? "1" : "0", string(_copy.count),
        _BladeCombatRuntimeChildCanonical(_runtime, _copy.child_spec),
    ]);
}

/// @func BladeCombatRuntimeCanonical(runtime)
/// Encodes every owned combat collection in allocation and commit order.
function BladeCombatRuntimeCanonical(_runtime) {
    _BladeCombatRuntimeRequire(_runtime);
    var _actors = [];
    for (var _index = 0; _index < array_length(_runtime.actors); ++_index) {
        var _actor = _runtime.actors[_index];
        array_push(_actors, BladeCanonicalRecord("BACTOR1", [
            _actor.instance_id, _actor.content_id, string(_actor.faction),
            string(_actor.health), string(_actor.health_max),
            _BladeCombatRuntimeAabbCanonical(_actor.previous_box),
            _BladeCombatRuntimeAabbCanonical(_actor.current_box),
            string(_actor.invulnerable_until_combat_tick),
            BladeCanonicalRecord("BRA1", _actor.recent_attack_ids),
            _actor.reward_on_defeat ? "1" : "0",
            _BladeCombatRuntimeChildCanonical(_runtime, _actor.child_spec),
            string(_actor.spawn_simulation_tick), string(_actor.spawn_combat_tick),
        ]));
    }
    var _attacks = [];
    for (var _index = 0; _index < array_length(_runtime.attacks); ++_index) {
        var _attack = _runtime.attacks[_index];
        array_push(_attacks, BladeCanonicalRecord("BATTACK1", [
            _attack.attack_id, _attack.owner_entity_id, _attack.content_id,
            string(_attack.faction), string(_attack.spawn_simulation_tick),
            string(_attack.spawn_combat_tick), string(_attack.damage),
            string(_attack.cancellation_policy), string(_attack.cancellation_power),
            string(_attack.penetration_remaining), string(_attack.hit_budget_remaining),
            string(_attack.lifetime_combat_ticks),
            BladeCombatTerminalReasonToken(_attack.terminal_reason),
        ]));
    }
    var _projectiles = [];
    for (var _index = 0; _index < array_length(_runtime.projectiles); ++_index) {
        var _projectile = _runtime.projectiles[_index];
        array_push(_projectiles, BladeCanonicalRecord("BPROJECTILE1", [
            _projectile.projectile_id, _projectile.attack_id,
            _projectile.owner_entity_id, _projectile.content_id,
            string(_projectile.faction), string(_projectile.spawn_simulation_tick),
            string(_projectile.spawn_combat_tick), string(_projectile.damage),
            string(_projectile.cancellation_policy),
            string(_projectile.cancellation_power),
            string(_projectile.penetration_remaining),
            string(_projectile.hit_budget_remaining),
            string(_projectile.lifetime_combat_ticks),
            BladeCombatTerminalReasonToken(_projectile.terminal_reason),
            _BladeCombatRuntimeAabbCanonical(_projectile.previous_box),
            _BladeCombatRuntimeAabbCanonical(_projectile.current_box),
            BladeCanonicalRecord("BHT1", _projectile.hit_target_ids),
        ]));
    }
    var _damage = [];
    for (var _index = 0;
        _index < array_length(_runtime.damage_transactions); ++_index) {
        var _record = _runtime.damage_transactions[_index];
        array_push(_damage, BladeCanonicalRecord("BDAMAGE1", [
            _record.damage_id, _record.projectile_id, _record.attack_id,
            _record.target_id, string(_record.simulation_tick),
            string(_record.combat_tick), string(_record.requested_amount),
            string(_record.applied_amount), string(_record.health_before),
            string(_record.health_after),
        ]));
    }
    var _terminals = [];
    for (var _index = 0; _index < array_length(_runtime.terminal_records); ++_index) {
        var _record = _runtime.terminal_records[_index];
        array_push(_terminals, BladeCanonicalRecord("BTERMINAL1", [
            string(_record.subject_kind), _record.subject_id,
            BladeCombatTerminalReasonToken(_record.reason), _record.content_id,
            string(_record.simulation_tick), string(_record.combat_tick),
        ]));
    }
    var _rewards = [];
    for (var _index = 0; _index < array_length(_runtime.reward_requests); ++_index) {
        var _record = _runtime.reward_requests[_index];
        array_push(_rewards, BladeCanonicalRecord("BREWARD1", [
            _record.source_actor_id, _record.content_id,
            BladeCombatTerminalReasonToken(_record.reason),
            string(_record.simulation_tick), string(_record.combat_tick),
        ]));
    }
    var _plane = "";
    if (!is_undefined(_runtime.plane)) {
        var _copy = BladeCombatPlaneCopy(_runtime.plane);
        _plane = BladeCanonicalRecord("BPLANE1", [
            string(_copy.left_q10), string(_copy.top_q10),
            string(_copy.right_q10_exclusive),
            string(_copy.bottom_q10_exclusive),
        ]);
    }
    return BladeCanonicalRecord("BCRUNTIME1", [
        _runtime.event_owner_id, _plane,
        BladeCanonicalRecord("BACTORS1", _actors),
        BladeCanonicalRecord("BATTACKS1", _attacks),
        BladeCanonicalRecord("BPROJECTILES1", _projectiles),
        BladeCanonicalRecord("BDAMAGES1", _damage),
        BladeCanonicalRecord("BTERMINALS1", _terminals),
        BladeCanonicalRecord("BREWARDS1", _rewards),
    ]);
}
