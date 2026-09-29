shader_type canvas_item;
render_mode unshaded, blend_mul;

// Lighting and visibility still come from the real tile simulation. Only their display
// coordinates move with the ship, exactly as its deck and fittings do.
uniform sampler2D ship_source : filter_linear, repeat_disable;
uniform sampler2D ship_mask : filter_nearest, repeat_disable;
uniform vec2 region_origin;
uniform int ship_count = 0;
uniform vec4 ship_pivots[8]; // source pivot xy, continuously drawn pivot zw, in tiles
uniform vec2 ship_rotations[8]; // cos/sin of drawn angle relative to source facing

void fragment() {
	vec2 region_size = vec2(textureSize(TEXTURE, 0));
	vec2 world = region_origin + UV * region_size;
	vec4 light = texture(TEXTURE, UV);
	for (int slot = 0; slot < 8; slot++) {
		if (slot >= ship_count) {
			break;
		}
		vec4 pivots = ship_pivots[slot];
		vec2 cs = ship_rotations[slot];
		vec2 rel = world - pivots.zw;
		vec2 source = pivots.xy + vec2(cs.x * rel.x + cs.y * rel.y,
			-cs.y * rel.x + cs.x * rel.y);
		vec2 source_uv = (source - region_origin) / region_size;
		if (any(lessThan(source_uv, vec2(0.0))) || any(greaterThanEqual(source_uv, vec2(1.0)))) {
			continue;
		}
		float id = texture(ship_mask, source_uv).r * 255.0;
		if (abs(id - float(slot + 1)) < 0.5) {
			light = texture(ship_source, source_uv);
			break;
		}
	}
	COLOR = light;
}
