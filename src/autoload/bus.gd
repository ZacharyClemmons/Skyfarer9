extends Node
## Global event bus. Systems publish world happenings here; perception, UI, the
## chronicle and the event director subscribe. Nothing here holds state.

## A thing happened that others could see or hear. `info` keys:
##   type (String), actor (Entity or null), target (Entity or null), cell (Vector2i),
##   loud (float: hearing radius in tiles, 0 = silent), illegal (bool), text (String)
signal stimulus(info: Dictionary)

## Speech: a mob said something out loud (radio handled separately).
signal speech(speaker: Entity, text: String, cell: Vector2i, radius: float)
## Radio transmission on a channel. `fact` is optional structured knowledge the message carries.
signal radio(speaker: Entity, channel: String, text: String, fact: Dictionary)
## Station-wide announcement (command console, AI, event director).
signal announcement(title: String, text: String, severity: int)

## Chat line for the local player's log. kind: "say", "radio", "emote", "info", "warn", "bad", "good", "examine", "announce"
signal chat(text: String, kind: String)

signal entity_spawned(e: Entity)
signal entity_removed(e: Entity)
signal entity_moved(e: Entity, from: Vector2i, to: Vector2i)
signal mob_died(e: Entity)
signal mob_state_changed(e: Entity)

signal tile_changed(cell: Vector2i)
signal opacity_changed(cell: Vector2i)
signal pipes_changed()
signal cables_changed()
signal lights_dirty()
signal power_state_changed(area_id: int)

## Story-worthy happening for the chronicle log.
signal chronicle(text: String, importance: int)

signal player_changed(e: Entity)
## The player took or let go of a ship's wheel (null when they step away).
@warning_ignore("unused_signal")
signal helm_changed(ship)
## the player's genetic powers changed (granted, removed, armed, used)
signal powers_changed()
signal ui_open_window(kind: String, target: Entity)

@warning_ignore("unused_signal")
signal skill_up(ent: Entity, what: String, level: int)
@warning_ignore("unused_signal")
signal xp_gained(ent: Entity, what: String, amount: float)
