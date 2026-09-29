class_name SpeechIntent extends RefCounted
## Understanding what a player typed. Not a language model, a forgiving pattern matcher:
## it strips the text down, looks for who and what is being talked about (people, rooms,
## items, skills), then picks the most likely intent. Handles typos in names by prefix,
## titles ("doc", "officer", "captain"), and follow-ups without a name.
##
## parse() returns {intent, text, person: Entity, area: Area, item: String, skill: String,
##                  addressed: bool, name_hit: bool, polite: bool, rude: bool}

const TITLES := {
	"doc": ["doctor", "cmo"], "doctor": ["doctor", "cmo"], "medic": ["doctor", "cmo"], "officer": ["security", "hos"], "sec": ["security", "hos"],
	"captain": ["captain"], "director": ["captain"], "cap": ["captain"], "chief": ["ce", "hos", "cmo"], "engineer": ["engineer", "ce", "atmos"],
	"chef": ["cook"], "cook": ["cook"], "bartender": ["bartender"], "barkeep": ["bartender"], "clown": ["clown"], "janitor": ["janitor"], "jani": ["janitor"],
	"botanist": ["botanist"], "miner": ["miner"], "scientist": ["scientist", "rd"], "chemist": ["chemist"], "geneticist": ["geneticist", "genetics"], "hop": ["hop"], "qm": ["qm"],
	"cargo": ["cargo", "qm"], "atmos": ["atmos"], "rd": ["rd"], "hos": ["hos"], "cmo": ["cmo"], "ce": ["ce"],
}

## Item words -> [ai tag or "", proto/name fragment]. The fragment matches display names too.
const ITEMS := {
	"welder": ["tool_welder", "welder"], "welding": ["tool_welder", "welder"], "wrench": ["tool_wrench", "wrench"], "crowbar": ["tool_crowbar", "crowbar"],
	"screwdriver": ["tool_screwdriver", "screwdriver"], "wirecutter": ["tool_wirecutters", "wirecutters"], "cutters": ["tool_wirecutters", "wirecutters"],
	"multitool": ["tool_multitool", "multitool"], "cable": ["mat_cable", "cable"], "wire": ["mat_cable", "cable"], "metal": ["mat_metal", "metal"],
	"glass": ["mat_glass", "glass"], "rods": ["mat_rods", "rods"], "tools": ["tool", ""], "toolbox": ["", "toolbox"], "tool": ["tool", ""],
	"gauze": ["", "gauze"], "bandage": ["", "gauze"], "suture": ["", "suture"], "medkit": ["", "medkit"], "first aid": ["", "medkit"], "kit": ["", "medkit"],
	"ointment": ["", "ointment"], "mesh": ["", "mesh"], "splint": ["", "splint"], "pill": ["", "pill"], "medicine": ["medical", ""], "meds": ["medical", ""],
	"analyzer": ["", "analyzer"], "scanner": ["", "health_analyzer"], "defib": ["", "defib"],
	"food": ["food", ""], "something to eat": ["food", ""], "eat": ["food", ""], "sandwich": ["", "sandwich"], "burger": ["", "burger"], "pizza": ["", "pizza"],
	"soup": ["", "soup"], "donut": ["", "donut"], "ration": ["", "ration"], "banana": ["", "banana"], "tomato": ["", "tomato"], "meat": ["", "meat"],
	"drink": ["drink", ""], "water": ["", "water"], "cocoa": ["", "cocoa"], "coffee": ["", "coffee"], "soda": ["", "soda"], "cola": ["", "soda"],
	"vodka": ["", "booze"], "booze": ["", "booze"], "beer": ["", "booze"], "alcohol": ["", "booze"],
	"coat": ["warm_clothing", ""], "jacket": ["warm_clothing", ""], "mask": ["breath_mask", ""], "tank": ["air_tank", ""], "oxygen": ["air_tank", ""],
	"gloves": ["", "gloves"], "insuls": ["insulated_gloves", ""], "flashlight": ["", "flashlight"], "light": ["", "flashlight"], "torch": ["", "flashlight"],
	"extinguisher": ["extinguisher", ""], "pickaxe": ["tool_dig", ""], "pick": ["tool_dig", ""], "mop": ["tool_mop", ""], "bucket": ["", "bucket"],
	"cuffs": ["restraint", ""], "handcuffs": ["restraint", ""], "baton": ["", "baton"], "disabler": ["", "disabler"], "flash": ["", "flash"],
	"weapon": ["weapon", ""], "gun": ["", "gun"], "knife": ["", "knife"], "id": ["", "id_card"], "headset": ["", "headset"], "radio": ["", "headset"],
	"cigarette": ["", "cig"], "smoke": ["", "cig"], "lighter": ["", "lighter"], "paper": ["", "paper"], "pen": ["", "pen"], "soap": ["", "soap"],
	"beaker": ["", "beaker"], "ore": ["ore", ""], "cash": ["", "cash"], "money": ["", "cash"],
}

