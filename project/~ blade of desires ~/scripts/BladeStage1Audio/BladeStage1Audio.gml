/// Owns the compact procedural score and semantic one-shots used by Stage 1.

enum BladeStage1AudioSfx {
    PlayerVolley = 0,
    EnemyVolley = 1,
    EnemyDefeat = 2,
    PlayerHit = 3,
    PlayerDeath = 4,
    Pickup = 5,
    Bomb = 6,
    Hyper = 7,
    Phase = 8,
    Handoff = 9
}

#macro BLADE_STAGE1_AUDIO_RATE 16000
#macro BLADE_STAGE1_AUDIO_SFX_COUNT 10

/// Writes one clamped stereo sample without changing the sound after creation.
function _BladeStage1AudioWriteStereo(_buffer, _left, _right) {
    buffer_write(
        _buffer,
        buffer_s16,
        clamp(round(_left * 32767), -32767, 32767)
    );
    buffer_write(
        _buffer,
        buffer_s16,
        clamp(round(_right * 32767), -32767, 32767)
    );
}

/// Registers one retained PCM buffer and its dynamic sound in the owner state.
function _BladeStage1AudioRegister(_audio, _buffer) {
    var _sound = audio_create_buffer_sound(
        _buffer,
        buffer_s16,
        BLADE_STAGE1_AUDIO_RATE,
        0,
        buffer_get_size(_buffer),
        audio_stereo
    );
    array_push(_audio.buffers, _buffer);
    array_push(_audio.sounds, _sound);
    return _sound;
}

/// Creates a short looping forest phrase from inspectable chord and melody data.
function _BladeStage1AudioMusicCreate(
    _audio, _roots, _melody, _beat_seconds, _brightness, _pulse
) {
    var _duration = _beat_seconds * array_length(_roots) * 2;
    var _sample_count = round(BLADE_STAGE1_AUDIO_RATE * _duration);
    var _buffer = buffer_create(_sample_count * 4, buffer_fixed, 1);
    buffer_seek(_buffer, buffer_seek_start, 0);

    for (var _sample_index = 0;
        _sample_index < _sample_count;
        ++_sample_index) {
        var _time = _sample_index / BLADE_STAGE1_AUDIO_RATE;
        var _beat = floor(_time / _beat_seconds);
        var _beat_phase = frac(_time / _beat_seconds);
        var _root = _roots[_beat mod array_length(_roots)];
        var _note = _melody[_beat mod array_length(_melody)];
        var _soft_edge = min(
            1,
            _time / 0.035,
            (_duration - _time) / 0.035
        );
        var _note_envelope = 0.42
            + 0.58 * power(max(0, 1 - _beat_phase), 2);
        var _breath = 0.78 + 0.22 * dsin(_time * 45);
        var _pad = dsin(_time * _root * 360) * 0.18
            + dsin(_time * _root * 180 + 34) * 0.12
            + dsin(_time * _root * 540 + 71) * 0.05;
        var _lead = dsin(_time * _note * 360) * 0.12 * _note_envelope;
        var _sparkle = dsin(_time * _note * 720 + 23)
            * 0.035 * _brightness * _note_envelope;
        var _rhythm = dsin(_beat_phase * 180)
            * _pulse * power(max(0, 1 - _beat_phase), 3);
        var _left = (_pad + _lead + _sparkle + _rhythm)
            * _breath * _soft_edge;
        var _right = (_pad + _lead * 0.92
            + dsin(_time * _note * 720 + 67) * 0.035 * _brightness
            + _rhythm * 0.88) * _breath * _soft_edge;
        _BladeStage1AudioWriteStereo(_buffer, _left, _right);
    }
    return _BladeStage1AudioRegister(_audio, _buffer);
}

