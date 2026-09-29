class_name Forensics extends RefCounted
## tg /datum/forensics (code/modules/forensics/) and the detective's forensic scanner
## (code/modules/detectivework/scanner.dm). Everything people handle keeps what they left:
##  - fingerprints: md5 of their DNA identity, from bare hands; gloves take the prints
##    themselves instead (and the gloves carry the wearer's own);
##  - fibres: now and then a thread of their suit, uniform or gloves (tg odds);
##  - blood DNA: whose blood is on it, and its type.
## Washing (soap, showers, space cleaner) wipes all three (tg CLEAN_WASH). The scanner
## reads them, analyses for 3 s, logs each scan, and prints a Forensic Record. Crew records
## list everyone's fingerprint and DNA, so evidence can be matched the tg way: by hand.

const FIBER_ITEM_MULT := 1.2 # tg ITEM_FIBER_MULTIPLIER (items pick up more than structures)
const SCAN_RANGE := 8
const SCAN_TIME := 3.0

# ------------------------------------------------------------------ identity
## A person's DNA (tg dna.unique_enzymes, which blood carries) and fingerprint
## (tg md5(dna.unique_identity)).
static func dna(who: Entity) -> String:
	var dn: CDna = who.c(&"dna")
	if dn and dn.unique_enzymes != "":
		return dn.unique_enzymes # tg: blood carries dna.unique_enzymes
	if not who.has_meta("dna"):
		var r := RandomNumberGenerator.new()
		r.seed = hash(str(who.get_instance_id()) + who.display_name + str(Game.rng.randi()))
		var s := ""
		for i in 16:
			s += "%02x" % (r.randi() % 256)
		who.set_meta("dna", s)
	return who.get_meta("dna")

static func fingerprint(who: Entity) -> String:
	var dn: CDna = who.c(&"dna")
	if dn and dn.unique_identity != "":
		return dn.unique_identity.md5_text() # tg md5(dna.unique_identity)
	if not who.has_meta("fingerprint"):
		who.set_meta("fingerprint", ("identity:" + dna(who)).md5_text())
	return who.get_meta("fingerprint")

static func _data(atom: Entity) -> Dictionary:
	if not atom.has_meta("forensics"):
		atom.set_meta("forensics", {"prints": {}, "fibers": {}, "blood": {}})
	return atom.get_meta("forensics")

static func prints_on(atom: Entity) -> Array:
	return _data(atom)["prints"].keys() if atom.has_meta("forensics") else []

static func fibers_on(atom: Entity) -> Array:
	return _data(atom)["fibers"].keys() if atom.has_meta("forensics") else []

static func blood_on(atom: Entity) -> Dictionary:
	return _data(atom)["blood"] if atom.has_meta("forensics") else {}

# ------------------------------------------------------------------ leaving traces
## tg /datum/forensics/add_fingerprint
static func touch(atom: Entity, who: Entity, ignore_gloves := false) -> void:
	if atom == null or who == null or atom == who or not who.has_c(&"mob") or not is_instance_valid(atom):
		return
	if atom.has_c(&"decal"):
		return
	add_fibers(atom, who)
	var inv: CInventory = who.c(&"inv")
	var gloves: Entity = inv.worn("gloves") if inv else null
	if gloves and not ignore_gloves:
		# the gloves take the print (with the wearer's own on them)
		touch(gloves, who, true)
		return
	var fp := fingerprint(who)
	_data(atom)["prints"][fp] = true
	# tg blood_in_hands: bloody bare hands leave blood (and its DNA) on what they touch
	var hb: int = who.tags.get("bloody_hands", 0)
	if hb > 0:
		for k in who.get_meta("hand_blood", {}):
			_data(atom)["blood"][k] = who.get_meta("hand_blood")[k]
		if atom.has_c(&"item"):
			Blood.stain_item(atom)
		who.tags["bloody_hands"] = hb - 1
		if hb - 1 <= 0:
			who.tags.erase("bloody_hands")
			who.remove_meta("hand_blood")

