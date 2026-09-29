class_name Voice extends RefCounted
## How an NPC *types*. Real SS13 players each have a recognisable chat style: the one who
## writes in full sentences, the one who never capitalises anything, the one who calls
## everyone "mate", the one who spams "!!", the one who typos every other word and never
## fixes it. Each NPC rolls a style from their personality and keeps it all shift, so you
## learn to recognise people by how they talk. Stress bends it on the fly: panic brings
## out caps and stammers, calm heads stay tidy.
##
## Style dictionary (Persona.voice):
##   caps      "proper" | "lower" | "loud"   (loud: CAPS when excited)
##   punct     "full" | "light" | "none" | "extra"
##   abbrev    0..1   how much they shorten (u, ur, rn, tbh, idk, pls, thx, engi, med)
##   typo      0..1   chance of a typo per message
##   filler    Array  words they lead with ("honestly", "uh", "look,")
##   addr      String what they call people ("mate", "pal", "boss", "friend"), or ""
##   emote     String a signature (":)", ":P", "lol", "xD", "..."), or ""
##   formal    0..1   full titles, no slang
##   swears    bool   mild cursing when upset
##   ramble    0..1   tacks on an afterthought

const ABBREV := [
	[" you ", " u "], [" your ", " ur "], [" you're ", " ur "], ["right now", "rn"], ["i don't know", "idk"], ["I don't know", "idk"],
	["to be honest", "tbh"], ["please", "pls"], ["thanks", "thx"], ["okay", "ok"], ["Okay", "ok"], ["because", "cuz"],
	["going to", "gonna"], ["want to", "wanna"], ["got to", "gotta"], ["kind of", "kinda"], ["probably", "prob"],
	["Engineering", "engi"], ["Medbay", "med"], ["Security", "sec"], ["Cafeteria", "caf"], ["Atmospherics", "atmos"],
	["Hydroponics", "hydro"], ["maintenance", "maint"], ["Maintenance", "maint"], ["Research Lab", "sci"], ["Departure Lounge", "departures"],
	["Station Director", "captain"], ["with", "w/"], ["someone", "some1"], ["anyone", "any1"], ["be right back", "brb"], ["oh my god", "omg"],
]
const FILLERS_CASUAL := ["honestly", "uh", "look,", "ok so", "man,", "dude,", "like,", "yeah", "anyway", "welp"]
const FILLERS_FORMAL := ["Frankly,", "Well,", "Listen,", "Right.", "Indeed,", "Now,"]
const ADDR_WARM := ["mate", "pal", "buddy", "friend", "love", "dear", "hon"]
const ADDR_ROUGH := ["chief", "boss", "man", "dude", "bud"]
const EMOTES := [":)", ":P", "lol", "xD", "...", ":D", "haha", ";)", "heh", "o7"]
const RAMBLES := ["anyway", "but whatever", "just saying", "if that makes sense", "you know how it is", "or something", "long story",
	"don't ask", "it's fine", "not that anyone asked", "I think", "probably"]
const KEYS := "qwertyuiop|asdfghjkl|zxcvbnm"

