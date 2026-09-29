class_name CGadget extends Component
## tg handheld gadgets, one component with a `kind` each:
##   flash         blinds and knocks down whoever you flash (Z flashes everyone around you);
##                 can burn out with overuse; sunglasses and welding gear protect
##   pepperspray   a short cone: blinds, drains stamina, makes people cough
##   spray         space cleaner: a short cone that cleans blood, vomit and oil off the floor
##   lighter       Z to flick it; lights cigarettes and molotovs; a lit one burns people
##   cigarette     wear it (mask slot) and light it; calms you while it burns down
##   pen           write on paper
##   defib         shock a recently dead body back to life (tg: within 5 minutes, body
##                 not too wrecked); on harm intent, a stunning jolt
##   gun           energy guns: disabler (stamina), laser (burn), energy gun (Z switches
##                 disable / kill). Shots fly in a line, can be dodged, drain the cell;
##                 recharge in a weapon recharger
##   grenade       flashbang / smoke: Z pulls the pin, then throw it; goes off after 5 s
##   glowstick     Z cracks it: green light for ten minutes, then it's spent
##   holofan       tg holosign_creator/atmos: click a tile to project a holofirelock (gas
##                 can't pass, people can); up to six; Z clears them all

var kind := ""
var sub := "" # gun: disabler / laser / egun; grenade: flash / smoke
var charges := 10
var max_charges := 10
var lit := false
var mode := "disable" # energy gun
var burn_t := 0.0 # cigarette / glowstick time left
var fuse := -1.0 # grenade
var cooldown := 0.0
var burnt_out := false
var text := "" # paper written with a pen
var scan_logs: Array = [] # forensic scanner (tg detective_scanner log_data)
var scan_busy_until := 0.0
var print_count := 0
var signs: Array = [] # holofan: the barriers this projector keeps up

const FLASH_PROTECT := ["sunglasses", "welding_goggles", "welding_helmet"]
const SHOT_RANGE := 12

func key() -> StringName:
	return &"gadget"

func setup(p: Dictionary) -> CGadget:
	kind = p.get("kind", kind)
	sub = p.get("sub", sub)
	charges = p.get("charges", charges)
	max_charges = p.get("max", charges)
	burn_t = p.get("burn", burn_t)
	if kind == "ballistic":
		# TG detective revolver and riot shotgun spawn with nonlethal ammunition.
		var r: String = p.get("round", "ammo_38_rubber" if sub == "revolver" else "shell_rubbershot")
		for k in max_charges:
			chamber.append(r)
	return self

## tg detective_scanner/scan: point it at something within 8 tiles you can see (or at
## anything you're carrying); it analyses for 3 s and logs what it found.
func forensic_scan(user: Entity, target: Entity) -> void:
	if Game.time < scan_busy_until:
		Game.tell(user, "The scanner is busy!", "warn")
		return
	var carried := target.holder == user or (target.holder != null and target.holder.holder == user)
	if not carried:
		if user.dist_to(target) > Forensics.SCAN_RANGE:
			return
		if Game.lighting and user.dist_to(target) > 1 and not Game.lighting._los(user.cell, target.root_cell()):
			return
	Sfx.play("ui_tick", user.cell, 0.4)
	Game.visible_message(user.cell, "%s points %s at %s and performs a forensic scan." % [user.display_name, e.the(), target.the()])
	Game.tell(user, "You scan %s. The scanner is now analysing the results..." % target.the())
	var entry := Forensics.scan(e, user, target)
	scan_busy_until = Game.time + Forensics.SCAN_TIME
	Game.get_tree().create_timer(Forensics.SCAN_TIME / maxf(Game.time_scale, 0.01)).timeout.connect(func():
		if is_instance_valid(e) and not e.removed:
			scan_logs.append(entry)
			if is_instance_valid(user):
				Game.tell(user, "Scan of %s complete." % entry["target"]))

## tg ForensicScanner "print": a paper Forensic Record in your hand, and the logs cleared.
func forensic_print(user: Entity) -> void:
	if scan_logs.is_empty() or Game.time < scan_busy_until:
		return
	print_count += 1
	var paper := Proto.spawn("paper", user.cell)
	paper.tags["text"] = Forensics.report(scan_logs, print_count)
	paper.display_name = "FR-%d 'Forensic Record'" % print_count
	scan_logs.clear()
	var inv: CInventory = user.c(&"inv")
	if inv:
		inv.put_in_hands(paper)
	Sfx.play("click", user.cell, 0.5)
	Game.tell(user, "The scanner prints a report. Logs cleared.")

func ranged() -> bool:
	return kind in ["gun", "pepperspray", "spray", "ballistic"]

