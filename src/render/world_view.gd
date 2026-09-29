class_name WorldView extends Node2D
## Owns the world's render layers (bottom to top):
##   terrain chunks -> entities (y-sorted) -> fx -> gases -> snowfall -> lightmap (multiply)
## plus the camera, footprints, breath fog and screen shake.

var map: StationMap
var chunks := {}
var terrain_root: Node2D
var ents: Node2D
var fx_layer: Node2D
var gas_root: Node2D
var gas_layer: GasLayer
var decal_root: Node2D
var snow: Snowfall
var lightmap: Sprite2D
var camera: Camera2D
var shake_amt := 0.0
var zoom_level := 2.0
var noise_tex: NoiseTexture2D
var ground_mat: ShaderMaterial
var _dirty_chunks := {}
var footprints: Array = []
var hover_rect: Node2D
var hover_cell := Vector2i(-1, -1)
## A gentle lean in the direction of travel, so a fast ship shows more of where she is
## going than where she has been.
var motion_lead := Vector2.ZERO

func _init() -> void:
	process_priority = 10 # follow this frame's ship and passenger transforms
	terrain_root = Node2D.new()
	terrain_root.name = "Terrain"
	# below every entity layer: floor-level objects use negative z (beds -1, decals -2)
	# and would otherwise sort underneath the floor itself
	terrain_root.z_index = -10
	add_child(terrain_root)
	decal_root = Node2D.new()
	decal_root.name = "Footprints"
	decal_root.z_index = -9
	add_child(decal_root)
	ents = Node2D.new()
	ents.name = "Entities"
	ents.y_sort_enabled = true
	add_child(ents)
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 3
	add_child(fx_layer)
	gas_root = Node2D.new()
	gas_root.name = "Gas"
	gas_root.z_index = 4
	add_child(gas_root)
	snow = Snowfall.new()
	snow.process_priority = 30
	add_child(snow)
	if not "--nomotes" in OS.get_cmdline_user_args():
		add_child(AmbientMotes.new())
	lightmap = Sprite2D.new()
	lightmap.name = "Lightmap"
	lightmap.z_index = 10
	lightmap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	lightmap.material = mat
	add_child(lightmap)
	add_child(ThermalVisionLayer.new())
	add_child(EchoVisionLayer.new())
	hover_rect = Node2D.new()
	hover_rect.z_index = 11
	hover_rect.draw.connect(_draw_hover)
	add_child(hover_rect)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	camera.zoom = Vector2(zoom_level, zoom_level)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)

func setup(m: StationMap) -> void:
	map = m
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	noise_tex.noise = fn
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://src/render/ground.gdshader")
	ground_mat.set_shader_parameter("noise_tex", noise_tex)
	var ncx := int(ceil(m.w / 16.0))
	var ncy := int(ceil(m.h / 16.0))
	for y in ncy:
		for x in ncx:
			var ch := TerrainChunk.new()
			ch.cx = x
			ch.cy = y
			ch.map = m
			ch.position = Vector2(x * 16 * 32, y * 16 * 32)
			if not "--noshader" in OS.get_cmdline_user_args():
				ch.material = ground_mat
			terrain_root.add_child(ch)
			chunks[Vector2i(x, y)] = ch
	gas_layer = GasLayer.new()
	gas_layer.setup(m)
	gas_root.add_child(gas_layer)
	var pdl := PipeDebugLayer.new()
	pdl.z_index = 6
	add_child(pdl)
	var tr := TRayLayer.new()
	tr.z_index = -8
	add_child(tr)
	var ao := AtmosOverlay.new()
	ao.z_index = 5
	add_child(ao)
	var ph := PipeHover.new()
	ph.z_index = 6
	add_child(ph)
	Bus.tile_changed.connect(_on_tile_changed)
	Bus.cables_changed.connect(_redraw_all)
	Bus.pipes_changed.connect(_redraw_all)

