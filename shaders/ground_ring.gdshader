shader_type spatial;
// M11 ground markers, drawn on a unit plane scaled to the radius.
//   mode 0 (Área):     one sharp solid ring that sweeps outward once (progress 0..1) and fades.
//   mode 1 (Contínuo): faint fill, pulsing dotted edge and an arc that shrinks with the time left.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(1.0);
uniform int mode = 1;
uniform float progress = 0.0;       // mode 0: sweep 0..1
uniform float remaining = 1.0;      // mode 1: time left 0..1
uniform float pulse_time = 0.0;     // mode 1: seconds alive (drives the pulse)


void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	if (mode == 0) {
		float front = mix(0.15, 1.0, progress);
		float band = smoothstep(0.07, 0.0, abs(r - front));
		float inner = step(r, front) * 0.25 * (1.0 - progress);
		a = (band + inner) * (1.0 - progress * progress);
	} else {
		float fill = step(r, 1.0) * 0.14;
		float angle = atan(p.y, p.x) / TAU + 0.5;
		float dots = step(0.5, fract(angle * 36.0));
		float edge = smoothstep(0.06, 0.0, abs(r - 0.94)) * dots;
		float pulse = 0.55 + 0.45 * sin(pulse_time * 5.0);
		// Time ring just inside the edge: a clockwise arc covering the fraction left.
		float timer = smoothstep(0.035, 0.0, abs(r - 0.82)) * step(angle, remaining);
		a = fill + edge * pulse + timer * 0.9;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