const GREET := ["hello", "hi", "hey", "heya", "hiya", "yo", "sup", "morning", "good morning", "afternoon", "evening", "howdy", "greetings", "o/", "hallo", "helo", "hai"]
const BYE := ["bye", "goodbye", "see you", "see ya", "cya", "later", "gotta go", "take care", "farewell", "night", "good night"]
const YES := ["yes", "yeah", "yep", "yup", "sure", "ok", "okay", "alright", "fine", "will do", "on it", "of course", "absolutely", "deal", "why not", "k", "ye", "ya", "aye"]
const NO := ["no", "nope", "nah", "no way", "not now", "can't", "cant", "won't", "busy", "later maybe", "not really", "negative"]
const INSULTS := ["idiot", "stupid", "moron", "dumb", "shut up", "stfu", "loser", "useless", "ugly", "hate you", "you suck", "suck", "pathetic",
	"fuck you", "fuck off", "piss off", "screw you", "jerk", "asshole", "bitch", "bastard", "incompetent", "worthless", "freak", "weirdo", "noob"]
const COMPLIMENTS := ["great job", "good job", "nice job", "well done", "good work", "nice work", "you're great", "you are great", "you're awesome", "awesome",
	"amazing", "love you", "like you", "you're the best", "nice hat", "nice coat", "you're cool", "you rock", "legend", "you're funny", "hero", "brilliant",
	"good one", "thank god", "you're nice", "you're kind", "cute", "beautiful", "handsome", "smart"]
const THREATS := ["kill you", "i'll kill", "gonna kill", "you're dead", "youre dead", "murder you", "hurt you", "i'll hurt", "watch your back", "end you",
	"beat you", "gonna get you", "stab you", "break your"]
const QUESTION_WORDS := ["what", "where", "who", "why", "how", "when", "can", "could", "would", "will", "do", "does", "did", "is", "are", "have", "any"]

static func norm(text: String) -> String:
	var t := text.to_lower().strip_edges()
	for ch in [",", ".", "!", "?", ";", "\"", "(", ")", "*", "~"]:
		t = t.replace(ch, " ")
	t = t.replace("’", "'")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return " " + t.strip_edges() + " "

static func has_word(t: String, w: String) -> bool:
	return t.contains(" " + w + " ")

static func has_any(t: String, words: Array) -> bool:
	for w in words:
		if t.contains(" " + w + " ") or (w.contains(" ") and t.contains(w)):
			return true
	return false

static func has_frag(t: String, frags: Array) -> bool:
	for f in frags:
		if t.contains(f):
			return true
	return false

## Does the text call `me` by name, nickname or title?
static func names_me(t: String, me: Entity) -> bool:
	var parts: PackedStringArray = me.display_name.to_lower().split(" ")
	for p in parts:
		if p.length() >= 3 and (has_word(t, p) or has_word(t, p + "s") or (p.length() >= 5 and t.contains(" " + p.substr(0, 4)))):
			return true
	var m: CMob = me.c(&"mob")
	if m:
		for title in TITLES:
			if has_word(t, title) and m.job in TITLES[title]:
				return true
	return false

