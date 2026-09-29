class_name GenePowers extends RefCounted
## The action buttons genetic mutations grant (tg power_path: /datum/action/cooldown/...).
## Each has tg's cooldown (scaled by the energetic chromosome in setup), and one of:
##   self     cast on yourself at once
##   pointed  arm it, then click a target (tg /spell/pointed, next click)
##   touch    arm it; your next touch on someone delivers it (tg /spell/touch hand item)
##   list     choose someone in view (tg /spell/list_target)
## The HUD draws the player's (Hud action bar); NPCs don't use them.

const DEFS := {
	"echo_focus": {"name": "Echolocation Focus", "desc": "Choose which nearby objects your echolocation highlights.", "cd": 0.0, "kind": "self"},
	"psychic_projection": {"name": "Psychic Projection", "desc": "Twist a target's view and cause rapid gunfire for ten seconds.", "cd": 60.0, "kind": "pointed", "range": 5},
	"psychic_booster": {"name": "Psychic Booster", "desc": "Focus for five seconds, then shoot faster with aim assistance for ten seconds.", "cd": 60.0, "kind": "self"},
	"psychic_wall": {"name": "Psychic Wall", "desc": "Create a three tile barrier that blocks movement and projectiles.", "cd": 30.0, "kind": "self"},
	"thermal_vision": {"name": "Activate Thermal Vision", "desc": "You can see thermal signatures, at the cost of your eyesight.", "cd": 60.0, "kind": "self", "icon": "augmented_eyesight"},
	"snow": {"name": "Create Snow", "desc": "Concentrates cryokinetic forces to create snow, useful for snow-like construction.", "cd": 5.0, "kind": "self", "icon": "snow"},
	"cryo": {"name": "Cryobeam", "desc": "This power fires a frozen bolt at a target.", "cd": 16.0, "kind": "pointed", "range": 9, "icon": "icebeam",
		"active_msg": "You focus your cryokinesis!", "deactive_msg": "You relax."},
	"ash": {"name": "Create Ash", "desc": "Concentrates pyrokinetic forces to create ash, useful for basically nothing.", "cd": 5.0, "kind": "self", "icon": "ash"},
	"pyro": {"name": "Pyrobeam", "desc": "This power fires a heated bolt at a target.", "cd": 30.0, "kind": "pointed", "range": 9, "icon": "firebeam",
		"active_msg": "You focus your pyrokinesis!", "deactive_msg": "You cool down."},
	"adrenaline": {"name": "Adrenaline!", "desc": "Energize yourself, pushing your body to its limits!", "cd": 120.0, "kind": "self", "icon": "adrenaline"},
	"self_amputation": {"name": "Drop a limb", "desc": "Concentrate to make a random limb pop right off your body.", "cd": 10.0, "kind": "self", "icon": "autotomy"},
	"farsight": {"name": "Farsight", "desc": "You can see further than normal.", "cd": 8.0, "kind": "self", "icon": "eye"},
	"fire_breath": {"name": "Fire Breath", "desc": "You breathe a cone of fire directly in front of you.", "cd": 40.0, "kind": "self", "icon": "fireball0"},
	"olfaction": {"name": "Remember the Scent", "desc": "Get a scent off of the item you're currently holding to track it. With an empty hand, you'll track the scent you've remembered.", "cd": 10.0, "kind": "self", "icon": "nose"},
	"telepathy": {"name": "Telepathy", "desc": "Telepathically transmits a message to the target.", "cd": 0.0, "kind": "list", "range": 7, "icon": "r_transmit"},
	"mindread": {"name": "Mindread", "desc": "Read the target's mind.", "cd": 5.0, "kind": "pointed", "range": 7, "icon": "mindread"},
	"tongue_spike": {"name": "Launch spike", "desc": "Shoot your tongue out in the direction you're facing, embedding it and dealing damage until they remove it.", "cd": 1.0, "kind": "self", "icon": "spike"},
	"chem_spike": {"name": "Launch chem spike", "desc": "Shoot your tongue out in the direction you're facing, embedding it for a very small amount of damage. While the other person has the spike embedded, you can transfer your chemicals to them.", "cd": 1.0, "kind": "self", "icon": "spikechem"},
	"send_chems": {"name": "Transfer Chemicals", "desc": "Send all of your reagents into whomever the chem spike is embedded in. One use.", "cd": 0.0, "kind": "self", "icon": "spikechemswap"},
	"shock_touch": {"name": "Shock Touch", "desc": "Channel electricity to your hand to shock people with. Mostly harmless! Mostly...", "cd": 7.0, "kind": "touch", "icon": "zap",
		"draw_msg": "You channel electricity into your hand.", "drop_msg": "You let the electricity from your hand dissipate."},
	"lay_on_hands": {"name": "Mending Touch", "desc": "You can now lay your hands on other people to transfer a small amount of their physical injuries to yourself. For some reason, this power does not play nicely with the undead, or people with strange ideas about morality.", "cd": 12.0, "kind": "touch", "icon": "mending_touch",
		"draw_msg": "You ready your hand to transfer injuries to yourself.", "drop_msg": "You lower your hand."},
	"void_cursed": {"name": "Convoke Void", "desc": "A rare genome that attracts odd forces not usually observed. May sometimes pull you in randomly.", "cd": 60.0, "kind": "self", "icon": "void_magnet"},
	"lay_web": {"name": "Spin Web", "desc": "Spin a web. Only you will be able to traverse your web easily.", "cd": 4.0, "kind": "self", "icon": "lay_web"},
}

