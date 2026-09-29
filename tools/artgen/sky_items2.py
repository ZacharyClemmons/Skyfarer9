"""Skyfarer, second pass: the production chain, the interesting drawer, and the crates.

Everything here has to read at 32x32 in an inventory slot the player is scanning rather
than studying, so each icon is built round one silhouette decision and one colour that
nothing else in the sheet uses. An ingot is a trapezoid; a tonic is a round-shouldered
bottle; a module crate is a box with its category stencilled on the lid in the tier's
colour, which means a player learns to read the whole shipyard inventory by colour alone.

Idiom is items.py's: a mask, a ramp lit from the upper left, selective outline through
`_fin`, and `sp.g()` for anything that should glow through the HDR pass.
"""
import math

import numpy as np

from common import (Canvas, ellipse_mask, hexc, mix, ramp, rng_for, rrect_mask,
                    sel_outline, shade)
from objects import Sprite
from items import _fin, thick_line


# ------------------------------------------------------------------ helpers
def _fill(sp, mask, pal, lx=0.12, ly=0.16, ox=10, oy=10):
    """Light a mask from the upper left onto a 7-step ramp."""
    ys, xs = np.nonzero(mask)
    for (yy, xx) in zip(ys, xs):
        lit = (ox - xx) * lx + (oy - yy) * ly
        sp.cv.px(xx, yy, pal[int(np.clip(4 + lit, 0, 6))])


def _speck(sp, rng, n, box, col, glow=False):
    for _ in range(n):
        x = rng.randint(box[0], box[2])
        y = rng.randint(box[1], box[3])
        if sp.cv.get(x, y)[3] > 0.5:
            (sp.g if glow else sp.cv.px)(x, y, col)


# ------------------------------------------------------------------ materials
def ingot(base, sheen=None, glow=None, tag=""):
    """A cast bar seen three-quarters on: trapezoid top, blunt end, hard top highlight."""
    sp = Sprite()
    rng = rng_for("ingot" + base + tag)
    p = ramp(base, 7, 0.5)
    # body
    for y in range(14, 25):
        t = (y - 14) / 10.0
        x0 = int(6 + t * 3)
        x1 = int(27 - t * 3)
        for x in range(x0, x1):
            sp.cv.px(x, y, p[int(np.clip(4 - (y - 14) * 0.45, 0, 6))])
    # the cast top face
    for y in range(11, 15):
        t = (y - 11) / 4.0
        x0 = int(9 - t * 3)
        x1 = int(24 + t * 3)
        for x in range(x0, x1):
            sp.cv.px(x, y, p[int(np.clip(6 - (y - 11) * 0.7, 0, 6))])
    for x in range(9, 24):
        sp.cv.px(x, 11, p[6])
    if sheen:
        for x in range(11, 21):
            sp.cv.px(x, 12, hexc(sheen))
    if glow:
        _speck(sp, rng, 10, (8, 13, 26, 24), hexc(glow), True)
    _fin(sp.cv)
    return sp


def timber(base="#a8814a", rings="#7a5a30", iron=False):
    """A cut length seen end-on, so the grain is the read."""
    sp = Sprite()
    p = ramp(base, 7, 0.45)
    r = ramp(rings, 7, 0.4)
    # the length
    for y in range(13, 24):
        for x in range(4, 24):
            sp.cv.px(x, y, p[int(np.clip(5 - (y - 13) * 0.4, 0, 6))])
    # the sawn end
    m = ellipse_mask(32, 32, 24, 18, 4, 6)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        d = math.hypot((xx - 24) / 4.0, (yy - 18) / 6.0)
        sp.cv.px(xx, yy, r[int(np.clip(2 + d * 4, 0, 6))] if int(d * 7) % 2 else p[3])
    # grain along the length
    for y in (15, 18, 21):
        for x in range(5, 23):
            if (x + y) % 5:
                sp.cv.px(x, y, p[2])
    if iron:
        for x in (8, 16):
            for y in range(12, 25):
                sp.cv.px(x, y, ramp("#8a8e98", 7, 0.4)[int(np.clip(5 - (y - 12) * 0.3, 0, 6))])
    _fin(sp.cv)
    return sp


def bundle(base, strands=9, tie="#6a4e33"):
    """Fibre, thread, rope: a fistful of lines with a tie round the middle."""
    sp = Sprite()
    rng = rng_for("bundle" + base)
    p = ramp(base, 7, 0.4)
    for k in range(strands):
        x = 7 + k * 2
        wob = rng.uniform(-1.4, 1.4)
        for y in range(7, 27):
            xx = int(x + math.sin((y + k) * 0.35) * 1.2 + wob * (y - 17) * 0.05)
            sp.cv.px(xx, y, p[int(np.clip(4 + (8 - k) * 0.25, 0, 6))])
    t = ramp(tie, 7, 0.4)
    for y in (15, 16, 17):
        for x in range(5, 27):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, t[4 if y == 16 else 2])
    _fin(sp.cv)
    return sp


