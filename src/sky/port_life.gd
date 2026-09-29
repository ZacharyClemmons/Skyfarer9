class_name PortLife extends Node2D
## The front at Port Meridian, moving.
##
## A port that only sits there is a diorama. Everything in here is ambient and none of it
## touches the simulation: chimney smoke and forge steam, bunting and rooftop pennants that
## sway in the real wind, gulls, cloud shadows sliding over the quay, barges bobbing at
## their moorings, windows that light up at dusk, a handful of townsfolk and dockhands
## walking between the doors, and a soft marker over the yard so a new player knows where
## to walk. It only does any work when the player is within sight of the port, and it draws
## everything with primitives so there is nothing to import.
##
## Layers, bottom to top:
##   shade   (z -7)  cloud shadows on the ground, under the people
##   this    (z  8)  smoke, bunting, flags, barges, gulls: under the night lightmap
##   glow    (z 12)  additive: lit windows, lantern bloom, wayfinding, hover — above the
##                   lightmap so a lit window stays lit in the dark

const TILE := 32.0
const NEAR := 58.0            # tiles: further than this and the whole thing sleeps
const WALKERS := 4

static var yard_seen := false  # the wayfinding arrow is dismissed for good once visited
static var board_seen := false
static var _floaters: Array = []

## A figure that rises off somebody and fades: "-1,200" over the buyer, "+340" over the
## seller. Any code may call it; it is drawn only while the port is on screen.
static func floater(text: String, who: Entity, col: Color) -> void:
	if who == null or not is_instance_valid(who):
		return
	_floaters.append({"text": text, "e": who, "col": col, "t": 0.0})
	if _floaters.size() > 6:
		_floaters.pop_front()

var glow: Node2D
var shade: Node2D
var _t := 0.0
var _inited := false
var _near := false
var gen: SkyGen
var isl: Dictionary = {}
var shops: Array = []
var lanterns: Array = []      # Vector2 world px of each lamp head
var bunting: Array = []       # [a: Vector2, b: Vector2, phase: float]
var yard_front := Vector2i(-1, -1)
var yard_door := Vector2i(-1, -1)
var board_cell := Vector2i(-1, -1)
var barges: Array = []
var puffs: Array = []
var sparks: Array = []
var gulls: Array = []
var _spawn_t := {}            # shop index -> seconds until next puff
var _cloud := FastNoiseLite.new()
var _shade_t := 0.0
var _rng := RandomNumberGenerator.new()
var _sky_t := 0.0
var _barge_check := 0.0
var _hover_e: Entity = null
var _arrow_fade := 0.0
var _walkers: Array = []
var _walker_t := 0.0
var _crates: Array = []       # cells beside crates, for dockhands
var _fronts: Array = []       # cells in front of each door, for townsfolk
var _no_walkers := false

const FLAG_COLS := [Color("#e8524a"), Color("#f2c14e"), Color("#3aa6c8"), Color("#f0ece0"), Color("#6fbf6a"), Color("#d6784a")]

func _ready() -> void:
	z_index = 8
	_rng.seed = 90210
	_cloud.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cloud.frequency = 0.045
	_cloud.fractal_octaves = 2
	shade = Node2D.new()
	shade.z_index = -7 - 8   # relative: this node is at +8, so -7 overall
	shade.draw.connect(_draw_shade)
	add_child(shade)
	glow = Node2D.new()
	glow.z_index = 4         # relative: +12 overall
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = cm
	glow.draw.connect(_draw_glow)
	add_child(glow)

# ------------------------------------------------------------------ setup
func _init_hub() -> void:
	_inited = true
	gen = Game.sky.gen if Game.sky != null else null
	if gen == null or gen.hub.is_empty():
		return
	isl = gen.hub
	shops = isl.get("shops", [])
	var args: Dictionary = {}
	if Game.world != null and Game.world.get_parent() != null and "args" in Game.world.get_parent():
		args = Game.world.get_parent().args
	for k in ["flighttest", "systemtest", "flytest", "looptest", "buildtest", "inventorytest", "gencheck", "airtest", "boardtest"]:
		if args.has(k):
			_no_walkers = true
	var hc: Vector2i = gen.hub_center
	for e in Game.all_with(&"light"):
		if e.proto == "port_lantern" and absi(e.cell.x - hc.x) < 40 and absi(e.cell.y - hc.y) < 40:
			lanterns.append(Vector2(e.cell) * TILE + Vector2(16, 3))
	# bunting between lanterns that stand in a line and are neither touching nor far apart
	for i in lanterns.size():
		var a: Vector2 = lanterns[i]
		for j in lanterns.size():
			if i == j:
				continue
			var b: Vector2 = lanterns[j]
			var d := b - a
			var aligned := absf(d.y) < 4.0 or absf(d.x) < 4.0
			var ln := d.length()
			if aligned and ln > 3.5 * TILE and ln < 9.0 * TILE and (d.x > 1.0 or (absf(d.x) < 4.0 and d.y > 1.0)):
				# only the nearest partner in each direction
				var best := true
				for k in lanterns.size():
					if k == i or k == j:
						continue
					var c2: Vector2 = lanterns[k]
					var d2 := c2 - a
					var al2 := absf(d2.y) < 4.0 or absf(d2.x) < 4.0
					if al2 and d2.dot(d) > 0.0 and d2.length() < ln - 1.0:
						best = false
						break
				if best:
					bunting.append([a, b, _rng.randf() * TAU])
	# where the yard is, and the board
	var desk := Vector2i(-1, -1)
	for de in Game.all_with(&"shipyard"):
		if _on_hub(de.cell):
			desk = de.cell
			break
	var best_d := 1 << 30
	for s in shops:
		var dc: Vector2i = s["door"]
		var out: Vector2i = s["out"]
		_fronts.append({"cell": dc + out, "door": dc, "out": out})
		if desk.x >= 0:
			var dd := (dc - desk).length_squared()
			if dd < best_d:
				best_d = dd
				yard_door = dc
				yard_front = dc + out
	if yard_front.x < 0 and desk.x >= 0:
		yard_front = desk
		yard_door = desk
	for be in Game.all_with(&"noticeboard"):
		if _on_hub(be.cell):
			board_cell = be.cell
			break
	_barge_sites()
	for c in Game.all_with(&"blocker"):
		if (c.proto == "quay_crate" or c.proto == "barrel") and _on_hub(c.cell):
			_crates.append(c.cell)
	for i in 8:
		gulls.append({"p": Vector2.ZERO, "h": _rng.randf() * TAU, "s": _rng.randf_range(38.0, 64.0),
			"ph": _rng.randf() * 10.0, "turn": _rng.randf_range(-0.8, 0.8), "on": false})

