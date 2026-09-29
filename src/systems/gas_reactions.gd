class_name GasReactions extends RefCounted
## tg's gas reactions, ported from code/modules/atmospherics/gasmixtures/reactions.dm with
## its constants from code/__DEFINES/reactions.dm and atmospherics/atmos_core.dm.
##
## How tg runs them (gas_mixture/react): every reaction whose requirements are met fires,
## grouped by priority - pre-formation, formation, post-formation, then fires - and each
## reaction's temperature limits are checked against the temperature at the start of the
## step while the mole requirements see the mix as earlier reactions left it. Five moles of
## hyper-noblium above 20 K stops everything.
##
## The mix is a plain Array of moles indexed like Defs.GAS_NAMES; `holder` says where it
## is: a tile (cell set), a pipe network, or nothing (a tank or a canister).

# ------------------------------------------------------------------ tg constants
const T0C := 273.15
const T20C := 293.15
const TCMB := 2.7
const R_IDEAL := 8.31
const CELL_VOLUME := 2500.0
const MINIMUM_MOLE_COUNT := 0.01
const MINIMUM_HEAT_CAPACITY := 0.0003
const MOLES_GAS_VISIBLE := 0.25
const MOLAR_ACCURACY := 1e-4
const EPS := 1e-7 # float dust allowed in tg's "never below zero" guards
const FIRE_MINIMUM_TEMPERATURE_TO_EXIST := 100.0 + T0C
const REACTION_OPPRESSION_THRESHOLD := 5.0
const REACTION_OPPRESSION_MIN_TEMP := 20.0
const ATMOS_RADIATION_VOLUME_EXP := 3.0
const GAS_REACTION_MAXIMUM_RADIATION_PULSE_RANGE := 20.0