## The other person mentioned in the text (not `me`, not the speaker), by name or title.
static func person_in(t: String, me: Entity, speaker: Entity) -> Entity:
	var best: Entity = null
	for m in Game.all_with(&"mob"):
		if m == me or m == speaker:
			continue
		var parts: PackedStringArray = m.display_name.to_lower().split(" ")
		for p in parts:
			if p.length() >= 3 and (has_word(t, p) or has_word(t, p + "s") or has_word(t, p + "'s")):
				return m
	# titles ("where's the captain", "is the doc around")
	for title in TITLES:
		if has_word(t, title) or has_word(t, title + "s"):
			var jobs: Array = TITLES[title]
			for m in Game.all_with(&"mob"):
				if m == me or m == speaker:
					continue
				var mm: CMob = m.c(&"mob")
				if mm and mm.job in jobs and not m.c(&"health").dead:
					if best == null or jobs.find(mm.job) < jobs.find(best.c(&"mob").job):
						best = m
			if best:
				return best
	return null

static func area_in(t: String) -> Area:
	var best: Area = null
	var bl := 0
	for a in Game.map.areas:
		if a.id == 0 or a.cells.is_empty():
			continue
		var n: String = a.name.to_lower()
		if t.contains(n) and n.length() > bl:
			best = a
			bl = n.length()
	if best:
		return best
	var aliases := {"medbay": "Medbay Treatment", "med bay": "Medbay Treatment", "medical": "Medbay Treatment", "engi": "Engineering", "engine": "Engineering",
		"sec": "Security Office", "security": "Security Office", "brig": "Brig", "bridge": "Bridge", "caf": "Cafeteria", "cafeteria": "Cafeteria",
		"kitchen": "Kitchen", "bar": "Bar", "hydro": "Hydroponics", "botany": "Hydroponics", "sci": "Research Lab", "science": "Research Lab",
		"research": "Research Lab", "rnd": "Research Lab", "chem": "Chemistry", "atmos": "Atmospherics", "cargo": "Cargo Bay", "mining": "Mining Dock",
		"dorms": "Dormitories", "dorm": "Dormitories", "bed": "Dormitories", "lounge": "Crew Lounge", "morgue": "Morgue", "departures": "Departure Lounge",
		"escape": "Departure Lounge", "reactor": "Reactor Chamber", "toilet": "Restroom", "bathroom": "Restroom", "restroom": "Restroom",
		"janitor": "Custodial Closet", "custodial": "Custodial Closet", "tool storage": "Tool Storage", "tools": "Tool Storage", "eva": "EVA Storage",
		"vault": "Vault", "hop": "Personnel Office", "personnel": "Personnel Office", "xeno": "Xenochemistry", "chapel": "Chapel", "maint": "Maint"}
	var bk := ""
	for k in aliases:
		if has_word(t, k) and k.length() > bk.length():
			bk = k
	if bk != "":
		for a in Game.map.areas:
			if a.name.begins_with(aliases[bk]):
				return a
	# single distinctive words of area names
	for a in Game.map.areas:
		if a.id == 0:
			continue
		for w in a.name.to_lower().split(" "):
			if w.length() > 4 and has_word(t, w):
				return a
	return null

static func item_in(t: String) -> String:
	var best := ""
	for k in ITEMS:
		if (k.contains(" ") and t.contains(k)) or has_word(t, k) or has_word(t, k + "s") or has_word(t, k + "es"):
			if k.length() > best.length():
				best = k
	return best

## Main entry. `me` is the listening NPC, `speaker` who said it.
static func parse(text: String, me: Entity, speaker: Entity) -> Dictionary:
	var t := norm(text)
	var r := {"intent": "unknown", "text": text, "t": t, "person": null, "area": null, "item": "", "skill": "",
		"polite": has_any(t, ["please", "pls", "plz", "thanks", "thank you", "could you", "would you", "mind"]),
		"rude": has_any(t, INSULTS), "question": text.strip_edges().ends_with("?") or has_any(t.substr(0, 10), QUESTION_WORDS),
		"name_hit": names_me(t, me)}
	r["person"] = person_in(t, me, speaker)
	r["area"] = area_in(t)
	r["item"] = item_in(t)
	r["skill"] = Dialogue.skill_from_text(t)
	var i := _intent(t, r)
	r["intent"] = i
	return r

