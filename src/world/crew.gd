class_name Crew extends RefCounted
## Builds crewmembers: body, outfit from the job datum, ID, headset, tools, skills,
## personality, and the knowledge they'd plausibly start the shift with.

const SUIT_STATS := {
	"winter": {"insulation": 0.55, "slow": 0.05}, "labcoat": {"insulation": 0.15}, "hazard": {"insulation": 0.12},
	"armor": {"insulation": 0.1, "armor": 0.35, "bullet": 30.0, "laser": 30.0, "energy": 40.0, "wound": 10.0, "covers": ["chest"]}, "apron": {"insulation": 0.03},
}
const HEAD_STATS := {
	"hood": {"insulation": 0.2, "hides_hair": true}, "beanie": {"insulation": 0.1}, "hardhat": {"armor": 0.15, "insulation": 0.05, "wound": 10.0},
	"helmet": {"armor": 0.35, "insulation": 0.08, "hides_hair": true, "wound": 10.0}, "beret": {"insulation": 0.03}, "cap": {"insulation": 0.03},
	"chef": {}, "captain": {"insulation": 0.04},
}

static func spawn_human(job: String, cell: Vector2i, opts: Dictionary = {}) -> Entity:
	var rng := Game.rng
	var e := Entity.new()
	e.proto = "human"
	var nm: String = opts.get("name", Jobs.random_name(rng))
	e.display_name = nm
	e.cell = cell
	e.position = Entity.cell_to_pos(cell)
	e.z_index = 1 # tg: mobs sit above objects on their tile
	Game.ents_node.add_child(e)
	var inv := CInventory.new()
	var health := CHealth.new()
	var needs := CNeeds.new()
	var mob := CMob.new()
	mob.real_name = nm
	mob.job = job
	mob.appearance = opts.get("appearance", Jobs.random_appearance(rng))
	mob.pronoun = opts.get("pronoun", ["they", "she", "he"][rng.randi() % 3])
	var jd: Dictionary = Jobs.JOBS.get(job, Jobs.JOBS["assistant"])
	e.add(inv)
	e.add(health)
	e.add(needs)
	e.add(mob)
	e.add(CMood.new()) # tg /datum/mood
	e.add(CDna.new()) # tg /datum/dna
	needs.nutrition = rng.randf_range(55, 95)
	needs.hydration = rng.randf_range(55, 95)
	needs.energy = rng.randf_range(60, 100)
	needs.social = rng.randf_range(40, 90)
	if not opts.get("player", false):
		var brain := CBrain.new()
		brain.job = job
		e.add(brain)
		brain.setup_personality(rng, jd.get("traits", {}))
	Game.register(e)
	# tg initialize_dna: the mutation blocks, the features, then the identity from the body
	var dna: CDna = e.c(&"dna")
	dna.initialize_dna()
	Species.apply_brain(e)
	starting_skills(e, job, rng, opts.get("saved", {}))
	outfit(e, job)
	# tg quirks: the player's own picks, the crew a random balanced set (SSquirks.randomise_quirks)
	var qs: Array = opts.get("quirks", []) if opts.get("player", false) else Quirks.random_set(rng)
	# a crewmember whose persona smokes is a tg smoker (and the other way round), hooked on nicotine
	var br: CBrain = e.c(&"brain")
	if br and br.persona:
		if br.persona.has_quirk("smoker") and not "smoker" in qs:
			qs = Quirks.filter_valid(qs + ["smoker"])
		if "smoker" in qs and not br.persona.has_quirk("smoker"):
			br.persona.quirks.append("smoker")
	Quirks.apply(e, qs)
	mob.refresh_doll()
	return e

## Job skills (0-10 in the job data) become levels around 10x that; everything else
## starts low. Attributes follow from the skills the job leans on. A saved character's
## own XP (opts "xp") is kept when it's higher.
static func starting_skills(e: Entity, job: String, rng: RandomNumberGenerator, saved := {}) -> void:
	var jd: Dictionary = Jobs.JOBS.get(job, Jobs.JOBS["assistant"])
	var js: Dictionary = jd.get("skills", {})
	var attr_sum := {}
	for s in Skills.SKILLS:
		var base: int = int(js.get(s, js.get("combat", 0) if s in ["melee", "unarmed", "block"] else 0))
		var lvl := clampi(base * 10 + rng.randi_range(-4, 4), 1, 95) if base > 0 else rng.randi_range(1, 8)
		Skills.set_level(e, s, lvl)
		var a: String = Skills.SKILLS[s]["attr"]
		attr_sum[a] = maxi(attr_sum.get(a, 0), lvl)
	for a in Skills.ATTRIBUTES:
		Skills.set_attr_level(e, a, clampi(int(attr_sum.get(a, 5) * 0.5) + rng.randi_range(3, 10), 1, 60))
	var m: CMob = e.c(&"mob")
	for k in saved.get("skills", {}):
		m.xp[k] = maxf(m.xp.get(k, 0.0), float(saved["skills"][k]))
	for k in saved.get("attrs", {}):
		m.attr_xp[k] = maxf(m.attr_xp.get(k, 0.0), float(saved["attrs"][k]))

