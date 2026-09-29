"""Item icons, second generation: food, drink and everyday things (see items_v2.py)."""
import math

import numpy as np

from common import hexc, mix, shade
from items_v2 import (DARK_STEEL, GUNMETAL, REDRAWN, RUBBER, STEEL, W, WHITE, _cv, _sub, ball, box, cyl,
                      dots, glint, glowing, item, rod)
from px import (capsule_height, capsule_mask, cyl_height, ell_m, finish, poly_mask, rect_m, shade_mask,
                sphere_height)


def _rows(cv, mask, cols):
    """Paint horizontal layers inside `mask`: [(y0, y1, colour)]."""
    for y0, y1, c in cols:
        cv.a[rect_m(W, W, 0, y0, W - 1, y1, 0) & mask] = np.array(hexc(c))


# ============================================================================ food
@item("food_burger")
def burger():
    cv = _cv()
    yy = np.mgrid[0:W, 0:W][0]
    bun_top = ell_m(W, W, 16, 13, 10, 6.5) & (yy < 16)
    shade_mask(cv, bun_top, "#d8903a", "food", height=sphere_height(bun_top))
    rng = np.random.default_rng(7)
    for _ in range(10):
        x, y = rng.integers(9, 23), rng.integers(8, 14)
        if bun_top[y, x]:
            cv.px(int(x), int(y), hexc("#f6e8c0"))
    shade_mask(cv, rect_m(W, W, 6, 16, 25, 17, 1), "#5ab83a", "food", bevel=1)
    for x in range(6, 26, 3):
        cv.px(x, 18, hexc("#4aa030"))
    shade_mask(cv, poly_mask(W, W, [(6, 17), (26, 17), (24, 20), (19, 18), (13, 20), (8, 18)]), "#f0c030", "food", bevel=1)
    shade_mask(cv, rect_m(W, W, 6, 19, 25, 21, 1), "#6a3a22", "food", bevel=1, noise=0.25, seed=2)
    shade_mask(cv, rect_m(W, W, 7, 22, 24, 25, 2), "#d8903a", "food", bevel=1.5)
    return finish(cv)


@item("food_sandwich")
def sandwich():
    cv = _cv()
    # a triangle cut sandwich seen from the side: two bread slices with fillings
    top = poly_mask(W, W, [(5, 14), (26, 10), (26, 13), (5, 17)])
    shade_mask(cv, top, "#e8c890", "food", bevel=1.2)
    cv.line(5, 14, 26, 10, hexc("#b8804a"))
    shade_mask(cv, poly_mask(W, W, [(5, 17), (26, 13), (26, 15), (5, 19)]), "#5ab83a", "food", bevel=1)
    shade_mask(cv, poly_mask(W, W, [(5, 19), (26, 15), (26, 17), (5, 21)]), "#e86a6a", "food", bevel=1)
    shade_mask(cv, poly_mask(W, W, [(5, 21), (26, 17), (26, 18), (5, 22)]), "#f0d040", "food", bevel=1)
    shade_mask(cv, poly_mask(W, W, [(5, 22), (26, 18), (26, 21), (5, 25)]), "#e8c890", "food", bevel=1.2)
    cv.line(5, 25, 26, 21, hexc("#b8804a"))
    return finish(cv)


@item("food_soup")
def soup():
    cv = _cv()
    bowl = poly_mask(W, W, [(5, 15), (27, 15), (24, 23), (20, 26), (12, 26), (8, 23)])
    shade_mask(cv, bowl, "#e8e4de", "plastic", height=cyl_height(bowl, "v"))
    shade_mask(cv, ell_m(W, W, 16, 15, 11, 3), "#e8e4de", "plastic", bevel=1)
    soup_m = ell_m(W, W, 16, 15, 9.5, 2.2)
    shade_mask(cv, soup_m, "#d8a040", "food", bevel=1)
    dots(cv, ((12, 15), (17, 14), (20, 15)), "#f0d890")
    dots(cv, ((14, 15), (19, 16)), "#5ab83a")
    cv.hline(9, 23, 21, hexc("#4a8ad8"))
    finish(cv)
    for (x, y, a) in ((13, 11, 0.4), (14, 9, 0.3), (18, 10, 0.4), (19, 8, 0.25)):
        cv.px(x, y, (0.95, 0.95, 1.0, a))
    return cv


