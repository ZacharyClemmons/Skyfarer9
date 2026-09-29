class_name AtmosOverlay extends Node2D
## Makes the pipework readable:
##  - gas flow: bright pulses run along any pipe network that has gas moving through it,
##    from where gas enters it (pump outputs, inlets) toward where it leaves (pump inputs,
##    injectors, vents), so you can see which way things are going;
##  - device arrows: every pump, filter, mixer and valve shows which way it moves gas (lit
##    when it's actually moving some, pale when idle, red when off), and injectors, inlets
##    and vents show gas coming out of or going into them;
##  - name tags: every atmos device is labelled (tg's own names: "Air to Distro", "N2 to Pure"...).
## All of it only shows while you hold a gas analyzer (in either hand).

const PERIOD := 2.0 # how often the flow directions are worked out again
var _t := 0.0
var _rebuild := 0.0
var _flow := {} # PipeNet -> Dictionary(cell idx -> steps from where gas comes in): gas moving now
var _design := {} # the same for every network with devices on it, running or not
var _font: Font

func _ready() -> void:
	_font = UITheme.font

var _shown := false

func _process(delta: float) -> void:
	_t += delta
	var show := analyzer_view()
	if show != _shown:
		_shown = show
		_rebuild = 0.0 # work the directions out now, not up to PERIOD after picking it up
		queue_redraw()
	if not show:
		return
	_rebuild -= delta
	if _rebuild <= 0.0:
		_rebuild = PERIOD
		_compute_flow()
	queue_redraw()

static var force_labels := false # screenshots
static var force_show := false # screenshots: the analyzer view without holding one

## Holding a gas analyzer in either hand: the pipe arrows, flow, tags and readouts show.
static func analyzer_held() -> bool:
	var p := Game.player
	if p == null or p.c(&"inv") == null:
		return false
	for held in [p.c(&"inv").active_item(), p.c(&"inv").other_item()]:
		if held != null and held.has_c(&"gasanalyzer"):
			return true
	return false

static func analyzer_view() -> bool:
	return force_show or force_labels or analyzer_held()

static func labels_wanted() -> bool:
	return force_labels or analyzer_held()

# ------------------------------------------------------------------ flow directions
## Which way gas goes in every network, worked out from the devices on it: pump and
## filter outputs, inlets and scrubbers put gas in; pump inputs, injectors and vents take
## it out. `_design` covers every network with devices (whether they're running or not);
## `_flow` only the ones with gas actually moving this moment.
func _compute_flow() -> void:
	_flow = _directions(true)
	_design = _directions(false)

func _directions(active_only: bool) -> Dictionary:
	var out := {}
	if Game.pipes == null:
		return out
	var srcs := {} # net -> [cells]
	var sinks := {}
	for m in Game.pipes.machines:
		if not is_instance_valid(m) or m.removed:
			continue
		var pm: CPipeMachine = m.c(&"pipemachine")
		if pm == null or not pm.inline():
			continue
		if active_only and pm.moved_last <= 0.0001:
			continue
		var out_n = pm.net_out()
		var in_n = pm.net_in()
		if out_n:
			_push(srcs, out_n, [pm.layer, m.cell + pm.dir_out])
		if in_n:
			_push(sinks, in_n, [pm.layer, m.cell + pm.dir_in])
		if pm.dir_side != Vector2i.ZERO:
			var side = pm.net_side()
			if side:
				if pm.kind == "filter":
					_push(srcs, side, [pm.layer, m.cell + pm.dir_side])
				else:
					_push(sinks, side, [pm.layer, m.cell + pm.dir_side])
	for id in Game.pipes.devices:
		for entry in Game.pipes.devices[id]:
			var ent: Entity = entry[2]
			if not is_instance_valid(ent) or ent.removed or not ent.has_c(&"vent"):
				continue
			var v: CVent = ent.c(&"vent")
			var n = Game.pipes.net_at(entry[0], ent.cell + entry[1])
			if n == null:
				continue
			var feeds := false # puts gas into the pipe
			var drains := false
			if active_only:
				if absf(v.moved_last) < 0.0001:
					continue
				feeds = v.moved_last < 0.0
				drains = v.moved_last > 0.0
			else:
				match v.mode:
					"vent":
						feeds = v.siphon
						drains = not v.siphon
					"scrubber", "siphon":
						feeds = true
					"injector", "outlet":
						drains = true
			if feeds:
				_push(srcs, n, [entry[0], ent.cell + entry[1]])
			elif drains:
				_push(sinks, n, [entry[0], ent.cell + entry[1]])
	for net in Game.pipes.nets:
		var from: Array = srcs.get(net, [])
		var toward: Array = sinks.get(net, [])
		if from.is_empty() and toward.is_empty():
			continue
		var d := _bfs(net, from if not from.is_empty() else toward)
		if from.is_empty():
			# only know where gas leaves: flip, so it still runs toward the exits
			var mx := 0
			for k in d:
				mx = maxi(mx, d[k])
			for k in d:
				d[k] = mx - d[k]
		out[net] = d
	return out

