class_name ShipRenderer extends Node2D
## A hull drawn in its own east-facing frame, with one continuous world transform.
## Terrain, fittings and passengers share the same pivot and sub-tile translation.

var ship: Airship
var tex: Texture2D
var obj_tex: Texture2D
var _carried_entities := {} # reset fitting rotations when a passenger leaves

func _init() -> void:
	z_index = -9
	y_sort_enabled = false
	process_priority = 0 # fleet (-10), visuals (0), camera (10)

func _ready() -> void:
	tex = Gfx.tex("terrain")
	obj_tex = Gfx.tex("objects")
	# the hull shares the ground's world-space shading, so deck and dock sit in one light
	if Game.view != null and Game.view.ground_mat != null:
		material = Game.view.ground_mat
	Bus.tile_changed.connect(_on_tile_changed)
	if ship != null and not "--noflair" in OS.get_cmdline_user_args():
		var fl := ShipFlair.new()
		fl.setup(ship)
		add_child(fl)
	sync_visuals()

func setup(sh: Airship) -> void:
	ship = sh

func _on_tile_changed(c: Vector2i) -> void:
	if ship != null and c in ship.cells:
		queue_redraw()

func _process(_delta: float) -> void:
	if ship == null or not ship.present:
		queue_free()
		return
	sync_visuals()

func sync_visuals() -> void:
	if ship == null or not ship.present:
		return
	position = ship.visual_pivot() + ship.fx_offset
	rotation = ship.angle
	_carry()

func _carry() -> void:
	var carried := {}
	for c in ship.cells:
		for e in Game.at(c):
			if e.removed or e.holder != null:
				continue
			carried[e.get_instance_id()] = e
			# These are perspective sprites with world-down feet and baked shadows.
			# Carry their anchors with the deck; preserve their upright artwork.
			e.position = ship.visual_position(ship.simulation_position(e)) + ship.fx_offset
			e.rotation = 0.0
	for eid in _carried_entities:
		if not carried.has(eid):
			var e = _carried_entities[eid]
			if is_instance_valid(e) and not e.removed:
				e.rotation = 0.0
	_carried_entities = carried

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_impl()
	if WorldView.rperf:
		WorldView.pt("ship_draw", t0)

func _draw_impl() -> void:
	if ship == null or Game.map == null:
		return
	var mid := ship.local_pivot()
	for key in ship.cells_map:
		var world: Vector2i = ship.cell(key.x, key.y)
		if not Game.map.inb(world):
			continue
		var i := Game.map.idx(world)
		var t: int = Game.map.turf[i]
		var info: Dictionary = Defs.TURFS[t]
		var rel := (Vector2(key) - mid - Vector2(0.5, 0.5)) * float(Defs.TILE)
		var fl: int = info["flags"]
		if fl & Defs.F_WALL:
			_t("plating_0", rel)
			_t("%s_%d" % [info["spr"], _wall_mask(key)], rel)
		else:
			var v: int = Game.map.variant[i] % maxi(1, int(info["var"]))
			_t("%s_%d" % [info["spr"], v], rel, Color.WHITE if fl & Defs.F_OUTDOOR else TerrainChunk.INDOOR)
			var structure: int = Game.map.structure[i]
			if Defs.is_window(structure):
				_t(("rwindow_%d" if structure == Defs.S_RWINDOW else "window_%d") % _window_mask(key), rel)
	if not ship.lower_cells.is_empty() and ship.upper_stair_local.x > -9000:
		var stair_at := (Vector2(ship.upper_stair_local) - mid - Vector2(0.5, 0.5)) * float(Defs.TILE)
		Underdecks.paint_stair(self, stair_at, "DOWN")

## Autotiling lives in the hull's frame so its artwork never flips at a restamp.
func _wall_mask(local: Vector2i) -> int:
	var mask := 0
	for d in 4:
		var n: Vector2i = local + Defs.DIRS4[d]
		if not ship.cells_map.has(n):
			continue
		var world := ship.cell(n.x, n.y)
		if Game.map.inb(world) and (Game.map.tflags(world) & (Defs.F_WALL | Defs.F_ROCK)) != 0:
			mask |= 1 << d
	return mask

func _window_mask(local: Vector2i) -> int:
	var mask := 0
	for d in 4:
		var n: Vector2i = local + Defs.DIRS4[d]
		if not ship.cells_map.has(n):
			continue
		var world := ship.cell(n.x, n.y)
		if Game.map.inb(world) and Defs.is_window(Game.map.structure[Game.map.idx(world)]):
			mask |= 1 << d
	return mask

func _t(name: String, at: Vector2, mod := Color.WHITE) -> void:
	var r = Gfx.manifest["terrain"].get(name)
	if r == null:
		return
	var tile := float(Defs.TILE)
	draw_texture_rect_region(tex, Rect2(at, Vector2(tile, tile)), Rect2(r[0] * tile, r[1] * tile, tile, tile), mod)
