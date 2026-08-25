/// @description Stage ownership commands and the run-to-kernel simulation bridge.

/// Returns attached stage ownership after validating the coordinator and executor boundary.
function _BladeRunStageAttached(_coordinator) {
	_BladeRunCoordinatorRequire(_coordinator);
	if (is_undefined(_coordinator.__stage)) {
		_BladeRunCoordinatorFail("stage", "has not been attached");
	}
	var _executor = _BladeStageExecutorRequire(_coordinator.__stage);
	if (!_executor.runtime_bound
		|| _executor.bound_identity != _coordinator.__kernel.identity) {
		_BladeRunCoordinatorFail(
			"stage ownership", "must remain bound to the active run identity"
		);
	}
	return _executor;
}

/// Requires an active attached stage command to run outside a kernel advance.
function _BladeRunStageBetweenTicks(_coordinator, _command) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, _command);
	_BladeRunCoordinatorRequireActive(_coordinator);
	return _BladeRunStageAttached(_coordinator);
}

/// Requires the active coordinator to have no existing stage ownership.
function _BladeRunStageRequireVacant(_coordinator, _command) {
	_BladeRunCoordinatorRequireNotAdvancing(_coordinator, _command);
	_BladeRunCoordinatorRequireActive(_coordinator);
	if (!is_undefined(_coordinator.__stage)) {
		_BladeRunCoordinatorFail("stage", "already has attached ownership");
	}
	return _coordinator;
}

/// Rejects previously advanced executors and returns a detached fresh owner over the same plan.
function _BladeRunStageFreshCopy(_executor) {
	_BladeStageExecutorRequire(_executor);
	var _fresh = BladeStageExecutorRestart(_executor);
	if (BladeStageExecutorCanonical(_executor)
		!= BladeStageExecutorCanonical(_fresh)) {
		_BladeRunCoordinatorFail(
			"stage executor", "must be pristine when attached"
		);
	}
	return _fresh;
}

/// Confirms the stage's declared contract ID belongs to the run's authoritative content set.
function _BladeRunStageRequireProductBinding(_coordinator, _executor) {
	// The public loader proves the exact product file fingerprint and version;
	// this internal seam also requires its declared contract ID in the run registry.
	_BladeRunCoordinatorRequireContentKind(
		_coordinator.__kernel.identity,
		_executor.plan.product_contract.id,
		"contract.",
		"stage product contract ID"
	);
}

/// Requires the executor's preflight plane to equal the run's compiled combat plane.
function _BladeRunStageRequirePlaneBinding(_coordinator, _executor) {
	var _expected = BladeCombatRuntimePlaneCopy(_coordinator.__combat);
	BladeStageExecutorRequireGameplayPlane(_executor, _expected);
	return _expected;
}

/// Copies all current clock counters into the tick shape required by stage boundaries.
function _BladeRunStageBoundaryTick(_coordinator) {
	var _counters = BladeSimulationClockGetCounters(_coordinator.__kernel.clock);
	return {
		simulation_tick: _counters.simulation_tick,
		stage_tick: _counters.stage_tick,
		actor_tick: _counters.actor_tick,
		boss_tick: _counters.boss_tick,
		combat_tick: _counters.combat_tick,
		presentation_tick: _counters.presentation_tick,
		domain_mask: int64(0),
	};
}

/// Validates one optional stage abort before another owner commits its boundary cleanup.
function _BladeRunStagePrepareAbort(_coordinator, _reason) {
	_BladeRunCoordinatorRequire(_coordinator);
	if (is_undefined(_coordinator.__stage)) return undefined;
	if (_reason != BladeCombatTerminalReason.StageEnd
		&& _reason != BladeCombatTerminalReason.RoomExit
		&& _reason != BladeCombatTerminalReason.RunCompleted
		&& _reason != BladeCombatTerminalReason.RunAborted
		&& _reason != BladeCombatTerminalReason.RunReset
		&& _reason != BladeCombatTerminalReason.RunLoad) {
		_BladeRunCoordinatorFail(
			"stage boundary reason", "must be an administrative terminal reason"
		);
	}
	var _executor = _BladeRunStageAttached(_coordinator);
	var _tick = _BladeStageExecutorTick(_BladeRunStageBoundaryTick(_coordinator));
	return {
		executor: _executor,
		runtime: _coordinator.__combat,
		reason: _reason,
		tick: _tick,
	};
}

