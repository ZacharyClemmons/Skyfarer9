"""Item icons (32x32, content roughly centred, ~20px). Drawn on the floor, in hands and in UI slots."""
import math

import numpy as np

from common import (Canvas, ellipse_mask, hexc, mix, ramp, rng_for, rrect_mask,
                    sel_outline, shade, shaded_fill)
from objects import Packer, Sprite

MET = "#a8b0bc"


def _fin(cv, shadow=True):
    sel_outline(cv, 0.55)
    if shadow:
        # tiny floor shadow
        ys, xs = np.nonzero(cv.alpha_mask())
        if len(ys):
            y = ys.max() + 1
            for x in range(xs.min() + 1, xs.max()):
                if y < 32 and cv.get(x, y)[3] == 0:
                    cv.px(x, y, (0.05, 0.05, 0.12, 0.25))
    return cv


def thick_line(cv, x0, y0, x1, y1, pal, w=2):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        for k in range(w):
            col = pal[min(3, len(pal) - 1)] if k == 0 else pal[1]
            cv.px(int(round(x)), int(round(y)) + k, col)


def wrench():
    cv = Canvas()
    p = ramp(MET, 5, 0.45)
    thick_line(cv, 8, 24, 19, 13, p, 3)
    # open-jaw head
    head = ellipse_mask(32, 32, 21, 11, 5, 5)
    shaded_fill(cv, head, MET, 0.45)
    jaw = rrect_mask(32, 32, 21, 5, 27, 10, 0)
    for y in range(32):
        for x in range(32):
            if jaw[y, x] and (x - 21) - (10 - y) * 0.2 > 0:
                cv.px(x, y, (0, 0, 0, 0))
    # ring end
    ring = ellipse_mask(32, 32, 8, 24, 3.2, 3.2)
    shaded_fill(cv, ring, MET, 0.45)
    cv.px(8, 24, (0, 0, 0, 0))
    cv.px(8, 23, p[0])
    return _fin(cv)

def crowbar():
    cv = Canvas()
    p = ramp("#c83a3a", 5, 0.4)
    thick_line(cv, 8, 25, 21, 10, p, 3)
    # the hooked, split claw end
    for (x, y, i) in ((22, 9, 3), (23, 8, 4), (24, 8, 3), (25, 9, 2), (25, 10, 2), (24, 11, 1), (22, 10, 2), (21, 8, 3)):
        cv.px(x, y, p[i])
    cv.px(23, 10, (0, 0, 0, 0))
    # flat pry end
    for (x, y, i) in ((6, 26, 2), (7, 27, 1), (6, 27, 1), (8, 27, 1)):
        cv.px(x, y, p[i])
    # worn paint showing steel
    m = ramp(MET, 5, 0.45)
    cv.px(7, 26, m[3])
    cv.px(24, 8, m[4])
    return _fin(cv)

def screwdriver():
    cv = Canvas()
    h = ramp("#e8c83a", 5, 0.4)
    m = ramp(MET, 5, 0.45)
    # chunky grip with ridges
    grip = rrect_mask(32, 32, 7, 17, 16, 22, 2)
    shaded_fill(cv, grip, "#e8c83a", 0.45)
    for x in (9, 11, 13):
        cv.vline(x, 18, 21, h[1])
    cv.rect(16, 18, 17, 21, h[0])  # ferrule
    # shaft + tip
    cv.hline(18, 25, 19, m[4])
    cv.hline(18, 25, 20, m[2])
    cv.px(26, 19, m[3])
    cv.px(26, 20, m[1])
    cv.px(27, 19, m[1])
    cv.px(27, 20, m[0])
    return _fin(cv)

def wirecutters():
    cv = Canvas()
    h = ramp("#d83a3a", 5, 0.4)
    m = ramp(MET, 5, 0.45)
    # two rubber handles splayed apart
    thick_line(cv, 7, 25, 14, 17, h, 3)
    thick_line(cv, 12, 27, 16, 18, h, 3)
    # pivot + jaws
    pv = ellipse_mask(32, 32, 16, 17, 2.4, 2.4)
    shaded_fill(cv, pv, MET, 0.4)
    thick_line(cv, 17, 15, 23, 8, m, 2)
    thick_line(cv, 18, 16, 25, 11, m, 2)
    cv.px(24, 8, m[4])
    cv.px(26, 11, m[3])
    cv.px(16, 17, m[4])
    return _fin(cv)

def welder(on=False):
    """tg welding tool: a yellow fuel tank with a steel neck and torch nozzle, a black
    grip underneath and the fuel cap on top."""
    sp = Sprite()
    cv = sp.cv
    p = ramp(MET, 5, 0.45)
    # fuel tank
    tank = rrect_mask(32, 32, 6, 13, 18, 21, 3)
    shaded_fill(cv, tank, "#e0b030", 0.45)
    cv.hline(8, 16, 17, shade(hexc("#e0b030"), -0.35))
    cv.px(10, 15, hexc("#fff0a0"))
    cv.px(11, 15, hexc("#fff0a0"))
    # fuel cap
    cv.rect(10, 11, 13, 12, p[3])
    cv.hline(10, 13, 11, p[4])
    # neck and nozzle
    cv.rect(18, 15, 23, 18, p[2])
    cv.hline(18, 23, 15, p[4])
    cv.rect(24, 16, 26, 17, p[1])
    cv.px(26, 16, p[0])
    # grip
    cv.rect(9, 21, 13, 25, hexc("#2a2a30"))
    cv.vline(10, 22, 24, hexc("#4a4a52"))
    cv.px(14, 21, p[2])
    _fin(cv)
    if on:
        sp.g(27, 16, hexc("#ffffff"))
        sp.g(27, 17, hexc("#9ad8ff"))
        sp.g(28, 16, hexc("#6ab8ff"))
        sp.g(28, 17, hexc("#3a8aff"))
        sp.g(29, 16, hexc("#3a8aff"))
    return sp


def multitool():
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 11, 8, 20, 24, 2)
    shaded_fill(cv, body, "#e8c83a", 0.4)
    cv.rect(13, 10, 18, 14, hexc("#1c2838"))
    _fin(cv)
    sp.g(14, 12, hexc("#5aff9a"))
    sp.g(15, 12, hexc("#5aff9a"))
    sp.g(17, 11, hexc("#5aff9a"))
    return sp


def cable_coil(color="#d83a3a"):
    cv = Canvas()
    p = ramp(color, 5, 0.4)
    for r, i in ((7, 1), (5.5, 3), (4, 2)):
        for a in range(0, 360, 4):
            x = 16 + math.cos(math.radians(a)) * r
            y = 17 + math.sin(math.radians(a)) * r * 0.7
            cv.px(int(x), int(y), p[i])
    cv.px(22, 12, p[3])
    cv.px(23, 11, p[2])
    return _fin(cv)


def sheets(color, n=3):
    cv = Canvas()
    for i in range(n):
        m = rrect_mask(32, 32, 7, 16 - i * 2, 24, 22 - i * 2, 0)
        shaded_fill(cv, m, color, 0.35)
    return _fin(cv)


