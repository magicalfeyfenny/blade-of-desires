/// @description Deterministic, composable ownership for simulation pause domains.

enum BladePauseReleasePolicy {
    Explicit = 0,
    OwnerDestroyed = 1,
    RoomExit = 2,
    RunBoundary = 3
}

enum BladePauseRunBoundary {
    Completed = 0,
    Aborted = 1,
    Reset = 2,
    Load = 3
}

/// Throws a field-specific pause-registry error without relying on display text as state.
function _BladePauseRegistryFail(_field, _reason) {
    throw("BladePauseRegistry: " + _field + ": " + _reason);
}

/// Rejects values that are not version 1 registries before internal state is accessed.
function _BladePauseRegistryRequire(_registry) {
    if (!is_struct(_registry)
        || !variable_struct_exists(_registry, "__blade_pause_registry_version")
        || _registry.__blade_pause_registry_version != 1) {
        _BladePauseRegistryFail("registry", "expected a version 1 pause registry");
    }
    if (!is_array(_registry.active_tokens) || !is_array(_registry.diagnostics)) {
        _BladePauseRegistryFail("registry", "token and diagnostic storage must be arrays");
    }
    BladeRunIdentityGetCounters(_registry.identity);
    BladeCanonicalRequireInteger(
        _registry.next_token_ordinal,
        1,
        int64("9223372036854775807"),
        "pause token frontier"
    );
    BladeCanonicalRequireInteger(
        _registry.next_diagnostic_ordinal,
        1,
        int64("9223372036854775807"),
        "pause diagnostic frontier"
    );
}

/// Converts one exact nonnegative integer to the tick representation shared by pause records.
function _BladePauseRegistryTick(_value, _field) {
    return BladeCanonicalRequireInteger(
        _value,
        0,
        int64("9223372036854775807"),
        _field
    );
}

/// Accepts one declared release-policy enum value and normalizes it to int64.
function _BladePauseRegistryReleasePolicy(_value) {
    return BladeCanonicalRequireInteger(
        _value,
        BladePauseReleasePolicy.Explicit,
        BladePauseReleasePolicy.RunBoundary,
        "pause release policy"
    );
}

/// Accepts one run-boundary enum value and normalizes it to int64.
function _BladePauseRegistryRunBoundary(_value) {
    return BladeCanonicalRequireInteger(
        _value,
        BladePauseRunBoundary.Completed,
        BladePauseRunBoundary.Load,
        "pause run boundary"
    );
}

/// Converts a run-boundary enum to the stable diagnostic token stored in reports.
function _BladePauseRegistryRunBoundaryCode(_boundary) {
    switch (_BladePauseRegistryRunBoundary(_boundary)) {
        case BladePauseRunBoundary.Completed: return "run.completed";
        case BladePauseRunBoundary.Aborted: return "run.aborted";
        case BladePauseRunBoundary.Reset: return "run.reset";
        case BladePauseRunBoundary.Load: return "run.load";
    }
    _BladePauseRegistryFail("run boundary", "unreachable boundary value");
}

/// Validates an already allocated deterministic event-owner ID without advancing identity state.
function _BladePauseRegistryOwner(_registry, _owner_id, _field) {
    try {
        return BladeRunIdentityRequireAllocated(
            _registry.identity,
            _owner_id,
            BladeRunIdKind.EventOwner
        );
    } catch (_caught) {
        _BladePauseRegistryFail(_field, string(_caught));
    }
}

/// Accepts lowercase dotted pause-reason tokens so diagnostics have one byte spelling.
function _BladePauseRegistryReason(_reason) {
    if (!is_string(_reason)
        || string_length(_reason) <= 6
        || string_copy(_reason, 1, 6) != "pause."
        || string_byte_length(_reason) != string_length(_reason)) {
        _BladePauseRegistryFail("reason", "must be a nonempty lowercase ASCII pause.* token");
    }
    for (var i = 1; i <= string_length(_reason); i++) {
        var _byte = string_ord_at(_reason, i);
        var _lower = _byte >= 97 && _byte <= 122;
        var _digit = _byte >= 48 && _byte <= 57;
        if (!_lower && !_digit && _byte != 46 && _byte != 95) {
            _BladePauseRegistryFail("reason", "contains a forbidden byte");
        }
    }
    return _reason;
}

