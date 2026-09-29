class_name Surgery extends RefCounted
## tg surgery (/datum/surgery), trimmed down. Lay the patient on an operating table, aim at
## a body part, drape them to choose a procedure, then work through its steps with the
## right tools: scalpel, hemostat, retractor, cautery (and a saw for the ribcage).
##
## Each step is a timed action with a success chance that depends on what the patient is
## lying on (tg: operating table 100%, a bed 80%, a table 70%, the floor 50%). An awake
## patient without anaesthetic makes it harder and flinches. A failed step hurts the part.
## A cautery at any point closes up and ends the operation.

const TOOLS := ["scalpel", "hemostat", "retractor", "cautery", "saw", "drapes", "bone_gel", "bonesetter", "limb", "organ"]
const TOOL_NAMES := {"scalpel": "a scalpel", "hemostat": "a hemostat", "retractor": "a retractor", "cautery": "a cautery", "saw": "a circular saw", "bone_gel": "bone gel", "bonesetter": "a bonesetter", "limb": "the severed limb", "organ": "an organ"}
## tg organ repair: heal_to_percent / failure_damage_percent
const ORGAN_REPAIR := {"lungs": [0.6, 0.1], "heart": [0.6, 0.2], "liver": [0.1, 0.15], "stomach": [0.2, 0.15]}
const LIMB_ZONES := ["l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot", "head"]

## Steps: tool, what it does, seconds. "repeat" steps can be done over and over (tending
## wounds) until the surgeon closes with the cautery.
const PROCEDURES := {
	"tend_brute": {"name": "Tend wounds (brute)", "zones": ["head", "chest", "groin", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot"],
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "hemostat", "text": "tend the wounds", "t": 2.5, "fx": "heal_brute", "repeat": true},
			{"tool": "cautery", "text": "close the incision", "t": 2.0, "fx": "close"},
		]},
	"tend_burn": {"name": "Tend wounds (burns)", "zones": ["head", "chest", "groin", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot"],
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "hemostat", "text": "debride the burns", "t": 2.5, "fx": "heal_burn", "repeat": true},
			{"tool": "cautery", "text": "close the incision", "t": 2.0, "fx": "close"},
		]},
	"eye_surgery": {"name": "Eye surgery", "zones": ["eyes"],
		"steps": [
			{"tool": "scalpel", "text": "cut around the eyes", "t": 2.5, "fx": "incise"},
			{"tool": "retractor", "text": "lift the eyes", "t": 2.0},
			{"tool": "hemostat", "text": "mend the eyes", "t": 4.0, "fx": "fix_eyes"},
			{"tool": "cautery", "text": "close up", "t": 2.0, "fx": "close"},
		]},
	# tg /datum/surgery/repair_bone_hairline and repair_bone_compound
	"repair_bone": {"name": "Repair bone fracture", "zones": ["head", "chest", "groin", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot"], "need": "fracture",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "bonesetter", "text": "reset the bone", "t": 3.0},
			{"tool": "bone_gel", "text": "repair the fracture", "t": 3.0, "fx": "fix_bone"},
			{"tool": "cautery", "text": "close the incision", "t": 2.0, "fx": "close"},
		]},
	# tg /datum/surgery/prosthetic_replacement: sew a limb back on
	"reattach": {"name": "Reattach limb", "zones": LIMB_ZONES, "need": "missing",
		"steps": [
			{"tool": "scalpel", "text": "clean up the stump", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "limb", "text": "attach the limb", "t": 4.0, "fx": "reattach"},
			{"tool": "cautery", "text": "seal the join", "t": 2.0, "fx": "close"},
		]},
	# tg /datum/surgery/amputation
	"amputate": {"name": "Amputation", "zones": LIMB_ZONES, "need": "present",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the bone", "t": 5.0, "fx": "amputate"},
			{"tool": "cautery", "text": "cauterize the stump", "t": 2.0, "fx": "close_stump"},
		]},
	# tg operation_organ_repair.dm: each opens up and repairs one organ once (brain surgery
	# can be repeated); a slip hurts the organ instead
	"lobectomy": {"name": "Lobectomy (lung surgery)", "zones": ["chest"], "need": "organ", "organ": "lungs",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the ribs", "t": 4.0},
			{"tool": "scalpel", "text": "excise the damaged lung lobe", "t": 4.2, "fx": "repair_organ"},
			{"tool": "cautery", "text": "close the chest", "t": 2.5, "fx": "close"},
		]},
	"coronary_bypass": {"name": "Coronary bypass (heart surgery)", "zones": ["chest"], "need": "organ", "organ": "heart",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the ribs", "t": 4.0},
			{"tool": "hemostat", "text": "graft a coronary bypass", "t": 9.0, "fx": "repair_organ"},
			{"tool": "cautery", "text": "close the chest", "t": 2.5, "fx": "close"},
		]},
	"hepatectomy": {"name": "Hepatectomy (liver surgery)", "zones": ["chest"], "need": "organ", "organ": "liver",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the ribs", "t": 4.0},
			{"tool": "scalpel", "text": "remove the damaged liver section", "t": 5.2, "fx": "repair_organ"},
			{"tool": "cautery", "text": "close the chest", "t": 2.5, "fx": "close"},
		]},
	"gastrectomy": {"name": "Gastrectomy (stomach surgery)", "zones": ["chest"], "need": "organ", "organ": "stomach",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the ribs", "t": 4.0},
			{"tool": "scalpel", "text": "remove the damaged stomach section", "t": 5.2, "fx": "repair_organ"},
			{"tool": "cautery", "text": "close the chest", "t": 2.5, "fx": "close"},
		]},
	# tg /datum/surgery_operation/organ/repair/brain: heals a quarter of the brain and cures
	# the severe traumas; a slip does 30% brain damage and a deep-rooted trauma
	"brain_surgery": {"name": "Brain surgery", "zones": ["head"], "need": "brain",
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw open the skull", "t": 5.0},
			{"tool": "hemostat", "text": "fix the brain", "t": 10.0, "fx": "fix_brain", "repeat": true},
			{"tool": "cautery", "text": "close the skull", "t": 2.5, "fx": "close"},
		]},
	# tg organ manipulation: take organs out with a hemostat, put new ones in by hand
	"organ_manip": {"name": "Organ manipulation", "zones": ["chest", "head"],
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the bone", "t": 4.0},
			{"tool": "hemostat", "alt": "organ", "text": "remove an organ (hemostat) or insert one", "t": 3.0, "fx": "manip", "repeat": true},
			{"tool": "cautery", "text": "close up", "t": 2.5, "fx": "close"},
		]},
	"ribcage": {"name": "Open the ribcage (toxin purge)", "zones": ["chest"],
		"steps": [
			{"tool": "scalpel", "text": "make an incision", "t": 2.5, "fx": "incise"},
			{"tool": "hemostat", "text": "clamp the bleeders", "t": 2.0, "fx": "clamp"},
			{"tool": "retractor", "text": "retract the skin", "t": 2.0},
			{"tool": "saw", "text": "saw through the ribs", "t": 4.0},
			{"tool": "hemostat", "text": "flush the organs", "t": 3.0, "fx": "heal_tox", "repeat": true},
			{"tool": "cautery", "text": "close the chest", "t": 2.5, "fx": "close"},
		]},
}

