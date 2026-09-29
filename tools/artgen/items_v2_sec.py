"""Item icons, second generation: security, weapons and gear (see items_v2.py)."""
import math

import numpy as np

from common import hexc, mix, shade
from items_v2 import (DARK_STEEL, GUNMETAL, REDRAWN, RUBBER, STEEL, W, WHITE, _cv, _sub, ball, box, cyl,
                      dots, glint, glowing, item, new_item, rod)
from px import (capsule_height, capsule_mask, cyl_height, ell_m, finish, poly_mask, rect_m, shade_mask,
                sphere_height)


@item("baton")
def baton():
    cv = _cv()
    rod(cv, 6, 26, 12, 20, 2.3, RUBBER, "rubber")
    rod(cv, 12, 20, 24, 8, 1.9, "#2e3038", "metal")
    for t in (0.35, 0.65):
        x, y = 12 + 12 * t, 20 - 12 * t
        cv.px(int(x), int(y), hexc("#e8c030"))
        cv.px(int(x) + 1, int(y) - 1, hexc("#e8c030"))
    rod(cv, 24, 8, 26, 6, 2.0, STEEL, "chrome")
    finish(cv)
    return glowing(cv, [(26, 6, "#9ad8ff"), (27, 5, "#6ab8ff"), (25, 7, "#bfe8ff")])


def _cuffs(col, mat, chain_col):
    cv = _cv()
    for cx, cy in ((10, 17), (22, 15)):
        ring = ell_m(W, W, cx, cy, 5.5, 5.5) & ~ell_m(W, W, cx, cy, 3.2, 3.2)
        shade_mask(cv, ring, col, mat, bevel=1.2)
        box(cv, cx - 1, cy - 7, cx + 1, cy - 5, col, mat, 0, 1)
    for x in range(15, 18):
        cv.px(x, 16 - (x - 15) % 2, hexc(chain_col))
    return finish(cv)


REDRAWN["handcuffs"] = lambda: _cuffs("#c8d0dc", "chrome", "#8a94a4")
REDRAWN["cable_cuffs"] = lambda: _cuffs("#d0342e", "rubber", "#8a2a2a")


@item("flash")
def flash():
    cv = _cv()
    rod(cv, 7, 25, 16, 16, 2.6, "#2e3038", "plastic")
    head = ell_m(W, W, 20, 12, 5.2, 5.2)
    shade_mask(cv, head, DARK_STEEL, "metal", height=sphere_height(head) * 0.6)
    bulb = ell_m(W, W, 20.5, 11.5, 3.3, 3.3)
    shade_mask(cv, bulb, "#e8f4ff", "glass", height=sphere_height(bulb))
    cv.px(10, 22, hexc("#d83a3a"))
    return finish(cv)


@item("pepperspray")
def pepperspray():
    cv = _cv()
    pal, body = cyl(cv, 12, 12, 20, 27, "#c8342e", "paint", 2)
    box(cv, 13, 17, 19, 22, "#f4f0e8", "paper", 0, 1)
    dots(cv, ((15, 19), (16, 20), (17, 19)), "#d85020")
    cyl(cv, 13, 8, 19, 12, "#2c2a33", "plastic", 1)
    box(cv, 18, 8, 21, 9, "#2c2a33", "plastic", 0, 1)
    return finish(cv)


def _egun(body, accent, lamp=None, barrel_col=None):
    cv = _cv()
    shape = poly_mask(W, W, [(4, 11), (23, 11), (26, 13), (26, 17), (14, 17), (12, 19), (4, 18)])
    pal = shade_mask(cv, shape, body, "plastic", bevel=2)
    shade_mask(cv, poly_mask(W, W, [(6, 17), (12, 17), (11, 27), (5, 27)]), "#3a3e4a", "rubber", bevel=1.5)
    cyl(cv, 24, 13, 28, 16, barrel_col or DARK_STEEL, "metal", 1, "h")
    cv.hline(5, 22, 12, mix(pal[-1], WHITE, 0.45))
    cv.px(13, 19, hexc("#2a2c34"))
    cv.px(13, 20, hexc("#2a2c34"))
    glow = [(28, 14, accent), (28, 15, accent)]
    for x in range(15, 21):
        glow.append((x, 14, accent))
    if lamp:
        glow.append((7, 14, lamp))
    finish(cv)
    return glowing(cv, glow)


REDRAWN["disabler"] = lambda: _egun("#e8ecf2", "#5ac8ff")
REDRAWN["laser_gun"] = lambda: _egun("#5a6272", "#ff4a3a")
REDRAWN["egun_stun"] = lambda: _egun("#9aa3b3", "#5ac8ff", "#5ac8ff", "#3a6ad8")
REDRAWN["egun_kill"] = lambda: _egun("#9aa3b3", "#ff4a3a", "#ff4a3a", "#c83a3a")


