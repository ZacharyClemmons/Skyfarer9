class_name Radiation extends RefCounted
## A stand-in for tg's radiation_pulse (code/datums/radiation?): the people within range of
## a radioactive event, and not behind a wall from it, may be irradiated. tg rolls each
## target against `threshold` (how much of the pulse gets through what's in the way); being
## irradiated means toxin damage over time until it's treated. Here that's an immediate
## dose of toxin damage and a warning, scaled by how close they were.

static func pulse(c: Vector2i, max_range: float, threshold: float) -> void:
	if max_range <= 0.0 or Game.map == null:
		return
	for m in Game.all_with(&"mob"):
		var h: CHealth = m.c(&"health")
		if h == null or h.dead:
			continue
		var d := Vector2(m.root_cell() - c).length()
		if d > max_range:
			continue
		# walls in the way soak it up (tg: insulation of what's between)
		if Game.lighting and d > 1.5 and not Game.lighting._los(c, m.root_cell()):
			continue
		if randf() > (1.0 - threshold) * (1.0 - d / (max_range + 1.0)):
			continue
		h.tox += 4.0 * (1.0 - d / (max_range + 1.0)) + 1.0
		if m == Game.player:
			Game.tell(m, "Your skin prickles with a strange warmth.", "warn")

## tg visible_hallucination_pulse: everyone who can see `c` within `radius` starts seeing things.
static func hallucination_pulse(c: Vector2i, radius: float, seconds: float) -> void:
	for m in Game.all_with(&"mob"):
		var h: CHealth = m.c(&"health")
		if h == null or h.dead:
			continue
		if Vector2(m.root_cell() - c).length() <= radius + 6.0:
			Hallucinations.adjust(h, seconds)
