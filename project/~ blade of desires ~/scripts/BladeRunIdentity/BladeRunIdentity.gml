/// @description Deterministic typed run-local identity allocation and validation.

enum BladeRunIdKind {
	Instance = 0,
	Attack = 1,
	Bullet = 2,
	DamageEvent = 3,
	EventOwner = 4,
	Event = 5
}

function _BladeRunIdentityRequire(_identity) {
	if (!is_struct(_identity)
		|| !variable_struct_exists(_identity, "__blade_run_identity_version")
		|| _identity.__blade_run_identity_version != 1) {
		throw("BladeRunIdentity: expected a version 1 identity allocator");
	}
}

function _BladeRunIdentityKind(_kind) {
	var _type = typeof(_kind);
	var _value;
	if (_type == "int32" || _type == "int64") {
		_value = int64(_kind);
	} else if (_type == "number") {
		if (is_nan(_kind) || is_infinity(_kind)
			|| floor(_kind) != _kind
			|| abs(_kind) > 9007199254740991) {
			throw("BladeRunIdentity: ID kind must be an exact finite integer");
		}
		_value = int64(_kind);
	} else {
		throw("BladeRunIdentity: ID kind must be an integer enum value");
	}
	if (_value < BladeRunIdKind.Instance || _value > BladeRunIdKind.Event) {
		throw("BladeRunIdentity: unknown ID kind " + string(_kind));
	}
	return _value;
}

function _BladeRunIdentityPrefix(_kind) {
	switch (_BladeRunIdentityKind(_kind)) {
		case BladeRunIdKind.Instance: return "ins";
		case BladeRunIdKind.Attack: return "atk";
		case BladeRunIdKind.Bullet: return "blt";
		case BladeRunIdKind.DamageEvent: return "dmg";
		case BladeRunIdKind.EventOwner: return "own";
		case BladeRunIdKind.Event: return "evt";
	}
	throw("BladeRunIdentity: unreachable ID kind");
}

function _BladeRunIdentityNextCounter(_identity, _kind) {
	switch (_BladeRunIdentityKind(_kind)) {
		case BladeRunIdKind.Instance: return _identity.next_instance;
		case BladeRunIdKind.Attack: return _identity.next_attack;
		case BladeRunIdKind.Bullet: return _identity.next_bullet;
		case BladeRunIdKind.DamageEvent: return _identity.next_damage_event;
		case BladeRunIdKind.EventOwner: return _identity.next_event_owner;
		case BladeRunIdKind.Event: return _identity.next_event;
	}
	throw("BladeRunIdentity: unreachable ID kind");
}

function _BladeRunIdentityTakeCounter(_identity, _kind) {
	switch (_BladeRunIdentityKind(_kind)) {
		case BladeRunIdKind.Instance:
			var _instance = _identity.next_instance;
			_identity.next_instance += int64(1);
			return _instance;
		case BladeRunIdKind.Attack:
			var _attack = _identity.next_attack;
			_identity.next_attack += int64(1);
			return _attack;
		case BladeRunIdKind.Bullet:
			var _bullet = _identity.next_bullet;
			_identity.next_bullet += int64(1);
			return _bullet;
		case BladeRunIdKind.DamageEvent:
			var _damage = _identity.next_damage_event;
			_identity.next_damage_event += int64(1);
			return _damage;
		case BladeRunIdKind.EventOwner:
			var _owner = _identity.next_event_owner;
			_identity.next_event_owner += int64(1);
			return _owner;
		case BladeRunIdKind.Event:
			var _event = _identity.next_event;
			_identity.next_event += int64(1);
			return _event;
	}
	throw("BladeRunIdentity: unreachable ID kind");
}

function _BladeRunIdentityPositiveDecimal(_text) {
	if (!is_string(_text) || string_length(_text) == 0) {
		return false;
	}
	for (var _index = 1; _index <= string_length(_text); ++_index) {
		var _byte = string_ord_at(_text, _index);
		if (_byte < 48 || _byte > 57) {
			return false;
		}
	}
	return string_char_at(_text, 1) != "0";
}

/// @func BladeRunIdentityCreate(content_id_predicate)
/// @param {Function} content_id_predicate Injected lookup sourced from the canonical content contract.
function BladeRunIdentityCreate(_content_id_predicate) {
	if (!is_callable(_content_id_predicate)) {
		throw("BladeRunIdentity: content ID predicate must be callable");
	}
	return {
		__blade_run_identity_version: 1,
		content_id_predicate: _content_id_predicate,
		next_instance: int64(1),
		next_attack: int64(1),
		next_bullet: int64(1),
		next_damage_event: int64(1),
		next_event_owner: int64(1),
		next_event: int64(1),
	};
}

