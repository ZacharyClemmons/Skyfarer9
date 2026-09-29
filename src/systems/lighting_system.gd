class_name LightingSystem extends Node
## CPU tile lightmap (SS13-style per-tile lighting, smoothed by bilinear filtering).
## Static lights cache their visible tiles; contributions are added/subtracted
## incrementally. Outdoor tiles and window spill get ambient (sky) light that follows the
## asteroid's day cycle. The player's field of view (shadowcast) masks everything unseen.

## Artic9 was a station of short corridors; the Cloudsea is an open horizon, so sight
## reaches as far as the lightmap region allows. Darkness at night comes from the ambient
## ramp rather than from not being able to see.
const FOV_RADIUS := 33
## Sky exposure above which a tile counts as "out in the open" and is lit by daylight
## regardless of what is between it and the player.
const OPEN_SKY_AMB := 0.5
const REGION_W := 72
const REGION_H := 44
const MAX_LIT_SHIPS := 8
const WINDOW_SPILL := 4.5
const WINDOW_MARGIN := 5 # ceil(WINDOW_SPILL): every affected ray ends within this

var map: StationMap
var lights := {} # CLight -> {cells, falloff, origin, color}
var dirty_lights := {}
var acc_r := PackedFloat32Array()
var acc_g := PackedFloat32Array()
var acc_b := PackedFloat32Array()
var amb := PackedFloat32Array() # 0..1 sky exposure per tile
var visible := PackedByteArray()
var fov_origin := Vector2i(-999, -999)
var fov_dirty := true
var fire_cache := {} # Vector2i -> {cells, falloff}
var flashes: Array = [] # {cell, color, radius, t, dur, cells, falloff}
var ambient := Color(0.3, 0.35, 0.5)
## Cells that are always lit regardless of turf or lamps: the inside of a port's premises.
##
## A shop is an indoor room, and an indoor room in this engine is pitch black until a
## light is registered in it. That is right for a station corridor and wrong for a shop:
## a black rectangle with a door reads as "you cannot go in there", which is the opposite
## of what a port is for. Hub.build registers its floors here and they are simply lit.
var lit_rooms := {}
var aurora := 0.0
var image: Image
var texture: ImageTexture
var region_origin := Vector2i.ZERO
var compose_t := 0.0
var sprite: Sprite2D
var full_bright := false
var _buf := PackedByteArray()
var _ship_source_image: Image
var _ship_source_texture: ImageTexture
var _ship_source_buf := PackedByteArray()
var _ship_mask_image: Image
var _ship_mask_texture: ImageTexture
var _ship_mask_buf := PackedByteArray()
var _ship_material: ShaderMaterial
var _lit_ships: Array = []
var _ship_source_pivots := PackedVector2Array()
var _ship_source_angles := PackedFloat32Array()
var _ship_pivots := PackedVector4Array()
var _ship_rotations := PackedVector2Array()
var _ship_backgrounds := {} # map index -> turf covered by the drawn ship
var _fr := PackedFloat32Array()
var _fov_turf := PackedByteArray()
var _fov_cnt := PackedByteArray()
var _fov_opq := PackedByteArray()
var _fw := 0
var _fh := 0
var _vis := PackedByteArray() # per texel: 0 outside map, 1 seen/lit, 2 unseen (dim shade)
var _opq_turf := PackedByteArray()
var _gl := PackedFloat32Array()
## Graphics quality for the optional lighting effects: 0 low (off), 1 medium (ambient
## occlusion, dim unseen space), 2 high (adds warm light bloom). Set with --gfx=low|medium|high.
static var quality := 1
var _glow_sprite: Sprite2D
var _glow_image: Image
var _glow_texture: ImageTexture
var _glow_ship_material: ShaderMaterial
var _turf_flags := PackedInt32Array()

func _init() -> void:
	# Ship movement, visual positions and the camera must settle before composition.
	process_priority = 20

func setup(m: StationMap, lightmap_sprite: Sprite2D) -> void:
	map = m
	var n := m.w * m.h
	for arr in [acc_r, acc_g, acc_b, amb]:
		arr.resize(n)
		arr.fill(0.0)
	visible.resize(n)
	sprite = lightmap_sprite
	image = Image.create(REGION_W, REGION_H, false, Image.FORMAT_RGBH)
	texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(Defs.TILE, Defs.TILE)
	_buf.resize(REGION_W * REGION_H * 6)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gfx="):
			quality = {"low": 0, "medium": 1, "high": 2}.get(a.substr(6), 1)
	compose_t = 0.0
	if Game.fleet != null:
		_setup_ship_lightmap()
	if quality >= 2:
		_setup_glow()
	rebuild_ambient()
	Bus.opacity_changed.connect(_on_opacity_changed)
	Bus.tile_changed.connect(_on_tile_changed)

