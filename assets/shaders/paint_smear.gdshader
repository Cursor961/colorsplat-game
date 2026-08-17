shader_type canvas_item;
// Paint smear shader — directional blur around the player position.
// Applied to paint_sprite (the Sprite2D that shows the SubViewport paint canvas).
// When the player moves through paint, this creates a realistic mixing/smearing effect.

// Player position in UV space (0-1). Updated each frame from GDScript.
uniform vec2 player_uv = vec2(-1.0, -1.0);
// Normalized movement direction of the player.
uniform vec2 move_dir = vec2(0.0, 0.0);
// Smear radius in UV space (how far from player the blur reaches).
uniform float smear_radius : hint_range(0.0, 0.2) = 0.04;
// Blur strength — how far pixels are displaced along move_dir.
uniform float smear_strength : hint_range(0.0, 0.02) = 0.006;
// Number of blur taps (higher = smoother but more expensive).
// 12 is a good mobile/desktop balance.
const int SAMPLES = 12;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	COLOR = original;

	// NOTE: 'return' is not allowed inside fragment() in Godot's shader language,
	// so the early-outs are expressed as nested conditions instead.
	float speed_sq = dot(move_dir, move_dir);
	if (player_uv.x >= -0.5 && speed_sq >= 0.001) {
		// Distance from this pixel to the player (in UV space)
		vec2 diff = UV - player_uv;
		float dist = length(diff);

		if (dist < smear_radius) {
			// Smooth falloff: full blur at center, zero at edge
			float falloff = 1.0 - smoothstep(0.0, smear_radius, dist);
			// Boost the center area for a more visible effect
			falloff = falloff * falloff;

			// Directional blur along movement direction
			vec4 blurred = vec4(0.0);
			float strength = smear_strength * falloff;

			for (int i = 0; i < SAMPLES; i++) {
				// Spread samples from -0.5 to +0.5 of the blur range
				float t = (float(i) / float(SAMPLES - 1)) - 0.5;
				vec2 offset = move_dir * t * strength;
				blurred += texture(TEXTURE, UV + offset);
			}
			blurred /= float(SAMPLES);

			// Mix original with blurred based on falloff
			COLOR = mix(original, blurred, falloff * 0.85);
		}
	}
}
