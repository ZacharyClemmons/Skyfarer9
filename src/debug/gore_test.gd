class_name GoreTest extends Node
## --goretest=DIR (with --autotest): how often tg dismemberment happens with real weapons
## through Combat.melee, and screenshots of blood, severed limbs and gibs (needs a window,
## e.g. xvfb-run).

var dir := ""
var n := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await _wait(1.0)
	var p: Entity = Game.player
	for m in Game.all_with(&"brain"):
		m.remove_comp(&"brain")
		Quirks.remove_all(m) # random crew quirks would skew the checks
	var inv: CInventory = p.c(&"inv")
	var spot := _open_spot(p)
	p.place(spot)
	var vc := spot + Vector2i(1, 0)
	# --- odds: hits to take an arm off (aimed at it), victim kept alive
	for w in [["fireaxe", true], ["knife_cleaver", false], ["knife_kitchen", false], ["spear", true], ["toolbox", false], ["baseball_bat", false], ["", false]]:
		var results := []
		for trial in 10:
			var v := _victim(vc)
			var h: CHealth = v.c(&"health")
			_fresh(h)
			for it in inv.hands.duplicate():
				if it:
					inv.drop(it)
					it.destroy()
			var item: Entity = null
			if w[0] != "":
				item = Proto.spawn(w[0], p.cell)
				inv.put_in_hands(item, inv.active)
				if w[1]:
					item.attack_self(p) # wield
			p.c(&"mob").intent = "harm"
			p.c(&"mob").aim_at_zone("r_arm")
			var hits := 0
			while hits < 80 and not h.missing.has("r_arm"):
				p.c(&"mob").next_attack = 0.0
				# keep them alive and standing: heal everything but the arm
				h.oxy = 0.0
				h.tox = 0.0
				var arm := Body.part_damage(h, "r_arm")
				h.brute = arm
				h.burn = 0.0
				h.dead = false
				h.blood_volume = Body.BLOOD_VOLUME_NORMAL
				h.status.clear()
				Combat.melee(p, v, item)
				hits += 1
			results.append(hits if h.missing.has("r_arm") else -1)
			for lim in Game.all_with(&"item"):
				if lim.proto == "severed_limb":
					lim.destroy()
		var got := results.filter(func(x): return x > 0)
		var avg := 0.0
		for x in got:
			avg += x
		avg = avg / maxf(1.0, got.size())
		print("GORE %s%s: arm off in %d/10 trials, avg %.1f swings (%s)" % [w[0] if w[0] != "" else "fists", " (wielded)" if w[1] else "", got.size(), avg, results])
	# --- pictures
	var v2 := _victim(vc)
	var h2: CHealth = v2.c(&"health")
	_fresh(h2)
	Game.view.zoom_level = 3.0
	Body.apply_wound(h2, "chest", "avulsion", Vector2i(1, 0))
	Body.apply_wound(h2, "l_arm", "cavity", Vector2i(1, 0))
	await _wait(6.0)
	await _shot("bleeding")
	# dragged along the floor
	v2.c(&"mob").pulled_by = null
	h2.knockdown(30.0)
	p.c(&"mob").start_pulling(v2)
	for i in 4:
		p.c(&"mob").try_step(Vector2i(-1, 0))
		await _wait(0.6)
	await _shot("drag_trail")
	Body.dismember(h2, "r_arm", "slash")
	Body.dismember(h2, "l_leg", "blunt")
	await _wait(1.0)
	await _shot("dismembered")
	# standing, facing us, close up: the stumps and bleed overlays on the doll
	p.c(&"mob").stop_pulling()
	h2.missing.erase("l_leg") # one leg short floors you (tg), so give it back for the picture
	h2.brute = 0.0
	h2.oxy = 0.0
	h2.dead = false
	h2.status.clear()
	h2.blood_volume = Body.BLOOD_VOLUME_NORMAL
	v2.place(p.cell + Vector2i(1, 0))
	v2.c(&"mob").moving = false
	v2.position = Entity.cell_to_pos(v2.cell)
	v2.c(&"mob").face(Defs.DIR_S)
	v2.c(&"mob").refresh_doll()
	Game.view.zoom_level = 5.0
	await _wait(1.5)
	print("GORE standing: lying=%s ko=%s hp=%.0f legs=%d stam=%s status=%s missing=%s rest=%s" % [h2.lying(), h2.knocked_out(), h2.health(), Body.usable_legs(h2), h2.stamcrit, h2.status.keys(), h2.missing.keys() if h2.missing is Dictionary else h2.missing, h2.resting])
	await _shot("dismembered_standing")
	v2.c(&"mob").face(Defs.DIR_N)
	await _wait(1.0)
	await _shot("dismembered_back")
	Game.view.zoom_level = 3.0
	Body.gib(h2)
	await _wait(1.0)
	await _shot("gibbed")
	# hallucinations the player sees (tg modules/hallucination)
	var ph: CHealth = p.c(&"health")
	Game.view.zoom_level = 2.0
	for id in ["fake_flood", "body", "body", "hazard", "eyes_in_dark", "bolts", "blood_flow", "chat", "message"]:
		Hallucinations.cause(ph, id)
	await _wait(8.0)
	await _shot("hallucinations")
	Traumas.gain(ph, "color_blindness")
	await _wait(1.0)
	await _shot("achromatopsia")
	print("GORE DONE: %d shots" % n)
	get_tree().quit()

func _fresh(h: CHealth) -> void:
	h.wounds.clear()
	h.gauze.clear()
	h.missing.clear()
	h.limb.clear()
	h.limb_burn.clear()
	h.limb_maxed.clear()
	h.brute = 0.0
	h.burn = 0.0
	h.oxy = 0.0
	h.dead = false
	h.eviscerated = false
	h.status.clear()
	h.blood_volume = Body.BLOOD_VOLUME_NORMAL

func _victim(at: Vector2i) -> Entity:
	for m in Game.all_with(&"mob"):
		if m != Game.player and not m.removed and not m.get_meta("gibbed", false):
			m.place(at)
			return m
	return null

func _open_spot(p: Entity) -> Vector2i:
	for r in range(0, 30):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var c := p.cell + Vector2i(dx, dy)
				var ok := true
				for k in range(-5, 6):
					for j in range(-2, 3):
						var cc := c + Vector2i(k, j)
						if not Game.map.inb(cc) or Game.map.blocks_move_static(cc) or Game.map.dense_count[Game.map.idx(cc)] > 0:
							ok = false
				if ok:
					return c
	return p.cell

func _shot(name: String) -> void:
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%02d_%s.png" % [dir, n, name])
	n += 1

func _wait(sec: float) -> void:
	var until := Game.time + sec
	while Game.time < until:
		await get_tree().process_frame