# ------------------------------------------------------------------ ballistic guns (tg /obj/item/gun/ballistic)
## tg ammo casings -> their projectiles (code/modules/projectiles/projectile/bullets/*.dm).
## dmg is brute; stam is stamina damage; pellets split the shot (buckshot); wb/exp are
## wound_bonus/exposed_wound_bonus, which fall off by `fall` per tile (tg
## wound_falloff_tile); sharp is the bullet's sharpness.
const ROUNDS := {
	"ammo_38": {"name": ".38 round", "dmg": 25.0, "stam": 0.0, "wb": -20.0, "exp": 10.0, "fall": -5.0, "sharp": "pointy", "pellets": 1, "cal": ".38"},
	"ammo_38_rubber": {"name": ".38 rubber round", "dmg": 10.0, "stam": 30.0, "wb": -20.0, "exp": 10.0, "fall": -5.0, "sharp": "", "pellets": 1, "cal": ".38"},
	"shell_beanbag": {"name": "beanbag slug", "dmg": 10.0, "stam": 55.0, "wb": 20.0, "exp": 0.0, "fall": -5.0, "sharp": "", "pellets": 1, "cal": "shotgun"},
	"shell_rubbershot": {"name": "rubber shot", "dmg": 3.0, "stam": 10.0, "stamina_fall": -0.25, "damage_fall": -0.25, "wb": 0.0, "exp": 0.0, "sharp": "", "pellets": 6, "cal": "shotgun"},
	"shell_buckshot": {"name": "buckshot shell", "dmg": 5.0, "stam": 0.0, "wb": 5.0, "exp": 5.0, "fall": -0.5, "damage_fall": -0.25, "sharp": "edged", "pellets": 6, "cal": "shotgun"},
	"shell_slug": {"name": "shotgun slug", "dmg": 25.0, "stam": 0.0, "wb": 0.0, "exp": 15.0, "fall": -5.0, "ap": 30.0, "sharp": "pointy", "pellets": 1, "cal": "shotgun"},
}
var chamber: Array = [] # rounds loaded, next to fire first
var pump_needed := false # shotgun queue begins with the live chamber only when false
var spent_shell := ""

func chamber_ready() -> bool:
	return not chamber.is_empty() and (sub != "shotgun" or not pump_needed)

func pump(user: Entity) -> void:
	if sub != "shotgun": return
	if spent_shell != "":
		var casing := Proto.spawn("spent_shell", user.root_cell())
		casing.tags["spent_round"] = spent_shell
		spent_shell = ""
	elif chamber_ready():
		# Racking a live chamber ejects its unused shell before feeding the next one.
		Proto.spawn(chamber.pop_front(), user.root_cell(), {"comps": {"stack": {"amount": 1}}})
	pump_needed = chamber.is_empty()
	Sfx.play("ratchet", user.root_cell(), 0.8)
	Game.tell(user, "You pump %s. %s" % [e.the(), "A shell is chambered." if chamber_ready() else "The chamber is empty."])

func caliber() -> String:
	return ".38" if sub == "revolver" else "shotgun"

func load_ammo(user: Entity, ammo: Entity) -> bool:
	if not ROUNDS.has(ammo.proto) or ROUNDS[ammo.proto]["cal"] != caliber():
		return false
	var live_chamber := 1 if sub == "shotgun" and chamber_ready() else 0
	var room := max_charges - (chamber.size() - live_chamber)
	if room <= 0:
		Game.tell(user, "%s is fully loaded." % e.the().capitalize(), "warn")
		return true
	var st: CStack = ammo.c(&"stack")
	var n := mini(room, st.amount if st else 1)
	if sub == "shotgun" and chamber.is_empty(): pump_needed = true
	for k in n:
		chamber.append(ammo.proto)
	if st:
		st.use(n)
	else:
		Interact.detach(ammo)
		ammo.destroy()
	Sfx.play("click", user.cell, 0.7)
	Game.tell(user, "You load %d %s%s into %s." % [n, ROUNDS[chamber[-1]]["name"], "" if n == 1 else "s", e.the()])
	return true

func unload(user: Entity) -> void:
	if chamber.is_empty():
		Game.tell(user, "It's empty.", "warn")
		return
	var counts := {}
	for r in chamber:
		counts[r] = counts.get(r, 0) + 1
	chamber.clear()
	if sub == "shotgun":
		pump_needed = true
		if spent_shell != "":
			pump(user)
	for r in counts:
		var it := Proto.spawn(r, user.cell, {"comps": {"stack": {"amount": counts[r]}}})
		user.c(&"inv").put_in_hands(it)
	Sfx.play("click", user.cell, 0.6)
	Game.tell(user, "You unload %s." % e.the())

