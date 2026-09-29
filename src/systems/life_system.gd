class_name LifeSystem extends Node
## Per-frame: movement, timers, doors, do_afters.
## Per second (tg SSmobs / SSmachines): breathing, body temperature, pressure, fire,
## bleeding, needs, disease, trespassing; machines, heaters, kitchens, plants.

var acc := 0.0
var macc := 0.5 # offset from acc so the two per-second batches land on different frames
var _tick_q: Array = [] # health entities still owed this second's life_tick (spread over frames)
var _tick_i := 0
const TICK_SLICES := 10

func _init() -> void:
	process_priority = -20 # finish walking before hull transforms and camera follow

func _exit_tree() -> void:
	Genetics.clear_timers()

func _process(delta: float) -> void:
	var _pt := Perf.t0()
	_process_body(delta)
	Perf.add("life", _pt)

func _process_body(delta: float) -> void:
	if not Game.running or Game.paused:
		return
	var d := delta * Game.time_scale
	DoAfter.process(d)
	Genetics.process(d)
	for e in Game.all_with(&"statue"):
		e.c(&"statue").process(d)
	for e in Game.all_with(&"dna"):
		e.c(&"dna").process(d)
	for e in Game.all_with(&"monkeyai"):
		e.c(&"monkeyai").process(d)
	for e in Game.all_with(&"animalai"):
		e.c(&"animalai").process(d)
	for e in Game.all_with(&"beastai"):
		e.c(&"beastai").process(d)
	for e in Game.all_with(&"glider"):
		e.c(&"glider").process(d)
	for e in Game.all_with(&"grapple"):
		e.c(&"grapple").process(d)
	# Skyfarer: worn curios re-apply their effects on a short timer, held guns recharge,
	# gun mounts reload, condensers make their own fuel, and shopkeepers restock.
	for e in Game.all_with(&"curio"):
		e.c(&"curio").process(d)
	for e in Game.all_with(&"aethergun"):
		e.c(&"aethergun").process(d)
	for e in Game.all_with(&"shipgun"):
		e.c(&"shipgun").process(d)
	for e in Game.all_with(&"fuelbunker"):
		e.c(&"fuelbunker").process(d)
	for e in Game.all_with(&"vendor"):
		e.c(&"vendor").process(d)
		e.c(&"vendor").idle(d)
	for e in Game.all_with(&"mob"):
		var m: CMob = e.c(&"mob")
		m.process(d)
		var h: CHealth = e.c(&"health")
		if h:
			h.process(d)
			Psyker.process(e)
	for e in Game.all_with(&"door"):
		e.c(&"door").process(d)
	for e in Game.all_with(&"firelock"):
		e.c(&"firelock").process(d)
	for e in Game.all_with(&"vermin"):
		e.c(&"vermin").process(d)
	acc += d
	while acc >= 1.0:
		acc -= 1.0
		_run_life_ticks(_tick_q.size()) # finish leftovers, then queue a fresh batch
		_tick_q = Game.all_with(&"health")
		_tick_i = 0
	if _tick_i < _tick_q.size():
		_run_life_ticks(ceili(float(_tick_q.size()) / TICK_SLICES))
	macc += d
	while macc >= 1.0:
		macc -= 1.0
		machines_tick(1.0)

func _run_life_ticks(n: int) -> void:
	var end := mini(_tick_i + n, _tick_q.size())
	while _tick_i < end:
		var e = _tick_q[_tick_i]
		_tick_i += 1
		if is_instance_valid(e) and not e.removed:
			life_tick(e, 1.0)

