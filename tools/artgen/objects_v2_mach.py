"""Station objects, second generation: machines - power, atmos, medical, science, kitchen,
cargo (see objects_v2.py)."""
import math

import numpy as np

from common import hexc, mix, ramp, rng_for, shade
from objects_v2 import (sheen, DARK_STEEL, GUNMETAL, REDRAWN, RUBBER, STEEL, E, H, P, R, _sp, cabinet, cyl_cols, done, door,
                        fill, ground, lamp, obj, panel, rod, screen, slits)
from px import cyl_height, shade_mask, sphere_height

MACHINE = "#b4bcc8"   # tg machine off-white grey
MACHINE_DK = "#5a6272"


def hazard(cv, x0, x1, y, h=2):
    for yy in range(y, y + h):
        for x in range(x0, x1 + 1):
            cv.px(x, yy, H("#e8c03a") if ((x + yy) // 2) % 2 == 0 else H("#26242c"))


def fan(sp, cx, cy, r, blade="#8a93a3", hub="#c8d0dc", phase=0.0, glow=None):
    cv = sp.cv
    m = E(cv, cx, cy, r, r)
    fill(cv, m, H("#15141c"))
    for k in range(4):
        a = k * math.pi / 2 + phase
        for t in np.linspace(1.0, r - 0.6, 8):
            x, y = cx + math.cos(a) * t - 0.5, cy + math.sin(a) * t - 0.5
            x2, y2 = cx + math.cos(a + 0.45) * t * 0.8 - 0.5, cy + math.sin(a + 0.45) * t * 0.8 - 0.5
            cv.px(int(round(x)), int(round(y)), H(blade))
            cv.px(int(round(x2)), int(round(y2)), shade(H(blade), -0.3))
    cv.px(int(cx - 0.5), int(cy - 0.5), H(hub))
    ring = m & ~E(cv, cx, cy, r - 0.9, r - 0.9)
    fill(cv, ring, H("#3a3f4a"))


# ============================================================================ power
@obj("smes")
def smes():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 4, 27, 46)
    fp, _, _ = cabinet(cv, 4, 6, 27, 45, 5, "#6a7486", "metal", top="#8a93a3")
    # terminals on top
    for x in (9, 21):
        rod(cv, x, 5, x + 1, 5, 1.6, "#c8a040", "metal")
    hazard(cv, 5, 26, 12, 2)
    # the charge gauge: five cells
    dp = door(cv, 7, 16, 24, 38, "#4a505e", "metal")
    for i in range(5):
        y = 18 + i * 4
        lit = i > 0
        for x in range(9, 23):
            c = H("#5aff7a") if lit else H("#1f3a2a")
            if lit:
                sp.g(x, y, c if x % 5 else shade(c, -0.25))
                sp.g(x, y + 1, shade(c, -0.3))
            else:
                cv.px(x, y, c)
                cv.px(x, y + 1, shade(c, -0.3))
    # input/output lamps and a label
    lamp(sp, 8, 41, "#ffd84a")
    lamp(sp, 11, 41, "#5ad0ff")
    cv.rect(16, 40, 24, 42, H("#e8eef4"))
    cv.hline(17, 23, 41, H("#4a505e"))
    return done(sp)


@obj("teg")
def teg():
    sp = _sp(64, 32)
    cv = sp.cv
    ground(cv, 3, 60, 30)
    # the two circulators: fat drums with pipe stubs, hot side orange, cold side blue
    for (x0, col) in ((2, "#e8903a"), (47, "#3ac0d8")):
        cabinet(cv, x0, 9, x0 + 14, 28, 4, "#7a8494", "metal")
        drum = E(cv, x0 + 7.5, 20, 5.5, 5.5)
        shade_mask(cv, drum, "#5a6272", "metal", height=sphere_height(drum))
        fill(cv, E(cv, x0 + 7.5, 20, 3.4, 3.4), H("#1a1a22"))
        for a in range(0, 360, 60):
            x = int(x0 + 7.5 + math.cos(math.radians(a)) * 2.5)
            y = int(20 + math.sin(math.radians(a)) * 2.5)
            sp.g(x, y, H(col))
        cv.hline(x0 + 1, x0 + 13, 26, H(col))
    # the core: a big finned block with its readout
    fp, _, _ = cabinet(cv, 18, 3, 45, 28, 6, "#4a505e", "metal", top="#6b7486")
    for x in range(20, 44, 2):
        cv.vline(x, 4, 7, fp[0])
    screen(sp, 23, 12, 40, 19, "#ffcc4a", "graph", "teg")
    for x in range(21, 43, 3):
        cv.vline(x, 22, 26, fp[0])
        cv.vline(x + 1, 22, 26, fp[-1])
    return done(sp)


def generator(on):
    sp = _sp()
    cv = sp.cv
    ground(cv, 5, 26, 30)
    fp, _, _ = cabinet(cv, 5, 9, 26, 28, 5, "#c8a03a", "paint")
    # fuel cap and exhaust on top
    rod(cv, 9, 10, 10, 10, 1.5, "#3a3f4a", "metal")
    rod(cv, 22, 6, 22, 11, 1.3, "#6b7486", "metal")
    # engine grille and control panel
    cv.rect(7, 16, 17, 26, H("#26242c"))
    for y in range(17, 26, 2):
        cv.hline(8, 16, y, H("#4a4a52"))
    cv.rect(19, 16, 24, 21, H("#3a3f4a"))
    lamp(sp, 20, 17, "#5aff7a" if on else "#ff4a3a")
    cv.px(23, 17, H("#e8eef4"))
    cv.rect(20, 23, 23, 25, H("#1a1a22"))
    if on:
        for y in range(18, 25, 2):
            sp.g(12, y, H("#ff8a3a"))
    # wheels
    for wx in (7, 23):
        fill(cv, E(cv, wx + 0.5, 28.5, 1.8, 1.6), H(RUBBER))
    return done(sp)


REDRAWN["generator"] = lambda: generator(False)
REDRAWN["generator_on"] = lambda: generator(True)


# ============================================================================ atmos
def portable(kind, on):
    col = "#c8b040" if kind == "pump" else "#4a7aa0"
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 6, 25, 38)
    fp, _, _ = cabinet(cv, 6, 10, 25, 35, 4, col, "paint")
    # carry handle and the connector port on top
    rod(cv, 10, 7, 21, 7, 1.0, "#3a3f4a", "metal")
    rod(cv, 10, 7, 10, 10, 1.0, "#3a3f4a", "metal")
    rod(cv, 21, 7, 21, 10, 1.0, "#3a3f4a", "metal")
    if kind == "pump":
        fan(sp, 13.5, 24, 6, phase=0.35 if on else 0.0)
    else:
        m = R(cv, 8, 18, 19, 31, 1)
        fill(cv, m, H("#1a1e26"))
        for y in range(19, 31, 2):
            cv.hline(9, 18, y, H("#6b7486"))
            cv.hline(9, 18, y + 1, H("#2a2e38"))
    # gauge and status light
    g = E(cv, 22.5, 19.5, 2.2, 2.2)
    shade_mask(cv, g, "#e8eef4", "plastic", height=sphere_height(g))
    cv.px(22, 19, H("#1a1a24"))
    cv.px(23, 18, H("#c83a3a"))
    lamp(sp, 22, 25, "#5aff7a" if on else "#ff4a3a")
    cv.rect(21, 28, 23, 31, H("#26242c"))
    # casters
    for wx in (8, 23):
        cv.rect(wx - 1, 35, wx + 1, 37, H(RUBBER))
        cv.px(wx, 36, H("#5a5f6a"))
    return done(sp)


