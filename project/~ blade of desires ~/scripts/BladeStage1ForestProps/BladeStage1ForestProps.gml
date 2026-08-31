/// Authors Stage 1's reusable terrain-relative scene prop placements.

enum BladeStage1ForestFoliageKind {
    Grass = 0,
    Vines = 1,
    Bush = 2
}

#macro BLADE_STAGE1_FOREST_FAE_TRAIL_LIGHTS 3

/// Returns the deterministic center of the authored path at one world Y.
function BladeStage1ForestRouteCenter(_world_y) {
    return dsin(radtodeg(_world_y / 31)) * 1.5
        + dsin(radtodeg(_world_y / 13)) * 0.4;
}

/// Returns the authored terrain surface at one world-space route position.
function BladeStage1ForestSurfaceZ(_world_x, _world_y) {
    var _route_offset = _world_x - BladeStage1ForestRouteCenter(_world_y);
    var _distance = abs(_route_offset);
    var _roll = 0.18 * dsin(radtodeg(_world_y / 19))
        + 0.08 * dsin(radtodeg(_world_y / 7.3));
    if (_distance <= 3.2) {
        var _path_elevation = _roll + 0.10 * sqr(_distance / 3.2)
            + 0.018 * dsin(radtodeg(
                _world_y / 4.8 + 0.7 * _route_offset
            ));
        return -_path_elevation;
    }

    var _bank_amount = clamp((_distance - 3.2) / (23 - 3.2), 0, 1);
    var _smooth_bank = sqr(_bank_amount) * (3 - 2 * _bank_amount);
    var _side = _route_offset < 0 ? -1 : 1;
    var _edge = 3.25
        + 0.65 * dsin(radtodeg(_world_y / 27 + 1.2 * _side))
        + 0.35 * dsin(radtodeg(_world_y / 8.5 - 0.6 * _side));
    var _relief = _smooth_bank * (
        0.18 * dsin(radtodeg(_world_y / 5.4 + 0.31 * _route_offset))
        + 0.12 * dsin(radtodeg(_world_y / 13.7 - 0.52 * _route_offset))
    );
    return -(_roll + 0.10 + _edge * _smooth_bank + _relief);
}

/// Places reusable tree models along both sides of the traversable route.
function BladeStage1ForestTreePlacementsCreate() {
    var _placements = [];
    for (var _row = 0; _row < 36; ++_row) {
        var _world_y = -18 + _row * 7.7;
        var _center = BladeStage1ForestRouteCenter(_world_y);
        for (var _side = -1; _side <= 1; _side += 2) {
            var _variation = (_row * 5 + (_side > 0 ? 0 : 2)) mod 6;
            var _tree_x = _center + _side * (7.2 + _variation * 1.15);
            var _tree_y = _world_y
                + (((_row + _side) mod 2 == 0) ? 1.4 : -0.8);
            array_push(_placements, {
                x: _tree_x,
                y: _tree_y,
                z: BladeStage1ForestSurfaceZ(_tree_x, _tree_y),
                scale: 0.72 + ((_row + _variation) mod 5) * 0.07,
                rotation: (_row * 37 + _variation * 19) mod 360,
                model_kind: (_row + (_side > 0 ? 0 : 1)) mod 2,
            });
        }
    }
    return _placements;
}

