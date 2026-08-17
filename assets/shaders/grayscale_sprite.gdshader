shader_type canvas_item;
// Desaturates a sprite's own texture to black & white (luminance), preserving alpha.
// Used for the Decoy explosion (the grenade explosion sprite, recolored monochrome).

uniform float contrast : hint_range(0.5, 2.5) = 1.25;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Push a little toward stark black/white.
	grey = clamp((grey - 0.5) * contrast + 0.5, 0.0, 1.0);
	COLOR = vec4(vec3(grey), c.a) * COLOR;
}
