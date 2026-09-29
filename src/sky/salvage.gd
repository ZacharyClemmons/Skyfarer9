class_name Salvage extends RefCounted
## What you find in a wreck, a cache or a dead skyfarer's locker.
##
## Weighted so that the common result is useful-but-dull (fuel, scrap, a tool you already
## own) and the rare result changes your week. Nothing here is generated: every entry is a
## real prototype, so anything you pull out of a crate works exactly as it would if you had
## bought it.

## [proto, weight]
const COMMON := [
	["salvage_scrap", 40], ["fuel_can", 30], ["sheet_metal", 22], ["rods", 16],
	["cable_coil", 16], ["sheet_glass", 12], ["floor_tile", 10], ["sheet_wood", 14],
	["ore_sulfur", 14], ["wrench", 8], ["crowbar", 8], ["screwdriver", 7],
	["wirecutters", 7], ["flashlight", 8], ["bruise_pack", 8], ["ointment", 7],
]

const UNCOMMON := [
	["ore_aetherite", 18], ["welder", 10], ["multitool", 9], ["extinguisher", 8],
	["medkit", 7], ["glowstick", 9], ["t_scanner", 5], ["chart_scrap", 10],
	["toolbox", 6], ["pickaxe", 7], ["sky_compass", 6], ["breathing_rig", 5],
	["ore_skyglass", 8], ["rcd_ammo", 4], ["spacecash", 9],
]

const RARE := [
	["spyglass", 8], ["grapple_gun", 7], ["glider_pack", 6], ["rcd", 3],
	["rpd", 3], ["eva_suit", 3], ["armor_vest", 4], ["revolver", 3],
	["fireaxe", 4], ["circuit_board", 4],
]

## Roll one item. `luck` shifts the odds toward the better tables — a deep-sky wreck is
## worth more than one beached on the home island.
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> String:
	var r := rng.randf() - luck * 0.25
	if r < 0.60:
		return _pick(COMMON, rng)
	if r < 0.90:
		return _pick(UNCOMMON, rng)
	return _pick(RARE, rng)

static func _pick(table: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for row in table:
		total += int(row[1])
	var r := rng.randi() % maxi(1, total)
	for row in table:
		r -= int(row[1])
		if r < 0:
			return row[0]
	return table[0][0]

## Fill a container with a wreck's worth of salvage.
static func fill(box: Entity, rng: RandomNumberGenerator, count := 3, luck := 0.0) -> void:
	var st: CStorage = box.c(&"storage")
	if st == null:
		return
	for _i in count:
		var id := roll(rng, luck)
		if Proto.has(id):
			st.insert(Proto.spawn(id, box.cell))

## Ore a broken rock face drops, by turf.
static func ore_for_turf(t: int) -> String:
	var info: Dictionary = Defs.TURFS[t]
	return str(info.get("ore", ""))