## The powers a body has: [{id, mut, cd, ready_t, armed, data}]
static func list_of(e: Entity) -> Array:
	var d: CDna = e.c(&"dna") if e else null
	return d.powers if d else []

static func find(e: Entity, id: String) -> Dictionary:
	for p in list_of(e):
		if p["id"] == id:
			return p
	return {}

## tg grant_power
static func grant(e: Entity, m: Mutation) -> void:
	var pid: String = m.def().get("power", "")
	if pid == "" or not DEFS.has(pid):
		return
	var d: CDna = e.c(&"dna")
	d.powers.append({"id": pid, "mut": m, "cd": DEFS[pid]["cd"], "ready_t": 0.0, "armed": false, "data": {}})
	_hud_changed(e)

static func grant_plain(e: Entity, pid: String, data := {}) -> void:
	var d: CDna = e.c(&"dna")
	if d == null or not find(e, pid).is_empty():
		return
	d.powers.append({"id": pid, "mut": null, "cd": DEFS[pid]["cd"], "ready_t": 0.0, "armed": false, "data": data})
	_hud_changed(e)

static func remove(e: Entity, m: Mutation) -> void:
	var d: CDna = e.c(&"dna")
	if d == null:
		return
	for p in d.powers.duplicate():
		if p["mut"] == m:
			_on_remove(e, p)
			d.powers.erase(p)
	_hud_changed(e)

static func remove_id(e: Entity, pid: String) -> void:
	var d: CDna = e.c(&"dna")
	if d == null:
		return
	for p in d.powers.duplicate():
		if p["id"] == pid:
			_on_remove(e, p)
			d.powers.erase(p)
	_hud_changed(e)

## tg Remove(): what the power undoes when it goes
static func _on_remove(e: Entity, p: Dictionary) -> void:
	match p["id"]:
		"thermal_vision":
			Traits.remove(e, "thermal_vision", "genetic")
		"farsight":
			if p["data"].get("active", false):
				_farsight_view(e, 0)
		"psychic_booster":
			Traits.remove_source(e, "psychic_booster")
		"mindread":
			Traits.remove(e, "mind_reader", "genetic")

## tg mutation/setup: the energetic chromosome scales the cooldown, and each power's own
## coefficients update.
static func setup(e: Entity, m: Mutation) -> void:
	for p in list_of(e):
		if p["mut"] != m:
			continue
		var base: float = DEFS[p["id"]]["cd"]
		p["cd"] = base * m.nrg()
		var dd: Dictionary = p["data"]
		match p["id"]:
			"thermal_vision":
				dd["eye_damage"] = 7.5 * m.sync() * m.pwr()
				dd["duration"] = 30.0 * m.pwr()
			"adrenaline":
				dd["amount"] = 10.0 * m.pwr()
				dd["comedown"] = 7.0 / m.sync()
			"farsight":
				dd["range"] = 1 * (1 if m.pwr() == 1.0 else 3)
			"fire_breath":
				dd["levels"] = 3 if m.pwr() <= 1.0 else 5
				dd["throw"] = 1 if m.pwr() <= 1.0 else 2
			"olfaction":
				dd["sensitivity"] = m.sync()
			"shock_touch":
				dd["stagger"] = m.pwr() > 1.0
			"lay_on_hands":
				dd["power"] = m.pwr()
				dd["sync"] = m.sync()
			"void_cursed":
				dd["curse_mod"] = m.sync()
			"lay_web":
				dd["time"] = 4.0 if m.nrg() == 1.0 else 2.0
			"mindread":
				Traits.add(e, "mind_reader", "genetic")

static func _hud_changed(e: Entity) -> void:
	if e == Game.player:
		Bus.powers_changed.emit()

static func ready(p: Dictionary) -> bool:
	return Game.time >= p["ready_t"]

static func cooldown_left(p: Dictionary) -> float:
	return maxf(0.0, p["ready_t"] - Game.time)

static func _start_cd(p: Dictionary) -> void:
	p["ready_t"] = Game.time + p["cd"]

