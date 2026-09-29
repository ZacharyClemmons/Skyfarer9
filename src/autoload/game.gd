extends Node
## Global game state: entity registry + spatial/component indices, simulation clock,
## and references to the running systems. Systems are created by Main.

var rng := RandomNumberGenerator.new()
var seed_value := 0
var time := 0.0 # simulated real-time seconds since shift start
var time_scale := 1.0
var paused := false
var god_mode := false # debug: the player takes no damage
var running := false

var map: StationMap
var world: Node2D
var ents_node: Node2D
var atmos
var power
var pipes
var lighting
var life
var ai
var director
var chronicle
var evac
var sky      # SkySystem: day/night, wind, falling, island climate
var fleet    # ShipSystem: every airship in the region
var hud
var view # WorldView (renderer)

var player: Entity
var entities := {} # id -> Entity
var comp_index := {} # StringName -> {id: Entity}
var cell_index := {} # Vector2i -> Array[Entity]
var _next_id := 1
var alert_level := 0 # 0 green, 1 blue, 2 red, 3 delta
const ALERT_NAMES := ["ALL CLEAR", "ON GUARD", "BATTLE STATIONS", "ABANDON SHIP"]
const ALERT_COLORS := [Color("#5ad87a"), Color("#4a8ad8"), Color("#e84a4a"), Color("#ff3aff")]

func _ready() -> void:
	_setup_input()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Perf.on = "--perf" in OS.get_cmdline_user_args() or "--perf" in OS.get_cmdline_args()

func _process(delta: float) -> void:
	if Perf.on:
		Perf.frame(delta)
	if running and not paused:
		time += delta * time_scale

# ------------------------------------------------------------------ registry
func register(e: Entity) -> void:
	e.id = _next_id
	_next_id += 1
	entities[e.id] = e
	for k in e.comps.keys():
		index_comp(e, k)
	if e.holder == null:
		_cell_add(e, e.cell)
	Bus.entity_spawned.emit(e)

func unregister(e: Entity) -> void:
	entities.erase(e.id)
	for k in e.comps.keys():
		unindex_comp(e, k)
	# always clear its cell: something destroyed while its holder was already gone would
	# otherwise stay in the index as a freed object
	_cell_remove(e, e.cell)

func index_comp(e: Entity, k: StringName) -> void:
	if e.id == 0:
		return
	if not comp_index.has(k):
		comp_index[k] = {}
	comp_index[k][e.id] = e

func unindex_comp(e: Entity, k: StringName) -> void:
	if comp_index.has(k):
		comp_index[k].erase(e.id)

func all_with(k: StringName) -> Array:
	if not comp_index.has(k):
		return []
	return comp_index[k].values()

func get_entity(id: int) -> Entity:
	var e = entities.get(id)
	if e != null and is_instance_valid(e) and not e.removed:
		return e
	return null

const NO_CELL := Vector2i(-99999, -99999)

## Each entity sits in exactly one cell_index slot, the one recorded in `indexed_at`, so
## moving, dropping or destroying it always clears the right slot even if its `cell` was
## changed behind the index's back (the stale-index bug the AI used to trip over).
func _cell_add(e: Entity, c: Vector2i) -> void:
	if e.indexed_at == c and cell_index.has(c) and e in cell_index[c]:
		return # dropped onto the map twice: one entry is enough
	_cell_remove(e, c)
	if not cell_index.has(c):
		cell_index[c] = []
	cell_index[c].append(e)
	e.indexed_at = c

func _cell_remove(e: Entity, _c: Vector2i) -> void:
	var at_c: Vector2i = e.indexed_at
	if at_c == NO_CELL:
		return
	if cell_index.has(at_c):
		cell_index[at_c].erase(e)
		if cell_index[at_c].is_empty():
			cell_index.erase(at_c)
	e.indexed_at = NO_CELL

func cell_index_move(e: Entity, old: Vector2i, new: Vector2i) -> void:
	if e.id == 0:
		return
	_cell_remove(e, old)
	_cell_add(e, new)

## Called when an entity is picked up / put in a container (leaves the map index).
func lift_from_map(e: Entity) -> void:
	_cell_remove(e, e.cell)

func drop_to_map(e: Entity, c: Vector2i) -> void:
	e.cell = c
	_cell_add(e, c)

