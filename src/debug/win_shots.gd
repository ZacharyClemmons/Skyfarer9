class_name WinShots extends Node
## --winshots=DIR: walks up to one of every kind of machine and console, opens its window
## and saves a screenshot cropped to it (win_<kind>.png). For reviewing the machine UIs.

var dir := ""

# [component, window kind, extra filter (console kind) or ""]
const TARGETS := [
	["console", "console", "eng"], ["console", "console", "med"], ["console", "console", "cmd"],
	["console", "console", "reactor"], ["console", "console", "atmos"], ["console", "console", "comms"],
	["console", "rnd", "sci"], ["console", "cargo", "cargo"], ["console", "secrecords", "sec"],
	["console", "tank_console", "tank"],
	["apc", "apc", ""], ["air_alarm", "air_alarm", ""], ["air_supply", "air_supply", ""],
	["canister", "canister", ""], ["pipemachine", "pipe_machine", "pump"], ["pipemachine", "pipe_machine", "vpump"], ["pipemachine", "pipe_machine", "filter"],
	["pipemachine", "pipe_machine", "mixer"], ["pipemachine", "pipe_machine", "valve"], ["pipemachine", "pipe_machine", "thermo"], ["powergen", "power", ""],
	["reactor", "reactor", ""], ["vending", "vending", ""], ["lathe", "lathe", ""],
	["chemmachine", "chemmachine", ""], ["danalyzer", "danalyzer", ""], ["dnaconsole", "dna_console", ""],
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var hud: HUD = Game.hud
	Game.lighting.full_bright = true
	# see the controls unlocked, as an atmos tech would
	var idc = Game.player.c(&"inv").id_card()
	if idc and not "atmos" in idc.access:
		idc.access.append("atmos")
	var done := {}
	for t in TARGETS:
		var ent: Entity = _find(t[0], t[2])
		if ent == null:
			print("WINSHOTS none for %s/%s" % [t[0], t[2]])
			continue
		var tag: String = t[1] + ("_" + t[2] if t[2] != "" else "")
		if done.has(tag):
			continue
		done[tag] = true
		# stand next to it so the window stays open
		for d in Defs.DIRS8 + [Vector2i.ZERO]:
			if Game.map.is_passable(ent.cell + d):
				Game.player.place(ent.cell + d)
				break
		Game.view.camera.position = Entity.cell_to_pos(ent.cell)
		Game.view.camera.reset_smoothing()
		for w in hud.windows.get_children():
			w.queue_free()
		await get_tree().process_frame
		hud.open_window(t[1], ent)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var win: Control = null
		for w in hud.windows.get_children():
			if w is UIWindow and not w.is_queued_for_deletion():
				win = w
		var img := get_viewport().get_texture().get_image()
		if img and win:
			var r := Rect2i(win.get_global_rect().grow(6)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img.get_region(r).save_png("%s/win_%s.png" % [dir, tag])
			print("WINSHOTS %s %s" % [tag, r.size])
	get_tree().quit()

func _find(comp: String, sub: String) -> Entity:
	var fallback: Entity = null
	for e in Game.all_with(StringName(comp)):
		if e.removed or e.holder != null:
			continue
		if sub != "" and comp == "console" and e.c(&"console").kind != sub:
			continue
		if comp == "pipemachine":
			var pm: CPipeMachine = e.c(&"pipemachine")
			if sub != "" and pm.kind != sub:
				continue
			# prefer a named, working one with gas in it
			if pm.display != "" and pm.net_in() and pm.net_in().total_moles() > 1.0:
				return e
			if fallback == null:
				fallback = e
			continue
		return e
	return fallback