## tg can_cast_spell: conscious, not mid-transformation or in the void.
static func can_cast(e: Entity, p: Dictionary, feedback := true) -> bool:
	var h: CHealth = e.c(&"health")
	if h == null or h.stat() != CHealth.CONSCIOUS or Traits.has(e, "no_transform"):
		if feedback:
			Game.tell(e, "You can't do that right now!", "warn")
		return false
	if not ready(p):
		if feedback:
			Game.tell(e, "%s isn't ready yet!" % DEFS[p["id"]]["name"], "warn")
		return false
	if Traits.has(e, "antimagic") and p["id"] in ["mindread", "telepathy", "psychic_projection", "psychic_booster", "psychic_wall"]:
		if feedback: Game.tell(e, "Antimagic prevents you from using this power.", "warn")
		return false
	if p["id"] == "psychic_booster" and DoAfter.busy(e): return false
	if p["id"] == "lay_web":
		for x in Game.at(e.cell):
			if x.proto in ["web", "web_genetic"]:
				if feedback:
					Game.tell(e, "There's already a web here.", "warn")
				return false
	return true

## The button was pressed.
static func trigger(e: Entity, pid: String) -> void:
	var p := find(e, pid)
	if p.is_empty():
		return
	var def: Dictionary = DEFS[pid]
	match def["kind"]:
		"pointed", "touch":
			if p["armed"]:
				p["armed"] = false
				Game.tell(e, def.get("deactive_msg", def.get("drop_msg", "You relax.")))
				_hud_changed(e)
				return
			if not can_cast(e, p):
				return
			for other in list_of(e):
				other["armed"] = false
			p["armed"] = true
			Game.tell(e, def.get("active_msg", def.get("draw_msg", "You prepare %s." % def["name"])) + (" [color=#8a9cb0](click a target)[/color]" if def["kind"] == "pointed" else ""))
			_hud_changed(e)
		"list":
			if not can_cast(e, p):
				return
			Bus.ui_open_window.emit("gene_list_target", e)
		_:
			if not can_cast(e, p):
				return
			cast(e, p, e)

## The power armed, if any (the player's next click goes to it).
static func armed(e: Entity) -> Dictionary:
	for p in list_of(e):
		if p["armed"]:
			return p
	return {}

## A click while armed. True = the click was used.
static func click(e: Entity, target: Entity, cell: Vector2i) -> bool:
	var p := armed(e)
	if p.is_empty():
		return false
	var def: Dictionary = DEFS[p["id"]]
	if def["kind"] == "touch":
		if target == null or target == e or not target.has_c(&"health") or not e.adjacent(target):
			return false # a touch power waits for a touch
		p["armed"] = false
		_hud_changed(e)
		if not can_cast(e, p):
			return true
		_touch(e, p, target)
		return true
	# pointed
	var r: int = def.get("range", 7)
	var to := target.root_cell() if target else cell
	if Entity.cells_adjacent(e.cell, to) == false and maxi(absi(to.x - e.cell.x), absi(to.y - e.cell.y)) > r:
		Game.tell(e, "That's too far away!", "warn")
		return true
	p["armed"] = false
	_hud_changed(e)
	if not can_cast(e, p):
		return true
	match p["id"]:
		"cryo", "pyro":
			_beam(e, p, to)
		"psychic_projection":
			if Psyker.visible(e, to) and Psyker.project(e, target): _start_cd(p)
		"mindread":
			if target == null or not target.has_c(&"mob"):
				Game.tell(e, "There's no mind there to read.", "warn")
				return true
			_mindread(e, p, target)
	return true