func _on_hub(c: Vector2i) -> bool:
	return _in_isl(c)

var _isl_set := {}
func _in_isl(c: Vector2i) -> bool:
	if _isl_set.is_empty():
		for x in (isl["cells"] as Array):
			_isl_set[x] = true
	return _isl_set.has(c)

## Moored barges: only where the water beside the quay is empty sky, and never near the
## berth where the player's own ship is laid down.
func _barge_sites() -> void:
	var q: Dictionary = isl.get("quay", {})
	if q.is_empty():
		return
	var origin: Vector2i = q["cell"]
	var out: Vector2i = q["dir"]
	var along: Vector2i = q["along"]
	var idx := 0
	for k in [-14, 24, -22, 32, -30, 40, -18, 28]:
		# the coast is ragged: find the last land cell going outward from here
		var lip: Vector2i = origin + along * k
		var steps := 0
		while gen.is_land(lip) and steps < 7:
			lip += out
			steps += 1
		lip -= out
		if not gen.is_land(lip):
			# nothing here at all; look inland for the shore instead
			var back: Vector2i = origin + along * k
			steps = 0
			while not gen.is_land(back) and steps < 7:
				back -= out
				steps += 1
			lip = back
		if not gen.is_land(lip):
			continue
		var ok := true
		for a in range(-4, 5):
			for j in range(1, 4):
				var c: Vector2i = lip + along * a + out * j
				if not Game.map.inb(c) or gen.is_land(c):
					ok = false
		# and clear of the player's own berth
		if ok and absi(k - 8) < 13:
			ok = false
		if ok:
			barges.append({"cell": lip, "out": out, "along": along, "k": k,
				"ph": _rng.randf() * TAU, "kind": idx % 2, "col": idx, "hide": false})
			idx += 1
		if barges.size() >= 2:
			break

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if Game.player == null or Game.map == null or Game.sky == null:
		return
	if not _inited:
		_init_hub()
	if isl.is_empty():
		set_process(false)
		return
	_t += delta
	var fi := _floaters.size() - 1
	while fi >= 0:
		_floaters[fi]["t"] = float(_floaters[fi]["t"]) + delta
		if float(_floaters[fi]["t"]) > 1.7:
			_floaters.remove_at(fi)
		fi -= 1
	var pc: Vector2i = Underdecks.world_cell(Game.player)
	var hc: Vector2i = gen.hub_center
	_near = maxi(absi(pc.x - hc.x), absi(pc.y - hc.y)) < int(NEAR)
	visible = _near
	if not _near:
		_walker_t = 0.0
		return
	var wind: Vector2 = Game.sky.wind_vector()
	_update_smoke(delta, pc, wind)
	_update_gulls(delta, wind)
	_barge_check -= delta
	if _barge_check <= 0.0:
		_barge_check = 1.0
		_check_barges()
	_hover_e = _hovered()
	# the shade layer is retained, so it only needs to be redrawn a few times a second
	_shade_t -= delta
	if _shade_t <= 0.0:
		_shade_t = 0.09
		shade.queue_redraw()
	queue_redraw()
	glow.queue_redraw()
	if not _no_walkers:
		_walker_t += delta
		_tick_walkers(delta, pc)

func _view_rect() -> Rect2:
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * sz
	return Rect2(a, b - a).abs()

func _dark() -> float:
	# 0 in daylight, 1 in the dead of night
	var s: float = Game.sky.sun_elevation()
	return clampf(smoothstep(0.30, -0.35, s), 0.0, 1.0)

