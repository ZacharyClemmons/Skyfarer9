class_name CMedItem extends Component
## tg /obj/item/stack/medical (code/game/objects/items/stacks/medical.dm, tape.dm), used on
## the bodypart you're aiming at:
##   gauze          wrap: clots the wounds under it (absorption 5, rate 0.125/s), splints
##                  0.7, sanitises burns; works on the dead; x6 (5 s self, 2 s others)
##   suture         heals 10 brute, 0.5 blood flow off one wound (x0.7 on yourself); repeats
##   mesh           heals 10 burn, burn wound sanitization 0.75 / flesh 3; repeats
##   ointment       heals 5 burn, sanitization 0.25 / flesh 2.5
##   bruise_pack    heals 40 brute
##   bone_gel       on a fracture: 25 brute, 100 stamina, and it's gelled (tg bone/gel)
##   surgical_tape  on a gelled fracture it starts the bones knitting; otherwise a wrap
##                  (splint 0.5)
##   splint         a wrap that splints (0.5) and doesn't soak anything up
##   bonesetter     resets a dislocation (tg TOOL_BONESET)
## Repeating stacks carry on to the next thing that needs treating, like tg's heal loop.
## The older kit items (with `heals`) still work as before.

var kind := ""
var heals := {} # damage type -> amount per use
var uses := 5
var delay := 3.0
var other_delay := -1.0
var analyzer := false
var cures := false
var stop_bleeding := 0.0
var sanitization := 0.0
var flesh_regeneration := 0.0
var repeating := false

## tg values
const KINDS := {
	"gauze": {"uses": 6, "delay": 5.0, "other": 2.0, "wrap": "gauze"},
	"improvised_gauze": {"uses": 6, "delay": 6.0, "other": 3.0, "wrap": "improvised_gauze"},
	"suture": {"uses": 10, "delay": 3.0, "other": 1.0, "heals": {"brute": 10.0}, "stop": 0.5, "repeat": true},
	"mesh": {"uses": 15, "delay": 3.0, "other": 1.0, "heals": {"burn": 10.0}, "san": 0.75, "regen": 3.0, "repeat": true},
	"ointment": {"uses": 8, "delay": 4.0, "other": 2.0, "heals": {"burn": 5.0}, "san": 0.25, "regen": 2.5},
	"bruise_pack": {"uses": 6, "delay": 4.0, "other": 2.0, "heals": {"brute": 40.0}},
	"bone_gel": {"uses": 5, "delay": 2.0, "other": 0.0},
	"surgical_tape": {"uses": 5, "delay": 8.0, "other": 5.0, "wrap": "surgical_tape"},
	"splint": {"uses": 2, "delay": 5.0, "other": 2.0, "wrap": "splint"},
	"bonesetter": {"uses": 9999, "delay": 5.0, "other": 5.0},
}
const BASE_TREAT_TIME := 5.0 # tg /datum/wound base_treat_time

func key() -> StringName:
	return &"meditem"

func setup(p: Dictionary) -> CMedItem:
	kind = p.get("kind", "")
	var d: Dictionary = KINDS.get(kind, {})
	heals = p.get("heals", d.get("heals", {})).duplicate()
	uses = p.get("uses", d.get("uses", uses))
	delay = p.get("delay", d.get("delay", delay))
	other_delay = p.get("other", d.get("other", -1.0))
	stop_bleeding = d.get("stop", 0.0)
	sanitization = d.get("san", 0.0)
	flesh_regeneration = d.get("regen", 0.0)
	repeating = d.get("repeat", false)
	analyzer = p.get("analyzer", false)
	cures = p.get("cures", false)
	return self

func _wrap() -> String:
	return KINDS.get(kind, {}).get("wrap", "")

func apply(user: Entity, target: Entity) -> bool:
	var h: CHealth = target.c(&"health")
	if h == null:
		return false
	if analyzer:
		Game.tell(user, analyze(target), "examine")
		if user.has_c(&"brain"):
			user.c(&"brain").learn_health(target)
		return true
	if uses <= 0:
		Game.tell(user, "%s is used up." % e.the().capitalize(), "warn")
		return true
	var zone: String = user.c(&"mob").zone if user.has_c(&"mob") else "chest"
	var part := Body.part_of(zone)
	# NPCs aim where it's needed (a player picks the part with the body doll)
	if user != Game.player and _check(h, part) != "":
		for p in Body.PARTS:
			if _check(h, p) == "":
				part = p
				break
	var why := _check(h, part)
	if why != "":
		Game.tell(user, why, "warn")
		return true
	_begin(user, target, h, part, false)
	return true

