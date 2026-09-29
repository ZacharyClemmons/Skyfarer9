"""Sky-themed consoles, workshop and engine-room machinery (see theme.py)."""
import math

import numpy as np

import theme as T
from theme import (BRASS, CANVAS, COPPER, IRON, IRON_D, LAMP, LEATHER, OAK, ROPE, H, R, E, P, _sp, brass, cabinet, done,
                   gauge, ground, iron, lamp_glass, obj, retone, rivet_line, round_brass, rope_line, warm, wood)
from common import hexc, mix, ramp, rng_for, shade
from px import cyl_height, shade_mask, sphere_height

REDRAWN = T.REDRAWN

# ================================================================== instrument pedestals (were consoles)
CONSOLE = {  # face colour of the main dial, needle angle, accent lamp
    "atmos": ("#bfe4d8", 0.4, "#7affc8"), "cargo": ("#f0dca0", 1.1, "#ffc46a"), "cmd": ("#cfe0f4", -0.3, "#7ab0ff"),
    "comms": ("#efe3bd", 2.2, "#ffc46a"), "dna": ("#e0d0f0", 0.9, "#c89aff"), "eng": ("#f4d8a8", 0.2, "#ff9a3a"),
    "med": ("#d4f0dc", 1.6, "#7aff9a"), "reactor": ("#f4c8b0", -0.7, "#ff6a4a"), "sci": ("#dccaf4", 1.9, "#b89aff"),
    "sec": ("#f0c8c8", 0.6, "#ff6a5a"),
}


def pedestal(kind):
    face, ang, lampc = CONSOLE[kind]
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    # oak cabinet base
    wood(cv, 5, 26, 26, 37, "#7a5030", True, 6, "ped" + kind, bevel=1.1)
    iron(cv, 5, 26, 26, 27, IRON_D, True, 4)
    cv.rect(6, 36, 25, 37, H("#2a1810"))
    brass(cv, 14, 31, 17, 32, 0)
    # the slanted instrument deck: brass-bound, dark leather panel
    deck = P(cv, [(3, 25), (28, 25), (26, 14), (5, 14)])
    shade_mask(cv, deck, "#5a4630", "paint", bevel=1.2)
    cv.hline(5, 26, 14, H(BRASS)); cv.hline(3, 28, 25, shade(H(BRASS), -0.35))
    for (x, y) in ((6, 16), (25, 16), (5, 23), (26, 23)):
        cv.px(x, y, mix(H(BRASS), hexc("#ffffff"), 0.4))
    # two small dials and a bank of brass toggles on the deck
    gauge(sp, 9, 20, 2, ang + 1.0, face)
    gauge(sp, 22, 20, 2, ang - 0.8, face)
    for k, x in enumerate(range(12, 20, 2)):
        cv.vline(x, 18, 22, H("#2a1810"))
        cv.rect(x - 1, 17 + (k % 2) * 3, x, 18 + (k % 2) * 3, H(BRASS))
    warm(sp, 15, 23, lampc) if False else sp.g(16, 23, H(lampc))
    # upright brass hood with the main dial
    hood = R(cv, 6, 2, 25, 13, 2)
    shade_mask(cv, hood, "#b98a38", "metal", bevel=1.3)
    cv.hline(7, 24, 2, mix(H(BRASS), hexc("#ffffff"), 0.35))
    gauge(sp, 15.5, 7.5, 4, ang, face)
    cv.px(8, 4, mix(H(BRASS), hexc("#ffffff"), 0.5)); cv.px(23, 4, mix(H(BRASS), hexc("#ffffff"), 0.5))
    for x in (8, 23):
        cv.px(x, 11, shade(H(BRASS), -0.5))
    # kind mark on the hood, painted
    if kind in ("cmd",):
        cv.px(15, 12, H("#2f4f8a")); cv.px(16, 12, H("#2f4f8a"))
    if kind == "sec":
        cv.hline(11, 20, 12, H("#8a3038"))
    if kind == "med":
        cv.hline(13, 18, 12, H("#3f8a6a"))
    return done(sp)


for _k in CONSOLE:
    REDRAWN[f"console_{_k}"] = (lambda k: (lambda: pedestal(k)))(_k)