const WATER_VAPOR_CONDENSATION_POINT := T20C + 10.0
const WATER_VAPOR_DEPOSITION_POINT := 200.0
const MIASTER_STERILIZATION_TEMP := FIRE_MINIMUM_TEMPERATURE_TO_EXIST + 70.0
const MIASTER_STERILIZATION_MAX_HUMIDITY := 0.1
const MIASTER_STERILIZATION_RATE_BASE := 20.0
const MIASTER_STERILIZATION_RATE_SCALE := 20.0
const MIASTER_STERILIZATION_ENERGY := 2e-3
const PLASMA_MINIMUM_BURN_TEMPERATURE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST
const PLASMA_UPPER_TEMPERATURE := PLASMA_MINIMUM_BURN_TEMPERATURE + 1270.0
const OXYGEN_BURN_RATIO_BASE := 1.4
const PLASMA_OXYGEN_FULLBURN := 10.0
const SUPER_SATURATION_THRESHOLD := 96.0
const PLASMA_BURN_RATE_DELTA := 9.0
const FIRE_PLASMA_ENERGY_RELEASED := 3e6
const HYDROGEN_MINIMUM_BURN_TEMPERATURE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST
const FIRE_HYDROGEN_ENERGY_RELEASED := 2.8e6
const HYDROGEN_OXYGEN_FULLBURN := 10.0
const FIRE_HYDROGEN_BURN_RATE_DELTA := 2.0
const TRITIUM_MINIMUM_BURN_TEMPERATURE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST
const FIRE_TRITIUM_ENERGY_RELEASED := FIRE_HYDROGEN_ENERGY_RELEASED
const TRITIUM_OXYGEN_FULLBURN := HYDROGEN_OXYGEN_FULLBURN
const FIRE_TRITIUM_BURN_RATE_DELTA := FIRE_HYDROGEN_BURN_RATE_DELTA
const TRITIUM_RADIATION_MINIMUM_MOLES := 0.1
const TRITIUM_RADIATION_RELEASE_THRESHOLD := FIRE_TRITIUM_ENERGY_RELEASED
const TRITIUM_RADIATION_RANGE_DIVISOR := 0.5
const TRITIUM_RADIATION_THRESHOLD := 0.3
const FREON_MAXIMUM_BURN_TEMPERATURE := 283.0
const FREON_LOWER_TEMPERATURE := 60.0
const FREON_TERMINAL_TEMPERATURE := 20.0
const FREON_OXYGEN_FULLBURN := 10.0
const FREON_BURN_RATE_DELTA := 4.0
const FIRE_FREON_ENERGY_CONSUMED := 3e5
const HOT_ICE_FORMATION_MAXIMUM_TEMPERATURE := 160.0
const HOT_ICE_FORMATION_MINIMUM_TEMPERATURE := 120.0
const HOT_ICE_FORMATION_PROB := 2.0
const N2O_FORMATION_MIN_TEMPERATURE := 200.0
const N2O_FORMATION_MAX_TEMPERATURE := 250.0
const N2O_FORMATION_ENERGY := 10000.0
const N2O_DECOMPOSITION_MIN_TEMPERATURE := 1400.0
const N2O_DECOMPOSITION_MAX_TEMPERATURE := 100000.0
const N2O_DECOMPOSITION_RATE_DIVISOR := 2.0
const N2O_DECOMPOSITION_MIN_SCALE_TEMP := 0.0
const N2O_DECOMPOSITION_MAX_SCALE_TEMP := 100000.0
const N2O_DECOMPOSITION_SCALE_DIVISOR := (-1.0 / 4.0) * ((N2O_DECOMPOSITION_MAX_SCALE_TEMP - N2O_DECOMPOSITION_MIN_SCALE_TEMP) * (N2O_DECOMPOSITION_MAX_SCALE_TEMP - N2O_DECOMPOSITION_MIN_SCALE_TEMP))
const N2O_DECOMPOSITION_ENERGY := 200000.0
const BZ_FORMATION_MAX_TEMPERATURE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST - 60.0
const BZ_FORMATION_ENERGY := 80000.0
const PLUOXIUM_FORMATION_MIN_TEMP := 50.0
const PLUOXIUM_FORMATION_MAX_TEMP := T0C
const PLUOXIUM_FORMATION_MAX_RATE := 5.0
const PLUOXIUM_FORMATION_ENERGY := 250.0
const NITRIUM_FORMATION_MIN_TEMP := 1500.0
const NITRIUM_FORMATION_TEMP_DIVISOR := FIRE_MINIMUM_TEMPERATURE_TO_EXIST * 8.0
const NITRIUM_FORMATION_ENERGY := 100000.0
const NITRIUM_DECOMPOSITION_MAX_TEMP := T0C + 70.0
const NITRIUM_DECOMPOSITION_TEMP_DIVISOR := FIRE_MINIMUM_TEMPERATURE_TO_EXIST * 8.0
const NITRIUM_DECOMPOSITION_ENERGY := 30000.0
const FREON_FORMATION_MIN_TEMPERATURE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST + 100.0
const NOBLIUM_FORMATION_MIN_TEMP := TCMB
const NOBLIUM_FORMATION_MAX_TEMP := 15.0
const NOBLIUM_FORMATION_ENERGY := 2e7
const HALON_COMBUSTION_ENERGY := 2500.0
const HALON_COMBUSTION_MIN_TEMPERATURE := T0C + 70.0
const HALON_COMBUSTION_TEMPERATURE_SCALE := FIRE_MINIMUM_TEMPERATURE_TO_EXIST * 10.0
const HEALIUM_FORMATION_MIN_TEMP := 25.0
const HEALIUM_FORMATION_MAX_TEMP := 300.0
const HEALIUM_FORMATION_ENERGY := 9000.0
const ZAUKER_FORMATION_MIN_TEMPERATURE := 50000.0
const ZAUKER_FORMATION_MAX_TEMPERATURE := 75000.0
const ZAUKER_FORMATION_TEMPERATURE_SCALE := 5e-6
const ZAUKER_FORMATION_ENERGY := 5000.0
const ZAUKER_DECOMPOSITION_MAX_RATE := 20.0
const ZAUKER_DECOMPOSITION_ENERGY := 460.0
const PN_FORMATION_MIN_TEMPERATURE := 5000.0
const PN_FORMATION_MAX_TEMPERATURE := 10000.0
const PN_FORMATION_ENERGY := 650.0
const PN_HYDROGEN_CONVERSION_THRESHOLD := 150.0
const PN_HYDROGEN_CONVERSION_MAX_RATE := 5.0
const PN_HYDROGEN_CONVERSION_ENERGY := 2500.0
const PN_TRITIUM_CONVERSION_MIN_TEMP := 150.0
const PN_TRITIUM_CONVERSION_MAX_TEMP := 340.0
const PN_TRITIUM_CONVERSION_ENERGY := 10000.0
const PN_TRITIUM_CONVERSION_RAD_RELEASE_THRESHOLD := 10000.0
const PN_TRITIUM_RAD_RANGE_DIVISOR := 0.5
const PN_TRITIUM_RAD_THRESHOLD := 0.3
const PN_BZASE_MIN_TEMP := 260.0
const PN_BZASE_MAX_TEMP := 280.0
const PN_BZASE_ENERGY := 60000.0
const PN_BZASE_RAD_RELEASE_THRESHOLD := 60000.0
const PN_BZASE_RAD_RANGE_DIVISOR := 1.5
const PN_BZASE_RAD_THRESHOLD := 0.3
const ANTINOBLIUM_CONVERSION_DIVISOR := 90.0

const G := {"o2": Defs.G_O2, "n2": Defs.G_N2, "co2": Defs.G_CO2, "plasma": Defs.G_PLASMA, "n2o": Defs.G_N2O,
	"h2o": Defs.G_H2O, "trit": Defs.G_TRITIUM, "nob": Defs.G_HYPERNOB, "nitrium": Defs.G_NITRIUM, "bz": Defs.G_BZ,
	"pluox": Defs.G_PLUOXIUM, "miasma": Defs.G_MIASMA, "freon": Defs.G_FREON, "h2": Defs.G_HYDROGEN,
	"healium": Defs.G_HEALIUM, "pn": Defs.G_PROTO_NITRATE, "zauker": Defs.G_ZAUKER, "halon": Defs.G_HALON,
	"he": Defs.G_HELIUM, "antinob": Defs.G_ANTINOB}