## tg cast(): the self-cast powers
static func cast(e: Entity, p: Dictionary, _target: Entity) -> void:
	var d: Dictionary = p["data"]
	var h: CHealth = e.c(&"health")
	var inv: CInventory = e.c(&"inv")
	var mb: CMob = e.c(&"mob")
	match p["id"]:
		"psychic_booster":
			Psyker.booster(e, p)
		"echo_focus":
			Bus.ui_open_window.emit("echo_focus", e)
		"psychic_wall":
			_start_cd(p)
			Psyker.wall(e)
		"thermal_vision":
			if Traits.has(e, "thermal_vision"):
				return
			_start_cd(p)
			Traits.add(e, "thermal_vision", "genetic")
			Game.tell(e, "You focus your eyes intensely, as your vision becomes filled with heat signatures.")
			var dmg: float = d.get("eye_damage", 7.5)
			Genetics.after(d.get("duration", 30.0), func():
				if not is_instance_valid(e) or e.removed or not Traits.has_from(e, "thermal_vision", "genetic"):
					return
				Traits.remove(e, "thermal_vision", "genetic")
				Game.tell(e, "You blink a few times, your vision returning to normal as a dull pain settles in your eyes.")
				StatusFx.damage_eyes(e.c(&"health"), dmg))
		"snow", "ash":
			_start_cd(p)
			if p["id"] == "ash":
				Proto.spawn("ash", e.cell) # an effect: it lands at your feet
				return
			var it := Proto.spawn("sheet_snow", e.cell)
			if inv:
				var held: Entity = inv.active_item()
				if held:
					inv.drop(held)
				inv.put_in_hands(it)
		"adrenaline":
			_start_cd(p)
			var amt: float = d.get("amount", 10.0)
			Game.tell(e, "[b]You feel pumped up! It's time to GO![/b]", "bad")
			Chem.affect_mob({"pumpup": amt, "synaptizine": amt, "determination": amt}, e, 1.0)
			var come: float = d.get("comedown", 7.0)
			Genetics.after(25.0, func():
				if not is_instance_valid(e) or e.removed:
					return
				Game.tell(e, "Your adrenaline rush makes way for a bout of nausea and a deep feeling of exhaustion in your muscles.", "bad")
				Chem.affect_mob({"tiring_solution": come, "dizzy_solution": come}, e, 1.0)
				e.c(&"health").set_status_if_lower("dizziness", 10.0))
		"self_amputation":
			_start_cd(p)
			if Traits.has(e, "nodismember"):
				Game.tell(e, "You concentrate really hard, but nothing happens.")
				return
			var parts := []
			for part in ["l_arm", "r_arm", "l_leg", "r_leg"]:
				if not h.missing.has(part):
					parts.append(part)
			if parts.is_empty():
				Game.tell(e, "You can't shed any more limbs!")
				return
			Body.dismember(h, Genetics.rand_pick(parts))
		"farsight":
			_start_cd(p)
			if d.get("active", false):
				_farsight_view(e, 0)
				d["active"] = false
				p["cd"] *= 2.0
			else:
				_farsight_view(e, d.get("range", 1))
				d["active"] = true
				p["cd"] *= 0.5
		"fire_breath":
			_start_cd(p)
			_fire_breath(e, p)
		"olfaction":
			_start_cd(p)
			_olfaction(e, p)
		"tongue_spike", "chem_spike":
			_start_cd(p)
			_tongue_spike(e, p)
		"send_chems":
			_send_chems(e, p)
		"void_cursed":
			_start_cd(p)
			_void(e)
		"lay_web":
			_start_cd(p)
			var at := e.cell
			Game.visible_message(at, "%s begins weaving a web..." % e.display_name)
			DoAfter.start(e, e, d.get("time", 4.0), func(ok):
				if ok and is_instance_valid(e) and e.cell == at:
					var w := Proto.spawn("web_genetic", at)
					w.tags["allowed"] = e.id)
	_hud_changed(e)

# ------------------------------------------------------------------ the powers
## tg /obj/projectile/temp/cryo and /pyro: a bolt to the first thing in the way
static func _beam(e: Entity, p: Dictionary, to: Vector2i) -> void:
	_start_cd(p)
	var cryo: bool = p["id"] == "cryo"
	var path := _line(e.cell, to, 9)
	var hit: Entity = null
	var end := e.cell
	for c in path:
		if Game.map.is_solid_turf(c) or Game.map.blocks_move_static(c):
			break
		end = c
		for x in Game.at(c):
			if x != e and x.has_c(&"health") and not x.c(&"health").dead:
				hit = x
				break
		if hit:
			break
	Fx.beam(e.cell, end, Color(0.55, 0.85, 1.0) if cryo else Color(1.0, 0.45, 0.15))
	Sfx.play("laser", e.cell, 0.5)
	if hit == null:
		if cryo:
			_freeze_turf(end) # tg cryo on_range: freeze_turf
		return
	var hh: CHealth = hit.c(&"health")
	var temp := -350.0 if cryo else 350.0
	# tg temp/on_hit: body temperature moves by temperature, more through less insulation
	var inv: CInventory = hit.c(&"inv")
	var prot := inv.heat_protection() if inv else 0.0
	hh.body_temp = maxf(2.7, hh.body_temp + (1.0 - prot) * temp + temp)
	if cryo:
		hh.set_status("freezing_blast", 5.0)
	else:
		hh.ignite(GeneFx.fire_stacks_time(1.0))
	Game.visible_message(hit.cell, "%s is hit by a %s!" % [hit.display_name, "cryo beam" if cryo else "hot beam"], "bad")

## tg freeze_turf: an icy patch where the cryo bolt ran out
static func _freeze_turf(c: Vector2i) -> void:
	if Game.map.inb(c) and not Game.map.is_solid_turf(c) and Proto.has("decal") and Proto.has("ice_patch"):
		Proto.spawn("ice_patch", c)

static func _line(a: Vector2i, b: Vector2i, max_len: int) -> Array:
	var out := []
	var d := Vector2(b - a)
	if d == Vector2.ZERO:
		return out
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	var dir := d / float(steps)
	for i in range(1, max_len + 1):
		var c := Vector2i((Vector2(a) + dir * i).round())
		out.append(c)
	return out