def rglass_sheets():
    """tg rglass: glass sheets with a mesh of rods set into them."""
    cv = Canvas()
    for i in range(3):
        m = rrect_mask(32, 32, 7, 16 - i * 2, 24, 22 - i * 2, 0)
        shaded_fill(cv, m, "#8cc0dc", 0.35)
    rod = hexc("#5c6474")
    for x in (11, 15, 19, 23):
        for y in range(12, 23):
            if cv.get(x, y)[3] > 0:
                cv.px(x, y, rod)
    return _fin(cv)


def extinguisher():
    cv = Canvas()
    body = rrect_mask(32, 32, 12, 10, 19, 26, 3)
    shaded_fill(cv, body, "#d83a3a", 0.45)
    p = ramp("#2a2e38", 3, 0.4)
    cv.rect(14, 7, 17, 9, p[1])
    thick_line(cv, 17, 8, 22, 12, p, 1)
    cv.rect(13, 16, 18, 18, hexc("#e8eef4"))
    return _fin(cv)


def tank(color):
    cv = Canvas()
    body = rrect_mask(32, 32, 12, 8, 19, 27, 3)
    shaded_fill(cv, body, color, 0.45)
    cv.rect(14, 5, 17, 7, hexc("#6a7486"))
    cv.px(14, 5, hexc("#b0b8c4"))
    return _fin(cv)


def gas_mask():
    cv = Canvas()
    m = ellipse_mask(32, 32, 16, 15, 7, 6)
    shaded_fill(cv, m, "#3a3f4a", 0.45)
    for (x, y) in ((13, 13), (19, 13)):
        e = ellipse_mask(32, 32, x, y, 2, 2)
        cv.mask_fill(e, hexc("#7ab8e0"))
        cv.px(x - 1, y - 1, hexc("#e8f8ff"))
    f = ellipse_mask(32, 32, 16, 21, 3, 3)
    shaded_fill(cv, f, "#6a7486", 0.4)
    return _fin(cv)


def coat(color):
    cv = Canvas()
    body = rrect_mask(32, 32, 9, 8, 22, 26, 3)
    shaded_fill(cv, body, color, 0.4)
    for y in range(9, 26):
        cv.px(16, y, shade(hexc(color), -0.4))
    fur = ramp("#e8e0d0", 3, 0.3)
    for x in range(9, 23):
        cv.px(x, 8, fur[2])
        cv.px(x, 9, fur[1])
    for y in range(8, 25):
        cv.px(8, y, shade(hexc(color), -0.2))
        cv.px(23, y, shade(hexc(color), -0.3))
    return _fin(cv)


def medkit(color="#e8eef4", cross="#d83a3a"):
    cv = Canvas()
    body = rrect_mask(32, 32, 8, 11, 23, 24, 2)
    shaded_fill(cv, body, color, 0.35)
    cv.rect(14, 14, 17, 21, hexc(cross))
    cv.rect(12, 16, 19, 19, hexc(cross))
    cv.rect(13, 9, 18, 10, hexc("#6a7486"))
    return _fin(cv)


def pack(color, stripe):
    cv = Canvas()
    body = rrect_mask(32, 32, 10, 12, 21, 21, 2)
    shaded_fill(cv, body, color, 0.35)
    cv.hline(10, 21, 16, hexc(stripe))
    cv.hline(10, 21, 17, shade(hexc(stripe), -0.3))
    return _fin(cv)


def syringe():
    cv = Canvas()
    p = ramp("#e8eef4", 5, 0.3)
    thick_line(cv, 9, 22, 19, 12, p, 2)
    cv.px(20, 11, hexc("#9aa3b3"))
    cv.px(21, 10, hexc("#9aa3b3"))
    cv.px(22, 9, hexc("#9aa3b3"))
    thick_line(cv, 11, 20, 15, 16, ramp("#d83a3a", 3, 0.3), 1)
    return _fin(cv)


def pill_bottle(color):
    cv = Canvas()
    body = rrect_mask(32, 32, 12, 11, 19, 24, 2)
    shaded_fill(cv, body, "#e8a83a", 0.4)
    cv.rect(12, 8, 19, 10, hexc("#e8eef4"))
    cv.rect(13, 15, 18, 19, hexc(color))
    return _fin(cv)


def beaker(fill=None):
    cv = Canvas()
    glass = hexc("#cfe8f5", 0.55)
    m = rrect_mask(32, 32, 12, 10, 19, 24, 1)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        cv.px(x, y, glass)
    if fill:
        for y in range(17, 24):
            cv.hline(13, 18, y, hexc(fill, 0.9))
        cv.hline(13, 18, 17, shade(hexc(fill), 0.35))
    cv.vline(13, 11, 22, hexc("#ffffff", 0.8))
    cv.hline(11, 20, 10, hexc("#e8f4ff"))
    return _fin(cv)


def analyzer():
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 11, 9, 20, 24, 2)
    shaded_fill(cv, body, "#e8eef4", 0.35)
    cv.rect(13, 11, 18, 16, hexc("#0b1a22"))
    _fin(cv)
    for x in range(13, 19):
        sp.g(x, 13 + (x % 3 == 0) - (x % 4 == 0), hexc("#4ad8ff"))
    cv.px(15, 20, hexc("#4aa3d8"))
    return sp


def gas_analyzer():
    """tg's handheld gas analyzer: a yellow body, a readout, and a sampling nozzle."""
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 11, 10, 20, 25, 2)
    shaded_fill(cv, body, "#d8b83a", 0.35)
    cv.rect(13, 12, 18, 17, hexc("#0b1a22"))
    cv.rect(14, 6, 17, 9, hexc("#6a7486"))
    cv.px(15, 5, hexc("#9aa3b3"))
    cv.px(16, 5, hexc("#9aa3b3"))
    _fin(cv)
    for x in range(13, 19):
        sp.g(x, 15 - (x % 2), hexc("#5aff9a"))
    cv.px(14, 21, hexc("#3a3a40"))
    cv.px(17, 21, hexc("#3a3a40"))
    return sp


def id_card(color):
    cv = Canvas()
    body = rrect_mask(32, 32, 8, 12, 23, 22, 1)
    shaded_fill(cv, body, "#e8eef4", 0.3)
    cv.rect(8, 12, 23, 14, hexc(color))
    cv.rect(10, 16, 13, 20, hexc("#9aa3b3"))
    cv.hline(15, 21, 17, hexc("#6a7486"))
    cv.hline(15, 19, 19, hexc("#6a7486"))
    return _fin(cv)


def headset():
    cv = Canvas()
    p = ramp("#3a3f4a", 5, 0.4)
    for a in range(180, 361, 6):
        x = 16 + math.cos(math.radians(a)) * 7
        y = 18 + math.sin(math.radians(a)) * 7
        cv.px(int(x), int(y), p[3])
    for x in (8, 23):
        m = ellipse_mask(32, 32, x + 0.5, 19, 2, 3)
        shaded_fill(cv, m, "#3a3f4a", 0.4)
    thick_line(cv, 22, 21, 19, 24, p, 1)
    return _fin(cv)