## [id, priority, requirements {gas: moles}, min temp, max temp] in tg's file order within each
## priority group (1 pre-formation, 2 formation, 3 post-formation, 4 fire). -1: no limit.
const REACTIONS := [
	["nitrium_decomposition", 1, {Defs.G_O2: MINIMUM_MOLE_COUNT, Defs.G_NITRIUM: MINIMUM_MOLE_COUNT}, -1.0, NITRIUM_DECOMPOSITION_MAX_TEMP],
	["halon_o2removal", 1, {Defs.G_HALON: MINIMUM_MOLE_COUNT, Defs.G_O2: MINIMUM_MOLE_COUNT}, HALON_COMBUSTION_MIN_TEMPERATURE, -1.0],
	["proto_nitrate_hydrogen_response", 1, {Defs.G_PROTO_NITRATE: MINIMUM_MOLE_COUNT, Defs.G_HYDROGEN: PN_HYDROGEN_CONVERSION_THRESHOLD}, -1.0, -1.0],
	["proto_nitrate_tritium_response", 1, {Defs.G_PROTO_NITRATE: MINIMUM_MOLE_COUNT, Defs.G_TRITIUM: MINIMUM_MOLE_COUNT}, PN_TRITIUM_CONVERSION_MIN_TEMP, PN_TRITIUM_CONVERSION_MAX_TEMP],
	["proto_nitrate_bz_response", 1, {Defs.G_PROTO_NITRATE: MINIMUM_MOLE_COUNT, Defs.G_BZ: MINIMUM_MOLE_COUNT}, PN_BZASE_MIN_TEMP, PN_BZASE_MAX_TEMP],
	["nitrousformation", 2, {Defs.G_O2: 10.0, Defs.G_N2: 20.0, Defs.G_BZ: 5.0}, N2O_FORMATION_MIN_TEMPERATURE, N2O_FORMATION_MAX_TEMPERATURE],
	["bzformation", 2, {Defs.G_N2O: 10.0, Defs.G_PLASMA: 10.0}, -1.0, BZ_FORMATION_MAX_TEMPERATURE],
	["pluox_formation", 2, {Defs.G_CO2: MINIMUM_MOLE_COUNT, Defs.G_O2: MINIMUM_MOLE_COUNT, Defs.G_TRITIUM: MINIMUM_MOLE_COUNT}, PLUOXIUM_FORMATION_MIN_TEMP, PLUOXIUM_FORMATION_MAX_TEMP],
	["nitrium_formation", 2, {Defs.G_TRITIUM: 20.0, Defs.G_N2: 10.0, Defs.G_BZ: 5.0}, NITRIUM_FORMATION_MIN_TEMP, -1.0],
	["freonformation", 2, {Defs.G_PLASMA: MINIMUM_MOLE_COUNT * 6.0, Defs.G_CO2: MINIMUM_MOLE_COUNT * 3.0, Defs.G_BZ: MINIMUM_MOLE_COUNT}, FREON_FORMATION_MIN_TEMPERATURE, -1.0],
	["nobliumformation", 2, {Defs.G_N2: 10.0, Defs.G_TRITIUM: 5.0}, NOBLIUM_FORMATION_MIN_TEMP, NOBLIUM_FORMATION_MAX_TEMP],
	["healium_formation", 2, {Defs.G_BZ: MINIMUM_MOLE_COUNT, Defs.G_FREON: MINIMUM_MOLE_COUNT}, HEALIUM_FORMATION_MIN_TEMP, HEALIUM_FORMATION_MAX_TEMP],
	["zauker_formation", 2, {Defs.G_HYPERNOB: MINIMUM_MOLE_COUNT, Defs.G_NITRIUM: MINIMUM_MOLE_COUNT}, ZAUKER_FORMATION_MIN_TEMPERATURE, ZAUKER_FORMATION_MAX_TEMPERATURE],
	["proto_nitrate_formation", 2, {Defs.G_PLUOXIUM: MINIMUM_MOLE_COUNT, Defs.G_HYDROGEN: MINIMUM_MOLE_COUNT}, PN_FORMATION_MIN_TEMPERATURE, PN_FORMATION_MAX_TEMPERATURE],
	["antinoblium_replication", 2, {Defs.G_ANTINOB: MOLES_GAS_VISIBLE}, REACTION_OPPRESSION_MIN_TEMP, -1.0],
	["water_vapor", 3, {Defs.G_H2O: MOLES_GAS_VISIBLE}, -1.0, WATER_VAPOR_CONDENSATION_POINT],
	["miaster", 3, {Defs.G_MIASMA: MINIMUM_MOLE_COUNT}, MIASTER_STERILIZATION_TEMP, -1.0],
	["nitrous_decomp", 3, {Defs.G_N2O: MINIMUM_MOLE_COUNT * 2.0}, N2O_DECOMPOSITION_MIN_TEMPERATURE, N2O_DECOMPOSITION_MAX_TEMPERATURE],
	["zauker_decomp", 3, {Defs.G_N2: MINIMUM_MOLE_COUNT, Defs.G_ZAUKER: MINIMUM_MOLE_COUNT}, -1.0, -1.0],
	["plasmafire", 4, {Defs.G_PLASMA: MINIMUM_MOLE_COUNT, Defs.G_O2: MINIMUM_MOLE_COUNT}, PLASMA_MINIMUM_BURN_TEMPERATURE, -1.0],
	["h2fire", 4, {Defs.G_HYDROGEN: MINIMUM_MOLE_COUNT, Defs.G_O2: MINIMUM_MOLE_COUNT}, HYDROGEN_MINIMUM_BURN_TEMPERATURE, -1.0],
	["tritfire", 4, {Defs.G_TRITIUM: MINIMUM_MOLE_COUNT, Defs.G_O2: MINIMUM_MOLE_COUNT}, TRITIUM_MINIMUM_BURN_TEMPERATURE, -1.0],
	["freonfire", 4, {Defs.G_O2: MINIMUM_MOLE_COUNT, Defs.G_FREON: MINIMUM_MOLE_COUNT}, FREON_TERMINAL_TEMPERATURE, FREON_MAXIMUM_BURN_TEMPERATURE],
]

