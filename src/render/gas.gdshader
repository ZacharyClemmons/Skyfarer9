shader_type canvas_item;
// Visible gases over the whole map (tg gas overlays). data_tex is map-sized, one texel per tile:
// r = plasma, g = nitrous oxide, b = water vapour, a = smoke, each the tg overlay opacity (0-1),
// eased over time by GasLayer. Drawn in world pixels so it stays crisp like the rest of the art.

uniform sampler2D data_tex : filter_linear, repeat_disable;
uniform sampler2D tint_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(176.0, 128.0);
uniform int debug_mode = 0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int k = 0; k < 3; k++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 amt = texture(data_tex, UV);
	vec4 tint = texture(tint_tex, UV);
	if (debug_mode == 0 && amt.r + amt.g + amt.b + amt.a + tint.a < 0.003) {
		discard;
	}
	vec2 px = floor(UV * map_size * 32.0); // one world pixel
	float t = TIME;
	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// smoke: dark billows rolling slowly
	if (amt.a > 0.0) {
		float n = fbm(px / 26.0 + vec2(t * 0.12, -t * 0.18));
		float a = amt.a * clamp(0.35 + n * 0.9, 0.0, 1.0) * 0.9;
		col = mix(col, vec3(0.13, 0.13, 0.15) + n * 0.08, a);
		alpha = alpha + a * (1.0 - alpha);
	}
	// water vapour: pale steam, soft and drifting upward
	if (amt.b > 0.0) {
		float n = fbm(px / 30.0 + vec2(t * 0.05, t * 0.22));
		float a = amt.b * clamp(0.25 + n * 0.8, 0.0, 1.0) * 0.6;
		col = mix(col, vec3(0.78, 0.86, 0.95), a / max(alpha + a * (1.0 - alpha), 0.001));
		alpha = alpha + a * (1.0 - alpha);
	}
	// plasma: swirling violet with brighter pink streaks (tg "plasma" overlay)
	if (amt.r > 0.0) {
		vec2 q = px / 20.0;
		float w = fbm(q + vec2(t * 0.25, -t * 0.15));
		float n = fbm(q * 1.7 + vec2(w * 2.5, -w * 1.5) + vec2(-t * 0.3, t * 0.2));
		float streak = smoothstep(0.62, 0.8, n);
		float a = amt.r * clamp(0.35 + n * 0.75, 0.0, 1.0) * 0.8;
		vec3 pc = mix(vec3(0.52, 0.16, 0.78), vec3(0.96, 0.52, 1.0), streak);
		col = mix(col, pc, a / max(alpha + a * (1.0 - alpha), 0.001));
		alpha = alpha + a * (1.0 - alpha);
	}
	// nitrous oxide: a warm pale haze full of drifting specks (tg "nitrous_oxide" overlay)
	if (amt.g > 0.0) {
		float haze = fbm(px / 24.0 + vec2(-t * 0.08, t * 0.1));
		vec2 cellp = floor((px + vec2(t * 3.0, t * 5.0)) / 3.0);
		float speck = step(0.93 - amt.g * 0.08, hash(cellp)) * (0.6 + 0.4 * sin(t * 3.0 + hash(cellp + 3.1) * 6.28));
		float a = amt.g * clamp(0.18 + haze * 0.45 + speck * 0.6, 0.0, 1.0) * 0.75;
		vec3 nc = mix(vec3(1.0, 0.89, 0.77), vec3(1.0), speck);
		col = mix(col, nc, a / max(alpha + a * (1.0 - alpha), 0.001));
		alpha = alpha + a * (1.0 - alpha);
	}
	// Rare gases share a colour-weighted haze. Premultiplication avoids dark seams
	// when filtering across the boundary between gas and a clear tile.
	if (tint.a > 0.003) {
		float n = fbm(px / 23.0 + vec2(-t * 0.16, t * 0.12));
		float a = tint.a * clamp(0.35 + n * 0.8, 0.0, 1.0) * 0.8;
		col = mix(col, tint.rgb / tint.a, a / max(alpha + a * (1.0 - alpha), 0.001));
		alpha += a * (1.0 - alpha);
	}
	// a few coarse opacity steps keep it looking like sprite art rather than a gradient
	alpha = floor(alpha * 10.0 + 0.5) / 10.0;
	COLOR = vec4(col, alpha);
	if (debug_mode == 1) {
		COLOR = vec4(amt.r, amt.g, amt.b + amt.a, 0.9); // the raw data, for checking
	}
}