@obj("desk_computer")
def chart_desk():
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    for x in (5, 25):
        wood(cv, x, 22, x + 2, 29, "#4a2e18", True, 9, "cdl%d" % x, bevel=0.8)
    cabinet(cv, 3, 12, 28, 26, 10, "#7a5030", "paint", top="#a87a46", bevel=1.1)
    # slanted chart with pencilled course and brass dividers
    ch = P(cv, [(6, 13), (25, 13), (26, 20), (5, 20)])
    shade_mask(cv, ch, CANVAS, "paper", bevel=1.0)
    cv.line(8, 18, 14, 15, H("#6a4a2a")); cv.line(14, 15, 22, 17, H("#6a4a2a"))
    cv.px(14, 15, H("#b0302e")); cv.px(22, 17, H("#b0302e"))
    cv.hline(6, 25, 13, H("#efe4c0"))
    brass(cv, 8, 20, 12, 21, 0)
    # lamp on the corner
    brass(cv, 22, 8, 25, 12, 0, "#8a6a3a")
    lamp_glass(sp, 22, 4, 3, 3)
    cv.rect(26, 21, 27, 22, H("#1d1510"))
    return done(sp)


def frame(stage, machine):
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    col = "#6f4a2b"
    # timber corner posts always; more is added as the build proceeds
    for x in (4, 26):
        wood(cv, x, 6, x + 2, 29, col, True, 9, "fr%d%d" % (x, stage), bevel=0.9)
    wood(cv, 4, 6, 28, 8, col, False, 9, "frt%d" % stage, bevel=0.9)
    wood(cv, 4, 27, 28, 29, col, False, 9, "frb%d" % stage, bevel=0.9)
    if stage >= 1:
        shade_mask(cv, R(cv, 7, 9, 25, 26, 0), "#3a2818", "paint", bevel=1.0)
        cv.hline(7, 25, 17, H("#5a4028"))
    if stage >= 2:
        iron(cv, 7, 12, 25, 13, IRON, True, 4)
        iron(cv, 7, 21, 25, 22, IRON, True, 4)
        if machine:
            cv.rect(11, 14, 20, 20, H("#7a5a2a")); cv.hline(11, 20, 14, H(BRASS))
        else:
            gauge(sp, 16, 16, 3, 0.8, glow=False)
    if stage >= 3:
        brass(cv, 7, 9, 25, 10, 0)
        sp.g(16, 24, H(LAMP))
    return done(sp)


for _s in range(4):
    REDRAWN[f"computer_frame_{_s}"] = (lambda s: (lambda: frame(s, False)))(_s)
    REDRAWN[f"machine_frame_{_s}"] = (lambda s: (lambda: frame(s, True)))(_s)


# ================================================================== forge, drafting, apothecary
def forge(on):
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    wood(cv, 4, 22, 27, 37, "#5a3a24", True, 6, "forge", bevel=1.1)
    iron(cv, 4, 22, 27, 23, IRON_D, True, 4)
    iron(cv, 4, 35, 27, 36, IRON_D, True, 4)
    # brick hearth with glowing coals
    hearth = R(cv, 6, 24, 25, 32, 1)
    shade_mask(cv, hearth, "#6a3a2a", "paint", bevel=1.0)
    for y in (27, 30):
        cv.hline(6, 25, y, shade(H("#6a3a2a"), -0.4))
    cv.rect(8, 26, 23, 31, H("#1d1510"))
    for x in range(9, 23):
        for y in range(28, 31):
            if on:
                sp.g(x, y, H("#ff9a3a") if (x + y) % 3 else H("#ffd06a"))
            else:
                cv.px(x, y, H("#4a2a1e") if (x + y) % 3 else H("#6a4030"))
    # anvil on top
    an = P(cv, [(7, 10), (24, 10), (21, 13), (18, 14), (18, 19), (22, 21), (10, 21), (14, 19), (14, 14), (11, 13)])
    shade_mask(cv, an, "#4a4650", "metal", bevel=1.2)
    cv.hline(8, 23, 10, mix(H("#8a8494"), hexc("#ffffff"), 0.3))
    horn = P(cv, [(23, 10), (30, 10), (24, 13)])
    shade_mask(cv, horn, "#4a4650", "metal", bevel=1.0)
    if on:
        cv.a[R(cv, 13, 9, 17, 10, 0)] = H("#ff8a3a")
        sp.g(15, 9, H("#ffcf6a")); sp.g(16, 8, H("#ff9a3a"))
    # tongs hung on the side
    cv.line(3, 24, 3, 32, H(IRON)); cv.px(2, 32, H(IRON)); cv.px(4, 32, H(IRON))
    return done(sp)


