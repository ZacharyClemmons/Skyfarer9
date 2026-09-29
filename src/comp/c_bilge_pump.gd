class_name CBilgePump extends Component
## The pump below decks. Working it lowers the bilge; caulking with a plank closes a seam.
## Neither is instant, because the point is that you are down there doing it while
## whatever is going on upstairs carries on without you.

func key() -> StringName:
	return &"bilge_pump"

func _ship() -> Airship:
	return Game.fleet.get_ship(int(e.tags.get("lower_ship", -1))) if Game.fleet != null else null

func examine(_user: Entity, lines: Array) -> void:
	var sh := _ship()
	if sh == null:
		return
	lines.append("The bilge is %d%% full and the seams are %s." % [int(sh.bilge * 100.0),
		"sound" if sh.seam < 0.05 else ("weeping" if sh.seam < 0.5 else "sprung")])

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Work the pump", "priority": 26, "cb": func(): pump(user)})
	out.append({"name": "Caulk a seam (uses planks)", "priority": 24, "cb": func(): caulk(user)})

func attack_hand(user: Entity) -> bool:
	pump(user)
	return true

func pump(user: Entity) -> void:
	var sh := _ship()
	if sh == null:
		return
	if sh.bilge <= 0.01:
		Game.tell(user, "The bilge is dry. The pump clanks on nothing.", "info")
		return
	sh.bilge = maxf(0.0, sh.bilge - 0.07)
	Sfx.play("ratchet", e.cell, 0.7)
	Game.tell(user, "You throw your weight on the pump handle. Water gurgles overboard — bilge %d%%." % int(sh.bilge * 100.0), "info")

func caulk(user: Entity) -> void:
	var sh := _ship()
	if sh == null:
		return
	if sh.seam <= 0.02:
		Game.tell(user, "The seams are tight. Nothing to caulk.", "info")
		return
	var inv: CInventory = user.c(&"inventory")
	var plank: Entity = inv.find_item(func(it): return it.proto == "sheet_wood") if inv != null else null
	if plank == null:
		Game.tell(user, "You need wooden planks to caulk a seam properly.", "warn")
		return
	plank.destroy()
	sh.seam = maxf(0.0, sh.seam - 0.3)
	Sfx.play("wall_hit", e.cell, 0.4)
	Game.tell(user, "You hammer oakum and a plank into the weeping seam. It holds — for now.", "good")
