varying vec2 v_texcoord;
varying vec3 v_world_position;
varying vec3 v_world_normal;
varying vec4 v_colour;

uniform vec3 u_ambient_color;
uniform vec3 u_directional_direction;
uniform vec3 u_directional_color;
uniform vec4 u_point_position_range[8];
uniform vec4 u_point_color_strength[8];
uniform float u_lighting_mix;
uniform float u_alpha_cutoff;

void main() {
    vec4 albedo = texture2D(gm_BaseTexture, v_texcoord) * v_colour;
    if (albedo.a < u_alpha_cutoff) {
        discard;
    }

    vec3 normal = normalize(v_world_normal);
    float directional_amount = max(
        dot(normal, -normalize(u_directional_direction)),
        0.0
    );
    vec3 light_total = u_ambient_color
        + u_directional_color * directional_amount;

    // Eight nearest scene lights are enough for this narrow route and give the
    // shader a fixed cost even when many authored props surround the camera.
    for (int light_index = 0; light_index < 8; light_index++) {
        vec4 position_range = u_point_position_range[light_index];
        vec4 color_strength = u_point_color_strength[light_index];
        vec3 toward_light = position_range.xyz - v_world_position;
        float distance_to_light = length(toward_light);
        float range = max(position_range.w, 0.001);
        float falloff = clamp(1.0 - distance_to_light / range, 0.0, 1.0);
        falloff *= falloff;
        vec3 light_direction = toward_light / max(distance_to_light, 0.001);
        float facing = max(dot(normal, light_direction), 0.0);
        float contribution = falloff
            * (0.24 + facing * 0.76)
            * color_strength.a;
        light_total += color_strength.rgb * contribution;
    }

    vec3 lit_color = albedo.rgb * light_total;
    gl_FragColor = vec4(
        mix(albedo.rgb, lit_color, clamp(u_lighting_mix, 0.0, 1.0)),
        albedo.a
    );
}
