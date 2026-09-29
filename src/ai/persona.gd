class_name Persona extends RefCounted
## Who an NPC *is*, beyond their stats: where they come from, why they signed on to a
## sky-going ship, what they love and can't stand, their habits, the way they
## type, and what they want out of this voyage. Rolled once per crewmember from the job
## and personality, so every voyage has a different cast. Personas feed the dialogue
## (topics, voice, opinions), leisure (what they do on a break), social chemistry
## (shared interests make friends), and ambitions (goals of their own).

# ------------------------------------------------------------------ tables
const HOMETOWNS := ["the Home Reach orchards", "a mining island in the Shelf", "Port Meridian's lower quay", "the Anvil forges", "a fishing hamlet on the Long Sky",
	"a drifting monastery in the Heights", "an orphanage on the Nearing", "the Rim shipyards", "a lift-cell farm above the Deep", "a salvage camp on the Rustfall",
	"a lighthouse island in the Outer Dark", "a sky-barge that never landed", "a cloud-market on the Long Sky", "a chalk-hill village in the Home Reach",
	"the Boneyard scrapper camps", "a monastery on a Heights spire", "Port Olympus", "an outport nobody remembers"]

## [id, why they came here (first person)]
const REASONS := [
	["money", "The hazard pay. Three voyages and I can buy my mother a proper house on solid ground."],
	["escape", "I needed to be very far away from someone. The Guild's furthest run was the furthest I could get."],
	["science", "The aether. There's nothing like the skyglass anywhere else in the known sky."],
	["debt", "The Guild bought out my debt. I work it off, one voyage at a time."],
	["adventure", "I wanted to see the edge of everything. Turns out the edge is cold and very windy."],
	["career", "A season on a good ship looks great in a Guild ledger. Everybody says so."],
	["quiet", "I like the quiet up here. Nobody asks too many questions."],
	["family", "My sister flew this route years ago. I wanted to see what she saw."],
	["mistake", "Clerical error. I signed for the Home Reach run. It has orchards."],
	["faith", "Up here you can hear yourself think. Or pray. Same thing, some days."],
	["fresh_start", "Clean slate. New ship, new me."],
	["aurora", "I saw a picture of the aurora over the Heights when I was nine. I had to see it."],
]