## High quality only: lamps bloom. An additive copy of the lightmap carrying just the
## bright part of the lamp light (no daylight), drawn over the multiplied scene.
func _setup_glow() -> void:
	_glow_image = Image.create(REGION_W, REGION_H, false, Image.FORMAT_RGBH)
	_glow_texture = ImageTexture.create_from_image(_glow_image)
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _glow_texture
	_glow_sprite.centered = false
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _ship_material != null:
		_glow_ship_material = ShaderMaterial.new()
		_glow_ship_material.shader = load("res://src/render/ship_glow.gdshader")
		_glow_ship_material.set_shader_parameter("ship_source", _glow_texture)
		_glow_ship_material.set_shader_parameter("ship_mask", _ship_mask_texture)
		_glow_sprite.material = _glow_ship_material
	else:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow_sprite.material = m
	sprite.add_child(_glow_sprite)

## The background keeps its world lightmap; a turning deck samples the same lighting in
## its own frame. Keeping these separate prevents the stamped cabin's dark rectangle
## from showing through the sky beside the continuously rotating hull.
func _setup_ship_lightmap() -> void:
	_lit_ships.clear()
	_ship_backgrounds.clear()
	_ship_source_buf.resize(_buf.size())
	_ship_source_image = Image.create(REGION_W, REGION_H, false, Image.FORMAT_RGBH)
	_ship_source_texture = ImageTexture.create_from_image(_ship_source_image)
	_ship_mask_buf.resize(REGION_W * REGION_H)
	_ship_mask_image = Image.create(REGION_W, REGION_H, false, Image.FORMAT_R8)
	_ship_mask_texture = ImageTexture.create_from_image(_ship_mask_image)
	_ship_source_pivots.resize(MAX_LIT_SHIPS)
	_ship_source_angles.resize(MAX_LIT_SHIPS)
	_ship_pivots.resize(MAX_LIT_SHIPS)
	_ship_rotations.resize(MAX_LIT_SHIPS)
	_ship_material = ShaderMaterial.new()
	_ship_material.shader = load("res://src/render/ship_lightmap.gdshader")
	_ship_material.set_shader_parameter("ship_source", _ship_source_texture)
	_ship_material.set_shader_parameter("ship_mask", _ship_mask_texture)
	sprite.material = _ship_material

## The source pose is captured with the texture. It stays fixed until the next compose,
## even if the simulation restamps into a new quarter in the intervening frames.
func _prepare_ship_lightmap() -> void:
	_lit_ships.clear()
	_ship_backgrounds.clear()
	_ship_mask_buf.fill(0)
	var center := Vector2(region_origin) + Vector2(REGION_W, REGION_H) * 0.5
	var region := Rect2(Vector2(region_origin), Vector2(REGION_W, REGION_H))
	for sh: Airship in Game.fleet.ships:
		if not sh.present or not is_instance_valid(sh.renderer):
			continue
		var radius := Vector2(sh.shape_bounds().size).length() * 0.5 + 2.0
		if region.grow(radius).has_point(sh.visual_pivot() / float(Defs.TILE)):
			_lit_ships.append(sh)
	_lit_ships.sort_custom(func(a: Airship, b: Airship):
		return center.distance_squared_to(a.visual_pivot() / float(Defs.TILE)) < center.distance_squared_to(b.visual_pivot() / float(Defs.TILE)))
	if _lit_ships.size() > MAX_LIT_SHIPS:
		_lit_ships.resize(MAX_LIT_SHIPS)
	for slot in _lit_ships.size():
		var sh: Airship = _lit_ships[slot]
		_ship_source_pivots[slot] = Vector2(sh.origin) + sh.pivot_offset(sh.facing)
		_ship_source_angles[slot] = Airship._angle_of(sh.facing)
		for c: Vector2i in sh.cells:
			var rel := c - region_origin
			if rel.x >= 0 and rel.y >= 0 and rel.x < REGION_W and rel.y < REGION_H:
				_ship_mask_buf[rel.y * REGION_W + rel.x] = slot + 1
		for footprint: Dictionary in sh._footprint:
			var c: Vector2i = footprint["cell"]
			if map.inb(c):
				_ship_backgrounds[map.idx(c)] = footprint["turf"]
	_ship_mask_image.set_data(REGION_W, REGION_H, false, Image.FORMAT_R8, _ship_mask_buf)
	_ship_mask_texture.update(_ship_mask_image)
	_ship_material.set_shader_parameter("region_origin", Vector2(region_origin))
	if _glow_ship_material != null:
		_glow_ship_material.set_shader_parameter("region_origin", Vector2(region_origin))
	_sync_ship_transforms()