## tg fire_breath: a staggered cone of fire straight ahead, 3 wide; the caster is thrown
## back a tile (two with power).
static func _fire_breath(e: Entity, p: Dictionary) -> void:
	var h: CHealth = e.c(&"health")
	var mb: CMob = e.c(&"mob")
	var inv: CInventory = e.c(&"inv")
	var levels: int = p["data"].get("levels", 3)
	# tg before_cast: breathing fire into your own mask
	if inv and inv.worn("mask") != null:
		h.ignite(GeneFx.fire_stacks_time(levels))
		Game.tell(e, "Something in front of your mouth catches fire!", "bad")
	Sfx.play("fire_breath", e.cell, 0.8)
	var fwd: Vector2i = Defs.DIRS4[mb.dir]
	var side := Vector2i(-fwd.y, fwd.x)
	var center := e.cell
	for level in range(1, levels + 1):
		center += fwd
		if Game.map.is_solid_turf(center):
			break
		var cells := [center]
		if level != 1:
			for s in [1, -1]:
				var c: Vector2i = center + side * s
				if not Game.map.is_solid_turf(c):
					cells.append(c)
		var lv := level
		Genetics.after(0.2 * (level - 1), func(): _breath_level(e, cells, lv))
	# thrown backwards, still facing forward
	var tb: int = p["data"].get("throw", 1)
	var back := e.cell
	for i in tb:
		var n := back - fwd
		if Game.map.blocks_move_static(n) or Game.map.is_solid_turf(n) or Game.map.dense_count[Game.map.idx(n)] > 0:
			break
		back = n
	if back != e.cell:
		Interact.glide(e, back, 0.15)
		e.place(back, false)
		mb.face(Defs.dir_from_vec(fwd))

static func _breath_level(e: Entity, cells: Array, level: int) -> void:
	for c in cells:
		if Game.atmos:
			Game.atmos.ignite(c, e, 2.0) # tg hotspot_expose(max(500, 900-100*level), ...)
		for x in Game.at(c):
			if x == e:
				continue
			var hh: CHealth = x.c(&"health")
			if hh:
				hh.take_overall_damage(0.0, maxf(10.0, 40.0 - 5.0 * level), e)
				hh.ignite(GeneFx.fire_stacks_time(maxf(2.0, 5.0 - level)))
			elif x.has_c(&"flammable"):
				x.c(&"flammable").ignite()

## tg farsight: the view grows (client view size)
static func _farsight_view(e: Entity, extra: int) -> void:
	if e == Game.player and Game.view and Game.view.has_method("set_farsight"):
		Game.view.set_farsight(extra)

## tg olfaction cast: sniff what you hold to pick up a scent, or follow the one you have
static func _olfaction(e: Entity, p: Dictionary) -> void:
	var inv: CInventory = e.c(&"inv")
	var h: CHealth = e.c(&"health")
	if h.missing.has("head"):
		Game.tell(e, "You have no nose!", "warn")
		return
	if Quirks.has(e, "anosmia") or Traits.has(e, "anosmia"):
		Game.tell(e, "You can't smell!", "warn")
		return
	if Game.atmos and Game.atmos.partial(Game.map.idx(e.cell), Defs.G_MIASMA) > 0.0:
		h.disgust = minf(150.0, h.disgust + p["data"].get("sensitivity", 1.0) * 45.0)
		Game.tell(e, "With your overly sensitive nose, you get a whiff of stench and feel sick! Try moving to a cleaner area!", "warn")
		return
	var held: Entity = inv.active_item() if inv else null
	if held:
		var prints := Forensics.prints_on(held)
		var possible := []
		for m in Game.all_with(&"dna"):
			if Forensics.fingerprint(m) in prints:
				possible.append(m)
		if possible.is_empty():
			Game.tell(e, "Despite your best efforts, there are no scents to be found on %s..." % held.the(), "warn")
			return
		if e == Game.player and possible.size() > 1:
			p["data"]["choices"] = possible
			Bus.ui_open_window.emit("gene_scent", held)
			return
		var t: Entity = possible[0]
		Game.tell(e, "You pick up the scent of %s. The hunt begins." % t.display_name)
		p["data"]["tracking"] = t
		_on_the_trail(e, p)
		return
	var cur = p["data"].get("tracking")
	if cur == null or not is_instance_valid(cur) or cur.removed:
		Game.tell(e, "You're not holding anything to smell, and you haven't smelled anything you can track. You smell your skin instead; it's kinda salty.", "warn")
		p["data"].erase("tracking")
		return
	_on_the_trail(e, p)

