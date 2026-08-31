attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_texcoord;
varying vec4 v_colour;

uniform vec2 u_size;
uniform vec3 u_camera_position;
uniform float u_sway;
uniform float u_sway_pivot;

void main() {
    vec3 center = (gm_Matrices[MATRIX_WORLD]
        * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec2 toward_camera = u_camera_position.xy - center.xy;
    toward_camera /= max(length(toward_camera), 0.001);
    vec3 right = vec3(-toward_camera.y, toward_camera.x, 0.0);
    vec3 up = vec3(0.0, 0.0, -1.0);
    // The pivot edge stays attached while the opposite edge bends in the wind.
    float distance_from_pivot = in_Position.y - u_sway_pivot;
    vec3 world_position = center
        + right * (in_Position.x * u_size.x + distance_from_pivot * u_sway)
        + up * in_Position.y * u_size.y;
    gl_Position = gm_Matrices[MATRIX_PROJECTION]
        * gm_Matrices[MATRIX_VIEW]
        * vec4(world_position, 1.0);
    // Draw Begin reverses clip Y; this leaves the authored -Z-up world intact.
    gl_Position.y = -gl_Position.y;
    v_colour = in_Colour;
    v_texcoord = in_TextureCoord;
}
