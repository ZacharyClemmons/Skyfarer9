class_name CCanister extends Component
## A portable gas canister, after tg's /obj/machinery/portable_atmospherics/canister:
## a release valve with a pressure regulator (0 - 10 atm), a holding slot for an
## internals tank to fill, and a port you wrench it onto to feed a pipe network.
## Its gas is the CTank on the same entity (1000 L, like tg's canisters).
##   valve open, no tank     -> gas released into the room until the room reaches the
##                              release pressure
##   valve open, tank inside -> fills the tank up to the release pressure
##   wrenched to a port      -> pushes gas into the port's pipe network until the
##                              pressures match

const MAX_RELEASE := Defs.ONE_ATMOS * 10.0
const FLOW := 12.0 # moles per second through the valve

var release_pressure := Defs.ONE_ATMOS
var valve_open := false
## tg portable_atmospherics: a plain canister, a portable pump (moves air between its tank
## and the room, out to or in from, up to its target pressure) or a portable scrubber
## (pulls the bad gases out of the air around it into its tank)
var kind := "canister"
var on := false
var pump_out := true
var target := Defs.ONE_ATMOS
# tg portable scrubber's scrubbing list (portable/scrubber.dm), plus smoke
const SCRUBBED := [Defs.G_PLASMA, Defs.G_CO2, Defs.G_N2O, Defs.G_BZ, Defs.G_NITRIUM, Defs.G_TRITIUM, Defs.G_HYPERNOB,
	Defs.G_H2O, Defs.G_FREON, Defs.G_HYDROGEN, Defs.G_HEALIUM, Defs.G_PROTO_NITRATE, Defs.G_ZAUKER, Defs.G_HALON, Defs.G_SMOKE]
const SCRUBBER_VOLUME_RATE := 650.0 # tg portable scrubber volume_rate, L per tick
const SCRUB_RATE := 0.25 # share of a scrubbed gas taken from a tile each second (tg volume_rate 1000 L of 2500)

func setup(p: Dictionary) -> CCanister:
	kind = p.get("kind", kind)
	return self
var port: Entity = null
var holding: Entity = null

func key() -> StringName:
	return &"canister"

func tank() -> CTank:
	return e.c(&"tank")

func pressure() -> float:
	return tank().pressure_kpa()

func tick(dt: float) -> void:
	var tk := tank()
	if tk == null:
		return
	if port != null and (not is_instance_valid(port) or port.removed or port.cell.distance_to(e.cell) > 1.5):
		port = null
	if port != null:
		_feed_port(tk, dt)
	if kind != "canister":
		_portable(tk, dt)
		return
	if tk.moles <= 0.001:
		return
	if not valve_open:
		return
	if holding != null and is_instance_valid(holding) and holding.holder == e:
		var ht: CTank = holding.c(&"tank")
		var mv := release_moles(tk.pressure_kpa(), ht.pressure_kpa(), release_pressure, ht.volume, Defs.T20C)
		if mv > 0.0:
			ht.add_mix(tk.take(minf(mv, tk.moles)))
		return
	if Game.atmos == null or e.holder != null:
		return
	var i := Game.map.idx(e.cell)
	var mv2 := minf(tk.moles, release_moles(tk.pressure_kpa(), Game.atmos.pressure(i), release_pressure, Defs.CELL_VOLUME, Defs.T20C))
	if mv2 <= 0.0:
		return
	var out := tk.take(mv2)
	for g in Defs.GAS_COUNT:
		if out[g] > 0.0:
			Game.atmos.add_gas(i, g, out[g], Defs.T20C)

## tg gas_mixture/release_gas_to: how many moles leave a container at `p_in` for somewhere
## at `p_out` (of `out_volume` litres), aiming for `target`. Never more than half the
## difference (it can't push the output past the input) and nothing once within 10 kPa.
static func release_moles(p_in: float, p_out: float, target: float, out_volume: float, t: float) -> float:
	if p_out >= minf(target, p_in - 10.0):
		return 0.0
	var delta := minf(target - p_out, (p_in - p_out) / 2.0)
	return maxf(0.0, delta * out_volume / (t * Defs.R_IDEAL))

static func gas_index(gas: String) -> int:
	return CTank.GAS_ID.get(gas, Defs.G_N2)

## tg portables_connector: the canister and the pipe share toward equal pressure, either
## way (a canister on the pipes fills up from them, a full one feeds them).
func _feed_port(tk: CTank, dt: float) -> void:
	var v: CVent = port.c(&"vent")
	var net = null
	if Game.pipes:
		net = Game.pipes.net_facing(v.layer, port.cell, v.face) if v.face != Vector2i.ZERO else Game.pipes.net_at(v.layer, port.cell)
	if net == null:
		return
	var pn: float = net.pressure()
	var pc := pressure()
	if absf(pc - pn) <= 1.0:
		return
	var vol: float = minf(tk.volume, net.volume)
	if pc > pn:
		var mv := minf(tk.moles, minf(FLOW * dt * 3.0, (pc - pn) * 0.5 * vol / (Defs.R_IDEAL * Defs.T20C)))
		var out := tk.take(mv)
		for g in Defs.GAS_COUNT:
			if out[g] > 0.0:
				net.add_gas(g, out[g], Defs.T20C)
	else:
		var tot: float = net.total_moles()
		if tot <= 0.001:
			return
		var mv2 := minf(tot * 0.5, minf(FLOW * dt * 3.0, (pn - pc) * 0.5 * vol / (Defs.R_IDEAL * maxf(net.temp, 2.7))))
		tk.add_mix(net.take_fraction(mv2 / tot))

