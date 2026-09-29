class_name CThruster extends Component
## An aether thruster: a fuel burner with a nozzle, bolted through the stern.
##
## It needs fuel from the ship's bunkers and a live power bus to hold its ignition. While
## it runs it dumps its exhaust — heat, carbon dioxide and soot — into the tile it stands
## in. That is the whole point: a thruster on an open weather deck is fine, and the same
## thruster walled into an unventilated engine room will cook and then choke the crew.
## Atmospherics is not decoration here; it is the reason engine rooms have scrubbers.

## At full throttle. A stock bunker holds 110 units, so a skiff runs for about ten
## minutes flat out — long enough to cross two rings and come back, short enough that a
## long haul is a thing you plan bunkers for.
const FUEL_PER_SECOND := 0.18
const EXHAUST_HEAT := 42000.0 # joules per second into the tile
const EXHAUST_CO2 := 0.9 # moles per second
const EXHAUST_SOOT := 0.12
const SPOOL_UP := 1.8 # seconds from cold to full
const OVERHEAT_TEMP := Defs.T0C + 420.0

var ship_id := -1
## Which module is actually bolted in here (ShipParts). Its stat block decides thrust,
## burn rate and how hard it cooks the compartment.
var mod := "thruster_std"
var running := false
var spool := 0.0 # 0..1
var heat := 0.0 # 0..1 how hot the unit itself is
var starved := false
var _noise_t := 0.0
var _ignited := false
const ShipFxScript := preload("res://src/ship/ship_fx.gd")

func key() -> StringName:
	return &"thruster"

## 0..1 of rated thrust. Rated thrust itself is the module's, read by Airship.thrust().
func output() -> float:
	return spool * (1.0 - heat * 0.35)

func burn_rate() -> float:
	return FUEL_PER_SECOND * ShipParts.stat(mod, "fuel_mul", 1.0)

func heat_scale() -> float:
	return ShipParts.stat(mod, "heat_mul", 1.0)

func ship() -> Airship:
	return Game.fleet.get_ship(ship_id) if Game.fleet else null

func process(delta: float) -> void:
	var sh := ship()
	var want: float = sh.throttle if sh != null else 0.0
	var m: CMachine = e.c(&"machine")
	# A thruster is a fuel burner with a steam injector, so what it needs is a lit boiler,
	# not a live power bus. Cold boiler, cold engines.
	var m_ok: bool = m == null or not m.broken
	if not m_ok or sh == null or not sh.steam_up():
		want = 0.0
	# fuel
	starved = false
	if want > 0.0 and sh != null:
		# an efficient engine burns less for the same shove, which is the whole point of
		# buying one, and a good hand on the wheel wastes less of it still
		var thrift: float = 1.0 - sh.pilot_skill("airmanship") * 0.22
		var need := burn_rate() * want * delta * thrift
		var got := sh.draw_fuel(need)
		if got < need * 0.9:
			starved = true
			want = 0.0
	running = want > 0.0
	spool = move_toward(spool, want, delta / SPOOL_UP)
	if m != null:
		m.active = running
	if spool <= 0.001:
		_ignited = false
		heat = maxf(0.0, heat - delta * 0.1)
		e.set_glow_visible(false)
		return
	if not _ignited and running:
		# the injector catches: a cough of exhaust, a thump in the frame
		_ignited = true
		Sfx.play("engine", e.cell, 0.7, 0.75)
		ShipFxScript.puff(e.position + Vector2(-20, -6), 3, 6.0, 10.0, 0.9, Color(0.75, 0.72, 0.7, 0.65), 1.4, 0.4, Vector2(-30, 0))
		if Game.view != null and sh != null and sh == Game.fleet.player_ship:
			Game.view.shake(1.4)
	heat = clampf(heat + delta * spool * 0.05 - delta * 0.06, 0.0, 1.0)
	e.set_glow_visible(true)
	_exhaust(delta)
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.7
		# a whisper drive is genuinely quieter, and the sky notices
		var loud: float = 0.25 if ShipParts.has_quirk(mod, "quiet") else 1.0
		Sfx.play("engine", e.cell, (0.3 + spool * 0.4) * loud)
		Bus.stimulus.emit({"type": "engine_noise", "actor": null, "cell": e.cell,
			"loud": (7.0 + spool * 9.0) * loud})

## Everything the burner throws out goes into the tile it occupies. Outdoors that is the
## sky's problem; indoors it is yours.
func _exhaust(delta: float) -> void:
	var at = Game.atmos
	if at == null or Game.map.is_outdoor(e.cell):
		return
	var i := Game.map.idx(e.cell)
	var hs := heat_scale()
	at.add_heat(i, EXHAUST_HEAT * spool * delta * hs)
	at.add_gas(i, Defs.G_CO2, EXHAUST_CO2 * spool * delta * hs, Defs.T0C + 300.0)
	at.add_gas(i, Defs.G_SMOKE, EXHAUST_SOOT * spool * delta * hs, Defs.T0C + 300.0)
	at.mark_present(Defs.G_SMOKE)
	# cooked in its own heat: an engine room without an extractor wrecks its own engines
	if at.temp_at(e.cell) > OVERHEAT_TEMP:
		heat = minf(1.0, heat + delta * 0.35)
		if heat >= 0.999 and Game.rng.randf() < delta * 0.2:
			_seize()

func _seize() -> void:
	var m: CMachine = e.c(&"machine")
	if m != null and not m.broken:
		m.set_broken(true, null)
	Game.visible_message(e.cell, "[b][color=#ff6a6a]The thruster seizes with a shriek of metal.[/color][/b]", "bad")
	Fx.sparks(e.cell)
	spool = 0.0
	running = false

func examine(_user: Entity, lines: Array) -> void:
	var spec := ShipParts.get_mod(mod)
	if not spec.is_empty():
		lines.append("[color=%s]%s[/color] — %s" % [ShipParts.tier_color(mod),
			String(spec["name"]).capitalize(), "   ".join(ShipParts.stat_lines(mod))])
		var q := ShipParts.quirk_text(mod)
		if q != "":
			lines.append("[color=#e8a83a]%s[/color]" % q)
	lines.append("Thrust: [b]%d%%[/b]. Unit temperature: [b]%s[/b]." % [int(output() * 100.0), _heat_word()])
	if starved:
		lines.append("[color=#ff8a5a]Fuel starved — the bunkers are dry.[/color]")
	var sh := ship()
	if sh != null and not sh.steam_up():
		lines.append("[color=#e8a83a]No steam. Light the boiler before you open the throttle.[/color]")
	var m: CMachine = e.c(&"machine")
	if m != null and m.broken:
		lines.append("[color=#ff6a6a]Seized. It needs a wrench and a blowtorch.[/color]")
	if not Game.map.is_outdoor(e.cell):
		lines.append("[i]It is running inside a sealed space. Watch the air.[/i]")

func _heat_word() -> String:
	if heat < 0.2: return "cool"
	if heat < 0.5: return "warm"
	if heat < 0.8: return "[color=#e8a83a]hot[/color]"
	return "[color=#ff6a6a]critical[/color]"

func ai_tags(out: Dictionary) -> void:
	out["thruster"] = true
	if heat > 0.7:
		out["overheating"] = true
