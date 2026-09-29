shader_type canvas_item;
// Full-screen post effects: vignette, creeping frost when the player is freezing,
// blizzard whiteout, blurred sight from hurt eyes, and tg's damage overlays
// (carbon/update_damage_hud: /atom/movable/screen/fullscreen/brute, oxy, crit, crit/vision).
uniform float frost = 0.0;
uniform float blizzard = 0.0;
uniform float brute_sev = 0.0; // 0-6
uniform float oxy_sev = 0.0; // 0-7
uniform float crit_sev = 0.0; // 0-10
uniform float critvision = 0.0; // 0, or 4-10
uniform float aurora = 0.0;
uniform float blur = 0.0; // eye damage, tg eye_blur
uniform float blind = 0.0; // tg /atom/movable/screen/fullscreen/blind (1 = black)
uniform float high = 0.0; // tg /atom/movable/screen/fullscreen/high
uniform float flash = 0.0; // tg /atom/movable/screen/fullscreen/flash (fades over 2.5 s)
uniform float mono = 0.0; // tg /datum/client_colour/monochrome (achromatopsia, trance)
uniform float psychic = 0.0;
uniform vec4 grade = vec4(0.0); // time-of-day haze/colour wash (rgb, alpha), set by LightingSystem
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	d.x *= 1.777;
	float r = length(d);
	vec4 col = vec4(0.0);
	if (mono > 0.0) {
		vec3 sc = textureLod(screen_tex, uv, 0.0).rgb;
		col = vec4(vec3(dot(sc, vec3(0.299, 0.587, 0.114))), mono);
	}
	// vignette
	// gentle haze toward the sky's colour, thickest at the edges, then a soft vignette
	col = mix(col, vec4(grade.rgb, grade.a * (0.45 + 0.55 * smoothstep(0.2, 1.0, r))), step(0.001, grade.a) * (1.0 - col.a));
	float vig = smoothstep(0.5, 1.2, r);
	vig *= vig * (3.0 - 2.0 * vig);
	col = mix(col, vec4(0.0, 0.01, 0.04, 0.5), vig);
	// frost: crystalline noise creeping from the edges
	if (frost > 0.0) {
		float n = texture(noise_tex, uv * vec2(3.0, 1.7)).r * 0.6 + texture(noise_tex, uv * vec2(9.0, 5.0)).r * 0.4;
		float edge = smoothstep(0.95 - frost * 0.55, 1.05 - frost * 0.4, r + n * 0.35);
		float crystal = smoothstep(0.55, 0.6, fract(n * 7.0 + r * 3.0)) * 0.35;
		vec4 f = vec4(vec3(0.82, 0.92, 1.0) + crystal, edge * 0.85);
		col = mix(col, f, f.a);
	}
	// blizzard whiteout (moving noise)
	if (blizzard > 0.0) {
		float n1 = texture(noise_tex, uv * vec2(1.6, 0.9) + vec2(-TIME * 0.19, TIME * 0.03)).r;
		float n2 = texture(noise_tex, uv * vec2(4.0, 2.3) + vec2(-TIME * 0.5, TIME * 0.07)).r;
		float wo = blizzard * (0.25 + 0.5 * n1 * n2 + 0.25 * smoothstep(0.2, 0.9, r));
		col = mix(col, vec4(0.86, 0.9, 0.98, 1.0), clamp(wo, 0.0, 0.85));
	}
	// tg brutedamageoverlay: a scratchy red rim, deeper and darker each step
	if (brute_sev > 0.0) {
		float k = brute_sev / 6.0;
		float n = texture(noise_tex, uv * vec2(5.0, 2.8)).r;
		float rim = smoothstep(1.02 - k * 0.42, 1.18 - k * 0.3, r + (n - 0.5) * 0.22);
		col = mix(col, vec4(0.42, 0.0, 0.0, 1.0), rim * (0.3 + 0.5 * k));
	}
	// tg oxydamageoverlay: a dark rim closing in
	if (oxy_sev > 0.0) {
		float k = oxy_sev / 7.0;
		float rim = smoothstep(1.0 - k * 0.55, 1.15 - k * 0.45, r);
		col = mix(col, vec4(0.0, 0.0, 0.03, 1.0), rim * (0.35 + 0.55 * k));
	}
	// tg crit "passage": a black ring that tightens as health falls
	if (crit_sev > 0.0) {
		float k = crit_sev / 10.0;
		float rim = smoothstep(0.85 - k * 0.5, 1.0 - k * 0.45, r);
		col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), rim * (0.55 + 0.45 * k));
	}
	// tg crit/vision: in soft crit you only see a shrinking circle around you
	if (critvision > 0.0) {
		float hole = mix(0.62, 0.12, (critvision - 4.0) / 6.0);
		col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), smoothstep(hole, hole + 0.12, r) * 0.96);
	}
	if (aurora > 0.0) {
		float band = texture(noise_tex, vec2(uv.x * 0.8 + TIME * 0.01, TIME * 0.02)).r;
		float top = smoothstep(0.45, 0.0, uv.y);
		vec3 ac = mix(vec3(0.2, 1.0, 0.6), vec3(0.6, 0.3, 1.0), band);
		col.rgb += ac * top * band * aurora * 0.12;
		col.a = max(col.a, top * band * aurora * 0.12);
	}
	if (blur > 0.0) {
		// hurt eyes: the world smears and dims, worst away from the centre
		float ba = clamp(blur * (0.55 + 0.45 * smoothstep(0.1, 0.7, r)), 0.0, 1.0);
		vec3 b = textureLod(screen_tex, uv, 1.0 + blur * 3.5).rgb * (1.0 - blur * 0.25);
		float oa = col.a + ba * (1.0 - col.a);
		col.rgb = (col.rgb * col.a + b * ba * (1.0 - col.a)) / max(oa, 0.001);
		col.a = oa;
	}
	if (high > 0.0) {
		// tg drugginess: a shifting wash of colour
		vec3 hc = 0.5 + 0.5 * cos(TIME * 1.3 + uv.xyx * 3.0 + vec3(0.0, 2.0, 4.0));
		col.rgb = mix(col.rgb, hc, 0.25 * high);
		col.a = max(col.a, 0.25 * high);
	}
	if (psychic > 0.0) {
		vec2 warped = uv + vec2(sin(uv.y * 25.0 + TIME * 2.0) * 0.006, cos(uv.x * 20.0 + TIME) * 0.004);
		col = vec4(textureLod(screen_tex, warped, 1.0).rgb, 0.85);
	}
	if (blind > 0.0) {
		// tg blindness: black, a faint flicker at the edges (temporary blindness)
		float flick = 0.04 * texture(noise_tex, uv * 2.0 + vec2(TIME * 0.3, 0.0)).r * step(blind, 0.99);
		col = mix(col, vec4(flick, flick, flick, 1.0), blind);
	}
	if (flash > 0.0) {
		col = mix(col, vec4(1.0, 1.0, 1.0, 1.0), flash);
	}
	COLOR = col;
}