for _kd in ("pump", "scrubber"):
    REDRAWN[f"portable_{_kd}"] = (lambda k: (lambda: portable(k, False)))(_kd)
    REDRAWN[f"portable_{_kd}_on"] = (lambda k: (lambda: portable(k, True)))(_kd)


@obj("pipe_tank")
def pipe_tank():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 3, 28, 38)
    # feet
    for x in (6, 24):
        cv.rect(x, 33, x + 1, 37, H(GUNMETAL))
    # the tank: a horizontal cylinder with end caps
    body = R(cv, 3, 14, 28, 34, 7)
    shade_mask(cv, body, "#7a8494", "metal", height=cyl_height(body, "h"))
    for x in (8, 23):
        cv.vline(x, 15, 33, H("#5a6272"))
        cv.vline(x + 1, 15, 33, H("#a9b3c2"))
    # inlet on top with a valve
    rod(cv, 15, 9, 15, 14, 1.6, "#8a93a3", "metal")
    fill(cv, E(cv, 15.5, 9, 3, 1.3), H("#c83a3a"))
    cv.rect(11, 22, 20, 26, H("#e8eef4"))
    cv.hline(12, 19, 24, H("#4a505e"))
    return done(sp)


def fuel_tank(open_):
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    for wx in (8, 23):
        fill(cv, E(cv, wx + 0.5, 28.5, 2, 1.7), H(RUBBER))
    body = R(cv, 4, 11, 27, 27, 6)
    pal = shade_mask(cv, body, "#c8322a", "paint", height=cyl_height(body, "h"))
    hazard(cv, 8, 23, 18, 3)
    # the "FUEL" stencil band
    cv.rect(10, 22, 21, 23, H("#e8eef4"))
    for x in (11, 13, 15, 17, 19):
        cv.px(x, 22, H("#26242c"))
    rod(cv, 15, 8, 16, 11, 1.6, "#8a93a3", "metal")
    cv.hline(13, 18, 8, H("#3a3f4a"))
    # tap
    rod(cv, 27, 21, 29, 21, 1.1, "#a9b3c2", "metal")
    if open_:
        cv.px(29, 23, H("#b8903a"))
        cv.px(29, 25, hexc("#b8903a", 0.8))
    return done(sp)


