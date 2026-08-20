/// @description Versioned, reason-coded deterministic gameplay event log.

enum BladeEventChannel {
    Gameplay = 0,
    Presentation = 1
}

function _BladeEventLogFail(_field, _reason) {
    throw("BladeEventLog: " + _field + ": " + _reason);
}

function _BladeEventLogRequire(_log) {
    if (!is_struct(_log)
        || !variable_struct_exists(_log, "__blade_event_log_version")
        || _log.__blade_event_log_version != 1) {
        _BladeEventLogFail("log", "expected a version 1 event log");
    }
}

function _BladeEventLogAsciiToken(_value, _field, _allow_dot) {
    if (!is_string(_value) || string_length(_value) == 0) {
        _BladeEventLogFail(_field, "must be a nonempty ASCII token");
    }
    if (string_byte_length(_value) != string_length(_value)) {
        _BladeEventLogFail(_field, "must be ASCII");
    }

    for (var i = 1; i <= string_length(_value); i++) {
        var _byte = string_ord_at(_value, i);
        var _lower = _byte >= 97 && _byte <= 122;
        var _digit = _byte >= 48 && _byte <= 57;
        if (!_lower && !_digit && _byte != 95 && !(_allow_dot && _byte == 46)) {
            _BladeEventLogFail(_field, "contains a forbidden byte");
        }
    }
    return _value;
}

function _BladeEventLogInteger(_value, _minimum, _maximum, _field) {
    return BladeCanonicalRequireInteger(_value, _minimum, _maximum, _field);
}

function _BladeEventLogPayloadTypeBounds(_type) {
    switch (_type) {
        case "i32":
            return [int64("-2147483648"), int64("2147483647")];
        case "u32":
            return [int64(0), int64("4294967295")];
        case "q10":
            return [int64("-2147483648"), int64("2147483647")];
        case "bool01":
            return [int64(0), int64(1)];
    }
    _BladeEventLogFail("payload type", "unknown type " + string(_type));
}

/// @func BladeEventPayload(key, type, value)
/// @desc Creates a typed numeric payload entry. q10 stores raw 1/1024 units.
function BladeEventPayload(_key, _type, _value) {
    var _validated_key = _BladeEventLogAsciiToken(_key, "payload key", false);
    var _validated_type = _BladeEventLogAsciiToken(_type, "payload type", false);
    var _bounds = _BladeEventLogPayloadTypeBounds(_validated_type);
    var _validated_value = _BladeEventLogInteger(
        _value,
        _bounds[0],
        _bounds[1],
        "payload " + _validated_key
    );
    return {
        key: _validated_key,
        type: _validated_type,
        value: _validated_value,
    };
}

function _BladeEventLogAsciiCompare(_left, _right) {
    var _left_length = string_length(_left);
    var _right_length = string_length(_right);
    var _shared_length = min(_left_length, _right_length);
    for (var i = 1; i <= _shared_length; i++) {
        var _left_byte = string_ord_at(_left, i);
        var _right_byte = string_ord_at(_right, i);
        if (_left_byte < _right_byte) return -1;
        if (_left_byte > _right_byte) return 1;
    }
    if (_left_length < _right_length) return -1;
    if (_left_length > _right_length) return 1;
    return 0;
}

function _BladeEventLogSortPayload(_payload) {
    if (!is_array(_payload)) {
        _BladeEventLogFail("payload", "must be an array");
    }

    var _sorted = [];
    for (var i = 0; i < array_length(_payload); i++) {
        var _entry = _payload[i];
        if (!is_struct(_entry)
            || !variable_struct_exists(_entry, "key")
            || !variable_struct_exists(_entry, "type")
            || !variable_struct_exists(_entry, "value")) {
            _BladeEventLogFail("payload", "entry " + string(i) + " is malformed");
        }
        var _copy = BladeEventPayload(_entry.key, _entry.type, _entry.value);
        var _insert_at = array_length(_sorted);
        for (var j = 0; j < array_length(_sorted); j++) {
            var _comparison = _BladeEventLogAsciiCompare(_copy.key, _sorted[j].key);
            if (_comparison == 0) {
                _BladeEventLogFail("payload", "duplicate key " + _copy.key);
            }
            if (_comparison < 0) {
                _insert_at = j;
                break;
            }
        }
        array_insert(_sorted, _insert_at, _copy);
    }
    return _sorted;
}

