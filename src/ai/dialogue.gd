class_name Dialogue extends RefCounted
## What NPCs say. Lines are picked for the situation, the relationship and the speaker's
## persona; *how* they're typed (caps, typos, slang) is added when spoken, by Voice.
## Everything returns plain text; CBrain.say / radio_say run it through the voice.

const LINES := {
	"see_body": ["Oh god... {name}?", "No, no, no... {name} is dead.", "Someone fetch the surgeon, {name} isn't breathing!", "...{name}? Oh no.", "Is that... is that {name}?", "Surgeon! {name}'s not moving!"],
	"friend_dead": ["{name}! NO! Somebody help!", "Not {name}... please, not {name}.", "{name}... I'm so sorry.", "No. No, {name}, wake up. Wake UP."],
	"alarm_fire": ["FIRE! Fire in {area}!", "Fire! Everyone out!", "Is that smoke?! FIRE!", "{area} is on fire!"],
	"alarm_on_fire": ["They're on fire!", "Someone's burning! Help!", "Stop, drop and roll!"],
	"alarm_explosion": ["What the hell was that?!", "Explosion! Get down!", "That came from {area}!", "The whole ship shook!"],
	"alarm_pipe_burst": ["A pipe just blew!", "Did you hear that bang?", "That's a pipe going, somewhere close."],
	"alarm_chem_reaction": ["What was THAT?", "Something just went off in {area}!", "The still's at it again."],
	"alarm_window_broken": ["The window! We've got a breach!", "Hull breach! Grab something!", "Window's gone, it's getting cold fast!"],
	"thanks": ["Thanks, {name}. I owe you one.", "Thank you... thank you, {name}.", "You're a lifesaver, {name}.", "I won't forget this, {name}."],
	"laugh": ["Ha! Watch your step!", "Heh. Classic.", "Pffft.", "HAH.", "Oh that's going in my diary."],
	"confront": ["Hey! What do you think you're doing, {name}?!", "{name}! Knock it off!", "I SAW that, {name}!", "Put it down, {name}. Now."],
	"witness": ["...did {name} just do that?", "The Watch needs to hear about this.", "Uh. I didn't see anything. Or did I.", "Okay, that's going out on the voice-link."],
	"panic": ["We're all going to die out here!", "I can't, I can't, I can't-", "Get me out of here!", "Oh god oh god oh god", "HELP! Anybody!"],
	"snap": ["That's IT, {name}! I've had it with you!", "You've been asking for this, {name}!", "I'm done being nice, {name}!"],
	"revenge": ["Remember me, {name}?", "Payback time, {name}.", "You thought I'd forget, {name}?"],
	"follow_ok": ["Lead the way, {name}.", "Sure, I'm right behind you.", "Okay, okay, I'm coming.", "Where are we going?", "Right with you."],
	"refuse": ["Why would I follow you?", "I've got my own work to do.", "No thanks.", "I don't even know you.", "Nah."],
	"ok": ["Okay.", "Sure.", "Fine, fine.", "Alright.", "Got it."],
	"nothing_new": ["Quiet watch so far.", "Not much. Cold, as usual.", "Nothing worth mentioning.", "Same old. Cloud and more cloud.", "Honestly? Nothing. It's been dead boring."],
	"welcome": ["Any time.", "No problem.", "Don't mention it.", "Happy to help.", "That's what we're here for."],
	"coming": ["On my way!", "Hang on, I'm coming!", "Hold still, I've got you.", "Stay there, I'm coming to you."],
	"dropped_patient": ["{name}'s in sickbay. Somebody patch them up!", "Got {name} to sickbay. Surgeon?"],
	"fixed": ["Repair done in {area}.", "{area} is patched up.", "Fixed the problem in {area}.", "{area}'s sorted.", "All good in {area} now."],
	"found_fault": ["There's the fault. Burnt cable.", "Found it. Wiring's fried.", "Aha. There's your problem."],
	"patched": ["There, {name}. You'll live.", "All patched up, {name}. Take it easy.", "Try not to do that again, {name}.", "Good as new. Well, nearly."],
	"arrest": ["Watch! Stop right there, {name}!", "{name}, you're under arrest!", "Hands where I can see them, {name}!", "Don't move, {name}!"],
	"oops": ["Oh. Oh no.", "That was NOT supposed to happen!", "Uh... fire extinguisher, anyone?", "Interesting! Also, ow."],
	"order_up": ["Order up! Fresh {food}.", "Hot {food}, come and get it!", "{food}'s ready!", "Fresh {food} on the counter!"],
	"honk": ["Ta-da!", "Watch your step, everybody!", "Hehehe."],
	"bye": ["See you around.", "Later.", "Take care.", "Stay warm.", "Catch you later.", "Bye for now."],
	"busy": ["Sorry, bit busy right now.", "Can it wait? I'm in the middle of something.", "Not now, I'm working.", "One sec... actually, a lot of secs. Busy."],
	"break_off": ["Sorry, gotta go.", "Hold that thought.", "I have to run, sorry!", "Duty calls.", "Oh, I have to deal with something."],
	"confused": ["Huh?", "Sorry, what?", "Not sure what you mean.", "Come again?", "...okay?", "I don't follow.", "Say that again?"],
	"yes": ["Sure!", "Yeah, okay.", "Why not.", "Alright, I can do that.", "Sure thing."],
	"no": ["No.", "Not a chance.", "I'd rather not.", "Nope.", "Can't, sorry."],
	"apology_accept": ["Alright. Apology accepted.", "Fine. Just don't do it again.", "Okay. We're good.", "...Okay. Thanks for saying that."],
	"apology_reject": ["Sorry doesn't cut it.", "Save it.", "You think sorry fixes that?", "Words are cheap."],
	"insulted": ["Excuse me?", "Wow. Okay.", "Rude.", "What's your problem?", "Charming.", "Say that again, I dare you."],
	"insulted_mad": ["Watch your mouth!", "You want to go?", "Say that one more time.", "Keep talking and see what happens."],
	"insulted_hurt": ["...that's not very nice.", "Why would you say that?", "Okay. I'll just... go.", "Wow. Thanks."],
	"complimented": ["Aw, thanks!", "That's nice of you to say.", "Really? Thanks!", "You're alright yourself.", "Stop it, you'll make me blush."],
	"complimented_cold": ["...thanks, I guess.", "Uh huh.", "What do you want?", "Flattery won't get you anywhere."],
	"threatened": ["Are you threatening me?", "The Watch is going to hear about this.", "Back off.", "Try it."],
	"threatened_scared": ["P-please don't hurt me.", "Okay, okay! I don't want trouble!", "Someone help!", "I'm calling the Watch!"],
	"greet_stranger": ["Hi.", "Hello.", "Hey there.", "Oh, hi. I don't think we've met.", "{tod}. You new?"],
	"greet_known": ["Hey, {name}.", "{tod}, {name}.", "Oh, hi {name}.", "Cold enough for you, {name}?", "{name}! How's it going?"],
	"greet_friend": ["{name}! Good to see you!", "Hey you!", "There's my favourite {job}!", "{name}! Just the person I wanted to see.", "Oh thank god, a friendly face. Hi {name}."],
	"greet_enemy": ["Oh. It's you.", "{name}.", "What do you want?", "Great. {name}.", "...hi."],
	"greet_boss": ["{tod}, {name}.", "Hi {name}. Everything's under control. Mostly.", "Hey {name}, all good here.", "Hey boss."],
	"passing_hi": ["Hey {name}.", "{tod}.", "Hi {name}!", "Yo.", "o/", "{tod}, {name}.", "Hey.", "Hiya {name}."],
	"joke": [
		"Why don't skyhares like talking to strangers at parties? They find it hard to break the cloud.",
		"What's an engineer's favourite part of a pipe? The part that isn't leaking. Which is none of them.",
		"How do you know the Master's been in a room? The whole crew is standing up straight.",
		"I told the boiler a joke. It didn't react.",
		"What do you call a prospector who doesn't come back? Honestly, we call them 'Tuesday'.",
		"Knock knock. Who's there? The island. The island who? The island drifting under the ship, but slowly.",
		"Why did the artificer stay inside? Too much skyglass. Get it? Sky-glass. ...I'll see myself out.",
		"What's the difference between the galley food and the hail outside? The hail has more flavour.",
		"I'd tell you a joke about the stove, but you wouldn't get it. It's not working.",
		"How many engineers does it take to change a lamp? None, they just say it's a feature.",
		"Why did the doctor bring a coat to surgery? In case the patient got cold feet.",
		"What does a watchman say when they're bored? 'Anyone want to be arrested?'",
		"The ferry's always late. Then again, so am I. We're a good match.",
	],
	"joke_laugh": ["Hah! Good one.", "Pffft. Okay, that was good.", "Heh.", "HAH. Alright, alright.", "I hate that I laughed."],
	"joke_groan": ["Ugh.", "That was terrible.", "...no.", "I'm reporting you to the Watch for that one.", "Boo."],
	"console": ["Hey. It's okay. I'm here.", "Take a breath. We'll get through this watch.", "Want to talk about it?", "Come on, let's get you a hot drink.", "You're not alone up here, {name}."],
	"console_reply": ["Thanks. I needed that.", "...yeah. Thanks, {name}.", "I'll be okay. I think.", "You're a good friend, {name}."],
	"grieving": ["I keep thinking about {name}.", "I can't believe {name}'s gone.", "{name} didn't deserve that.", "It should have been a normal voyage."],
	"cold_comment": ["Brr.", "Why is it always so COLD.", "Can't feel my fingers.", "Somebody fix the stove, please."],
	"hungry_comment": ["I'm starving.", "When's lunch?", "My stomach's making noises.", "I'd kill for a sandwich right now."],
	"tired_comment": ["*yawns*", "I need a nap.", "Five more minutes...", "Is it bedtime yet?"],
	"bored_comment": ["Bored...", "Anyone doing anything fun?", "I'm so bored I'm reading the fire safety posters.", "Nothing to do on this tub."],
	"stressed_comment": ["I need a break.", "Everything's falling apart.", "Deep breaths. Deep breaths.", "Why did I sign up for this?"],
	"see_bleeding": ["{name}, you're bleeding everywhere! Get to sickbay!", "Whoa, {name}, you're leaking. Sickbay. Now.", "{name}! Wrap that before you pass out!"],
	"see_burning": ["{name}, you're ON FIRE!", "Roll, {name}! ROLL!"],
	"see_choking": ["{name}, you're choking! Mask on! Open your cylinder!", "{name}! Get out of here, the air's bad!", "{name}, can you breathe?! Get out!", "Breathe, {name}! Mask, now!"],
	"see_hurt": ["You look hurt, {name}. Want me to call a doctor?", "{name}, you okay? You look awful.", "Whoa, {name}. Sickbay. Seriously.", "Who did that to you, {name}?"],
	"see_bloody": ["Is that blood on you, {name}?", "{name}... why are you covered in blood?", "Uh, {name}? You've got blood on you."],
	"see_weapon": ["Put that away, {name}.", "Why are you waving that around, {name}?", "{name}, holster that. We're all clear."],
	"no_coat_outside": ["{name}, where's your coat? You'll freeze!", "Get inside, {name}, you're not dressed for that!"],
	"ack": ["On it.", "Copy.", "I'll take it.", "Heading there now.", "Got it.", "Roger.", "omw", "I've got this one.", "Understood.", "On my way."],
	"ack_head": ["Acknowledged.", "Understood, on it.", "Copy that, handling it.", "I'll see to it."],
	"someone_else": ["{name}'s on it.", "{name} has it, I'll stand by.", "Leaving it to {name}."],
	"all_clear": ["All clear here.", "{area} is fine now.", "Crisis averted in {area}."],
	"lunch_call": ["Dinner! Who's coming to the galley?", "I'm grabbing a bite, anyone want to join?", "Food time. Galley in five.", "Anyone hungry? Galley's open."],
	"break_start": ["Taking five.", "Break time.", "I'm on break, don't call me.", "Stepping away for a bit."],
	"back_to_work": ["Back to it.", "Right, back to work.", "Break's over, sadly.", "Alright, where was I."],
	"shift_start": ["Morning, everyone.", "Another day in the sky.", "Who made the coffee? Oh right, nobody. There's no coffee.", "Let's have a quiet one, people."],
	"shift_end": ["Almost done. Hang in there.", "Home stretch, everyone.", "Can't wait for port."],
	"arcade_win": ["YES! High score!", "Get wrecked, machine!", "Who's the champion? Me. I'm the champion.", "Top of the board, baby!"],
	"arcade_lose": ["Oh come ON.", "This machine is rigged.", "One more go. Just one more.", "Ugh, so close."],
	"smoke": ["*lights a cigarette*", "Ahh. That's the stuff.", "Don't tell the surgeon.", "Just one. I'll quit tomorrow."],
	"aurora": ["Look at that... the aurora.", "Would you look at that sky.", "Green and violet. Gorgeous.", "That's why I came out here."],
	"music_on": ["Let's get some music going.", "This place is too quiet.", "Now THIS is my song."],
	"drink_order": ["One {drink}, please.", "Could I get a {drink}?", "{drink}, when you get a sec.", "Pour me a {drink}, would you?", "The usual. {drink}."],
	"drink_serve": ["Here you go. One {drink}.", "{drink}, as ordered.", "Enjoy.", "On the house. Don't tell the purser.", "Coming right up. There."],
	"food_serve": ["Here, {name}. Eat up.", "One {food}, hot.", "Made you something, {name}.", "Try this. Fresh {food}."],
	"give_item": ["Here, take this.", "Here you go.", "Catch.", "It's yours, {name}.", "Take it, I've got a spare."],
	"refuse_item": ["I need that for work.", "Sorry, that's mine.", "Get your own.", "Not a chance.", "I can't give that away."],
	"dont_have": ["I don't have one on me.", "Sorry, don't have any.", "I wish."],
	"taught": ["Here's how it works: {tip}", "Pro tip: {tip}", "Listen, {tip}", "Okay, so. {tip}", "What I've learned out here: {tip}"],
	"cant_teach": ["I wouldn't know where to start.", "That's not really my area.", "Ask someone from that crew.", "Honestly, I'm no expert."],
	"favor_thanks": ["You actually did it! Thanks, {name}.", "Perfect, that's exactly what I needed. I owe you one.", "You're a star, {name}.", "Brilliant. Thank you!"],
	"favor_decline_ok": ["No worries.", "That's fine, I'll figure it out.", "Alright, never mind."],
	"not_wanted": ["What's this for?", "Uh, thanks? I don't really need this.", "Why are you giving me this?"],
	"food_thanks": ["Oh, food! Thank you!", "You're an angel, I was starving.", "Thanks! I'll eat this right now."],
	"stop_fight": ["Break it up, both of you!", "HEY! Cut it out!", "Watch! Stop fighting!"],
	"accused_deny": ["That's a lie!", "I didn't do anything!", "Who told you that?", "Prove it.", "I was nowhere near there."],
	"accused_guilty": ["...I can explain.", "It's not what it looks like.", "Okay, fine. Yes. But there's a reason."],
	"leave_me": ["Leave me alone.", "Go away.", "I don't want to talk to you.", "Not interested."],
}