static func pick_scent(e: Entity, target: Entity) -> void:
	var p := find(e, "olfaction")
	if p.is_empty() or e.c(&"health").stat() != CHealth.CONSCIOUS or not is_instance_valid(target) or target.removed or not target in p["data"].get("choices", []):
		return
	Game.tell(e, "You pick up the scent of %s. The hunt begins." % target.display_name)
	p["data"]["tracking"] = target
	p["data"].erase("choices")
	_on_the_trail(e, p)

static func _on_the_trail(e: Entity, p: Dictionary) -> void:
	var t: Entity = p["data"].get("tracking")
	if t == e:
		Game.tell(e, "You smell out the trail to yourself. Yep, it's you.", "warn")
		return
	var dv := t.root_cell() - e.root_cell()
	Game.tell(e, "You consider %s's scent. The trail leads [b]%s[/b]." % [t.display_name, dir_text(dv)])

static func dir_text(dv: Vector2i) -> String:
	var ns := "north" if dv.y < 0 else ("south" if dv.y > 0 else "")
	var ew := "west" if dv.x < 0 else ("east" if dv.x > 0 else "")
	# tg get_dir: diagonal only when both axes differ
	if ns != "" and ew != "":
		return ns + ew
	return ns + ew if ns + ew != "" else "right here"

## tg telepathy cast: whisper into someone's head
static func telepathy(e: Entity, target: Entity, message: String) -> void:
	var p := find(e, "telepathy")
	if p.is_empty() or message.strip_edges() == "":
		return
	if e.dist_to(target) > 7:
		Game.tell(e, "They're too far!", "warn")
		return
	_start_cd(p)
	Game.tell(e, "[b]You transmit to %s:[/b] %s" % [target.display_name, message])
	Game.tell(target, "[b]You hear a voice in your head...[/b] %s" % message)
	var br = target.c(&"brain")
	if br and br.has_method("hear_telepathy"):
		br.hear_telepathy(e, message)

## tg mindread cast
static func _mindread(e: Entity, p: Dictionary, target: Entity) -> void:
	_start_cd(p)
	var th: CHealth = target.c(&"health")
	if th.dead:
		Game.tell(e, "%s is dead!" % target.display_name, "warn")
		return
	if target == e:
		Game.tell(e, "You plunge into your mind... Yep, it's your mind.", "warn")
		return
	if not target.has_c(&"brain") and target != Game.player:
		Game.tell(e, "%s has no mind to read!" % target.display_name, "warn")
		return
	var lines := ["[i]You plunge into %s's mind and discover...[/i]" % target.display_name]
	if Genetics.prob(20):
		Game.tell(target, "You feel something foreign enter your mind.", "bad")
	var said: Array = target.get_meta("recent_speech", [])
	var mem := []
	for s in said.slice(maxi(0, said.size() - 3)):
		if Genetics.prob(50):
			mem.append("    \"%s\"..." % s)
	if not mem.is_empty():
		lines.append("...Drifting memories of past conversations:")
		lines.append("\n".join(mem))
	var tm: CMob = target.c(&"mob")
	lines.append("...Intent to [b]%s[/b]." % ("harm" if tm and tm.combat else "help"))
	lines.append("...True identity of [b]%s[/b]." % (tm.real_name if tm else target.display_name))
	Game.tell(e, "\n".join(lines))

## tg tongue_spike cast: the tongue flies out as a spike in the facing direction
static func _tongue_spike(e: Entity, p: Dictionary) -> void:
	var h: CHealth = e.c(&"health")
	if Traits.has(e, "nodismember"):
		Game.tell(e, "You concentrate really hard, but nothing happens.")
		return
	if h.get_meta("no_tongue", false):
		Game.tell(e, "You don't have a tongue to shoot!")
		return
	h.set_meta("no_tongue", true)
	var chem: bool = p["id"] == "chem_spike"
	var mb: CMob = e.c(&"mob")
	var fwd: Vector2i = Defs.DIRS4[mb.dir]
	var c := e.cell
	var hit: Entity = null
	for i in 14:
		var n := c + fwd
		if not Game.map.inb(n) or Game.map.is_solid_turf(n) or Game.map.blocks_move_static(n):
			break
		c = n
		for x in Game.at(c):
			if x != e and x.has_c(&"health"):
				hit = x
				break
		if hit:
			break
	Fx.beam(e.cell, c, Color(0.85, 0.4, 0.5))
	var spike := Proto.spawn("chem_spike" if chem else "tongue_spike", c)
	spike.tags["fired_by"] = e.id
	if hit:
		var hh: CHealth = hit.c(&"health")
		var part: String = Genetics.rand_pick(["chest", "l_arm", "r_arm", "l_leg", "r_leg", "head"])
		if hh.missing.has(part):
			part = "chest"
		if not chem:
			hh.hurt_zone(Body.PARTS[part]["zones"][0], 25.0, "brute", e, "pointy") # throwforce 25
		Embeds.embed_into(hh, part, spike.display_name, spike.proto, 2, "pointy", Embeds.data("tongue_spike_chem" if chem else "tongue_spike"), 2.0 if chem else 25.0, false)
		spike.destroy()
		Game.visible_message(hit.cell, "%s is struck by %s!" % [hit.display_name, "a biomass spike"], "bad")
		if chem:
			grant_plain(e, "send_chems", {"target": hit.id})
			Game.tell(e, "Link established! Use the \"Transfer Chemicals\" ability to send your chemicals to the linked target!")
	else:
		# tg check_morph: not embedded after 5 s, it cracks back into a tongue
		Genetics.after(5.0, func():
			if is_instance_valid(spike) and not spike.removed:
				Game.visible_message(spike.cell, "%s cracks and twists, changing shape!" % spike.the(), "warn")
				spike.destroy()
				var fb: Entity = Game.get_entity(spike.tags.get("fired_by", 0))
				if fb:
					fb.c(&"health").remove_meta("no_tongue"))

