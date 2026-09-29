shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
// Spatial port of paperdoll.gdshader, for the first-person view's billboards.
//
// The 2D and 3D views draw the same characters from the same palette-encoded sheets, so a
// creature recoloured for one is recoloured for the other with no extra art. The gore and
// bleed overlays are left out here: at billboard size they are invisible, and skipping them
// keeps this cheap enough to run on every mob on screen.
//
// Layer textures store R = shade (0..5)/5 and G = material (0..3)/3.
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 pal[24];
uniform vec2 region_pos = vec2(0.0);   // top-left of this frame in the sheet, in pixels
uniform vec2 region_size = vec2(32.0);
uniform vec2 sheet_size = vec2(1024.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform float frost = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 uv = (region_pos + UV * region_size) / sheet_size;
	vec4 t = texture(tex, uv);
	if (t.a < 0.5) {
		discard;
	}
	int s = clamp(int(round(t.r * 5.0)), 0, 5);
	int m = clamp(int(round(t.g * 3.0)), 0, 3);
	vec4 c = pal[m * 6 + s];
	c.rgb = mix(c.rgb, vec3(0.75, 0.88, 1.0), frost * 0.45);
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = 1.0;
}
