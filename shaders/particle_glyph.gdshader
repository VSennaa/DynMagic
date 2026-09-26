shader_type spatial;
// Particle glyphs drawn as SDF shapes in the quad's UV space (docs/briefs/gauntlet-vfx.md).
// One material per element: `shape` (0..3) selects the glyph, 4 is the soft core glow.
// Fire/Storm use the additive variant rebuilt in vfx/element_fx.gd (the render_mode
// token below is swapped at runtime); Frost/Wind keep the default alpha blending.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform int shape = 0;
uniform vec4 core_color : source_color = vec4(1.0, 0.91, 0.66, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.12, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 1.0;
// Stable per-particle random rotation (0 = keep upright), e.g. frost shards.
uniform float random_rot : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// 0 fire — teardrop flame pointing up.
float sd_flame(vec2 p) {
	float body = length(p - vec2(0.0, -0.28)) - 0.52;
	float tip = max(p.y - 0.95, abs(p.x) - (0.95 - p.y) * 0.34);
	return smin(body, tip, 0.32);
}

// 1 frost — elongated diamond shard.
float sd_shard(vec2 p) {
	vec2 q = abs(p);
	return (q.x / 0.30 + q.y / 0.95 - 1.0) * 0.30;
}

// 2 storm — 3-segment zig-zag bolt (unsigned distance to the polyline).
float sd_bolt(vec2 p) {
	float d = sd_segment(p, vec2(-0.05, -0.92), vec2(0.38, -0.15));
	d = min(d, sd_segment(p, vec2(0.38, -0.15), vec2(-0.38, 0.32)));
	d = min(d, sd_segment(p, vec2(-0.38, 0.32), vec2(0.05, 0.92)));
	return d;
}

// 3 wind — curved ribbon, a ~120° arc band.
float sd_ribbon(vec2 p) {
	vec2 q = p - vec2(0.0, -0.12);
	float r = length(q);
	float radial = abs(r - 0.72) - 0.17;
	float ang = atan(q.y, q.x);
	float lo = radians(30.0);
	float hi = radians(150.0);
	float angular = 0.0;
	if (ang < lo) {
		angular = (lo - ang) * 0.72;
	} else if (ang > hi) {
		angular = (ang - hi) * 0.72;
	}
	return max(radial, angular);
}

// 4 — soft circular core glow.
float sd_glow(vec2 p) {
	return length(p) - 0.55;
}

// Value noise for the dissolve: glyphs erode into ragged pieces instead of fading as solid cut-outs.
float vnoise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Billboard the quad to face the camera, keeping the particle's world position
	// and its uniform scale (mesh size stays in VERTEX, scale in MODEL_MATRIX).
	float s = length(MODEL_MATRIX[0].xyz);
	mat4 bb = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * s, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * s, 0.0),
		vec4(-INV_VIEW_MATRIX[2].xyz * s, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	world_pos = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (random_rot > 0.0) {
		float ang = (hash21(floor(world_pos.xy * 2.0)) - 0.5) * TAU * random_rot;
		float c = cos(ang);
		float sn = sin(ang);
		p = vec2(c * p.x - sn * p.y, sn * p.x + c * p.y);
	}
	vec3 col = core_color.rgb;
	float a = 0.0;
	if (shape == 0) {
		// UV.y grows downward on the billboard quad, so flip it or the flame points down.
		float d = sd_flame(vec2(p.x, -p.y));
		float aa = max(fwidth(d), 0.015);
		float edge = 1.0 - smoothstep(-aa, aa, d);
		float core = step(d, -0.30);
		col = mix(edge_color.rgb, core_color.rgb, core);
		a = edge * base_alpha;
	} else if (shape == 1) {
		float d = sd_shard(p);
		float aa = max(fwidth(d), 0.015);
		float edge = 1.0 - smoothstep(-aa, aa, d);
		float core = step(d, -0.08);
		col = mix(edge_color.rgb, core_color.rgb, core);
		a = edge * base_alpha;
	} else if (shape == 2) {
		float d = sd_bolt(p);
		float core = 1.0 - smoothstep(0.02, 0.05, d);
		float halo = 1.0 - smoothstep(0.10, 0.35, d);
		col = mix(edge_color.rgb, core_color.rgb, core);
		a = max(halo * 0.55, core) * base_alpha;
	} else if (shape == 3) {
		float d = sd_ribbon(p);
		float aa = max(fwidth(d), 0.015);
		float edge = 1.0 - smoothstep(-aa, aa, d);
		float core = step(d, -0.06);
		col = mix(edge_color.rgb, core_color.rgb, core);
		a = edge * base_alpha;
	} else {
		float d = sd_glow(p);
		col = core_color.rgb;
		a = (1.0 - smoothstep(0.0, 0.6, d)) * base_alpha;
	}
	ALBEDO = col;
	// COLOR.a is the lifetime fade from the colour ramp (1 at birth, 0 at death).
	float life = COLOR.a;
	if (shape == 4) {
		ALPHA = clamp(a, 0.0, 1.0) * life;
	} else {
		float n = vnoise(p * 2.6 + world_pos.xz * 3.7 + world_pos.y * 1.3);
		float keep = smoothstep(n - 0.06, n + 0.06, life * 1.2 - 0.1);
		ALPHA = clamp(a, 0.0, 1.0) * keep;
	}
}