## tg send_chems Trigger: all your reagents into the spiked target
static func _send_chems(e: Entity, p: Dictionary) -> void:
	var t: Entity = Game.get_entity(p["data"].get("target", 0))
	remove_id(e, "send_chems")
	if t == null:
		Game.tell(e, "Link lost!", "warn")
		return
	var h: CHealth = e.c(&"health")
	var th: CHealth = t.c(&"health")
	Game.tell(t, "You feel a tiny prick!", "warn")
	for k in h.chems.keys():
		th.chems[k] = th.chems.get(k, 0.0) + h.chems[k]
	h.chems.clear()
	for em in th.embedded.duplicate():
		if em.get("proto", "") == "chem_spike":
			Game.visible_message(t.cell, "%s falls out of %s!" % [em.get("name", "the spike"), t.display_name])
			Embeds.fall_out(th, em)

## tg void/cast: pulled into a pocket of the void for 10 s, untouchable
static func _void(e: Entity) -> void:
	var mb: CMob = e.c(&"mob")
	if mb:
		mb.say("DOOOOOOOOOOOOOOOOOOOOM!!!") # INVOCATION_SHOUT
	vanish(e)

## tg /obj/effect/immortality_talisman/void: vanish, godmode, pop back in 10 s
static func vanish(e: Entity) -> void:
	if e.get_meta("in_void", false):
		return
	Game.visible_message(e.cell, "[b]%s is dragged into the void, leaving a hole in %s place![/b]" % [e.display_name, e.c(&"mob").their() if e.has_c(&"mob") else "its"], "bad")
	e.set_meta("in_void", true)
	Traits.add(e, "godmode", "void")
	Traits.add(e, "no_transform", "void")
	var hole := Proto.spawn("void_hole", e.cell)
	hole.desc = "It's shaped an awful lot like %s." % e.display_name
	e.visible = false
	Genetics.after(10.0, func():
		if not is_instance_valid(e) or e.removed:
			return
		e.remove_meta("in_void")
		Traits.remove(e, "godmode", "void")
		Traits.remove(e, "no_transform", "void")
		e.visible = true
		if is_instance_valid(hole) and not hole.removed:
			e.place(hole.cell)
			hole.destroy()
		Game.visible_message(e.cell, "[b]%s pops back into reality![/b]" % e.display_name, "bad"))

## tg void/cursed on_life: a chance, worse with instability, of being pulled in anyway
static func on_life(e: Entity, m: Mutation, dt: float) -> void:
	if m.id != "void":
		return
	var p := find(e, "void_cursed")
	if p.is_empty():
		return
	var h: CHealth = e.c(&"health")
	if h.dead or e.holder != null:
		return
	var chance := 0.25
	var d: CDna = e.c(&"dna")
	if d:
		chance += (100.0 - d.stability) / 40.0
	chance *= p["data"].get("curse_mod", 1.0)
	if Genetics.spt_prob(chance, dt):
		_void(e)

# ------------------------------------------------------------------ touch powers
static func _touch(e: Entity, p: Dictionary, target: Entity) -> void:
	match p["id"]:
		"shock_touch":
			_start_cd(p)
			_shock_touch(e, p, target)
		"lay_on_hands":
			if _lay_on_hands(e, p, target):
				_start_cd(p)
	_hud_changed(e)

