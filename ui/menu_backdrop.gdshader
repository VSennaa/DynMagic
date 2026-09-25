shader_type canvas_item;

// Menu backdrop (spec 06 §4): deep ink gradient, faint parchment grain and a slowly turning
// arcane circle drawn in gold, like a page of a grimoire at night.

uniform vec4 ink_top : source_color = vec4(0.10, 0.09, 0.16, 1.0);
uniform vec4 ink_bottom : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform vec4 gold : source_color = vec4(0.91, 0.76, 0.44, 1.0);
uniform vec4 violet : source_color = vec4(0.79, 0.55, 1.0, 1.0);
uniform float circle_alpha = 0.16;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float ring(float r, float c, float w) { return 1.0 - smoothstep(w * 0.5, w, abs(r - c)); }

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(ink_top.rgb, ink_bottom.rgb, uv.y);
	// Parchment grain and a soft vignette.
	col += (noise(uv * vec2(420.0, 240.0)) - 0.5) * 0.025 + (noise(uv * 9.0) - 0.5) * 0.04;
	float vignette = smoothstep(1.1, 0.35, length((uv - 0.5) * vec2(1.4, 1.0)));
	col *= mix(0.55, 1.0, vignette);
	// Arcane circle centred on the right third, turning slowly.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (uv - vec2(0.66, 0.5)) * aspect * 2.2;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * 0.05;
	float lines = ring(r, 0.92, 0.012) + ring(r, 0.78, 0.008) + ring(r, 0.42, 0.01);
	lines += ring(r, 0.85, 0.02) * step(0.5, fract((a + t) / TAU * 36.0));
	// Hexagram between the inner rings.
	for (int i = 0; i < 6; i++) {
		float ang = float(i) * TAU / 6.0 - t * 2.0;
		vec2 d = vec2(cos(ang), sin(ang));
		float dist = abs(dot(p, vec2(-d.y, d.x)));
		lines += (1.0 - smoothstep(0.004, 0.009, dist - 0.0)) * step(r, 0.78) * step(0.42, r) * 0.6;
	}
	float glow = lines * circle_alpha * (0.8 + 0.2 * sin(TIME * 0.7));
	col += mix(gold.rgb, violet.rgb, 0.5 + 0.5 * sin(a * 3.0 + TIME * 0.2)) * glow;
	COLOR = vec4(col, 1.0);
}