/// @func BladeRunIdentityReset(identity)
function BladeRunIdentityReset(_identity) {
	_BladeRunIdentityRequire(_identity);
	_identity.next_instance = int64(1);
	_identity.next_attack = int64(1);
	_identity.next_bullet = int64(1);
	_identity.next_damage_event = int64(1);
	_identity.next_event_owner = int64(1);
	_identity.next_event = int64(1);
	return _identity;
}

/// @func BladeRunIdentityAllocate(identity, kind)
/// @returns {String} Immutable typed ID: ins/atk/blt/dmg/own/evt plus ordinal.
function BladeRunIdentityAllocate(_identity, _kind) {
	_BladeRunIdentityRequire(_identity);
	var _validated_kind = _BladeRunIdentityKind(_kind);
	var _ordinal = _BladeRunIdentityTakeCounter(_identity, _validated_kind);
	return _BladeRunIdentityPrefix(_validated_kind) + ":" + string(_ordinal);
}

/// @func BladeRunIdentityRequireContent(identity, content_id)
/// @returns {String} The known canonical content ID.
function BladeRunIdentityRequireContent(_identity, _content_id) {
	_BladeRunIdentityRequire(_identity);
	if (!is_string(_content_id) || string_length(_content_id) == 0) {
		throw("BladeRunIdentity: content ID must be a nonempty string");
	}
	if (!_identity.content_id_predicate(_content_id)) {
		throw("BladeRunIdentity: unknown content ID " + _content_id);
	}
	return _content_id;
}

/// @func BladeRunIdentityAllocateForContent(identity, kind, content_id)
/// @description Validate content before advancing the typed counter.
function BladeRunIdentityAllocateForContent(_identity, _kind, _content_id) {
	_BladeRunIdentityRequire(_identity);
	var _validated_kind = _BladeRunIdentityKind(_kind);
	BladeRunIdentityRequireContent(_identity, _content_id);
	return BladeRunIdentityAllocate(_identity, _validated_kind);
}

/// @func BladeRunIdentityRequireAllocated(identity, id, expected_kind)
/// @returns {String} The validated canonical allocated ID.
function BladeRunIdentityRequireAllocated(_identity, _id, _expected_kind) {
	_BladeRunIdentityRequire(_identity);
	var _kind = _BladeRunIdentityKind(_expected_kind);
	if (!is_string(_id)) {
		throw("BladeRunIdentity: run-local ID must be a string");
	}
	var _parts = string_split(_id, ":");
	if (array_length(_parts) != 2 || _parts[0] != _BladeRunIdentityPrefix(_kind)) {
		throw(
			"BladeRunIdentity: expected " + _BladeRunIdentityPrefix(_kind)
			+ " ID, received " + _id
		);
	}
	if (!_BladeRunIdentityPositiveDecimal(_parts[1])) {
		throw("BladeRunIdentity: malformed run-local ID " + _id);
	}

	var _ordinal = int64(_parts[1]);
	if (string(_ordinal) != _parts[1]) {
		throw("BladeRunIdentity: noncanonical run-local ID " + _id);
	}
	if (_ordinal >= _BladeRunIdentityNextCounter(_identity, _kind)) {
		throw("BladeRunIdentity: unallocated run-local ID " + _id);
	}
	return _id;
}

/// @func BladeRunIdentityGetCounters(identity)
/// @returns {Struct} Fresh fixed-order allocated-count diagnostics.
function BladeRunIdentityGetCounters(_identity) {
	_BladeRunIdentityRequire(_identity);
	return {
		instance: _identity.next_instance - int64(1),
		attack: _identity.next_attack - int64(1),
		bullet: _identity.next_bullet - int64(1),
		damage_event: _identity.next_damage_event - int64(1),
		event_owner: _identity.next_event_owner - int64(1),
		event: _identity.next_event - int64(1),
	};
}

/// @func BladeRunIdentityCountersCanonical(identity)
/// @returns {String} Fixed-order identity-counter fragment for deterministic hashing.
function BladeRunIdentityCountersCanonical(_identity) {
	var _counters = BladeRunIdentityGetCounters(_identity);
	return "BRIC1|" + string(_counters.instance)
		+ "|" + string(_counters.attack)
		+ "|" + string(_counters.bullet)
		+ "|" + string(_counters.damage_event)
		+ "|" + string(_counters.event_owner)
		+ "|" + string(_counters.event);
}
