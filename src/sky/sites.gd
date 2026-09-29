class_name Sites extends RefCounted
## Places somebody else got to first.
##
## Every island rolls for a site or two from its biome's table. There are twenty-odd site
## names but only four builders, because a peat-cutters' camp and a bone-harvesters' camp
## are the same structure with different props and a different story — and keeping them
## one builder means every camp benefits when the camp code gets better.
##
##   camp    tents, a fire, crates, and whoever is still there
##   ruin    a walled building, part collapsed, with loot inside and something living in it
##   circle  standing stones, shrines, arrays: scenery with a centre and a meaning
##   wreck   a derelict hull from ShipPlan.WRECKS, beached and strippable

## id -> {kind, name, props, loot, guard, size, desc}
static var SITE := {
	# ---- camps
	"shepherd_camp": {"kind": "camp", "name": "shepherd's camp", "props": ["bush_berry", "boulder"],
		"loot": 2, "guard": 0, "size": 5,
		"desc": "Somebody keeps animals up here. The fire is cold but the wood is dry."},
	"poacher_camp": {"kind": "camp", "name": "poachers' camp", "props": ["thorn_tree", "vine_curtain"],
		"loot": 3, "guard": 2, "size": 5,
		"desc": "Skins pegged out to dry, and a lot of them."},
	"peat_cutters": {"kind": "camp", "name": "peat cutters' camp", "props": ["reed_bed", "bog_stump"],
		"loot": 2, "guard": 1, "size": 5,
		"desc": "Cut turf stacked in walls to dry. The cutting has stopped part way through."},
	"frozen_camp": {"kind": "camp", "name": "frozen camp", "props": ["snow_drift", "frozen_carcass"],
		"loot": 3, "guard": 0, "size": 5,
		"desc": "Tents still pitched, still pegged, and the drift has come halfway up the door."},
	"bone_harvesters": {"kind": "camp", "name": "harvesters' camp", "props": ["bone_pile", "rib_arch"],
		"loot": 3, "guard": 2, "size": 6,
		"desc": "Saws, tackle, and a lot of marrow drying on racks."},
	"caravan_wreck": {"kind": "camp", "name": "scattered caravan", "props": ["dune_bone", "sand_arch"],
		"loot": 4, "guard": 1, "size": 6,
		"desc": "Whatever they were carrying is spread over sixty feet of sand."},
	# ---- ruins
	"overgrown_ruin": {"kind": "ruin", "name": "overgrown hall", "props": ["vine_curtain", "fern_giant"],
		"loot": 3, "guard": 2, "size": 7,
		"desc": "Stone walls under a century of green. Somebody lived well here, once."},
	"buried_town": {"kind": "ruin", "name": "buried street", "props": ["ash_pillar", "dune_bone"],
		"loot": 4, "guard": 2, "size": 9,
		"desc": "Two rows of houses with their upper floors above the drift and nothing below."},
	"forge_ruin": {"kind": "ruin", "name": "ruined forge", "props": ["cinder_spire", "obsidian_shard"],
		"loot": 4, "guard": 2, "size": 7,
		"desc": "The chimneys are still standing. The heat never entirely left the stone."},
	"ossuary": {"kind": "ruin", "name": "ossuary", "props": ["bone_pile", "skull_huge"],
		"loot": 4, "guard": 3, "size": 7,
		"desc": "Bone stacked in courses like brick, and the courses are load-bearing."},
	"watchtower": {"kind": "ruin", "name": "watchtower", "props": ["wind_sculpt", "boulder"],
		"loot": 3, "guard": 1, "size": 5,
		"desc": "Somebody thought this crag was worth watching from. They may have been right."},
	"ice_vault": {"kind": "ruin", "name": "ice vault", "props": ["ice_spire", "snow_drift"],
		"loot": 5, "guard": 3, "size": 6,
		"desc": "A door in the rock, sealed with a plug of clear ice, and light on the other side."},
	"salt_works": {"kind": "ruin", "name": "salt works", "props": ["salt_pillar", "brine_pool"],
		"loot": 3, "guard": 1, "size": 7,
		"desc": "Evaporation pans in ranks, and a boiling house at the end of them."},
	"glass_kiln": {"kind": "ruin", "name": "glass kiln", "props": ["glass_shard", "glass_tree"],
		"loot": 4, "guard": 1, "size": 6,
		"desc": "A kiln big enough to walk into, and racks of what came out of it."},
	"plasma_drill": {"kind": "ruin", "name": "abandoned drill", "props": ["fumarole", "obsidian_shard"],
		"loot": 4, "guard": 2, "size": 7,
		"desc": "A drill head sunk into the rock and left running until it stopped."},
	"aether_mine": {"kind": "ruin", "name": "aetherite working", "props": ["boulder", "cliff_moss"],
		"loot": 5, "guard": 2, "size": 8,
		"desc": "Galleries cut along the vein. The spoil is still worth picking over."},
	"sunken_barge": {"kind": "wreck", "name": "sunken barge", "hull": "wreck_cutter",
		"loot": 4, "guard": 1, "size": 0,
		"desc": "Down by the bow in six inches of brine."},
	# ---- circles
	"standing_stones": {"kind": "circle", "name": "standing stones", "props": ["boulder", "wind_sculpt"],
		"loot": 1, "guard": 0, "size": 5,
		"desc": "Set upright by hand, a long time ago, by people who had a reason."},
	"shrine": {"kind": "circle", "name": "wayside shrine", "props": ["boulder", "wildflowers"],
		"loot": 2, "guard": 0, "size": 3,
		"desc": "Offerings left by crews who made it this far and wanted to keep making it."},
	"prism_array": {"kind": "circle", "name": "prism array", "props": ["prism_shard", "glass_tree"],
		"loot": 3, "guard": 2, "size": 6,
		"desc": "Shards set in a ring, each one angled at the next. It is still doing whatever it does."},
	"spore_heart": {"kind": "circle", "name": "spore heart", "props": ["cap_tower", "puffball"],
		"loot": 2, "guard": 3, "size": 6,
		"desc": "The centre of the bloom. Everything else on this island grew outward from here."},
	"hive_tree": {"kind": "circle", "name": "hive tree", "props": ["thorn_tree", "spore_pod"],
		"loot": 3, "guard": 3, "size": 5,
		"desc": "One trunk, hollowed and rebuilt from the inside by something with a lot of legs."},
	# ---- the new rings
	"wayhouse": {"kind": "ruin", "name": "wayhouse", "props": ["boulder", "wildflowers", "moss_bed"],
		"loot": 2, "guard": 0, "size": 6,
		"desc": "A stone house kept unlocked for anybody who needs it, with a rule about leaving \
firewood written on the door in four hands."},
	"chalk_figures": {"kind": "circle", "name": "chalk figures", "props": ["chalk_figure", "boulder", "wind_sculpt"],
		"loot": 2, "guard": 1, "size": 9,
		"desc": "Eleven of them, cut down to the white, all facing the same way. Nobody has ever \
been able to say what they are facing."},
	"reef_shrine": {"kind": "circle", "name": "reef shrine", "props": ["reef_fan", "tide_bell", "aether_polyp"],
		"loot": 3, "guard": 2, "size": 6,
		"desc": "Offerings wound into the coral by people who go out further than you do."},
	"breakers_yard": {"kind": "camp", "name": "breakers' yard", "props": ["rust_spar", "hull_plate_heap"],
		"loot": 5, "guard": 2, "size": 8,
		"desc": "Somebody was cutting ships up here for a living. The half-cut hull is still on \
the slip and there is nobody to ask about it."},
	"mirror_hall": {"kind": "ruin", "name": "hall of mirrors", "props": ["mirror_pool", "prism_shard"],
		"loot": 5, "guard": 3, "size": 8,
		"desc": "Polished walls, angled inward, and a great many of you looking back. They are \
not all doing the same thing."},
	"lightning_farm": {"kind": "circle", "name": "lightning farm", "props": ["storm_spire", "fulgurite", "lightning_tree"],
		"loot": 5, "guard": 3, "size": 8,
		"desc": "A ring of iron spires sunk into the rock to catch strikes, and a cable run back \
to something that is still charging."},
	"sunless_vault": {"kind": "ruin", "name": "sunless vault", "props": ["gloom_stalk", "pale_fungus", "bone_pile"],
		"loot": 6, "guard": 4, "size": 7,
		"desc": "A door, a stair, and a long argument with yourself about whether to go down it."},
	"aether_shoal": {"kind": "circle", "name": "aether shoal", "props": ["aether_polyp", "tide_bell"],
		"loot": 3, "guard": 1, "size": 7,
		"desc": "The field runs thick enough here to see. Fish it, tap it, or simply stand in it \
and feel better than you did."},
	# ---- wrecks
	"wreck_small": {"kind": "wreck", "name": "beached skiff", "hull": "wreck_skiff",
		"loot": 3, "guard": 0, "size": 0,
		"desc": "She came down on her side and nobody came back for her."},
	"wreck_burnt": {"kind": "wreck", "name": "burnt-out hull", "hull": "wreck_skiff",
		"loot": 3, "guard": 1, "size": 0,
		"desc": "Fire got the deck before the ground got the hull."},
	"wreck_frozen": {"kind": "wreck", "name": "frozen wreck", "hull": "wreck_cutter",
		"loot": 4, "guard": 1, "size": 0,
		"desc": "Rimed over to the gunwales. The crew are still aboard, and still where they sat."},
}

