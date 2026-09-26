shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Cartoon shading (docs/specs/07-art-pipeline.md section 2): 3 light bands, rim light,
// block specular and a faint painted noise so flat colours do not look plastic.

uniform vec4 base_color : source_color = vec4(0.6, 0.58, 0.55, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.32;
// Shadow side leans cool so lit faces read warm against it (value + temperature contrast).
uniform vec4 shadow_tint : source_color = vec4(0.78, 0.84, 1.0, 1.0);
uniform float mid_band : hint_range(0.0, 1.0) = 0.72;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform float paint_noise : hint_range(0.0, 0.3) = 0.06;
// Untextured arena geometry gets hand-painted masonry in world space (M13 gauntlet):
// running-bond stone on walls, flagstones on floors, grime at the foot of walls.
uniform bool procedural_surface = false;
uniform float brick_size = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Distance-antialiased mortar line: 1 inside the joint, 0 on the stone face.
float joint(vec2 cell_uv, vec2 width) {
	vec2 aa = fwidth(cell_uv) * 1.5;
	vec2 edge = min(cell_uv, 1.0 - cell_uv);
	vec2 j = 1.0 - smoothstep(width, width + aa, edge);
	return max(j.x, j.y);
}

// Returns a colour multiplier for the stone/tile pattern on this fragment.
vec3 masonry(vec3 p, vec3 nrm) {
	float up = abs(nrm.y);
	vec2 uv;
	vec2 cell;
	float line;
	if (up > 0.6) {
		// Floor / top faces: large flagstones, every other row offset by half a tile.
		vec2 q = p.xz / (brick_size * 1.7);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		cell = floor(q);
		uv = fract(q);
		line = joint(uv, vec2(0.014) * (0.6 + noise(p.xz * 6.0) * 0.8));
	} else {
		// Walls: running-bond blocks, horizontal coordinate follows the face direction.
		float h = abs(nrm.x) > abs(nrm.z) ? p.z : p.x;
		vec2 q = vec2(h / brick_size, p.y / (brick_size * 0.42));
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		cell = floor(q);
		uv = fract(q);
		line = joint(uv, vec2(0.012, 0.03) * (0.6 + noise(p.xy * 7.0 + p.z * 5.0) * 0.8));
	}
	float jitter = hash(cell + floor(p.y * 0.01));
	// Painted face: per-stone value shift, a soft top-left highlight and blotchy wear.
	float face = 0.8 + jitter * 0.3;
	face += (1.0 - uv.y) * 0.05 * step(up, 0.6) - uv.x * 0.03;
	face *= 0.94 + noise(p.xz * 3.1 + p.y * 2.3) * 0.12;
	vec3 col = vec3(face);
	// Macro variation: large soft patches break the tiling read at distance (warm/cool drift).
	float macro = noise(p.xz * 0.11 + p.y * 0.07) * 0.6 + noise(p.xz * 0.37 - p.y * 0.21) * 0.4;
	col *= mix(vec3(0.86, 0.88, 0.94), vec3(1.08, 1.03, 0.95), macro);
	col = mix(col, vec3(0.74), line * 0.7);
	// Grime and moss tint at the foot of walls, lighter wash near the top.
	if (up <= 0.6) {
		float foot = 1.0 - smoothstep(0.0, 0.9, p.y);
		col *= mix(vec3(1.0), vec3(0.72, 0.78, 0.66), foot * 0.6);
	}
	return col;
}

void fragment() {
	float n = noise(world_pos.xz * 1.7 + world_pos.y * 0.9);
	ALBEDO = base_color.rgb * texture(albedo_texture, UV).rgb * (1.0 - paint_noise + n * paint_noise * 2.0);
	if (procedural_surface) {
		ALBEDO *= masonry(world_pos, world_normal);
	}
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float lit = ndotl * ATTENUATION;
	float band = lit > 0.55 ? 1.0 : (lit > 0.05 ? mid_band : shadow_floor);
	vec3 tint = mix(shadow_tint.rgb, vec3(1.0), step(0.05, lit));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * tint * band / PI * 1.6;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += rim_color.rgb * step(0.5, rim) * rim_strength * LIGHT_COLOR / PI * max(ndotl, 0.2);
	vec3 half_vec = normalize(LIGHT + VIEW);
	// Keep block highlights tight and subdued on large planar arena surfaces.
	// LIGHT_COLOR includes light energy; broad 0.25 highlights clipped to white.
	SPECULAR_LIGHT += step(0.995, dot(NORMAL, half_vec)) * LIGHT_COLOR * 0.035 * ATTENUATION;
}
