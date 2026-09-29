class_name CTank extends Component
## Gas tank for internals (tg: /obj/item/tank). Holds oxygen for breathing through a mask.

var gas := "o2"
var moles := 20.0
var max_moles := 20.0
var volume := 70.0 # litres (tg: internals tanks 70 L, canisters 1000 L)
var distribute_pressure := Defs.ONE_ATMOS # tg: oxygen tanks release at 16 kPa, others at one atmosphere

func key() -> StringName:
	return &"tank"

func setup(p: Dictionary) -> CTank:
	gas = p.get("gas", gas)
	moles = p.get("moles", moles)
	max_moles = moles
	volume = p.get("volume", volume)
	distribute_pressure = p.get("release", Defs.TANK_DEFAULT_RELEASE_PRESSURE if gas == "o2" else Defs.ONE_ATMOS)
	return self

## tg /obj/item/tank/remove_air_volume(BREATH_VOLUME): one breath at the release pressure
## (never more than the tank has). Returns moles of each gas.
func breath_mix() -> PackedFloat32Array:
	var pr := minf(pressure_kpa(), distribute_pressure)
	var want := pr * Defs.BREATH_VOLUME / (Defs.R_IDEAL * Defs.T20C)
	return take(minf(want, moles))

func pressure_kpa() -> float:
	return moles * Defs.R_IDEAL * Defs.T20C / volume

## Take one breath's worth. Returns O2 partial pressure the lungs get.
func breathe() -> float:
	if moles <= 0.0:
		return 0.0
	if gas == "mix":
		take(0.01)
		var tot := _mix_total()
		if tot <= 0.0:
			return 0.0
		if mix[Defs.G_PLASMA] / tot > 0.1:
			return -1.0
		return mix[Defs.G_O2] / tot * 100.0
	moles = maxf(0.0, moles - 0.01)
	if gas == "plasma":
		return -1.0
	return 21.0 if gas == "air" else 100.0

# ------------------------------------------------------------------ mixed contents
## tg tanks hold a whole gas mixture. Ours are one named gas, or "mix" with `mix` holding
## moles of each (a canister filled off the pipes, a portable scrubber's catch).
var mix := PackedFloat32Array()

## Tank / canister contents codes (tg canister kinds) -> gas.
const GAS_ID := {"o2": Defs.G_O2, "n2": Defs.G_N2, "co2": Defs.G_CO2, "plasma": Defs.G_PLASMA, "n2o": Defs.G_N2O, "h2o": Defs.G_H2O,
	"tritium": Defs.G_TRITIUM, "nob": Defs.G_HYPERNOB, "nitrium": Defs.G_NITRIUM, "bz": Defs.G_BZ, "pluox": Defs.G_PLUOXIUM,
	"miasma": Defs.G_MIASMA, "freon": Defs.G_FREON, "h2": Defs.G_HYDROGEN, "healium": Defs.G_HEALIUM,
	"proto_nitrate": Defs.G_PROTO_NITRATE, "zauker": Defs.G_ZAUKER, "halon": Defs.G_HALON, "he": Defs.G_HELIUM, "antinob": Defs.G_ANTINOB}

func _mix_total() -> float:
	var t := 0.0
	for v in mix:
		t += v
	return t

## Moles of each gas inside.
func composition() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(Defs.GAS_COUNT)
	if gas == "mix":
		for g in mini(mix.size(), Defs.GAS_COUNT):
			out[g] = mix[g]
	elif gas == "air":
		out[Defs.G_O2] = moles * 0.21
		out[Defs.G_N2] = moles * 0.79
	elif GAS_ID.has(gas):
		out[GAS_ID[gas]] = moles
	return out

func _set_composition(c: PackedFloat32Array) -> void:
	var tot := 0.0
	var top := -1
	for g in Defs.GAS_COUNT:
		tot += c[g]
		if top < 0 or c[g] > c[top]:
			top = g
	moles = tot
	if tot <= 0.0001:
		gas = ""
		mix = PackedFloat32Array()
		moles = 0.0
		return
	if c[top] / tot > 0.999:
		# pure again: back to a plain named gas
		for k in GAS_ID:
			if GAS_ID[k] == top:
				gas = k
		mix = PackedFloat32Array()
		return
	gas = "mix"
	mix = c

## Put gas in (moles of each).
func add_mix(add: PackedFloat32Array) -> void:
	var c := composition()
	for g in Defs.GAS_COUNT:
		c[g] += add[g]
	_set_composition(c)

## Take `amount` moles out, in proportion. Returns the moles of each taken.
func take(amount: float) -> PackedFloat32Array:
	var c := composition()
	var out := PackedFloat32Array()
	out.resize(Defs.GAS_COUNT)
	if moles <= 0.0:
		return out
	var f := clampf(amount / moles, 0.0, 1.0)
	for g in Defs.GAS_COUNT:
		out[g] = c[g] * f
		c[g] -= out[g]
	_set_composition(c)
	return out

## What's inside, for readouts: "Nitrogen 79%, Oxygen 21%".
func contents_text() -> String:
	if moles <= 0.0001:
		return "empty"
	var c := composition()
	var parts := []
	for g in Defs.GAS_COUNT:
		if c[g] / moles > 0.005:
			parts.append("%s %.0f%%" % [Defs.GAS_NAMES[g], c[g] / moles * 100.0])
	return ", ".join(parts)

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Pressure gauge: %.0f kPa." % pressure_kpa())

func ai_tags(out: Dictionary) -> void:
	if gas in ["o2", "air"] and moles > 1.0:
		out["air_tank"] = true