@item("revolver")
def revolver():
    cv = _cv()
    rod(cv, 12, 12, 27, 12, 1.6, GUNMETAL, "metal")
    body = poly_mask(W, W, [(8, 10), (16, 10), (17, 17), (9, 17)])
    shade_mask(cv, body, GUNMETAL, "metal", bevel=1.5)
    cyl_m = ell_m(W, W, 14, 14, 3.2, 3.2)
    cp = shade_mask(cv, cyl_m, DARK_STEEL, "metal", height=sphere_height(cyl_m) * 0.6)
    dots(cv, ((13, 13), (15, 13), (14, 15)), cp[0])
    grip = poly_mask(W, W, [(8, 16), (13, 16), (11, 27), (5, 26)])
    shade_mask(cv, grip, "#7a4a2a", "paint", bevel=1.5)
    for y in (19, 22):
        cv.px(8, y, hexc("#5a3218"))
        cv.px(9, y + 1, hexc("#5a3218"))
    rod(cv, 7, 9, 8, 11, 0.8, DARK_STEEL, "metal")
    cv.px(27, 10, hexc(DARK_STEEL))
    return finish(cv)


@item("shotgun")
def shotgun():
    cv = _cv()
    # long gun pointing right: wooden stock at the left, steel receiver, barrel and pump
    stock = poly_mask(W, W, [(1, 16), (9, 13), (11, 17), (3, 21)])
    shade_mask(cv, stock, "#8a5a32", "paint", bevel=1.5)
    box(cv, 9, 12, 16, 16, GUNMETAL, "metal", 1, 1.2)
    rod(cv, 16, 13, 30, 13, 1.1, DARK_STEEL, "metal")
    rod(cv, 17, 15, 28, 15, 1.2, "#2e3038", "metal")
    box(cv, 19, 14, 25, 17, "#7a4a2a", "paint", 1, 1)
    cv.px(12, 17, hexc("#2a2c34"))
    cv.px(12, 18, hexc("#2a2c34"))
    return finish(cv)


def _ammo_box(band):
    cv = _cv()
    pal, bx = box(cv, 7, 11, 24, 25, "#5a5f6a", "paint", 1, 2)
    cv.a[rect_m(W, W, 7, 15, 24, 19, 0) & bx] = np.array(hexc(band))
    for x in range(9, 23, 3):
        ball(cv, x + 0.5, 9.5, 1.3, 1.6, "#d8b040", "metal")
    cv.hline(10, 21, 17, hexc("#f4f0e8"))
    return finish(cv)


REDRAWN["ammo_38"] = lambda: _ammo_box("#d84a4a")
REDRAWN["ammo_38_rubber"] = lambda: _ammo_box("#4a8ad8")


def _shell(col):
    cv = _cv()
    # three shells standing side by side: coloured hull, ridged brass base
    for x0 in (8, 14, 20):
        hull = rect_m(W, W, x0, 9, x0 + 4, 21, 1)
        pal = shade_mask(cv, hull, col, "plastic", height=cyl_height(hull, "v"))
        cv.hline(x0 + 1, x0 + 3, 9, pal[0])
        base = rect_m(W, W, x0, 21, x0 + 4, 26, 0)
        bp = shade_mask(cv, base, "#d8b040", "metal", height=cyl_height(base, "v"))
        cv.hline(x0, x0 + 4, 23, bp[1])
    return finish(cv)


REDRAWN["shell_beanbag"] = lambda: _shell("#4ab84a")
REDRAWN["shell_buckshot"] = lambda: _shell("#d83a3a")
REDRAWN["shell_slug"] = lambda: _shell("#4a4e58")


@item("riot_shield")
def riot_shield():
    cv = _cv()
    sh = rect_m(W, W, 7, 3, 24, 29, 3)
    shade_mask(cv, sh, "#a8c8e0", "glass", height=cyl_height(sh, "h") * 0.6)
    frame = sh & ~rect_m(W, W, 8, 4, 23, 28, 2)
    cv.a[frame] = np.array(hexc(GUNMETAL))
    box(cv, 9, 20, 22, 23, "#2e3038", "plastic", 0, 1)
    dots(cv, ((11, 21), (12, 21), (13, 21), (14, 21), (15, 21)), "#e8eef4")
    cv.line(10, 6, 10, 15, WHITE)
    return finish(cv)


