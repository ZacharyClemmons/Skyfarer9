class_name Cargo extends RefCounted
## tg supply (code/modules/cargo): the cargo budget, supply packs ordered from the cargo
## console, and the supply shuttle, here a freight crawler that drives up to the Cargo
## Airlock. Orders ride in its hold; whatever is in the hold when it's sent away is sold
## (tg exports).
## Department requests from the crew still show up on the console.

static var points := 5000 # credits in the cargo budget (tg starts it at a few thousand)
static var requests: Array = [] # [{what, dept, by, t}]
static var orders: Array = [] # [{pack, by}] paid for, waiting for the shuttle
enum { AWAY, INBOUND, DOCKED, OUTBOUND }
static var state := AWAY
static var shuttle_eta := -1.0 # seconds left on the current trip
static var crawler: Vessel = null
static var last_report := ""
static var _pay_t := 0.0

## tg CARGO_CRATE_VALUE
const CRATE := 200
const SHUTTLE_TIME := 90.0
## the freight crawler: an open hold behind the hatch, drive units at the back
const LAYOUT := [
	"########",
	"#.....E#",
	"#......W",
	"#......#",
	"H......#",
	"#......#",
	"#......W",
	"#.....E#",
	"########",
]
const V0 := 4
## tg payday: departments get paid every five minutes
const PAYDAY := 300.0
const PAYDAY_AMOUNT := 500