func _sync_ship_transforms() -> void:
	for slot in _lit_ships.size():
		var sh: Airship = _lit_ships[slot]
		var source := _ship_source_pivots[slot]
		var drawn := sh.visual_pivot() / float(Defs.TILE) if sh.present else Vector2(-100000.0, -100000.0)
		_ship_pivots[slot] = Vector4(source.x, source.y, drawn.x, drawn.y)
		var offset := sh.angle - _ship_source_angles[slot]
		_ship_rotations[slot] = Vector2(cos(offset), sin(offset))
	_ship_material.set_shader_parameter("ship_count", _lit_ships.size())
	_ship_material.set_shader_parameter("ship_pivots", _ship_pivots)
	_ship_material.set_shader_parameter("ship_rotations", _ship_rotations)
	if _glow_ship_material != null:
		_glow_ship_material.set_shader_parameter("ship_count", _lit_ships.size())
		_glow_ship_material.set_shader_parameter("ship_pivots", _ship_pivots)
		_glow_ship_material.set_shader_parameter("ship_rotations", _ship_rotations)

var _amb_dirty := false
var _amb_full_dirty := false
var _amb_dirty_rect := Rect2i()

func _on_tile_changed(c: Vector2i) -> void:
	mark_ambient_dirty([c])

func register(l: CLight) -> void:
	dirty_lights[l] = true

func unregister(l: CLight) -> void:
	_remove_contrib(l)
	lights.erase(l)
	dirty_lights.erase(l)

func mark_dirty(l: CLight) -> void:
	dirty_lights[l] = true

func fire_changed() -> void:
	# fire lights are recomputed lazily in compose
	pass

func flash(cell: Vector2i, color: Color, radius: float, dur: float) -> void:
	var cache := _cast(cell, radius)
	flashes.append({"cell": cell, "color": color, "t": 0.0, "dur": dur, "cells": cache[0], "falloff": cache[1]})

## How lit a tile is, roughly tg's lumcount (0 dark .. 1 bright; tg LIGHTING_TILE_IS_DARK
## is 0.2): the strongest colour channel of the lights on it, plus daylight.
func light_at(c: Vector2i) -> float:
	if full_bright:
		return 1.0
	if map == null or not map.inb(c):
		return 0.0
	var i := map.idx(c)
	var l := 0.0
	if i < acc_r.size():
		l = maxf(acc_r[i], maxf(acc_g[i], acc_b[i]))
	if i < amb.size():
		l += amb[i] * ambient.v
	return clampf(l, 0.0, 2.0)

func player_can_see(c: Vector2i) -> bool:
	if not map.inb(c):
		return false
	return visible[map.idx(c)] == 1

func _on_opacity_changed(c: Vector2i) -> void:
	# Doors and opaque entities affect window spill just as terrain does.
	mark_ambient_dirty([c])

func _invalidate_opacity_region(changed: Rect2i) -> void:
	fov_dirty = true
	for l in lights.keys():
		var info: Dictionary = lights[l]
		var o: Vector2i = info["origin"]
		var margin := ceili(l.radius) + 1
		var influence := Rect2i(o - Vector2i(margin, margin), Vector2i.ONE * (margin * 2 + 1))
		if influence.intersects(changed):
			dirty_lights[l] = true
	for fc in fire_cache.keys():
		if Rect2i(fc - Vector2i(5, 5), Vector2i(11, 11)).intersects(changed):
			fire_cache.erase(fc)

# ------------------------------------------------------------------ light casting
func _cast(origin: Vector2i, radius: float) -> Array:
	var cells := PackedInt32Array()
	var fall := PackedFloat32Array()
	var r := int(ceil(radius))
	for y in range(origin.y - r, origin.y + r + 1):
		for x in range(origin.x - r, origin.x + r + 1):
			var c := Vector2i(x, y)
			if not map.inb(c):
				continue
			var d := Vector2(c - origin).length()
			if d > radius:
				continue
			if not _los(origin, c):
				continue
			var f := 1.0 - d / (radius + 0.5)
			f = f * f * (3.0 - 2.0 * f) # smoothstep falloff
			cells.append(map.idx(c))
			fall.append(f)
	return [cells, fall]