## tg try_heal_checks / can_gauze_limb / wound item_can_treat: why it can't be used here.
func _check(h: CHealth, part: String) -> String:
	var pn := Body.pname(part)
	if h.missing.has(part):
		return "no %s!" % pn
	match kind:
		"bone_gel":
			var w := Body.wound_on(h, part, "bone")
			return "" if not w.is_empty() and w["sev"] >= 2 and not w.get("gel", false) else "no fractures!"
		"surgical_tape":
			var w2 := Body.wound_on(h, part, "bone")
			if not w2.is_empty() and w2["sev"] >= 2 and w2.get("gel", false) and not w2.get("taped", false):
				return ""
			return Body.can_gauze(h, part, "surgical_tape")
		"bonesetter":
			var w3 := Body.wound_on(h, part, "bone")
			return "" if not w3.is_empty() and w3["sev"] == 1 else "nothing to set!"
	if _wrap() != "":
		return Body.can_gauze(h, part, _wrap())
	if kind == "" :
		return "" if h.dead == false else "%s is dead!" % h.e.display_name
	if h.dead:
		return "they're dead!"
	var bw := Body.wound_on(h, part, "burn")
	var can_burn: bool = (flesh_regeneration > 0.0 or sanitization > 0.0) and not bw.is_empty() and Body.burn_treatable(bw)
	var can_suture: bool = stop_bleeding > 0.0 and Body.part_bleed_rate(h, part) > 0.0
	var pd := Body.part_damage(h, part)
	var pb := Body.part_burn(h, part)
	var brute_to_heal: bool = heals.get("brute", 0.0) > 0.0 and pd - pb > 0.0
	var burn_to_heal: bool = heals.get("burn", 0.0) > 0.0 and pb > 0.0
	if not brute_to_heal and not burn_to_heal and not can_burn and not can_suture:
		if not brute_to_heal and stop_bleeding > 0.0:
			return "%s is not bleeding or bruised!" % pn
		if not burn_to_heal and (flesh_regeneration > 0.0 or sanitization > 0.0) and not bw.is_empty():
			return "%s is fully treated, give it time!" % pn
		if pd <= 0.0:
			return "%s is not hurt!" % pn
		return "can't heal %s with %s!" % [pn, e.display_name]
	return ""

func _delay(user: Entity, target: Entity, h: CHealth, part: String) -> float:
	var self_use := user == target
	match kind:
		"bone_gel":
			return BASE_TREAT_TIME * 1.5 * (1.5 if self_use else 1.0)
		"bonesetter":
			return BASE_TREAT_TIME * (1.5 if self_use else 1.0)
		"surgical_tape":
			var w := Body.wound_on(h, part, "bone")
			if not w.is_empty() and w.get("gel", false):
				return BASE_TREAT_TIME * (1.5 if self_use else 1.0)
	return delay if self_use else maxf(other_delay, 0.0)

func _begin(user: Entity, target: Entity, h: CHealth, part: String, silent: bool) -> void:
	var t := _delay(user, target, h, part)
	var who := "their" if user == target else "%s's" % target.display_name
	if not silent:
		Game.visible_message(target.cell, "%s starts to apply %s on %s %s." % [user.display_name, e.display_name, who, Body.pname(part)])
	if t <= 0.0:
		_done(user, target, h, part)
		return
	DoAfter.start(user, target, t, func(ok):
		if not ok or not is_instance_valid(e) or e.removed or _check(h, part) != "":
			return
		_done(user, target, h, part))

func _done(user: Entity, target: Entity, h: CHealth, part: String) -> void:
	if not _treat(user, h, part):
		return
	uses -= 1
	Skills.add_xp(user, "medical", 2.0)
	Bus.stimulus.emit({"type": "treated", "actor": user, "target": target, "cell": target.cell, "loud": 1.0})
	if uses <= 0:
		if not e.proto.begins_with("medkit"):
			e.destroy()
		return
	# tg heal loop: repeating stacks move on to the next thing that needs it
	if repeating:
		var next := part if _check(h, part) == "" else ""
		if next == "":
			for p in Body.PARTS:
				if _check(h, p) == "":
					next = p
					break
		if next != "":
			_begin(user, target, h, next, true)
		else:
			Game.tell(user, "fully treated", "good")

