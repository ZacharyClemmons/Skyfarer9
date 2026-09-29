class_name ShipSurvey extends RefCounted
## The shipwright's read on a drawn hull, before she flies: where the wind will get in, where
## it will be miserable to stand, and what will burn first. Works on a live layout
## (`cells`: local cell -> glyph) with the same rules ShipHazards applies in the air, so
## what the board warns about is what the sky will do.

const MAX_DEPTH := 7
const FUEL := ["T", "B"]

## local cell -> 0..1: how hard a gale would blow through the tile. Sources are every cabin
## tile that is open to the weather; the draught follows the walkable floor behind them.
static func draught_map(cells: Dictionary) -> Dictionary:
	var out := {}
	var leaks := ShipPlan.leaks_of(cells)
	var sealed := ShipPlan.sealed_of(cells)
	for src in leaks:
		var seen := {src: 0}
		var q: Array = [src]
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			var dist: int = seen[c]
			var s := 1.0 - float(dist) / float(MAX_DEPTH + 1)
			if s > float(out.get(c, 0.0)):
				out[c] = s
			if dist >= MAX_DEPTH:
				continue
			for d in Defs.DIRS4:
				var n: Vector2i = c + d
				if seen.has(n) or not cells.has(n):
					continue
				var g := String(cells[n])
				if g in ShipPlan.WALLS or g in ShipPlan.WINDOWS or g == "I" or g in ShipPlan.OPEN_DECK or g == "A":
					continue
				if not sealed.has(n) and not leaks.has(n):
					continue
				seen[n] = dist + 1
				q.append(n)
	return out

## Weather-deck tiles with nothing solid beside them: a person standing there has no lee.
static func bare_deck(cells: Dictionary) -> Array:
	var out := []
	for k in cells:
		if not String(cells[k]) in ShipPlan.OPEN_DECK:
			continue
		var lee := false
		for d in Defs.DIRS4:
			var g := String(cells.get(k + d, ""))
			if g in ShipPlan.WALLS or g in ShipPlan.WINDOWS or g == "I" or g in ShipPlan.DENSE:
				lee = true
				break
		if not lee:
			out.append(k)
	return out

## Diagnostics in the shape ShipPlan.diagnose returns: {severity, code, text, cells}.
static func diagnose(cells: Dictionary, lower_plan: Dictionary, lower_entry: Vector2i) -> Array:
	var out := []
	if cells.is_empty():
		return out
	var draught := draught_map(cells)
	var strong := []
	for k in draught:
		if float(draught[k]) >= 0.35:
			strong.append(k)
	if not strong.is_empty():
		out.append(_d("info", "draught", "%d tile%s will sit in a draught. Wind through an open cabin chills the crew, gutters lanterns and fans fires. Close the gap or put a bulkhead across it." % [
			strong.size(), "" if strong.size() == 1 else "s"], strong))
	var sealed := ShipPlan.sealed_of(cells)
	# the wheel
	for k in cells:
		if String(cells[k]) == "h" and not sealed.has(k):
			out.append(_d("info", "open_helm", "The wheel is out on open deck. Fine in a breeze; in a gale the helmsman is slowed and can be thrown down. A wheelhouse fixes that.", [k]))
	# the galley
	for k in cells:
		if String(cells[k]) != "f":
			continue
		for d in Defs.DIRS8:
			if String(cells.get(k + d, "")) in FUEL:
				out.append(_d("warn", "stove_fuel", "A stove beside the %s. One stray flame and the whole compartment goes." % (
					"bunker" if String(cells[k + d]) == "T" else "boiler"), [k, k + d]))
				break
		if draught.has(k):
			out.append(_d("warn", "stove_draught", "A draught reaches the stove. It will throw flame onto whatever is beside it.", [k]))
	var bare := bare_deck(cells)
	var deck_n := 0
	for k in cells:
		if String(cells[k]) in ShipPlan.OPEN_DECK:
			deck_n += 1
	if deck_n >= 6 and bare.size() * 10 >= deck_n * 8:
		out.append(_d("info", "no_lee", "Almost all of her deck is bare: no bulwark, no wall to get behind. Crew caught out in a blow have nothing to hold.", []))
	# the lower deck
	if lower_plan.is_empty():
		out.append(_d("info", "no_hold", "No lower deck drawn. There will be no galley to warm up in, and nowhere to stow a pump.", []))
	else:
		var floor_n := 0
		for k in lower_plan:
			if String(lower_plan[k]) == "=":
				floor_n += 1
		if floor_n < 8:
			out.append(_d("warn", "cramped_hold", "The lower deck is cramped. A stove, a pump and a bunk will not all fit.", []))
		if lower_plan.has(lower_entry) and cells.has(lower_entry) and not sealed.has(lower_entry) \
				and not String(cells[lower_entry]) in ["+", "A"]:
			out.append(_d("info", "open_hatch", "The hatch below comes up on open deck. Smoke from the galley will pour out of it, and wind will find its way down.", [lower_entry]))
	return out

static func _d(sev: String, code: String, text: String, cells: Array) -> Dictionary:
	return {"severity": sev, "code": code, "text": text, "cells": cells}