/// Places separately swaying foliage along grounded and canopy pivots.
function BladeStage1ForestFoliagePlacementsCreate() {
    var _placements = [];
    for (var _row = 0; _row < 44; ++_row) {
        var _world_y = -14 + _row * 6.2;
        var _center = BladeStage1ForestRouteCenter(_world_y);
        var _side = (_row mod 2 == 0) ? -1 : 1;
        var _grass_height = 1.5 + (_row mod 4) * 0.18;
        var _grass_x = _center + _side * (4.3 + (_row mod 4) * 0.65);
        array_push(_placements, {
            kind: BladeStage1ForestFoliageKind.Grass,
            x: _grass_x,
            y: _world_y,
            z: BladeStage1ForestSurfaceZ(_grass_x, _world_y)
                - _grass_height * 0.5,
            width: 2.7 + (_row mod 3) * 0.45,
            height: _grass_height,
            tint: make_color_rgb(224, 238, 207),
            sway: 0,
            sway_phase: _row * 41,
            sway_speed: 1.35 + (_row mod 4) * 0.13,
            sway_range: 0.15 + (_row mod 3) * 0.035,
            sway_pivot: -0.5,
        });
        var _bush_height = 2.2 + (_row mod 2) * 0.35;
        var _bush_x = _center - _side * (5.2 + (_row mod 5) * 0.55);
        var _bush_y = _world_y + 2.3;
        array_push(_placements, {
            kind: BladeStage1ForestFoliageKind.Bush,
            x: _bush_x,
            y: _bush_y,
            z: BladeStage1ForestSurfaceZ(_bush_x, _bush_y)
                - _bush_height * 0.5,
            width: 3.7 + (_row mod 3) * 0.5,
            height: _bush_height,
            tint: make_color_rgb(235, 222, 211),
            sway: 0,
            sway_phase: 83 + _row * 29,
            sway_speed: 0.92 + (_row mod 5) * 0.11,
            sway_range: 0.12 + (_row mod 4) * 0.03,
            sway_pivot: -0.5,
        });
        if (_row mod 3 == 0) {
            var _vine_height = 6.0 + (_row mod 4) * 0.45;
            var _vine_x = _center + _side * (8.4 + (_row mod 4));
            var _vine_y = _world_y + 0.8;
            array_push(_placements, {
                kind: BladeStage1ForestFoliageKind.Vines,
                x: _vine_x,
                y: _vine_y,
                z: BladeStage1ForestSurfaceZ(_vine_x, _vine_y)
                    - 8.35 + _vine_height * 0.5,
                width: 2.8,
                height: _vine_height,
                tint: make_color_rgb(222, 235, 190),
                sway: 0,
                sway_phase: 151 + _row * 37,
                sway_speed: 1.05 + (_row mod 4) * 0.14,
                sway_range: 0.22 + (_row mod 3) * 0.055,
                sway_pivot: 0.5,
            });
        }
    }
    return _placements;
}

/// Places ambient fae on small paths the scrolling camera can pass.
function BladeStage1ForestFaePlacementsCreate() {
    var _anchors = [
        [-5.8, 4, -4.1, 2.4],
        [7.2, 38, -5.0, 2.7],
        [-8.4, 71, -3.7, 2.2],
        [6.1, 108, -5.6, 2.8],
        [-6.9, 143, -4.6, 2.5],
        [8.1, 181, -5.1, 2.6],
        [-7.6, 216, -4.0, 2.3],
    ];
    var _placements = [];
    for (var _index = 0; _index < array_length(_anchors); ++_index) {
        var _anchor = _anchors[_index];
        var _surface_z = BladeStage1ForestSurfaceZ(_anchor[0], _anchor[1]);
        array_push(_placements, {
            x: _anchor[0],
            y: _anchor[1],
            z: _surface_z + _anchor[2],
            anchor_x: _anchor[0],
            anchor_y: _anchor[1],
            altitude: _anchor[2],
            width: _anchor[3],
            height: _anchor[3],
            path_phase: _index * 67,
            path_speed: 0.78 + (_index mod 4) * 0.12,
            path_radius_x: 0.55 + (_index mod 3) * 0.16,
            path_radius_y: 0.38 + (_index mod 2) * 0.14,
            path_height: 0.25 + (_index mod 4) * 0.07,
        });
    }
    return _placements;
}

/// Samples one fae's presentation-only path at an exact presentation time.
function BladeStage1ForestFaePathPosition(_fae, _time) {
    var _angle = _fae.path_phase + _time * _fae.path_speed;
    var _x = _fae.anchor_x + dcos(_angle) * _fae.path_radius_x;
    var _y = _fae.anchor_y + dsin(_angle) * _fae.path_radius_y;
    return {
        x: _x,
        y: _y,
        z: BladeStage1ForestSurfaceZ(_x, _y) + _fae.altitude
            + dsin(_angle * 1.7 + _fae.path_phase) * _fae.path_height,
    };
}