static func _push(dict: Dictionary, net, c: Array) -> void:
	if not dict.has(net):
		dict[net] = []
	dict[net].append(c)

## Steps from `starts` ([layer, cell] pairs) along the network, following pipes on each
## layer and hopping between layers where an adaptor joins them. Keys are pipe keys
## (layer * w*h + tile), so each layer's pipe on a tile gets its own distance.
func _bfs(net, starts: Array) -> Dictionary:
	var map := Game.map
	var n_tiles := map.w * map.h
	var dist := {}
	var q := []
	for st in starts:
		var k: int = map.pipe_key(st[0], st[1])
		if _on_net(net, st[0], st[1]) and not dist.has(k):
			dist[k] = 0
			q.append(st)
	var head := 0
	while head < q.size():
		var l: int = q[head][0]
		var c: Vector2i = q[head][1]
		head += 1
		var here: int = dist[map.pipe_key(l, c)]
		var nexts := []
		var m := map.pipe_mask(l, c)
		for d in 4:
			if m & (1 << d):
				nexts.append([l, c + Defs.DIRS4[d]])
		if map.pipe_links.has(map.idx(c)):
			for l2 in StationMap.PIPE_LAYER_COUNT:
				if l2 != l:
					nexts.append([l2, c])
		for nx in nexts:
			var nk: int = map.pipe_key(nx[0], nx[1])
			if not dist.has(nk) and map.inb(nx[1]) and _on_net(net, nx[0], nx[1]):
				dist[nk] = here + 1
				q.append(nx)
	return dist

func _on_net(net, l: int, c: Vector2i) -> bool:
	var map := Game.map
	if not map.inb(c):
		return false
	var i := map.idx(c)
	var gs := map.pipe_groups_at(l, c)
	for g in gs.size():
		if Game.pipes.node_net[l].get(i * 4 + g) == net:
			return true
	return false

# ------------------------------------------------------------------ drawing
func _view_rect() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var vs := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vs
	return Rect2(a, b - a).grow(64)

func _pipe_seen(layer: int, c: Vector2i) -> bool:
	var map := Game.map
	var fl: int = Defs.TURFS[map.turf[map.idx(c)]]["flags"]
	var covered := (fl & Defs.F_FLOOR) != 0 or (fl & Defs.F_WALL) != 0
	if not covered or map.pipe_shown.has(map.pipe_key(layer, c)) or TerrainChunk.xray:
		return true
	var o := CTray.player_scan_origin()
	return o.x > -9000 and Vector2(c - o).length() <= CTray.RANGE + 0.5

func _can_see(c: Vector2i) -> bool:
	return Game.lighting == null or Game.lighting.full_bright or Game.lighting.player_can_see(c)

