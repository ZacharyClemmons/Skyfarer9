class_name TerrainChunk extends Node2D
## Draws a 16x16 block of the tile grid: ground, blended snow edges, ambient occlusion,
## exposed pipes & cables, tile structures and autotiled 3/4 walls / rock.

const SIZE := 16
## Whether SkyBackdrop is drawing the sky. With it off (--flatsky) the old tiled sky
## sprites come back, which is occasionally useful for looking at map structure.
static var SKY_BACKDROP := true
var cx := 0
var cy := 0
var map: StationMap
var tex: Texture2D
var obj_tex: Texture2D
var _background_tiles: Dictionary = {}
const INDOOR := Color(0.996, 1.0, 1.0, 1.0)
const TRIM := {"engineering": "eng", "medical": "med", "security": "sec", "science": "sci", "command": "cmd", "service": "srv", "supply": "cargo"}

func _ready() -> void:
	tex = Gfx.tex("terrain")
	obj_tex = Gfx.tex("objects")

## Terrain draws the world the ship covered, including the neighbouring cells used by
## autotiles. Reading the stamped hull here leaves a stationary coastline / wall outline
## around a ship while its separate renderer turns and moves between grid cells.
func _cache_background() -> void:
	_background_tiles.clear()
	if Game.fleet == null:
		return
	var bounds := Rect2i(Vector2i(cx * SIZE - 1, cy * SIZE - 1), Vector2i(SIZE + 2, SIZE + 2))
	for ship in Game.fleet.ships:
		if not ship.present:
			continue
		for f in ship._footprint:
			var c: Vector2i = f["cell"]
			if bounds.has_point(c):
				_background_tiles[c] = f

func _terrain_turf(c: Vector2i) -> int:
	return int(_background_tiles[c]["turf"]) if _background_tiles.has(c) else map.get_turf(c)

func _terrain_variant(c: Vector2i) -> int:
	return int(_background_tiles[c]["variant"]) if _background_tiles.has(c) else map.variant[map.idx(c)]

func _terrain_structure(c: Vector2i) -> int:
	if not map.inb(c):
		return Defs.S_NONE
	return int(_background_tiles[c]["structure"]) if _background_tiles.has(c) else map.structure[map.idx(c)]

func _terrain_area(c: Vector2i) -> int:
	return int(_background_tiles[c]["area"]) if _background_tiles.has(c) else map.area[map.idx(c)]

func _snowish(c: Vector2i) -> bool:
	var t := _terrain_turf(c)
	return t == Defs.T_SNOW or t == Defs.T_DEEPSNOW

func _wallish(c: Vector2i) -> bool:
	if not map.inb(c):
		return true
	return (int(Defs.TURFS[_terrain_turf(c)]["flags"]) & Defs.F_WALL) != 0

## Is this tile something you could stand on? Used to find island coastlines.
func _landish(c: Vector2i) -> bool:
	if not map.inb(c):
		return false
	return not Defs.is_void_turf(_terrain_turf(c))

func _rockish(c: Vector2i) -> bool:
	if not map.inb(c):
		return true
	return (int(Defs.TURFS[_terrain_turf(c)]["flags"]) & Defs.F_ROCK) != 0

func _mask(c: Vector2i, pred: Callable) -> int:
	var m := 0
	if pred.call(c + Vector2i(0, -1)): m |= 1
	if pred.call(c + Vector2i(1, 0)): m |= 2
	if pred.call(c + Vector2i(0, 1)): m |= 4
	if pred.call(c + Vector2i(-1, 0)): m |= 8
	return m

## Debug / review: draw the pipes and cables hidden under floors and walls.
static var xray := false

func _t(name: String, pos: Vector2, mod := Color.WHITE) -> void:
	var r = Gfx.manifest["terrain"].get(name)
	if r == null:
		return
	draw_texture_rect_region(tex, Rect2(pos, Vector2(32, 32)), Rect2(r[0] * 32, r[1] * 32, 32, 32), mod)