REDRAWN["fuel_tank"] = lambda: fuel_tank(False)
REDRAWN["fuel_tank_open"] = lambda: fuel_tank(True)


# ============================================================================ medical & chemistry
@obj("chem_dispenser")
def chem_dispenser():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    fp, _, _ = cabinet(cv, 4, 6, 27, 37, 4, "#e2e8f0", "plastic")
    # the reagent cartridges behind a window
    cv.rect(6, 11, 25, 17, H("#26303c"))
    for i, col in enumerate(("#e84a4a", "#4ae86a", "#4ab8ff", "#ffd84a", "#e84ae8", "#e8e8e8")):
        x = 7 + i * 3
        c = H(col)
        cv.rect(x, 12, x + 1, 16, shade(c, -0.25))
        sp.g(x, 13, c)
        sp.g(x, 14, c)
        cv.px(x, 12, shade(c, 0.35))
    screen(sp, 8, 20, 23, 24, "#5ad0ff", "text", "chemdisp")
    # nozzle over the beaker bay
    cv.rect(9, 27, 22, 35, H("#1d2028"))
    cv.rect(15, 27, 16, 28, H("#9aa3b3"))
    bk = R(cv, 13, 30, 18, 35, 0)
    shade_mask(cv, bk, "#cfe8f5", "glass", bevel=1)
    cv.rect(14, 33, 17, 35, H("#4ab8d8"))
    return done(sp)


@obj("chem_master")
def chem_master():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    fp, _, _ = cabinet(cv, 4, 8, 27, 37, 4, "#c8d0dc", "plastic")
    screen(sp, 7, 14, 24, 21, "#6ae8a8", "text", "chemmaster")
    # beaker slot and the pill output tray
    cv.rect(8, 25, 14, 34, H("#1d2028"))
    bk = R(cv, 9, 28, 13, 34, 0)
    shade_mask(cv, bk, "#cfe8f5", "glass", bevel=1)
    cv.rect(10, 31, 12, 34, H("#e87ab8"))
    cv.rect(17, 27, 25, 32, H("#3a3e48"))
    cv.hline(17, 25, 27, H("#6b7486"))
    for x, c in ((18, "#e84a4a"), (20, "#4ab8ff"), (22, "#ffd84a"), (24, "#e8e8e8")):
        cv.px(x, 30, H(c))
        cv.px(x + 1, 30, shade(H(c), -0.3))
    lamp(sp, 25, 11, "#5aff7a")
    return done(sp)