static func state(patient: Entity) -> Dictionary:
	return patient.get_meta("surgery", {}) if patient.has_meta("surgery") else {}

static func surface(patient: Entity) -> Array:
	## [success multiplier, what they're on]
	for e in Game.at(patient.root_cell()):
		if e.proto == "op_table":
			return [1.0, "the operating table"]
	for e in Game.at(patient.root_cell()):
		var f: CFurniture = e.c(&"furniture")
		if f and f.kind == "bed":
			return [0.8, e.display_name]
		if f and f.kind in ["table", "counter"]:
			return [0.7, e.display_name]
	return [0.5, "the floor"]

## Procedures that fit the part being aimed at.
static func options(zone: String, patient: Entity = null) -> Array:
	var out := []
	var h: CHealth = patient.c(&"health") if patient else null
	var part := Body.part_of(zone)
	for id in PROCEDURES:
		if not zone in PROCEDURES[id]["zones"]:
			continue
		if h:
			match PROCEDURES[id].get("need", ""):
				"missing":
					if not h.missing.has(part):
						continue
				"present":
					if h.missing.has(part) or part == "head" and not h.dead:
						continue
				"fracture":
					var w := Body.wound_on(h, part, "blunt")
					if w.is_empty() and Body.wound_on(h, part, "fissure").is_empty():
						continue
				"organ":
					# tg repair/state_check: damaged past heal_to_percent, not operated on before
					var slot: String = PROCEDURES[id]["organ"]
					var o := Organs.get_organ(h, slot)
					if o.is_empty() or o.get("operated", false) or o["dmg"] < Organs.DEFS[slot]["max"] * ORGAN_REPAIR[slot][0]:
						continue
				"brain":
					if not Organs.has(h, "brain"):
						continue
		out.append(id)
	return out