func _los(a: Vector2i, b: Vector2i) -> bool:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		if x0 == b.x and y0 == b.y:
			return true
		if (x0 != a.x or y0 != a.y) and map.is_opaque(Vector2i(x0, y0)):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true

func _remove_contrib(l: CLight) -> void:
	if not lights.has(l):
		return
	var info: Dictionary = lights[l]
	if not info["on"]:
		return
	var col: Color = info["color"]
	var cells: PackedInt32Array = info["cells"]
	var fall: PackedFloat32Array = info["falloff"]
	for k in cells.size():
		var i := cells[k]
		acc_r[i] -= col.r * fall[k]
		acc_g[i] -= col.g * fall[k]
		acc_b[i] -= col.b * fall[k]
	info["on"] = false
	_light_ver += 1

func _add_contrib(l: CLight) -> void:
	var origin := l.origin()
	var cache := _cast(origin, l.radius)
	var col := l.color * l.energy
	var info := {"cells": cache[0], "falloff": cache[1], "origin": origin, "color": col, "on": true}
	lights[l] = info
	_light_ver += 1
	var cells: PackedInt32Array = info["cells"]
	var fall: PackedFloat32Array = info["falloff"]
	for k in cells.size():
		var i := cells[k]
		acc_r[i] += col.r * fall[k]
		acc_g[i] += col.g * fall[k]
		acc_b[i] += col.b * fall[k]

func _update_lights() -> void:
	var t0 := Time.get_ticks_usec()
	_update_lights_impl()
	if WorldView.rperf:
		WorldView.pt("light_update", t0)

func _update_lights_impl() -> void:
	# held/carried lights follow their holder
	for l in lights.keys():
		if l.kind == "item" and lights[l]["on"] and l.origin() != lights[l]["origin"]:
			dirty_lights[l] = true
	var budget := 60
	for l in dirty_lights.keys():
		if budget <= 0:
			break
		budget -= 1
		dirty_lights.erase(l)
		if not is_instance_valid(l.e) or l.e.removed:
			_remove_contrib(l)
			lights.erase(l)
			continue
		_remove_contrib(l)
		l.lit = l.compute_lit()
		if l.lit:
			_add_contrib(l)
		else:
			lights[l] = {"cells": PackedInt32Array(), "falloff": PackedFloat32Array(), "origin": l.origin(), "color": Color.BLACK, "on": false}

# ------------------------------------------------------------------ ambient
## Only rays within the window spill radius of changed terrain can alter sky exposure.
## Callers without cell information still request the complete map.
func mark_ambient_dirty(changed_cells: Array = []) -> void:
	_amb_dirty = true
	if changed_cells.is_empty():
		_amb_full_dirty = true
		fov_dirty = true
		for l in lights:
			dirty_lights[l] = true
		fire_cache.clear()
		return
	var changed := Rect2i(changed_cells[0], Vector2i.ONE)
	for c: Vector2i in changed_cells:
		changed = changed.merge(Rect2i(c, Vector2i.ONE))
	var affected := changed.grow(WINDOW_MARGIN)
	_amb_dirty_rect = affected if _amb_dirty_rect.size == Vector2i.ZERO else _amb_dirty_rect.merge(affected)
	_invalidate_opacity_region(changed)

func rebuild_ambient() -> void:
	_rebuild_ambient_region(Rect2i(Vector2i.ZERO, Vector2i(map.w, map.h)))

func _refresh_ambient() -> void:
	if _amb_full_dirty or _amb_dirty_rect.size == Vector2i.ZERO:
		rebuild_ambient()
	else:
		_rebuild_ambient_region(_amb_dirty_rect)

func _rebuild_ambient_region(requested: Rect2i) -> void:
	var t0 := Time.get_ticks_usec()
	_rebuild_ambient_region_impl(requested)
	if WorldView.rperf:
		WorldView.pt("light_ambient", t0)