/// Accepts a nonzero combination of Stage, Actor, and Boss without claiming Presentation is pausable.
function _BladePauseRegistryFrozenMask(_domains) {
    var _mask = BladeCanonicalRequireInteger(
        _domains,
        BladeClockDomain.None,
        BladeClockDomain.All,
        "pause domain mask"
    );
    var _allowed = BladeClockDomain.Stage
        | BladeClockDomain.Actor
        | BladeClockDomain.Boss;
    if (_mask == BladeClockDomain.None) {
        _BladePauseRegistryFail("domains", "must freeze at least one simulation domain");
    }
    if ((_mask & ~_allowed) != 0) {
        _BladePauseRegistryFail("domains", "may contain only Stage, Actor, and Boss");
    }
    return _mask;
}

/// Accepts any existing clock-domain combination for a caller's base eligibility mask.
function _BladePauseRegistryRequestedMask(_domains) {
    return BladeCanonicalRequireInteger(
        _domains,
        BladeClockDomain.None,
        BladeClockDomain.All,
        "requested domain mask"
    );
}

/// Recognizes a canonical positive decimal after the pau: prefix without parsing alternate spellings.
function _BladePauseRegistryTokenId(_token_id) {
    if (!is_string(_token_id)
        || string_length(_token_id) < 5
        || string_copy(_token_id, 1, 4) != "pau:") {
        _BladePauseRegistryFail("token ID", "must use pau:positive-decimal");
    }
    var _ordinal_text = string_delete(_token_id, 1, 4);
    if (string_length(_ordinal_text) > 19
        || string_char_at(_ordinal_text, 1) == "0"
        || (string_length(_ordinal_text) == 19
            && string_compare(_ordinal_text, "9223372036854775807") > 0)) {
        _BladePauseRegistryFail("token ID", "must use canonical positive decimal");
    }
    for (var i = 1; i <= string_length(_ordinal_text); i++) {
        var _byte = string_ord_at(_ordinal_text, i);
        if (_byte < 48 || _byte > 57) {
            _BladePauseRegistryFail("token ID", "must use canonical positive decimal");
        }
    }
    var _ordinal = int64(_ordinal_text);
    if (_ordinal < 1 || string(_ordinal) != _ordinal_text) {
        _BladePauseRegistryFail("token ID", "must use canonical positive decimal");
    }
    return _token_id;
}

/// Copies one token so callers cannot mutate the registry through returned diagnostics or snapshots.
function _BladePauseRegistryCopyToken(_token) {
    return {
        token_id: _token.token_id,
        owner_id: _token.owner_id,
        reason: _token.reason,
        domains: _token.domains,
        acquisition_tick: _token.acquisition_tick,
        release_policy: _token.release_policy,
    };
}

/// Copies one diagnostic record so its stored fields remain immutable to callers.
function _BladePauseRegistryCopyDiagnostic(_diagnostic) {
    return {
        diagnostic_id: _diagnostic.diagnostic_id,
        code: _diagnostic.code,
        token_id: _diagnostic.token_id,
        owner_id: _diagnostic.owner_id,
        requested_owner_id: _diagnostic.requested_owner_id,
        boundary: _diagnostic.boundary,
        observed_tick: _diagnostic.observed_tick,
    };
}

/// Returns the active-token index for one ID, or -1 when no active token has that ID.
function _BladePauseRegistryFindToken(_registry, _token_id) {
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        if (_registry.active_tokens[i].token_id == _token_id) {
            return i;
        }
    }
    return -1;
}

/// Rejects command chronology that claims a known token was observed before acquisition.
function _BladePauseRegistryRequireObservedToken(_token, _observed_tick) {
    if (_observed_tick < _token.acquisition_tick) {
        _BladePauseRegistryFail(
            "observed tick",
            "cannot precede acquisition of " + _token.token_id
        );
    }
}

/// Removes exactly one indexed token while preserving every other token's acquisition order.
function _BladePauseRegistryRemoveToken(_registry, _index) {
    var _removed = _registry.active_tokens[_index];
    var _remaining = [];
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        if (i != _index) {
            array_push(_remaining, _registry.active_tokens[i]);
        }
    }
    _registry.active_tokens = _remaining;
    return _removed;
}

