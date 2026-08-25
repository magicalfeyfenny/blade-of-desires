/// @description Public combat commands over the active run's sole runtime owner.

/// Returns active combat ownership without exposing the coordinator's kernel.
function _BladeRunCombatRuntime(_coordinator) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return _coordinator.__combat;
}

/// Requires an active coordinator command that cannot run inside a simulation callback.
function _BladeRunCombatBetweenTicks(_coordinator, _command) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, _command);
	return _BladeRunCombatRuntime(_coordinator);
}

/// Returns the two deterministic clocks needed by combat registrations and boundaries.
function _BladeRunCombatCounters(_coordinator) {
	var _counters = BladeSimulationClockGetCounters(_coordinator.__kernel.clock);
	return {
		simulation_tick: _counters.simulation_tick,
		combat_tick: _counters.combat_tick,
	};
}

/// @func BladeRunCombatConfigurePlane(coordinator, gameplay_plane)
/// Installs #6's compiled product plane before the run begins emitting projectiles.
function BladeRunCombatConfigurePlane(_coordinator, _gameplay_plane) {
	return BladeCombatRuntimeConfigurePlane(
		_BladeRunCombatBetweenTicks(_coordinator, "combat plane command"),
		_gameplay_plane
	);
}

/// @func BladeRunCombatRegisterPlayer(coordinator, health, box, invulnerable_until)
/// Attaches the coordinator's already allocated player identity to combat state.
function BladeRunCombatRegisterPlayer(
	_coordinator, _health, _box, _invulnerable_until_combat_tick = 0
) {
	var _runtime = _BladeRunCombatBetweenTicks(
		_coordinator, "player combat registration"
	);
	var _view = _BladeRunCoordinatorStateView(_coordinator);
	var _ticks = _BladeRunCombatCounters(_coordinator);
	return BladeCombatRuntimeRegisterActor(
		_runtime, _view.player.instance_id, _view.player.ship_id,
		BladeCombatFaction.Player, _health, _box,
		_invulnerable_until_combat_tick, false, undefined,
		_ticks.simulation_tick, _ticks.combat_tick
	);
}

/// @func BladeRunCombatSpawnActor(coordinator, content_id, faction, health, box, invulnerable_until, reward_on_defeat, child_spec)
/// Allocates one validated run-local actor between ticks, including defeat lineage data.
function BladeRunCombatSpawnActor(
	_coordinator, _content_id, _faction, _health, _box,
	_invulnerable_until_combat_tick = 0, _reward_on_defeat = false,
	_child_spec = undefined
) {
	var _runtime = _BladeRunCombatBetweenTicks(_coordinator, "combat actor spawn");
	var _ticks = _BladeRunCombatCounters(_coordinator);
	return BladeCombatRuntimeSpawnActor(
		_runtime, _content_id, _faction, _health, _box,
		_invulnerable_until_combat_tick, _reward_on_defeat, _child_spec,
		_ticks.simulation_tick, _ticks.combat_tick
	);
}

/// @func BladeRunCombatEnemyEmit(coordinator, owner_id, spec, projectile_box, gate_kind, gate_geometry)
/// Rechecks one enemy attempt against the central product-plane gate during Combat time.
function BladeRunCombatEnemyEmit(
	_coordinator, _owner_id, _spec, _projectile_box, _gate_kind, _gate_geometry
) {
	return BladeCombatRuntimeEnemyEmit(
		_BladeRunCombatRuntime(_coordinator), _owner_id, _spec,
		_projectile_box, _gate_kind, _gate_geometry
	);
}

/// @func BladeRunCombatPlayerEmit(coordinator, owner_id, spec, projectile_box)
/// Creates one player attack and projectile during eligible Combat time.
function BladeRunCombatPlayerEmit(_coordinator, _owner_id, _spec, _projectile_box) {
	return BladeCombatRuntimePlayerEmit(
		_BladeRunCombatRuntime(_coordinator), _owner_id, _spec, _projectile_box
	);
}

/// @func BladeRunCombatSetActorBox(coordinator, instance_id, box)
/// Advances a visible actor pose on eligible Actor time independently of Combat pause.
function BladeRunCombatSetActorBox(_coordinator, _instance_id, _box) {
	return BladeCombatRuntimeSetActorBox(
		_BladeRunCombatRuntime(_coordinator), _instance_id, _box
	);
}

/// @func BladeRunCombatMoveProjectile(coordinator, projectile_id, box)
/// Advances a projectile hurtbox only during eligible Combat time.
function BladeRunCombatMoveProjectile(_coordinator, _projectile_id, _box) {
	return BladeCombatRuntimeMoveProjectile(
		_BladeRunCombatRuntime(_coordinator), _projectile_id, _box
	);
}

/// @func BladeRunCombatRequestTerminal(coordinator, subject_kind, subject_id, reason)
/// Queues one idempotent terminal request for stable resolution at tick end.
function BladeRunCombatRequestTerminal(
	_coordinator, _subject_kind, _subject_id, _reason
) {
	return BladeCombatRuntimeRequestTerminal(
		_BladeRunCombatRuntime(_coordinator), _subject_kind, _subject_id, _reason
	);
}

/// @func BladeRunCombatRoomExit(coordinator)
/// Clears room-owned pause, combat, and attached stage state without ending the run.
function BladeRunCombatRoomExit(_coordinator) {
	var _runtime = _BladeRunCombatBetweenTicks(_coordinator, "combat room exit");
	var _ticks = _BladeRunCombatCounters(_coordinator);
	var _stage_boundary = _BladeRunStagePrepareAbort(
		_coordinator, BladeCombatTerminalReason.RoomExit
	);
	var _plan = BladeCombatRuntimeBoundaryPlan(
		_runtime, BladeCombatTerminalReason.RoomExit,
		_ticks.simulation_tick, _ticks.combat_tick
	);
	var _pause_report = BladeRunCoordinatorPauseRoomExit(_coordinator);
	var _combat_report = BladeCombatRuntimeCommitBoundary(_runtime, _plan);
	var _stage_report = _BladeRunStageCommitAbort(_stage_boundary);
	if (!is_undefined(_stage_report)) {
		// The report retains the ended room's provenance while the active run
		// becomes vacant for its next room-owned stage.
		_coordinator.__stage = undefined;
	}
	var _result = {
		pause_boundary_report: _pause_report,
		combat_boundary_report: _combat_report,
	};
	if (!is_undefined(_stage_report)) {
		_result.stage_boundary_report = _stage_report;
	}
	return _result;
}

/// @func BladeRunCombatSnapshot(coordinator)
/// Returns detached combat state without exposing identity, kernel, or mutable ownership.
function BladeRunCombatSnapshot(_coordinator) {
	return BladeCombatRuntimeSnapshot(_BladeRunCombatRuntime(_coordinator));
}
