attribute vec3 in_Position;
attribute vec3 in_Normal;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_texcoord;
varying vec3 v_world_position;
varying vec3 v_world_normal;
varying vec4 v_colour;

void main() {
    vec4 object_position = vec4(in_Position, 1.0);
    vec4 world_position = gm_Matrices[MATRIX_WORLD] * object_position;
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_position;
    // Draw Begin custom shaders receive OpenGL clip Y inverted in this project.
    // Correct only clip Y so the authored -Z-up world stays unchanged.
    gl_Position.y = -gl_Position.y;
    v_world_position = world_position.xyz;
    v_world_normal = normalize(
        (gm_Matrices[MATRIX_WORLD] * vec4(in_Normal, 0.0)).xyz
    );
    v_colour = in_Colour;
    v_texcoord = in_TextureCoord;
}