## tg /datum/supply_pack, the ones whose contents exist here. cost is in CARGO_CRATE_VALUEs.
const PACKS := {
	# Emergency
	"spacesuit": {"name": "High-altitude Suit Crate", "cat": "Emergency", "cost": 3.0, "crate": "eng", "contains": {"eva_suit": 1, "eva_helmet": 1, "breath_mask": 1, "tank_o2": 1}},
	"internals": {"name": "Breathing Crate", "cat": "Emergency", "cost": 2.0, "crate": "gen", "contains": {"gas_mask": 3, "breath_mask": 3, "tank_air": 3, "tank_o2": 3}},
	"firefighting": {"name": "Firefighting Crate", "cat": "Emergency", "cost": 2.0, "crate": "gen", "contains": {"gas_mask": 2, "flashlight": 2, "tank_o2": 2, "extinguisher": 2}},
	"winter": {"name": "Cold Weather Gear Crate", "cat": "Emergency", "cost": 2.0, "crate": "gen", "contains": {"winter_coat": 3, "winter_hood": 3, "gloves": 3}},
	"rations": {"name": "Surplus Ration Triple-Pak", "cat": "Emergency", "cost": 3.0, "crate": "food", "contains": {"food_ration": 9}},
	# Engineering
	"engiequipment": {"name": "Engineering Gear Crate", "cat": "Engineering", "cost": 4.0, "crate": "eng", "contains": {"toolbelt": 3, "welding_helmet": 3, "insulated_gloves": 1, "gas_analyzer": 1}},
	"powergamermitts": {"name": "Insulated Gloves Crate", "cat": "Engineering", "cost": 8.0, "crate": "eng", "contains": {"insulated_gloves": 3}},
	"pacman": {"name": "P.A.C.M.A.N Generator Crate", "cat": "Engineering", "cost": 5.0, "crate": "", "contains": {"generator": 1, "sheet_plasma": 1}},
	"tools": {"name": "Tool Chest Crate", "cat": "Engineering", "cost": 5.0, "crate": "eng", "contains": {"toolbox_elec": 3, "toolbox": 3}},
	"portapump": {"name": "Portable Air Pump Crate", "cat": "Engineering", "cost": 4.5, "crate": "", "contains": {"portable_pump": 2}},
	"portascrubber": {"name": "Portable Scrubber Crate", "cat": "Engineering", "cost": 4.5, "crate": "", "contains": {"portable_scrubber": 2}},
	"holofans": {"name": "Holofan Projector Crate", "cat": "Engineering", "cost": 3.0, "crate": "eng", "contains": {"holofan": 2}},
	# Materials
	"metamorphic_samples": {"name": "Metamorphic Mineral Samples", "cat": "Materials", "cost": 8.0, "crate": "sci", "contains": {"sheet_silver": 3, "sheet_gold": 3, "sheet_uranium": 3, "sheet_plasteel": 3, "sheet_titanium": 3, "sheet_diamond": 3, "sheet_bananium": 3, "sheet_bluespace": 3}},
	"metal50": {"name": "50 Metal Sheets", "cat": "Materials", "cost": 1.5, "crate": "eng", "contains": {"sheet_metal": 50}},
	"glass50": {"name": "50 Glass Sheets", "cat": "Materials", "cost": 1.5, "crate": "eng", "contains": {"sheet_glass": 50}},
	"plasma10": {"name": "10 Plasma Sheets", "cat": "Materials", "cost": 5.0, "crate": "sci", "contains": {"sheet_plasma": 10}},
	"cable": {"name": "Cable Coil Crate", "cat": "Materials", "cost": 1.5, "crate": "eng", "contains": {"cable_coil": 3}},
	"fueltank": {"name": "Fuel Tank Crate", "cat": "Materials", "cost": 1.6, "crate": "", "contains": {"fuel_tank": 1}},
	# Atmospherics
	"o2can": {"name": "Oxygen Canister", "cat": "Atmospherics", "cost": 3.0, "crate": "", "contains": {"canister_o2": 1}},
	"n2can": {"name": "Nitrogen Canister", "cat": "Atmospherics", "cost": 2.0, "crate": "", "contains": {"canister_n2": 1}},
	"aircan": {"name": "Air Canister", "cat": "Atmospherics", "cost": 3.0, "crate": "", "contains": {"canister_air": 1}},
	"co2can": {"name": "Carbon Dioxide Canister", "cat": "Atmospherics", "cost": 3.0, "crate": "", "contains": {"canister_co2": 1}},
	"n2ocan": {"name": "Nitrous Oxide Canister", "cat": "Atmospherics", "cost": 6.0, "crate": "", "contains": {"canister_n2o": 1}},
	"plasmacan": {"name": "Plasma Canister", "cat": "Atmospherics", "cost": 10.0, "crate": "", "contains": {"canister_plasma": 1}},
	"watervapor": {"name": "Water Vapor Canister", "cat": "Atmospherics", "cost": 2.5, "crate": "", "contains": {"canister_h2o": 1}},
	# Rare-gas supplies: local economy prices (not TG supply-pack prices).
	"tritiumcan": {"name": "Tritium Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_tritium": 1}},
	"nobcan": {"name": "Hyper-Noblium Canister", "cat": "Atmospherics", "cost": 100.0, "crate": "", "contains": {"canister_nob": 1}},
	"nitriumcan": {"name": "Nitrium Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_nitrium": 1}},
	"bzcan": {"name": "BZ Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_bz": 1}},
	"pluoxcan": {"name": "Pluoxium Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_pluox": 1}},
	"miasmacan": {"name": "Miasma Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_miasma": 1}},
	"freoncan": {"name": "Freon Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_freon": 1}},
	"h2can": {"name": "Hydrogen Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_h2": 1}},
	"healiumcan": {"name": "Healium Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_healium": 1}},
	"proto_nitratecan": {"name": "Proto-Nitrate Canister", "cat": "Atmospherics", "cost": 100.0, "crate": "", "contains": {"canister_proto_nitrate": 1}},
	"zaukercan": {"name": "Zauker Canister", "cat": "Atmospherics", "cost": 100.0, "crate": "", "contains": {"canister_zauker": 1}},
	"haloncan": {"name": "Halon Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_halon": 1}},
	"hecan": {"name": "Helium Canister", "cat": "Atmospherics", "cost": 15.0, "crate": "", "contains": {"canister_he": 1}},
	"antinobcan": {"name": "Anti-Noblium Canister", "cat": "Atmospherics", "cost": 100.0, "crate": "", "contains": {"canister_antinob": 1}},
	# Medical
	"defibs": {"name": "Defibrillator Crate", "cat": "Medical", "cost": 5.0, "crate": "med", "contains": {"defib": 2}},
	"medipens": {"name": "Medipen Variety-Pak", "cat": "Medical", "cost": 3.5, "crate": "med", "contains": {"medipen": 5}},
	"medsupplies": {"name": "Medical Supplies Crate", "cat": "Medical", "cost": 4.0, "crate": "med", "contains": {"medkit": 2, "medkit_burn": 1, "medkit_toxin": 1, "medkit_o2": 1, "gauze": 3, "beaker": 2}},
	"surgery": {"name": "Surgical Supplies Crate", "cat": "Medical", "cost": 6.0, "crate": "med", "contains": {"scalpel": 1, "hemostat": 1, "retractor": 1, "cautery": 1, "circular_saw": 1, "surgical_drapes": 1}},
	"virus": {"name": "Antiviral Crate", "cat": "Medical", "cost": 2.0, "crate": "med", "contains": {"pill_bottle": 3}},
	# Security
	"armor": {"name": "Plated Vest Crate", "cat": "Security", "cost": 3.0, "crate": "sec", "contains": {"armor_vest": 3}},
	"helmets": {"name": "Helms Crate", "cat": "Security", "cost": 3.0, "crate": "sec", "contains": {"helmet_sec": 3}},
	"riotarmor": {"name": "Boarding Harness Crate", "cat": "Security", "cost": 6.0, "crate": "sec", "contains": {"riot_armor": 3}},
	"riothelmets": {"name": "Boarding Helm Crate", "cat": "Security", "cost": 4.0, "crate": "sec", "contains": {"helmet_riot": 3}},
	"bulletproof": {"name": "Shot-proof Vest Crate", "cat": "Security", "cost": 3.0, "crate": "sec", "contains": {"bulletproof_vest": 3}},
	"reflector": {"name": "Mirrored Vest Crate", "cat": "Security", "cost": 5.0, "crate": "sec", "contains": {"reflector_vest": 2}},
	"ammo": {"name": "Ammo Crate", "cat": "Security", "cost": 8.0, "crate": "sec", "contains": {"shell_beanbag": 3, "shell_buckshot": 2, "ammo_38": 2, "ammo_38_rubber": 2}},
	"shotguns": {"name": "Scattergun Crate", "cat": "Security", "cost": 17.5, "crate": "sec", "contains": {"shotgun": 3}},
	"disablers": {"name": "Aether Stunner Crate", "cat": "Security", "cost": 3.0, "crate": "sec", "contains": {"disabler": 3}},
	"lasers": {"name": "Aether Pistol Crate", "cat": "Security", "cost": 4.0, "crate": "sec", "contains": {"laser_gun": 3}},
	"eguns": {"name": "Aether Carbine Crate", "cat": "Security", "cost": 18.0, "crate": "sec", "contains": {"egun": 3}},
	"batons": {"name": "Shock Batons Crate", "cat": "Security", "cost": 3.0, "crate": "sec", "contains": {"baton": 3}},
	"securitysupplies": {"name": "Watch Supplies Crate", "cat": "Security", "cost": 3.5, "crate": "sec", "contains": {"flashbang": 3, "flash": 3, "handcuffs": 3, "pepperspray": 2}},
	"riotshields": {"name": "Boarding Shields Crate", "cat": "Security", "cost": 5.0, "crate": "sec", "contains": {"riot_shield": 3}},
	"sunglasses": {"name": "Tinted Goggles Crate", "cat": "Security", "cost": 2.0, "crate": "sec", "contains": {"sunglasses": 1}},
	# Service
	"janitor": {"name": "Deck Sweeper's Crate", "cat": "Service", "cost": 2.0, "crate": "gen", "contains": {"bucket": 3, "mop": 1, "soap": 1, "spray_bottle": 2}},
	"lights": {"name": "Replacement Lights", "cat": "Service", "cost": 2.0, "crate": "gen", "contains": {"light_tube": 12}},
	"knives": {"name": "Survival Knives Crate", "cat": "Service", "cost": 3.0, "crate": "gen", "contains": {"knife_survival": 3}},
	"party": {"name": "Party Equipment", "cat": "Service", "cost": 5.0, "crate": "food", "contains": {"drink_booze": 4, "drink_soda": 6, "cig_pack": 2, "lighter": 2}},
	"food": {"name": "Food Crate", "cat": "Service", "cost": 2.0, "crate": "food", "contains": {"food_flour": 3, "food_egg": 6, "food_meat": 3, "food_tomato": 3, "food_potato": 3}},
	"coffee": {"name": "Coffee Equipment Crate", "cat": "Service", "cost": 4.0, "crate": "food", "contains": {"drink_coffee": 8, "drink_cocoa": 4}},
	"cargosupplies": {"name": "Cargo Supplies Crate", "cat": "Service", "cost": 1.75, "crate": "gen", "contains": {"paper": 10, "pen": 3}},
	"idcards": {"name": "Plain Passcard Multipack Crate", "cat": "Service", "cost": 3.0, "crate": "gen", "contains": {"id_card": 4}},
	"emptycrate": {"name": "Empty Crate", "cat": "Service", "cost": 1.4, "crate": "gen", "contains": {}},
	# Science
	"plasmaassembly": {"name": "Plasma Assembly Crate", "cat": "Science", "cost": 2.0, "crate": "sci", "contains": {"sheet_plasma": 3, "beaker": 3, "glowstick": 3}},
	"robotics": {"name": "Robotics Assembly Crate", "cat": "Science", "cost": 3.0, "crate": "sci", "contains": {"health_analyzer": 2, "medkit": 2, "multitool": 2, "cable_coil": 2}},
	# Mining
	"miner": {"name": "Shaft Miner Starter Kit", "cat": "Mining", "cost": 4.0, "crate": "gen", "contains": {"pickaxe": 1, "flashlight": 1, "tank_o2": 1, "breath_mask": 1, "winter_coat": 1, "backpack": 1}},
}