# ------------------------------------------------------------------ machines
func machines_tick(dt: float) -> void:
	for e in Game.all_with(&"machine"):
		e.c(&"machine").tick(dt)
	for e in Game.all_with(&"heater"):
		e.c(&"heater").tick(dt)
	for e in Game.all_with(&"spaceheater"):
		e.c(&"spaceheater").tick(dt)
	for e in Game.all_with(&"cooker"):
		e.c(&"cooker").tick(dt)
	for e in Game.all_with(&"hydro"):
		e.c(&"hydro").tick(dt)
	for e in Game.all_with(&"furniture"):
		e.c(&"furniture").tick(dt)
	for e in Game.all_with(&"air_alarm"):
		e.c(&"air_alarm").tick(dt)
	for e in Game.all_with(&"firealarm"):
		e.c(&"firealarm").tick(dt)
	for e in Game.all_with(&"firelock"):
		e.c(&"firelock").tick(dt)
	for e in Game.all_with(&"lathe"):
		e.c(&"lathe").tick(dt)
	Research.tick_servers(dt)
	Cargo.tick(dt)
	for e in Game.all_with(&"fixture"):
		e.c(&"fixture").tick(dt)
	for e in Game.all_with(&"chemmachine"):
		e.c(&"chemmachine").tick(dt)
	for e in Game.all_with(&"decal"):
		if not e.removed:
			e.c(&"decal").tick(dt)
	for e in Game.all_with(&"melt"):
		e.c(&"melt").tick(dt)
	for e in Game.all_with(&"statusdisplay"):
		e.c(&"statusdisplay").tick(dt)
	for e in Game.all_with(&"meter"):
		e.c(&"meter").tick(dt)
	for e in Game.all_with(&"fueltank"):
		e.c(&"fueltank").tick(dt)
	for e in Game.all_with(&"welder"):
		e.c(&"welder").tick(dt)
	for e in Game.all_with(&"molotov"):
		e.c(&"molotov").tick(dt)
	for e in Game.all_with(&"gadget"):
		e.c(&"gadget").tick(dt)
	for e in Game.all_with(&"recharger"):
		e.c(&"recharger").tick(dt)
	for e in Game.all_with(&"dnascanner"):
		e.c(&"dnascanner").tick(dt)
	for e in Game.all_with(&"skillstation"):
		e.c(&"skillstation").tick(dt)
	for e in Game.all_with(&"dnaconsole"):
		e.c(&"dnaconsole").tick(dt)
	for e in Game.all_with(&"flammable"):
		var f: CFlammable = e.c(&"flammable")
		if f.burning > 0 and e.holder == null and Game.atmos and not Game.atmos.hotspots.has(e.cell):
			Game.atmos.ignite(e.cell, null, 3.0)
	for e in Game.all_with(&"canister"):
		e.c(&"canister").tick(dt)
	for e in Game.all_with(&"tank"):
		var tk: CTank = e.c(&"tank")
		if tk.moles > 200 and e.has_c(&"blocker") and tk.get_meta("ruptured", false):
			_vent_canister(e, tk)

func _vent_canister(e: Entity, tk: CTank) -> void:
	var g := {"o2": Defs.G_O2, "n2": Defs.G_N2, "plasma": Defs.G_PLASMA, "air": Defs.G_N2}.get(tk.gas, Defs.G_N2)
	var amt := minf(tk.moles, 60.0)
	tk.moles -= amt
	Game.atmos.add_gas(Game.map.idx(e.cell), g, amt, Defs.T20C)