func _shoot_ballistic(user: Entity, target: Vector2i) -> void:
	var h: CHealth = user.c(&"health")
	if h and not h.can_use_hands():
		return
	if not chamber_ready():
		Game.tell(user, "*click*", "warn")
		Sfx.play("click", user.cell, 0.6)
		cooldown = 0.4
		return
	var round_id: String = chamber.pop_front()
	if sub == "shotgun":
		pump_needed = true
		spent_shell = round_id
	var rd: Dictionary = ROUNDS[round_id].duplicate()
	rd["id"] = round_id
	cooldown = 0.6 if sub == "revolver" else 0.8
	if Traits.has(user, "double_tap"): cooldown *= 0.5
	Sfx.play("gunshot", user.cell, 1.0)
	Fx.sparks(user.cell)
	var d := Vector2(target - user.cell)
	if d == Vector2.ZERO:
		return
	var um: CMob = user.c(&"mob")
	if um:
		um.face(Defs.dir_from_vec(target - user.cell))
	for pellet in rd["pellets"]:
		var spread := 0.0 if rd["pellets"] == 1 else deg_to_rad(roundf(Game.rng.randf_range(-7.5, 7.5)))
		var dir := d.normalized().rotated(spread + Quirks.extra_spread(user))
		_bullet(user, target, dir, rd)
	Bus.stimulus.emit({"type": "gunshot", "actor": user, "cell": user.cell, "loud": 12.0, "illegal": false})

func _bullet(user: Entity, target: Vector2i, dir: Vector2, rd: Dictionary) -> void:
	if Traits.has(user, "double_tap"):
		for mob in Game.in_radius(target, 1, &"health"):
			if mob != user and not mob.c(&"health").dead:
				dir = Vector2(mob.cell - user.cell).normalized()
				break
	var end := user.cell
	var hit: Entity = null
	for k in range(1, SHOT_RANGE + 1):
		var c := user.cell + Vector2i(roundi(dir.x * k), roundi(dir.y * k))
		if not Game.map.inb(c): break
		if Game.map.blocks_move_static(c):
			# tg: bullets smash into windows and walls
			var s: int = Game.map.structure[Game.map.idx(c)]
			if s != Defs.S_NONE:
				Structures.take_damage(c, rd["dmg"] * rd.get("pellets", 1) / maxf(1.0, rd.get("pellets", 1)), "brute", "bullet", user, 0.0, true, end)
			end = c
			break
		end = c
		var blocked := false
		for b in Game.at_with(c, &"blocker"):
			if b.c(&"blocker").dense and not b.has_c(&"health"):
				blocked = true
				if b.has_c(&"psychicwall"): b.c(&"psychicwall").deflect(user, rd["dmg"], "brute")
				if b.has_c(&"integrity") or b.has_c(&"machine"):
					b.take_damage(rd["dmg"], "brute", user)
		if blocked:
			break
		for m in Game.at_with(c, &"health"):
			if m != user and not Traits.has(m, "unhittable_projectiles") and not m.c(&"health").dead and not (m.c(&"mob") and m.c(&"mob").is_lying() and c != target):
				hit = m
				break
		if hit:
			break
	Fx.beam(user.cell, end, Color("#ffe8a0"))
	if hit == null:
		return
	var th: CHealth = hit.c(&"health")
	var zone := Combat.pick_zone(user, hit)
	var tiles := maxi(absi(hit.cell.x - user.cell.x), absi(hit.cell.y - user.cell.y))
	var raw_damage := maxf(0.0, float(rd["dmg"]) + float(rd.get("damage_fall", 0.0)) * tiles)
	if Combat.check_block(hit, rd["name"], raw_damage, rd.get("ap", 0.0)): return
	var arm := minf(Combat.penetrate(Combat.armor_vs(hit, zone, "bullet"), rd.get("ap", 0.0)), Combat.ARMOR_MAX_BLOCK)
	var dmg: float = raw_damage * (1.0 - arm / 100.0)
	if dmg > 0.0:
		var wb: float = rd["wb"] + rd.get("fall", 0.0) * tiles
		var exb: float = maxf(0.0, rd.get("exp", 0.0) + rd.get("fall", 0.0) * tiles)
		th.hurt_zone(zone, dmg, "brute", user, rd.get("sharp", "pointy"), wb, exb, true)
		# tg try_embed_projectile: the round may lodge (less likely the further it flew)
		Embeds.try_projectile(rd.get("id", ""), hit, zone, tiles, arm)
		# tg create_projectile_hit_effects: a splatter, and a third of the time blood on the floor
		if th.blood_volume > 0.0 and Body.prob(33):
			Body.splatter(hit.cell, 10.0, false, th)
	if rd["stam"] > 0.0:
		var raw_stamina := maxf(0.0, float(rd["stam"]) + float(rd.get("stamina_fall", 0.0)) * tiles)
		th.adjust("stamina", raw_stamina * (1.0 - arm / 100.0), user)
	Game.visible_message(hit.cell, "%s is hit in the %s by a %s!" % [hit.display_name, Combat.ZONE_NAMES[zone], rd["name"]], "bad")
	Skills.add_xp(user, "throwing", 6.0)
	Bus.stimulus.emit({"type": "assault", "actor": user, "target": hit, "cell": hit.cell, "loud": 8.0, "illegal": not Combat._lawful_force(user, hit)})