## Gameplay advice, by skill: NPCs are the ship's living tutorials.
const TIPS := {
	"medical": ["for a bleeding limb, aim at it and wrap gauze. Then suture the cut closed.",
		"broken bone? Bone gel, then surgical tape. In a pinch, gauze makes a splint.",
		"burns need mesh or ointment, and keep them clean or they go septic.",
		"if someone's been dead less than five minutes, defib them. If it buzzes about the heart, fix that first.",
		"someone in crit? CPR keeps them going. Right-click them.",
		"scan people with a health analyzer before you guess. It tells you everything.",
		"a lot of blood lost? Blood packs on an IV drip. Otherwise they just keep fading."],
	"engineering": ["leaking pipe? Weld it shut with the blowtorch. Wear something on your eyes.",
		"burnt wiring gets relaid with a cable coil.",
		"if a power junction's dark, check the breaker before you go hunting for broken cable.",
		"a broken window: rods to fix the grille, then two sheets of glass. Reinforced if you've got it.",
		"boiler running hot? Push the control rods in at the console, then find the coolant leak.",
		"doors: screwdriver opens the panel, multitool pulses the wires, wirecutters cut them."],
	"construction": ["metal sheets make half of everything. Use them in your hand and see the list.",
		"crowbar pries up floor tiles. Screwdriver and wrench take most furniture apart.",
		"a blowtorch does walls, a wrench does machines. Don't mix them up in front of the chief shipwright."],
	"atmos": ["air bell ringing? Check the vents and scrubbers in that room first.",
		"fires: grab an extinguisher from any red cabinet and aim at the base.",
		"a shimmer projector blocks a breach long enough to fix it properly.",
		"if the air's bad, mask up and open your gas cylinder. Don't be a hero."],
	"security": ["shove someone to knock them down, then cuff them.",
		"an aether stunner tires people out from range. Three or four shots and they drop.",
		"flash then cuff. Sunglasses block flashes, so check their face first.",
		"warrants go through the Watch records. Log everything."],
	"cooking": ["two ingredients in the microwave make a meal. Flour, eggs, meat, tomatoes, whatever's in the fridge.",
		"feed people and they love you. Simple as that."],
	"botany": ["grow trays need regular care. Hand-tend them and they'll grow.",
		"bring the harvest to the galley icebox. The cook will thank you."],
	"chemistry": ["some reactions only happen above a certain temperature. Use the heater.",
		"never mix things at random. I mean it. I've seen the scorch marks."],
	"mining": ["before the high islands: warm coat, breath mask, gas cylinder open. And a pickaxe.",
		"bring ore back to the quay. The hold sells it."],
	"survival": ["up high, the cold kills in minutes. Coat, mask, gas cylinder.",
		"a hot cocoa from the galley warms you right up.",
		"if you're freezing below decks, the stove's out. Tell the engine room."],
	"social": ["be decent to people. Word gets around here, good and bad.",
		"say thanks. You'd be amazed how far it gets you."],
	"science": ["the ledger engine spends research points on new tech. The servers earn them slowly.",
		"the breaking bench gives points for taking apart interesting things."],
}