/// Applies one already validated stage abort after authoritative combat cleanup succeeds.
function _BladeRunStageCommitAbort(_prepared) {
	if (is_undefined(_prepared)) return undefined;
	return BladeStageExecutorAbort(
		_prepared.executor, _prepared.runtime, _prepared.reason, _prepared.tick
	);
}

/// Copies the resolved kernel tick so client mutation cannot affect later encoding.
function _BladeRunCoordinatorTickView(_tick) {
	return {
		simulation_tick: _tick.simulation_tick,
		stage_tick: _tick.stage_tick,
		actor_tick: _tick.actor_tick,
		boss_tick: _tick.boss_tick,
		combat_tick: _tick.combat_tick,
		presentation_tick: _tick.presentation_tick,
		domain_mask: _tick.domain_mask,
	};
}

/// Runs client combat first, then advances stage ownership while the kernel tick remains open.
function _BladeRunCoordinatorBindSimulationCallback(_coordinator, _callback) {
	if (!is_undefined(_callback) && typeof(_callback) != "method") {
		_BladeRunCoordinatorFail("simulation callback", "must be a method or undefined");
	}

	var _context = {
		coordinator: _coordinator,
		callback: _callback,
	};
	return method(_context, function(_kernel, _input_snapshot, _tick) {
		var _has_stage = !is_undefined(self.coordinator.__stage);
		var _run_snapshot = _BladeRunCoordinatorStateView(self.coordinator);
		_BladeCombatRuntimeBeginTick(self.coordinator.__combat, _kernel, _tick);
		try {
			var _client_fragment = "";
			if (typeof(self.callback) == "method") {
				_client_fragment = self.callback(
					_run_snapshot, _input_snapshot,
					_BladeRunCoordinatorTickView(_tick)
				);
				if (is_undefined(_client_fragment)) _client_fragment = "";
				if (!is_string(_client_fragment)) {
					_BladeRunCoordinatorFail(
						"simulation callback",
						"must return a canonical string or undefined"
					);
				}
			}
			_BladeCombatRuntimeEndTick(self.coordinator.__combat);
			var _stage_fragment = "";
			if (_has_stage) {
				BladeStageExecutorAdvance(
					self.coordinator.__stage, _kernel,
					self.coordinator.__combat, _tick
				);
				_stage_fragment = BladeStageExecutorCanonical(
					self.coordinator.__stage
				);
			}
			// Stage may register new encounter actors after Combat closes this tick.
			var _combat_fragment = BladeCombatRuntimeCanonical(
				self.coordinator.__combat
			);
			var _fragments = [_client_fragment, _combat_fragment];
			if (_has_stage) array_push(_fragments, _stage_fragment);
			return BladeCanonicalRecord("BRCF1", _fragments);
		} catch (_caught) {
			_BladeCombatRuntimeCancelTick(self.coordinator.__combat);
			throw _caught;
		}
	});
}

/// Attaches one trusted content-created executor after all run bindings preflight.
function _BladeRunStageAttachExecutor(_coordinator, _executor) {
	_BladeRunStageRequireVacant(_coordinator, "stage attach command");
	var _fresh = _BladeRunStageFreshCopy(_executor);
	_BladeRunStageRequireProductBinding(_coordinator, _fresh);
	_BladeRunStageRequirePlaneBinding(_coordinator, _fresh);
	BladeStageExecutorBindRuntime(
		_fresh, _coordinator.__kernel, _coordinator.__combat
	);
	_coordinator.__stage = _fresh;
	return BladeStageExecutorSnapshot(_fresh);
}

