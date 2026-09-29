class_name CBotany extends Component
## Botany kit and machines, ported from tgstation (code/modules/hydroponics/
## hydroponics_items.dm, seed_extractor.dm, grafts.dm).
##
##   seed        a seed packet: it carries a whole seed (stats, traits, chemicals)
##   graft       a cutting taken with the secateurs; it carries one trait
##   analyzer    plant analyzer: reads a tray, a seed or a fruit
##   cultivator  uproots the weeds in a tray
##   hatchet     chops down a plant (and makes a fine weapon)
##   spade       digs out everything in a tray
##   secateurs   takes a graft off a harvestable plant
##   shears      gene shears: cut one trait out of the plant
##   extractor   the seed extractor machine: produce in, seed packets out
##   watertank   a water tank you refill buckets and watering cans from

var kind := "seed"
var seed: Dictionary = {}
var graft_gene := ""
var water_stock := 1000.0
var piles: Array = [] # extractor: seeds waiting to be dispensed

func key() -> StringName:
	return &"botany"

func setup(p: Dictionary) -> CBotany:
	kind = p.get("kind", kind)
	water_stock = p.get("water", water_stock)
	if p.has("species"):
		set_seed(Plants.new_seed(p["species"]))
	elif kind == "seed" and p.get("random", false):
		set_seed(Plants.new_seed(Plants.STARTER_SEEDS[Game.rng.randi() % Plants.STARTER_SEEDS.size()]))
	return self

func set_seed(new_seed: Dictionary) -> void:
	seed = new_seed
	if kind == "seed" and not seed.is_empty():
		e.display_name = "%s seed packet" % String(seed.get("name", "plant")).to_lower()

func set_graft(gene: String, from_name: String) -> void:
	graft_gene = gene
	e.display_name = "%s graft (%s)" % [from_name.to_lower(), Plants.GENES.get(gene, {}).get("name", gene)]

# ---------------------------------------------------------------- on a tray
## Called by CHydro when this item is used on a tray. Returns true if it did something.
func use_on_tray(user: Entity, tray: CHydro) -> bool:
	match kind:
		"seed":
			if not tray.seed.is_empty():
				Game.tell(user, "%s already has a plant growing in it!" % tray.e.the(), "warn")
				return true
			tray.plant(Plants.copy(seed))
			Game.tell(user, "You plant %s." % e.the())
			Skills.add_xp(user, "botany", 4.0)
			e.destroy()
			return true
		"graft":
			if tray.seed.is_empty():
				Game.tell(user, "The tray is empty.", "warn")
				return true
			if Plants.add_gene(tray.seed, graft_gene):
				Game.tell(user, "You carefully integrate the graft onto %s, granting it %s." % [
					tray.seed.get("name", "the plant"), Plants.GENES.get(graft_gene, {}).get("name", graft_gene)])
				Skills.add_xp(user, "botany", 12.0)
			else:
				Game.tell(user, "The plant rejects the trait from %s." % e.the(), "warn")
			e.destroy()
			return true
		"analyzer":
			Game.tell(user, Botany.analyze(tray.seed, tray))
			return true
		"cultivator":
			if tray.weeds <= 0.0:
				Game.tell(user, "This plot is completely devoid of weeds! It doesn't need uprooting.", "warn")
				return true
			DoAfter.start(user, tray.e, 2.0, func(ok):
				if ok:
					tray.adjust_weeds(-tray.weeds)
					Game.visible_message(tray.e.cell, "%s uproots the weeds." % user.display_name)
					Skills.add_xp(user, "botany", 3.0))
			return true
		"hatchet", "spade":
			if tray.seed.is_empty() and tray.weeds <= 0.0:
				Game.tell(user, "%s doesn't have any plants or weeds!" % tray.e.the(), "warn")
				return true
			Game.visible_message(tray.e.cell, "%s starts digging out %s's plants..." % [user.display_name, tray.e.the()])
			DoAfter.start(user, tray.e, 5.0, func(ok):
				if ok:
					tray.clear_plant()
					tray.adjust_weeds(-tray.weeds)
					Game.visible_message(tray.e.cell, "%s digs out all of %s's plants!" % [user.display_name, tray.e.the()]))
			return true
		"secateurs":
			if tray.seed.is_empty():
				Game.tell(user, "This plot is empty.", "warn")
				return true
			if not tray.ready():
				Game.tell(user, "This plant must be harvestable in order to be grafted.", "warn")
				return true
			if int(tray.seed.get("grafts", 0)) >= 1:
				Game.tell(user, "You can't take any more cuttings from this plant!", "warn")
				return true
			var gene := _graftable_gene(tray.seed)
			if gene == "":
				Game.tell(user, "There's nothing worth grafting off this plant.", "warn")
				return true
			var cutting := Proto.spawn("plant_graft", tray.e.cell)
			var b: CBotany = cutting.c(&"botany")
			if b: b.set_graft(gene, tray.seed.get("name", "plant"))
			tray.seed["grafts"] = int(tray.seed.get("grafts", 0)) + 1
			tray.adjust_health(-5.0)
			Game.visible_message(tray.e.cell, "%s grafts off a limb from %s." % [user.display_name, tray.e.the()])
			Skills.add_xp(user, "botany", 8.0)
			return true
		"shears":
			if tray.seed.is_empty():
				Game.tell(user, "The tray is empty.", "warn")
				return true
			if tray.plant_health <= Plants.GENE_SHEAR_MIN_HEALTH:
				Game.tell(user, "This plant looks too unhealthy to be sheared right now.", "warn")
				return true
			var genes: Array = tray.seed.get("genes", [])
			if genes.is_empty():
				Game.tell(user, "There are no traits left to shear off.", "warn")
				return true
			var target: String = genes[genes.size() - 1]
			Plants.remove_gene(tray.seed, target)
			tray.adjust_health(-15.0)
			Game.tell(user, "You carefully shear the %s off %s, leaving the plant looking weaker." % [
				Plants.GENES.get(target, {}).get("name", target), tray.seed.get("name", "the plant")])
			Skills.add_xp(user, "botany", 10.0)
			return true
	return false