def chem_heater(on):
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    fp, _, _ = cabinet(cv, 6, 13, 25, 29, 4, "#8a93a3", "metal")
    # the hot plate with a beaker on it
    plate = E(cv, 15.5, 14.5, 7, 2)
    fill(cv, plate, H("#ff6a2a") if on else H("#3a3f4a"))
    if on:
        for y, x in zip(*np.nonzero(plate)):
            sp.g(x, y, H("#ff6a2a") if (x + y) % 2 else H("#ffa04a"))
    bk = R(cv, 13, 6, 18, 14, 0)
    shade_mask(cv, bk, "#cfe8f5", "glass", bevel=1)
    cv.rect(14, 10, 17, 13, H("#8ad85a"))
    cv.hline(12, 19, 6, H("#e8f4ff"))
    # dial and lamp
    d = E(cv, 11.5, 23, 2.2, 2.2)
    shade_mask(cv, d, "#3a3f4a", "plastic", height=sphere_height(d))
    cv.px(12, 22, H("#e8eef4"))
    lamp(sp, 21, 22, "#ff6a2a" if on else "#5aff7a")
    return done(sp)


REDRAWN["chem_heater"] = lambda: chem_heater(False)
REDRAWN["chem_heater_on"] = lambda: chem_heater(True)


@obj("sleeper")
def sleeper():
    sp = _sp(64, 32)
    cv = sp.cv
    ground(cv, 3, 60, 30)
    fp, _, _ = cabinet(cv, 3, 12, 60, 29, 5, "#d8dee6", "plastic")
    cv.hline(4, 59, 22, H("#4aa3d8"))
    cv.hline(4, 59, 23, shade(H("#4aa3d8"), -0.3))
    # the glass pod lid
    pod = R(cv, 6, 5, 47, 20, 7)
    shade_mask(cv, pod, "#2a4a5a", "paint", bevel=3)
    lid = R(cv, 8, 6, 45, 18, 6)
    shade_mask(cv, lid, "#9fd0ec", "glass", bevel=3)
    for x in range(12, 40, 1):
        if x % 7 < 4:
            sheen(cv, x, 8, 0.7)
    # soft interior glow
    for x in range(12, 42):
        sp.glow.px(x, 13, hexc("#4ab8d8", 0.4))
    sp.has_glow = True
    screen(sp, 50, 14, 57, 20, "#4ab8d8", "graph", "sleeper")
    lamp(sp, 51, 25, "#5aff7a")
    return done(sp)


@obj("med_bed")
def med_bed():
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    for x in (6, 25):
        cv.rect(x, 25, x, 29, H("#6b7486"))
        fill(cv, E(cv, x + 0.5, 29.5, 1.4, 1), H(RUBBER))
    cabinet(cv, 4, 6, 27, 26, 16, "#c8d0dc", "metal", bevel=1)
    # the mattress, raised at the head, and a folded sheet
    shade_mask(cv, R(cv, 5, 7, 26, 23, 2), "#e8f0f8", "cloth", bevel=2)
    shade_mask(cv, R(cv, 7, 8, 24, 12, 2), "#ffffff", "cloth", bevel=2)
    shade_mask(cv, R(cv, 5, 16, 26, 22, 1), "#6ab8e0", "cloth", bevel=1.5)
    cv.hline(5, 26, 16, H("#e8f4ff"))
    # side rails
    cv.hline(4, 27, 24, H("#9aa3b3"))
    return done(sp)