/// Rejects a planned diagnostic count that would exhaust the signed int64 frontier.
function _BladePauseRegistryRequireDiagnosticCapacity(_registry, _count) {
    var _amount = BladeCanonicalRequireInteger(
        _count,
        0,
        int64("9223372036854775807"),
        "pause diagnostic count"
    );
    var _maximum = int64("9223372036854775807");
    if (_amount > _maximum - _registry.next_diagnostic_ordinal) {
        _BladePauseRegistryFail("diagnostics", "exhausted signed int64 capacity");
    }
}

/// Appends one stable diagnostic after callers have preflighted any multi-record operation.
function _BladePauseRegistryEmitDiagnostic(
    _registry,
    _code,
    _token_id,
    _owner_id,
    _requested_owner_id,
    _boundary,
    _observed_tick
) {
    _BladePauseRegistryRequireDiagnosticCapacity(_registry, 1);
    var _diagnostic = {
        diagnostic_id: "pdiag:" + string(_registry.next_diagnostic_ordinal),
        code: _code,
        token_id: _token_id,
        owner_id: _owner_id,
        requested_owner_id: _requested_owner_id,
        boundary: _boundary,
        observed_tick: _observed_tick,
    };
    _registry.next_diagnostic_ordinal += int64(1);
    array_push(_registry.diagnostics, _diagnostic);
    return _diagnostic;
}

/// Builds a detached lifecycle report from ordered released, retained, and diagnostic records.
function _BladePauseRegistryBoundaryReport(
    _boundary,
    _released,
    _retained,
    _diagnostics
) {
    var _released_copies = [];
    for (var i = 0; i < array_length(_released); i++) {
        array_push(_released_copies, _BladePauseRegistryCopyToken(_released[i]));
    }
    var _retained_copies = [];
    for (var i = 0; i < array_length(_retained); i++) {
        array_push(_retained_copies, _BladePauseRegistryCopyToken(_retained[i]));
    }
    var _diagnostic_copies = [];
    for (var i = 0; i < array_length(_diagnostics); i++) {
        array_push(
            _diagnostic_copies,
            _BladePauseRegistryCopyDiagnostic(_diagnostics[i])
        );
    }
    return {
        boundary: _boundary,
        released_tokens: _released_copies,
        retained_tokens: _retained_copies,
        diagnostics: _diagnostic_copies,
    };
}

/// Encodes one active token in fixed field order for coordinator canonical state.
function _BladePauseRegistryTokenCanonical(_token) {
    return BladeCanonicalRecord("BPT1", [
        _token.token_id,
        _token.owner_id,
        _token.reason,
        string(_token.domains),
        string(_token.acquisition_tick),
        string(_token.release_policy),
    ]);
}

/// Encodes one diagnostic in fixed field order so equal invalid commands remain comparable.
function _BladePauseRegistryDiagnosticCanonical(_diagnostic) {
    return BladeCanonicalRecord("BPD1", [
        _diagnostic.diagnostic_id,
        _diagnostic.code,
        _diagnostic.token_id,
        _diagnostic.owner_id,
        _diagnostic.requested_owner_id,
        _diagnostic.boundary,
        string(_diagnostic.observed_tick),
    ]);
}

/// @func BladePauseRegistryCreate(identity)
/// Creates an empty version 1 registry sharing a deterministic owner-ID allocator.
function BladePauseRegistryCreate(_identity) {
    BladeRunIdentityGetCounters(_identity);
    return {
        __blade_pause_registry_version: 1,
        identity: _identity,
        next_token_ordinal: int64(1),
        next_diagnostic_ordinal: int64(1),
        active_tokens: [],
        diagnostics: [],
    };
}