# ------------------------------------------------------------------ entry
static func populate(gen: SkyGen, isl: Dictionary) -> void:
	var b: Dictionary = isl["b"]
	var table: Array = b.get("sites", [])
	if table.is_empty() or isl["surface"].size() < 40:
		return
	var tier: int = int(isl.get("tier", 1))
	var n := 1
	if isl["surface"].size() > 240 and gen.rng.randf() < 0.65:
		n = 2
	# the further out an island is, the more there is on it worth walking to
	if tier >= 2 and isl["surface"].size() > 400:
		n += 1
	if tier >= 4 and isl["surface"].size() > 300:
		n += 1
	if isl.get("home", false):
		n = 1 # the home island stays legible
	var used := []
	var placed := 0
	# a site can fail to fit (no flat ground big enough), so roll again rather than leaving
	# a large island bare
	for _try in 8:
		if placed >= n:
			break
		var id = Biomes.weighted(table, gen.rng)
		if id == null or id in used or not SITE.has(id):
			continue
		used.append(id)
		if build(gen, isl, str(id)):
			isl["sites"].append(str(id))
			placed += 1

static func build(gen: SkyGen, isl: Dictionary, id: String) -> bool:
	var s: Dictionary = SITE[id]
	match s["kind"]:
		"camp": return _camp(gen, isl, s)
		"ruin": return _ruin(gen, isl, s)
		"circle": return _circle(gen, isl, s)
		"wreck": return _wreck(gen, isl, s)
	return false