## tg /datum/export values (credits) for what gets shipped off the pad.
const EXPORTS := {
	"spacecash": 1000, "ore_iron": 20, "ore_plasma": 100, "ore_cryo": 150, "ore_gold": 125, "ice_chunk": 5,
	"sheet_metal": 5, "sheet_glass": 5, "sheet_rglass": 8, "sheet_plasma": 100, "rods": 2,
	"crate": 100, "canister_empty": 50, "defib": 200, "egun": 400, "laser_gun": 300, "disabler": 200,
	"medkit": 40, "toolbox": 30, "multitool": 40, "gas_analyzer": 30, "health_analyzer": 60,
	"mouse_dead": 10, "food_meat": 15, "food_wheat": 5, "food_tomato": 8, "food_potato": 8, "food_berries": 10, "food_banana": 10,
}

static func request(what: String, dept: String, by: Entity) -> void:
	for r in requests:
		if r["what"] == what and r["dept"] == dept:
			return
	requests.append({"what": what, "dept": dept, "by": by.id if by else 0, "t": Game.time})
	StationAlerts.radio_system("Hold Ledger", "Supply", "New request: %s for %s." % [what, Defs.DEPARTMENTS.get(dept, {}).get("name", dept)], {"type": "supply_request", "key": "req:%s:%s" % [what, dept], "cell": Vector2i.ZERO, "severity": 1, "data": {"what": what, "dept": dept}})