/// @func BladePauseRegistryAcquire(registry, owner_id, reason, domains, acquisition_tick, release_policy)
/// Validates every field before consuming one deterministic pau: ordinal and storing the token.
function BladePauseRegistryAcquire(
    _registry,
    _owner_id,
    _reason,
    _domains,
    _acquisition_tick,
    _release_policy
) {
    _BladePauseRegistryRequire(_registry);
    var _owner = _BladePauseRegistryOwner(_registry, _owner_id, "owner ID");
    var _stable_reason = _BladePauseRegistryReason(_reason);
    var _mask = _BladePauseRegistryFrozenMask(_domains);
    var _tick = _BladePauseRegistryTick(_acquisition_tick, "acquisition tick");
    var _policy = _BladePauseRegistryReleasePolicy(_release_policy);
    if (_registry.next_token_ordinal >= int64("9223372036854775807")) {
        _BladePauseRegistryFail("token IDs", "exhausted signed int64 capacity");
    }

    var _token = {
        token_id: "pau:" + string(_registry.next_token_ordinal),
        owner_id: _owner,
        reason: _stable_reason,
        domains: _mask,
        acquisition_tick: _tick,
        release_policy: _policy,
    };
    _registry.next_token_ordinal += int64(1);
    array_push(_registry.active_tokens, _token);
    return _BladePauseRegistryCopyToken(_token);
}

/// @func BladePauseRegistryRelease(registry, owner_id, token_id, observed_tick)
/// Releases only a token held by the requesting owner; unknown and mismatched commands diagnose safely.
function BladePauseRegistryRelease(
    _registry,
    _owner_id,
    _token_id,
    _observed_tick
) {
    _BladePauseRegistryRequire(_registry);
    var _owner = _BladePauseRegistryOwner(_registry, _owner_id, "requested owner ID");
    var _stable_token_id = _BladePauseRegistryTokenId(_token_id);
    var _tick = _BladePauseRegistryTick(_observed_tick, "release tick");
    var _index = _BladePauseRegistryFindToken(_registry, _stable_token_id);
    if (_index < 0) {
        var _unknown = _BladePauseRegistryEmitDiagnostic(
            _registry,
            "pause.unknown_release",
            _stable_token_id,
            "",
            _owner,
            "release.explicit",
            _tick
        );
        return {
            released: false,
            token: undefined,
            diagnostic: _BladePauseRegistryCopyDiagnostic(_unknown),
        };
    }

    var _token = _registry.active_tokens[_index];
    _BladePauseRegistryRequireObservedToken(_token, _tick);
    if (_token.owner_id != _owner) {
        var _mismatch = _BladePauseRegistryEmitDiagnostic(
            _registry,
            "pause.release_owner_mismatch",
            _stable_token_id,
            _token.owner_id,
            _owner,
            "release.explicit",
            _tick
        );
        return {
            released: false,
            token: undefined,
            diagnostic: _BladePauseRegistryCopyDiagnostic(_mismatch),
        };
    }

    var _released = _BladePauseRegistryRemoveToken(_registry, _index);
    return {
        released: true,
        token: _BladePauseRegistryCopyToken(_released),
        diagnostic: undefined,
    };
}

/// @func BladePauseRegistryTransfer(registry, owner_id, token_id, new_owner_id, new_policy, observed_tick)
/// Transfers one active token only from its current owner while preserving its identity and acquisition.
function BladePauseRegistryTransfer(
    _registry,
    _owner_id,
    _token_id,
    _new_owner_id,
    _new_policy,
    _observed_tick
) {
    _BladePauseRegistryRequire(_registry);
    var _owner = _BladePauseRegistryOwner(_registry, _owner_id, "requested owner ID");
    var _new_owner = _BladePauseRegistryOwner(_registry, _new_owner_id, "new owner ID");
    var _stable_token_id = _BladePauseRegistryTokenId(_token_id);
    var _policy = _BladePauseRegistryReleasePolicy(_new_policy);
    var _tick = _BladePauseRegistryTick(_observed_tick, "transfer tick");
    var _index = _BladePauseRegistryFindToken(_registry, _stable_token_id);
    if (_index < 0) {
        var _unknown = _BladePauseRegistryEmitDiagnostic(
            _registry,
            "pause.unknown_transfer",
            _stable_token_id,
            "",
            _owner,
            "transfer.explicit",
            _tick
        );
        return {
            transferred: false,
            token: undefined,
            diagnostic: _BladePauseRegistryCopyDiagnostic(_unknown),
        };
    }

    var _token = _registry.active_tokens[_index];
    _BladePauseRegistryRequireObservedToken(_token, _tick);
    if (_token.owner_id != _owner) {
        var _mismatch = _BladePauseRegistryEmitDiagnostic(
            _registry,
            "pause.transfer_owner_mismatch",
            _stable_token_id,
            _token.owner_id,
            _owner,
            "transfer.explicit",
            _tick
        );
        return {
            transferred: false,
            token: undefined,
            diagnostic: _BladePauseRegistryCopyDiagnostic(_mismatch),
        };
    }

    _token.owner_id = _new_owner;
    _token.release_policy = _policy;
    return {
        transferred: true,
        token: _BladePauseRegistryCopyToken(_token),
        diagnostic: undefined,
    };
}

