"""Artic-9's station map, laid out by hand in the spirit of /tg/station's Box and Meta
stations: departments around a ring of primary hallways, a service hub in the middle
(bar, cafeteria, kitchen, hydroponics), purpose-built rooms and furniture placed where
it belongs.

This file is the map's source. Running it writes assets/data/station.json, which
MapGen loads (tiles, areas, doors, windows, airlocks and every placed object). Pipes,
cables, lights, APCs, vents and air alarms are still routed automatically in-game.

    py tools/mapgen/station.py            # write the map
    py tools/mapgen/station.py --preview  # also write tools/mapgen/station_preview.png

Coordinates are station-local: x 0..99 east, y 0..71 south. The outer ring is hull.
Paint floors with room()/hall(); everything inside the hull that isn't floor becomes
wall. Then punch doors and windows into those walls.
"""
import json
import os
import sys

W, H = 128, 92
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "data", "station.json")

tile = [[" "] * W for _ in range(H)]  # " " unset, "." floor, "#" wall, "%" hull, "=" window, "+" door, "@" external door
area = [[""] * W for _ in range(H)]
areas = {}  # code -> {name, kind, floor?}
objects = []
exits = []
OX, OY = 0, 0  # where the department being drawn sits (see origin())
_codes = iter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$&()*,-/:;<>?[]^_`{|}~")


def origin(x, y):
    """Draw the following department with its (0,0) at (x, y) on the station grid."""
    global OX, OY
    OX, OY = x, y


def new_area(name, kind, floor=None, hall=False):
    code = next(_codes)
    areas[code] = {"name": name, "kind": kind}
    if floor:
        areas[code]["floor"] = floor
    if hall:
        areas[code]["hall"] = True
    return code


def paint(code, x0, y0, x1, y1):
    for y in range(y0 + OY, y1 + OY + 1):
        for x in range(x0 + OX, x1 + OX + 1):
            tile[y][x] = "."
            area[y][x] = code


def floor_cell(x, y, code):
    tile[y + OY][x + OX] = "."
    area[y + OY][x + OX] = code


def room(name, kind, x0, y0, x1, y1, floor=None):
    code = new_area(name, kind, floor)
    paint(code, x0, y0, x1, y1)
    return code


def door(x, y, code=None):
    """A door in a wall. It belongs to `code`'s area (the room it leads into); by
    default the more private of the two rooms it joins."""
    x += OX
    y += OY
    tile[y][x] = "+"
    if code is None:
        sides = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if area[y + dy][x + dx]]
        rooms = [area[sy][sx] for sx, sy in sides if not areas[area[sy][sx]].get("hall")]
        code = rooms[0] if rooms else area[sides[0][1]][sides[0][0]]
    area[y][x] = code


def window(x, y, code=None):
    x += OX
    y += OY
    tile[y][x] = "="
    if code:
        area[y][x] = code


def windows(x0, y0, x1, y1, every=1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + y) % every == 0:
                window(x, y)


def obj(x, y, proto, **ov):
    o = {"x": x + OX, "y": y + OY, "p": proto}
    o.update(ov)
    objects.append(o)
    return o


def row(proto, x0, x1, y, **ov):
    for x in range(x0, x1 + 1):
        obj(x, y, proto, **ov)


def col(proto, x, y0, y1, **ov):
    for y in range(y0, y1 + 1):
        obj(x, y, proto, **ov)


def table(x, y, style="steel", *items):
    obj(x, y, "table", spr="table_" + style)
    for it in items:
        obj(x, y, it)


def chair(x, y, facing, style="steel"):
    obj(x, y, "chair", spr="chair_%s_%s" % (style, facing))


def edge(x0, y0, x1, y1, dept):
    """Department trim painted round the inside edge of a room (tg's colored edge decals)."""
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            obj(x, y, "decal", spr="edge_" + dept)
    for y in range(y0 + 1, y1):
        for x in (x0, x1):
            obj(x, y, "decal", spr="edge_" + dept)


def stripes(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            obj(x, y, "decal", spr="hazard_stripe")


def exit_airlock(name, hx, hy, dx, dy):
    """External airlock: outer door in the hull at (hx, hy) facing (dx, dy), a one-tile
    chamber, and an inner door."""
    code = new_area(name, "airlock", floor="dark")
    hx += OX
    hy += OY
    tile[hy][hx] = "@"
    area[hy][hx] = code
    cx, cy = hx - dx, hy - dy
    tile[cy][cx] = "."
    area[cy][cx] = code
    ix, iy = cx - dx, cy - dy
    tile[iy][ix] = "+"
    area[iy][ix] = code
    # walls either side of the chamber and inner door
    sx, sy = dy, dx
    for (px, py) in ((cx, cy), (ix, iy)):
        for s in (1, -1):
            qx, qy = px + sx * s, py + sy * s
            if tile[qy][qx] in (" ", "#"):
                tile[qy][qx] = "%"
    exits.append({"name": name, "x": hx + dx, "y": hy + dy, "dx": dx, "dy": dy})


# ====================================================================== hallways
# The service hub sits in a ring of primary hallways (North, South, West and East,
# meeting at the Central Hall crossings). Every department is its own wing off that
# ring, joined by a corridor: Command up its spur, Security and Science to the west,
# the quarters and the long Departures arm to the north-east, Medbay east, Cargo and
# Engineering south, Atmospherics down its own hall to the south-east.
north = new_area("North Hall", "hall", "steel", hall=True)
south = new_area("South Hall", "hall", "steel", hall=True)
west = new_area("West Hall", "hall", "steel", hall=True)
east = new_area("East Hall", "hall", "steel", hall=True)
central = new_area("Central Hall", "hall", "steel", hall=True)
cmd_hall = new_area("Command Hall", "hall", "blue", hall=True)
dep_hall = new_area("Departures Hall", "hall", "steel", hall=True)
lounge = new_area("Departure Lounge", "departures", "blue", hall=True)
med_hall = new_area("Medbay Hall", "hall", "white", hall=True)
cargo_hall = new_area("Cargo Hall", "hall", "steel", hall=True)
eng_hall = new_area("Engineering Hall", "hall", "steel", hall=True)
atmos_hall = new_area("Atmospherics Hall", "hall", "steel", hall=True)
quarters_hall = new_area("Quarters Hall", "hall", "steel", hall=True)
north_lock_hall = new_area("North Airlock Hall", "hall", "steel", hall=True)
paint(north, 3, 31, 78, 33)
paint(west, 42, 34, 44, 76)
paint(east, 79, 27, 81, 59)
paint(south, 42, 57, 118, 59)
for cx, cy in ((42, 31), (79, 31), (42, 57), (79, 57)):
    paint(central, cx, cy, cx + 2, cy + 2)
paint(cmd_hall, 46, 21, 77, 23)
paint(cmd_hall, 60, 24, 62, 30)
paint(dep_hall, 82, 27, 105, 29)
paint(lounge, 106, 27, 121, 29)
paint(med_hall, 82, 31, 96, 33)
paint(cargo_hall, 3, 61, 41, 63)
paint(eng_hall, 45, 65, 84, 67)
paint(atmos_hall, 85, 60, 87, 80)
paint(quarters_hall, 87, 12, 89, 26)
paint(north_lock_hall, 38, 14, 40, 30)

# ====================================================================== SECURITY (north-west)
origin(2, 10)
sec = room("Security Office", "security_office", 1, 11, 16, 19)
armory = room("Armory", "armory", 1, 1, 8, 9)
hos = room("Head of Security's Office", "hos_office", 10, 1, 16, 9)
brig = room("Brig", "brig", 18, 13, 28, 19)
for i, cx in enumerate((18, 22, 26)):
    paint(brig, cx, 8, cx + 2, 11)
    door(cx + 1, 12, brig)
    obj(cx + 1, 8, "bed", spr="bed_1", name="brig cell bed")
    obj(cx, 11, "decal", spr="edge_sec")
fp_maint = room("Fore-Port Maintenance", "maint_storage", 18, 1, 28, 6, floor="plating")
door(9, 20)        # security office front door
door(24, 20)       # brig lobby door
door(17, 15, brig)  # office <-> brig
door(5, 10)        # armory
door(13, 10)       # HoS office
door(29, 3)        # maint
windows(2, 20, 7, 20)
windows(11, 20, 15, 20)
windows(19, 20, 22, 20)
# security office: front desk, lockers, console, briefing table
row("counter", 2, 7, 18, spr="table_counter")
obj(3, 18, "paper")
obj(6, 18, "handcuffs")
obj(8, 11, "console", spr="console_sec", comps={"console": {"kind": "sec"}})
table(11, 14, "steel", "paper")
table(12, 14, "steel", "flashlight")
table(11, 15, "steel")
table(12, 15, "steel", "handcuffs")
chair(10, 14, "e")
chair(10, 15, "e")
chair(13, 14, "w")
chair(13, 15, "w")
obj(15, 18, "potted_plant", spr="potted_plant_0")
obj(4, 11, "noticeboard")
obj(12, 11, "wall_clock")
obj(15, 11, "vending", spr="vending_snack", comps={"vending": {"products": [["food_donut", 10], ["drink_coffee", 8]]}})
edge(1, 11, 16, 19, "sec")
# armory: weapon racks and lockers
row("table", 2, 7, 1, spr="table_steel")
obj(2, 1, "baton")
obj(3, 1, "baton")
obj(4, 1, "handcuffs")
obj(5, 1, "riot_shield")
obj(6, 1, "riot_shield")
obj(7, 1, "flashlight")
obj(2, 5, "locker", kind="sec", items=["baton", "baton", "handcuffs", "handcuffs"])
obj(2, 7, "locker", kind="sec", items=["medkit", "flashlight", "gas_mask", "gas_mask"])
# tg armory: the armour rack, riot gear, the shotguns and the lethal ammo
obj(8, 5, "locker", kind="sec", name="armour locker", items=["armor_vest", "armor_vest", "armor_vest", "helmet_sec", "helmet_sec", "helmet_sec"])
obj(8, 7, "locker", kind="sec", name="riot gear locker", items=["riot_armor", "riot_armor", "helmet_riot", "helmet_riot", "bulletproof_vest", "reflector_vest"])
obj(8, 3, "locker", kind="sec", name="weapons locker", items=["shotgun", "shotgun", "shell_beanbag", "shell_beanbag", "shell_buckshot", "shell_slug", "ammo_38", "ammo_38_rubber"], comps={"storage": {"access": ["armory"]}})
stripes(4, 4, 7, 7)
# HoS office
table(13, 3, "wood", "paper", "revolver")
table(14, 3, "wood", "flashlight")
chair(13, 4, "n", "comfy")
obj(16, 1, "bookshelf")
obj(10, 1, "potted_plant", spr="potted_plant_1")
# brig main room: a bench for the booked, the processing desk
for x in (20, 21, 22):
    obj(x, 16, "bench")
table(26, 15, "steel", "paper")
chair(26, 16, "n")
edge(18, 13, 28, 19, "sec")
# maintenance
obj(19, 1, "crate", kind="gen", items=["sheet_metal", "cable_coil", "glowstick"])
obj(20, 1, "crate", kind="gen", items=["drink_soda", "light_tube"])
obj(27, 5, "canister_air")
obj(24, 3, "trash_bin")
obj(22, 5, "debris")

# ====================================================================== COMMAND (north)
origin(12, 0)
capt = room("Director's Office", "captain_office", 34, 1, 39, 10, floor="bluecarpet")
eva = room("EVA Storage", "eva_storage", 34, 12, 39, 19, floor="dark")
bridge = room("Bridge", "bridge", 41, 1, 58, 19, floor="blue")
vault = room("Vault", "vault", 60, 1, 65, 9, floor="dark")
hop = room("Personnel Office", "hop_office", 60, 11, 65, 19, floor="bluecarpet")
door(40, 6, capt)
door(36, 20)
door(49, 20, bridge)
door(50, 20, bridge)
door(59, 15, bridge)
door(62, 20)
door(62, 10, vault)
windows(42, 0, 57, 0, 2)
windows(35, 0, 38, 0, 2)
windows(42, 20, 47, 20)
windows(52, 20, 57, 20)
windows(63, 20, 64, 20)
# bridge: a horseshoe of consoles facing the windows, the captain's chair behind
for x, kind, spr in ((44, "cmd", "console_cmd"), (46, "comms", "console_comms"), (48, "med", "console_med"),
                     (51, "atmos", "console_atmos"), (53, "eng", "console_eng"), (55, "sec", "console_sec")):
    obj(x, 3, "console", spr=spr, comps={"console": {"kind": kind}})
    chair(x, 4, "n", "office")
obj(42, 6, "console", spr="console_cargo", comps={"console": {"kind": "cargo"}})
obj(57, 6, "console", spr="console_sci", comps={"console": {"kind": "sci"}})
chair(49, 9, "n", "comfy")
table(47, 12, "glass", "paper")
table(48, 12, "glass")
table(51, 12, "glass", "flashlight")
table(52, 12, "glass")
for x in (47, 48, 51, 52):
    chair(x, 13, "n", "office")
obj(42, 18, "locker", kind="emerg", items=["tank_air", "breath_mask", "extinguisher_mini"])
obj(57, 18, "locker", kind="emerg", items=["tank_air", "breath_mask", "extinguisher_mini"])
obj(42, 15, "potted_plant", spr="potted_plant_0")
obj(57, 15, "potted_plant", spr="potted_plant_1")
edge(41, 1, 58, 19, "cmd")
# director's office
table(36, 3, "wood", "paper", "drink_booze")
table(37, 3, "wood", "flashlight")
chair(36, 4, "n", "comfy")
obj(34, 1, "bookshelf")
obj(39, 1, "bookshelf")
obj(38, 9, "potted_plant", spr="potted_plant_1")
obj(34, 8, "bed", spr="bed_3", name="the Director's bed")
obj(39, 8, "display_case", name="the Director's display case", desc="A glass case holding the station's founding charter and a very old ice pick.")
obj(37, 1, "wall_clock")
# EVA storage: winter gear lockers and a suit rack
for y in (13, 15, 17):
    obj(34, y, "locker", kind="winter", items=["winter_coat", "winter_hood", "breath_mask", "tank_o2", "flashlight"])
# tg EVA storage: sealed suits for going outside when the air's gone
for y in (13, 16):
    obj(39, y, "locker", kind="eng", name="EVA suit storage", items=["eva_suit", "eva_helmet", "tank_o2", "breath_mask"])
table(38, 13, "steel", "tank_air", "breath_mask")
table(38, 14, "steel", "gas_mask")
stripes(36, 16, 38, 18)
# vault: tg's vault has the station's reserves locked away behind command access
obj(60, 1, "locker", kind="cmd", name="vault safe", desc="A heavy steel safe for the station's reserves.", items=["spacecash", "spacecash", "spacecash", "spacecash", "ore_gold", "ore_gold"], comps={"storage": {"access": ["captain"]}})
obj(62, 3, "crate", kind="sec", items=["ore_gold", "ore_gold", "sheet_plasma"])
obj(64, 3, "crate", kind="gen", items=["ore_gold", "paper"])
obj(61, 1, "display_case", name="bullion display", items=["ore_gold"])
obj(65, 1, "display_case", name="plasma display", items=["sheet_plasma"])
obj(65, 5, "crate", kind="sec", name="secure reserve crate", items=["sheet_plasma", "sheet_plasma", "ore_cryo", "ore_cryo", "rcd_ammo"])
stripes(61, 6, 64, 8)
# personnel office: the queue desk faces the hall
table(62, 17, "counter", "paper")
table(63, 17, "counter")
chair(62, 16, "s", "office")
obj(61, 12, "console", spr="console_cmd", comps={"console": {"kind": "cmd"}})
obj(64, 11, "noticeboard")
obj(65, 12, "bookshelf")

# ====================================================================== CREW QUARTERS (north-east)
origin(20, 6)
dh = new_area("Dormitory Hall", "hall", "steel", hall=True)
paint(dh, 71, 9, 98, 11)
door(70, 10, dh)
for i, x0 in enumerate((71, 78, 85, 92)):
    d = room("Dormitories " + "ABCD"[i], "dormitories", x0, 1, x0 + 5, 7, floor="wood")
    door(x0 + 2, 8, d)
    obj(x0, 1, "bed", spr="bed_%d" % (i % 6))
    obj(x0 + 5, 1, "bed", spr="bed_%d" % ((i + 3) % 6))
    obj(x0, 5, "wardrobe", items=["winter_coat", "beanie", "scarf"] if i % 2 == 0 else ["winter_coat", "flashlight", "drink_water"])
    table(x0 + 5, 5, "wood", ["paper", "drink_water", "flashlight", "food_donut"][i])
    obj(x0 + 5, 7, "potted_plant", spr="potted_plant_%d" % (i % 2))
    window(x0 + 2, 0)
    window(x0 + 3, 0)
rest = room("Restrooms", "restroom", 71, 13, 78, 19, floor="freezer")
crew = room("Crew Lounge", "lounge", 80, 13, 98, 19, floor="carpet")
door(74, 12, rest)
door(86, 12, crew)
door(89, 20, crew)
windows(81, 20, 86, 20)
windows(92, 20, 97, 20)
# restrooms: sinks under mirrors, toilet stalls down the east wall, showers in the corner
row("sink", 71, 73, 13)
for x in (71, 72, 73):
    obj(x, 13, "mirror")
table(74, 13, "counter", "soap")
for y in (14, 16, 18):
    obj(78, y, "toilet")
    obj(77, y, "curtain", spr="shower_curtain_open", comps={"curtain": {"style": "shower_curtain"}})
for x in (71, 72, 73):
    obj(x, 19, "shower")
    obj(x, 18, "curtain", spr="shower_curtain_open", comps={"curtain": {"style": "shower_curtain"}})
obj(75, 19, "bench")
# lounge: sofas round low tables, books, a cocoa machine
for tx in (83, 90):
    table(tx, 16, "wood", "drink_cocoa" if tx == 83 else "paper")
    chair(tx - 1, 16, "e", "comfy")
    chair(tx + 1, 16, "w", "comfy")
    chair(tx, 15, "s", "comfy")
row("bookshelf", 80, 82, 13)
obj(98, 13, "vending", spr="vending_cocoa", comps={"vending": {"products": [["drink_cocoa", 12], ["drink_coffee", 10]]}})
obj(96, 13, "vending", spr="vending_snack", comps={"vending": {"products": [["food_donut", 8], ["food_ration", 10], ["food_sandwich", 4]]}})
obj(80, 19, "potted_plant", spr="potted_plant_0")
obj(98, 19, "potted_plant", spr="potted_plant_1")
obj(94, 17, "baseball_bat")

# ====================================================================== SCIENCE (west)
origin(12, 10)
lab = room("Research Lab", "research_lab", 1, 25, 14, 34, floor="white")
xeno = room("Xenochemistry", "xenochem", 1, 36, 14, 45, floor="purple")
rd = room("RD's Office", "rd_office", 16, 25, 28, 31, floor="purple")
servers = room("Server Room", "server_room", 16, 33, 20, 38, floor="dark")
sstore = room("Science Storage", "science_storage", 22, 33, 28, 38, floor="dark")
p_maint = room("Port Maintenance", "maint_storage", 16, 40, 28, 45, floor="plating")
door(7, 24)
door(15, 28, rd)
door(15, 34, servers)
door(21, 36, sstore)
door(7, 35, xeno)
door(29, 43)
door(22, 46)
windows(2, 24, 5, 24)
windows(9, 24, 13, 24)
windows(0, 26, 0, 33, 2)
windows(0, 37, 0, 44, 2)
# research lab: workbenches with glassware, the R&D console, a dispenser
for x in (3, 4, 5):
    table(x, 28, "steel", "beaker" if x != 4 else "health_analyzer")
for x in (9, 10, 11):
    table(x, 28, "steel", "beaker" if x != 10 else "paper")
for x in (3, 4, 5, 9, 10, 11):
    chair(x, 29, "n", "office")
obj(2, 25, "console", spr="console_sci", comps={"console": {"kind": "sci"}})
# tg R&D: the protolathe and destructive analyzer beside the R&D console
obj(4, 25, "protolathe")
obj(6, 25, "destructive_analyzer")
stripes(3, 26, 7, 26)
obj(12, 25, "chem_dispenser")
obj(1, 33, "locker", kind="sci", items=["beaker", "beaker", "gas_mask", "extinguisher_mini"])
obj(14, 33, "locker", kind="sci", items=["gas_mask", "extinguisher_mini", "multitool"])
obj(14, 25, "sink")
obj(13, 34, "disposal")
obj(12, 33, "autolathe", name="research autolathe")
edge(1, 25, 14, 34, "sci")
# xenochemistry: the lab that blows up. tg-style: a chem line along the north wall
# (dispenser, heater, ChemMaster), benches of glassware, a fume hood (portable
# scrubber) over the reaction bench, the burn-test pad with its plasma, an emergency
# shower by the door, and the safety lockers
obj(2, 44, "canister_plasma")
obj(3, 44, "canister_plasma")
obj(4, 44, "canister_n2")
obj(3, 42, "igniter", name="burn pad igniter")
obj(12, 37, "chem_dispenser")
obj(13, 37, "chem_heater")
obj(11, 37, "chem_master")
obj(10, 37, "sink")
table(8, 39, "steel", "beaker", "beaker_large")
table(9, 39, "steel", "gas_mask", "dropper")
table(10, 39, "steel", "beaker", "bottle")
table(11, 39, "steel", "syringe", "bottle")
table(8, 41, "steel", "beaker_large", "beaker")
table(9, 41, "steel", "health_analyzer", "gas_analyzer")
obj(10, 41, "portable_scrubber", name="fume hood scrubber")
obj(1, 37, "locker", kind="fire", items=["extinguisher", "gas_mask", "gas_mask", "tank_air", "tank_air"])
obj(1, 38, "locker", kind="sci", items=["beaker", "beaker", "beaker_large", "bottle", "bottle", "dropper", "syringe", "pill_bottle"])
obj(7, 45, "shower", name="emergency shower")
obj(6, 45, "curtain", comps={"curtain": {"style": "shower_curtain"}})
obj(14, 44, "extinguisher")
obj(13, 45, "disposal")
obj(5, 36, "noticeboard", name="safety board")
stripes(1, 42, 5, 45)
# RD office
table(22, 27, "wood", "paper", "multitool")
table(23, 27, "wood")
chair(22, 28, "n", "comfy")
obj(26, 25, "console", spr="console_sci", comps={"console": {"kind": "sci"}})
obj(16, 25, "bookshelf")
obj(28, 31, "potted_plant", spr="potted_plant_0")
# server room: two rows of racks with a cold aisle between (the north wall stays clear
# for the room's APC and alarms)
for y in (34, 37):
    for x in (17, 18, 19, 20):
        obj(x, y, "server_rack")
row("decal", 17, 20, 35, spr="line_blue_n")
row("decal", 17, 20, 36, spr="line_blue_s")
obj(16, 38, "console", spr="console_sci", comps={"console": {"kind": "sci"}}, name="server control console")
# science storage
for x in (23, 25):
    obj(x, 33, "crate", kind="sci", items=["beaker", "sheet_glass", "gas_mask"])
obj(27, 37, "canister_n2")
obj(27, 36, "canister_o2")
# port maintenance
obj(17, 40, "crate", kind="eng", items=["sheet_metal", "cable_coil", "wrench"])
obj(18, 40, "crate", kind="gen", items=["food_ration", "glowstick"])
obj(27, 44, "generator")
obj(26, 41, "fuel_tank")
obj(20, 43, "trash_bin")
obj(23, 42, "debris")
obj(21, 44, "decal", spr="puddle_oil")

# ====================================================================== SERVICE HUB (centre)
origin(12, 10)
caf = room("Cafeteria", "cafeteria", 34, 25, 57, 38, floor="cafe")
bar = room("Bar", "bar", 59, 25, 65, 38, floor="wood")
kitchen = room("Kitchen", "kitchen", 34, 40, 47, 45, floor="freezer")
hydro = room("Hydroponics", "hydroponics", 49, 40, 65, 45, floor="green")
# the bar is open to the cafeteria over its counter (no wall at x=58)
paint(bar, 58, 25, 58, 38)
door(45, 24, caf)
door(46, 24, caf)
door(33, 31, caf)
door(66, 31, bar)
door(45, 39, kitchen)
door(48, 43, hydro)
door(57, 46, hydro)
windows(37, 24, 43, 24)
windows(48, 24, 56, 24)
windows(50, 46, 55, 46)
windows(59, 46, 64, 46)
# the kitchen's serving hatch onto the cafeteria
for x in (40, 41, 42, 43):
    floor_cell(x, 39, kitchen)
    obj(x, 39, "counter", spr="table_counter")
obj(41, 39, "food_sandwich")
obj(43, 39, "food_burger")
# the bar counter and stools
for y in range(25, 39):
    obj(58, y, "counter", spr="table_bar", name="bar counter", desc="A polished wooden bar top with a brass rail.")
for y, it in ((27, "drink_booze"), (29, "drink_soda"), (32, "drink_booze"), (35, "drink_coffee")):
    obj(58, y, it)
for y in range(26, 38, 2):
    obj(57, y, "bar_stool")
obj(63, 37, "jukebox")
obj(59, 33, "arcade")
obj(60, 25, "wall_clock")
row("counter", 61, 65, 25, spr="table_bar", name="back bar")
obj(61, 25, "drink_booze")
obj(62, 25, "drink_booze")
obj(64, 25, "drink_soda")
obj(65, 30, "fridge", items=["drink_booze", "drink_booze", "drink_booze", "drink_soda", "drink_soda", "drink_soda"])
obj(65, 37, "sink")
obj(62, 37, "potted_plant", spr="potted_plant_1")
obj(60, 37, "vending", spr="vending_drink", comps={"vending": {"products": [["drink_soda", 10], ["drink_water", 12]]}})
# cafeteria: staggered tables either side of a clear aisle (x 44-46, from the hall doors
# to the kitchen hatch), booths by the west wall, vending along the north wall
for tx, ty in ((40, 28), (48, 28), (51, 28), (39, 32), (49, 32), (52, 32), (40, 36), (48, 36), (51, 36)):
    table(tx, ty, "wood")
    table(tx + 1, ty, "wood")
    chair(tx, ty - 1, "s", "wood")
    chair(tx + 1, ty - 1, "s", "wood")
    chair(tx, ty + 1, "n", "wood")
    chair(tx + 1, ty + 1, "n", "wood")
for by in (27, 35):  # booths: a table between two benches against the west wall
    obj(34, by, "bench", spr="bench_wood")
    table(34, by + 1, "wood")
    obj(34, by + 2, "bench", spr="bench_wood")
    obj(35, by + 1, "chair", spr="chair_wood_w")
for tx, ty, it in ((40, 28, "drink_coffee"), (49, 28, "food_donut"), (49, 32, "drink_cocoa"), (52, 36, "food_ration"), (41, 36, "paper"), (34, 28, "drink_cocoa")):
    obj(tx, ty, it)
obj(37, 32, "potted_plant", spr="potted_plant_1")
obj(55, 33, "potted_plant", spr="potted_plant_0")
obj(34, 25, "vending", spr="vending_snack", comps={"vending": {"products": [["food_donut", 8], ["food_ration", 10], ["food_sandwich", 4]]}})
obj(35, 25, "vending", spr="vending_cocoa", comps={"vending": {"products": [["drink_cocoa", 12], ["drink_coffee", 10]]}})
obj(56, 25, "vending", spr="vending_drink", comps={"vending": {"products": [["drink_soda", 10], ["drink_water", 12]]}})
obj(34, 38, "potted_plant", spr="potted_plant_0")
obj(56, 38, "potted_plant", spr="potted_plant_1")
obj(36, 38, "trash_bin")
# kitchen: counters round the walls, ovens, fridge, prep table in the middle
row("counter", 34, 38, 40, spr="table_counter")
obj(34, 40, "microwave")
obj(36, 40, "knife_kitchen")
obj(37, 40, "food_flour")
obj(38, 40, "food_egg")
obj(39, 40, "oven")
obj(47, 40, "fridge", items=["food_meat", "food_meat", "food_meat", "food_flour", "food_flour", "food_egg", "food_egg", "food_tomato", "food_potato", "food_potato"])
obj(47, 42, "fridge", items=["food_meat", "food_berries", "food_banana", "drink_water"])
table(41, 43, "steel", "knife_cleaver", "food_meat")
table(42, 43, "steel", "food_tomato")
obj(34, 45, "sink")
row("decal", 34, 38, 41, spr="edge_srv")
# tg kitchen: a second range and microwave on the cook line, a prep island, the
# walk-in freezer by the back wall, trash and a disposal bin, and the recipe board
obj(40, 40, "oven")
obj(35, 40, "microwave")
table(40, 43, "steel", "food_flour", "food_egg")
table(43, 43, "steel", "knife_kitchen", "food_potato")
obj(47, 44, "fridge", name="walk-in freezer", desc="Keeps the meat frozen. Not that that's hard out here.", items=["food_meat", "food_meat", "food_meat", "food_meat", "food_meat", "food_egg", "food_egg", "food_egg"])
obj(35, 45, "trash_bin")
obj(36, 45, "disposal")
obj(39, 45, "vending", spr="vending_cocoa", comps={"vending": {"products": [["drink_cocoa", 10], ["drink_coffee", 10], ["drink_water", 6]]}}, name="Hot Drinks machine")
obj(37, 40, "noticeboard", name="recipe board")
obj(46, 40, "wall_clock")
# hydroponics: rows of trays with walkways
for ty in (41, 43):
    for tx in range(51, 64):
        if tx not in (54, 58, 62):
            obj(tx, ty, "hydro_tray")
obj(65, 45, "sink")
obj(49, 40, "crate", kind="food", items=["food_wheat", "food_tomato", "food_potato"])
table(50, 45, "steel", "bucket")
edge(49, 40, 65, 45, "srv")

# ====================================================================== MEDBAY (east)
origin(12, 10)
lobby = room("Medbay Lobby", "medbay_lobby", 71, 25, 80, 33, floor="white")
treat = room("Medbay Treatment", "treatment", 82, 25, 98, 38, floor="tealmed")
chem = room("Chemistry", "chemistry", 71, 35, 80, 40, floor="white")
cmo = room("CMO's Office", "cmo_office", 82, 40, 89, 45, floor="tealmed")
morgue = room("Morgue", "morgue", 91, 40, 98, 45, floor="dark")
sb_maint = room("Starboard Maintenance", "maint_storage", 71, 42, 80, 45, floor="plating")
door(75, 24, lobby)
door(76, 24, lobby)
door(70, 29, lobby)
door(81, 29, treat)
door(81, 37, chem)
door(85, 39, cmo)
door(94, 39, morgue)
door(70, 43)
door(75, 46)
windows(72, 24, 73, 24)
windows(78, 24, 79, 24)
windows(99, 26, 99, 37, 2)
# chemistry's pass-through window onto the lobby
for x in (77, 78):
    floor_cell(x, 34, chem)
    obj(x, 34, "counter", spr="table_counter")
obj(77, 34, "pill_bottle")
# lobby: rows of waiting benches, the reception desk, the medical vending machine
for x in (72, 73, 74):
    obj(x, 27, "bench")
    obj(x, 31, "bench")
table(77, 26, "counter", "paper")
table(78, 26, "counter", "health_analyzer")
chair(77, 25, "s", "office")
obj(73, 25, "noticeboard")
# tg NanoMed Plus stock
obj(80, 25, "vending", spr="vending_med", comps={"vending": {"products": [["suture", 6], ["mesh", 6], ["gauze", 6], ["bruise_pack", 4], ["ointment", 4], ["patch_libital", 6], ["patch_aiuri", 6], ["pill_multiver", 6], ["pill_salbutamol", 4], ["pill_iron", 4], ["syringe", 8], ["medipen", 4], ["health_analyzer", 2], ["splint", 4], ["bonesetter", 2], ["bone_gel", 2], ["surgical_tape", 2], ["pill_bottle", 3]]}})
obj(71, 25, "potted_plant", spr="potted_plant_0")
edge(71, 25, 80, 33, "med")
# treatment: curtained recovery bays down the east wall (bed, IV drip, bedside table),
# two triage beds in the middle, sleepers and the crew monitor along the north wall
for y in (26, 29, 32, 35):
    obj(98, y, "med_bed")
    obj(97, y, "iv_drip")
    table(98, y + 1, "glass", "suture" if y % 2 else "mesh", "gauze")
    obj(96, y, "curtain")
    obj(96, y + 1, "curtain")
    if y < 35:
        obj(97, y + 2, "curtain", comps={"curtain": {"closed": True}})
        obj(98, y + 2, "curtain", comps={"curtain": {"closed": True}})
obj(84, 25, "sleeper")
obj(88, 25, "sleeper")
obj(92, 25, "console", spr="console_med", comps={"console": {"kind": "med"}})
for x in (86, 90):
    obj(x, 32, "med_bed", name="triage bed")
    obj(x + 1, 32, "iv_drip")
    obj(x, 31, "curtain")
    obj(x + 1, 31, "curtain")
table(85, 29, "glass", "medkit", "health_analyzer")
obj(95, 37, "disposal")
table(86, 29, "glass", "medkit_burn")
table(87, 29, "glass", "medkit_toxin")
row("decal", 84, 92, 28, spr="line_blue_s")
obj(82, 34, "locker", kind="med", items=["medkit", "medkit_burn", "suture", "mesh", "health_analyzer", "splint", "bonesetter"])
obj(82, 36, "locker", kind="med", items=["medkit_o2", "medkit_toxin", "pill_bottle", "bone_gel", "surgical_tape", "syringe", "bottle_epinephrine"])
# tg blood bank: a fridge of blood packs and saline by the treatment bays
obj(93, 38, "fridge", name="blood bank", items=["blood_pack", "blood_pack", "blood_pack", "blood_pack", "saline_bag", "saline_bag", "blood_pack_empty", "blood_pack_empty"])
obj(95, 38, "sink")
obj(82, 25, "potted_plant", spr="potted_plant_1")
obj(90, 25, "med_cabinet")
obj(83, 38, "med_cabinet")
# the operating corner: table under a surgical light, instrument trays either side
obj(87, 36, "op_table")
table(85, 36, "glass", "scalpel", "hemostat")
table(85, 37, "glass", "retractor", "cautery")
table(89, 36, "glass", "circular_saw")
table(89, 37, "glass", "surgical_drapes", "bonesetter")
table(88, 38, "glass", "bone_gel", "surgical_tape")
obj(87, 36, "ceiling_light", comps={"light": {"kind": "ceiling", "radius": 4.0, "color": "#f4fbff", "energy": 1.1}})
for x in range(84, 91):
    obj(x, 34, "decal", spr="line_white_n")
obj(94, 25, "wall_clock")
edge(82, 25, 98, 38, "med")
# chemistry: two dispensers, each with a ChemMaster and a heater beside it (tg chem lab)
obj(71, 36, "chem_dispenser")
obj(71, 37, "chem_heater")
obj(71, 39, "chem_dispenser")
obj(71, 38, "chem_master")
table(74, 37, "steel", "beaker", "beaker_large")
table(75, 37, "steel", "dropper", "syringe")
table(76, 37, "steel", "beaker", "bottle")
obj(80, 40, "locker", kind="med", items=["beaker", "beaker", "beaker_large", "gas_mask", "pill_bottle", "bottle", "bottle", "dropper"])
obj(79, 36, "sink")
stripes(72, 40, 73, 40)
# CMO office
table(85, 42, "glass", "paper", "health_analyzer")
chair(85, 43, "n", "comfy")
obj(89, 40, "bookshelf")
obj(82, 45, "potted_plant", spr="potted_plant_0")
# morgue
for x in (92, 94, 96):
    obj(x, 42, "med_bed", name="morgue tray")
obj(98, 45, "trash_bin")
# starboard maintenance
obj(71, 42, "crate", kind="med", items=["bruise_pack", "ointment"])
obj(72, 42, "crate", kind="gen", items=["paper", "drink_soda", "light_tube"])
obj(80, 45, "canister_air")
obj(76, 44, "debris")

# ====================================================================== GENETICS (east of Treatment)
# tg's genetics lab: two DNA scanner + console pairs, a bench of disks, sequence scanners
# and mutadone, and a windowed monkey pen with a box of monkey cubes. Entered from
# Treatment; the pen opens off the lab. (Custodial and Tool Storage sit just south.)
gen = room("Genetics", "genetics", 100, 28, 109, 37, floor="white")
pen = room("Monkey Pen", "monkey_pen", 111, 29, 114, 37, floor="green")
door(99, 37, gen)
door(110, 36, pen)
windows(110, 29, 110, 35)
# the DNA consoles, each with its scanner beside it (tg connect_to_scanner: cardinal).
# They stand along the south wall: the north wall is where the alarms, APC and lights go.
obj(102, 37, "dna_console")
obj(103, 37, "dna_scanner")
obj(106, 37, "dna_console")
obj(107, 37, "dna_scanner")
obj(105, 34, "skill_station")
obj(102, 32, "skillchip", comps={"skillchip": {"kind": "musical"}})
chair(102, 36, "s", "office")
chair(106, 36, "s", "office")
obj(104, 28, "med_cabinet")
# the bench: disks, sequence scanners, mutadone, gloves
table(101, 32, "glass", "disk_box", "sequence_scanner")
table(102, 32, "glass", "sequence_scanner", "latex_gloves")
table(103, 32, "glass", "pill_bottle_mutadone", "pill_bottle_mutadone")
table(109, 32, "glass", "monkey_cube_box")
table(109, 33, "glass", "food_banana", "food_banana")
obj(109, 30, "sink")
obj(109, 37, "potted_plant", spr="potted_plant_1")
edge(100, 28, 109, 37, "med")
# the pen and its monkeys
for (x, y) in ((112, 30), (113, 33), (112, 36)):
    obj(x, y, "monkey")

# ====================================================================== CARGO (south-west)
origin(6, 14)
cargo = room("Cargo Bay", "cargo_bay", 1, 51, 20, 62, floor="yellow")
qm = room("Quartermaster's Office", "qm_office", 22, 51, 28, 57, floor="yellow")
ap_maint = room("Aft-Port Maintenance", "maint_storage", 22, 59, 28, 62, floor="plating")
mining = room("Mining Dock", "mining_dock", 1, 64, 13, 70, floor="dark")
ware = room("Cargo Warehouse", "warehouse", 15, 64, 28, 70, floor="dark")
door(10, 50, cargo)
door(11, 50, cargo)
door(21, 54, qm)
door(25, 50, qm)
door(29, 60)
door(7, 63, mining)
door(20, 63, ware)
windows(2, 50, 8, 50)
windows(13, 50, 19, 50)
windows(0, 65, 0, 69, 2)
# cargo bay: the delivery floor with its conveyor-side crates and the supply console
for k, (x, y, kind, items) in enumerate(((2, 52, "food", ["food_ration", "food_ration", "food_flour", "food_meat", "drink_water"]),
                                         (3, 52, "eng", ["sheet_metal", "sheet_glass", "cable_coil", "welder"]),
                                         (4, 52, "med", ["medkit", "bruise_pack", "ointment"]),
                                         (2, 54, "gen", ["flashlight", "glowstick", "paper", "drink_soda"]),
                                         (3, 54, "gen", ["winter_coat", "beanie"]))):
    obj(x, y, "crate", kind=kind, items=items)
stripes(1, 56, 6, 62)
# the delivery lane: from the hall doors down to the mining dock and warehouse
for y in range(51, 63):
    obj(10, y, "decal", spr="line_yellow_w")
    obj(11, y, "decal", spr="line_yellow_e")
for y in (53, 57, 61):
    obj(10, y, "decal", spr="arrow_s")
    obj(11, y, "decal", spr="arrow_s")
for x in range(12, 21):
    obj(x, 61, "decal", spr="line_yellow_n")
    obj(x, 62, "decal", spr="line_yellow_s")
obj(15, 61, "decal", spr="arrow_e")
obj(12, 51, "console", spr="console_cargo", comps={"console": {"kind": "cargo"}})
# tg: the public autolathe in the cargo office
obj(17, 51, "autolathe")
obj(19, 51, "disposal")
table(14, 51, "steel", "paper", "paper")
table(15, 51, "steel", "crowbar")
chair(14, 52, "n", "office")
obj(18, 62, "trash_bin")
edge(1, 51, 20, 62, "cargo")
# QM office
table(25, 53, "wood", "paper")
chair(25, 54, "n", "comfy")
obj(22, 51, "console", spr="console_cargo", comps={"console": {"kind": "cargo"}})
obj(28, 51, "bookshelf")
# maintenance
obj(23, 59, "crate", kind="gen", items=["sheet_metal", "light_tube"])
obj(27, 62, "fuel_tank")
obj(25, 61, "debris")
# mining dock
for x in (1, 2):
    obj(x, 64, "locker", kind="winter", items=["winter_coat", "winter_hood", "breath_mask", "tank_o2", "pickaxe", "flashlight"])
table(11, 64, "steel", "pickaxe")
table(12, 64, "steel", "flashlight", "tank_air")
obj(13, 70, "crate", kind="gen", items=["ore_iron"])
stripes(5, 67, 9, 70)
# warehouse
for i, x in enumerate(range(16, 28, 2)):
    obj(x, 66, "crate", kind=["gen", "food", "eng", "gen", "med", "gen"][i], items=[["paper", "glowstick"], ["food_ration", "drink_water"], ["cable_coil", "sheet_metal"], ["drink_soda"], ["bruise_pack"], ["light_tube", "soap"]][i])
    obj(x, 69, "crate", kind="gen", items=["sheet_wood"] if False else ["paper"])

# ====================================================================== ENGINEERING (south)
origin(12, 18)
eng = room("Engineering", "engineering", 34, 51, 52, 58, floor="yellow")
ce = room("CE's Office", "ce_office", 54, 51, 65, 57, floor="yellow")
reactor = room("Reactor Chamber", "reactor", 34, 60, 55, 70, floor="grate")
power = room("Power Storage", "power_storage", 57, 60, 65, 70, floor="dark")
door(42, 50, eng)
door(43, 50, eng)
door(33, 54, eng)
door(53, 54, ce)
door(60, 50, ce)
door(43, 59, reactor)
door(56, 64, power)
windows(36, 50, 40, 50)
windows(45, 50, 51, 50)
windows(44, 59, 50, 59)
# engineering: lockers, the tool vendor, workbenches, consoles over the reactor window
for x in (34, 35, 36):
    obj(x, 51, "locker", kind="eng", items=["toolbox", "insulated_gloves", "cable_coil", "welder", "sheet_metal", "sheet_glass", "hardhat"])
obj(38, 51, "vending", spr="vending_tool", comps={"vending": {"products": [["wrench", 5], ["welder", 4], ["crowbar", 5], ["multitool", 3], ["cable_coil", 6], ["flashlight", 5]]}})
obj(46, 58, "console", spr="console_eng", comps={"console": {"kind": "eng"}})
obj(48, 58, "console", spr="console_reactor", comps={"console": {"kind": "reactor"}})
obj(50, 58, "console", spr="console_atmos", comps={"console": {"kind": "atmos"}})
table(41, 54, "steel", "toolbox_elec")
table(42, 54, "steel", "sheet_metal")
table(43, 54, "steel", "welder", "cable_coil")
table(44, 54, "steel", "sheet_glass")
chair(42, 55, "n", "office")
obj(52, 51, "fuel_tank")
# workbench under the tool pegboards
for x, it in ((46, "wrench"), (47, "screwdriver"), (48, "wirecutters")):
    table(x, 51, "steel", it)
    obj(x, 51, "pegboard")
obj(34, 58, "extinguisher")
# tg: engineering's autolathe, with a stack of sheets to feed it
obj(40, 51, "autolathe")
table(44, 51, "steel", "sheet_metal", "sheet_glass")
stripes(34, 57, 38, 58)
edge(34, 51, 52, 58, "eng")
# CE office
table(58, 53, "wood", "paper", "multitool")
table(59, 53, "wood", "flashlight")
chair(58, 54, "n", "comfy")
obj(62, 51, "console", spr="console_reactor", comps={"console": {"kind": "reactor"}})
obj(65, 51, "locker", kind="eng", items=["toolbox", "insulated_gloves", "multitool", "rcd", "rcd_ammo"])
obj(54, 57, "potted_plant", spr="potted_plant_0")
# reactor chamber: the reactor and TEG go in the middle (placed by the engine builder),
# hazard stripes round the core
stripes(39, 62, 50, 62)
stripes(39, 70, 50, 70)
obj(35, 61, "locker", kind="fire", items=["extinguisher", "gas_mask", "tank_air", "holofan", "rpd"])
obj(54, 61, "locker", kind="fire", items=["extinguisher", "gas_mask", "tank_air"])

# ====================================================================== TOOLS / JANITOR (east of Medbay)
origin(0, 0)
tools = room("Tool Storage", "tool_storage", 118, 49, 124, 55, floor="steel")
cust = room("Custodial Closet", "custodial", 113, 49, 116, 55, floor="plating")
door(118, 56, tools)
door(115, 56, cust)
# tool storage: public tools and the winter-wear vendor
obj(119, 49, "pegboard")
obj(121, 49, "pegboard")
table(119, 51, "steel", "toolbox")
table(120, 51, "steel", "toolbox_emerg")
table(121, 51, "steel", "toolbox_elec")
table(123, 51, "steel", "flashlight", "cable_coil", "gas_analyzer")
obj(124, 49, "vending", spr="vending_winter", comps={"vending": {"products": [["winter_coat", 6], ["beanie", 6], ["scarf", 6], ["winter_hood", 4]]}})
obj(123, 49, "vending", spr="vending_tool", comps={"vending": {"products": [["wrench", 3], ["crowbar", 3], ["flashlight", 5], ["cable_coil", 4]]}})
obj(124, 55, "locker", kind="eng", items=["flashlight", "extinguisher", "cable_coil", "gas_mask"])
# custodial closet
obj(113, 49, "sink")
obj(114, 52, "bucket")
obj(115, 52, "mop")
table(113, 54, "steel", "soap", "light_tube")
# tg janitor closet: signs, a spare bucket and cleaner, and the trash
obj(116, 49, "locker", kind="gen", name="janitorial supplies", items=["wet_floor_sign", "wet_floor_sign", "wet_floor_sign", "spray_bottle", "spray_bottle", "light_tube", "light_tube", "light_tube", "soap", "bucket"])
obj(116, 55, "trash_bin")

# ====================================================================== ATMOSPHERICS (south-east)
# MetaStation's Atmospherics, transcribed from the tg map by tg_atmos_import.py: the pump
# room and gas storage, the machine hall with its canister bays, the filter gallery, and
# the seven gas chambers out on the ice. Its pipes and devices go into the map as-is.
ATMOS = json.load(open(os.path.join(HERE, "atmos_metastation.json")))
atmos_pipework = {k: ATMOS[k] for k in ("pipes", "devices", "links", "exits")}


def import_block(block):
    ox, oy = block["origin"]
    bw, bh = block["size"]
    codes = {}
    for code, L in block["legend"].items():
        codes[code] = new_area(L["name"], L["kind"], L.get("floor"))
        if "gas" in L:
            areas[codes[code]]["gas"] = L["gas"]
    for yy in range(bh):
        for xx in range(bw):
            ch = block["tiles"][yy][xx]
            code = block["areas"][yy][xx]
            x, y = ox + xx, oy + yy
            if ch == " ":
                continue
            # the block's rim meets our station: it's wall there unless it's a door
            # (the top row is inside tg's pump room; our wall runs just above it)
            rim = xx == 0 or xx == bw - 1 or yy == bh - 1
            if rim and ch == "." and tile[y][x] == " ":
                ch = "%"
            if rim and ch == "+":
                ch = "%"
            tile[y][x] = ch
            if code.strip():
                area[y][x] = codes[code]
    # doors that led into parts of tg's map we didn't bring over are wall now
    for yy in range(bh):
        for xx in range(bw):
            x, y = ox + xx, oy + yy
            if tile[y][x] == "+":
                op = [tile[y + dy][x + dx] in ".+@" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if not ((op[0] and op[1]) or (op[2] and op[3])):
                    tile[y][x] = "%"
    return codes


# the Atmospherics Hall runs down to tg's west door
paint(atmos_hall, 88, 77, 90, 77)
atmos_codes = import_block(ATMOS)
atmos_main = next(c for c, L in areas.items() if L["name"] == "Atmospherics")


def atmos_viewing_gallery(block):
    """tg looks into its gas tanks across a strip of open space through one window each;
    that strip became solid wall here and hid the tanks. Open it into a gallery along the
    control room's south side and glaze the tanks' north walls, so one pane of reinforced
    glass is all there is between you and the gas."""
    ox, oy = block["origin"]
    bw, bh = block["size"]
    rows = block["tiles"]
    # the tanks' top wall is the row above their first floor row
    tank_codes = {c for c, L in block["legend"].items() if L["kind"] == "gas_chamber"}
    top = next(yy for yy in range(bh) if any(block["areas"][yy][xx] in tank_codes and rows[yy][xx] == "."
                                             for xx in range(bw))) - 1
    for xx in range(bw):
        x = ox + xx
        below = rows[top + 1][xx]
        if rows[top][xx] == " ":
            continue
        # glaze every stretch of top wall that has tank floor behind it
        if below == ".":
            tile[oy + top][x] = "W"
        # the old window row and the gap become gallery floor over the whole run of tanks
        for yy in (top - 2, top - 1):
            if tile[oy + yy][x] in ("W", " ", "%", "#") and rows[top][xx] != " " and rows[top - 2][xx] == "W":
                tile[oy + yy][x] = "."
                area[oy + yy][x] = atmos_main
    # close the gallery's ends
    for yy in (top - 2, top - 1):
        for xx in range(bw):
            x = ox + xx
            if tile[oy + yy][x] == "." and area[oy + yy][x] == atmos_main:
                for dx in (-1, 1):
                    if tile[oy + yy][x + dx] == " ":
                        tile[oy + yy][x + dx] = "%"


atmos_viewing_gallery(ATMOS)
# tg reached gas storage and the pump room from its front desk; ours open onto the South Hall
door(89, 60, next(c for c, L in areas.items() if L["name"] == "Atmospherics Gas Storage"))
door(103, 60, next(c for c, L in areas.items() if L["name"] == "Atmospherics Pump Room"))
for t in ATMOS["things"]:
    x, y, p = t["x"], t["y"], t["proto"]
    if tile[y][x] != ".":
        continue  # on the rim, now wall (tg's front desk faced a room we didn't bring)
    if p == "table":
        table(x, y, "steel")
    elif p.startswith("canister_"):
        obj(x, y, p)
    elif p == "console":
        if t.get("console") == "tank":
            obj(x, y, "console", spr="console_atmos", comps={"console": {"kind": "tank", "tank": t.get("tank", "")}})
        else:
            obj(x, y, "console", spr="console_atmos", comps={"console": {"kind": "atmos"}})
    elif p == "locker_atmos":
        obj(x, y, "locker", kind="eng", items=["gas_mask", "tank_air", "gas_analyzer", "wrench", "extinguisher"])
    elif p == "pipe_dispenser":
        obj(x, y, "pipe_dispenser")
    elif p in ("portable_pump", "portable_scrubber"):
        obj(x, y, p)

# ====================================================================== dressing
# Signs, posters, office furniture and rugs, per department (in each one's own coordinates).
origin(2, 10)   # security
obj(8, 21, "sign_sec")
obj(23, 21, "sign_sec")
obj(7, 11, "poster_2")
obj(16, 13, "filing_cabinet")
obj(11, 15, "desk_computer")
obj(14, 3, "desk_lamp")
for x in range(11, 16):
    for y in range(5, 8):
        obj(x, y, "decal", spr="rug_red")
origin(12, 0)   # command
obj(48, 21, "sign_cmd")
obj(51, 21, "sign_cmd")
obj(37, 3, "desk_lamp")
for x in range(35, 39):
    for y in range(5, 8):
        obj(x, y, "decal", spr="rug_blue")
obj(60, 13, "filing_cabinet")
obj(63, 17, "desk_computer")
obj(58, 10, "water_cooler")
obj(41, 10, "coffee_machine")
for x in range(46, 54):
    for y in range(7, 11):
        obj(x, y, "decal", spr="rug_blue")
origin(20, 6)   # quarters
for x in range(84, 95):
    for y in range(15, 19):
        obj(x, y, "decal", spr="rug_brown")
obj(91, 13, "poster_4")
for i, x0 in enumerate((71, 78, 85, 92)):
    for x in range(x0 + 1, x0 + 5):
        for y in (3, 4):
            obj(x, y, "decal", spr="rug_red" if i % 2 == 0 else "rug_green")
origin(12, 10)  # science
obj(8, 25, "sign_sci")
obj(6, 25, "poster_1")
for x in range(19, 26):
    for y in range(28, 31):
        obj(x, y, "decal", spr="rug_blue")
obj(23, 27, "desk_computer")
obj(28, 25, "filing_cabinet")
origin(12, 10)  # service
obj(60, 25, "sign_bar")
obj(44, 25, "sign_srv")
obj(47, 25, "poster_0")
obj(57, 25, "poster_3")
obj(36, 25, "coffee_machine")
obj(44, 40, "poster_5")
for x in range(59, 65):
    for y in range(28, 35):
        obj(x, y, "decal", spr="rug_red")
origin(12, 10)  # medbay
obj(74, 21, "sign_med")
obj(77, 21, "sign_med")
obj(91, 25, "poster_1")
obj(79, 25, "water_cooler")
for x in range(83, 89):
    for y in range(41, 45):
        obj(x, y, "decal", spr="rug_blue")
obj(88, 45, "filing_cabinet")
origin(6, 14)   # cargo
obj(9, 51, "sign_cargo")
obj(27, 51, "filing_cabinet")
obj(25, 53, "desk_computer")
for x in range(23, 28):
    for y in (55, 56):
        obj(x, y, "decal", spr="rug_brown")
origin(12, 18)  # engineering
obj(41, 51, "sign_eng")
obj(44, 51, "poster_2")
obj(38, 60, "sign_danger")
obj(59, 53, "desk_lamp")
obj(54, 51, "filing_cabinet")
for x in range(56, 62):
    for y in range(54, 57):
        obj(x, y, "decal", spr="rug_brown")
origin(0, 0)
# the halls: signs where the corridors branch off, and posters on the long walls
obj(19, 31, "poster_3")
obj(30, 31, "poster_5")
obj(98, 27, "poster_4")
obj(12, 61, "poster_1")
obj(50, 65, "poster_2")
obj(66, 65, "sign_eng")

# ====================================================================== maintenance tunnels
origin(0, 0)
# Security's maintenance runs down to the North Hall
paint(fp_maint, 32, 13, 32, 29)
door(32, 30, fp_maint)
# Science's aft maintenance drops to the Cargo Hall
paint(p_maint, 34, 57, 34, 60)
# Cargo's maintenance cuts through to the West Hall
paint(ap_maint, 36, 67, 36, 74)
paint(ap_maint, 37, 74, 40, 74)
door(41, 74, ap_maint)

# The maintenance network: narrow plating tunnels through the wall space between wings,
# with maintenance-access doors, junk, canisters and the odd generator (tg's maints).
c_maint = room("Central Maintenance", "maint_storage", 46, 61, 83, 62, floor="plating")
door(45, 62, c_maint)   # to the West Hall
door(84, 61, c_maint)   # to the Atmospherics Hall
door(60, 60, c_maint)   # up to the South Hall
paint(c_maint, 70, 63, 70, 63)
door(70, 64, c_maint)   # down to the Engineering Hall
obj(47, 61, "crate", kind="gen", items=["cable_coil", "light_tube", "glowstick"])
obj(52, 62, "canister_air")
obj(58, 61, "debris")
obj(66, 62, "trash_bin")
obj(75, 61, "crate", kind="eng", items=["sheet_metal", "wrench"])
obj(82, 62, "generator")
obj(63, 62, "decal", spr="puddle_oil")
aft_maint = room("Aft Maintenance", "maint_storage", 79, 69, 81, 86, floor="plating")
door(80, 68, aft_maint)  # up to the Engineering Hall
door(78, 82, aft_maint)  # into Engineering's power storage
obj(79, 72, "crate", kind="eng", items=["cable_coil", "cable_coil", "sheet_glass"])
obj(81, 79, "fuel_tank")
obj(81, 85, "canister_air")
obj(79, 85, "debris")
bow_maint = room("Bow Maintenance", "maint_storage", 34, 17, 36, 29, floor="plating")
door(36, 30, bow_maint)  # to the North Hall
door(37, 20, bow_maint)  # to the North Airlock Hall
obj(34, 17, "crate", kind="gen", items=["drink_soda", "paper", "glowstick"])
obj(35, 23, "canister_air")
obj(34, 27, "debris")
stb_maint = room("Starboard Bow Maintenance", "maint_storage", 83, 1, 85, 25, floor="plating")
door(86, 16, stb_maint)  # to the Quarters Hall
door(84, 26, stb_maint)  # down to the Departures Hall
obj(84, 2, "crate", kind="gen", items=["beanie", "scarf", "food_ration"])
obj(83, 12, "trash_bin")
obj(85, 20, "canister_air")
obj(84, 7, "debris")

# wall alcoves for the long north-south corridors (somewhere to hang their APC, air
# alarm and lights: wall fixtures go on a north wall)
for x, y, code in ((41, 45, west), (41, 66, west), (84, 70, atmos_hall), (90, 18, quarters_hall), (37, 22, north_lock_hall)):
    floor_cell(x, y, code)

# ====================================================================== hall dressing
for (x, y) in ((4, 31), (45, 33), (77, 31), (46, 21), (77, 21), (45, 59), (116, 57), (4, 63), (84, 65)):
    obj(x, y, "potted_plant", spr="potted_plant_%d" % ((x + y) % 2))
# lounge seating under the quarters' windows, facing the departures dock
for x in range(107, 121):
    if x != 109:
        chair(x, 27, "s", "shuttle")
stripes(118, 27, 121, 29)

# ====================================================================== external airlocks
exit_airlock("West Airlock", 0, 32, -1, 0)
exit_airlock("Departures Airlock", 124, 28, 1, 0)
exit_airlock("Mining Airlock", 0, 62, -1, 0)
# tg's cargo shuttle dock: the supply crawler parks outside the Cargo Bay's west wall
exit_airlock("Cargo Airlock", 4, 70, -1, 0)
for _y in (69, 71):
    tile[_y][4] = "%"
exit_airlock("Southeast Airlock", 121, 58, 1, 0)
exit_airlock("North Airlock", 39, 11, 0, -1)
exit_airlock("Engineering Airlock", 86, 83, 0, 1)

# ====================================================================== walls and hull
# Every empty cell touching the floor plan becomes wall; walls that touch the outside
# are hull. Pockets of empty space sealed inside the station are filled in with wall;
# notches open to the outside stay as snow, which gives the station its outline.
def _is_open(x, y):
    return 0 <= x < W and 0 <= y < H and tile[y][x] in ".+@=W"


for y in range(H):
    for x in range(W):
        if tile[y][x] == " " and any(_is_open(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            tile[y][x] = "#"
# outside = empty cells reachable from the edge of the grid
outside = set()
stack = [(x, y) for x in range(W) for y in (0, H - 1)] + [(x, y) for y in range(H) for x in (0, W - 1)]
while stack:
    x, y = stack.pop()
    if not (0 <= x < W and 0 <= y < H) or (x, y) in outside or tile[y][x] != " ":
        continue
    outside.add((x, y))
    stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
for y in range(H):
    for x in range(W):
        if tile[y][x] == " " and (x, y) not in outside:
            tile[y][x] = "#"


def _touches_outside(x, y):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            qx, qy = x + dx, y + dy
            if not (0 <= qx < W and 0 <= qy < H) or (qx, qy) in outside:
                return True
    return False


for y in range(H):
    for x in range(W):
        if tile[y][x] == "#" and _touches_outside(x, y):
            tile[y][x] = "%"


WALL_MOUNTED = ("sign_", "poster_")


def check():
    problems = []
    for o in objects:
        x, y = o["x"], o["y"]
        if tile[y][x] not in ".":
            problems.append("object %s at %d,%d is on '%s'" % (o["p"], x, y, tile[y][x]))
        elif o["p"].startswith(WALL_MOUNTED) and tile[y - 1][x] not in "#%":
            problems.append("%s at %d,%d has no wall above it" % (o["p"], x, y))
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if tile[y][x] == "+":
                open_ = [tile[y + dy][x + dx] in ".+@" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if not ((open_[0] and open_[1]) or (open_[2] and open_[3])):
                    problems.append("door at %d,%d doesn't join two floors" % (x, y))
    return problems


def write():
    data = {"w": W, "h": H, "tiles": ["".join(r) for r in tile], "areas": ["".join(c if c else " " for c in r) for r in area],
            "legend": areas, "objects": objects, "exits": exits, "atmos": atmos_pipework}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, indent=0)


def preview(path):
    from PIL import Image, ImageDraw
    S = 8
    im = Image.new("RGB", (W * S, H * S), (20, 24, 30))
    dr = ImageDraw.Draw(im)
    import colorsys
    for y in range(H):
        for x in range(W):
            t = tile[y][x]
            c = {"#": (70, 76, 88), "%": (40, 44, 52), "=": (120, 180, 220), "W": (90, 150, 200), "+": (230, 190, 60), "@": (230, 110, 60)}.get(t)
            if c is None and t == ".":
                code = area[y][x]
                h = (hash(areas[code]["name"]) % 360) / 360.0
                r, g, b = colorsys.hsv_to_rgb(h, 0.35, 0.75 if not areas[code].get("hall") else 0.45)
                c = (int(r * 255), int(g * 255), int(b * 255))
            dr.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=c or (0, 0, 0))
    for o in objects:
        if o["p"] == "decal":
            continue
        x, y = o["x"], o["y"]
        dr.rectangle([x * S + 2, y * S + 2, x * S + S - 3, y * S + S - 3], fill=(20, 20, 20))
    im.save(path)


if __name__ == "__main__":
    probs = check()
    for p in probs:
        print("WARNING", p)
    write()
    print("wrote %s: %d areas, %d objects, %d exits" % (OUT, len(areas), len(objects), len(exits)))
    if "--preview" in sys.argv:
        preview(os.path.join(HERE, "station_preview.png"))
