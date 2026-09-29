class_name CFood extends Component
## Food and drink. Bites until eaten. Hot drinks warm you up (vital in the arctic).

var nutrition := 20.0
var hydration := 0.0
var bites := 3
var warmth := 0.0
var ingredient := false
var mood := 3.0
var drink := false
var chems := {} # reagents per whole item (tg drink containers: a bottle of vodka is 100u)

func key() -> StringName:
	return &"food"

func setup(p: Dictionary) -> CFood:
	nutrition = p.get("nutrition", nutrition)
	hydration = p.get("hydration", hydration)
	bites = p.get("bites", bites)
	warmth = p.get("warmth", warmth)
	ingredient = p.get("ingredient", ingredient)
	mood = p.get("mood", mood)
	drink = p.get("drink", drink)
	chems = p.get("chems", {}).duplicate()
	return self

func consume(user: Entity) -> void:
	var n: CNeeds = user.c(&"needs")
	var h: CHealth = user.c(&"health")
	if n:
		n.nutrition = minf(100.0, n.nutrition + nutrition / bites)
		n.hydration = minf(100.0, n.hydration + hydration / bites)
		n.fun = minf(100.0, n.fun + mood)
		n.stress = maxf(0.0, n.stress - mood * 0.5)
	if h and warmth > 0:
		h.body_temp = minf(Defs.BODYTEMP_NORMAL + 0.5, h.body_temp + warmth)
		if n:
			n.comfort = minf(100.0, n.comfort + warmth * 3.0)
	if not chems.is_empty():
		Chem.affect_mob(chems, user, 1.0 / maxf(1.0, bites))
		for k in chems.keys():
			chems[k] = chems[k] * (1.0 - 1.0 / maxf(1.0, bites))
	_taste(user, 1.0 / maxf(1.0, bites))
	bites -= 1
	Sfx.play("drink" if drink else "eat", user.cell)
	if bites <= 0:
		Game.tell(user, "You finish %s." % e.the())
		if e.proto == "food_banana":
			var holder := e.holder
			var peel := Proto.spawn("banana_peel", user.cell)
			if holder and holder.c(&"inv"):
				holder.c(&"inv").remove_ref(e)
				holder.c(&"inv").put_in_hands(peel)
		e.destroy()
	else:
		Game.tell(user, "You take a %s of %s." % ["sip" if drink else "bite", e.the()])

func attack_self(user: Entity) -> bool:
	if ingredient and nutrition <= 0:
		return false
	consume(user)
	return true

func examine(_user: Entity, lines: Array) -> void:
	if warmth > 0:
		lines.append("[color=#ffb87a]It's steaming hot.[/color]")

func ai_tags(out: Dictionary) -> void:
	if drink:
		out["drink"] = true
	elif not ingredient or nutrition > 5:
		out["food"] = true
	if ingredient:
		out["ingredient"] = true
	if warmth > 0:
		out["hot_food"] = true

## tg edible/checkLiked (and drinks' quality moodlets), at most every 5 s: how good it
## tastes to you. The food's own quality is its `mood` (0-10 here, tg recipe complexity
## 0-7); your favourite food or drink is +2, meat -4 for vegetarians, deviant tastes flip it.
const MEATY := ["food_burger", "food_sandwich", "food_meat", "food_meatpie", "food_steak"]
var _last_taste := -99.0

func _taste(user: Entity, fraction: float) -> void:
	if Game.time - _last_taste < 5.0 or not user.has_c(&"mood"):
		return
	_last_taste = Game.time
	var h: CHealth = user.c(&"health")
	var base := clampi(roundi(mood / 2.0), 0, 7)
	var fav := false
	var b: CBrain = user.c(&"brain")
	if b and b.persona:
		var likes: String = b.persona.fav_drink if drink else b.persona.fav_food
		for w in e.display_name.to_lower().split(" "):
			if w.length() >= 4 and likes.contains(w.trim_suffix("s")):
				fav = true
	var q := Quirks.food_quality(user, base, e.proto in MEATY or e.proto.contains("meat"), fav)
	if q <= -8:
		Game.tell(user, "What the hell was that thing?!", "bad")
		if h: h.disgust = minf(150.0, h.disgust + 25.0 + 30.0 * fraction)
		CMood.event(user, "toxic_food", "disgusting_food")
	elif q < 0:
		Game.tell(user, "That didn't taste very good...", "warn")
		if h: h.disgust = minf(150.0, h.disgust + 11.0 + 15.0 * fraction)
		CMood.event(user, "gross_food", "gross_food")
	elif q == 0:
		return # meh
	elif drink:
		# tg drinks: quality_drink by the drink's quality
		CMood.event(user, "quality_drink", ["quality_nice", "quality_nice", "quality_good", "quality_verygood", "quality_fantastic"][clampi(q - 1, 0, 4)])
		if fav:
			CMood.event(user, "fav_food", "favorite_food")
	else:
		CMood.event(user, "quality_food", "food", q)
		if h: h.disgust = maxf(0.0, h.disgust - (5.0 + 2.0 * q * fraction))
		Game.tell(user, "That's %s %s meal." % ["an" if CMood.FOOD_QUALITY[q][0] in "aeiou" else "a", CMood.FOOD_QUALITY[q]])