func _on_tile_changed(c: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cc: Vector2i = c + d
		_dirty_chunks[Vector2i(cc.x / 16, cc.y / 16)] = true

## Mark every chunk covering these cells for redraw. Cheaper than one tile_changed per
## tile when a whole airship's worth of terrain moves at once.
func mark_cells_dirty(cs: Array) -> void:
	for c in cs:
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cc: Vector2i = c + d
			_dirty_chunks[Vector2i(cc.x / 16, cc.y / 16)] = true

func _redraw_all() -> void:
	for ch in chunks.values():
		ch.queue_redraw()

var _dizzy_off := Vector2.ZERO
var _wind_t := 0.0

## --rperf: cheap accumulating timers, printed every few seconds.
static var rperf := "--rperf" in OS.get_cmdline_user_args()
static var _pt := {}
var _rp_t := 0.0
var _rp_frames := 0

static func pt(key: String, t0: int) -> void:
	var d: Array = _pt.get(key, [0, 0, 0])
	var us := Time.get_ticks_usec() - t0
	d[0] += 1
	d[1] += us
	d[2] = maxi(d[2], us)
	_pt[key] = d

func _rperf_tick(delta: float) -> void:
	_rp_t += delta
	_rp_frames += 1
	if _rp_t < 4.0:
		return
	var parts := []
	for k in _pt:
		var d: Array = _pt[k]
		parts.append("%s n=%d avg=%.2fms max=%.2fms tot/s=%.2fms" % [k, d[0], d[1] / 1000.0 / maxi(1, d[0]), d[2] / 1000.0, d[1] / 1000.0 / _rp_t])
	print("RPERF fps=%.1f proc=%.2fms draws=%d objs=%d nodes=%d prims=%d
  %s" % [_rp_frames / _rp_t,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"
  ".join(parts)])
	_pt.clear()
	_rp_t = 0.0
	_rp_frames = 0

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_proc(delta)
	if rperf:
		pt("view_proc", t0)

func _proc(delta: float) -> void:
	if rperf:
		_rperf_tick(delta)
	# A moving hull dirties the chunks under it every restamp; redrawing them all in one
	# frame is a visible hitch, so a few per frame is plenty (a queue, oldest first).
	var budget := 3
	for k in _dirty_chunks.keys():
		if chunks.has(k):
			chunks[k].queue_redraw()
		_dirty_chunks.erase(k)
		budget -= 1
		if budget <= 0:
			break
	# the ground's wind ripples and cloud shadows drift the way the weather says
	_wind_t -= delta
	if _wind_t <= 0.0 and ground_mat != null and Game.sky != null:
		_wind_t = 0.5
		var wv: Vector2 = Game.sky.wind_vector()
		ground_mat.set_shader_parameter("wind_dir", wv if wv.length() > 0.05 else Vector2(1.0, 0.25))
		ground_mat.set_shader_parameter("wind_speed", clampf(0.5 + wv.length() * 1.2, 0.5, 2.5))
	# camera follow + shake
	var p := Game.player
	if p != null and is_instance_valid(p):
		camera.position = p.position + Vector2(0, -12) + motion_lead
	if Game.fleet != null and Game.fleet.ship_at(hover_cell) != null:
		hover_rect.queue_redraw()
	if shake_amt > 0.05:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt *= pow(0.02, delta)
	else:
		camera.offset = Vector2.ZERO
	# tg dizziness: the view swings about
	if p != null and is_instance_valid(p) and p.has_c(&"health"):
		var dz := StatusFx.dizzy_offset(p.c(&"health"), Game.time * 10.0)
		_dizzy_off = _dizzy_off.lerp(dz, minf(1.0, delta * 3.0))
		camera.offset += _dizzy_off
	camera.zoom = camera.zoom.lerp(Vector2(zoom_level, zoom_level), minf(1.0, delta * 10.0))
	camera.force_update_scroll()
	# footprints fade
	for f in footprints.duplicate():
		f[1] -= delta
		if f[1] <= 0:
			f[0].queue_free()
			footprints.erase(f)
		elif f[1] < 20.0:
			f[0].modulate.a = f[1] / 20.0
	# breath fog outside
	_breath(delta)

func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)

func on_step(e: Entity, from: Vector2i, to: Vector2i) -> void:
	_blood_step(e, from, to)
	var fl := map.tflags(to)
	var is_near := Game.player != null and e.dist_to(Game.player) < 12
	if is_near:
		Sfx.play("step_snow" if fl & Defs.F_OUTDOOR else "step_floor", to, 0.5 if e != Game.player else 0.8)
	if fl & Defs.F_OUTDOOR and map.get_turf(to) != Defs.T_ICE:
		var d := to - from
		var dname := "n" if d.y < 0 else ("s" if d.y > 0 else ("e" if d.x > 0 else "w"))
		var s := Sprite2D.new()
		s.texture = Gfx.tex("objects")
		s.region_enabled = true
		s.region_rect = Gfx.region("objects", "snowprints_" + dname)
		s.position = Vector2(to.x * 32 + 16, to.y * 32 + 16)
		decal_root.add_child(s)
		footprints.append([s, 90.0])
		if footprints.size() > 400:
			footprints[0][0].queue_free()
			footprints.remove_at(0)

## tg: walking through blood leaves bloody footprints for a while (shoes_bloody), and a
## bleeding person being dragged along the floor leaves a trail.
func _blood_step(e: Entity, from: Vector2i, to: Vector2i) -> void:
	var h: CHealth = e.c(&"health")
	if h == null or e.holder != null:
		return
	var m: CMob = e.c(&"mob")
	if m and m.is_lying():
		# tg make_blood_trail: dragging a bleeding body smears its cuts along the floor
		if not h.dead and Body.leaves_trail(h):
			var already := Game.at(from).any(func(x): return x.proto == "blood_trail")
			if not already and not map.is_solid_turf(from):
				# tg get_trail_state: heavy trails from a badly hurt body, light smears otherwise
				var heavy := h.brute >= 300.0 or Body.bleed_rate(h) >= 2.0
				Proto.spawn("blood_trail", from, {"spr": "blood_%s_%d_%s" % ["trails" if heavy else "ltrails", Game.rng.randi() % 2, "h" if from.y == to.y else "v"]})
			h.blood_volume = maxf(0.0, h.blood_volume - (Body.BLOOD_AMOUNT_PER_DECAL * 0.1 + Body.drag_bleed_amount(h)))
		return
	# tg cleanable/blood on_entered + /datum/component/bloodysoles: stepping in wet blood
	# soaks the soles (up to MAX_SHOE_BLOODINESS), each step after leaves prints and costs
	# BLOOD_LOSS_PER_STEP, and prints stop below BLOOD_FOOTPRINTS_MIN.
	var soles: float = e.tags.get("bloody_feet", 0.0)
	for d in Game.at(to):
		var dc: CDecal = d.c(&"decal")
		if dc and dc.blood and not dc.dried and dc.bloodiness > 0.0:
			var add := minf(dc.bloodiness, minf(100.0, 100.0 - soles))
			dc.bloodiness -= add
			e.tags["bloody_feet"] = soles + add
			# tg bloodysoles on shoes: the shoes get bloody too
			var inv: CInventory = e.c(&"inv")
			if inv and inv.worn("shoes"):
				for k in Forensics.blood_on(d):
					Forensics._data(inv.worn("shoes"))["blood"][k] = Forensics.blood_on(d)[k]
			if inv and inv.worn("shoes") and not Blood.bloody(inv.worn("shoes")):
				Blood.stain_item(inv.worn("shoes"))
				e.c(&"mob").refresh_doll()
			return
		if dc and dc.kind == "blood" and dc.liquid:
			e.tags["bloody_feet"] = 100.0
			return
	if soles < 5.0:
		e.tags.erase("bloody_feet")
		return
	e.tags["bloody_feet"] = soles - 5.0
	var dd := to - from
	var dname := "n" if dd.y < 0 else ("s" if dd.y > 0 else ("e" if dd.x > 0 else "w"))
	var s := Sprite2D.new()
	s.texture = Gfx.tex("objects")
	s.region_enabled = true
	s.region_rect = Gfx.region("objects", "bloodprints_" + dname)
	s.position = Vector2(to.x * 32 + 16, to.y * 32 + 16)
	decal_root.add_child(s)
	footprints.append([s, 240.0])

var _breath_t := 0.0

func _breath(delta: float) -> void:
	_breath_t -= delta
	if _breath_t > 0.0 or Game.atmos == null or Game.player == null:
		return
	_breath_t = 0.9
	for e in Game.in_radius(Game.player.cell, 12, &"mob"):
		var h: CHealth = e.c(&"health")
		if h == null or h.dead or randf() < 0.55:
			continue
		if Game.atmos.temp_at(e.cell) > 262.0:
			continue
		if not Game.lighting.player_can_see(e.cell):
			continue
		var m: CMob = e.c(&"mob")
		var s := Sprite2D.new()
		s.texture = Gfx.tex("fx")
		s.region_enabled = true
		s.region_rect = Gfx.region("fx", "breath")
		var off := Vector2(0, -22)
		match m.dir:
			Defs.DIR_E: off += Vector2(7, 2)
			Defs.DIR_W: off += Vector2(-7, 2)
			Defs.DIR_S: off += Vector2(0, 5)
			Defs.DIR_N: off += Vector2(0, -4)
		s.position = e.position + off
		s.modulate = Color(1, 1, 1, 0.55)
		s.scale = Vector2(0.4, 0.4)
		s.z_index = 3
		fx_layer.add_child(s)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "scale", Vector2(1.1, 1.1), 1.4)
		tw.tween_property(s, "modulate:a", 0.0, 1.4)
		tw.tween_property(s, "position", s.position + Vector2(snow.wind.x * 0.2, -10), 1.4)
		tw.chain().tween_callback(s.queue_free)

