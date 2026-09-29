"""Transcribe a /tg/station map's Atmospherics into Artic-9 layout data.

    python3 tg_atmos_import.py <tg checkout> [out.json]

Reads MetaStation's .dmm (TGM format), cuts out the Atmospherics block, and resolves every
pipe connection the way tg does when the round starts:
  - smart pipes try all four sides; bridge pipes, layer adaptors and colour adapters only
    their axis; devices only their node sides (binary: back/front, trinary: back, clockwise
    side, front, with "flipped" swapping back and front; unary: facing)
  - two things connect when each opens toward the other, they're on the same piping layer
    (a layer adaptor reaches every layer) and share a colour (grey/omni joins any colour)
  - each side takes the first match in the neighbouring tile's contents
The result is written in station coordinates for tools/mapgen/station.py:
tiles and areas, doors, furniture, the atmos devices with their ports and settings, and the
pipes as per-tile masks on our pipe layers, with tg's colours and hidden/visible.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "..", "tg")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "atmos_metastation.json")
DMM = os.path.join(TG, "_maps", "map_files", "MetaStation", "MetaStation.dmm")

# tg region (inclusive) and where its top-left lands on our station grid
TX0, TY0, TX1, TY1 = 155, 126, 193, 153
OX, OY = 88, 61

N, S, E, W = 1, 2, 4, 8
DV = {N: (0, -1), S: (0, 1), E: (1, 0), W: (-1, 0)}
REV = {N: S, S: N, E: W, W: E}
CW = {N: E, E: S, S: W, W: N}  # BYOND turn(dir, -90)
BIT = {N: 1, E: 2, S: 4, W: 8}  # our NESW mask bits (Defs.DIRS4 order)
# tg piping layer -> our pipe layer (StationMap.PL_*)
LAYER = {1: 5, 2: 1, 3: 4, 4: 0, 5: 5}
PL_SUPPLY, PL_SCRUB = 0, 1

OMNI = "general"
COLORS = {  # tg helper colour -> the tint we draw it with
    "general": "#c8ccd4", "cyan": "#3ad0d8", "green": "#4ad86a", "orange": "#e8a03a",
    "purple": "#a050d8", "dark": "#5a5f6a", "brown": "#b09060", "violet": "#7a50d0",
    "pink": "#e8a0c0", "yellow": "#e8d84a", "red": "#d84a3a", "blue": "#3a7ad8",
    "scrubbers": "#d84a3a", "supply": "#3a7ad8",
}
GASES = {"n2": "n2", "o2": "o2", "co2": "co2", "plasma": "plasma", "n2o": "n2o", "air": "air",
         "vacuum": "", "nitrogen": "n2", "oxygen": "o2", "carbon_dioxide": "co2",
         "nitrous_oxide": "n2o", "water_vapor": "h2o"}


def load(path):
    txt = open(path).read()
    keys = {}
    for m in re.finditer(r'^"(\w+)" = \((.*?)\)\n(?="|\n)', txt, re.S | re.M):
        parts = re.split(r',\n(?=/)', m.group(2).strip())
        keys[m.group(1)] = [p.strip() for p in parts]
    grid = {}
    for m in re.finditer(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', txt, re.S | re.M):
        x, y0 = int(m.group(1)), int(m.group(2))
        for k, key in enumerate(m.group(4).split("\n")):
            grid[(x, y0 + k)] = key
    return keys, grid


def tvars(o):
    return {k: v.strip().strip('"') for k, v in re.findall(r"(\w+) = ([^;\n]+)", o)}


class Obj:
    def __init__(self, x, y, path, v, order):
        self.x, self.y, self.path, self.v, self.order = x, y, path, v, order
        self.dir = int(v.get("dir", 2))
        m = re.search(r"/layer(\d)", path)
        self.layer = int(v.get("piping_layer", m.group(1) if m else 3))
        self.color = OMNI
        for c in COLORS:
            if re.search(r"/%s(/|$)" % c, path) and "/components/" not in path:
                self.color = c
        self.all_layers = "/layer_manifold" in path
        self.all_colors = "/color_adapter" in path
        self.kind, self.nodes = self._nodes()
        self.links = {}  # dir -> Obj

    def _axis(self):
        return [N, S] if self.dir in (N, S) else [E, W]

    def _nodes(self):
        p = self.path
        if "/pipe/smart/" in p:
            return "pipe", [N, S, E, W]
        if "/pipe/bridge_pipe" in p or "/pipe/color_adapter" in p:
            return "pipe", self._axis()
        if "/pipe/layer_manifold" in p:
            return "link", self._axis()
        if "/pipe/" in p:
            return "pipe", [N, S, E, W]
        if "/components/binary/" in p:
            return "binary", [REV[self.dir], self.dir]
        if "/components/trinary/" in p:
            n1, n2, n3 = REV[self.dir], CW[self.dir], self.dir
            if "flipped" in p:
                n1, n3 = REV[n1], REV[n3]
            return "trinary", [n1, n2, n3]
        if "/components/unary/" in p or "/components/tank" in p:
            return "unary", [self.dir]
        if "/meter" in p:
            return "meter", []
        return "other", []

    def connectable(self, other, d):
        """tg connection_check + is_connectable, from self toward other along d."""
        if other.kind in ("meter", "other") or (other.x, other.y) == (self.x, self.y):
            return False
        if d not in self.nodes or REV[d] not in other.nodes:
            return False
        if not (self.all_layers or other.all_layers) and self.layer != other.layer:
            return False
        if self.color != other.color and OMNI not in (self.color, other.color) and not (self.all_colors or other.all_colors):
            return False
        return True


def main():
    keys, grid = load(DMM)
    objs = {}  # (x, y) -> [Obj], the whole station's pipework (to trace lines beyond the block)
    turfs, areas, others = {}, {}, {}
    order = 0
    for (x, y), key in grid.items():
        near = TX0 - 1 <= x <= TX1 + 1 and TY0 - 1 <= y <= TY1 + 1
        for o in keys[key]:
            path = o.split("{")[0]
            order += 1
            if path.startswith("/obj/machinery/atmospherics/") or path.startswith("/obj/machinery/meter"):
                objs.setdefault((x, y), []).append(Obj(x, y, path, tvars(o), order))
            elif not near:
                continue
            elif path.startswith("/turf/"):
                turfs[(x, y)] = path
            elif path.startswith("/area/"):
                areas[(x, y)] = path
            else:
                others.setdefault((x, y), []).append((path, tvars(o)))
    # resolve nodes: each side takes the first connectable thing in the next tile
    for (x, y), lst in objs.items():
        for a in lst:
            for d in a.nodes:
                dx, dy = DV[d]
                for b in objs.get((x + dx, y + dy), []):
                    if a.connectable(b, d):
                        a.links[d] = b
                        break
    # tg pipelines also expand one-way links, so a link either side counts
    for (x, y), lst in objs.items():
        for a in lst:
            for d, b in list(a.links.items()):
                b.links.setdefault(REV[d], a)
    # tg pipelines: pipes (and layer adaptors) joined up; devices are their boundaries
    line = {}
    for lst in objs.values():
        for a in lst:
            if a.kind not in ("pipe", "link") or a in line:
                continue
            lid = len(set(line.values()))
            stack = [a]
            line[a] = lid
            while stack:
                cur = stack.pop()
                for b in cur.links.values():
                    if b.kind in ("pipe", "link") and b not in line:
                        line[b] = lid
                        stack.append(b)
    # the station distro is the line feeding the most vents, the waste loop the one fed by
    # the most scrubbers
    import collections
    vents, scrubs = collections.Counter(), collections.Counter()
    for lst in objs.values():
        for a in lst:
            if a.kind == "unary" and a.links:
                b = next(iter(a.links.values()))
                if b in line:
                    if "/vent_pump" in a.path and "siphon" not in a.path:
                        vents[line[b]] += 1
                    elif "/vent_scrubber" in a.path:
                        scrubs[line[b]] += 1
    distro = vents.most_common(1)[0][0] if vents else -1
    waste = scrubs.most_common(1)[0][0] if scrubs else -1
    print("distro line feeds %d vents, waste line takes %d scrubbers" % (vents[distro], scrubs[waste]))

    # only Atmospherics proper (and its chambers); walls count if they border it
    keep_area = lambda a: a.startswith("/area/station/engineering/atmos") and "atmospherics_engine" not in a
    floor_in = {(x, y) for (x, y), a in areas.items() if TX0 <= x <= TX1 and TY0 <= y <= TY1
                and (keep_area(a) or "/engine/" in turfs.get((x, y), "")) and "/closed/" not in turfs.get((x, y), "")
                and "/open/space" not in turfs.get((x, y), "")}
    included = set(floor_in)
    for (x, y) in floor_in:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if TX0 <= q[0] <= TX1 and TY0 <= q[1] <= TY1 and "/closed/" in turfs.get(q, ""):
                    included.add(q)
                ps = [pp for pp, _ in others.get(q, [])]
                if TX0 <= q[0] <= TX1 and TY0 <= q[1] <= TY1 and any("spawner/structure/window" in pp or "/door/airlock" in pp for pp in ps):
                    included.add(q)
    # pipe runs crossing open space (the chamber feeds) come along too, laid on the ice
    for (x, y), lst in objs.items():
        if TX0 <= x <= TX1 and TY0 <= y <= TY1 and "/open/space" in turfs.get((x, y), "") and "atmospherics_engine" not in areas.get((x, y), ""):
            included.add((x, y))
    inside = lambda x, y: (x, y) in included
    to_st = lambda x, y: (x - TX0 + OX, y - TY0 + OY)

    # ---------------------------------------------------------------- pipes per tile
    pipes = {}  # (layer, sx, sy) -> {"groups": [[mask, ...objs]], "color", "shown"}
    links = []
    exits = []
    devices = []

    def add_group(layer, sx, sy, mask, color, shown):
        k = (layer, sx, sy)
        e = pipes.setdefault(k, {"groups": [], "color": None, "shown": False})
        # a new pipe sharing a side with one already here joins it (one tg pipeline)
        merged = [g for g in e["groups"] if g & mask]
        for g in merged:
            e["groups"].remove(g)
            mask |= g
        e["groups"].append(mask)
        if color and e["color"] is None:
            e["color"] = color
        e["shown"] = e["shown"] or shown

    def conn_mask(o, layer_filter=None):
        m = 0
        for d, b in o.links.items():
            if layer_filter is not None and LAYER[b.layer] != layer_filter:
                continue
            if not inside(b.x, b.y):
                continue
            m |= BIT[d]
        return m

    def tint(o):
        lay = LAYER[o.layer]
        default = (lay == PL_SUPPLY and o.color == "supply") or (lay == PL_SCRUB and o.color == "scrubbers")
        return None if default else COLORS[o.color]

    for (x, y), lst in sorted(objs.items()):
        if not inside(x, y):
            continue
        sx, sy = to_st(x, y)
        for o in lst:
            # pipes leaving the block: remember where, so the station's loops can join them
            for d, b in o.links.items():
                if not inside(b.x, b.y):
                    lid = line.get(o, line.get(b, -2))
                    loop = "distro" if lid == distro else ("waste" if lid == waste else "")
                    exits.append({"layer": LAYER[o.layer], "x": sx, "y": sy, "dir": BIT[d], "color": o.color, "loop": loop})
            if o.kind == "pipe":
                m = conn_mask(o)
                if m:
                    add_group(LAYER[o.layer], sx, sy, m, tint(o), "/hidden" not in o.path)
            elif o.kind == "link":
                # tg layer adaptor: joins only what runs along its own axis
                links.append([sx, sy, BIT[o.nodes[0]] | BIT[o.nodes[1]]])
                for lay in sorted(set(LAYER.values())):
                    m = conn_mask(o, lay)
                    if m:
                        add_group(lay, sx, sy, m, None, True)
            elif o.kind in ("binary", "trinary", "unary"):
                m = conn_mask(o)
                if m:
                    add_group(LAYER[o.layer], sx, sy, m, None, True)
                dev = device(o, sx, sy)
                if dev:
                    devices.append(dev)
            elif o.kind == "meter":
                devices.append({"proto": "meter", "x": sx, "y": sy, "layer": LAYER[o.layer], "name": o.v.get("name", "")})

    # ---------------------------------------------------------------- tiles, areas, things
    tiles, arow, legend = [], [], {}
    area_code = {}
    codes = iter("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    things = []
    doors = []
    for y in range(TY0, TY1 + 1):
        trow, crow = "", ""
        for x in range(TX0, TX1 + 1):
            t = turfs.get((x, y), "")
            a = areas.get((x, y), "")
            ps = [p for p, _ in others.get((x, y), [])]
            ch = " "
            if not inside(x, y):
                trow += " "
                crow += " "
                continue
            if "/closed/" in t:
                ch = "%" if ("r_wall" in t or "reinforced" in t) else "#"
            elif "/open/space" in t or t == "":
                ch = " "
            else:
                ch = "."
            # full-tile windows only: tg's thin directional panes and windoors sit on a tile
            # edge and leave the floor usable, so they stay floor here
            full = [p for p in ps if p.startswith("/obj/effect/spawner/structure/window") or
                    (p.startswith("/obj/structure/window") and "fulltile" in p)]
            if full:
                ch = "W" if any("reinforced" in p or "plasma" in p for p in full) else "="
            if any(p.startswith("/obj/machinery/door/airlock") for p in ps):
                ch = "+"
            code = " "
            if ch in ".+" or (ch in "=W" and a):
                aname, kind, floor, gas = area_for(a, t)
                if aname not in area_code:
                    area_code[aname] = next(codes)
                    legend[area_code[aname]] = {"name": aname, "kind": kind}
                    if floor:
                        legend[area_code[aname]]["floor"] = floor
                    if gas is not None:
                        legend[area_code[aname]]["gas"] = gas
                code = area_code[aname]
            trow += ch
            crow += code
            sx, sy = to_st(x, y)
            for p, v in (others.get((x, y), []) if (x, y) in floor_in else []):
                th = thing(p, v)
                if th:
                    th.update({"x": sx, "y": sy})
                    things.append(th)
        tiles.append(trow)
        arow.append(crow)

    out = {
        "source": "MetaStation Atmospherics (tg), transcribed by tg_atmos_import.py",
        "origin": [OX, OY], "size": [TX1 - TX0 + 1, TY1 - TY0 + 1],
        "tiles": tiles, "areas": arow, "legend": legend,
        "things": things, "devices": devices, "links": links, "exits": exits,
        "pipes": [{"layer": k[0], "x": k[1], "y": k[2], "groups": v["groups"], "color": v["color"], "shown": v["shown"]}
                  for k, v in sorted(pipes.items())],
    }
    json.dump(out, open(OUT, "w"), indent=0)
    print("wrote %s: %d pipe tiles, %d devices, %d things, %d exits, %d layer links" % (
        OUT, len(out["pipes"]), len(devices), len(things), len(exits), len(links)))


def area_for(a, t):
    """Our area for a tg tile: the main room, or one of the gas chambers."""
    if "/engine/" in t:
        g = t.split("/")[-1]
        gas = GASES.get(g, "")
        names = {"n2": "Nitrogen", "o2": "Oxygen", "co2": "Carbon Dioxide", "plasma": "Plasma",
                 "n2o": "Nitrous Oxide", "air": "Air Mix", "": "Gas Mix", "h2o": "Water Vapour"}
        return ("%s Chamber" % names.get(gas, "Gas"), "gas_chamber", "engine", gas)
    if "pumproom" in a:
        return ("Atmospherics Pump Room", "atmospherics", "dark", None)
    if "storage/gas" in a:
        return ("Atmospherics Gas Storage", "atmospherics", "dark", None)
    if "/atmos" in a:
        return ("Atmospherics", "atmospherics", "dark", None)
    return ("Atmospherics", "atmospherics", "dark", None)


def device(o, sx, sy):
    p, v = o.path, o.v
    lay = LAYER[o.layer]
    d = {"x": sx, "y": sy, "layer": lay, "dir": BIT[o.dir], "name": v.get("name", "")}
    on = "/on" in p or v.get("on") == "1"
    ports = {}
    if o.kind == "binary":
        ports = {"in": BIT[o.nodes[0]], "out": BIT[o.nodes[1]]}
    elif o.kind == "trinary":
        ports = {"in": BIT[o.nodes[0]], "side": BIT[o.nodes[1]], "out": BIT[o.nodes[2]]}
    d.update(ports)
    if "/binary/volume_pump" in p:
        d.update({"proto": "volume_pump", "kind": "vpump", "on": on, "rate": float(v.get("transfer_rate", 200))})
    elif "/binary/pump" in p:
        d.update({"proto": "pump", "kind": "pump", "on": on, "target": float(v.get("target_pressure", 101.325))})
    elif "/binary/valve" in p:
        d.update({"proto": "manual_valve", "kind": "valve", "on": on or v.get("on") == "1", "digital": "/digital" in p})
    elif "/binary/passive_gate" in p:
        d.update({"proto": "passive_gate", "kind": "gate", "on": on, "target": float(v.get("target_pressure", 101.325))})
    elif "/binary/pressure_valve" in p:
        d.update({"proto": "pressure_valve", "kind": "pvalve", "on": on, "target": float(v.get("target_pressure", 101.325))})
    elif "/binary/temperature_gate" in p:
        d.update({"proto": "passive_gate", "kind": "gate", "on": on, "target": 4500.0})
    elif "/binary/crystallizer" in p or "/binary/" in p:
        return None
    elif "/trinary/filter" in p:
        gas = ""
        m = re.search(r"/filter/atmos/(\w+)", p)
        if m and m.group(1) != "flipped":
            gas = {"n2": "n2", "o2": "o2", "co2": "co2", "n2o": "n2o", "plasma": "plasma"}.get(m.group(1), m.group(1))
        d.update({"proto": "gas_filter", "kind": "filter", "on": on or "/atmos" in p, "gas": gas})
    elif "/trinary/mixer" in p:
        air = "/airmix" in p
        inv = "/inverse" in p
        d.update({"proto": "gas_mixer", "kind": "mixer", "on": on or air,
                  "node1": (0.21 if inv else 0.79) if air else float(v.get("node1_concentration", 0.5)),
                  "target": 4500.0 if air else float(v.get("target_pressure", 101.325))})
    elif "/thermomachine/freezer" in p:
        d.update({"proto": "thermo_freezer", "on": on})
    elif "/thermomachine/heater" in p:
        d.update({"proto": "thermo_heater", "on": on})
    elif "/outlet_injector" in p:
        mon = "/monitored" in p
        m = re.search(r"/monitored/(\w+)_input", p)
        d.update({"proto": "gas_injector", "on": mon or on, "volume_rate": 200.0 if mon else 50.0,
                  "monitored": GASES.get(m.group(1), m.group(1)) if m else ""})
    elif "/vent_pump" in p and "siphon" in p:
        m = re.search(r"/monitored/(\w+)_output", p)
        d.update({"proto": "gas_siphon", "on": True, "volume_l": 1000.0 if "high_volume" in p else 200.0,
                  "monitored": GASES.get(m.group(1), m.group(1)) if m else ""})
    elif "/vent_pump" in p:
        d.update({"proto": "vent", "on": True})
    elif "/vent_scrubber" in p:
        d.update({"proto": "scrubber", "on": True})
    elif "/portables_connector" in p:
        d.update({"proto": "connector_port"})
    elif "/passive_vent" in p:
        d.update({"proto": "passive_vent"})
    elif "/components/tank" in p:
        g = p.split("/tank/")[-1].split("/")[0] if "/tank/" in p else ""
        d.update({"proto": "pipe_tank", "gas": GASES.get(g, g)})
    else:
        return None
    return d


def thing(p, v):
    """Furniture and fixtures worth carrying over, as our protos."""
    if p.startswith("/obj/structure/table"):
        return {"proto": "table"}
    if "/portable_atmospherics/canister" in p:
        g = p.split("/canister")[-1].strip("/").split("/")[0]
        return {"proto": "canister_" + GASES.get(g, g) if g else "canister_empty"}
    if "/portable_atmospherics/pump" in p:
        return {"proto": "portable_pump"}
    if "/portable_atmospherics/scrubber" in p or "/portable_atmospherics/pipe_scrubber" in p:
        return {"proto": "portable_scrubber"}
    if "/computer/atmos_control" in p:
        m = re.search(r"/atmos_control/(\w+)_tank", p)
        tank = {"nitrogen": "n2", "oxygen": "o2", "carbon": "co2", "plasma": "plasma", "nitrous": "n2o", "air": "air", "mix": "mix"}
        return {"proto": "console", "console": "tank" if m else "atmos", "tank": tank.get(m.group(1), m.group(1)) if m else "", "dir": int(v.get("dir", 2))}
    if "/computer/atmos_alert" in p:
        return {"proto": "console", "console": "atmos", "dir": int(v.get("dir", 2))}
    if "/closet/secure_closet/atmospherics" in p:
        return {"proto": "locker_atmos"}
    if "/pipedispenser" in p:
        return {"proto": "pipe_dispenser"}
    if "/space_heater" in p:
        return {"proto": "space_heater"}
    if p.startswith("/obj/structure/rack"):
        return {"proto": "rack"}
    return None


if __name__ == "__main__":
    main()