# ------------------------------------------------------------------ smoke and steam
func _update_smoke(delta: float, pc: Vector2i, wind: Vector2) -> void:
	var wdir := wind.normalized() if wind.length() > 0.01 else Vector2(1, 0)
	var drift := wdir * clampf(wind.length(), 0.2, 2.0) * 9.0
	for i in shops.size():
		var s: Dictionary = shops[i]
		var corner: Vector2i = s["corner"]
		if maxi(absi(corner.x - pc.x), absi(corner.y - pc.y)) > 36:
			continue
		var trade: String = s["trade"]
		var rate := 1.5
		match trade:
			"shipwright": rate = 0.55
			"artificer": rate = 0.8
			"gunsmith": rate = 1.1
			"curiosity": rate = 2.6
		_spawn_t[i] = float(_spawn_t.get(i, _rng.randf() * 2.0)) - delta
		if float(_spawn_t[i]) <= 0.0:
			_spawn_t[i] = rate * _rng.randf_range(0.7, 1.4)
			var along: Vector2i = s["along"]
			var cc: Vector2i = corner + along * (int(s["w"]) - 2)
			var pos := Vector2(cc) * TILE + Vector2(_rng.randf_range(10, 22), 6)
			puffs.append({"p": pos, "v": Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-15, -10)) + drift * 0.3,
				"a": 0.0, "life": _rng.randf_range(3.0, 4.6), "sz": _rng.randf_range(3.0, 5.0), "trade": trade})
			if trade == "shipwright" and _rng.randf() < 0.55:
				sparks.append({"p": pos + Vector2(_rng.randf_range(-6, 6), 0), "v": Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-40, -22)),
					"a": 0.0, "life": _rng.randf_range(0.6, 1.1)})
	var i2 := puffs.size() - 1
	while i2 >= 0:
		var p: Dictionary = puffs[i2]
		p["a"] = float(p["a"]) + delta
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
		p["v"] = (p["v"] as Vector2).lerp(drift, delta * 0.35)
		if float(p["a"]) >= float(p["life"]):
			puffs.remove_at(i2)
		i2 -= 1
	if puffs.size() > 140:
		puffs = puffs.slice(puffs.size() - 140)
	var i3 := sparks.size() - 1
	while i3 >= 0:
		var sp: Dictionary = sparks[i3]
		sp["a"] = float(sp["a"]) + delta
		sp["v"] = (sp["v"] as Vector2) + Vector2(0, 40) * delta
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
		if float(sp["a"]) >= float(sp["life"]):
			sparks.remove_at(i3)
		i3 -= 1

# ------------------------------------------------------------------ gulls
func _update_gulls(delta: float, wind: Vector2) -> void:
	var vr := _view_rect()
	var ctr := vr.get_center()
	var night := _dark() > 0.85
	for g in gulls:
		var p: Vector2 = g["p"]
		if p == Vector2.ZERO or absf(p.x - ctr.x) > vr.size.x * 0.9 or absf(p.y - ctr.y) > vr.size.y * 0.9:
			# come in from just outside the frame, heading roughly across it
			var side := _rng.randi() % 4
			var ex := vr.size * 0.6
			match side:
				0: p = ctr + Vector2(-ex.x, _rng.randf_range(-ex.y, ex.y))
				1: p = ctr + Vector2(ex.x, _rng.randf_range(-ex.y, ex.y))
				2: p = ctr + Vector2(_rng.randf_range(-ex.x, ex.x), -ex.y)
				_: p = ctr + Vector2(_rng.randf_range(-ex.x, ex.x), ex.y)
			g["h"] = (ctr - p).angle() + _rng.randf_range(-0.6, 0.6)
		g["ph"] = float(g["ph"]) + delta
		g["h"] = float(g["h"]) + sin(float(g["ph"]) * 0.4) * float(g["turn"]) * delta
		var v := Vector2.from_angle(float(g["h"])) * float(g["s"]) + wind * 4.0
		p += v * delta
		g["p"] = p
		g["night"] = night

# ------------------------------------------------------------------ barges
func _check_barges() -> void:
	for b in barges:
		var hide := false
		if Game.fleet != null:
			var origin: Vector2i = b["cell"]
			var out: Vector2i = b["out"]
			var along: Vector2i = b["along"]
			for a in range(-6, 7, 3):
				for j in range(1, 6):
					if Game.fleet.ship_at(origin + along * a + out * j) != null:
						hide = true
		b["hide"] = hide