# ------------------------------------------------------------------ mob life
func life_tick(e: Entity, dt: float) -> void:
	var h: CHealth = e.c(&"health")
	var m: CMob = e.c(&"mob")
	var n: CNeeds = e.c(&"needs")
	var inv: CInventory = e.c(&"inv")
	# tg carbon/Life (every 2 s, SSMOBS_DT): the hit flash lasts until the next Life tick
	if int(Game.time) % 2 == 0:
		h.damageoverlaytemp = 0.0
	# tg carbon/handle_organs: organs work (or decay, once dead) before anything else
	Organs.tick(h, dt)
	# tg SSmood (1 s) and the quirks that process
	var md: CMood = e.c(&"mood")
	if md:
		md.tick(dt)
	Quirks.tick(e, dt)
	Addiction.tick(h, dt)
	# tg genetics: mutations' on_life, genetic damage, the meltdown timer
	var dn: CDna = e.c(&"dna")
	if dn:
		dn.tick(dt)
		if e.removed:
			return
	if h.dead:
		return
	var at: AtmosSystem = Game.atmos
	var c := e.root_cell()
	var i := Game.map.idx(c)
	var p := at.pressure(i)
	var env_t := at.temp[i]
	# ---------------- breathing (tg carbon/breathe + lungs/check_breath)
	_breathe(e, h, m, inv, i, dt)
	# tg carbon/Life: failing to breathe is its own moodlet
	if h.failed_last_breath:
		CMood.event(e, "suffocation", "suffocation")
	else:
		CMood.clear_event(e, "suffocation")
	# ---------------- temperature (tg species/handle_body_temperature)
	_body_temperature(e, h, inv, env_t, dt)
	# ---------------- pressure (tg species/handle_environment_pressure)
	# a sealed suit and helmet (tg STOPSPRESSUREDAMAGE) keep you at a safe pressure
	var sealed := false
	if inv:
		var su: Entity = inv.worn("suit")
		var hd: Entity = inv.worn("head")
		sealed = su != null and hd != null and su.has_c(&"clothing") and hd.has_c(&"clothing") and su.c(&"clothing").pressure_proof and hd.c(&"clothing").pressure_proof
	if sealed:
		h.low_pressure_t = 0.0
		h.pressure_status = "ok"
	elif p < Defs.HAZARD_LOW_PRESSURE and h.traits.has("resistlowpressure"):
		h.low_pressure_t = 0.0
		h.pressure_status = "ok" # tg TRAIT_RESISTLOWPRESSURE
	elif p > Defs.HAZARD_HIGH_PRESSURE and h.traits.has("resisthighpressure"):
		h.pressure_status = "ok" # tg TRAIT_RESISTHIGHPRESSURE
	elif p < Defs.HAZARD_LOW_PRESSURE:
		# starts at 2/s and grows the longer you're in it, up to 5/s
		h.low_pressure_t += dt
		h.adjust("brute", minf(snappedf(1.0 + h.low_pressure_t / 80.0, 0.05) * 2.0, 5.0) * dt)
		h.pressure_status = "low"
	elif p > Defs.HAZARD_HIGH_PRESSURE:
		h.low_pressure_t = 0.0
		h.adjust("brute", minf((p / Defs.HAZARD_HIGH_PRESSURE - 1.0) * 2.0, 2.0) * dt)
		h.pressure_status = "high"
	else:
		h.low_pressure_t = 0.0
		h.pressure_status = "ok"
	# ---------------- fire
	if h.on_fire > 0:
		h.adjust("burn", 3.0 * dt)
		h.body_temp += 4.0 * dt
		h.on_fire -= dt * (3.0 if h.lying() else 1.0)
		if at.can_burn(i) and Game.rng.randf() < 0.3:
			at.ignite(c, null, 2.0)
		if at.partial(i, Defs.G_O2) < 5.0:
			h.on_fire = 0.0
		if not e.get_node_or_null("Flame"):
			Fx.flame_on(e)
	elif e.get_node_or_null("Flame"):
		Fx.flame_off(e)
	# ---------------- blood, wounds and the bloodstream (tg handle_blood, metabolize)
	Body.handle(h, dt)
	Chem.metabolize(h, dt)
	# tg handle_brain_damage: the traumas act
	Traumas.tick(h, dt)
	Traumas.trance_tick(h)
	# tg /datum/status_effect/hallucination
	Hallucinations.tick(h, dt)
	# tg /datum/embedding/process
	Embeds.tick(h, dt)
	# ---------------- needs
	if n:
		n.tick(dt, 1.3 if h.body_temp < Defs.BODYTEMP_COLD_DAMAGE_LIMIT else 1.0)
		var comfort_target := 85.0
		if h.body_temp < 295:
			comfort_target -= (295 - h.body_temp) * 2.0
		if env_t < 283:
			comfort_target -= (283 - env_t) * 0.4
		comfort_target -= h.pain * 0.4
		if Game.map.is_outdoor(c):
			comfort_target -= 10
		n.comfort = move_toward(n.comfort, clampf(comfort_target, 0, 100), dt * 1.5)
		if n.nutrition <= 0:
			h.adjust("stamina", 1.0 * dt)
			h.adjust("tox", 0.05 * dt)
		if n.hydration <= 0:
			h.adjust("tox", 0.15 * dt)
		if n.energy <= 0 and not h.sleeping:
			Game.visible_message(c, "%s collapses from exhaustion." % e.display_name)
			h.fall_asleep()
	# natural recovery
	if not h.in_crit() and (n == null or n.nutrition > 25):
		var rate := 0.03 if not h.sleeping else 0.12
		h.adjust("brute", -rate * dt)
		h.adjust("burn", -rate * dt)
		h.adjust("tox", -rate * 0.5 * dt)
	if h.disease != null:
		h.disease.tick(e)
	# ---------------- wind (space-wind, arctic style)
	var w := at.wind_at(c)
	if w.length() > 1.2 and not h.lying() and not m.moving and Game.rng.randf() < clampf(w.length() / 6.0, 0.0, 0.8):
		var d := Vector2i(signi(roundi(w.x)), signi(roundi(w.y)))
		if d != Vector2i.ZERO and m.push(d):
			Game.tell(e, "The wind drags you along!", "warn")
	# ---------------- trespass
	var aid := Game.map.area[i]
	if aid != m.last_area:
		m.last_area = aid
		m.trespass_t = 0.0
	var ar: Area = Game.map.areas[aid]
	if not ar.restricted.is_empty() and inv:
		var ok := false
		for tag in ar.restricted:
			if inv.has_access(tag):
				ok = true
				break
		if not ok:
			m.trespass_t -= dt
			if m.trespass_t <= 0:
				m.trespass_t = 12.0
				Bus.stimulus.emit({"type": "trespass", "actor": e, "cell": c, "loud": 0.0, "illegal": true, "text": ar.name})

