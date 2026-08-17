shader_type canvas_item;
// Red edge vignette that flashes when the player takes damage.
// Center stays clear; only the screen edges/corners tint red.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vig_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.45, 0.85, d);
	COLOR = vec4(vig_color.rgb, edge * intensity);
}