# ------------------------------------------------------------------ in hand (Z)
func attack_self(user: Entity) -> bool:
	match kind:
		"forensic":
			Bus.ui_open_window.emit("forensic_scanner", e) # tg ForensicScanner
			return true
		"flash":
			_flash_area(user)
			return true
		"lighter":
			lit = not lit
			_sprite()
			Sfx.play("click", user.cell, 0.4)
			Game.visible_message(user.cell, "%s %s %s." % [user.display_name, "flicks on" if lit else "snaps shut", e.the()])
			var l = e.c(&"light")
			if l:
				l.on = lit
				l.refresh()
			return true
		"gun":
			if sub == "egun":
				mode = "kill" if mode == "disable" else "disable"
				_sprite()
				Game.tell(user, "%s is now set to %s." % [e.the().capitalize(), mode], "warn" if mode == "kill" else "info")
				Sfx.play("click", user.cell, 0.4)
				return true
		"grenade":
			if fuse < 0.0:
				fuse = 5.0
				_sprite()
				Sfx.play("click", user.cell, 0.7)
				Game.visible_message(user.cell, "%s primes %s!" % [user.display_name, e.the()], "bad")
				Bus.stimulus.emit({"type": "assault", "actor": user, "target": user, "cell": user.cell, "loud": 3.0, "illegal": false})
			return true
		"glowstick":
			if not lit and burn_t > 0.0:
				lit = true
				var l2 = e.c(&"light")
				if l2:
					l2.on = true
					l2.refresh()
				Game.visible_message(user.cell, "%s cracks %s and it starts to glow." % [user.display_name, e.the()])
				return true
		"defib":
			Game.tell(user, "Charge: %d/%d. Use it on a body." % [charges, max_charges])
			return true
		"ballistic":
			if sub == "shotgun":
				pump(user)
			else:
				unload(user)
			return true
		"holofan":
			if signs.is_empty():
				Game.tell(user, "There are no holograms to clear.")
				return true
			for s in signs.duplicate():
				if is_instance_valid(s) and not s.removed:
					s.destroy()
			signs.clear()
			Sfx.play("shimmer", user.cell, 0.5)
			Game.tell(user, "Holograms cleared.")
			return true
	return false

## tg holosign_creator interact_with_atom: project a barrier onto an open tile in view.
func project(user: Entity, cell: Vector2i) -> void:
	var map := Game.map
	if not map.inb(cell) or map.is_solid_turf(cell) or map.blocks_move_static(cell):
		return
	if maxi(absi(cell.x - user.cell.x), absi(cell.y - user.cell.y)) > 7:
		return
	for o in Game.at(cell):
		if o.has_c(&"holosign"):
			return
	signs = signs.filter(func(s): return is_instance_valid(s) and not s.removed)
	if signs.size() >= max_charges:
		Game.tell(user, "Max capacity!", "warn")
		return
	var b := Proto.spawn("holofan_barrier", cell)
	b.c(&"holosign").projector = e
	signs.append(b)
	Sfx.play("shimmer", cell, 0.7)
	Game.tell(user, "You create %s with %s." % [b.display_name, e.the()])

# ------------------------------------------------------------------ on a person
## Called before the generic item-on-mob handling. True = handled.
func use_on(user: Entity, target: Entity) -> bool:
	var th: CHealth = target.c(&"health")
	match kind:
		"flash":
			if th == null:
				return false
			_flash(user, target, true)
			return true
		"lighter":
			if not lit:
				return false
			var cig := _cig_on(target)
			if cig:
				cig.c(&"gadget").light(user)
				return true
			if user.c(&"mob").combat and th:
				th.adjust("burn", 5.0, user)
				Game.visible_message(target.cell, "%s burns %s with %s!" % [user.display_name, target.display_name, e.the()], "bad")
				Bus.stimulus.emit({"type": "assault", "actor": user, "target": target, "cell": target.cell, "loud": 4.0, "illegal": true})
				return true
		"defib":
			if th == null:
				return false
			_defib(user, target)
			return true
		"pepperspray", "spray", "gun":
			fire(user, target.cell)
			return true
	return false

## Something used on this gadget (a lighter on a cigarette, a pen on paper...).
func attackby(user: Entity, item: Entity) -> bool:
	if kind == "ballistic":
		return load_ammo(user, item)
	var g: CGadget = item.c(&"gadget")
	if kind == "cigarette" and g and g.kind == "lighter" and g.lit and not lit:
		light(user)
		return true
	return false

func _cig_on(target: Entity) -> Entity:
	var inv: CInventory = target.c(&"inv")
	if inv == null:
		return null
	var m: Entity = inv.worn("mask")
	if m and m.c(&"gadget") and m.c(&"gadget").kind == "cigarette":
		return m
	return null

func light(user: Entity) -> void:
	if kind != "cigarette" or lit:
		return
	lit = true
	_sprite()
	var who := e.holder if e.holder else user
	Game.visible_message(e.root_cell(), "%s lights %s." % [user.display_name, "%s's cigarette" % who.display_name if who != user else "their cigarette"])

# ------------------------------------------------------------------ flash (tg: /obj/item/assembly/flash)
func _use_flash(user: Entity) -> bool:
	if burnt_out:
		Game.tell(user, "%s is burnt out." % e.the().capitalize(), "warn")
		return false
	if cooldown > 0.0:
		return false
	cooldown = 1.0
	charges += 1 # times used, for burnout
	Sfx.play("stun", user.cell, 0.5)
	Fx.text_popup(user.cell, "*flash*", Color("#fff4c0"))
	# tg: past a few uses it starts risking burnout
	if charges > 5 and Game.rng.randf() < 0.1 * (charges - 5):
		burnt_out = true
		Game.visible_message(user.cell, "%s's %s burns out!" % [user.display_name, e.display_name], "warn")
	return true

## tg /obj/item/assembly/flash: attack() is flash_mob(target, confusion 5 s, targeted);
## attack_self() is AOE_flash (range 3, confusion 5 s, not targeted).
func _flash(user: Entity, target: Entity, direct: bool) -> void:
	if direct and not user.adjacent(target):
		return
	if direct and not _use_flash(user):
		return
	var th: CHealth = target.c(&"health")
	if th == null or th.dead:
		return
	if StatusFx.flash_mob(target, user, 5.0, direct) and direct and target != user:
		Bus.stimulus.emit({"type": "assault", "actor": user, "target": target, "cell": target.cell, "loud": 4.0, "illegal": not Combat._lawful_force(user, target)})

func _flash_area(user: Entity) -> void:
	if not _use_flash(user):
		return
	Game.visible_message(user.cell, "%s holds up %s and it goes off!" % [user.display_name, e.the()], "bad")
	for m in Game.in_radius(user.cell, 3):
		if m.has_c(&"health") and Game.lighting._los(user.cell, m.cell):
			_flash(user, m, false)

# ------------------------------------------------------------------ sprays (a short cone, like the extinguisher)
func _cone(user: Entity, target: Vector2i, length := 3) -> Array:
	var d := target - user.cell
	var dir := Vector2i(signi(d.x), signi(d.y))
	if dir == Vector2i.ZERO:
		dir = Defs.DIRS4[user.c(&"mob").dir] if user.c(&"mob") else Vector2i(0, 1)
	var side := Vector2i(-dir.y, dir.x)
	var cells := []
	for dist in range(1, length + 1):
		var c := user.cell + dir * dist
		if Game.map.blocks_air(c):
			break
		cells.append(c)
		if dist >= 2:
			for sc in [c + side, c - side]:
				if not Game.map.blocks_air(sc):
					cells.append(sc)
	return cells

## Ranged use: click somewhere with it.
func fire(user: Entity, target: Vector2i) -> void:
	if cooldown > 0.0:
		return
	# tg can_trigger_gun: ISADVANCEDTOOLUSER (discoordination) and TRAIT_PACIFISM
	var uh: CHealth = user.c(&"health")
	if kind in ["gun", "ballistic"] and uh and not uh.traumas.is_empty():
		if Traumas.discoordinated(uh):
			Game.tell(user, "You don't have the dexterity to do this!", "warn")
			return
		var nonlethal := kind == "gun" and (sub == "disabler" or (sub == "egun" and mode == "disable"))
		if Traumas.pacifist(uh) and not nonlethal:
			Game.tell(user, "%s is lethally chambered! You don't want to risk harming anyone..." % e.display_name.capitalize(), "warn")
			return
	match kind:
		"pepperspray":
			if charges <= 0:
				Game.tell(user, "It's empty.", "warn")
				return
			charges -= 1
			cooldown = 0.8
			Sfx.play("spray", user.cell, 0.7)
			for c in _cone(user, target):
				Fx.foam(c)
				for m in Game.at_with(c, &"health"):
					if m == user:
						continue
					# tg pepper spray: condensed capsaicin exposure
					if StatusFx.pepper(m.c(&"health")):
						Bus.stimulus.emit({"type": "assault", "actor": user, "target": m, "cell": c, "loud": 4.0, "illegal": not Combat._lawful_force(user, m)})
		"spray":
			if charges <= 0:
				Game.tell(user, "It's empty.", "warn")
				return
			charges -= 1
			cooldown = 0.5
			Sfx.play("spray", user.cell, 0.5)
			var cleaned := 0
			for c in _cone(user, target, 2):
				Fx.foam(c)
				for d in Game.at_with(c, &"decal"):
					if d.c(&"decal").cleanable:
						d.destroy()
						cleaned += 1
			if cleaned > 0:
				Skills.add_xp(user, "survival", cleaned * 2.0)
				Bus.stimulus.emit({"type": "cleaned", "actor": user, "cell": target, "loud": 1.0})
		"gun":
			_shoot(user, target)
		"ballistic":
			_shoot_ballistic(user, target)

# ------------------------------------------------------------------ energy guns (tg: /obj/item/gun/energy)
func shot_cost() -> int:
	return 1

func _shoot(user: Entity, target: Vector2i) -> void:
	var h: CHealth = user.c(&"health")
	if h and not h.can_use_hands():
		return
	if charges < shot_cost():
		Game.tell(user, "*click*", "warn")
		Sfx.play("click", user.cell, 0.6)
		cooldown = 0.4
		return
	charges -= shot_cost()
	cooldown = 0.45
	if Traits.has(user, "double_tap"): cooldown *= 0.5
	var kill := sub == "laser" or (sub == "egun" and mode == "kill")
	var col := Color("#ff4a3a") if kill else Color("#6ac8ff")
	var d := Vector2(target - user.cell)
	if d == Vector2.ZERO:
		return
	var dir := d.normalized().rotated(Quirks.extra_spread(user))
	var end := user.cell
	var hit: Entity = null
	for k in range(1, SHOT_RANGE + 1):
		var c := user.cell + Vector2i(roundi(dir.x * k), roundi(dir.y * k))
		if Game.map.blocks_move_static(c):
			if Defs.is_window(Game.map.structure[Game.map.idx(c)]):
				# lasers go through glass; disablers don't hurt it
				if kill:
					end = c
					continue
			break
		end = c
		var blocked := false
		for b in Game.at_with(c, &"blocker"):
			if b.c(&"blocker").dense and not b.has_c(&"health"):
				blocked = true
				if b.has_c(&"psychicwall"): b.c(&"psychicwall").deflect(user, 20.0 if kill else 30.0, "burn" if kill else "stamina")
		if blocked:
			break
		for m in Game.at_with(c, &"health"):
			if m != user and not Traits.has(m, "unhittable_projectiles") and not m.c(&"health").dead and not (m.c(&"mob") and m.c(&"mob").is_lying() and c != target):
				hit = m
				break
		if hit:
			break
	Sfx.play("zap" if Sfx.streams.has("zap") else "spark", user.cell, 0.7)
	Fx.beam(user.cell, end, col)
	var um: CMob = user.c(&"mob")
	if um:
		um.face(Defs.dir_from_vec(target - user.cell))
	if hit == null:
		return
	var th: CHealth = hit.c(&"health")
	# tg: shields block projectiles too
	if kill and Traits.has(hit, "ricochet_shiny") and Genetics.prob(80.0):
		GeneInteraction.reflect_projectile(hit, user, 20.0, "burn")
		Game.visible_message(hit.cell, "The laser ricochets from %s's golden coating!" % hit.display_name)
		return
	if Combat.check_block(hit, "the laser" if kill else "the disabler beam", 20.0 if kill else 30.0, 0.0, true): return
	# the aim still matters at range, and your Ranged skill helps
	var zone := Combat.pick_zone(user, hit)
	if kill:
		# tg laser: 20 burn, through LASER armour
		var dmg := 20.0 * (1.0 - Combat.armor_vs(hit, zone, "laser") / 100.0)
		th.hurt_zone(zone, dmg, "burn", user, "", -20.0, 10.0, true) # tg /obj/projectile/beam
		Game.visible_message(hit.cell, "%s is hit in the %s by a laser!" % [hit.display_name, Combat.ZONE_NAMES[zone]], "bad")
	else:
		# tg /obj/projectile/beam/disabler: 30 stamina through ENERGY armour
		th.adjust("stamina", 30.0 * (1.0 - Combat.armor_vs(hit, zone, "energy") / 100.0), user)
		Game.visible_message(hit.cell, "%s is hit by a disabler bolt!" % hit.display_name, "warn")
	Skills.add_xp(user, "throwing", 6.0)
	Bus.stimulus.emit({"type": "assault", "actor": user, "target": hit, "cell": hit.cell, "loud": 6.0, "illegal": not Combat._lawful_force(user, hit)})

# ------------------------------------------------------------------ defibrillator (tg: /obj/item/defibrillator)
func _defib(user: Entity, target: Entity) -> void:
	var th: CHealth = target.c(&"health")
	if charges <= 0:
		Game.tell(user, "The defibrillator's cell is flat.", "warn")
		return
	var um: CMob = user.c(&"mob")
	if not th.dead and Organs.undergoing_cardiac_arrest(th) and not (um and um.intent == "harm"):
		# tg: a living patient in cardiac arrest gets their heart restarted
		Game.visible_message(target.cell, "%s places the paddles on %s's chest..." % [user.display_name, target.display_name], "warn")
		DoAfter.start(user, target, 5.0 * Skills.speed(user, "medical"), func(ok):
			if not ok or charges <= 0:
				return
			charges -= 1
			Sfx.play("stun", target.cell)
			if not Organs.has(th, "heart"):
				Game.visible_message(target.cell, "The defibrillator buzzes: Patient's heart is missing. Operation aborted.", "warn")
			elif Organs.failing(th, "heart"):
				Game.visible_message(target.cell, "The defibrillator buzzes: Resuscitation failed, heart damage detected.", "warn")
			else:
				Organs.set_heartattack(th, false)
				Game.visible_message(target.cell, "The defibrillator pings: Patient's heart is now beating again.", "good")
		)
		return
	if not th.dead:
		if um and um.intent == "harm":
			charges -= 1
			th.knockdown(4.0)
			th.adjust("stamina", 60.0, user)
			Sfx.play("stun", target.cell)
			Game.visible_message(target.cell, "%s shocks %s with the paddles!" % [user.display_name, target.display_name], "bad")
			Bus.stimulus.emit({"type": "assault", "actor": user, "target": target, "cell": target.cell, "loud": 5.0, "illegal": true})
		else:
			Game.tell(user, "%s has a pulse. The defibrillator won't fire." % target.display_name)
		return
	Game.visible_message(target.cell, "%s places the paddles on %s's chest..." % [user.display_name, target.display_name], "warn")
	DoAfter.start(user, target, 5.0 * Skills.speed(user, "medical"), func(ok):
		if not ok or charges <= 0:
			return
		charges -= 1
		Sfx.play("stun", target.cell)
		Fx.sparks(target.cell)
		Game.visible_message(target.cell, "%s's body convulses as the defibrillator fires." % target.display_name, "warn")
		# tg can_defib: tissue damage, then the heart and the brain (which decay once dead)
		var fail := ""
		if th.brute >= 180.0 or th.burn >= 180.0:
			fail = "Tissue damage too severe, repair and try again."
		elif th.missing.has("head"):
			fail = "Patient's brain is missing. Further attempts futile."
		else:
			fail = {"no_heart": "Patient's heart is missing.", "failing_heart": "Patient's heart too damaged, replace or repair and try again.",
				"no_brain": "Patient's brain is missing. Further attempts futile.", "failing_brain": "Patient's brain is too damaged, repair and try again."}.get(Organs.defib_block(th), "")
		if fail != "":
			Game.visible_message(target.cell, "The defibrillator buzzes: Resuscitation failed - %s" % fail, "warn")
			return
		th.revive(true)
		if th.dead:
			Game.visible_message(target.cell, "The defibrillator buzzes: Resuscitation failed.", "warn")
			return
		th.set_status_if_lower("jitter", 200.0)
		Skills.add_xp(user, "medical", 60.0)
		CMood.event(user, "saved_life", "saved_life") # tg defib success
		Game.visible_message(target.cell, "[b]%s gasps as their heart starts beating again![/b]" % target.display_name, "good")
		Bus.chronicle.emit("%s brought %s back from the dead." % [user.display_name, target.display_name], 2)
		Bus.stimulus.emit({"type": "rescue", "actor": user, "target": target, "cell": target.cell, "loud": 2.0})
	)

