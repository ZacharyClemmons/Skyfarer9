# Vital systems polish pass

This pass fixes interaction and combat failures found during the TG parity work.
It does not certify full game or genetics parity.

- Inventory chooses a usable arm, including when the active arm is missing or
  disabled. Two unusable arms cannot receive items.
- Timed actions cancel when two wall corners block adjacency to the target.
- Ballistic and energy shots check solid cover before people sharing its tile.
  Opening a crate removes its protection. Ballistic tracing stops at map bounds.
- Buckshot applies its pellet spread, and energy guns apply the poor-aim quirk.
- Traumatic nonviolence and impaired dexterity apply to ballistic weapons too.
  An energy gun permits nonlethal firing and refuses lethal firing under nonviolence.
- Olfaction offers working buttons for multiple scents, initializes choices before
  opening the window, and resolves selection during the existing sniff cooldown.
  Antimagic no longer blocks physical genetic abilities; mental powers retain it.
- Regression fixtures explicitly equip flash protection and isolate glass-jaw
  sampling from the shared random stream. UI tests create screenshot directories
  and report failed image writes.

Validation: inventory/timed-action/projectile polish, combat, station machinery,
atmospherics, status effects, genetics, and rendered HUD interaction suites pass.
The rendered suite saves ten screenshots and exercises inventory drag/drop,
equipment, hotbars, information windows, themes, and layout controls.

## UI and basic actions (2026-09-28)

- Keyboard use/equip and HUD actions share the hand-use restrictions; cuffed
  players cannot activate or equip held items through shortcuts.
- Storage windows accept held items when clicking an empty cell. Taking an item
  uses the same validated transfer as drag/drop, preserving its container if the
  transfer fails.
- Drop previews reject disabled hands instead of moving the item into another
  hand. Dragging cannot bypass a held item's no-drop restriction.
- The front window takes priority over inventory slots and other windows behind
  it when resolving drops.
- Escape cancels typing and pending drags, then closes one front window per press.
  Reopening a window ignores copies already queued for deletion.
- Hand tooltips name the hand, explain selection versus use, and identify hands
  that cannot hold items. Inventory context use/drop checks hand availability
  and current ownership before acting.

Validation: the rendered UI suite includes shortcut restrictions, empty-cell
storage, disabled-hand drops, no-drop items, window occlusion, and Escape behavior,
alongside the existing inventory, hotbar, theme, and layout checks. Screenshots
are saved under `.godot/ui-actions-verified-shots`.

## Pickup controls and enclosure follow-up

- Hand transfers and drops refresh the owner's inventory after the transfer,
  avoiding an intermediate empty-hand state. Unchanged inline bag/floor controls
  survive hand refreshes, while storage capacity captions still update.
- Completing or cancelling a drag clears the source slot's pressed state. A
  cancelled drag cannot activate the held item on a later mouse release; destroyed
  pickup targets cancel safely. Held-sprite fallbacks use the new item's region.
- Wielded two-handed items reserve the other hand. Missing arms cannot supply the
  second grip. Hand previews check item restrictions, and failed handoffs retain
  the giver's item.
- Closing a genetics scanner clears both incoming and outgoing pulls, stops
  movement, and conceals its occupant from world picking. Enclosed bodies cannot
  be pulled or moved through the pull-movement path.
- Lockers enclose up to three eligible people when closed. Unlocked occupants
  can walk or resist out; locked/welded escape uses TG's 120-second base action.
  Cuffed occupants can resist. Moving/destructing lockers carries/releases them
  correctly. Crates accept lying people and refuse lids obstructed by standing
  people. Dragging a pulled person into an open locker uses a four-second action
  followed by four seconds of paralysis and closes the locker.

Source comparison uses the pinned TG closet and crate implementations linked in
`SYSTEMS_PARITY.md`. This covers enclosure and escape rules, not every storage
feature; crate climbing/elevation and full secure-locker mechanics remain open.