# ============================================================================ science & fabrication
def autolathe(on):
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 3, 28, 38)
    fp, _, _ = cabinet(cv, 3, 10, 28, 37, 5, MACHINE, "metal")
    # material hopper on top
    hop = P(cv, [(8, 4), (23, 4), (21, 10), (10, 10)])
    shade_mask(cv, hop, "#6b7486", "metal", bevel=1.2)
    cv.rect(10, 5, 21, 7, H("#26242c"))
    cv.hline(11, 20, 6, H("#8a93a3"))
    hazard(cv, 4, 27, 16, 2)
    screen(sp, 6, 20, 15, 25, "#5ad0ff", "text", "autolathe")
    lamp(sp, 19, 21, "#ffcc4a" if on else "#5aff7a")
    lamp(sp, 22, 21, "#5aff7a")
    lamp(sp, 25, 21, "#5ad0ff")
    # output bay; when running, a glowing part being printed
    cv.rect(6, 28, 25, 34, H("#1c2028"))
    cv.hline(6, 25, 28, H("#0e1014"))
    cv.hline(6, 25, 35, fp[-1])
    if on:
        for x in range(13, 19):
            sp.g(x, 32, H("#ffb84a"))
        sp.g(15, 31, H("#fff0c0"))
        sp.g(16, 29, H("#ffb84a"))
    else:
        cv.rect(12, 31, 18, 33, H("#8a93a3"))
        cv.hline(12, 18, 31, H("#c8d0dc"))
    return done(sp)


REDRAWN["autolathe"] = lambda: autolathe(False)
REDRAWN["autolathe_on"] = lambda: autolathe(True)


@obj("rnd_protolathe")
def protolathe():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 3, 28, 38)
    fp, _, _ = cabinet(cv, 3, 11, 28, 37, 5, MACHINE, "metal")
    cv.hline(4, 27, 16, H("#b87ae8"))
    cv.hline(4, 27, 17, shade(H("#b87ae8"), -0.35))
    # print chamber behind glass, a laser head over a glowing bed
    cv.rect(6, 19, 25, 28, H("#1a2030"))
    cv.hline(7, 24, 21, H("#6b7486"))
    cv.rect(14, 21, 16, 23, H("#c8d0dc"))
    sp.g(15, 24, H("#ff5a5a"))
    sp.g(15, 25, H("#ff8a5a"))
    for x in range(8, 24):
        sp.g(x, 27, H("#ffb05a") if x % 3 else H("#ffd08a"))
    for i in range(4):
        sheen(cv, 20 + i, 19 + i, 0.25)
    # material slots
    for i, c in enumerate(("#c8d0dc", "#9fd0ec", "#ffd84a", "#b87ae8")):
        cv.rect(7 + i * 5, 31, 9 + i * 5, 34, H("#26242c"))
        cv.hline(7 + i * 5, 9 + i * 5, 33, H(c))
    # extraction vents on top
    for x in range(6, 26, 3):
        cv.vline(x, 12, 14, H("#6b7486"))
    return done(sp)


@obj("rnd_analyzer")
def analyzer():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    fp, _, _ = cabinet(cv, 4, 15, 27, 37, 5, "#6a7486", "metal")
    # the scanning ring standing on top
    ring = E(cv, 15.5, 16, 9, 8) & ~E(cv, 15.5, 16, 6, 5.2)
    shade_mask(cv, ring, "#9a6ad8", "metal", bevel=1.6)
    inner = E(cv, 15.5, 16, 6, 5.2)
    for y, x in zip(*np.nonzero(inner)):
        d = math.hypot(x + 0.5 - 15.5, (y + 0.5 - 16) * 1.15)
        sp.g(x, y, mix(H("#e8c8ff"), H("#3a1a5a"), min(1, d / 6)))
    # scanning beam
    for x in range(10, 22):
        sp.g(x, 16, H("#ffffff") if x in (15, 16) else H("#d8a8ff"))
    screen(sp, 7, 26, 16, 32, "#b87ae8", "bars", "analyzer")
    lamp(sp, 21, 28, "#5aff7a")
    lamp(sp, 24, 28, "#b87ae8")
    return done(sp)


