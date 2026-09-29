class_name GlassShots extends Node
## --glassshots=DIR (with --autotest): walks the player up to a window and smashes it with a
## toolbox, screenshotting the attack flick, each crack stage and the shatter as it plays out,
## then a grille being kicked apart. For eyeballing the effects; needs a real window (no
## --headless).

var dir := ""
var n := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var p: Entity = Game.player
	var spot := _window_spot()
	if p == null or spot.is_empty():
		print("GLASSSHOTS: no player or window")
		get_tree().quit()
		return
	var cell: Vector2i = spot["cell"]
	var map := Game.map
	map.set_structure(cell, Defs.S_WINDOW)
	p.place(spot["stand"])
	p.c(&"mob").combat = true
	var inv: CInventory = p.c(&"inv")
	for h in inv.hands.duplicate():
		if h:
			inv.drop(h)
	var tb := Proto.spawn("toolbox", p.cell)
	inv.put_in_hands(tb, inv.active)
	Game.view.zoom_level = 4.0
	await _wait(1.5)
	await _shot("start")
	var stage := 0
	var hits := 0
	while Defs.is_window(map.structure[map.idx(cell)]) and hits < 30:
		p.c(&"mob").next_attack = 0.0
		var last := Structures.max_hp(Defs.S_WINDOW) - map.struct_hp[map.idx(cell)] + 8.2 >= Structures.max_hp(Defs.S_WINDOW)
		Interact.hit_tile(p, tb, cell)
		hits += 1
		if hits == 1:
			await _wait(0.1)
			await _shot("flick")
		if not Defs.is_window(map.structure[map.idx(cell)]):
			await _wait(0.06)
			await _shot("shatter_a")
			await _wait(0.15)
			await _shot("shatter_b")
			await _wait(0.3)
			await _shot("shatter_c")
			await _wait(1.2)
			await _shot("aftermath")
			break
		var cs := Structures.crack_at(cell)
		if cs != stage:
			stage = cs
			await _wait(0.5)
			await _shot("crack%d" % cs)
		elif not last:
			await _wait(0.35)
	# the grille: kick it until it bends
	inv.drop(tb)
	var k := 0
	while map.structure[map.idx(cell)] == Defs.S_GRILLE and k < 40:
		p.c(&"mob").next_attack = 0.0
		Interact.hand_on_tile(p, cell)
		k += 1
		if k == 1:
			await _wait(0.12)
			await _shot("kick")
		await _wait(0.3)
		if map.struct_hp[map.idx(cell)] <= 25.0 and map.structure[map.idx(cell)] == Defs.S_GRILLE and not has_meta(&"half"):
			set_meta(&"half", true)
			await _shot("grille_half")
	await _wait(0.8)
	await _shot("grille_bent")
	print("GLASSSHOTS DONE: %d shots" % n)
	get_tree().quit()

func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/glass_%02d_%s.png" % [dir, n, nm])
	n += 1

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame

func _window_spot() -> Dictionary:
	var map := Game.map
	for i in map.structure.size():
		if not Defs.is_window(map.structure[i]):
			continue
		var c := map.cell_of(i)
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var st: Vector2i = c + d
			if map.is_passable(st) and not map.is_outdoor(st) and Game.at(st).is_empty() and map.area_at(st).id != 0:
				return {"cell": c, "stand": st}
	return {}
