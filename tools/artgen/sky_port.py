"""Port furniture: what a working quay and a fitted-out shop have standing on them.

None of this does anything mechanically, and all of it is the difference between a stone
rectangle with seven identical sheds on it and a place where people load ships for a
living. The rule for every piece: one clear silhouette, one colour the rest of the sheet
does not use, and enough asymmetry that a row of them does not read as a tiled pattern.
"""
import math

import numpy as np

from common import (ellipse_mask, hexc, ramp, rng_for, rrect_mask, sel_outline)
from objects import Sprite, box3d, contact_shadow


# ------------------------------------------------------------------ the quay
def bollard():
    """Cast iron, sunk into the quay, worn smooth at the neck by a century of rope."""
    sp = Sprite()
    p = ramp("#3a3e46", 7, 0.5)
    for y in range(16, 29):
        t = (y - 16) / 13.0
        w = int(4 + t * 1.5)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, p[int(np.clip(5 - abs(x - 14) * 0.45, 0, 6))])
    m = ellipse_mask(32, 32, 16, 15, 7, 4)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, p[int(np.clip(5 + (13 - xx) * 0.12 + (13 - yy) * 0.2, 0, 6))])
    for x in range(11, 22):
        if sp.cv.get(x, 19)[3] > 0.5:
            sp.cv.px(x, 19, p[6])
    contact_shadow(sp.cv, 11, 21, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def barrel():
    sp = Sprite()
    wd = ramp("#8a6238", 7, 0.45)
    hoop = ramp("#5a5e66", 7, 0.4)
    for y in range(10, 29):
        t = abs(y - 19.5) / 10.0
        w = int(9 - t * 2.0)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, wd[int(np.clip(5 - abs(x - 13) * 0.3, 0, 6))])
    for x in range(8, 25, 3):
        for y in range(11, 28):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, wd[2])
    for y in (13, 19, 26):
        for x in range(5, 28):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, hoop[4])
                sp.cv.px(x, y + 1, hoop[2])
    m = ellipse_mask(32, 32, 16, 10, 7, 3)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, wd[int(np.clip(6 - (yy - 8) * 0.4, 0, 6))])
    for k in range(4):
        sp.cv.px(13 + k, 22 - (k % 2), hexc("#e0dcc8"))
    contact_shadow(sp.cv, 7, 25, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def rope_coil():
    """Flaked down properly, which means somebody here knows their trade."""
    sp = Sprite()
    p = ramp("#b8a878", 7, 0.4)
    for k in range(4):
        r = 10 - k * 2
        for i in range(120):
            a = i / 120.0 * math.tau
            x = int(16 + math.cos(a) * r)
            y = int(21 + math.sin(a) * r * 0.5)
            sp.cv.px(x, y, p[int(np.clip(4 + math.sin(a) * 2 - k * 0.4, 0, 6))])
    for k in range(7):
        sp.cv.px(18 + k, 17 + k // 3, p[6])
    sel_outline(sp.cv, 0.45)
    return sp


def quay_crate():
    sp = Sprite()
    p = box3d(sp.cv, 4, 9, 28, 28, 6, "#8a6a44")
    for x in (9, 17, 24):
        for y in range(10, 28):
            sp.cv.px(x, y, p[6])
            sp.cv.px(x + 1, y, p[2])
    for y in (11, 26):
        for x in range(5, 28):
            sp.cv.px(x, y, p[6] if y == 11 else p[1])
    for k in range(3):
        x0 = 11 + k * 5
        for i in range(4):
            sp.cv.px(x0 + i, 17, hexc("#3a3a44"))
            sp.cv.px(x0 + i, 18, hexc("#3a3a44"))
    contact_shadow(sp.cv, 4, 28, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def shop_mat():
    """A painted square outside a door, tinted per trade by the game. This is why a row
    of seven identical shopfronts is still readable from the far end of the quay."""
    sp = Sprite()
    rng = rng_for("shop_mat")
    for y in range(6, 27):
        for x in range(4, 29):
            edge = x < 6 or x > 26 or y < 8 or y > 24
            sp.cv.px(x, y, (1, 1, 1, 0.85 if not edge else 0.5))
    for _ in range(26):
        sp.cv.px(rng.randint(5, 27), rng.randint(7, 25), (1, 1, 1, 0.33))
    return sp


# ------------------------------------------------------------------ shop fittings
def canvas_roll():
    """Bolts of tarred canvas standing on end, each one a mast's worth."""
    sp = Sprite()
    for k, x0 in enumerate((6, 14, 22)):
        tone = ["#c8bca0", "#b0a488", "#d0c4a8"][k]
        p = ramp(tone, 7, 0.35)
        h = 26 - k * 2
        for y in range(30 - h, 30):
            for x in range(x0, x0 + 6):
                sp.cv.px(x, y, p[int(np.clip(5 - (x - x0) * 0.5, 0, 6))])
        for i in range(40):
            a = i / 40.0 * math.tau * 1.6
            r = 0.6 + i * 0.06
            sp.cv.px(int(x0 + 3 + math.cos(a) * r),
                     int(30 - h + 1 + math.sin(a) * r * 0.6), p[2 if i % 6 < 3 else 6])
    contact_shadow(sp.cv, 6, 27, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def gun_rack():
    """Barrels stood muzzle-up with a chain through the trigger guards."""
    sp = Sprite()
    st = ramp("#6a7280", 7, 0.4)
    wd = ramp("#6a4e33", 7, 0.4)
    for y in range(8, 29):
        sp.cv.px(4, y, wd[4])
        sp.cv.px(27, y, wd[4])
    for x in range(4, 28):
        sp.cv.px(x, 28, wd[3])
        sp.cv.px(x, 8, wd[5])
    for k in range(5):
        x = 7 + k * 4
        for y in range(10, 27):
            sp.cv.px(x, y, st[5])
            sp.cv.px(x + 1, y, st[3])
        for y in range(23, 28):
            sp.cv.px(x, y, wd[int(np.clip(5 - (y - 23), 0, 6))])
            sp.cv.px(x + 1, y, wd[2])
    for x in range(5, 27):
        if x % 2:
            sp.cv.px(x, 20, st[6])
    contact_shadow(sp.cv, 4, 27, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def instrument_case():
    """Glass over green baize, and a row of things all pointing slightly differently."""
    sp = Sprite()
    box3d(sp.cv, 3, 12, 29, 28, 5, "#6a4e33")
    for y in range(13, 22):
        for x in range(5, 28):
            sp.cv.px(x, y, hexc("#25402f"))
    br = ramp("#c8a85a", 7, 0.4)
    for k in range(4):
        cx = 8 + k * 6
        for i in range(30):
            a = i / 30.0 * math.tau
            sp.cv.px(int(cx + math.cos(a) * 2.6), int(17 + math.sin(a) * 2.6), br[4])
        ang = [0.4, 1.9, 3.2, 5.0][k]
        sp.g(int(cx + math.cos(ang) * 1.6), int(17 + math.sin(ang) * 1.6), hexc("#9ad8ff"))
    for k in range(18):
        sp.cv.px(6 + k, 14, (1, 1, 1, 0.3))
    contact_shadow(sp.cv, 3, 29, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def curio_shelf():
    """Objects of uncertain provenance, arranged by somebody with an unexplained system."""
    sp = Sprite()
    rng = rng_for("curio_shelf")
    wd = ramp("#4a3a4a", 7, 0.45)
    for y in range(6, 29):
        for x in range(4, 28):
            sp.cv.px(x, y, wd[int(np.clip(3 + (6 - x) * 0.1, 0, 6))])
    for y in (11, 18, 25):
        for x in range(4, 28):
            sp.cv.px(x, y, wd[6])
            sp.cv.px(x, y + 1, wd[1])
        for _ in range(rng.randint(3, 5)):
            x = rng.randint(6, 25)
            h = rng.randint(2, 5)
            tone = rng.choice(["#c8a85a", "#8ac8b8", "#c88ae8", "#d8d0bc", "#8a9ad8"])
            tp = ramp(tone, 7, 0.4)
            for k in range(h):
                sp.cv.px(x, y - 1 - k, tp[int(np.clip(4 + k, 0, 6))])
                if rng.random() < 0.5:
                    sp.cv.px(x + 1, y - 1 - k, tp[2])
            if rng.random() < 0.4:
                sp.g(x, y - h, hexc(tone))
    contact_shadow(sp.cv, 4, 27, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def build_into(pk):
    pk.add("bollard", bollard())
    pk.add("barrel", barrel())
    pk.add("rope_coil", rope_coil())
    pk.add("quay_crate", quay_crate())
    pk.add("shop_mat", shop_mat())
    pk.add("canvas_roll", canvas_roll())
    pk.add("gun_rack", gun_rack())
    pk.add("instrument_case", instrument_case())
    pk.add("curio_shelf", curio_shelf())
