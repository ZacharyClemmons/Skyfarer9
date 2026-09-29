class_name HoldShots extends Node
## --holdshots=DIR (with --autotest, needs a window): a line-up of people holding items in
## both hands, facing each way, screenshotted close up. For judging in-hand sprites.

var dir := ""
var items: Array = [] # every item proto with a sprite (filled in _run)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await _wait(0.5)
	var p: Entity = Game.player
	if p == null:
		get_tree().quit()
		return
	for m in Game.all_with(&"brain"):
		m.remove_comp(&"brain")
	if items.is_empty():
		for id in Proto.P:
			var comps: Dictionary = Proto.P[id].get("comps", {})
			if comps.has("item") and not comps.has("clothing") and not id.begins_with("blood") and not id.begins_with("organ_"):
				items.append(id)
		items.sort()
	Game.hud.root.visible = false
	Game.lighting.full_bright = true
	var map := Game.map
	# find an open 8x5 patch of floor
	var origin := Vector2i(-1, -1)
	for y in range(10, 200, 3):
		for x in range(10, 200, 3):
			var c := Vector2i(x, y)
			var ok := true
			for dx in range(0, 9):
				for dy in range(0, 5):
					var n: Vector2i = c + Vector2i(dx, dy)
					if not map.inb(n) or not map.is_outdoor(n) or not map.is_passable(n) or not Game.at(n).is_empty():
						ok = false
			if ok:
				origin = c
				break
		if origin.x >= 0:
			break
	if origin.x < 0:
		print("HOLDSHOTS: no room")
		get_tree().quit()
		return
	var mobs := Game.all_with(&"mob").filter(func(m): return m != p)
	var page := 0
	var k := 0
	while k < items.size():
		# 4 people per page (one per facing), each with two items
		var used := []
		for f in 4:
			if k >= items.size():
				break
			var who: Entity = mobs[(page * 4 + f) % mobs.size()]
			var cell := origin + Vector2i(1 + f * 2, 2)
			for x in Game.at(cell).duplicate():
				if x.has_c(&"item"):
					x.destroy()
			who.place(cell)
			var inv: CInventory = who.c(&"inv")
			for hi2 in 2:
				if inv.hands[hi2]:
					inv.hands[hi2].destroy()
					inv.hands[hi2] = null
			for hi in 2:
				if k < items.size():
					var it := Proto.spawn(items[k], cell)
					inv.put_in_hands(it, hi)
					k += 1
			who.c(&"mob").face([Defs.DIR_S, Defs.DIR_E, Defs.DIR_N, Defs.DIR_W][f])
			used.append(who)
		p.place(origin + Vector2i(4, 2))
		p.visible = false
		Game.view.zoom_level = 4.0
		Game.view.camera.position = Entity.cell_to_pos(origin + Vector2i(4, 2)) + Vector2(0, -16)
		Game.view.camera.reset_smoothing()
		await _wait(1.5 if page == 0 else 0.5)
		await _shot("page%d" % page, used)
		for who in used:
			who.place(origin + Vector2i(8, 0))
		page += 1
	print("HOLDSHOTS DONE")
	get_tree().quit()

func _shot(name: String, used: Array) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	# crop to the line-up, with the item names underneath
	var vp := get_viewport().get_visible_rect().size
	var xf := get_viewport().get_canvas_transform()
	var a: Vector2 = xf * (used[0].position + Vector2(-40, -70))
	var b: Vector2 = xf * (used[-1].position + Vector2(40, 30))
	var r := Rect2i(Vector2i(clampi(int(a.x), 0, int(vp.x) - 1), clampi(int(a.y), 0, int(vp.y) - 1)), Vector2i.ZERO)
	r.end = Vector2i(clampi(int(b.x), 1, int(vp.x)), clampi(int(b.y), 1, int(vp.y)))
	if r.size.x > 10 and r.size.y > 10:
		img = img.get_region(r)
	img.save_png("%s/%s.png" % [dir, name])
	var names := []
	for w in used:
		var inv: CInventory = w.c(&"inv")
		names.append("%s+%s" % [inv.hands[0].proto if inv.hands[0] else "-", inv.hands[1].proto if inv.hands[1] else "-"])
	print("HOLDSHOTS %s: %s" % [name, ", ".join(names)])

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame
