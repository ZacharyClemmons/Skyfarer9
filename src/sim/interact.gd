class_name Interact extends RefCounted
## The shared interaction layer. The player's clicks and the NPC AI both end up here, so
## anything a player can do to the world, an NPC can do with the same rules.
## Mirrors SS13's ClickOn -> attackby / attack_hand / afterattack chain.

# ------------------------------------------------------------------ holding
static func detach(item: Entity, refresh := true) -> void:
	var it: CItem = item.c(&"item")
	if it:
		it.is_wielded = false
	if item.pixel_offset != Vector2.ZERO:
		item.set_pixel_offset(Vector2.ZERO)
	var h := item.holder
	if h == null:
		if not item.removed and item.id != 0:
			Game.lift_from_map(item)
		return
	if h.has_c(&"inv"):
		h.c(&"inv").remove_ref(item, refresh)
	if h.has_c(&"storage"):
		h.c(&"storage").remove(item)
	if h.has_c(&"furniture") and h.c(&"furniture").stored == item:
		h.c(&"furniture").stored = null
	item.holder = null

static func pickup(user: Entity, item: Entity) -> bool:
	var inv: CInventory = user.c(&"inv")
	if inv == null or item.c(&"item") == null:
		return false
	var h: CHealth = user.c(&"health")
	if h and not h.can_use_hands():
		return false
	if item.holder == null and not Genetics.can_reach(user, item):
		return false
	if inv.free_hand() < 0:
		Game.tell(user, "Your hands are full.", "warn")
		return false
	var was_on_map := item.holder == null
	var area := Game.map.area_at(item.cell)
	if not inv.put_in_hands(item, inv.active):
		return false
	Forensics.touch(item, user)
	Sfx.play("pickup", user.cell)
	if was_on_map:
		_theft_check(user, item, area)
	return true

static func _theft_check(user: Entity, item: Entity, area: Area) -> void:
	# Taking department property from a restricted area you have no access to is theft.
	if area.restricted.is_empty():
		return
	var inv: CInventory = user.c(&"inv")
	for tag in area.restricted:
		if inv.has_access(tag):
			return
	var it: CItem = item.c(&"item")
	if it and it.category in ["tool", "medical", "weapon", "tank", "material", "chem"]:
		Bus.stimulus.emit({"type": "theft", "actor": user, "target": item, "cell": user.cell, "loud": 0.0, "illegal": true, "text": item.display_name})

static func drop_active(user: Entity) -> void:
	var inv: CInventory = user.c(&"inv")
	if inv == null:
		return
	var it := inv.active_item()
	if it:
		# tg TRAIT_NODROP from the possessive trauma
		if it.get_meta("nodrop", false):
			Game.tell(user, "You can't bring yourself to let go of %s." % it.the(), "warn")
			return
		inv.drop(it)
		Sfx.play("drop", user.cell)

# ------------------------------------------------------------------ main click dispatch
## Where in the world the last click landed (tg click params ICON_X/ICON_Y), or null for
## NPCs. Tables use it to put things down where you clicked.
static var click_pos = null

static func click(user: Entity, target: Entity, cell: Vector2i, mods: Dictionary = {}) -> void:
	click_pos = mods.get("wpos", null)
	var h: CHealth = user.c(&"health")
	if h and h.stat() != CHealth.CONSCIOUS:
		return
	if mods.get("shift", false):
		examine(user, target, cell)
		return
	if Traits.has(user, "animal_body"):
		if target and target != user and user.adjacent(target) and user.c(&"mob").combat and not DoAfter.busy(user):
			Combat.melee(user, target, null)
		return
	# tg atmos devices: ctrl-click switches them on and off, alt-click maxes them out
	if target != null and (mods.get("ctrl", false) or mods.get("alt", false)) and user.adjacent(target):
		var tpm: CPipeMachine = target.c(&"pipemachine")
		if tpm:
			if mods.get("ctrl", false):
				tpm.set_on(not tpm.on, user)
			else:
				tpm.max_out(user)
			return
		var tcc: CCanister = target.c(&"canister")
		if tcc and tcc.kind != "canister" and mods.get("ctrl", false):
			tcc.set_on(not tcc.on, user)
			return
	if mods.get("ctrl", false) and target == user and user.has_c(&"health"):
		self_grasp(user)
		return
	if mods.get("ctrl", false) and target != null:
		var pm: CMob = user.c(&"mob")
		if pm and pm.pulling == target:
			pm.stop_pulling() # tg: ctrl-click what you're pulling to let go
		elif user.adjacent(target):
			pm.start_pulling(target)
		return
	if DoAfter.busy(user):
		return
	if h and not h.can_use_hands():
		Game.tell(user, "You can't do that right now.", "warn")
		return
	var inv: CInventory = user.c(&"inv")
	var item: Entity = inv.active_item() if inv else null
	if GeneInteraction.click(user, target, cell, mods):
		return
	var mob: CMob = user.c(&"mob")
	if mob and target != null:
		if target.root_cell() != user.cell:
			mob.face(Defs.dir_from_vec(target.root_cell() - user.cell))
	elif mob and cell != user.cell:
		mob.face(Defs.dir_from_vec(cell - user.cell))
	# ranged uses
	if item and item.has_c(&"extinguisher") and (target == null or not user.adjacent(target) or target.has_c(&"health") == false):
		if target == null or not target.has_c(&"item") or not user.adjacent(target):
			item.c(&"extinguisher").spray(user, cell)
			return
	if mods.get("throw", false) and item:
		throw_item(user, item, cell)
		return
	# guns and sprays work at range (tg: afterattack with proximity = FALSE)
	var gd: CGadget = item.c(&"gadget") if item else null
	if gd and gd.kind == "forensic" and target != null and target != item and not mods.get("shift", false):
		gd.forensic_scan(user, target) # tg detective_scanner: ranged_interact_with_atom
		return
	if gd and gd.kind == "holofan" and not mods.get("shift", false) and (target == null or not target.has_c(&"holosign")):
		if target == null or (target.holder == null and not target.has_c(&"health")):
			gd.project(user, cell)
			return
	if gd and gd.ranged() and not mods.get("shift", false) and (target == null or not user.adjacent(target) or target.has_c(&"health")):
		if target == null or target.holder == null:
			gd.fire(user, cell)
			return
	if target == null:
		if Entity.cells_adjacent(user.cell, cell) and cell != user.cell:
			if item:
				if not use_on_tile(user, item, cell):
					hit_tile(user, item, cell)
			else:
				hand_on_tile(user, cell)
		return
	if target.holder == null and not Genetics.can_reach(user, target):
		return
	if item:
		use_item_on(user, item, target)
	else:
		hand_on(user, target)

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func use_item_on(user: Entity, item: Entity, target: Entity) -> void:
	if item.tags.has("self_grasp"):
		return # tg NOBLUDGEON hand item
	var fgd: CGadget = item.c(&"gadget")
	if fgd and fgd.kind == "forensic" and target != item:
		fgd.forensic_scan(user, target) # scanning something you carry
		return
	Forensics.touch(item, user)
	if target != item and not target.has_c(&"mob"):
		Forensics.touch(target, user)
	if target == item:
		item.attack_self(user)
		return
	# Skyfarer: gathering is the first thing checked, because an axe used on a tree should
	# never fall through to "you hit the tree with the axe" — that is the same action with
	# none of the point of it.
	if Gathering.try_harvest(user, item, target):
		return
	if Gathering.try_skin(user, item, target):
		return
	# a crated ship module, a fishing rod or a held aether weapon all act on the tile
	for comp in [&"shipmodule", &"skyrod", &"aethergun"]:
		if item.has_c(comp) and not target.has_c(&"item"):
			var c = item.c(comp)
			if c.has_method("use_on") and target.has_c(&"health"):
				if c.use_on(user, target):
					return
			elif c.has_method("use_on_cell"):
				if c.use_on_cell(user, target.root_cell()):
					return
	var cu: CCurio = item.c(&"curio")
	if cu != null and cu.use_on(user, target):
		return
	# tg RCD/RPD: they work on the tile, whatever's on it
	if item.has_c(&"shiprig") and not target.has_c(&"item") and not target.has_c(&"health"):
		if item.c(&"shiprig").use_on_cell(user, target.cell):
			return
	if item.has_c(&"rcd") and not target.has_c(&"item") and not target.has_c(&"health"):
		if item.c(&"rcd").act(user, target.cell):
			return
	if item.has_c(&"rpd") and not target.has_c(&"item") and not target.has_c(&"health"):
		if item.c(&"rpd").act(user, target.cell):
			return
	if target.has_c(&"rcd") and item.has_c(&"stack") or target.has_c(&"rcd") and item.proto == "rcd_ammo":
		if target.c(&"rcd").refill(user, item):
			return
	var ga: CGasAnalyzer = item.c(&"gasanalyzer")
	if ga and ga.scan_entity(user, target):
		return
	var gd: CGadget = item.c(&"gadget")
	if gd and gd.use_on(user, target):
		return
	if gd and gd.kind == "pen" and target.proto == "paper":
		Bus.ui_open_window.emit("write", target)
		return
	if gd and gd.kind == "lighter" and gd.lit and target.has_c(&"molotov"):
		target.c(&"molotov").light(user)
		return
	var mob: CMob = user.c(&"mob")
	var combat := mob != null and mob.combat
	# tg water/expose_obj: water splashed on a monkey cube makes a monkey
	var wr: CReagents = item.c(&"reagents")
	if wr and target.tags.has("monkeycube") and wr.is_open() and wr.contents.get("water", 0.0) > 0.0:
		Game.visible_message(target.root_cell(), "%s pours some water onto %s." % [user.display_name, target.the()])
		wr.take(minf(wr.transfer, wr.contents["water"]))
		Monkeys.expose_water(target)
		return
	if target.has_c(&"health"):
		if target == user and not combat and RockMetabolism.consume(user, item): return
		# tg genetics: DNA injectors and the sequence scanner
		var dj: CDnaInjector = item.c(&"dnainjector")
		if dj:
			dj.attack(user, target)
			return
		var sq: CSeqScanner = item.c(&"seqscanner")
		if sq:
			sq.use_on(user, target)
			return
		var rg: CReagents = item.c(&"reagents")
		if rg and rg.use_on_mob(user, target):
			return
		var sgt: CSurgeryTool = item.c(&"surgerytool")
		# tg embedding on_item_interaction: tweeze it out with a hemostat or wirecutters
		var is_pluck: bool = (sgt and sgt.kind == "hemostat") or (item.has_c(&"item") and item.c(&"item").tool == "wirecutters")
		if is_pluck and not combat and not target.c(&"health").embedded.is_empty() and Surgery.state(target).is_empty():
			var ems := Embeds.on_part(target.c(&"health"), Body.part_of(mob.aimed_zone() if mob else "chest"))
			if not ems.is_empty():
				Embeds.try_pluck(user, target, ems[0], item)
				return
		if sgt and not combat and _discoordinated(user, item):
			return
		if sgt and not combat and Surgery.use_tool(user, target, sgt.kind):
			return
		if not combat and Surgery.state(target).is_empty() and try_cauterize(user, target, item):
			return
		var meds: CMedItem = item.c(&"meditem")
		if meds and not combat:
			meds.apply(user, target)
			return
		var sg: CSecurityGear = item.c(&"secgear")
		if sg:
			if sg.kind == "cuffs":
				sg.cuff(user, target)
				return
			if sg.kind == "baton" and sg.stun_hit(user, target):
				_crime_check(user, target, "assault")
				return
		var food: CFood = item.c(&"food")
		if food and target == user:
			food.consume(user)
			return
		if food and not combat:
			Game.visible_message(user.cell, "%s feeds %s to %s." % [user.display_name, item.display_name, target.display_name])
			food.consume(target)
			return
		attack(user, target, item)
		return
	if target.attackby(user, item):
		return
	# tg tool acts: deconstruction, anchoring, welding closets shut, building frames
	if not combat and item.c(&"item") and item.c(&"item").tool != "" and _discoordinated(user, item):
		return
	if not combat and Construction.tool_act(user, item, target):
		return
	if target.has_c(&"storage") and target.c(&"storage").kind == "closet" and target.c(&"storage").is_open and not combat:
		user.c(&"inv").drop(item, target.cell)
		return
	# tg attack_atom: nothing special happened, so you hit it with the thing
	if hit_object(user, item, target):
		return
	use_on_tile(user, item, target.cell)