## Interests: id -> [label, things they say about it]
const INTERESTS := {
	"chess": ["chess", ["I've got a correspondence game going with a woman on the Rim. She's been thinking about her move for three weeks.", "Anyone here play chess? Real chess, not that clockwork nonsense.", "Knight to f3. Always knight to f3."]],
	"cooking": ["cooking", ["You haven't lived until you've had real bread. Not the hardtack.", "I'm working on a stew that only uses what grows on the island tops.", "The secret is salt. It's always salt."]],
	"music": ["music", ["The taproom squeezebox has exactly one good tune and I'm not telling you which.", "I used to play in a band. Terrible band. Great times.", "Do you ever hum along to the boiler? It's in B flat."]],
	"aurora": ["the aurora", ["The aurora was green and violet last night. Did you see it?", "I keep a log of every aurora I've seen up here. Forty-one so far.", "They say if you whistle at the aurora it comes down to get you."]],
	"geology": ["rocks", ["These islands drift about a mile a year. We're all riding something.", "Found a piece of banded stone with a fossil feather in it. Four hundred years old, easy.", "I collect rocks. Don't laugh."]],
	"conspiracy": ["conspiracies", ["The Guild knows exactly what's under the Deep. Why else keep the lanes closed?", "Ever notice the ferry schedule never lines up with the ledgers?", "I'm just saying, nobody has ever met the Guild board in person."]],
	"history": ["old-world history", ["Did you know people used to cross the sky in balloons with a basket and a prayer?", "I'm reading about the first lift-cell expeditions. Most of them ended badly.", "History doesn't repeat, but it definitely rhymes."]],
	"fitness": ["staying fit", ["Two hundred pull-ups on the mast every morning. The wind keeps you honest.", "Take the rigging. Every rung. Even in a gale.", "Slack ballast makes you soft. Not me."]],
	"gambling": ["cards and dice", ["Cards in the taproom, if anyone's brave enough.", "I'm up forty marks on the penny arcade this week. Don't tell the purser.", "Wanna bet on how long the boiler holds?"]],
	"gardening": ["plants", ["I talk to the plants in the ship garden. They grow better. It's natural philosophy.", "Tomatoes don't like altitude any more than we do.", "Someday I'm going to grow a real apple tree up here."]],
	"poetry": ["poetry", ["I wrote a haiku about the wind. It's just the word 'wind' seventeen times.", "Rime on the rigging / the stove clicks off again / I am so cold now", "Poetry is just complaining with rhythm."]],
	"engines": ["engines and machines", ["The boiler's got a little rattle in the third pipe. I love that rattle.", "They don't build airships like they used to. Thank goodness.", "Give me a wrench and a broken machine and I'm happy all day."]],
	"birds": ["birdwatching", ["There's a glidewing that circles the mooring mast. I named her Margaret.", "No proper birds up this high, really. I miss birds.", "Do you think birds could live in the Anvil? Big ones?"]],
	"films": ["old plays", ["I've got a trunk of old playbills. Want to read one in the taproom later?", "Nothing beats a play where everyone falls off the edge. Too soon?", "The ending of that one play... you know the one. Ruined me."]],
	"knitting": ["knitting", ["I'm knitting a scarf for everyone aboard. I'm up to three.", "Knitting keeps my hands warm and my mind quiet.", "Yes, I brought my own yarn. Yes, it took up half my kit."]],
	"religion": ["faith", ["I say a little prayer every time we cast off. Can't hurt.", "Whatever's out there in the clouds, I hope it's friendly.", "Faith is warm. Like a coat for the soul."]],
	"cryptids": ["the cloud creatures", ["The old hands say there's something big that lives under the cloud floor.", "I heard knocking from under the hull at night. Knock knock. Three times.", "You're going to laugh, but I've seen tracks out there that aren't ours."]],
	"tea": ["tea", ["Proper tea, not that galley sludge.", "I've got a tin of real leaf tea in my locker. Guard it with my life.", "Tea fixes most things. The rest need a blowtorch."]],
	"sports": ["skyball", ["The Rim Rovers are going all the way this year. Mark my words.", "Did you catch the skyball final? Neither did I. No signal out here.", "I used to play goalie. Took a ball to the face at forty knots."]],
	"stars": ["astronomy", ["You can see the Long Ring from the rail some nights.", "Every star you see out there is older than anything on this island.", "I'm mapping the constellations from here. They look different."]],
}

## Quirks: habits that show in what they do and how they come across.
const QUIRKS := {
	"hums": "hums while working",
	"smoker": "sneaks off for cigarette breaks",
	"coffee": "runs on hot drinks",
	"neat_freak": "can't stand a mess",
	"night_owl": "comes alive late in the watch",
	"early_bird": "is at work before everyone else",
	"superstitious": "knocks on wood, a lot",
	"collector": "picks up odd little things",
	"hypochondriac": "is sure they're coming down with something",
	"gossip": "knows everyone's business",
	"prankster": "loves a practical joke",
	"stickler": "goes by the book, always",
	"complainer": "always has something to complain about",
	"optimist": "sees the bright side of everything",
	"daydreamer": "is often lost in thought",
	"snacker": "is always eating something",
	"storyteller": "has a story for every occasion",
	"nosy": "sticks their nose into things",
	"loner": "prefers their own company",
	"worrier": "worries out loud",
}

const FOODS := ["flatbread", "stew", "sandwiches", "soup", "anything with cheese", "fried eggs", "tomato anything", "fresh bread", "meat pies", "noodles", "ship's biscuit, honestly"]
const DRINKS := ["cocoa", "black coffee", "tea", "beer", "rum", "water, just water", "anything hot", "skyfizz"]
const PEEVES := ["people who leave the hatch open", "loud chewing", "wet decks", "the bunkroom stove", "people who don't say thanks", "being called by my full name",
	"messy toolbelts", "the taproom squeezebox", "people touching my stuff", "running on the deck", "voice-link chatter about nothing", "being late"]
const FEARS := ["the dark", "the long drop", "fire", "being alone", "blood", "sickbays", "small spaces", "the boiler", "rats", "the lift cells failing"]

## Nicknames people like being called (short forms), picked by first letter where possible.
const NICK_STYLE := ["short", "surname", "full", "title"]