static func generate(rng: RandomNumberGenerator, job: String, t: Dictionary, _p) -> Dictionary:
	var v := {}
	var soc: float = t.get("sociability", 0.5)
	var dil: float = t.get("diligence", 0.5)
	var neu: float = t.get("neuroticism", 0.5)
	var agg: float = t.get("aggression", 0.5)
	var hum: float = t.get("humor", 0.5)
	var law: float = t.get("lawfulness", 0.5)
	var formal := clampf(dil * 0.5 + law * 0.4 - hum * 0.3 + rng.randf_range(-0.25, 0.25) + (0.25 if Jobs.is_head(job) else 0.0), 0.0, 1.0)
	if job in ["assistant", "clown"]:
		formal *= 0.5
	v["formal"] = formal
	# capitalisation
	var r := rng.randf()
	if formal > 0.6:
		v["caps"] = "proper"
	elif r < 0.35 + (1.0 - formal) * 0.25:
		v["caps"] = "lower"
	elif agg > 0.65 and r < 0.8:
		v["caps"] = "loud"
	else:
		v["caps"] = "proper"
	# punctuation
	r = rng.randf()
	if formal > 0.65:
		v["punct"] = "full"
	elif v["caps"] == "lower":
		v["punct"] = "none" if r < 0.55 else "light"
	elif soc > 0.65 and hum > 0.5 and r < 0.4:
		v["punct"] = "extra"
	else:
		v["punct"] = "full" if r < 0.5 else "light"
	v["abbrev"] = clampf((1.0 - formal) * rng.randf_range(0.2, 1.0) - 0.15, 0.0, 1.0)
	v["typo"] = clampf(rng.randf_range(0.0, 0.35) * (1.0 - formal) + (0.1 if v["caps"] == "lower" else 0.0), 0.0, 0.45)
	# filler words
	var fillers := []
	var pool: Array = FILLERS_FORMAL if formal > 0.55 else FILLERS_CASUAL
	if rng.randf() < 0.55:
		fillers.append(pool[rng.randi() % pool.size()])
		if rng.randf() < 0.3:
			fillers.append(pool[rng.randi() % pool.size()])
	v["filler"] = fillers
	# how they address people
	v["addr"] = ""
	if formal < 0.55 and rng.randf() < 0.55:
		v["addr"] = (ADDR_WARM if t.get("empathy", 0.5) > 0.5 else ADDR_ROUGH)[rng.randi() % 5]
	# signature emoticon
	v["emote"] = ""
	if formal < 0.5 and rng.randf() < 0.5 + hum * 0.3:
		v["emote"] = EMOTES[rng.randi() % EMOTES.size()]
		if Jobs.dept(job) == "security" and rng.randf() < 0.4:
			v["emote"] = "o7"
	v["swears"] = agg > 0.55 and law < 0.6 and rng.randf() < 0.7
	v["ramble"] = clampf(soc * 0.35 + (1.0 - dil) * 0.15 + rng.randf_range(-0.1, 0.1), 0.0, 0.5)
	if neu > 0.7:
		v["filler"].append("uh")
	return v

## Rewrite `text` the way this NPC would type it. ctx: {radio, excited, to}
static func apply(text: String, b, ctx := {}) -> String:
	if text == "" or b == null or b.persona == null:
		return text
	var v: Dictionary = b.persona.voice
	if v.is_empty():
		return text
	var s := text
	# emotes (*yawns*) are actions, not typing
	if s.begins_with("*"):
		return s
	var nwords := s.split(" ").size()
	var panic: float = b.panic
	var excited: bool = ctx.get("excited", false) or s.ends_with("!")
	var radio: bool = ctx.get("radio", false)
	var formal: float = v.get("formal", 0.5)
	# lead-in filler (not on urgent radio calls)
	var fillers: Array = v.get("filler", [])
	if not fillers.is_empty() and not (radio and excited) and nwords >= 4 and randf() < 0.18:
		var f: String = fillers[randi() % fillers.size()]
		s = "%s %s" % [f, _lower_first(s) if not f.ends_with(".") else s]
	# afterthought
	if randf() < v.get("ramble", 0.0) * 0.35 and not excited and not radio and nwords >= 6 and not s.ends_with("?") and s.length() < 90:
		s = _strip_end(s) + ", " + RAMBLES[randi() % RAMBLES.size()] + "."
	# addressing
	var addr: String = v.get("addr", "")
	if addr != "" and ctx.get("to") != null and nwords >= 3 and randf() < 0.22 and not s.ends_with("?"):
		s = _strip_end(s) + ", " + addr + _end_mark(s)
	# abbreviations
	var ab: float = v.get("abbrev", 0.0)
	if ab > 0.05:
		var padded := " " + s + " "
		var lower_typist: bool = v.get("caps", "") == "lower"
		for pair in ABBREV:
			# place names only get shortened by people who type in lowercase anyway
			if pair[0][0] == pair[0][0].to_upper() and pair[0][0] != " " and not lower_typist:
				continue
			if padded.contains(pair[0]) and randf() < ab:
				padded = padded.replace(pair[0], pair[1])
		s = padded.strip_edges()
	# swearing when stressed
	if v.get("swears", false) and (panic > 0.4 or b.anger > 0.5 or b.needs.stress > 65) and randf() < 0.3:
		s = ["damn it, ", "hell, ", "frick, ", "ugh, ", "for crying out loud, "][randi() % 5] + _lower_first(s)
	# capitalisation
	match v.get("caps", "proper"):
		"lower":
			s = s.to_lower()
		"loud":
			if excited and randf() < 0.55:
				s = s.to_upper()
		_:
			s = _upper_first(s)
	# punctuation
	match v.get("punct", "full"):
		"none":
			if not s.ends_with("?") or randf() < 0.5:
				s = _strip_end(s)
		"light":
			if s.ends_with(".") and randf() < 0.7:
				s = s.substr(0, s.length() - 1)
		"extra":
			if s.ends_with("!"):
				s += "!" if randf() < 0.6 else "!!"
			elif s.ends_with("?") and randf() < 0.4:
				s += "?"
	# panic: stammer and caps, whatever the usual style
	if panic > 0.55 and randf() < panic:
		s = _stammer(s)
		if randf() < panic * 0.6:
			s = s.to_upper()
	elif b.tv("neuroticism") > 0.78 and randf() < 0.18:
		s = _stammer(s)
	# typos, mostly from sloppy typists, more when panicking
	var typo_p: float = v.get("typo", 0.0) + panic * 0.25
	if randf() < typo_p:
		s = _typo(s)
	# signature
	var em: String = v.get("emote", "")
	if em != "" and not excited and panic < 0.3 and randf() < 0.14 and b.mood > -0.3:
		s = _strip_end(s) + " " + em if em != "..." else _strip_end(s) + "..."
	return s

