class_name CRPD extends Component
## tg Rapid Pipe Dispenser (code/game/objects/items/rcd/RPD.dm). Z opens its menu.
##   build     pipe: lays smart pipe on the tile, joined to every neighbouring pipe on the
##             chosen layer. Devices go onto an existing pipe on that layer: pumps, valves,
##             gates and injectors on a straight run (flowing the chosen way), filters and
##             mixers on a T junction, vents/scrubbers/ports/meters anywhere on it
##   destroy   takes the pipe (and anything built into it) off the tile

var mode := "build"
var category := "pipe"
var layer := StationMap.PL_SUPPLY
var flow := Vector2i.RIGHT

const LAYERS := [StationMap.PL_SUPPLY, StationMap.PL_SCRUB, StationMap.PL_GEN, StationMap.PL_AUX]
## category -> [proto, shape] (shape: pipe, straight, tee, any)
const DEVICES := {
	"pipe": ["", "pipe"],
	"pump": ["pump", "straight"], "volume_pump": ["volume_pump", "straight"], "valve": ["manual_valve", "straight"],
	"passive_gate": ["passive_gate", "straight"], "pressure_valve": ["pressure_valve", "straight"],
	"filter": ["gas_filter", "tee"], "mixer": ["gas_mixer", "tee"],
	"vent": ["vent", "any"], "scrubber": ["scrubber", "any"], "injector": ["gas_injector", "any"],
	"passive_vent": ["passive_vent", "any"], "connector": ["connector_port", "any"], "meter": ["meter", "any"],
	"he_pipe": ["he_pipe", "any"],
}
const NAMES := {"pipe": "Pipe", "pump": "Pressure pump", "volume_pump": "Volumetric pump", "valve": "Manual valve", "passive_gate": "Passive gate",
	"pressure_valve": "Pressure valve", "filter": "Gas filter", "mixer": "Gas mixer", "vent": "Vent", "scrubber": "Scrubber",
	"injector": "Air injector", "passive_vent": "Passive vent", "connector": "Connector port", "meter": "Gas meter", "he_pipe": "Heat exchanger"}

func key() -> StringName:
	return &"rpd"

func attack_self(_user: Entity) -> bool:
	Bus.ui_open_window.emit("rpd", e)
	return true