def _grenade(col, band, active):
    cv = _cv()
    body = ell_m(W, W, 15, 18, 6, 8)
    pal = shade_mask(cv, body, col, "metal", height=sphere_height(body))
    cv.a[rect_m(W, W, 9, 17, 21, 18, 0) & body] = np.array(hexc(band))
    cyl(cv, 12, 8, 18, 11, DARK_STEEL, "metal", 1)
    rod(cv, 18, 9, 22, 14, 0.9, STEEL, "metal")
    ring = ell_m(W, W, 11, 8, 2.2, 2.2) & ~ell_m(W, W, 11, 8, 1.2, 1.2)
    if not active:
        shade_mask(cv, ring, "#d8dee8", "chrome", bevel=1)
    finish(cv)
    if not active:
        return cv
    return glowing(cv, [(15, 9, "#ff4a3a"), (16, 9, "#ff4a3a")])


REDRAWN["flashbang"] = lambda: _grenade("#5a6272", "#e8e8e8", False)
REDRAWN["flashbang_active"] = lambda: _grenade("#5a6272", "#e8e8e8", True)
REDRAWN["smoke_grenade"] = lambda: _grenade("#7a8290", "#9a9a9a", False)
REDRAWN["smoke_grenade_active"] = lambda: _grenade("#7a8290", "#9a9a9a", True)


@item("sunglasses")
def sunglasses():
    cv = _cv()
    for cx in (10, 21):
        lens = rect_m(W, W, cx - 5, 13, cx + 4, 19, 3)
        shade_mask(cv, lens, "#1c1c28", "glass", bevel=2, alpha=1.0)
        cv.line(cx - 3, 14, cx - 1, 14, hexc("#6a7aa8"))
    rod(cv, 14, 14, 16, 14, 0.8, "#2a2a32", "metal")
    rod(cv, 4, 14, 2, 17, 0.7, "#2a2a32", "metal")
    rod(cv, 26, 14, 28, 17, 0.7, "#2a2a32", "metal")
    return finish(cv)


@new_item("glasses")
def glasses():
    # tg regular prescription glasses: thin frames, clear lenses
    cv = _cv()
    for cx in (10, 21):
        lens = rect_m(W, W, cx - 5, 13, cx + 4, 19, 3)
        shade_mask(cv, lens, "#b8d4ea", "glass", bevel=2, alpha=0.55)
        cv.line(cx - 3, 14, cx - 1, 14, hexc("#ffffff"))
    for cx in (10, 21):
        cv.hline(cx - 5, cx + 4, 13, hexc("#3a3a44"))
    rod(cv, 14, 14, 16, 14, 0.8, "#3a3a44", "metal")
    rod(cv, 4, 14, 2, 17, 0.7, "#3a3a44", "metal")
    rod(cv, 26, 14, 28, 17, 0.7, "#3a3a44", "metal")
    return finish(cv)


@item("welding_helmet")
def welding_helmet():
    cv = _cv()
    shell = ell_m(W, W, 16, 17, 10, 11)
    shade_mask(cv, shell, "#d8a530", "paint", height=sphere_height(shell))
    box(cv, 10, 13, 22, 18, "#1a1e28", "glass", 1, 1)
    cv.hline(11, 17, 14, hexc("#3a5a8a"))
    for y in (21, 23):
        cv.hline(12, 20, y, shade(hexc("#d8a530"), -0.3))
    return finish(cv)


@item("headset")
def headset():
    cv = _cv()
    for a in range(180, 361, 6):
        for r in (8.0, 9.0):
            x = 16 + math.cos(math.radians(a)) * r
            y = 18 + math.sin(math.radians(a)) * r * 0.9
            cv.px(int(round(x)), int(round(y)), hexc("#3a3e4a") if r < 8.5 else hexc("#22242c"))
    for cx in (7, 25):
        cup = ell_m(W, W, cx, 19, 3.2, 4.2)
        shade_mask(cv, cup, "#2e3038", "rubber", height=sphere_height(cup))
    rod(cv, 25, 22, 19, 27, 0.8, "#3a3e4a", "plastic")
    ball(cv, 18, 27, 1.8, 1.4, "#2e3038", "rubber")
    cv.px(25, 18, hexc("#5aff9a"))
    return finish(cv)


# ------------------------------------------------------------------ melee & tools of violence
@item("fireaxe")
def fireaxe():
    cv = _cv()
    rod(cv, 4, 29, 20, 9, 1.4, "#c8342e", "paint")
    # a broad curved blade on one side of the head, a spike on the other
    blade = poly_mask(W, W, [(18, 6), (22, 5), (27, 3), (30, 8), (28, 14), (23, 13), (20, 11)])
    shade_mask(cv, blade, STEEL, "metal", bevel=1.5)
    cv.line(27, 4, 29, 9, WHITE)
    cv.line(29, 9, 28, 13, hexc("#e8eef6"))
    shade_mask(cv, poly_mask(W, W, [(19, 7), (14, 5), (18, 11)]), DARK_STEEL, "metal", bevel=1)
    ball(cv, 20, 9, 1.8, 1.8, "#c8342e", "paint")
    return finish(cv)