const TIP_ALIASES := {"medicine": "medical", "doctor": "medical", "heal": "medical", "healing": "medical", "surgery": "medical", "first aid": "medical",
	"engineer": "engineering", "repair": "engineering", "fix": "engineering", "power": "engineering", "wiring": "engineering", "electric": "engineering",
	"build": "construction", "building": "construction", "atmospherics": "atmos", "air": "atmos", "fire": "atmos", "gas": "atmos",
	"fight": "security", "fighting": "security", "combat": "security", "arrest": "security", "cook": "cooking", "food": "cooking",
	"plants": "botany", "garden": "botany", "chem": "chemistry", "mine": "mining", "survive": "survival", "cold": "survival", "talk": "social",
	"people": "social", "research": "science"}

## Capitalise the first letter only (String.capitalize() title-cases every word).
static func cap(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)

static func pick(opts: Array) -> String:
	if opts.is_empty():
		return ""
	return opts[randi() % opts.size()]

static func fill(s: String, vars: Dictionary) -> String:
	if s.contains("{tod}"):
		s = s.replace("{tod}", _time_greeting())
	for k in vars:
		s = s.replace("{" + k + "}", str(vars[k]))
	return s

static func line(cat: String, _b, vars: Dictionary) -> String:
	return fill(pick(LINES.get(cat, [])), vars)