# ------------------------------------------------------------------ the reaction step
## One tg react() on a mixture. `ctx`: {"m": Array of moles, "t": temperature, "v": volume (L),
## "cell": Vector2i (a tile) or (-1, -1), "net": a PipeNet or null}. Changes ctx in place and
## returns tg's reaction_results ({} when nothing reacted).
static func react(ctx: Dictionary) -> Dictionary:
	var m: Array = ctx["m"]
	if m[Defs.G_HYPERNOB] >= REACTION_OPPRESSION_THRESHOLD and ctx["t"] > REACTION_OPPRESSION_MIN_TEMP:
		return {}
	var res := {}
	var temp0: float = ctx["t"]
	for r in REACTIONS:
		if (r[3] >= 0.0 and temp0 < r[3]) or (r[4] >= 0.0 and temp0 > r[4]):
			continue
		var ok := true
		for g in r[2]:
			if m[g] < r[2][g]:
				ok = false
				break
		if not ok:
			continue
		var amount: float = _run(r[0], ctx)
		if amount != 0.0:
			res[r[0]] = amount
	for g in Defs.GAS_COUNT:
		if m[g] < 0.0:
			m[g] = 0.0
	return res

static func _run(id: String, ctx: Dictionary) -> float:
	match id:
		"water_vapor": return _water_vapor(ctx)
		"miaster": return _miaster(ctx)
		"plasmafire": return _plasmafire(ctx)
		"h2fire": return _h2fire(ctx)
		"tritfire": return _tritfire(ctx)
		"freonfire": return _freonfire(ctx)
		"nitrousformation": return _nitrousformation(ctx)
		"nitrous_decomp": return _nitrous_decomp(ctx)
		"bzformation": return _bzformation(ctx)
		"pluox_formation": return _pluox_formation(ctx)
		"nitrium_formation": return _nitrium_formation(ctx)
		"nitrium_decomposition": return _nitrium_decomposition(ctx)
		"freonformation": return _freonformation(ctx)
		"nobliumformation": return _nobliumformation(ctx)
		"halon_o2removal": return _halon_o2removal(ctx)
		"healium_formation": return _healium_formation(ctx)
		"zauker_formation": return _zauker_formation(ctx)
		"zauker_decomp": return _zauker_decomp(ctx)
		"proto_nitrate_formation": return _pn_formation(ctx)
		"proto_nitrate_hydrogen_response": return _pn_hydrogen(ctx)
		"proto_nitrate_tritium_response": return _pn_tritium(ctx)
		"proto_nitrate_bz_response": return _pn_bz(ctx)
		"antinoblium_replication": return _antinob(ctx)
	return 0.0

# ------------------------------------------------------------------ helpers
static func hc(m: Array) -> float:
	var c := 0.0
	for g in Defs.GAS_COUNT:
		if m[g] > 0.0:
			c += m[g] * Defs.GAS_SPECIFIC_HEAT[g]
	return c

static func total(m: Array) -> float:
	var t := 0.0
	for g in Defs.GAS_COUNT:
		t += m[g]
	return t

static func quantize(v: float) -> float:
	return snappedf(v, MOLAR_ACCURACY)

static func inv(x: float) -> float:
	return 1.0 / x if x != 0.0 else INF

## air.temperature = (temperature * old_hc + energy) / new_hc, floored at TCMB
static func _heat(ctx: Dictionary, t_old: float, old_hc: float, energy: float) -> void:
	var nhc := hc(ctx["m"])
	if nhc > MINIMUM_HEAT_CAPACITY:
		ctx["t"] = maxf((t_old * old_hc + energy) / nhc, TCMB)

static func _location_cell(ctx: Dictionary) -> Vector2i:
	if ctx["cell"].x >= 0:
		return ctx["cell"]
	var net = ctx.get("net")
	if net and not net.cells.is_empty():
		return Game.map.cell_of(net.cells[randi() % net.cells.size()])
	return Vector2i(-1, -1)

static func _expose(ctx: Dictionary) -> void:
	var c: Vector2i = ctx["cell"]
	if c.x >= 0 and Game.atmos and ctx["t"] > FIRE_MINIMUM_TEMPERATURE_TO_EXIST:
		Game.atmos.hotspot_expose(c, ctx["t"], CELL_VOLUME)

# ------------------------------------------------------------------ the reactions
## Steam condensation / deposition: wets the floor, or frosts it over below 200 K.
static func _water_vapor(ctx: Dictionary) -> float:
	var c: Vector2i = ctx["cell"]
	if c.x < 0:
		return 0.0
	var consumed := 0.0
	var map: StationMap = Game.map
	if ctx["t"] <= WATER_VAPOR_DEPOSITION_POINT:
		if Liquids.spill(c, "ice", 2.0) != null:
			consumed = MOLES_GAS_VISIBLE
	elif map.has_floor_tile(c) or map.get_turf(c) == Defs.T_PLATING:
		Liquids.spill(c, "water", 2.0)
		consumed = MOLES_GAS_VISIBLE
	if consumed > 0.0:
		ctx["m"][Defs.G_H2O] -= consumed
	return consumed