def flashlight(on=False):
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 6, 15, 19, 20, 2)
    shaded_fill(cv, body, "#4a5262", 0.45)
    head = rrect_mask(32, 32, 19, 12, 24, 23, 2)
    shaded_fill(cv, head, "#8a93a3", 0.4)
    p = ramp("#4a5262", 5, 0.4)
    for x in (8, 10, 12):
        cv.vline(x, 16, 19, p[1])  # grip knurling
    cv.rect(14, 16, 15, 17, hexc("#d84a4a"))  # switch
    lens = hexc("#fff4c0") if on else hexc("#9fb8d0")
    cv.vline(25, 14, 21, lens)
    cv.vline(24, 13, 22, shade(lens, -0.3))
    _fin(cv)
    if on:
        for y in range(13, 23):
            sp.g(25, y, hexc("#fffbe0"))
        sp.g(26, 17, hexc("#fff4c0"))
        sp.g(26, 18, hexc("#fff4c0"))
    return sp

def baton():
    sp = Sprite()
    cv = sp.cv
    thick_line(cv, 11, 21, 23, 9, ramp("#2a2e38", 5, 0.5), 3)
    thick_line(cv, 6, 26, 11, 21, ramp("#6a4a2e", 5, 0.45), 3)  # grip
    m = ramp(MET, 5, 0.45)
    cv.px(11, 21, m[3])
    cv.px(12, 21, m[2])
    cv.px(11, 22, m[2])
    y = ramp("#e8c83a", 5, 0.4)
    for k in range(3):
        cv.px(22 + k, 9 - k + 1, y[3])  # contact prongs
    _fin(cv)
    sp.g(24, 8, hexc("#ffe04a"))
    sp.g(25, 8, hexc("#ffe04a"))
    sp.g(24, 7, hexc("#fff8a0"))
    return sp

def cuffs():
    cv = Canvas()
    m = ramp(MET, 6, 0.5)
    for cx, cy in ((10, 18), (22, 18)):
        ring = ellipse_mask(32, 32, cx, cy, 5.5, 5.5) & ~ellipse_mask(32, 32, cx, cy, 3.2, 3.2)
        shaded_fill(cv, ring, "#b8c2cc", 0.45)
        # the ratchet arm
        cv.px(cx - 4, cy + 3, m[1])
        cv.px(cx - 5, cy + 2, m[1])
    # chain
    for x in range(15, 18):
        cv.px(x, 16 + (x % 2), m[4] if x % 2 else m[2])
    cv.px(8, 14, hexc("#ffffff"))
    cv.px(20, 14, hexc("#ffffff"))
    return _fin(cv)

def toolbox(color):
    cv = Canvas()
    body = rrect_mask(32, 32, 7, 13, 24, 24, 1)
    shaded_fill(cv, body, color, 0.4)
    cv.hline(7, 24, 16, shade(hexc(color), -0.35))
    cv.rect(13, 9, 18, 10, hexc("#3a3f4a"))
    cv.vline(13, 10, 12, hexc("#3a3f4a"))
    cv.vline(18, 10, 12, hexc("#3a3f4a"))
    cv.rect(15, 18, 16, 19, hexc("#c8ccd4"))
    return _fin(cv)


def mop():
    cv = Canvas()
    thick_line(cv, 20, 6, 12, 22, ramp("#8a5a3b", 3, 0.4), 1)
    m = ellipse_mask(32, 32, 11, 24, 5, 3)
    shaded_fill(cv, m, "#e8e0c8", 0.4)
    return _fin(cv)


def bucket():
    cv = Canvas()
    body = rrect_mask(32, 32, 10, 14, 21, 25, 2)
    shaded_fill(cv, body, "#3a8ad8", 0.4)
    top = ellipse_mask(32, 32, 16, 14, 6, 2)
    cv.mask_fill(top, hexc("#6ab8e8"))
    for a in range(180, 361, 10):
        x = 16 + math.cos(math.radians(a)) * 7
        y = 14 + math.sin(math.radians(a)) * 6
        cv.px(int(x), int(y), hexc("#9aa3b3"))
    return _fin(cv)


def pickaxe():
    cv = Canvas()
    thick_line(cv, 10, 25, 20, 11, ramp("#8a5a3b", 3, 0.4), 2)
    p = ramp(MET, 5, 0.45)
    for i in range(-6, 7):
        x = 20 + i
        y = 11 + int(abs(i) * 0.4) - (0 if abs(i) < 5 else -1)
        cv.px(x, y - 2, p[3])
        cv.px(x, y - 1, p[1])
    return _fin(cv)


def ore(color, v=0):
    cv = Canvas()
    rng = rng_for(f"ore{color}{v}")
    for k in range(3):
        cx, cy = 12 + rng.randint(0, 8), 14 + rng.randint(0, 8)
        m = ellipse_mask(32, 32, cx, cy, rng.uniform(3, 5), rng.uniform(2.5, 4))
        shaded_fill(cv, m, color, 0.5)
    return _fin(cv)