func _draw() -> void:
	if Game.map == null or Game.pipes == null or not _shown:
		return
	var view := _view_rect()
	var map := Game.map
	# which way every pipe carries its gas: a small arrow at each joint
	var n_tiles := map.w * map.h
	for net in _design:
		var dd: Dictionary = _design[net]
		var has_gas: bool = net.total_moles() > 0.01
		var col2: Color = _net_color(net).lerp(Color.WHITE, 0.3) if has_gas else Color(0.75, 0.8, 0.88)
		col2.a = 0.75 if has_gas else 0.4
		_each_step(dd, view, func(ctr: Vector2, dir: Vector2): _chevron(ctr + dir * 17.0, dir, col2, 2.6))
	# gas moving along the pipes right now
	for net in _flow:
		if net.flow < 0.005 and net.total_moles() < 0.01:
			continue
		var col: Color = _net_color(net).lerp(Color.WHITE, 0.35) if net.total_moles() > 0.01 else Color.WHITE
		_each_step(_flow[net], view, func(ctr: Vector2, dir: Vector2):
			for s in 3:
				var f := fposmod(_t * 1.2 + s / 3.0, 1.0)
				var p := ctr + dir * 32.0 * f
				var a := sin(f * PI)
				draw_line(p - dir * 6.0, p, Color(col, 0.35 * a), 2.0)
				draw_circle(p, 2.2, Color(0, 0, 0, 0.5 * a))
				draw_circle(p, 1.7, Color(col, 0.95 * a)))
	# the devices
	var labels := labels_wanted()
	var tags := []
	for m in Game.pipes.machines:
		if not is_instance_valid(m) or m.removed:
			continue
		var ctr := Vector2(m.cell) * Defs.TILE + Vector2(16, 16)
		if not view.has_point(ctr) or not _can_see(m.cell):
			continue
		var pm: CPipeMachine = m.c(&"pipemachine")
		if pm == null:
			continue
		_machine_arrows(pm, ctr + Vector2.ONE * PipeHover.LAYER_PX[pm.layer])
		if labels:
			tags.append([ctr + Vector2(0, -14), label_for(m)])
	for id in Game.pipes.devices:
		for entry in Game.pipes.devices[id]:
			var ent: Entity = entry[2]
			if not is_instance_valid(ent) or ent.removed:
				continue
			var ctr2 := Vector2(ent.cell) * Defs.TILE + Vector2(16, 16)
			if not view.has_point(ctr2) or not _can_see(ent.cell):
				continue
			if ent.has_c(&"vent"):
				_vent_arrows(ent.c(&"vent"), ctr2)
			if labels and (ent.has_c(&"vent") and ent.c(&"vent").mode in ["injector", "siphon", "passive", "port", "outlet"] or ent.has_c(&"meter")):
				tags.append([ctr2 + Vector2(0, -14), label_for(ent)])
	if labels:
		# tg layer adaptors: where lines on different pipe layers join
		for li in map.pipe_links:
			var lc := map.cell_of(li)
			var lp := Vector2(lc) * Defs.TILE + Vector2(16, 16)
			if view.has_point(lp) and _can_see(lc):
				tags.append([lp + Vector2(0, -12), "Layer adaptor"])
		for mt in Game.all_with(&"meter"):
			var c3 := Vector2(mt.cell) * Defs.TILE + Vector2(16, 16)
			if view.has_point(c3) and _can_see(mt.cell) and not Game.pipes.devices.has(mt.get_instance_id()):
				tags.append([c3 + Vector2(0, -14), label_for(mt)])
		_draw_tags(tags)

## A network's colour: breathable air is sky blue, anything else its main gas.
static func _net_color(net) -> Color:
	if PipeHover.net_name(net) in ["Air pipe", "Air supply pipe"]:
		return Color("#9ad8ff")
	return TGUI.GAS_COLORS[PipeDebugLayer.main_gas(net)]

## Calls fn(centre, direction) for every pipe step that runs downstream (from a tile to
## the next one further from where the gas comes in), on the visible part of the map.
func _each_step(dd: Dictionary, view: Rect2, fn: Callable) -> void:
	var map := Game.map
	var n_tiles := map.w * map.h
	for key in dd:
		var l: int = key / n_tiles
		var c := map.cell_of(key % n_tiles)
		var off: float = PipeHover.LAYER_PX[l]
		var ctr := Vector2(c) * Defs.TILE + Vector2(16.0 + off, 16.0 + off)
		if not view.has_point(ctr) or not _pipe_seen(l, c) or not _can_see(c):
			continue
		var m := map.pipe_mask(l, c)
		for k in 4:
			if not (m & (1 << k)):
				continue
			var nc: Vector2i = c + Defs.DIRS4[k]
			if not map.inb(nc):
				continue
			var nk := map.pipe_key(l, nc)
			if dd.get(nk, -1) == dd[key] + 1:
				fn.call(ctr, Vector2(Defs.DIRS4[k]))

func _chevron(at: Vector2, dir: Vector2, col: Color, size := 4.5) -> void:
	var n := Vector2(-dir.y, dir.x)
	var tip := at + dir * size
	draw_line(tip, tip - dir * size + n * size, Color(0, 0, 0, col.a * 0.8), 3.2)
	draw_line(tip, tip - dir * size - n * size, Color(0, 0, 0, col.a * 0.8), 3.2)
	draw_line(tip, tip - dir * size + n * size, col, 1.6)
	draw_line(tip, tip - dir * size - n * size, col, 1.6)

func _state_col(active: bool, on: bool) -> Color:
	if not on:
		return Color(1.0, 0.35, 0.3, 0.55)
	if active:
		return Color("#6aff9a").lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 6.0))
	return Color(0.85, 0.9, 0.95, 0.7)