@item("food_donut")
def donut():
    cv = _cv()
    ring = ell_m(W, W, 16, 17, 10, 8) & ~ell_m(W, W, 16, 17, 3.2, 2.4)
    shade_mask(cv, ring, "#d8904a", "food", height=sphere_height(ell_m(W, W, 16, 17, 10, 8)) * 0.6)
    icing = (ell_m(W, W, 16, 16, 9, 6.6) & ~ell_m(W, W, 16, 16, 4, 3.2))
    shade_mask(cv, icing, "#f07ab0", "food", bevel=2)
    rng = np.random.default_rng(3)
    for _ in range(12):
        x, y = rng.integers(8, 25), rng.integers(10, 23)
        if icing[y, x]:
            cv.px(int(x), int(y), hexc(["#ffffff", "#5ad8ff", "#ffe050", "#7ae87a"][int(rng.integers(0, 4))]))
    return finish(cv)


@item("food_pizza")
def pizza():
    cv = _cv()
    slice_m = poly_mask(W, W, [(6, 9), (27, 9), (16, 28)])
    shade_mask(cv, slice_m, "#f0c050", "food", bevel=1.5)
    crust = rect_m(W, W, 5, 7, 28, 10, 2)
    shade_mask(cv, crust, "#c8803a", "food", height=cyl_height(crust, "h"))
    for (x, y) in ((12, 14), (19, 13), (16, 19), (14, 23)):
        ball(cv, x, y, 1.8, 1.6, "#c8342e", "food")
    dots(cv, ((10, 12), (22, 12), (17, 16), (13, 18)), "#f8e8a0")
    return finish(cv)


@item("food_ration")
def ration():
    cv = _cv()
    pal, bx = box(cv, 6, 10, 25, 24, "#6a7a4a", "paper", 1, 1.5)
    cv.a[rect_m(W, W, 6, 14, 25, 19, 0) & bx] = np.array(hexc("#e8dcb0"))
    cv.hline(9, 22, 16, hexc("#3a3a2a"))
    cv.hline(9, 16, 18, hexc("#3a3a2a"))
    cv.line(6, 10, 9, 13, pal[0])
    return finish(cv)


@item("food_meat")
def meat():
    cv = _cv()
    slab = poly_mask(W, W, [(6, 14), (12, 9), (22, 9), (27, 14), (25, 23), (16, 26), (7, 22)])
    pal = shade_mask(cv, slab, "#c8404a", "organic", bevel=2.5)
    for (a, b, c, d) in ((10, 15, 20, 12), (11, 20, 23, 17)):
        cv.line(a, b, c, d, hexc("#f0d0d0"))
    bone = ell_m(W, W, 22, 14, 2.4, 2.4)
    shade_mask(cv, bone, "#f4ecdc", "plastic", height=sphere_height(bone))
    return finish(cv)


@item("food_flour")
def flour():
    cv = _cv()
    sack = poly_mask(W, W, [(9, 9), (22, 9), (25, 27), (6, 27)])
    pal = shade_mask(cv, sack, "#ece4d0", "cloth", bevel=2.5, noise=0.15, seed=4)
    tie = poly_mask(W, W, [(11, 5), (20, 5), (22, 9), (9, 9)])
    shade_mask(cv, tie, "#ece4d0", "cloth", bevel=1)
    cv.hline(10, 21, 9, hexc("#8a6a4a"))
    ball(cv, 15.5, 19, 3.2, 3.2, "#e8c040", "paper")
    cv.hline(10, 21, 24, pal[1])
    return finish(cv)


@item("food_egg")
def egg():
    cv = _cv()
    m = ell_m(W, W, 16, 17, 5.5, 7.5)
    shade_mask(cv, m, "#f4ecdc", "plastic", height=sphere_height(m))
    glint(cv, 13, 13)
    return finish(cv)


@item("food_tomato")
def tomato():
    cv = _cv()
    m = ell_m(W, W, 16, 18, 8.5, 7.5)
    shade_mask(cv, m, "#e0302a", "food", height=sphere_height(m))
    leaf = poly_mask(W, W, [(12, 11), (16, 9), (20, 11), (17, 12), (16, 14), (15, 12)])
    shade_mask(cv, leaf, "#4aa030", "food", bevel=1)
    glint(cv, 12, 15)
    glint(cv, 13, 15, 0.6)
    return finish(cv)


