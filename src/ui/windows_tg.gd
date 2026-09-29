class_name WindowsTG extends RefCounted
## Windows for the tg machines and consoles ported in the machines pass: lathes, the
## destructive analyzer, the R&D console's techweb, the cargo console, security records
## and the gas tank consoles. Windows.build() hands these kinds over.

static var lathe_cat := {} # lathe entity id -> selected category
static var cargo_cat := "Emergency"

static func handles(kind: String) -> bool:
	return kind in ["lathe", "danalyzer", "rnd", "cargo", "secrecords", "arcade", "disposal", "chemmachine", "chem", "rcd", "rpd", "forensic_scanner"]

static func title(kind: String, t: Entity) -> String:
	match kind:
		"lathe": return t.c(&"lathe").title()
		"danalyzer": return "Destructive Analyzer"
		"rnd": return "R&D Console"
		"cargo": return "Hold Ledger"
		"secrecords": return "Watch Records"
		"tank_console": return t.c(&"console").title()
		"arcade": return "Battle Arcade"
		"chemmachine": return "ChemMaster 3000" if t.c(&"chemmachine").kind == "master" else "Chemical Heater"
		"chem": return "Chem Dispenser"
		"rcd": return "Rapid Construction Device"
		"rpd": return "Rapid Pipe Dispenser"
		"disposal": return "Disposal Unit"
		"forensic_scanner": return "Forensic Scanner"
	return kind

static func width(kind: String) -> int:
	return {"chemmachine": 620, "chem": 600, "lathe": 640, "danalyzer": 440, "rnd": 720, "cargo": 720, "secrecords": 760, "tank_console": 480, "forensic_scanner": 560}.get(kind, 480)

static func interval(kind: String) -> float:
	return {"lathe": 1.0, "rnd": 1.0, "cargo": 1.0, "secrecords": 2.0}.get(kind, 0.75)

static func build(kind: String, t: Entity, body: VBoxContainer, w: UIWindow) -> void:
	var p := Game.player
	match kind:
		"lathe": _lathe(t.c(&"lathe"), body, p)
		"danalyzer": _danalyzer(t.c(&"danalyzer"), body, p)
		"rnd": _rnd(body, p)
		"cargo": _cargo(body, p)
		"secrecords": _secrecords(body, p)
		"forensic_scanner": _forensic_scanner(t.c(&"gadget"), body, p)
		"tank_console": _tank(t.c(&"console"), body, p)
		"arcade": _arcade(t.c(&"fixture"), body, p)
		"disposal": _disposal(t.c(&"fixture"), body, p)
		"chemmachine": _chemmachine(t.c(&"chemmachine"), body, p)
		"chem": _dispenser(t, body, p)
		"rcd": _rcd(t.c(&"rcd"), body, p)
		"rpd": _rpd(t.c(&"rpd"), body, p)

static func _hdr(body: Control, text: String) -> void:
	body.add_child(UITheme.label(text, UITheme.BODY, UITheme.ACCENT))

# ------------------------------------------------------------------ lathes
static func _lathe(l: CLathe, body: VBoxContainer, p: Entity) -> void:
	var mats := []
	for m in l.mats:
		mats.append("%s [color=#7fd4ff]%.0f[/color]" % [CLathe.MAT_NAMES[m], l.mats[m]])
	Windows._rt(body, "  ".join(mats) + ("\n[color=#ffb84a]Printing: %s (%d queued)[/color]" % [Research.DESIGNS[l.queue[0]["id"]]["proto"], l.queue.size()] if not l.queue.is_empty() else "\n[color=#8a9cb0]Insert sheets or ore to add materials.[/color]"))
	var er := Windows._row(body)
	for m in CLathe.MAT_SHEET:
		var mm: String = m
		var b := Windows._btn(er, "Eject %s" % CLathe.MAT_NAMES[m], func(): l.eject(p, mm, 50))
		b.disabled = l.mats[m] < CLathe.SHEET
	var designs := Research.designs_for(l.kind)
	var cats := []
	for id in designs:
		var c: String = Research.DESIGNS[id]["cat"]
		if not c in cats:
			cats.append(c)
	var sel: String = lathe_cat.get(l.e.id, cats[0] if not cats.is_empty() else "")
	var cr := Windows._row(body)
	for c in cats:
		var cc: String = c
		var b := Windows._btn(cr, c, func(): WindowsTG.lathe_cat[l.e.id] = cc)
		b.toggle_mode = true
		b.button_pressed = c == sel
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	body.add_child(grid)
	for id in designs:
		var d: Dictionary = Research.DESIGNS[id]
		if d["cat"] != sel:
			continue
		var nm: String = d.get("name", Proto.P.get(d["proto"], {}).get("name", d["proto"]))
		if d.has("amount"):
			nm = "%s (x%d)" % [nm, d["amount"]]
		var cost := []
		for m in d["mats"]:
			cost.append("%s %d" % [CLathe.MAT_NAMES[m].substr(0, 2), d["mats"][m]])
		var did: String = id
		var r := HBoxContainer.new()
		grid.add_child(r)
		var b1 := Windows._btn(r, nm.capitalize(), func(): l.print_design(p, did, 1))
		b1.custom_minimum_size = Vector2(190, 0)
		b1.disabled = not l.can_afford(id, 1)
		var b5 := Windows._btn(r, "x5", func(): l.print_design(p, did, 5))
		b5.disabled = not l.can_afford(id, 5)
		r.add_child(UITheme.label(" ".join(cost), UITheme.SMALL, UITheme.DIM))
	if l.kind == "protolathe":
		body.add_child(UITheme.label("Research more nodes at the R&D console to unlock designs.", UITheme.SMALL, UITheme.DIM))

