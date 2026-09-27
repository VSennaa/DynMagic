shader_type spatial;
// Element wall skins (gauntlet spell-body pass), applied over the existing BoxMesh so
// collision/HP logic in wall.gd stays untouched: only the material changes per element.
//   0 fire  = rising flame curtain
//   1 frost = faceted ice cracks
//   2 storm = crackling vertical arcs
//   3 wind  = swirling diagonal air streaks
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);
uniform int element = 0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.7;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.1 + vec2(5.1, 2.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec3 col = core_color.rgb;
	float a = base_alpha;
	if (element == 0) {
		float flip_t = floor(t * 10.0) / 10.0;
		float n = fbm(vec2(uv.x * 4.0, uv.y * 3.0 - flip_t * 2.2));
		float lick = smoothstep(0.35, 0.75, n) * smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.7, uv.y);
		col = mix(edge_color.rgb, core_color.rgb, n);
		a = base_alpha * (0.35 + 0.65 * lick);
	} else if (element == 1) {
		vec2 cell = fract(uv * vec2(6.0, 4.0)) - 0.5;
		float d = min(abs(cell.x), abs(cell.y));
		float crack = smoothstep(0.08, 0.0, d);
		col = mix(core_color.rgb, edge_color.rgb, crack);
		a = base_alpha;
	} else if (element == 2) {
		float lane = floor(uv.x * 10.0);
		float jitter = hash21(vec2(lane, floor(t * 8.0)));
		float x0 = (lane + 0.5) / 10.0 + (jitter - 0.5) * 0.06;
		float dist = abs(uv.x - x0);
		float arc = smoothstep(0.02, 0.0, dist);
		col = mix(edge_color.rgb, core_color.rgb, arc);
		a = base_alpha * (0.25 + 0.75 * arc);
	} else {
		float diag = uv.x * 3.0 + uv.y * 6.0 - t * 1.5;
		float streak = smoothstep(0.4, 0.5, fract(diag)) - smoothstep(0.5, 0.6, fract(diag));
		col = mix(core_color.rgb, edge_color.rgb, streak);
		a = base_alpha * (0.3 + 0.5 * streak);
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