## A surgery tool used on someone. Returns true if it was surgery (so it isn't an attack).
static func use_tool(user: Entity, patient: Entity, kind: String) -> bool:
	var h: CHealth = patient.c(&"health")
	if h == null or (patient == user and not Traits.has(user, "self_surgery")) or not h.lying():
		return false
	var st := state(patient)
	var zone: String = user.c(&"mob").zone if user.has_c(&"mob") else "chest"
	if kind == "drapes":
		if st.is_empty():
			if options(zone, patient).is_empty():
				Game.tell(user, "There's nothing you can operate on there. Aim at a different body part.", "warn")
				return true
			Bus.ui_open_window.emit("surgery", patient)
			return true
		if st["step"] == 0:
			patient.remove_meta("surgery")
			Game.visible_message(patient.root_cell(), "%s removes the drapes from %s." % [user.display_name, patient.display_name])
			return true
		Game.tell(user, "The operation is under way. Close up with a cautery first.", "warn")
		return true
	if st.is_empty():
		return false # a scalpel on someone who isn't draped is just a knife
	var proc: Dictionary = PROCEDURES[st["proc"]]
	var steps: Array = proc["steps"]
	var step: Dictionary = steps[st["step"]]
	var closing: bool = kind == "cautery" and st["step"] > 0
	if kind != step["tool"] and kind != step.get("alt", "") and not closing:
		Game.tell(user, "Next you need to %s, with %s." % [step["text"], TOOL_NAMES.get(step["tool"], step["tool"])], "warn")
		return true
	var s := step
	if closing and kind != step["tool"]:
		s = steps[-1]
	Game.visible_message(patient.root_cell(), "%s begins to %s on %s's %s." % [user.display_name, s["text"], patient.display_name, Combat.ZONE_NAMES.get(st["zone"], st["zone"])])
	var tool_item: Entity = user.c(&"inv").active_item() if user.c(&"inv") else null
	DoAfter.start(user, patient, float(s["t"]) * Skills.speed(user, "medical"), func(ok): Surgery._finish_step(user, patient, s, closing, ok, tool_item))
	return true

static func begin(user: Entity, patient: Entity, proc_id: String) -> void:
	var h: CHealth = patient.c(&"health")
	if h == null or not h.lying() or not user.adjacent(patient):
		Game.tell(user, "They need to be lying down next to you.", "warn")
		return
	var zone: String = user.c(&"mob").zone
	if not zone in PROCEDURES[proc_id]["zones"]:
		Game.tell(user, "Aim at the right body part for that.", "warn")
		return
	patient.set_meta("surgery", {"proc": proc_id, "zone": zone, "step": 0})
	var where: Array = surface(patient)
	Game.visible_message(patient.root_cell(), "%s drapes %s on %s for %s." % [user.display_name, patient.display_name, where[1], PROCEDURES[proc_id]["name"].to_lower()])
	if where[0] < 1.0:
		Game.tell(user, "This would go better on an operating table.", "warn")

static func _finish_step(user: Entity, patient: Entity, s: Dictionary, closing: bool, ok: bool, tool_item: Entity = null) -> void:
	if not ok or not is_instance_valid(patient) or patient.removed:
		return
	var st := state(patient)
	if st.is_empty():
		return
	var h: CHealth = patient.c(&"health")
	var zone: String = st["zone"]
	var chance: float = surface(patient)[0]
	var awake := h.stat() == CHealth.CONSCIOUS
	CMood.surgery(patient, "started")
	if awake:
		chance *= 0.8 # tg: no anaesthetic, the patient squirms
		patient.c(&"mob").emote("writhes in pain!")
		h.pain = minf(100.0, h.pain + 10.0)
	if Game.rng.randf() > chance:
		h.hurt_zone(zone, 6.0, "brute", user)
		h.bleeding += 0.2
		Game.visible_message(patient.root_cell(), "%s's hand slips, cutting into %s's %s!" % [user.display_name, patient.display_name, Combat.ZONE_NAMES.get(zone, zone)], "bad")
		_organ_failure(s.get("fx", ""), h, st, user)
		return
	_apply(s.get("fx", ""), h, zone, user, tool_item)
	Skills.add_xp(user, "medical", 4.0)
	var steps: Array = PROCEDURES[st["proc"]]["steps"]
	if closing or s.get("fx", "") == "close":
		patient.remove_meta("surgery")
		Game.visible_message(patient.root_cell(), "%s finishes the operation on %s." % [user.display_name, patient.display_name], "good")
		return
	if s.get("repeat", false):
		if not _needs_more(s.get("fx", ""), h, zone):
			Game.tell(user, "That's all that can be done. Close up with the cautery.", "good")
			st["step"] = steps.size() - 1
		return
	st["step"] += 1
	var nxt: Dictionary = steps[st["step"]]
	Game.tell(user, "Next: %s (%s)." % [nxt["text"], TOOL_NAMES.get(nxt["tool"], nxt["tool"])], "info")