def bolt_cloth(base="#c8bca0", tar="#5a4e38"):
    """A rolled bolt of canvas, end-on."""
    sp = Sprite()
    p = ramp(base, 7, 0.35)
    t = ramp(tar, 7, 0.4)
    m = rrect_mask(32, 32, 5, 11, 27, 24, 3)
    _fill(sp, m, p, 0.06, 0.18, 8, 11)
    # the spiral of the roll on the near end
    for k in range(64):
        a = k / 64.0 * math.tau * 2.4
        r = 1.0 + k * 0.08
        sp.cv.px(int(24 + math.cos(a) * r * 0.6), int(17 + math.sin(a) * r), p[2 if k % 6 < 3 else 5])
    for x in range(6, 27):
        sp.cv.px(x, 11, p[6])
        sp.cv.px(x, 24, t[1])
    _fin(sp.cv)
    return sp


def hide(base="#8a6a4a"):
    """A scraped hide, pegged out square-ish with one ragged edge."""
    sp = Sprite()
    rng = rng_for("hide")
    p = ramp(base, 7, 0.45)
    for y in range(7, 26):
        w = int(11 + math.sin((y - 7) * 0.32) * 2)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, p[int(np.clip(4 + (10 - x) * 0.08 + (10 - y) * 0.1, 0, 6))])
    # the flesh side, paler, showing at one corner
    for y in range(8, 15):
        for x in range(6, 13):
            if sp.cv.get(x, y)[3] > 0.5 and (x + y) % 3:
                sp.cv.px(x, y, p[6])
    _speck(sp, rng, 14, (7, 9, 25, 24), p[1])
    _fin(sp.cv)
    return sp


def plate_chitin(base="#6a8a4a", sheen="#c8e8a0"):
    """A lacquered shell section: curved, ribbed, and it catches the light in bands."""
    sp = Sprite()
    p = ramp(base, 7, 0.5)
    m = ellipse_mask(32, 32, 16, 18, 11, 9)
    _fill(sp, m, p, 0.1, 0.18, 9, 11)
    for k in range(5):
        y = 12 + k * 3
        for x in range(5, 28):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, p[1])
                sp.cv.px(x, y - 1, p[6])
    for x in range(10, 18):
        sp.g(x, 13, hexc(sheen))
    _fin(sp.cv)
    return sp


def lens(base="#9ad8ff", frame="#b8923a"):
    """A ground lens in a brass collar, glowing faintly at the edge."""
    sp = Sprite()
    br = ramp(frame, 7, 0.45)
    for k in range(140):
        a = k / 140.0 * math.tau
        for r in (11, 12):
            sp.cv.px(int(16 + math.cos(a) * r), int(16 + math.sin(a) * r), br[4 if math.sin(a) < 0 else 2])
    m = ellipse_mask(32, 32, 16, 16, 10, 10)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        d = math.hypot(xx - 16, yy - 16) / 10.0
        c = mix(hexc(base), hexc("#ffffff"), max(0.0, 0.7 - d))
        sp.cv.px(xx, yy, (c[0], c[1], c[2], 0.85))
    for k in range(40):
        a = k / 40.0 * math.tau
        sp.g(int(16 + math.cos(a) * 9), int(16 + math.sin(a) * 9), hexc(base))
    sp.g(12, 12, hexc("#ffffff"))
    _fin(sp.cv)
    return sp