func _o(name: String, pos: Vector2, mod := Color.WHITE) -> void:
	var r = Gfx.manifest["objects"].get(name)
	if r == null:
		return
	draw_texture_rect_region(obj_tex, Rect2(pos, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]), mod)

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_impl()
	if WorldView.rperf:
		WorldView.pt("chunk_draw", t0)

# ---- cached lookups: per-turf flags / variant counts, and tile rects by integer key, so a
# chunk redraw does no string formatting or manifest lookups for the common tiles.
const G := SIZE + 2
const PF_LAND := 1
const PF_WALL := 2
const PF_ROCK := 4
const PF_SNOW := 8
static var _tf := PackedInt32Array()
static var _tvar := PackedInt32Array()
static var _rects := {}
var _pf := PackedByteArray()
var _grid := PackedInt32Array()

static func _init_tables() -> void:
	_tf.resize(Defs.TURFS.size())
	_tvar.resize(Defs.TURFS.size())
	for t in Defs.TURFS.size():
		_tf[t] = int(Defs.TURFS[t]["flags"])
		_tvar[t] = maxi(1, int(Defs.TURFS[t].get("var", 1)))

## kinds: 0 ground(turf, variant) 1 isle_edge(mask) 2 snowedge(mask) 3 ao_n 4 ao_w 5 ao_e
## 6 wall(turf, mask) 7 rock(turf, mask, variant)
static func _key(kind: int, a: int, b: int) -> int:
	return (kind << 24) | (a << 12) | b

func _tk(k: int, pos: Vector2, mod := Color.WHITE) -> void:
	var r = _rects.get(k)
	if r == null:
		r = _resolve(k)
		_rects[k] = r
	if r.size.x > 0.0:
		draw_texture_rect_region(tex, Rect2(pos, Vector2(32, 32)), r, mod)

static func _resolve(k: int) -> Rect2:
	var kind := k >> 24
	var a := (k >> 12) & 0xFFF
	var b := k & 0xFFF
	var name := ""
	match kind:
		0: name = "%s_%d" % [Defs.TURFS[a]["spr"], b]
		1: name = "isle_edge_%d" % a
		2: name = "snowedge_%d" % a
		3: name = "ao_n"
		4: name = "ao_w"
		5: name = "ao_e"
		6: name = "%s_%d" % [Defs.TURFS[a]["spr"], b]
		7:
			var m := b / 3
			name = "rock_%d_%d" % [m, b % 3] if a == Defs.T_ROCK else "%s_%d" % [Defs.TURFS[a]["spr"], m]
	var r = Gfx.manifest["terrain"].get(name)
	if r == null:
		return Rect2()
	return Rect2(r[0] * 32, r[1] * 32, 32, 32)