def _knife(kind):
    cv = _cv()
    if kind == "cleaver":
        rod(cv, 6, 27, 12, 21, 1.8, "#3a2a22", "paint")
        blade = poly_mask(W, W, [(11, 18), (19, 9), (27, 16), (19, 24)])
        shade_mask(cv, blade, "#c8d0dc", "chrome", bevel=1.5)
        cv.px(21, 12, hexc("#4a505e"))
    elif kind == "survival":
        rod(cv, 6, 27, 12, 21, 2.0, "#4a5a3a", "rubber")
        rod(cv, 11, 22, 13, 20, 2.4, GUNMETAL, "metal")
        blade = poly_mask(W, W, [(12, 19), (22, 8), (27, 5), (24, 11), (15, 22)])
        shade_mask(cv, blade, "#b8c0cc", "metal", bevel=1.2)
        for i in range(4):
            cv.px(17 + i * 2, 14 - i * 2, hexc("#6a7486"))
    else:
        rod(cv, 6, 27, 13, 20, 1.6, "#2e2a28", "paint")
        dots(cv, ((8, 25), (11, 22)), "#c8d0dc")
        blade = poly_mask(W, W, [(13, 19), (25, 6), (27, 6), (17, 21)])
        shade_mask(cv, blade, "#d8dee8", "chrome", bevel=1)
    return finish(cv)


REDRAWN["knife_kitchen"] = lambda: _knife("kitchen")
REDRAWN["knife_cleaver"] = lambda: _knife("cleaver")
REDRAWN["knife_survival"] = lambda: _knife("survival")


@item("baseball_bat")
def baseball_bat():
    cv = _cv()
    m = capsule_mask(W, W, 7, 26, 16, 15, 1.4) | capsule_mask(W, W, 16, 15, 25, 5, 3.0)
    h = np.maximum(capsule_height(W, W, 7, 26, 16, 15, 1.4), capsule_height(W, W, 16, 15, 25, 5, 3.0))
    shade_mask(cv, m, "#c8904a", "paint", height=h)
    rod(cv, 5, 28, 9, 24, 1.5, RUBBER, "rubber")
    ball(cv, 5, 28, 1.8, 1.8, "#c8904a", "paint")
    return finish(cv)


@item("spear")
def spear():
    cv = _cv()
    rod(cv, 2, 30, 21, 11, 1.1, "#9aa3b3", "metal")
    shade_mask(cv, poly_mask(W, W, [(20, 12), (26, 3), (29, 2), (28, 5), (21, 13)]) | poly_mask(W, W, [(19, 11), (22, 8), (24, 14)]), "#b8e4f4", "glass", bevel=1)
    for t in (0.55, 0.6):
        x, y = 2 + 19 * t, 30 - 19 * t
        cv.px(int(x), int(y), hexc("#d0342e"))
        cv.px(int(x) + 1, int(y), hexc("#d0342e"))
    return finish(cv)


@item("shiv")
def shiv():
    cv = _cv()
    rod(cv, 7, 26, 13, 20, 2.0, "#d0342e", "rubber")
    for i in range(3):
        cv.px(8 + i * 2, 24 - i * 2, hexc("#7a1a1a"))
    shade_mask(cv, poly_mask(W, W, [(12, 19), (17, 12), (25, 5), (21, 13), (15, 21)]), "#b8e4f4", "glass", bevel=1.2)
    return finish(cv)


def _molotov(lit):
    cv = _cv()
    body = poly_mask(W, W, [(10, 28), (21, 28), (21, 15), (18, 12), (18, 7), (13, 7), (13, 12), (10, 15)])
    shade_mask(cv, body, "#3a7a3a", "glass", height=cyl_height(body, "v"))
    cv.a[rect_m(W, W, 11, 20, 20, 27, 0) & body] = np.array(np.r_[hexc("#c8a040")[:3], 0.9])
    rag = poly_mask(W, W, [(13, 7), (18, 7), (19, 3), (16, 1), (12, 3)])
    shade_mask(cv, rag, "#e8e0c8", "cloth", bevel=1)
    finish(cv)
    if not lit:
        return cv
    return glowing(cv, [(15, 1, "#ffe070"), (16, 0, "#ffb040"), (14, 2, "#ff8a30"), (17, 2, "#ffb040"), (15, 2, "#fff0a0")])


