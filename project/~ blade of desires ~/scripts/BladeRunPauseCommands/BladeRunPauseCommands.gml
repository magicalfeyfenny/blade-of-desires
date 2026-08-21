/// @description Pause-command and eligibility seam for the authoritative run coordinator.

/// Reads the authoritative master simulation tick used for pause acquisition and cleanup records.
function _BladeRunCoordinatorCurrentTick(_coordinator) {
	return BladeSimulationClockGetCounters(
		_coordinator.__kernel.clock
	).simulation_tick;
}

/// Prevalidates numeric masks and subtracts active pause domains from every live tick result.
function _BladeRunCoordinatorPauseEligibility(_coordinator, _eligibility) {
	var _base = _eligibility;
	if (typeof(_base) != "method") {
		// Validate before kernel sampling, but preserve the base mask for later live resolution.
		BladePauseRegistryResolveDomains(_coordinator.__pause_registry, _base);
	}
	var _context = {
		coordinator: _coordinator,
		eligibility: _base,
	};
	return method(_context, function(_counters) {
		var _requested = self.eligibility;
		if (typeof(_requested) == "method") {
			_requested = _requested(_counters);
		}
		// Re-read the registry so commands from tick N constrain tick N+1 in one batch.
		return BladePauseRegistryResolveDomains(
			self.coordinator.__pause_registry,
			_requested
		);
	});
}

/// Allocates one deterministic event-owner ID for a system that will submit pause commands.
function BladeRunCoordinatorAllocatePauseOwner(_coordinator) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return BladeKernelAllocate(_coordinator.__kernel, BladeRunIdKind.EventOwner);
}

/// Acquires one pause token at the coordinator's current master simulation tick.
function BladeRunCoordinatorAcquirePause(
	_coordinator, _owner_id, _reason, _domains, _release_policy
) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return BladePauseRegistryAcquire(
		_coordinator.__pause_registry, _owner_id, _reason, _domains,
		_BladeRunCoordinatorCurrentTick(_coordinator), _release_policy
	);
}

/// Releases one owned pause token at the coordinator's current master simulation tick.
function BladeRunCoordinatorReleasePause(_coordinator, _owner_id, _token_id) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return BladePauseRegistryRelease(
		_coordinator.__pause_registry, _owner_id, _token_id,
		_BladeRunCoordinatorCurrentTick(_coordinator)
	);
}

/// Transfers one token and lifetime policy between already allocated pause owners.
function BladeRunCoordinatorTransferPause(
	_coordinator, _owner_id, _token_id, _new_owner_id, _new_policy
) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return BladePauseRegistryTransfer(
		_coordinator.__pause_registry, _owner_id, _token_id, _new_owner_id,
		_new_policy, _BladeRunCoordinatorCurrentTick(_coordinator)
	);
}

/// Cleans one destroyed pause owner without affecting tokens held by other owners.
function BladeRunCoordinatorPauseOwnerDestroyed(_coordinator, _owner_id) {
	_BladeRunCoordinatorRequireActive(_coordinator);
	return BladePauseRegistryOwnerDestroyed(
		_coordinator.__pause_registry, _owner_id,
		_BladeRunCoordinatorCurrentTick(_coordinator)
	);
}

/// Applies room-exit policy using the coordinator's persistent own:1 run owner.
function BladeRunCoordinatorPauseRoomExit(_coordinator) {
	var _view = _BladeRunCoordinatorRequireActive(_coordinator);
	return BladePauseRegistryRoomExit(
		_coordinator.__pause_registry, _view.event_owner_id,
		_BladeRunCoordinatorCurrentTick(_coordinator)
	);
}

/// Returns a detached pause-only view without exposing the coordinator's mutable registry.
function BladeRunCoordinatorPauseSnapshot(_coordinator) {
	_BladeRunCoordinatorStateView(_coordinator);
	return BladePauseRegistrySnapshot(_coordinator.__pause_registry);
}
