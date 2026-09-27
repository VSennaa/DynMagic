shader_type spatial;
// Volumetric brazier flame (docs/briefs/gauntlet-look3.md task 2): drawn on 3-4 crossed
// vertical quads so the flame reads as a solid volume from any angle. Unshaded, additive,
// double-sided. The silhouette is a teardrop eroded by value noise that rolls upward with
// TIME, then split into three hard toon bands: core -> mid -> edge.

render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 0.945, 0.76, 1.0);  // #FFF1C2
uniform vec4 mid_color : source_color = vec4(1.0, 0.694, 0.231, 1.0);  // #FFB13B
uniform vec4 edge_color : source_color = vec4(1.0, 0.353, 0.122, 1.0); // #FF5A1F
uniform float rise_speed : hint_range(0.0, 8.0) = 1.6;
uniform float edge_erosion : hint_range(0.0, 1.0) = 0.55;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// Teardrop flame silhouette (same family as particle_glyph.gdshader), p in [-1,1]^2, y up.
float sd_flame(vec2 p) {
	float body = length(p - vec2(0.0, -0.28)) - 0.52;
	float tip = max(p.y - 0.92, abs(p.x) - (0.92 - p.y) * 0.34);
	return smin(body, tip, 0.32);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);
	// Slight sway of the tip so the flame does not look like a static card.
	p.x += sin(TIME * 2.4 + UV.y * 7.0) * 0.08 * UV.y;

	// Noise rolling upward erodes the edge; two octaves, the finer one moving faster.
	float roll = fbm(vec2(UV.x * 3.4, UV.y * 4.2 - TIME * rise_speed)) * 0.5
	           + vnoise(vec2(UV.x * 6.0, UV.y * 8.0 - TIME * rise_speed * 1.7)) * 0.5;
	float d = sd_flame(p) + (roll - 0.5) * edge_erosion * 1.2;

	float edge = 1.0 - smoothstep(-0.04, 0.04, d);
	float mid = 1.0 - smoothstep(-0.16, -0.06, d);
	float core = 1.0 - smoothstep(-0.30, -0.20, d);

	vec3 col = edge_color.rgb;
	col = mix(col, mid_color.rgb, mid);
	col = mix(col, core_color.rgb, core);

	ALBEDO = col;
	ALPHA = edge;
}