def powder(base="#d8d0c0", jar="#8a8e98"):
    """A measure of something ground fine, in a paper twist."""
    sp = Sprite()
    rng = rng_for("powder" + base)
    p = ramp(jar, 7, 0.4)
    d = ramp(base, 7, 0.3)
    m = rrect_mask(32, 32, 9, 13, 23, 26, 3)
    _fill(sp, m, p)
    for y in range(16, 25):
        for x in range(11, 22):
            if sp.cv.get(x, y)[3] > 0.5:
                sp.cv.px(x, y, d[int(np.clip(4 + (11 - x) * 0.14, 0, 6))])
    # the twist at the top
    for k in range(7):
        sp.cv.px(16 - k // 2, 12 - k, p[5 - k // 2])
        sp.cv.px(16 + k // 2, 12 - k, p[3])
    _speck(sp, rng, 10, (11, 16, 22, 25), d[6])
    _fin(sp.cv)
    return sp


def flask(liquid, glass="#9ab0c0", cork="#8a6a3a", glow=False):
    """A round-shouldered bottle. Every tonic is this shape in a different colour, which
    is deliberate: the shape says 'drinkable' and the colour says which one."""
    sp = Sprite()
    g = ramp(glass, 7, 0.35)
    liq = ramp(liquid, 7, 0.45)
    ck = ramp(cork, 7, 0.4)
    body = ellipse_mask(32, 32, 16, 20, 8, 8)
    ys, xs = np.nonzero(body)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, g[int(np.clip(4 + (11 - xx) * 0.1, 0, 6))])
    # the liquid, filling most of it
    for y in range(17, 28):
        for x in range(8, 25):
            if sp.cv.get(x, y)[3] > 0.5:
                c = liq[int(np.clip(4 + (11 - x) * 0.12 + (18 - y) * 0.1, 0, 6))]
                (sp.g if glow and y > 20 else sp.cv.px)(x, y, c)
    # neck and cork
    for y in range(8, 14):
        for x in range(13, 19):
            sp.cv.px(x, y, g[int(np.clip(4 + (14 - x) * 0.4, 0, 6))])
    for y in range(5, 9):
        for x in range(13, 19):
            sp.cv.px(x, y, ck[int(np.clip(5 - (y - 5), 0, 6))])
    # a hard highlight so it reads as glass
    for y in range(13, 23):
        sp.cv.px(11, y, (1, 1, 1, 0.42))
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ tools
def axe(head="#98a2b0", haft="#a8814a", edge="#e8f0ff", big=False):
    sp = Sprite()
    st = ramp(head, 7, 0.4)
    wd = ramp(haft, 7, 0.4)
    for k in range(24):
        x = 11 + k // 3
        y = 28 - k
        for w in range(3):
            sp.cv.px(x + w, y, wd[int(np.clip(4 - w, 0, 6))])
    # the bit
    w0 = 9 if big else 7
    for y in range(4, 4 + w0):
        t = abs(y - (4 + w0 // 2)) / float(w0)
        x0 = int(12 - (1.0 - t) * 6)
        for x in range(x0, 21):
            sp.cv.px(x, y, st[int(np.clip(5 - (x - x0) * 0.5, 0, 6))])
        sp.cv.px(x0, y, hexc(edge))
    for y in range(3, 4 + w0 + 1):
        sp.cv.px(20, y, st[1])
    _fin(sp.cv)
    return sp


def knife(blade="#c0c8d4", grip="#6a4e33", curve=True, small=False):
    sp = Sprite()
    st = ramp(blade, 7, 0.35)
    gp = ramp(grip, 7, 0.4)
    n = 14 if small else 18
    for k in range(n):
        x = 8 + k
        y = int(20 - k * 0.55 - (math.sin(k / float(n) * math.pi) * 3 if curve else 0))
        for w in range(3):
            sp.cv.px(x, y + w, st[int(np.clip(5 - w * 2, 0, 6))])
        sp.cv.px(x, y - 1, (1, 1, 1, 0.55))
    for k in range(8):
        for w in range(4):
            sp.cv.px(5 + k // 2, 21 + k - w // 2, gp[int(np.clip(4 - w, 0, 6))])
    _fin(sp.cv)
    return sp


def pick(head="#8ab0d8", haft="#a8814a", glow="#9ad0ff"):
    sp = Sprite()
    st = ramp(head, 7, 0.4)
    wd = ramp(haft, 7, 0.4)
    for k in range(22):
        sp.cv.px(15, 28 - k, wd[4])
        sp.cv.px(16, 28 - k, wd[2])
        sp.cv.px(14, 28 - k, wd[5])
    for k in range(13):
        a = k / 13.0
        y = int(9 - math.sin(a * math.pi) * 3)
        sp.cv.px(3 + k, y, st[5])
        sp.cv.px(3 + k, y + 1, st[3])
        sp.cv.px(28 - k, y, st[4])
        sp.cv.px(28 - k, y + 1, st[2])
    sp.g(3, 8, hexc(glow))
    sp.g(28, 8, hexc(glow))
    _fin(sp.cv)
    return sp


def rod_fishing():
    sp = Sprite()
    cane = ramp("#c8a86a", 7, 0.4)
    st = ramp("#98a2b0", 7, 0.4)
    for k in range(28):
        x = 3 + k
        y = int(27 - k * 0.85 + math.sin(k * 0.1) * 1.5)
        sp.cv.px(x, y, cane[int(np.clip(5 - k // 8, 0, 6))])
        sp.cv.px(x, y + 1, cane[2])
    # the reel
    for k in range(50):
        a = k / 50.0 * math.tau
        sp.cv.px(int(10 + math.cos(a) * 4), int(21 + math.sin(a) * 4), st[4])
    sp.cv.px(10, 21, st[6])
    # the line
    for k in range(14):
        sp.cv.px(29 - k // 4, 5 + k, (0.85, 0.9, 1.0, 0.5))
    _fin(sp.cv)
    return sp


def saw_salvage():
    sp = Sprite()
    st = ramp("#98a2b0", 7, 0.4)
    bd = ramp("#5a6270", 7, 0.4)
    m = ellipse_mask(32, 32, 17, 14, 10, 10)
    _fill(sp, m, st, 0.1, 0.14, 11, 9)
    for k in range(26):
        a = k / 26.0 * math.tau
        sp.cv.px(int(17 + math.cos(a) * 11), int(14 + math.sin(a) * 11), st[6])
    m2 = ellipse_mask(32, 32, 17, 14, 4, 4)
    ys, xs = np.nonzero(m2)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, bd[3])
    for y in range(22, 29):
        for x in range(5, 12):
            sp.cv.px(x, y, ramp("#6a4e33", 7, 0.4)[int(np.clip(5 - (y - 22), 0, 6))])
    _fin(sp.cv)
    return sp


def artificer_kit():
    sp = Sprite()
    lea = ramp("#5a4030", 7, 0.4)
    st = ramp("#b0b8c4", 7, 0.35)
    m = rrect_mask(32, 32, 4, 10, 28, 25, 3)
    _fill(sp, m, lea)
    # a roll of files
    for k in range(6):
        x = 7 + k * 3
        for y in range(12, 23):
            sp.cv.px(x, y, st[5 if k % 2 else 3])
        sp.cv.px(x, 11, st[6])
    # the loupe
    for k in range(40):
        a = k / 40.0 * math.tau
        sp.cv.px(int(24 + math.cos(a) * 4), int(19 + math.sin(a) * 4), st[4])
    sp.g(24, 19, hexc("#9ad8ff"))
    _fin(sp.cv)
    return sp


def sail_palm():
    sp = Sprite()
    lea = ramp("#8a6a4a", 7, 0.4)
    st = ramp("#c0c8d4", 7, 0.35)
    m = ellipse_mask(32, 32, 14, 18, 9, 8)
    _fill(sp, m, lea)
    for k in range(30):
        a = k / 30.0 * math.tau
        sp.cv.px(int(14 + math.cos(a) * 4), int(18 + math.sin(a) * 3.5), ramp("#5a4030", 7, 0.4)[2])
    for k in range(14):
        sp.cv.px(19 + k // 2, 22 - k, st[5 if k % 2 else 4])
    sp.cv.px(26, 8, st[6])
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ weapons
def harpoon():
    sp = Sprite()
    st = ramp("#98a2b0", 7, 0.4)
    wd = ramp("#6a4e33", 7, 0.4)
    for k in range(26):
        sp.cv.px(4 + k, 26 - k, wd[4])
        sp.cv.px(5 + k, 26 - k, wd[2])
    # the head, with barbs
    for k in range(8):
        sp.cv.px(23 + k // 2, 5 + k // 2, st[6])
        sp.cv.px(24 + k // 2, 6 + k // 2, st[4])
    for k in range(5):
        sp.cv.px(22 - k, 10 + k, st[3])
        sp.cv.px(27, 9 + k, st[3])
    _fin(sp.cv)
    return sp


def boarding_axe():
    sp = Sprite()
    st = ramp("#8a929e", 7, 0.4)
    wd = ramp("#6a4e33", 7, 0.4)
    for k in range(22):
        for w in range(3):
            sp.cv.px(13 + w, 28 - k, wd[int(np.clip(4 - w, 0, 6))])
    for y in range(5, 13):
        t = abs(y - 9) / 8.0
        for x in range(int(6 + t * 4), 14):
            sp.cv.px(x, y, st[int(np.clip(5 - t * 3, 0, 6))])
    # the grapnel spike on the reverse
    for k in range(7):
        sp.cv.px(16 + k, 8 - k // 2, st[5])
    sp.cv.px(23, 4, st[6])
    _fin(sp.cv)
    return sp


def sword(blade="#c8d8e8", grip="#6a4e33", guard="#b8923a", glow=None, wavy=False):
    sp = Sprite()
    st = ramp(blade, 7, 0.35)
    gp = ramp(grip, 7, 0.4)
    gd = ramp(guard, 7, 0.45)
    for k in range(20):
        x = 9 + k
        y = 21 - k
        off = int(math.sin(k * 0.6) * 1.2) if wavy else 0
        for w in range(3):
            sp.cv.px(x + off, y + w, st[int(np.clip(5 - w * 2, 0, 6))])
        if glow and k % 3 == 0:
            sp.g(x + off, y + 1, hexc(glow))
        sp.cv.px(x + off, y - 1, (1, 1, 1, 0.5))
    # guard and grip
    for k in range(7):
        sp.cv.px(5 + k, 26 - k, gd[5])
        sp.cv.px(6 + k, 27 - k, gd[3])
    for k in range(6):
        sp.cv.px(3 + k // 2, 28 - k // 2 + 1, gp[4])
    _fin(sp.cv)
    return sp


def maul():
    sp = Sprite()
    rock = ramp("#4a3a34", 7, 0.5)
    wd = ramp("#6a4e33", 7, 0.4)
    for k in range(22):
        for w in range(3):
            sp.cv.px(13 + w, 29 - k, wd[int(np.clip(4 - w, 0, 6))])
    m = rrect_mask(32, 32, 5, 4, 26, 15, 2)
    _fill(sp, m, rock, 0.1, 0.2, 8, 4)
    rng = rng_for("maul")
    for _ in range(18):
        x, y = rng.randint(6, 25), rng.randint(5, 14)
        sp.g(x, y, hexc("#ff8a3a"))
    _fin(sp.cv)
    return sp


def aether_gun(length=14, barrel="#5a6270", coil="#9ad8ff", stock="#6a4e33", scatter=False):
    sp = Sprite()
    st = ramp(barrel, 7, 0.4)
    wd = ramp(stock, 7, 0.4)
    y0 = 14
    for x in range(8, 8 + length):
        for w in range(4):
            sp.cv.px(x, y0 + w, st[int(np.clip(5 - w, 0, 6))])
    if scatter:
        for k in range(3):
            for x in range(8 + length, 8 + length + 4):
                sp.cv.px(x, y0 - 1 + k * 2, st[4])
    # the coil pack
    for k in range(5):
        for y in range(y0 - 2, y0 + 6):
            sp.cv.px(10 + k, y, st[2] if k % 2 else st[5])
    for y in range(y0 - 1, y0 + 5):
        sp.g(12, y, hexc(coil))
    # grip and stock
    for k in range(9):
        for w in range(4):
            sp.cv.px(6 + w - k // 3, y0 + 4 + k, wd[int(np.clip(4 - w, 0, 6))])
    sp.g(8 + length - 1, y0 + 1, hexc(coil))
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ curios
def bell():
    sp = Sprite()
    br = ramp("#c8a03a", 7, 0.45)
    for y in range(9, 24):
        t = (y - 9) / 15.0
        w = int(3 + t * 8)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, br[int(np.clip(5 - abs(x - 13) * 0.25, 0, 6))])
    for x in range(6, 27):
        sp.cv.px(x, 24, br[1])
    for y in range(4, 10):
        sp.cv.px(16, y, br[3])
        sp.cv.px(15, y, br[5])
    sp.cv.px(16, 26, br[6])
    # it is ringing, faintly, always
    for k in range(6):
        sp.g(4 - k // 3, 12 + k, hexc("#fff0c0"))
        sp.g(28 + k // 3, 12 + k, hexc("#fff0c0"))
    _fin(sp.cv)
    return sp


def gravity_sink():
    sp = Sprite()
    g = ramp("#7a8494", 7, 0.35)
    m = rrect_mask(32, 32, 8, 8, 24, 27, 4)
    _fill(sp, m, g)
    # what is inside does not light correctly
    inner = ellipse_mask(32, 32, 16, 18, 6, 7)
    ys, xs = np.nonzero(inner)
    for (yy, xx) in zip(ys, xs):
        d = math.hypot(xx - 16, yy - 18) / 7.0
        sp.cv.px(xx, yy, (0.02, 0.02, 0.05, 1.0 - d * 0.2))
    for k in range(30):
        a = k / 30.0 * math.tau
        r = 7.5
        sp.g(int(16 + math.cos(a) * r), int(18 + math.sin(a) * r * 1.1), hexc("#5a3a8a"))
    for x in range(10, 23):
        sp.cv.px(x, 7, g[6])
    _fin(sp.cv)
    return sp


def flask_boiling():
    sp = Sprite()
    sp2 = flask("#d8a84a", glass="#b0c0cc", cork="#8a8e98")
    sp.cv.a[:] = sp2.cv.a
    rng = rng_for("boilflask")
    for _ in range(12):
        x, y = rng.randint(10, 22), rng.randint(16, 26)
        sp.g(x, y, hexc("#ffd88a"))
    for k in range(5):
        sp.g(16 + k % 3 - 1, 4 - k, hexc("#ffffff"))
    return sp


def updraft_flask():
    sp = Sprite()
    st = ramp("#a8b4c0", 7, 0.35)
    m = rrect_mask(32, 32, 10, 9, 22, 27, 4)
    _fill(sp, m, st)
    for y in range(12, 25):
        sp.cv.px(13, y, (1, 1, 1, 0.4))
    # the ring
    for k in range(34):
        a = k / 34.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 4), int(6 + math.sin(a) * 3), ramp("#c8a03a", 7, 0.4)[4])
    for k in range(6):
        sp.g(16, 26 + k // 3, hexc("#9ad8ff"))
    _fin(sp.cv)
    return sp


def shell_echo():
    sp = Sprite()
    p = ramp("#d8c8b0", 7, 0.4)
    for k in range(120):
        a = k / 120.0 * math.tau * 2.2
        r = 2 + k * 0.075
        x = int(16 + math.cos(a) * r)
        y = int(18 + math.sin(a) * r * 0.85)
        sp.cv.px(x, y, p[int(np.clip(6 - k // 22, 0, 6))])
    for k in range(20):
        a = k / 20.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 11), int(18 + math.sin(a) * 9), p[1])
    sp.g(16, 18, hexc("#c8a8e8"))
    _fin(sp.cv)
    return sp


def charm_knot():
    sp = Sprite()
    p = ramp("#c8b088", 7, 0.4)
    for k in range(130):
        a = k / 130.0 * math.tau
        r1 = 8 + math.sin(a * 3) * 3
        sp.cv.px(int(16 + math.cos(a) * r1), int(16 + math.sin(a) * r1), p[int(np.clip(4 + math.sin(a * 3) * 2, 0, 6))])
    for k in range(60):
        a = k / 60.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 4), int(16 + math.sin(a) * 4), p[2])
    for y in range(3, 9):
        sp.cv.px(16, y, p[5])
    _fin(sp.cv)
    return sp


def ledger():
    sp = Sprite()
    lea = ramp("#6a3a2a", 7, 0.4)
    pg = ramp("#d8d0bc", 7, 0.25)
    m = rrect_mask(32, 32, 6, 7, 26, 26, 2)
    _fill(sp, m, lea)
    for y in range(9, 25):
        for x in range(9, 24):
            sp.cv.px(x, y, pg[int(np.clip(5 - (y - 9) * 0.1, 0, 6))])
    for y in range(11, 24, 2):
        for x in range(11, 22):
            if (x + y) % 3:
                sp.cv.px(x, y, pg[1])
    for y in range(7, 27):
        sp.cv.px(7, y, lea[6])
    _fin(sp.cv)
    return sp


def tin_stars():
    sp = Sprite()
    st = ramp("#8a929e", 7, 0.4)
    m = ellipse_mask(32, 32, 16, 20, 10, 7)
    _fill(sp, m, st)
    for k in range(44):
        a = k / 44.0 * math.tau
        sp.cv.px(int(16 + math.cos(a) * 10), int(20 + math.sin(a) * 7), st[1])
    # the lid, tipped off
    for k in range(30):
        a = k / 30.0 * math.tau
        sp.cv.px(int(20 + math.cos(a) * 8), int(10 + math.sin(a) * 4), st[5])
    rng = rng_for("tinstars")
    for _ in range(22):
        x, y = rng.randint(8, 24), rng.randint(15, 24)
        sp.g(x, y, hexc("#e8f0ff"))
    _fin(sp.cv)
    return sp


def cap_thinking():
    sp = Sprite()
    w = ramp("#7a6a9a", 7, 0.4)
    m = ellipse_mask(32, 32, 16, 18, 11, 9)
    _fill(sp, m, w)
    for y in range(22, 27):
        for x in range(5, 28):
            if sp.cv.get(x, y)[3] > 0.5 or y < 25:
                sp.cv.px(x, y, w[int(np.clip(3 + (24 - y), 0, 6))])
    for k in range(9):
        for x in range(5, 28):
            if (x + k) % 4 == 0 and sp.cv.get(x, 12 + k)[3] > 0.5:
                sp.cv.px(x, 12 + k, w[6])
    sp.g(22, 24, hexc("#9ad8ff"))
    _fin(sp.cv)
    return sp


def lung_mask():
    sp = Sprite()
    p = ramp("#5a7878", 7, 0.4)
    m = ellipse_mask(32, 32, 15, 15, 9, 10)
    _fill(sp, m, p)
    # it is an organ, and it is breathing
    for k in range(5):
        for x in range(9, 22):
            if (x + k) % 3 and sp.cv.get(x, 11 + k * 2)[3] > 0.5:
                sp.cv.px(x, 11 + k * 2, p[6])
    for k in range(11):
        sp.cv.px(20 + k // 2, 22 + k // 2, p[3])
    sp.g(13, 13, hexc("#a8e0d0"))
    _fin(sp.cv)
    return sp


def monocle():
    sp = Sprite()
    br = ramp("#c8a85a", 7, 0.45)
    for k in range(120):
        a = k / 120.0 * math.tau
        for r in (9, 10):
            sp.cv.px(int(14 + math.cos(a) * r), int(15 + math.sin(a) * r), br[4 if math.sin(a) < 0 else 2])
    m = ellipse_mask(32, 32, 14, 15, 8, 8)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, (0.55, 0.78, 0.95, 0.55))
    sp.g(11, 12, hexc("#ffffff"))
    for k in range(12):
        sp.cv.px(23 + k // 3, 22 + k, br[3])
    _fin(sp.cv)
    return sp


def compass_liar():
    sp = Sprite()
    br = ramp("#8a7a5a", 7, 0.45)
    for k in range(120):
        a = k / 120.0 * math.tau
        for r in (10, 11):
            sp.cv.px(int(16 + math.cos(a) * r), int(17 + math.sin(a) * r), br[4 if math.sin(a) < 0 else 2])
    m = ellipse_mask(32, 32, 16, 17, 9, 9)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, hexc("#2a2038"))
    # two needles, disagreeing
    for k in range(-7, 8):
        sp.g(int(16 + k * 0.8), int(17 - k * 0.4), hexc("#e85a4a" if k > 0 else "#d8dce8"))
    for k in range(-6, 7):
        sp.cv.px(int(16 + k * 0.3), int(17 + k * 0.85), hexc("#8a7ad8"))
    sp.cv.px(16, 17, br[6])
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ fish
def fish(body="#c0ccd8", fin="#8aa0c0", eye="#1a1a22", long=False, glow=None):
    """A sky fish: a fat lozenge with a forked tail and one clear eye."""
    sp = Sprite()
    p = ramp(body, 7, 0.4)
    f = ramp(fin, 7, 0.4)
    rx, ry = (12, 5) if long else (10, 7)
    m = ellipse_mask(32, 32, 15, 17, rx, ry)
    _fill(sp, m, p, 0.09, 0.2, 10, 11)
    # tail
    for k in range(7):
        for w in range(k // 2 + 1):
            sp.cv.px(15 + rx + k // 2, 17 - k + w, f[4])
            sp.cv.px(15 + rx + k // 2, 17 + k - w, f[3])
    # dorsal and pectoral
    for k in range(9):
        sp.cv.px(12 + k, 17 - ry + 1 - k // 4, f[5])
    for k in range(5):
        sp.cv.px(13 + k, 17 + ry - 2 + k // 3, f[2])
    # the eye
    sp.cv.px(8, 15, hexc("#f0f4f8"))
    sp.cv.px(8, 16, hexc(eye))
    sp.cv.px(7, 15, hexc(eye))
    if glow:
        rng = rng_for("fish" + body)
        for _ in range(9):
            x, y = rng.randint(8, 24), rng.randint(13, 22)
            if sp.cv.get(x, y)[3] > 0.5:
                sp.g(x, y, hexc(glow))
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ module crates
CAT_MARK = {
    "thruster": "#c85a3a", "propeller": "#9a6a4a", "mast": "#7a8a5a", "lift": "#5a8ac8",
    "boiler": "#c8783a", "dynamo": "#c8a83a", "bunker": "#8a6a3a", "gun": "#c84a4a",
    "helm": "#e8c85a", "nav": "#a8c85a", "utility": "#5ac8a8", "armor": "#8a929e",
}


def module_crate(cat):
    """A crated part. The lid carries a stencil in the category's colour, so a shipyard
    inventory can be read by colour alone once the player has learned four of them."""
    sp = Sprite()
    rng = rng_for("crate" + cat)
    wd = ramp("#8a6a44", 7, 0.45)
    mark = hexc(CAT_MARK.get(cat, "#9aa3b3"))
    m = rrect_mask(32, 32, 3, 8, 29, 27, 1)
    _fill(sp, m, wd, 0.05, 0.14, 6, 9)
    # battens
    for x in (6, 15, 25):
        for y in range(8, 28):
            sp.cv.px(x, y, wd[6])
            sp.cv.px(x + 1, y, wd[2])
    for y in (9, 26):
        for x in range(3, 30):
            sp.cv.px(x, y, wd[6 if y == 9 else 1])
    # the stencil: a simple glyph per category, painted on
    cx, cy = 16, 18
    if cat in ("thruster", "propeller"):
        for k in range(9):
            sp.cv.px(cx - 4 + k, cy, mark)
            sp.cv.px(cx - 4 + k, cy + 1, mark)
        for k in range(4):
            sp.cv.px(cx + 5, cy - k, mark)
            sp.cv.px(cx + 5, cy + 1 + k, mark)
    elif cat == "mast":
        for k in range(11):
            sp.cv.px(cx, cy - 5 + k, mark)
        for k in range(6):
            sp.cv.px(cx + 1 + k, cy - 4 + k, mark)
    elif cat == "lift":
        for k in range(44):
            a = k / 44.0 * math.tau
            sp.cv.px(int(cx + math.cos(a) * 5), int(cy + math.sin(a) * 6), mark)
    elif cat in ("boiler", "bunker"):
        for y in range(cy - 5, cy + 6):
            for x in (cx - 4, cx + 4):
                sp.cv.px(x, y, mark)
        for x in range(cx - 4, cx + 5):
            sp.cv.px(x, cy - 5, mark)
            sp.cv.px(x, cy + 5, mark)
    elif cat == "dynamo":
        for k in range(10):
            sp.cv.px(cx - 4 + k, cy - 4 + (k % 3) * 3, mark)
    elif cat == "gun":
        for k in range(11):
            sp.cv.px(cx - 5 + k, cy, mark)
        for k in range(4):
            sp.cv.px(cx - 5, cy - 2 + k, mark)
    elif cat in ("helm", "nav"):
        for k in range(44):
            a = k / 44.0 * math.tau
            sp.cv.px(int(cx + math.cos(a) * 5), int(cy + math.sin(a) * 5), mark)
        for k in range(4):
            a = k / 4.0 * math.tau
            for r in range(6):
                sp.cv.px(int(cx + math.cos(a) * r), int(cy + math.sin(a) * r), mark)
    elif cat == "armor":
        for y in range(cy - 5, cy + 6):
            w = 5 - abs(y - cy) // 2
            for x in range(cx - w, cx + w):
                if (x + y) % 2:
                    sp.cv.px(x, y, mark)
    else:
        for k in range(9):
            sp.cv.px(cx - 4 + k, cy - 4 + k // 2, mark)
            sp.cv.px(cx - 4 + k, cy + 4 - k // 2, mark)
    _fin(sp.cv)
    return sp


# ------------------------------------------------------------------ registration
def build_into(pk):
    # ---- materials
    pk.add("sky_timber", timber())
    pk.add("ironwood_beam", timber("#6a5030", "#3a2a18", iron=True))
    pk.add("fibre_bundle", bundle("#b8a878"))
    pk.add("skysilk_thread", bundle("#e0e8f0", strands=7, tie="#8a7a9a"))
    pk.add("canvas_bolt", bolt_cloth())
    pk.add("beast_hide", hide())
    pk.add("chitin_plate", plate_chitin())
    pk.add("iron_ingot", ingot("#8a929e", sheen="#cfd8e4"))
    pk.add("aether_ingot", ingot("#5a8ac8", sheen="#a8d8ff", glow="#9ad0ff", tag="ae"))
    pk.add("voidsteel_ingot", ingot("#3a3e4a", sheen="#7a8ad8", glow="#5a4a9a", tag="vs"))
    pk.add("skyglass_lens", lens())
    pk.add("storm_glass", lens("#c8b8ff", frame="#7a8a9a"))
    pk.add("bone_meal", powder("#e0dcc8", jar="#a89878"))
    pk.add("marrow_oil", flask("#c8a03a", glass="#8a8e78", cork="#5a4030"))
    pk.add("sporecap", powder("#a878c8", jar="#7a6a58"))
    pk.add("fulgurite", ingot("#c8c0e8", sheen="#ffffff", glow="#9ad8ff", tag="fg"))

    # ---- tools
    pk.add("axe_felling", axe())
    pk.add("axe_ironwood", axe(head="#a8b0c8", haft="#6a5030", edge="#d0b8ff", big=True))
    pk.add("pick_aether", pick())
    pk.add("forage_knife", knife())
    pk.add("skinning_knife", knife(blade="#d8d0c0", grip="#8a6a4a", curve=True, small=True))
    pk.add("sky_rod", rod_fishing())
    pk.add("salvage_saw", saw_salvage())
    pk.add("artificers_kit", artificer_kit())
    pk.add("sail_needle", sail_palm())

    # ---- weapons
    pk.add("harpoon", harpoon())
    pk.add("boarding_axe", boarding_axe())
    pk.add("cutlass_brine", sword(blade="#c8d8d0", guard="#8a9a8a", wavy=True))
    pk.add("stormblade", sword(blade="#d8e8ff", guard="#7a8ad8", glow="#9ad8ff"))
    pk.add("quiet_knife", knife(blade="#4a4a54", grip="#2a2a34", curve=False))
    pk.add("cinder_maul", maul())
    pk.add("aether_pistol", aether_gun(length=11))
    pk.add("lance_carbine", aether_gun(length=18, barrel="#3a4250", coil="#b8d8ff"))
    pk.add("scattergun", aether_gun(length=10, barrel="#6a5a4a", coil="#ffb84a", scatter=True))

    # ---- curios
    pk.add("shrieking_bell", bell())
    pk.add("gravity_sink", gravity_sink())
    pk.add("liars_compass", compass_liar())
    pk.add("boiling_flask", flask_boiling())
    pk.add("pocket_updraft", updraft_flask())
    pk.add("echo_shell", shell_echo())
    pk.add("anchor_charm", charm_knot())
    pk.add("ledger", ledger())
    pk.add("tin_of_stars", tin_stars())
    pk.add("thinking_cap", cap_thinking())
    pk.add("drowned_lung", lung_mask())
    pk.add("cart_eye", monocle())

    # ---- tonics. One shape, six colours, and the colour is the whole read.
    pk.add("tonic_lift", flask("#c86a3a"))
    pk.add("tonic_wind", flask("#5ac8a8"))
    pk.add("tonic_clarity", flask("#a878e8", glow=True))
    pk.add("tonic_ironhide", flask("#8a8a7a"))
    pk.add("tonic_breath", flask("#6ad8f0"))
    pk.add("rations_sky", powder("#c8a878", jar="#7a6a4a"))

    # ---- fish
    pk.add("fish_sky_minnow", fish("#c8d8e8", "#9ab0c8", long=True))
    pk.add("fish_cloud_whiting", fish("#d8dce0", "#a8b0b8"))
    pk.add("fish_driftmoth", fish("#c8a8d8", "#9a7ab0", glow="#e0c0ff"))
    pk.add("fish_glass_eel", fish("#b8e0e8", "#88c0d0", long=True))
    pk.add("fish_nightgill", fish("#4a5a7a", "#2a3a5a", glow="#6ad8c8"))
    pk.add("fish_deepmouth", fish("#5a4a4a", "#3a2a2a"))
    pk.add("fish_aether_ray", fish("#8ab8d8", "#5a88b0", glow="#9ad0ff"))
    pk.add("fish_stormfin", fish("#7a8ac8", "#4a5a9a", glow="#b8d8ff"))

    # ---- one crate per module category
    for cat in CAT_MARK:
        pk.add("mod_" + cat, module_crate(cat))