## Ambitions for the voyage: id -> [short text, first person goal]
const AMBITIONS := {
	"impress_boss": ["impress their section head", "I want my boss to notice me this voyage."],
	"make_friend": ["make a new friend", "I'd like to actually get to know someone here."],
	"see_aurora": ["see the aurora", "I want to see the aurora from the rail. Just once."],
	"promotion": ["earn a promotion", "I'm going to head this crew one day."],
	"win_arcade": ["beat the arcade high score", "I'm going to beat that penny arcade if it kills me."],
	"feed_everyone": ["make sure everyone eats", "Nobody on this ship goes hungry on my watch."],
	"quiet_shift": ["have a quiet voyage", "I just want one voyage where nothing catches fire."],
	"catch_criminal": ["catch a criminal", "Something shady is going on here and I'm going to catch whoever it is."],
	"save_life": ["save someone's life", "If someone's in trouble, I want to be the one who helps."],
	"learn_skill": ["learn something new", "I want to pick up a new skill before we make port."],
	"collect": ["find something interesting", "There's got to be something interesting on this ship."],
	"party": ["throw a get-together", "This place needs a party. A real one."],
	"write_home": ["write a letter home", "I owe my family a letter. A long one."],
	"get_rich": ["make some money on the side", "There's money to be made out here, if you're clever."],
}

# ------------------------------------------------------------------ fields
var hometown := ""
var reason_id := ""
var reason := ""
var interests: Array = [] # interest ids
var quirks: Array = [] # quirk ids
var fav_food := ""
var fav_drink := ""
var peeve := ""
var fear := ""
var chronotype := "day" # early / day / late
var ambitions: Array = [] # ambition ids
var ambition_done := {} # id -> true
var voice := {} # see Voice
var nick_style := "short"
var catchphrase := ""
var age := 30
var years_on_ice := 0

