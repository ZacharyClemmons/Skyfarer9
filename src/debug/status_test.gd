class_name StatusTest extends Node
## --statustest (with --autotest): visible gases, the tg lung effects (CO2, plasma, N2O), the
## status alerts the HUD shows for them, APC charge lamps and the multitool power reading.
## Prints STATUS PASS/FAIL lines and quits.

var fails := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_gas_visibility()
	await _breathing()
	await _alerts()
	_power()
	print("STATUS DONE: %d failed" % fails)
	get_tree().quit()

# ------------------------------------------------------------------ gases on screen
func _gas_visibility() -> void:
	_check("gas under its moles_visible isn't drawn", GasLayer.opacity(0.25, 0.25) == 0.0)
	_near("just past it: tg state 2 alpha, log4(34/28)", GasLayer.opacity(0.3, 0.25), log(34.0 / 28.0) / log(4.0), 0.001)
	_check("20 mol of plasma is fully opaque", is_equal_approx(GasLayer.opacity(20.0, 0.25), 1.0))
	_check("0.4 mol of N2O is still invisible (tg: twice the threshold)", GasLayer.opacity(0.4, 0.5) == 0.0)
	var c := _open_cell()
	var i := Game.map.idx(c)
	Game.atmos.add_gas(i, Defs.G_PLASMA, 6.0, Defs.T20C)
	Game.view.gas_layer._write(i)
	_check("a plasma leak shows on the gas layer", Game.view.gas_layer.visible_amount(c, Defs.G_PLASMA) > 0.45)
	Game.atmos.gas[Defs.G_PLASMA][i] = 0.0
	Game.view.gas_layer._write(i)
	_check("and clears when it's gone", Game.view.gas_layer.visible_amount(c, Defs.G_PLASMA) == 0.0)

# ------------------------------------------------------------------ lungs
func _breathing() -> void:
	var old_time := Game.time
	Game.time = 100.0 # CO2 exposure uses an absolute timestamp, not elapsed seconds.
	var c := _open_cell()
	var d := Crew.spawn_human("assistant", c, {"name": "Breather"})
	d.remove_comp(&"brain")
	Quirks.remove_all(d) # random crew quirks would skew the checks
	var h: CHealth = d.c(&"health")
	var i := Game.map.idx(c)
	var at: AtmosSystem = Game.atmos
	var pp_per_mol := Defs.R_IDEAL * at.temp[i] / Defs.CELL_VOLUME
	# N2O over 1 kPa knocks you out; over 5 you sleep longer
	_clear_bad(i)
	at.gas[Defs.G_N2O][i] = 2.0 / pp_per_mol
	_force_breath(d)
	_check("N2O at 2 kPa knocks you out (6 s)", h.unconscious_t >= 5.9 and h.stat() == CHealth.UNCONSCIOUS and h.breath_alerts.has("n2o"))
	at.gas[Defs.G_N2O][i] = 8.0 / pp_per_mol
	_force_breath(d)
	_check("N2O over 5 kPa puts you under for longer (%.0f s)" % h.unconscious_t, h.unconscious_t > 10.0)
	_clear_bad(i)
	h.remove_status("unconscious")
	# CO2: coughing, then out cold after 12 s
	at.gas[Defs.G_CO2][i] = 15.0 / pp_per_mol
	_force_breath(d)
	_check("fresh CO2 overload: an alert but still awake", h.breath_alerts.get("co2") == false and h.stat() == CHealth.CONSCIOUS)
	h.co2_over = Game.time - 13.0
	_force_breath(d)
	_check("12 s in CO2 and you pass out", h.breath_alerts.get("co2") == true and h.unconscious_t > 0.0)
	_clear_bad(i)
	_force_breath(d)
	_check("fresh air clears the CO2 alert", not h.breath_alerts.has("co2") and h.co2_over == 0.0)
	# plasma: tg's 0.05 kPa limit
	h.remove_status("unconscious")
	var tox0 := h.tox
	at.gas[Defs.G_PLASMA][i] = 0.2 / pp_per_mol
	_force_breath(d)
	_check("0.2 kPa of plasma hurts (tg safe_plasma_max 0.05)", h.tox > tox0 and h.breath_alerts.has("plasma"))
	_clear_bad(i)
	d.destroy()
	Game.time = old_time