func at(c: Vector2i) -> Array:
	return cell_index.get(c, [])

func at_with(c: Vector2i, k: StringName) -> Array:
	var out := []
	for e in cell_index.get(c, []):
		if e.has_c(k):
			out.append(e)
	return out

func first_at_with(c: Vector2i, k: StringName) -> Entity:
	for e in cell_index.get(c, []):
		if e.has_c(k):
			return e
	return null

func in_radius(c: Vector2i, r: int, k: StringName = &"") -> Array:
	var out := []
	if k != &"" and comp_index.has(k) and comp_index[k].size() < (2 * r + 1) * (2 * r + 1):
		for e in comp_index[k].values():
			if e.holder == null and absi(e.cell.x - c.x) <= r and absi(e.cell.y - c.y) <= r:
				out.append(e)
		return out
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			for e in cell_index.get(Vector2i(x, y), []):
				if k == &"" or e.has_c(k):
					out.append(e)
	return out

# ------------------------------------------------------------------ time
func station_seconds() -> float:
	return Defs.SHIFT_START_HOUR * 3600.0 + time * Defs.SIM_TIME_SCALE

func clock_string() -> String:
	var s := int(station_seconds()) % 86400
	return "%02d:%02d" % [s / 3600, (s / 60) % 60]

func minutes_since(t: float) -> float:
	## Station minutes elapsed since sim time t.
	return (time - t) * Defs.SIM_TIME_SCALE / 60.0

# ------------------------------------------------------------------ messaging helpers
func msg(text: String, kind := "info") -> void:
	Bus.chat.emit(text, kind)

## Message shown to the player only if `to` is the player.
func tell(to: Entity, text: String, kind := "info") -> void:
	if to != null and to == player:
		Bus.chat.emit(text, kind)

## Visible message: shown to the player if they can see `cell`.
func visible_message(cell: Vector2i, text: String, kind := "emote") -> void:
	if player != null and lighting != null and lighting.player_can_see(cell):
		Bus.chat.emit(text, kind)

func set_alert(level: int, reason := "") -> void:
	if level == alert_level:
		return
	alert_level = level
	if evac:
		evac.on_alert_changed(level)
	var texts := [
		"All threats to the ship have passed. The Watch may stand down and stow their arms.",
		"The ship has word of possible hostile activity. The Watch may go armed and searches of the hold are permitted.",
		"There is an immediate serious threat to the ship. The Watch may keep their weapons drawn at all times. Searches are allowed and advised.",
		"The ship is lost. All hands are to obey the orders of the officers and make for the boats.",
	]
	Bus.announcement.emit("Ship alert: %s" % ALERT_NAMES[level], texts[level] + ("\n" + reason if reason != "" else ""), 2 if level >= 2 else 1)

# ------------------------------------------------------------------ input map
func _setup_input() -> void:
	var binds := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"drop": [KEY_Q], "swap_hands": [KEY_X], "use_self": [KEY_Z], "combat": [KEY_R], "throw": [KEY_F],
		"talk": [KEY_T, KEY_ENTER], "radio_talk": [KEY_Y], "inventory": [KEY_TAB], "walk_toggle": [KEY_C],
		"resist": [KEY_B], "chronicle": [KEY_L], "help": [KEY_F1], "pause_menu": [KEY_ESCAPE], "equip": [KEY_E],
		"debug_atmos": [KEY_F3], "debug_ai": [KEY_F4], "debug_menu": [KEY_F10], "zoom_in": [KEY_EQUAL], "zoom_out": [KEY_MINUS],
		"pull_stop": [KEY_V], "time_fast": [KEY_F6], "knowledge": [KEY_K], "hud_layout": [KEY_F2], "skills": [KEY_P],
		"intent_help": [KEY_1], "intent_disarm": [KEY_2], "intent_grab": [KEY_3], "intent_harm": [KEY_4],
		"station_map": [KEY_M], "crafting": [KEY_N], "objectives": [KEY_O], "aim_preset": [KEY_H],
		"rest": [KEY_U], "hotbar_0": [KEY_5], "hotbar_1": [KEY_6], "hotbar_2": [KEY_7], "hotbar_3": [KEY_8], "hotbar_4": [KEY_9], "hotbar_5": [KEY_0],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