## Dry heat sterilization: hot, dry air turns miasma back into oxygen.
static func _miaster(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var h2o: float = m[Defs.G_H2O]
	if h2o > 0.0 and h2o / total(m) > MIASTER_STERILIZATION_MAX_HUMIDITY:
		return 0.0
	var cleaned: float = minf(m[Defs.G_MIASMA], MIASTER_STERILIZATION_RATE_BASE + (ctx["t"] - MIASTER_STERILIZATION_TEMP) / MIASTER_STERILIZATION_RATE_SCALE)
	m[Defs.G_MIASMA] -= cleaned
	m[Defs.G_O2] += cleaned
	ctx["t"] += cleaned * MIASTER_STERILIZATION_ENERGY
	return cleaned

static func _plasmafire(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var t: float = ctx["t"]
	var scale := 1.0
	if t <= PLASMA_UPPER_TEMPERATURE:
		scale = (t - PLASMA_MINIMUM_BURN_TEMPERATURE) / (PLASMA_UPPER_TEMPERATURE - PLASMA_MINIMUM_BURN_TEMPERATURE)
		if scale <= 0.0:
			return 0.0
	var o2_ratio := OXYGEN_BURN_RATIO_BASE - scale
	var o2: float = m[Defs.G_O2]
	var pl: float = m[Defs.G_PLASMA]
	var rate := 0.0
	var super_sat := false
	var ratio: float = o2 / pl if pl > 0.0 else INF
	if ratio >= SUPER_SATURATION_THRESHOLD:
		rate = (pl / PLASMA_BURN_RATE_DELTA) * scale
		super_sat = true
	elif ratio >= PLASMA_OXYGEN_FULLBURN:
		rate = (pl / PLASMA_BURN_RATE_DELTA) * scale
	else:
		rate = ((o2 / PLASMA_OXYGEN_FULLBURN) / PLASMA_BURN_RATE_DELTA) * scale
	if rate < MINIMUM_HEAT_CAPACITY:
		return 0.0
	var old_hc := hc(m)
	rate = minf(rate, minf(pl, o2 * inv(o2_ratio)))
	m[Defs.G_PLASMA] = quantize(pl - rate)
	m[Defs.G_O2] = quantize(o2 - rate * o2_ratio)
	if super_sat:
		m[Defs.G_TRITIUM] += rate
	else:
		m[Defs.G_CO2] += rate * 0.75
		m[Defs.G_H2O] += rate * 0.25
	_heat(ctx, t, old_hc, FIRE_PLASMA_ENERGY_RELEASED * rate)
	_expose(ctx)
	return rate * (1.0 + o2_ratio)

static func _h2fire(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var h2: float = m[Defs.G_HYDROGEN]
	var o2: float = m[Defs.G_O2]
	var old_hc := hc(m)
	var t: float = ctx["t"]
	var burned := minf(minf(h2 / FIRE_HYDROGEN_BURN_RATE_DELTA, o2 / (FIRE_HYDROGEN_BURN_RATE_DELTA * HYDROGEN_OXYGEN_FULLBURN)), minf(h2, o2 * inv(0.5)))
	if burned <= 0.0 or h2 - burned < -EPS or o2 - burned * 0.5 < -EPS:
		return 0.0
	m[Defs.G_HYDROGEN] -= burned
	m[Defs.G_O2] -= burned * 0.5
	m[Defs.G_H2O] += burned
	_heat(ctx, t, old_hc, FIRE_HYDROGEN_ENERGY_RELEASED * burned)
	_expose(ctx)
	return burned

static func _tritfire(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var tr: float = m[Defs.G_TRITIUM]
	var o2: float = m[Defs.G_O2]
	var old_hc := hc(m)
	var t: float = ctx["t"]
	var burned := minf(minf(tr / FIRE_TRITIUM_BURN_RATE_DELTA, o2 / (FIRE_TRITIUM_BURN_RATE_DELTA * TRITIUM_OXYGEN_FULLBURN)), minf(tr, o2 * inv(0.5)))
	if burned <= 0.0 or tr - burned < -EPS or o2 - burned * 0.5 < -EPS:
		return 0.0
	m[Defs.G_TRITIUM] -= burned
	m[Defs.G_O2] -= burned * 0.5
	m[Defs.G_H2O] += burned
	var energy := FIRE_TRITIUM_ENERGY_RELEASED * burned
	var loc := _location_cell(ctx)
	if loc.x >= 0 and burned > TRITIUM_RADIATION_MINIMUM_MOLES and energy > TRITIUM_RADIATION_RELEASE_THRESHOLD * pow(ctx["v"] / CELL_VOLUME, ATMOS_RADIATION_VOLUME_EXP) and randf() < 0.1:
		Radiation.pulse(loc, minf(sqrt(burned) / TRITIUM_RADIATION_RANGE_DIVISOR, GAS_REACTION_MAXIMUM_RADIATION_PULSE_RANGE), TRITIUM_RADIATION_THRESHOLD)
	_heat(ctx, t, old_hc, energy)
	_expose(ctx)
	return burned

## Freon + oxygen soaks up heat; cold enough, it can leave hot ice behind.
static func _freonfire(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var t: float = ctx["t"]
	var scale := 0.0
	if t < FREON_TERMINAL_TEMPERATURE:
		scale = 0.0
	elif t < FREON_LOWER_TEMPERATURE:
		scale = 0.5
	else:
		scale = (FREON_MAXIMUM_BURN_TEMPERATURE - t) / (FREON_MAXIMUM_BURN_TEMPERATURE - FREON_TERMINAL_TEMPERATURE)
	if scale <= 0.0:
		return 0.0
	var o2_ratio := OXYGEN_BURN_RATIO_BASE - scale
	var fr: float = m[Defs.G_FREON]
	var o2: float = m[Defs.G_O2]
	var rate := 0.0
	if o2 < fr * FREON_OXYGEN_FULLBURN:
		rate = ((o2 / FREON_OXYGEN_FULLBURN) / FREON_BURN_RATE_DELTA) * scale
	else:
		rate = (fr / FREON_BURN_RATE_DELTA) * scale
	if rate < MINIMUM_HEAT_CAPACITY:
		return 0.0
	var old_hc := hc(m)
	rate = minf(rate, minf(fr, o2 * inv(o2_ratio)))
	m[Defs.G_FREON] = quantize(fr - rate)
	m[Defs.G_O2] = quantize(o2 - rate * o2_ratio)
	m[Defs.G_CO2] += rate
	if t < HOT_ICE_FORMATION_MAXIMUM_TEMPERATURE and t > HOT_ICE_FORMATION_MINIMUM_TEMPERATURE and randf() * 100.0 < HOT_ICE_FORMATION_PROB and ctx["cell"].x >= 0:
		if Proto.P.has("hot_ice"):
			Proto.spawn("hot_ice", ctx["cell"])
	var nhc := hc(m)
	if nhc > MINIMUM_HEAT_CAPACITY:
		ctx["t"] = maxf((t * old_hc - FIRE_FREON_ENERGY_CONSUMED * rate) / nhc, TCMB)
	var c: Vector2i = ctx["cell"]
	if c.x >= 0 and Game.atmos and ctx["t"] < FREON_MAXIMUM_BURN_TEMPERATURE:
		Game.atmos.hotspot_expose(c, ctx["t"], CELL_VOLUME)
	return rate * (1.0 + o2_ratio)

## N2O formation, with BZ as the catalyst.
static func _nitrousformation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var o2: float = m[Defs.G_O2]
	var n2: float = m[Defs.G_N2]
	var eff := minf(o2 * inv(0.5), n2)
	if o2 - eff * 0.5 < -EPS or n2 - eff < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_O2] -= eff * 0.5
	m[Defs.G_N2] -= eff
	m[Defs.G_N2O] += eff
	_heat(ctx, ctx["t"], old_hc, eff * N2O_FORMATION_ENERGY)
	return eff

static func _nitrous_decomp(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var n2o: float = m[Defs.G_N2O]
	var t: float = ctx["t"]
	var burned := (n2o / N2O_DECOMPOSITION_RATE_DIVISOR) * ((t - N2O_DECOMPOSITION_MIN_SCALE_TEMP) * (t - N2O_DECOMPOSITION_MAX_SCALE_TEMP) / N2O_DECOMPOSITION_SCALE_DIVISOR)
	if burned <= 0.0 or n2o - burned < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_N2O] -= burned
	m[Defs.G_N2] += burned
	m[Defs.G_O2] += burned / 2.0
	var nhc := hc(m)
	if nhc > MINIMUM_HEAT_CAPACITY:
		ctx["t"] = (t * old_hc + N2O_DECOMPOSITION_ENERGY * burned) / nhc
	return burned

## BZ: nitrous oxide and plasma, better at low pressure and large volume.
static func _bzformation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var n2o: float = m[Defs.G_N2O]
	var pl: float = m[Defs.G_PLASMA]
	var pressure: float = total(m) * R_IDEAL * ctx["t"] / ctx["v"]
	if pressure <= 0.0:
		return 0.0
	var env_eff: float = ctx["v"] / pressure
	var ratio_eff := minf(n2o / pl, 1.0)
	var decomposed := maxf(4.0 * (pl / (n2o + pl) - 0.75), 0.0)
	var bz := minf(minf(0.01 * ratio_eff * env_eff, n2o * inv(0.4)), pl * inv(0.8 * (1.0 - decomposed)))
	if n2o - bz * 0.4 < -EPS or pl - 0.8 * bz * (1.0 - decomposed) < -EPS or bz <= 0.0:
		return 0.0
	var old_hc := hc(m)
	if decomposed > 0.0:
		var amt := 0.4 * bz * decomposed
		m[Defs.G_N2] += amt
		m[Defs.G_O2] += 0.5 * amt
	m[Defs.G_BZ] += bz * (1.0 - decomposed)
	m[Defs.G_N2O] -= 0.4 * bz
	m[Defs.G_PLASMA] -= 0.8 * bz * (1.0 - decomposed)
	_heat(ctx, ctx["t"], old_hc, bz * (BZ_FORMATION_ENERGY + decomposed * (N2O_DECOMPOSITION_ENERGY - BZ_FORMATION_ENERGY)))
	return bz

static func _pluox_formation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var co2: float = m[Defs.G_CO2]
	var o2: float = m[Defs.G_O2]
	var tr: float = m[Defs.G_TRITIUM]
	var made := minf(minf(PLUOXIUM_FORMATION_MAX_RATE, co2), minf(o2 * inv(0.5), tr * inv(0.01)))
	if made <= 0.0 or co2 - made < -EPS or o2 - made * 0.5 < -EPS or tr - made * 0.01 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_CO2] -= made
	m[Defs.G_O2] -= made * 0.5
	m[Defs.G_TRITIUM] -= made * 0.01
	m[Defs.G_PLUOXIUM] += made
	m[Defs.G_HYDROGEN] += made * 0.01
	_heat(ctx, ctx["t"], old_hc, made * PLUOXIUM_FORMATION_ENERGY)
	return made

static func _nitrium_formation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var tr: float = m[Defs.G_TRITIUM]
	var n2: float = m[Defs.G_N2]
	var bz: float = m[Defs.G_BZ]
	var t: float = ctx["t"]
	var eff := minf(minf(t / NITRIUM_FORMATION_TEMP_DIVISOR, tr), minf(n2, bz * inv(0.05)))
	if eff <= 0.0 or tr - eff < -EPS or n2 - eff < -EPS or bz - eff * 0.05 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_TRITIUM] -= eff
	m[Defs.G_N2] -= eff
	m[Defs.G_BZ] -= eff * 0.05
	m[Defs.G_NITRIUM] += eff
	_heat(ctx, t, old_hc, -eff * NITRIUM_FORMATION_ENERGY)
	return eff

static func _nitrium_decomposition(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var ni: float = m[Defs.G_NITRIUM]
	var t: float = ctx["t"]
	var eff := minf(t / NITRIUM_DECOMPOSITION_TEMP_DIVISOR, ni)
	if eff <= 0.0 or ni - eff < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_NITRIUM] -= eff
	m[Defs.G_HYDROGEN] += eff
	m[Defs.G_N2] += eff
	_heat(ctx, t, old_hc, eff * NITRIUM_DECOMPOSITION_ENERGY)
	return eff

static func _freonformation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var pl: float = m[Defs.G_PLASMA]
	var co2: float = m[Defs.G_CO2]
	var bz: float = m[Defs.G_BZ]
	var t: float = ctx["t"]
	var minimal := minf(minf(pl * inv(0.6), bz * inv(0.1)), co2 * inv(0.3))
	var first := exp(-pow((t - 800.0) / 200.0, 2.0))
	var second := 3.0 / (1.0 + exp(-0.001 * (t - 6000.0)))
	var formed := minf(minf((first + second) * minimal * 0.05, pl * inv(0.6)), minf(co2 * inv(0.3), bz * inv(0.1)))
	if formed <= 0.0 or pl - formed * 0.6 < -EPS or co2 - formed * 0.3 < -EPS or bz - formed * 0.1 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_PLASMA] -= formed * 0.6
	m[Defs.G_CO2] -= formed * 0.3
	m[Defs.G_BZ] -= formed * 0.1
	m[Defs.G_FREON] += formed
	var consumed := (7000.0 / (1.0 + exp(-0.0015 * (t - 6000.0))) + 1000.0) * formed * 0.1
	_heat(ctx, t, old_hc, -consumed)
	return formed

static func _nobliumformation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var n2: float = m[Defs.G_N2]
	var tr: float = m[Defs.G_TRITIUM]
	var bz: float = m[Defs.G_BZ]
	var reduction := clampf(tr / (tr + bz), 0.001, 1.0)
	var formed := minf(minf((n2 + tr) * 0.01, tr * inv(5.0 * reduction)), n2 * inv(10.0))
	if quantize(formed) <= 0.0 or quantize(tr - 5.0 * formed * reduction) < -EPS or quantize(n2 - 10.0 * formed) < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_TRITIUM] -= 5.0 * formed * reduction
	m[Defs.G_N2] -= 10.0 * formed
	m[Defs.G_HYPERNOB] += formed
	_heat(ctx, ctx["t"], old_hc, formed * NOBLIUM_FORMATION_ENERGY / maxf(bz, 1.0))
	return formed

