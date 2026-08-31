varying vec2 v_texcoord;
varying vec4 v_colour;

uniform vec4 u_tint;
uniform float u_alpha_cutoff;

void main() {
    vec4 color = texture2D(gm_BaseTexture, v_texcoord) * v_colour * u_tint;
    if (color.a < u_alpha_cutoff) {
        discard;
    }
    gl_FragColor = color;
}