# ------------------------------------------------------------------ drawing: low layer
func _draw() -> void:
	if not _near:
		return
	var vr := _view_rect().grow(96.0)
	var dark := _dark()
	var amb := Color(1, 1, 1)
	_draw_barges(vr, dark)
	# smoke
	for p in puffs:
		var pos: Vector2 = p["p"]
		if not vr.has_point(pos):
			continue
		var f: float = float(p["a"]) / float(p["life"])
		var sz: float = float(p["sz"]) * (1.0 + f * 2.4)
		var alpha := sin(clampf(f, 0.0, 1.0) * PI) * 0.42
		var tr: String = p["trade"]
		var col := Color(0.86, 0.85, 0.82)
		if tr == "shipwright" or tr == "gunsmith":
			col = Color(0.32, 0.30, 0.30).lerp(Color(0.62, 0.6, 0.6), f)
		elif tr == "artificer":
			col = Color(0.85, 0.93, 1.0)
		elif tr == "curiosity":
			col = Color(0.78, 0.6, 0.95)
		col.a = alpha
		var sn := Vector2(roundf(pos.x / 2.0) * 2.0, roundf(pos.y / 2.0) * 2.0)
		draw_rect(Rect2(sn - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
		if sz > 5.0:
			var c2 := col
			c2.a = alpha * 0.6
			draw_rect(Rect2(sn + Vector2(sz * 0.3, -sz * 0.4), Vector2(sz * 0.6, sz * 0.6)), c2)
	# bunting
	var wind: float = clampf(Game.sky.wind_strength(), 0.3, 2.0)
	for b in bunting:
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		if not vr.has_point(a) and not vr.has_point(c) and not vr.has_point((a + c) * 0.5):
			continue
		_draw_bunting(a, c, float(b[2]), wind)
	# pennants on the rooftops
	for i in shops.size():
		var s: Dictionary = shops[i]
		var corner: Vector2i = s["corner"]
		var pole := Vector2(corner) * TILE + Vector2(6, 4)
		if not vr.has_point(pole):
			continue
		_draw_pennant(pole, Color(String(s["col"])), i, wind)
	# gulls and their shadows
	if dark < 0.85:
		for g in gulls:
			var gp: Vector2 = g["p"]
			if not vr.has_point(gp):
				continue
			var flap := sin(_t * 9.0 + float(g["ph"]) * 3.0)
			var ang := float(g["h"])
			var fwd := Vector2.from_angle(ang)
			var side := fwd.orthogonal()
			var wl: float = 7.0
			var tip_l := gp + side * wl + fwd * (-2.0 + flap * 2.5)
			var tip_r := gp - side * wl + fwd * (-2.0 + flap * 2.5)
			var sh := Color(0.05, 0.07, 0.12, 0.16 * (1.0 - dark))
			var so := Vector2(10, 46)
			draw_line(tip_l + so, gp + so, sh, 2.0)
			draw_line(tip_r + so, gp + so, sh, 2.0)
			var wc := Color(0.97, 0.96, 0.94).lerp(Color(0.5, 0.55, 0.65), dark)
			draw_line(tip_l, gp + fwd * 1.0, wc, 2.0)
			draw_line(tip_r, gp + fwd * 1.0, wc, 2.0)
			draw_rect(Rect2(gp - Vector2(1.5, 1.5), Vector2(3, 3)), wc.darkened(0.15))

func _draw_bunting(a: Vector2, b: Vector2, phase: float, wind: float) -> void:
	var ln := (b - a).length()
	var sag := ln * 0.10
	var n := maxi(6, int(ln / 14.0))
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / float(n)
		var p := a.lerp(b, f)
		p.y += sin(f * PI) * sag + sin(_t * 1.6 * wind + phase + f * 5.0) * 0.8 * sin(f * PI)
		pts.append(p)
	draw_polyline(pts, Color(0.24, 0.18, 0.13, 0.9), 1.5)
	for i in range(1, n):
		var p2: Vector2 = pts[i]
		var col: Color = FLAG_COLS[(i + int(phase * 3.0)) % FLAG_COLS.size()]
		var flutter := sin(_t * 3.3 * wind + phase + float(i) * 1.7) * 1.6
		var tri := PackedVector2Array([p2 + Vector2(-3.5, 0), p2 + Vector2(3.5, 0), p2 + Vector2(flutter, 9.0)])
		draw_colored_polygon(tri, col)

func _draw_pennant(pole: Vector2, col: Color, seed_i: int, wind: float) -> void:
	draw_line(pole, pole + Vector2(0, -26), Color(0.22, 0.17, 0.13), 2.0)
	var w := 16.0
	var prev_top := pole + Vector2(1, -25)
	var prev_bot := pole + Vector2(1, -18)
	var pts_top := PackedVector2Array()
	var pts_bot := PackedVector2Array()
	pts_top.append(prev_top)
	pts_bot.append(prev_bot)
	var segs := 4
	for i in range(1, segs + 1):
		var f := float(i) / float(segs)
		var wave := sin(_t * 4.2 * wind + float(seed_i) * 1.3 - f * 4.0) * (1.0 + f * 2.2) * wind
		var x := pole.x + 1.0 + f * w
		var half := (1.0 - f) * 3.5 + 0.5
		pts_top.append(Vector2(x, pole.y - 21.5 - half + wave))
		pts_bot.append(Vector2(x, pole.y - 21.5 + half + wave))
	var poly := PackedVector2Array()
	for p in pts_top:
		poly.append(p)
	for i in range(pts_bot.size() - 1, -1, -1):
		poly.append(pts_bot[i])
	draw_colored_polygon(poly, col)
	draw_polyline(pts_top, col.lightened(0.3), 1.0)

func _draw_barges(vr: Rect2, dark: float) -> void:
	for b in barges:
		if bool(b["hide"]):
			continue
		var out: Vector2i = b["out"]
		var along: Vector2i = b["along"]
		var cell: Vector2i = b["cell"]
		var ctr := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE + Vector2(out) * TILE * 2.6
		if not vr.grow(160.0).has_point(ctr):
			continue
		var ph: float = b["ph"]
		var bob := sin(_t * 1.25 + ph) * 1.4
		var roll := sin(_t * 0.9 + ph * 1.7) * 0.012
		var ang := Vector2(along).angle()
		draw_set_transform(ctr + Vector2(out) * bob, ang + roll, Vector2.ONE)
		var hull := Color("#6d4b2f")
		var rim := Color("#3e2a1a")
		var deck := Color("#8f6a43")
		var kind: int = b["kind"]
		if kind == 1:
			hull = Color("#4f5f6b")
			rim = Color("#2b333a")
			deck = Color("#79868f")
		# hull, pointed at the bow (+x), squared at the stern
		var L := 138.0
		var W := 30.0
		var poly := PackedVector2Array([Vector2(-L, -W + 6), Vector2(-L + 8, -W), Vector2(L - 40, -W), Vector2(L + 12, -4),
			Vector2(L + 12, 4), Vector2(L - 40, W), Vector2(-L + 8, W), Vector2(-L, W - 6)])
		draw_set_transform(ctr + Vector2(out) * bob + Vector2(0, 5), ang + roll, Vector2.ONE)
		draw_colored_polygon(poly, Color(0, 0, 0, 0.16))
		draw_set_transform(ctr + Vector2(out) * bob, ang + roll, Vector2.ONE)
		draw_colored_polygon(poly, rim)
		var inner := PackedVector2Array()
		for p in poly:
			inner.append(p.move_toward(Vector2(0, 0), 5.0))
		draw_colored_polygon(inner, hull)
		var dk := PackedVector2Array([Vector2(-L + 14, -W + 8), Vector2(L - 42, -W + 8), Vector2(L - 2, -2), Vector2(L - 2, 2),
			Vector2(L - 42, W - 8), Vector2(-L + 14, W - 8)])
		draw_colored_polygon(dk, deck)
		for x in range(int(-L + 22), int(L - 44), 14):
			draw_line(Vector2(x, -W + 8), Vector2(x, W - 8), deck.darkened(0.16), 1.0)
		if kind == 0:
			# a small cabin aft, a mast amidships with the canvas furled along the boom
			draw_rect(Rect2(-L + 20, -16, 46, 32), rim)
			draw_rect(Rect2(-L + 23, -13, 40, 26), Color("#a5845a"))
			draw_rect(Rect2(-L + 28, -6, 8, 12), Color("#2a2f3a"))
			draw_line(Vector2(-6, 0), Vector2(60, 0), Color("#e2d8bc"), 5.0)
			draw_circle(Vector2(-6, 0), 5.0, rim)
			draw_circle(Vector2(-6, 0), 3.0, Color("#b0864c"))
		else:
			# cargo, lashed down under a tarpaulin
			for cx in [-70.0, -20.0, 30.0]:
				draw_rect(Rect2(cx, -20, 36, 40), Color("#5e4a2c"))
				draw_rect(Rect2(cx + 2, -18, 32, 36), Color("#7d6238"))
				draw_line(Vector2(cx + 2, 0), Vector2(cx + 34, 0), Color("#4a3a22"), 1.0)
			draw_rect(Rect2(-L + 12, -8, 16, 16), Color("#8a3b2c"))
		# a stern lamp
		draw_circle(Vector2(-L + 6, 0), 3.0, Color("#ffd8a0"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# mooring lines up to the lip
		var lip := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
		for off_v in [-90.0, 70.0]:
			var off: float = off_v
			var on_hull: Vector2 = ctr + Vector2(out) * (bob - W + 2.0) + Vector2(along) * off
			var on_quay: Vector2 = lip + Vector2(along) * off + Vector2(out) * 14.0
			var mid: Vector2 = (on_hull + on_quay) * 0.5 + Vector2(0, 2.0 + sin(_t + ph) * 0.5)
			draw_polyline(PackedVector2Array([on_quay, mid, on_hull]), Color("#d8c9a0", 0.85), 1.5)

# ------------------------------------------------------------------ drawing: cloud shadows
func _draw_shade() -> void:
	if not _near or gen == null:
		return
	var dark := _dark()
	if dark > 0.9:
		return
	var vr := _view_rect().grow(64.0)
	var x0 := floori(vr.position.x / TILE)
	var y0 := floori(vr.position.y / TILE)
	var x1 := ceili(vr.end.x / TILE)
	var y1 := ceili(vr.end.y / TILE)
	var step := 2
	while (x1 - x0) / step > 34:
		step += 1
	var wind: Vector2 = Game.sky.wind_vector()
	var wd := wind.normalized() if wind.length() > 0.01 else Vector2(1, 0.2)
	var drift: Vector2 = wd * _t * 0.55 + Vector2(_t * 0.25, 0.0)
	var strength := 0.20 * (1.0 - dark)
	for cy in range(y0, y1, step):
		for cx in range(x0, x1, step):
			var n := _cloud.get_noise_2d(float(cx) - drift.x, float(cy) - drift.y)
			var a := smoothstep(0.12, 0.5, n) * strength
			if a < 0.012:
				continue
			var sc := Color(0.06, 0.09, 0.2, a)
			# a block only where the whole block is ground; on a ragged coast, cell by cell,
			# so the shadow never spills over open sky
			var whole := true
			for oy in step:
				for ox in step:
					if not gen.is_land(Vector2i(cx + ox, cy + oy)):
						whole = false
			if whole:
				shade.draw_rect(Rect2(Vector2(cx, cy) * TILE, Vector2(step, step) * TILE), sc)
			else:
				for oy in step:
					for ox in step:
						if gen.is_land(Vector2i(cx + ox, cy + oy)):
							shade.draw_rect(Rect2(Vector2(cx + ox, cy + oy) * TILE, Vector2(TILE, TILE)), sc)

# ------------------------------------------------------------------ drawing: glow layer
func _draw_glow() -> void:
	if not _near:
		return
	var vr := _view_rect().grow(96.0)
	var dark := _dark()
	var lit := smoothstep(0.35, -0.25, Game.sky.sun_elevation())
	if lit > 0.02:
		for s in shops:
			var col := Color(String(s["col"])).lerp(Color(1.0, 0.8, 0.5), 0.5)
			for w in s["windows"]:
				var wc: Vector2i = w
				var r := Rect2(Vector2(wc) * TILE, Vector2(TILE, TILE))
				if not vr.intersects(r):
					continue
				var fl := 0.92 + 0.08 * sin(_t * 7.0 + float(wc.x * 3 + wc.y))
				var c1 := col
				c1.a = 0.55 * lit * fl
				glow.draw_rect(r.grow(-5), c1)
				var c2 := col
				c2.a = 0.10 * lit * fl
				glow.draw_rect(r.grow(9), c2)
			var door: Vector2i = s["door"]
			var out: Vector2i = s["out"]
			var pool := (Vector2(door + out) + Vector2(0.5, 0.5)) * TILE
			if vr.has_point(pool):
				for k in 4:
					var cp := col
					cp.a = 0.035 * lit
					glow.draw_circle(pool, 52.0 - float(k) * 10.0, cp)
		for lp in lanterns:
			var lv: Vector2 = lp
			if not vr.has_point(lv):
				continue
			for k in 3:
				var lc := Color(1.0, 0.78, 0.42, 0.10 * lit)
				glow.draw_circle(lv + Vector2(0, 4), 24.0 - float(k) * 7.0, lc)
	# forge sparks and steam glints, always
	for sp in sparks:
		var f: float = float(sp["a"]) / float(sp["life"])
		var pos: Vector2 = sp["p"]
		if vr.has_point(pos):
			glow.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.65, 0.2, (1.0 - f) * 0.9))
	# the sun's warm bounce on the water-side edge of the quay at low sun: a soft rim
	_draw_wayfinding(vr)
	_draw_hover(dark)
	var slot := 0
	for fl in _floaters:
		var fe: Entity = fl["e"]
		if not is_instance_valid(fe) or fe.removed:
			continue
		var ft: float = fl["t"]
		var rise := (1.0 - pow(1.0 - clampf(ft / 1.5, 0.0, 1.0), 2.0)) * 40.0
		var fa := clampf((1.7 - ft) / 0.6, 0.0, 1.0)
		var fc: Color = fl["col"]
		fc.a = fa
		_label(glow, String(fl["text"]), fe.position + Vector2(0, -56 - rise - slot * 18.0), 20, fc)
		slot += 1

func _draw_wayfinding(vr: Rect2) -> void:
	var p: Entity = Game.player
	var show_yard := not yard_seen and yard_front.x >= 0
	if show_yard and Game.fleet != null and Game.fleet.player_ship != null:
		show_yard = false
	if show_yard:
		var pc: Vector2i = p.root_cell()
		if (pc - yard_front).length() < 5.0:
			yard_seen = true
			show_yard = false
	_arrow_fade = move_toward(_arrow_fade, 1.0 if show_yard and _t > 2.5 else 0.0, get_process_delta_time() * 0.8)
	if _arrow_fade > 0.01:
		var target := (Vector2(yard_front) + Vector2(0.5, 0.5)) * TILE
		var bob := sin(_t * 3.0) * 4.0
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var gold := Color(1.0, 0.82, 0.38)
		if vr.has_point(target):
			# a pulsing ring on the step and a bobbing arrow above it
			for k in 3:
				var rc := gold
				rc.a = (0.10 + 0.08 * pulse) * _arrow_fade
				glow.draw_circle(target, 30.0 - float(k) * 7.0, rc)
			var tip := target + Vector2(0, -40 + bob)
			var poly := PackedVector2Array([tip, tip + Vector2(-11, -16), tip + Vector2(-4, -16), tip + Vector2(-4, -30),
				tip + Vector2(4, -30), tip + Vector2(4, -16), tip + Vector2(11, -16)])
			var ac := gold
			ac.a = 0.85 * _arrow_fade
			glow.draw_colored_polygon(poly, ac)
			_label(glow, "THE YARD", tip + Vector2(0, -38), 15, Color(1.0, 0.92, 0.6, _arrow_fade))
		else:
			# off screen: hug the edge of the view and point the way
			var ctr := vr.get_center()
			var half := vr.size * 0.5 - Vector2(74, 74)
			var dir := (target - ctr)
			var dl := dir.length()
			if dl > 1.0:
				var k2 := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
				var pos := ctr + dir * minf(k2, 1.0)
				var nd := dir / dl
				var perp := nd.orthogonal()
				var sz := 15.0 + pulse * 2.0
				var tri := PackedVector2Array([pos + nd * sz, pos - nd * sz * 0.6 + perp * sz * 0.8, pos - nd * sz * 0.6 - perp * sz * 0.8])
				var ec := gold
				ec.a = 0.85 * _arrow_fade
				glow.draw_colored_polygon(tri, ec)
				_label(glow, "THE YARD  %d" % int(dl / TILE), pos - nd * sz * 1.6 + Vector2(0, -6), 14, Color(1.0, 0.92, 0.6, _arrow_fade * 0.9))
	# the notice board gets a small "!" until somebody has been to read it
	if not board_seen and board_cell.x >= 0:
		var pc2: Vector2i = p.root_cell()
		if (pc2 - board_cell).length() < 3.0:
			board_seen = true
		else:
			var bp := (Vector2(board_cell) + Vector2(0.5, 0.5)) * TILE
			if vr.has_point(bp):
				var bo := sin(_t * 2.6) * 3.0
				var ba := 0.5 + 0.35 * sin(_t * 2.6)
				glow.draw_circle(bp + Vector2(0, -34 + bo), 10.0, Color(1.0, 0.85, 0.4, 0.12 * ba))
				_label(glow, "!", bp + Vector2(0, -28 + bo), 20, Color(1.0, 0.88, 0.45, 0.9))

func _label(node: Node2D, text: String, at: Vector2, size: int, col: Color) -> void:
	var f: Font = UITheme.font if UITheme.font != null else ThemeDB.fallback_font
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at - Vector2(w * 0.5, 0)
	node.draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.8))
	node.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ------------------------------------------------------------------ hover highlight