@item("food_potato")
def potato():
    cv = _cv()
    m = ell_m(W, W, 16, 17, 9.5, 6.5)
    pal = shade_mask(cv, m, "#c89a5a", "food", height=sphere_height(m), noise=0.12, seed=6)
    dots(cv, ((11, 15), (18, 14), (21, 18), (14, 20)), pal[0])
    return finish(cv)


@item("food_berries")
def berries():
    cv = _cv()
    for (x, y) in ((11, 18), (16, 16), (21, 18), (13, 22), (19, 22), (16, 20)):
        ball(cv, x, y, 3, 3, "#6a4ad8", "food")
        cv.px(int(x) - 1, int(y) - 1, WHITE)
    rod(cv, 16, 13, 17, 9, 0.7, "#4aa030", "paint")
    shade_mask(cv, poly_mask(W, W, [(17, 10), (22, 8), (19, 12)]), "#5ab83a", "food", bevel=1)
    return finish(cv)


@item("food_wheat")
def wheat():
    cv = _cv()
    for dx in (-3, 0, 3):
        rod(cv, 16 + dx // 2, 28, 16 + dx, 12, 0.6, "#c8a040", "paint")
        for k in range(5):
            ball(cv, 16 + dx + (1 if k % 2 else -1), 12 - k * 2, 1.3, 1.6, "#e8c050", "food")
    return finish(cv)


@item("food_banana")
def banana():
    cv = _cv()
    m = np.zeros((W, W), bool)
    for a in range(20, 160, 3):
        cx = 16 + math.cos(math.radians(a)) * 9
        cy = 10 + math.sin(math.radians(a)) * 9
        m |= ell_m(W, W, cx, cy, 2.6, 2.6)
    shade_mask(cv, m, "#f0d040", "food", bevel=2)
    dots(cv, ((7, 12), (25, 13)), "#5a4a22")
    return finish(cv)


@item("food_banana_peel")
def banana_peel():
    cv = _cv()
    for pts in ([(15, 19), (8, 25), (11, 26)], [(16, 19), (24, 25), (21, 27)], [(15, 19), (13, 12), (17, 12)], [(16, 19), (22, 16), (22, 19)]):
        shade_mask(cv, poly_mask(W, W, pts), "#f0d040", "food", bevel=1)
    ball(cv, 15.5, 19.5, 2.4, 2, "#f4ecc0", "food")
    return finish(cv)


# ============================================================================ drink
@item("drink_cocoa")
def cocoa():
    cv = _cv()
    mug = rect_m(W, W, 9, 12, 21, 26, 2)
    shade_mask(cv, mug, "#e8e4de", "plastic", height=cyl_height(mug, "v"))
    handle = ell_m(W, W, 22.5, 18.5, 3.6, 3.8) & ~ell_m(W, W, 22.5, 18.5, 1.8, 2.0) & ~mug
    shade_mask(cv, handle, "#e8e4de", "plastic", bevel=1)
    shade_mask(cv, ell_m(W, W, 15, 12.5, 5.5, 1.6), "#6a3a22", "food", bevel=1)
    dots(cv, ((13, 12), (16, 12)), "#f0e0d0")
    cv.hline(10, 20, 22, hexc("#c83a3a"))
    cv.hline(10, 20, 23, shade(hexc("#c83a3a"), -0.3))
    finish(cv)
    for (x, y, a) in ((13, 9, 0.5), (14, 7, 0.4), (13, 5, 0.25), (17, 8, 0.45), (18, 6, 0.3)):
        cv.px(x, y, (0.95, 0.95, 1.0, a))
    return cv


@item("drink_coffee")
def coffee():
    cv = _cv()
    cup = poly_mask(W, W, [(9, 11), (23, 11), (21, 27), (11, 27)])
    shade_mask(cv, cup, "#f0ece4", "paper", height=cyl_height(cup, "v"))
    sleeve = poly_mask(W, W, [(10, 16), (22, 16), (21, 22), (11, 22)])
    shade_mask(cv, sleeve, "#8a5a32", "paper", height=cyl_height(sleeve, "v"))
    lid = rect_m(W, W, 8, 8, 24, 11, 1)
    shade_mask(cv, lid, "#2e2c34", "plastic", bevel=1)
    cv.px(19, 8, hexc("#5a5864"))
    return finish(cv)


@item("drink_water")
def water():
    cv = _cv()
    body = poly_mask(W, W, [(11, 13), (20, 13), (21, 16), (21, 28), (10, 28), (10, 16)])
    shade_mask(cv, body, "#a8d8f0", "glass", height=cyl_height(body, "v"))
    cv.a[rect_m(W, W, 11, 17, 20, 27, 0) & body] = np.array([0.5, 0.75, 0.95, 0.8])
    box(cv, 10, 19, 21, 23, "#3a8ad8", "paper", 0, 1)
    cv.hline(12, 19, 21, WHITE)
    cyl(cv, 13, 8, 18, 12, "#3a8ad8", "plastic", 1)
    glint(cv, 12, 15)
    return finish(cv)


@item("drink_soda")
def soda():
    cv = _cv()
    can = rect_m(W, W, 10, 9, 21, 27, 2)
    pal = shade_mask(cv, can, "#2f7ad8", "metal", height=cyl_height(can, "v"))
    cv.a[rect_m(W, W, 10, 15, 21, 20, 0) & can] = np.array(hexc("#e8f4ff"))
    dots(cv, ((12, 17), (13, 16), (14, 17), (15, 16), (16, 17), (17, 16), (18, 17)), "#2f7ad8")
    top = ell_m(W, W, 15.5, 9.5, 5.5, 1.6)
    shade_mask(cv, top, STEEL, "metal", bevel=1)
    cv.px(17, 9, hexc(DARK_STEEL))
    return finish(cv)


@item("drink_booze")
def booze():
    cv = _cv()
    body = poly_mask(W, W, [(10, 15), (13, 11), (13, 4), (18, 4), (18, 11), (21, 15), (21, 28), (10, 28)])
    shade_mask(cv, body, "#dce8f0", "glass", height=cyl_height(body, "v"))
    box(cv, 10, 18, 21, 25, "#f4f0e8", "paper", 0, 1)
    cv.hline(12, 19, 20, hexc("#c83a3a"))
    cv.hline(12, 17, 22, hexc("#3a3a4a"))
    cyl(cv, 13, 3, 18, 6, "#c83a3a", "metal", 1)
    glint(cv, 12, 16)
    return finish(cv)


# ============================================================================ everyday things
@item("paper")
def paper():
    cv = _cv()
    sheet = poly_mask(W, W, [(9, 5), (22, 5), (25, 8), (25, 28), (9, 28)])
    pal = shade_mask(cv, sheet, "#f4f2ec", "paper", bevel=1)
    shade_mask(cv, poly_mask(W, W, [(22, 5), (25, 8), (22, 8)]), "#d8d4c8", "paper", bevel=1)
    for y in range(11, 26, 3):
        cv.hline(11, 23 if y < 23 else 18, y, hexc("#a8b8c8"))
    return finish(cv)


@item("pen")
def pen():
    cv = _cv()
    rod(cv, 7, 25, 21, 11, 1.6, "#2f4ab8", "plastic")
    rod(cv, 21, 11, 24, 8, 1.0, STEEL, "chrome", 2)
    cv.px(25, 7, hexc("#1a1a24"))
    rod(cv, 8, 22, 12, 18, 0.5, STEEL, "chrome", 3)
    return finish(cv)


@item("soap")
def soap():
    cv = _cv()
    m = rect_m(W, W, 7, 12, 24, 22, 4)
    shade_mask(cv, m, "#7ae8c0", "plastic", bevel=3)
    for (x, y) in ((24, 10), (26, 8), (22, 8)):
        ball(cv, x, y, 1.4, 1.4, "#e8fff8", "glass")
    return finish(cv)


def _lighter(lit):
    cv = _cv()
    pal, body = box(cv, 11, 12, 20, 27, "#d0342e", "plastic", 2, 2)
    box(cv, 11, 8, 20, 12, STEEL, "metal", 1, 1)
    ball(cv, 18, 10, 1.3, 1.3, GUNMETAL, "metal")
    finish(cv)
    if not lit:
        return cv
    return glowing(cv, [(14, 6, "#ffe070"), (14, 5, "#ffb040"), (15, 4, "#ff8a30"), (13, 7, "#fff0a0"), (14, 7, "#fff0a0")])


REDRAWN["lighter"] = lambda: _lighter(False)
REDRAWN["lighter_on"] = lambda: _lighter(True)


def _cig(lit):
    cv = _cv()
    rod(cv, 8, 22, 12, 19, 1.3, "#e89a50", "paper")
    rod(cv, 12, 19, 23, 11, 1.3, "#f4f2ec", "paper")
    finish(cv)
    if not lit:
        return cv
    for (x, y, a) in ((25, 8, 0.4), (26, 6, 0.3), (25, 4, 0.2)):
        cv.px(x, y, (0.85, 0.85, 0.9, a))
    return glowing(cv, [(23, 11, "#ff7a30"), (24, 10, "#ffb040")])


REDRAWN["cigarette"] = lambda: _cig(False)
REDRAWN["cigarette_lit"] = lambda: _cig(True)


@item("cig_pack")
def cig_pack():
    cv = _cv()
    pal, bx = box(cv, 10, 9, 22, 27, "#e8ecf0", "paper", 1, 1.5)
    cv.a[rect_m(W, W, 10, 9, 22, 14, 0) & bx] = np.array(hexc("#c8342e"))
    cv.a[rect_m(W, W, 13, 18, 19, 22, 0) & bx] = np.array(hexc("#c8342e"))
    for x in (12, 15, 18):
        rod(cv, x, 5, x, 8, 1.0, "#f4f2ec" if x != 15 else "#e89a50", "paper")
    return finish(cv)


def _glowstick(col, pts):
    cv = _cv()
    tube = capsule_mask(W, W, 8, 24, 23, 9, 2.2)
    shade_mask(cv, tube, col, "glass", height=capsule_height(W, W, 8, 24, 23, 9, 2.2))
    rod(cv, 22, 10, 25, 7, 2.3, "#e8ecf2", "plastic")
    finish(cv)
    return glowing(cv, pts)


REDRAWN["glowstick"] = lambda: _glowstick("#5aff9a", [(11, 21, "#aaffcc"), (14, 18, "#aaffcc"), (17, 15, "#aaffcc"), (20, 12, "#aaffcc")])


@item("ice_chunk")
def ice_chunk():
    cv = _cv()
    m = poly_mask(W, W, [(7, 16), (12, 8), (21, 7), (26, 14), (24, 24), (14, 27), (8, 23)])
    pal = shade_mask(cv, m, "#bfe8f8", "glass", bevel=3)
    cv.line(12, 9, 9, 17, WHITE)
    cv.line(18, 14, 23, 19, pal[1])
    cv.line(14, 18, 16, 24, pal[1])
    return finish(cv)


@item("debris")
def debris():
    cv = _cv()
    for pts, col in (([(5, 22), (12, 16), (16, 24), (9, 27)], "#8a93a3"), ([(14, 12), (22, 9), (24, 17), (17, 19)], "#6a7486"),
                     ([(18, 21), (26, 20), (27, 26), (20, 27)], "#9aa3b3")):
        shade_mask(cv, poly_mask(W, W, pts), col, "metal", bevel=1.2)
    rod(cv, 8, 14, 13, 10, 0.8, "#c8904a", "paint")
    dots(cv, ((11, 20), (19, 13), (22, 23)), "#4a505e")
    return finish(cv)


def _ore(col, crystal=False):
    cv = _cv()
    rock = poly_mask(W, W, [(6, 19), (10, 11), (18, 8), (25, 12), (27, 20), (21, 27), (11, 27)])
    pal = shade_mask(cv, rock, "#6a6470", "paint", bevel=2.5, noise=0.15, seed=8)
    for (cx, cy, rx, ry) in ((12, 16, 3.2, 2.6), (20, 14, 2.6, 2.2), (17, 22, 3.4, 2.4)):
        v = ell_m(W, W, cx, cy, rx, ry)
        shade_mask(cv, v & rock, col, "glass" if crystal else "metal", height=sphere_height(v))
    return finish(cv)


REDRAWN["ore_iron"] = lambda: _ore("#b0704a")
REDRAWN["ore_plasma"] = lambda: _ore("#b04ae8", True)
REDRAWN["ore_cryo"] = lambda: _ore("#5ae0f0", True)
REDRAWN["ore_gold"] = lambda: _ore("#f0c830")