static func first(e: Entity) -> String:
	return e.display_name.split(" ")[0] if e else "someone"

## What `b` calls `other` (their persona's naming habit).
static func call_name(b, other: Entity) -> String:
	if b != null and b.persona != null:
		return b.persona.address(other)
	return first(other)

# ------------------------------------------------------------------ reports
static func report_line(b, f: Dictionary) -> String:
	var area := Game.map.area_at(f.get("cell", Vector2i.ZERO)).name
	var formal: bool = Jobs.is_head(b.job) or b.tv("diligence") > 0.7
	var s := ""
	match f["type"]:
		"fire": s = pick(["Fire in %s! Need help here!", "%s is on fire!", "FIRE, %s!", "We've got a fire in %s."]) % area if not formal else "Fire reported in %s. Requesting assistance." % area
		"breach": s = pick(["Hull breach in %s! It's freezing in here!", "Breach in %s, window's gone.", "%s is breached, need the engine room!"]) % area
		"person_down": s = pick(["%s is down in %s! We need a medic!", "Medic! %s collapsed in %s!", "%s isn't moving, %s. Doctors please!"]) % [Knowledge._name(f.get("subject", 0)), area]
		"body":
			var who := Knowledge._name(f.get("subject", 0))
			s = pick(["Found %s dead in %s." % [who, area], "%s is dead. %s." % [who, area], "Body in %s. It's %s." % [area, who]])
		"injured": s = "%s is hurt in %s." % [Knowledge._name(f.get("subject", 0)), area]
		"burning_person": s = "%s is on fire in %s!" % [Knowledge._name(f.get("subject", 0)), area]
		"sick": s = "%s looks really sick. Sickbay, might be contagious." % Knowledge._name(f.get("subject", 0))
		"power_out": s = pick(["Power's out in %s.", "%s has no power.", "Lights are out in %s, engineering?"]) % Game.map.areas[f.get("area", 0)].name
		"hazard_gas": s = pick(["Air's bad in %s, stay out!", "Don't go in %s, the air's toxic.", "%s has bad air, masks on."]) % area
		"pipe_leak": s = pick(["Leaking pipe in %s.", "There's a pipe hissing in %s.", "Pipe leak, %s."]) % area
		"cold_area": s = pick(["It's freezing in %s. Stove's gone.", "%s is an icebox, can someone look at the stove?"]) % area
		"crime":
			var d: Dictionary = f.get("data", {})
			s = "Watch, %s %s." % [Knowledge._name(d.get("actor", 0)), b.knowledge._crime_text(f)]
			if b.tv("honesty") < 0.3 and randf() < 0.3:
				s += " Probably."
		_:
			s = b.knowledge.describe(f)
	return s

