/// @description Focused tests for reason-coded combat lifecycle cleanup.

/// Runs one valid lethal hit while Defeat and duplicate StageEnd requests compete.
function _BladeCombatLifecycleTestsStageEndCompetition(_stage_end_first) {
	var _fixture = _BladeCombatRuntimeTestsGhostFixture();
	var _context = {
		coordinator: _fixture.coordinator,
		large_id: _fixture.large.instance_id,
		box: _fixture.box,
		stage_end_first: _stage_end_first,
		defeat_queued: false,
		stage_end_queued: false,
		duplicate_stage_end_queued: true,
	};
	_BladeCombatRuntimeTestsStep(
		_fixture.coordinator,
		method(_context, function(_run, _input, _tick) {
			if (self.stage_end_first) {
				self.stage_end_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.StageEnd
				).queued;
				self.duplicate_stage_end_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.StageEnd
				).queued;
				self.defeat_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.Defeat
				).queued;
			} else {
				self.defeat_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.Defeat
				).queued;
				self.stage_end_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.StageEnd
				).queued;
				self.duplicate_stage_end_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.StageEnd
				).queued;
			}
			BladeRunCombatPlayerEmit(
				self.coordinator, "ins:1", _BladeCombatRuntimeTestsSpec(), self.box
			);
			return undefined;
		})
	);
	return {
		canonical: BladeRunCoordinatorCanonical(_fixture.coordinator),
		snapshot: BladeRunCombatSnapshot(_fixture.coordinator),
		defeat_queued: _context.defeat_queued,
		stage_end_queued: _context.stage_end_queued,
		duplicate_stage_end_queued: _context.duplicate_stage_end_queued,
	};
}

/// Asserts one StageEnd result cannot inherit defeat rewards or child creation.
function _BladeCombatLifecycleTestsAssertStageEnd(_result, _order_name) {
	BladeKernelTestAssertTrue(
		_result.defeat_queued, _order_name + " defeat request queues"
	);
	BladeKernelTestAssertTrue(
		_result.stage_end_queued, _order_name + " stage-end request queues"
	);
	BladeKernelTestAssertFalse(
		_result.duplicate_stage_end_queued,
		_order_name + " duplicate stage-end request is idempotent"
	);
	BladeKernelTestAssertEqual(
		array_length(_result.snapshot.damage_transactions), 1,
		_order_name + " lethal damage makes defeat eligible"
	);
	BladeKernelTestAssertEqual(
		_BladeCombatRuntimeTestsTerminalCount(
			_result.snapshot, BladeCombatTerminalReason.StageEnd,
			BladeCombatSubjectKind.Actor
		),
		1, _order_name + " stage end wins exactly once"
	);
	BladeKernelTestAssertEqual(
		_BladeCombatRuntimeTestsTerminalCount(
			_result.snapshot, BladeCombatTerminalReason.Defeat,
			BladeCombatSubjectKind.Actor
		),
		0, _order_name + " defeat cannot impersonate stage end"
	);
	BladeKernelTestAssertEqual(
		array_length(_result.snapshot.reward_requests), 0,
		_order_name + " stage end grants no defeat reward"
	);
	BladeKernelTestAssertEqual(
		_BladeCombatRuntimeTestsContentCount(_result.snapshot, "ghost.medium"),
		0, _order_name + " stage end creates no defeat children"
	);
}

/// Registers combat lifecycle priority and idempotence coverage.
function BladeCombatLifecycleTestsRun(_state) {
	BladeKernelTestRunCase(
		_state,
		"stage-end cleanup outranks eligible defeat independent of request order",
		function() {
			var _stage_end_first = _BladeCombatLifecycleTestsStageEndCompetition(true);
			var _defeat_first = _BladeCombatLifecycleTestsStageEndCompetition(false);
			_BladeCombatLifecycleTestsAssertStageEnd(
				_stage_end_first, "stage-end-first"
			);
			_BladeCombatLifecycleTestsAssertStageEnd(
				_defeat_first, "defeat-first"
			);
			BladeKernelTestAssertEqual(
				_stage_end_first.canonical, _defeat_first.canonical,
				"terminal request insertion order cannot change canonical state"
			);
		}
	);
}
