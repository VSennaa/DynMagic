shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, skip_vertex_transform;

// Screen-space ink outline (docs/specs/07-art-pipeline.md section 2): edges where depth or
// normals jump are darkened. Put on a 2x2 QuadMesh child of the camera.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink_color : source_color = vec4(0.07, 0.06, 0.1, 1.0);
uniform float thickness = 1.2;
uniform float depth_sensitivity = 12.0;
uniform float normal_sensitivity = 1.6;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float d = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dx = abs(linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - linear_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX));
	float dy = abs(linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - linear_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX));
	float depth_edge = clamp((dx + dy) / max(d, 0.001) * depth_sensitivity - 0.25, 0.0, 1.0);
	vec3 n0 = texture(normal_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	vec3 n1 = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).xyz * 2.0 - 1.0;
	float normal_edge = clamp((distance(n0, n1) + distance(n0, n2)) * normal_sensitivity - 0.6, 0.0, 1.0);
	float edge = max(depth_edge, normal_edge) * step(d, 80.0);
	vec3 scene = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	ALBEDO = mix(scene, ink_color.rgb, edge * ink_color.a);
}