## Halon puts out fires: it takes oxygen out of hot air and cools it, leaving pluoxium.
static func _halon_o2removal(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var ha: float = m[Defs.G_HALON]
	var o2: float = m[Defs.G_O2]
	var t: float = ctx["t"]
	var eff := minf(minf(t / HALON_COMBUSTION_TEMPERATURE_SCALE, ha), o2 * inv(20.0))
	if eff <= 0.0 or ha - eff < -EPS or o2 - eff * 20.0 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_HALON] -= eff
	m[Defs.G_O2] -= eff * 20.0
	m[Defs.G_PLUOXIUM] += eff * 2.5
	_heat(ctx, t, old_hc, -eff * HALON_COMBUSTION_ENERGY)
	return eff * 5.0

static func _healium_formation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var bz: float = m[Defs.G_BZ]
	var fr: float = m[Defs.G_FREON]
	var t: float = ctx["t"]
	var eff := minf(minf(t * 0.3, fr * inv(2.75)), bz * inv(0.25))
	if eff <= 0.0 or fr - eff * 2.75 < -EPS or bz - eff * 0.25 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_FREON] -= eff * 2.75
	m[Defs.G_BZ] -= eff * 0.25
	m[Defs.G_HEALIUM] += eff * 3.0
	_heat(ctx, t, old_hc, eff * HEALIUM_FORMATION_ENERGY)
	return eff * 3.0