static func _apply(fx: String, h: CHealth, zone: String, user: Entity, tool_item: Entity = null) -> void:
	var part := Body.part_of(zone)
	match fx:
		"fix_bone":
			# tg bone repair / cranial reconstruction surgery
			var w := Body.wound_on(h, part, "blunt")
			if w.is_empty():
				w = Body.wound_on(h, part, "fissure")
			if not w.is_empty():
				Body.remove_wound(h, w)
				Game.visible_message(h.e.root_cell(), "%s repairs %s's %s." % [user.display_name, h.e.display_name, Body.PARTS[part]["name"]], "good")
		"reattach":
			var lp: String = tool_item.tags.get("limb_part", "") if tool_item else ""
			if lp != "" and lp.substr(2) != part.substr(2) and lp != part:
				Game.tell(user, "That limb won't fit there.", "warn")
			elif h.missing.has(part) and tool_item and not tool_item.removed:
				h.missing.erase(part)
				h.body_materials[part] = tool_item.tags.get("limb_material", "flesh")
				h.dismembered_by.erase(part)
				Interact.detach(tool_item)
				tool_item.destroy()
				Game.visible_message(h.e.root_cell(), "%s attaches a %s to %s!" % [user.display_name, Body.PARTS[part]["name"], h.e.display_name], "good")
				var m: CMob = h.e.c(&"mob")
				if m:
					m._update_pose()
		"amputate":
			Body.dismember(h, part, "slash")
		"close_stump":
			h.bleeding = maxf(0.0, h.bleeding - 0.4)
		"incise":
			h.bleeding += 0.4
		"clamp":
			h.bleeding = maxf(0.0, h.bleeding - 0.6)
		"heal_brute":
			var amt := minf(h.brute, 12.0)
			h.adjust("brute", -amt)
			h.limb[zone] = maxf(0.0, h.limb.get(zone, 0.0) - amt)
		"heal_burn":
			h.adjust("burn", -minf(h.burn, 12.0))
		"heal_tox":
			h.adjust("tox", -minf(h.tox, 15.0))
		"fix_eyes":
			h.eye_damage = 0.0
		"repair_organ":
			var slot: String = PROCEDURES[state(h.e)["proc"]]["organ"]
			if Organs.has(h, slot):
				Organs.set_damage(h, slot, Organs.DEFS[slot]["max"] * ORGAN_REPAIR[slot][0])
				Organs.get_organ(h, slot)["operated"] = true
				Game.visible_message(h.e.root_cell(), "%s successfully repairs %s's %s." % [user.display_name, h.e.display_name, Organs.DEFS[slot]["name"]], "good")
		"fix_brain":
			if Organs.has(h, "brain"):
				Organs.apply_damage(h, "brain", -Organs.BRAIN_DAMAGE_DEATH * 0.25)
				Traumas.cure_all(h, Traumas.RES_SURGERY)
				Game.visible_message(h.e.root_cell(), "%s successfully fixes %s's brain!" % [user.display_name, h.e.display_name], "good")
				Game.tell(h.e, "The pain in your head receeds, thinking becomes a bit easier!", "good")
				if Organs.damage(h, "brain") > Organs.BRAIN_DAMAGE_DEATH * 0.1:
					Game.tell(user, "%s's brain looks like it could be fixed further." % h.e.display_name, "info")
		"manip":
			_manip(h, zone, user, tool_item)
		"close":
			h.bleeding = maxf(0.0, h.bleeding - 0.4)

