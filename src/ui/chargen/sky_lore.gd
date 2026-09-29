class_name SkyLore extends RefCounted
## Words for the sign-on office: where you were raised, what brought you up here, what the
## old engine's "quirks" are called in a sky port, and names to pick from. Pure data plus a
## couple of generators; nothing here touches the world, so the creator can be as chatty
## as it likes without changing a single number in the game.

## Altitude bands, by index into Defs.ALT_NAMES. `sky` is [zenith, mid, horizon] for the
## backdrop behind the pad, `sun` the colour of the light, `stars` how much of the night
## shows through, `cloud` the tint of the cloud banks.
const ORIGINS := [
	{"id": "deep", "name": "The Deep", "born": "Deep-born",
		"tag": "Warm, thick air two miles below the light.",
		"blurb": "Foundries, fog-markets and stairwells lit by lamps that never go out. Everything up top is made down here first, and nobody up top remembers that. Deep-born breathe anything and squint at every sunrise.",
		"proverb": "\"Up is only a direction. Down is a place.\"",
		"homes": ["Cinderstair", "Lamp Row", "the Under-Docks", "Fogmarket"],
		"sky": [Color("#3a2a3c"), Color("#b4643c"), Color("#f0b060")], "sun": Color("#ffb060"), "stars": 0.0,
		"cloud": Color("#f0c8a0"), "haze": 0.45},
	{"id": "shelf", "name": "The Shelf", "born": "Shelf-raised",
		"tag": "Trade lanes, tidy ports and reliable weather.",
		"blurb": "Where the money moves. Chandlers, customs houses and a bell to tell you the tide of the wind. Port Meridian is a Shelf town, so is half the paperwork in the sky, and you learned to read all of it.",
		"proverb": "\"A fair wind and a clean ledger.\"",
		"homes": ["Meridian", "Tolling Quay", "Saltpenny", "Harrow Landing"],
		"sky": [Color("#3a78c8"), Color("#8cc4ec"), Color("#ffe6b0")], "sun": Color("#fff0c0"), "stars": 0.0,
		"cloud": Color("#ffffff"), "haze": 0.25},
	{"id": "reaches", "name": "The Reaches", "born": "Reach-folk",
		"tag": "Cold, clean air, cliff villages and windmills.",
		"blurb": "Terraced islands strung with wind-farms, herds of cloud-goats and villages that only see a trader twice a year. Reach-folk are patient, blunt, and can tell you the weather by the hair on their arms.",
		"proverb": "\"The wind never lies. It just doesn't explain.\"",
		"homes": ["Gullwatch", "Thistle Fall", "Upper Kern", "Windbarrow"],
		"sky": [Color("#1f4a9a"), Color("#5aa0e0"), Color("#c0e8f4")], "sun": Color("#e8f4ff"), "stars": 0.05,
		"cloud": Color("#e8f4ff"), "haze": 0.15},
	{"id": "heights", "name": "The Heights", "born": "Height-born",
		"tag": "Thin air, aurora and observatory monasteries.",
		"blurb": "You learned to breathe slowly and to speak less. Stone cloisters, brass telescopes, and long nights under a green sky. Nobody in the Heights is in a hurry because nothing up there can afford to be.",
		"proverb": "\"Count the stars. They are the only honest ledger.\"",
		"homes": ["Vesper Cloister", "Hollow Crown", "the Glass Steps", "Nine Lenses"],
		"sky": [Color("#100a3a"), Color("#3a3aa0"), Color("#8a8ae0")], "sun": Color("#c8c0ff"), "stars": 0.7,
		"cloud": Color("#b8b8ee"), "haze": 0.2},
	{"id": "anvil", "name": "The Anvil", "born": "Anvil-touched",
		"tag": "The roof of the sky. Sealed hulls only.",
		"blurb": "Nobody is born there and a few were. Storm-wrecks, black air and a sun that does not warm. You grew up on a hull that never came down, and you still check the seals on every door you close.",
		"proverb": "\"If you can hear the wind, you are already in trouble.\"",
		"homes": ["Wreck Nine", "the Long Keel", "Scab Island", "Last Lamp"],
		"sky": [Color("#04040e"), Color("#161238"), Color("#4a2a5a")], "sun": Color("#ff7a5a"), "stars": 1.0,
		"cloud": Color("#7a6aa0"), "haze": 0.1},
]

