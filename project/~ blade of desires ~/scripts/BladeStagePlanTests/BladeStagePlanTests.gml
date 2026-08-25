/// @description Focused raw normalization and constructor-preflight tests for stage plans.

/// Registers canonical data, graph-state, plane, and fingerprint cases.
function BladeStagePlanTestsRun(_state) {
	BladeKernelTestRunCase(_state, "stage catalog normalization ignores authored collection order", function() {
		var _plane = _BladeStageTestsPlane();
		var _raw = _BladeStageTestsRawCatalog();
		var _first = BladeStageCatalogNormalize(_raw, _plane);
		var _second = BladeStageCatalogNormalize(
			_BladeStageTestsReorderedRaw(_raw), _plane
		);
		BladeKernelTestAssertEqual(
			BladeStageNormalizedPlanCanonical(_first),
			BladeStageNormalizedPlanCanonical(_second),
			"reordered raw definitions normalize to identical bytes"
		);
		BladeKernelTestAssertEqual(
			BladeStageNormalizedPlanFingerprint(_first),
			BladeStageNormalizedPlanFingerprint(_second),
			"reordered raw definitions share plan fingerprint"
		);
		BladeKernelTestAssertEqual(
			_first.catalogs[0].stages[0].nodes[0].content_order, int64(0),
			"stage nodes normalize by content order"
		);
		BladeKernelTestAssertEqual(
			_first.catalogs[0].encounters[0].participants[1].spawn_order, int64(1),
			"participants normalize by spawn order"
		);
	});

	BladeKernelTestRunCase(_state, "raw source variants expand and normalized data detaches", function() {
		var _raw = _BladeStageTestsRawCatalog();
		var _normalized = BladeStageCatalogNormalize(_raw, _BladeStageTestsPlane());
		var _signals = _normalized.catalogs[0].signals;
		var _external = _BladeStagePlanFind(
			_signals, "signal.neutral_stage.release"
		);
		var _task = _BladeStagePlanFind(
			_signals, "signal.neutral_stage.task_completed"
		);
		BladeKernelTestAssertTrue(
			is_undefined(_external.source.task_port_id)
				&& is_undefined(_external.source.encounter_id),
			"external source expands both null references"
		);
		BladeKernelTestAssertEqual(
			_task.source.task_port_id, "task_port.neutral_stage.probe",
			"task source expands its reciprocal port"
		);
		_raw.signals[0].id = "signal.mutated";
		BladeKernelTestAssertEqual(
			_normalized.catalogs[0].signals[0].id,
			"signal.neutral_stage.encounter_completed",
			"accepted plan does not retain caller records"
		);
	});

	BladeKernelTestRunCase(_state, "stage preflight rejects bad plane geometry and offset bounds", function() {
		var _outside = _BladeStageTestsRawCatalog();
		_outside.named_anchors[0].x_q10 = int64(465920);
		var _outside_context = {
			raw: _outside,
			plane: _BladeStageTestsPlane(),
		};
		BladeKernelTestAssertThrows(method(_outside_context, function() {
			BladeStageCatalogNormalize(self.raw, self.plane);
		}), "named anchor", "outside named anchor fails before construction");

		var _offset = _BladeStageTestsRawCatalog();
		_offset.stages[0].nodes[2].local_offset_q10.x = 1000001;
		var _offset_context = {
			raw: _offset,
			plane: _BladeStageTestsPlane(),
		};
		BladeKernelTestAssertThrows(method(_offset_context, function() {
			BladeStageCatalogNormalize(self.raw, self.plane);
		}), "local_offset_q10.x", "oversized q10 offset is rejected");
	});

	BladeKernelTestRunCase(_state, "stage preflight rejects dangling runtime references", function() {
		var _raw = _BladeStageTestsRawCatalog();
		_raw.stages[0].nodes[2].anchor_id = "anchor.neutral_stage.missing";
		var _context = {
			raw: _raw,
			plane: _BladeStageTestsPlane(),
		};
		BladeKernelTestAssertThrows(method(_context, function() {
			BladeStageCatalogNormalize(self.raw, self.plane);
		}), "unknown anchor", "dangling spawn anchor fails during plan construction");
	});

	BladeKernelTestRunCase(_state, "stage path state rejects overlap and duplicate signal consumption", function() {
		var _overlap = _BladeStageTestsRawCatalog();
		var _prior = _overlap.stages[0].nodes[2];
		var _slot = _overlap.stages[0].nodes[3];
		_overlap.stages[0].nodes[3] = {
			schema_version: 1,
			id: _slot.id,
			display_name: "Invalid overlapping spawn",
			content_order: 3,
			kind: "spawn_encounter",
			encounter_id: _prior.encounter_id,
			anchor_id: _prior.anchor_id,
			local_offset_q10: { x: 0, y: 0 },
			next_node_id: _slot.next_node_id,
		};
		var _overlap_context = {
			raw: _overlap,
			plane: _BladeStageTestsPlane(),
		};
		BladeKernelTestAssertThrows(method(_overlap_context, function() {
			BladeStageCatalogNormalize(self.raw, self.plane);
		}), "overlaps an active", "second active encounter generation is rejected");

		var _duplicate = _BladeStageTestsRawCatalog();
		_duplicate.stages[0].nodes[6].signal = _BladeStagePlanClone(
			_duplicate.stages[0].nodes[5].signal
		);
		var _duplicate_context = {
			raw: _duplicate,
			plane: _BladeStageTestsPlane(),
		};
		BladeKernelTestAssertThrows(method(_duplicate_context, function() {
			BladeStageCatalogNormalize(self.raw, self.plane);
		}), "consumes one signal twice", "duplicate typed signal wait is rejected");
	});

	BladeKernelTestRunCase(_state, "plan fingerprint must bind validated normalized bytes", function() {
		var _plane = _BladeStageTestsPlane();
		var _normalized = BladeStageCatalogNormalize(
			_BladeStageTestsRawCatalog(), _plane
		);
		var _context = { normalized: _normalized, plane: _plane };
		BladeKernelTestAssertThrows(method(_context, function() {
			BladeStagePlanCreate(
				self.normalized,
				"sha1:0000000000000000000000000000000000000000",
				"stage_schedule.neutral_fixture", self.plane
			);
		}), "does not match", "caller cannot lie about plan fingerprint");
		var _plan = BladeStagePlanCreate(
			_normalized, BladeStageNormalizedPlanFingerprint(_normalized),
			"stage_schedule.neutral_fixture", _plane
		);
		BladeKernelTestAssertEqual(
			_plan.stage.id, "stage_schedule.neutral_fixture",
			"matching plan fingerprint constructs selected stage"
		);
	});
}
