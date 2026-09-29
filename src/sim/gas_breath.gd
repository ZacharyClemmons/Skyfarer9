class_name GasBreath extends RefCounted
## Human gas effects from tg code/modules/surgery/organs/internal/lungs/_lungs.dm.
## Pressures are kPa; this runs once per breath, not once per life tick.
## Disease uses this port's disease pool; irradiation uses its timed toxin model.

const STIMULATION_MIN := 0.002
const FILTERED := [Defs.G_PLASMA, Defs.G_N2O, Defs.G_BZ, Defs.G_TRITIUM,
	Defs.G_NITRIUM, Defs.G_FREON, Defs.G_MIASMA, Defs.G_HALON, Defs.G_ZAUKER, Defs.G_SMOKE,
	Defs.G_CO2, Defs.G_HYPERNOB, Defs.G_HEALIUM, Defs.G_PROTO_NITRATE]

static func top_up(h: CHealth, reagent: String, amount: float) -> void:
	h.chems[reagent] = maxf(h.chems.get(reagent, 0.0), amount)

static func apply(h: CHealth, pp: PackedFloat32Array, breath: PackedFloat32Array) -> void:
	# Metabolized gases are absorbed, not exhaled. BZ remains in the exhaled mix.
	for g in [Defs.G_PLUOXIUM, Defs.G_FREON, Defs.G_HALON, Defs.G_HEALIUM,
		Defs.G_HELIUM, Defs.G_HYPERNOB, Defs.G_MIASMA, Defs.G_NITRIUM, Defs.G_ZAUKER]:
		breath[g] = 0.0
	if pp[Defs.G_PLUOXIUM] > STIMULATION_MIN:
		top_up(h, "pluoxium", 1.0)
	if pp[Defs.G_HYPERNOB] > STIMULATION_MIN:
		top_up(h, "hypernoblium", 1.0)
	if pp[Defs.G_BZ] > 1.0:
		h.chems["bz_metabolites"] = h.chems.get("bz_metabolites", 0.0) + clampf(pp[Defs.G_BZ], 1.0, 5.0)
	if pp[Defs.G_BZ] > 10.0 and Game.rng.randf() < 0.33:
		Organs.apply_damage(h, "brain", 3.0)
	var freon := pp[Defs.G_FREON]
	if freon > STIMULATION_MIN:
		h.chems["freon"] = h.chems.get("freon", 0.0) + 1.0
		h.adjust("burn", 15.0 if freon > 40.0 else freon / 4.0)
		if Body.prob(freon):
			Game.tell(h.e, "Your mouth feels like it's burning!", "bad")
		if freon > 40.0:
			Emotes.emote(h.e, "gasp")
		if freon > 40.0 and Game.rng.randf() * 100.0 < freon / 2.0:
			Game.tell(h.e, "Your throat closes up!", "bad")
			h.set_status_if_lower("silence", 6.0)
	if pp[Defs.G_HALON] > STIMULATION_MIN:
		h.adjust("oxy", 5.0)
		top_up(h, "halon", 1.0)
	# tg consume_healium: euphoria
	if pp[Defs.G_HEALIUM] > STIMULATION_MIN and Body.prob(15):
		Game.tell(h.e, "Your head starts spinning and your lungs burn!", "warn")
		Emotes.emote(h.e, "gasp")
	if pp[Defs.G_HEALIUM] > 3.0 and Game.rng.randf() < 0.3:
		h.sleep_for(Game.rng.randf_range(3.0, 5.0))
	if pp[Defs.G_HEALIUM] > 6.0:
		top_up(h, "healium", 1.0)
	h.helium_voice = pp[Defs.G_HELIUM] > 5.0
	var miasma := pp[Defs.G_MIASMA]
	if miasma > 0.0:
		if h.disease == null and Game.rng.randf() * 100.0 < miasma * 0.5:
			Disease.make_random().infect(h.e)
		if miasma > 5.0:
			h.disgust = minf(150.0, h.disgust + minf(miasma, 30.0))
		if miasma > 15.0 and Game.rng.randf() < (0.15 if miasma > 30.0 else 0.05):
			Organs.vomit(h)
	var nitrium := pp[Defs.G_NITRIUM]
	if nitrium > 0.0 and Body.prob(20):
		Emotes.emote(h.e, "burp") # tg too_much_nitrium
	if nitrium > 15.0 and Game.rng.randf() * 100.0 < nitrium:
		Organs.apply_damage(h, "lungs", nitrium * 0.1)
		Game.tell(h.e, "You feel a burning sensation in your chest", "warn")
	if nitrium > 5.0:
		top_up(h, "nitrium", 2.0)
	if nitrium > 10.0:
		top_up(h, "nitrosyl_plasmide", 2.0)
	var tritium := breath[Defs.G_TRITIUM]
	breath[Defs.G_TRITIUM] = 0.0
	if tritium > Defs.GAS_VISIBLE_AT[Defs.G_TRITIUM] * Defs.BREATH_PERCENTAGE:
		h.adjust("tox", clampf(tritium * 15.0, Defs.MIN_TOXIC_GAS_DAMAGE, Defs.MAX_TOXIC_GAS_DAMAGE))
	if pp[Defs.G_TRITIUM] > 1.0:
		var chance := lerpf(10.0, 60.0, clampf((pp[Defs.G_TRITIUM] - 1.0) / 14.0, 0.0, 1.0))
		if Game.rng.randf() * 100.0 < chance:
			h.set_status_if_lower("irradiated", 30.0)
	if pp[Defs.G_ZAUKER] > STIMULATION_MIN:
		top_up(h, "zauker", 1.0)