static func _intent(t: String, r: Dictionary) -> String:
	var words := t.strip_edges().split(" ")
	var n := words.size()
	# threats first: they trump everything
	if has_frag(t, THREATS):
		return "threat"
	# accusing someone / reporting a crime
	if r["person"] != null and has_frag(t, ["attacked me", "hit me", "punched me", "stabbed me", "hurt me", "stole", "robbed", "is a traitor",
			"traitor", "killed", "murdered", "is attacking", "attacking", "broke into", "shot me", "beat me", "assaulted", "is dangerous", "is armed"]):
		return "report_crime"
	if has_frag(t, ["you stole", "you took my", "you killed", "you're a traitor", "youre a traitor", "you attacked", "you hit me", "i saw you"]):
		return "accuse"
	if has_frag(t, ["sorry", "apologi", "my bad", "didn't mean", "didnt mean", "forgive"]):
		return "apology"
	if (has_frag(t, ["thank", "thx", "cheers", "appreciate"]) or has_word(t, "ty")) and n <= 6:
		return "thanks"
	# orders / movement
	if has_frag(t, ["follow me", "come with me", "follow", "with me", "come along", "tag along", "escort me"]):
		return "follow"
	if has_frag(t, ["come here", "over here", "come to me", "get over here"]):
		return "come_here"
	if has_frag(t, [" stop ", "stay here", " stay ", "wait here", " wait ", "hold on", "halt", "freeze", "stand still", "don't move", "dont move", "leave me alone", "go away"]):
		if has_frag(t, ["leave me alone", "go away"]):
			return "go_away"
		return "stop"
	if has_frag(t, ["go to ", "head to ", "get to ", "run to "]) and r["area"] != null and not has_frag(t, ["how do i", "how to", "where"]):
		return "go_to"
	# teaching
	if has_frag(t, ["teach me", "show me how", "how do i", "how do you", "how to ", "any tips", "tips", "advice", "explain", "help me learn", "what should i do"]):
		if r["area"] != null and has_frag(t, ["how do i get", "how to get", "how do i find", "way to"]):
			return "where_place"
		return "teach"
	# jobs for us / favors
	if has_frag(t, ["need anything", "need any help", "can i help", "anything i can do", "need help with", "any jobs", "any work", "got anything for me", "want me to", "anything you need", "can i do anything"]):
		return "offer_help"
	# healing
	if has_frag(t, ["heal me", "patch me", "fix me up", "i'm hurt", "im hurt", "i am hurt", "i'm bleeding", "im bleeding", "i'm injured", "need a doctor",
			"need medical", "i need help", "help me", "i'm dying", "im dying", "treat me", "my arm", "my leg", "broken bone", "i'm burned", "burns"]):
		return "request_heal"
	# food and drink orders
	if has_frag(t, ["i'm hungry", "im hungry", "cook me", "make me something", "make me food", "something to eat", "get me food", "feed me", "i'm starving", "im starving"]):
		return "request_food"
	if has_frag(t, ["a drink", "pour me", "get me a drink", "i'm thirsty", "im thirsty", "a beer", "a vodka", "a cocoa", "a coffee", "some water", "a soda"]) and not has_frag(t, ["where"]):
		return "request_drink"
	# access and doors
	if has_frag(t, ["access", "id change", "change my id", "new job", "job change", "transfer", "promote me", "promotion"]):
		return "request_access"
	if has_frag(t, ["open the door", "open this", "let me in", "open the", "open up", "unlock"]):
		return "request_open"
	# fixing things
	if has_frag(t, ["fix ", "repair", "broken", "leak", "leaking", "no power", "power's out", "power is out", "breach", "it's cold in", "its cold in", "freezing in"]):
		if not has_frag(t, ["fix me"]):
			return "request_fix"
	# asking for items
	if r["item"] != "" and has_frag(t, ["give me", "can i have", "could i have", "can i get", "could i get", "lend me", "borrow", "hand me", "pass me", "i need a", "i need some",
			"i need the", "i need your", "spare", "got a", "got any", "have a", "have any", "you have", "toss me", "bring me", "get me", "want a"]):
		if has_frag(t, ["bring me", "get me", "fetch"]) and not has_frag(t, ["give me"]):
			return "request_fetch"
		return "request_item"
	# questions
	if has_frag(t, ["where are you from", "where you from", "where r u from", "where're you from"]):
		return "about_you"
	if has_frag(t, ["where is", "where's", "wheres", "where are", "seen ", "know where", "where can i find", "where do i find", "where'd", "any idea where", "location of"]):
		if r["person"] != null:
			return "where_person"
		if r["item"] != "":
			return "where_item"
		if r["area"] != null:
			return "where_place"
		return "where_unknown"
	if has_frag(t, ["what do you think of", "what do you think about", "thoughts on", "opinion of", "opinion on", "do you like", "do you trust", "how's ", "hows ", "what's ", "whats ", "tell me about", "who is", "who's", "whos ", "is it true"]) and r["person"] != null:
		return "opinion"
	if has_frag(t, ["what do you think of me", "do you like me", "do you trust me", "what do you think about me", "am i", "are we friends", "we cool", "are we good"]):
		return "opinion_me"
	if has_frag(t, ["how are you", "how are u", "how r u", "how's it going", "hows it going", "how you doing", "how are you doing", "you ok", "you okay", "you alright", "how do you feel", "how you feeling", "how's your day", "hows your day", "wyd"]):
		return "how_are_you"
	if has_frag(t, ["what are you doing", "what're you doing", "whatcha doing", "what you doing", "what are you up to", "whatre you up to", "you busy", "are you busy", "what's your job", "whats your job", "what do you do"]):
		return "doing"
	if has_frag(t, ["what happened", "what's new", "whats new", "any news", "news", "gossip", "heard anything", "anything interesting", "what's going on", "whats going on", "what's up", "whats up", "wassup", "sup "]):
		return "news"
	if has_frag(t, ["where are you from", "where you from", "your story", "about yourself", "who are you", "why are you here", "why did you come", "how did you end up", "what brought you", "your name", "who r u", "tell me about you", "how long have you", "how old are you"]):
		return "about_you"
	if has_frag(t, ["hobbies", "hobby", "free time", "what do you like", "what are you into", "interests", "for fun", "like to do", "favourite", "favorite"]):
		return "interests"
	if has_frag(t, ["joke", "make me laugh", "something funny", "cheer me up"]):
		return "joke"
	if has_frag(t, ["what do you want", "what are your goals", "your goal", "your dream", "what do you want to do", "plans", "ambition"]):
		return "ambition"
	if has_frag(t, ["are you scared", "afraid of", "scared of", "what scares you", "fear"]):
		return "fear"
	if has_frag(t, ["lunch", "want to eat", "grab food", "grab a bite", "drink with me", "get a drink", "hang out", "wanna hang", "join me", "come eat"]):
		return "invite"
	# emotional
	if has_any(t, INSULTS) or r["rude"]:
		return "insult"
	if has_frag(t, COMPLIMENTS):
		return "compliment"
	if has_any(t, BYE):
		return "bye"
	if has_any(t, GREET) and n <= 5:
		return "greet"
	if n <= 3 and has_any(t, YES):
		return "yes"
	if n <= 4 and has_any(t, NO):
		return "no"
	if has_frag(t, ["help"]):
		return "help_general"
	# mentions of interests get people talking
	for k in Persona.INTERESTS:
		if has_word(t, k) or t.contains(Persona.INTERESTS[k][0]):
			r["topic"] = k
			return "topic"
	if r["person"] != null:
		return "opinion"
	return "unknown"

## Does an item fit an ITEMS word?
static func item_matches(it: Entity, word: String) -> bool:
	if word == "" or it == null:
		return false
	var spec: Array = ITEMS.get(word, ["", word])
	if spec[0] != "" and it.ai_tags().has(spec[0]):
		return true
	var frag: String = spec[1]
	if frag != "" and (it.proto.contains(frag) or it.display_name.to_lower().contains(frag)):
		return true
	return false