# ------------------------------------------------------------------ builders
## A camp: a cleared patch, a fire ring, tents (represented by crates and bedrolls until
## the art exists), some scattered scenery, and whatever is still living here.
static func _camp(gen: SkyGen, isl: Dictionary, s: Dictionary) -> bool:
	var size: int = int(s["size"])
	var o := gen.find_flat(isl, size, size)
	if o.x < 0:
		return false
	var area := _area(gen, isl, s, o, size, size, false)
	var centre := o + Vector2i(size / 2, size / 2)
	_spawn(gen, "campfire", centre)
	for _i in gen.rng.randi_range(2, 4):
		var c := _free(gen, o, size, size)
		if c.x >= 0:
			_spawn(gen, ["crate", "locker", "bed"][gen.rng.randi() % 3], c)
	for _i in int(s["loot"]):
		var c2 := _free(gen, o, size, size)
		if c2.x < 0:
			continue
		var box := _spawn(gen, "crate", c2)
		if box != null:
			Salvage.fill(box, gen.rng, gen.rng.randi_range(1, 3) + _bonus(isl), _luck(isl))
	_scatter(gen, s, o, size, size)
	_guards(gen, isl, s, o, size, size)
	return true

## A ruin: a rectangle of wall with a floor inside, a doorway, and holes knocked in it.
static func _ruin(gen: SkyGen, isl: Dictionary, s: Dictionary) -> bool:
	var w: int = int(s["size"])
	var h: int = maxi(4, w - gen.rng.randi_range(0, 2))
	var o := gen.find_flat(isl, w, h)
	if o.x < 0:
		return false
	var map := gen.map
	var area := _area(gen, isl, s, o, w, h, true)
	var floor_t: int = [Defs.T_PLATING, Defs.T_STEEL, Defs.T_DARK, Defs.T_WOOD][gen.rng.randi() % 4]
	for y in range(o.y, o.y + h):
		for x in range(o.x, o.x + w):
			var c := Vector2i(x, y)
			var i := map.idx(c)
			var edge: bool = x == o.x or y == o.y or x == o.x + w - 1 or y == o.y + h - 1
			if edge:
				# a ruin is a ruin: leave gaps where the wall has come down
				if gen.rng.randf() < 0.22:
					map.turf[i] = floor_t
					map.turf_hp[i] = 100.0
					continue
				map.turf[i] = Defs.T_WALL
				map.turf_hp[i] = float(Defs.TURFS[Defs.T_WALL]["hp"])
			else:
				map.turf[i] = floor_t
				map.turf_hp[i] = 100.0
			map.area[i] = area.id
			area.cells.append(c)
	# a way in
	var door := Vector2i(o.x + w / 2, o.y + h - 1)
	map.turf[map.idx(door)] = floor_t
	if gen.rng.randf() < 0.5:
		_spawn(gen, "airlock", door)
	area.center = o + Vector2i(w / 2, h / 2)
	for _i in int(s["loot"]):
		var c3 := _free(gen, o + Vector2i.ONE, w - 2, h - 2)
		if c3.x < 0:
			continue
		var box := _spawn(gen, ["crate", "locker"][gen.rng.randi() % 2], c3)
		if box != null:
			Salvage.fill(box, gen.rng, gen.rng.randi_range(1, 3) + _bonus(isl), 0.25 + _luck(isl))
	_scatter(gen, s, o, w, h)
	_guards(gen, isl, s, o, w, h)
	return true

