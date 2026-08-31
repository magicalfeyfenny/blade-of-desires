attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_texcoord;
varying vec4 v_colour;

uniform vec2 u_size;

void main() {
    vec4 view_position = gm_Matrices[MATRIX_WORLD_VIEW]
        * vec4(0.0, 0.0, 0.0, 1.0);
    // Building the quad in view space makes it face the camera in every axis.
    view_position.xy += in_Position.xy * u_size;
    gl_Position = gm_Matrices[MATRIX_PROJECTION] * view_position;
    gl_Position.y = -gl_Position.y;
    v_colour = in_Colour;
    v_texcoord = in_TextureCoord;
}
