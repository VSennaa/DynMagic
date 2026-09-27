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
// M13 "look" pass (brief gauntlet-look2): edge bevel, foot grime and low-frequency
// wear, all inside the procedural_surface branch so textured objects are untouched.
uniform float bevel_strength : hint_range(0.0, 0.5) = 0.15;
uniform float wear_strength : hint_range(0.0, 0.3) = 0.08;
uniform float grime_strength : hint_range(0.0, 1.0) = 1.0;
// M13 "look3" decals (brief gauntlet-look3.md): moss/ivy, cracks, floor dust and
// floor-region tone variation, all inside procedural_surface in world coordinates.
uniform vec3 sun_dir = vec3(-0.5, -0.433013, 0.75); // toward the sun (arena directional light)
uniform vec2 arena_half = vec2(14.0, 19.0);         // playable floor half extents (x, z)
uniform float moss_strength : hint_range(0.0, 1.0) = 0.4;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.0;
uniform float dust_strength : hint_range(0.0, 1.0) = 0.85;
uniform float region_strength : hint_range(0.0, 0.5) = 0.5;

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

// Distance-based thin stroke: 1 on a line segment from a to b, fading to 0 past `width`.
float stroke(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d = length(pa - ba * h);
	return 1.0 - smoothstep(width * 0.35, width, d);
}

