/// @description Focused integration tests for run-owned deterministic combat transactions.

/// Recognizes the run fixtures plus the non-art combat and Ghost fixture IDs.
function _BladeCombatRuntimeTestsKnownContent(_content_id) {
	return _BladeRunCoordinatorTestKnownContent(_content_id)
		|| _content_id == "enemy.fixture"
		|| _content_id == "ally.fixture"
		|| _content_id == "ghost.large"
		|| _content_id == "ghost.medium"
		|| _content_id == "ghost.small";
}

/// Creates one combat-enabled run over #6's authoritative plane fixture.
function _BladeCombatRuntimeTestsCreate() {
	return BladeRunCoordinatorCreate(
		"sha1:288e8d1b7d90b5ce04b881bfa631ee3a497ef885",
		method({}, _BladeCombatRuntimeTestsKnownContent),
		"ship.maynii", "difficulty.normal",
		BladeRunMode.Normal, 305419896, 8,
		_BladeCombatGeometryTestsPlaneSource()
	);
}

/// Creates one q10 test box from a top-left point and optional dimensions.
function _BladeCombatRuntimeTestsBox(
	_x, _y, _width = 1024, _height = 1024
) {
	return BladeCombatAabbCreate(_x, _y, _x + _width, _y + _height);
}

/// Creates one ordinary offense fixture with overridable damage, budget, and lifetime.
function _BladeCombatRuntimeTestsSpec(
	_damage = 1, _hit_budget = 1, _lifetime = 100,
	_policy = BladeCombatCancellationPolicy.Ignore,
	_power = 0, _penetration = 0
) {
	return BladeCombatOffenseSpecCreate(
		_damage, _policy, _power, _penetration, _hit_budget, _lifetime
	);
}

/// Steps one exact tick with neutral input and an optional simulation command.
function _BladeCombatRuntimeTestsStep(
	_coordinator, _callback = undefined, _domains = BladeClockDomain.All
) {
	return BladeRunCoordinatorStepDirect(
		_coordinator, BladeInputRawStateCreate(0, 0, 0), _domains, _callback
	);
}

/// Returns an active actor by stable ID from one detached snapshot.
function _BladeCombatRuntimeTestsActor(_snapshot, _instance_id) {
	for (var _index = 0; _index < array_length(_snapshot.actors); ++_index) {
		if (_snapshot.actors[_index].instance_id == _instance_id) {
			return _snapshot.actors[_index];
		}
	}
	return undefined;
}

/// Counts terminal records matching one reason and optional subject kind.
function _BladeCombatRuntimeTestsTerminalCount(
	_snapshot, _reason, _subject_kind = -1
) {
	var _count = 0;
	for (var _index = 0;
		_index < array_length(_snapshot.terminal_records); ++_index) {
		var _record = _snapshot.terminal_records[_index];
		if (_record.reason == _reason
			&& (_subject_kind < 0 || _record.subject_kind == _subject_kind)) {
			_count += 1;
		}
	}
	return _count;
}

/// Counts active actors with one content ID in a detached snapshot.
function _BladeCombatRuntimeTestsContentCount(_snapshot, _content_id) {
	var _count = 0;
	for (var _index = 0; _index < array_length(_snapshot.actors); ++_index) {
		if (_snapshot.actors[_index].content_id == _content_id) _count += 1;
	}
	return _count;
}

