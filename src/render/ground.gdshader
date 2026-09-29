shader_type canvas_item;
// Terrain chunks (and ship decks): world-space shading that breaks up tile repetition and
// gives the ground a life of its own.
//   - low-frequency mottling and warm/cool patches on everything (no more flat slab)
//   - snow glitter and drift shading (as before)
//   - grass: wind ripples travelling across the meadow
//   - water: glints and slow bands; lava: a pulsing glow
//   - cloud shadows sliding over outdoor ground, so ground, ship and sky share a light
// Everything is a handful of ALU ops and three texture reads: the cost is per pixel and
// does not grow with the size of the world.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float wind_speed = 1.0;
uniform vec2 wind_dir = vec2(1.0, 0.25);
uniform float cloud_shadow = 0.16;
varying vec2 world_pos;
varying vec4 vcol;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float sat = mx - min(c.r, min(c.g, c.b));
	float snowy = smoothstep(0.62, 0.8, lum) * (1.0 - smoothstep(0.12, 0.3, sat));
	float n = texture(noise_tex, world_pos / 900.0).r;
	float n2 = texture(noise_tex, world_pos / 260.0 + vec2(0.37, 0.11)).r;
	float land = 1.0 - snowy;
	// snow: drift shading (as before)
	c.rgb *= 1.0 + (n - 0.5) * 0.10 * snowy + (n2 - 0.5) * 0.05 * snowy;
	c.rgb = mix(c.rgb, c.rgb * vec3(0.9, 0.95, 1.06), snowy * smoothstep(0.55, 0.3, n));
	// everything else: patchy wear, and warm / cool drift so a wide quay is not one colour
	c.rgb *= 1.0 + ((n - 0.5) * 0.22 + (n2 - 0.5) * 0.14) * land;
	c.rgb = mix(c.rgb, c.rgb * vec3(1.07, 1.0, 0.92), smoothstep(0.52, 0.78, n2) * 0.55 * land);
	c.rgb = mix(c.rgb, c.rgb * vec3(0.94, 0.98, 1.06), smoothstep(0.48, 0.22, n) * 0.5 * land);
	vec2 px = floor(world_pos);
	float ph = hash(px);
	// grass: brightness ripples running downwind
	float grass = smoothstep(0.015, 0.07, c.g - max(c.r, c.b));
	if (grass > 0.0) {
		float w = sin(dot(world_pos, normalize(wind_dir)) * 0.05 - TIME * 1.9 * wind_speed + n2 * 9.0);
		float gust = smoothstep(0.4, 0.9, sin(dot(world_pos, vec2(0.006, 0.004)) - TIME * 0.5 * wind_speed + n * 6.0));
		c.rgb *= 1.0 + grass * (w * 0.07 + gust * (0.05 + 0.07 * w));
		c.rgb += vec3(0.05, 0.07, 0.01) * grass * step(0.985, ph * 0.5 + 0.5 * fract(w * 3.0 + n));
	}
	// water: blue and darker than sky-blue rock; glints and drifting bands
	float water = smoothstep(0.05, 0.14, c.b - c.r) * smoothstep(0.0, 0.1, c.b - c.g + 0.06) * (1.0 - snowy) * step(lum, 0.6);
	if (water > 0.0) {
		float band = sin((world_pos.x + world_pos.y * 0.6) * 0.16 - TIME * 0.9 + n2 * 7.0);
		c.rgb *= 1.0 + water * band * 0.07;
		float gl = step(0.992, hash(px + floor(TIME * 2.2 + ph * 5.0)));
		c.rgb += vec3(0.5, 0.65, 0.7) * gl * water;
	}
	// lava: the melt breathes
	float lava = smoothstep(0.35, 0.6, c.r - c.b) * smoothstep(0.5, 0.75, c.r) * step(0.3, sat);
	if (lava > 0.0) {
		c.rgb *= 1.0 + lava * (0.10 + 0.14 * sin(TIME * 1.3 + n * 12.0 + n2 * 5.0));
	}
	// snow sparkle
	float sparkle = step(0.9965, hash(px + floor(TIME * 1.7 + ph * 6.0)));
	c.rgb += vec3(sparkle * snowy * 0.9);
	// cloud shadows: big soft patches drifting with the wind across outdoor ground.
	// Tiles drawn with vcol.r just under 1.0 are indoors and stay out of it.
	float outdoor = step(0.998, vcol.r);
	float cs = texture(noise_tex, world_pos / 820.0 + wind_dir * TIME * 0.0045 * wind_speed + vec2(0.61, 0.27)).r;
	float shadow = smoothstep(0.50, 0.68, cs) * cloud_shadow * outdoor;
	c.rgb *= 1.0 - shadow;
	c.rgb = mix(c.rgb, c.rgb * vec3(0.88, 0.94, 1.08), shadow * 2.0);
	COLOR = c * vcol;
}