// Returns a colour multiplier for the stone/tile pattern on this fragment.
// sat_boost (0 = neutral grey, ~0.5-0.8 = saturated cover colour) scales macro
// variation and wear so covers do not read as an obviously tiling texture.
vec3 masonry(vec3 p, vec3 nrm, float sat_boost) {
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
	// Fake bevel: a ~4 cm band on the top and left edges of each wall block catches light.
	if (up <= 0.6) {
		float bevel = 1.0 - smoothstep(0.0, 0.045, min(1.0 - uv.y, uv.x));
		face += bevel_strength * bevel;
	}
	face *= 0.94 + noise(p.xz * 3.1 + p.y * 2.3) * 0.12;
	vec3 col = vec3(face);
	// Macro variation: large soft patches break the tiling read at distance (warm/cool drift).
	// Saturated surfaces (cover blocks) get extra macro contrast so the repeat is less blatant.
	float macro = noise(p.xz * 0.11 + p.y * 0.07) * 0.6 + noise(p.xz * 0.37 - p.y * 0.21) * 0.4;
	float macro2 = noise(p.xz * 0.83 - p.y * 0.53 + 5.1) * 0.5 + noise(p.zx * 1.7 + p.y * 0.31 - 2.3) * 0.5;
	col *= mix(vec3(1.0), mix(vec3(0.86, 0.88, 0.94), vec3(1.08, 1.03, 0.95), macro), 1.0 + sat_boost * 1.2);
	col *= 1.0 + (macro2 - 0.5) * 0.5 * sat_boost;
	col = mix(col, vec3(0.74), line * 0.7);
	// Grime rising from the floor: blotchy, darkest at the base, fading over ~0.4 m.
	if (up <= 0.6) {
		float blotch = 0.55 + noise(p.xz * 3.0) * 0.6 + noise(p.xz * 8.0 + 11.3) * 0.25;
		float foot = 1.0 - smoothstep(0.0, 0.4 * blotch, p.y);
		col *= mix(vec3(1.0), vec3(0.74, 0.72, 0.67), clamp(foot, 0.0, 1.0) * grime_strength);
	}
	// Low-frequency wear blotches (0.3-0.6 m) that brighten/darken slightly; edge wear on
	// saturated cover blocks is boosted so the flat colour reads as a worn surface, not a tile.
	float wear = noise(p.xz * 2.0 + p.y * 0.4) * 2.0 - 1.0;
	col *= 1.0 + wear * wear_strength * (1.0 + sat_boost * 2.5);
	if (up <= 0.6) {
		// Edge chipping: darken a thin band right at the block's mortar edge, stronger when saturated.
		float edge_wear = 1.0 - smoothstep(0.0, 0.05, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
		col *= 1.0 - edge_wear * 0.25 * sat_boost * (0.5 + jitter);
	}
	// Thin dark cracks in ~10% of blocks: 1-2 short strokes seeded per cell, drawn inside
	// the block's own UV space so they never straddle a mortar joint.
	if (hash(cell + vec2(4.2, 1.7)) < 0.10) {
		float seed = hash(cell * 2.0 + vec2(9.3, 0.7));
		vec2 a = vec2(0.15 + seed * 0.5, 0.2 + fract(seed * 7.0) * 0.4);
		vec2 b = vec2(0.55 + fract(seed * 13.0) * 0.3, 0.65 + seed * 0.25);
		float crack = stroke(uv, a, b, 0.012 + seed * 0.02);
		if (seed > 0.5) {
			vec2 c = vec2(fract(seed * 5.0) * 0.7, 0.15 + seed * 0.2);
			vec2 d = vec2(0.3 + fract(seed * 11.0) * 0.5, 0.5 + fract(seed * 3.0) * 0.4);
			crack = max(crack, stroke(uv, c, d, 0.010 + seed * 0.02));
		}
		col *= 1.0 - crack * 0.55 * crack_strength;
	}
	return col;
}

// Absolute-colour decals layered over the masonry (M13 look3): moss/ivy on the foot of
// vertical faces, sand/dust on the floor next to the walls, and large tone patches that
// break up the floor tiling. Moss blends toward a fixed green so it reads as growth over
// any base colour, and only ever touches wall faces (never the floor).
vec3 decals(vec3 p, vec3 nrm, vec3 albedo) {
	float up = abs(nrm.y);
	// Moss/ivy: low-frequency patches (3-6 m cells) climbing from the wall foot, strongest
	// on faces turned away from the sun (dot(nrm, sun_dir) < 0).
	if (up <= 0.6) {
		float patch = noise(p.xz * 0.25 + 3.7) * 0.65 + noise(p.xz * 0.4 - 9.1) * 0.35;
		float patch_mask = smoothstep(0.48, 0.72, patch);
		float climb = 1.0 - smoothstep(0.0, 1.1, p.y);
		float away = clamp(-dot(nrm, sun_dir), 0.0, 1.0);
		float moss = patch_mask * climb * (0.35 + 0.65 * away) * moss_strength;
		vec3 moss_col = mix(vec3(0.431, 0.545, 0.306), vec3(0.616, 0.702, 0.416), smoothstep(0.0, 1.0, p.y / 1.1));
		albedo = mix(albedo, moss_col, moss);
	}
	if (up > 0.6) {
		// Sand/dust: lightens and yellows a ~0.5 m band around the wall bases.
		float dist = min(arena_half.x - abs(p.x), arena_half.y - abs(p.z));
		float dust = (1.0 - smoothstep(0.0, 0.5, dist)) * step(0.0, dist);
		dust *= (0.6 + noise(p.xz * 1.3 + 17.0) * 0.4) * dust_strength;
		albedo = mix(albedo, albedo * vec3(1.16, 1.14, 0.9), dust);
		// Large floor-region patches (4-8 m): +-10% value and a slight warm/cool hue drift.
		float region = noise(p.xz * 0.18 + 21.0) * 0.6 + noise(p.xz * 0.35 - 5.7) * 0.4;
		float val = (region - 0.5) * 0.2 * region_strength;
		float hue = (region - 0.5) * 0.05 * region_strength;
		albedo *= vec3(1.0 + val + hue, 1.0 + val, 1.0 + val - hue);
	}
	return albedo;
}

void fragment() {
	float n = noise(world_pos.xz * 1.7 + world_pos.y * 0.9);
	ALBEDO = base_color.rgb * texture(albedo_texture, UV).rgb * (1.0 - paint_noise + n * paint_noise * 2.0);
	if (procedural_surface) {
		// Saturation of the instance colour flags cover blocks (purple) vs. neutral stone/floor.
		float sat = max(base_color.r, max(base_color.g, base_color.b)) - min(base_color.r, min(base_color.g, base_color.b));
		ALBEDO *= masonry(world_pos, world_normal, sat);
		ALBEDO = decals(world_pos, world_normal, ALBEDO);
		// Fake rounded edge from screen-space derivatives: real geometry stays a sharp box, but a
		// ~6 cm band where the normal changes fast (a box edge) gets a highlight on top-facing
		// edges and a darker line on vertical corners, so 90-degree edges read as chamfered.
		float normal_edge = length(fwidth(world_normal));
		float edge_mask = smoothstep(0.015, 0.12, normal_edge) * (1.0 + sat * 1.5);
		float top_bias = clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
		ALBEDO *= 1.0 + edge_mask * mix(-0.10, 0.16, top_bias);
	}
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float lit = ndotl * ATTENUATION;
	float band = lit > 0.55 ? 1.0 : (lit > 0.05 ? mid_band : shadow_floor);
	vec3 tint = mix(shadow_tint.rgb, vec3(1.0), step(0.05, lit));
	// Point/spot lights fade with distance (ATTENUATION) instead of a hard toon disc at their
	// range; the sun keeps the banded look (its ATTENUATION is only the shadow term).
	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	if (!LIGHT_IS_DIRECTIONAL) {
		band = mix(0.0, 1.0, smoothstep(0.0, 0.6, ndotl)) ;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * tint * band * falloff / PI * 1.6;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += rim_color.rgb * step(0.5, rim) * rim_strength * LIGHT_COLOR / PI * max(ndotl, 0.2);
	vec3 half_vec = normalize(LIGHT + VIEW);
	// Keep block highlights tight and subdued on large planar arena surfaces.
	// LIGHT_COLOR includes light energy; broad 0.25 highlights clipped to white.
	SPECULAR_LIGHT += step(0.995, dot(NORMAL, half_vec)) * LIGHT_COLOR * 0.035 * ATTENUATION;
}