static func _stammer(s: String) -> String:
	var words := s.split(" ")
	if words.is_empty() or words[0].length() < 2:
		return s
	var w: String = words[0]
	var first := w.substr(0, 1)
	if not first.to_lower() in "abcdefghijklmnopqrstuvwxyz":
		return s
	words[0] = "%s-%s" % [first, w]
	return " ".join(words)

static func _typo(s: String) -> String:
	var words := s.split(" ")
	var cands := []
	for i in words.size():
		var w: String = words[i]
		if w.length() >= 4 and w.to_lower() == w and w.is_valid_identifier():
			cands.append(i)
	if cands.is_empty():
		return s
	var i: int = cands[randi() % cands.size()]
	var w2: String = words[i]
	var k := randi_range(1, w2.length() - 2)
	match randi() % 4:
		0: # swap two letters
			w2 = w2.substr(0, k) + w2[k + 1] + w2[k] + w2.substr(k + 2)
		1: # drop one
			w2 = w2.substr(0, k) + w2.substr(k + 1)
		2: # double one
			w2 = w2.substr(0, k) + w2[k] + w2.substr(k)
		3: # fat finger: a neighbouring key
			var c := w2[k]
			var row_i := KEYS.find(c)
			if row_i >= 0:
				var nb := row_i + (1 if randf() < 0.5 else -1)
				if nb >= 0 and nb < KEYS.length() and KEYS[nb] != "|":
					w2 = w2.substr(0, k) + KEYS[nb] + w2.substr(k + 1)
	words[i] = w2
	return " ".join(words)

static func _strip_end(s: String) -> String:
	while s.length() > 0 and s[s.length() - 1] in ".!":
		s = s.substr(0, s.length() - 1)
	return s

static func _end_mark(s: String) -> String:
	if s.ends_with("!"):
		return "!"
	if s.ends_with("?"):
		return "?"
	return "."

static func _lower_first(s: String) -> String:
	if s.length() < 2:
		return s.to_lower()
	# keep "I" and names (a capital followed by lowercase in a second word is a name)
	if s.begins_with("I ") or s.begins_with("I'"):
		return s
	var first_word := s.split(" ")[0]
	if first_word.length() > 1 and first_word == first_word.to_upper():
		return s # an acronym or shouting
	return s.substr(0, 1).to_lower() + s.substr(1)

static func _upper_first(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)

## One-line description of the style, for the mind inspector.
static func describe(v: Dictionary) -> String:
	var bits := []
	bits.append({"proper": "proper caps", "lower": "all lowercase", "loud": "CAPS when excited"}.get(v.get("caps", ""), ""))
	bits.append({"full": "full stops", "light": "light punctuation", "none": "no punctuation", "extra": "!!!"}.get(v.get("punct", ""), ""))
	if v.get("abbrev", 0.0) > 0.4:
		bits.append("lots of abbreviations")
	if v.get("typo", 0.0) > 0.2:
		bits.append("typos")
	if v.get("addr", "") != "":
		bits.append("calls people '%s'" % v["addr"])
	if v.get("emote", "") != "":
		bits.append("signs off with %s" % v["emote"])
	if v.get("swears", false):
		bits.append("swears when upset")
	if v.get("formal", 0.0) > 0.65:
		bits.append("formal")
	return ", ".join(bits.filter(func(x): return x != ""))
