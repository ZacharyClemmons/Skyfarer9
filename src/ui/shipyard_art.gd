extends RefCounted
## Sprite lookups and the small custom widgets the drawing board is built from.
## The board draws real ship parts (the same terrain and object sprites the flying hull
## uses), so what you draw is recognisably what you get.

const WALLISH := ["#", "K", "I"]

## glyph -> object sprite that sits on the deck for that glyph.
const OBJ := {
	"h": "ship_wheel", "n": "nav_table", "E": "thruster_w", "L": "lift_cell_0", "m": "ship_mast",
	"p": "propeller_e", "B": "boiler", "G": "dynamo", "S": "apc", "T": "fuel_bunker",
	"O": "ballast_tank", "g": "gun_e", "C": "cargo_winch", "v": "vent", "s": "scrubber",
	"*": "deck_lantern", "b": "bed_0", "k": "crate_gen", "c": "chair_shuttle_e",
	"t": "table_steel", "d": "table_wood", "f": "galley_stove", "M": "med_bed",
	"l": "locker_gen", "o": "locker_emerg", "+": "airlock_generic_0", "A": "airlock_ext_0", "J": "airlock_cargo_0",
	"r": "rudder_post",
}
const UTIL_OBJ := {
	"util_winch": "cargo_winch", "util_bench": "table_wood", "util_still": "chem_heater",
	"util_forge": "autolathe", "util_galley": "galley_stove", "util_medbay": "med_bed",
	"util_hold": "crate_gen", "util_scrubber": "scrubber", "util_bunk": "bed_0",
	"util_lantern": "deck_lantern", "util_beacon": "antenna",
}

static func has_obj(n: String) -> bool:
	return Gfx.has("objects", n)

static func variant_of(key: Vector2i) -> int:
	return absi(key.x * 7 + key.y * 13) & 3

static func glyph_name(g: String) -> String:
	for br in Shipyard.BRUSHES:
		if String(br["g"]) == g:
			return String(br["name"])
	return "hull"

static func obj_for(glyph: String, module: String) -> String:
	if glyph == "C" and module != "" and UTIL_OBJ.has(module):
		var u: String = UTIL_OBJ[module]
		if has_obj(u):
			return u
	var o: String = OBJ.get(glyph, "")
	return o if o != "" and has_obj(o) else ""

static func _terr(cv: CanvasItem, name: String, r: Rect2, col: Color) -> bool:
	if not Gfx.has("terrain", name):
		return false
	cv.draw_texture_rect_region(Gfx.tex("terrain"), r, Gfx.region("terrain", name), col)
	return true

static func draw_obj(cv: CanvasItem, name: String, r: Rect2, col: Color) -> bool:
	if not Gfx.has("objects", name):
		return false
	var reg := Gfx.region("objects", name)
	if reg.size.y > 32.0:
		reg = Rect2(reg.position.x, reg.position.y + reg.size.y - 32.0, reg.size.x, 32.0)
	if reg.size.x > 32.0:
		reg = Rect2(reg.position.x, reg.position.y, 32.0, reg.size.y)
	cv.draw_texture_rect_region(Gfx.tex("objects"), r, reg, col)
	return true

static func _mask(cells: Dictionary, key: Vector2i, glyphs: Array) -> int:
	var m := 0
	for d in 4:
		var n: Vector2i = key + Defs.DIRS4[d]
		if cells.has(n) and String(cells[n]) in glyphs:
			m |= 1 << d
	return m

## One tile of ship, as sprites. `col` is a modulate (used for ghosts and fades).
static func draw_cell(cv: CanvasItem, r: Rect2, key: Vector2i, glyph: String, module: String,
		cells: Dictionary, sealed: bool, col := Color.WHITE) -> void:
	var v := variant_of(key)
	var ok := true
	match glyph:
		"#":
			_terr(cv, "plating_0", r, col)
			ok = _terr(cv, "hullwood_%d" % _mask(cells, key, WALLISH), r, col)
		"K":
			_terr(cv, "plating_0", r, col)
			ok = _terr(cv, "keel_%d" % _mask(cells, key, WALLISH), r, col)
		"I":
			_terr(cv, "plating_0", r, col)
			ok = _terr(cv, "bulkhead_%d" % _mask(cells, key, WALLISH), r, col)
		"W", "w":
			_terr(cv, "deckplate_%d" % v, r, col)
			ok = _terr(cv, "window_%d" % _mask(cells, key, ["W", "w"]), r, col)
		",", ".":
			ok = _terr(cv, "deckopen_%d" % v, r, col)
		"=":
			ok = _terr(cv, "deck_%d" % v, r, col)
		_:
			var floor_n := "deck_%d" % v if (sealed or glyph in ShipPlan.INDOOR_FITTINGS) else "deckopen_%d" % v
			_terr(cv, floor_n, r, col)
			var o := obj_for(glyph, module)
			if o != "":
				draw_obj(cv, o, r, col)
			else:
				ok = false
	if glyph == "+" or glyph == "A" or glyph == "J":
		_terr(cv, "deck_%d" % v, r, col)
		var d := obj_for(glyph, module)
		if d != "":
			draw_obj(cv, d, r, col)
	if not ok:
		var c := Shipyard._glyph_color(glyph)
		cv.draw_rect(r.grow(-1), Color(c, col.a))
		cv.draw_string(UITheme.font, r.position + Vector2(r.size.x * 0.32, r.size.y * 0.66), glyph if glyph != "," else ".",
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.5), Color(0, 0, 0, 0.6 * col.a))

