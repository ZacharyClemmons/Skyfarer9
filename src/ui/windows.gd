class_name Windows extends RefCounted
## Content builders for machine / info windows. Each build() fills `body` from live data.

static func title(kind: String, t: Entity) -> String:
	if WindowsPort.handles(kind):
		return WindowsPort.title(kind, t)
	if WindowsDna.handles(kind):
		return WindowsDna.title(kind, t)
	if WindowsTG.handles(kind):
		return WindowsTG.title(kind, t)
	match kind:
		"console": return t.c(&"console").title()
		"tank_console": return t.c(&"console").title()
		"space_heater": return "Cabin Heater"
		"chronicle": return "Ship's Log"
		"crew": return "Crew Manifest"
		"help": return "Skyfarer's Guide"
		"skills": return "Skills"
		"station_map": return "Chart"
		"objectives": return "Duties"
		"crafting": return "Crafting"
		"write": return "Writing on %s" % t.display_name
		"airlock_wires": return "%s - wiring" % t.display_name.capitalize()
		"talk": return "Talking to %s" % t.display_name
		"mind": return "Mind of %s" % t.display_name
		"surgery": return "Surgery"
		"debug": return "Debug"
		"pipe_nets": return "Pipe Networks"
	return t.display_name.capitalize() if t else kind.capitalize()

static func width(kind: String, t: Entity = null) -> int:
	if WindowsPort.handles(kind):
		return WindowsPort.width(kind)
	if WindowsDna.handles(kind):
		return WindowsDna.width(kind)
	if WindowsTG.handles(kind) and not WindowsMachines.handles(kind, t):
		return WindowsTG.width(kind)
	if WindowsMachines.handles(kind, t):
		return WindowsMachines.width(kind, t)
	return {"console": 620, "chronicle": 640, "help": 620, "crew": 520, "skills": 780, "air_alarm": 560, "canister": 460, "station_map": 820, "objectives": 560, "crafting": 620, "pipe_machine": 600, "debug": 560, "pipe_nets": 760, "talk": 560, "mind": 720}.get(kind, 440)

static func interval(kind: String) -> float:
	if WindowsPort.handles(kind):
		return WindowsPort.interval(kind)
	if WindowsDna.handles(kind):
		return WindowsDna.interval(kind)
	if WindowsTG.handles(kind):
		return WindowsTG.interval(kind)
	return {"vending": 2.0, "storage": 1.0, "help": 9999.0, "chronicle": 3.0, "talk": 2.0, "chem": 1.5, "crew": 3.0, "station_map": 9999.0, "objectives": 2.0, "crafting": 0.5, "debug": 1.0, "pipe_nets": 1.0, "mind": 1.5}.get(kind, 0.75)