/// Creates three individually rendered green lights that lag behind each fae.
function BladeStage1ForestFaeTrailPlacementsCreate(_fae_placements) {
    var _trails = [];
    for (var _fae_index = 0;
        _fae_index < array_length(_fae_placements);
        ++_fae_index) {
        var _fae = _fae_placements[_fae_index];
        for (var _trail_index = 0;
            _trail_index < BLADE_STAGE1_FOREST_FAE_TRAIL_LIGHTS;
            ++_trail_index) {
            var _lag_ticks = 12 + _trail_index * 13;
            var _position = BladeStage1ForestFaePathPosition(
                _fae, -_lag_ticks
            );
            var _size = 0.58 - _trail_index * 0.10;
            array_push(_trails, {
                fae_index: _fae_index,
                lag_ticks: _lag_ticks,
                x: _position.x,
                y: _position.y,
                z: _position.z,
                width: _size,
                height: _size,
                alpha: 0.78 - _trail_index * 0.16,
            });
        }
    }
    return _trails;
}

/// Places individually colored ball-light props throughout the 3D route.
function BladeStage1ForestBallLightPlacementsCreate() {
    var _palette = [
        [0.35, 0.95, 1.00],
        [1.00, 0.54, 0.82],
        [1.00, 0.82, 0.35],
        [0.58, 0.48, 1.00],
        [0.52, 1.00, 0.55],
    ];
    var _placements = [];
    for (var _index = 0; _index < 24; ++_index) {
        var _world_y = -6 + _index * 11.1;
        var _side = (_index mod 2 == 0) ? -1 : 1;
        var _color = _palette[_index mod array_length(_palette)];
        var _anchor_x = BladeStage1ForestRouteCenter(_world_y)
            + _side * (4.8 + (_index mod 5) * 0.85);
        var _altitude = -2.2 - (_index mod 4) * 0.85;
        array_push(_placements, {
            x: _anchor_x,
            y: _world_y,
            z: BladeStage1ForestSurfaceZ(_anchor_x, _world_y) + _altitude,
            anchor_x: _anchor_x,
            anchor_y: _world_y,
            altitude: _altitude,
            width: 0.78 + (_index mod 3) * 0.12,
            height: 0.78 + (_index mod 3) * 0.12,
            red: _color[0],
            green: _color[1],
            blue: _color[2],
            orbit_phase: _index * 73,
            orbit_speed: 0.62 + (_index mod 5) * 0.09,
            orbit_radius_x: 0.32 + (_index mod 4) * 0.10,
            orbit_radius_y: 0.24 + (_index mod 3) * 0.09,
            orbit_height: 0.18 + (_index mod 4) * 0.055,
        });
    }
    return _placements;
}

/// Gives every moving fae and ball prop one matching point-light record.
function BladeStage1ForestPointLightsCreate(_fae, _balls) {
    var _lights = [];
    for (var _fae_index = 0; _fae_index < array_length(_fae); ++_fae_index) {
        var _fae_prop = _fae[_fae_index];
        array_push(_lights, {
            x: _fae_prop.x,
            y: _fae_prop.y,
            z: _fae_prop.z,
            range: 13,
            red: 0.24,
            green: 1.00,
            blue: 0.48,
            strength: 1.45,
        });
    }
    for (var _ball_index = 0; _ball_index < array_length(_balls); ++_ball_index) {
        var _ball = _balls[_ball_index];
        array_push(_lights, {
            x: _ball.x,
            y: _ball.y,
            z: _ball.z,
            range: 9,
            red: _ball.red,
            green: _ball.green,
            blue: _ball.blue,
            strength: 1.25,
        });
    }
    return _lights;
}
