class_name MapShots extends Node
## --mapshots=DIR: flies the camera over the station's departments and saves a
## screenshot of each (fullbright, HUD hidden). For reviewing the map and its art.

var dir := ""
var lit := false

const STOPS := [
	["security", 18, 20], ["command", 62, 10], ["quarters", 104, 14], ["science", 26, 45],
	["service", 62, 45], ["medbay", 97, 45], ["cargo", 20, 72], ["engineering", 62, 78],
	["atmos", 102, 70], ["departures", 110, 28], ["maint", 64, 62],
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.root.visible = false
	if not lit:
		Game.lighting.full_bright = true
	var view = Game.view
	view.zoom_level = float(Game.world.get_parent().args.get("zoom", "1.0"))
	for s in STOPS:
		var c := Vector2i(MapGen.SX + s[1], MapGen.SY + s[2])
		Game.player.place(c)
		view.camera.position = Entity.cell_to_pos(c)
		view.camera.reset_smoothing()
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_png("%s/map_%s.png" % [dir, s[0]])
	# the gas chambers outside atmos
	var ch_cells := []
	for ar in Game.map.areas:
		if ar.room_kind == "gas_chamber" and not ar.cells.is_empty():
			ch_cells.append(ar.center)
	if not ch_cells.is_empty():
		var mid := Vector2.ZERO
		for cc in ch_cells:
			mid += Vector2(cc)
		var cm := Vector2i(mid / ch_cells.size())
		# stand in the control room, looking in through the windows
		var stand := cm
		for k in 12:
			var up := cm + Vector2i(0, -k)
			if Game.map.area_at(up).room_kind == "atmospherics" and Game.map.is_passable(up):
				stand = up
				break
		Game.player.place(stand)
		view.camera.position = Entity.cell_to_pos(cm)
		view.camera.reset_smoothing()
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img3 := get_viewport().get_texture().get_image()
		if img3:
			img3.save_png("%s/map_chambers.png" % dir)
		Game.player.place(cm)
		view.camera.position = Entity.cell_to_pos(cm)
		view.camera.reset_smoothing()
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img4 := get_viewport().get_texture().get_image()
		if img4:
			img4.save_png("%s/map_chamber_inside.png" % dir)
	# Atmospherics' pipework with the gas moving, then with every device labelled
	AtmosOverlay.force_show = true # as if holding a gas analyzer
	var ac := Vector2i(MapGen.SX + 108, MapGen.SY + 76)
	Game.player.place(ac)
	view.camera.position = Entity.cell_to_pos(ac)
	view.camera.reset_smoothing()
	await get_tree().create_timer(3.0).timeout
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imf := get_viewport().get_texture().get_image()
	if imf:
		imf.save_png("%s/map_atmos_flow.png" % dir)
	AtmosOverlay.force_labels = true
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var iml := get_viewport().get_texture().get_image()
	if iml:
		iml.save_png("%s/map_atmos_labels.png" % dir)
	AtmosOverlay.force_labels = false
	# hover a pipe in Atmospherics: its network should light up and the examine bar read it
	var at := Vector2i(MapGen.SX + 102, MapGen.SY + 70)
	Game.player.place(at)
	view.camera.position = Entity.cell_to_pos(at)
	view.camera.reset_smoothing()
	for i in 6:
		await get_tree().process_frame
	var target := Vector2i(-1, -1)
	var tlay := 0
	for r in range(1, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var pc := at + Vector2i(dx, dy)
				if target.x >= 0 or not Game.at(pc).filter(func(e2): return not e2.has_c(&"decal")).is_empty():
					continue
				for ly in StationMap.PIPE_LAYER_COUNT:
					if Game.map.pipe_mask(ly, pc) in [5, 10] and Game.map.pipe_shown.has(Game.map.pipe_key(ly, pc)):
						target = pc
						tlay = ly
	print("PIPEHOVER target %s" % target)
	if target.x >= 0:
		Game.hud.root.visible = true
		var po: float = PipeHover.LAYER_PX[tlay]
		var sp: Vector2 = get_viewport().get_canvas_transform() * (Vector2(target) * Defs.TILE + Vector2(16 + po, 16 + po))
		Game.hud.mouse = sp
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img5 := get_viewport().get_texture().get_image()
		if img5:
			img5.save_png("%s/map_pipe_hover.png" % dir)
		print("PIPEHOVER %s net=%s name=%s hint=%s" % [target, PipeHover.hovered != null, Game.hud.examine_label.text, Game.hud.examine_hint.text])
		Game.hud.root.visible = false
	AtmosOverlay.force_show = false
	# the whole station, with the utilities under the floor showing
	TerrainChunk.xray = true
	for ch in view.find_children("*", "TerrainChunk", true, false):
		ch.queue_redraw()
	view.zoom_level = 0.5
	for s2 in [["xray_west", 34, 46], ["xray_east", 94, 46]]:
		var c2 := Vector2i(MapGen.SX + s2[1], MapGen.SY + s2[2])
		Game.player.place(c2)
		view.camera.position = Entity.cell_to_pos(c2)
		view.camera.reset_smoothing()
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := get_viewport().get_texture().get_image()
		if img2:
			img2.save_png("%s/map_%s.png" % [dir, s2[0]])
	get_tree().quit()
