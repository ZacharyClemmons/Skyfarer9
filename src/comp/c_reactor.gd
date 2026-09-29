class_name CReactor extends Component
## Fission core, the station's heart. Heats the HOT coolant loop; the TEG turns the
## temperature difference between the hot loop and the COLD loop (cooled by radiators
## out in the snow) into electricity. Loses coolant -> can't shed heat -> overheats.
## Monitoring mirrors tg's supermatter: integrity warnings over Engineering radio.

var core_temp := 600.0 # K
var rods := 0.55 # control rod insertion 0 (full power) .. 1 (scram)
var rod_target := 0.55
var fuel := 1.0
var integrity := 100.0
var heat_out_kw := 0.0
var transfer_kw := 0.0
var scrammed := false
var melted := false
var _last_warn := -999.0
var _warn_level := 0
const THERMAL_MASS := 800.0 # kJ/K
const WARN_T := 950.0
const DANGER_T := 1250.0
const MELT_T := 1600.0

func key() -> StringName:
	return &"reactor"

func on_added() -> void:
	if Game.pipes:
		Game.pipes.register_device(e, StationMap.PL_HOT)

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_device(e)

## Called every atmos tick (0.5s) by PipeSystem with the coolant net (may be null).
func process_heat(net, dt: float) -> void:
	if melted:
		return
	rods = move_toward(rods, 1.0 if scrammed else rod_target, dt * 0.05)
	var power := (1.0 - rods) * fuel
	heat_out_kw = 1800.0 * power + 40.0 # decay heat
	fuel = maxf(0.05, fuel - power * dt * 0.00002)
	transfer_kw = 0.0
	if net != null:
		var moles: float = net.total_moles()
		var ct: float = net.temp
		var cap: float = net.heat_capacity()
		var coupling := clampf(moles / 600.0, 0.0, 1.5)
		transfer_kw = maxf(0.0, (core_temp - ct) * 6.0 * coupling)
		# can't push the coolant hotter than the core
		var max_q := (core_temp - ct) * cap * 0.5 / 1000.0 / dt
		transfer_kw = minf(transfer_kw, maxf(0.0, max_q))
		net.add_heat(transfer_kw * 1000.0 * dt)
	core_temp += (heat_out_kw - transfer_kw) * dt / THERMAL_MASS
	core_temp = maxf(core_temp, 250.0)
	# damage
	if core_temp > DANGER_T:
		integrity -= (core_temp - DANGER_T) * 0.004 * dt
	elif core_temp < WARN_T and integrity < 100:
		integrity = minf(100.0, integrity + 0.01 * dt)
	_monitor()
	if integrity <= 0.0 or core_temp > MELT_T * 1.4:
		meltdown()

func _monitor() -> void:
	var lvl := 0
	if core_temp > WARN_T or integrity < 95:
		lvl = 1
	if core_temp > DANGER_T or integrity < 60:
		lvl = 2
	if integrity < 25:
		lvl = 3
	var interval = [9999.0, 60.0, 25.0, 10.0][lvl]
	if lvl > 0 and (lvl > _warn_level or Game.time - _last_warn > interval):
		_last_warn = Game.time
		var txt = ["", "WARNING: Reactor core temperature %.0f K. Integrity %.0f%%.", "DANGER: Reactor core temperature %.0f K! Integrity %.0f%%! Coolant loop failing!", "CRITICAL: REACTOR MELTDOWN IMMINENT. Core %.0f K, integrity %.0f%%. EVACUATE ENGINEERING."][lvl] % [core_temp, integrity]
		StationAlerts.radio_system("Reactor Monitor", "Engineering", txt, {"type": "reactor_hot", "key": "reactor_hot", "subject": e.id, "cell": e.cell, "severity": lvl, "data": {"temp": core_temp, "integrity": integrity}})
		if lvl >= 3:
			StationAlerts.radio_system("Reactor Monitor", "Common", txt, {})
	if lvl == 0 and _warn_level > 0:
		StationAlerts.radio_system("Reactor Monitor", "Engineering", "Reactor core stabilised at %.0f K." % core_temp, {"type": "reactor_ok", "key": "reactor_hot", "subject": e.id, "cell": e.cell, "severity": 0})
	_warn_level = lvl

func meltdown() -> void:
	if melted:
		return
	melted = true
	Bus.chronicle.emit("The reactor core melted down in %s." % Game.map.area_at(e.cell).name, 5)
	Explosion.explode(e.cell, 3, 6, 9, null)
	if Game.atmos:
		for c in [e.cell, e.cell + Vector2i(1, 0), e.cell + Vector2i(-1, 0)]:
			Game.atmos.add_gas(Game.map.idx(c), Defs.G_PLASMA, 200.0, 2500.0)
	Game.set_alert(3, "Reactor meltdown.")

func status_text() -> String:
	return "Core %.0f K | Rods %d%% (target %d%%) | Fuel %d%% | Integrity %.0f%% | Heat %.0f kW -> coolant %.0f kW" % [core_temp, int(rods * 100), int(rod_target * 100), int(fuel * 100), integrity, heat_out_kw, transfer_kw]

func examine(_user: Entity, lines: Array) -> void:
	lines.append(status_text())
	if core_temp > WARN_T:
		lines.append("[color=#ff7a3a]It is radiating intense heat.[/color]")

func attack_hand(_user: Entity) -> bool:
	Bus.ui_open_window.emit("reactor", e)
	return true

func ai_tags(out: Dictionary) -> void:
	out["reactor"] = true
	if core_temp > WARN_T:
		out["reactor_hot"] = true
