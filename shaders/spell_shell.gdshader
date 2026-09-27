shader_type spatial;
// Self-spell shells (guard/aura/impulse) and explosion shockwaves (gauntlet spell-body
// pass): a fresnel rim shell colored by the spell's element, instead of a plain flat sphere.
render_mode unshaded, cull_back, blend_mix, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float rim_power : hint_range(0.1, 8.0) = 2.5;
uniform float ripple_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power);
	float ripple = 0.85 + 0.15 * sin(UV.y * 20.0 - TIME * ripple_speed);
	vec3 col = mix(color.rgb, color.rgb + vec3(0.3), rim);
	ALBEDO = col;
	ALPHA = clamp((base_alpha + rim * 0.6) * ripple, 0.0, 1.0);
}
