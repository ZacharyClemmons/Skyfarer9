shader_type canvas_item;
render_mode unshaded;

// The Cloudsea itself.
//
// Everything that is not an island is this shader. It has to do three jobs at once: say
// what time of day it is, say how far down "down" goes, and say what the weather is
// doing, all without competing with the pixel art in front of it. So it is built from a
// snapped pixel grid, a small number of tones per cloud, an ordered dither, and one hard
// element (the sun or moon).
//
// Parallax is the point of the cloud decks. Three of them drift at different rates
// against the camera, so flying fast over open air *reads* as flying fast even though
// the hull is pinned to the middle of the screen. Far islands ride in the haze behind them.

uniform vec4 top_color : source_color = vec4(0.18, 0.34, 0.60, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.55, 0.72, 0.88, 1.0);
// The cloud floor a long way below, which is what an island is floating over.
uniform vec4 deck_color : source_color = vec4(0.78, 0.82, 0.90, 1.0);
uniform vec4 haze_color : source_color = vec4(0.70, 0.80, 0.92, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);

uniform vec2 cam;              // camera position in world pixels
uniform vec2 wind = vec2(1.0, 0.2);
uniform float time_of_day = 0.4;   // 0 midnight, 0.5 noon
uniform float sun_elev = 0.6;      // -1 deep night .. 1 noon
uniform float altitude = 0.4;      // 0 the Deep .. 1 the Anvil
uniform float weather = 0.0;       // 0 clear .. 1 fully socked in
uniform vec4 weather_color : source_color = vec4(0.6, 0.66, 0.78, 1.0);
uniform float aurora = 0.0;
uniform float storm = 0.0;
uniform float flash = 0.0;         // lightning, driven from the weather system
uniform float t = 0.0;
uniform float warmth = 0.0;        // 1 at dawn and dusk: how golden the horizon is
uniform vec2 screen_size = vec2(1920.0, 1080.0);
// How hard to posterise (with an ordered dither, so it does not band).
uniform float bands = 20.0;

// The size of a sky pixel in screen units.
const float PIX = 3.0;

// ---------------------------------------------------------------- noise
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * amp;
		p = p * 2.07 + 17.0;
		amp *= 0.5;
	}
	return v;
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(floor(p), 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[q.x + q.y * 4]) + 0.5) / 16.0;
}

// One deck of cloud, drifting: returns (thickness 0 outside .. 1 deep in, sun-facing rim).
// `depth` is how far below you it is; nearer decks move faster against the camera.
// The sheet is squashed vertically so it reads as flat cloud seen nearly edge-on.
vec2 cloud_layer(vec2 uvq, float asp, float depth, float scale, float thresh, vec2 off, vec2 sdir, float dth) {
	vec2 p = vec2(uvq.x * asp, uvq.y * 1.9) * scale + off + cam * (0.00035 / depth) + wind * t * (0.004 / depth);
	float n = fbm3(p);
	float edge = thresh + dth;
	if (n < edge) {
		return vec2(0.0);
	}
	float nl = fbm3(p + vec2(sdir.x, sdir.y * 1.9) * 0.16);
	float rim = clamp((n - nl) * 9.0 + 0.35, 0.0, 1.0);
	float thick = clamp((n - edge) * 5.0, 0.0, 1.0);
	return vec2(thick + 0.02, rim);
}

// Distant floating islands as hazy silhouettes: a flat-topped hill on a hanging cone of
// rock. A 2D grid of cells with at most one island each, so they parallax in both axes.
// Returns (present, 1 for the grassy top).
vec2 far_island(vec2 uvq, float asp, float scale, float par, float seed) {
	vec2 p = vec2(uvq.x * asp, uvq.y) * scale + cam * par + vec2(seed * 7.3, seed * 3.1);
	vec2 c = floor(p);
	vec2 f = fract(p);
	float h1 = hash(c + seed);
	if (h1 < 0.62) {
		return vec2(0.0);
	}
	float h2 = hash(c + 31.7 + seed);
	float h3 = hash(c + 77.1 + seed);
	vec2 ctr = vec2(0.5 + (h2 - 0.5) * 0.22, 0.42 + (h3 - 0.5) * 0.18);
	float w = 0.20 + h3 * 0.15;
	float dx = f.x - ctr.x;
	float dy = f.y - ctr.y;              // +down
	float bump = (vnoise(vec2(f.x * 9.0, seed + h1 * 9.0)) - 0.5) * 0.05;
	float top = -0.035 + bump;
	if (dy < top) {
		float hill = 0.05 * (1.0 - clamp(abs(dx) / (w * 0.8), 0.0, 1.0));
		return vec2((dy > top - hill && abs(dx) < w * 0.8) ? 1.0 : 0.0, 1.0);
	}
	float len = 0.24 + h2 * 0.12;
	float k = 1.0 - (dy - top) / len;
	float half_w = w * pow(clamp(k, 0.0, 1.0), 0.7) * (0.9 + 0.25 * vnoise(vec2(dy * 26.0, h1 * 20.0)));
	return vec2((k > 0.0 && abs(dx) < half_w) ? 1.0 : 0.0, 0.0);
}