function _BladeEventLogTypeSchema(_type, _reason) {
    switch (_type) {
        case "instance.spawned":
            if (_reason == "outcome.scheduled") {
                return [-1, BladeRunIdKind.Instance];
            }
            break;
        case "attack.started":
            if (_reason == "outcome.input_pressed") {
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
        case "instance.removed":
            if (_reason == "cleanup.stage_end"
                || _reason == "cleanup.owner_removed"
                || _reason == "cleanup.out_of_bounds"
                || _reason == "cancel.phase_change") {
                return [BladeRunIdKind.Instance, -1];
            }
            break;
        case "attack.cancelled":
            if (_reason == "cleanup.owner_removed" || _reason == "cancel.phase_change") {
                return [BladeRunIdKind.Attack, -1];
            }
            break;
        case "bullet.removed":
            if (_reason == "cleanup.stage_end"
                || _reason == "cleanup.owner_removed"
                || _reason == "cleanup.out_of_bounds"
                || _reason == "cancel.phase_change") {
                return [BladeRunIdKind.Bullet, -1];
            }
            break;
        case "damage.cancelled":
            if (_reason == "cleanup.owner_removed" || _reason == "cancel.phase_change") {
                return [BladeRunIdKind.DamageEvent, -1];
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

function _BladeEventLogRequireOptionalId(_identity, _id, _kind, _field) {
    if (_kind < 0) {
        if (_id != "") {
            _BladeEventLogFail(_field, "must be empty for this event type");
        }
        return "";
    }
    if (_id == "") {
        _BladeEventLogFail(_field, "is required for this event type");
    }
    return BladeRunIdentityRequireAllocated(_identity, _id, _kind);
}

function _BladeEventLogPayloadCanonical(_payload) {
    var _fields = [
        BladeCanonicalIntegerString(
            array_length(_payload),
            0,
            1024,
            "payload entry count"
        )
    ];
    for (var i = 0; i < array_length(_payload); i++) {
        array_push(_fields, _payload[i].key);
        array_push(_fields, _payload[i].type);
        array_push(_fields, string(_payload[i].value));
    }
    return BladeCanonicalRecord("P1", _fields);
}

function _BladeEventLogBuildQueued(
    _log,
    _tick,
    _channel,
    _order_key,
    _type,
    _reason,
    _source_id,
    _target_id,
    _owner_id,
    _content_id,
    _payload,
    _enqueue_ordinal
) {
    var _maximum = int64("9223372036854775807");
    var _validated_tick = _BladeEventLogInteger(
        _tick,
        0,
        _maximum,
        "queued tick"
    );
    if (_validated_tick != _log.active_tick) {
        _BladeEventLogFail("queued tick", "must match the active tick");
    }
    var _validated_channel = _BladeEventLogInteger(
        _channel,
        BladeEventChannel.Gameplay,
        BladeEventChannel.Presentation,
        "channel"
    );
    var _validated_order = _BladeEventLogInteger(
        _order_key,
        0,
        int64("2147483647"),
        "order key"
    );
    var _validated_type = _BladeEventLogAsciiToken(_type, "type", true);
    var _validated_reason = _BladeEventLogAsciiToken(_reason, "reason", true);
    var _schema = _BladeEventLogTypeSchema(_validated_type, _validated_reason);
    if (_validated_channel == BladeEventChannel.Presentation
        && _validated_type != "presentation.effect") {
        _BladeEventLogFail("channel", "presentation channel requires a presentation event");
    }
    if (_validated_channel == BladeEventChannel.Gameplay
        && _validated_type == "presentation.effect") {
        _BladeEventLogFail("channel", "gameplay channel rejects presentation events");
    }

    var _validated_source = _BladeEventLogRequireOptionalId(
        _log.identity,
        _source_id,
        _schema[0],
        "source ID"
    );
    var _validated_target = _BladeEventLogRequireOptionalId(
        _log.identity,
        _target_id,
        _schema[1],
        "target ID"
    );
    var _validated_owner = BladeRunIdentityRequireAllocated(
        _log.identity,
        _owner_id,
        BladeRunIdKind.EventOwner
    );
    var _validated_content = BladeRunIdentityRequireContent(
        _log.identity,
        _content_id
    );
    var _validated_payload = _BladeEventLogSortPayload(_payload);
    var _payload_canonical = _BladeEventLogPayloadCanonical(_validated_payload);
    var _validated_ordinal = _BladeEventLogInteger(
        _enqueue_ordinal,
        0,
        _maximum - int64(1),
        "enqueue ordinal"
    );

    return {
        tick: _validated_tick,
        channel: _validated_channel,
        order_key: _validated_order,
        type: _validated_type,
        reason: _validated_reason,
        source_id: _validated_source,
        target_id: _validated_target,
        owner_id: _validated_owner,
        content_id: _validated_content,
        payload: _validated_payload,
        payload_canonical: _payload_canonical,
        enqueue_ordinal: _validated_ordinal,
    };
}

function _BladeEventLogCopyPayload(_payload) {
    var _copy = [];
    for (var i = 0; i < array_length(_payload); i++) {
        array_push(_copy, {
            key: _payload[i].key,
            type: _payload[i].type,
            value: _payload[i].value,
        });
    }
    return _copy;
}

function _BladeEventLogCopyQueued(_queued) {
    return {
        tick: _queued.tick,
        channel: _queued.channel,
        order_key: _queued.order_key,
        type: _queued.type,
        reason: _queued.reason,
        source_id: _queued.source_id,
        target_id: _queued.target_id,
        owner_id: _queued.owner_id,
        content_id: _queued.content_id,
        payload: _BladeEventLogCopyPayload(_queued.payload),
        payload_canonical: _queued.payload_canonical,
        enqueue_ordinal: _queued.enqueue_ordinal,
    };
}

function _BladeEventLogRequirePendingFields(_pending, _index) {
    if (!is_struct(_pending)) {
        _BladeEventLogFail("pending event", "entry " + string(_index) + " must be a struct");
    }
    var _fields = [
        "tick",
        "channel",
        "order_key",
        "type",
        "reason",
        "source_id",
        "target_id",
        "owner_id",
        "content_id",
        "payload",
        "enqueue_ordinal",
    ];
    for (var i = 0; i < array_length(_fields); i++) {
        if (!variable_struct_exists(_pending, _fields[i])) {
            _BladeEventLogFail(
                "pending event",
                "entry " + string(_index) + " is missing " + _fields[i]
            );
        }
    }
}

function _BladeEventLogRebuildPending(_log, _expected_count) {
    if (!is_array(_log.pending)) {
        _BladeEventLogFail("pending events", "must be an array");
    }
    var _count = array_length(_log.pending);
    if (int64(_count) != _expected_count) {
        _BladeEventLogFail("pending events", "count must match the enqueue ordinal");
    }

    var _seen_ordinals = array_create(_count, false);
    var _rebuilt = [];
    var _gameplay_count = int64(0);
    var _presentation_count = int64(0);
    for (var i = 0; i < _count; i++) {
        var _pending = _log.pending[i];
        _BladeEventLogRequirePendingFields(_pending, i);
        var _ordinal = _BladeEventLogInteger(
            _pending.enqueue_ordinal,
            0,
            int64("9223372036854775806"),
            "pending enqueue ordinal"
        );
        if (_ordinal >= int64(_count)) {
            _BladeEventLogFail("pending enqueue ordinal", "must be within the pending array");
        }
        var _ordinal_index = real(_ordinal);
        if (_seen_ordinals[_ordinal_index]) {
            _BladeEventLogFail("pending enqueue ordinal", "must be unique");
        }
        _seen_ordinals[_ordinal_index] = true;

        var _validated = _BladeEventLogBuildQueued(
            _log,
            _pending.tick,
            _pending.channel,
            _pending.order_key,
            _pending.type,
            _pending.reason,
            _pending.source_id,
            _pending.target_id,
            _pending.owner_id,
            _pending.content_id,
            _pending.payload,
            _ordinal
        );
        array_push(_rebuilt, _validated);
        if (_validated.channel == BladeEventChannel.Gameplay) {
            _gameplay_count += int64(1);
        } else {
            _presentation_count += int64(1);
        }
    }
    return {
        pending: _rebuilt,
        gameplay_count: _gameplay_count,
        presentation_count: _presentation_count,
    };
}

function _BladeEventLogCompareQueued(_left, _right) {
    if (_left.order_key < _right.order_key) return -1;
    if (_left.order_key > _right.order_key) return 1;

    var _left_fields = [
        _left.source_id,
        _left.target_id,
        _left.owner_id,
        _left.type,
        _left.reason,
        _left.content_id,
        _left.payload_canonical,
    ];
    var _right_fields = [
        _right.source_id,
        _right.target_id,
        _right.owner_id,
        _right.type,
        _right.reason,
        _right.content_id,
        _right.payload_canonical,
    ];
    for (var i = 0; i < array_length(_left_fields); i++) {
        var _comparison = _BladeEventLogAsciiCompare(_left_fields[i], _right_fields[i]);
        if (_comparison != 0) return _comparison;
    }
    if (_left.enqueue_ordinal < _right.enqueue_ordinal) return -1;
    if (_left.enqueue_ordinal > _right.enqueue_ordinal) return 1;
    return 0;
}

function _BladeEventLogSortQueued(_pending) {
    var _sorted = [];
    for (var i = 0; i < array_length(_pending); i++) {
        var _insert_at = array_length(_sorted);
        for (var j = 0; j < array_length(_sorted); j++) {
            if (_BladeEventLogCompareQueued(_pending[i], _sorted[j]) < 0) {
                _insert_at = j;
                break;
            }
        }
        array_insert(_sorted, _insert_at, _pending[i]);
    }
    return _sorted;
}

function _BladeEventLogRecordCanonical(_record) {
    var _fields = [
        _record.event_id,
        string(_record.tick),
        _record.type,
        _record.reason,
        _record.source_id,
        _record.target_id,
        _record.owner_id,
        _record.content_id,
        string(array_length(_record.payload)),
    ];
    for (var i = 0; i < array_length(_record.payload); i++) {
        array_push(_fields, _record.payload[i].key);
        array_push(_fields, _record.payload[i].type);
        array_push(_fields, string(_record.payload[i].value));
    }
    return BladeCanonicalRecord("E1", _fields);
}

/// @func BladeEventLogCreate(identity)
function BladeEventLogCreate(_identity) {
    BladeRunIdentityGetCounters(_identity);
    return {
        __blade_event_log_version: 1,
        identity: _identity,
        active_tick: int64(-1),
        last_committed_tick: int64(-1),
        enqueue_ordinal: int64(0),
        next_presentation_event: int64(1),
        pending: [],
        gameplay_records: [],
        presentation_records: [],
    };
}

/// @func BladeEventLogReset(log)
function BladeEventLogReset(_log) {
    _BladeEventLogRequire(_log);
    _log.active_tick = int64(-1);
    _log.last_committed_tick = int64(-1);
    _log.enqueue_ordinal = int64(0);
    _log.next_presentation_event = int64(1);
    _log.pending = [];
    _log.gameplay_records = [];
    _log.presentation_records = [];
    return _log;
}

/// @func BladeEventLogBeginTick(log, tick)
function BladeEventLogBeginTick(_log, _tick) {
    _BladeEventLogRequire(_log);
    if (_log.active_tick >= 0 || array_length(_log.pending) != 0) {
        _BladeEventLogFail("tick", "the prior tick has not been committed");
    }
    var _validated_tick = _BladeEventLogInteger(
        _tick,
        0,
        int64("9223372036854775807"),
        "tick"
    );
    if (_validated_tick <= _log.last_committed_tick) {
        _BladeEventLogFail("tick", "ticks must commit in strictly increasing order");
    }
    _log.active_tick = _validated_tick;
    _log.enqueue_ordinal = int64(0);
    return _validated_tick;
}

/// @func BladeEventLogQueue(log, channel, order_key, type, reason, source_id, target_id, owner_id, content_id, payload)
function BladeEventLogQueue(
    _log,
    _channel,
    _order_key,
    _type,
    _reason,
    _source_id,
    _target_id,
    _owner_id,
    _content_id,
    _payload = []
) {
    _BladeEventLogRequire(_log);
    var _maximum = int64("9223372036854775807");
    var _active_tick = _BladeEventLogInteger(
        _log.active_tick,
        -1,
        _maximum,
        "active tick"
    );
    if (_active_tick < 0) {
        _BladeEventLogFail("tick", "begin a tick before queuing events");
    }
    var _ordinal = _BladeEventLogInteger(
        _log.enqueue_ordinal,
        0,
        _maximum,
        "enqueue ordinal"
    );
    if (_ordinal == _maximum) {
        _BladeEventLogFail("enqueue ordinal", "cannot exceed signed int64 range");
    }
    if (!is_array(_log.pending)) {
        _BladeEventLogFail("pending events", "must be an array");
    }
    if (int64(array_length(_log.pending)) != _ordinal) {
        _BladeEventLogFail("pending events", "count must match the enqueue ordinal");
    }

    var _queued = _BladeEventLogBuildQueued(
        _log,
        _active_tick,
        _channel,
        _order_key,
        _type,
        _reason,
        _source_id,
        _target_id,
        _owner_id,
        _content_id,
        _payload,
        _ordinal
    );
    var _result = _BladeEventLogCopyQueued(_queued);
    array_push(_log.pending, _queued);
    _log.enqueue_ordinal = _ordinal + int64(1);
    return _result;
}

/// @func BladeEventLogCommitTick(log)
function BladeEventLogCommitTick(_log) {
    _BladeEventLogRequire(_log);
    var _maximum = int64("9223372036854775807");
    var _active_tick = _BladeEventLogInteger(
        _log.active_tick,
        -1,
        _maximum,
        "active tick"
    );
    if (_active_tick < 0) {
        _BladeEventLogFail("tick", "no active tick to commit");
    }
    var _enqueue_count = _BladeEventLogInteger(
        _log.enqueue_ordinal,
        0,
        _maximum,
        "enqueue ordinal"
    );
    if (!is_array(_log.gameplay_records) || !is_array(_log.presentation_records)) {
        _BladeEventLogFail("committed records", "must remain arrays");
    }

    var _plan = _BladeEventLogRebuildPending(_log, _enqueue_count);
    var _ordered = _BladeEventLogSortQueued(_plan.pending);
    var _identity_counters = BladeRunIdentityGetCounters(_log.identity);
    var _event_count = _BladeEventLogInteger(
        _identity_counters.event,
        0,
        _maximum - int64(1),
        "gameplay event count"
    );
    if (_plan.gameplay_count > (_maximum - int64(1)) - _event_count) {
        _BladeEventLogFail("gameplay event counter", "cannot exceed signed int64 range");
    }
    var _next_presentation = _BladeEventLogInteger(
        _log.next_presentation_event,
        1,
        _maximum,
        "presentation event counter"
    );
    if (_plan.presentation_count > _maximum - _next_presentation) {
        _BladeEventLogFail("presentation event counter", "cannot exceed signed int64 range");
    }

    var _prepared = [];
    var _gameplay_offset = int64(0);
    var _presentation_offset = int64(0);
    for (var i = 0; i < array_length(_ordered); i++) {
        var _queued = _ordered[i];
        var _event_id;
        if (_queued.channel == BladeEventChannel.Gameplay) {
            _event_id = "evt:" + string(
                _event_count + _gameplay_offset + int64(1)
            );
            _gameplay_offset += int64(1);
        } else {
            _event_id = "pev:" + string(_next_presentation + _presentation_offset);
            _presentation_offset += int64(1);
        }
        var _record = {
            event_id: _event_id,
            tick: _queued.tick,
            type: _queued.type,
            reason: _queued.reason,
            source_id: _queued.source_id,
            target_id: _queued.target_id,
            owner_id: _queued.owner_id,
            content_id: _queued.content_id,
            payload: _queued.payload,
        };
        array_push(_prepared, {
            channel: _queued.channel,
            canonical: _BladeEventLogRecordCanonical(_record),
        });
    }

    var _allocated = int64(0);
    while (_allocated < _plan.gameplay_count) {
        BladeRunIdentityAllocate(_log.identity, BladeRunIdKind.Event);
        _allocated += int64(1);
    }
    _log.next_presentation_event = _next_presentation + _plan.presentation_count;

    var _committed = [];
    for (var i = 0; i < array_length(_prepared); i++) {
        array_push(_committed, _prepared[i].canonical);
        if (_prepared[i].channel == BladeEventChannel.Gameplay) {
            array_push(_log.gameplay_records, _prepared[i].canonical);
        } else {
            array_push(_log.presentation_records, _prepared[i].canonical);
        }
    }

    _log.last_committed_tick = _active_tick;
    _log.active_tick = int64(-1);
    _log.enqueue_ordinal = int64(0);
    _log.pending = [];
    return _committed;
}

/// @func BladeEventLogGameplayCanonical(log)
function BladeEventLogGameplayCanonical(_log) {
    _BladeEventLogRequire(_log);
    if (_log.active_tick >= 0) {
        _BladeEventLogFail("log", "cannot serialize while a tick is active");
    }
    return BladeCanonicalRecord("L1", _log.gameplay_records);
}

/// @func BladeEventLogAllCanonical(log)
function BladeEventLogAllCanonical(_log) {
    _BladeEventLogRequire(_log);
    return BladeCanonicalRecord("A1", [
        BladeEventLogGameplayCanonical(_log),
        BladeCanonicalRecord("V1", _log.presentation_records),
    ]);
}

/// @func BladeEventLogGameplayHash(log)
function BladeEventLogGameplayHash(_log) {
    return BladeCanonicalHashUtf8(BladeEventLogGameplayCanonical(_log));
}