## tg breathing. A breath every 8 s (every 2 s while the last one failed): 1.99 L of the
## tile's air (or of internals, at the tank's release pressure), judged by the partial
## pressures in it. The oxygen breathed goes back out as CO2.
func _breathe(e: Entity, h: CHealth, m: CMob, inv: CInventory, i: int, dt: float) -> void:
	h.breath_t -= dt
	# tg: hard crit misses every breath, soft crit one in four
	if h.in_crit():
		h.losebreath += (1.0 if h.health() <= CHealth.HARD_CRIT else 0.25) * dt / 2.0
	if h.breath_t > 0.0:
		return
	# tg handle_breathing: every 4th tick, sooner with bad lungs or a bad heart
	h.breath_t = Defs.BREATH_INTERVAL_FAILING if h.failed_last_breath else Organs.breath_interval(h)
	# tg breathe: failing lungs miss the breath
	if Organs.lungs_failing(h):
		h.losebreath += 1.0
	var at: AtmosSystem = Game.atmos
	var breath := PackedFloat32Array()
	breath.resize(Defs.GAS_COUNT)
	var btemp := Defs.T20C
	var from_tile := false
	if h.losebreath >= 1.0:
		h.losebreath -= 1.0 # missed it: an empty breath
	else:
		var mask: Entity = inv.worn("mask") if inv else null
		var masked = mask != null and mask.has_c(&"clothing") and mask.c(&"clothing").breath_mask
		var tank := _internals_tank(e) if (m and m.internals and masked) else null
		if tank and tank.moles > 0.0:
			breath = tank.breath_mix()
			h.breath_status = "internals"
			if tank.moles <= 0.0:
				m.internals = false
				Game.tell(e, "Your gas cylinder is empty!", "bad")
		else:
			from_tile = true
			btemp = at.temp[i]
			var tot := at.total_moles(i)
			var f := Defs.BREATH_PERCENTAGE
			for g in Defs.GAS_COUNT:
				var amt: float = at.gas[g][i] * f
				if amt > 0.0 and tot > 0.0:
					at.remove_gas(i, g, amt)
					breath[g] = amt
			if masked and mask.c(&"clothing").gas_filter:
				# This port's filter removes 80% of harmful gases, all smoke.
				for g in GasBreath.FILTERED:
					breath[g] *= 0.2 if g != Defs.G_SMOKE else 0.0
	# tg check_breath: no lungs, no breath (and extra oxygen loss)
	if not Organs.has(h, "lungs"):
		for g in Defs.GAS_COUNT:
			if from_tile and breath[g] > 0.0:
				at.add_gas(i, g, breath[g], btemp)
			breath[g] = 0.0
		from_tile = false
		h.adjust("oxy", 2.0)
	var pp := PackedFloat32Array()
	pp.resize(Defs.GAS_COUNT)
	var total := 0.0
	for g in Defs.GAS_COUNT:
		pp[g] = breath[g] * Defs.R_IDEAL * btemp / Defs.BREATH_VOLUME
		total += breath[g]
	h.breath_alerts.clear()
	h.failed_last_breath = total <= 0.0
	# oxygen (tg breathe_oxygen / handle_suffocation)
	var o2 := pp[Defs.G_O2] + pp[Defs.G_PLUOXIUM] * 8.0
	if o2 < Defs.SAFE_O2_MIN_PP:
		h.failed_last_breath = true
		if Body.prob(25): # tg lungs handle_suffocation: a chance to notice something is wrong
			m.do_emote("gasp")
		var dmg := Defs.SUFFOCATION_OXYLOSS
		if o2 > 0.0:
			dmg *= (Defs.SAFE_O2_MIN_PP - o2) / Defs.SAFE_O2_MIN_PP
		if h.in_crit():
			dmg *= Defs.SUFFOCATION_OXYLOSS_CRIT_MODIFIER
		h.adjust("oxy", dmg)
		h.breath_status = "no_air" if o2 < 4.0 else "low_o2"
		if e == Game.player and Game.rng.randf() < 0.3:
			Game.tell(e, "You gasp for breath!" if o2 < 8 else "The air feels thin.", "bad")
	else:
		if h.breath_status != "internals":
			h.breath_status = "ok"
		if not h.in_crit() and h.oxy > 0.0:
			h.adjust("oxy", -5.0)
	# the oxygen breathed comes back out as CO2 (tg breathe_gas_volume)
	breath[Defs.G_CO2] += breath[Defs.G_O2]
	breath[Defs.G_O2] = 0.0
	GasBreath.apply(h, pp, breath)
	# CO2 (tg too_much_co2): coughing, then after 12 s over the limit out cold and hurting
	if pp[Defs.G_CO2] > Defs.SAFE_CO2_MAX_PP:
		if h.co2_over <= 0.0:
			h.co2_over = Game.time
		var over := Game.time - h.co2_over
		if Body.prob(20):
			m.do_emote("cough")
		h.breath_alerts["co2"] = over > 12.0
		if over > 12.0:
			h.knock_out(6.0)
			h.adjust("oxy", 3.0)
			if over > 30.0:
				h.adjust("oxy", 8.0)
		h.breath_status = "toxic"
	else:
		h.co2_over = 0.0
	# plasma (tg too_much_plasma): toxin damage from the moles breathed
	if pp[Defs.G_PLASMA] > Defs.SAFE_PLASMA_MAX_PP:
		var ratio := breath[Defs.G_PLASMA] / Defs.SAFE_PLASMA_MAX_PP * 10.0
		h.adjust("tox", clampf(ratio, Defs.MIN_TOXIC_GAS_DAMAGE, Defs.MAX_TOXIC_GAS_DAMAGE))
		h.breath_status = "toxic"
		h.breath_alerts["plasma"] = true
	# N2O (tg too_much_n2o)
	var n2o := pp[Defs.G_N2O]
	if n2o >= Defs.N2O_PARA_MIN:
		h.breath_alerts["n2o"] = true
		h.knock_out(6.0)
		if n2o > Defs.N2O_SLEEP_MIN:
			h.knock_out(minf(h.unconscious_t + 10.0, 20.0))
	elif n2o > Defs.N2O_DETECT_MIN and Game.rng.randf() < 0.2:
		m.do_emote(["giggle", "laugh"][Game.rng.randi() % 2])
	# smoke (a chemical cloud in tg; here a gas): coughing and a little choking
	if pp[Defs.G_SMOKE] > 2.0:
		h.breath_alerts["smoke"] = true
		h.adjust("oxy", 1.2)
		if Game.rng.randf() < 0.25:
			m.do_emote("cough")
	# breath temperature (tg lungs handle_breath_temperature)
	if total > 0.0:
		for k in Defs.COLD_LEVELS.size():
			var lv: Array = Defs.COLD_LEVELS[k]
			if btemp < lv[0]:
				h.adjust("burn", lv[1])
				# tg: breath_effect_prob 100 / 50 / 25 by level
				if Body.prob(sqrt([100.0, 50.0, 25.0][k]) * 4.0):
					Game.tell(e, "You feel your face freezing and an icicle forming in your lungs!", "warn")
					if Body.prob(50):
						m.do_emote("shiver")
				break
		for k in Defs.HEAT_LEVELS.size():
			var lv: Array = Defs.HEAT_LEVELS[k]
			if btemp > lv[0]:
				h.adjust("burn", lv[1])
				# tg heat_message_prob: 25 at level 3, 50 at 2, 100 at 1
				if Body.prob(sqrt([25.0, 50.0, 100.0][k]) * 4.0):
					Game.tell(e, "You feel your face burning and a searing heat in your lungs!", "warn")
				break
	# breathe out
	if from_tile:
		for g in Defs.GAS_COUNT:
			if breath[g] > 0.0:
				at.add_gas(i, g, breath[g], btemp)