func _treat(user: Entity, h: CHealth, part: String) -> bool:
	var pn := Body.pname(part)
	var t := h.e
	var self_use := user == t
	var who := "their" if self_use else "%s's" % t.display_name
	match kind:
		"bone_gel":
			var r := Body.bone_gel(h, part, self_use)
			if r == "passed out":
				Game.visible_message(t.cell, "%s fails to finish applying %s to their %s, passing out from the pain!" % [t.display_name, e.display_name, pn], "bad")
				return true
			if r != "":
				Game.tell(user, r, "warn")
				return false
			Game.visible_message(t.cell, "%s finishes applying %s to %s %s, emitting a fizzing noise!" % [user.display_name, e.display_name, who, pn], "warn")
			Game.tell(t, "[b]You can feel the bones exploding with pain as they begin melting and reforming![/b]", "bad")
			return true
		"bonesetter":
			if Body.set_bone(h, part, self_use):
				Game.visible_message(t.cell, "%s finishes resetting %s %s!" % [user.display_name, who, pn], "good")
				return true
			return false
		"surgical_tape":
			var w := Body.wound_on(h, part, "bone")
			if not w.is_empty() and w.get("gel", false) and not w.get("taped", false):
				Body.surgical_tape(h, part, self_use)
				Game.visible_message(t.cell, "%s finishes applying %s to %s %s, emitting a fizzing noise!" % [user.display_name, e.display_name, who, pn], "good")
				Game.tell(t, "You immediately begin to feel your bones start to reform!", "good")
				return true
	if _wrap() != "":
		Body.apply_gauze(h, part, _wrap())
		Game.visible_message(t.cell, "%s applies %s to %s %s." % [user.display_name, e.display_name, who, pn], "good")
		return true
	# tg heal_carbon
	Game.visible_message(t.cell, "%s applies %s on %s %s." % [user.display_name, e.display_name, who, pn], "good")
	if kind == "":
		for k in heals:
			h.adjust(k, -heals[k], user)
		if cures and h.disease != null:
			h.disease.cure_progress += 0.5
		return true
	Body.heal_part(h, part, heals.get("brute", 0.0), heals.get("burn", 0.0))
	if stop_bleeding > 0.0:
		Body.stop_bleeding(h, part, stop_bleeding * (0.7 if self_use else 1.0))
		h.bleeding = maxf(0.0, h.bleeding - stop_bleeding)
	if flesh_regeneration > 0.0 or sanitization > 0.0:
		Body.treat_burn(h, part, flesh_regeneration, sanitization)
	return true

## tg healthanalyzer: health, damage, blood, wounds, temperature, chemicals, disease.
static func analyze(target: Entity) -> String:
	var h: CHealth = target.c(&"health")
	var s := "[b]Analyzing results for %s:[/b]\n" % target.display_name
	s += "Overall status: %s\n" % ("[color=#ff5a4a]DEAD[/color]" if h.dead else "%d%% healthy" % int(h.health()))
	s += "[color=#ff8a8a]Brute %d[/color]  [color=#ffb84a]Burn %d[/color]  [color=#8aff8a]Toxin %d[/color]  [color=#8ab8ff]Suffocation %d[/color]\n" % [int(h.brute), int(h.burn), int(h.tox), int(h.oxy)]
	s += "Body temperature: %.1f C" % (h.body_temp - Defs.T0C)
	if h.body_temp < 285:
		s += " [color=#8ad8ff](hypothermic)[/color]"
	if h.dead:
		s += "\nTime of death: %s ago%s" % [_ago(Game.time - h.time_of_death), " [color=#6ae88a](can still be revived)[/color]" if Organs.defib_block(h) == "" and h.brute < 180.0 and h.burn < 180.0 else ""]
	for line in Body.analyzer_lines(h):
		s += "\n" + line
	# tg healthscan organ status (the organs with something wrong) and brain traumas
	var organ_lines := []
	for slot in Organs.ORDER:
		var st := Organs.status_text(h, slot)
		if st != "":
			organ_lines.append("%s: [color=#ff8a4a]%s[/color]" % [Organs.DEFS[slot]["name"].capitalize(), st])
	if h.eye_damage > StatusFx.EYES_LOW:
		organ_lines.append("Eyes: [color=#ff8a4a]%s[/color]" % ("Non-Functional" if h.eye_damage >= StatusFx.EYES_MAX else "Damaged"))
	if not organ_lines.is_empty():
		s += "\n[b]Organ status:[/b] " + ", ".join(organ_lines)
	if Organs.damage(h, "brain") >= Organs.BRAIN_DAMAGE_SEVERE:
		s += "\n[color=#ff5a4a]Severe brain damage detected. Subject likely to have mental traumas.[/color]"
	elif Organs.damage(h, "brain") >= 45.0:
		s += "\n[color=#ff8a4a]Brain damage detected.[/color]"
	var el := Embeds.analyzer_line(h)
	if el != "":
		s += "\n[color=#ff8a4a]%s[/color]" % el
	var tl := Traumas.analyzer_line(h)
	if tl != "":
		s += "\n[color=#d8a8ff]%s[/color]" % tl
	if not h.chems.is_empty():
		s += "\n[color=#b8d8ff]Reagents in blood: %s[/color]" % Chem.describe(h.chems)
	if h.disease != null:
		s += "\n[color=#b8ff5a]Pathogen detected: %s (stage %d). Suggested cure: aethermycin.[/color]" % [h.disease.name, h.disease.stage]
	return s

static func _ago(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]

func examine(_user: Entity, lines: Array) -> void:
	if not analyzer and kind != "bonesetter":
		lines.append("There %s %d %s left." % ["is" if uses == 1 else "are", uses, "use" if uses == 1 else "uses"])

func ai_tags(out: Dictionary) -> void:
	out["medical"] = true
	for k in heals:
		out["heals_" + k] = true
	if analyzer:
		out["analyzer"] = true
