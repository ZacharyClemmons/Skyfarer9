class_name ShowcaseShots extends Node
## --showcase=DIR (with --autotest, not headless): fills a room with each visible gas and puts
## the player in a bad way, then screenshots the gas overlays and the status alerts.

var dir := ""
var n := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var p: Entity = Game.player
	var room: Dictionary = Game.world.get_parent().mapgen.room_of("cafeteria")
	var a: Area = room["area"]
	var cells: Array = a.cells.filter(func(c): return Game.map.is_passable(c))
	var mid: Vector2i = a.center
	p.place(mid)
	Game.lighting.full_bright = true
	Game.view.zoom_level = 2.0
	# four patches, left to right: plasma, nitrous oxide, water vapour, smoke
	var at: AtmosSystem = Game.atmos
	var gases := [Defs.G_PLASMA, Defs.G_N2O, Defs.G_H2O, Defs.G_SMOKE]
	for k in 4:
		var cx := mid.x - 9 + k * 5
		for y in range(mid.y - 3, mid.y + 4):
			for x in range(cx - 2, cx + 3):
				var c := Vector2i(x, y)
				if Game.map.inb(c) and not Game.map.is_solid_turf(c):
					var i := Game.map.idx(c)
					var falloff := 1.0 - (absf(x - cx) + absf(y - mid.y)) / 7.0
					at.gas[gases[k]][i] += 14.0 * maxf(0.1, falloff)
					at.dirty_visual[i] = true
	# keep the player breathing through it for the alerts shot
	p.c(&"health").body_temp = 255.0
	p.c(&"health").bleeding = 0.5
	p.c(&"health").stun(4.0)
	await _wait(0.6)
	var gl: GasLayer = Game.view.gas_layer
	var cnt := [0, 0, 0, 0]
	var mx := [0.0, 0.0, 0.0, 0.0]
	for y in Game.map.h:
		for x in Game.map.w:
			var v := gl.img.get_pixel(x, y)
			for ch in 4:
				if v[ch] > 0.01:
					cnt[ch] += 1
					mx[ch] = maxf(mx[ch], v[ch])
	var h2o := 0.0
	for i in Game.map.w * Game.map.h:
		h2o = maxf(h2o, at.gas[Defs.G_H2O][i])
	print("DBG counts ", cnt, " max ", mx, " maxh2o ", h2o, " tex ", gl.texture.get_size(), " scale ", gl.scale, " pos ", gl.global_position)
	print("DBG vis ", gl.is_visible_in_tree(), " z ", gl.z_index, " root z ", Game.view.gas_root.z_index, " mat ", gl.material, " tex ", gl.texture, " player ", p.cell, " cam ", Game.view.camera.global_position, " mid ", mid)
	Game.view.camera.position = p.position
	Game.view.camera.reset_smoothing()
	gl.mat.set_shader_parameter("debug_mode", 1)
	await _shot("dbg_raw")
	gl.mat.set_shader_parameter("debug_mode", 0)
	await _shot("gases_a")
	await _wait(0.9)
	await _shot("gases_b")
	Game.lighting.full_bright = false
	await _wait(0.5)
	await _shot("gases_lit")
	print("SHOWCASE DONE: %d shots" % n)
	get_tree().quit()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/show_%02d_%s.png" % [dir, n, nm])
	n += 1

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame
