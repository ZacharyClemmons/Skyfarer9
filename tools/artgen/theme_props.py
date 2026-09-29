"""Sky-themed furniture, galley, sick bay and wall fittings (see theme.py)."""
import math

import numpy as np

import theme as T
from theme import (BRASS, CANVAS, COPPER, IRON, IRON_D, LAMP, LEATHER, OAK, OAK_D, OAK_L, PINE, ROPE, TIMBER, H, R, E, P,
                   _sp, brass, cabinet, done, gauge, ground, iron, lamp_glass, obj, retone, rivet_line, round_brass,
                   rope_line, warm, wood)
from common import hexc, mix, ramp, rng_for, shade
from px import cyl_height, shade_mask, sphere_height

REDRAWN = T.REDRAWN


# ================================================================== icebox / larder
@obj("fridge")
def icebox():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 5, 26, 46)
    shade_mask(cv, R(cv, 5, 5, 26, 10, 0), "#c9c2ae", "paint", bevel=1.0)     # zinc lid
    cv.hline(6, 25, 5, hexc("#f2ecd8"))
    cv.hline(5, 26, 10, hexc("#7a7466"))
    wood(cv, 5, 11, 26, 45, "#a98352", True, 7, "ice", bevel=1.2)
    for (a, b) in ((12, 26), (29, 43)):
        fr = shade(H("#a98352"), -0.5)
        cv.rect(7, a, 24, a, fr); cv.rect(7, b, 24, b, fr)
        cv.vline(7, a, b, fr); cv.vline(24, a, b, fr)
    iron(cv, 5, 27, 26, 28, IRON, True, 4)
    for y in (16, 36):
        brass(cv, 21, y, 23, y + 4, 0)
    cv.px(22, 18, H("#3a2616"))
    ic = H("#cfe4ee")
    for (dx, dy) in ((0, 0), (-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)):
        cv.px(13 + dx, 19 + dy, ic)
    cv.hline(10, 16, 33, hexc("#efe3bd")); cv.hline(10, 14, 35, hexc("#efe3bd"))
    warm(sp, 12, 40, "#9ad4e8")
    return done(sp)


# ================================================================== market stalls (were vending machines)
STALL = {"snack": ("#b8472e", ["#e0b04a", "#c85a3a", "#9a6a3a", "#d8c8a0"]),
         "cocoa": ("#6a4a2e", ["#8a5a3a", "#e8d8b8", "#c8843a", "#6a3a22"]),
         "drink": ("#2f6a8a", ["#7ab0d0", "#b0302e", "#4a8a4a", "#e8d8a0"]),
         "med": ("#3f8a6a", ["#e8eef4", "#7ab0a0", "#b0302e", "#cfa84a"]),
         "tool": ("#c9922e", ["#8a93a3", "#b0302e", "#cfa84a", "#5a4a3a"]),
         "winter": ("#4a6a8c", ["#e8eef4", "#8ab0d0", "#c8843a", "#7a5a3a"])}


def stall(kind):
    col, goods = STALL[kind]
    sp = _sp(32, 48)
    cv = sp.cv
    rng = rng_for("stall" + kind)
    ground(cv, 4, 27, 46)
    for x in (5, 25):
        wood(cv, x, 6, x + 1, 45, "#6a4526", True, 9, "sp%d%s" % (x, kind), bevel=0.8)
    for y in range(14, 36):
        for x in range(7, 25):
            cv.px(x, y, H("#3a2618") if y % 2 else H("#33210f"))
    for row, y in enumerate((17, 25, 33)):
        cv.hline(7, 24, y + 1, H("#a07240"))
        cv.hline(7, 24, y + 2, H("#4a2e18"))
        x = 8
        while x < 22:
            w = rng.choice((2, 3, 3, 4))
            h = rng.choice((3, 4, 5))
            c = H(rng.choice(goods))
            cv.rect(x, y - h + 1, x + w - 1, y, c)
            cv.px(x, y - h + 1, shade(c, 0.35))
            cv.vline(x + w - 1, y - h + 2, y, shade(c, -0.35))
            x += w + 1
    cw = H(CANVAS)
    for x in range(3, 29):
        stripe = ((x - 3) // 3) % 2 == 0
        c = H(col) if stripe else cw
        for y in range(3, 11):
            t = (y - 3) / 8
            cv.px(x, y, shade(c, 0.18 - 0.5 * t))
        cv.px(x, 11, shade(c, -0.35))
        if x % 3 != 1:
            cv.px(x, 12, shade(c, -0.55))
    cv.hline(3, 28, 3, mix(cw, hexc("#ffffff"), 0.4))
    wood(cv, 2, 1, 29, 3, "#5b3a21", False, 3, "aw" + kind, bevel=0.8)
    shade_mask(cv, R(cv, 4, 36, 27, 38, 0), "#b48a54", "paint", bevel=0.8)
    wood(cv, 4, 39, 27, 45, "#7a5030", True, 6, "sc" + kind, bevel=1.0)
    cv.hline(4, 27, 36, mix(H("#b48a54"), hexc("#ffffff"), 0.35))
    round_brass(cv, 22, 36, 1.6)
    cv.rect(9, 40, 14, 43, H("#2a3a34")); cv.hline(10, 13, 41, hexc("#e8e0c8")); cv.hline(10, 12, 43, hexc("#e8e0c8"))
    lamp_glass(sp, 15, 13, 2, 2)
    return done(sp)


for _k in STALL:
    REDRAWN[f"vending_{_k}"] = (lambda k: (lambda: stall(k)))(_k)


# ================================================================== water cask / urn / stoves
@obj("water_cooler")
def water_cask():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 6, 25, 38)
    for x in (7, 23):
        wood(cv, x, 26, x + 2, 37, "#5b3a21", True, 9, "wc%d" % x, bevel=0.8)
    wood(cv, 7, 27, 25, 29, "#6f4a2b", False, 9, "wcb", bevel=0.8)
    m = E(cv, 16, 17, 11, 9)
    shade_mask(cv, m, "#9a6a3a", "paint", height=cyl_height(m, "h") * 1.2)
    for x in range(6, 27):
        if (x - 6) % 4 == 0:
            for y in range(9, 26):
                if m[y, x]:
                    cv.px(x, y, shade(H("#9a6a3a"), -0.35))
    for x in (9, 22):
        for y in range(7, 27):
            if m[y, x]:
                cv.px(x, y, H(IRON)); cv.px(x + 1, y, shade(H(IRON), 0.2))
    brass(cv, 14, 13, 18, 15, 0)
    cv.px(16, 14, H("#3a2616"))
    brass(cv, 22, 22, 25, 23, 0)
    cv.px(25, 24, H(BRASS)); cv.px(25, 25, shade(H(BRASS), -0.3))
    cv.rect(4, 22, 6, 25, H("#b8bcc8")); cv.px(4, 22, hexc("#ffffff"))
    warm(sp, 16, 9, "#ffd9a0")
    return done(sp)


@obj("coffee_machine")
def urn():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 7, 24, 38)
    wood(cv, 7, 28, 24, 37, "#4a3a34", True, 6, "urnb", bevel=1.0)
    iron(cv, 7, 28, 24, 29, IRON_D, True, 4)
    cv.rect(10, 31, 21, 34, H("#1d1510"))
    for x in range(10, 22):
        sp.g(x, 33, H("#ff9a3a" if x % 2 else "#ffcf5a"))
        sp.g(x, 32, H("#e8742a"))
    m = E(cv, 15.5, 17, 8, 10)
    shade_mask(cv, m, "#c99a3c", "metal", height=cyl_height(m, "v"))
    neck = R(cv, 12, 5, 19, 9, 0)
    shade_mask(cv, neck, "#b98a30", "metal", height=cyl_height(neck, "v"))
    lid = E(cv, 15.5, 5, 5, 2)
    shade_mask(cv, lid, "#e0b04a", "metal", height=sphere_height(lid))
    round_brass(cv, 15.5, 2.5, 1.5)
    brass(cv, 22, 20, 26, 22, 0)
    cv.px(26, 23, H("#3a2616"))
    cv.vline(6, 15, 19, H("#5b3a21")); cv.hline(6, 7, 15, H("#5b3a21")); cv.hline(6, 7, 19, H("#5b3a21"))
    rivet_line(cv, 10, 21, 24, BRASS, 3)
    gauge(sp, 15, 17, 2, -0.9)
    return done(sp)


def stove(on, chimney=True):
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    if chimney:
        shade_mask(cv, R(cv, 21, 1, 25, 10, 0), IRON, "metal", bevel=1.0)
        cv.hline(20, 26, 1, H("#7a7684"))
    cabinet(cv, 4, 8, 27, 29, 5, "#3e3a44", "metal", top="#5a5560", bevel=1.2)
    iron(cv, 4, 14, 27, 15, IRON_D, True, 4)
    dm = R(cv, 8, 17, 23, 26, 1)
    cv.a[dm] = H("#2a2530")
    cv.rect(8, 17, 23, 17, H(BRASS)); cv.rect(8, 26, 23, 26, shade(H(BRASS), -0.4))
    cv.vline(8, 17, 26, H(BRASS)); cv.vline(23, 17, 26, shade(H(BRASS), -0.4))
    for x in range(10, 22):
        for y in range(19, 25):
            if on:
                if (x + y) % 3:
                    sp.g(x, y, H("#ffb84a") if y > 20 else H("#ffd98a"))
            else:
                cv.px(x, y, H("#6a3a24"))
    if on:
        for x in range(10, 22):
            sp.g(x, 24, H("#ff7a2a"))
    cv.vline(15, 18, 25, H(IRON_D)); cv.vline(16, 18, 25, H(IRON_D))
    brass(cv, 12, 12, 15, 13, 0)
    round_brass(cv, 22, 11, 1.5)
    return done(sp)


REDRAWN["microwave"] = lambda: stove(False, False)
REDRAWN["microwave_on"] = lambda: stove(True, False)
REDRAWN["oven"] = lambda: stove(True, True)


# ================================================================== seating and tables (retoned to timber)
WOODS = ["#241610", "#3e2716", "#5b3a21", "#8a5b33", "#b98f5a", "#dcb67c"]
LEATHERS = ["#1e130e", "#3a2416", "#5e3a22", "#84522f", "#a86c3e", "#c9925a"]
DARKOAK = ["#1a100b", "#2e1c10", "#46291a", "#6a4126", "#8a5b33", "#a87a46"]
DRIFT = ["#3a2e22", "#5e4a36", "#8a7250", "#b39a70", "#d4bd92", "#efe0b8"]
BRASSY = ["#2a1e14", "#5a3e1e", "#8a6428", "#c99a3c", "#e8c66a", "#fff0b0"]
CANVASY = ["#5a4a30", "#8a7650", "#b8a578", "#d8cba0", "#efe4c0"]

RT = {}
for _d in "nesw":
    RT[f"chair_steel_{_d}"] = WOODS
    RT[f"chair_shuttle_{_d}"] = LEATHERS
    RT[f"chair_office_{_d}"] = LEATHERS
    RT[f"chair_comfy_{_d}"] = LEATHERS
RT["bench"] = WOODS
RT["bar_stool"] = WOODS
for _i in [None] + list(range(16)):
    _s = "" if _i is None else f"_{_i}"
    RT[f"table_steel{_s}"] = WOODS
    RT[f"table_reinforced{_s}"] = DARKOAK
    RT[f"table_glass{_s}"] = DRIFT
    RT[f"table_counter{_s}"] = WOODS
    RT[f"table_bar{_s}"] = DARKOAK
for _n in ("shower_curtain_closed", "shower_curtain_open", "curtain_closed", "curtain_open"):
    RT[_n] = CANVASY
for _n in ("vent", "vent_siphon", "vent_welded", "passive_vent", "scrubber"):
    RT[_n] = BRASSY


def apply_retones(pk):
    """Recolour selected sprites' materials in place (steel to timber, plastic to leather)."""
    for name, cv in pk.items:
        stops = T.RT_ALL.get(name)
        if stops is not None:
            retone(cv, stops)


# ================================================================== bunks, cots, sick bay
PATCH = ["#a84a3a", "#3a6a8a", "#c9922e", "#4a8a52", "#7a5a9a", "#d8cba0"]


def bunk(i):
    sp = _sp()
    cv = sp.cv
    ground(cv, 3, 28, 30)
    for lx in (4, 27):
        cv.rect(lx, 27, lx + 1, 29, H("#4a2e18"))
    cabinet(cv, 3, 3, 28, 28, 23, "#8a5b33", "paint", top="#a87a46", bevel=1.2)
    wood(cv, 3, 1, 28, 5, "#6f4a2b", False, 4, "bkh%d" % i, bevel=1.0)
    for x in (5, 26):
        cv.px(x, 3, H(BRASS))
    shade_mask(cv, R(cv, 5, 6, 26, 25, 1), CANVAS, "cloth", bevel=2)
    pil = R(cv, 8, 7, 23, 11, 2)
    pp = shade_mask(cv, pil, "#efe4c0", "cloth", height=sphere_height(pil))
    cv.hline(13, 18, 9, pp[1])
    base = PATCH[i % len(PATCH)]
    for py in range(13, 27, 4):
        for px_ in range(5, 26, 5):
            c = base if (px_ // 5 + py // 4) % 2 == 0 else PATCH[(i + 2 + px_ // 5) % len(PATCH)]
            bm = R(cv, px_, py, min(px_ + 4, 26), py + 3, 0)
            bp = shade_mask(cv, bm, c, "cloth", bevel=1.2)
            cv.hline(px_, min(px_ + 4, 26), py, bp[-1])
    for px_ in range(5, 27, 5):
        cv.vline(px_, 13, 26, H("#3a2616"))
    cv.hline(5, 26, 26, shade(H(base), -0.5))
    return done(sp)


for _i in range(6):
    REDRAWN[f"bed_{_i}"] = (lambda i: (lambda: bunk(i)))(_i)


@obj("med_bed")
def cot():
    sp = _sp()
    cv = sp.cv
    ground(cv, 3, 28, 30)
    for x in (4, 26):
        wood(cv, x, 3, x + 1, 29, "#6f4a2b", True, 9, "cot%d" % x, bevel=0.8)
    shade_mask(cv, R(cv, 6, 5, 25, 26, 1), "#cfc3a0", "cloth", bevel=2.2)
    pil = R(cv, 9, 6, 22, 10, 2)
    shade_mask(cv, pil, "#efe4c0", "cloth", height=sphere_height(pil))
    for y in range(12, 26, 3):
        cv.hline(7, 24, y, shade(H("#cfc3a0"), -0.22))
    shade_mask(cv, R(cv, 6, 17, 25, 26, 1), "#3f8a6a", "cloth", bevel=1.6)
    cv.rect(14, 19, 17, 24, H("#efe4c0")); cv.rect(12, 21, 19, 22, H("#efe4c0"))
    for y in (13, 24):
        cv.px(7, y, H(ROPE)); cv.px(24, y, H(ROPE))
    return done(sp)


@obj("op_table")
def surgeons_table():
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    for x in (6, 24):
        wood(cv, x, 22, x + 2, 29, "#4a2e18", True, 9, "opl%d" % x, bevel=0.8)
    cabinet(cv, 3, 6, 28, 26, 14, "#8a5b33", "paint", top="#b98f5a", bevel=1.0)
    shade_mask(cv, R(cv, 5, 8, 26, 18, 0), "#d8b47a", "paint", bevel=1.0)
    for y in (11, 14):
        cv.hline(5, 26, y, shade(H("#d8b47a"), -0.2))
    for x in (9, 22):
        cv.rect(x, 7, x + 2, 19, H(LEATHER))
        cv.vline(x, 7, 19, shade(H(LEATHER), 0.25))
        cv.rect(x, 12, x + 2, 13, H(BRASS))
    lamp_glass(sp, 15, 3, 2, 2)
    return done(sp)


@obj("sleeper")
def sick_berth():
    sp = _sp(64, 32)
    cv = sp.cv
    ground(cv, 3, 60, 30)
    for x in (4, 58):
        cv.rect(x, 26, x + 2, 29, H("#4a2e18"))
    cabinet(cv, 2, 8, 61, 28, 12, "#7a5030", "paint", top="#a07240", bevel=1.2)
    wood(cv, 2, 20, 61, 28, "#7a5030", False, 4, "sbf", bevel=1.0)
    shade_mask(cv, R(cv, 5, 9, 58, 18, 1), CANVAS, "cloth", bevel=2)
    pil = R(cv, 6, 10, 17, 16, 2)
    shade_mask(cv, pil, "#efe4c0", "cloth", height=sphere_height(pil))
    shade_mask(cv, R(cv, 20, 11, 58, 18, 1), "#3f8a6a", "cloth", bevel=1.6)
    for x in range(24, 58, 8):
        cv.vline(x, 11, 18, shade(H("#3f8a6a"), -0.35))
    for x in (8, 12, 16):
        cv.vline(x, 2, 8, H("#b89b62")); cv.px(x, 2, H(BRASS))
    for x in range(8, 17):
        cv.px(x, 3, H(CANVAS))
    lamp_glass(sp, 30, 3, 2, 3)
    iron(cv, 2, 24, 61, 25, IRON, True, 6)
    return done(sp)


def bell(powered, occupied, open_):
    sp = _sp()
    cv = sp.cv
    ground(cv, 5, 26, 30)
    x1 = 25 if not open_ else 21
    body = R(cv, 6, 3, x1, 28, 5)
    shade_mask(cv, body, "#b98a38", "metal", height=cyl_height(body, "v"))
    for y in (9, 22):
        cv.hline(6, x1, y, shade(H("#b98a38"), -0.45))
        for x in range(8, x1 - 1, 3):
            cv.px(x, y - 1, mix(H(BRASS), hexc("#ffffff"), 0.4))
    cx = 15.5 if not open_ else 13.5
    pm = E(cv, cx, 15.5, 5, 6)
    ring = E(cv, cx, 15.5, 6, 7)
    cv.a[ring] = H("#7a5a24")
    if open_:
        cv.a[pm] = H("#1d1510")
        wood(cv, 22, 6, 27, 27, "#6f4a2b", True, 6, "bell", bevel=0.8)
    else:
        cv.a[pm] = H("#3a5a6a") if powered else H("#1d3244")
        if occupied:
            cv.a[E(cv, 15.5, 16.5, 3, 4)] = H("#d8a070")
            cv.a[E(cv, 15.5, 13, 2, 2)] = H("#e8b888")
        if powered:
            for y, x in zip(*np.nonzero(pm)):
                sp.glow.px(int(x), int(y), hexc("#ffcf7a", 0.5))
            sp.has_glow = True
        cv.px(13, 12, hexc("#cfe8f4")); cv.px(14, 11, hexc("#ffffff"))
    cv.a[E(cv, 15.5, 3.5, 2, 1.5)] = H(COPPER)
    if powered and not open_:
        warm(sp, 23, 6, "#7aff8a")
    return done(sp)


for _n, (_p, _o, _op) in {"dna_scanner": (True, False, False), "dna_scanner_occupied": (True, True, False),
                          "dna_scanner_open": (True, False, True), "dna_scanner_open_unpowered": (False, False, True),
                          "dna_scanner_unpowered": (False, False, False)}.items():
    REDRAWN[_n] = (lambda p, o, op: (lambda: bell(p, o, op)))(_p, _o, _op)


# ================================================================== washing and stores
@obj("toilet")
def commode():
    sp = _sp()
    cv = sp.cv
    ground(cv, 8, 24, 30)
    cabinet(cv, 8, 8, 24, 29, 6, "#7a5030", "paint", top="#a07240", bevel=1.0)
    wood(cv, 8, 15, 24, 29, "#7a5030", True, 5, "commode", bevel=1.0)
    seat = E(cv, 16, 11.5, 6, 3.6)
    shade_mask(cv, seat, "#d8b47a", "paint", height=sphere_height(seat))
    cv.a[E(cv, 16, 11.5, 3.6, 1.8)] = H("#1d1510")
    iron(cv, 8, 20, 24, 21, IRON, True, 4)
    brass(cv, 14, 24, 18, 26, 0)
    shade_mask(cv, R(cv, 3, 21, 7, 29, 1), "#a89060", "paint", bevel=1.0)
    cv.hline(3, 7, 24, H(IRON)); cv.hline(3, 7, 27, H(IRON))
    return done(sp)


@obj("sink")
def washstand():
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    for x in (5, 25):
        wood(cv, x, 16, x + 2, 29, "#5b3a21", True, 9, "ws%d" % x, bevel=0.8)
    cabinet(cv, 4, 10, 27, 20, 4, "#8a5b33", "paint", top="#b98f5a", bevel=1.0)
    basin = E(cv, 15.5, 13, 9, 4)
    shade_mask(cv, basin, "#e8e2d0", "paint", height=sphere_height(basin))
    cv.a[E(cv, 15.5, 13.6, 6.5, 2.6)] = H("#7ab0c8")
    cv.hline(11, 17, 13, hexc("#cfe8f4"))
    brass(cv, 14, 6, 17, 8, 0); cv.vline(15, 8, 10, H(BRASS)); cv.px(15, 4, H(COPPER)); cv.px(16, 4, H(COPPER))
    cv.hline(13, 18, 5, shade(H(BRASS), 0.3))
    shade_mask(cv, R(cv, 22, 12, 25, 17, 1), "#8a7a5a", "paint", bevel=1.0)
    wood(cv, 6, 21, 25, 27, "#6f4a2b", True, 6, "wsd", bevel=0.8)
    brass(cv, 14, 23, 17, 24, 0)
    return done(sp)


@obj("shower")
def bucket_shower():
    sp = _sp()
    cv = sp.cv
    ground(cv, 8, 24, 30)
    for x in (7, 24):
        wood(cv, x, 3, x + 1, 30, "#5b3a21", True, 9, "sh%d" % x, bevel=0.8)
    cv.hline(7, 25, 4, H("#5b3a21"))
    m = E(cv, 16, 9, 6, 4)
    shade_mask(cv, m, "#9a6a3a", "paint", height=sphere_height(m))
    cv.hline(11, 21, 7, H(IRON)); cv.hline(11, 21, 11, H(IRON))
    brass(cv, 14, 13, 17, 14, 0)
    cv.vline(15, 15, 16, H(BRASS))
    for y in range(17, 27, 2):
        cv.px(15 + (y // 2) % 2, y, hexc("#bfe4ee", 0.7))
    cv.rect(11, 27, 20, 29, H("#7a5030")); cv.hline(11, 20, 27, H("#a07240"))
    for y in range(4, 9):
        cv.px(24, y, H(ROPE))
    return done(sp)


@obj("filing_cabinet")
def chest_of_drawers():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 6, 25, 38)
    cabinet(cv, 6, 4, 25, 38, 5, "#8a5b33", "paint", top="#b98f5a", bevel=1.2)
    for y in (10, 19, 28):
        fr = shade(H("#8a5b33"), -0.5)
        cv.rect(8, y, 23, y + 7, fr)
        pal = shade_mask(cv, R(cv, 9, y + 1, 22, y + 6, 0), "#96663a", "paint", bevel=1.0)
        brass(cv, 14, y + 3, 17, y + 4, 0)
        cv.hline(9, 22, y + 1, pal[-1])
    cv.rect(7, 37, 24, 38, H("#3a2616"))
    return done(sp)


@obj("med_cabinet")
def apothecary():
    sp = _sp()
    cv = sp.cv
    wood(cv, 6, 3, 25, 28, "#8a5b33", True, 6, "apo", bevel=1.2)
    shade_mask(cv, R(cv, 8, 5, 23, 26, 0), "#5b3a21", "paint", bevel=1.0)
    for y in (12, 19):
        cv.hline(9, 22, y, H("#a07240")); cv.hline(9, 22, y + 1, H("#2a1810"))
    rng = rng_for("apo")
    for y in (12, 19, 26):
        x = 9
        while x < 21:
            w = rng.choice((2, 3)); h = rng.choice((3, 4, 5))
            c = H(rng.choice(["#5a9a7a", "#b0602e", "#d8cba0", "#4a6a9a", "#a8823e"]))
            if y - h > 5:
                cv.rect(x, y - h, x + w - 1, y - 1, c)
                cv.px(x, y - h, shade(c, 0.4)); cv.px(x, y - h - 1, H("#d8c8a0"))
            x += w + 1
    cv.hline(6, 25, 3, H("#b98f5a"))
    cv.rect(14, 1, 17, 3, H("#efe3bd")); cv.px(15, 2, H("#3f8a6a")); cv.px(16, 2, H("#3f8a6a"))
    brass(cv, 23, 15, 24, 18, 0)
    return done(sp)


def fire_bucket(empty):
    sp = _sp()
    cv = sp.cv
    wood(cv, 7, 2, 24, 29, "#6f4a2b", True, 6, "fb", bevel=1.0)
    shade_mask(cv, R(cv, 9, 4, 22, 27, 0), "#3a2616", "paint", bevel=1.0)
    if not empty:
        m = R(cv, 11, 11, 20, 24, 1)
        shade_mask(cv, m, "#b8342a", "paint", height=cyl_height(m, "v"))
        cv.hline(11, 20, 11, H(IRON)); cv.hline(11, 20, 24, H(IRON))
        cv.hline(11, 20, 15, H("#efe3bd"))
        cv.px(11, 8, H(IRON)); cv.px(20, 8, H(IRON)); cv.hline(12, 19, 7, H(IRON))
    else:
        cv.rect(11, 8, 20, 9, H(IRON))
        cv.rect(12, 10, 13, 12, H("#a07240"))
    brass(cv, 22, 14, 24, 17, 0)
    cv.rect(13, 1, 18, 2, H("#efe3bd")); cv.px(15, 1, H("#b8342a")); cv.px(16, 1, H("#b8342a"))
    return done(sp)


REDRAWN["extinguisher_cabinet"] = lambda: fire_bucket(False)
REDRAWN["extinguisher_cabinet_empty"] = lambda: fire_bucket(True)


@obj("trash_bin")
def basket():
    sp = _sp()
    cv = sp.cv
    ground(cv, 8, 24, 30)
    m = R(cv, 8, 12, 24, 29, 2)
    shade_mask(cv, m, "#a8814a", "paint", height=cyl_height(m, "v"))
    for y in range(14, 29, 3):
        for x in range(8, 25):
            if (x + y // 3) % 2 == 0:
                cv.px(x, y, shade(cv.get(x, y), -0.32))
    rim = E(cv, 16, 12, 9, 3)
    shade_mask(cv, rim, "#c9a468", "paint", height=sphere_height(rim))
    cv.a[E(cv, 16, 12.5, 7, 2)] = H("#2a1a10")
    rope_line(cv, 8, 13, 24, 13, ROPE)
    return done(sp)


@obj("wall_clock")
def ships_clock():
    sp = _sp()
    cv = sp.cv
    cx, cy = 15.5, 15.5
    round_brass(cv, cx, cy, 9.5, BRASS)
    cv.a[E(cv, cx, cy, 7.4, 7.4)] = H("#efe3bd")
    for k in range(12):
        a = k * math.tau / 12
        cv.px(int(round(cx + math.cos(a) * 6.2)), int(round(cy + math.sin(a) * 6.2)), H("#3a2616"))
    cv.line(15, 15, 15, 10, H("#2a1a10")); cv.line(15, 15, 19, 17, H("#2a1a10"))
    cv.px(15, 15, H("#b0302e"))
    for x, y in ((9, 8), (22, 8)):
        cv.px(x, y, mix(H(BRASS), hexc("#ffffff"), 0.5))
    return done(sp)


@obj("mirror")
def brass_mirror():
    sp = _sp()
    cv = sp.cv
    m = E(cv, 15.5, 15.5, 8, 11)
    shade_mask(cv, m, BRASS, "metal", height=sphere_height(m) * 0.25 + 0.3)
    g = E(cv, 15.5, 15.5, 6, 9)
    cv.a[g] = H("#8ab0be")
    for y, x in zip(*np.nonzero(g)):
        if (x - y) % 7 in (0, 1):
            cv.px(int(x), int(y), H("#dff0f6"))
    cv.px(11, 9, hexc("#ffffff"))
    return done(sp)


@obj("status_display")
def slate():
    sp = _sp()
    cv = sp.cv
    wood(cv, 2, 8, 29, 23, "#6f4a2b", False, 4, "slate", bevel=1.2)
    cv.rect(4, 10, 27, 21, H("#232a26"))
    cv.hline(4, 27, 10, H("#0e1210"))
    for y, ln in ((12, 14), (15, 18), (18, 9)):
        for x in range(6, 6 + ln):
            if (x + y) % 5 != 0:
                sp.g(x, y, H("#dcd8c0"))
    cv.px(24, 13, hexc("#ffcf7a")); cv.px(25, 13, hexc("#ffcf7a"))
    return done(sp)


@obj("apc")
def fuse_box():
    sp = _sp()
    cv = sp.cv
    wood(cv, 4, 3, 27, 28, "#6f4a2b", True, 6, "apcw", bevel=1.2)
    brass(cv, 7, 6, 24, 25, 1, "#b98a38")
    cv.rect(9, 8, 22, 14, H("#1d1510"))
    for k, x in enumerate((11, 15, 19)):
        cv.vline(x, 9, 13, H("#8a6a3a"))
        cv.rect(x - 1, 9 + (k % 2) * 3, x + 1, 10 + (k % 2) * 3, H("#c8c0a8"))
    gauge(sp, 16, 20, 2, -0.6)
    for x in (8, 23):
        for y in (7, 24):
            cv.px(x, y, mix(H(BRASS), hexc("#ffffff"), 0.4))
    warm(sp, 21, 20, "#7aff8a")
    return done(sp)


@obj("air_alarm")
def barometer():
    sp = _sp()
    cv = sp.cv
    wood(cv, 5, 3, 26, 28, "#6f4a2b", True, 7, "baro", bevel=1.2)
    gauge(sp, 15.5, 13, 6, 0.9, glow=True)
    cv.hline(10, 21, 22, H("#efe3bd")); cv.hline(11, 20, 24, H("#efe3bd"))
    cv.px(9, 6, H(BRASS)); cv.px(22, 6, H(BRASS))
    return done(sp)


def alarm_bell(state):
    sp = _sp()
    cv = sp.cv
    wood(cv, 8, 3, 23, 28, "#6f4a2b", True, 6, "fab", bevel=1.2)
    bm = E(cv, 15.5, 14, 7, 7)
    shade_mask(cv, bm, "#c99a3c" if state != "on" else "#e0b04a", "metal", height=sphere_height(bm))
    cv.a[R(cv, 6, 19, 25, 21, 0)] = H("#a87a30")
    cv.rect(14, 7, 17, 8, H(IRON_D))
    cv.vline(15, 21, 26, H(ROPE)); cv.px(15, 27, H("#b0302e")); cv.px(16, 27, H("#b0302e"))
    if state == "on":
        for (x, y) in ((4, 11), (3, 14), (4, 17), (27, 11), (28, 14), (27, 17)):
            sp.g(x, y, H("#ffc46a"))
        sp.g(15, 14, H("#ffe6a0"))
    return done(sp)


REDRAWN["fire_alarm"] = lambda: alarm_bell("idle")
REDRAWN["fire_alarm_idle"] = lambda: alarm_bell("idle")
REDRAWN["fire_alarm_on"] = lambda: alarm_bell("on")


@obj("intercom")
def speaking_tube():
    sp = _sp()
    cv = sp.cv
    wood(cv, 8, 6, 23, 27, "#6f4a2b", True, 6, "sptw", bevel=1.2)
    horn = E(cv, 15.5, 16, 6, 6)
    shade_mask(cv, horn, BRASS, "metal", height=sphere_height(horn))
    cv.a[E(cv, 15.5, 16, 3.5, 3.5)] = H("#1d1510")
    cv.px(13, 14, hexc("#fff0b0"))
    cv.vline(15, 3, 8, H(BRASS)); cv.vline(16, 3, 8, shade(H(BRASS), -0.3))
    brass(cv, 12, 24, 19, 25, 0)
    warm(sp, 15, 16, "#ffb04a")
    return done(sp)


@obj("emergency_light")
def hood_lantern():
    sp = _sp()
    cv = sp.cv
    cv.hline(12, 19, 12, H(IRON)); cv.hline(13, 18, 11, H(IRON_D))
    lamp_glass(sp, 14, 13, 4, 3, "#ffb05a")
    cv.px(15, 9, H(ROPE)); cv.px(16, 10, H(ROPE))
    return done(sp)


def lever(on):
    sp = _sp()
    cv = sp.cv
    wood(cv, 11, 8, 20, 24, "#6f4a2b", True, 5, "lvr", bevel=1.0)
    brass(cv, 13, 10, 18, 22, 0)
    cv.rect(15, 12, 16, 20, H("#1d1510"))
    if on:
        cv.line(15, 18, 15, 11, H(IRON)); cv.rect(14, 10, 17, 11, H("#b0302e"))
        warm(sp, 16, 22, "#ffc46a")
    else:
        cv.line(15, 14, 15, 20, H(IRON)); cv.rect(14, 20, 17, 21, H("#b0302e"))
    return done(sp)


REDRAWN["light_switch_on"] = lambda: lever(True)
REDRAWN["light_switch_off"] = lambda: lever(False)


def rail_lamp(state):
    sp = _sp()
    cv = sp.cv
    brass(cv, 4, 10, 28, 12, 0)
    for x in range(6, 27, 5):
        cv.px(x, 11, mix(H(BRASS), hexc("#ffffff"), 0.4))
    for k, x in enumerate((7, 14, 21)):
        if state == "on":
            for dx in range(4):
                for dy in range(3):
                    sp.g(x + dx, 13 + dy, mix(H("#ffcf7a"), hexc("#fff4d0"), 0.4 if dy == 0 else 0))
        elif state == "off":
            cv.rect(x, 13, x + 3, 15, H("#6a604a"))
            cv.px(x, 13, H("#8a805e"))
        elif k != 1:
            cv.rect(x, 13, x + 3, 15, H("#3a3630"))
    return done(sp)


REDRAWN["light_on"] = lambda: rail_lamp("on")
REDRAWN["light_off"] = lambda: rail_lamp("off")
REDRAWN["light_broken"] = lambda: rail_lamp("broken")


@obj("floodlight", "floodlight_off")
def lantern_post():
    sp = _sp(32, 64)
    cv = sp.cv
    ground(cv, 11, 20, 62)
    rod = R(cv, 14, 14, 17, 60, 0)
    shade_mask(cv, rod, "#4a4a52", "metal", height=cyl_height(rod, "v"))
    brass(cv, 11, 56, 20, 61, 0, "#8a6a3a")
    brass(cv, 12, 30, 19, 32, 0)
    hm = P(cv, [(6, 8), (25, 8), (21, 3), (10, 3)])
    shade_mask(cv, hm, COPPER, "metal", bevel=1.0)
    for y in range(9, 18):
        for x in range(9, 23):
            sp.g(x, y, mix(H("#ffcf7a"), hexc("#fff4d0"), 0.35 if (x < 13 and y < 12) else 0.0))
    for x in (8, 15, 22):
        cv.vline(x, 9, 18, H(BRASS))
    cv.hline(8, 23, 19, shade(H(BRASS), -0.35))
    cv.hline(7, 24, 20, shade(H(BRASS), -0.5))
    return done(sp)


@obj("iv_drip")
def flask_stand():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 9, 22, 46)
    rod = R(cv, 15, 8, 16, 44, 0)
    shade_mask(cv, rod, BRASS, "metal", height=cyl_height(rod, "v"))
    cv.hline(9, 22, 45, H("#7a5a24"))
    cv.line(15, 44, 10, 46, H("#7a5a24")); cv.line(16, 44, 21, 46, H("#7a5a24"))
    cv.hline(11, 20, 6, H(BRASS)); cv.vline(11, 6, 8, H(BRASS)); cv.vline(20, 6, 8, H(BRASS))
    fm = E(cv, 15.5, 12, 4.5, 5.5)
    shade_mask(cv, fm, "#8ab0be", "glass", height=sphere_height(fm))
    cv.a[R(cv, 12, 13, 19, 16, 0) & fm] = H("#b8342a")
    cv.rect(14, 5, 17, 7, H("#8a6a3a"))
    cv.vline(15, 17, 26, H("#c8c0a8"))
    return done(sp)


# ================================================================== amusements
@obj("jukebox")
def phonograph():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 5, 26, 46)
    cabinet(cv, 6, 20, 25, 45, 4, "#7a4a28", "paint", top="#a87a46", bevel=1.2)
    wood(cv, 6, 25, 25, 45, "#7a4a28", True, 6, "pho", bevel=1.2)
    plat = E(cv, 15.5, 22.5, 8, 2.4)
    shade_mask(cv, plat, "#1d1510", "paint", height=sphere_height(plat))
    cv.hline(11, 20, 22, H("#4a3a2a"))
    cv.line(19, 20, 14, 22, H(BRASS))
    cv.rect(9, 29, 22, 41, H("#8a2a2a"))
    for y in range(30, 41, 2):
        for x in range(10, 22, 2):
            cv.px(x, y, H("#6a1e1e"))
    cv.rect(9, 29, 22, 29, H(BRASS))
    horn = P(cv, [(14, 19), (17, 19), (28, 3), (22, 1), (16, 9)])
    shade_mask(cv, horn, BRASS, "metal", bevel=1.0)
    hm = E(cv, 25.5, 3.5, 5, 3)
    shade_mask(cv, hm, "#e0b04a", "metal", height=sphere_height(hm))
    cv.a[E(cv, 25.5, 3.5, 3.5, 1.8)] = H("#4a2e18")
    for x in (10, 21):
        warm(sp, x, 27, "#ffb04a")
    return done(sp)


@obj("arcade")
def orrery():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 8, 24, 46)
    cabinet(cv, 8, 30, 23, 45, 4, "#6f4a2b", "paint", top="#a07240", bevel=1.2)
    wood(cv, 8, 34, 23, 45, "#6f4a2b", True, 5, "orr", bevel=1.0)
    brass(cv, 14, 38, 17, 40, 0)
    cv.rect(14, 12, 17, 30, H("#8a6a3a")); cv.vline(14, 12, 30, H(BRASS))
    sun = E(cv, 15.5, 17, 3, 3)
    shade_mask(cv, sun, "#f0c04a", "metal", height=sphere_height(sun))
    sp.g(15, 17, H("#fff0b0")); sp.g(16, 17, H("#ffdf80"))
    for (rx, ry, ph) in ((9, 3.6, 0.5), (12, 5, 2.2), (6, 2.6, 4.0)):
        for k in range(48):
            a = k / 48 * math.tau
            x, y = int(round(15.5 + math.cos(a) * rx)), int(round(17 + math.sin(a) * ry))
            cv.px(x, y, H(BRASS) if math.sin(a) < 0 else shade(H(BRASS), -0.35))
        px_, py_ = int(round(15.5 + math.cos(ph) * rx)), int(round(17 + math.sin(ph) * ry))
        cv.rect(px_, py_, px_ + 1, py_ + 1, H("#7ab0d0" if rx == 9 else "#c8543a" if rx == 12 else "#e8e0c8"))
    cv.hline(11, 20, 8, H(BRASS)); cv.vline(15, 6, 8, H(BRASS))
    round_brass(cv, 15.5, 5.5, 1.5)
    return done(sp)


T.RT_ALL = RT


def apply(pk):
    apply_retones(pk)