## tg get_temp_change_amount: how far a temperature moves toward a target in a step.
static func _temp_step(diff: float, rate: float) -> float:
	if diff < 0.0:
		return -(Defs.BODYTEMP_AUTORECOVERY_DIVISOR / 2.0) * log(1.0 - diff * rate)
	return (Defs.BODYTEMP_AUTORECOVERY_DIVISOR / 2.0) * log(1.0 + diff * rate)

## tg body_temperature_core / _skin / _damage. `body_temp` is the skin, `core_temp` the core.
func _body_temperature(e: Entity, h: CHealth, inv: CInventory, env_t: float, dt: float) -> void:
	# the core is kept at 37 °C by metabolism (not when dead)
	if not h.dead:
		h.core_temp += _temp_step(Defs.BODYTEMP_NORMAL - h.core_temp, Defs.BODYTEMP_CORE_CHANGE_RATE * dt)
	# skin <-> core
	h.core_temp += _temp_step(h.body_temp - h.core_temp, Defs.BODYTEMP_SKIN_CORE_CHANGE_RATE * dt)
	# the room <-> skin, through clothing
	var protection: float = (inv.heat_protection() if env_t > h.body_temp else inv.insulation()) if inv else 0.0
	var area_skin_diff := env_t - h.body_temp
	if h.on_fire <= 0.0 or area_skin_diff > 0.0:
		var ch := _temp_step(area_skin_diff, Defs.BODYTEMP_AREA_SKIN_CHANGE_RATE * dt)
		if Defs.BODYTEMP_NORMAL + 10.0 < h.core_temp:
			ch *= 1.0 - protection * 0.7
		else:
			ch *= 1.0 - protection
		h.body_temp += ch
	if h.on_fire <= 0.0:
		var core_skin_diff := h.core_temp - h.body_temp
		var cs := (1.0 + protection) * _temp_step(core_skin_diff, Defs.BODYTEMP_CORE_SKIN_CHANGE_RATE * dt)
		cs = minf(cs, core_skin_diff) if core_skin_diff > 0.0 else maxf(cs, core_skin_diff)
		h.body_temp += cs
	# damage from the core temperature
	if h.core_temp > Defs.BODYTEMP_HEAT_DAMAGE_LIMIT and not h.traits.has("resistheat"): # tg TRAIT_RESISTHEAT
		var burn := maxf(log(h.core_temp - Defs.BODYTEMP_NORMAL) / log(2.0) - 5.0, 0.0) * 0.5 * dt
		h.adjust("burn", burn)
		# tg: prob(burn_damage) a Life tick to scream in pain (2 s ticks, so per second: burn)
		if burn > 0.0 and not h.knocked_out() and Body.prob(burn):
			e.c(&"mob").do_emote("scream")
	if h.core_temp < Defs.BODYTEMP_COLD_DAMAGE_LIMIT and not h.traits.has("resistcold"): # tg TRAIT_RESISTCOLD
		var lvl := 0.25 if h.core_temp > 200.0 else (0.75 if h.core_temp >= 120.0 else 1.5)
		h.adjust("burn", lvl * h.cold_mod * dt, null, true) # tg physiology.cold_mod
		h.last_damage_kind = "cold"
		if e == Game.player and Game.rng.randf() < 0.2:
			Game.tell(e, "You're freezing! Your fingers have gone numb.", "bad")

func _internals_tank(e: Entity) -> CTank:
	var inv: CInventory = e.c(&"inv")
	for s in ["back", "belt", "suit", "pocket_l", "pocket_r"]:
		var it: Entity = inv.worn(s)
		if it and it.has_c(&"tank"):
			return it.c(&"tank")
	for hnd in inv.hands:
		if hnd and hnd.has_c(&"tank"):
			return hnd.c(&"tank")
	return null