# ------------------------------------------------------------------ generation
static func generate(rng: RandomNumberGenerator, job: String, traits: Dictionary) -> Persona:
	var p := Persona.new()
	p.hometown = HOMETOWNS[rng.randi() % HOMETOWNS.size()]
	var reasons := REASONS.duplicate()
	# some reasons fit some people better
	if Jobs.dept(job) == "science":
		reasons.append(REASONS[2])
		reasons.append(REASONS[2])
	if traits.get("honesty", 0.5) < 0.35:
		reasons.append(REASONS[1])
		reasons.append(REASONS[6])
	if traits.get("curiosity", 0.5) > 0.65:
		reasons.append(REASONS[4])
		reasons.append(REASONS[11])
	var r: Array = reasons[rng.randi() % reasons.size()]
	p.reason_id = r[0]
	p.reason = r[1]
	p.age = rng.randi_range(22, 61)
	p.years_on_ice = rng.randi_range(0, mini(12, p.age - 21))
	# interests: 2-3, biased by job and personality
	var pool: Array = INTERESTS.keys()
	var weights := {}
	for k in pool:
		weights[k] = 1.0
	match Jobs.dept(job):
		"engineering": weights["engines"] = 4.0
		"science": weights["stars"] = 3.0; weights["geology"] = 3.0; weights["cryptids"] = 1.5
		"medical": weights["tea"] = 2.0; weights["knitting"] = 2.0
		"security": weights["fitness"] = 4.0; weights["films"] = 2.0
		"service": weights["cooking"] = 3.0 if job == "cook" else 1.5; weights["gardening"] = 5.0 if job == "botanist" else 1.0; weights["music"] = 3.0 if job in ["bartender", "clown"] else 1.0
		"supply": weights["geology"] = 3.0 if job == "miner" else 1.0; weights["gambling"] = 2.0
		"command": weights["history"] = 2.5; weights["chess"] = 2.5
	if traits.get("curiosity", 0.5) > 0.6:
		weights["conspiracy"] = 2.0; weights["cryptids"] = 2.5; weights["stars"] = 2.0
	if traits.get("humor", 0.5) > 0.6:
		weights["films"] = 2.0; weights["gambling"] = 2.0
	if traits.get("neuroticism", 0.5) > 0.6:
		weights["religion"] = 2.0; weights["knitting"] = 2.0
	var n_int := rng.randi_range(2, 3)
	for i in n_int:
		var pick := _weighted(rng, weights)
		if pick != "" and not pick in p.interests:
			p.interests.append(pick)
			weights.erase(pick)
	# quirks: 1-3
	var qw := {}
	for k in QUIRKS.keys():
		qw[k] = 1.0
	if traits.get("diligence", 0.5) > 0.7:
		qw["stickler"] = 3.0; qw["early_bird"] = 3.0; qw["neat_freak"] = 2.0
	if traits.get("diligence", 0.5) < 0.3:
		qw["daydreamer"] = 3.0; qw["night_owl"] = 2.5; qw["smoker"] = 2.0
	if traits.get("sociability", 0.5) > 0.65:
		qw["gossip"] = 3.0; qw["storyteller"] = 3.0
	if traits.get("sociability", 0.5) < 0.35:
		qw["loner"] = 4.0
	if traits.get("humor", 0.5) > 0.65:
		qw["prankster"] = 3.0
	if traits.get("neuroticism", 0.5) > 0.65:
		qw["worrier"] = 3.0; qw["hypochondriac"] = 2.0; qw["superstitious"] = 2.0
	if traits.get("neuroticism", 0.5) < 0.35:
		qw["optimist"] = 3.0
	if traits.get("curiosity", 0.5) > 0.65:
		qw["nosy"] = 2.5; qw["collector"] = 2.0
	if traits.get("lawfulness", 0.5) > 0.7:
		qw["stickler"] = qw.get("stickler", 1.0) + 2.0
	if job == "janitor":
		qw["neat_freak"] = 5.0
	if job == "clown":
		qw["prankster"] = 8.0
	var n_q := rng.randi_range(1, 3)
	for i in n_q:
		var q := _weighted(rng, qw)
		if q != "" and not q in p.quirks:
			# a few pairs contradict each other
			if (q == "early_bird" and "night_owl" in p.quirks) or (q == "night_owl" and "early_bird" in p.quirks):
				continue
			if (q == "loner" and "gossip" in p.quirks) or (q == "gossip" and "loner" in p.quirks):
				continue
			p.quirks.append(q)
			qw.erase(q)
	p.chronotype = "early" if "early_bird" in p.quirks else ("late" if "night_owl" in p.quirks else ["early", "day", "day", "late"][rng.randi() % 4])
	p.fav_food = FOODS[rng.randi() % FOODS.size()]
	p.fav_drink = DRINKS[rng.randi() % DRINKS.size()]
	if job == "bartender":
		p.fav_drink = ["rum", "beer", "black coffee"][rng.randi() % 3]
	p.peeve = PEEVES[rng.randi() % PEEVES.size()]
	if job == "janitor":
		p.peeve = ["people who walk on wet decks", "blood. So much blood.", "wet decks"][rng.randi() % 3]
	p.fear = FEARS[rng.randi() % FEARS.size()]
	# ambitions: 1-2
	var aw := {}
	for k in AMBITIONS.keys():
		aw[k] = 1.0
	if traits.get("diligence", 0.5) > 0.6:
		aw["impress_boss"] = 3.0; aw["promotion"] = 2.0 if not Jobs.is_head(job) else 0.0
	if Jobs.is_head(job):
		aw["promotion"] = 0.0; aw["impress_boss"] = 0.3; aw["quiet_shift"] = 2.5
	if traits.get("sociability", 0.5) > 0.6:
		aw["make_friend"] = 3.0; aw["party"] = 2.0
	if traits.get("curiosity", 0.5) > 0.6:
		aw["see_aurora"] = 2.5; aw["collect"] = 2.0; aw["learn_skill"] = 2.0
	if traits.get("empathy", 0.5) > 0.6:
		aw["save_life"] = 3.0; aw["feed_everyone"] = 1.5
	if traits.get("honesty", 0.5) < 0.35:
		aw["get_rich"] = 3.0
	if traits.get("neuroticism", 0.5) > 0.6:
		aw["quiet_shift"] = 3.0
	if Jobs.dept(job) == "security":
		aw["catch_criminal"] = 5.0
	if job == "cook":
		aw["feed_everyone"] = 6.0
	if Jobs.dept(job) == "medical":
		aw["save_life"] = 5.0
	if "gambling" in p.interests:
		aw["win_arcade"] = 3.0
	if "aurora" in p.interests:
		aw["see_aurora"] = 5.0
	var n_a := 1 if rng.randf() < 0.55 else 2
	for i in n_a:
		var a := _weighted(rng, aw)
		if a != "" and not a in p.ambitions:
			p.ambitions.append(a)
			aw.erase(a)
	p.voice = Voice.generate(rng, job, traits, p)
	p.nick_style = NICK_STYLE[rng.randi() % NICK_STYLE.size()]
	if Jobs.is_head(job) or job == "security":
		p.nick_style = ["surname", "title", "full"][rng.randi() % 3]
	p.catchphrase = _catchphrase(rng, job, traits, p)
	return p

