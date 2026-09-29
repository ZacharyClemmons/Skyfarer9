class_name CVent extends Component
## Pipe-to-room devices (tg: vent_pump / vent_scrubber / outlet injector).
##   "vent"      supply layer -> room, fills rooms up to the target pressure
##   "scrubber"  room -> waste layer, removes CO2 / plasma / smoke / N2O / vapour
##   "outlet"    waste layer -> outdoors (station exhaust)
##   "port"      connector for canisters (supply layer)

var mode := "vent"
var layer := StationMap.PL_SUPPLY
var target_pressure := Defs.ONE_ATMOS
var rate := 6.0 # moles per tick at most
var welded := false
var clogged := 0.0
var panic := false
# tg vent_pump / vent_scrubber settings, driven by the room's air alarm
var on := true
var siphon := false # vent: pump room air back into the pipe. scrubber: take everything, not just the filtered gases
var widenet := false # scrubber: also work the tiles around it
var filters := {Defs.G_CO2: true, Defs.G_SMOKE: true} # tg vent_scrubber filter_types: CO2 (smoke is ours)
var number := 0 # "Vent #3" in the air alarm's list
# tg chamber devices
var volume_rate := 50.0 # injector, L/s (tg outlet_injector; the monitored ones run at 200)
var internal_bound := 4000.0 # siphon: stop once the pipe reaches this, kPa
var volume_l := 200.0 # siphon: the vent's own air volume (tg high_volume: 1000 L)
var monitored := "" # the tank this device feeds or drains ("n2", "o2"...), for its console
var moved_last := 0.0 # moles last tick: + pipe to room, - room to pipe (for the overlay)
var face := Vector2i.ZERO # tg unary node side: which of the tile's pipes it's on (zero: the tile's pipe)

func key() -> StringName:
	return &"vent"

func setup(p: Dictionary) -> CVent:
	mode = p.get("mode", mode)
	layer = {"vent": StationMap.PL_SUPPLY, "scrubber": StationMap.PL_SCRUB, "outlet": StationMap.PL_SCRUB, "port": StationMap.PL_HOT,
		"injector": StationMap.PL_GEN, "siphon": StationMap.PL_GEN, "passive": StationMap.PL_GEN}[mode]
	layer = p.get("layer", layer)
	on = p.get("on", on)
	volume_rate = p.get("volume_rate", volume_rate)
	internal_bound = p.get("internal_bound", internal_bound)
	volume_l = p.get("volume_l", volume_l)
	monitored = p.get("monitored", monitored)
	return self

func on_added() -> void:
	if Game.pipes:
		Game.pipes.register_device(e, layer)

func on_removed() -> void:
	if Game.pipes:
		Game.pipes.unregister_device(e)

func working() -> bool:
	if welded or not on:
		return false
	if mode in ["outlet", "passive"]:
		return true # unpowered: open pipe ends
	var m: CMachine = e.c(&"machine")
	return m == null or m.operable()

func attackby(user: Entity, item: Entity) -> bool:
	var it: CItem = item.c(&"item")
	if mode == "port" and it and it.tool == "wrench":
		# wrench the nearest free canister onto this port (tg connector)
		for can in Game.in_radius(e.cell, 1, &"canister"):
			var cc: CCanister = can.c(&"canister")
			if can.holder == null and cc.port == null:
				cc.port = e
				Game.visible_message(e.cell, "%s wrenches %s onto %s. The pipes hiss as it feeds in." % [user.display_name, can.the(), e.the()], "good")
				Sfx.play("ratchet", e.cell)
				Bus.stimulus.emit({"type": "repaired", "actor": user, "target": e, "cell": e.cell, "loud": 1.0, "what": "coolant"})
				return true
		Game.tell(user, "There's no gas canister next to the port.", "warn")
		return true
	if it and it.tool == "welder" and item.c(&"welder") and item.c(&"welder").lit:
		DoAfter.start(user, e, 3.0, func(ok):
			if ok:
				welded = not welded
				e.set_sprite("objects", "vent_welded" if welded else ("vent" if mode == "vent" else "scrubber"))
				Game.visible_message(e.cell, "%s %s %s." % [user.display_name, "welds" if welded else "unwelds", e.the()])
				if welded:
					Bus.stimulus.emit({"type": "tamper", "actor": user, "target": e, "cell": e.cell, "loud": 3.0})
		)
		return true
	return false

func examine(_user: Entity, lines: Array) -> void:
	if mode in ["vent", "scrubber"]:
		lines.append("It is %s%s." % ["off" if not on else ("siphoning" if siphon else ("releasing air at %.0f kPa" % target_pressure if mode == "vent" else "scrubbing")), " (wide net)" if widenet and on else ""])
	if welded:
		lines.append("It has been welded shut.")
	if clogged > 0:
		lines.append("[color=#ffb84a]Something is gurgling inside it.[/color]")
