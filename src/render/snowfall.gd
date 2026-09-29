class_name Snowfall extends Node2D
## CPU snowfall around the camera. Flakes only render over outdoor tiles so it never
## snows indoors; wind and blizzard intensity come from the event director.

const MAX := 900
var px := PackedFloat32Array()
var py := PackedFloat32Array()
var pz := PackedFloat32Array() # depth 0..1 (parallax/size)
var ph := PackedFloat32Array()
var intensity := 0.35
var wind := Vector2(-18, 0)
var tex: Texture2D
var r_small: Rect2
var r_mid: Rect2
var r_big: Rect2
var r_streak: Rect2

func _ready() -> void:
	tex = Gfx.tex("fx")
	r_small = Gfx.region("fx", "flake_0")
	r_mid = Gfx.region("fx", "flake_1")
	r_big = Gfx.region("fx", "flake_2")
	r_streak = Gfx.region("fx", "streak")
	px.resize(MAX)
	py.resize(MAX)
	pz.resize(MAX)
	ph.resize(MAX)
	for i in MAX:
		px[i] = randf() * 1400.0
		py[i] = randf() * 900.0
		pz[i] = randf()
		ph[i] = randf() * TAU
	z_index = 5

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_proc(delta)
	if WorldView.rperf:
		WorldView.pt("snow_proc", t0)

func _proc(delta: float) -> void:
	var cam: Camera2D = Game.view.camera if Game.view else null
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom * 0.5 + Vector2(64, 64)
	var w := half.x * 2.0
	var h := half.y * 2.0
	var t := Game.time
	# only the flakes that are drawn need to move (the rest are re-randomised by the wrap)
	var live := int(MAX * clampf(intensity, 0.0, 1.0))
	for i in live:
		var z := pz[i]
		var fall := lerpf(22.0, 60.0, z) * (1.0 + intensity)
		px[i] += (wind.x * lerpf(0.5, 1.3, z) + sin(t * 1.3 + ph[i]) * 6.0) * delta
		py[i] += (fall + wind.y) * delta
		px[i] = fposmod(px[i], w)
		py[i] = fposmod(py[i], h)
	position = center - half
	queue_redraw()

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_impl()
	if WorldView.rperf:
		WorldView.pt("snow_draw", t0)

func _draw_impl() -> void:
	if Game.map == null:
		return
	var map := Game.map
	var n := int(MAX * clampf(intensity, 0.0, 1.0))
	var storm := intensity > 0.75
	if TerrainChunk._tf.is_empty():
		TerrainChunk._init_tables()
	var tf := TerrainChunk._tf
	var turf := map.turf
	var mw := map.w
	var mh := map.h
	for i in n:
		var wx := position.x + px[i]
		var wy := position.y + py[i]
		var tx := int(wx) / Defs.TILE
		var ty := int(wy) / Defs.TILE
		if wx < 0.0 or wy < 0.0 or tx >= mw or ty >= mh or (tf[turf[ty * mw + tx]] & Defs.F_OUTDOOR) == 0:
			continue
		var z := pz[i]
		var a := lerpf(0.35, 0.95, z)
		if storm and z > 0.6:
			var ang := atan2(60.0 + wind.y, wind.x)
			draw_set_transform(Vector2(px[i], py[i]), ang, Vector2(0.6 + z * 0.6, 1.0))
			draw_texture_rect_region(tex, Rect2(Vector2(-16, -4), Vector2(32, 8)), r_streak, Color(1, 1, 1, a * 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var r := r_small if z < 0.45 else (r_mid if z < 0.85 else r_big)
		draw_texture_rect_region(tex, Rect2(Vector2(px[i], py[i]) - Vector2(4, 4), Vector2(8, 8)), r, Color(1, 1, 1, a))