REDRAWN["molotov"] = lambda: _molotov(False)
REDRAWN["molotov_lit"] = lambda: _molotov(True)


@item("pickaxe")
def pickaxe():
    cv = _cv()
    rod(cv, 5, 28, 18, 11, 1.3, "#8a5a32", "paint")
    head = poly_mask(W, W, [(9, 6), (15, 7), (22, 10), (27, 16), (22, 13), (15, 10), (9, 9)])
    shade_mask(cv, head, DARK_STEEL, "metal", bevel=1.3)
    cv.line(10, 7, 21, 10, hexc("#d8dee8"))
    return finish(cv)


@item("mop")
def mop():
    cv = _cv()
    rod(cv, 22, 3, 12, 22, 1.1, "#c8904a", "paint")
    head = poly_mask(W, W, [(6, 23), (18, 20), (21, 27), (7, 29)])
    pal = shade_mask(cv, head, "#e8e4d8", "cloth", bevel=1.5, noise=0.3, seed=9)
    for x in range(8, 21, 2):
        cv.vline(x, 26, 28, pal[1])
    box(cv, 10, 21, 15, 23, "#3a6ad8", "plastic", 0, 1)
    return finish(cv)


@item("bucket")
def bucket():
    cv = _cv()
    body = poly_mask(W, W, [(7, 11), (25, 11), (23, 27), (9, 27)])
    pal = shade_mask(cv, body, "#3a6ad8", "plastic", height=cyl_height(body, "v"))
    rim = ell_m(W, W, 16, 11, 9.5, 2.4)
    shade_mask(cv, rim, "#4a7ae8", "plastic", bevel=1)
    cv.a[ell_m(W, W, 16, 11, 8, 1.4)] = np.array(hexc("#2a4aa8"))
    for a in range(180, 361, 8):
        x = 16 + math.cos(math.radians(a)) * 9.5
        y = 10 + math.sin(math.radians(a)) * 6
        cv.px(int(round(x)), int(round(y)), hexc(STEEL))
    return finish(cv)


@item("wet_floor_sign")
def wet_floor_sign():
    cv = _cv()
    a = poly_mask(W, W, [(16, 3), (26, 28), (6, 28)])
    shade_mask(cv, a, "#f0c830", "plastic", bevel=1.5)
    cv.line(16, 3, 16, 28, hexc("#c89a20"))
    for (x, y) in ((14, 13), (15, 12), (15, 16), (14, 18), (16, 18), (13, 22), (17, 21)):
        cv.px(x, y, hexc("#2a2530"))
    cv.hline(8, 24, 25, hexc("#2a2530"))
    return finish(cv)


@item("gas_mask")
def gas_mask():
    cv = _cv()
    face = ell_m(W, W, 16, 15, 9, 9.5)
    pal = shade_mask(cv, face, "#3a3c46", "rubber", height=sphere_height(face))
    for cx in (12, 20):
        shade_mask(cv, ell_m(W, W, cx, 13, 3.4, 3.4), DARK_STEEL, "metal", bevel=1)
        lens = ell_m(W, W, cx, 13, 2.4, 2.4)
        shade_mask(cv, lens, "#5aa8d0", "glass", height=sphere_height(lens))
    fil = ell_m(W, W, 16, 22, 4.2, 3.6)
    fp = shade_mask(cv, fil, "#8a93a3", "metal", height=sphere_height(fil))
    for x in (14, 16, 18):
        cv.px(x, 22, fp[0])
    cv.hline(5, 7, 12, pal[0])
    cv.hline(25, 27, 12, pal[0])
    return finish(cv)


@item("extinguisher")
def extinguisher():
    cv = _cv()
    body = rect_m(W, W, 10, 9, 19, 28, 3)
    shade_mask(cv, body, "#d23a32", "paint", height=cyl_height(body, "v"))
    lab = rect_m(W, W, 12, 15, 17, 21, 0)
    shade_mask(cv, lab, "#eae4d4", "paper", height=cyl_height(lab, "v") * 0.6)
    for y in (17, 19):
        cv.hline(13, 16, y, hexc("#8a8078"))
    cv.px(14, 16, hexc("#d23a32"))
    box(cv, 12, 5, 17, 9, "#2e2c34", "metal", 1, 1.4)
    rod(cv, 13, 4, 21, 3, 0.9, STEEL, "chrome", 2)
    rod(cv, 18, 7, 23, 12, 1.0, RUBBER, "rubber")
    cv.px(23, 13, hexc("#1c1a22"))
    return finish(cv)