/// @func BladePauseRegistryFrozenDomains(registry)
/// Returns the union of all active token masks without exposing the mutable token array.
function BladePauseRegistryFrozenDomains(_registry) {
    _BladePauseRegistryRequire(_registry);
    var _frozen = BladeClockDomain.None;
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        _frozen |= _registry.active_tokens[i].domains;
    }
    return _frozen;
}

/// @func BladePauseRegistryResolveDomains(registry, requested_domains)
/// Removes every actively frozen simulation bit from the caller's preexisting eligibility mask.
function BladePauseRegistryResolveDomains(_registry, _requested_domains) {
    _BladePauseRegistryRequire(_registry);
    var _requested = _BladePauseRegistryRequestedMask(_requested_domains);
    return _requested & ~BladePauseRegistryFrozenDomains(_registry);
}

/// @func BladePauseRegistryOwnerDestroyed(registry, owner_id, observed_tick)
/// Releases that owner's tokens; policies expecting a longer lifetime diagnose a missing transfer.
function BladePauseRegistryOwnerDestroyed(_registry, _owner_id, _observed_tick) {
    _BladePauseRegistryRequire(_registry);
    var _owner = _BladePauseRegistryOwner(_registry, _owner_id, "destroyed owner ID");
    var _tick = _BladePauseRegistryTick(_observed_tick, "owner destruction tick");
    var _leak_count = int64(0);
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        var _candidate = _registry.active_tokens[i];
        _BladePauseRegistryRequireObservedToken(_candidate, _tick);
        if (_candidate.owner_id == _owner
            && _candidate.release_policy != BladePauseReleasePolicy.OwnerDestroyed) {
            _leak_count += int64(1);
        }
    }
    _BladePauseRegistryRequireDiagnosticCapacity(_registry, _leak_count);

    var _released = [];
    var _retained = [];
    var _diagnostics = [];
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        var _token = _registry.active_tokens[i];
        if (_token.owner_id != _owner) {
            array_push(_retained, _token);
            continue;
        }
        if (_token.release_policy != BladePauseReleasePolicy.OwnerDestroyed) {
            array_push(_diagnostics, _BladePauseRegistryEmitDiagnostic(
                _registry,
                "pause.leaked_token",
                _token.token_id,
                _token.owner_id,
                "",
                "owner.destroyed",
                _tick
            ));
        }
        array_push(_released, _token);
    }
    _registry.active_tokens = _retained;
    return _BladePauseRegistryBoundaryReport(
        "owner.destroyed",
        _released,
        _retained,
        _diagnostics
    );
}

/// @func BladePauseRegistryRoomExit(registry, run_owner_id, observed_tick)
/// Releases room-lifetime tokens and retains only RunBoundary tokens already held by the run owner.
function BladePauseRegistryRoomExit(_registry, _run_owner_id, _observed_tick) {
    _BladePauseRegistryRequire(_registry);
    var _run_owner = _BladePauseRegistryOwner(_registry, _run_owner_id, "run owner ID");
    var _tick = _BladePauseRegistryTick(_observed_tick, "room exit tick");
    var _leak_count = int64(0);
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        var _candidate = _registry.active_tokens[i];
        _BladePauseRegistryRequireObservedToken(_candidate, _tick);
        var _retains = _candidate.release_policy == BladePauseReleasePolicy.RunBoundary
            && _candidate.owner_id == _run_owner;
        if (!_retains
            && (_candidate.release_policy == BladePauseReleasePolicy.Explicit
                || _candidate.release_policy == BladePauseReleasePolicy.RunBoundary)) {
            _leak_count += int64(1);
        }
    }
    _BladePauseRegistryRequireDiagnosticCapacity(_registry, _leak_count);

    var _released = [];
    var _retained = [];
    var _diagnostics = [];
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        var _token = _registry.active_tokens[i];
        var _retains = _token.release_policy == BladePauseReleasePolicy.RunBoundary
            && _token.owner_id == _run_owner;
        if (_retains) {
            array_push(_retained, _token);
            continue;
        }
        if (_token.release_policy == BladePauseReleasePolicy.Explicit
            || _token.release_policy == BladePauseReleasePolicy.RunBoundary) {
            array_push(_diagnostics, _BladePauseRegistryEmitDiagnostic(
                _registry,
                "pause.leaked_token",
                _token.token_id,
                _token.owner_id,
                "",
                "room.exit",
                _tick
            ));
        }
        array_push(_released, _token);
    }
    _registry.active_tokens = _retained;
    return _BladePauseRegistryBoundaryReport(
        "room.exit",
        _released,
        _retained,
        _diagnostics
    );
}

