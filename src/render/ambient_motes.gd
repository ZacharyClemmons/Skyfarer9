class_name AmbientMotes extends Node2D
## Drifting specks of the air: pollen and dust turning in the light by day, fireflies by
## night, and water dripping off the underside of the islands into the sky.
##
## Everything lives in world space (so it slides past as the camera moves, which is what
## makes the air read as a place rather than an overlay) but is wrapped into the visible
## rectangle, so the count is fixed at MOTES and the cost is one draw_rect each.

const MOTES := 46
const DRIPS := 10
const TILE := 32.0

var _seed: Array = []      # [x, y, depth, phase, kind]
var _drips: Array = []     # [pos: Vector2, age: float, life: float]
var _t := 0.0
var _drip_t := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	z_index = 2
	_rng.seed = 1187
	for i in MOTES:
		_seed.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.35, 1.0), _rng.randf() * TAU, _rng.randi() % 4])

func _view_rect() -> Rect2:
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * sz
	return Rect2(a, b - a).abs()

func _process(delta: float) -> void:
	if Game.sky == null or Game.map == null:
		return
	_t += delta
	_drip_t -= delta
	var vr := _view_rect()
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(0.25, 0.7)
		if _drips.size() < DRIPS:
			_try_drip(vr)
	var i := _drips.size() - 1
	while i >= 0:
		_drips[i][1] = float(_drips[i][1]) + delta
		if float(_drips[i][1]) >= float(_drips[i][2]):
			_drips.remove_at(i)
		i -= 1
	queue_redraw()

## A drip forms where island rock hangs over open sky: a void tile with land above it.
func _try_drip(vr: Rect2) -> void:
	for k in 8:
		var c := Vector2i(floori(_rng.randf_range(vr.position.x, vr.end.x) / TILE),
				floori(_rng.randf_range(vr.position.y, vr.end.y) / TILE))
		if not Game.map.inb(c) or not Game.map.inb(c + Vector2i(0, -1)):
			continue
		if Defs.is_void_turf(Game.map.get_turf(c)) and not Defs.is_void_turf(Game.map.get_turf(c + Vector2i(0, -1))):
			var p := Vector2(c) * TILE + Vector2(_rng.randf_range(4.0, 28.0), _rng.randf_range(14.0, 24.0))
			_drips.append([p, 0.0, _rng.randf_range(0.9, 1.5)])
			return

func _draw() -> void:
	if Game.sky == null:
		return
	var vr := _view_rect()
	if vr.size.x <= 0.0:
		return
	var sun: float = Game.sky.sun_elevation()
	var night := clampf(smoothstep(0.05, -0.3, sun), 0.0, 1.0)
	var wind: Vector2 = Game.sky.wind_vector()
	var drift := wind * 6.0 + Vector2(1.5, -2.5)
	for m in _seed:
		var d: float = m[2]
		var ph: float = m[3]
		var kind: int = m[4]
		var x: float = vr.position.x + fposmod(float(m[0]) * vr.size.x + drift.x * d * _t + sin(_t * 0.6 + ph) * 5.0, vr.size.x)
		var y: float = vr.position.y + fposmod(float(m[1]) * vr.size.y + drift.y * d * _t + cos(_t * 0.5 + ph) * 4.0, vr.size.y)
		var p := Vector2(roundf(x), roundf(y))
		if night > 0.5 and kind == 0:
			# a firefly: blinks on a slow private clock, with a faint halo
			var blink := clampf(sin(_t * 1.3 + ph * 3.0) * 2.0, 0.0, 1.0)
			if blink > 0.02:
				var a := blink * night
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.75, 1.0, 0.35, 0.12 * a))
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.95, 1.0, 0.6, 0.85 * a))
		elif night < 0.9:
			var tw := 0.5 + 0.5 * sin(_t * 1.9 + ph * 2.0)
			var a := (0.10 + 0.32 * tw * d) * (1.0 - night)
			var col := Color(1.0, 0.95, 0.75, a) if kind < 2 else Color(1.0, 0.98, 0.9, a * 0.7)
			var s := 2.0 if d > 0.7 else 1.0
			draw_rect(Rect2(p, Vector2(s, s)), col)
	for dr in _drips:
		var f: float = float(dr[1]) / float(dr[2])
		var p: Vector2 = dr[0]
		var fall := f * f * 46.0
		var a := (1.0 - f) * 0.8 if f > 0.15 else f / 0.15 * 0.8
		var q := Vector2(roundf(p.x), roundf(p.y + fall))
		draw_rect(Rect2(q, Vector2(1, 3)), Color(0.72, 0.88, 1.0, a))
		draw_rect(Rect2(q + Vector2(0, 3), Vector2(1, 1)), Color(1, 1, 1, a * 0.6))