func _draw_impl() -> void:
	if map == null:
		return
	if _tf.is_empty():
		_init_tables()
	_cache_background()
	var has_bg := not _background_tiles.is_empty()
	var x0 := cx * SIZE
	var y0 := cy * SIZE
	var x1 := mini(x0 + SIZE, map.w)
	var y1 := mini(y0 + SIZE, map.h)
	var mw := map.w
	# the turf grid for this chunk plus a one-tile border, and its predicate bits
	if _grid.size() != G * G:
		_grid.resize(G * G)
		_pf.resize(G * G)
	for gy in G:
		var y := y0 - 1 + gy
		for gx in G:
			var x := x0 - 1 + gx
			var gi := gy * G + gx
			if x < 0 or y < 0 or x >= mw or y >= map.h:
				_grid[gi] = -1
				_pf[gi] = PF_WALL | PF_ROCK
				continue
			var c := Vector2i(x, y)
			var t: int = int(_background_tiles[c]["turf"]) if has_bg and _background_tiles.has(c) else map.turf[y * mw + x]
			_grid[gi] = t
			var f := _tf[t]
			var bits := 0
			if not (f & Defs.F_VOID):
				bits |= PF_LAND
			if f & Defs.F_WALL:
				bits |= PF_WALL
			if f & Defs.F_ROCK:
				bits |= PF_ROCK
			if t == Defs.T_SNOW or t == Defs.T_DEEPSNOW:
				bits |= PF_SNOW
			_pf[gi] = bits
	# pass 1: ground
	for y in range(y0, y1):
		for x in range(x0, x1):
			var gi := (y - y0 + 1) * G + (x - x0 + 1)
			var t := _grid[gi]
			var fl := _tf[t]
			var pos := Vector2((x - x0) * 32, (y - y0) * 32)
			# Open sky next to land: draw the island's broken underside hanging into it.
			# This is what makes an island read as floating rather than as a hole in a
			# map, so it is done before anything else on the tile.
			if fl & Defs.F_VOID:
				# Open sky is not a tile any more: SkyBackdrop draws the whole sky behind
				# the world with its own gradient, cloud decks, sun and weather, and a
				# tiled sprite over the top of that would only flatten it again. Cloud
				# banks still draw, because a bank you can fly into is a real thing.
				if t == Defs.T_CLOUD or not SKY_BACKDROP:
					_tk(_key(0, t, _variant_at(x, y) % _tvar[t]), pos)
				# the island's broken underside hanging into the air.
				var em := 0
				if _pf[gi - G] & PF_LAND: em |= 1
				if _pf[gi + 1] & PF_LAND: em |= 2
				if _pf[gi + G] & PF_LAND: em |= 4
				if _pf[gi - 1] & PF_LAND: em |= 8
				if em != 0:
					_tk(_key(1, em, 0), pos)
				continue
			var variant := _variant_at(x, y)
			if fl & (Defs.F_WALL | Defs.F_ROCK):
				# the ground beneath walls / rock (seen past 3/4 faces)
				if fl & Defs.F_WALL:
					_t("plating_0", pos)
				else:
					_t("gravel_%d" % (variant % 4), pos)
				continue
			# indoor floors are drawn a hair under pure white so the ground shader can tell
			# them from open ground and keep cloud shadows off them
			_tk(_key(0, t, variant % _tvar[t]), pos, INDOOR if fl & Defs.F_OUTDOOR == 0 else Color.WHITE)
			if fl & Defs.F_OUTDOOR and not (fl & Defs.F_LIQUID):
				_draw_lip(gi, pos)
			var c := Vector2i(x, y)
			if t == Defs.T_ICE or t == Defs.T_GRAVEL or t == Defs.T_PACKED:
				var m := 0
				if _pf[gi - G] & PF_SNOW: m |= 1
				if _pf[gi + 1] & PF_SNOW: m |= 2
				if _pf[gi + G] & PF_SNOW: m |= 4
				if _pf[gi - 1] & PF_SNOW: m |= 8
				if m != 0:
					_tk(_key(2, m, 0), pos)
			if fl & Defs.F_OUTDOOR == 0:
				if map.floor_grime.has(c):
					_o("grime_%d" % map.floor_grime[c], pos)
				# rugs: patterned fill with a fringed border
				var dec: String = map.floor_decals.get(c, "")
				if dec.begins_with("rug_"):
					_o(dec, pos)
					for s in 4:
						if map.floor_decals.get(c + Defs.DIRS4[s], "") != dec:
							_o("%s_%s" % [dec, "nesw"[s]], pos)
				# painted floor markings: tg-style hazard zones (striped border, faint hatching)
				if dec == "hazard":
					_o("hazard_hatch", pos)
					for s in 4:
						if map.floor_decals.get(c + Defs.DIRS4[s], "") != "hazard":
							_o("hazard_" + "nesw"[s], pos)
				# department trim along every wall of the room
				var trim: String = TRIM.get(map.areas[_terrain_area(c)].dept, "")
				if trim != "" and (fl & Defs.F_FLOOR):
					for s in 4:
						if _wallish(c + Defs.DIRS4[s]):
							_o("edge_%s_%s" % [trim, "nesw"[s]], pos)
				if _pf[gi - G] & (PF_WALL | PF_ROCK):
					_tk(_key(3, 0, 0), pos)
				if _pf[gi - 1] & PF_WALL:
					_tk(_key(4, 0, 0), pos)
				if _pf[gi + 1] & PF_WALL:
					_tk(_key(5, 0, 0), pos)
			elif _pf[gi - G] & PF_ROCK:
				_tk(_key(3, 0, 0), pos, Color(1, 1, 1, 0.6))
	# pass 2: exposed infrastructure (cables under pipes); most chunks have none
	var any_pipes := not map.pipe_links.is_empty()
	var pl: Array = map.pipe_layers
	if not any_pipes:
		for layer in StationMap.PIPE_LAYER_COUNT:
			var pa: PackedByteArray = pl[layer]
			for y in range(y0, y1):
				var rb := y * mw
				for x in range(x0, x1):
					if pa[rb + x] != 0:
						any_pipes = true
						break
				if any_pipes:
					break
			if any_pipes:
				break
	if not any_pipes:
		for y in range(y0, y1):
			var rb := y * mw
			for x in range(x0, x1):
				if map.cable[rb + x] > 0:
					any_pipes = true
					break
			if any_pipes:
				break
	if any_pipes:
		_draw_pass2(x0, y0, x1, y1)
	# pass 3: structures and walls / rock
	var any_struct := has_bg
	if not any_struct:
		for y in range(y0, y1):
			var rb := y * mw
			for x in range(x0, x1):
				if map.structure[rb + x] != Defs.S_NONE:
					any_struct = true
					break
			if any_struct:
				break
	for y in range(y0, y1):
		for x in range(x0, x1):
			var gi := (y - y0 + 1) * G + (x - x0 + 1)
			var t := _grid[gi]
			var fl := _tf[t]
			var pos := Vector2((x - x0) * 32, (y - y0) * 32)
			if any_struct:
				var c := Vector2i(x, y)
				var i := y * mw + x
				var s := _terrain_structure(c)
				if Defs.is_window(s):
					# the pane sits on its grille; panes join up with their neighbours
					var m := _mask(c, func(q): return map.inb(q) and Defs.is_window(_terrain_structure(q)))
					if s == Defs.S_WINDOW:
						_o("grille", pos)
					_t(("rwindow_%d" if s == Defs.S_RWINDOW else "window_%d") % m, pos)
					# tg window update_overlays: crack overlays at 75/50/25% integrity
					var hp: float = Structures.max_hp(s) if _background_tiles.has(c) else map.struct_hp[i]
					var cracks := Structures.crack_stage(hp, Structures.max_hp(s))
					if cracks > 0:
						_t("window_damage%d" % cracks, pos)
				elif s == Defs.S_GRILLE:
					# tg grille update_icon: "grille50" once it's at half integrity or less
					var hp: float = Structures.max_hp(s) if _background_tiles.has(c) else map.struct_hp[i]
					_o("grille_damaged" if hp <= Structures.max_hp(s) * 0.5 else "grille", pos)
				elif s == Defs.S_GRILLE_BROKEN:
					_o("grille_broken", pos)
				elif s == Defs.S_GIRDER:
					_o("girder", pos)
			if fl & Defs.F_WALL:
				var m := 0
				if _pf[gi - G] & PF_WALL: m |= 1
				if _pf[gi + 1] & PF_WALL: m |= 2
				if _pf[gi + G] & PF_WALL: m |= 4
				if _pf[gi - 1] & PF_WALL: m |= 8
				_tk(_key(6, t, m), pos)
			elif fl & Defs.F_ROCK:
				var m := 0
				if _pf[gi - G] & PF_ROCK: m |= 1
				if _pf[gi + 1] & PF_ROCK: m |= 2
				if _pf[gi + G] & PF_ROCK: m |= 4
				if _pf[gi - 1] & PF_ROCK: m |= 8
				_tk(_key(7, t, m * 3 + (_variant_at(x, y) % 3)), pos)