func _rebuild_ambient_region_impl(requested: Rect2i) -> void:
	var map_bounds := Rect2i(Vector2i.ZERO, Vector2i(map.w, map.h))
	var region := requested.intersection(map_bounds)
	var flags := PackedInt32Array()
	for info: Dictionary in Defs.TURFS:
		flags.append(info["flags"])
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var i := y * map.w + x
			var fl: int = flags[map.turf[i]]
			amb[i] = 1.0 if fl & Defs.F_OUTDOOR else (0.92 if fl & Defs.F_ROCK else 0.0)
			if amb[i] < 0.78 and lit_rooms.has(i):
				amb[i] = 0.78
	# Nearby windows outside the refreshed region may also cast into it. Recast their
	# contributions only into the reset cells; untouched exposure stays exactly intact.
	var sources := region.grow(WINDOW_MARGIN).intersection(map_bounds)
	for y in range(sources.position.y, sources.end.y):
		for x in range(sources.position.x, sources.end.x):
			var i := y * map.w + x
			var s: int = map.structure[i]
			if not Defs.is_window(s) and not Defs.is_grille(s):
				continue
			var c := Vector2i(x, y)
			if region.has_point(c):
				amb[i] = maxf(amb[i], 0.8)
			var cache := _cast(c, WINDOW_SPILL)
			var cells: PackedInt32Array = cache[0]
			var fall: PackedFloat32Array = cache[1]
			for k in cells.size():
				var j := cells[k]
				if region.has_point(Vector2i(j % map.w, j / map.w)) and (flags[map.turf[j]] & Defs.F_OUTDOOR) == 0:
					amb[j] = maxf(amb[j], fall[k] * 0.55)
	_amb_dirty = false
	_amb_full_dirty = false
	_amb_dirty_rect = Rect2i()
	_amb_ver += 1