# ---------------------------------------------------------------- food & drink
def food(kind):
    cv = Canvas()
    if kind == "sandwich":
        for (y0, col) in ((20, "#d8a86a"), (18, "#4ab83a"), (17, "#e84a3a"), (16, "#f0d8a0"), (13, "#d8a86a")):
            m = rrect_mask(32, 32, 9, y0, 23, y0 + 3, 2)
            shaded_fill(cv, m, col, 0.35)
    elif kind == "soup":
        bowl = ellipse_mask(32, 32, 16, 19, 8, 5)
        shaded_fill(cv, bowl, "#e8eef4", 0.35)
        s = ellipse_mask(32, 32, 16, 17, 6.5, 2.5)
        cv.mask_fill(s, hexc("#d87a3a"))
        cv.px(13, 17, hexc("#f0b87a"))
        cv.px(18, 16, hexc("#4ab83a"))
    elif kind == "burger":
        for (y0, h, col) in ((20, 3, "#c88a4a"), (18, 2, "#6a3a22"), (17, 1, "#4ab83a"), (12, 5, "#d8964a")):
            m = rrect_mask(32, 32, 9, y0, 23, y0 + h, 2 if h > 2 else 0)
            shaded_fill(cv, m, col, 0.35)
        for x in range(11, 22, 3):
            cv.px(x, 13, hexc("#fff0c8"))
    elif kind == "donut":
        m = ellipse_mask(32, 32, 16, 17, 7, 5.5) & ~ellipse_mask(32, 32, 16, 17, 2.5, 2)
        shaded_fill(cv, m, "#d8964a", 0.35)
        ic = ellipse_mask(32, 32, 16, 16, 6, 4.5) & ~ellipse_mask(32, 32, 16, 17, 3, 2.5)
        cv.mask_fill(ic, hexc("#ff8ad8"))
        for (x, y) in ((12, 14), (19, 15), (15, 13), (18, 19)):
            cv.px(x, y, hexc("#ffffff"))
    elif kind == "pizza":
        for y in range(10, 25):
            w = (y - 10) // 2
            for x in range(16 - w, 17 + w):
                cv.px(x, y, hexc("#f0c85a") if y < 23 else hexc("#c8883a"))
        for (x, y) in ((16, 14), (14, 18), (18, 19)):
            cv.px(x, y, hexc("#c83a2a"))
            cv.px(x + 1, y, hexc("#a82a1a"))
    elif kind == "ration":
        m = rrect_mask(32, 32, 9, 12, 22, 22, 1)
        shaded_fill(cv, m, "#6a7a4a", 0.35)
        cv.rect(11, 15, 20, 17, hexc("#e8e0c8"))
    elif kind == "meat":
        m = ellipse_mask(32, 32, 16, 17, 7, 5)
        shaded_fill(cv, m, "#c84a4a", 0.4)
        f = ellipse_mask(32, 32, 14, 16, 3, 1.5)
        cv.mask_fill(f, hexc("#f0c8c8"))
    elif kind == "flour":
        m = rrect_mask(32, 32, 10, 9, 21, 25, 2)
        shaded_fill(cv, m, "#e8e0d0", 0.3)
        cv.rect(12, 15, 19, 19, hexc("#c8883a"))
    elif kind == "egg":
        m = ellipse_mask(32, 32, 16, 17, 4, 5)
        shaded_fill(cv, m, "#f4ecd8", 0.3)
    elif kind in ("tomato", "potato", "berries", "wheat", "banana", "banana_peel"):
        colr = {"tomato": "#e83a2a", "potato": "#c8a06a", "berries": "#7a4ae8", "wheat": "#e8c85a", "banana": "#f0d83a", "banana_peel": "#e8c83a"}[kind]
        if kind == "banana":
            # a plump crescent: thick in the middle, a brown stem and tip
            pb = ramp(colr, 5, 0.4)
            for i in range(15):
                t = i / 14
                x = 8 + i
                yc = 19 - math.sin(t * math.pi) * 5
                half = 1 + math.sin(t * math.pi) * 1.6
                for y in range(int(yc - half), int(yc + half) + 1):
                    k = 3 if y < yc - 0.5 else (2 if y < yc + 0.8 else 1)
                    cv.px(x, y, pb[k])
            cv.px(7, 19, hexc("#5a3a1a"))
            cv.px(7, 18, hexc("#5a3a1a"))
            cv.px(23, 19, hexc("#3a2a1a"))
        elif kind == "banana_peel":
            # the tg peel: splayed yellow strips round a brown heart
            pb = ramp(colr, 5, 0.4)
            for (dx, dy) in ((-6, 3), (6, 3), (-3, -4), (4, -4), (0, 5)):
                for s in range(6):
                    t = s / 5
                    x = int(round(16 + dx * t))
                    y = int(round(18 + dy * t))
                    cv.px(x, y, pb[3 if s < 3 else 2])
                    cv.px(x, y + 1, pb[1])
            cv.rect(15, 17, 17, 19, hexc("#8a6a2a"))
            cv.px(16, 16, hexc("#5a3a1a"))
        elif kind == "berries":
            for (x, y) in ((13, 16), (17, 15), (15, 19), (19, 19), (12, 20)):
                m = ellipse_mask(32, 32, x, y, 2, 2)
                shaded_fill(cv, m, colr, 0.4)
        elif kind == "wheat":
            # a sheaf: five stalks fanning out of a twine band, a grain head on each
            pw = ramp(colr, 5, 0.4)
            stalk = hexc("#b8984a")
            for tx in (11, 13, 16, 19, 21):
                n = 14
                for s_ in range(n):
                    t = s_ / (n - 1)
                    x = int(round(16 + (tx - 16) * t))
                    y = int(round(25 - 12 * t))
                    cv.px(x, y, stalk)
                hy = 13 - (1 if tx == 16 else 0)
                for gy in range(hy - 5, hy):
                    cv.px(tx, gy, pw[3] if gy % 2 else pw[2])
                    if gy % 2 == 0:
                        cv.px(tx - 1, gy, pw[1])
                        cv.px(tx + 1, gy, pw[1])
                cv.px(tx, hy - 6, pw[4])
            cv.hline(14, 18, 21, hexc("#8a5a2a"))
            cv.hline(14, 18, 22, hexc("#6a4a1a"))
        else:
            m = ellipse_mask(32, 32, 16, 17, 6, 5)
            shaded_fill(cv, m, colr, 0.4)
            if kind == "tomato":
                cv.px(16, 12, hexc("#4ab83a"))
                cv.px(15, 12, hexc("#3a8a2a"))
    return _fin(cv)


def drink(kind):
    sp = Sprite()
    cv = sp.cv
    if kind == "cocoa":
        m = rrect_mask(32, 32, 11, 13, 20, 24, 2)
        shaded_fill(cv, m, "#e8eef4", 0.3)
        top = ellipse_mask(32, 32, 15.5, 13, 4.5, 1.5)
        cv.mask_fill(top, hexc("#6a3a22"))
        for (x, y) in ((21, 16), (22, 17), (22, 18), (21, 19)):
            cv.px(x, y, hexc("#c8d0dc"))
        _fin(cv)
        for (x, y) in ((14, 10), (15, 8), (17, 9), (16, 6)):
            cv.px(x, y, hexc("#ffffff", 0.5))
    elif kind == "water":
        m = rrect_mask(32, 32, 13, 9, 18, 25, 2)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            cv.px(x, y, hexc("#9fd0ec", 0.8 if y > 12 else 0.5))
        cv.rect(14, 7, 17, 8, hexc("#3a6ad8"))
        cv.vline(14, 11, 23, hexc("#ffffff", 0.7))
        _fin(cv)
    elif kind == "soda":
        m = rrect_mask(32, 32, 12, 10, 19, 24, 1)
        shaded_fill(cv, m, "#d83a3a", 0.4)
        cv.hline(12, 19, 10, hexc("#c8ccd4"))
        cv.rect(13, 15, 18, 17, hexc("#e8eef4"))
        _fin(cv)
    elif kind == "coffee":
        m = rrect_mask(32, 32, 12, 12, 19, 24, 1)
        shaded_fill(cv, m, "#f0e8d8", 0.3)
        cv.rect(12, 16, 19, 19, hexc("#7a4a2e"))
        cv.hline(12, 19, 11, hexc("#3a2e2a"))
        _fin(cv)
    elif kind == "booze":
        m = rrect_mask(32, 32, 12, 12, 19, 25, 2)
        shaded_fill(cv, m, "#4a8a3a", 0.45)
        cv.rect(14, 6, 17, 11, shade(hexc("#4a8a3a"), -0.2))
        cv.rect(13, 16, 18, 20, hexc("#e8e0c8"))
        _fin(cv)
    return sp


def misc_paper():
    cv = Canvas()
    m = rrect_mask(32, 32, 10, 8, 21, 24, 0)
    shaded_fill(cv, m, "#f0ece0", 0.2)
    for y in range(11, 23, 2):
        cv.hline(12, 12 + (y * 7) % 8, y, hexc("#8a93a3"))
    return _fin(cv)


def soap():
    cv = Canvas()
    m = rrect_mask(32, 32, 11, 15, 21, 21, 2)
    shaded_fill(cv, m, "#8ae8a8", 0.35)
    return _fin(cv)


def ice_chunk():
    cv = Canvas()
    m = rrect_mask(32, 32, 10, 12, 22, 23, 2)
    shaded_fill(cv, m, "#9fd6ee", 0.5)
    cv.px(12, 14, hexc("#ffffff"))
    cv.px(13, 13, hexc("#ffffff"))
    return _fin(cv)


