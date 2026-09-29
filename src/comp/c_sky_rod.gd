class_name CSkyRod extends Component
## Skyfishing: trailing a line off the rail into two thousand feet of nothing, and
## catching things.
##
## It works because the aether is thick enough to swim in if you are built for it, and a
## surprising number of things are. What you catch depends on where you are — the band,
## the biome you are over, the weather and the time of day — so it is a gathering skill
## with a map behind it rather than a slot machine. A skyfisher who knows the sky can
## find a marrow moth shoal on purpose.
##
## You cast into open sky from a tile next to open sky. That means the rail of your own
## ship, the lip of an island, or a very bad decision.

const CAST_TIME := 4.0

var casting := false
var _t := 0.0
var _at := Vector2i.ZERO
var caught := 0

func key() -> StringName:
	return &"skyrod"

func examine(_user: Entity, lines: Array) -> void:
	lines.append("[i]Click open sky within a few tiles to cast.[/i]")
	if caught > 0:
		lines.append("[color=#8aa0b4]%d taken on this line.[/color]" % caught)
	if Game.sky != null:
		lines.append("The aether is [b]%s[/b] here." % _thickness_word())

func _thickness_word() -> String:
	var d := 1.0
	if Game.sky != null and Game.sky.has_method("aether_density_at") and e.holder != null:
		d = Game.sky.aether_density_at(e.holder.root_cell())
	if d < 0.7: return "thin — poor fishing"
	if d < 1.1: return "ordinary"
	if d < 1.5: return "[color=#6ad88a]thick — good fishing[/color]"
	return "[color=#7fd4ff]running like a river[/color]"

# ------------------------------------------------------------------ casting
func use_on_cell(user: Entity, c: Vector2i) -> bool:
	if casting:
		Game.tell(user, "The line is already out.", "warn")
		return true
	if not Game.map.inb(c) or not Defs.is_void_turf(Game.map.get_turf(c)):
		Game.tell(user, "You cast into open sky. That is not open sky.", "warn")
		return true
	var from := user.root_cell()
	if maxi(absi(c.x - from.x), absi(c.y - from.y)) > 5:
		Game.tell(user, "Too far to cast. Get nearer the edge.", "warn")
		return true
	casting = true
	_at = c
	Game.visible_message(from, "%s casts a line out over the edge." % user.display_name.capitalize(), "emote")
	Sfx.play("whoosh", from, 0.4)
	var wait := CAST_TIME * (1.0 - Skills.frac(user, "skyfishing") * 0.35) * Game.rng.randf_range(0.7, 1.9)
	DoAfter.start(user, null, wait, func(ok: bool):
		casting = false
		if not ok:
			Game.tell(user, "The line goes slack.")
			return
		_bite(user))
	return true

func _bite(user: Entity) -> void:
	var skill := Skills.frac(user, "skyfishing")
	var density := 1.0
	if Game.sky != null and Game.sky.has_method("aether_density_at"):
		density = Game.sky.aether_density_at(_at)
	# nothing at all, sometimes, and more often when the aether is thin
	if Game.rng.randf() > clampf(0.42 + skill * 0.4 + (density - 1.0) * 0.3, 0.12, 0.95):
		Game.tell(user, "Nothing. You reel in a length of cold line.")
		Skills.add_xp(user, "skyfishing", 3.0)
		return
	var table := _table_for(_at)
	var pick := _roll(table, skill + SkyBuffs.value(user, "luck", 0.0))
	if pick == "":
		Game.tell(user, "Something took the hook and kept it.")
		return
	# occasionally what bites is not a fish
	if pick.begins_with("!"):
		_hooked_something(user, pick.substr(1))
		return
	var n := Skills.yield_roll(user, "skyfishing", 1.0)
	for _i in n:
		if Proto.has(pick):
			Proto.spawn(pick, user.root_cell())
	caught += n
	var nm: String = String(Proto.P.get(pick, {}).get("name", pick))
	Game.tell(user, "[color=#6ad88a]The line goes tight — %s%s.[/color]" % [nm, "" if n == 1 else " x%d" % n], "good")
	Sfx.play("squeak", user.root_cell(), 0.5)
	Skills.add_xp(user, "skyfishing", 22.0 + float(n) * 4.0)

## Something large has taken the hook and is now aware of you.
func _hooked_something(user: Entity, beast: String) -> void:
	var from := user.root_cell()
	Game.visible_message(from, "[b][color=#ff8a5a]The rod bends double — that is not a fish.[/color][/b]", "bad")
	Sfx.play("swing", from, 0.9)
	if Game.view:
		Game.view.shake(3.0)
	var spot := _open_near(from)
	if spot.x < -9000:
		Game.tell(user, "The line parts with a crack.", "warn")
		return
	var m := SkyMobs.spawn(beast, spot)
	if m != null:
		var ai: CBeastAI = m.c(&"beastai")
		if ai != null:
			ai.target = user
			ai.last_seen = Game.time
			ai.alert = 1.0
		Skills.add_xp(user, "skyfishing", 40.0)
		Bus.chronicle.emit("%s hooked %s off the rail." % [user.display_name, m.display_name], 2)