## What brought you up here. `line` is what the papers say.
const REASONS := [
	{"id": "wander", "name": "The horizon", "line": "Looked up once and never quite looked down again.",
		"blurb": "There was a coast, and then there was the edge of it, and you kept walking."},
	{"id": "debt", "name": "A debt", "line": "Owes somebody in Meridian, and the sky is the one place large enough to hide.",
		"blurb": "It began as a small sum. It is not a small sum now, and the sky is very large."},
	{"id": "legacy", "name": "A lost ship", "line": "Was left a name and a great deal of paperwork; the ship went down with the rest.",
		"blurb": "Somebody left you a name that meant something on a hull. The hull is gone. The name is not."},
	{"id": "escape", "name": "A closed door", "line": "Left a place behind. Does not say which.",
		"blurb": "You left a place with your head down and did not look back. You still do not discuss it."},
	{"id": "promise", "name": "A promise", "line": "Gave their word to someone, and is still working out how to keep it.",
		"blurb": "You said you would, and at the time you meant it, and now you are two thousand feet up."},
]

## Per-calling flavour: the rating written on the papers and what old hands say about it.
const CALLINGS := {
	"deckhand": ["Able Hand", "\"Hauls, hoists, holds the line. Every ship is short of one.\""],
	"shipwright": ["Master of Keels", "\"Ask her what a ship wants and she will tell you it wants a better keel.\""],
	"prospector": ["Vein-reader", "\"Listens to rock. Rock, on the whole, listens back.\""],
	"sailmaker": ["Canvas-hand", "\"Two needles, one thimble, no patience for wind.\""],
	"gunner": ["Broadside Hand", "\"Left the last ship on good terms. Or at speed.\""],
	"navigator": ["Sky-reader", "\"Knows where the islands are and what the weather thinks of them.\""],
	"beastlorist": ["Beast-hunter", "\"Has met most things that bite, and the scars to prove the introductions.\""],
	"distiller": ["Still-keeper", "\"Fuel by the barrel, tonics by request, other things by arrangement.\""],
	"artificer": ["Aether-wright", "\"Half the trade is knowing what it does. The other half is what it does next.\""],
	"salvager": ["Wreck-picker", "\"Has a rule about not looking at the crew.\""],
	"factor": ["Cargo Factor", "\"Rich, connected and cannot tie a knot to save their life.\""],
}

