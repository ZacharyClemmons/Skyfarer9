shader_type canvas_item;
// Paper-doll recolouring. Layer textures store R = shade (0..5)/5 and G = material (0..3)/3.
// `pal` holds 4 materials x 6 shades (outline, dark .. highlight), filled from Gfx.ramp6().
uniform vec4 pal[24];
uniform float flash = 0.0;       // damage flash
uniform vec4 flash_color : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform float frost = 0.0;       // hypothermia tint
// tg bodypart gore: `cut` bits are missing limbs (1 l_arm, 2 r_arm, 4 l_leg, 8 r_leg),
// `bleed` the bleed overlay level per limb (0..3, tg bleed_overlays.dmi), `bleed2` the
// chest and head. `origin` is the frame's top-left in the sheet, `facing` 0 s 1 n 2 e 3 w.
uniform int cut = 0;
uniform vec4 bleed = vec4(0.0);
uniform vec2 bleed2 = vec2(0.0);
uniform vec2 origin = vec2(0.0);
uniform int facing = 0;
uniform float stain = 0.0; // tg blood-stained clothing (the item's blood overlay)
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

float hash(float n) {
	return fract(sin(n * 91.345 + 7.13) * 43758.5453);
}

// which limb this frame pixel belongs to: 0 none, 1 l_arm, 2 r_arm, 3 l_leg, 4 r_leg, 5 chest, 6 head
int part_at(vec2 p) {
	float x = p.x;
	float y = p.y;
	if (facing == 3) {
		x = 31.0 - x; // west is the east view mirrored
	}
	if (y <= 12.0) {
		return 6;
	}
	if (facing <= 1) {
		// front/back: the arm on the viewer's left is the right arm facing south
		bool left_side = x <= 10.5;
		bool right_side = x >= 20.5;
		if ((left_side || right_side) && y >= 12.5 && y <= 25.5) {
			bool is_left_arm = (facing == 0) ? right_side : left_side;
			return is_left_arm ? 1 : 2;
		}
		if (y >= 21.5 && x >= 10.5 && x <= 20.5) {
			bool is_left_leg = (facing == 0) ? (x >= 15.5) : (x < 15.5);
			return is_left_leg ? 3 : 4;
		}
		return 5;
	}
	// profile: the near arm is drawn over the torso and stays (only legs split front/back)
	if (y >= 21.5) {
		bool front = x >= 16.0;
		if (facing == 2) {
			return front ? 4 : 3;
		}
		return front ? 3 : 4;
	}
	return 5;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE - origin);
	int part = part_at(p);
	if (part >= 1 && part <= 4 && (cut & (1 << (part - 1))) != 0) {
		discard;
	}
	int s = clamp(int(round(t.r * 5.0)), 0, 5);
	int m = clamp(int(round(t.g * 3.0)), 0, 3);
	vec4 c = pal[m * 6 + s];
	// tg bleed overlays: blood runs down from the wound, more streaks the worse it bleeds
	float lvl = 0.0;
	if (part >= 1 && part <= 4) {
		lvl = bleed[part - 1];
	} else if (part == 5) {
		lvl = bleed2.x;
	} else if (part == 6) {
		lvl = bleed2.y;
	}
	// a fresh stump: the pixels next to a missing limb are raw and bloody
	bool stump = false;
	if (facing <= 1 && p.y >= 12.5 && p.y <= 14.5 && (cut & 3) != 0) {
		int side = part_at(p + vec2(-2.0, 0.0));
		int side2 = part_at(p + vec2(2.0, 0.0));
		stump = (side >= 1 && side <= 2 && (cut & (1 << (side - 1))) != 0) || (side2 >= 1 && side2 <= 2 && (cut & (1 << (side2 - 1))) != 0);
	}
	if (p.y >= 20.5 && p.y <= 21.5 && (cut & 12) != 0 && part == 5) {
		int below = part_at(p + vec2(0.0, 1.0));
		stump = stump || (below >= 3 && (cut & (1 << (below - 1))) != 0);
	}
	if (lvl > 0.0) {
		float col = p.x + float(part) * 13.0;
		float dens = lvl * 0.22;
		float top = floor(hash(col + 3.1) * 5.0);
		float len = 2.0 + floor(hash(col + 9.7) * (2.0 + lvl * 3.0));
		float y0 = (part == 6) ? 6.0 : ((part >= 3 && part <= 4) ? 22.0 : 14.0);
		if (hash(col) < dens && p.y >= y0 + top && p.y <= y0 + top + len) {
			float dark = hash(p.y * 3.3 + col) < 0.3 ? 0.55 : 0.75;
			c.rgb = mix(c.rgb, vec3(0.55, 0.02, 0.03) * (dark + 0.35), 0.85);
		}
	}
	if (stain > 0.0) {
		// splotches of dried and wet blood across the worn item
		vec2 q = floor(p / 2.0);
		float n = hash(q.x * 7.1 + q.y * 13.7);
		float n2 = hash(q.x * 3.3 - q.y * 5.9 + 11.0);
		if (n < 0.22 * stain || (n2 < 0.12 * stain && p.y > 14.0)) {
			c.rgb = mix(c.rgb, vec3(0.42, 0.03, 0.04) * (0.7 + 0.5 * n2), 0.8);
		}
	}
	if (stump) {
		c.rgb = mix(c.rgb, vec3(0.62, 0.05, 0.06), 0.8);
	}
	c.rgb = mix(c.rgb, vec3(0.75, 0.88, 1.0), frost * 0.45);
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = vec4(c.rgb * vcol.rgb, c.a * vcol.a);
}