func _hovered() -> Entity:
	if Game.view == null:
		return null
	var hc: Vector2i = Game.view.hover_cell
	if hc.x < 0:
		return null
	for x in Game.at(hc):
		if x.has_c(&"vendor") or x.has_c(&"noticeboard") or x.has_c(&"shipyard"):
			return x
	# a person is drawn up to a tile above their feet; be kind to the mouse
	for x in Game.at(hc + Vector2i(0, 1)):
		if x.has_c(&"vendor"):
			return x
	return null

func _draw_hover(dark: float) -> void:
	if _hover_e == null or not is_instance_valid(_hover_e) or _hover_e.removed:
		return
	var e: Entity = _hover_e
	var r := Rect2(Vector2(e.cell) * TILE, Vector2(TILE, TILE))
	if e.has_c(&"mob"):
		r = Rect2(e.position - Vector2(16, 32), Vector2(TILE, TILE))
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var col := Color(1.0, 0.86, 0.45)
	var hint := "click to trade"
	if e.has_c(&"noticeboard"):
		hint = "click to read"
	elif e.has_c(&"shipyard"):
		hint = "click to draw a hull"
	var c1 := col
	c1.a = 0.12 + 0.07 * pulse
	glow.draw_rect(r.grow(3.0), c1)
	var L := 8.0
	var g := r.grow(4.0 + pulse * 2.0)
	var cc := col
	cc.a = 0.9
	for cn in [[g.position, Vector2(1, 1)], [g.position + Vector2(g.size.x, 0), Vector2(-1, 1)],
			[g.position + Vector2(0, g.size.y), Vector2(1, -1)], [g.end, Vector2(-1, -1)]]:
		var pp: Vector2 = cn[0]
		var sg: Vector2 = cn[1]
		glow.draw_line(pp, pp + Vector2(L * sg.x, 0), cc, 2.0)
		glow.draw_line(pp, pp + Vector2(0, L * sg.y), cc, 2.0)
	_label(glow, hint, Vector2(r.get_center().x, r.position.y - 8.0 - pulse * 2.0), 13, Color(1.0, 0.94, 0.7, 0.95))

