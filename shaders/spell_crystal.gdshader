shader_type spatial;
// Frost projectile / wall crystal look (gauntlet spell-body pass): flat per-face shading
// from the screen-space derivative of the vertex position gives a faceted, low-poly read
// on any mesh (PrismMesh shards, wall panels), plus a bright fresnel edge rim.
render_mode unshaded, cull_back;

uniform vec4 core_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float rim_power : hint_range(0.1, 8.0) = 3.0;

void fragment() {
	// Facet flat-normal via derivatives of the view-space position: constant per triangle,
	// so each face of a low-poly mesh reads as a distinct flat plane instead of smooth-shaded.
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float ndv = clamp(dot(flat_normal, normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power);
	float facet_shade = 0.55 + 0.45 * ndv;
	vec3 col = mix(core_color.rgb * facet_shade, edge_color.rgb, rim);
	ALBEDO = col;
	ALPHA = 1.0;
}