static func fact_line(b, f: Dictionary) -> String:
	var src := {Knowledge.SEEN: "I saw", Knowledge.HEARD: "I heard", Knowledge.TOLD: "Someone told me", Knowledge.RADIO: "Radio said", Knowledge.JOB: "Word is", Knowledge.FELT: "Looks like"}.get(f.get("src", 0), "I heard")
	var what: String = b.knowledge.describe(f)
	if f["type"] == "crime":
		what = "%s %s" % [Knowledge._name(f.get("data", {}).get("actor", 0)), b.knowledge._crime_text(f)]
		if f.get("src", 0) == Knowledge.SEEN:
			return pick(["%s. Saw it with my own eyes." % Dialogue.cap(what), "I watched %s. Right in front of me." % what.replace(" was ", " who was "), "%s. I was there." % Dialogue.cap(what)])
		return "%s %s." % [src, what] if src != "Someone told me" else "Did you hear? %s." % Dialogue.cap(what)
	var opener = pick(["Did you hear? ", "So get this: ", "", "Between you and me, ", "Okay, so, "])
	return "%s%s %s." % [opener, src, what]

static func fact_reaction(b, f: Dictionary) -> String:
	if f["type"] in ["body", "crime"] and f.get("severity", 0) >= 3:
		return pick(["No way.", "That's horrible.", "Oh my god.", "Are you serious?", "I knew something was off.", "Jesus."])
	if b.tv("neuroticism") > 0.65:
		return pick(["Oh no. Oh no no.", "That's not good.", "We're all going to die out here.", "Great. Just great."])
	return pick(["Huh.", "Seriously?", "No kidding.", "Figures.", "Wow.", "Typical.", "Good to know.", "Thanks for the heads up."])

# ------------------------------------------------------------------ people
static func greeting(b, other: Entity) -> String:
	var nm := call_name(b, other)
	var job := SkyClasses.title_of(other).to_lower() if other.has_c(&"mob") else "person"
	var r = b.memory.rel(other.id)
	var tod := _time_greeting()
	if r.familiarity < 8:
		return fill(pick(LINES["greet_stranger"]), {})
	if r.affinity < -30:
		return fill(pick(LINES["greet_enemy"]), {"name": nm})
	if b._is_superior(other):
		return fill(pick(LINES["greet_boss"]), {"name": nm})
	if r.affinity > 40:
		return fill(pick(LINES["greet_friend"]), {"name": nm, "job": job})
	if randf() < 0.3:
		return "%s, %s." % [tod, nm]
	return fill(pick(LINES["greet_known"]), {"name": nm})

static func _time_greeting() -> String:
	var h := int(Game.station_seconds() / 3600.0) % 24
	if h < 12:
		return "Morning"
	if h < 18:
		return "Afternoon"
	return "Evening"

## What `b` thinks of `other`, as something they'd say out loud. `to` is the listener.
static func opinion(b, other: Entity, to: Entity = null) -> String:
	if other == null:
		return "Who?"
	var nm := first(other)
	if other == b.e:
		return pick(["Me? I'm great. Obviously.", "I try my best.", "Ha, I'd rather not say."])
	if to != null and other == to:
		return opinion_of_you(b, other)
	var r = b.memory.rel(other.id)
	var head: Array = b.learned.headline(other.id)
	var ep: Dictionary = b.memory.strongest_about(other.id)
	if other.c(&"health") and other.c(&"health").dead and b.knowledge.has("body:%d" % other.id):
		return pick(["%s's dead. I still can't believe it.", "%s... didn't make it.", "We lost %s today."]) % nm
	if not head.is_empty():
		var k: String = head[0]
		var v: float = head[1]
		var saw: bool = head[2] == "saw"
		if k == "violent" and v > 0:
			return ("Stay away from %s. I saw them hurt someone." if saw else "People say %s gets violent. I'd be careful.") % nm
		if k == "thief" and v > 0:
			return ("Watch your pockets around %s. I've seen them take stuff." if saw else "I've heard %s has sticky fingers.") % nm
		if k == "liar" and v > 0:
			return "I wouldn't trust a word %s says." % nm
		if k == "helpful" and v > 0:
			return ("%s helped me out earlier. Good sort." if saw else "Everyone says %s is really helpful.") % nm
		if k == "kind" and v > 0:
			return "%s? One of the nicest people on the ship." % nm
		if k == "competent" and v > 0:
			return pick(["%s knows their stuff.", "%s is really good at their job.", "If something's broken, %s is who you want."]) % nm
		if k == "competent" and v < 0:
			return "%s... let's just say I double-check their work." % nm
		if k == "funny" and v > 0:
			return "%s cracks me up." % nm
		if k == "lazy" and v > 0:
			return "Have you ever actually seen %s work? Me neither." % nm
		if k == "brave" and v > 0:
			return "%s ran into a fire for someone today. Brave or crazy, I can't decide." % nm
		if k == "creepy" and v > 0:
			return "%s gives me the creeps, honestly." % nm
	if r.affinity > 50:
		return pick(["%s? One of my favourite people here.", "%s's a good friend. Don't tell them I said that.", "I'd trust %s with my life."]) % nm
	if r.affinity > 20:
		return pick(["%s's alright.", "I like %s.", "%s? Good company."]) % nm
	if r.affinity < -40:
		if not ep.is_empty() and ep["valence"] < 0:
			return "Don't get me started on %s. %s" % [nm, ep["text"]]
		return pick(["Don't get me started on %s.", "Can't stand %s.", "%s and I don't get along."]) % nm
	if r.affinity < -15:
		return pick(["%s gets on my nerves.", "I try to avoid %s.", "%s's... a lot."]) % nm
	if r.familiarity < 10:
		return pick(["Don't really know %s.", "Haven't really talked to %s.", "%s? Couldn't tell you much."]) % nm
	return pick(["%s's fine.", "%s? No complaints.", "%s seems okay. We don't talk much."]) % nm