@obj("rnd_server")
def server():
    sp = _sp(32, 40)
    cv = sp.cv
    rng = rng_for("v2srv")
    ground(cv, 7, 24, 38)
    fp, _, _ = cabinet(cv, 7, 4, 24, 37, 3, "#2a2e38", "metal", top="#4a505e")
    for y in range(9, 35, 4):
        dp = door(cv, 9, y, 22, y + 2, "#3a3f4a", "metal")
        for x in range(10, 16):
            if x % 2 == 0:
                cv.px(x, y + 1, H("#15141c"))
        for x in (18, 20):
            c = "#5aff7a" if rng.random() < 0.75 else "#ffb84a"
            lamp(sp, x, y + 1, c)
    return done(sp)


# ============================================================================ kitchen & service
@obj("oven")
def oven():
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    fp, tp, _ = cabinet(cv, 4, 5, 27, 29, 8, "#3a3f4a", "metal", top="#5a6272")
    # four burners on the cooktop
    for (x, y) in ((9.5, 7.5), (21.5, 7.5), (9.5, 10.5), (21.5, 10.5)):
        fill(cv, E(cv, x, y, 3.2, 1.4), H("#15141c"))
        fill(cv, E(cv, x, y, 2.2, 0.8) & ~E(cv, x, y, 1.2, 0.4), H("#6b7486"))
    # control knobs
    for x in range(7, 26, 4):
        cv.px(x, 15, H("#c8d0dc"))
        cv.px(x, 16, H("#6b7486"))
    lamp(sp, 25, 15, "#ff8a3a")
    # the oven door: handle bar and a window with the element glowing
    cv.rect(8, 18, 23, 19, H("#a9b3c2"))
    cv.hline(8, 23, 18, H("#e8eef4"))
    cv.rect(8, 21, 23, 27, H("#15141c"))
    for x in range(9, 23):
        sp.g(x, 26, hexc("#ff7a2a", 0.8) if x % 2 else hexc("#ffb05a", 0.8))
    for i in range(4):
        sheen(cv, 18 + i, 21 + i, 0.2)
    return done(sp)


def microwave(on):
    sp = _sp()
    cv = sp.cv
    fp, _, _ = cabinet(cv, 5, 8, 26, 23, 3, "#c8ccd4", "metal")
    cv.rect(7, 13, 19, 21, H("#26242c"))
    for y in range(14, 21):
        for x in range(8, 19):
            if on:
                sp.g(x, y, H("#ffd88a") if (x + y) % 3 else H("#ffb84a"))
            else:
                cv.px(x, y, H("#1d2028") if (x + y) % 2 else H("#23262e"))
    # the plate and the dish going round
    fill(cv, E(cv, 13.5, 19, 4, 1.2), H("#e8eef4") if not on else H("#fff4d8"))
    cv.px(13, 18, H("#c83a3a"))
    cv.px(14, 18, H("#e8a83a"))
    cv.vline(20, 13, 21, fp[0])
    screen(sp, 22, 13, 24, 14, "#5aff7a", "text", "micro")
    for y in (17, 19):
        cv.px(22, y, fp[-1])
        cv.px(24, y, fp[-1])
    return done(sp)


REDRAWN["microwave"] = lambda: microwave(False)
REDRAWN["microwave_on"] = lambda: microwave(True)


@obj("sink")
def sink():
    sp = _sp()
    cv = sp.cv
    cabinet(cv, 5, 10, 26, 22, 7, "#c8d0dc", "metal", bevel=1)
    basin = E(cv, 15.5, 13.5, 8, 2.8)
    shade_mask(cv, basin, "#6a7a8a", "metal", bevel=1.5)
    fill(cv, E(cv, 15.5, 14, 1, 0.6), H("#1a1a22"))
    # tap and handles
    rod(cv, 15, 6, 15, 10, 1.0, "#c8d0dc", "chrome")
    rod(cv, 15, 6, 17, 7, 0.8, "#c8d0dc", "chrome")
    cv.px(12, 9, H("#d84a4a"))
    cv.px(19, 9, H("#4a8ad8"))
    return done(sp)


