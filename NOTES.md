# Skyfarer9 — build notes

A Skies-of-Arcadia / Treasure-Planet game on the Artic9 engine: floating islands in an
open sky, SS13-depth buildable airships, a day/night cycle, real weather, an MMO-shaped
skill tree, and a 2D ⇄ first-person 3D hybrid renderer.

The whole Artic9 engine (`src/`, `assets/`, `tools/`, 67k lines of GDScript) was copied in
verbatim, so every existing system — atmospherics, power, pipes, lighting, bodies,
genetics, AI, crafting, the procedural art pipeline — is available unchanged.

## Running it

```
Godot_v4.7-stable_win64_console.exe --path . --import       # after any art or script change
Godot_v4.7-stable_win64_console.exe --path .                # play
```

Useful flags (after `--`):

| flag | effect |
|---|---|
| `--seed=N` | fixed region |
| `--band=0..4` | altitude band (the Deep, the Shelf, the Reaches, the Heights, the Anvil) |
| `--ship` / `--hull=ID` | skip the yard and start aboard a hull (the old opening) |
| `--gencheck` | generate, print a report including hull prices and port contents, quit |
| `--flytest` | light the boiler, take the wheel, open the throttle, report |
| `--flighttest` | deterministic flight, turning, passenger and render regressions |
| `--systemtest` | control, pause, tutorial, wildlife and message-log regressions |
| `--autotest=SEC --shots=DIR` | play for SEC seconds, save screenshots |
| `--yardshot [--hullpick=ID] [--purse=N]` | open the shipwright's drawing board |
| `--airtest` | report every port's air, lighting and whether you can walk to each counter |
| `--shopshot[=trade]` | open a trader's counter with money in your pocket |
| `--craftshot` / `--noticeshot` / `--skillshot` | open the bench, the board, the skills screen |
| `--fps --look=DEG` | start in first person, facing DEG |
| `--onisland` / `--at=x,y` | put the player somewhere specific |
| `--day=0..1` | set the time of day (0.5 noon, 0.77 dusk) |
| `--flatsky` | the old tiled sky instead of the sky shader |
| `--nolight --hidehud --bare --fullbright` | rendering diagnostics |

### Controls

| key | on foot | with the wheel in your hands |
|---|---|---|
| W A S D | walk | W/S throttle, A/D rudder |
| Q / E | drop / equip | trim ballast lighter / heavier |
| R | combat toggle | set or furl sail |
| Space | — | all stop |
| G | ship systems panel | |
| J | the bench — everything you can make, and what is stopping you | |
| I | the drawing board, on the ship you are standing on (refit) | |
| P | skills | |
| F5 | first-person view | F7 hide the tutorial prompts |
| Shift + direction | step off a ledge on purpose — nothing else will | |

**The opening.** Pick a **trade** in the creator — what you were before you had a ship
(`SkyClasses`, eleven of them). It decides your starting skills, the tools in your hands
and what is left in your purse: a Prospector starts skilled and broke, a Factor starts
rich and useless. Then a cold-open card, and you are on the quay at **Port Meridian**
with about 3,300 marks and no ship. A second-hand skiff at the yard costs 3,203. Buy it
and be flying in ninety seconds, or spend the same money drawing your own hull on the
yard master's board. Both are correct and the game has no opinion.

**Nothing in a port can go wrong.** You cannot attack the people who run one — the swing
does not happen, they step back and tell you off. Clicking a trader opens their counter,
because that is obviously what the click meant. Meridian is the one place in this game
that is safe, and an accidental click must never be the thing that takes that away.

**Flying her, from cold:** walk to the boiler → right-click → *Light the burner* → wait
about ten seconds for pressure → click the wheel → hold **W**. Trim with **E** or she will
climb away from you.

**Getting ashore:** bring her alongside an island, stop, let go of the wheel, and walk
into the rail. A bulwark is chest height, so you climb it.

## Design decisions

**Islands are turfs, sky is a turf.** `Defs.T_SKY` / `T_CLOUD` are open air: walkable by
nothing, so the tile grid, atmos, pathfinding and lighting need no special cases. Falling
off is the game's universal hazard, and you only do it on purpose — a plain step into
nothing is refused with a warning.

**Ships are real tiles, not sprites.** An airship stamps its deck plan into `StationMap`
and flies by restamping one tile at a time, carrying everything aboard. So the air in a
cabin is simulated by the same LINDA port as a station room, a hull breach at altitude
decompresses for real, and a thruster walled into an unventilated engine room genuinely
cooks its crew.