# ------------------------------------------------------------------ townsfolk
## A few people who are going somewhere. They use the same bodies as everyone else, walk
## on a plain breadth-first route, and are tagged protected like every soul in a port.
const BARKS_DOCK := ["Mind your backs!", "Heave, then!", "That one is not ours.", "Two more and we break.", "Watch the rope.", "Whose crate is this?"]
const BARKS_TOWN := ["Morning.", "Lovely wind.", "Is the Yard open?", "Mind the step.", "Fine day for it.", "Late again, late again.", "Have you tried the Exchange?", "Skiffs. Everybody wants a skiff."]

func _tick_walkers(delta: float, pc: Vector2i) -> void:
	if _walkers.is_empty() and _walker_t > 1.5 and not _fronts.is_empty():
		_spawn_walkers(pc)
	var i := _walkers.size() - 1
	while i >= 0:
		var w: Dictionary = _walkers[i]
		var e: Entity = w["e"]
		if not is_instance_valid(e) or e.removed:
			_walkers.remove_at(i)
		else:
			_drive(w, e, delta, pc)
		i -= 1

func _spawn_walkers(pc: Vector2i) -> void:
	var cands: Array = []
	for f in _fronts:
		cands.append(f["cell"])
	for n in WALKERS:
		var cell := Vector2i(-1, -1)
		# start off-screen if we can, so they arrive rather than appear
		for tries in 12:
			var c: Vector2i = cands[_rng.randi() % cands.size()]
			if _stand_ok(c) and (c - pc).length() > 16.0:
				cell = c
				break
		if cell.x < 0:
			for c2 in cands:
				if _stand_ok(c2) and (c2 - pc).length() > 6.0:
					cell = c2
					break
		if cell.x < 0:
			continue
		var dock := n % 2 == 0
		var who := Crew.spawn_human("assistant", cell, {"name": Hub._person_name(_rng), "appearance": Jobs.random_appearance(_rng),
			"pronoun": ["they", "she", "he"][_rng.randi() % 3]})
		if who == null:
			continue
		who.remove_comp(&"brain")
		who.tags["protected"] = true
		who.tags["no_smalltalk"] = true
		who.tags["portlife"] = true
		Hub._dress_keeper(who, "shipwright" if dock else "quartermaster")
		who.display_name = who.display_name + (", dockhand" if dock else "")
		_walkers.append({"e": who, "dock": dock, "path": [], "wait": _rng.randf_range(0.2, 2.0), "stuck": 0,
			"bark": _rng.randf_range(8.0, 20.0), "care": 0.0})