func act(user: Entity, cell: Vector2i) -> bool:
	var map := Game.map
	if not map.inb(cell) or not Entity.cells_adjacent(user.cell, cell):
		return false
	if map.is_solid_turf(cell) or map.is_outdoor(cell):
		Game.tell(user, "You can't lay pipe there.", "warn")
		return true
	if mode == "destroy":
		var l := layer if map.pipe_mask(layer, cell) != 0 else -1
		if l < 0:
			for k in StationMap.PIPE_LAYER_COUNT:
				if map.pipe_mask(k, cell) != 0:
					l = k
					break
		if l < 0:
			Game.tell(user, "There's no pipe there.", "warn")
			return true
		DoAfter.start(user, null, 1.0, func(ok):
			if not ok:
				return
			for x in Game.at(cell).duplicate():
				var pm: CPipeMachine = x.c(&"pipemachine")
				var v: CVent = x.c(&"vent")
				if (pm and pm.layer == l) or (v and v.layer == l) or (x.has_c(&"meter") and x.c(&"meter").layer == l) or (x.has_c(&"hepipe") and x.c(&"hepipe").layer == l):
					x.destroy()
			PipeWork._remove(l, cell)
			for f in Game.at(cell).duplicate():
				if f.proto == "pipe_fitting":
					f.destroy()
			Sfx.play("ratchet", cell, 0.6)
			Game.visible_message(cell, "%s takes the pipe apart with %s." % [user.display_name, e.the()]))
		return true
	var spec: Array = DEVICES[category]
	var mask := map.pipe_mask(layer, cell)
	if spec[1] == "pipe":
		if mask != 0:
			Game.tell(user, "There's already a %s pipe there." % PipeWork.LAYER_NAMES[mini(layer, 3)], "warn")
			return true
		var links := []
		for k in 4:
			var n: Vector2i = cell + Defs.DIRS4[k]
			if map.inb(n) and map.pipe_mask(layer, n) != 0 and not Game.pipes.inline[layer].has(map.idx(n)):
				links.append(n)
		if links.is_empty():
			Game.tell(user, "There's no pipe on that layer next to it to join.", "warn")
			return true
		DoAfter.start(user, null, 0.5, func(ok):
			if ok and map.pipe_mask(layer, cell) == 0:
				for n in links:
					map.connect_pipe(layer, cell, n)
					Bus.tile_changed.emit(n)
				Bus.pipes_changed.emit()
				Bus.tile_changed.emit(cell)
				Sfx.play("ratchet", cell, 0.5))
		return true
	# a device on the pipe
	if mask == 0:
		Game.tell(user, "There's no pipe on that layer to fit it on.", "warn")
		return true
	if spec[0] != "he_pipe" and (Game.pipes.inline[layer].has(map.idx(cell)) or Game.at(cell).any(func(x): return x.has_c(&"pipemachine") or x.has_c(&"vent") or x.has_c(&"meter"))):
		Game.tell(user, "Something's already fitted there.", "warn")
		return true
	if spec[1] == "any" and proto_is_he(spec[0]) and Game.at(cell).any(func(x): return x.has_c(&"hepipe")):
		Game.tell(user, "There are already fins on that pipe.", "warn")
		return true
	var dirs := []
	for k in 4:
		if mask & (1 << k):
			dirs.append(Defs.DIRS4[k])
	var d_in := Vector2i.ZERO
	var d_out := Vector2i.ZERO
	var d_side := Vector2i.ZERO
	match spec[1]:
		"straight":
			if dirs.size() != 2 or dirs[0] != -dirs[1]:
				Game.tell(user, "That needs a straight run of pipe.", "warn")
				return true
			# flow toward the chosen direction if it's along the pipe
			d_out = flow if flow in dirs else dirs[1]
			d_in = -d_out
		"tee":
			if dirs.size() != 3:
				Game.tell(user, "That needs a T junction.", "warn")
				return true
			for dd in dirs:
				if not -dd in dirs:
					d_side = dd
			var axis := dirs.filter(func(x): return x != d_side)
			d_out = flow if flow in axis else axis[1]
			d_in = -d_out
	var proto: String = spec[0]
	DoAfter.start(user, null, 1.0, func(ok):
		if not ok:
			return
		var comps := {}
		if Proto.P[proto]["comps"].has("pipemachine"):
			comps["pipemachine"] = {"layer": layer}
		elif Proto.P[proto]["comps"].has("vent"):
			comps["vent"] = {"layer": layer}
		elif Proto.P[proto]["comps"].has("meter"):
			comps["meter"] = {"layer": layer}
		elif Proto.P[proto]["comps"].has("hepipe"):
			comps["hepipe"] = {"layer": layer}
		var dev := Proto.spawn(proto, cell, {"comps": comps})
		var pm: CPipeMachine = dev.c(&"pipemachine")
		if pm:
			pm.dir_in = d_in
			pm.dir_out = d_out
			pm.dir_side = d_side
		Game.pipes.dirty = true
		Bus.pipes_changed.emit()
		Sfx.play("ratchet", cell, 0.6)
		Game.visible_message(cell, "%s fits %s with %s." % [user.display_name, dev.display_name, e.the()]))
	return true

func examine(_user: Entity, lines: Array) -> void:
	lines.append("Mode: %s. %s on the %s layer. (Z to change.)" % [mode, NAMES[category], StationMap.PIPE_LAYER_NAMES[layer]])

static func proto_is_he(p: String) -> bool:
	return p == "he_pipe"