**A hull is a shape; a fit-out is a set of decisions.** `cells_map` says what shape she is
— planking, bulwark, a hole for an engine. `fittings` says *which* engine is in the hole
(`ShipParts`, 57 modules over five grades). Splitting the two is what makes upgrading a
real activity: the deck plan never changes when you buy a better thruster, the hole stays
the same size and something better goes in it. Every number the shop quotes — thrust,
lift, canvas, rudder, tankage, plating — is the number the flight model actually reads.

**A hull out of the book has a grade.** A skiff is delivered at grade 0 (brass burner,
patched bladders, pot boiler) and a frigate at grade 2. That is why a starter ship is
affordable and worth upgrading, and it is derived from the catalogue rather than tabulated,
so a new module automatically becomes what a high-grade hull is delivered with.

**Sealing is geometry plus intent.** `.` and `,` in a deck plan declare weather deck;
every other floor tile takes its answer from a flood fill that starts outside the hull
*and* from every weather tile. So the same wheel is a wheelhouse on a cutter and a wheel
bolted to the planking on a skiff, and a hull the player builds seals the moment they
close the last gap. `ShipPlan.leaks()` reports holes; the yard's **L** key shows them.

**Lift scales with the hull.** Cells are rated at `hull_mass * 1.34 / lift_units` rather
than a fixed size, so every hull — including one the player designs — floats at the same
designed ratio with no table to tune. A better cell then carries more than its share of it.

**The region is rings, not a plane.** `SkyGen` lays 45–56 islands into five concentric
rings around the home port: the Home Reach, the Nearing, the Long Sky, the Outer Dark and
the Rim. A ring decides which biomes may appear (`Biomes.TIER_OF`), how hard the wildlife
hits (`RING_POWER`, 1.0 → 3.8), how good the loot is (`RING_LOOT`) and how many ports
there are. Altitude band is the *other* axis and decides the flavour of a sky. Keeping
them separate is what stops the world being one straight line.

**Wildlife is streamed, not spawned.** The region carries 600–750 creature records.
`FaunaStream` brings an island's population in at 52 tiles and puts it back at 92, never
inside the player's view, and *remembers* anything that was hurt, angered or has robbed
you. Come back to an island you fought on and the survivors are the survivors.

**Weather is a thing in the world.** `Weather` moves discrete fronts with positions and
edges. A thunderhead charges every aether cell aboard (free ammunition, free lift) and
puts bolts into your masthead; fog blinds the sounder and makes hunting things find you;
a squall is free altitude and a downdraft is how ships are lost; an aurora doubles what
you learn. You can see them coming and fly round them.

**A port is built, not found.** Meridian is laid out in this order and the order is the
point: pick the largest connected *walkable* region of the island, put the quay on the
edge of it, level a town-sized patch behind it, reserve the harbour apron, place the
premises, then cut streets to every door. Anybody who could not get a building takes a
counter in somebody else's; anybody still without one sets up on a barrow on the front.
The result is 7 trades out of 7 and 100% of the counters reachable on foot, on every seed
tested — which earlier heuristics ("score the coast by how much land is behind it") got
right about four times in five.

**Other people's ships fly the same model you do.** `ShipAI` has throttle, rudder,
ballast, sails and guns and nothing else — no shortcut that moves an NPC hull directly,
because the moment one exists the AI stops being beatable by understanding the flight
model. A pirate with a cold boiler cannot chase you. A barque is slow to come about for
exactly the reason yours is. Shooting a ship's lift cells brings it down rather than
reducing a hit-point pool, and a good crew knows to aim for them.

**The sky sorts itself out.** `SkyTraffic` keeps a handful of hulls near the player,
weighted by ring: traders and revenue cutters near home, pirates thickening outward.
Patrols hunt pirates whether or not you are watching. `Reputation` holds two numbers that
are not opposites — how the ports feel about you, and how much the revenue service would
like a word — so a famous pirate and a well-liked smuggler are both playable.

**Creatures have one trick each.** Seven behaviours decide how a thing moves;
`BeastPowers` decides why you remember it. Every power telegraphs a turn before it lands
and every one has a counter that was a decision you could have made a minute earlier —
stand somewhere else, carry something that is not iron, put a wall between you, or kill it
faster. Beastlore is the skill that tells you which tricks a thing has before it uses them.

**Skills are a web, not a ladder.** 33 skills in five groups. The chains converge on the
ship: ore → ingots → plate and parts; timber → planks → hull, ironwood → keels; fibre →
rope and canvas → rigging; hide and chitin → harnesses and armour; sporecap and marrow →
tonics. Almost every module in `ShipParts` can be *made* as well as bought, at a level
that takes real work — the Vashti turbine you cannot afford at hour three is a thing you
can build at hour twenty.

**Nothing in the bench list is hidden.** A greyed-out recipe that says "needs Smithing 40,
you have 12" teaches more than a hidden one: it is a goal, a number and a route in one line.