func _stand_ok(c: Vector2i) -> bool:
	if not Game.map.inb(c) or not Game.map.is_passable(c) or not Falling.supported(c):
		return false
	var a := Game.map.area_at(c)
	if a != null and a.room_kind == "shop":
		return false
	return true

func _drive(w: Dictionary, e: Entity, delta: float, pc: Vector2i) -> void:
	w["care"] = float(w["care"]) - delta
	if float(w["care"]) <= 0.0:
		w["care"] = 45.0
		var nd: CNeeds = e.c(&"needs")
		if nd != null:
			nd.nutrition = 85.0
			nd.hydration = 85.0
			nd.energy = 85.0
	var m: CMob = e.c(&"mob")
	if m == null:
		return
	# a bark, now and then, to someone within earshot
	w["bark"] = float(w["bark"]) - delta
	if float(w["bark"]) <= 0.0:
		w["bark"] = _rng.randf_range(18.0, 40.0)
		if (e.cell - pc).length() < 9.0:
			var pool: Array = BARKS_DOCK if bool(w["dock"]) else BARKS_TOWN
			m.say(pool[_rng.randi() % pool.size()])
	if m.moving:
		return
	var path: Array = w["path"]
	if path.is_empty():
		w["wait"] = float(w["wait"]) - delta
		if float(w["wait"]) > 0.0:
			return
		w["wait"] = _rng.randf_range(2.5, 7.0)
		var goal := _pick_goal(w, e)
		if goal.x < 0:
			return
		w["path"] = _route(e.cell, goal)
		return
	var nxt: Vector2i = path[0]
	if nxt == e.cell:
		path.pop_front()
		return
	var d: Vector2i = nxt - e.cell
	if absi(d.x) + absi(d.y) != 1:
		w["path"] = []
		return
	if m.try_step(d):
		path.pop_front()
		w["stuck"] = 0
	else:
		w["stuck"] = int(w["stuck"]) + 1
		if int(w["stuck"]) > 6:
			w["path"] = []
			w["stuck"] = 0

