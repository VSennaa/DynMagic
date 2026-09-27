shader_type spatial;
// Element ground motifs for zone/area spells (gauntlet spell-body pass). Extends the
// M11 ground_ring.gdshader readability contract:
//   mode 0 (Área):     one sharp solid ring that sweeps outward once (progress 0..1) and fades.
//   mode 1 (Contínuo): faint fill, pulsing dotted edge and an arc that shrinks with time left.
// `element` (0 fire, 1 frost, 2 storm, 3 wind) adds a motif inside the ring so each element
// reads distinctly instead of a plain flat disc.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(1.0);
uniform int mode = 1;
uniform int element = 0;
uniform float progress = 0.0;       // mode 0: sweep 0..1
uniform float remaining = 1.0;      // mode 1: time left 0..1
uniform float pulse_time = 0.0;     // mode 1: seconds alive (drives the pulse)

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float motif(vec2 p, float r, float ang, float t) {
	if (element == 0) {
		// fire: flickering ember dashes just inside the ring
		float slot = floor(ang * 20.0);
		float dashes = step(0.5, fract(ang * 20.0 + hash21(vec2(slot, 0.0)) * 0.3));
		float band = smoothstep(0.05, 0.0, abs(r - 0.8));
		float flicker = 0.6 + 0.4 * sin(t * 9.0 + ang * 40.0);
		return band * dashes * flicker;
	} else if (element == 1) {
		// frost: 6-point star radiating from the centre
		float star = 0.0;
		for (int i = 0; i < 6; i++) {
			float a0 = float(i) / 6.0 * TAU;
			vec2 dir = vec2(cos(a0), sin(a0));
			float proj = max(dot(p, dir), 0.0);
			float perp = length(p - dir * proj);
			star = max(star, smoothstep(0.05, 0.0, perp) * step(proj, 0.85) * step(0.04, proj));
		}
		return star;
	} else if (element == 2) {
		// storm: jagged arcs ringing the edge, redrawn a few times a second
		float step_t = floor(t * 6.0);
		float zig = abs(fract(ang * 10.0 + step_t * 0.37) - 0.5) * 2.0;
		return smoothstep(0.12, 0.0, abs(r - (0.78 + zig * 0.08)));
	} else {
		// wind: spinning spiral arms
		float spiral = fract(ang * 3.0 + r * 2.2 - t * 0.6);
		return smoothstep(0.5, 0.46, abs(spiral - 0.5)) * step(r, 0.95);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / TAU + 0.5;
	float m = motif(p, r, ang, pulse_time);
	float a = 0.0;
	if (mode == 0) {
		float front = mix(0.15, 1.0, progress);
		float band = smoothstep(0.07, 0.0, abs(r - front));
		float inner = step(r, front) * 0.25 * (1.0 - progress);
		a = (band + inner + m * step(r, front) * 0.6) * (1.0 - progress * progress);
	} else {
		float fill = step(r, 1.0) * 0.14;
		float dots = step(0.5, fract(ang * 36.0));
		float edge = smoothstep(0.06, 0.0, abs(r - 0.94)) * dots;
		float pulse = 0.55 + 0.45 * sin(pulse_time * 5.0);
		float timer = smoothstep(0.035, 0.0, abs(r - 0.82)) * step(ang, remaining);
		a = fill + edge * pulse + timer * 0.9 + m * 0.5;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
