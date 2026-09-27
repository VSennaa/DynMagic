shader_type spatial;
// Storm projectile body: a crackling plasma orb. Unshaded + additive, fresnel core with
// procedural noise veins racing across the surface (gauntlet spell-body pass).
render_mode unshaded, cull_back, blend_add, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.7, 0.4, 1.0, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 4.0;

varying vec3 local_pos;

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

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float t = TIME * speed;
	float crackle = vnoise(local_pos.xy * 6.0 + local_pos.z * 3.0 + t);
	float veins = smoothstep(0.55, 0.62, crackle) - smoothstep(0.62, 0.72, crackle);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.5);
	vec3 col = mix(edge_color.rgb, core_color.rgb, clamp(fres + veins * 1.5, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(fres * 0.8 + veins, 0.12, 1.0);
}