## The coping where ground meets open sky: a lit lip on the edges facing the light, a
## shaded front where the ground drops away, and a dark seam under both. It is what stops
## the quay reading as a texture pasted over a hole.
func _draw_lip(gi: int, pos: Vector2) -> void:
	var nv := not (_pf[gi - G] & PF_LAND)
	var sv := not (_pf[gi + G] & PF_LAND)
	var wv := not (_pf[gi - 1] & PF_LAND)
	var ev := not (_pf[gi + 1] & PF_LAND)
	if not (nv or sv or wv or ev):
		return
	var lit := Color(1.0, 0.96, 0.85, 0.26)
	var dk := Color(0.05, 0.04, 0.08, 0.34)
	if nv:
		draw_rect(Rect2(pos.x, pos.y, 32, 2), lit)
		draw_rect(Rect2(pos.x, pos.y + 2, 32, 1), dk)
	if sv:
		draw_rect(Rect2(pos.x, pos.y + 27, 32, 3), Color(0.05, 0.04, 0.08, 0.16))
		draw_rect(Rect2(pos.x, pos.y + 30, 32, 1), lit)
		draw_rect(Rect2(pos.x, pos.y + 31, 32, 1), dk)
	if wv:
		draw_rect(Rect2(pos.x, pos.y, 2, 32), lit)
		draw_rect(Rect2(pos.x + 2, pos.y, 1, 32), dk)
	if ev:
		draw_rect(Rect2(pos.x + 29, pos.y, 3, 32), Color(0.05, 0.04, 0.08, 0.14))
		draw_rect(Rect2(pos.x + 31, pos.y, 1, 32), dk)