static func _clothes(proto: String, cell: Vector2i, name: String, sprite: String, colors: Array, extra := {}) -> Entity:
	var params := {"sprite": sprite, "colors": colors}
	params.merge(extra, true)
	return Proto.spawn(proto, cell, {"name": name, "comps": {"clothing": params}})

static func outfit(e: Entity, job: String) -> void:
	var inv: CInventory = e.c(&"inv")
	var mob: CMob = e.c(&"mob")
	var jd: Dictionary = Jobs.JOBS.get(job, Jobs.JOBS["assistant"])
	var o: Dictionary = jd["outfit"]
	var c := e.cell
	var title: String = jd["title"]
	if o.has("uniform"):
		var u: Array = o["uniform"]
		var w := _clothes("uniform", c, "%s's uniform" % title.to_lower(), "uniform_" + u[0], u.slice(1), {"insulation": 0.1, "wound": 10.0 if o.get("id", "") == "id_sec" else 5.0})
		inv.put_in_hands(w)
		inv.equip(w, "uniform")
	if o.has("shoes"):
		var sh := _clothes("shoes", c, "boots", "shoes", [o["shoes"]], {"insulation": 0.06})
		inv.put_in_hands(sh)
		inv.equip(sh, "shoes")
	if o.has("gloves"):
		var yellow: bool = o["gloves"] == "#e8c83a"
		var gl := _clothes("insulated_gloves" if yellow else "gloves", c, "insulated gloves" if yellow else "gloves", "gloves", [o["gloves"]], {"insulated": yellow})
		inv.put_in_hands(gl)
		inv.equip(gl, "gloves")
	if o.has("suit"):
		var s: Array = o["suit"]
		var st: Dictionary = SUIT_STATS.get(s[0], {})
		var nm: String = {"winter": "winter coat", "labcoat": "labcoat", "hazard": "hazard vest", "armor": "armor vest", "apron": "apron"}.get(s[0], "coat")
		var su := _clothes("winter_coat" if s[0] == "winter" else "suit", c, nm, "suit_" + s[0], s.slice(1), st)
		inv.put_in_hands(su)
		inv.equip(su, "suit")
	if o.has("head"):
		var hd: Array = o["head"]
		var hs: Dictionary = HEAD_STATS.get(hd[0], {})
		var h := _clothes("winter_hood" if hd[0] == "hood" else "hat", c, {"hardhat": "hard hat", "helmet": "helmet", "hood": "winter hood", "captain": "director's cap", "chef": "chef's hat"}.get(hd[0], hd[0]), "head_" + hd[0], hd.slice(1), hs)
		inv.put_in_hands(h)
		inv.equip(h, "head")
	if o.has("mask"):
		var mk: Array = o["mask"]
		var m := _clothes("gas_mask" if mk[0] == "gasmask" else "breath_mask", c, "gas mask" if mk[0] == "gasmask" else "breath mask", "mask_" + mk[0], mk.slice(1), {"breath": true, "filter": mk[0] == "gasmask"})
		inv.put_in_hands(m)
		inv.equip(m, "mask")
	# ID
	var id_spr: String = o.get("id", "id_gen")
	var card := Proto.spawn("id_card", c, {"spr": id_spr, "name": "%s's passcard (%s)" % [e.display_name, title], "comps": {"idcard": {"owner": e.display_name, "job": title, "access": jd["access"]}}})
	inv.put_in_hands(card)
	inv.equip(card, "id")
	# headset
	var hsx := Proto.spawn("headset", c, {"comps": {"headset": {"channels": jd.get("radio", [])}}})
	inv.put_in_hands(hsx)
	inv.equip(hsx, "ears")
	# back
	var bag: Entity = null
	if o.has("back"):
		bag = Proto.spawn("backpack", c, {"comps": {"clothing": {"colors": [o["back"], Color(o["back"]).darkened(0.35).to_html()]}}})
		inv.put_in_hands(bag)
		inv.equip(bag, "back")
		for it in ["tank_air", "breath_mask", "drink_water"]:
			bag.c(&"storage").insert(Proto.spawn(it, c))
	if o.get("belt", "") == "toolbelt":
		var belt := Proto.spawn("toolbelt", c)
		inv.put_in_hands(belt)
		inv.equip(belt, "belt")
		for t in ["wrench", "screwdriver", "crowbar", "wirecutters", "welder", "cable_coil"]:
			var tool := Proto.spawn(t, c)
			# a full belt spills into the backpack, not onto the floor
			if not belt.c(&"storage").insert(tool) and not (bag != null and bag.c(&"storage").insert(tool)):
				tool.destroy()
	elif o.has("belt"):
		var belt2 := Proto.spawn("toolbelt", c, {"name": "security belt", "comps": {"clothing": {"colors": [o["belt"], "#000000", "#000000", "#b0b8c4"]},
			"storage": {"slots": 5, "holds": ["handcuffs", "cable_cuffs", "baton", "flash", "pepperspray", "flashlight", "flashbang", "smoke_grenade", "disabler", "restraint", "radio", "headset"]}}})
		inv.put_in_hands(belt2)
		inv.equip(belt2, "belt")
	for it_name in jd.get("items", []):
		var it := Proto.spawn(it_name, c)
		if bag and bag.c(&"storage").insert(it):
			continue
		var belt3: Entity = inv.worn("belt")
		if belt3 and belt3.c(&"storage").insert(it):
			continue
		if not inv.put_in_hands(it):
			inv.drop(it)
	if job == "atmos" or job == "miner":
		var tk := inv.find_item(func(x): return x.proto == "tank_o2")
		if tk:
			pass
	mob.refresh_doll()