# ------------------------------------------------------------------ destructive analyzer
static func _danalyzer(da: CDAnalyzer, body: VBoxContainer, p: Entity) -> void:
	if da.loaded == null:
		Windows._rt(body, "[color=#8a9cb0]No item loaded. Use an item on the analyzer to load it.[/color]\nResearch points: [color=#7fd4ff]%.0f[/color]" % Research.points)
		return
	var v := Research.analyze_value(da.loaded)
	Windows._rt(body, "Loaded: [b]%s[/b]\n%s\nResearch points: [color=#7fd4ff]%.0f[/color]" % [da.loaded.display_name,
		("Deconstructing it will yield [color=#6ae88a]%.0f[/color] points." % v) if v > 0 else "[color=#ffb84a]The servers already know everything about this.[/color]", Research.points])
	var r := Windows._row(body)
	Windows._btn(r, "Deconstruct", func(): da.destroy_item(p))
	Windows._btn(r, "Eject", func(): da.eject(p))

# ------------------------------------------------------------------ techweb
static func _rnd(body: VBoxContainer, p: Entity) -> void:
	var servers := 0
	for s in Game.all_with(&"machine"):
		if s.proto == "server_rack" and s.c(&"machine").operable():
			servers += 1
	Windows._rt(body, "Research points: [color=#7fd4ff][b]%.0f[/b][/color]   ·   %d server%s online (+%d/s)   ·   %d things analyzed" % [Research.points, servers, "" if servers == 1 else "s", servers, Research.analyzed.size()])
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	body.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var order := Research.NODES.keys()
	order.sort_custom(func(a, b):
		var ra := 0 if Research.available(a) else (1 if not Research.is_researched(a) else 2)
		var rb := 0 if Research.available(b) else (1 if not Research.is_researched(b) else 2)
		if ra != rb:
			return ra < rb
		return Research.NODES[a]["tier"] < Research.NODES[b]["tier"])
	for id in order:
		var n: Dictionary = Research.NODES[id]
		var done := Research.is_researched(id)
		var avail := Research.available(id)
		var designs := []
		for did in Research.designs_of(id):
			designs.append(Research.DESIGNS[did].get("name", Proto.P.get(Research.DESIGNS[did]["proto"], {}).get("name", did)))
		var pre := []
		for q in n["pre"]:
			pre.append(Research.NODES[q]["name"])
		var r := HBoxContainer.new()
		list.add_child(r)
		var col := "#6ae88a" if done else ("#e8eef4" if avail else "#6a7486")
		var txt := "[color=%s][b]%s[/b][/color]  [color=#8a9cb0]%s[/color]" % [col, n["name"], n["desc"]]
		if not designs.is_empty():
			txt += "\n  [color=#9ab8d8]Unlocks: %s[/color]" % ", ".join(designs)
		if not pre.is_empty() and not done:
			txt += "\n  [color=#8a93a3]Requires: %s[/color]" % ", ".join(pre)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.text = txt
		r.add_child(rt)
		if done:
			r.add_child(UITheme.label("Researched", UITheme.SMALL, UITheme.GOOD))
		else:
			var nid: String = id
			var b := Button.new()
			b.text = "Research (%d)" % int(Research.cost(id))
			b.disabled = not avail or Research.points < Research.cost(id)
			b.pressed.connect(func(): Research.research(nid, p))
			r.add_child(b)