static func _zauker_formation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var nob: float = m[Defs.G_HYPERNOB]
	var ni: float = m[Defs.G_NITRIUM]
	var t: float = ctx["t"]
	var eff := minf(minf(t * ZAUKER_FORMATION_TEMPERATURE_SCALE, nob * inv(0.01)), ni * inv(0.5))
	if eff <= 0.0 or nob - eff * 0.01 < -EPS or ni - eff * 0.5 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_HYPERNOB] -= eff * 0.01
	m[Defs.G_NITRIUM] -= eff * 0.5
	m[Defs.G_ZAUKER] += eff * 0.5
	_heat(ctx, t, old_hc, -eff * ZAUKER_FORMATION_ENERGY)
	return eff * 0.5

static func _zauker_decomp(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var n2: float = m[Defs.G_N2]
	var za: float = m[Defs.G_ZAUKER]
	var burned := minf(ZAUKER_DECOMPOSITION_MAX_RATE, minf(n2, za))
	if burned <= 0.0 or za - burned < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_ZAUKER] -= burned
	m[Defs.G_O2] += burned * 0.3
	m[Defs.G_N2] += burned * 0.7
	_heat(ctx, ctx["t"], old_hc, ZAUKER_DECOMPOSITION_ENERGY * burned)
	return burned