/// Creates one deterministic pitched one-shot without consuming gameplay RNG.
function _BladeStage1AudioSfxCreate(
    _audio, _duration, _start_hz, _end_hz, _harmonic, _roughness
) {
    var _sample_count = round(BLADE_STAGE1_AUDIO_RATE * _duration);
    var _buffer = buffer_create(_sample_count * 4, buffer_fixed, 1);
    buffer_seek(_buffer, buffer_seek_start, 0);
    var _phase = 0;
    for (var _sample_index = 0;
        _sample_index < _sample_count;
        ++_sample_index) {
        var _progress = _sample_index / max(1, _sample_count - 1);
        var _frequency = lerp(_start_hz, _end_hz, _progress);
        _phase += _frequency * 360 / BLADE_STAGE1_AUDIO_RATE;
        var _envelope = power(max(0, 1 - _progress), 2);
        var _tone = dsin(_phase) * 0.58
            + dsin(_phase * _harmonic + 31) * 0.24;
        var _grain = dsin(_phase * 4.13 + _sample_index * 17.7)
            * _roughness;
        var _sample = (_tone + _grain) * _envelope;
        _BladeStage1AudioWriteStereo(
            _buffer,
            _sample * 0.82,
            _sample * 0.76 + dsin(_phase + 19) * 0.035 * _envelope
        );
    }
    return _BladeStage1AudioRegister(_audio, _buffer);
}

/// Creates the one Stage 1 audio owner from current config gain semantics.
function BladeStage1AudioCreate(_config_audio) {
    var _audio = {
        buffers: [],
        sounds: [],
        sfx: array_create(BLADE_STAGE1_AUDIO_SFX_COUNT, -1),
        master_gain: clamp(_config_audio.master_gain_percent / 100, 0, 1),
        music_gain: clamp(_config_audio.music_gain_percent / 100, 0, 1),
        sfx_gain: clamp(_config_audio.sfx_gain_percent / 100, 0, 1),
        music_instance: -1,
        music_key: "",
        music_travel: -1,
        music_duo: -1,
        music_approach: -1,
    };

    _audio.music_travel = _BladeStage1AudioMusicCreate(
        _audio,
        [146.83, 174.61, 196.00, 130.81],
        [293.66, 349.23, 392.00, 440.00, 392.00, 349.23, 293.66, 261.63],
        0.44,
        0.72,
        0.025
    );
    _audio.music_duo = _BladeStage1AudioMusicCreate(
        _audio,
        [164.81, 196.00, 146.83, 220.00],
        [329.63, 392.00, 440.00, 523.25, 440.00, 392.00, 349.23, 293.66],
        0.30,
        1.00,
        0.070
    );
    _audio.music_approach = _BladeStage1AudioMusicCreate(
        _audio,
        [130.81, 146.83, 174.61, 196.00],
        [261.63, 293.66, 349.23, 392.00, 440.00, 523.25, 587.33, 659.25],
        0.52,
        0.88,
        0.035
    );

    _audio.sfx[BladeStage1AudioSfx.PlayerVolley] = _BladeStage1AudioSfxCreate(
        _audio, 0.070, 560, 720, 2.0, 0.015
    );
    _audio.sfx[BladeStage1AudioSfx.EnemyVolley] = _BladeStage1AudioSfxCreate(
        _audio, 0.090, 210, 150, 1.5, 0.045
    );
    _audio.sfx[BladeStage1AudioSfx.EnemyDefeat] = _BladeStage1AudioSfxCreate(
        _audio, 0.230, 420, 92, 2.7, 0.120
    );
    _audio.sfx[BladeStage1AudioSfx.PlayerHit] = _BladeStage1AudioSfxCreate(
        _audio, 0.220, 175, 72, 1.3, 0.160
    );
    _audio.sfx[BladeStage1AudioSfx.PlayerDeath] = _BladeStage1AudioSfxCreate(
        _audio, 0.520, 260, 48, 1.8, 0.190
    );
    _audio.sfx[BladeStage1AudioSfx.Pickup] = _BladeStage1AudioSfxCreate(
        _audio, 0.120, 620, 980, 2.0, 0.010
    );
    _audio.sfx[BladeStage1AudioSfx.Bomb] = _BladeStage1AudioSfxCreate(
        _audio, 0.620, 150, 35, 1.1, 0.230
    );
    _audio.sfx[BladeStage1AudioSfx.Hyper] = _BladeStage1AudioSfxCreate(
        _audio, 0.430, 240, 1080, 2.0, 0.070
    );
    _audio.sfx[BladeStage1AudioSfx.Phase] = _BladeStage1AudioSfxCreate(
        _audio, 0.340, 310, 650, 1.5, 0.055
    );
    _audio.sfx[BladeStage1AudioSfx.Handoff] = _BladeStage1AudioSfxCreate(
        _audio, 0.780, 390, 880, 2.0, 0.025
    );
    return _audio;
}