/// @func BladePauseRegistryRunBoundary(registry, boundary, observed_tick)
/// Releases every token at a terminal/replacement boundary and diagnoses unreleased Explicit tokens.
function BladePauseRegistryRunBoundary(_registry, _boundary, _observed_tick) {
    _BladePauseRegistryRequire(_registry);
    var _boundary_code = _BladePauseRegistryRunBoundaryCode(_boundary);
    var _tick = _BladePauseRegistryTick(_observed_tick, "run boundary tick");
    var _leak_count = int64(0);
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        _BladePauseRegistryRequireObservedToken(_registry.active_tokens[i], _tick);
        if (_registry.active_tokens[i].release_policy == BladePauseReleasePolicy.Explicit) {
            _leak_count += int64(1);
        }
    }
    _BladePauseRegistryRequireDiagnosticCapacity(_registry, _leak_count);

    var _released = _registry.active_tokens;
    var _diagnostics = [];
    for (var i = 0; i < array_length(_released); i++) {
        var _token = _released[i];
        if (_token.release_policy == BladePauseReleasePolicy.Explicit) {
            array_push(_diagnostics, _BladePauseRegistryEmitDiagnostic(
                _registry,
                "pause.leaked_token",
                _token.token_id,
                _token.owner_id,
                "",
                _boundary_code,
                _tick
            ));
        }
    }
    _registry.active_tokens = [];
    return _BladePauseRegistryBoundaryReport(
        _boundary_code,
        _released,
        [],
        _diagnostics
    );
}

/// @func BladePauseRegistrySnapshot(registry)
/// Returns detached frontiers, union mask, active tokens, and diagnostics for read-only consumers.
function BladePauseRegistrySnapshot(_registry) {
    _BladePauseRegistryRequire(_registry);
    var _tokens = [];
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        array_push(_tokens, _BladePauseRegistryCopyToken(_registry.active_tokens[i]));
    }
    var _diagnostics = [];
    for (var i = 0; i < array_length(_registry.diagnostics); i++) {
        array_push(
            _diagnostics,
            _BladePauseRegistryCopyDiagnostic(_registry.diagnostics[i])
        );
    }
    return {
        next_token_ordinal: _registry.next_token_ordinal,
        next_diagnostic_ordinal: _registry.next_diagnostic_ordinal,
        frozen_domains: BladePauseRegistryFrozenDomains(_registry),
        active_tokens: _tokens,
        diagnostics: _diagnostics,
    };
}

/// @func BladePauseRegistryCanonical(registry)
/// Encodes token/diagnostic frontiers and ordered records for inclusion in coordinator state.
function BladePauseRegistryCanonical(_registry) {
    _BladePauseRegistryRequire(_registry);
    var _tokens = [];
    for (var i = 0; i < array_length(_registry.active_tokens); i++) {
        array_push(
            _tokens,
            _BladePauseRegistryTokenCanonical(_registry.active_tokens[i])
        );
    }
    var _diagnostics = [];
    for (var i = 0; i < array_length(_registry.diagnostics); i++) {
        array_push(
            _diagnostics,
            _BladePauseRegistryDiagnosticCanonical(_registry.diagnostics[i])
        );
    }
    return BladeCanonicalRecord("BPR1", [
        string(_registry.next_token_ordinal),
        string(_registry.next_diagnostic_ordinal),
        string(BladePauseRegistryFrozenDomains(_registry)),
        BladeCanonicalRecord("BPTS1", _tokens),
        BladeCanonicalRecord("BPDS1", _diagnostics),
    ]);
}