# ------------------------------------------------------------------ mouse helpers
func mouse_cell() -> Vector2i:
	var mp := get_global_mouse_position()
	if Game.fleet != null:
		return Game.fleet.cell_at_visual(mp)
	return Vector2i(floori(mp.x / 32.0), floori(mp.y / 32.0))

## The cell under a point on the screen (canvas coordinates, like HUD.mouse).
func cell_at_screen(pos: Vector2) -> Vector2i:
	var wp := get_viewport().get_canvas_transform().affine_inverse() * pos
	if Game.fleet != null:
		return Game.fleet.cell_at_visual(wp)
	return Vector2i(floori(wp.x / 32.0), floori(wp.y / 32.0))

func set_hover(c: Vector2i) -> void:
	if c != hover_cell:
		hover_cell = c
		hover_rect.queue_redraw()

func _draw_hover() -> void:
	if hover_cell.x < 0:
		return
	var r := Rect2(Vector2(hover_cell) * 32, Vector2(32, 32))
	var sh: Airship = Game.fleet.ship_at(hover_cell) if Game.fleet != null else null
	if sh != null:
		var centre := sh.visual_position(Entity.cell_to_pos(hover_cell)) - Vector2(0, Defs.TILE * 0.5)
		hover_rect.draw_set_transform(centre, sh.angle)
		r = Rect2(Vector2(-16, -16), Vector2(32, 32))
	var col := Color(0.75, 0.9, 1.0, 0.35)
	var L := 6.0
	for corner in [[r.position, Vector2(1, 1)], [r.position + Vector2(32, 0), Vector2(-1, 1)], [r.position + Vector2(0, 32), Vector2(1, -1)], [r.position + Vector2(32, 32), Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		hover_rect.draw_line(p, p + Vector2(L * s.x, 0), col, 1.0)
		hover_rect.draw_line(p, p + Vector2(0, L * s.y), col, 1.0)
	hover_rect.draw_set_transform(Vector2.ZERO)