**Daylight beats line of sight outdoors.** Station-style FOV made an open desert look like
a cave, so outdoor tiles stay lit while the sun is up; night darkness comes from the
ambient ramp. Ship hulls are solid but *not* opaque — a bulwark is waist-high.

**The sky is a shader, not a tile.** `SkyBackdrop` draws the whole sky behind the world on
one full-screen quad: a day/night gradient, the cloud floor whose height on screen is the
altitude cue, three parallax cloud decks drifting against the camera (which is the only
thing telling a player that a hull pinned to the middle of the screen is moving), a sun
that tracks the clock, stars, aurora, and the weather wash. Posterised at the end so it
sits with the pixel art rather than behind glass.

## What's built and verified

| Area | Files | Verified by |
|---|---|---|
| Sky turfs, altitude air model, 21 biomes over 5 rings | `autoload/defs.gd`, `sky/biomes.gd` | gencheck |
| Region generator: 512×448, 45–56 islands, rings, ports, moorings | `sky/skygen.gd` | gencheck, ~2.4 s |
| Port Meridian and the outports: quays, shops, traders, the yard | `sky/hub.gd` | gencheck, screenshots |
| Marks, port moods, haggling, trade routes | `sky/economy.gd`, `comp/c_vendor.gd` | shopshot |
| 57 ship modules over 12 categories and 5 tiers | `ship/ship_parts.gd` | gencheck, shopshot |
| Modular fit-out: thrust, lift, sail, rudder, range, hold, plating, quirks | `ship/airship.gd` | flytest, flighttest |
| Drag-and-drop drawing board: draw, fit, mirror, wrap, leaks, undo, live stats | `ui/shipyard.gd` | yardshot |
| Ship guns that fire: ball, lance, scatter, harpoon, arcs | `ship/c_ship_gun.gd` | — |
| Weather fronts and everything they do | `sky/weather.gd` | in-game |
| Streamed wildlife with memory | `sky/fauna_stream.gd` | autotest |
| 78 creatures, 23 powers, ring-scaled | `sky/sky_mobs.gd`, `sky/beast_powers.gd` | gencheck |
| 33 skills, gating, yields, mastery curves | `sim/skills.gd` | skillshot |
| 92 recipes incl. one per module, station-gated | `sky/sky_crafting.gd` | craftshot |
| Gathering: timber, fibre, ore, hide, salvage, skyfishing | `sky/gathering.gd`, `comp/c_sky_rod.gd` | — |
| Materials, tools, weapons, curios, tonics | `data/sky_items.gd` | shopshot |
| Timed effects (tonics, curios, weather, webbing) | `sky/sky_buffs.gd` | in-game |
| Sky shader: gradient, parallax decks, sun, stars, weather | `render/sky_backdrop.gd`, `render/sky.gdshader` | screenshots |
| Art: 1,477 item and 1,202 object sprites | `tools/artgen/sky_items2.py`, `sky_objects2.py` | contact sheets |
| First-person hybrid renderer + toggle | `render3d/` | screenshots |
| Eleven trades to start from, with real trade-offs | `data/sky_classes.gd` | creator |
| NPC ship captains: patrol, haul, hunt, fight, flee | `ship/ship_ai.gd` | autotest |
| Streamed ship traffic by ring | `sky/sky_traffic.gd` | autotest |
| Standing and warrants | `sky/reputation.gd` | in-game |
| Port layout: walkable siting, groundworks, streets, lodgers, barrows | `sky/hub.gd` | `--airtest` |
| Shop interiors, per trade, always lit | `sky/hub.gd`, `systems/lighting_system.gd` | `--airtest` |
| Ship panel: gauges, safe bands, advice line, collapsible | `ui/ship_panel.gd` | `--uishot` |
| Drawing board: auto-fit, hover inspector, grouped palette | `ui/shipyard.gd` | `--yardshot` |
| The cold open | `ui/intro.gd` | in-game |

`--flighttest`: 144 checks, 0 failed.

## Known gaps

- **Region transit is still a stub.** Climbing or sinking out of a band warns and holds
  the ship at the boundary (`sky_main._transit`). Rebuilding the region under a flying
  ship needs the crew, hull and cargo carried across intact.
- **Outports are three shops and a quay.** They work and they are reachable, but
  Meridian is the only port with a shape worth walking around.
- **No contracts yet.** Cargo runs between ports, bounties on named pirates and salvage
  jobs all have the systems under them (ports want things, pirates carry bounties,
  wrecks exist) and nothing that hands them out.
- **3D polish**: distant ground compresses to a thin band at the horizon (correct, but
  reads oddly); rock outcrops show a visible cap seam. The 3D view does not yet draw the
  sky shader, so it still has the old flat horizon.
- `--flytest` leaves diagnostics in `sky_main`; harmless, but it is test scaffolding.