/// @func BladeRunStageLoadAndAttach(coordinator, path, stage_id, participant_spec_resolver)
/// Verifies bundled product binding and all spawn specs before attaching between ticks.
function BladeRunStageLoadAndAttach(
	_coordinator, _path, _stage_id, _participant_spec_resolver
) {
	_BladeRunStageRequireVacant(_coordinator, "stage load command");
	var _plane = BladeCombatRuntimePlaneCopy(_coordinator.__combat);
	var _executor = BladeStageContentCreateExecutor(
		_path, _stage_id, _participant_spec_resolver, _plane,
		"content/product_contract.json", _coordinator.__content_fingerprint
	);
	return _BladeRunStageAttachExecutor(_coordinator, _executor);
}

/// @func BladeRunStageSubmitTaskCompletion(coordinator, port_id, type_id, signal_id, signal_type_id, request_generation)
/// Submits one correlated typed task result only outside the coordinator's advance.
function BladeRunStageSubmitTaskCompletion(
	_coordinator, _port_id, _type_id, _signal_id, _signal_type_id,
	_request_generation
) {
	return BladeStageExecutorSubmitTaskCompletion(
		_BladeRunStageBetweenTicks(_coordinator, "stage task completion"),
		_port_id, _type_id, _signal_id, _signal_type_id, _request_generation
	);
}

/// @func BladeRunStageSubmitExternalSignal(coordinator, signal_id, type_id, wait_generation)
/// Submits one typed external signal only outside the coordinator's advance.
function BladeRunStageSubmitExternalSignal(
	_coordinator, _signal_id, _type_id, _wait_generation
) {
	return BladeStageExecutorSubmitExternalSignal(
		_BladeRunStageBetweenTicks(_coordinator, "stage external signal"),
		_signal_id, _type_id, _wait_generation
	);
}

/// @func BladeRunStageReadTaskRequests(coordinator, cursor)
/// Reads task requests after a consumer-owned cursor without exposing mutable ports.
function BladeRunStageReadTaskRequests(_coordinator, _cursor) {
	var _executor = _BladeRunStageAttached(_coordinator);
	return BladeStagePortsReadTaskRequests(_executor.ports, _cursor);
}

/// @func BladeRunStageReadCueRequests(coordinator, cursor)
/// Reads semantic presentation cues after a consumer-owned delivery cursor.
function BladeRunStageReadCueRequests(_coordinator, _cursor) {
	var _executor = _BladeRunStageAttached(_coordinator);
	return BladeStagePortsReadCueRequests(_executor.ports, _cursor);
}

/// @func BladeRunStageReadSignalRecords(coordinator, cursor)
/// Reads typed signal facts after a consumer-owned diagnostic cursor.
function BladeRunStageReadSignalRecords(_coordinator, _cursor) {
	var _executor = _BladeRunStageAttached(_coordinator);
	return BladeStagePortsReadSignalRecords(_executor.ports, _cursor);
}

/// @func BladeRunStageReadEvents(coordinator, cursor)
/// Reads committed deterministic stage events after a consumer-owned cursor.
function BladeRunStageReadEvents(_coordinator, _cursor) {
	var _executor = _BladeRunStageAttached(_coordinator);
	return BladeStageEventStreamRead(_executor.events, _cursor);
}

/// @func BladeRunStageSnapshot(coordinator)
/// Returns a detached view of attached stage ownership, including its typed outboxes.
function BladeRunStageSnapshot(_coordinator) {
	return BladeStageExecutorSnapshot(_BladeRunStageAttached(_coordinator));
}

/// @func BladeRunStageCanonical(coordinator)
/// Returns the complete canonical fragment contributed by attached stage ownership.
function BladeRunStageCanonical(_coordinator) {
	return BladeStageExecutorCanonical(_BladeRunStageAttached(_coordinator));
}