void fragment() {
	vec2 grid = screen_size / PIX;
	vec2 uv = (floor(SCREEN_UV * grid) + 0.5) / grid;   // snapped to the sky's pixel grid
	float asp = screen_size.x / screen_size.y;
	float y = uv.y;
	float day = smoothstep(-0.28, 0.32, sun_elev);      // 0 night .. 1 full day
	float night = smoothstep(0.05, 0.55, -sun_elev);
	float wl = 1.0 - weather * 0.85;
	float dith = bayer4(FRAGCOORD.xy) - 0.5;

	// ---- where the sun is, and which way is "toward the sun" on screen
	float sx = fract(time_of_day + 0.25);
	vec2 sun_p = vec2(sx, 0.42 - sun_elev * 0.34);
	vec2 d = (uv - sun_p) * vec2(asp, 1.0);
	float dist = length(d);
	vec2 sdir = -normalize(d + vec2(0.0001));

	// ---- the vertical body of the sky: darker overhead, brighter toward the deck below,
	// with a hot band at the horizon that leans toward the sun and warms at dawn and dusk
	vec3 col = mix(top_color.rgb, bottom_color.rgb, pow(y, 0.85));
	float side = exp(-abs(uv.x - sx) * asp * 1.5);
	float hor = smoothstep(0.15, 1.0, y);
	vec3 warm_lo = vec3(1.0, 0.50, 0.24);
	vec3 warm_hi = vec3(0.86, 0.34, 0.50);
	col = mix(col, mix(warm_hi, warm_lo, hor), warmth * hor * (0.32 + 0.45 * side) * wl);
	col = mix(col, top_color.rgb * vec3(0.85, 0.75, 1.15), warmth * (1.0 - y) * 0.30);
	col += vec3(0.05, 0.07, 0.10) * day * side * (1.0 - y * 0.6) * wl;

	// ---- stars and the milky way, once the sun is properly down
	if (night > 0.02) {
		vec2 sc = floor(uv * grid * 0.5 + cam * 0.00012);
		float s = hash(sc);
		float star = step(0.985, s);
		float mag = hash(sc + 9.1);
		float twinkle = 0.65 + 0.35 * sin(t * (1.5 + mag * 3.0) + s * 60.0);
		vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.85, 0.65), step(0.7, hash(sc + 3.3)));
		col += tint * star * twinkle * (0.5 + mag * 0.9) * night * wl;
		col += tint * step(0.9975, s) * 0.35 * night * wl;
		vec2 mp = vec2(uv.x * asp, uv.y) * 2.0;
		float lane = abs((mp.y - 0.25) - (mp.x - asp) * 0.35);
		float mw = exp(-lane * lane * 6.0) * (0.35 + fbm3(mp * 3.5 + 4.0));
		mw = floor(mw * 5.0) / 5.0;
		col += vec3(0.28, 0.26, 0.48) * mw * night * 0.55 * wl;
		// now and then a shooting star
		float ph = t * 0.11;
		float cyc = floor(ph);
		float fr = fract(ph);
		vec2 st0 = vec2(hash(vec2(cyc, 1.0)) * 0.8 + 0.1, hash(vec2(cyc, 2.0)) * 0.3 + 0.05);
		vec2 sd = vec2(0.22, 0.10);
		vec2 rel = (uv - (st0 + sd * fr)) * vec2(asp, 1.0);
		vec2 sn = normalize(sd * vec2(asp, 1.0));
		float along = dot(rel, -sn);
		float across = abs(dot(rel, vec2(-sn.y, sn.x)));
		float streak = step(across, 0.0025) * step(0.0, along) * step(along, 0.10) * (1.0 - along / 0.10);
		streak *= step(fr, 0.09) * step(0.4, hash(vec2(cyc, 5.0)));
		col += vec3(0.9, 0.95, 1.0) * streak * night * wl;
	}

	// ---- the sun, or the moon: the only hard-edged bodies in the backdrop
	float disc = 1.0 - smoothstep(0.016, 0.020, dist);
	float glow = exp(-dist * 9.0);
	vec3 body = sun_color.rgb;
	if (sun_elev < -0.05) {
		disc = 1.0 - smoothstep(0.014, 0.017, dist);
		glow *= 0.4;
		body = vec3(0.86, 0.90, 1.0);
		float shade = smoothstep(0.012, 0.018, length(d - vec2(0.006, -0.003)));
		float maria = smoothstep(0.55, 0.72, vnoise(d * 320.0 + 3.0));
		body *= (1.0 - 0.32 * maria) * (1.0 - 0.35 * shade);
	}
	col += body * glow * 0.24 * wl;
	col += body * exp(-dist * 3.2) * 0.10 * wl;
	// crepuscular rays, banded so they read as rays and not fog
	if (sun_elev > -0.15) {
		float ang = atan(d.y, d.x);
		float rays = fbm3(vec2(ang * 5.0 + t * 0.006, 1.7));
		rays = floor(smoothstep(0.40, 0.85, rays) * 4.0) / 4.0;
		col += body * rays * exp(-dist * 2.2) * 0.10 * wl * clamp(sun_elev + 0.35, 0.0, 1.0);
	}

	// ---- distant floating islands, blue-grey in the haze, two depths
	float far_vis = smoothstep(0.10, 0.5, y) * (1.0 - weather * 0.9);
	if (far_vis > 0.0) {
		vec2 i2 = far_island(uv, asp, 2.6, 0.00006, 1.0);
		if (i2.x > 0.0) {
			vec3 rock = mix(col, vec3(0.30, 0.34, 0.46) * (0.35 + day * 0.65), 0.30);
			vec3 grass = mix(col, vec3(0.34, 0.50, 0.42) * (0.4 + day * 0.6), 0.32);
			col = mix(col, mix(rock, grass, i2.y), 0.85 * far_vis);
		}
		vec2 i1 = far_island(uv + vec2(0.13, 0.0), asp, 1.6, 0.00013, 4.0);
		if (i1.x > 0.0) {
			vec3 rock = mix(col, vec3(0.28, 0.30, 0.42) * (0.3 + day * 0.7), 0.50);
			vec3 grass = mix(col, vec3(0.30, 0.50, 0.38) * (0.35 + day * 0.65), 0.52);
			col = mix(col, mix(rock, grass, i1.y), 0.92 * far_vis);
		}
	}

	// ---- cloud colours: lit side catches the sun, the underside takes the sky
	vec3 lit_c = mix(vec3(0.42, 0.46, 0.68), mix(vec3(1.0, 0.99, 0.97), sun_color.rgb * 1.08, warmth * 0.75), day);
	vec3 shd_c = mix(vec3(0.10, 0.12, 0.26), mix(bottom_color.rgb * 0.62 + vec3(0.06, 0.08, 0.14), vec3(0.55, 0.38, 0.52), warmth * 0.7), day);

	// ---- the cloud floor. A long way down, always there, and brighter than the air.
	float deck_y = mix(0.62, 0.88, altitude);
	float floor_mask = smoothstep(deck_y - 0.26, deck_y + 0.10, y);
	float floor_n = 0.0;
	if (floor_mask > 0.0) {
		vec2 fc = cloud_layer(uv, asp, 3.0, 2.1, 0.44, vec2(0.0), sdir, dith * 0.05);
		floor_n = fc.x;
		float b = floor((0.55 + 0.45 * fc.y - 0.22 * fc.x * (1.0 - fc.y)) * 4.0 + 0.5) / 4.0;
		col = mix(col, deck_color.rgb * 0.85, floor_mask * 0.55);
		col = mix(col, mix(shd_c, lit_c, b), floor_mask * clamp(fc.x * 4.0, 0.0, 1.0) * 0.72);
	}

	// ---- three drifting decks between you and it, hard-lit on the sun side
	float below = smoothstep(0.06, 0.62, y);
	if (below > 0.0) {
		float dth = dith * 0.05;
		vec2 cf = cloud_layer(uv, asp, 2.2, 2.4, 0.56, vec2(0.0), sdir, dth);
		vec2 cm = cloud_layer(uv, asp, 1.3, 3.8, 0.575, vec2(11.3, 4.1), sdir, dth);
		vec2 cn = cloud_layer(uv, asp, 0.8, 6.0, 0.60, vec2(-6.7, 9.2), sdir, dth);
		if (cf.x > 0.0) {
			float b = floor((0.6 + 0.4 * cf.y - 0.2 * cf.x * (1.0 - cf.y)) * 4.0 + 0.5) / 4.0;
			col = mix(col, mix(shd_c, lit_c, b), 0.55 * below * clamp(cf.x * 4.0, 0.0, 1.0));
		}
		if (cm.x > 0.0) {
			float b = floor((0.55 + 0.45 * cm.y - 0.25 * cm.x * (1.0 - cm.y)) * 4.0 + 0.5) / 4.0;
			col = mix(col, mix(shd_c, lit_c, b), 0.75 * below * clamp(cm.x * 4.0, 0.0, 1.0));
		}
		if (cn.x > 0.0) {
			float b = floor((0.5 + 0.5 * cn.y - 0.28 * cn.x * (1.0 - cn.y)) * 4.0 + 0.5) / 4.0;
			col = mix(col, mix(shd_c, lit_c, b), 0.92 * below * clamp(cn.x * 4.0, 0.0, 1.0));
		}
	}
	// wispy cirrus up high: long faint streaks
	{
		vec2 cp = vec2(uv.x * asp * 0.9, uv.y * 7.0) + cam * 0.00006 + wind * t * 0.002;
		float ci = fbm3(cp * vec2(1.6, 1.0) + 40.0);
		float cir = smoothstep(0.55, 0.72, ci + dith * 0.08) * (1.0 - smoothstep(0.1, 0.55, y));
		cir = floor(cir * 3.0 + 0.5) / 3.0;
		col = mix(col, mix(top_color.rgb * 1.4, lit_c, 0.7 * day + 0.2), cir * 0.35 * wl);
	}
	// the cloud floor catches the light, and the horizon burns at sunrise and sunset
	col += body * floor_mask * (0.20 + floor_n) * exp(-dist * 2.2) * 0.10 * wl;
	col = mix(col, sun_color.rgb * 0.95, warmth * smoothstep(0.32, 1.0, y) * 0.16 * wl);
	col = mix(col, body, disc * (1.0 - weather * 0.9));

	// ---- an aurora, when the weather says so: broad vertical curtains, slow
	if (aurora > 0.001) {
		float curtain = fbm3(vec2(uv.x * 3.0 + t * 0.03, uv.y * 1.2 - t * 0.01));
		float band = smoothstep(0.45, 0.85, curtain) * smoothstep(0.7, 0.1, y);
		col += vec3(0.28, 0.85, 0.62) * (floor(band * 4.0) / 4.0) * aurora * 0.5;
	}

	// ---- the weather wash. Fog, ash and thunder all arrive as a tint plus a loss of
	// contrast, which is exactly what they do to the real thing.
	if (weather > 0.001) {
		float churn = fbm3(uv * 3.4 + wind * t * 0.02 + cam * 0.0004);
		vec3 w = weather_color.rgb * (0.85 + churn * 0.3);
		col = mix(col, w, clamp(weather, 0.0, 0.92));
	}
	if (storm > 0.001) {
		float pulse = max(0.0, sin(t * 0.7) * sin(t * 2.3 + 1.0));
		col += vec3(0.55, 0.65, 0.95) * pulse * storm * 0.10;
	}
	col += vec3(0.85, 0.90, 1.0) * flash;

	// ---- posterise with an ordered dither, so the sky sits with the pixel art
	col = floor(col * bands + dith * 0.9 + 0.5) / bands;

	vec2 vc = uv - 0.5;
	col *= 1.0 - dot(vc, vc) * 0.45;

	COLOR = vec4(col, 1.0);
}