## tg add_fibers: suit, uniform (if the suit leaves it showing) and gloves, by chance
static func add_fibers(atom: Entity, who: Entity) -> void:
	var inv: CInventory = who.c(&"inv")
	if inv == null:
		return
	var mult := FIBER_ITEM_MULT if atom.has_c(&"item") else 1.0
	var suit: Entity = inv.worn("suit")
	var uni: Entity = inv.worn("uniform")
	var gloves: Entity = inv.worn("gloves")
	var fib: Dictionary = _data(atom)["fibers"]
	if suit:
		_fiber(fib, "Material from %s." % _a(suit), 10.0 * mult)
		# our suits all cover the chest and leave the hands out
		if gloves:
			_fiber(fib, "Material from a pair of %s." % gloves.display_name, 20.0 * mult)
	elif uni:
		_fiber(fib, "Fibers from %s." % _a(uni), 15.0 * mult)
		if gloves:
			_fiber(fib, "Material from a pair of %s." % gloves.display_name, 20.0 * mult)
	elif gloves:
		_fiber(fib, "Material from a pair of %s." % gloves.display_name, 20.0 * mult)

static func _fiber(fib: Dictionary, text: String, chance: float) -> void:
	if not fib.has(text) and Body.prob(chance):
		fib[text] = true

static func _a(it: Entity) -> String:
	var n := it.display_name
	return ("an " if n.length() > 0 and n[0].to_lower() in "aeiou" else "a ") + n

## tg add_blood_DNA: whose blood, and its type
static func add_blood(atom: Entity, from: CHealth) -> void:
	if atom == null or from == null or not is_instance_valid(atom):
		return
	_data(atom)["blood"][dna(from.e)] = from.blood_type

## tg clean_act with CLEAN_WASH: blood, fingerprints and fibres all go
static func wash(atom: Entity) -> void:
	if atom and atom.has_meta("forensics"):
		atom.remove_meta("forensics")

# ------------------------------------------------------------------ the scanner
## tg detective_scanner/scan: a log entry of everything on it. People: their prints (if
## their hands are bare) and the blood on them; things: prints, fibres, blood, reagents;
## ID cards also list their access.
static func scan(scanner: Entity, user: Entity, target: Entity) -> Dictionary:
	var entry := {"target": target.display_name, "time": Game.clock_string(), "data": {}}
	var d: Dictionary = entry["data"]
	var fib := fibers_on(target)
	if not fib.is_empty():
		d["Fibers"] = fib
	var bl := blood_on(target)
	if not bl.is_empty():
		var b := []
		for k in bl:
			b.append("%s (%s)" % [k, bl[k]])
		d["Blood"] = b
	if target.has_c(&"mob"):
		var inv: CInventory = target.c(&"inv")
		if inv == null or inv.worn("gloves") == null:
			d["Fingerprints"] = [fingerprint(target)]
	else:
		var pr := prints_on(target)
		if not pr.is_empty():
			d["Fingerprints"] = pr
		var rg: CReagents = target.c(&"reagents")
		if rg and not rg.contents.is_empty():
			var r := []
			for k in rg.contents:
				r.append("%s: %.1fu" % [Chem.REAGENTS.get(k, {}).get("name", k), rg.contents[k]])
			d["Reagents"] = r
		var fd: CFood = target.c(&"food")
		if fd and not fd.chems.is_empty():
			var r2 := []
			for k in fd.chems:
				r2.append("%s: %.1fu" % [Chem.REAGENTS.get(k, {}).get("name", k), fd.chems[k]])
			d["Reagents"] = r2
		var idc: CIdCard = target.c(&"idcard")
		if idc:
			d["Access"] = [", ".join(idc.access)]
	return entry

static func report(logs: Array, n: int) -> String:
	var t := "[b]Forensic Record - (FR-%d)[/b]\n" % n
	for en in logs:
		t += "\n[b]%s[/b] (scanned %s)\n" % [en["target"], en["time"]]
		if en["data"].is_empty():
			t += "  No forensic traces found.\n"
		for cat in ["Fingerprints", "Blood", "Fibers", "Reagents", "Access"]:
			if en["data"].has(cat):
				t += "  %s:\n" % cat
				for line in en["data"][cat]:
					t += "    %s\n" % line
	t += "\nNotes:\n"
	return t
