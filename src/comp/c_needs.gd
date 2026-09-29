class_name CNeeds extends Component
## Physiological & psychological needs, 0 (desperate) .. 100 (satisfied).
## Stress is inverted: 0 calm .. 100 breaking point. Rates are per real second.

var nutrition := 85.0
var hydration := 85.0
var energy := 90.0
var social := 70.0
var comfort := 80.0 # warmth, being indoors, not injured
var fun := 70.0
var stress := 10.0

## A full belly lasts about 40 minutes of a one-hour shift, a drink about 35: people eat and drink
## once or twice a shift, which a working kitchen, cargo and the taps can keep up with.
const RATES := {"nutrition": 100.0 / 2400.0, "hydration": 100.0 / 2100.0, "energy": 100.0 / 3600.0, "social": 100.0 / 1400.0, "fun": 100.0 / 1800.0}

func key() -> StringName:
	return &"needs"

func tick(dt: float, mult := 1.0) -> void:
	if not Traits.has(e, "nohunger"):
		nutrition = maxf(0.0, nutrition - RATES["nutrition"] * dt * mult)
	hydration = maxf(0.0, hydration - RATES["hydration"] * dt * mult)
	var h = e.c(&"health")
	if h and h.sleeping:
		energy = minf(100.0, energy + dt * 100.0 / 300.0)
		if energy >= 99.0 and e.c(&"brain") == null:
			h.wake()
	else:
		energy = maxf(0.0, energy - RATES["energy"] * dt * mult)
	social = maxf(0.0, social - RATES["social"] * dt)
	fun = maxf(0.0, fun - RATES["fun"] * dt)
	# stress drifts toward a baseline set by unmet needs & discomfort
	var target := 8.0
	if nutrition < 25: target += 15
	if hydration < 25: target += 15
	if energy < 20: target += 12
	if comfort < 40: target += (40 - comfort) * 0.6
	if social < 20: target += 8
	if h and h.pain > 20: target += h.pain * 0.3
	stress = move_toward(stress, target, dt * 0.35)
	if h:
		h.pain = maxf(0.0, h.pain - dt * 1.5)

func add_stress(v: float) -> void:
	stress = clampf(stress + v, 0.0, 100.0)

func mood() -> float:
	## -1 miserable .. 1 content
	var avg := (nutrition + hydration + energy + social + comfort + fun) / 6.0
	return clampf((avg - 50.0) / 50.0 - stress / 100.0, -1.0, 1.0)

func alerts() -> Array:
	var out := []
	if nutrition < 10: out.append("starving")
	elif nutrition < 25: out.append("hungry")
	if hydration < 25: out.append("thirsty")
	if energy < 15: out.append("tired")
	return out

func examine(_user: Entity, lines: Array) -> void:
	if nutrition < 15:
		lines.append("They look gaunt and hungry.")
	if energy < 15:
		lines.append("They look exhausted.")