static func opinion_of_you(b, other: Entity) -> String:
	var r = b.memory.rel(other.id)
	var head: Array = b.learned.headline(other.id)
	if not head.is_empty():
		var k: String = head[0]
		var v: float = head[1]
		if k == "violent" and v > 0.2:
			return "Honestly? You scare me a bit. I've seen what you do to people."
		if k == "thief" and v > 0.2:
			return "I know you've been nicking things. Everyone does."
		if k == "helpful" and v > 0.2:
			return "You're one of the good ones. You helped me."
	if r.affinity > 40:
		return "I like you. You're good people."
	if r.affinity < -30:
		return "You really want to know? Not much."
	if r.familiarity < 10:
		return "I don't know you well enough yet."
	return "You seem alright."

static func memory_line(b, ep: Dictionary, other: Entity) -> String:
	var nm := call_name(b, other)
	match ep["type"]:
		"saved_me": return "%s! I haven't forgotten how you saved me. Thank you." % nm
		"treated_me": return "Hey %s. Thanks for patching me up earlier." % nm
		"hurt_me": return "Stay away from me, %s." % nm if b.tv("bravery") < 0.5 else "You've got some nerve showing your face, %s." % nm
		"stole_from_me": return "I know what you took, %s." % nm
		"arrested_me": return "Oh. It's you. Officer." if b.tv("aggression") < 0.6 else "Come to lock me up again, %s?" % nm
		"friend_hurt_by": return "I know what you did to my friend, %s." % nm
		"hugged_me": return "Hi %s! Nice to see you." % nm
		"good_chat": return "Hey %s, good to see you again." % nm
		"fed_me": return "%s! That meal earlier was great." % nm
		"helped_me": return "%s! Thanks again for the help earlier." % nm
		"insulted_me": return "Oh. %s. Come to insult me again?" % nm
		"gave_me": return "Hey %s! Still got the thing you gave me." % nm
	return greeting(b, other)

static func status_line(b) -> String:
	var n: CNeeds = b.needs
	var h: CHealth = b.health
	if h.health() < 60:
		return pick(["Honestly? I'm hurting. I should see a doctor.", "Not great. Everything hurts.", "I've been better. Much better."])
	if h.body_temp < 285:
		return "C-c-cold. So cold."
	if b.grief > 0.4:
		var dead := Game.get_entity(b.grief_for)
		return "Not great. I lost %s today." % (first(dead) if dead else "a friend")
	if n.nutrition < 25:
		return "Starving. When's the cook making something?"
	if n.energy < 20:
		return "Exhausted. I need a nap."
	if n.stress > 70:
		return pick(["Stressed out of my mind, to be honest.", "Barely holding it together.", "Ask me after the watch."])
	if n.fun < 25:
		return pick(["Bored out of my skull.", "So bored. Please give me something to do."])
	if b.mood > 0.4:
		return pick(["Pretty good, actually!", "Great! Good watch so far.", "Can't complain. Well, I could, but I won't."])
	if b.mood < -0.3:
		return pick(["Rough day.", "Could be better.", "Don't ask."])
	return pick(["Getting by. You?", "Fine, fine. You?", "Same as always. Cold. You?", "Not bad. Yourself?"])

static func doing_line(b) -> String:
	var g: String = b.goal.get("desc", "")
	if b.antag.size() > 0 and g == b.goal.get("desc", "") and b.goal.get("id", "") == "antag":
		return pick(["Just doing some maintenance.", "Checking the pipes. Routine stuff.", "Oh, nothing. Just looking around.", "Work stuff. Boring."])
	if g == "" or g == "hanging around":
		if Jobs.dept(b.job) == "engineering":
			return "Just %s. Nothing's broken, for once." % ("taking a breather" if b.tv("diligence") < 0.4 else "keeping an eye on things")
		return "Just %s." % ("taking a breather" if b.tv("diligence") < 0.4 else "keeping an eye on things")
	return "I'm %s." % g

static func smalltalk(b, other: Entity) -> String:
	var nm := call_name(b, other)
	var opts := [
		"How's your watch going, %s?" % nm,
		"Is it just me or is it colder than yesterday?",
		"I heard the aurora might show up tonight.",
		"This ship creaks like it's alive.",
		"Have you tried the cocoa in the galley? Life-changing.",
		"I swear the wind never stops out there.",
		"What do you think is under all this cloud, %s?" % nm,
		"How long till port, do you reckon?",
		"Did you sleep at all? The bunkroom stove was rattling all night.",
		"Anything interesting happen in your crew?",
	]
	if b.tv("humor") > 0.65:
		opts.append(pick(LINES["joke"]))
	if b.needs.stress > 50:
		opts.append("Honestly, %s, this place is getting to me." % nm)
	if Jobs.dept(b.job) == "engineering":
		opts.append("Boiler's humming nicely today. Knock on wood.")
	if Jobs.dept(b.job) == "medical":
		opts.append("Wear your coat on deck. I'm tired of treating frostbite.")
	if Jobs.dept(b.job) == "security":
		opts.append("Quiet watch. Too quiet. I don't like it.")
	if b.persona and not b.persona.interests.is_empty():
		opts.append(b.persona.interest_line(b.persona.interests[randi() % b.persona.interests.size()]))
	return pick(opts)

static func reply(b, other: Entity, good: bool) -> String:
	var nm := call_name(b, other)
	if good:
		return pick(["Ha, yeah, %s." % nm, "Tell me about it.", "Right? Same here.", "Heh, good one.", "Totally.", "You're not wrong.", "Ha! Yeah."])
	return pick(["...sure, %s." % nm, "Mm.", "If you say so.", "Can we talk later?", "Uh huh.", "Okay."])

