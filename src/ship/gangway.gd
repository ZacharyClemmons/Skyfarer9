class_name Gangway extends RefCounted
## The boarding ramp. A hull piece that looks like a sealed plate in the ship's side until
## somebody uses it; then it swings open and a ramp runs out across the gap to whatever is
## there — quay, island, another ship's deck. While it is out she is made fast: she will not
## move until it is hauled in, and it will not come in while somebody is standing on it.
##
## The planking is real: each span tile is an entity with the `platform` tag that
## `Falling.supported` already honours, so anyone can walk it and nothing falls.

const REACH := 4      # tiles of open air it can span

## Run the ramp out from the ramp piece `ramp`. Returns "" on success, else the reason.
static func deploy(ramp: Entity, sh: Airship) -> String:
	if sh == null or ramp == null or Game.map == null:
		return "The ramp is not part of a ship."
	if not sh.gangway.is_empty():
		return "A ramp is already out."
	if sh.speed() > 0.4:
		return "She is moving too fast. Bring her to a stop first."
	var map := Game.map
	var h: Vector2i = ramp.cell
	var best := {}
	var best_score := 999
	for d in Defs.DIRS4:
		if sh.cells.has(h + d):
			continue
		var span := []
		var landing := Vector2i(-1, -1)
		for i in range(1, REACH + 1):
			var c: Vector2i = h + d * i
			if not map.inb(c) or sh.cells.has(c):
				break
			if Defs.is_void_turf(map.get_turf(c)):
				span.append(c)
				continue
			if map.is_passable(c) and Falling.supported(c):
				landing = c
			break
		if landing.x < 0:
			continue
		if span.size() < best_score:
			best_score = span.size()
			best = {"dir": d, "span": span, "landing": landing}
	if best.is_empty():
		return "There is nothing within reach. Bring her alongside a quay or an island, close to this side."
	var rec := {"rail": h, "dir": best["dir"], "planks": [], "cells": [h], "landing": best["landing"], "ramp": ramp}
	for c in best["span"]:
		var plank := Proto.spawn("gangway_plank", c)
		if plank != null:
			plank.tags["platform"] = true
			plank.visible = false
			rec["planks"].append(plank)
		rec["cells"].append(c)
	var fx := RampFx.new()
	fx.setup(rec)
	Game.view.add_child(fx)
	rec["fx"] = fx
	sh.gangway = rec
	Sfx.play("ratchet", h, 0.8)
	return ""

## Returns "" on success, or why it will not come in.
static func retract(sh: Airship, force := false) -> String:
	if sh == null or sh.gangway.is_empty():
		return "The ramp is not out."
	var rec: Dictionary = sh.gangway
	if not force:
		var spots: Array = [rec["rail"]]
		for pc in rec["planks"]:
			if is_instance_valid(pc) and not pc.removed:
				spots.append(pc.cell)
		for c in spots:
			for e in Game.at(c):
				if e.has_c(&"mob"):
					return "Somebody is standing on the ramp."
	for pc in rec["planks"]:
		if is_instance_valid(pc) and not pc.removed:
			pc.tags["platform"] = false
			pc.destroy()
	var fx = rec.get("fx")
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	Sfx.play("ratchet", rec["rail"], 0.6)
	sh.gangway = {}
	return ""

## The ramp, drawn: boards along the span with a rope rail down each side.
class RampFx extends Node2D:
	var rec := {}
	var _cells: Array = []
	var _dir := Vector2i.RIGHT

	func setup(r: Dictionary) -> void:
		rec = r
		_cells = r["cells"].duplicate()
		_dir = r["dir"]
		z_index = 2

	func _draw() -> void:
		var t := float(Defs.TILE)
		var along := Vector2(_dir)
		var side := Vector2(-along.y, along.x)
		for c in _cells:
			var p := Entity.cell_to_pos(c)
			if c != rec["rail"]:
				draw_rect(Rect2(p - Vector2(t, t) * 0.5 + Vector2(1, 1), Vector2(t - 2.0, t - 2.0)), Color("#8a6a3e"))
				for i in 4:
					var o := (float(i) + 0.5) * t * 0.25 - t * 0.5
					draw_line(p + along * o - side * (t * 0.5 - 2.0), p + along * o + side * (t * 0.5 - 2.0), Color("#5b4426"), 1.0)
			for s in [-1.0, 1.0]:
				var e0: Vector2 = p + side * s * (t * 0.5 - 1.0)
				draw_line(e0 - along * (t * 0.5), e0 + along * (t * 0.5), Color("#d8c08a"), 2.0)
