"""Skyfarer objects: ship machinery and island scenery.

Two families with different jobs. Ship fittings are hard-edged, riveted and readable at a
glance, because you need to find the boiler in a hurry. Island scenery is soft, silhouetted
and varied, because its job is to make an island look like somewhere rather than like a
field of identical props.

Everything is drawn with objects.py's own primitives (box3d, contact_shadow, the Sprite
glow layer) so the new pieces sit on the same shelf as Artic9's.
"""
import math

import numpy as np

from common import (T, Canvas, ellipse_mask, fbm, hexc, mix, ramp, rng_for,
                    sel_outline, shade, value_noise)
from objects import Sprite, box3d, contact_shadow, OUTLINE


def _tree(sp, rng, trunk_col, leaf_col, h=26, spread=11, leafy=0.85, droop=0.0):
    """A generic tree: trunk, then a blob canopy of clustered leaf dabs."""
    cx = 16
    tp = ramp(trunk_col, 7, 0.45)
    base_y = 30
    top_y = base_y - h
    # trunk, leaning slightly
    lean = rng.uniform(-0.12, 0.12)
    for y in range(top_y + 4, base_y + 1):
        t = (base_y - y) / max(1, h)
        w = max(1, int(3 - t * 1.6))
        x = int(cx + lean * (base_y - y))
        for dx in range(-w, w + 1):
            i = 4 if dx < 0 else (2 if dx > 0 else 3)
            sp.cv.px(x + dx, y, tp[i])
    # a couple of limbs
    for _ in range(rng.randint(1, 3)):
        y0 = rng.randint(top_y + 6, base_y - 6)
        d = rng.choice([-1, 1])
        for k in range(rng.randint(3, 6)):
            sp.cv.px(int(cx + lean * (base_y - y0)) + d * k, y0 - k // 2, tp[2])
    # canopy
    lp = ramp(leaf_col, 7, 0.5)
    cyy = top_y + 7
    for _ in range(rng.randint(5, 8)):
        ox = rng.randint(-spread, spread)
        oy = rng.randint(-5, 6) + int(droop * abs(ox))
        r = rng.randint(4, 7)
        m = ellipse_mask(T, T, cx + ox, cyy + oy, r, r * rng.uniform(0.6, 0.95))
        ys, xs = np.nonzero(m)
        for (yy, xx) in zip(ys, xs):
            if rng.random() > leafy:
                continue
            lit = (xx - (cx + ox)) * -0.12 + (yy - (cyy + oy)) * -0.16
            i = int(np.clip(3 + lit, 0, 6))
            sp.cv.px(xx, yy, lp[i])
    contact_shadow(sp.cv, cx - 4, cx + 4, base_y + 1)
    sel_outline(sp.cv, 0.5)
    return sp


def sky_oak():
    return _tree(Sprite(), rng_for("sky_oak"), "#6b4f32", "#4f7a34", h=27, spread=12)


def thorn_tree():
    sp = _tree(Sprite(), rng_for("thorn_tree"), "#33281f", "#2f5128", h=25, spread=10, leafy=0.62)
    rng = rng_for("thorn_tree_spikes")
    for _ in range(18):
        x, y = rng.randint(6, 25), rng.randint(6, 28)
        if sp.cv.get(x, y)[3] > 0.5:
            sp.cv.px(x, y, hexc("#c8b070"))
    return sp


def frost_pine():
    sp = Sprite()
    rng = rng_for("frost_pine")
    tp = ramp("#3a2e22", 7, 0.4)
    for y in range(12, 31):
        for dx in range(-1, 2):
            sp.cv.px(16 + dx, y, tp[3 + dx])
    lp = ramp("#26402c", 7, 0.5)
    snow = ramp("#dbe7f5", 7, 0.3)
    for tier in range(5):
        yy = 6 + tier * 5
        w = 3 + tier * 2
        for x in range(16 - w, 16 + w + 1):
            d = abs(x - 16)
            hh = 4 - d // 2
            for y in range(yy, yy + max(1, hh)):
                i = int(np.clip(4 - d * 0.35, 0, 6))
                sp.cv.px(x, y, lp[i])
            if rng.random() < 0.45:
                sp.cv.px(x, yy, snow[5])
    contact_shadow(sp.cv, 12, 20, 31)
    sel_outline(sp.cv, 0.5)
    return sp


def glass_tree():
    sp = Sprite()
    rng = rng_for("glass_tree")
    p = ramp("#9fc6de", 7, 0.55)
    for _ in range(9):
        x0, y0 = 16 + rng.randint(-2, 2), 30
        ang = rng.uniform(-1.1, 1.1)
        ln = rng.randint(10, 20)
        for k in range(ln):
            x = int(x0 + math.sin(ang) * k)
            y = int(y0 - math.cos(ang) * k * 0.92)
            i = int(np.clip(2 + k * 0.22, 0, 6))
            sp.cv.px(x, y, p[i])
            if k > ln - 4:
                sp.g(x, y, p[6])
    contact_shadow(sp.cv, 12, 20, 31)
    sel_outline(sp.cv, 0.4)
    return sp


def cap_tower():
    """A fungal stalk with a glowing cap."""
    sp = Sprite()
    rng = rng_for("cap_tower")
    st = ramp("#cbbfa8", 7, 0.35)
    for y in range(12, 31):
        w = 2 if y > 18 else 3
        for dx in range(-w, w + 1):
            sp.cv.px(16 + dx, y, st[4 + (1 if dx < 0 else (-1 if dx > 0 else 0))])
    cp = ramp("#8a4f86", 7, 0.5)
    m = ellipse_mask(T, T, 16, 12, 11, 7)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        if yy > 13:
            continue
        i = int(np.clip(4 - (yy - 5) * 0.4 + (16 - xx) * 0.06, 0, 6))
        sp.cv.px(xx, yy, cp[i])
    for _ in range(8):
        x, y = rng.randint(7, 25), rng.randint(5, 12)
        if sp.cv.get(x, y)[3] > 0.5:
            sp.g(x, y, hexc("#e6b8ff"))
    contact_shadow(sp.cv, 12, 20, 31)
    sel_outline(sp.cv, 0.5)
    return sp


def _clump(name, col, count=26, y0=18, y1=30, spread=11, height=8, tip=None):
    """Grass/reed/fern style: upright strokes from a common base."""
    sp = Sprite()
    rng = rng_for(name)
    p = ramp(col, 7, 0.5)
    tipc = hexc(tip) if tip else None
    for _ in range(count):
        x = 16 + rng.randint(-spread, spread)
        base = rng.randint(y1 - 3, y1)
        h = rng.randint(height // 2, height)
        bend = rng.uniform(-0.35, 0.35)
        for k in range(h):
            xx = int(x + bend * k)
            yy = base - k
            if yy < y0 - 4:
                break
            i = int(np.clip(2 + k * 0.45, 0, 6))
            sp.cv.px(xx, yy, p[i])
        if tipc is not None and rng.random() < 0.4:
            sp.cv.px(int(x + bend * h), base - h, tipc)
    contact_shadow(sp.cv, 8, 24, y1 + 1, 0.22)
    sel_outline(sp.cv, 0.45)
    return sp


def _rockish(name, col, w=11, h=9, cy=25, glow=None, spiky=False):
    """A lump of something: boulder, shard, pillar, stump."""
    sp = Sprite()
    rng = rng_for(name)
    p = ramp(col, 7, 0.55)
    if spiky:
        for _ in range(rng.randint(3, 6)):
            x0 = 16 + rng.randint(-w, w)
            hh = rng.randint(6, h * 2)
            ww = rng.randint(1, 3)
            for y in range(cy + 4 - hh, cy + 5):
                t = (cy + 4 - y) / max(1, hh)
                cw = max(0, int(ww * (1 - t)))
                for dx in range(-cw, cw + 1):
                    i = int(np.clip(3 + dx * -0.7 + t * 1.6, 0, 6))
                    sp.cv.px(x0 + dx, y, p[i])
            if glow:
                sp.g(x0, cy + 4 - hh, hexc(glow))
    else:
        m = ellipse_mask(T, T, 16, cy, w, h)
        n = fbm(T, T, rng.randint(0, 999), 3, 8)
        ys, xs = np.nonzero(m)
        for (yy, xx) in zip(ys, xs):
            lit = (16 - xx) * 0.09 + (cy - yy) * 0.14 + (n[yy, xx] - 0.5) * 2.0
            i = int(np.clip(3 + lit, 0, 6))
            sp.cv.px(xx, yy, p[i])
        if glow:
            for _ in range(rng.randint(2, 5)):
                x, y = rng.randint(16 - w, 16 + w), rng.randint(cy - h, cy + h)
                if sp.cv.get(x, y)[3] > 0.5:
                    sp.g(x, y, hexc(glow))
    contact_shadow(sp.cv, 16 - w, 16 + w, cy + h + 1)
    sel_outline(sp.cv, 0.5)
    return sp


def _flat(name, col, r=12, speck=None):
    """Ground-hugging scenery: mats, pools, crusts, drifts."""
    sp = Sprite()
    rng = rng_for(name)
    p = ramp(col, 7, 0.4)
    m = ellipse_mask(T, T, 16, 22, r, r * 0.55)
    n = fbm(T, T, rng.randint(0, 999), 3, 7)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        if n[yy, xx] < 0.36:
            continue
        i = int(np.clip(3 + (n[yy, xx] - 0.5) * 3.5, 0, 6))
        sp.cv.px(xx, yy, p[i])
    if speck:
        for _ in range(rng.randint(4, 10)):
            x, y = rng.randint(16 - r, 16 + r), rng.randint(16, 28)
            if sp.cv.get(x, y)[3] > 0.5:
                sp.g(x, y, hexc(speck))
    sel_outline(sp.cv, 0.35)
    return sp


def _bones(name, col="#cfc6ae", arch=True):
    sp = Sprite()
    rng = rng_for(name)
    p = ramp(col, 7, 0.4)
    if arch:
        for side in (-1, 1):
            for k in range(20):
                t = k / 19.0
                x = int(16 + side * (3 + t * 11))
                y = int(29 - math.sin(t * math.pi * 0.62) * 26)
                for dx in (-1, 0, 1):
                    sp.cv.px(x + dx, y, p[4 + dx])
    else:
        for _ in range(rng.randint(6, 11)):
            x = rng.randint(6, 25)
            y = rng.randint(20, 29)
            ln = rng.randint(4, 10)
            d = rng.choice([(1, 0), (1, -1), (0, -1)])
            for k in range(ln):
                sp.cv.px(x + d[0] * k, y + d[1] * k, p[rng.randint(3, 6)])
    contact_shadow(sp.cv, 8, 24, 30)
    sel_outline(sp.cv, 0.5)
    return sp


# ======================================================================== ship fittings
def ship_wheel():
    sp = Sprite()
    p = ramp("#7a5a38", 7, 0.5)
    br = ramp("#b8923a", 7, 0.45)
    cx, cy = 16, 18
    for k in range(120):
        a = k / 120.0 * math.tau
        for r in (9, 10):
            x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.72)
            sp.cv.px(x, y, p[4 if math.sin(a) < 0 else 2])
    for s in range(8):
        a = s / 8.0 * math.tau
        for r in range(2, 13):
            x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.72)
            sp.cv.px(x, y, p[3])
            if r > 10:
                sp.cv.px(x, y, p[5])
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            sp.cv.px(cx + dx, cy + dy, br[4])
    # pedestal
    box3d(sp.cv, 13, 24, 19, 30, 2, "#5a4a36")
    contact_shadow(sp.cv, 11, 21, 31)
    sel_outline(sp.cv, 0.55)
    return sp


