class_name Thoughts extends RefCounted
## The inner monologue: a first-person reason for whatever an NPC just decided to do,
## coloured by their mood and personality. Shown over their heads with F4 and in the
## mind inspector, and sometimes said out loud when someone asks what they're doing.

static func of(b: CBrain, g: Dictionary) -> String:
	var id: String = g.get("id", "")
	var desc: String = g.get("desc", "")
	var anxious := b.tv("neuroticism") > 0.65
	var lazy := b.tv("diligence") < 0.3
	var brave := b.tv("bravery") > 0.65
	match id:
		"stop_drop_roll": return "I'M ON FIRE."
		"breathe": return "Can't... breathe..."
		"get_warm": return Dialogue.pick(["So cold. I need to warm up.", "I can't feel my fingers."])
		"flee_fire": return "Fire! Get away from it!"
		"extinguish": return "That fire won't put itself out." if brave else "Someone has to deal with that fire. I guess it's me."
		"escape_gas": return "The air's wrong in here. Out, out."
		"fight_back": return "You want a fight? Fine."
		"flee_attacker": return "Run. Just run."
		"panic": return "We're all going to die out here."
		"go_inside": return "What am I doing out here? Inside, now."
		"evacuate", "wait_departures": return "The ferry's here. I'm not missing it."
		"help_burning": return "They're burning! Help them!"
		"rescue": return "Someone's down. I have to help." if not anxious else "Oh god, someone's down. Okay. Okay. I can do this."
		"report": return "People need to know about this."
		"eat": return Dialogue.pick(["I'm starving.", "Food. Now.", "When did I last eat?"])
		"drink": return "I'm parched."
		"sleep": return "I can barely keep my eyes open."
		"cocoa": return "Something hot would be nice."
		"socialize": return Dialogue.pick(["I could use some company.", "Wonder what everyone's up to.", "Haven't talked to anyone in ages."])
		"decompress": return "I need a minute to myself."
		"snap": return "I've had it with them."
		"revenge": return "They're going to pay for what they did."
		"follow": return "Better keep up."
		"investigate": return "What was that noise?" if not anxious else "What was that? I shouldn't look. I'm going to look."
		"idle": return Dialogue.pick(["Nothing to do.", "Quiet. Too quiet?", "Just keeping an eye on things."]) if not lazy else "Nobody's watching. Good."
		"go_to_work": return "Better get back to work." if not lazy else "Ugh. Work."
		"treat": return "My patient needs me."
		"cure": return "That looks contagious. Better treat it."
		"move_body": return "Nobody should have to see that. Morgue."
		"brew": return "Sickbay's going to need more supplies."
		"restock": return "I'm low on supplies."
		"fix_leak": return "That leak won't weld itself."
		"fix_breach": return "Breach. Seal it before the room freezes."
		"fix_cable": return "Burnt cable. Easy fix."
		"power": return "Somebody's sitting in the dark. Let's fix that."
		"fix_machine": return "Broken again. Of course."
		"reactor": return "The reactor. Don't panic. Don't panic."
		"warrant", "arrest": return "Nobody breaks the law on my watch." if b.tv("lawfulness") > 0.6 else "Time to earn my pay."
		"patrol": return Dialogue.pick(["Let's see who's up to no good.", "Rounds.", "Just walking. Watching."])
		"experiment": return "Let's see what happens if..."
		"cook": return "People need feeding."
		"garden": return "The plants need me."
		"clean": return "Who made this mess?" if b.persona.has_quirk("neat_freak") or b.job == "janitor" else "Might as well clean that."
		"mine": return "Ore won't dig itself."
		"antag": return Dialogue.pick(["Nobody's watching. Now's my chance.", "Stick to the plan.", "Stay calm. Look normal."])
		"lunch": return "Lunch. Finally."
		"leisure", "take_break": return Dialogue.pick(["I need a break.", "All work and no play.", "Something fun. Anything."])
		"serve": return "Someone's waiting on me."
		"errand": return "I said I'd help."
		"chat": return ""
	if desc != "":
		return "I should be %s." % desc if not lazy else "I suppose I should be %s." % desc
	return ""