# ------------------------------------------------------------------ FOV (recursive shadowcasting)
func compute_fov(origin: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	_compute_fov(origin)
	if WorldView.rperf:
		WorldView.pt("light_fov", t0)

func _compute_fov(origin: Vector2i) -> void:
	visible.fill(0)
	_fov_ver += 1
	_fov_turf = map.turf
	_fov_cnt = map.opaque_count
	_fw = map.w
	_fh = map.h
	if _fov_opq.size() != Defs.TURFS.size():
		_fov_opq.resize(Defs.TURFS.size())
		for t in Defs.TURFS.size():
			_fov_opq[t] = 1 if (int(Defs.TURFS[t]["flags"]) & Defs.F_OPAQUE) != 0 else 0
	fov_origin = origin
	if not map.inb(origin):
		return
	visible[map.idx(origin)] = 1
	for oct in 8:
		_cast_octant(origin, 1, 1.0, 0.0, oct)
	if Game.player and Traits.has(Game.player, "xray_vision"):
		for y in range(maxi(0, origin.y - FOV_RADIUS), mini(map.h, origin.y + FOV_RADIUS + 1)):
			for x in range(maxi(0, origin.x - FOV_RADIUS), mini(map.w, origin.x + FOV_RADIUS + 1)):
				if origin.distance_to(Vector2i(x, y)) <= FOV_RADIUS:
					visible[map.idx(Vector2i(x, y))] = 1
	fov_dirty = false

const _MULT := [[1, 0, 0, -1, -1, 0, 0, 1], [0, 1, -1, 0, 0, -1, 1, 0], [0, 1, 1, 0, 0, -1, -1, 0], [1, 0, 0, 1, -1, 0, 0, -1]]

func _cast_octant(o: Vector2i, row: int, start: float, end: float, oct: int) -> void:
	if start < end:
		return
	var xx: int = _MULT[0][oct]
	var xy: int = _MULT[1][oct]
	var yx: int = _MULT[2][oct]
	var yy: int = _MULT[3][oct]
	var new_start := 0.0
	for j in range(row, FOV_RADIUS + 1):
		var dx := -j - 1
		var dy := -j
		var blocked := false
		while dx <= 0:
			dx += 1
			var X := o.x + dx * xx + dy * xy
			var Y := o.y + dx * yx + dy * yy
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			elif end > l_slope:
				break
			# (map.inb / is_opaque inlined: this is the hottest loop in the lighting)
			var in_map := X >= 0 and Y >= 0 and X < _fw and Y < _fh
			var mi := Y * _fw + X
			if in_map and dx * dx + dy * dy <= FOV_RADIUS * FOV_RADIUS:
				visible[mi] = 1
			var opaque := true if not in_map else (_fov_opq[_fov_turf[mi]] == 1 or _fov_cnt[mi] > 0)
			if blocked:
				if opaque:
					new_start = r_slope
					continue
				else:
					blocked = false
					start = new_start
			else:
				if opaque and j < FOV_RADIUS:
					blocked = true
					_cast_octant(o, j + 1, start, l_slope, oct)
					new_start = r_slope
		if blocked:
			break

# ------------------------------------------------------------------ compose
func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("light", _pt)

func _process_body(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_proc(delta)
	if WorldView.rperf:
		WorldView.pt("light_proc_all", t0)

func _proc(delta: float) -> void:
	if map == null:
		return
	if _amb_dirty:
		_refresh_ambient()
	_update_lights()
	for f in flashes.duplicate():
		f["t"] += delta
		if f["t"] >= f["dur"]:
			flashes.erase(f)
	var p := Game.player
	if p != null:
		var pc := p.root_cell()
		if pc != fov_origin or fov_dirty:
			compute_fov(pc)
	compose_t -= delta
	if compose_t <= 0.0:
		compose_t = 0.066
		if _can_skip_compose():
			if _ship_material != null:
				_sync_ship_transforms()
		else:
			compose()
	elif _ship_material != null:
		_sync_ship_transforms()

## Recomposing is the lightmap's whole cost, so it is skipped while nothing that goes into
## it has changed: same view region, same field of view, same lights and ambient, no fire,
## flash or aurora flicker, and the hulls that are lit have not been restamped. A forced
## refresh every half second catches anything this does not know about.
var _light_ver := 0
var _amb_ver := 0
var _fov_ver := 0
var _sig: Array = []
var _sig_ms := 0

func _signature() -> Array:
	var cam = Game.view.camera if Game.view else null
	var center := Vector2i(map.w / 2, map.h / 2)
	if cam:
		center = Vector2i(cam.get_screen_center_position() / Defs.TILE)
	var sig := [center, fov_origin, _fov_ver, _light_ver, _amb_ver, ambient.to_rgba32(), full_bright, Game.player != null,
		lit_rooms.size(), Game.sky.sun_elevation() > -0.25 if Game.sky != null else true]
	if Game.player != null:
		sig.append(Traits.has(Game.player, "night_vision") or Traits.has(Game.player, "xray_vision"))
	if Game.fleet != null:
		for sh: Airship in Game.fleet.ships:
			if sh.present:
				var d := Vector2(center) - sh.visual_pivot() / float(Defs.TILE)
				if absf(d.x) < 70.0 and absf(d.y) < 50.0:
					sig.append(sh.origin)
					sig.append(sh.facing)
	return sig

func _can_skip_compose() -> bool:
	if _sig.is_empty() or not flashes.is_empty() or aurora > 0.0 or Time.get_ticks_msec() - _sig_ms > 500:
		return false
	if Game.atmos != null and (not Game.atmos.hotspots.is_empty() or not fire_cache.is_empty()):
		return false
	return _signature() == _sig

func _note_compose() -> void:
	_sig = _signature()
	_sig_ms = Time.get_ticks_msec()

func compose() -> void:
	var t0 := Time.get_ticks_usec()
	_compose()
	if WorldView.rperf:
		WorldView.pt("light_compose", t0)

func _compose() -> void:
	var cam = Game.view.camera if Game.view else null
	var center := Vector2i(map.w / 2, map.h / 2)
	if cam:
		center = Vector2i(cam.get_screen_center_position() / Defs.TILE)
	region_origin = center - Vector2i(REGION_W / 2, REGION_H / 2)
	if _ship_material != null:
		_prepare_ship_lightmap()
	var n := REGION_W * REGION_H
	var fr := _fr
	if fr.size() != n * 3:
		fr.resize(n * 3)
	fr.fill(0.0)
	var amb_c := ambient
	if aurora > 0:
		var t := Game.time * 0.3
		amb_c = amb_c.lerp(Color(0.25, 0.9, 0.6).lerp(Color(0.6, 0.35, 0.9), 0.5 + 0.5 * sin(t)), aurora * 0.35)
	var flicker := 0.85 + 0.15 * sin(Game.time * 23.0) * sin(Game.time * 7.3)
	var have_player := Game.player != null
	# how much of the sky's own light is on the ground right now
	var open_sight: bool = Game.sky == null or Game.sky.sun_elevation() > -0.25
	var dark_sight := have_player and (Traits.has(Game.player, "night_vision") or Traits.has(Game.player, "xray_vision"))
	# vis[k]: is this texel lit at all. Line of sight hides what is behind a wall, which is
	# right indoors and wrong under an open sky: outdoor ground stays visible while there
	# is daylight on it (night darkening comes from the ambient ramp), and empty sky stays
	# visible so hull occlusion cannot cut a silhouette out of the cloudsea.
	if _vis.size() != n:
		_vis.resize(n)
	var everything := full_bright or not have_player
	_vis.fill(1 if everything else 0)
	var ro := region_origin
	var rx0 := maxi(0, -ro.x)
	var rx1 := mini(REGION_W, map.w - ro.x)
	var mw := map.w
	var lo_r := 0.85 if dark_sight else 0.05
	var lo_g := 0.85 if dark_sight else 0.06
	var lo_b := 0.85 if dark_sight else 0.09
	if _turf_flags.is_empty():
		var tf := PackedInt32Array()
		for info: Dictionary in Defs.TURFS:
			tf.append(info["flags"])
		_turf_flags = tf
	var flags := _turf_flags
	if _opq_turf.size() != flags.size():
		_opq_turf.resize(flags.size())
		for t in flags.size():
			_opq_turf[t] = 1 if (flags[t] & Defs.F_OPAQUE) != 0 else 0
	var opq_cnt := map.opaque_count
	var glow_on := _glow_sprite != null and not full_bright
	var gl := _gl
	if glow_on:
		if gl.size() != n * 3:
			gl.resize(n * 3)
		gl.fill(0.0)
	var ao_w := 0.0 if quality <= 0 else (0.075 if quality == 1 else 0.10)
	var void_bit: int = Defs.F_VOID
	var vis_arr := visible
	for ry in REGION_H:
		var y := ro.y + ry
		if y < 0 or y >= map.h:
			continue
		var base := y * mw + ro.x
		var kbase := ry * REGION_W
		for rx in range(rx0, rx1):
			var i := base + rx
			var a := amb[i]
			var v := everything or vis_arr[i] == 1 or (flags[map.turf[i]] & void_bit) != 0 or (open_sight and a > OPEN_SKY_AMB)
			var k := kbase + rx
			var o := k * 3
			if not v:
				# Unseen but in the map: not a black hole. A dim, cool "remembered" shade
				# keeps the deck's shape readable (entities stay hidden elsewhere).
				_vis[k] = 2
				fr[o] = (acc_r[i] + a * amb_c.r) * 0.5
				fr[o + 1] = (acc_g[i] + a * amb_c.g) * 0.5
				fr[o + 2] = (acc_b[i] + a * amb_c.b) * 0.5
				continue
			_vis[k] = 1
			if glow_on:
				var lr := maxf(acc_r[i] - 0.3, 0.0) * 0.30
				var lg := maxf(acc_g[i] - 0.3, 0.0) * 0.27
				var lb := maxf(acc_b[i] - 0.3, 0.0) * 0.20
				gl[o] = lr
				gl[o + 1] = lg
				gl[o + 2] = lb
			fr[o] = acc_r[i] + a * amb_c.r
			fr[o + 1] = acc_g[i] + a * amb_c.g
			fr[o + 2] = acc_b[i] + a * amb_c.b
			if ao_w > 0.0 and _opq_turf[map.turf[i]] == 0 and opq_cnt[i] == 0:
				# ambient occlusion: floor beside a wall or tall fitting is a little darker
				var n_opq := 0
				var x := ro.x + rx
				if x > 0 and (_opq_turf[map.turf[i - 1]] == 1 or opq_cnt[i - 1] > 0): n_opq += 1
				if x < mw - 1 and (_opq_turf[map.turf[i + 1]] == 1 or opq_cnt[i + 1] > 0): n_opq += 1
				if y > 0 and (_opq_turf[map.turf[i - mw]] == 1 or opq_cnt[i - mw] > 0): n_opq += 1
				if y < map.h - 1 and (_opq_turf[map.turf[i + mw]] == 1 or opq_cnt[i + mw] > 0): n_opq += 1
				if n_opq > 0:
					var ao := 1.0 - ao_w * minf(float(n_opq), 2.5)
					fr[o] *= ao
					fr[o + 1] *= ao
					fr[o + 2] *= ao
	# fire light (dynamic, flickering)
	if Game.atmos:
		for c in Game.atmos.hotspots.keys():
			if not fire_cache.has(c):
				var cache := _cast(c, 4.5)
				fire_cache[c] = cache
			_splat(fr, fire_cache[c], Color(1.0, 0.55, 0.2) * (1.1 * flicker))
		for c in fire_cache.keys():
			if not Game.atmos.hotspots.has(c):
				fire_cache.erase(c)
	for f in flashes:
		var k: float = 1.0 - f["t"] / f["dur"]
		_splat(fr, [f["cells"], f["falloff"]], f["color"] * (k * 1.6))
	# minimum visibility + clamp
	if full_bright:
		fr.fill(1.0)
	else:
		# floor for unseen space follows the time of day so night decks sink, noon decks don't
		var dim_r := 0.12 + amb_c.r * 0.16
		var dim_g := 0.13 + amb_c.g * 0.16
		var dim_b := 0.18 + amb_c.b * 0.17
		if dark_sight:
			dim_r = 0.85
			dim_g = 0.85
			dim_b = 0.85
		for k in n:
			var o := k * 3
			var vk := _vis[k]
			if vk == 1:
				fr[o] = clampf(fr[o], lo_r, 1.12)
				fr[o + 1] = clampf(fr[o + 1], lo_g, 1.12)
				fr[o + 2] = clampf(fr[o + 2], lo_b, 1.15)
			elif vk == 2:
				fr[o] = clampf(fr[o], dim_r, 0.42)
				fr[o + 1] = clampf(fr[o + 1], dim_g, 0.44)
				fr[o + 2] = clampf(fr[o + 2], dim_b, 0.5)
			else:
				fr[o] = 0.0
				fr[o + 1] = 0.0
				fr[o + 2] = 0.0
	# float -> half conversion is done natively by Image.convert
	if _ship_material != null:
		_upload(_ship_source_image, _ship_source_texture, fr)
		if not full_bright:
			var sky_r := clampf(amb_c.r, lo_r, 1.12)
			var sky_g := clampf(amb_c.g, lo_g, 1.12)
			var sky_b := clampf(amb_c.b, lo_b, 1.15)
			for idx in _ship_backgrounds:
				var covered: int = _ship_backgrounds[idx]
				if covered < 0 or not (int(flags[covered]) & (Defs.F_OUTDOOR | Defs.F_VOID)):
					continue
				# This is the original sky beneath the stamp, not cabin space. Deck
				# lighting will be put back only where the drawn hull actually lies.
				var cx: int = int(idx) % mw - ro.x
				var cy: int = int(idx) / mw - ro.y
				if cx < 0 or cy < 0 or cx >= REGION_W or cy >= REGION_H:
					continue
				var oo := (cy * REGION_W + cx) * 3
				fr[oo] = sky_r
				fr[oo + 1] = sky_g
				fr[oo + 2] = sky_b
	_update_grade(amb_c)
	_upload(image, texture, fr)
	if _glow_sprite != null:
		_glow_sprite.visible = glow_on
		if glow_on:
			_upload(_glow_image, _glow_texture, gl)
	sprite.position = Vector2(region_origin) * Defs.TILE
	_note_compose()

func _upload(img: Image, tex: ImageTexture, fr: PackedFloat32Array) -> void:
	var tmp := Image.create_from_data(REGION_W, REGION_H, false, Image.FORMAT_RGBF, fr.to_byte_array())
	tmp.convert(Image.FORMAT_RGBH)
	img.set_data(REGION_W, REGION_H, false, Image.FORMAT_RGBH, tmp.get_data())
	tex.update(img)

func _splat(fr: PackedFloat32Array, cache: Array, col: Color) -> void:
	var cells: PackedInt32Array = cache[0]
	var fall: PackedFloat32Array = cache[1]
	for k in cells.size():
		var i := cells[k]
		var x := i % map.w - region_origin.x
		var y := i / map.w - region_origin.y
		if x < 0 or y < 0 or x >= REGION_W or y >= REGION_H:
			continue
		if Game.player != null and visible[i] == 0:
			continue
		var o := (y * REGION_W + x) * 3
		fr[o] += col.r * fall[k]
		fr[o + 1] += col.g * fall[k]
		fr[o + 2] += col.b * fall[k]

## Colour wash over the whole frame that follows the sky: warm at dusk and dawn, cool blue at
## night, almost nothing at noon. It is the one time-of-day cue that also covers the UI-free
## screen (characters, docks and hulls are already graded through the lightmap).
func _update_grade(amb_c: Color) -> void:
	if quality <= 0 or Game.hud == null or not is_instance_valid(Game.hud):
		return
	var g := Color(0, 0, 0, 0)
	if Game.sky != null and not full_bright:
		var e: float = Game.sky.sun_elevation()
		var low := clampf(1.0 - absf(e) * 3.0, 0.0, 1.0) # strongest at the horizon
		var night := clampf(-e * 1.5, 0.0, 1.0)
		g = Color(1.0, 0.6, 0.35, 0.10 * low).lerp(Color(0.05, 0.08, 0.22, 0.14), night)
		if e > 0.0:
			g.a = 0.10 * low
		else:
			g.a = maxf(0.10 * low, 0.14 * night)
	for m in [Game.hud.get("fx_full"), Game.hud.get("fx_lite")]:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("grade", Vector4(g.r, g.g, g.b, g.a))
