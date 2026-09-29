class_name DistantLife extends Node2D
## Skywhales and far-off hulls, drifting through the backdrop.
##
## They live in screen space between the sky shader and the world, and they shift with the
## camera at a small fraction of its speed, so they read as very far away and give a
## standing player something to watch. Each is a flat silhouette tinted toward the haze,
## which is all a thing needs to be at that distance.

const W_MARGIN := 420.0

var _t := 0.0
var _things: Array = []
var _cam := Vector2.ZERO
var _top := Color(0.3, 0.45, 0.7)
var _bot := Color(0.6, 0.75, 0.9)
var _night := 0.0
var _warm := 0.0

func _init() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in 6:
		var whale := i < 2
		_things.append({
			"whale": whale,
			"x0": r.randf(),
			"y": r.randf_range(0.14, 0.52) if whale else r.randf_range(0.22, 0.6),
			"par": r.randf_range(0.012, 0.03) if whale else r.randf_range(0.02, 0.05),
			"speed": (r.randf_range(4.0, 8.0) if whale else r.randf_range(7.0, 13.0)) * (1.0 if r.randf() < 0.5 else -1.0),
			"scale": r.randf_range(0.8, 1.15) if whale else r.randf_range(0.5, 0.9),
			"ph": r.randf() * TAU,
		})

func tick(delta: float, cam: Vector2, sky) -> void:
	_t += delta
	_cam = cam
	if sky != null:
		_top = sky.sky_top()
		_bot = sky.sky_bottom()
		_night = clampf(-sky.sun_elevation(), 0.0, 1.0)
		var d: float = sky.day_t
		_warm = maxf(smoothstep(0.17, 0.30, d) * (1.0 - smoothstep(0.36, 0.5, d)), smoothstep(0.62, 0.72, d) * (1.0 - smoothstep(0.80, 0.88, d)))
	queue_redraw()

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_impl()
	if WorldView.rperf:
		WorldView.pt("distant_draw", t0)

func _draw_impl() -> void:
	var vp := get_viewport_rect().size
	var tint := _bot.lerp(_top, 0.55).darkened(0.30 + _night * 0.2)
	tint = tint.lerp(Color(0.85, 0.5, 0.35), _warm * 0.25)
	for th in _things:
		var span := vp.x + W_MARGIN * 2.0
		var x := fposmod(float(th["x0"]) * span + _t * float(th["speed"]) - _cam.x * float(th["par"]), span) - W_MARGIN
		var y := float(th["y"]) * vp.y - _cam.y * float(th["par"]) * 0.5 + sin(_t * 0.35 + float(th["ph"])) * 4.0
		if y < -80.0 or y > vp.y + 80.0:
			continue
		var dir := 1.0 if float(th["speed"]) > 0.0 else -1.0
		var s: float = th["scale"]
		var col := tint
		col.a = 0.62 - _night * 0.22
		draw_set_transform(Vector2(x, y), sin(_t * 0.3 + float(th["ph"])) * 0.03, Vector2(dir * s, s))
		if bool(th["whale"]):
			_whale(col)
		else:
			_hull(col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static var _whale_body := PackedVector2Array()
static var _hull_bag := PackedVector2Array()

func _whale(col: Color) -> void:
	# body: a long teardrop, blunt at the head (+x); the outline never changes, so it is
	# built once
	if _whale_body.is_empty():
		var pts := PackedVector2Array()
		for i in 21:
			var f := float(i) / 20.0
			var px := lerpf(-70.0, 70.0, f)
			var prof := sin(pow(f, 0.7) * PI)
			var ry := 24.0 * prof * (1.0 - 0.25 * f)
			pts.append(Vector2(px, -ry - 2.0))
		for i in range(20, -1, -1):
			var f2 := float(i) / 20.0
			var px2 := lerpf(-70.0, 70.0, f2)
			var prof2 := sin(pow(f2, 0.7) * PI)
			pts.append(Vector2(px2, 26.0 * prof2 * (1.0 - 0.15 * f2) - 2.0))
		_whale_body = pts
	draw_colored_polygon(_whale_body, col)
	# tail and flukes; the tail beats slowly
	var beat := sin(_t * 0.9) * 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(-66, -3), Vector2(-92, -4 + beat * 0.5), Vector2(-104, -18 + beat),
		Vector2(-98, -2 + beat * 0.5), Vector2(-104, 14 + beat), Vector2(-90, 0 + beat * 0.5)]), col)
	# a long fin trailing under the belly
	draw_colored_polygon(PackedVector2Array([Vector2(20, 18), Vector2(-4, 36 + beat * 0.3), Vector2(2, 17)]), col)
	var lc := col.lightened(0.18)
	lc.a = col.a * 0.6
	draw_line(Vector2(-40, 12), Vector2(50, 12), lc, 3.0)
	draw_circle(Vector2(52, -6), 2.0, col.darkened(0.5))

func _hull(col: Color) -> void:
	# a gasbag, a keel under it and a pennant on a spar
	if _hull_bag.is_empty():
		var bag := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			bag.append(Vector2(cos(a) * 46.0, sin(a) * 15.0 - 20.0))
		_hull_bag = bag
	draw_colored_polygon(_hull_bag, col)
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(20, 10), Vector2(-22, 10)]), col.darkened(0.15))
	draw_line(Vector2(-18, -6), Vector2(-14, 0), col, 1.5)
	draw_line(Vector2(18, -6), Vector2(14, 0), col, 1.5)
	draw_line(Vector2(-28, -18), Vector2(-40, -30), col, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -30), Vector2(-54, -27 + sin(_t * 3.0) * 2.0), Vector2(-40, -24)]), col)
	if _night > 0.4:
		draw_circle(Vector2(0, 5), 1.6, Color(1.0, 0.85, 0.5, 0.8 * _night))
		draw_circle(Vector2(-10, 5), 1.4, Color(1.0, 0.85, 0.5, 0.7 * _night))