REDRAWN["autolathe"] = lambda: forge(False)
REDRAWN["autolathe_on"] = lambda: forge(True)


def bench_base(sp, seed):
    cv = sp.cv
    ground(cv, 4, 27, 38)
    wood(cv, 4, 22, 27, 37, "#6f4a2b", True, 6, seed, bevel=1.1)
    iron(cv, 4, 22, 27, 23, IRON_D, True, 4)
    cv.rect(6, 36, 25, 37, H("#2a1810"))
    shade_mask(cv, R(cv, 3, 19, 28, 22, 0), "#b98f5a", "paint", bevel=0.8)
    cv.hline(3, 28, 19, mix(H("#b98f5a"), hexc("#ffffff"), 0.35))


@obj("rnd_protolathe")
def drafting_table():
    sp = _sp(32, 40)
    bench_base(sp, "prt")
    cv = sp.cv
    tilt = P(cv, [(5, 8), (26, 8), (28, 19), (3, 19)])
    shade_mask(cv, tilt, CANVAS, "paper", bevel=1.0)
    for x in range(8, 26, 4):
        cv.vline(x, 9, 18, shade(H(CANVAS), -0.14))
    cv.line(7, 16, 12, 11, H("#3a5a8a")); cv.line(12, 11, 20, 14, H("#3a5a8a")); cv.line(20, 14, 24, 10, H("#3a5a8a"))
    cv.px(12, 11, H("#b0302e")); cv.px(20, 14, H("#b0302e"))
    brass(cv, 6, 3, 9, 7, 0)
    lamp_glass(sp, 8, 3, 2, 3) if False else None
    cv.line(22, 7, 27, 2, H(BRASS)); cv.line(27, 2, 27, 1, H(BRASS))
    lamp_glass(sp, 26, 3, 2, 2)
    return done(sp)


@obj("rnd_analyzer")
def astrolabe():
    sp = _sp(32, 40)
    bench_base(sp, "asl")
    cv = sp.cv
    for k in range(3):
        cv.line(15 + (k - 1) * 3, 19, 15 + (k - 1) * 7, 26 if False else 19, H(IRON_D)) if False else None
    tube = P(cv, [(9, 15), (12, 12), (26, 3), (28, 6), (14, 17)])
    shade_mask(cv, tube, "#b98a38", "metal", bevel=1.0)
    cv.line(11, 14, 27, 5, mix(H(BRASS), hexc("#ffffff"), 0.4))
    cv.rect(26, 2, 29, 6, H("#7a5a24"))
    cv.a[E(cv, 28, 4, 1.5, 1.8)] = H("#8ab0d0")
    for x in (12, 20):
        cv.rect(x, 12, x + 1, 19, H(BRASS))
    ring = E(cv, 11, 12, 6, 6)
    for k in range(40):
        a = k / 40 * math.tau
        cv.px(int(round(11 + math.cos(a) * 5.4)), int(round(12 + math.sin(a) * 5.4)), H(BRASS))
    cv.line(11, 12, 15, 8, H("#8a6a3a"))
    sp.g(11, 12, H("#ffe6a0"))
    return done(sp)


@obj("rnd_server")
def difference_engine():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    wood(cv, 4, 4, 27, 37, "#5b3a21", True, 6, "dfe", bevel=1.2)
    shade_mask(cv, R(cv, 6, 6, 25, 33, 0), "#26180e", "paint", bevel=1.0)
    for i, (cx, cy, r) in enumerate(((12, 12, 4), (20, 15, 3), (11, 23, 3), (19, 26, 4))):
        teeth = 8 + r
        for k in range(teeth):
            a = k / teeth * math.tau + i
            cv.px(int(round(cx + math.cos(a) * (r + 0.6))), int(round(cy + math.sin(a) * (r + 0.6))), H(BRASS))
        m = E(cv, cx, cy, r - 0.5, r - 0.5)
        shade_mask(cv, m, "#b98a38", "metal", height=sphere_height(m))
        cv.px(int(cx), int(cy), H("#2a1810"))
    for y in (8, 20, 31):
        cv.hline(6, 25, y, shade(H(BRASS), -0.3))
    for x, y in ((8, 8), (23, 8), (8, 31), (23, 31)):
        cv.px(x, y, mix(H(BRASS), hexc("#ffffff"), 0.5))
    sp.g(24, 10, H("#ffc46a")); sp.g(24, 24, H("#ffc46a"))
    return done(sp)


