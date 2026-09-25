shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Composition circle (docs/specs/01-spell-system.md section 5).
// Colour = element. Central glyph = form. Outer ring = effect.

uniform vec4 rune_color : source_color = vec4(1.0, 0.35, 0.12, 1.0);
// -1 none, 0 projectile (arrow), 1 self (inner circle), 2 area (square)
uniform int form_index = -1;
// -1 none, 0 direct (solid ring), 1 burst (toothed), 2 lingering (dotted)
uniform int effect_index = -1;
uniform float intensity = 1.6;
uniform float spin_speed = 0.6;

float band(float x, float center, float half_width) {
	return 1.0 - smoothstep(half_width * 0.6, half_width, abs(x - center));
}

float triangle_sdf(vec2 p, float r) {
	// Equilateral triangle pointing up (+Y in UV space = forward arrow).
	const float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float box_sdf(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float r = length(p);
	float angle = atan(p.y, p.x) + TIME * spin_speed;

	// Base ring with runic ticks: always visible while composing.
	float glow = band(r, 0.78, 0.035);
	float ticks = step(0.5, fract(angle / TAU * 24.0)) * band(r, 0.70, 0.02);
	glow += ticks * 0.6;

	// Outer ring: effect.
	if (effect_index == 0) {
		glow += band(r, 0.93, 0.03);
	} else if (effect_index == 1) {
		float teeth = step(0.5, fract(angle / TAU * 12.0));
		glow += band(r, 0.93, 0.03) + teeth * band(r, 0.98, 0.03);
	} else if (effect_index == 2) {
		float dots = 1.0 - smoothstep(0.08, 0.12, length(vec2(fract(angle / TAU * 16.0) - 0.5, (r - 0.93) * 8.0)));
		glow += dots;
	}

	// Central glyph: form.
	vec2 q = p;
	if (form_index == 0) {
		glow += 1.0 - smoothstep(0.0, 0.03, abs(triangle_sdf(q * 1.0, 0.32)));
	} else if (form_index == 1) {
		glow += band(r, 0.28, 0.03) + (1.0 - smoothstep(0.06, 0.09, r));
	} else if (form_index == 2) {
		float c = cos(TIME * -spin_speed), s = sin(TIME * -spin_speed);
		q = mat2(vec2(c, s), vec2(-s, c)) * q;
		glow += 1.0 - smoothstep(0.0, 0.03, abs(box_sdf(q, vec2(0.28))));
	}

	glow = clamp(glow, 0.0, 1.5) * step(r, 1.0);
	ALBEDO = rune_color.rgb * intensity;
	ALPHA = glow * rune_color.a;
}