## Quirks under their sky names. Same ids, same points, same effects; only the words differ.
## id -> [name, what it means aboard]
const HABITS := {
	"alcohol_tolerance": ["Hollow Leg", "A night in the taproom leaves you standing. Drink hits you slowly and costs you less."],
	"drunkhealing": ["Spirits Mend", "A few drinks in and your hurts close up on their own, which is not medical advice."],
	"empath": ["Reads the Room", "One look at a face and you know how the day is going for them."],
	"freerunning": ["Rigging Rat", "Quick over rails and crates, and short drops do you no harm."],
	"friendly": ["Warm Welcome", "You give the best hugs on the quay, when you are in the mood."],
	"jolly": ["Fair-Weather Cheer", "Sometimes you are simply happy, for no reason. Sailors find it suspicious."],
	"light_step": ["Soft Boots", "You walk gently: quieter footfalls, kinder to sharp things underfoot, and nothing sticks to your soles."],
	"selfaware": ["Knows Their Own Hull", "You can tell exactly how badly you are hurt, and where."],
	"strong_stomach": ["Galley Stomach", "You will eat what fell on the deck and it will not argue."],
	"throwingarm": ["Bosun's Arm", "Whatever you throw goes further, and lands where you meant."],
	"death_mimicry": ["Playing Dead", "A well-timed death gasp drops you senseless and fools anyone who looks, for a little while."],
	"bald": ["Bare Pate", "No hair, and touchy about it. Keep a cap on, or at least keep quiet."],
	"deviant_tastes": ["Odd Palate", "You dislike what everybody eats and love what nobody does."],
	"gamer": ["Dice-Hand", "You need a game the way others need breakfast. You love to win and hate to lose."],
	"monochromatic": ["Grey-Sighted", "You see the world in blacks and whites, and it has never cost you a wager."],
	"no_taste": ["Dull Tongue", "Nothing has a flavour. Poisons still work."],
	"phobia": ["A Certain Fear", "There is one thing you are irrationally afraid of. Ask the crew what."],
	"shifty_eyes": ["Wandering Eye", "Your gaze roams, and people think you are looking straight at them when you are not."],
	"vegetarian": ["Greens Only", "Meat is morally and physically out of the question."],
	"all_nighter": ["Sleepless Watch", "You have not slept, and it shows. Short-tempered and prone to nod off; tea or a nap helps."],
	"badback": ["Bad Back", "Packs never sit right on you. Evenly balanced loads are fine."],
	"blindness": ["Blind", "You cannot see at all, and nothing can change that."],
	"blooddeficiency": ["Thin Blood", "Your body cannot keep up with what it loses."],
	"brainproblems": ["Slow Fever", "Something is wearing away at your mind. Keep a tonic to hand."],
	"deafness": ["Deaf", "You cannot hear, and never will."],
	"depression": ["Grey Spells", "Sometimes you hate life. It passes; it also comes back."],
	"family_heirloom": ["Family Heirloom", "You carry something of your family's. Keep it safe."],
	"frail": ["Glass Bones", "Skin like paper, bones like glass. You are wounded far more easily."],
	"glass_jaw": ["Glass Jaw", "One hard knock to the head and out you go."],
	"hypersensitive": ["Wears Its Heart", "Everything moves your mood further than it should, for better or for worse."],
	"insanity": ["Sky-Sick", "A deep trouble of the mind: vivid visions and trouble putting your thoughts into words."],
	"light_drinker": ["Lightweight", "One cup and you are singing."],
	"monophobia": ["Hates Being Alone", "You have always kept to crowds. Solitude frightens you badly."],
	"mute": ["Voiceless", "You cannot speak."],
	"narcolepsy": ["Drowsy Spells", "You could nod off at any moment. Tea, movement and stimulants help you through the watch."],
	"nearsighted": ["Short-Sighted", "Everything beyond your arm is soft, but you carry spectacles."],
	"nonviolent": ["Pacifist", "The thought of harming anybody makes you ill. You cannot do it."],
	"numb": ["Feels No Pain", "You cannot feel pain at all. This is worse than it sounds."],
	"nyctophobia": ["Afraid of the Dark", "Without a lamp, you feel a creeping dread."],
	"photophobia": ["Sun-Shy", "Bright light bothers you more than it does most."],
	"poor_aim": ["Shoots Wide", "You have never hit what you aimed at."],
	"prosopagnosia": ["Faceblind", "You cannot recognise faces at all."],
	"pushover": ["Pushover", "Your first instinct is to give way. Slipping out of a grip is much harder."],
	"pyrophobia": ["Fears the Flame", "Fire terrifies you. That includes boilers."],
	"social_anxiety": ["Tongue-Tied", "Talking to strangers is very hard; you stammer or freeze."],
	"softspoken": ["Soft-Spoken", "Your voice barely carries."],
	"unstable": ["Unsteady Nerves", "Old troubles: once your nerve goes, it does not come back on its own."],
	"smoker": ["Pipe-Smoker", "Now and then you badly want a pipe. Not kind to your lungs."],
	"alcoholic": ["Bottle-Bound", "You cannot go long without a drink."],
	"junkie": ["Aether-Dreamer", "You cannot get enough of the hard stuff."],
}