def nav_table():
    sp = Sprite()
    rng = rng_for("nav_table")
    box3d(sp.cv, 3, 12, 28, 29, 6, "#6b5236")
    # chart
    for y in range(14, 24):
        for x in range(6, 26):
            sp.cv.px(x, y, hexc("#d8cca6" if (x + y) % 17 else "#c4b68c"))
    for _ in range(9):
        x0, y0 = rng.randint(7, 22), rng.randint(15, 22)
        for k in range(rng.randint(2, 6)):
            sp.cv.px(x0 + k, y0 + (k % 2), hexc("#6a5a3a"))
    for _ in range(4):
        sp.cv.px(rng.randint(7, 24), rng.randint(15, 22), hexc("#a8402a"))
    contact_shadow(sp.cv, 3, 28, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def thruster(dirn):
    """Aether thruster. `dirn` is which way the nozzle points (the exhaust end)."""
    sp = Sprite()
    body = ramp("#5e6470", 7, 0.45)
    hot = ramp("#e88a2a", 7, 0.5)
    box3d(sp.cv, 5, 10, 26, 27, 5, "#5e6470")
    # ribs
    for x in range(7, 25, 4):
        for y in range(11, 27):
            sp.cv.px(x, y, body[2])
    # nozzle on the exhaust side
    if dirn == "w":
        for y in range(14, 24):
            for x in range(0, 6):
                sp.cv.px(x, y, body[3 if x % 2 else 4])
        for y in range(16, 22):
            sp.g(1, y, hot[5])
            sp.g(0, y, hot[6])
    elif dirn == "e":
        for y in range(14, 24):
            for x in range(26, 32):
                sp.cv.px(x, y, body[3 if x % 2 else 4])
        for y in range(16, 22):
            sp.g(30, y, hot[5])
            sp.g(31, y, hot[6])
    elif dirn == "n":
        for y in range(0, 10):
            for x in range(11, 21):
                sp.cv.px(x, y, body[3 if y % 2 else 4])
        for x in range(13, 19):
            sp.g(x, 1, hot[5])
            sp.g(x, 0, hot[6])
    else:
        for y in range(27, 32):
            for x in range(11, 21):
                sp.cv.px(x, y, body[3 if y % 2 else 4])
        for x in range(13, 19):
            sp.g(x, 30, hot[5])
            sp.g(x, 31, hot[6])
    contact_shadow(sp.cv, 5, 26, 28)
    sel_outline(sp.cv, 0.5)
    return sp


def propeller(dirn):
    sp = Sprite()
    rng = rng_for("prop" + dirn)
    p = ramp("#6a7280", 7, 0.45)
    cx, cy = 16, 18
    for k in range(140):
        a = k / 140.0 * math.tau
        x, y = int(cx + math.cos(a) * 12), int(cy + math.sin(a) * 9)
        sp.cv.px(x, y, p[3])
    for b in range(3):
        a = b / 3.0 * math.tau + 0.4
        for r in range(2, 11):
            x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.75)
            sp.cv.px(x, y, p[5 if b == 0 else 4])
    box3d(sp.cv, 14, 16, 18, 21, 2, "#4a5260")
    contact_shadow(sp.cv, 6, 26, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def lift_cell(stage):
    """A braced gas bladder. Stage 0 full and taut, 2 flat and wrinkled."""
    sp = Sprite()
    rng = rng_for(f"liftcell{stage}")
    fill = [1.0, 0.72, 0.42][stage]
    p = ramp("#7fa7c8", 7, 0.5)
    rope = ramp("#8a7450", 7, 0.4)
    ry = int(4 + 9 * fill)
    m = ellipse_mask(T, T, 16, 26 - ry, 11, ry)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        lit = (16 - xx) * 0.10 + ((26 - ry) - yy) * 0.13
        i = int(np.clip(3 + lit, 0, 6))
        sp.cv.px(xx, yy, p[i])
    if stage > 0:
        for _ in range(stage * 5):
            x, y = rng.randint(7, 24), rng.randint(26 - ry * 2, 26)
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, p[1])
    # rope harness
    for x in (10, 16, 22):
        for y in range(26 - ry * 2, 27):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, rope[3])
    for x in range(5, 28):
        sp.cv.px(x, 27, rope[4])
    box3d(sp.cv, 8, 27, 24, 30, 1, "#54452f")
    contact_shadow(sp.cv, 8, 24, 31)
    sel_outline(sp.cv, 0.5)
    return sp