func _graftable_gene(from_seed: Dictionary) -> String:
	for g in from_seed.get("genes", []):
		if Plants.GENES.get(g, {}).get("graft", false): return g
	return ""

# ---------------------------------------------------------------- machines and tools
func attackby(user: Entity, item: Entity) -> bool:
	match kind:
		"watertank":
			var r: CReagents = item.c(&"reagents")
			if r == null or not r.is_open(): return false
			if not user.adjacent(e) or not user.c(&"health").can_use_hands(): return true
			var amount := minf(water_stock, r.free_space())
			r.add("water", amount, user)
			water_stock -= amount
			Game.tell(user, "You fill %s with %d units of water. Reservoir: %d." % [item.the(), int(amount), int(water_stock)])
			return true
		"extractor":
			if not user.adjacent(e) or not user.c(&"health").can_use_hands(): return true
			var m: CMachine = e.c(&"machine")
			if m and not m.operable():
				Game.tell(user, "The extractor has no power.", "warn")
				return true
			var seed_from := Botany.seed_of(item)
			if seed_from.is_empty():
				Game.tell(user, "%s has no seeds in it." % item.the(), "warn")
				return true
			var count := Game.rng.randi_range(1, 4)
			item.destroy()
			for i in count:
				piles.append(Plants.copy(seed_from))
			Game.visible_message(e.cell, "%s puts %s into %s." % [user.display_name, item.the(), e.the()])
			Game.tell(user, "It extracts %d %s seeds." % [count, String(seed_from.get("name", "plant")).to_lower()])
			Skills.add_xp(user, "botany", 3.0)
			return true
		"analyzer":
			var seed_from := Botany.seed_of(item)
			if seed_from.is_empty():
				var b: CBotany = item.c(&"botany")
				if b: seed_from = b.seed
			Game.tell(user, Botany.analyze(seed_from))
			return true
	return false

func attack_hand(user: Entity) -> bool:
	if kind != "extractor": return false
	if not user.adjacent(e) or not user.c(&"health").can_use_hands(): return true
	if piles.is_empty():
		Game.tell(user, "The extractor is empty.", "warn")
		return true
	var seed_out: Dictionary = piles.pop_back()
	var packet := Botany.make_packet(seed_out, e.cell)
	var inv: CInventory = user.c(&"inv")
	if inv: inv.put_in_hands(packet)
	Game.tell(user, "You take %s out of %s." % [packet.the(), e.the()])
	return true

func attack_self(user: Entity) -> bool:
	if kind == "seed":
		Game.tell(user, Plants.describe(seed))
		return true
	if kind == "analyzer":
		var tray := _tray_under(user)
		if tray != null:
			Game.tell(user, Botany.analyze(tray.seed, tray))
		else:
			Game.tell(user, "Point it at a tray, a seed packet or some produce.")
		return true
	return false

func _tray_under(user: Entity) -> CHydro:
	for ent in Game.at(user.cell):
		var t: CHydro = ent.c(&"hydro")
		if t != null: return t
	return null

func examine(_user: Entity, lines: Array) -> void:
	match kind:
		"seed":
			lines.append(Plants.describe(seed))
		"graft":
			lines.append("A cutting carrying %s." % Plants.GENES.get(graft_gene, {}).get("name", "nothing"))
		"watertank":
			lines.append("Reservoir: %d units of water." % int(water_stock))
		"extractor":
			if piles.is_empty():
				lines.append("It holds no seeds.")
			else:
				var counts := {}
				for s in piles:
					var n: String = s.get("name", "?")
					counts[n] = counts.get(n, 0) + 1
				var parts := []
				for n in counts: parts.append("%d x %s" % [counts[n], n])
				lines.append("It holds " + ", ".join(parts) + ".")

func ai_tags(out: Dictionary) -> void:
	out["botany_" + kind] = true
	if kind == "seed": out["seed"] = true