## Knowledge NPCs have on day one: their department's layout and gear, the vending
## machines and extinguisher cabinets everyone passes, and their own bed.
static func seed_knowledge(e: Entity) -> void:
	var b: CBrain = e.c(&"brain")
	if b == null:
		return
	var dept := Jobs.dept(b.job)
	var work := b.work_areas()
	for it in Game.all_with(&"item"):
		var root: Entity = it.root()
		if root.has_c(&"mob"):
			continue
		var a := Game.map.area_at(root.cell)
		if a in work or (a.dept == dept and dept != "civilian") or (a.room_kind in ["tool_storage", "eva_storage"] and randf() < 0.6):
			b.remember_item(it, Knowledge.JOB)
	for v in Game.all_with(&"vending"):
		b.remember_item(v, Knowledge.JOB)
	for f in Game.all_with(&"furniture"):
		if f.c(&"furniture").kind == "cabinet":
			b.remember_item(f, Knowledge.JOB)
		elif f.c(&"furniture").kind == "bed":
			var a2 := Game.map.area_at(f.cell)
			if a2.name.begins_with("Dormitories"):
				b.remember_item(f, Knowledge.JOB)

static func assign_beds(crew: Array) -> void:
	var beds := []
	for f in Game.all_with(&"furniture"):
		if f.c(&"furniture").kind == "bed" and Game.map.area_at(f.cell).name.begins_with("Dormitories"):
			beds.append(f)
	beds.shuffle()
	for i in crew.size():
		var b: CBrain = crew[i].c(&"brain")
		if b and i < beds.size():
			b.bed_id = beds[i].id

## Colleagues know each other; some are friends, a few can't stand each other.
static func seed_relationships(crew: Array) -> void:
	var rng := Game.rng
	for a in crew:
		var ba: CBrain = a.c(&"brain")
		for bb in crew:
			if a == bb:
				continue
			var r = ba.memory.rel(bb.id) if ba else null
			var same := Jobs.dept(a.c(&"mob").job) == Jobs.dept(bb.c(&"mob").job)
			if r == null:
				continue
			r.familiarity = 40.0 if same else rng.randf_range(0, 20)
			r.affinity = rng.randf_range(0, 18) if same else rng.randf_range(-8, 10)
			r.trust = r.affinity * 0.8 + (10.0 if same else 0.0)
			if Jobs.is_head(bb.c(&"mob").job) and same:
				r.respect = 30.0
	# friendships and rivalries (symmetric-ish)
	for k in crew.size() / 2:
		var x: Entity = crew[rng.randi() % crew.size()]
		var y: Entity = crew[rng.randi() % crew.size()]
		if x == y:
			continue
		var friendly := rng.randf() < 0.72
		var v := rng.randf_range(40, 75) if friendly else rng.randf_range(-70, -40)
		for pair in [[x, y], [y, x]]:
			var br: CBrain = pair[0].c(&"brain")
			if br:
				var rr = br.memory.rel(pair[1].id)
				rr.affinity = v * rng.randf_range(0.8, 1.1)
				rr.trust = v * 0.7
				rr.familiarity = 70.0
