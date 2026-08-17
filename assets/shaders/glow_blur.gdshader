shader_type canvas_item;
// Gaussian edge blur for powerup/item glow sprites.
// Softens ray edges to create a smooth fade-out effect.

uniform float blur_strength : hint_range(0.0, 10.0) = 3.5;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_strength;
	vec4 sum = vec4(0.0);
	float weight_sum = 0.0;

	// 5x5 gaussian kernel (25 samples)
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			float w = exp(-(x * x + y * y) / 4.0);
			sum += texture(TEXTURE, UV + vec2(x, y) * ps) * w;
			weight_sum += w;
		}
	}

	COLOR = sum / weight_sum;
}