static func idle_line(b) -> String:
	var opts := ["*yawns*", "Brr.", "Another day in the sky.", "Where did I leave my gloves...", "*hums quietly*"]
	if b.needs.nutrition < 40:
		opts.append(pick(LINES["hungry_comment"]))
	if b.needs.fun < 30:
		opts.append(pick(LINES["bored_comment"]))
	if b.needs.energy < 30:
		opts.append(pick(LINES["tired_comment"]))
	if b.health.body_temp < 300:
		opts.append(pick(LINES["cold_comment"]))
	if b.persona:
		if b.persona.has_quirk("hums"):
			opts.append("*hums a tune*")
		if b.persona.has_quirk("complainer"):
			opts.append("Of course the %s is broken again." % pick(["stove", "cocoa kettle", "lamp", "hatch"]))
		if b.persona.has_quirk("worrier"):
			opts.append("Does anyone else smell smoke? No? Just me?")
		if b.persona.has_quirk("superstitious"):
			opts.append("*knocks on a wall for luck*")
		if b.persona.catchphrase != "" and randf() < 0.4:
			opts.append(b.persona.catchphrase)
	if b.job == "clown":
		opts.append("Honk.")
	return pick(opts)

static func order_line(b, f: Dictionary, dept: String) -> String:
	var area := Game.map.area_at(f.get("cell", Vector2i.ZERO)).name
	var what: String = b.knowledge.describe(f)
	var who = Defs.DEPARTMENTS[dept]["name"]
	var opts := ["%s, I need you on %s. Now." % [who, what], "%s: priority one is %s. Move." % [who, what], "Attention %s, respond to %s." % [who, what if what.contains(area) else "%s in %s" % [what, area]]]
	return pick(opts)

# ------------------------------------------------------------------ conversation pieces
static func complaint(b) -> String:
	var n: CNeeds = b.needs
	var opts := []
	if b.persona:
		opts.append("You know what I can't stand? %s." % Dialogue.cap(b.persona.peeve))
	if n.energy < 40:
		opts.append("I barely slept. The bunkroom is an icebox.")
	if n.nutrition < 45:
		opts.append("I'm so hungry. The galley better have something.")
	if n.stress > 50:
		opts.append("Everything's going wrong today.")
	var boss := Jobs.head_of(Jobs.dept(b.job))
	if boss != b.job and not Jobs.is_head(b.job):
		opts.append("My boss is on my case again. Nothing's ever good enough.")
	if Jobs.dept(b.job) == "engineering":
		opts.append("Third leak this week. Somebody's sitting on those pipes, I swear.")
	if Jobs.dept(b.job) == "medical":
		opts.append("If one more person comes in with frostbite because they didn't wear a coat...")
	if Jobs.dept(b.job) == "security":
		opts.append("Nobody ever thanks the Watch. Ever.")
	if b.job == "janitor":
		opts.append("Do you know how hard it is to get blood out of deck planking?")
	if b.job == "cook":
		opts.append("Nobody ever says thank you for the food.")
	if b.job == "assistant":
		opts.append("Nobody gives deckhands anything to do. Or any access. Or respect.")
	opts.append_array(["The stove in here is a joke.", "Pay's terrible for how cold it is.", "The ferry food last month was criminal."])
	return pick(opts)

static func sympathy(b, good: bool) -> String:
	if good:
		return pick(["Ugh, tell me about it.", "Yeah, that's rough.", "I hear you.", "Same, honestly.", "That's not fair on you."])
	if b.tv("empathy") < 0.35:
		return pick(["Could be worse.", "Everyone's got problems.", "Welcome to the sky.", "Stop whining."])
	return pick(["Hm.", "I guess.", "Well. Chin up."])

static func argument_open(b, other: Entity) -> String:
	var nm := call_name(b, other)
	var ep: Dictionary = b.memory.strongest_about(other.id)
	if not ep.is_empty() and ep["valence"] < 0:
		match ep["type"]:
			"hurt_me": return "You've got some nerve, %s. After what you did." % nm
			"stole_from_me": return "Give it back, %s. I know you took it." % nm
			"bad_chat": return "Oh great, %s. Here to ruin my day again?" % nm
			"insulted_me": return "Still think I'm an idiot, %s?" % nm
	return pick(["What's your problem, %s?" % nm, "Can you not, %s?" % nm, "You're in my way, %s." % nm, "Do you ever do any actual work, %s?" % nm,
		"You left the hatch open again, didn't you, %s?" % nm, "Was it you who ate my sandwich, %s?" % nm])

static func argument_back(b, other: Entity, escalate: bool) -> String:
	var nm := call_name(b, other)
	if escalate:
		return pick(["Say that again, %s. I dare you." % nm, "Back off, %s!" % nm, "You want to take this outside? Oh wait, you'd fall.", "Keep talking, %s." % nm])
	return pick(["Whatever, %s." % nm, "I don't have time for this.", "Leave me alone, %s." % nm, "Real mature.", "Oh, grow up."])

static func interest_chat(b, id: String, shared: bool) -> String:
	var lbl: String = b.persona.interest_label(id) if b.persona else id
	if shared:
		return pick(["You're into %s too, right? " % lbl, "Talking of %s... " % lbl, ""]) + b.persona.interest_line(id)
	return b.persona.interest_line(id)

static func interest_response(b, id: String, shared: bool, curious: bool) -> String:
	if shared:
		return pick(["Oh, I love that!", "Yes! Finally someone who gets it.", "Ha, same. We should talk about that more.", "That's exactly what I think!"])
	if curious:
		return pick(["Huh, I never thought about that. Tell me more sometime.", "That actually sounds interesting.", "Really? I might have to try that."])
	return pick(["...cool.", "Huh.", "If you say so.", "Mm-hm.", "Not really my thing."])