## tg shock touch: 5 burn that never stuns, 20 stamina, both hands empty, 15 s confusion
static func _shock_touch(e: Entity, p: Dictionary, target: Entity) -> void:
	var th: CHealth = target.c(&"health")
	Sfx.play("zap", target.cell, 0.7)
	if Traits.has(target, "shockimmune"):
		Game.tell(e, "The electricity doesn't seem to affect %s..." % target.display_name, "warn")
		return
	th.adjust("burn", 5.0, e)
	th.adjust_status("jitter", 20.0)
	Fx.sparks(target.cell)
	var mb: CMob = e.c(&"mob")
	var zone: String = mb.aimed_zone() if mb else "chest"
	var inv: CInventory = target.c(&"inv")
	var armor := inv.armor() if inv else 0.0
	th.adjust("stamina", 20.0 * (1.0 - armor), e)
	if inv:
		for it in inv.hands.duplicate():
			if it:
				inv.drop(it)
	th.adjust_status("confusion", 15.0)
	Game.visible_message(target.cell, "%s electrocutes %s!" % [e.display_name, target.display_name], "bad")
	Game.tell(target, "[b]%s electrocutes you![/b]" % e.display_name, "bad")
	if p["data"].get("stagger", false):
		th.set_status("staggered", minf(th.status_left("staggered") + 6.0, maxf(10.0, th.status_left("staggered"))))
	Interact._crime_check(e, target, "assault")

## tg lay_on_hands: take up to 35 of their brute and burn onto yourself
static func _lay_on_hands(e: Entity, p: Dictionary, target: Entity) -> bool:
	var h: CHealth = e.c(&"health")
	var th: CHealth = target.c(&"health")
	var heal_mult: float = p["data"].get("power", 1.0)
	var pain_mult: float = p["data"].get("sync", 1.0)
	var mb: CMob = e.c(&"mob")
	var evil := Traits.has(target, "evil") and not Traits.has(e, "evil")
	if evil:
		if Traits.has(e, "pacifism") or (mb and not mb.combat):
			Game.tell(e, "%s would be hurt!" % target.display_name, "warn")
			return false
		Game.visible_message(target.cell, "%s lays hands on %s, but it shears them with a brilliant energy!" % [e.display_name, target.display_name], "bad")
		th.take_overall_damage(0.0, 10.0 * heal_mult, e)
		th.ignite(GeneFx.fire_stacks_time(3.0 * heal_mult))
		Emotes.emote(target, "scream")
		return true
	if Traits.has(e, "pacifism"):
		heal_mult *= 1.75
	var budget := 35.0 * heal_mult
	var any := false
	for part in ["head", "chest", "l_arm", "r_arm", "l_leg", "r_leg"]:
		if th.missing.has(part) or budget <= 0.0:
			continue
		var burn := Body.part_burn(th, part)
		var brute := Body.part_damage(th, part) - burn
		var tot := brute + burn
		if tot <= 0.0:
			continue
		var b_dam := 0.0
		var f_dam := 0.0
		if budget >= tot:
			budget -= tot
			b_dam = brute
			f_dam = burn
		else:
			if brute > burn:
				f_dam = minf(burn, budget / 2.0)
				b_dam = budget - f_dam
			else:
				b_dam = minf(burn, budget / 2.0) # tg: min(affected_limb.burn_dam, budget/2) - kept
				f_dam = budget - b_dam
			budget = 0.0
		any = true
		Body.heal_part(th, part, b_dam, f_dam)
		th.brute = maxf(0.0, th.brute - b_dam)
		th.burn = maxf(0.0, th.burn - f_dam)
		var z: String = Body.PARTS[part]["zones"][0]
		if not h.missing.has(part):
			if b_dam > 0.0:
				h.hurt_zone(z, b_dam * pain_mult, "brute", null, "", Body.CANT_WOUND)
			if f_dam > 0.0:
				h.hurt_zone(z, f_dam * pain_mult, "burn", null, "", Body.CANT_WOUND)
		else:
			h.take_overall_damage(b_dam, f_dam)
	# tg: blood evens out between them (10% of normal at most)
	var max_blood := Body.BLOOD_VOLUME_NORMAL * 0.1 * heal_mult
	if th.blood_volume < Body.BLOOD_VOLUME_NORMAL:
		var amt := minf(max_blood, Body.BLOOD_VOLUME_NORMAL - th.blood_volume)
		amt = minf(amt, h.blood_volume)
		if amt > 0.0:
			h.blood_volume -= amt
			th.blood_volume += amt
			Game.tell(e, "Your veins (and brain) feel a bit lighter.")
			Game.tell(target, "Your veins feel thicker!")
			any = true
	if not any:
		Game.tell(e, "%s is unhurt!" % target.display_name, "warn")
		return false
	if th.on_fire > 0.0:
		h.ignite(th.on_fire * pain_mult)
		th.on_fire = 0.0
	Fx.beam(e.cell, target.cell, Color(0.8, 0.1, 0.1))
	Game.visible_message(target.cell, "%s lays hands on %s!" % [e.display_name, target.display_name], "good")
	Game.tell(target, "[b]%s lays hands on you, healing you![/b]" % e.display_name, "good")
	Sfx.play("heal", target.cell, 0.6)
	return true
