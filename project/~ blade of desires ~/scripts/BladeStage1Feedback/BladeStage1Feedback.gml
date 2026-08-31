/// Creates large, deterministic combat bursts without affecting gameplay RNG.

#macro BLADE_STAGE1_EFFECT_ENEMY "enemy"
#macro BLADE_STAGE1_EFFECT_MAYNII "maynii"
#macro BLADE_STAGE1_EFFECT_KOLAR "kolar"
#macro BLADE_STAGE1_EFFECT_CIELA "ciela"
#macro BLADE_STAGE1_EFFECT_HANDOFF "handoff"

/// Spawns one presentation-only effect; its object initializes next Step.
function BladeStage1FeedbackSpawn(
    _x, _y, _kind, _color = c_white, _scale = 1
) {
    if (room != r_stage1_first_beat) return noone;
    var _effect = instance_create_layer(
        _x, _y, "Instances", o_blade_stage1_feedback_effect
    );
    _effect.effect_kind = _kind;
    _effect.effect_color = _color;
    _effect.effect_scale = max(0.25, _scale);
    return _effect;
}

/// Resolves presentation tuning once after spawn variables have been assigned.
function BladeStage1FeedbackInitialize(_effect) {
    if (!instance_exists(_effect) || _effect.initialized) return false;
    switch (_effect.effect_kind) {
        case BLADE_STAGE1_EFFECT_MAYNII:
            _effect.duration = 54;
            _effect.particle_count = 30;
            _effect.max_radius = 54;
            break;
        case BLADE_STAGE1_EFFECT_KOLAR:
            _effect.duration = 58;
            _effect.particle_count = 28;
            _effect.max_radius = 58;
            break;
        case BLADE_STAGE1_EFFECT_CIELA:
            _effect.duration = 68;
            _effect.particle_count = 34;
            _effect.max_radius = 62;
            break;
        case BLADE_STAGE1_EFFECT_HANDOFF:
            _effect.duration = 100;
            _effect.particle_count = 44;
            _effect.max_radius = 112;
            break;
        default:
            _effect.duration = 42;
            _effect.particle_count = 24;
            _effect.max_radius = 46;
            break;
    }
    _effect.initialized = true;
    return true;
}