func _machine_arrows(pm: CPipeMachine, ctr: Vector2) -> void:
	if not pm.inline():
		return
	var active := pm.moved_last > 0.0001
	var col := _state_col(active, pm.working())
	var dout := Vector2(pm.dir_out)
	var din := Vector2(pm.dir_in)
	if pm.kind == "valve":
		# open: a bar along the pipe; closed: a bar across it
		var along := dout if dout != Vector2.ZERO else Vector2.RIGHT
		var across := Vector2(-along.y, along.x)
		var bar := along if pm.on else across
		draw_line(ctr - bar * 6.0, ctr + bar * 6.0, Color(0, 0, 0, 0.8), 4.0)
		draw_line(ctr - bar * 6.0, ctr + bar * 6.0, Color("#6aff9a") if pm.on else Color("#ff5a4a"), 2.0)
		return
	var big := 5.5 if active else (4.0 if pm.working() else 3.0)
	if dout != Vector2.ZERO:
		_chevron(ctr + dout * 9.0, dout, col, big)
	if din != Vector2.ZERO:
		_chevron(ctr - din * 9.0 + dout * 0.0, -din, Color(col, col.a * 0.6), 3.5)
	if pm.dir_side != Vector2i.ZERO:
		var ds := Vector2(pm.dir_side)
		if pm.kind == "filter":
			var gc: Color = TGUI.GAS_COLORS[pm.filter_gas] if pm.filter_gas >= 0 else Color(0.6, 0.6, 0.6)
			_chevron(ctr + ds * 9.0, ds, Color(gc.lerp(Color.WHITE, 0.2), col.a))
		else:
			_chevron(ctr + ds * 9.0, -ds, Color(col, col.a * 0.6), 3.5)

func _vent_arrows(v: CVent, ctr: Vector2) -> void:
	if absf(v.moved_last) < 0.0005:
		return
	var out := v.moved_last > 0.0
	var col := Color("#9ae8ff") if out else Color("#ffd27a")
	var ph := fposmod(_t * 1.2, 1.0)
	for k in 4:
		var dir := Vector2(Defs.DIRS4[k])
		var r := (8.0 + ph * 7.0) if out else (15.0 - ph * 7.0)
		_chevron(ctr + dir * r, dir if out else -dir, Color(col, 0.75 * sin(ph * PI)), 3.0)

# ------------------------------------------------------------------ names
## What to call a device on its tag and in the examine bar.
static func label_for(ent: Entity) -> String:
	if ent.has_c(&"pipemachine"):
		var pm: CPipeMachine = ent.c(&"pipemachine")
		var kind_name: String = {"pump": "Pump", "vpump": "Volume pump", "valve": "Valve", "filter": "Filter", "mixer": "Mixer",
			"gate": "Passive gate", "pvalve": "Pressure valve", "thermo": "Freezer" if pm.freezer else "Heater"}.get(pm.kind, "Machine")
		var nm := pm.display if pm.display != "" else kind_name
		if pm.kind == "filter" and not pm.filters.is_empty():
			var gs := []
			for g in pm.filters:
				gs.append(TGUI.GAS_SHORT[g])
			nm += " (%s)" % ", ".join(gs)
		return nm
	if ent.has_c(&"vent"):
		var v: CVent = ent.c(&"vent")
		var gas: String = CConsole.TANK_NAMES.get(v.monitored, "")
		match v.mode:
			"injector": return ("%s injector" % gas) if gas != "" else "Injector"
			"siphon": return ("%s outlet" % gas) if gas != "" else "Outlet"
			"passive": return "Open pipe end"
			"port": return "Connector port"
			"outlet": return "Outlet"
			"scrubber": return "Scrubber"
		return "Vent"
	if ent.has_c(&"meter"):
		var mt: CMeter = ent.c(&"meter")
		var n = mt.net()
		return "Meter %s" % (TGUI.kpa(n.pressure()) if n else "-")
	return ent.display_name.capitalize()