def glowstick(col):
    sp = Sprite()
    cv = sp.cv
    thick_line(cv, 10, 23, 20, 11, ramp(col, 5, 0.35), 3)
    cap = ramp("#4a5262", 5, 0.4)
    for (x, y) in ((9, 24), (10, 25), (9, 25), (21, 10), (22, 10), (21, 11)):
        cv.px(x, y, cap[2])
    cv.px(21, 9, cap[3])
    _fin(cv)
    for i in range(11):
        sp.g(10 + i, 23 - int(i * 1.15), hexc(col))
        sp.g(11 + i, 23 - int(i * 1.15), hexc(col))
    return sp


def light_tube():
    cv = Canvas()
    glass = ellipse_mask(32, 32, 16, 16, 11, 2.2)
    shaded_fill(cv, glass, "#e8f4ff", 0.3)
    cv.hline(8, 24, 15, hexc("#ffffff"))
    cap = ramp(MET, 5, 0.45)
    for x in (4, 5, 26, 27):
        cv.vline(x, 14, 18, cap[2 if x in (4, 27) else 3])
    for x in (3, 28):
        cv.px(x, 15, cap[1])
        cv.px(x, 17, cap[1])
    return _fin(cv)


def shard(size="large"):
    """tg /obj/item/shard: "large", "medium" or "small" (picked when it's made)."""
    cv = Canvas()
    from PIL import Image, ImageDraw
    im = Image.new("L", (32, 32), 0)
    poly = {
        "large": [(10, 25), (15, 8), (22, 22), (17, 26)],
        "medium": [(12, 23), (18, 12), (21, 22)],
        "small": [(14, 21), (17, 15), (19, 21)],
    }[size]
    ImageDraw.Draw(im).polygon(poly, fill=1)
    m = np.array(im).astype(bool)
    shaded_fill(cv, m, "#9fd0ec", 0.45)
    top = min(p[1] for p in poly) + 2
    bot = max(p[1] for p in poly) - 2
    gx = poly[1][0]
    for y in range(top, bot):
        a = cv.get(gx, y)
        if a[3] > 0:
            cv.px(gx, y, hexc("#e2f6ff"))
    return _fin(cv)


def rods():
    """A small bundle of metal rods, lying diagonally."""
    cv = Canvas()
    pal = ramp(MET, 5, 0.5)
    for k, (dx, dy) in enumerate(((0, 0), (2, -2), (4, 0), (2, 2))):
        thick_line(cv, 7 + dx, 22 + dy, 23 + dx, 8 + dy, pal, 2)
    return _fin(cv)


def pipe_item(col):
    """tg smart pipe fitting: a short bent length of pipe with collared ends."""
    cv = Canvas()
    pal = ramp(col, 5, 0.45)
    out = hexc("#16141d")
    # horizontal arm, then down
    for x in range(8, 20):
        cv.px(x, 12, out); cv.px(x, 13, pal[3]); cv.px(x, 14, pal[2]); cv.px(x, 15, pal[1]); cv.px(x, 16, out)
    for y in range(12, 25):
        cv.px(17, y, out); cv.px(18, y, pal[3]); cv.px(19, y, pal[2]); cv.px(20, y, pal[1]); cv.px(21, y, out)
    # collars
    for y in range(11, 18):
        cv.px(7, y, pal[1]); cv.px(8, y, pal[4])
    for x in range(16, 23):
        cv.px(x, 24, pal[1]); cv.px(x, 25, pal[4])
    cv.px(19, 14, pal[4])
    return _fin(cv)


def debris():
    cv = Canvas()
    from PIL import Image, ImageDraw
    for pts, col in (([(6, 20), (16, 14), (20, 18), (11, 25)], "#8a93a3"), ([(15, 22), (24, 12), (27, 16), (19, 26)], "#6a7486"), ([(9, 13), (15, 9), (16, 12), (11, 16)], "#9aa3b3")):
        im = Image.new("L", (32, 32), 0)
        ImageDraw.Draw(im).polygon(pts, fill=1)
        shaded_fill(cv, np.array(im).astype(bool), col, 0.45)
    p = ramp("#5a6272", 5, 0.4)
    for (x, y) in ((12, 19), (21, 17), (12, 12)):
        cv.px(x, y, p[0])  # rivet holes
    return _fin(cv)


# ------------------------------------------------------------------ weapons (tg melee)
def blade(cv, x0, y0, x1, y1, width=2, col=MET):
    """A diagonal blade from (x0,y0) to the tip at (x1,y1), bright edge on top."""
    p = ramp(col, 5, 0.5)
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t = i / n
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        w = width if t < 0.8 else max(1, width - 1)
        for k in range(w):
            cv.px(x, y + k, p[4] if k == 0 else (p[2] if k < w - 1 else p[1]))


def fireaxe():
    cv = Canvas()
    thick_line(cv, 7, 27, 22, 8, ramp("#c83a2a", 5, 0.4), 2)  # red haft
    p = ramp(MET, 5, 0.5)
    # axe head: a wedge on one side of the haft's top, a spike on the other
    head = rrect_mask(32, 32, 20, 4, 27, 12, 2)
    shaded_fill(cv, head, "#b8c2cc", 0.5)
    for y in range(4, 13):
        cv.px(27, y, p[4])
    for i in range(3):
        cv.px(17 - i, 9 + i, p[3])
    cv.px(8, 26, hexc("#1a1a20"))
    cv.px(9, 25, hexc("#1a1a20"))
    return _fin(cv)


def knife(kind):
    cv = Canvas()
    if kind == "kitchen":
        thick_line(cv, 8, 24, 13, 19, ramp("#2a2a30", 3, 0.4), 2)
        blade(cv, 13, 17, 25, 7, 3)
    elif kind == "cleaver":
        thick_line(cv, 8, 25, 12, 21, ramp("#6a4a2e", 3, 0.4), 2)
        m = rrect_mask(32, 32, 12, 9, 24, 20, 1)
        shaded_fill(cv, m, "#c8d0d8", 0.5)
        for x in range(12, 25):
            cv.px(x, 20, hexc("#f0f4f8"))
        cv.px(22, 11, hexc("#3a3f4a"))
    else:  # survival knife
        thick_line(cv, 8, 24, 13, 19, ramp("#3a4a2e", 3, 0.4), 2)
        cv.px(13, 18, hexc("#b0b8c4"))
        cv.px(14, 19, hexc("#b0b8c4"))
        blade(cv, 14, 16, 24, 7, 3, "#c8ccd4")
        for i in range(0, 8, 2):
            cv.px(15 + i, 15 - i, hexc("#6a7486"))  # serrations
    return _fin(cv)


def riot_shield():
    cv = Canvas()
    body = rrect_mask(32, 32, 8, 4, 23, 27, 3)
    shaded_fill(cv, body, "#6a8aa8", 0.35)
    win = rrect_mask(32, 32, 10, 7, 21, 13, 1)
    shaded_fill(cv, win, "#a8d0e8", 0.3)
    for y in range(16, 26, 3):
        cv.hline(10, 21, y, shade(hexc("#6a8aa8"), -0.25))
    cv.hline(11, 20, 15, hexc("#e8eef4"))
    return _fin(cv)