func _force_breath(d: Entity) -> void:
	var h: CHealth = d.c(&"health")
	h.breath_t = 0.0
	Game.life._breathe(d, h, d.c(&"mob"), d.c(&"inv"), Game.map.idx(d.cell), 1.0)

func _clear_bad(i: int) -> void:
	for g in [Defs.G_CO2, Defs.G_PLASMA, Defs.G_N2O, Defs.G_SMOKE]:
		Game.atmos.gas[g][i] = 0.0

# ------------------------------------------------------------------ the HUD
func _alerts() -> void:
	var p: Entity = Game.player
	if p == null or Game.hud == null:
		_check("a player and HUD to test alerts on", false)
		return
	var h: CHealth = p.c(&"health")
	var bar: AlertBar = Game.hud.alerts_box
	h.body_temp = Defs.BODYTEMP_COLD_DAMAGE_LIMIT - 75.0
	Game.hud._update_alerts(p)
	var t: AlertBar.AlertTile = bar.tiles.get("cold")
	_check("a cold player gets a COLD alert", t != null and t.text.text == "COLD" and t.sev == AlertBar.BAD)
	h.body_temp = Defs.BODYTEMP_COLD_DAMAGE_LIMIT - 10.0
	Game.hud._update_alerts(p)
	_check("the same tile stays, relabelled CHILLY and downgraded", bar.tiles.get("cold") == t and t.text.text == "CHILLY" and t.sev == AlertBar.WARN)
	h.body_temp = Defs.BODYTEMP_NORMAL
	h.stun(3.0)
	Game.hud._update_alerts(p)
	_check("the cold alert goes when you're warm", not bar.tiles.has("cold"))
	_check("stuns show with their countdown", bar.tiles.has("stunned") and bar.tiles["stunned"].text.text == "STUN 3s")
	var tip = bar.tiles["stunned"]._make_custom_tooltip("")
	_check("hovering gives tg's name and advice", tip is RichTextLabel and tip.text.contains("Stunned"))
	tip.free()
	h.stun_t = 0.0
	h.cuffed = true
	Game.hud._update_alerts(p)
	var cuffed_tip = bar.tiles["cuffed"]._make_custom_tooltip("")
	_check("clickable alerts say what a click does", cuffed_tip.text.contains("Click to wriggle out"))
	cuffed_tip.free()
	h.cuffed = false
	Game.hud._update_alerts(p)
	var ids := {}
	for k in AlertBar.CATALOG:
		ids[k] = Gfx.has("fx", "ui_alert_" + k)
	_check("every alert has its own icon", not ids.values().has(false))

# ------------------------------------------------------------------ electrical
func _power() -> void:
	var apc_e: Entity = null
	for e in Game.all_with(&"apc"):
		apc_e = e
		break
	if apc_e == null:
		_check("an APC to test", false)
		return
	var apc: CApc = apc_e.c(&"apc")
	var ok := true
	for st in [["full", true, false], ["charging", true, true], ["draining", false, false]]:
		apc.grid_ok = st[1]
		apc.charging = st[2]
		apc.update_lamp()
		ok = ok and apc.lamp_state() == st[0] and apc_e.c(&"light").color.is_equal_approx(CApc.LAMP[st[0]])
	_check("APC lamps: green full, blue charging, red on battery", ok)
	apc.breaker = false
	apc.update_lamp()
	_check("breaker off: the lamp goes dark", apc.lamp_state() == "off")
	apc.breaker = true
	Game.power.tick(1.0)
	var cable := Vector2i(-1, -1)
	for i in Game.map.cable.size():
		if Game.map.cable[i] == 1:
			cable = Game.map.cell_of(i)
			break
	var rep: String = Game.power.cable_report(cable)
	_check("a multitool on a cable reads the power network", rep.contains("Total power") and rep.contains("Load") and rep.contains("Excess"))

# ------------------------------------------------------------------ helpers
func _open_cell() -> Vector2i:
	var a: Area = Game.world.get_parent().mapgen.room_of("cafeteria")["area"]
	for c in a.cells:
		if Game.map.is_passable(c) and Game.at(c).is_empty():
			return c
	return a.cells[0]

func _near(what: String, got: float, want: float, tol := 0.01) -> void:
	_check("%s (got %.3f)" % [what, got], absf(got - want) <= tol)

func _check(what: String, ok: bool) -> void:
	print("STATUS %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1