/// Switches the looping score only when the semantic route state changes.
function BladeStage1AudioMusicSwitch(_audio, _key, _sound) {
    if (!is_struct(_audio) || _audio.music_key == _key) return false;
    if (_audio.music_instance >= 0) {
        audio_stop_sound(_audio.music_instance);
        _audio.music_instance = -1;
    }
    _audio.music_key = _key;
    if (_sound < 0 || !audio_exists(_sound)) return false;
    _audio.music_instance = audio_play_sound(_sound, 0, true);
    audio_sound_gain(
        _audio.music_instance,
        _audio.master_gain * _audio.music_gain * 0.52,
        90
    );
    return true;
}

/// Plays one semantic Stage 1 sound with a bounded category mix.
function BladeStage1AudioPlay(_audio, _cue, _mix = 1) {
    if (!is_struct(_audio)
        || _cue < 0
        || _cue >= array_length(_audio.sfx)) return false;
    var _sound = _audio.sfx[_cue];
    if (_sound < 0 || !audio_exists(_sound)) return false;
    var _instance = audio_play_sound(_sound, 1, false);
    audio_sound_gain(
        _instance,
        _audio.master_gain * _audio.sfx_gain * clamp(_mix, 0, 1),
        0
    );
    return true;
}

/// Safely plays a one-shot for a production controller while tests stay silent.
function BladeStage1AudioPlayForController(_controller, _cue, _mix = 1) {
    if (!instance_exists(_controller)
        || !variable_instance_exists(_controller, "stage_audio")) return false;
    return BladeStage1AudioPlay(_controller.stage_audio, _cue, _mix);
}

/// Makes existing authored route cues the sole authority for music transitions.
function BladeStage1AudioApplyRouteCue(_controller, _cue_id) {
    if (!instance_exists(_controller)
        || !variable_instance_exists(_controller, "stage_audio")
        || !is_struct(_controller.stage_audio)) return false;
    var _audio = _controller.stage_audio;
    switch (_cue_id) {
        case "cue.stage1.forest_travel":
        case "cue.stage1.forest_resume":
            return BladeStage1AudioMusicSwitch(
                _audio, "travel", _audio.music_travel
            );
        case "cue.stage1.midboss_stop":
            BladeStage1AudioPlay(_audio, BladeStage1AudioSfx.Phase, 0.72);
            return BladeStage1AudioMusicSwitch(_audio, "duo", _audio.music_duo);
        case "cue.stage1.world_tree_approach":
            BladeStage1AudioPlay(_audio, BladeStage1AudioSfx.Phase, 0.62);
            return BladeStage1AudioMusicSwitch(
                _audio, "approach", _audio.music_approach
            );
        case "cue.stage1.world_tree_handoff":
            BladeStage1AudioMusicSwitch(_audio, "handoff", -1);
            return BladeStage1AudioPlay(
                _audio, BladeStage1AudioSfx.Handoff, 0.82
            );
    }
    return false;
}

/// Frees dynamic sounds before their retained PCM buffers at room cleanup.
function BladeStage1AudioDestroy(_audio) {
    if (!is_struct(_audio)) return false;
    if (_audio.music_instance >= 0) {
        audio_stop_sound(_audio.music_instance);
        _audio.music_instance = -1;
    }
    for (var _sound_index = 0;
        _sound_index < array_length(_audio.sounds);
        ++_sound_index) {
        var _sound = _audio.sounds[_sound_index];
        if (_sound < 0) continue;
        audio_stop_sound(_sound);
        audio_free_buffer_sound(_sound);
    }
    for (var _buffer_index = 0;
        _buffer_index < array_length(_audio.buffers);
        ++_buffer_index) {
        var _buffer = _audio.buffers[_buffer_index];
        if (buffer_exists(_buffer)) buffer_delete(_buffer);
    }
    _audio.sounds = [];
    _audio.buffers = [];
    return true;
}