static func value_of(item: Entity) -> int:
	var v: int = EXPORTS.get(item.proto, 0)
	var st: CStack = item.c(&"stack")
	if st and v > 0:
		v *= st.amount
	if v == 0 and item.has_c(&"item"):
		v = 3 # tg: most things are worth a little as scrap
	return v

static func sell(item: Entity) -> int:
	var v := value_of(item)
	points += v
	return v

static func pack_cost(id: String) -> int:
	return int(PACKS[id]["cost"] * CRATE)

static func can_order(user: Entity) -> bool:
	var inv: CInventory = user.c(&"inv") if user else null
	return inv != null and (inv.has_access("supply") or inv.has_access("cargo") or inv.has_access("hop") or inv.has_access("captain"))

## tg cargo console "add to cart" + purchase: pays now, arrives on the next shuttle.
static func order(id: String, user: Entity) -> bool:
	if not PACKS.has(id):
		return false
	if not can_order(user):
		Game.tell(user, "Access denied: supply access required.", "bad")
		return false
	var c := pack_cost(id)
	if points < c:
		Game.tell(user, "Insufficient funds: %d cr needed." % c, "warn")
		return false
	points -= c
	orders.append({"pack": id, "by": user.display_name})
	Sfx.play_ui("ui_select")
	Game.tell(user, "Ordered %s for %d cr. It will arrive with the next supply drop." % [PACKS[id]["name"], c])
	return true

static func cancel(idx: int, user: Entity) -> void:
	if idx < 0 or idx >= orders.size():
		return
	var o: Dictionary = orders[idx]
	points += pack_cost(o["pack"])
	orders.remove_at(idx)
	Game.tell(user, "Order cancelled and refunded.")

static func status_text() -> String:
	match state:
		INBOUND: return "Supply ferry en route to the Cargo Hatch: %d s." % int(shuttle_eta)
		DOCKED: return "Supply ferry docked at the Cargo Hatch."
		OUTBOUND: return "Supply ferry returning to the home depot: %d s." % int(shuttle_eta)
	return "Supply ferry at the home depot."

## tg "Send to station".
static func call_shuttle(user: Entity) -> void:
	if state != AWAY:
		return
	if user and not can_order(user):
		Game.tell(user, "Access denied: supply access required.", "bad")
		return
	state = INBOUND
	shuttle_eta = SHUTTLE_TIME
	StationAlerts.radio_system("Hold Ledger", "Supply", "The supply ferry is on its way with %d order%s. ETA %d seconds." % [orders.size(), "" if orders.size() == 1 else "s", int(SHUTTLE_TIME)], {"type": "supply_shuttle", "key": "shuttle", "cell": Vector2i.ZERO, "severity": 0})