func _pick_goal(w: Dictionary, e: Entity) -> Vector2i:
	var opts: Array = []
	if bool(w["dock"]) and not _crates.is_empty():
		var cc: Vector2i = _crates[_rng.randi() % _crates.size()]
		for d in Defs.DIRS4:
			if _stand_ok(cc + d):
				opts.append(cc + d)
	else:
		for f in _fronts:
			opts.append(f["cell"])
		if board_cell.x >= 0:
			opts.append(board_cell + Vector2i(0, 1))
	if opts.is_empty():
		return Vector2i(-1, -1)
	for tries in 6:
		var g: Vector2i = opts[_rng.randi() % opts.size()]
		if g != e.cell and _stand_ok(g) and (g - e.cell).length() < 34.0:
			return g
	return Vector2i(-1, -1)

## Plain breadth-first, bounded, over open ground outside the shops.
func _route(from: Vector2i, to: Vector2i) -> Array:
	var came := {from: from}
	var q: Array = [from]
	var head := 0
	while head < q.size() and q.size() < 2600:
		var cur: Vector2i = q[head]
		head += 1
		if cur == to:
			break
		for d in Defs.DIRS4:
			var n: Vector2i = cur + d
			if came.has(n):
				continue
			if n != to and not _stand_ok(n):
				continue
			if n == to and (not Game.map.inb(n) or not Game.map.is_passable(n)):
				continue
			came[n] = cur
			q.append(n)
	if not came.has(to):
		return []
	var path: Array = []
	var at: Vector2i = to
	while at != from:
		path.append(at)
		at = came[at]
	path.reverse()
	return path
