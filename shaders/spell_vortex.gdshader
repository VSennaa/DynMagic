shader_type spatial;
// Wind projectile ribbons / wall screen: a translucent swirling band scrolling along the
// quad's V axis so a set of spinning crossed quads reads as a twisted vortex
// (gauntlet spell-body pass).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 core_color : source_color = vec4(0.6, 1.0, 0.8, 0.55);
uniform vec4 edge_color : source_color = vec4(0.88, 1.0, 0.93, 0.85);
uniform float twist : hint_range(0.0, 10.0) = 3.0;
uniform float speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV;
	float swirl = sin((uv.y * twist - TIME * speed) * TAU) * 0.5 + 0.5;
	float band = smoothstep(0.15, 0.5, swirl) - smoothstep(0.5, 0.85, swirl);
	float edge_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
	vec3 col = mix(core_color.rgb, edge_color.rgb, swirl);
	ALBEDO = col;
	ALPHA = clamp(band * edge_fade * core_color.a, 0.0, 1.0);
}