def bat():
    cv = Canvas()
    p = ramp("#b8864a", 5, 0.45)
    for i in range(18):
        t = i / 17
        x = int(round(6 + 18 * t))
        y = int(round(27 - 20 * t))
        w = 1 + int(t * 3)
        for k in range(-(w // 2), w - w // 2):
            cv.px(x + k, y, p[3] if k < 0 else p[1])
            cv.px(x + k, y + 1, p[2])
    cv.px(6, 27, hexc("#3a2a1a"))
    cv.px(7, 26, hexc("#3a2a1a"))
    return _fin(cv)


# ------------------------------------------------------------------ improvised (crafting)
def shiv():
    """A glass shard with a cable-wrapped grip."""
    cv = Canvas()
    from PIL import Image, ImageDraw
    im = Image.new("L", (32, 32), 0)
    ImageDraw.Draw(im).polygon([(14, 17), (23, 6), (25, 8), (17, 19)], fill=1)
    shaded_fill(cv, np.array(im).astype(bool), "#9fd0ec", 0.45)
    for i in range(7):
        cv.px(17 + i, 16 - i, hexc("#e2f6ff"))
    wrap = ramp("#d83a3a", 4, 0.45)
    for i in range(6):
        x, y = 9 + i, 24 - i
        cv.px(x, y, wrap[2 + (i % 2)])
        cv.px(x + 1, y, wrap[1])
        cv.px(x, y + 1, wrap[0])
    return _fin(cv)


def spear():
    """A metal rod with a glass shard lashed on with cable."""
    cv = Canvas()
    thick_line(cv, 4, 29, 22, 11, ramp("#8a93a3", 5, 0.45), 2)
    from PIL import Image, ImageDraw
    im = Image.new("L", (32, 32), 0)
    ImageDraw.Draw(im).polygon([(21, 10), (28, 2), (29, 4), (24, 13)], fill=1)
    shaded_fill(cv, np.array(im).astype(bool), "#9fd0ec", 0.45)
    for i in range(5):
        cv.px(23 + i, 8 - i, hexc("#e2f6ff"))
    wrap = ramp("#d83a3a", 4, 0.45)
    for i in range(3):
        cv.px(19 + i, 13 - i, wrap[3])
        cv.px(20 + i, 13 - i, wrap[1])
    return _fin(cv)


def molotov(lit=False):
    """A bottle of spirits with a paper rag stuffed in the neck."""
    cv = Canvas()
    m = rrect_mask(32, 32, 12, 13, 19, 26, 2)
    shaded_fill(cv, m, "#4a8a3a", 0.45)
    cv.rect(14, 8, 17, 12, shade(hexc("#4a8a3a"), -0.2))
    cv.rect(13, 18, 18, 21, hexc("#e8e0c8"))
    rag = ramp("#e8e0c8", 4, 0.4)
    for (x, y, k) in ((15, 7, 3), (16, 6, 2), (17, 5, 3), (18, 4, 1), (14, 6, 1)):
        cv.px(x, y, rag[k])
    if lit:
        for (x, y, c) in ((17, 3, "#ffd84a"), (18, 2, "#ff9a3a"), (16, 2, "#ffd84a"), (17, 1, "#ff6a2a"), (18, 3, "#ffe89a")):
            cv.px(x, y, hexc(c))
    return _fin(cv)


def cable_cuffs():
    """Two loops of cable coil twisted into restraints."""
    cv = Canvas()
    for cx, cy in ((11, 18), (21, 18)):
        ring = ellipse_mask(32, 32, cx, cy, 5.0, 4.2) & ~ellipse_mask(32, 32, cx, cy, 2.9, 2.2)
        shaded_fill(cv, ring, "#d83a3a", 0.45)
    for x in range(15, 18):
        cv.px(x, 15 + (x % 2), hexc("#ff7a6a" if x % 2 else "#a82a2a"))
    return _fin(cv)


# ------------------------------------------------------------------ tg gadgets
def _box(cv, x0, y0, x1, y1, col, r=1, spread=0.4):
    shaded_fill(cv, rrect_mask(32, 32, x0, y0, x1, y1, r), col, spread)


def flash():
    cv = Canvas()
    _box(cv, 12, 14, 19, 26, "#3a3f4a")
    _box(cv, 10, 8, 21, 14, "#c8ccd4", 2)
    cv.rect(12, 9, 19, 12, hexc("#f4f8ff"))
    cv.px(13, 10, hexc("#ffffff"))
    cv.rect(14, 18, 17, 19, hexc("#d83a3a"))
    return _fin(cv)


def pepperspray():
    cv = Canvas()
    _box(cv, 12, 11, 19, 27, "#c83a2a", 2)
    cv.rect(13, 16, 18, 20, hexc("#e8e0c8"))
    cv.rect(14, 7, 17, 10, hexc("#2a2e38"))
    cv.px(18, 8, hexc("#2a2e38"))
    return _fin(cv)


def spray_bottle():
    cv = Canvas()
    _box(cv, 11, 13, 20, 27, "#6ab8e8", 3, 0.35)
    for y in range(15, 26):
        cv.px(12, y, hexc("#bfe6ff"))
    cv.rect(14, 8, 19, 12, hexc("#e8e8e8"))
    cv.rect(19, 9, 22, 10, hexc("#e8e8e8"))
    cv.rect(13, 18, 18, 21, hexc("#2a6ad8"))
    return _fin(cv)


def lighter(lit):
    cv = Canvas()
    _box(cv, 13, 15, 19, 26, "#d83a3a", 1)
    cv.rect(13, 12, 19, 14, hexc("#b0b8c4"))
    cv.px(15, 11, hexc("#6a7486"))
    if lit:
        for (x, y, c) in ((16, 10, "#ffe89a"), (16, 9, "#ffd84a"), (17, 8, "#ff9a3a"), (16, 7, "#ff6a2a"), (15, 9, "#ffd84a")):
            cv.px(x, y, hexc(c))
    return _fin(cv)


def cigarette(lit):
    cv = Canvas()
    for i in range(12):
        x, y = 9 + i, 20 - i // 2
        cv.px(x, y, hexc("#f4f0e8") if i > 3 else hexc("#d8a060"))
        cv.px(x, y + 1, hexc("#c8c4bc") if i > 3 else hexc("#b88040"))
    if lit:
        cv.px(21, 14, hexc("#ff6a2a"))
        cv.px(21, 15, hexc("#ffb05a"))
        cv.px(22, 12, hexc("#b0b8c4", 0.6))
        cv.px(23, 10, hexc("#b0b8c4", 0.4))
    return _fin(cv)


def cig_pack():
    cv = Canvas()
    _box(cv, 11, 9, 20, 25, "#e8e8e8", 1, 0.3)
    cv.rect(11, 9, 20, 12, hexc("#d83a3a"))
    cv.rect(13, 16, 18, 19, hexc("#d83a3a"))
    cv.px(13, 8, hexc("#d8a060"))
    cv.px(15, 8, hexc("#d8a060"))
    return _fin(cv)


def pen():
    cv = Canvas()
    for i in range(16):
        x, y = 8 + i, 24 - i
        cv.px(x, y, hexc("#2a4ad8") if i > 2 else hexc("#c8ccd4"))
        cv.px(x + 1, y, hexc("#1a2a8a") if i > 2 else hexc("#8a93a3"))
    cv.px(8, 25, hexc("#1d1b22"))
    cv.px(21, 12, hexc("#e8e8e8"))
    return _fin(cv)


def gauze():
    cv = Canvas()
    m = ellipse_mask(32, 32, 16, 18, 7, 6)
    shaded_fill(cv, m, "#f4f0e8", 0.3)
    cv.rect(15, 17, 17, 19, hexc("#c8c4bc"))
    for x in range(10, 23, 3):
        cv.px(x, 15, hexc("#d8d4cc"))
    return _fin(cv)


def medipen():
    cv = Canvas()
    for i in range(14):
        x, y = 9 + i, 23 - i
        for k in range(3):
            cv.px(x + k - 1, y, hexc("#e8e8e8") if i > 3 else hexc("#d83a3a"))
    cv.px(22, 9, hexc("#b0b8c4"))
    cv.px(23, 8, hexc("#b0b8c4"))
    for i in range(6, 11):
        cv.px(9 + i, 23 - i, hexc("#e8c83a"))
    return _fin(cv)


def defib():
    cv = Canvas()
    _box(cv, 8, 10, 23, 26, "#e8e0c8", 2, 0.35)
    cv.rect(10, 12, 21, 15, hexc("#3a8a3a"))
    cv.px(13, 13, hexc("#9aff9a"))
    cv.px(14, 14, hexc("#9aff9a"))
    cv.px(15, 12, hexc("#9aff9a"))
    for (x0, y0) in ((10, 18), (17, 18)):
        cv.rect(x0, y0, x0 + 4, y0 + 5, hexc("#2a2e38"))
        cv.rect(x0 + 1, y0 + 1, x0 + 3, y0 + 3, hexc("#d83a3a"))
    return _fin(cv)


def energy_gun(body, accent, lamp=None):
    cv = Canvas()
    _box(cv, 7, 12, 25, 18, body, 2)
    cv.rect(10, 18, 14, 25, hexc(body))
    cv.rect(11, 19, 13, 24, shade(hexc(body), -0.2))
    cv.rect(20, 13, 26, 16, hexc(accent))
    cv.px(26, 14, hexc("#ffffff"))
    for x in range(9, 18, 2):
        cv.px(x, 14, hexc(accent))
    if lamp:
        cv.px(17, 16, hexc(lamp))
        cv.px(18, 16, hexc(lamp))
    return _fin(cv)


def grenade(col, band, active):
    cv = Canvas()
    m = rrect_mask(32, 32, 12, 12, 20, 27, 3)
    shaded_fill(cv, m, col, 0.4)
    cv.hline(12, 20, 17, hexc(band))
    cv.hline(12, 20, 18, hexc(band))
    cv.rect(14, 8, 18, 11, hexc("#8a93a3"))
    cv.rect(19, 9, 22, 10, hexc("#8a93a3"))
    if active:
        cv.px(16, 7, hexc("#ff4a3a"))
        cv.px(15, 7, hexc("#ff8a6a"))
    else:
        cv.px(22, 11, hexc("#c8ccd4"))
        cv.px(23, 12, hexc("#c8ccd4"))
    return _fin(cv)


def sunglasses():
    cv = Canvas()
    for cx in (12, 20):
        m = ellipse_mask(32, 32, cx, 17, 3.6, 2.8)
        shaded_fill(cv, m, "#1d1b22", 0.2)
        cv.px(cx - 2, 16, hexc("#6a7486"))
    cv.hline(15, 17, 16, hexc("#2a2e38"))
    cv.hline(6, 8, 16, hexc("#2a2e38"))
    cv.hline(24, 26, 16, hexc("#2a2e38"))
    return _fin(cv)


def welding_helmet():
    cv = Canvas()
    m = rrect_mask(32, 32, 8, 8, 23, 25, 5)
    shaded_fill(cv, m, "#4a5262", 0.4)
    cv.rect(11, 15, 20, 18, hexc("#101720"))
    cv.hline(12, 19, 15, hexc("#3a4a5a"))
    cv.hline(10, 21, 10, hexc("#e8c83a"))
    return _fin(cv)


# ------------------------------------------------------------------ surgery (tg)
def scalpel():
    cv = Canvas()
    m = ramp(MET, 5, 0.45)
    h = ramp("#5a8ab8", 5, 0.4)
    thick_line(cv, 8, 24, 16, 16, h, 2)
    thick_line(cv, 17, 15, 21, 11, m, 2)
    cv.px(22, 10, m[4])
    cv.px(23, 9, m[3])
    cv.px(20, 11, m[4])
    return _fin(cv)


def hemostat():
    cv = Canvas()
    m = ramp(MET, 5, 0.45)
    for (x, y) in ((8, 23), (12, 25)):  # finger rings
        ring = ellipse_mask(32, 32, x, y, 2.6, 2.6) & ~ellipse_mask(32, 32, x, y, 1.2, 1.2)
        shaded_fill(cv, ring, MET, 0.4)
    thick_line(cv, 10, 21, 17, 14, m, 1)
    thick_line(cv, 13, 23, 18, 15, m, 1)
    thick_line(cv, 18, 14, 24, 8, m, 1)
    cv.px(17, 15, m[4])
    return _fin(cv)


def retractor():
    cv = Canvas()
    m = ramp(MET, 5, 0.45)
    thick_line(cv, 9, 23, 20, 12, m, 2)
    for k in range(4):  # the hooked blade
        cv.px(21 + k, 11 - k // 2, m[3])
    cv.vline(24, 9, 14, m[2])
    cv.px(23, 14, m[1])
    return _fin(cv)


def cautery():
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 8, 17, 18, 21, 2)
    shaded_fill(cv, body, "#d8a53a", 0.4)
    m = ramp(MET, 5, 0.45)
    cv.hline(19, 23, 19, m[3])
    cv.hline(19, 23, 20, m[1])
    _fin(cv)
    sp.g(24, 19, hexc("#ff7a2a"))
    sp.g(24, 20, hexc("#ffb84a"))
    return sp


def circular_saw():
    cv = Canvas()
    body = rrect_mask(32, 32, 6, 15, 17, 22, 2)
    shaded_fill(cv, body, "#4a8ad8", 0.4)
    blade = ellipse_mask(32, 32, 21, 18, 6, 6)
    shaded_fill(cv, blade, "#b8c2cc", 0.4)
    m = ramp(MET, 5, 0.45)
    for a in range(0, 360, 30):
        x = 21 + int(round(6.4 * np.cos(np.radians(a))))
        y = 18 + int(round(6.4 * np.sin(np.radians(a))))
        cv.px(x, y, m[4])
    cv.px(21, 18, m[0])
    cv.rect(8, 22, 11, 25, hexc("#2a2e38"))  # grip
    return _fin(cv)


def drapes():
    cv = Canvas()
    m = rrect_mask(32, 32, 7, 11, 24, 23, 2)
    shaded_fill(cv, m, "#4ab8a8", 0.35)
    p = ramp("#4ab8a8", 5, 0.35)
    for y in (14, 17, 20):
        cv.hline(8, 23, y, p[1])
    return _fin(cv)


def build(manifest):
    from common import save
    pk = Packer(1024)
    from sky_items import build_into as sky_items_build
    sky_items_build(pk)
    pk.add("wrench", wrench())
    pk.add("crowbar", crowbar())
    pk.add("screwdriver", screwdriver())
    pk.add("wirecutters", wirecutters())
    pk.add("welder", welder(False))
    pk.add("welder_on", welder(True))
    pk.add("multitool", multitool())
    pk.add("cable_coil", cable_coil())
    pk.add("sheet_metal", sheets("#9aa3b3"))
    pk.add("sheet_glass", sheets("#9fd0ec"))
    pk.add("sheet_rglass", rglass_sheets())
    pk.add("sheet_plasteel", sheets("#6a7486"))
    pk.add("sheet_wood", sheets("#8a5a3b"))
    pk.add("sheet_plasma", sheets("#b04ae8"))
    pk.add("light_tube", light_tube())
    pk.add("glass_shard", shard("large"))
    pk.add("glass_shard_medium", shard("medium"))
    pk.add("glass_shard_small", shard("small"))
    pk.add("rods", rods())
    for layer, col in (("supply", "#3a7ad8"), ("scrub", "#d84a3a"), ("hot", "#e8903a"), ("cold", "#3ad0d8")):
        pk.add(f"pipe_item_{layer}", pipe_item(col))
    pk.add("scalpel", scalpel())
    pk.add("hemostat", hemostat())
    pk.add("retractor", retractor())
    pk.add("cautery", cautery())
    pk.add("circular_saw", circular_saw())
    pk.add("surgical_drapes", drapes())
    pk.add("debris", debris())
    pk.add("extinguisher", extinguisher())
    pk.add("tank_o2", tank("#3a6ad8"))
    pk.add("tank_air", tank("#b0b8c4"))
    pk.add("tank_plasma", tank("#e87a2a"))
    pk.add("tank_fuel", tank("#d8a53a"))
    pk.add("gas_mask", gas_mask())
    for k, col in (("gen", "#6a7486"), ("eng", "#d8a53a"), ("med", "#e8eef4"), ("sec", "#8a2a33"), ("sci", "#7a5ab8"), ("cmd", "#3a5ab8"), ("srv", "#4a9a6a"), ("cargo", "#b8823a")):
        pk.add(f"coat_{k}", coat(col))
    pk.add("medkit", medkit())
    pk.add("medkit_burn", medkit("#e8a83a", "#e8eef4"))
    pk.add("medkit_toxin", medkit("#4ab83a", "#e8eef4"))
    pk.add("medkit_o2", medkit("#3a6ad8", "#e8eef4"))
    pk.add("bruise_pack", pack("#e8eef4", "#d83a3a"))
    pk.add("ointment", pack("#e8e0c8", "#e8a83a"))
    pk.add("syringe", syringe())
    pk.add("pill_bottle", pill_bottle("#e84a4a"))
    pk.add("beaker", beaker())
    pk.add("beaker_filled", beaker("#4ab8d8"))
    pk.add("health_analyzer", analyzer())
    pk.add("gas_analyzer", gas_analyzer())
    for k, col in (("gen", "#9aa3b3"), ("eng", "#d8a53a"), ("med", "#4ab8d8"), ("sec", "#d84a4a"), ("sci", "#a87ae8"), ("cmd", "#4a8ad8"), ("cap", "#d8b84a"), ("srv", "#5ac87a"), ("cargo", "#c8883a")):
        pk.add(f"id_{k}", id_card(col))
    pk.add("headset", headset())
    pk.add("flashlight", flashlight())
    pk.add("flashlight_on", flashlight(True))
    pk.add("baton", baton())
    pk.add("handcuffs", cuffs())
    for k, col in (("red", "#c83a3a"), ("blue", "#3a6ad8"), ("yellow", "#d8a53a")):
        pk.add(f"toolbox_{k}", toolbox(col))
    pk.add("mop", mop())
    pk.add("bucket", bucket())
    pk.add("pickaxe", pickaxe())
    pk.add("fireaxe", fireaxe())
    pk.add("knife_kitchen", knife("kitchen"))
    pk.add("knife_cleaver", knife("cleaver"))
    pk.add("knife_survival", knife("survival"))
    pk.add("riot_shield", riot_shield())
    pk.add("baseball_bat", bat())
    pk.add("ore_iron", ore("#9a6a4a"))
    pk.add("ore_plasma", ore("#9a4ad8"))
    pk.add("ore_cryo", ore("#4ad8e8"))
    pk.add("ore_gold", ore("#e8c83a"))
    for k in ("sandwich", "soup", "burger", "donut", "pizza", "ration", "meat", "flour", "egg", "tomato", "potato", "berries", "wheat", "banana", "banana_peel"):
        pk.add(f"food_{k}", food(k))
    for k in ("cocoa", "water", "soda", "coffee", "booze"):
        pk.add(f"drink_{k}", drink(k))
    pk.add("paper", misc_paper())
    pk.add("shiv", shiv())
    pk.add("spear", spear())
    pk.add("molotov", molotov(False))
    pk.add("molotov_lit", molotov(True))
    pk.add("cable_cuffs", cable_cuffs())
    pk.add("flash", flash())
    pk.add("pepperspray", pepperspray())
    pk.add("spray_bottle", spray_bottle())
    pk.add("lighter", lighter(False))
    pk.add("lighter_on", lighter(True))
    pk.add("cigarette", cigarette(False))
    pk.add("cigarette_lit", cigarette(True))
    pk.add("cig_pack", cig_pack())
    pk.add("pen", pen())
    pk.add("gauze", gauze())
    pk.add("medipen", medipen())
    pk.add("defib", defib())
    pk.add("disabler", energy_gun("#e8e8e8", "#6ac8ff"))
    pk.add("laser_gun", energy_gun("#6a7486", "#ff4a3a"))
    pk.add("egun_stun", energy_gun("#9aa3b3", "#6ac8ff", "#6ac8ff"))
    pk.add("egun_kill", energy_gun("#9aa3b3", "#ff4a3a", "#ff4a3a"))
    pk.add("flashbang", grenade("#5a6272", "#e8e8e8", False))
    pk.add("flashbang_active", grenade("#5a6272", "#e8e8e8", True))
    pk.add("smoke_grenade", grenade("#6a7486", "#9a9a9a", False))
    pk.add("smoke_grenade_active", grenade("#6a7486", "#9a9a9a", True))
    pk.add("sunglasses", sunglasses())
    pk.add("welding_helmet", welding_helmet())
    pk.add("soap", soap())
    pk.add("ice_chunk", ice_chunk())
    pk.add("glowstick", glowstick("#5aff9a"))
    import tgport
    tgport.add_items(pk)
    # second-generation drawings replace the first ones (see items_v2.py)
    import items_v2
    have = {n for n, _ in pk.items}
    for name, fn in items_v2.REDRAWN.items():
        if name in have:
            pk.replace(name, fn())
    # brand new items drawn only in the second generation
    for name, fn in items_v2.NEW.items():
        if name not in have:
            pk.add(name, fn())
    # 12x12 in-hand versions of everything (see inhands.py)
    from inhands import shrink
    import handheld
    for name, cv in list(pk.items):
        if not name.endswith("_glow"):
            pk.add("held_" + name, shrink(cv))
            # tg-style held views: grip at the centre, turned the way it's held
            for v, vc in handheld.views(name, cv).items():
                pk.add("ih_%s_%s" % (name, v), vc)
    import props_fx
    props_fx.finish_items(pk)
    sheet, placed = pk.pack()
    save(sheet, "items.png")
    manifest["items"] = {k: list(v) for k, v in placed.items()}
