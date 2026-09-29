class_name CSeqScanner extends Component
## tg /obj/item/sequence_scanner (code/game/objects/items/devices/scanners/sequence_scanner.dm):
## the geneticist's pocket scanner. Scan someone to read their gene sequences (the ones
## the station has discovered by name); scan their genetic makeup (3 s) to carry it to a
## console. Use it on a DNA console to link it to the discovered-mutation database.
## Z switches between scanning sequences and makeup (tg's left and right click).

var discovered := {}
var buffer := {} # mutation id -> sequence
var genetic_makeup_buffer := {}
var makeup_mode := false
var ready := true
var ready_at := 0.0
const ANALYSIS_COOLDOWN := 20.0

func key() -> StringName:
	return &"seqscanner"

func attack_self(user: Entity) -> bool:
	makeup_mode = not makeup_mode
	Game.tell(user, "You set %s to scan %s." % [e.the(), "genetic makeup" if makeup_mode else "gene sequences"])
	return true

## tg interact_with_atom on a DNA console
func link(user: Entity, console: CDnaConsole) -> void:
	if makeup_mode:
		# TG asks which of the three slots to replace. The port presents that choice
		# in the console, where the existing slot contents remain visible.
		if genetic_makeup_buffer.is_empty():
			return
		console.view["consoleMode"] = "enzymes"
		Game.tell(user, "Choose Import from handheld in the console's desired makeup slot.")
		if user == Game.player and Game.hud:
			Game.hud.open_window("dna_console", console.e)
		return
	Game.tell(user, "%s linked to central research database." % e.display_name.capitalize())
	discovered = Genetics.discovered

## Scan someone (use on a mob).
func use_on(user: Entity, target: Entity) -> void:
	Forensics.touch(e, user)
	if not target.has_c(&"health"):
		return
	if not target.has_c(&"dna") or Traits.has(target, "geneless") or Traits.has(target, "baddna"):
		Game.visible_message(user.cell, "%s fails to analyze %s's genetic sequence." % [user.display_name, target.display_name])
		Game.tell(user, "%s has no readable genetic sequence!" % target.display_name, "warn")
		return
	if makeup_mode:
		if Traits.has(target, "no_dna_copy"):
			Game.tell(user, "%s has no readable genetic makeup!" % target.display_name, "warn")
			return
		Game.visible_message(user.cell, "%s is scanning %s's genetic makeup." % [user.display_name, target.display_name], "warn")
		DoAfter.start(user, target, 3.0, func(ok):
			if not ok:
				Game.visible_message(user.cell, "%s fails to scan %s's genetic makeup." % [user.display_name, target.display_name], "warn")
				return
			makeup_scan(target, user)
			Game.tell(user, "Makeup scanned."))
		return
	Game.visible_message(user.cell, "%s analyzes %s's genetic sequence." % [user.display_name, target.display_name])
	Sfx.play("scanner", user.cell, 0.5)
	gene_scan(target, user)

## tg gene_scan
func gene_scan(target: Entity, user: Entity) -> void:
	var d: CDna = target.c(&"dna")
	buffer = d.mutation_index.duplicate()
	var active := []
	for m in d.mutations:
		buffer[m.id] = Genetics.sequence(m.id)
		active.append(m.id)
	var lines := ["Subject %s's DNA sequence has been saved to buffer." % target.display_name]
	for mid in buffer:
		lines.append(("[b]%s[/b]" if mid in active else "%s") % display_name(mid))
	Game.tell(user, "\n".join(lines))

## tg makeup_scan
func makeup_scan(target: Entity, _user: Entity) -> void:
	var d: CDna = target.c(&"dna")
	var h: CHealth = target.c(&"health")
	var m: CMob = target.c(&"mob")
	genetic_makeup_buffer = {"label": "Analyzer Slot:%s" % (m.real_name if m else target.display_name), "UI": d.unique_identity, "UE": d.unique_enzymes,
		"UF": d.unique_features, "name": m.real_name if m else target.display_name, "blood_type": h.blood_type if h else ""}

## tg get_display_name: the real name once discovered, else the alias
func display_name(mid: String) -> String:
	var nm := Genetics.alias(mid)
	if discovered.has(mid):
		nm += " (%s)" % Genetics.DEFS[mid]["name"]
	return nm

## tg display_sequence: read one buffered gene's sequence, a pair at a time
func verbs(user: Entity, out: Array) -> void:
	if user.c(&"inv") == null or not e in user.c(&"inv").hands:
		return
	for mid in buffer:
		var m: String = mid
		out.append({"name": "Analyze %s" % display_name(m), "cb": func(): display_sequence(user, m), "priority": 1})

func display_sequence(user: Entity, mid: String) -> void:
	var inv: CInventory = user.c(&"inv") if user else null
	if inv == null or not e in inv.hands:
		return
	if not buffer.has(mid):
		return
	if not ready:
		Game.tell(user, "The analyzer is recharging (%ds)." % maxi(0, int(ceil(ready_at - Game.time))), "warn")
		return
	if not Traits.has(user, "literate") or Traits.has(user, "illiterate"):
		Game.tell(user, "You cannot read the analyzer's display.", "warn")
		return
	var health: CHealth = user.c(&"health")
	if not health or not health.can_use_hands() or StatusFx.blind(health):
		Game.tell(user, "You cannot use the analyzer's display right now.", "warn")
		return
	if Game.lighting and Game.lighting.light_at(user.root_cell()) < 0.2:
		Game.tell(user, "It is too dark to read the analyzer's display.", "warn")
		return
	ready = false
	e.spr.modulate = Color(0.5, 0.65, 0.8)
	ready_at = Game.time + ANALYSIS_COOLDOWN
	Genetics.after(ANALYSIS_COOLDOWN, recharge)
	var seq: String = buffer[mid]
	var top := ""
	var bottom := ""
	for i in range(0, seq.length(), 2):
		if i > 0 and i % 8 == 0:
			top += "  "
			bottom += "  "
		top += seq[i] + " "
		bottom += seq[i + 1] + " "
	Game.tell(user, "[b]%s[/b]
[code]%s
%s[/code]" % [display_name(mid), top, bottom])

func recharge() -> void:
	if is_instance_valid(e) and not e.removed:
		ready = true
		e.spr.modulate = Color.WHITE

func examine(_user: Entity, lines: Array) -> void:
	if not ready:
		lines.append("The analyzer is recharging (%ds)." % maxi(0, int(ceil(ready_at - Game.time))))
	lines.append("Z switches it between scanning gene sequences and genetic makeup (now: %s)." % ("makeup" if makeup_mode else "sequences"))
	if not genetic_makeup_buffer.is_empty():
		lines.append("It has the genetic makeup of \"%s\" stored inside its buffer" % genetic_makeup_buffer.get("name", "?"))
	if not buffer.is_empty():
		var parts := []
		for mid in buffer:
			parts.append(display_name(mid))
		lines.append("Buffer: %s" % ", ".join(parts))