@obj("hydro_tray")
def hydro_tray():
    sp = _sp()
    cv = sp.cv
    ground(cv, 3, 28, 30)
    fp, tp, _ = cabinet(cv, 3, 11, 28, 29, 6, "#4a6a72", "metal", top="#5a7a82")
    # the soil bed, with a lip all round
    soil = R(cv, 5, 12, 26, 16, 1)
    shade_mask(cv, soil, "#4a3526", "organic", bevel=1, noise=0.25, seed=3)
    for x in range(6, 26, 3):
        cv.px(x, 13, H("#6a4a32"))
    # water level strip and nutrient gauge
    cv.rect(6, 21, 20, 22, H("#1a2a38"))
    for x in range(6, 16):
        sp.g(x, 21, H("#4ab8e8"))
    lamp(sp, 23, 21, "#5aff7a")
    lamp(sp, 25, 21, "#5ad0ff")
    for x in range(6, 26, 2):
        cv.px(x, 26, fp[0])
    return done(sp)


@obj("trash_bin")
def trash_bin():
    sp = _sp()
    cv = sp.cv
    ground(cv, 9, 22, 29)
    body = P(cv, [(9, 13), (22, 13), (21, 28), (10, 28)])
    pal = cyl_cols(cv, body, H("#3a7a4a"))
    for x in (12, 15, 18):
        cv.vline(x, 15, 26, pal[1])
    lid = E(cv, 15.5, 12.5, 7.5, 2.5)
    lp = shade_mask(cv, lid, "#4a9a5a", "plastic", bevel=1.2)
    cv.rect(14, 10, 17, 10, H("#2a4a30"))
    # a bit of rubbish poking out
    cv.px(19, 10, H("#e8e0c8"))
    cv.px(20, 11, H("#e8e0c8"))
    return done(sp)


@obj("disposal")
def disposal():
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    fp, _, _ = cabinet(cv, 6, 8, 25, 29, 8, "#6a7486", "metal", top="#8a93a3")
    chute = E(cv, 15.5, 11.5, 7.5, 3)
    fill(cv, chute, H("#0e0e12"))
    fill(cv, chute & ~E(cv, 15.5, 12.5, 7.5, 3), H("#3a3f4a"))
    hazard(cv, 7, 24, 18, 2)
    lamp(sp, 22, 23, "#5aff7a")
    cv.rect(9, 22, 17, 26, H("#e8eef4"))
    cv.hline(10, 16, 24, H("#4a505e"))
    return done(sp)


# ============================================================================ cargo
CRATE = {"gen": "#8a7a4a", "eng": "#d8a53a", "med": "#e8eef4", "sec": "#8a2a33", "food": "#4a9a6a", "sci": "#7a5ab8"}


def crate(kind, open_):
    col = CRATE[kind]
    sp = _sp()
    cv = sp.cv
    ground(cv, 4, 27, 30)
    if open_:
        fp, tp, _ = cabinet(cv, 4, 13, 27, 29, 5, col, "paint")
        cv.rect(6, 14, 25, 17, H("#15141c"))
        cv.hline(6, 25, 17, fp[1])
        # packing straw / stuff inside
        for x in range(7, 25, 2):
            cv.px(x, 16, H("#c8a860"))
        # lid leaning back against the wall
        cabinet(cv, 4, 3, 27, 10, 2, col, "paint")
    else:
        fp, tp, _ = cabinet(cv, 4, 9, 27, 29, 6, col, "paint")
        # the lid seam and its reinforcing ribs
        for x in (8, 23):
            cv.vline(x, 16, 28, fp[0])
            cv.vline(x + 1, 16, 28, fp[-1])
        cv.hline(5, 26, 22, fp[0])
        cv.hline(5, 26, 23, fp[-1])
        # latch and label
        cv.rect(14, 17, 17, 20, H("#c8ccd4"))
        cv.px(15, 18, H("#3a3f4a"))
        cv.px(16, 18, H("#3a3f4a"))
        cv.rect(11, 25, 20, 27, H("#e8e0c8"))
        cv.hline(12, 18, 26, H("#6b6454"))
    return done(sp)


for _k in CRATE:
    REDRAWN[f"crate_{_k}"] = (lambda k: (lambda: crate(k, False)))(_k)
    REDRAWN[f"crate_{_k}_open"] = (lambda k: (lambda: crate(k, True)))(_k)
