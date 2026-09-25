shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Cartoon shading (docs/specs/07-art-pipeline.md section 2): 3 light bands, rim light,
// block specular and a faint painted noise so flat colours do not look plastic.

uniform vec4 base_color : source_color = vec4(0.6, 0.58, 0.55, 1.0);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.42;
uniform float mid_band : hint_range(0.0, 1.0) = 0.72;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform float paint_noise : hint_range(0.0, 0.3) = 0.06;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(world_pos.xz * 1.7 + world_pos.y * 0.9);
	ALBEDO = base_color.rgb * (1.0 - paint_noise + n * paint_noise * 2.0);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float lit = ndotl * ATTENUATION;
	float band = lit > 0.55 ? 1.0 : (lit > 0.05 ? mid_band : shadow_floor);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band / PI * 1.6;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += rim_color.rgb * step(0.5, rim) * rim_strength * LIGHT_COLOR / PI * max(ndotl, 0.2);
	vec3 half_vec = normalize(LIGHT + VIEW);
	// Keep block highlights tight and subdued on large planar arena surfaces.
	// LIGHT_COLOR includes light energy; broad 0.25 highlights clipped to white.
	SPECULAR_LIGHT += step(0.995, dot(NORMAL, half_vec)) * LIGHT_COLOR * 0.035 * ATTENUATION;
}