## tg ISADVANCEDTOOLUSER: the discoordination trauma leaves you unable to work tools.
static func _discoordinated(user: Entity, item: Entity) -> bool:
	var h: CHealth = user.c(&"health")
	if h == null or h.traumas.is_empty() or not Traumas.discoordinated(h):
		return false
	Game.tell(user, "You don't have the dexterity to use %s!" % item.the(), "warn")
	return true

static func can_be_hit(target: Entity) -> bool:
	return not target.has_c(&"item") and not target.has_c(&"decal") and (target.has_c(&"integrity") or target.has_c(&"machine"))

## tg /obj/item/proc/attack_atom + /atom/proc/attacked_by. Returns true if it was a hit.
static func hit_object(user: Entity, item: Entity, target: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it == null or not can_be_hit(target):
		return false
	var force := Combat.item_force(user, item)
	if force <= 0.0:
		return false # tg NOBLUDGEON / no force: nothing happens
	if not Combat.ready_to_attack(user):
		return true
	Combat._set_cooldown(user, item)
	if user.has_c(&"mob"):
		user.c(&"mob").lunge(target.cell) # tg do_attack_animation
	var where := target.cell
	Combat.strike_object(user, target, item)
	Bus.stimulus.emit({"type": "vandalism", "actor": user, "target": target, "cell": where, "loud": 6.0, "illegal": false})
	return true

static func hand_on(user: Entity, target: Entity) -> void:
	var mob: CMob = user.c(&"mob")
	if not target.has_c(&"mob"):
		Forensics.touch(target, user) # tg atom/attack_hand: add_fingerprint
	# tg carbon attack_hand: wounds get first go (wrenching a dislocation, a fissure)
	if target != user and target.has_c(&"health") and mob and try_handle_wounds(user, target):
		return
	# tg embedding rip_out: pull out what's stuck in the part you're aiming at
	if target.has_c(&"health") and mob and (target == user or mob.intent == "help") and not target.c(&"health").embedded.is_empty():
		var ems := Embeds.on_part(target.c(&"health"), Body.part_of(mob.aimed_zone()))
		if not ems.is_empty():
			Embeds.rip_out(user, target, ems[0])
			return
	if target == user and target.has_c(&"health") and (mob == null or not mob.combat):
		check_self(user)
		return
	# Skyfarer: some people are a counter rather than somebody you are trying to hug.
	# Clicking a trader opens their shop, because that is obviously what the click meant.
	# You have to genuinely mean it — combat mode on, or harm intent — to swing at them,
	# and the shop refuses to serve somebody who just did.
	if target != user and target.has_c(&"vendor") and mob != null and not mob.combat and mob.intent == "help":
		target.c(&"vendor").open_counter(user)
		return
	if target.has_c(&"health") and target != user:
		match mob.intent if mob else "help":
			"harm":
				Combat.melee(user, target, null)
			"disarm":
				Combat.shove(user, target)
			"grab":
				grab(user, target)
			_:
				help_hand(user, target)
		return
	if target.has_c(&"item") and target.holder == null:
		pickup(user, target)
		return
	if target.attack_hand(user):
		return

# ------------------------------------------------------------------ combat
## tg grabs: a first grab is passive (you pull them), grabbing again tightens it to
## aggressive (hard to break, they can't use their hands well), then a neck grab (they
## are pinned and can barely struggle). Each step needs a moment.
static func grab(user: Entity, target: Entity) -> void:
	var um: CMob = user.c(&"mob")
	var tm: CMob = target.c(&"mob")
	if um == null or tm == null or not user.adjacent(target):
		return
	if um.pulling != target:
		um.start_pulling(target)
		um.grab_state = 0
		Game.visible_message(target.cell, "%s grabs %s passively." % [user.display_name, target.display_name], "warn")
		Sfx.play("punch", target.cell, 0.25)
		return
	if um.grab_state >= 2 or not Combat.ready_to_attack(user):
		return
	Combat._set_cooldown(user, null)
	um.grab_state += 1
	if um.grab_state == 1:
		Game.visible_message(target.cell, "%s grabs %s aggressively!" % [user.display_name, target.display_name], "bad")
	else:
		Game.visible_message(target.cell, "%s grabs %s by the neck!" % [user.display_name, target.display_name], "bad")
		target.c(&"health").knockdown(2.0)
	Sfx.play("punch", target.cell, 0.4)
	_crime_check(user, target, "assault")

static func attack(user: Entity, target: Entity, item: Entity) -> void:
	Combat.melee(user, target, item)

## Crew in the middle of an emergency job (fixing a breach, getting the power back,
## reaching a patient, fighting a fire) may force their way through; nobody calls that a
## break-in. Players answer for themselves.
const EMERGENCY_GOALS := ["fix_leak", "fix_breach", "fix_cable", "power", "fix_machine", "reactor", "extinguish", "rescue", "treat", "defib",
	"evacuate", "help_burning", "breathe", "get_warm", "escape_gas", "flee_fire", "arrest", "stop_fight", "escort", "refill_air"]

static func on_emergency_duty(user: Entity) -> bool:
	var b = user.c(&"brain")
	return b != null and String(b.goal.get("id", "")) in EMERGENCY_GOALS

static func _crime_check(user: Entity, target: Entity, crime: String) -> void:
	Bus.stimulus.emit({"type": crime, "actor": user, "target": target, "cell": target.cell, "loud": 6.0, "illegal": not (crime == "assault" and Combat._lawful_force(user, target))})

## Clicking yourself with an empty hand: look yourself over, part by part (tg bodypart
## damage words: bruised / battered / mangled).
static func check_self(user: Entity) -> void:
	var h: CHealth = user.c(&"health")
	if h.on_fire > 0:
		Game.tell(user, "You're on fire! Stop, drop and roll (B).", "bad")
	Game.visible_message(user.cell, "%s examines %sself." % [user.display_name, "them"])
	var lines := ["[b]You check yourself for injuries.[/b]"]
	# tg bodypart/check_for_injuries: each part against its max damage; Self-Aware reads the
	# numbers; Numb (fake_healthy) feels nothing wrong
	var aware := Quirks.has(user, "selfaware")
	var numb := Quirks.has(user, "numb")
	for part in Body.PARTS:
		var pn: String = Body.PARTS[part]["name"]
		if h.missing.has(part):
			lines.append("  [color=#ff5a4a]Your %s is missing![/color]" % pn)
			continue
		var burn_d := Body.part_burn(h, part)
		var brute_d := maxf(0.0, Body.part_damage(h, part) - burn_d)
		if numb:
			brute_d = 0.0
			burn_d = 0.0
		var mx: float = Body.PARTS[part]["max"]
		var status := ""
		if aware:
			status = "no damage" if brute_d <= 0.01 and burn_d <= 0.01 else "%d brute damage and %d burn damage" % [roundi(brute_d), roundi(burn_d)]
		else:
			if brute_d > mx * 0.8: status += "mangled"
			elif brute_d > mx * 0.4: status += "battered"
			elif brute_d > 0.01: status += "bruised"
			if brute_d > 0.01 and burn_d > 0.01: status += " and "
			if burn_d > mx * 0.8: status += "peeling away"
			elif burn_d > mx * 0.2: status += "blistered"
			elif burn_d > 0.01: status += "numb"
			if status == "": status = "OK"
		var ok := status == "OK" or status == "no damage"
		var disabled := ""
		if not numb and part in Body.LIMBS and Body.limb_disabled(h, part):
			disabled = " is disabled" + (" but otherwise" if ok else " and")
		lines.append("  [color=%s]Your %s%s%s%s.[/color]" % ["#6ae88a" if ok else "#ffb84a", pn, disabled, " has " if aware else " looks ", status])
	if Body.bleed_rate(h) > 0.0 and not numb:
		lines.append("  [color=#ff5a4a]You are bleeding![/color]")
	# tg check_self_for_injuries: embedded objects (aim at the part and use your hand to rip it out)
	for em in h.embedded:
		if em["data"]["stealthy"]:
			lines.append("  [color=#ff5a4a]There is something in your %s![/color]" % Body.pname(em["part"]))
		else:
			lines.append("  [color=#ff5a4a]There is a %s embedded in your %s![/color]" % [em["name"], Body.pname(em["part"])])
	# tg organ feel_for_damage
	for slot in Organs.ORDER:
		var f := Organs.feel(h, slot)
		if f != "":
			lines.append("  [color=#ffb84a]%s[/color]" % f)
	for l in Body.self_check_lines(h):
		lines.append("  " + l)
	for gp in h.gauze:
		lines.append("  Your %s is wrapped in %s%s." % [Body.pname(gp), Body._gauze_word(h.gauze[gp]["cap"]), h.gauze[gp]["name"]])
	for p in h.missing:
		lines.append("  [color=#ff5a4a][b]Your %s is gone![/b][/color]" % Body.PARTS[p]["name"])
	if h.blood_volume < Body.BLOOD_VOLUME_SAFE:
		lines.append("  [color=#c8b8b8]You feel light-headed.[/color]")
	if h.eye_damage > 10:
		lines.append("  [color=#ffb84a]Your eyes hurt.[/color]")
	Game.tell(user, "\n".join(lines), "info")

## tg carbon/help_shake_act: help intent on someone. On fire: you can't pat it out bare-
## handed. Lying down: shake them to get them up. Aimed at the head: a headpat. Otherwise a
## hug (a bear hug with an aggressive grab), which shares body heat and lifts moods. Every
## kind of shake knocks 6 s off their stuns and 10 s off sleep, and gets them up.
static func help_hand(user: Entity, target: Entity) -> void:
	var h: CHealth = target.c(&"health")
	var tm: CMob = target.c(&"mob")
	if h == null or tm == null:
		return
	if h.on_fire > 0.0:
		Game.tell(user, "You can't put %s out with just your bare hands!" % tm.them(), "warn")
		return
	var um: CMob = user.c(&"mob")
	var uh: CHealth = user.c(&"health")
	if h.lying():
		if tm.buckled != null:
			Game.tell(user, "You need to unbuckle %s first to do that!" % target.display_name, "warn")
			return
		Game.visible_message(target.cell, "%s shakes %s trying to get %s up!" % [user.display_name, target.display_name, tm.them()])
		Game.tell(target, "%s shakes you to get you up!" % user.display_name)
	elif um and Body.part_of(um.zone) == "head" and not h.missing.has("head"):
		Game.visible_message(target.cell, "%s gives %s a pat on the head to make %s feel better!" % [user.display_name, target.display_name, tm.them()])
	else:
		var bear: bool = um != null and um.pulling == target and um.grab_state >= 1
		if bear:
			Game.visible_message(target.cell, "%s embraces %s in a tight bear hug!" % [user.display_name, target.display_name])
			Game.tell(target, "%s squeezes you super tightly in a firm bear hug!" % user.display_name)
		else:
			Game.visible_message(target.cell, "%s hugs %s to make %s feel better!" % [user.display_name, target.display_name, tm.them()])
			Game.tell(target, "%s hugs you to make you feel better!" % user.display_name)
		# tg share_bodytemperature: half the difference moves across
		if uh:
			var diff := h.body_temp - uh.body_temp
			h.body_temp -= diff * 0.5
			uh.body_temp += diff * 0.5
		var tmood: CMood = target.c(&"mood")
		var umood: CMood = user.c(&"mood")
		if tmood:
			if bear:
				tmood.add("hug", "bear_hug")
			elif uh and h.body_temp > uh.body_temp:
				if umood:
					umood.add("hug", "warmhug")
				tmood.add("hug", "hug")
			else:
				tmood.add("hug", "warmhug")
			# tg TRAIT_FRIENDLY: a friendly hugger in a good way makes it special
			if Quirks.has(user, "friendly") and umood:
				if umood.sanity >= CMood.SANITY_GREAT:
					tmood.add("friendly_hug", "besthug", user.display_name)
				elif umood.sanity >= CMood.SANITY_DISTURBED:
					tmood.add("friendly_hug", "betterhug", user.display_name)
		Bus.stimulus.emit({"type": "hug", "actor": user, "target": target, "cell": target.cell, "loud": 0.0})
	# tg adjust_status_effects_on_shake_up, set_resting(FALSE), get_up(TRUE)
	var was_down := h.incapacitated()
	for id in ["stun", "knockdown", "unconscious", "paralyzed", "immobilized"]:
		if h.has_status(id):
			h.set_status(id, maxf(0.0, h.status_left(id) - 6.0))
	if h.has_status("sleeping"):
		h.set_status("sleeping", maxf(0.0, h.status_left("sleeping") - 10.0))
	if h.sleeping:
		h.wake()
	h.set_resting(false)
	if h.lying() and tm.buckled == null and not h.floored():
		h.get_up(true)
	Sfx.play("jump", target.cell, 0.5) # tg thudswoosh
	if was_down:
		tm.emote_anim("twitch") # tg shake_up_animation

static func cpr(user: Entity, target: Entity) -> void:
	var h: CHealth = target.c(&"health")
	if h == null or h.dead:
		return
	Game.visible_message(target.cell, "%s is trying to perform CPR on %s!" % [user.display_name, target.display_name], "warn")
	DoAfter.start(user, target, 3.0, func(ok):
		if ok and not h.dead:
			# tg: CPR on someone in crit feels good
			if h.health() <= h.crit_threshold():
				CMood.event(user, "saved_life", "saved_life")
			h.adjust("oxy", -12.0)
			Game.visible_message(target.cell, "%s performs CPR on %s." % [user.display_name, target.display_name])
			Bus.stimulus.emit({"type": "rescue", "actor": user, "target": target, "cell": target.cell, "loud": 1.0})
	)

## tg: welding without eye protection hurts your eyes a little every time.
static func weld_flash(user: Entity) -> void:
	var inv: CInventory = user.c(&"inv")
	var h: CHealth = user.c(&"health")
	if inv == null or h == null:
		return
	# tg /datum/element/tool_flash: a lit welder (light_range 2) flashes its user
	StatusFx.flash_act(h, 2)

## Electrocution. Returns false if insulated gloves stopped it.
static func shock(user: Entity, dmg: float) -> bool:
	if Traits.has(user, "shockimmune"): # tg TRAIT_SHOCKIMMUNE (the insulated mutation)
		return false
	var inv: CInventory = user.c(&"inv")
	if inv:
		var g: Entity = inv.worn("gloves")
		if g and g.has_c(&"clothing") and g.c(&"clothing").insulated_gloves:
			return false
	var h: CHealth = user.c(&"health")
	if h and dmg >= 1.0:
		# tg carbon/electrocute_act: burns; stuns you upright (or floors you if you were
		# already helpless), jitter 20 s, stutter 4 s, and 2 s later a paralysing second jolt
		var stun_duration := 4.0
		h.adjust("burn", dmg)
		if h.incapacitated():
			h.paralyze(stun_duration)
		else:
			h.stun(stun_duration)
		h.adjust_status("jitter", 20.0)
		h.adjust_status("stutter", 4.0)
		# Follow pause and fast-forward, like the initial stun and all other statuses.
		h.shock_jolts.append(2.0)
		Game.tell(user, "[b]You feel a powerful shock coursing through your body![/b]", "bad")
	Fx.sparks(user.cell)
	Game.visible_message(user.cell, "%s was shocked by it!" % user.display_name, "bad")
	Bus.stimulus.emit({"type": "shocked", "actor": user, "target": user, "cell": user.cell, "loud": 4.0})
	return true

# ------------------------------------------------------------------ tiles / construction
static func use_on_tile(user: Entity, item: Entity, cell: Vector2i) -> bool:
	var map := Game.map
	var it: CItem = item.c(&"item")
	if it == null:
		return false
	if item.proto == "soap":
		# tg soap: scrub the floor clean
		var mess := Game.at_with(cell, &"decal").filter(func(d): return d != item and d.c(&"decal").cleanable)
		if not mess.is_empty():
			Game.visible_message(cell, "%s starts scrubbing the floor with %s." % [user.display_name, item.the()])
			DoAfter.start(user, null, 2.5, func(ok):
				if ok:
					for d in mess:
						if is_instance_valid(d) and not d.removed:
							d.destroy()
					Game.visible_message(cell, "%s scrubs the floor clean." % user.display_name)
			)
			return true
	if item.has_c(&"gasanalyzer"):
		item.c(&"gasanalyzer").scan_tile(user, cell)
		return true
	if it.tool == "mop" and not Game.map.is_solid_turf(cell):
		return Janitor.mop_tile(user, item, cell)
	if item.has_c(&"shiprig"):
		return item.c(&"shiprig").use_on_cell(user, cell)
	# Skyfarer: the things that act on a bare tile — fitting a module into a hole, casting
	# a line into open air, firing a held aether weapon at something a long way off
	for comp in [&"shipmodule", &"skyrod", &"aethergun"]:
		if item.has_c(comp):
			return item.c(comp).use_on_cell(user, cell)
	# a gun mount on your own ship, fired by clicking what you want hit
	if CShipGun.fire_from_ship(user, cell):
		return true
	if item.has_c(&"rcd"):
		return item.c(&"rcd").act(user, cell)
	if item.has_c(&"rpd"):
		return item.c(&"rpd").act(user, cell)
	if item.has_c(&"pipefitting") and not Game.map.blocks_move_static(cell):
		# set the fitting down where it's going; then wrench it
		user.c(&"inv").drop(item, cell)
		Game.tell(user, "You set %s down. Wrench it to fasten it." % item.the())
		return true
	var t := map.get_turf(cell)
	var fl: int = Defs.TURFS[t]["flags"]
	var i := map.idx(cell)
	# repair leaking pipes (welder), the engineer's bread and butter
	if it.tool == "welder" and item.c(&"welder") and item.c(&"welder").lit:
		weld_flash(user)
		# (in combat mode you'd rather burn it: that falls through to hit_tile)
		if Defs.is_window(map.structure[i]) and not (user.has_c(&"mob") and user.c(&"mob").combat):
			Structures.weld_repair(user, cell)
			return true
		for layer in StationMap.PIPE_LAYER_COUNT:
			if map.pipe_mask(layer, cell) != 0 and map.pipe_hp_at(layer, cell) < 100:
				var dur := 5.0 * Skills.speed(user, "engineering")
				Game.visible_message(cell, "%s starts welding the damaged pipe." % user.display_name)
				DoAfter.start(user, null, dur, func(ok):
					if ok and item.c(&"welder").use_fuel(1.0):
						map.repair_pipe(layer, cell)
						Game.visible_message(cell, "%s welds the pipe back together." % user.display_name, "good")
						Bus.stimulus.emit({"type": "repaired", "actor": user, "cell": cell, "loud": 1.0, "what": "pipe"})
				)
				return true
		if fl & Defs.F_WALL:
			Game.visible_message(cell, "%s starts slicing through the wall." % user.display_name, "warn")
			DoAfter.start(user, null, 12.0 if t == Defs.T_WALL else 25.0, func(ok):
				if ok:
					map.set_turf(cell, Defs.T_PLATING)
					map.set_structure(cell, Defs.S_GIRDER)
					Proto.spawn("sheet_metal", cell, {"comps": {"stack": {"amount": 2}}})
					Bus.stimulus.emit({"type": "deconstruct", "actor": user, "cell": cell, "loud": 6.0, "illegal": not user.c(&"inv").has_access("engineering")})
			)
			return true
		if map.structure[i] == Defs.S_GIRDER:
			DoAfter.start(user, null, 4.0, func(ok):
				if ok:
					map.set_structure(cell, Defs.S_NONE)
					Proto.spawn("sheet_metal", cell, {"comps": {"stack": {"amount": 2}}})
			)
			return true
	# tg cable multitool_act: read the powernet this cable is part of
	if it.tool == "multitool" and map.cable[i] > 0 and not (fl & Defs.F_FLOOR) and Game.power:
		Game.tell(user, Game.power.cable_report(cell), "examine")
		return true
	if it.tool == "wirecutters" and map.cable[i] > 0 and not (fl & Defs.F_FLOOR):
		DoAfter.start(user, null, 1.5, func(ok):
			if ok:
				map.cable[i] = 0
				Bus.cables_changed.emit()
				Proto.spawn("cable_coil", cell, {"comps": {"stack": {"amount": 1}}})
				Game.visible_message(cell, "%s cuts the cable." % user.display_name)
				if Game.power and Game.power.cell_powered(cell):
					shock(user, 20.0)
				Bus.stimulus.emit({"type": "sabotage", "actor": user, "cell": cell, "loud": 2.0, "illegal": not user.c(&"inv").has_access("engineering"), "text": "cut power cables"})
		)
		return true
	if item.has_c(&"stack"):
		var st: CStack = item.c(&"stack")
		match st.material:
			"cable":
				if map.cable[i] == 2:
					DoAfter.start(user, null, 2.5 * Skills.speed(user, "engineering"), func(ok):
						if ok and st.use(1):
							map.cable[i] = 1
							Bus.cables_changed.emit()
							Game.visible_message(cell, "%s splices the damaged cable." % user.display_name, "good")
							Bus.stimulus.emit({"type": "repaired", "actor": user, "cell": cell, "loud": 1.0, "what": "cable"})
					)
					return true
				if map.cable[i] == 0 and not (fl & Defs.F_FLOOR) and not (fl & Defs.F_SOLID) and not (fl & Defs.F_OUTDOOR):
					if st.use(1):
						map.cable[i] = 1
						Bus.cables_changed.emit()
						Game.tell(user, "You lay down a cable.")
					return true
			"metal":
				if map.structure[i] == Defs.S_GIRDER:
					DoAfter.start(user, null, 5.0 * Skills.speed(user, "construction"), func(ok):
						if ok and st.amount >= 2 and st.use(2):
							map.set_structure(cell, Defs.S_NONE)
							map.set_turf(cell, Defs.T_WALL)
							Skills.add_xp(user, "construction", 20.0)
							Game.visible_message(cell, "%s finishes the wall." % user.display_name)
					)
					return true
				if t == Defs.T_PLATING and map.structure[i] == Defs.S_NONE:
					if st.use(1):
						map.set_turf(cell, Defs.T_STEEL)
						Skills.add_xp(user, "construction", 3.0)
						Game.tell(user, "You lay a floor tile.")
					return true
				if (fl & Defs.F_OUTDOOR) and map.structure[i] == Defs.S_NONE:
					DoAfter.start(user, null, 3.0, func(ok):
						if ok and st.use(1):
							map.set_turf(cell, Defs.T_PLATING)
							Game.tell(user, "You lay a plating foundation.")
					)
					return true
				if t == Defs.T_PLATING and st.amount >= 2 and Game.at(cell).is_empty():
					DoAfter.start(user, null, 3.0, func(ok):
						if ok and st.use(2):
							map.set_structure(cell, Defs.S_GIRDER)
					)
					return true
			"glass", "rglass":
				# tg grille item_interaction: two sheets of glass on an intact grille make a
				# full-tile window (reinforced glass, a reinforced one)
				if map.structure[i] == Defs.S_GRILLE_BROKEN:
					Game.tell(user, "The grille is broken. Fix it with a rod first.", "warn")
					return true
				if map.structure[i] == Defs.S_GRILLE:
					if st.amount < 2:
						Game.tell(user, "You need more %s to do that." % item.display_name, "warn")
						return true
					var kind := Defs.S_RWINDOW if st.material == "rglass" else Defs.S_WINDOW
					Game.visible_message(cell, "%s starts placing a window on the grille." % user.display_name)
					DoAfter.start(user, null, 3.0 * Skills.speed(user, "construction"), func(ok):
						if ok and map.structure[i] == Defs.S_GRILLE and st.use(2):
							map.set_structure(cell, kind)
							Skills.add_xp(user, "construction", 12.0)
							Sfx.play("glass_knock", cell, 0.8)
							if Game.atmos:
								Game.atmos.wake(cell)
							Game.visible_message(cell, "%s installs a new %s." % [user.display_name, Defs.STRUCTS[kind]["name"]], "good")
							Bus.stimulus.emit({"type": "repaired", "actor": user, "cell": cell, "loud": 1.0, "what": "window"})
					)
					return true
	if it.tool == "crowbar" and (fl & Defs.F_FLOOR):
		DoAfter.start(user, null, 1.5, func(ok):
			if ok:
				map.set_turf(cell, Defs.T_PLATING)
				Proto.spawn("floor_tile", cell, {"comps": {"stack": {"amount": 1}}})
				Game.tell(user, "You pry up the floor tile.")
		)
		return true
	if item.proto == "wallframe":
		return Construction.place_wallframe(user, item, cell)
	if item.has_c(&"stack") and item.c(&"stack").material == "tile" and t == Defs.T_PLATING and map.structure[i] == Defs.S_NONE:
		if item.c(&"stack").use(1):
			map.set_turf(cell, Defs.T_STEEL)
			Sfx.play("ratchet", cell, 0.4)
			Skills.add_xp(user, "construction", 2.0)
		return true
	if it.tool == "wrench":
		for layer in StationMap.PIPE_LAYER_COUNT:
			if map.pipe_mask(layer, cell) != 0 and map.pipe_hp_at(layer, cell) < 100 and map.pipe_hp_at(layer, cell) >= 30:
				DoAfter.start(user, null, 3.0, func(ok):
					if ok:
						map.repair_pipe(layer, cell)
						Game.visible_message(cell, "%s tightens the loose pipe fitting." % user.display_name, "good")
						Bus.stimulus.emit({"type": "repaired", "actor": user, "cell": cell, "loud": 1.0, "what": "pipe"})
				)
				return true
		if PipeWork.try_unwrench(user, item, cell):
			return true
		if map.structure[i] == Defs.S_GIRDER:
			DoAfter.start(user, null, 3.0, func(ok):
				if ok:
					map.set_structure(cell, Defs.S_NONE)
					Proto.spawn("sheet_metal", cell, {"comps": {"stack": {"amount": 2}}})
			)
			return true
	if it.tool == "dig" and (fl & Defs.F_ROCK):
		var dur := 4.0 * Skills.speed(user, "mining")
		Sfx.play("dig", cell)
		DoAfter.start(user, null, dur, func(ok):
			if ok:
				mine(cell, user)
				Skills.add_xp(user, "mining", 8.0)
		)
		return true
	if it.tool == "dig" and (fl & Defs.F_OUTDOOR):
		DoAfter.start(user, null, 3.0, func(ok):
			if ok:
				Proto.spawn("ice_chunk", cell)
				Game.tell(user, "You chip out a chunk of rime-ice.")
		)
		return true
	if it.tool == "wirecutters" and Defs.is_grille(map.structure[i]):
		# tg grille wirecutter_act: cut it apart (a live one shocks you), the rods drop
		if map.structure[i] == Defs.S_GRILLE and _grille_shock(user, cell, 1.0):
			return true
		Structures.break_grille(cell, user)
		Sfx.play("grille_hit", cell, 0.6)
		Game.visible_message(cell, "%s cuts the grille apart." % user.display_name)
		return true
	if item.has_c(&"stack") and item.c(&"stack").material == "rods":
		var rods: CStack = item.c(&"stack")
		# tg grille item_interaction: a rod straightens a broken grille
		if map.structure[i] == Defs.S_GRILLE_BROKEN:
			DoAfter.start(user, null, 1.0, func(ok):
				if ok and map.structure[i] == Defs.S_GRILLE_BROKEN and not _grille_shock(user, cell, 0.9) and rods.use(1):
					map.set_structure(cell, Defs.S_GRILLE)
					Game.visible_message(cell, "%s rebuilds the broken grille." % user.display_name)
					if Game.atmos:
						Game.atmos.wake(cell)
			)
			return true
		if map.structure[i] == Defs.S_NONE and (fl & (Defs.F_FLOOR | Defs.F_OUTDOOR) or t == Defs.T_PLATING) and not (fl & Defs.F_SOLID) and not Game.at(cell).any(func(x): return (x.has_c(&"blocker") and x.c(&"blocker").dense) or x.has_c(&"mob")):
			if rods.amount < 2:
				Game.tell(user, "You need at least two rods to build a grille.", "warn")
				return true
			DoAfter.start(user, null, 1.0, func(ok):
				if ok and map.structure[i] == Defs.S_NONE and rods.use(2):
					map.set_structure(cell, Defs.S_GRILLE)
					Game.visible_message(cell, "%s builds a grille." % user.display_name)
			)
			return true
	# nothing special: drop onto adjacent tile? no, SS13 does nothing.
	return false

# ------------------------------------------------------------------ walls, windows, grilles
## tg attack_hand on walls, windows and grilles: an empty hand on a structure.
##   wall:   "You push the wall but nothing happens!" and a tap (turf/closed/wall/attack_hand)
##   window: knock (help) or bash (combat), no damage (structure/window/attack_hand)
##   grille: a kick for 5-10 melee, unless it's live and shocks you (structure/grille/attack_hand)
static func hand_on_tile(user: Entity, cell: Vector2i) -> void:
	var map := Game.map
	if not map.inb(cell):
		return
	var i := map.idx(cell)
	var s: int = map.structure[i]
	var mob: CMob = user.c(&"mob")
	var combat := mob != null and mob.combat
	if not Defs.is_window(s) and not Defs.is_grille(s) and not map.is_wall(cell):
		return
	if not Combat.ready_to_attack(user):
		return
	Combat._set_cooldown(user, null) # tg changeNext_move(CLICK_CD_MELEE)
	if Defs.is_window(s):
		if combat:
			Game.visible_message(cell, "%s bashes the %s!" % [user.display_name, Defs.STRUCTS[s]["name"]], "warn")
			Sfx.play("glass_bash", cell, 1.5)
			Fx.pane_flash(cell, 0.3)
			Bus.stimulus.emit({"type": "vandalism", "actor": user, "cell": cell, "loud": 5.0, "illegal": false})
			if mob:
				mob.lunge(cell)
		else:
			Game.visible_message(cell, "%s knocks on the %s." % [user.display_name, Defs.STRUCTS[s]["name"]])
			Sfx.play("glass_knock", cell, 1.2)
		return
	if Defs.is_grille(s):
		if mob:
			mob.lunge(cell)
		Fx.attack_effect(Vector2(cell * 32) + Vector2(16, 16), "kick") # tg ATTACK_EFFECT_KICK
		Game.visible_message(cell, "%s hits the %s." % [user.display_name, Defs.STRUCTS[s]["name"]], "warn")
		if not _grille_shock(user, cell, 0.7):
			Structures.take_damage(cell, float(Game.rng.randi_range(5, 10)), "brute", "melee", user, 0.0, true, user.cell)
		return
	# tg wall/attack_hulk: a hulk in combat mode smashes it; 40% (the wall's hardness) it
	# comes down, and the arm takes 20 brute for it
	if combat and Traits.has(user, "hulk"):
		if mob:
			mob.lunge(cell)
		var uh: CHealth = user.c(&"health")
		var arm := "r_arm" if (user.c(&"inv") == null or user.c(&"inv").active == 1) else "l_arm"
		if uh and (uh.missing.has(arm) or Body.limb_disabled(uh, arm)):
			return
		if Body.prob(40):
			Sfx.play("meteor", cell, 1.0)
			user.c(&"mob").say(Genetics.rand_pick([";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!"]))
			var dn: CDna = user.c(&"dna")
			if dn and (dn.has_mutation("hulk") or dn.has_mutation("hulk_ork")):
				uh.hurt_zone(arm, 20.0, "brute", null) # hulk_recoil (no_recoil hulks skip it)
			map.set_turf(cell, Defs.T_PLATING)
			map.set_structure(cell, Defs.S_GIRDER)
			spawn_debris(cell, 2)
		else:
			Sfx.play("bang", cell, 0.6)
			Game.visible_message(cell, "%s smashes the wall!" % user.display_name, "bad")
		return
	Game.tell(user, "You push the wall but nothing happens!")
	Sfx.play("wall_tap", cell, 1.2)

## tg attack_atom -> obj/attacked_by on a wall, window or grille with something in hand:
## the item's force (wielded, if two-handed) times its demolition modifier, through the
## structure's melee armour. Walls just take a knock (tg walls have no integrity for hand
## weapons at all). Returns true if it was a hit.
static func hit_tile(user: Entity, item: Entity, cell: Vector2i) -> bool:
	var map := Game.map
	var it: CItem = item.c(&"item")
	if it == null or not map.inb(cell):
		return false
	var i := map.idx(cell)
	var s: int = map.structure[i]
	var is_wall := map.is_wall(cell)
	if s == Defs.S_NONE and not is_wall:
		return false
	var force := Combat.item_force(user, item)
	if force <= 0.0:
		return false # tg NOBLUDGEON / no force: nothing happens
	if not Combat.ready_to_attack(user):
		return true
	Combat._set_cooldown(user, item)
	if user.has_c(&"mob"):
		user.c(&"mob").lunge(cell)
	var at := Vector2(cell * 32) + Vector2(16, 16)
	Fx.item_flick(item, user.position + Vector2(0, -16), at)
	if s == Defs.S_NONE:
		Game.visible_message(cell, "%s hits the wall with %s, without leaving a mark!" % [user.display_name, item.the()], "warn")
		Sfx.play("wall_hit", cell, 1.2)
		return true
	var what: String = Defs.STRUCTS[s]["name"]
	# tg grille item_interaction: a conductive item on a live grille can bite you instead
	if Defs.is_grille(s) and it.conducts and _grille_shock(user, cell, 0.7):
		return true
	var demo := Combat.demolition(user, item)
	var dealt := Structures.take_damage(cell, force * demo, Combat.damtype(item), "melee", user, it.armour_penetration, true, user.cell)
	# tg obj/attacked_by message: the item's verb, "pulverises" on a big demolition hit,
	# "ineffectively" when the tool is bad at breaking things
	var verb := it.attack_verb
	if demo > 1.0 and Game.rng.randf() < dealt * 0.05:
		verb = "pulverises"
	if demo < 1.0:
		verb = "ineffectively " + verb
	Game.visible_message(cell, "%s %s the %s with %s%s" % [user.display_name, verb, what, item.the(), "." if dealt > 0.0 else ", without leaving a mark!"], "warn")
	Combat.after_attack(user, item)
	Bus.stimulus.emit({"type": "vandalism", "actor": user, "cell": cell, "loud": 6.0, "illegal": false})
	return true

## tg grille/shock: a grille over a live cable bites whoever touches it, and the arc
## scorches the grille a little (50% for 1 fire damage).
static func _grille_shock(user: Entity, cell: Vector2i, chance: float) -> bool:
	var map := Game.map
	if map.structure[map.idx(cell)] != Defs.S_GRILLE: # broken grilles are never connected
		return false
	if chance <= 0.0 or map.cable[map.idx(cell)] == 0 or Game.power == null or not Game.power.cell_powered(cell):
		return false
	if Game.rng.randf() >= chance:
		return false
	Sfx.play("spark", cell)
	if not shock(user, 20.0):
		return false
	if Game.rng.randf() < 0.5:
		Structures.take_damage(cell, 1.0, "burn", "fire", null, 0.0, false)
	return true

static func mine(cell: Vector2i, user: Entity) -> void:
	var map := Game.map
	var t := map.get_turf(cell)
	var ore: String = Defs.TURFS[t].get("ore", "")
	map.set_turf(cell, Defs.T_GRAVEL)
	if ore != "":
		for k in Game.rng.randi_range(1, 3):
			Proto.spawn(ore, cell)
	elif Game.rng.randf() < 0.25:
		Proto.spawn("ice_chunk", cell)
	if user:
		Bus.stimulus.emit({"type": "mined", "actor": user, "cell": cell, "loud": 3.0})
	if Game.atmos:
		Game.atmos.wake(cell)

# ------------------------------------------------------------------ misc
static func throw_item(user: Entity, item: Entity, cell: Vector2i, range_override := -1) -> void:
	var inv: CInventory = user.c(&"inv")
	var d := cell - user.cell
	var dist := mini(maxi(absi(d.x), absi(d.y)), 6 + (2 if Quirks.has(user, "throwingarm") else 0)) # tg TRAIT_THROWINGARM
	if range_override >= 0: dist = mini(maxi(absi(d.x), absi(d.y)), range_override)
	if dist == 0:
		return
	var dir := Vector2(d).normalized()
	var land := user.cell
	for k in range(1, dist + 1):
		var c := user.cell + Vector2i(roundi(dir.x * k), roundi(dir.y * k))
		if Game.map.blocks_move_static(c) or Game.map.dense_count[Game.map.idx(c)] > 0:
			# tg obj/hitby: throwforce times the demolition modifier, through melee armour
			var ts: int = Game.map.structure[Game.map.idx(c)]
			if ts != Defs.S_NONE and Defs.struct_dense(ts):
				var tf: float = item.c(&"item").throwforce * Combat.demolition(null, item)
				if tf > 0.0:
					var sname: String = Defs.STRUCTS[ts]["name"]
					var dealt := Structures.take_damage(c, tf, "brute", "melee", user, 0.0, true, land)
					Game.visible_message(c, "%s hits the %s%s" % [item.the().capitalize(), sname, "." if dealt > 0.0 else ", without leaving a mark!"], "warn")
					Bus.stimulus.emit({"type": "vandalism", "actor": user, "cell": c, "loud": 6.0, "illegal": false})
			break
		land = c
		var hit := false
		for m in Game.at_with(c, &"health"):
			if m != user and not m.c(&"mob").is_lying():
				# tg embedding: a spear (or anything else that embeds) may lodge in them instead
				var ezone := Combat.pick_zone(user, m)
				var iname := item.the()
				if Embeds.try_thrown(user, item, m, ezone):
					Game.visible_message(user.cell, "%s throws %s." % [user.display_name, iname])
					Skills.add_xp(user, "throwing", 10.0)
					_crime_check(user, m, "assault")
					return
				# tg: thrown things hit with their throwforce; Throwing skill and Dexterity help
				var f: float = item.c(&"item").throwforce * (1.0 + Skills.level(user, "throwing") * 0.004 + Skills.attr_level(user, "dexterity") * 0.003)
				if f > 0:
					m.take_damage(f, item.c(&"item").damtype, user)
					Skills.add_xp(user, "throwing", f)
					Game.visible_message(c, "%s is hit by %s!" % [m.display_name, item.the()], "bad")
					_crime_check(user, m, "assault")
				hit = true
				break
		if hit:
			break
	inv.drop(item, user.cell)
	var flight := 0.06 * maxf(1.0, Vector2(land).distance_to(Vector2(user.cell)))
	glide(item, land, flight, true)
	Game.visible_message(user.cell, "%s throws %s." % [user.display_name, item.the()])
	var mo: CMolotov = item.c(&"molotov")
	if mo and mo.lit:
		item.get_tree().create_timer(flight).timeout.connect(func():
			if is_instance_valid(item) and not item.removed:
				mo.shatter(land, user)
		)

static func glide(ent: Entity, to: Vector2i, dur: float, spin := false) -> void:
	var from_pos := ent.position
	ent.place(to, false)
	var tw := ent.create_tween()
	tw.tween_property(ent, "position", Entity.cell_to_pos(to), dur).from(from_pos)
	# tg thrown things tumble through the air
	if spin and ent.spr:
		var sp := ent.spr
		var turns := maxf(1.0, dur / 0.12)
		var tw2 := ent.create_tween()
		tw2.tween_property(sp, "rotation", TAU * turns * (1.0 if Game.rng.randf() < 0.5 else -1.0), dur).from(0.0)
		tw2.tween_callback(func():
			if is_instance_valid(sp):
				sp.rotation = 0.0)

static func spawn_debris(cell: Vector2i, n: int) -> void:
	Proto.spawn("debris", cell, {"comps": {"stack": {"amount": n}}})

static func examine(user: Entity, target: Entity, cell: Vector2i) -> void:
	if target != null:
		Game.tell(user, target.examine_text(user), "examine")
		Bus.stimulus.emit({"type": "examined", "actor": user, "target": target, "cell": cell, "loud": 0.0})
		return
	var map := Game.map
	var lines := ["That's [b]%s[/b]." % Defs.TURFS[map.get_turf(cell)]["name"]]
	var s := map.structure[map.idx(cell)]
	if s != Defs.S_NONE:
		lines.append("There is a %s here." % Defs.STRUCTS[s]["name"])
		if s == Defs.S_GRILLE_BROKEN:
			lines.append("It appears to be broken.")
		else:
			# tg structure examine_status
			var pct: float = map.struct_hp[map.idx(cell)] / Structures.max_hp(s) * 100.0
			if pct < 25.0:
				lines.append("[color=#ff5a4a]It's falling apart![/color]")
			elif pct < 50.0:
				lines.append("[color=#ffb84a]It appears heavily damaged.[/color]")
			elif pct < 99.5:
				lines.append("It looks slightly damaged.")
		if Defs.is_window(s) and map.struct_hp[map.idx(cell)] < Structures.max_hp(s):
			lines.append("[color=#8a93a3]A lit blowtorch could repair it.[/color]")
		if Defs.is_grille(s):
			lines.append("[color=#8a93a3]The rods look like they could be [b]cut[/b] through.%s[/color]" % (" A [b]rod[/b] would straighten it out." if s == Defs.S_GRILLE_BROKEN else ""))
	for layer in StationMap.PIPE_LAYER_COUNT:
		if map.pipe_leaking(layer, cell) and (not map.has_floor_tile(cell) or Game.player == user):
			lines.append("[color=#ffb84a]A %s pipe here is hissing![/color]" % StationMap.PIPE_LAYER_NAMES[layer])
	if map.cable[map.idx(cell)] == 2:
		lines.append("[color=#ffb84a]A damaged power cable sparks here.[/color]")
	if Game.atmos and not map.is_solid_turf(cell):
		lines.append("[color=#8a9ab8]%.0f kPa, %.0f C[/color]" % [Game.atmos.pressure(map.idx(cell)), Game.atmos.temp[map.idx(cell)] - Defs.T0C])
	Game.tell(user, "\n".join(lines), "examine")


# ------------------------------------------------------------------ tg wound handling
## tg carbon grabbedby(self): hold your own bleeding part with a free hand to slow it (x0.7).
## Ctrl+click yourself with the part targeted; let go by dropping the grip or ctrl+clicking
## again.
static func self_grasp(user: Entity) -> void:
	var h: CHealth = user.c(&"health")
	var inv: CInventory = user.c(&"inv")
	var mob: CMob = user.c(&"mob")
	if h == null or inv == null or mob == null:
		return
	if h.grasp != "":
		release_grasp(user)
		return
	var part := Body.part_of(mob.zone)
	if not Body.can_be_grasped(h, part):
		return
	if (inv.active == 0 and part == "l_arm") or (inv.active == 1 and part == "r_arm"):
		Game.tell(user, "You can't grasp your %s with itself!" % Body.pname(part), "bad")
		return
	if inv.active_item() != null or Body.limb_disabled(h, "l_arm" if inv.active == 0 else "r_arm"):
		Game.tell(user, "You fail to grasp your %s." % Body.pname(part), "bad")
		return
	var bleeding_text := ", trying to stop the bleeding" if Body.part_bleed_rate(h, part) > 0.0 else ""
	Game.tell(user, "You try grasping at your %s%s..." % [Body.pname(part), bleeding_text], "warn")
	var hand := inv.active
	DoAfter.start(user, null, 0.75, func(ok):
		if not ok or inv.active != hand or inv.active_item() != null or not Body.can_be_grasped(h, part):
			Game.tell(user, "You fail to grasp your %s." % Body.pname(part), "bad")
			return
		var g := Proto.spawn("self_grasp", user.cell)
		g.tags["self_grasp"] = part
		inv.put_in_hands(g, hand)
		h.grasp = part
		Game.visible_message(user.cell, "%s grasps at their %s%s." % [user.display_name, Body.pname(part), bleeding_text], "warn")
		Game.tell(user, "You grab hold of your %s tightly." % Body.pname(part), "info"))

static func release_grasp(user: Entity) -> void:
	var h: CHealth = user.c(&"health")
	var inv: CInventory = user.c(&"inv")
	if h == null or h.grasp == "":
		return
	var part := h.grasp
	h.grasp = ""
	if inv:
		for i in 2:
			var it: Entity = inv.hands[i]
			if it and it.tags.has("self_grasp"):
				inv.remove_ref(it)
				it.destroy()
	Game.tell(user, "You stop holding onto your %s." % Body.pname(part), "info")

## tg slash/pierce treat: a cautery (or anything hot, on yourself or someone you have in an
## aggressive grab) closes some of the bleeding on the targeted part, 0.6 flow a go.
static func try_cauterize(user: Entity, target: Entity, item: Entity) -> bool:
	var th: CHealth = target.c(&"health")
	var mob: CMob = user.c(&"mob")
	if th == null or mob == null or item == null:
		return false
	var part := Body.part_of(mob.zone)
	var sgt: CSurgeryTool = item.c(&"surgerytool")
	var is_cautery := sgt != null and sgt.kind == "cautery"
	var hot := false
	if item.has_c(&"welder") and item.c(&"welder").lit:
		hot = true
	var gd: CGadget = item.c(&"gadget")
	if gd and gd.kind == "lighter" and gd.lit:
		hot = true
	if not is_cautery:
		if not hot:
			return false
		if user != target and not (mob.pulling == target and mob.grab_state >= 1):
			return false
	var bleeding := Body.wounds_on(th, part).filter(func(w): return w["type"] in ["slash", "pierce"] and w.get("flow", 0.0) > 0.0)
	if bleeding.is_empty():
		return false
	var self_use := user == target
	var t := 3.0 * (1.5 if self_use else 1.0) * (1.0 if is_cautery else 1.25)
	var who := "their" if self_use else "%s's" % target.display_name
	Game.visible_message(target.cell, "%s begins cauterizing %s %s with %s..." % [user.display_name, who, Body.pname(part), item.display_name], "warn")
	DoAfter.start(user, target, t, func(ok):
		if not ok:
			return
		if Body.cauterize(th, part, not is_cautery, self_use):
			Game.visible_message(target.cell, "%s cauterizes some of the bleeding on %s." % [user.display_name, target.display_name], "good")
			# tg: keep going while it still bleeds
			if Body.wounds_on(th, part).any(func(w): return w["type"] in ["slash", "pierce"] and w.get("flow", 0.0) > 0.0):
				try_cauterize(user, target, item))
	return true

## tg wound try_handling from attack_hand: wrench a dislocated limb back (65%; combat mode
## snaps it instead) with them in an aggressive grab; pull the eyes out of a split skull.
static func try_handle_wounds(user: Entity, target: Entity) -> bool:
	var th: CHealth = target.c(&"health")
	var mob: CMob = user.c(&"mob")
	var part := Body.part_of(mob.zone)
	var disl := Body.wound_on(th, part, "bone")
	if not disl.is_empty() and disl["sev"] == 1 and mob.pulling == target:
		if mob.grab_state < 1:
			Game.tell(user, "You must have %s in an aggressive grab to manipulate their dislocation!" % target.display_name, "warn")
			return true
		Game.visible_message(target.cell, "%s begins twisting and straining %s's dislocated %s!" % [user.display_name, target.display_name, Body.pname(part)], "bad")
		_wrench(user, target, part, mob.combat)
		return true
	var fis := Body.wound_on(th, "head", "fissure")
	if not fis.is_empty() and not mob.combat and mob.zone in ["head", "eyes"] and th.lying():
		if th.eyes_removed:
			Game.tell(user, "no eyes to take!", "warn")
			return true
		Game.visible_message(target.cell, "[b]%s reaches inside %s's skull...[/b]" % [user.display_name, target.display_name], "bad")
		DoAfter.start(user, target, 10.0, func(ok):
			if not ok or th.eyes_removed:
				return
			th.eyes_removed = true
			var eyes := Proto.spawn("organ_eyes", user.cell)
			var uinv: CInventory = user.c(&"inv")
			if uinv:
				uinv.put_in_hands(eyes)
			Game.visible_message(target.cell, "[b]%s rips out %s's eyes![/b]" % [user.display_name, target.display_name], "bad"))
		return true
	return false

static func _wrench(user: Entity, target: Entity, part: String, malpractice: bool) -> void:
	var th: CHealth = target.c(&"health")
	DoAfter.start(user, target, 5.0, func(ok):
		if not ok:
			return
		var r := Body.wrench_joint(th, part, malpractice)
		if r == 1:
			if malpractice:
				Game.visible_message(target.cell, "%s snaps %s's dislocated %s with a sickening crack!" % [user.display_name, target.display_name, Body.pname(part)], "bad")
			else:
				Game.visible_message(target.cell, "%s snaps %s's dislocated %s back into place!" % [user.display_name, target.display_name, Body.pname(part)], "good")
		elif r == 0:
			Game.visible_message(target.cell, "%s wrenches %s's dislocated %s around painfully!" % [user.display_name, target.display_name, Body.pname(part)], "bad")
			_wrench(user, target, part, malpractice))