## tg portable pump / scrubber, run each second.
func _portable(tk: CTank, dt: float) -> void:
	if not on or Game.atmos == null or e.holder != null:
		return
	var at: AtmosSystem = Game.atmos
	var i := Game.map.idx(e.cell)
	# tg runs portables every SSair tick (0.5 s); we're called once per `dt`
	var ticks := dt / AtmosSystem.TICK
	if kind == "pump":
		# tg portable pump: an internal pressure pump, room <-> tank, up to the target
		var p: float = at.pressure(i)
		if pump_out:
			if p >= target or tk.moles <= 0.001:
				return
			var need: float = (target - p) * Defs.CELL_VOLUME / (Defs.R_IDEAL * Defs.T20C)
			var out := tk.take(minf(tk.moles, need))
			for g in Defs.GAS_COUNT:
				if out[g] > 0.0:
					at.add_gas(i, g, out[g], Defs.T20C)
		else:
			if pressure() >= target:
				return
			var tot := at.total_moles(i)
			if tot <= 0.01:
				return
			var want: float = (target - pressure()) * tk.volume / (Defs.R_IDEAL * maxf(at.temp[i], 2.7))
			var f := minf(1.0, want / tot)
			var got := PackedFloat32Array()
			got.resize(Defs.GAS_COUNT)
			for g in at.present:
				var amt: float = at.gas[g][i] * f
				if amt > 0.0:
					at.remove_gas(i, g, amt)
					got[g] = amt
			tk.add_mix(got)
		at.wake(e.cell)
	elif kind == "scrubber":
		# tg portable scrubber: volume_rate 650 L of its tile's 2500 L each tick, only the
		# gases on its scrubbing list, until its own tank fills
		if pressure() >= MAX_RELEASE * 3.0:
			return
		var f2 := 1.0 - pow(1.0 - minf(1.0, SCRUBBER_VOLUME_RATE / Defs.CELL_VOLUME), ticks)
		var got2 := PackedFloat32Array()
		got2.resize(Defs.GAS_COUNT)
		for g in SCRUBBED:
			var amt2: float = at.gas[g][i] * f2
			if amt2 > 0.0001:
				at.remove_gas(i, g, amt2)
				got2[g] += amt2
		at.wake(e.cell)
		tk.add_mix(got2)

func set_on(v: bool, user: Entity) -> void:
	on = v
	Sfx.play("click", e.cell, 0.5)
	e.set_sprite("objects", "%s%s" % [e.proto, "_on" if on else ""])
	if user:
		Game.tell(user, "You switch %s %s." % [e.the(), "on" if on else "off"])

## Wrench onto (or off) an adjacent connector port.
func toggle_port(user: Entity) -> void:
	if port != null:
		Game.visible_message(e.cell, "%s disconnects %s from the port." % [user.display_name, e.the()])
		port = null
		Sfx.play("ratchet", e.cell)
		return
	for v in Game.in_radius(e.cell, 1, &"vent"):
		if v.c(&"vent").mode == "port":
			port = v
			Game.visible_message(e.cell, "%s wrenches %s onto %s." % [user.display_name, e.the(), v.the()], "good")
			Sfx.play("ratchet", e.cell)
			Bus.stimulus.emit({"type": "repaired", "actor": user, "target": v, "cell": v.cell, "loud": 1.0, "what": "coolant"})
			return
	Game.tell(user, "There's no connector port next to %s." % e.the(), "warn")

func insert_tank(user: Entity, item: Entity) -> void:
	if holding != null:
		Game.tell(user, "There's already a cylinder in %s." % e.the(), "warn")
		return
	Interact.detach(item)
	item.holder = e
	item.visible = false
	holding = item
	user.c(&"inv")._refresh()
	Game.tell(user, "You put %s into %s." % [item.the(), e.the()])

func eject_tank(user: Entity) -> void:
	if holding == null:
		return
	var t := holding
	holding = null
	t.holder = null
	if user and user.c(&"inv") and user.c(&"inv").put_in_hands(t):
		return
	t.visible = true
	Game.drop_to_map(t, e.cell)
	t.place(e.cell)

func set_release(kpa: float) -> void:
	release_pressure = clampf(kpa, 0.0, MAX_RELEASE)

func toggle_valve(user: Entity) -> void:
	valve_open = not valve_open
	Sfx.play("pour" if valve_open else "click", e.cell, 0.6)
	if user:
		var into := "into %s" % holding.the() if holding else "into the air"
		Game.visible_message(e.cell, "%s %s the valve on %s%s." % [user.display_name, "opens" if valve_open else "closes", e.the(), (", releasing it " + into) if valve_open else ""], "warn" if valve_open and holding == null else "info")
		if valve_open and holding == null and tank().gas == "plasma":
			Bus.stimulus.emit({"type": "sabotage", "actor": user, "target": e, "cell": e.cell, "loud": 4.0, "illegal": true, "text": "released plasma"})

func attack_hand(user: Entity) -> bool:
	Bus.ui_open_window.emit("canister", e)
	return true

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if it and it.tool == "wrench":
		toggle_port(user)
		return true
	if item.has_c(&"tank") and it != null:
		insert_tank(user, item)
		return true
	return false

func verbs(user: Entity, out: Array) -> void:
	out.append({"name": "Open interface", "cb": attack_hand.bind(user), "priority": 7})

func examine(_user: Entity, lines: Array) -> void:
	lines.append("It holds %s at %.0f kPa." % [tank().contents_text(), pressure()])
	if kind != "canister":
		lines.append("It's %s%s." % ["on" if on else "off", (", pumping %s, target %.0f kPa" % ["out" if pump_out else "in", target]) if kind == "pump" else ""])
	lines.append("The valve is %s; release pressure %.0f kPa.%s%s" % ["OPEN" if valve_open else "closed", release_pressure,
		" It's connected to a port." if port else "", (" %s is in the holding slot." % holding.display_name.capitalize()) if holding else ""])