# ------------------------------------------------------------------ cargo
static func _cargo(body: VBoxContainer, p: Entity) -> void:
	Windows._rt(body, "Budget: [color=#7fd4ff][b]%d marks[/b][/color]   ·   %s%s" % [Cargo.points, Cargo.status_text(), ("\n[color=#8a9cb0]%s[/color]" % Cargo.last_report) if Cargo.last_report != "" else ""])
	var r := Windows._row(body)
	var b1 := Windows._btn(r, "Call supply ferry", func(): Cargo.call_shuttle(p))
	b1.disabled = Cargo.state != Cargo.AWAY
	var b2 := Windows._btn(r, "Send ferry away (sells the hold)", func(): Cargo.send_shuttle(p))
	b2.disabled = Cargo.state != Cargo.DOCKED
	if not Cargo.orders.is_empty():
		_hdr(body, "Cart (%d)" % Cargo.orders.size())
		for i in Cargo.orders.size():
			var o: Dictionary = Cargo.orders[i]
			var rr := Windows._row(body)
			rr.add_child(UITheme.label("%s  %d marks  (%s)" % [Cargo.PACKS[o["pack"]]["name"], Cargo.pack_cost(o["pack"]), o["by"]], UITheme.SMALL))
			var ii := i
			Windows._btn(rr, "Cancel", func(): Cargo.cancel(ii, p))
	if not Cargo.requests.is_empty():
		var req := []
		for q in Cargo.requests:
			req.append("%s for %s" % [q["what"], q["dept"]])
		Windows._rt(body, "[color=#ffb84a]Requests:[/color] " + "; ".join(req))
	var cats := []
	for id in Cargo.PACKS:
		if not Cargo.PACKS[id]["cat"] in cats:
			cats.append(Cargo.PACKS[id]["cat"])
	var cr := Windows._row(body)
	for c in cats:
		var cc: String = c
		var b := Windows._btn(cr, c, func(): WindowsTG.cargo_cat = cc)
		b.toggle_mode = true
		b.button_pressed = c == cargo_cat
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 300)
	body.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for id in Cargo.PACKS:
		var pk: Dictionary = Cargo.PACKS[id]
		if pk["cat"] != cargo_cat:
			continue
		var row := HBoxContainer.new()
		list.add_child(row)
		var parts := []
		for q in pk["contains"]:
			parts.append("%s x%d" % [Proto.P.get(q, {}).get("name", q), pk["contains"][q]])
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.text = "[b]%s[/b]  [color=#8a9cb0]%s[/color]" % [pk["name"], ", ".join(parts) if not parts.is_empty() else "an empty crate"]
		row.add_child(rt)
		var pid: String = id
		var b := Button.new()
		b.text = "%d cr" % Cargo.pack_cost(id)
		b.disabled = Cargo.points < Cargo.pack_cost(id)
		b.pressed.connect(func(): Cargo.order(pid, p))
		row.add_child(b)
	body.add_child(UITheme.label("Orders ride in on the supply ferry at the Cargo Hatch. Load exports into its hold before sending it away.", UITheme.SMALL, UITheme.DIM))

# ------------------------------------------------------------------ security records
static func _secrecords(body: VBoxContainer, p: Entity) -> void:
	var can: bool = p != null and p.c(&"inv") != null and (p.c(&"inv").has_access("security") or p.c(&"inv").has_access("brig"))
	if not can:
		body.add_child(UITheme.label("Read-only: Watch access required to change a status.", UITheme.SMALL, UITheme.WARN))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	body.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for m in Game.all_with(&"mob"):
		var mob: CMob = m.c(&"mob")
		if mob.job == "":
			continue
		var st := SecurityRecords.status_of(m.id)
		var row := HBoxContainer.new()
		list.add_child(row)
		var col: String = SecurityRecords.STATUS_COLORS.get(st, "#e8eef4")
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var crime: String = SecurityRecords.wanted[m.id]["crime"] if SecurityRecords.wanted.has(m.id) else ""
		rt.text = "[b]%s[/b], %s  [color=%s]%s[/color]%s" % [m.display_name, Jobs.title(mob.job), col, st, ("  [color=#8a9cb0](%s)[/color]" % crime) if crime != "" else ""]
		var mh: CHealth = m.c(&"health")
		# tg crew records: fingerprint, DNA and blood type, to match forensic evidence against
		rt.text += "