## A circle: scenery arranged with a centre, and something in the middle of it.
static func _circle(gen: SkyGen, isl: Dictionary, s: Dictionary) -> bool:
	var r: int = int(s["size"]) / 2 + 1
	var centre := gen.free_surface(isl, r + 1)
	if centre.x < 0:
		return false
	var props: Array = s["props"]
	var n := 6 + gen.rng.randi() % 4
	for k in n:
		var ang := TAU * float(k) / float(n)
		var c := centre + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
		if gen._clear_for_prop(c):
			_spawn(gen, str(props[gen.rng.randi() % props.size()]), c)
	if gen._clear_for_prop(centre):
		var box := _spawn(gen, "crate", centre)
		if box != null:
			Salvage.fill(box, gen.rng, int(s["loot"]) + _bonus(isl), 0.4 + _luck(isl))
	_area(gen, isl, s, centre - Vector2i(r, r), r * 2 + 1, r * 2 + 1, false)
	_guards(gen, isl, s, centre - Vector2i(r, r), r * 2 + 1, r * 2 + 1)
	return true

## A wreck: a derelict hull from ShipPlan, laid on the ground and left there.
static func _wreck(gen: SkyGen, isl: Dictionary, s: Dictionary) -> bool:
	if Game.fleet == null:
		return false
	var hull: String = s["hull"]
	var ex := ShipPlan.extent(ShipPlan.get_hull(hull)["plan"])
	var o := gen.find_flat(isl, ex.x, ex.y)
	if o.x < 0:
		return false
	var dir: int = [Defs.DIR_E, Defs.DIR_S, Defs.DIR_W, Defs.DIR_N][gen.rng.randi() % 4]
	var sh: Airship = Game.fleet.add_ship(hull, o + Vector2i(0, ShipPlan.get_hull(hull)["keel"]), dir, str(s["name"]))
	if sh == null:
		return false
	sh.derelict = true
	sh.throttle = 0.0
	# the lift cells are flat, which is why she is on the ground
	for l in sh.lift_cells:
		var lc = l.c(&"liftcell")
		if lc != null:
			lc.charge = gen.rng.randf_range(0.0, 0.18)
			lc.integrity = gen.rng.randf_range(0.2, 0.7)
	for bnk in sh.bunkers:
		var fb = bnk.c(&"fuelbunker")
		if fb != null:
			fb.amount = gen.rng.randf_range(0.0, 18.0)
	_guards(gen, isl, s, o, ex.x, ex.y)
	return true