static func _rt(body: Control, text: String, min_h := 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = min_h == 0
	r.custom_minimum_size = Vector2(0, min_h)
	r.scroll_active = min_h > 0
	r.text = text
	body.add_child(r)
	return r

static func _btn(body: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	body.add_child(b)
	return b

static func _row(body: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	return h

static func build(kind: String, t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var p := Game.player
	if WindowsPort.handles(kind):
		WindowsPort.build(kind, t, body, w)
		return
	if WindowsDna.handles(kind):
		WindowsDna.build(kind, t, body, w)
		return
	if WindowsTG.handles(kind):
		WindowsTG.build(kind, t, body, w)
		return
	if WindowsMachines.handles(kind, t):
		WindowsMachines.build(kind, t, body, p)
		return
	match kind:
		"debug":
			_debug_menu(body, p)
			return
		"pipe_nets":
			_pipe_nets(body)
			return
		"console":
			var lines := []
			for l in t.c(&"console").readout():
				lines.append(l["text"])
			_rt(body, "\n".join(lines) if not lines.is_empty() else "[color=#8a9cb0]No data.[/color]", 320)
			if t.c(&"console").kind == "comms" and p:
				var r := _row(body)
				for lvl in 3:
					_btn(r, "Set %s" % Game.ALERT_NAMES[lvl], func(): Windows._set_alert(p, lvl))
				_evac_controls(body, p)
			if t.c(&"console").kind == "pod" and p and Game.evac:
				var pod: Vessel = Game.evac.vessel_at(t.cell)
				var lb := _btn(body, "LAUNCH", func(): Game.evac.launch_pod(pod, p))
				lb.disabled = pod == null or Game.evac.can_launch_pod() != ""
		"apc":
			var apc: CApc = t.c(&"apc")
			var a := apc.area_ref
			_rt(body, "[b]%s[/b]\nCell: %d%% (%.0f/%.0f kJ)\nExternal power: %s\nLoad: %.2f kW\n\nEquipment: %s\nLighting: %s\nEnvironment: %s" % [
				a.name, int(apc.charge / apc.capacity * 100), apc.charge, apc.capacity,
				"[color=#6ae88a]connected[/color]" if apc.grid_ok else "[color=#ffb84a]none - running on battery[/color]",
				apc.last_load_w / 1000.0, _on(a.power_equip), _on(a.power_light), _on(a.power_environ)])
			var r2 := _row(body)
			_btn(r2, "Breaker: %s" % ("ON" if apc.breaker else "OFF"), func(): apc.toggle_breaker(p))
			for ch in ["equip", "light", "environ"]:
				_btn(r2, "%s: %s" % [ch, apc.modes[ch]], func(): Windows._cycle_mode(apc, ch))
		"air_alarm":
			Windows._air_alarm(t.c(&"air_alarm"), body, p)
		"reactor":
			var rc: CReactor = t.c(&"reactor")
			_rt(body, rc.status_text().replace(" | ", "\n"))
			var r5 := _row(body)
			_btn(r5, "Rods +10%", func(): rc.rod_target = minf(1.0, rc.rod_target + 0.1))
			_btn(r5, "Rods -10%", func(): rc.rod_target = maxf(0.0, rc.rod_target - 0.1))
			_btn(r5, "SCRAM" if not rc.scrammed else "Reset SCRAM", func(): rc.scrammed = not rc.scrammed)
		"air_supply":
			var asu: CAirSupply = t.c(&"air_supply")
			var nets = Game.pipes.nets_on_layer(StationMap.PL_SUPPLY)
			var np: float = nets[0].pressure() if not nets.is_empty() else 0.0
			_rt(body, "Distribution: %s\nLoop pressure: %.0f kPa (target %.0f)\nO2 reserve: %.0f mol\nN2 reserve: %.0f mol\n[color=#8a9cb0]Feed it rime-ice chunks cut from the high sky to replenish oxygen.[/color]" % [_on(asu.working()), np, asu.target_kpa, asu.o2_reserve, asu.n2_reserve])
			var r6 := _row(body)
			_btn(r6, "Toggle", func(): asu.on = not asu.on)
			_btn(r6, "Target -25", func(): asu.target_kpa = maxf(100.0, asu.target_kpa - 25.0))
			_btn(r6, "Target +25", func(): asu.target_kpa = minf(600.0, asu.target_kpa + 25.0))
		"power":
			var pg: CPowerGen = t.c(&"powergen")
			if pg.kind == "smes":
				_rt(body, "Charge: %d%% (%.1f MJ)\nInput: %.1f kW  Output: %.1f kW\n%s" % [int(pg.charge / pg.capacity * 100), pg.charge / 1000.0, pg.last_in / 1000.0, pg.last_out / 1000.0, Game.power.summary()])
				var r7 := _row(body)
				_btn(r7, "Charging: %s" % ("ON" if pg.charge_on else "OFF"), func(): pg.charge_on = not pg.charge_on)
				_btn(r7, "Output: %s" % ("ON" if pg.output_on else "OFF"), func(): pg.output_on = not pg.output_on)
			else:
				_rt(body, "Output: %.1f kW\n%s" % [pg.output_w / 1000.0, Game.power.summary()])
		"vending":
			_vending(t.c(&"vending"), body, p)
		"pipe_machine":
			_pipe_machine(t.c(&"pipemachine"), body, p)
		"canister":
			Windows._canister(t.c(&"canister"), body, p)
		"storage":
			# an icon grid, like the HUD's slots: click to take, right-click for actions,
			# drag items in and out
			var stg: CStorage = t.c(&"storage")
			var used := stg.used()
			var summary := TGUI.section(body, "Contents")
			summary.add_child(TGUI.bar(used, stg.capacity, "%d / %d space used" % [used, stg.capacity], TGUI.AVERAGE if used >= stg.capacity else TGUI.GOOD))
			var detail := "%d items" % stg.contents.size()
			if stg.max_slots > 0:
				detail += " / %d slots" % stg.max_slots
			summary.add_child(UITheme.label(detail + "  ·  Click to take; drag to store.", UITheme.SMALL, TGUI.LABEL))
			if stg.contents.is_empty():
				TGUI.notice(summary, "Empty — drag an item into a slot to store it.")
			var grid := GridContainer.new()
			grid.columns = 7
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			body.add_child(grid)
			var cells := maxi(14, ceili((stg.contents.size() + 1) / 7.0) * 7)
			for i in cells:
				var sl := InvSlot.new("storage", "", 52)
				sl.container = t
				grid.add_child(sl)
				if i < stg.contents.size():
					var itv: Entity = stg.contents[i]
					sl.set_item(itv)
					sl.clicked.connect(func(_s, b): Windows._storage_click(p, stg, itv, b))
				else:
					sl.set_item(null)
					sl.clicked.connect(func(_s, b):
						if b == MOUSE_BUTTON_LEFT:
							var held: Entity = p.c(&"inv").active_item()
							if held:
								DragDrop.apply(p, held, {"kind": "store", "container": t}, false)
								Game.hud.refresh_inventory()
								w.refresh_t = 0.0
					)
		"talk":
			WindowsNPC.talk(t, body, w)
		"mind":
			WindowsNPC.mind(t, body, w)
		"surgery":
			var zone: String = p.c(&"mob").zone if p else "chest"
			var where: Array = Surgery.surface(t)
			_rt(body, "Operating on [b]%s[/b]'s [b]%s[/b], on %s%s." % [t.display_name, Combat.ZONE_NAMES.get(zone, zone), where[1],
				"" if where[0] >= 1.0 else " [color=#ffb84a](an operating table would be safer)[/color]"])
			for id in Surgery.options(zone, t):
				var pid: String = id
				_btn(body, Surgery.PROCEDURES[id]["name"], func():
					Surgery.begin(p, t, pid)
					w.queue_free())
			w.refresh_fn = Callable()
		"chronicle":
			_rt(body, Game.chronicle.as_bbcode(false), 420)
		"crew":
			var lines2 := []
			for m in Game.all_with(&"mob"):
				var mob: CMob = m.c(&"mob")
				var h: CHealth = m.c(&"health")
				var line := "%-22s %-24s" % [m.display_name, Jobs.title(mob.job)]
				if m.has_c(&"brain") and p:
					var br: CBrain = m.c(&"brain")
					if br.memory.has_rel(p.id):
						var r8 = br.memory.rel(p.id)
						if r8.familiarity > 10:
							line += " " + Windows._attitude(r8.affinity)
				if h and h.dead and Game.chronicle and _known_dead(m):
					line = "[color=#6a6a6a][s]%s[/s][/color]" % line
				lines2.append(line)
			_rt(body, "[color=#8a9cb0]Name                   Assignment               Toward you[/color]\n" + "\n".join(lines2), 420)
		"help":
			_rt(body, HELP_TEXT, 520)
		"skills":
			# builds once and keeps itself up to date
			body.add_child(SkillsPanel.new(p))
			w.refresh_fn = Callable()
		"station_map":
			body.add_child(HudWidgets.StationMapView.new())
			body.add_child(UITheme.label("Hover a room for its name. You are the blinking dot.", UITheme.SMALL, UITheme.DIM))
			w.refresh_fn = Callable()
		"objectives":
			_objectives(body, p)
		"crafting":
			_crafting(body, p)
		"airlock_wires":
			_airlock_wires(t.c(&"door"), body, p)
		"write":
			# tg paper: write with a pen; everyone who reads it sees the words
			var te := TextEdit.new()
			te.custom_minimum_size = Vector2(0, 220)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.text = t.tags.get("text", "")
			body.add_child(te)
			var r := _row(body)
			_btn(r, "Save", func():
				t.tags["text"] = te.text.substr(0, 1200)
				t.display_name = "paper" if te.text.strip_edges() == "" else "paper - '%s'" % te.text.strip_edges().split("\n")[0].substr(0, 24)
				Game.visible_message(p.cell, "%s scribbles something on %s." % [p.display_name, t.the()])
				w.queue_free()
			)
			w.refresh_fn = Callable()

## What the shift expects of you: your job's standing orders (tg's job descriptions and
## Burgerstation's objectives), how you're doing on them, and staying alive.
const DEPT_GOALS := {
	"command": [["Keep the ship running", "Check in with each officer and keep the alert state honest."], ["Protect the crew", "Call the ferry if the ship can't be held."]],
	"security": [["Keep the peace", "Answer crimes you see or hear of; cuff and lock up offenders."], ["Guard the armoury and bridge", "Restricted areas stay restricted."]],
	"engineering": [["Keep the lights on", "Power every junction; keep the generators and storage cells charged."], ["Keep the air good", "Fix breaches; watch the air bells and air-plant pressure."]],
	"medical": [["Treat the wounded", "Heal injured crew; bring back anyone who can be saved."], ["Recover the fallen", "Nobody left on the decks."]],
	"science": [["Research", "Advance the ship's artifice and share what you make."], ["Handle the dangerous stuff safely", "Volatiles stay in the workshop."]],
	"service": [["Keep the crew fed and happy", "Food and drink out, the ship clean."]],
	"supply": [["Keep the ship supplied", "Fill orders, haul crates, dig ore."]],
	"civilian": [["Make yourself useful", "Help where you're needed."]],
}

static func _objectives(body: VBoxContainer, p: Entity) -> void:
	if p == null:
		return
	var m: CMob = p.c(&"mob")
	var job: Dictionary = Jobs.JOBS.get(m.job, {})
	var dept: String = job.get("dept", "civilian")
	var h: CHealth = p.c(&"health")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	body.add_child(head)
	head.add_child(UITheme.label(Jobs.title(m.job), UITheme.TITLE, UITheme.ACCENT))
	var sup: String = job.get("supervisor", "")
	head.add_child(UITheme.label("reports to " + (Jobs.title(sup) if sup != "" else "the Guild"), UITheme.SMALL, UITheme.DIM))
	var goals: Array = DEPT_GOALS.get(dept, DEPT_GOALS["civilian"]).duplicate()
	var work: Array = job.get("work", [])
	if not work.is_empty():
		goals.push_front(["Report to your post", "You work in: " + ", ".join(work) + "."])
	goals.append(["Survive the voyage", "Get aboard the ferry when it's called, or hold out until the voyage ends."])
	WindowsNPC.favors(body, p)
	for i in goals.size():
		var g: Array = goals[i]
		var done := false
		if g[0] == "Report to your post":
			var a := Game.map.area_at(p.cell)
			done = a != null and a.name in work
		if g[0] == "Survive the voyage":
			done = h.dead == false and Game.evac and Game.evac.mode == Evac.ESCAPE
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.frame("well", 10, 6))
		body.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var ic := TextureRect.new()
		ic.texture = UITheme.tex("icon_objectives" if not done else "icon_heart")
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = UITheme.GOOD if done else Color.WHITE
		hb.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v)
		v.add_child(UITheme.label(("✓ " if done else "") + g[0], UITheme.BODY, UITheme.GOOD if done else Color.WHITE))
		var d := UITheme.label(g[1], UITheme.SMALL, UITheme.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)

## Burgerstation's crafting grid: drag parts into the 3x3 grid, see what they make, press
## Craft. The recipe list shows what you know how to make; click one to fill the grid
## from what you carry and what's around you.
static func _crafting(body: VBoxContainer, p: Entity) -> void:
	if p == null:
		return
	var hud: HUD = Game.hud
	var grid_arr: Array = hud.craft_grid
	for i in grid_arr.size():
		var it: Entity = grid_arr[i]
		if it != null and (not is_instance_valid(it) or it.removed or not DragDrop.reachable(p, it)):
			grid_arr[i] = null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(UITheme.caption("Parts"))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	left.add_child(g)
	for i in 9:
		var sl := InvSlot.new("craft_%d" % i, "", 58)
		sl.set_item(grid_arr[i])
		sl.tooltip_text = (grid_arr[i].display_name.capitalize() + "\nClick to take it out.") if grid_arr[i] else "Drag a part here."
		sl.clicked.connect(hud._on_slot_clicked)
		g.add_child(sl)
	var id := Crafting.match_grid(grid_arr)
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 8)
	left.add_child(res)
	var out := InvSlot.new("craft_out", "", 58)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res.add_child(out)
	var rv := VBoxContainer.new()
	res.add_child(rv)
	if id != "":
		var r: Dictionary = Crafting.RECIPES[id]
		var ghost := Proto.spawn(r["out"], Vector2i(-50, -50))
		out.set_item(ghost)
		out.active = true
		ghost.destroy.call_deferred()
		rv.add_child(UITheme.label(r["name"], UITheme.BODY, UITheme.GOOD))
		rv.add_child(UITheme.label("%s  ·  %.0fs" % [Skills.SKILLS[r["skill"]]["name"], r["time"]], UITheme.SMALL, UITheme.DIM))
	else:
		rv.add_child(UITheme.label("Nothing yet" if not Crafting.tally(grid_arr).is_empty() else "Empty grid", UITheme.BODY, UITheme.DIM))
	var cb := Button.new()
	cb.text = "Craft"
	cb.disabled = id == ""
	cb.pressed.connect(func():
		Crafting.craft(p, grid_arr, func(_m):
			for k in grid_arr.size():
				grid_arr[k] = null
			hud.refresh_inventory()
		)
	)
	left.add_child(cb)
	var clr := Button.new()
	clr.text = "Clear"
	clr.pressed.connect(func():
		for k in grid_arr.size():
			grid_arr[k] = null
	)
	left.add_child(clr)
	row.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	right.add_child(UITheme.caption("Recipes"))
	for rid in Crafting.RECIPES:
		var r2: Dictionary = Crafting.RECIPES[rid]
		var have := Crafting.gather(p, rid)
		var parts := []
		for k in r2["needs"]:
			var nm: String = Proto.P[k]["name"] if Proto.has(k) else k
			parts.append("%s%s" % ["%d " % r2["needs"][k] if r2["needs"][k] > 1 else "", nm])
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = r2["name"]
		b.tooltip_text = "%s\nNeeds: %s\n%s" % [r2["desc"], ", ".join(parts), "Click to put the parts in the grid." if not have.is_empty() else "You don't have the parts to hand."]
		b.disabled = have.is_empty()
		b.icon = Gfx.atlas(Proto.P[r2["out"]].get("sheet", "items"), Proto.P[r2["out"]]["spr"])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(func():
			Crafting.picked = rid
			for k in grid_arr.size():
				grid_arr[k] = null
			var got := Crafting.gather(p, rid)
			for k in mini(got.size(), 9):
				grid_arr[k] = got[k]
		)
		right.add_child(b)
		var need_l := UITheme.label("   " + ", ".join(parts), UITheme.SMALL, UITheme.DIM if have.is_empty() else UITheme.TEXT)
		right.add_child(need_l)

## tg's vending interface: every product with its stock and a Vend button.
static func _vending(vd: CVending, body: VBoxContainer, p: Entity) -> void:
	var m: CMachine = vd.e.c(&"machine")
	if m and not m.operable():
		TGUI.notice(body, "The screen is dark.", "bad")
		return
	var sec := TGUI.section(body, "Products")
	if vd.products.is_empty():
		TGUI.notice(sec, "Nothing stocked.")
		return
	var tbl := TGUI.table(sec, ["Item", "Stock", ""])
	for pr in vd.products:
		var pp: String = pr["proto"]
		var n: int = pr["count"]
		var nm: String = Proto.P.get(pp, {}).get("name", pp)
		var name_l := TGUI.cell(tbl, nm.capitalize(), UITheme.TEXT, UITheme.BODY)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TGUI.cell(tbl, str(n) if n > 0 else "Sold out", TGUI.GOOD if n > 5 else (TGUI.AVERAGE if n > 0 else TGUI.BAD))
		TGUI.button(tbl, "Vend", func(): vd.vend(p, pp), false, n <= 0)

## tg's air alarm interface: status and readings, the lock, the eight modes, the
## thermostat, and every vent and scrubber in the room with its own controls.
static func _air_alarm(al: CAirAlarm, body: VBoxContainer, p: Entity) -> void:
	WindowsMachines._air_alarm(al, body, p)

## tg's canister interface: the gauge, the port, the release regulator, the valve and
## the holding tank.
static func _canister(cc: CCanister, body: VBoxContainer, p: Entity) -> void:
	var tk := cc.tank()
	var pr := cc.pressure()
	var gas_name: String = {"o2": "Oxygen", "n2": "Nitrogen", "plasma": "Plasma", "air": "Air", "co2": "Carbon dioxide", "n2o": "Nitrous oxide"}.get(tk.gas, tk.gas)
	var gauge := ProgressBar.new()
	gauge.max_value = 4600.0
	gauge.value = pr
	gauge.show_percentage = false
	gauge.custom_minimum_size = Vector2(0, 16)
	if tk.gas == "mix" or tk.gas == "":
		gas_name = tk.contents_text().capitalize()
	if cc.kind != "canister":
		var pw := _row(body)
		var onb := _btn(pw, "Power: %s" % ("ON" if cc.on else "off"), func(): cc.set_on(not cc.on, p))
		if cc.on:
			onb.add_theme_color_override("font_color", UITheme.GOOD)
		if cc.kind == "pump":
			_btn(pw, "Direction: %s" % ("out (tank to room)" if cc.pump_out else "in (room to tank)"), func(): cc.pump_out = not cc.pump_out)
			_stepper(body, "Target pressure", "%.0f kPa" % cc.target, [["Min", 0.0], ["-10", cc.target - 10.0], ["+10", cc.target + 10.0], ["Max", CCanister.MAX_RELEASE]], func(v): cc.target = clampf(v, 0.0, CCanister.MAX_RELEASE), true)
	_rt(body, "[b]%s[/b]   Tank pressure [color=#7fd4ff]%.0f kPa[/color]  (%.0f mol)
Port: %s" % [gas_name, pr, tk.moles,
		"[color=#6ae88a]connected[/color]" if cc.port else "[color=#8a9cb0]not connected[/color]"])
	body.add_child(gauge)
	var rr := _row(body)
	rr.add_child(UITheme.label("Release pressure  ", 14))
	_btn(rr, "Min", func(): cc.set_release(0.0))
	_btn(rr, "-10", func(): cc.set_release(cc.release_pressure - 10.0))
	rr.add_child(UITheme.label(" %.0f kPa " % cc.release_pressure, 15, UITheme.ACCENT))
	_btn(rr, "+10", func(): cc.set_release(cc.release_pressure + 10.0))
	_btn(rr, "Max", func(): cc.set_release(CCanister.MAX_RELEASE))
	var vr := _row(body)
	var vb := _btn(vr, "Valve: OPEN" if cc.valve_open else "Valve: closed", func(): cc.toggle_valve(p))
	if cc.valve_open:
		vb.add_theme_color_override("font_color", UITheme.WARN)
		if cc.holding == null:
			vr.add_child(UITheme.label("  releasing into the air!", 14, UITheme.WARN))
	var hr := _row(body)
	if cc.holding:
		var ht: CTank = cc.holding.c(&"tank")
		hr.add_child(UITheme.label("Holding: %s, %.0f kPa  " % [cc.holding.display_name, ht.pressure_kpa()], 14))
		_btn(hr, "Eject", func(): cc.eject_tank(p))
	else:
		hr.add_child(UITheme.label("Holding: no tank (use a tank on the canister to insert it)", 14, UITheme.DIM))