# ------------------------------------------------------------------ ticking
func tick(dt: float) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	match kind:
		"cigarette":
			if lit:
				burn_t -= dt
				var who: Entity = e.holder
				if who and who.has_c(&"needs"):
					who.c(&"needs").add_stress(-dt * 0.15)
					CMood.event(who, "smoked", "smoked") # tg nicotine
					Addiction.expose(who.c(&"health"), "nicotine", 0.1 * dt) # tg: 15u over a 5-minute cigarette
				if Game.atmos and Game.rng.randf() < dt * 0.3:
					Game.atmos.add_gas(Game.map.idx(e.root_cell()), Defs.G_SMOKE, 0.05, 310.0)
				if burn_t <= 0.0:
					Game.visible_message(e.root_cell(), "%s burns down to the filter." % e.display_name.capitalize())
					e.destroy()
		"glowstick":
			if lit:
				burn_t -= dt
				var l = e.c(&"light")
				if l and burn_t < 60.0:
					l.energy = 0.7 * clampf(burn_t / 60.0, 0.1, 1.0)
					l.refresh()
				if burn_t <= 0.0:
					lit = false
					if l:
						l.on = false
						l.refresh()
					e.display_name = "spent glowstick"
		"grenade":
			if fuse >= 0.0:
				fuse -= dt
				if fuse <= 0.0:
					_detonate()
		"lighter":
			if lit and Game.atmos and Game.rng.randf() < dt * 0.5:
				Game.atmos.spark(e.root_cell(), 0.05)

func _detonate() -> void:
	var at := e.root_cell()
	match sub:
		"flash":
			Sfx.play("explosion", at, 0.6)
			Fx.text_popup(at, "BANG", Color("#fff4c0"))
			Game.visible_message(at, "[b]The flashbang goes off with a deafening bang![/b]", "bad")
			# tg flashbang: bang() on everyone in view within flashbang_range (7)
			for m in Game.in_radius(at, 7):
				if not m.has_c(&"health") or not Game.lighting._los(at, m.cell):
					continue
				StatusFx.flashbang(m.c(&"health"), at)
		"smoke":
			Sfx.play("whoosh", at, 0.8)
			Game.visible_message(at, "%s spews thick smoke!" % e.display_name.capitalize(), "warn")
			if Game.atmos:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var c := at + Vector2i(dx, dy)
						if Game.map.inb(c) and not Game.map.blocks_air(c):
							Game.atmos.add_gas(Game.map.idx(c), Defs.G_SMOKE, 25.0, 300.0)
	Bus.stimulus.emit({"type": "explosion", "cell": at, "loud": 14.0})
	e.destroy()

func _sprite() -> void:
	match kind:
		"lighter":
			e.set_sprite("items", "lighter_on" if lit else "lighter")
		"cigarette":
			e.set_sprite("items", "cigarette_lit" if lit else "cigarette")
		"gun":
			if sub == "egun":
				e.set_sprite("items", "egun_stun" if mode == "disable" else "egun_kill")
		"grenade":
			e.set_sprite("items", e.proto + ("_active" if fuse >= 0.0 else ""))
	var holder: Entity = e.holder
	if holder and holder.has_c(&"mob"):
		holder.c(&"mob").refresh_doll()

func verbs(user: Entity, out: Array) -> void:
	if kind == "ballistic" and e.holder == user:
		out.append({"name": "Unload", "cb": unload.bind(user), "priority": 4})

func examine(_user: Entity, lines: Array) -> void:
	if kind == "ballistic":
		var capacity := max_charges + (1 if sub == "shotgun" else 0)
		lines.append("It has %d/%d rounds loaded%s." % [chamber.size(), capacity, (" (next: %s)" % ROUNDS[chamber[0]]["name"]) if not chamber.is_empty() else ""])
		if sub == "shotgun":
			lines.append("%s Use it in hand (Z) to pump." % ("A live shell is chambered." if chamber_ready() else "The chamber needs pumping."))
	if kind == "holofan":
		signs = signs.filter(func(s): return is_instance_valid(s) and not s.removed)
		lines.append("It is currently maintaining [b]%d/%d[/b] projections." % [signs.size(), max_charges])
	match kind:
		"flash":
			if burnt_out:
				lines.append("[color=#ffb84a]It's burnt out.[/color]")
		"pepperspray", "spray":
			lines.append("%d sprays left." % charges)
		"gun":
			lines.append("Charge: %d/%d shots.%s" % [charges, max_charges, "  Set to [b]%s[/b]." % mode if sub == "egun" else ""])
		"defib":
			lines.append("Charge: %d/%d." % [charges, max_charges])
		"grenade":
			if fuse >= 0.0:
				lines.append("[color=#ff5a4a]The pin is out![/color]")
		"cigarette":
			if lit:
				lines.append("It's lit.")
		"glowstick":
			if not lit and burn_t > 0.0:
				lines.append("Z to crack it.")

func ai_tags(out: Dictionary) -> void:
	if kind == "gun":
		out["weapon"] = true
		out["ranged"] = true