/// Executes independent enemy gate attempts and returns authorization plus owned state.
function _BladeCombatRuntimeTestsGateSequence(_x_values) {
	var _coordinator = _BladeCombatRuntimeTestsCreate();
	var _enemy = BladeRunCombatSpawnActor(
		_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 10,
		_BladeCombatRuntimeTestsBox(_x_values[0], 100000)
	);
	var _context = {
		coordinator: _coordinator,
		enemy_id: _enemy.instance_id,
		x_q10: 0,
		authorized: [],
	};
	var _callback = method(_context, function(_run, _input, _tick) {
		BladeRunCombatSetActorBox(
			self.coordinator, self.enemy_id,
			_BladeCombatRuntimeTestsBox(self.x_q10, 100000)
		);
		var _result = BladeRunCombatEnemyEmit(
			self.coordinator, self.enemy_id,
			_BladeCombatRuntimeTestsSpec(),
			_BladeCombatRuntimeTestsBox(300000, 100000),
			BladeCombatGateKind.Point,
			{ x_q10: self.x_q10, y_q10: 100000 }
		);
		array_push(self.authorized, _result.authorized);
		return undefined;
	});
	for (var _index = 0; _index < array_length(_x_values); ++_index) {
		_context.x_q10 = _x_values[_index];
		_BladeCombatRuntimeTestsStep(_coordinator, _callback);
	}
	return {
		authorized: _context.authorized,
		snapshot: BladeRunCombatSnapshot(_coordinator),
		diagnostics: BladeRunCoordinatorDiagnostics(_coordinator),
	};
}

/// Creates the recursive medium and small declarations used by the Ghost fixture.
function _BladeCombatRuntimeTestsGhostChildren(_box) {
	var _small = BladeCombatChildSpecCreate(
		"ghost.small", BladeCombatFaction.Enemy, 1, _box,
		0, false, 3
	);
	return BladeCombatChildSpecCreate(
		"ghost.medium", BladeCombatFaction.Enemy, 1, _box,
		0, false, 3, _small
	);
}

/// Creates a run with one reward-eligible large Ghost actor.
function _BladeCombatRuntimeTestsGhostFixture() {
	var _coordinator = _BladeCombatRuntimeTestsCreate();
	BladeRunCombatRegisterPlayer(
		_coordinator, 10, _BladeCombatRuntimeTestsBox(200000, 200000)
	);
	var _box = _BladeCombatRuntimeTestsBox(300000, 100000);
	var _large = BladeRunCombatSpawnActor(
		_coordinator, "ghost.large", BladeCombatFaction.Enemy, 1, _box,
		0, true, _BladeCombatRuntimeTestsGhostChildren(_box)
	);
	return { coordinator: _coordinator, large: _large, box: _box };
}