# ------------------------------------------------------------------ helpers
## How much better a site's contents are for being this far out. This is the whole
## argument for flying to the Rim, and it is deliberately a single readable number.
static func _luck(isl: Dictionary) -> float:
	return Biomes.ring_loot(int(isl.get("tier", 0)))

static func _bonus(isl: Dictionary) -> int:
	return int(isl.get("tier", 0)) / 2

static func _area(gen: SkyGen, isl: Dictionary, s: Dictionary, o: Vector2i, w: int, h: int, indoor: bool) -> Area:
	var a := gen.map.new_area("%s, %s" % [str(s["name"]).capitalize(), isl["name"]], "civilian")
	a.outdoor = not indoor
	a.room_kind = "site"
	a.center = o + Vector2i(w / 2, h / 2)
	if not indoor:
		for y in range(o.y, o.y + h):
			for x in range(o.x, o.x + w):
				var c := Vector2i(x, y)
				if gen.is_land(c):
					gen.map.area[gen.map.idx(c)] = a.id
					a.cells.append(c)
	return a

static func _free(gen: SkyGen, o: Vector2i, w: int, h: int) -> Vector2i:
	for _try in 40:
		var c := o + Vector2i(gen.rng.randi() % maxi(1, w), gen.rng.randi() % maxi(1, h))
		if gen._clear_for_prop(c) and gen.map.is_passable(c):
			return c
	return Vector2i(-1, -1)

static func _scatter(gen: SkyGen, s: Dictionary, o: Vector2i, w: int, h: int) -> void:
	var props: Array = s.get("props", [])
	if props.is_empty():
		return
	for _i in gen.rng.randi_range(2, 5):
		var c := o + Vector2i(gen.rng.randi_range(-2, w + 1), gen.rng.randi_range(-2, h + 1))
		if gen._clear_for_prop(c):
			_spawn(gen, str(props[gen.rng.randi() % props.size()]), c)

## Whatever has made this place its own. Recorded as a spawn so the boot sequence decides
## when it wakes up, same as the rest of the island's fauna.
static func _guards(gen: SkyGen, isl: Dictionary, s: Dictionary, o: Vector2i, w: int, h: int) -> void:
	var n: int = int(s.get("guard", 0))
	if n <= 0:
		return
	var b: Dictionary = isl["b"]
	for _i in n:
		var c := _free(gen, o, w, h)
		if c.x < 0:
			continue
		var mob = Biomes.weighted(b["fauna"], gen.rng)
		if mob == null:
			continue
		# a site's guards are a cut above the island's ordinary wildlife: something has
		# chosen to live here, which means it can hold the place
		var tier: int = int(isl.get("tier", 0))
		gen.mob_spawns.append({"cell": c, "mob": mob, "island": isl["id"], "night": false,
			"tier": tier, "power": Biomes.ring_power(tier) * 1.2})

static func _spawn(gen: SkyGen, proto: String, c: Vector2i) -> Entity:
	if not Proto.has(proto):
		return null
	return Proto.spawn(proto, c)