func _open_near(from: Vector2i) -> Vector2i:
	for r in range(1, 5):
		for d in Defs.DIRS8:
			var c: Vector2i = from + d * r
			if Game.map.inb(c) and Game.map.is_passable(c):
				return c
	return Vector2i(-9999, -9999)

# ------------------------------------------------------------------ what lives where
## [proto or !beast, weight, min skill]
const BASE_TABLE := [
	["sky_minnow", 40, 1], ["cloud_whiting", 26, 1], ["fibre_bundle", 10, 1],
	["salvage_scrap", 8, 1], ["driftmoth", 18, 8], ["glass_eel", 14, 20],
	["aether_ray", 8, 35], ["stormfin", 5, 50], ["!updraft_raptor", 3, 1],
]
const BY_BAND := {
	0: [["deepmouth", 22, 25], ["marrow_oil", 10, 15], ["!drowned_thing", 4, 1]],
	1: [["sky_minnow", 20, 1], ["cloud_whiting", 16, 1]],
	2: [["glass_eel", 18, 18], ["ore_skyglass", 6, 30]],
	3: [["aether_ray", 16, 30], ["skysilk_thread", 8, 40]],
	4: [["stormfin", 18, 50], ["storm_glass", 6, 60], ["!cold_thing", 3, 1]],
}

func _table_for(c: Vector2i) -> Array:
	var out: Array = BASE_TABLE.duplicate(true)
	if Game.sky != null and Game.sky.gen != null:
		var band := Defs.band_index(Game.sky.gen.altitude)
		for row in BY_BAND.get(band, []):
			out.append(row)
		# over a storm, the charged things come up
		if Game.sky.has_method("storm_charge_at") and Game.sky.storm_charge_at(c) > 0.3:
			out.append(["stormfin", 30, 1])
			out.append(["storm_glass", 12, 1])
		if Game.sky.is_night():
			out.append(["driftmoth", 26, 1])
			out.append(["nightgill", 18, 12])
	return out

func _roll(table: Array, skill: float) -> String:
	var lvl := 1 + int(skill * 99.0)
	var pool := []
	var total := 0.0
	for row in table:
		if lvl < int(row[2]):
			continue
		# rarer things get relatively likelier as you improve, which is the whole hook
		var w := float(row[1]) * (1.0 + skill * (2.5 if int(row[2]) > 20 else 0.0))
		pool.append([row[0], w])
		total += w
	if total <= 0.0:
		return ""
	var r := Game.rng.randf() * total
	for row in pool:
		r -= float(row[1])
		if r <= 0.0:
			return String(row[0])
	return String(pool[pool.size() - 1][0])

# ------------------------------------------------------------------ the catch
## Sky fish are food, materials and — in two cases — reagents worth more than the ship.
const FISH := {
	"sky_minnow": {"name": "sky minnow", "value": 9, "nut": 90,
		"desc": "Six inches of silver that swims in air the way a sardine swims in water. \
Best fried whole and nobody has ever eaten just one."},
	"cloud_whiting": {"name": "cloud whiting", "value": 16, "nut": 180,
		"desc": "Flat, pale and it tastes faintly of rain. The staple catch of the Shelf."},
	"driftmoth": {"name": "driftmoth", "value": 24, "nut": 70,
		"desc": "It only rises after dark. The wing dust is worth more than the meat and \
the meat is worth having."},
	"glass_eel": {"name": "glass eel", "value": 42, "nut": 140,
		"desc": "Transparent end to end, so you can watch it decide things. Distillers \
pay for the spine."},
	"nightgill": {"name": "nightgill", "value": 55, "nut": 160,
		"desc": "It hunts what the lanterns attract, which makes fishing off a lit deck \
either clever or extremely stupid."},
	"deepmouth": {"name": "deepmouth", "value": 70, "nut": 260,
		"desc": "Everything below the cloud floor is mostly mouth. This is the small one."},
	"aether_ray": {"name": "aether ray", "value": 130, "nut": 240,
		"desc": "Four feet across and it weighs about as much as a hat. Cut carefully — \
the liver is worth four times the rest of it."},
	"stormfin": {"name": "stormfin", "value": 260, "nut": 200,
		"desc": "It lives inside thunderheads and it is still charged when you land it. \
Handle it with something that is not your hand."},
}

static func install() -> void:
	for id in FISH:
		var f: Dictionary = FISH[id]
		Proto.P[id] = {
			"name": f["name"], "desc": f["desc"], "sheet": "items", "spr": "fish_" + id,
			"comps": {"item": {"w": 2, "force": 4, "throwforce": 5, "cat": "food"},
				"food": {"nutrition": float(f["nut"]), "taste": "cold air"}},
			"tags": {"value": int(f["value"]), "fish": true},
		}
	# the charged one bites back
	Proto.P["stormfin"]["comps"]["light"] = {"kind": "always", "radius": 2.0, "color": "#9ad8ff", "energy": 0.5}