static func bio_ask(b, other: Entity) -> String:
	return pick(["So where are you from, %s?" % call_name(b, other), "What brought you up here anyway?", "How'd you end up on this ship?", "I don't think I ever asked, what's your story?"])

static func plan_invite(_b, what: String, _other: Entity) -> String:
	match what:
		"lunch": return pick(["Want to grab a bite in the galley?", "Dinner? My treat. Well, the galley's treat.", "Come eat with me, I hate eating alone."])
		"bar": return pick(["Drink at the taproom after this?", "Taproom later? I need a drink.", "Let's hit the taproom."])
		"break": return pick(["Want to take a break with me?", "Coffee break? Well, cocoa break.", "Take five with me?"])
	return "Want to hang out later?"

static func tip(skill: String) -> String:
	return pick(TIPS.get(skill, []))

static func skill_from_text(t: String) -> String:
	for s in TIPS:
		if t.contains(s):
			return s
	for k in TIP_ALIASES:
		if t.contains(k):
			return TIP_ALIASES[k]
	return ""

# ------------------------------------------------------------------ directions
static func directions(from: Vector2i, a: Area) -> String:
	if a == null or a.cells.is_empty():
		return "No idea, sorry."
	var here := Game.map.area_at(from)
	if here == a:
		return "You're standing in it."
	var d: Vector2 = Vector2(a.center - from)
	var dist := d.length()
	var dir := _compass(d)
	var how := ""
	if dist < 12:
		how = "just to the %s" % dir
	elif dist < 35:
		how = "to the %s, not far" % dir
	elif dist < 70:
		how = "a fair walk %s" % dir
	else:
		how = "clear across the ship, %s" % dir
	# name a hall on the way, if there is one between here and there
	var mid: Vector2i = from + Vector2i(d * 0.5)
	var via := Game.map.area_at(mid)
	var via_s := ""
	if via != null and via != a and via != here and via.name.contains("Hall"):
		via_s = ", through %s" % via.name
	return "%s is %s%s." % [a.name, how, via_s]

static func _compass(d: Vector2) -> String:
	var ang := fposmod(rad_to_deg(atan2(d.y, d.x)), 360.0)
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[int(round(ang / 45.0)) % 8]

# ------------------------------------------------------------------ radio
static func banter(b) -> String:
	var opts := []
	var n: CNeeds = b.needs
	if n.fun < 35:
		opts.append_array(["Anyone want to play cards in the taproom?", "Is anyone doing anything fun? Anything at all?", "bored. entertain me, ship"])
	if n.nutrition < 40:
		opts.append_array(["Is there any food in the galley?", "Cook, are you making anything? Asking for my stomach."])
	if b.health.body_temp < 303:
		opts.append_array(["Why is it so cold in %s?" % Game.map.area_at(b.e.cell).name, "Can the engine room turn the heat up? Please?"])
	if b.persona and b.persona.has_quirk("collector"):
		opts.append("Anyone found anything weird lying around? I'll take it off your hands.")
	if b.persona and b.persona.has_interest("aurora"):
		opts.append("Anyone seen the aurora today?")
	if b.persona and b.persona.has_interest("gambling"):
		opts.append("Cards in the taproom later. Bring marks.")
	if b.persona and b.persona.has_interest("cryptids"):
		opts.append("Did anyone else hear knocking under the hull just now?")
	opts.append_array(["Has anyone seen my gloves?", "Who keeps leaving the hatch open?", "Quiet watch. I love it.", "What time do we make port?",
		"Is the cocoa kettle working?", "Shout out to whoever fixed the lights earlier."])
	return pick(opts)

static func dept_status(b) -> String:
	match Jobs.dept(b.job):
		"engineering":
			var rh: Dictionary = b.knowledge.get_fact("reactor_hot")
			if not rh.is_empty():
				return "Boiler's running warm. Keeping an eye on it."
			return pick(["Boiler's steady, power's good.", "Engine room status: all clear.", "Power's up, pipes are holding. For now."])
		"medical":
			return pick(["Sickbay's open. Come see us if you're hurt. Don't wait.", "Sickbay's all quiet. Wear your coats on deck, people.", "Anyone with frostbite, sickbay. Now, not later."])
		"security":
			return pick(["Watch here, all quiet.", "Watch status: nothing to report.", "Doing rounds. Behave, everyone."])
		"science":
			return pick(["Research is ticking along.", "The aetherworks is working on something exciting. Probably.", "Artificers' update: nothing's exploded yet."])
		"service":
			if b.job == "cook":
				return pick(["Galley's open!", "Fresh food in the galley!", "Cook here, anyone want anything in particular?"])
			if b.job == "bartender":
				return pick(["Taproom's open.", "Drinks are flowing in the taproom.", "Come get a drink, everyone. You've earned it."])
			if b.job == "botanist":
				return pick(["The garden is growing nicely.", "Fresh produce going to the kitchen."])
			return "Service is running."
		"supply":
			return pick(["Hold's open for requests.", "Hold here. Need anything ordered?", "Ore's coming in steady."])
		"command":
			return pick(["All hands, keep up the good work.", "Bridge here. Status reports when you get a chance.", "Stay safe out there, crew."])
	return banter(b)

static func morning_announcement(b) -> String:
	var nm: String = b.e.display_name
	var opts := [
		"Good morning, all hands. This is Master %s. Stay warm, stay safe, and keep the hatches shut." % nm.split(" ")[-1],
		"Morning, crew. %s here. Let's have a productive day. And no fires, please." % nm,
		"Attention crew: a new watch begins. Report to your stations. Officers, status reports by mid-morning.",
		"Rise and shine. The wind waits for no one. Neither do I.",
	]
	return pick(opts)