def boiler(lit_):
    sp = Sprite()
    p = box3d(sp.cv, 6, 6, 25, 29, 6, "#5a4a42")
    # rivets and bands
    for y in (12, 20, 26):
        for x in range(7, 25):
            sp.cv.px(x, y, p[2])
        for x in range(8, 25, 4):
            sp.cv.px(x, y, p[5])
    # firebox door
    for y in range(21, 27):
        for x in range(11, 21):
            sp.cv.px(x, y, p[1])
    if lit_:
        for y in range(22, 26):
            for x in range(12, 20):
                sp.g(x, y, hexc("#ff9a30" if (x + y) % 3 else "#ffd06a"))
    # pressure gauge
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                sp.cv.px(22 + dx, 15 + dy, hexc("#d8d0b8"))
    sp.cv.px(22, 15, hexc("#a8302a"))
    sp.cv.px(23, 14, hexc("#a8302a"))
    contact_shadow(sp.cv, 6, 25, 30)
    sel_outline(sp.cv, 0.55)
    return sp


def dynamo(on):
    sp = Sprite()
    p = box3d(sp.cv, 5, 11, 26, 28, 5, "#4f5866")
    for x in range(7, 25, 3):
        for y in range(17, 28):
            sp.cv.px(x, y, p[2])
    # belt wheel
    for k in range(90):
        a = k / 90.0 * math.tau
        sp.cv.px(int(23 + math.cos(a) * 5), int(20 + math.sin(a) * 5), p[5])
    if on:
        for y in range(13, 16):
            sp.g(9 + (y % 2), y, hexc("#8ae8ff"))
        sp.g(12, 14, hexc("#c8f4ff"))
    contact_shadow(sp.cv, 5, 26, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def fuel_bunker():
    sp = Sprite()
    p = box3d(sp.cv, 6, 9, 25, 29, 5, "#4a5442")
    for y in (15, 22):
        for x in range(7, 25):
            sp.cv.px(x, y, p[2])
    # hazard stripe and filler cap
    for x in range(8, 24):
        sp.cv.px(x, 18, hexc("#c8a83a" if (x // 2) % 2 else "#2a2620"))
    for dx in range(-3, 4):
        for dy in range(-2, 3):
            sp.cv.px(16 + dx, 11 + dy, p[5 if dy < 0 else 3])
    contact_shadow(sp.cv, 6, 25, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def ballast_tank():
    sp = Sprite()
    p = box3d(sp.cv, 5, 12, 26, 29, 5, "#48566a")
    for k in range(80):
        a = k / 80.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 10), int(20 + math.sin(a) * 7), p[2])
    for x in range(9, 24):
        sp.cv.px(x, 16, p[5])
    contact_shadow(sp.cv, 5, 26, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def ship_mast():
    sp = Sprite()
    p = ramp("#6b5236", 7, 0.45)
    sail = ramp("#cfc3a6", 7, 0.3)
    for y in range(2, 30):
        for dx in (-1, 0, 1):
            sp.cv.px(16 + dx, y, p[4 + dx])
    # furled sail on the yard
    for x in range(5, 28):
        sp.cv.px(x, 9, p[3])
    for x in range(6, 27):
        for y in range(10, 14):
            sp.cv.px(x, y, sail[4 if (x % 3) else 3])
    for x in range(6, 27, 3):
        sp.cv.px(x, 14, sail[2])
    contact_shadow(sp.cv, 13, 19, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def gun_mount(dirn):
    sp = Sprite()
    p = ramp("#4a5058", 7, 0.5)
    box3d(sp.cv, 11, 20, 21, 29, 3, "#3f444c")
    d = {"e": (1, 0), "w": (-1, 0), "n": (0, -1), "s": (0, 1)}[dirn]
    for k in range(13):
        x = int(16 + d[0] * k)
        y = int(20 + d[1] * k)
        for o in (-1, 0, 1):
            if d[0]:
                sp.cv.px(x, y + o, p[4 + o])
            else:
                sp.cv.px(x + o, y, p[4 + o])
    contact_shadow(sp.cv, 10, 22, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def cargo_winch():
    sp = Sprite()
    p = box3d(sp.cv, 4, 14, 27, 29, 4, "#5a5248")
    for k in range(70):
        a = k / 70.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 8), int(21 + math.sin(a) * 5), p[5])
    for x in range(9, 24):
        sp.cv.px(x, 21, p[2])
    # boom
    for k in range(14):
        sp.cv.px(20 + k // 2, 13 - k, p[4])
    contact_shadow(sp.cv, 4, 27, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def deck_lantern():
    sp = Sprite()
    p = ramp("#5a5044", 7, 0.4)
    for y in range(8, 12):
        for x in range(13, 20):
            sp.cv.px(x, y, p[4])
    for y in range(12, 22):
        for x in range(12, 21):
            if x in (12, 20):
                sp.cv.px(x, y, p[2])
            else:
                sp.g(x, y, hexc("#ffd88a" if (x + y) % 3 else "#ffb452"))
    for x in range(12, 21):
        sp.cv.px(x, 22, p[3])
    for y in range(4, 9):
        sp.cv.px(16, y, p[3])
    sel_outline(sp.cv, 0.5)
    return sp


def rudder_post():
    sp = Sprite()
    p = ramp("#6b5236", 7, 0.45)
    box3d(sp.cv, 13, 12, 19, 29, 3, "#6b5236")
    for k in range(8):
        sp.cv.px(20 + k, 16 - k // 2, p[4])
        sp.cv.px(12 - k, 16 - k // 2, p[3])
    contact_shadow(sp.cv, 12, 20, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def galley_stove():
    sp = Sprite()
    p = box3d(sp.cv, 5, 11, 26, 29, 5, "#3f4450")
    for (cx, cy) in ((11, 14), (20, 14)):
        for k in range(60):
            a = k / 60.0 * math.tau
            sp.cv.px(int(cx + math.cos(a) * 4), int(cy + math.sin(a) * 2.6), p[2])
    for y in range(20, 27):
        for x in range(9, 23):
            sp.cv.px(x, y, p[1])
    sp.g(15, 23, hexc("#ff9a30"))
    sp.g(16, 23, hexc("#ffc45a"))
    contact_shadow(sp.cv, 5, 26, 30)
    sel_outline(sp.cv, 0.5)
    return sp


# ======================================================================== registration
SCENERY = [
    # name,               builder
    ("bush_berry", lambda: _clump("bush_berry", "#38602c", 30, 14, 29, 11, 12, "#a83a4a")),
    ("wildflowers", lambda: _clump("wildflowers", "#4e7a3a", 24, 20, 30, 12, 7, "#e8d86a")),
    ("tall_reed", lambda: _clump("tall_reed", "#7a7a40", 26, 10, 30, 9, 17)),
    ("reed_bed", lambda: _clump("reed_bed", "#5e6e38", 32, 10, 30, 12, 18)),
    ("fern_giant", lambda: _clump("fern_giant", "#2f6038", 30, 10, 30, 12, 16)),
    ("vine_curtain", lambda: _clump("vine_curtain", "#355a2c", 26, 2, 22, 13, 20)),
    ("cliff_moss", lambda: _flat("cliff_moss", "#3f6448", 11)),
    ("mycelium_mat", lambda: _flat("mycelium_mat", "#8a7a9a", 12, "#d8c8f0")),
    ("crust_shelf", lambda: _flat("crust_shelf", "#c9c6bb", 12)),
    ("brine_pool", lambda: _flat("brine_pool", "#5a8090", 12, "#bfe4ee")),
    ("refraction_pool", lambda: _flat("refraction_pool", "#6a90b8", 12, "#e8f6ff")),
    ("snow_drift", lambda: _flat("snow_drift", "#cfdcef", 13)),
    ("lava_crust", lambda: _flat("lava_crust", "#4a2418", 12, "#ff8a30")),
    ("bone_pile", lambda: _bones("bone_pile", arch=False)),
    ("rib_arch", lambda: _bones("rib_arch", arch=True)),
    ("dune_bone", lambda: _bones("dune_bone", "#d8cfae", arch=False)),
    ("boulder_sky", lambda: _rockish("boulder_sky", "#6e6a62", 11, 9)),
    ("bog_stump", lambda: _rockish("bog_stump", "#4a3f2e", 10, 8)),
    ("burnt_stump", lambda: _rockish("burnt_stump", "#2e2a26", 9, 8)),
    ("cinder_spire", lambda: _rockish("cinder_spire", "#3c3438", 8, 10, 24, "#ff7a2a", spiky=True)),
    ("ash_pillar", lambda: _rockish("ash_pillar", "#5a5450", 7, 9, 24, None, spiky=True)),
    ("salt_pillar", lambda: _rockish("salt_pillar", "#c9c6bb", 7, 9, 24, None, spiky=True)),
    ("ice_spire", lambda: _rockish("ice_spire", "#9fc6de", 6, 10, 24, "#dff2ff", spiky=True)),
    ("obsidian_shard", lambda: _rockish("obsidian_shard", "#26232c", 6, 8, 25, None, spiky=True)),
    ("glass_shard", lambda: _rockish("glass_shard", "#a8c4d4", 6, 9, 25, "#e8f8ff", spiky=True)),
    ("prism_shard", lambda: _rockish("prism_shard", "#8a7ad8", 6, 10, 25, "#d8c8ff", spiky=True)),
    ("wind_sculpt", lambda: _rockish("wind_sculpt", "#7a746a", 12, 10)),
    ("sand_arch", lambda: _bones("sand_arch", "#c2a874", arch=True)),
    ("skull_huge", lambda: _rockish("skull_huge", "#cfc6ae", 13, 10)),
    ("marrow_well", lambda: _flat("marrow_well", "#a89880", 10, "#e0c8a0")),
    ("eyrie_nest", lambda: _flat("eyrie_nest", "#6a5a3e", 11)),
    ("frozen_carcass", lambda: _rockish("frozen_carcass", "#8fa8bd", 12, 8)),
    ("gas_vent", lambda: _flat("gas_vent", "#4a4a38", 9, "#9ad86a")),
    ("fumarole", lambda: _flat("fumarole", "#6a5a30", 9, "#e8d85a")),
    ("fen_lantern", lambda: _clump("fen_lantern", "#3a5a44", 14, 14, 29, 8, 13, "#8ae8c8")),
    ("spore_pod", lambda: _rockish("spore_pod", "#7a5a86", 8, 9, 24, "#d8a8f0")),
    ("puffball", lambda: _rockish("puffball", "#a89880", 8, 7)),
    ("cactus_sky", lambda: _rockish("cactus_sky", "#4a7a4a", 6, 11, 23, None, spiky=True)),
]


def build_into(pk):
    """Add every Skyfarer object. `pk` is objects.build's Packer."""
    from sky_objects2 import build_into as sky2
    for name, fn in SCENERY:
        pk.add(name, fn())
    sky2(pk)
    pk.add("sky_oak", sky_oak())
    pk.add("thorn_tree", thorn_tree())
    pk.add("frost_pine", frost_pine())
    pk.add("glass_tree", glass_tree())
    pk.add("cap_tower", cap_tower())
    # ship fittings
    pk.add("ship_wheel", ship_wheel())
    pk.add("nav_table", nav_table())
    pk.add("rudder_post", rudder_post())
    pk.add("ship_mast", ship_mast())
    pk.add("boiler", boiler(False))
    pk.add("boiler_lit", boiler(True))
    pk.add("dynamo", dynamo(False))
    pk.add("dynamo_on", dynamo(True))
    pk.add("fuel_bunker", fuel_bunker())
    pk.add("ballast_tank", ballast_tank())
    pk.add("cargo_winch", cargo_winch())
    pk.add("deck_lantern", deck_lantern())
    pk.add("galley_stove", galley_stove())
    for s in range(3):
        pk.add(f"lift_cell_{s}", lift_cell(s))
    for d in ("n", "e", "s", "w"):
        pk.add(f"thruster_{d}", thruster(d))
        pk.add(f"propeller_{d}", propeller(d))
        pk.add(f"gun_{d}", gun_mount(d))