static func _pn_formation(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var pl: float = m[Defs.G_PLUOXIUM]
	var h2: float = m[Defs.G_HYDROGEN]
	var t: float = ctx["t"]
	var eff := minf(minf(t * 0.005, pl * inv(0.2)), h2 * inv(2.0))
	if eff <= 0.0 or pl - eff * 0.2 < -EPS or h2 - eff * 2.0 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_HYDROGEN] -= eff * 2.0
	m[Defs.G_PLUOXIUM] -= eff * 0.2
	m[Defs.G_PROTO_NITRATE] += eff * 2.2
	_heat(ctx, t, old_hc, eff * PN_FORMATION_ENERGY)
	return eff * 2.2

static func _pn_hydrogen(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var pn: float = m[Defs.G_PROTO_NITRATE]
	var h2: float = m[Defs.G_HYDROGEN]
	var made := minf(PN_HYDROGEN_CONVERSION_MAX_RATE, minf(h2, pn))
	if made <= 0.0 or h2 - made < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_HYDROGEN] -= made
	m[Defs.G_PROTO_NITRATE] += made * 0.5
	_heat(ctx, ctx["t"], old_hc, -made * PN_HYDROGEN_CONVERSION_ENERGY)
	return made * 0.5

static func _pn_tritium(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var pn: float = m[Defs.G_PROTO_NITRATE]
	var tr: float = m[Defs.G_TRITIUM]
	var t: float = ctx["t"]
	var made := minf(minf(t / 34.0 * (tr * pn) / (tr + 10.0 * pn), tr), pn * inv(0.01))
	if tr - made < -EPS or pn - made * 0.01 < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_PROTO_NITRATE] -= made * 0.01
	m[Defs.G_TRITIUM] -= made
	m[Defs.G_HYDROGEN] += made
	var energy := made * PN_TRITIUM_CONVERSION_ENERGY
	var loc := _location_cell(ctx)
	if loc.x >= 0 and energy > PN_TRITIUM_CONVERSION_RAD_RELEASE_THRESHOLD * pow(ctx["v"] / CELL_VOLUME, ATMOS_RADIATION_VOLUME_EXP):
		Radiation.pulse(loc, minf(sqrt(made) / PN_TRITIUM_RAD_RANGE_DIVISOR, GAS_REACTION_MAXIMUM_RADIATION_PULSE_RANGE), PN_TRITIUM_RAD_THRESHOLD)
	if energy != 0.0:
		_heat(ctx, t, old_hc, energy)
	return made

static func _pn_bz(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var pn: float = m[Defs.G_PROTO_NITRATE]
	var bz: float = m[Defs.G_BZ]
	var t: float = ctx["t"]
	var used := minf(minf(t / 2240.0 * bz * pn / (bz + pn), bz), pn)
	if used <= 0.0 or bz - used < -EPS:
		return 0.0
	var old_hc := hc(m)
	m[Defs.G_BZ] -= used
	m[Defs.G_N2] += used * 0.4
	m[Defs.G_HELIUM] += used * 1.6
	m[Defs.G_PLASMA] += used * 0.8
	var energy := used * PN_BZASE_ENERGY
	var loc := _location_cell(ctx)
	if loc.x >= 0 and energy > PN_BZASE_RAD_RELEASE_THRESHOLD * pow(ctx["v"] / CELL_VOLUME, ATMOS_RADIATION_VOLUME_EXP):
		Radiation.pulse(loc, minf(sqrt(used) / PN_BZASE_RAD_RANGE_DIVISOR, GAS_REACTION_MAXIMUM_RADIATION_PULSE_RANGE), PN_BZASE_RAD_THRESHOLD)
		Radiation.hallucination_pulse(loc, 1, used * 2.0)
	_heat(ctx, t, old_hc, energy)
	return used

## Anti-noblium turns everything else in the mix into more of itself.
static func _antinob(ctx: Dictionary) -> float:
	var m: Array = ctx["m"]
	var heat_capacity := hc(m)
	var tot := total(m)
	var an: float = m[Defs.G_ANTINOB]
	var others := tot - an
	var rate := minf(an / ANTINOBLIUM_CONVERSION_DIVISOR, others)
	var clear := others < MINIMUM_MOLE_COUNT
	if clear:
		rate = others
	for g in Defs.GAS_COUNT:
		if g == Defs.G_ANTINOB:
			continue
		if clear:
			m[g] = 0.0
		elif others > 0.0:
			m[g] -= rate * m[g] / others
	m[Defs.G_ANTINOB] += rate
	var nhc := hc(m)
	if nhc > MINIMUM_HEAT_CAPACITY:
		ctx["t"] = maxf(ctx["t"] * heat_capacity / nhc, TCMB)
	return rate