const FIRSTS := ["Tamsin", "Orrin", "Bryony", "Calder", "Dessa", "Edrin", "Fenna", "Galen", "Halcyon", "Isolde", "Jory", "Kestrel",
	"Lark", "Marek", "Nerys", "Odo", "Pippa", "Quill", "Rook", "Saskia", "Tobias", "Ulla", "Vance", "Wren", "Yarrow", "Zephyr",
	"Aldous", "Briar", "Cormac", "Delphine", "Emrys", "Fitch", "Gwen", "Hollis", "Ines", "Jasper", "Kit", "Linnea", "Merrin", "Nash",
	"Ottoline", "Percival", "Rosalind", "Silas", "Thea", "Ansel", "Blythe", "Corin"]
const LASTS := ["Windermere", "Cloudesley", "Brightwater", "Skerry", "Tallow", "Corvane", "Fairweather", "Hargreave", "Ashdown", "Quillon",
	"Stormwright", "Latch", "Pennywhistle", "Rookwood", "Saltmarsh", "Gantry", "Halyard", "Kettleby", "Lanternshaw", "Mizzen",
	"Oakhollow", "Pell", "Ravenscroft", "Sparrowhawk", "Thistlewood", "Vane", "Wick", "Yardley", "Brasswell", "Cutter", "Dunmere",
	"Fathom", "Grayling", "Heron", "Keel", "Larkspur", "Marlow", "Northcott", "Ostler", "Tern"]
const NICKS := ["Lucky", "Two-Sail", "Fathom", "Gale", "Bosun", "Cinder", "Patch", "Weathervane", "Longshot", "Windfall", "Kite", "Brass"]

const SHIP_A := ["Prudent", "Second", "Long", "Brass", "Fair", "Windward", "Restless", "Modest", "Tolerable", "Late", "Gilded", "Honest"]
const SHIP_B := ["Gull", "Thoughts", "Way Round", "Kestrel", "Weather", "Bargain", "Lantern", "Apology", "Compass", "Errand", "Sparrow", "Promise"]

static func origin(i: int) -> Dictionary:
	return ORIGINS[clampi(i, 0, ORIGINS.size() - 1)]

static func reason(id: String) -> Dictionary:
	for r in REASONS:
		if r["id"] == id:
			return r
	return REASONS[0]

## An airship-flavoured person. Sometimes with a nickname, always under 32 characters.
static func random_name(rng: RandomNumberGenerator) -> String:
	var f: String = FIRSTS[rng.randi() % FIRSTS.size()]
	var l: String = LASTS[rng.randi() % LASTS.size()]
	if rng.randf() < 0.28:
		var n: String = NICKS[rng.randi() % NICKS.size()]
		var full := "%s \"%s\" %s" % [f, n, l]
		if full.length() <= 30:
			return full
	return "%s %s" % [f, l]

## The name you tell people you will give your first ship.
static func random_ship(rng: RandomNumberGenerator) -> String:
	if rng.randf() < 0.3:
		return "%s's %s" % [FIRSTS[rng.randi() % FIRSTS.size()], SHIP_B[rng.randi() % SHIP_B.size()]]
	return "The %s %s" % [SHIP_A[rng.randi() % SHIP_A.size()], SHIP_B[rng.randi() % SHIP_B.size()]]

## Name and blurb for a quirk id, falling back to the engine's own wording.
static func habit(id: String) -> Array:
	if HABITS.has(id):
		return HABITS[id]
	var d: Array = Quirks.DEFS.get(id, [id, 0, ""])
	return [d[0], d[2]]