/// Registers every focused combat ownership, transaction, lifecycle, and pause case.
function BladeCombatRuntimeTestsRun(_state) {
	BladeKernelTestRunCase(_state, "enemy gate rechecks every attempt before allocation", function() {
		var _always_outside = _BladeCombatRuntimeTestsGateSequence([100000, 500000]);
		BladeKernelTestAssertArrayEqual(
			_always_outside.authorized, [false, false], "always outside remains locked"
		);
		BladeKernelTestAssertEqual(
			array_length(_always_outside.snapshot.projectiles), 0,
			"outside attempts create no projectile"
		);
		BladeKernelTestAssertEqual(
			_always_outside.diagnostics.kernel.identity.attack, int64(0),
			"outside attempts allocate no attack ID"
		);
		BladeKernelTestAssertEqual(
			_always_outside.diagnostics.kernel.identity.bullet, int64(0),
			"outside attempts allocate no projectile ID"
		);
		BladeKernelTestAssertEqual(
			_always_outside.diagnostics.kernel.identity.event, int64(0),
			"outside attempts emit no gameplay event"
		);

		BladeKernelTestAssertArrayEqual(
			_BladeCombatRuntimeTestsGateSequence([100000, 200000]).authorized,
			[false, true], "outside to inside authorizes only the new attempt"
		);
		BladeKernelTestAssertArrayEqual(
			_BladeCombatRuntimeTestsGateSequence([200000, 500000]).authorized,
			[true, false], "inside to outside revokes later authorization"
		);
		var _composite = _BladeCombatRuntimeTestsGateSequence([
			100000, 200000, 500000, 300000,
		]);
		BladeKernelTestAssertArrayEqual(
			_composite.authorized, [false, true, false, true],
			"composite cadence recalculates each attempt"
		);
		BladeKernelTestAssertEqual(
			array_length(_composite.snapshot.projectiles), 2,
			"only two authorized composite emissions exist"
		);

		var _edges = _BladeCombatRuntimeTestsGateSequence([189440, 465920]);
		BladeKernelTestAssertArrayEqual(
			_edges.authorized, [true, false],
			"central gate uses the half-open plane edges"
		);
		var _attack = _edges.snapshot.attacks[0];
		var _projectile = _edges.snapshot.projectiles[0];
		BladeKernelTestAssertEqual(_attack.attack_id, "atk:1", "stable attack ID");
		BladeKernelTestAssertEqual(_projectile.projectile_id, "blt:1", "stable bullet ID");
		BladeKernelTestAssertEqual(
			_projectile.attack_id, _attack.attack_id, "projectile binds its emitter attack"
		);
		BladeKernelTestAssertEqual(
			_projectile.owner_entity_id, "ins:2", "projectile binds its actor owner"
		);
		BladeKernelTestAssertEqual(
			_projectile.faction, BladeCombatFaction.Enemy, "projectile faction"
		);
		BladeKernelTestAssertEqual(_projectile.damage, int64(1), "integer damage payload");
		BladeKernelTestAssertEqual(
			_projectile.lifetime_combat_ticks, int64(100), "declared lifetime"
		);
		BladeKernelTestAssertEqual(
			_projectile.terminal_reason, BladeCombatTerminalReason.None,
			"active projectile has no terminal reason"
		);
	});

	BladeKernelTestRunCase(_state, "swept hits resolve in stable ID order with exact transactions", function() {
		var _coordinator = _BladeCombatRuntimeTestsCreate();
		var _player = BladeRunCombatRegisterPlayer(
			_coordinator, 10, _BladeCombatRuntimeTestsBox(195000, 200000)
		);
		var _target_box = _BladeCombatRuntimeTestsBox(210000, 100000);
		var _first = BladeRunCombatSpawnActor(
			_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 10, _target_box
		);
		var _second = BladeRunCombatSpawnActor(
			_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 10, _target_box
		);
		var _context = {
			coordinator: _coordinator, player_id: _player.instance_id,
		};
		_BladeCombatRuntimeTestsStep(_coordinator, method(_context, function(_run, _input, _tick) {
			var _emission = BladeRunCombatPlayerEmit(
				self.coordinator, self.player_id,
				_BladeCombatRuntimeTestsSpec(3, 2),
				_BladeCombatRuntimeTestsBox(200000, 100000)
			);
			BladeRunCombatMoveProjectile(
				self.coordinator, _emission.projectile_id,
				_BladeCombatRuntimeTestsBox(220000, 100000)
			);
			return undefined;
		}));
		var _snapshot = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(
			array_length(_snapshot.damage_transactions), 2,
			"one accepted transaction per target"
		);
		BladeKernelTestAssertEqual(
			_snapshot.damage_transactions[0].target_id, _first.instance_id,
			"lower numeric target ID resolves first"
		);
		BladeKernelTestAssertEqual(
			_snapshot.damage_transactions[1].target_id, _second.instance_id,
			"higher numeric target ID resolves second"
		);
		BladeKernelTestAssertEqual(
			_snapshot.damage_transactions[0].damage_id, "dmg:1", "first damage ID"
		);
		BladeKernelTestAssertEqual(
			_snapshot.damage_transactions[1].damage_id, "dmg:2", "second damage ID"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsActor(_snapshot, _first.instance_id).health,
			int64(7), "first health owns integer subtraction"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsActor(_snapshot, _second.instance_id).health,
			int64(7), "second health owns integer subtraction"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(
				_snapshot, BladeCombatTerminalReason.HitBudgetExhausted,
				BladeCombatSubjectKind.Projectile
			),
			1, "exhausted hit budget removes the projectile once"
		);
	});

	BladeKernelTestRunCase(_state, "hurtbox policy rejects faction invulnerability and repeat hits", function() {
		var _coordinator = _BladeCombatRuntimeTestsCreate();
		var _box = _BladeCombatRuntimeTestsBox(300000, 100000);
		var _player = BladeRunCombatRegisterPlayer(
			_coordinator, 10, _BladeCombatRuntimeTestsBox(200000, 200000)
		);
		var _ally = BladeRunCombatSpawnActor(
			_coordinator, "ally.fixture", BladeCombatFaction.Player, 10, _box
		);
		var _enemy = BladeRunCombatSpawnActor(
			_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 10, _box, 2
		);
		var _context = { coordinator: _coordinator, player_id: _player.instance_id, box: _box };
		_BladeCombatRuntimeTestsStep(_coordinator, method(_context, function(_run, _input, _tick) {
			BladeRunCombatPlayerEmit(
				self.coordinator, self.player_id,
				_BladeCombatRuntimeTestsSpec(3, 2), self.box
			);
			return undefined;
		}));
		var _blocked = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(
			array_length(_blocked.damage_transactions), 0,
			"same faction and active invulnerability reject the first tick"
		);
		_BladeCombatRuntimeTestsStep(_coordinator);
		var _accepted = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(
			array_length(_accepted.damage_transactions), 1,
			"expired invulnerability admits one enemy hit"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsActor(_accepted, _ally.instance_id).health,
			int64(10), "same-faction ally remains untouched"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsActor(_accepted, _enemy.instance_id).health,
			int64(7), "opposing target takes one hit"
		);
		_BladeCombatRuntimeTestsStep(_coordinator);
		var _repeat = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(
			array_length(_repeat.damage_transactions), 1,
			"persistent projectile cannot damage the same target twice"
		);
	});

	BladeKernelTestRunCase(_state, "cancellation expiration offscreen and phase reasons commit", function() {
		var _cancel = _BladeCombatRuntimeTestsCreate();
		var _player = BladeRunCombatRegisterPlayer(
			_cancel, 10, _BladeCombatRuntimeTestsBox(200000, 200000)
		);
		var _enemy = BladeRunCombatSpawnActor(
			_cancel, "enemy.fixture", BladeCombatFaction.Enemy, 10,
			_BladeCombatRuntimeTestsBox(400000, 200000)
		);
		var _cancel_box = _BladeCombatRuntimeTestsBox(300000, 100000);
		var _cancel_context = {
			coordinator: _cancel, player_id: _player.instance_id,
			enemy_id: _enemy.instance_id, box: _cancel_box,
		};
		_BladeCombatRuntimeTestsStep(_cancel, method(_cancel_context, function(_run, _input, _tick) {
			var _spec = _BladeCombatRuntimeTestsSpec(
				1, 1, 100, BladeCombatCancellationPolicy.Symmetric, 5, 2
			);
			BladeRunCombatPlayerEmit(self.coordinator, self.player_id, _spec, self.box);
			BladeRunCombatEnemyEmit(
				self.coordinator, self.enemy_id, _spec, self.box,
				BladeCombatGateKind.Point, { x_q10: 400000, y_q10: 200000 }
			);
			return undefined;
		}));
		var _cancelled = BladeRunCombatSnapshot(_cancel);
		BladeKernelTestAssertEqual(array_length(_cancelled.projectiles), 0, "equal pair removed");
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(
				_cancelled, BladeCombatTerminalReason.ProjectileCancellation,
				BladeCombatSubjectKind.Projectile
			),
			2, "equal cancellation records both projectiles"
		);
		BladeKernelTestAssertEqual(
			array_length(_cancelled.damage_transactions), 0,
			"cancelled projectiles apply no later damage"
		);

		var _lifetime = _BladeCombatRuntimeTestsCreate();
		var _lifetime_enemy = BladeRunCombatSpawnActor(
			_lifetime, "enemy.fixture", BladeCombatFaction.Enemy, 10,
			_BladeCombatRuntimeTestsBox(300000, 100000)
		);
		var _life_context = { coordinator: _lifetime, enemy_id: _lifetime_enemy.instance_id };
		_BladeCombatRuntimeTestsStep(_lifetime, method(_life_context, function(_run, _input, _tick) {
			BladeRunCombatEnemyEmit(
				self.coordinator, self.enemy_id,
				_BladeCombatRuntimeTestsSpec(1, 1, 1),
				_BladeCombatRuntimeTestsBox(300000, 100000),
				BladeCombatGateKind.Point, { x_q10: 300000, y_q10: 100000 }
			);
			return undefined;
		}));
		_BladeCombatRuntimeTestsStep(_lifetime);
		var _expired = BladeRunCombatSnapshot(_lifetime);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(_expired, BladeCombatTerminalReason.Expiration),
			2, "attack and projectile expire explicitly"
		);

		var _offscreen = _BladeCombatRuntimeTestsCreate();
		var _offscreen_enemy = BladeRunCombatSpawnActor(
			_offscreen, "enemy.fixture", BladeCombatFaction.Enemy, 10,
			_BladeCombatRuntimeTestsBox(300000, 100000)
		);
		var _off_context = { coordinator: _offscreen, enemy_id: _offscreen_enemy.instance_id };
		_BladeCombatRuntimeTestsStep(_offscreen, method(_off_context, function(_run, _input, _tick) {
			BladeRunCombatEnemyEmit(
				self.coordinator, self.enemy_id, _BladeCombatRuntimeTestsSpec(),
				_BladeCombatRuntimeTestsBox(500000, 100000),
				BladeCombatGateKind.Point, { x_q10: 300000, y_q10: 100000 }
			);
			return undefined;
		}));
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(
				BladeRunCombatSnapshot(_offscreen), BladeCombatTerminalReason.OutOfBounds
			),
			1, "offscreen projectile records its cleanup reason"
		);

		var _phase = _BladeCombatRuntimeTestsCreate();
		var _phase_enemy = BladeRunCombatSpawnActor(
			_phase, "enemy.fixture", BladeCombatFaction.Enemy, 10,
			_BladeCombatRuntimeTestsBox(300000, 100000)
		);
		var _phase_context = { coordinator: _phase, enemy_id: _phase_enemy.instance_id };
		_BladeCombatRuntimeTestsStep(_phase, method(_phase_context, function(_run, _input, _tick) {
			var _emission = BladeRunCombatEnemyEmit(
				self.coordinator, self.enemy_id, _BladeCombatRuntimeTestsSpec(),
				_BladeCombatRuntimeTestsBox(300000, 100000),
				BladeCombatGateKind.Point, { x_q10: 300000, y_q10: 100000 }
			);
			BladeRunCombatRequestTerminal(
				self.coordinator, BladeCombatSubjectKind.Projectile,
				_emission.projectile_id, BladeCombatTerminalReason.PhaseChange
			);
			return undefined;
		}));
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(
				BladeRunCombatSnapshot(_phase), BladeCombatTerminalReason.PhaseChange
			),
			1, "phase-break seam commits explicitly"
		);
	});

	BladeKernelTestRunCase(_state, "administrative cleanup outranks defeat without rewards", function() {
		var _fixture = _BladeCombatRuntimeTestsGhostFixture();
		var _context = {
			coordinator: _fixture.coordinator,
			large_id: _fixture.large.instance_id,
			player_id: "ins:1",
			box: _fixture.box,
			first_queued: false,
			second_queued: true,
		};
		_BladeCombatRuntimeTestsStep(
			_fixture.coordinator,
			method(_context, function(_run, _input, _tick) {
				self.first_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.OwnerRemoval
				).queued;
				self.second_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.OwnerRemoval
				).queued;
				BladeRunCombatPlayerEmit(
					self.coordinator, self.player_id,
					_BladeCombatRuntimeTestsSpec(), self.box
				);
				return undefined;
			})
		);
		var _snapshot = BladeRunCombatSnapshot(_fixture.coordinator);
		BladeKernelTestAssertTrue(_context.first_queued, "first cleanup request queues");
		BladeKernelTestAssertFalse(_context.second_queued, "duplicate request is idempotent");
		BladeKernelTestAssertEqual(
			array_length(_snapshot.damage_transactions), 1,
			"lethal damage competes in the same tick"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsTerminalCount(
				_snapshot, BladeCombatTerminalReason.OwnerRemoval,
				BladeCombatSubjectKind.Actor
			),
			1, "higher-priority administrative reason wins"
		);
		BladeKernelTestAssertEqual(array_length(_snapshot.reward_requests), 0, "cleanup grants no reward");
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsContentCount(_snapshot, "ghost.medium"), 0,
			"cleanup creates no defeat children"
		);
	});

	BladeKernelTestRunCase(_state, "Ghost defeat lineage is exactly one to three to nine", function() {
		var _fixture = _BladeCombatRuntimeTestsGhostFixture();
		var _large_context = {
			coordinator: _fixture.coordinator,
			large_id: _fixture.large.instance_id,
			box: _fixture.box,
			duplicate_queued: true,
		};
		_BladeCombatRuntimeTestsStep(
			_fixture.coordinator,
			method(_large_context, function(_run, _input, _tick) {
				BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.Defeat
				);
				self.duplicate_queued = BladeRunCombatRequestTerminal(
					self.coordinator, BladeCombatSubjectKind.Actor,
					self.large_id, BladeCombatTerminalReason.Defeat
				).queued;
				BladeRunCombatPlayerEmit(
					self.coordinator, "ins:1", _BladeCombatRuntimeTestsSpec(), self.box
				);
				return undefined;
			})
		);
		var _mediums = BladeRunCombatSnapshot(_fixture.coordinator);
		BladeKernelTestAssertFalse(_large_context.duplicate_queued, "duplicate defeat queues once");
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsContentCount(_mediums, "ghost.medium"), 3,
			"one large defeat creates three medium actors"
		);
		BladeKernelTestAssertEqual(array_length(_mediums.reward_requests), 1, "large reward queues once");
		BladeKernelTestAssertEqual(
			_mediums.reward_requests[0].reason, BladeCombatTerminalReason.Defeat,
			"reward reason cannot impersonate cleanup"
		);

		var _medium_context = { coordinator: _fixture.coordinator, box: _fixture.box };
		_BladeCombatRuntimeTestsStep(
			_fixture.coordinator,
			method(_medium_context, function(_run, _input, _tick) {
				for (var _index = 0; _index < 3; ++_index) {
					BladeRunCombatPlayerEmit(
						self.coordinator, "ins:1",
						_BladeCombatRuntimeTestsSpec(), self.box
					);
				}
				return undefined;
			})
		);
		var _smalls = BladeRunCombatSnapshot(_fixture.coordinator);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsContentCount(_smalls, "ghost.medium"), 0,
			"all three medium actors are defeated"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsContentCount(_smalls, "ghost.small"), 9,
			"three medium defeats create nine small actors"
		);
		BladeKernelTestAssertEqual(
			array_length(_smalls.reward_requests), 1,
			"nonrewarding medium declarations add no reward"
		);
	});

	BladeKernelTestRunCase(_state, "room reset complete abort and load clear combat explicitly", function() {
		var _room = _BladeCombatRuntimeTestsGhostFixture();
		var _room_result = BladeRunCombatRoomExit(_room.coordinator);
		BladeKernelTestAssertEqual(
			_room_result.combat_boundary_report.terminals[0].reason,
			BladeCombatTerminalReason.RoomExit, "room-exit reason"
		);
		BladeKernelTestAssertEqual(
			array_length(BladeRunCombatSnapshot(_room.coordinator).actors), 0,
			"room exit clears active combat while run stays active"
		);
		BladeKernelTestAssertEqual(
			array_length(_room_result.combat_boundary_report.rewards), 0,
			"room exit is nonrewarding"
		);

		var _reset = _BladeCombatRuntimeTestsGhostFixture();
		var _reset_result = BladeRunCoordinatorReset(
			_reset.coordinator, "ship.maynii", "difficulty.normal",
			BladeRunMode.Normal, 305419896
		);
		BladeKernelTestAssertEqual(
			_reset_result.prior_combat_boundary_report.terminals[0].reason,
			BladeCombatTerminalReason.RunReset, "reset reason"
		);
		BladeKernelTestAssertEqual(
			array_length(_reset_result.combat.actors), 0, "reset installs empty combat"
		);
		BladeKernelTestAssertFalse(is_undefined(_reset_result.combat.plane), "reset retains product plane");

		var _complete = _BladeCombatRuntimeTestsGhostFixture();
		var _complete_result = BladeRunCoordinatorComplete(_complete.coordinator);
		BladeKernelTestAssertEqual(
			_complete_result.combat_boundary_report.terminals[0].reason,
			BladeCombatTerminalReason.RunCompleted, "completion reason"
		);
		BladeKernelTestAssertEqual(
			array_length(_complete_result.combat_boundary_report.children), 0,
			"completion creates no children"
		);

		var _abort = _BladeCombatRuntimeTestsGhostFixture();
		var _pause_owner = BladeRunCoordinatorAllocatePauseOwner(_abort.coordinator);
		BladeRunCoordinatorAcquirePause(
			_abort.coordinator, _pause_owner, "pause.abort_combat",
			BladeClockDomain.Combat, BladePauseReleasePolicy.Explicit
		);
		var _abort_result = BladeRunCoordinatorAbort(_abort.coordinator);
		BladeKernelTestAssertEqual(
			_abort_result.combat_boundary_report.terminals[0].reason,
			BladeCombatTerminalReason.RunAborted, "abort reason while paused"
		);
		BladeKernelTestAssertEqual(
			array_length(_abort_result.combat_boundary_report.rewards), 0,
			"abort while paused is nonrewarding"
		);

		var _load = _BladeCombatRuntimeTestsGhostFixture();
		var _load_result = BladeRunCoordinatorLoadBoundary(_load.coordinator);
		BladeKernelTestAssertEqual(
			_load_result.combat_boundary_report.terminals[0].reason,
			BladeCombatTerminalReason.RunLoad, "load reason"
		);
		BladeKernelTestAssertEqual(
			_load_result.pause_boundary_report.boundary,
			"run.load", "load applies the matching pause boundary"
		);
		BladeKernelTestAssertEqual(
			_load_result.lifecycle, BladeRunLifecycle.Aborted,
			"load closes the replaced attempt"
		);
	});

	BladeKernelTestRunCase(_state, "Combat pause freezes transactions while Actor and Presentation advance", function() {
		var _coordinator = _BladeCombatRuntimeTestsCreate();
		var _player = BladeRunCombatRegisterPlayer(
			_coordinator, 10, _BladeCombatRuntimeTestsBox(200000, 200000)
		);
		var _enemy = BladeRunCombatSpawnActor(
			_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 1,
			_BladeCombatRuntimeTestsBox(210000, 100000), 0, true
		);
		var _setup = {
			coordinator: _coordinator, player_id: _player.instance_id,
			projectile_id: "",
		};
		_BladeCombatRuntimeTestsStep(_coordinator, method(_setup, function(_run, _input, _tick) {
			self.projectile_id = BladeRunCombatPlayerEmit(
				self.coordinator, self.player_id, _BladeCombatRuntimeTestsSpec(),
				_BladeCombatRuntimeTestsBox(200000, 100000)
			).projectile_id;
			return undefined;
		}));
		var _pause_owner = BladeRunCoordinatorAllocatePauseOwner(_coordinator);
		var _token = BladeRunCoordinatorAcquirePause(
			_coordinator, _pause_owner, "pause.combat_test",
			BladeClockDomain.Combat, BladePauseReleasePolicy.Explicit
		);
		var _paused_context = {
			coordinator: _coordinator, enemy_id: _enemy.instance_id,
			box: _BladeCombatRuntimeTestsBox(215000, 100000),
			emission_blocked: false,
		};
		var _paused_step = _BladeCombatRuntimeTestsStep(
			_coordinator,
			method(_paused_context, function(_run, _input, _tick) {
				BladeRunCombatSetActorBox(self.coordinator, self.enemy_id, self.box);
				try {
					BladeRunCombatEnemyEmit(
						self.coordinator, self.enemy_id,
						_BladeCombatRuntimeTestsSpec(), self.box,
						BladeCombatGateKind.Point,
						{ x_q10: 215000, y_q10: 100000 }
					);
				} catch (_caught) {
					self.emission_blocked = string_pos(
						"requires its eligible simulation tick", string(_caught)
					) > 0;
				}
				return undefined;
			})
		);
		var _paused = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(_paused_step.counters.combat_tick, int64(1), "Combat clock frozen");
		BladeKernelTestAssertEqual(_paused_step.counters.actor_tick, int64(2), "Actor clock advances");
		BladeKernelTestAssertEqual(
			_paused_step.counters.presentation_tick, int64(2), "Presentation advances"
		);
		BladeKernelTestAssertEqual(array_length(_paused.damage_transactions), 0, "damage stays frozen");
		BladeKernelTestAssertEqual(array_length(_paused.reward_requests), 0, "rewards stay frozen");
		BladeKernelTestAssertTrue(
			_paused_context.emission_blocked, "paused emission is rejected before allocation"
		);
		BladeKernelTestAssertEqual(
			array_length(_paused.attacks), 1, "paused attempt creates no attack"
		);
		BladeKernelTestAssertEqual(
			_BladeCombatRuntimeTestsActor(_paused, _enemy.instance_id).current_box.left_q10,
			int64(215000), "outside combat, visible actor pose still advances"
		);
		BladeRunCoordinatorReleasePause(_coordinator, _pause_owner, _token.token_id);
		var _resume = {
			coordinator: _coordinator, projectile_id: _setup.projectile_id,
		};
		_BladeCombatRuntimeTestsStep(_coordinator, method(_resume, function(_run, _input, _tick) {
			BladeRunCombatMoveProjectile(
				self.coordinator, self.projectile_id,
				_BladeCombatRuntimeTestsBox(220000, 100000)
			);
			return undefined;
		}));
		var _resumed = BladeRunCombatSnapshot(_coordinator);
		BladeKernelTestAssertEqual(array_length(_resumed.damage_transactions), 1, "damage resumes");
		BladeKernelTestAssertEqual(array_length(_resumed.reward_requests), 1, "defeat reward resumes");
	});

	BladeKernelTestRunCase(_state, "combat state is canonical repeatable and publicly detached", function() {
		var _first = _BladeCombatRuntimeTestsGateSequence([200000, 300000]);
		var _second = _BladeCombatRuntimeTestsGateSequence([200000, 300000]);
		BladeKernelTestAssertEqual(
			_first.diagnostics.canonical, _second.diagnostics.canonical,
			"equal combat commands produce equal coordinator bytes"
		);
		var _coordinator = _BladeCombatRuntimeTestsCreate();
		BladeRunCombatSpawnActor(
			_coordinator, "enemy.fixture", BladeCombatFaction.Enemy, 10,
			_BladeCombatRuntimeTestsBox(300000, 100000)
		);
		var _canonical = BladeRunCoordinatorCanonical(_coordinator);
		var _snapshot = BladeRunCombatSnapshot(_coordinator);
		_snapshot.actors[0].health = 0;
		_snapshot.actors[0].current_box.left_q10 = 0;
		_snapshot.plane.left_q10 = 0;
		BladeKernelTestAssertEqual(
			BladeRunCoordinatorCanonical(_coordinator), _canonical,
			"mutated public combat views cannot reach ownership"
		);
	});

	return _state;
}
