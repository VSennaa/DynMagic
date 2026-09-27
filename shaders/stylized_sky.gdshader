shader_type sky;

// Stylized painted sky (docs/briefs/gauntlet-look2.md, M13): a three-band gradient
// (warm horizon -> mid -> zenith), a hard-disk sun with a wide halo following the
// directional light, and layered fbm clouds quantized to three hard toon steps,
// lit cream on the sun side and lilac in shadow, drifting slowly with TIME.

uniform vec3 zenith_color : source_color = vec3(0.31, 0.50, 0.77);   // #4F7FC4
uniform vec3 mid_color : source_color = vec3(0.62, 0.71, 0.88);      // #9FB6E0
uniform vec3 horizon_color : source_color = vec3(0.96, 0.81, 0.63);  // #F4CFA0
uniform vec3 sun_color : source_color = vec3(1.0, 0.89, 0.69);       // #FFE2B0
uniform vec3 cloud_light : source_color = vec3(1.0, 0.96, 0.88);     // #FFF4E0
uniform vec3 cloud_shadow : source_color = vec3(0.72, 0.65, 0.84);   // #B7A6D6

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	// Three-band gradient: warm horizon -> mid -> zenith.
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, h));
	col = mix(col, zenith_color, smoothstep(0.18, 0.65, h));

	// Sun: hard disk + wide halo, following the directional light direction.
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	float cos_angle = dot(dir, sun_dir);
	float disk = smoothstep(cos(radians(1.8)), cos(radians(1.0)), cos_angle);
	float halo = smoothstep(cos(radians(16.0)), cos(radians(2.0)), cos_angle);
	col = mix(col, sun_color, disk);
	col += sun_color * halo * 0.4 * (1.0 - disk);

	// Stylized clouds: two fbm layers drifting with TIME, quantized to three steps.
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.18);
		float t = TIME * 0.01;
		float c1 = fbm(uv * 0.55 + vec2(t * 2.0, -t));
		float c2 = fbm(uv * 1.3 - vec2(t * 3.0, t * 1.5) + vec2(37.0, 17.0));
		float cover = c1 * 0.7 + c2 * 0.3;
		// Hard toon quantization: 0 = clear, 1/3 = thin, 2/3 = dense.
		float q = floor(clamp(cover, 0.0, 0.999) * 3.0) / 3.0;
		// Lit side faces the sun, shadow side reads lilac.
		float lit = step(0.5, fbm(uv * 0.9 + sun_dir.xz * 0.4 + vec2(t, -t * 0.5)));
		vec3 cloud_col = mix(cloud_shadow, cloud_light, lit);
		float fade = smoothstep(0.0, 0.1, h);
		col = mix(col, cloud_col, q * fade * 1.5);
	}

	COLOR = col;
}