## tg's pump / valve / filter / thermomachine interfaces.
static func _pipe_machine(pm: CPipeMachine, body: VBoxContainer, p: Entity) -> void:
	var a = pm.net_in()
	var b = pm.net_out()
	var ok := pm.can_control(p)
	var st := _row(body)
	var power_txt := "Open" if pm.kind == "valve" else "Power"
	var ob := _btn(st, "%s: %s" % [power_txt, ("ON" if pm.on else "off") if pm.kind != "valve" else ("OPEN" if pm.on else "closed")], func(): pm.set_on(not pm.on, p))
	ob.disabled = not ok
	if pm.on:
		ob.add_theme_color_override("font_color", UITheme.GOOD)
	if not ok:
		st.add_child(UITheme.label("  Locked: air-works access needed.", UITheme.SMALL, UITheme.WARN))
	match pm.kind:
		"pump":
			_stepper(body, "Output pressure", "%.0f kPa" % pm.target_pressure, [["Min", 0.0], ["-100", pm.target_pressure - 100.0], ["-10", pm.target_pressure - 10.0], ["+10", pm.target_pressure + 10.0], ["+100", pm.target_pressure + 100.0], ["Max", CPipeMachine.MAX_PRESSURE]], func(v): pm.adjust("target", v, p), ok)
		"vpump", "filter":
			_stepper(body, "Transfer rate", "%.0f L/s" % pm.rate, [["Min", 0.0], ["-20", pm.rate - 20.0], ["+20", pm.rate + 20.0], ["Max", CPipeMachine.MAX_RATE]], func(v): pm.adjust("rate", v, p), ok)
		"mixer", "gate", "pvalve":
			_stepper(body, "Output pressure" if pm.kind != "pvalve" else "Opens above", "%.0f kPa" % pm.target_pressure, [["Min", 0.0], ["-100", pm.target_pressure - 100.0], ["-10", pm.target_pressure - 10.0], ["+10", pm.target_pressure + 10.0], ["+100", pm.target_pressure + 100.0], ["Max", CPipeMachine.MAX_PRESSURE]], func(v): pm.adjust("target", v, p), ok)
			if pm.kind == "mixer":
				var n1 := pm.node1_conc
				_stepper(body, "Node 1 / node 2", "%d%% / %d%%" % [roundi(n1 * 100.0), roundi((1.0 - n1) * 100.0)], [["0%", 0.0], ["-10", n1 - 0.1], ["-1", n1 - 0.01], ["+1", n1 + 0.01], ["+10", n1 + 0.1], ["100%", 1.0], ["Air 79/21", 0.79]], func(v): pm.adjust("node1", v, p), ok)
		"thermo":
			var t := pm.target_temp
			_stepper(body, "Target temperature", "%.0f K  (%.0f°C)" % [t, t - Defs.T0C], [["Min", CPipeMachine.TEMP_RANGE[0]], ["-10", t - 10.0], ["-1", t - 1.0], ["+1", t + 1.0], ["+10", t + 10.0], ["Max", CPipeMachine.TEMP_RANGE[1]], ["20°C", Defs.T20C]], func(v): pm.adjust("temp", v, p), ok)
			var n = Game.pipes.net_at(pm.layer, pm.e.cell + pm.dir_in)
			_rt(body, "Pipe: [color=#7fd4ff]%s[/color]" % ("%.0f K  (%.0f°C), %.0f kPa" % [n.temp, n.temp - Defs.T0C, n.pressure()] if n else "not connected"))
	if pm.kind == "filter":
		var fr := _row(body)
		fr.add_child(UITheme.label("Filter  ", UITheme.SMALL))
		for g in [-1, Defs.G_O2, Defs.G_N2, Defs.G_CO2, Defs.G_PLASMA, Defs.G_N2O, Defs.G_H2O]:
			var gb := _btn(fr, "Nothing" if g < 0 else Defs.GAS_NAMES[g].replace("Carbon Dioxide", "CO2").replace("Nitrous Oxide", "N2O").replace("Water Vapor", "H2O"), func(): pm.adjust("gas", g, p))
			gb.disabled = not ok
			if pm.filter_gas == g:
				gb.add_theme_color_override("font_color", UITheme.ACCENT)
	if pm.inline():
		var lines := []
		lines.append("Input:  %s" % (_net_txt(a) if a else "[color=#8a9cb0]not connected[/color]"))
		lines.append("Output: %s" % (_net_txt(b) if b else "[color=#8a9cb0]not connected[/color]"))
		if pm.kind in ["filter", "mixer"]:
			var sn = pm.net_side()
			lines.append("%s %s" % ["Side:  " if pm.kind == "filter" else "Node 2:", _net_txt(sn) if sn else "[color=#8a9cb0]not connected[/color]"])
		lines.append("[color=#8a9cb0]Moving %.1f mol/tick[/color]" % pm.moved_last)
		_rt(body, "
".join(lines))

## tg's airlock wire panel: every wire, cut or intact, and the door's status lights.
static func _airlock_wires(d: CDoor, body: VBoxContainer, p: Entity) -> void:
	if not d.panel_open:
		_rt(body, "[color=#8a9cb0]The panel is closed. Use a screwdriver on the door.[/color]")
		return
	var lights := "Bolts: %s   Power: %s   Shock: %s" % [
		"[color=#ff5a4a]DOWN[/color]" if d.bolted else "[color=#6ae88a]up[/color]",
		"[color=#6ae88a]on[/color]" if d.powered() else "[color=#ff5a4a]off[/color]",
		"[color=#ff5a4a]LIVE[/color]" if d.electrified() else "[color=#6ae88a]safe[/color]"]
	_rt(body, lights)
	var cols := {"red": "#e84a3a", "blue": "#4a8aff", "green": "#4ad86a", "yellow": "#e8d84a", "orange": "#e89a3a", "purple": "#a86ae8", "pink": "#ff8ac8", "white": "#f0f0f0"}
	for c in d.wires:
		var r := _row(body)
		var wire_name := "%s wire" % c.capitalize()
		if Traits.has(p, "know_engi_wires"): wire_name += " (%s)" % d.wires[c]
		var l := UITheme.label(wire_name.rpad(14) + ("  (cut)" if d.cut.has(c) else ""), UITheme.BODY, Color(cols.get(c, "#ffffff")))
		l.custom_minimum_size = Vector2(180, 0)
		r.add_child(l)
		var col: String = c
		if d.cut.has(c):
			_btn(r, "Mend", func(): d.wire_action(p, col, "mend"))
		else:
			_btn(r, "Cut", func(): d.wire_action(p, col, "cut"))
			_btn(r, "Pulse", func(): d.wire_action(p, col, "pulse"))
	_rt(body, "[color=#8a9cb0]Wirecutters cut and mend; a multitool pulses. Which wire does what is different on every door.[/color]")

static func _net_txt(n) -> String:
	return "[color=#7fd4ff]%.0f kPa[/color]  %.0f°C  %.0f mol" % [n.pressure(), n.temp - Defs.T0C, n.total_moles()]

static func _stepper(body: VBoxContainer, label: String, value: String, steps: Array, cb: Callable, ok: bool) -> void:
	var r := _row(body)
	r.add_child(UITheme.label(label + "  ", UITheme.SMALL))
	for i in steps.size():
		if i == steps.size() / 2:
			r.add_child(UITheme.label(" %s " % value, UITheme.BODY, UITheme.ACCENT))
		var v: float = steps[i][1]
		var b := _btn(r, steps[i][0], func(): cb.call(v))
		b.disabled = not ok

static func _set_alert(p: Entity, lvl: int) -> void:
	if p.c(&"inv").has_access("command"):
		Game.set_alert(lvl, "By order of %s." % p.display_name)
	else:
		Game.tell(p, "Access denied.", "bad")

static var _evac_reason := ""

static func _evac_controls(body: VBoxContainer, p: Entity) -> void:
	var ev: Evac = Game.evac
	if ev == null:
		return
	var r := _row(body)
	if ev.mode in [Evac.IDLE, Evac.RECALLED]:
		var le := LineEdit.new()
		le.placeholder_text = "Nature of emergency%s" % (" (required above green)" if Game.alert_level > 0 else "")
		le.text = _evac_reason
		le.custom_minimum_size = Vector2(360, 0)
		le.text_changed.connect(func(txt): Windows._evac_reason = txt)
		le.text_submitted.connect(func(_txt): le.release_focus())
		r.add_child(le)
		var b := _btn(r, "Call ferry", func(): Windows._call_evac(p))
		b.disabled = ev.can_call() != ""
	elif ev.mode == Evac.CALLED:
		var b2 := _btn(r, "Recall ferry", func(): Windows._recall_evac(p))
		b2.disabled = not ev.can_recall()

static func _call_evac(p: Entity) -> void:
	if not p.c(&"inv").has_access("command"):
		Game.tell(p, "Access denied.", "bad")
		return
	if Game.evac.request_by(p, _evac_reason):
		_evac_reason = ""

static func _recall_evac(p: Entity) -> void:
	if not p.c(&"inv").has_access("command"):
		Game.tell(p, "Access denied.", "bad")
		return
	Game.evac.recall_by(p)

static func _cycle_mode(apc: CApc, ch: String) -> void:
	var order := ["auto", "on", "off"]
	apc.modes[ch] = order[(order.find(apc.modes[ch]) + 1) % 3]
	apc.update_channels()

static func _storage_click(p: Entity, stg: CStorage, itv: Entity, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		Game.hud.show_context_for([itv])
	elif button == MOUSE_BUTTON_LEFT:
		_take(p, stg, itv)

static func _take(p: Entity, stg: CStorage, itv: Entity) -> void:
	if not itv in stg.contents or not DragDrop.reachable(p, stg.e):
		return
	if p.c(&"inv").free_hand() >= 0:
		DragDrop.apply(p, itv, {"kind": "hand", "idx": p.c(&"inv").free_hand()}, false)
	else:
		Game.tell(p, "Your hands are full.", "warn")
	Game.hud.refresh_inventory()
	for w in Game.hud.windows.get_children():
		if w is UIWindow and w.kind == "storage":
			w.refresh_t = 0.0

static func _attitude(a: float) -> String:
	if a > 35:
		return "[color=#6ae88a]friendly[/color]"
	if a > 12:
		return "[color=#a8d88a]warm[/color]"
	if a < -35:
		return "[color=#ff5a4a]hostile[/color]"
	if a < -12:
		return "[color=#ffb84a]wary[/color]"
	return "[color=#9aa8b8]neutral[/color]"

static func _known_dead(m: Entity) -> bool:
	for en in Game.chronicle.entries:
		if en["text"].begins_with(m.display_name) and en["text"].contains("died"):
			return true
	return false

static func _on(v: bool) -> String:
	return "[color=#6ae88a]ON[/color]" if v else "[color=#ff5a4a]OFF[/color]"

const HELP_TEXT := """[b][color=#7fd4ff]Skyfarer - a guide to the sky and your hands.[/color][/b]
Settings (F9): HUD scale, text size, volume and every key below can be changed.

[b][color=#ffd970]Flying her, from cold[/color][/b]
1. Walk to the [b]boiler[/b], right-click it, [b]Light the burner[/b]. Wait about ten seconds for pressure.
2. Left-click the [b]wheel[/b] to take it. Hold [b]W[/b] for throttle, [b]S[/b] to close it, [b]A[/b] / [b]D[/b] for rudder. [b]Space[/b] is all stop.
3. [b]Q[/b] / [b]E[/b] trim ballast lighter or heavier while at the wheel - trim with E or she climbs away from you. [b]R[/b] sets or furls sail.
4. [b]G[/b] opens the ship panel: every gauge, with a plain-words reading of what it means and what to do about it.
Getting ashore: bring her alongside, stop, let go of the wheel, and walk into the rail. A bulwark is chest height, so you climb it.
Nothing steps off an edge by accident. [b]Shift[/b] + a direction steps off on purpose.

[b][color=#ffd970]Ports and money[/color][/b]
Every door on the quay is a trader; click one to open their counter. Nothing in a port can go wrong: nobody there can be attacked.
[b]J[/b] the bench - everything you can make, and what is stopping you. [b]I[/b] the drawing board, on the ship you stand on.
[b]P[/b] skills. The purse (marks) is at the top left and counts up or down as you trade.

[b][color=#ffd970]Moving and looking[/color][/b]
WASD move · C cycles walk / run / sneak · mouse wheel or +/- zoom · F5 first person · Shift+click examine
The bar above your hands names what is under the mouse and what a click would do.

[b][color=#ffd970]Hands and items[/color][/b]
Left click uses your active hand on something. X swap hands · Z use the held item · Q drop (on foot) · E equip · F throw · Tab inventory.
Right-click anything for a menu of actions. Drag items between slots, the hotbar (5 6 7 8 9 0) and the floor.
Click a bag or belt to open it as a row above your hands. Ctrl+click pulls a crate; V lets go.

[b][color=#ffd970]Fighting[/color][/b]
1 help · 2 disarm (shove) · 3 grab · 4 harm · R flips help and harm. The doll, bottom right, aims each hand.
Wildlife telegraphs every attack a turn before it lands: step aside, put a wall between you, or kill it faster.
B resists a grab or puts you out if you are burning.

[b][color=#ffd970]The interface[/color][/b]
The message log (top right) tucks its tabs away when quiet; hover it to bring them back. The [b]Worn[/b] button unfolds the gear slots.
F2 arranges the HUD (drag panels; drag the log's corner to resize) · F1 this guide · F7 hides tutorial prompts
F3 / F4 debug overlays · F6 speeds up time · Esc closes the front window, then pauses."""


# ------------------------------------------------------------------ debug (F10)
static func _toggle(r: Control, label: String, on: bool, cb: Callable) -> void:
	var b := _btn(r, "%s: %s" % [label, "ON" if on else "off"], cb)
	if on:
		b.add_theme_color_override("font_color", UITheme.GOOD)

static func _debug_menu(body: VBoxContainer, p: Entity) -> void:
	_rt(body, "[color=#8aa0b4]%s[/color]" % BuildInfo.line())
	var hud: HUD = Game.hud
	_rt(body, "[b]Views[/b]")
	var r1 := _row(body)
	_toggle(r1, "Atmos readout (F3)", hud.debug_atmos, func(): hud.debug_atmos = not hud.debug_atmos)
	_toggle(r1, "Crew thoughts (F4)", hud.debug_ai, func(): hud.debug_ai = not hud.debug_ai)
	var r2 := _row(body)
	_toggle(r2, "Pipe x-ray", TerrainChunk.xray, func():
		TerrainChunk.xray = not TerrainChunk.xray
		Game.view._redraw_all())
	_toggle(r2, "Pipe gas overlay", PipeDebugLayer.enabled, func(): PipeDebugLayer.enabled = not PipeDebugLayer.enabled)
	_btn(r2, "Pipe networks...", func(): hud.open_window("pipe_nets", null))
	var r3 := _row(body)
	var lm = Game.view.lightmap
	_toggle(r3, "Fullbright", lm != null and not lm.visible, func():
		if lm:
			lm.visible = not lm.visible)
	_toggle(r3, "God mode", Game.god_mode, func(): Game.god_mode = not Game.god_mode)
	var rm := _row(body)
	_toggle(rm, "Unlimited money", Economy.infinite, func():
		Economy.infinite = not Economy.infinite
		Bus.powers_changed.emit()
		Game.msg("[color=#e8c85a]Unlimited money %s.[/color]" % ("ON — every purchase is free" if Economy.infinite else "off"), "info"))
	_btn(rm, "+10,000 marks", func(): if p != null: Economy.give(p, 10000))
	_rt(body, "[b]Time[/b]  (now x%s)" % str(Game.time_scale))
	var r4 := _row(body)
	for sp in [0.5, 1.0, 2.0, 4.0, 8.0]:
		_btn(r4, "x%s" % str(sp), func(): Game.time_scale = sp)
	_btn(r4, "Pause atmos" if Game.atmos.process_mode != Node.PROCESS_MODE_DISABLED else "Resume atmos", func():
		Game.atmos.process_mode = Node.PROCESS_MODE_DISABLED if Game.atmos.process_mode != Node.PROCESS_MODE_DISABLED else Node.PROCESS_MODE_INHERIT)
	if p == null:
		return
	_rt(body, "[b]You[/b]")
	var r5 := _row(body)
	_btn(r5, "Heal fully", func():
		# tg fully_heal(HEAL_ORGANS | HEAL_TRAUMAS): new organs, no traumas
		p.c(&"health").organs = Organs.fresh()
		Traumas.cure_all(p.c(&"health"), Traumas.RES_ABSOLUTE)
		p.c(&"health").terror = 0.0
		p.c(&"health").revive()
		p.c(&"health").body_temp = Defs.BODYTEMP_NORMAL
		p.c(&"health").core_temp = Defs.BODYTEMP_NORMAL)
	_btn(r5, "All access", func():
		var idc: Entity = p.c(&"inv").worn("id")
		if idc and idc.has_c(&"idcard"):
			idc.c(&"idcard").access = ["captain", "command", "security", "brig", "armory", "engineering", "engine", "atmos", "maint", "medical", "research", "cargo", "janitor", "hop", "eva", "external", "tech"]
			Game.tell(p, "Your pass now opens everything.", "good"))
	var r6 := _row(body)
	r6.add_child(UITheme.label("Spawn: ", UITheme.SMALL))
	var le := LineEdit.new()
	le.placeholder_text = "proto id, e.g. wrench, canister_plasma"
	le.custom_minimum_size = Vector2(260, 0)
	r6.add_child(le)
	_btn(r6, "Spawn", func():
		var id := le.text.strip_edges()
		if Proto.P.has(id):
			var it := Proto.spawn(id, p.cell)
			if it.has_c(&"item"):
				p.c(&"inv").put_in_hands(it)
		else:
			Game.tell(p, "No such thing: %s" % id, "warn"))
	_rt(body, "[b]Gas on the tile under the mouse[/b]")
	var r7 := _row(body)
	for gg in [Defs.G_O2, Defs.G_N2, Defs.G_CO2, Defs.G_PLASMA, Defs.G_N2O, Defs.G_H2O, Defs.G_TRITIUM]:
		_btn(r7, "+%s" % Defs.GAS_NAMES[gg].replace("Carbon Dioxide", "CO2").replace("Nitrous Oxide", "N2O").replace("Water Vapor", "H2O"), func():
			var c: Vector2i = Game.view.hover_cell
			if Game.map.inb(c):
				Game.atmos.add_gas(Game.map.idx(c), gg, 50.0, Defs.T20C)
				Game.atmos.wake(c))
	var r8 := _row(body)
	_btn(r8, "Ignite", func(): Game.atmos.ignite(Game.view.hover_cell, p, 8.0))
	_btn(r8, "Vacuum", func():
		var c: Vector2i = Game.view.hover_cell
		if Game.map.inb(c):
			var i := Game.map.idx(c)
			for g in Defs.GAS_COUNT:
				Game.atmos.gas[g][i] = 0.0
			Game.atmos.wake(c))
	_btn(r8, "Break window", func(): Structures.break_window(Game.view.hover_cell, p) if Game.map.inb(Game.view.hover_cell) else null)
	_rt(body, "[color=#8a9cb0]Hover the map to aim the gas buttons. With the pipe gas overlay on, hovering a pipe shows what's in it.[/color]")

## One line about a pipe network: pressure, temperature, what's in it, flow.
static func net_summary(net) -> String:
	var tot: float = net.total_moles()
	var parts := []
	if tot > 0.001:
		for g in Defs.GAS_COUNT:
			if net.gas[g] / tot > 0.005:
				parts.append("%s %.0f%%" % [Defs.GAS_NAMES[g].replace("Carbon Dioxide", "CO2").replace("Nitrous Oxide", "N2O").replace("Water Vapor", "H2O"), net.gas[g] / tot * 100.0])
	return "%.0f kPa  %.0f°C  %.1f mol  [%s]  %s" % [net.pressure(), net.temp - Defs.T0C, tot, ", ".join(parts) if not parts.is_empty() else "empty", ("flowing %.2f mol/tick" % net.flow) if net.flow > 0.001 else "still"]

## Every pipe network: layer, size, contents, flow. Click one to outline it on the map.
static func _pipe_nets(body: VBoxContainer) -> void:
	if Game.pipes == null:
		return
	var nets: Array = Game.pipes.nets.duplicate()
	nets.sort_custom(func(a, b): return a.flow > b.flow if absf(a.flow - b.flow) > 0.001 else a.total_moles() > b.total_moles())
	var active := nets.filter(func(n2): return n2.flow > 0.001).size()
	_rt(body, "%d networks, %d with gas moving. Sorted by flow. [color=#8a9cb0]Click Show to outline one on the map (turns the overlay on).[/color]" % [nets.size(), active])
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	body.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var shown := 0
	for net in nets:
		if net.total_moles() < 0.01 and net.flow <= 0.001:
			continue
		shown += 1
		if shown > 120:
			break
		var r := _row(list)
		var c: Vector2i = Game.map.cell_of(net.cells[0]) - Vector2i(MapGen.SX, MapGen.SY)
		var where := Game.map.area_at(Game.map.cell_of(net.cells[0])).name
		var col: Color = PipeDebugLayer.GAS_COLORS[PipeDebugLayer.main_gas(net)]
		var l := UITheme.label("%-6s %4d tiles  %s" % [StationMap.PIPE_LAYER_NAMES[net.layer], net.cells.size(), where.left(20)], UITheme.SMALL, col)
		l.custom_minimum_size = Vector2(250, 0)
		r.add_child(l)
		var t2 := UITheme.label(net_summary(net), UITheme.SMALL)
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2.clip_text = true
		r.add_child(t2)
		_btn(r, "Show", func():
			PipeDebugLayer.enabled = true
			PipeDebugLayer.selected = net
			if Game.view:
				Game.view.camera.global_position = Entity.cell_to_pos(Game.map.cell_of(net.cells[0]))
			Game.tell(Game.player, "Showing the %s network at %s." % [StationMap.PIPE_LAYER_NAMES[net.layer], c]) if Game.player else null)