@obj("chem_dispenser")
def apothecary_rack():
    sp = _sp(32, 40)
    cv = sp.cv
    rng = rng_for("chemd")
    ground(cv, 4, 27, 38)
    wood(cv, 4, 3, 27, 37, "#6f4a2b", True, 6, "chd", bevel=1.2)
    shade_mask(cv, R(cv, 6, 5, 25, 25, 0), "#26180e", "paint", bevel=1.0)
    for y in (14, 24):
        cv.hline(6, 25, y, H("#a07240")); cv.hline(6, 25, y + 1, H("#2a1810"))
    cols = ["#5a9a7a", "#b0602e", "#4a6a9a", "#a8823e", "#8a4a8a", "#c8d0c0"]
    for y in (14, 24):
        x = 7
        while x < 23:
            w = rng.choice((3, 4)); h = rng.choice((5, 6, 7))
            c = H(rng.choice(cols))
            m = R(cv, x, y - h, x + w - 1, y - 1, 1)
            shade_mask(cv, m, c, "glass", height=cyl_height(m, "v"))
            cv.px(x + w // 2, y - h - 1, H("#d8c8a0"))
            sp.g(x + 1, y - h + 1, mix(c, hexc("#ffffff"), 0.4)) if False else None
            x += w + 1
    for x in (10, 16, 22):
        brass(cv, x, 27, x + 1, 30, 0)
        cv.px(x, 31, hexc("#bfe4ee", 0.8))
    wood(cv, 4, 32, 27, 37, "#5b3a21", False, 6, "chdb", bevel=1.0)
    sp.g(8, 6, H("#ffc46a"))
    return done(sp)


@obj("chem_master")
def scales_bench():
    sp = _sp(32, 40)
    bench_base(sp, "chm")
    cv = sp.cv
    # brass scales
    cv.vline(15, 6, 19, H(BRASS)); cv.hline(7, 24, 8, H(BRASS))
    for x in (8, 23):
        cv.line(x, 8, x - 1, 12, H("#7a5a24")); cv.line(x, 8, x + 1, 12, H("#7a5a24"))
        cv.a[E(cv, x, 13, 3, 1.4)] = H("#c99a3c")
    cv.rect(6, 11, 7, 12, H("#efe3bd"))
    m = E(cv, 21, 17, 4, 2.6)
    shade_mask(cv, m, "#d8d0bc", "paint", height=sphere_height(m))
    cv.a[E(cv, 21, 17, 2.4, 1.4)] = H("#3a2a1e")
    cv.rect(10, 15, 13, 19, H("#5a9a7a")); cv.px(10, 15, H("#d8f0e0"))
    warm(sp, 15, 5, LAMP) if False else None
    return done(sp)


def alembic(on):
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    brass(cv, 8, 22, 23, 28, 0, "#8a6a3a")
    cv.rect(12, 24, 19, 26, H("#1d1510"))
    for x in range(12, 20):
        if on:
            sp.g(x, 25, H("#ff9a3a") if x % 2 else H("#ffd06a"))
    fl = E(cv, 15.5, 15, 6, 6)
    shade_mask(cv, fl, "#9ac8d0" if not on else "#d8b070", "glass", height=sphere_height(fl))
    cv.a[fl & R(cv, 0, 15, 31, 20, 0)] = H("#c8843a") if on else H("#7a9a6a")
    brass(cv, 13, 6, 18, 10, 0)
    cv.line(19, 7, 27, 12, H(COPPER)); cv.line(19, 8, 27, 13, shade(H(COPPER), -0.3))
    cv.rect(26, 14, 28, 20, H("#7ab0c8")); cv.px(26, 14, hexc("#ffffff"))
    if on:
        cv.px(16, 12, hexc("#ffe6b0", 0.8)); cv.px(14, 16, hexc("#ffe6b0", 0.6))
    return done(sp)


REDRAWN["chem_heater"] = lambda: alembic(False)
REDRAWN["chem_heater_on"] = lambda: alembic(True)


# ================================================================== engine-room props
def drum(kind, on=False):
    """generator / dynamo drum: iron barrel body, brass bands and dial."""
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    body = R(cv, 4, 10, 27, 29, 2)
    shade_mask(cv, body, "#4a4650", "metal", height=cyl_height(body, "v"))
    for x in (8, 23):
        cv.vline(x, 10, 29, H(BRASS)); cv.vline(x + 1, 10, 29, shade(H(BRASS), -0.4))
    top = E(cv, 15.5, 10, 12, 3)
    shade_mask(cv, top, "#6a6674", "metal", height=sphere_height(top))
    brass(cv, 12, 4, 19, 8, 0)
    cv.rect(13, 1, 18, 3, H("#2a2630"))
    if on:
        sp.g(15, 0, hexc("#c8c8c8")) if False else None
    gauge(sp, 15.5, 20, 3, 0.9 if on else -1.0)
    for x in (12, 19):
        cv.px(x, 27, H(BRASS))
    warm(sp, 24, 15, "#7aff8a" if on else "#ff6a3a")
    return done(sp)


REDRAWN["generator"] = lambda: drum("generator")
REDRAWN["generator_on"] = lambda: drum("generator", True)


def oil_drum(open_):
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    body = R(cv, 6, 8, 25, 29, 2)
    shade_mask(cv, body, "#a8342a", "paint", height=cyl_height(body, "v"))
    for y in (12, 20, 26):
        for x in range(6, 26):
            if body[y, x]:
                cv.px(x, y, shade(cv.get(x, y), -0.3))
                cv.px(x, y + 1, shade(cv.get(x, y + 1), 0.15))
    top = E(cv, 15.5, 8, 9.5, 2.6)
    shade_mask(cv, top, "#6a6674", "metal", height=sphere_height(top))
    if open_:
        cv.a[E(cv, 15.5, 8, 7, 1.7)] = H("#1d1510")
    else:
        cv.a[E(cv, 12, 8, 2, 1)] = H("#c8c0a8")
    cv.rect(11, 15, 20, 17, H("#efe3bd")) if False else None
    for x in range(12, 20):
        if x % 2:
            cv.px(x, 15, H("#efe3bd"))
    return done(sp)


REDRAWN["fuel_tank"] = lambda: oil_drum(False)
REDRAWN["fuel_tank_open"] = lambda: oil_drum(True)


def steam_heater(on):
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    cv.rect(4, 26, 27, 28, H("#2a1e14"))
    for x in range(5, 27, 4):
        m = R(cv, x, 9, x + 2, 26, 1)
        shade_mask(cv, m, COPPER if not on else "#d8783a", "metal", height=cyl_height(m, "v"))
    brass(cv, 4, 7, 27, 10, 0)
    brass(cv, 4, 25, 27, 27, 0)
    round_brass(cv, 28, 17, 1.6)
    if on:
        for x in range(6, 26, 4):
            sp.g(x, 12, H("#ffb06a"))
    return done(sp)


REDRAWN["heater_off"] = lambda: steam_heater(False)
REDRAWN["heater_on"] = lambda: steam_heater(True)


def brazier(state):
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    for x in (8, 22):
        cv.line(x, 22, x + (1 if x < 15 else -1), 29, H(IRON_D))
    bowl = E(cv, 15.5, 20, 9, 4.2)
    shade_mask(cv, bowl, "#4a4650", "metal", height=sphere_height(bowl))
    cv.hline(7, 24, 17, H(BRASS))
    inner = E(cv, 15.5, 19, 7.4, 2.8)
    cv.a[inner] = H("#1d1510")
    for x in range(9, 23):
        for y in range(17, 21):
            if inner[y, x]:
                if state == "heat":
                    sp.g(x, y, H("#ff8a3a") if (x + y) % 3 else H("#ffd06a"))
                elif state == "cool":
                    cv.px(x, y, H("#5a8ab0") if (x + y) % 3 else H("#8ab8d8"))
                else:
                    cv.px(x, y, H("#4a2a1e") if (x + y) % 3 else H("#6a4030"))
    if state == "heat":
        sp.g(15, 14, H("#ffb84a")); sp.g(16, 13, H("#ff8a3a")); sp.g(14, 15, H("#ffd06a")); sp.g(17, 15, H("#ffb84a"))
    return done(sp)


REDRAWN["space_heater"] = lambda: brazier("idle")
REDRAWN["space_heater_heat"] = lambda: brazier("heat")
REDRAWN["space_heater_cool"] = lambda: brazier("cool")


def hand_pump(on, bellows=False):
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 5, 26, 38)
    for x in (7, 24):
        m = E(cv, x, 34, 3.4, 3.4)
        shade_mask(cv, m, "#3a3036", "metal", height=sphere_height(m))
        cv.px(x, 34, H(BRASS))
    wood(cv, 5, 22, 26, 31, "#6f4a2b", False, 5, "hp%d" % bellows, bevel=1.0)
    if bellows:
        for k, y in enumerate((8, 12, 16, 20)):
            w = 9 - (0 if k % 2 else 1)
            cv.a[R(cv, 16 - w, y, 15 + w, y + 3, 1)] = shade(H("#7a5a3a"), 0.1 if k % 2 else -0.15)
        cv.rect(6, 5, 25, 7, H(IRON))
        brass(cv, 12, 2, 19, 4, 0)
    else:
        cyl = R(cv, 11, 8, 20, 23, 1)
        shade_mask(cv, cyl, "#b98a38", "metal", height=cyl_height(cyl, "v"))
        cv.rect(14, 3, 17, 8, H(IRON_D)); cv.hline(8, 23, 3, H(IRON))
        cv.line(23, 3, 28, 12, H(IRON)); cv.rect(27, 12, 29, 14, H(LEATHER))
    gauge(sp, 21 if not bellows else 27, 15, 2, 0.8 if on else -1.2)
    if on:
        warm(sp, 8, 27, "#7aff8a")
    return done(sp)


REDRAWN["portable_pump"] = lambda: hand_pump(False)
REDRAWN["portable_pump_on"] = lambda: hand_pump(True)
REDRAWN["portable_scrubber"] = lambda: hand_pump(False, True)
REDRAWN["portable_scrubber_on"] = lambda: hand_pump(True, True)


# ================================================================== retoned machines (steel plumbing to brass and copper)
BR = ["#1e1408", "#4a3418", "#7a5a24", "#b98a38", "#dcb45a", "#fff0b0"]
CU = ["#24120c", "#5a2a1a", "#8a4428", "#bd6a3c", "#e0925a", "#ffd8b0"]
RT = {}
for _n in ("connector", "injector", "injector_off", "igniter", "igniter_on", "pipe_dispenser", "recharger", "recharger_on",
           "pipe_link"):
    RT[_n] = BR
for _p in ("aux", "gen", "scrub", "supply", ""):
    for _st in ("on", "off"):
        for _f in ("pump", "vpump", "valve", "mixer", "filter", "gate"):
            RT[f"{_f}_{_p}_{_st}" if _p else f"{_f}_{_st}"] = BR
for _n in ("thermo_freezer_off", "thermo_freezer_on", "thermo_heater_off", "thermo_heater_on", "radiator", "teg", "pipe_tank",
           "supply_pod"):
    RT[_n] = CU
RT["girder"] = ["#241610", "#3e2716", "#5b3a21", "#8a5b33", "#b98f5a", "#dcb67c"]
for _n in ("grille", "grille_broken", "grille_damaged"):
    RT[_n] = ["#241c16", "#3e342c", "#5e5248", "#8a7a68", "#b8a688", "#e0d0b0"]
T.RT_ALL.update(RT)