## tg "Send to CentCom": whatever is aboard is sold.
static func send_shuttle(user: Entity) -> void:
	if state != DOCKED or crawler == null:
		return
	if user and not can_order(user):
		Game.tell(user, "Access denied: supply access required.", "bad")
		return
	var earned := 0
	var n := 0
	for c in crawler.cells:
		for ent in Game.at(c).duplicate():
			if ent.has_c(&"mob") or ent.has_c(&"decal") or ent.removed or ent in crawler.parts:
				continue
			var st: CStorage = ent.c(&"storage")
			if st:
				for inner in st.contents.duplicate():
					earned += value_of(inner)
			earned += value_of(ent) if ent.has_c(&"item") else EXPORTS.get(ent.proto, 25)
			n += 1
	points += earned
	last_report = ("Exported %d item%s for %d cr." % [n, "" if n == 1 else "s", earned]) if n > 0 else "Nothing exported."
	# nobody rides back to the depot: step them off onto the dock
	for m in crawler.occupants():
		m.place(crawler.dock_cell - crawler.dir)
	Sfx.play("engine", crawler.dock_cell, 0.9)
	crawler.remove()
	crawler = null
	state = OUTBOUND
	shuttle_eta = SHUTTLE_TIME
	StationAlerts.radio_system("Hold Ledger", "Supply", "The supply ferry has left. %s" % last_report, {"type": "supply_shuttle", "key": "shuttle_left", "cell": Vector2i.ZERO, "severity": 0})

## The hold: where ordered crates arrive and exports are loaded.
static func pad_cells() -> Array:
	if crawler == null or not crawler.present:
		return []
	return crawler.interior

static func tick(dt: float) -> void:
	_pay_t += dt
	if _pay_t >= PAYDAY:
		_pay_t = 0.0
		points += PAYDAY_AMOUNT
	if state == INBOUND or state == OUTBOUND:
		shuttle_eta -= dt
		if shuttle_eta <= 0.0:
			shuttle_eta = -1.0
			if state == INBOUND:
				_arrive()
			else:
				state = AWAY

static func _arrive() -> void:
	var dock: Dictionary = Game.map.supply_dock
	if dock.is_empty():
		state = AWAY
		return
	crawler = Vessel.new()
	crawler.name = "Supply Ferry"
	crawler.dock_cell = dock["cell"]
	crawler.dir = dock["dir"]
	crawler.layout = LAYOUT
	crawler.v0 = V0
	crawler.area_names = {"main": "Supply Ferry"}
	crawler.lights = [Vector2i(3, -2), Vector2i(3, 2)]
	crawler.treads = true
	crawler.stamp()
	state = DOCKED
	_deliver()

static func _deliver() -> void:
	var dc: Vector2i = crawler.dock_cell
	var cells: Array = crawler.interior.filter(func(c): return c != dc)
	cells.sort_custom(func(a, b): return (a - dc).length_squared() > (b - dc).length_squared())
	var n := 0
	for o in orders:
		var pack: Dictionary = PACKS[o["pack"]]
		var at: Vector2i = cells[n % cells.size()] if not cells.is_empty() else dc
		n += 1
		if pack["crate"] == "":
			for p in pack["contains"]:
				for k in pack["contains"][p]:
					Proto.spawn(p, at)
			continue
		var cs: String = "crate_" + pack["crate"]
		var crate := Proto.spawn("crate", at, {"name": pack["name"], "spr": cs, "comps": {"storage": {"spr": cs, "spr_open": cs + "_open"}}})
		var st: CStorage = crate.c(&"storage")
		for p in pack["contains"]:
			var cnt: int = pack["contains"][p]
			if String(p).begins_with("sheet_") or p == "rods":
				st.insert(Proto.spawn(p, at, {"comps": {"stack": {"amount": cnt}}}))
			elif p == "cable_coil":
				for k in cnt:
					st.insert(Proto.spawn(p, at, {"comps": {"stack": {"amount": 30}}}))
			else:
				for k in cnt:
					st.insert(Proto.spawn(p, at))
		crate.tags["ordered_by"] = o["by"]
	var count := orders.size()
	orders.clear()
	Sfx.play("engine", dc, 0.8)
	StationAlerts.radio_system("Hold Ledger", "Supply", "The supply ferry has docked at the Cargo Hatch with %d order%s." % [count, "" if count == 1 else "s"], {"type": "supply_arrived", "key": "shuttle_arrived", "cell": dc, "severity": 0})