static func _weighted(rng: RandomNumberGenerator, w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += maxf(0.0, w[k])
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for k in w:
		roll -= maxf(0.0, w[k])
		if roll <= 0.0:
			return k
	return w.keys()[-1]

static func _catchphrase(rng: RandomNumberGenerator, job: String, traits: Dictionary, p: Persona) -> String:
	var opts := ["Could be worse.", "Stay warm.", "Such is life in the sky.", "Right as rain.", "Nothing a blowtorch can't fix.", "One more watch.",
		"Keep your coat on.", "We ride the wind.", "Chin up.", "Colder than the Master's heart.", "Fair winds.", "Knock on wood."]
	if traits.get("humor", 0.5) > 0.65:
		opts.append_array(["That's what she-- never mind.", "Blow me down.", "Cloud nine, that.", "Sky's the limit."])
	if traits.get("aggression", 0.5) > 0.65:
		opts.append_array(["Don't push me.", "Whatever.", "Deal with it."])
	if traits.get("neuroticism", 0.5) > 0.65:
		opts.append_array(["We're all going to fall.", "This can't be good.", "Oh no. Oh no no."])
	if "religion" in p.interests:
		opts.append("The wind provides.")
	if Jobs.dept(job) == "engineering":
		opts.append_array(["Have you tried turning it off and on again?", "Wrench first, questions later."])
	if Jobs.dept(job) == "medical":
		opts.append_array(["Take two and call me in the morning.", "Wear your coat outside."])
	if Jobs.dept(job) == "security":
		opts.append_array(["Move along.", "I'm watching you.", "The Watch is the Watch."])
	if job == "clown":
		opts = ["Ta-da!", "Bells and whistles!", "Mind the peel!"]
	return opts[rng.randi() % opts.size()]

# ------------------------------------------------------------------ queries
func has_interest(id: String) -> bool:
	return id in interests

func has_quirk(id: String) -> bool:
	return id in quirks

func interest_label(id: String) -> String:
	return INTERESTS.get(id, [id])[0]

func shared_interests(other: Persona) -> Array:
	if other == null:
		return []
	return interests.filter(func(i): return i in other.interests)

func interest_line(id: String) -> String:
	var lines: Array = INTERESTS.get(id, ["", []])[1]
	if lines.is_empty():
		return ""
	return lines[randi() % lines.size()]

func interests_text() -> String:
	var labels := []
	for i in interests:
		labels.append(interest_label(i))
	return _and_list(labels)

func quirks_text() -> Array:
	var out := []
	for q in quirks:
		out.append(QUIRKS.get(q, q))
	return out

func ambition_text(id: String) -> String:
	return AMBITIONS.get(id, ["", ""])[0]

func ambition_line(id: String) -> String:
	return AMBITIONS.get(id, ["", ""])[1]

static func _and_list(items: Array) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return items[0]
	return "%s and %s" % [", ".join(items.slice(0, items.size() - 1)), items[-1]]

## What they call someone, by their own naming habit.
func address(other: Entity) -> String:
	if other == null:
		return "you"
	var parts: PackedStringArray = other.display_name.split(" ")
	var first: String = parts[0]
	var last: String = parts[parts.size() - 1] if parts.size() > 1 else first
	var om: CMob = other.c(&"mob")
	match nick_style:
		"surname":
			return last
		"full":
			return other.display_name if randf() < 0.3 else first
		"title":
			if om and Jobs.is_head(om.job):
				return {"captain": "Master", "hos": "Chief", "ce": "Chief", "cmo": "Doc", "rd": "Chief", "hop": "Purser", "qm": "Boss"}.get(om.job, first)
			if om and Jobs.dept(om.job) == "security":
				return "Watchman"
			if om and om.job in ["doctor", "cmo"]:
				return "Doc"
			return first
	return first

## A short biography, first person, for when someone asks about them.
func bio_lines(b) -> Array:
	var out := []
	out.append("I'm from %s. %s" % [hometown, reason])
	if years_on_ice == 0:
		out.append("First season in the sky, if you can believe it.")
	elif years_on_ice == 1:
		out.append("This is my second year out here.")
	else:
		out.append("I've done %d years in the sky now." % years_on_ice)
	if not interests.is_empty():
		out.append("In my spare time? %s." % Dialogue.cap(interests_text()))
	return out