[color=#8a9cb0][font_size=12]Fingerprint %s   DNA %s   Blood %s[/font_size][/color]" % [Forensics.fingerprint(m), Forensics.dna(m), mh.blood_type if mh else "?"]
		row.add_child(rt)
		var ob := OptionButton.new()
		for s in SecurityRecords.STATUSES:
			ob.add_item(s)
		ob.selected = SecurityRecords.STATUSES.find(st)
		ob.disabled = not can
		var mid: int = m.id
		ob.item_selected.connect(func(i): SecurityRecords.set_status(Game.entities.get(mid), SecurityRecords.STATUSES[i], p))
		row.add_child(ob)

# ------------------------------------------------------------------ tank consoles
static func _tank(cc: CConsole, body: VBoxContainer, p: Entity) -> void:
	var lines := []
	for l in cc.readout():
		lines.append(l["text"])
	Windows._rt(body, "\n".join(lines) if not lines.is_empty() else "[color=#8a9cb0]No data.[/color]")
	var mon := "" if cc.tank == "mix" else cc.tank
	for d in Game.all_with(&"vent"):
		var v: CVent = d.c(&"vent")
		if v.monitored != mon or not v.mode in ["injector", "siphon"]:
			continue
		var r := Windows._row(body)
		var vv := v
		r.add_child(UITheme.label("%s  " % ("Input injector" if v.mode == "injector" else "Output inlet"), UITheme.SMALL))
		Windows._btn(r, "Turn %s" % ("off" if v.on else "on"), func():
			vv.on = not vv.on
			Game.tell(p, "You turn the %s %s." % ["injector" if vv.mode == "injector" else "inlet", "on" if vv.on else "off"]))

# ------------------------------------------------------------------ arcade (tg battle arcade)
static func _arcade(f: CFixture, body: VBoxContainer, p: Entity) -> void:
	Windows._rt(body, "[b]%s[/b]\nEnemy HP [color=#ff7a6a]%d/%d[/color]   MP %d\n\nYou: HP [color=#6ae88a]%d/100[/color]   MP [color=#7fd4ff]%d/50[/color]   Wins: %d\n\n[color=#e8d84a]%s[/color]" % [
		f.enemy_name, maxi(0, f.enemy_hp), f.enemy_max, f.enemy_mp, maxi(0, f.player_hp), f.player_mp, f.wins, f.feedback])
	var r := Windows._row(body)
	if f.player_hp <= 0:
		Windows._btn(r, "New game", func(): f.arcade_act(p, "restart"))
		return
	Windows._btn(r, "Attack", func(): f.arcade_act(p, "attack"))
	Windows._btn(r, "Magic attack (10 MP)", func(): f.arcade_act(p, "magic"))
	Windows._btn(r, "Counterattack (10 MP)", func(): f.arcade_act(p, "counter"))
	Windows._btn(r, "Defend", func(): f.arcade_act(p, "defend"))

# ------------------------------------------------------------------ disposal unit
static func _disposal(f: CFixture, body: VBoxContainer, p: Entity) -> void:
	var st: CStorage = f.e.c(&"storage")
	var names := []
	for it in st.contents:
		if is_instance_valid(it) and not it.removed:
			names.append(it.display_name)
	Windows._rt(body, "Pressure: [color=#7fd4ff]%d%%[/color]%s\nHandle: %s\nContents: %s" % [int(f.pressure), "" if f.powered() else " [color=#ffb84a](no power)[/color]",
		"[color=#ffb84a]engaged[/color]" if f.flush_handle else "disengaged", ", ".join(names) if not names.is_empty() else "empty"])
	var r := Windows._row(body)
	Windows._btn(r, "Disengage handle" if f.flush_handle else "Engage handle", func(): f._toggle_flush(p))
	Windows._btn(r, "Eject contents", func(): f._eject_all())

# ------------------------------------------------------------------ chem dispenser (tg chem_dispenser)
static var dispense_amount := 10.0

static func _dispenser(t: Entity, body: VBoxContainer, p: Entity) -> void:
	var held: Entity = p.c(&"inv").active_item()
	var beaker: CReagents = held.c(&"reagents") if held and held.has_c(&"reagents") else null
	if beaker == null or not beaker.is_open():
		Windows._rt(body, "[color=#ffb84a]Hold a beaker or bottle in your active hand.[/color]")
		return
	Windows._rt(body, "%s: %.0f / %.0f u, %d K\n%s" % [held.display_name.capitalize(), beaker.total(), beaker.volume, int(beaker.temp), Chem.describe(beaker.contents)])
	var ar := Windows._row(body)
	ar.add_child(UITheme.label("Amount: ", UITheme.SMALL))
	for a in [1.0, 5.0, 10.0, 20.0, 30.0, 50.0]:
		var aa: float = a
		var b := Windows._btn(ar, str(int(a)), func(): WindowsTG.dispense_amount = aa)
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(a, dispense_amount)
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	var m: CMachine = t.c(&"machine")
	for r in Chem.DISPENSABLE:
		var rr: String = r
		var b2 := Windows._btn(grid, Chem.rname(r), func():
			beaker.add(rr, WindowsTG.dispense_amount, p)
			Sfx.play("pour", t.cell, 0.3))
		b2.disabled = (m != null and not m.operable()) or beaker.free_space() <= 0.0
	Windows._btn(body, "Empty the container", func():
		beaker.contents.clear()
		beaker._update_sprite())

# ------------------------------------------------------------------ ChemMaster / heater
static var master_units := 10.0
static var master_count := 1

static func _chemmachine(cm: CChemMachine, body: VBoxContainer, p: Entity) -> void:
	var r := cm.beaker_r()
	if cm.kind == "heater":
		Windows._rt(body, ("Loaded: %s, %.0f u at [color=#7fd4ff]%d K[/color]\n%s" % [cm.beaker.display_name, r.total(), int(r.temp), Chem.describe(r.contents)]) if r else "[color=#8a9cb0]No beaker loaded. Use one on the heater.[/color]")
		var hr := Windows._row(body)
		Windows._btn(hr, "Turn %s" % ("off" if cm.on else "on"), func(): cm.toggle(p))
		Windows._stepper(body, "Target", "%d K" % int(cm.target_temp), [["-50", -50.0], ["-10", -10.0], ["+10", 10.0], ["+50", 50.0]], func(v): cm.target_temp = clampf(cm.target_temp + v, 10.0, 1000.0), true)
		if r:
			Windows._btn(body, "Eject beaker", func(): cm.eject(p))
		return
	if r == null:
		Windows._rt(body, "[color=#8a9cb0]No beaker loaded. Use one on the ChemMaster.[/color]")
	else:
		Windows._rt(body, "[b]Beaker[/b] (%.0f / %.0f u)" % [r.total(), r.volume])
		for k in r.contents.keys():
			var kk: String = k
			var row := Windows._row(body)
			row.add_child(UITheme.label("%s %.1fu  " % [Chem.rname(k), r.contents[k]], UITheme.SMALL))
			for a in [1.0, 5.0, 10.0]:
				var aa: float = a
				Windows._btn(row, str(int(a)), func(): cm.to_buffer(kk, aa))
			Windows._btn(row, "All", func(): cm.to_buffer(kk, 9999.0))
		Windows._btn(body, "Eject beaker", func(): cm.eject(p))
	Windows._rt(body, "[b]Buffer[/b] (%.0f u)" % cm.buffer_total())
	for k in cm.buffer.keys():
		var kk2: String = k
		var row2 := Windows._row(body)
		row2.add_child(UITheme.label("%s %.1fu  " % [Chem.rname(k), cm.buffer[k]], UITheme.SMALL))
		Windows._btn(row2, "To beaker", func(): cm.from_buffer(kk2, 9999.0))
		Windows._btn(row2, "Discard", func(): cm.from_buffer(kk2, 9999.0, true))
	Windows._stepper(body, "How many", str(master_count), [["-5", -5.0], ["-1", -1.0], ["+1", 1.0], ["+5", 5.0]], func(v): WindowsTG.master_count = clampi(WindowsTG.master_count + int(v), 1, 20), true)
	var pr := Windows._row(body)
	for what in ["pill", "patch", "bottle"]:
		var ww: String = what
		var b := Windows._btn(pr, "Create %s%s" % [what, "es" if what == "patch" and master_count > 1 else ("s" if master_count > 1 else "")], func(): cm.produce(p, ww, WindowsTG.master_count))
		b.disabled = cm.buffer_total() <= 0.0
	body.add_child(UITheme.label("Pills hold up to 50 u, patches 40 u, bottles 30 u; the buffer is split evenly.", UITheme.SMALL, UITheme.DIM))

# ------------------------------------------------------------------ RCD / RPD
static func _rcd(r: CRCD, body: VBoxContainer, p: Entity) -> void:
	Windows._rt(body, "Matter: [color=#7fd4ff]%d / %d[/color]\nFeed it metal sheets (4), glass (2), reinforced glass (6) or a matter cartridge (160)." % [int(r.matter), int(r.max_matter)])
	var g := GridContainer.new()
	g.columns = 2
	body.add_child(g)
	for m in CRCD.MODES:
		var mm: String = m
		var b := Windows._btn(g, CRCD.MODE_NAMES[m], func(): r.set_mode(p, mm))
		b.toggle_mode = true
		b.button_pressed = r.mode == m

static func _rpd(r: CRPD, body: VBoxContainer, p: Entity) -> void:
	var mr := Windows._row(body)
	for m in ["build", "destroy"]:
		var mm: String = m
		var b := Windows._btn(mr, m.capitalize(), func(): r.mode = mm)
		b.toggle_mode = true
		b.button_pressed = r.mode == m
	var lr := Windows._row(body)
	lr.add_child(UITheme.label("Layer: ", UITheme.SMALL))
	for l in CRPD.LAYERS:
		var ll: int = l
		var b2 := Windows._btn(lr, StationMap.PIPE_LAYER_NAMES[l], func(): r.layer = ll)
		b2.toggle_mode = true
		b2.button_pressed = r.layer == l
	var fr := Windows._row(body)
	fr.add_child(UITheme.label("Flow: ", UITheme.SMALL))
	for pair in [["north", Vector2i.UP], ["east", Vector2i.RIGHT], ["south", Vector2i.DOWN], ["west", Vector2i.LEFT]]:
		var dv: Vector2i = pair[1]
		var b3 := Windows._btn(fr, pair[0], func(): r.flow = dv)
		b3.toggle_mode = true
		b3.button_pressed = r.flow == dv
	var g := GridContainer.new()
	g.columns = 3
	body.add_child(g)
	for c in CRPD.DEVICES:
		var cc: String = c
		var b4 := Windows._btn(g, CRPD.NAMES[c], func(): r.category = cc)
		b4.toggle_mode = true
		b4.button_pressed = r.category == c
	body.add_child(UITheme.label("Pipe joins the pipes around it. Devices fit onto a pipe: pumps and valves on a straight run, filters and mixers on a T.", UITheme.SMALL, UITheme.DIM))

## tg ForensicScanner: every scan, by category, with delete, clear and print.
static func _forensic_scanner(gd: CGadget, body: VBoxContainer, p: Entity) -> void:
	var busy: bool = Game.time < gd.scan_busy_until
	var head := TGUI.row(body)
	TGUI.button(head, "Print report", func(): gd.forensic_print(p), false, gd.scan_logs.is_empty() or busy)
	TGUI.button(head, "Clear logs", func(): gd.scan_logs.clear(), false, gd.scan_logs.is_empty() or busy)
	if busy:
		head.add_child(UITheme.label("Analysing...", UITheme.SMALL, TGUI.AVERAGE))
	if gd.scan_logs.is_empty():
		TGUI.notice(body, "No scans yet. Click something (up to 8 tiles away) with the scanner in hand.")
		return
	for i in gd.scan_logs.size():
		var en: Dictionary = gd.scan_logs[i]
		var idx := i
		var del := Button.new()
		del.text = "Delete"
		del.focus_mode = Control.FOCUS_NONE
		del.disabled = busy
		del.pressed.connect(func(): gd.scan_logs.remove_at(idx))
		var sec := TGUI.section(body, "%s  (%s)" % [en["target"], en["time"]], [del])
		if en["data"].is_empty():
			sec.add_child(UITheme.label("No forensic traces found.", UITheme.SMALL, TGUI.LABEL))
		var cols := {"Fingerprints": TGUI.INFO, "Blood": TGUI.BAD, "Fibers": TGUI.AVERAGE, "Reagents": TGUI.GOOD, "Access": UITheme.TEXT}
		for cat in ["Fingerprints", "Blood", "Fibers", "Reagents", "Access"]:
			if not en["data"].has(cat):
				continue
			sec.add_child(UITheme.label(cat, UITheme.SMALL, cols[cat]))
			for line in en["data"][cat]:
				var l := UITheme.label("   " + str(line), UITheme.SMALL, UITheme.TEXT)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				sec.add_child(l)