## tg organ manipulation: an organ item goes in; a hemostat takes the worst organ out
## (an inflamed appendix first: the appendectomy).
static func _manip(h: CHealth, zone: String, user: Entity, tool_item: Entity) -> void:
	var zn := "head" if zone == "head" else "chest"
	if tool_item and tool_item.has_c(&"surgerytool") and tool_item.c(&"surgerytool").kind == "organ":
		var slot := Organs.slot_of(tool_item.proto)
		if slot == "" or Organs.DEFS[slot]["zone"] != zn:
			Game.tell(user, "%s doesn't go there." % tool_item.the().capitalize(), "warn")
			return
		if Organs.has(h, slot):
			Game.tell(user, "%s already has a %s." % [h.e.display_name, Organs.DEFS[slot]["name"]], "warn")
			return
		Interact.detach(tool_item)
		Organs.insert(h, slot, tool_item)
		if slot in ["heart", "lungs", "liver", "stomach", "appendix"]:
			h.eviscerated = not (Organs.has(h, "heart") and Organs.has(h, "lungs") and Organs.has(h, "liver"))
		Game.visible_message(h.e.root_cell(), "%s inserts %s into %s's %s." % [user.display_name, Organs.DEFS[slot]["name"], h.e.display_name, Combat.ZONE_NAMES.get(zone, zone)], "good")
		return
	var pick := ""
	var app := Organs.get_organ(h, "appendix")
	if zn == "chest" and not app.is_empty() and (app.get("inflamation", 0) > 0 or app["failing"]):
		pick = "appendix"
	if pick == "":
		var worst := -1.0
		for slot in Organs.ORDER:
			if Organs.has(h, slot) and Organs.DEFS[slot]["zone"] == zn and slot != "brain":
				var d: float = Organs.damage(h, slot) / Organs.DEFS[slot]["max"]
				if d > worst:
					worst = d
					pick = slot
	if pick == "" and zn == "head" and Organs.has(h, "brain"):
		pick = "brain"
	if pick == "":
		Game.tell(user, "There's nothing there to take out.", "warn")
		return
	var it := Organs.remove(h, pick, user.cell)
	if pick in ["heart", "lungs", "liver"]:
		h.eviscerated = true
	Game.visible_message(h.e.root_cell(), "%s successfully extracts %s from %s's %s!" % [user.display_name, it.display_name if it else pick, h.e.display_name, Combat.ZONE_NAMES.get(zone, zone)], "warn")
	if it:
		user.c(&"inv").put_in_hands(it)

## tg organ repair on_failure: the slip hurts the organ being operated on.
static func _organ_failure(fx: String, h: CHealth, st: Dictionary, user: Entity) -> void:
	match fx:
		"repair_organ":
			var slot: String = PROCEDURES[st["proc"]]["organ"]
			Organs.apply_damage(h, slot, Organs.DEFS[slot]["max"] * ORGAN_REPAIR[slot][1])
			match slot:
				"lungs":
					h.losebreath += 4.0
					Game.tell(h.e, "You feel a sharp stab in your chest; the wind is knocked out of you and it hurts to catch your breath!", "bad")
				"heart":
					h.bleeding += 30.0 * 0.05
					Game.visible_message(h.e.root_cell(), "%s screws up, causing blood to spurt out of %s's chest profusely!" % [user.display_name, h.e.display_name], "bad")
				"liver":
					Game.tell(h.e, "The pain in your abdomen intensifies!", "bad")
				"stomach":
					Game.tell(h.e, "The pain in your gut intensifies!", "bad")
		"fix_brain":
			Organs.apply_damage(h, "brain", Organs.BRAIN_DAMAGE_DEATH * 0.3)
			Game.visible_message(h.e.root_cell(), "%s screws up, causing brain damage!" % user.display_name, "bad")
			Game.tell(h.e, "Your head throbs with horrible pain; thinking hurts!", "bad")
			Traumas.gain_type(h, "severe", Traumas.RES_LOBOTOMY)

static func _needs_more(fx: String, h: CHealth, _zone: String) -> bool:
	match fx:
		"fix_brain": return Organs.damage(h, "brain") > 0.5 or h.traumas.any(func(t): return t["res"] <= Traumas.RES_SURGERY)
		"manip": return true
		"heal_brute": return h.brute > 0.5
		"heal_burn": return h.burn > 0.5
		"heal_tox": return h.tox > 0.5
	return false

static func describe(patient: Entity) -> String:
	var st := state(patient)
	if st.is_empty():
		return ""
	var proc: Dictionary = PROCEDURES[st["proc"]]
	var step: Dictionary = proc["steps"][st["step"]]
	return "[color=#ff9a8a]%s is under surgery: %s on the %s. Next: %s (%s).[/color]" % [patient.display_name, proc["name"].to_lower(), Combat.ZONE_NAMES.get(st["zone"], st["zone"]), step["text"], TOOL_NAMES.get(step["tool"], step["tool"])]