func _variant_at(x: int, y: int) -> int:
	if not _background_tiles.is_empty():
		var c := Vector2i(x, y)
		if _background_tiles.has(c):
			return int(_background_tiles[c]["variant"])
	return map.variant[y * map.w + x]

func _draw_pass2(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := Vector2i(x, y)
			var i := map.idx(c)
			var fl: int = Defs.TURFS[_terrain_turf(c)]["flags"]
			if fl & Defs.F_SOLID and not (fl & Defs.F_WALL):
				continue
			var covered := ((fl & Defs.F_FLOOR) != 0 or (fl & Defs.F_WALL) != 0) and not xray
			var pos := Vector2((x - x0) * 32, (y - y0) * 32)
			if map.cable[i] > 0 and not covered:
				var m := 0
				for d in 4:
					if map.cable[map.idx(c + Defs.DIRS4[d])] > 0 if map.inb(c + Defs.DIRS4[d]) else false:
						m |= 1 << d
				_o("cable_%d" % m, pos, Color(1, 1, 1, 1) if map.cable[i] == 1 else Color(0.5, 0.45, 0.4, 1))
				if map.cable[i] == 2:
					_o("pipe_leak", pos, Color(1, 0.8, 0.3))
			for layer in StationMap.PIPE_LAYER_COUNT:
				var pm := map.pipe_mask(layer, c)
				if pm == 0:
					continue
				var key := map.pipe_key(layer, c)
				var leaking := map.pipe_leaking(layer, c)
				# tg "visible" pipes sit on top of the floor; hidden ones only show when exposed
				var shown: bool = map.pipe_shown.has(key)
				if covered and not leaking and not shown:
					continue
				var alpha := 1.0 if not covered or shown else 0.85
				var col = map.pipe_color.get(key)
				for g in map.pipe_groups_at(layer, c):
					if col != null:
						var cc: Color = col
						_o("pipe_t%d_%d" % [StationMap.PIPE_TG_LAYER[layer], g], pos, Color(cc.r, cc.g, cc.b, alpha))
					else:
						_o("pipe_%s_%d" % [StationMap.PIPE_LAYER_NAMES[layer], g], pos, Color(1, 1, 1, alpha))
				if map.pipe_hp_at(layer, c) < 100:
					_o("pipe_leak", pos)
			if map.pipe_links.has(i):
				_o("pipe_link", pos)
