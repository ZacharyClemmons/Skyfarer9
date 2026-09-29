"""Skyfarer items: the ores you dig out of an island and the kit you carry off it.

Small 32x32 icons in items.py's idiom — chunky silhouette, one clear read at a glance,
selective outline. These are seen in inventory slots and lying on a deck, so legibility
beats detail every time.
"""
import math

import numpy as np

from common import (Canvas, ellipse_mask, hexc, mix, ramp, rng_for, rrect_mask,
                    sel_outline, shade)
from objects import Sprite
from items import _fin, thick_line


def ore(name, rock="#6e6a62", vein="#4a8ad8", glint="#9ad0ff", count=3):
    """A few lumps of stone with a mineral running through them."""
    sp = Sprite()
    rng = rng_for("ore" + name)
    rp = ramp(rock, 7, 0.5)
    vp = ramp(vein, 7, 0.5)
    spots = [(11, 21, 6), (20, 19, 5), (15, 13, 4)][:count]
    for (cx, cy, r) in spots:
        m = ellipse_mask(32, 32, cx, cy, r, r * 0.85)
        ys, xs = np.nonzero(m)
        for (yy, xx) in zip(ys, xs):
            lit = (cx - xx) * 0.13 + (cy - yy) * 0.17
            sp.cv.px(xx, yy, rp[int(np.clip(3 + lit, 0, 6))])
        # the vein: a jagged seam across each lump
        x, y = cx - r, cy
        for k in range(r * 2):
            x += 1
            y += rng.choice([-1, 0, 0, 1])
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, vp[3])
                if rng.random() < 0.45:
                    sp.g(x, y - 1, hexc(glint))
    _fin(sp.cv)
    return sp


def fuel_can():
    sp = Sprite()
    p = ramp("#4a5442", 7, 0.45)
    m = rrect_mask(32, 32, 9, 8, 23, 27, 2)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        lit = (10 - xx) * 0.10 + (10 - yy) * 0.07
        sp.cv.px(xx, yy, p[int(np.clip(4 + lit, 0, 6))])
    # cap and handle
    for x in range(13, 19):
        sp.cv.px(x, 6, p[5])
        sp.cv.px(x, 7, p[3])
    for x in range(11, 22):
        sp.cv.px(x, 5, p[2])
    # hazard flash
    for x in range(11, 22):
        sp.cv.px(x, 17, hexc("#c8a83a" if (x // 2) % 2 else "#2a2620"))
    sp.cv.px(15, 12, p[6])
    _fin(sp.cv)
    return sp


def glider_pack():
    sp = Sprite()
    p = ramp("#8a7450", 7, 0.45)
    silk = ramp("#cfc3a6", 7, 0.3)
    m = rrect_mask(32, 32, 10, 9, 22, 26, 2)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, p[int(np.clip(4 + (11 - xx) * 0.1, 0, 6))])
    # folded canopy showing at the top
    for y in range(10, 15):
        for x in range(11, 22):
            sp.cv.px(x, y, silk[4 if (x + y) % 3 else 3])
    # straps
    for y in range(9, 27):
        sp.cv.px(12, y, p[2])
        sp.cv.px(20, y, p[2])
    # rip cord
    for k in range(6):
        sp.cv.px(23 + k // 2, 16 + k, hexc("#c84a3a"))
    _fin(sp.cv)
    return sp


def grapple_gun():
    sp = Sprite()
    p = ramp("#5a6270", 7, 0.5)
    steel = ramp("#98a2b0", 7, 0.4)
    # body
    m = rrect_mask(32, 32, 7, 14, 22, 21, 1)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, p[int(np.clip(4 + (15 - yy) * 0.2, 0, 6))])
    # drum of line
    for k in range(70):
        a = k / 70.0 * math.tau
        sp.cv.px(int(11 + math.cos(a) * 4), int(18 + math.sin(a) * 4), steel[3])
    sp.cv.px(11, 18, steel[5])
    # grip
    for y in range(21, 27):
        for x in range(9, 13):
            sp.cv.px(x, y, p[2])
    # barrel and hook
    for x in range(22, 28):
        sp.cv.px(x, 16, steel[4])
        sp.cv.px(x, 17, steel[2])
    for k in range(4):
        sp.cv.px(28 + k // 2, 15 - k, steel[5])
    sp.cv.px(29, 12, steel[6])
    _fin(sp.cv)
    return sp


def sky_compass():
    sp = Sprite()
    br = ramp("#b8923a", 7, 0.45)
    for k in range(120):
        a = k / 120.0 * math.tau
        for r in (10, 11):
            sp.cv.px(int(16 + math.cos(a) * r), int(17 + math.sin(a) * r), br[4 if math.sin(a) < 0 else 2])
    m = ellipse_mask(32, 32, 16, 17, 9, 9)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, hexc("#1b2740"))
    # needle, pointing off toward whatever land there is
    for k in range(-7, 8):
        x = int(16 + k * 0.72)
        y = int(17 - k * 0.55)
        sp.g(x, y, hexc("#e85a4a" if k > 0 else "#d8dce8"))
    sp.cv.px(16, 17, br[6])
    # hinge lid
    for x in range(11, 22):
        sp.cv.px(x, 5, br[3])
    _fin(sp.cv)
    return sp


def spyglass():
    sp = Sprite()
    br = ramp("#b8923a", 7, 0.5)
    lea = ramp("#5a4030", 7, 0.4)
    # three drawtubes, fat to thin
    segs = [(5, 13, 11, 19), (11, 14, 19, 18), (19, 15, 27, 18)]
    for i, (x0, y0, x1, y1) in enumerate(segs):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                pal = lea if i == 1 else br
                sp.cv.px(x, y, pal[int(np.clip(5 - (y - y0) * 0.9, 0, 6))])
        for y in range(y0, y1 + 1):
            sp.cv.px(x1, y, br[1])
    # glass at the wide end
    for y in range(14, 19):
        sp.g(6, y, hexc("#9fd0ec"))
    _fin(sp.cv)
    return sp


def breathing_rig():
    sp = Sprite()
    p = ramp("#4a5262", 7, 0.45)
    steel = ramp("#b0b8c4", 7, 0.35)
    # mask
    m = ellipse_mask(32, 32, 13, 14, 7, 8)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, p[int(np.clip(4 + (10 - xx) * 0.12, 0, 6))])
    for y in range(11, 17):
        for x in range(9, 14):
            sp.cv.px(x, y, hexc("#2a3140"))
    sp.cv.px(10, 12, steel[5])
    # bottle
    mm = rrect_mask(32, 32, 20, 12, 26, 27, 2)
    ys, xs = np.nonzero(mm)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, steel[int(np.clip(4 + (21 - xx) * 0.15, 0, 6))])
    for x in range(21, 26):
        sp.cv.px(x, 18, hexc("#3a8ad8"))
    # hose
    for k in range(9):
        sp.cv.px(15 + k, 18 + int(math.sin(k * 0.7) * 2), p[2])
    _fin(sp.cv)
    return sp