func _draw_tags(tags: Array) -> void:
	var z: float = get_viewport().get_canvas_transform().get_scale().x
	var s := 1.0 / maxf(z, 0.01)
	var fs := 12
	var placed := [] # screen-size rects, in world space
	for t in tags:
		var txt: String = t[1]
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box_w := (w + 8) * s
		var box_h := (fs + 6) * s
		var pos: Vector2 = t[0]
		var r := Rect2(pos + Vector2(-box_w * 0.5, -box_h), Vector2(box_w, box_h))
		# stack upward past anything already placed
		for k in 6:
			var hit := false
			for q in placed:
				if q.intersects(r):
					hit = true
					break
			if not hit:
				break
			r.position.y -= box_h + 1.0 * s
		placed.append(r)
		# a leader line when it had to move
		if absf(r.end.y - pos.y) > 1.0:
			draw_line(pos, Vector2(pos.x, r.end.y), Color(UITheme.ACCENT, 0.4), 1.0 * s)
		draw_set_transform(Vector2(r.position.x + box_w * 0.5, r.end.y), 0.0, Vector2(s, s))
		var rr := Rect2(Vector2(-w * 0.5 - 4, -fs - 4), Vector2(w + 8, fs + 6))
		draw_rect(rr, Color(0.03, 0.05, 0.08, 0.85))
		draw_rect(rr, Color(UITheme.ACCENT, 0.5), false, 1.0)
		draw_string(_font, Vector2(-w * 0.5, -3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.96, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_legend(s)

## What the colours mean, in the top-left of the view while the labels are up.
func _draw_legend(s: float) -> void:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var at := inv * Vector2(16, 110)
	draw_set_transform(at, 0.0, Vector2(s, s))
	var rows := [[Color("#6aff9a"), "moving gas"], [Color(0.85, 0.9, 0.95), "on, nothing to move"], [Color(1.0, 0.35, 0.3), "off"],
		[Color("#9ae8ff"), "vent / injector releasing"], [Color("#ffd27a"), "inlet drawing in"]]
	draw_rect(Rect2(0, 0, 250, 22 + rows.size() * 18 + 22), Color(0.03, 0.05, 0.08, 0.85))
	draw_rect(Rect2(0, 0, 250, 22 + rows.size() * 18 + 22), Color(UITheme.ACCENT, 0.5), false, 1.0)
	draw_string(_font, Vector2(8, 16), "ATMOS  (release Alt to hide)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.ACCENT)
	for i in rows.size():
		var y := 34 + i * 18
		_chevron(Vector2(16, y - 4), Vector2.RIGHT, rows[i][0], 4.0)
		draw_string(_font, Vector2(30, y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 0.95))
	var yy := 34 + rows.size() * 18
	draw_circle(Vector2(12, yy - 4), 2.0, Color.WHITE)
	draw_circle(Vector2(20, yy - 4), 2.0, Color(1, 1, 1, 0.6))
	draw_string(_font, Vector2(30, yy), "gas flowing along a pipe", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One line for the examine bar: what it is doing right now.
static func describe(ent: Entity) -> String:
	if ent.has_c(&"pipemachine"):
		var pm: CPipeMachine = ent.c(&"pipemachine")
		var st := "off" if not pm.on else ("moving %.2f mol/s" % pm.moved_last if pm.moved_last > 0.0001 else "idle")
		var what := ""
		match pm.kind:
			"pump": what = "pushes gas along to %.0f kPa" % pm.target_pressure
			"vpump": what = "moves %.0f L/s" % pm.rate
			"valve": return "valve  ·  %s  ·  click to %s" % ["OPEN" if pm.on else "closed", "close" if pm.on else "open"]
			"filter":
				var gs2 := []
				for g in pm.filters:
					gs2.append(TGUI.GAS_SHORT[g])
				what = "sends %s out the side" % (", ".join(gs2) if not gs2.is_empty() else "nothing")
			"mixer": what = "mixes %d%% / %d%% to %.0f kPa" % [roundi(pm.node1_conc * 100.0), roundi((1.0 - pm.node1_conc) * 100.0), pm.target_pressure]
			"gate", "pvalve": what = "one way, opens at %.0f kPa" % pm.target_pressure
			"thermo": what = "holds the pipe at %.0f K" % pm.target_temp
		var a = pm.net_in()
		var b = pm.net_out()
		var io := ""
		if pm.inline() and a and b:
			io = "  ·  in %s  ->  out %s" % [TGUI.kpa(a.pressure()), TGUI.kpa(b.pressure())]
		return "%s  ·  %s%s" % [what, st, io]
	if ent.has_c(&"vent"):
		var v: CVent = ent.c(&"vent")
		var mv := v.moved_last
		var flow := "idle" if absf(mv) < 0.0005 else ("releasing %.2f mol/s" % mv if mv > 0 else "drawing in %.2f mol/s" % -mv)
		var job: String = {"injector": "pipe gas into the room", "siphon": "room gas into the pipe", "vent": "keeps the room at %.0f kPa" % v.target_pressure,
			"scrubber": "pulls bad gases out of the room", "passive": "pipe and room share their gas", "port": "a canister connects here"}.get(v.mode, v.mode)
		return "%s  ·  %s  ·  %s" % [job, "on" if v.on else "off", flow]
	return ""