def salvage_scrap():
    sp = Sprite()
    rng = rng_for("salvage_scrap")
    p = ramp("#77808e", 7, 0.5)
    rust = ramp("#8a5a3a", 7, 0.4)
    for _ in range(7):
        x0, y0 = rng.randint(6, 22), rng.randint(12, 25)
        w, h = rng.randint(4, 10), rng.randint(2, 4)
        ang = rng.choice([0, 0, 1])
        for y in range(h):
            for x in range(w):
                xx, yy = (x0 + x, y0 + y) if not ang else (x0 + y, y0 + x)
                col = rust if rng.random() < 0.3 else p
                sp.cv.px(xx, yy, col[int(np.clip(4 - y, 0, 6))])
    # a bearing that still turns
    for k in range(50):
        a = k / 50.0 * math.tau
        sp.cv.px(int(21 + math.cos(a) * 4), int(20 + math.sin(a) * 4), p[5])
    _fin(sp.cv)
    return sp


def ship_rig():
    """A shipwright's strap: saw, brace, mallet and a roll of fixings."""
    sp = Sprite()
    leather = ramp("#6a4e33", 7, 0.45)
    steel = ramp("#98a2b0", 7, 0.4)
    wood = ramp("#a8814a", 7, 0.4)
    # the strap
    for y in range(11, 24):
        for x in range(6, 26):
            if (x - 6 + y) % 9 < 6:
                sp.cv.px(x, y, leather[int(np.clip(4 - (y - 11) * 0.2, 0, 6))])
    for x in range(6, 26):
        sp.cv.px(x, 11, leather[6])
        sp.cv.px(x, 23, leather[1])
    # saw blade across it
    for x in range(7, 25):
        sp.cv.px(x, 15, steel[5])
        sp.cv.px(x, 16, steel[3])
        if x % 2:
            sp.cv.px(x, 17, steel[2])
    for x in range(7, 11):
        sp.cv.px(x, 14, wood[4])
    # mallet head and a brace
    for y in range(18, 22):
        for x in range(18, 24):
            sp.cv.px(x, y, wood[int(np.clip(5 - (y - 18), 0, 6))])
    for y in range(19, 27):
        sp.cv.px(12, y, steel[3])
    sp.cv.px(12, 27, steel[5])
    _fin(sp.cv)
    return sp


def build_into(pk):
    from sky_items2 import build_into as sky2
    sky2(pk)
    pk.add("ship_rig", ship_rig())
    pk.add("ore_aetherite", ore("aetherite", vein="#4a8ad8", glint="#9ad0ff"))
    pk.add("ore_sulfur", ore("sulfur", vein="#c8b83a", glint="#f0e07a"))
    pk.add("ore_skyglass", ore("skyglass", vein="#8a6ad8", glint="#d0b8ff"))
    pk.add("fuel_can", fuel_can())
    pk.add("glider_pack", glider_pack())
    pk.add("grapple_gun", grapple_gun())
    pk.add("sky_compass", sky_compass())
    pk.add("spyglass", spyglass())
    pk.add("breathing_rig", breathing_rig())
    pk.add("salvage_scrap", salvage_scrap())
