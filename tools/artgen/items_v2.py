"""Item icons, second generation: hand-designed silhouettes 22-26 px long on the 32 px
canvas, shaded from surface normals with material presets (px.py), then hand-finished.
Every sprite should read as the real object at a glance; shading never stands in for shape.

Orientation contract (handheld.py relies on it): long items run from the grip at the lower
left to the head at the upper right; guns point right with the grip low on the left.

REDRAWN maps sprite name -> function returning a Canvas or an objects.Sprite (with glow).
items.build() swaps these in before the held / in-hand views are derived.
"""
import math

import numpy as np

from common import Canvas, hexc, mix, shade
from px import (capsule_height, capsule_mask, cyl_height, ell_m, finish, outline, poly_mask, rect_m,
                shade_mask, shadow, sphere_height)

W = 32
STEEL = "#a9b3c2"
DARK_STEEL = "#6b7486"
GUNMETAL = "#4a505e"
RUBBER = "#2c2a33"
WHITE = hexc("#ffffff")
REDRAWN = {}
NEW = {}  # items that only exist in the second generation (added, not swapped in)


def new_item(*names):
    """Register a drawing for a sprite the first generation never had."""
    def deco(fn):
        for n in names:
            NEW[n] = fn
        return fn
    return deco


def item(*names):
    """Register a drawing function under one or more sprite names."""
    def deco(fn):
        for n in names:
            REDRAWN[n] = fn
        return fn
    return deco


def _cv():
    return Canvas(W, W)


def _sub(a, b):
    return a & ~b


# ------------------------------------------------------------------ drawing helpers
def rod(cv, x0, y0, x1, y1, r, col, mat="metal", k=1.0):
    m = capsule_mask(W, W, x0, y0, x1, y1, r)
    return shade_mask(cv, m, col, mat, height=capsule_height(W, W, x0, y0, x1, y1, r) * k), m


def box(cv, x0, y0, x1, y1, col, mat="paint", r=1, bevel=2.0):
    m = rect_m(W, W, x0, y0, x1, y1, r)
    return shade_mask(cv, m, col, mat, bevel=bevel), m


def cyl(cv, x0, y0, x1, y1, col, mat="paint", r=2, axis="v"):
    m = rect_m(W, W, x0, y0, x1, y1, r)
    return shade_mask(cv, m, col, mat, height=cyl_height(m, axis)), m


def ball(cv, cx, cy, rx, ry, col, mat="plastic"):
    m = ell_m(W, W, cx, cy, rx, ry)
    return shade_mask(cv, m, col, mat, height=sphere_height(m)), m


def glint(cv, x, y, a=1.0):
    # blended, so a soft glint brightens the surface instead of punching a hole in it
    if 0 <= x < cv.w and 0 <= y < cv.h:
        cv.blend_px(x, y, np.array([1.0, 1.0, 1.0, a]))


def dots(cv, pts, c):
    c = hexc(c) if isinstance(c, str) else c
    for x, y in pts:
        cv.px(x, y, c)


def glowing(cv, pts):
    """A Sprite whose glow layer carries the given (x, y, colour) pixels."""
    from objects import Sprite
    sp = Sprite()
    sp.cv = cv
    for x, y, c in pts:
        sp.g(x, y, hexc(c))
    return sp


# ============================================================================ tools
@item("wrench")
def wrench():
    cv = _cv()
    rod(cv, 8, 24, 20, 12, 2.2, STEEL, "metal", 0.8)
    head = ell_m(W, W, 22.5, 9.5, 5.2, 5.2)
    slot = poly_mask(W, W, [(22, 9), (29, 2), (31, 5), (24, 12)])
    shade_mask(cv, _sub(head, slot), STEEL, "metal", bevel=2.2)
    ring = ell_m(W, W, 7.5, 24.5, 4.0, 4.0)
    shade_mask(cv, _sub(ring, ell_m(W, W, 7.5, 24.5, 1.6, 1.6)), STEEL, "metal", bevel=1.8)
    dots(cv, ((13, 19), (14, 18), (15, 17)), shade(hexc(STEEL), -0.35))
    return finish(cv)


@item("screwdriver")
def screwdriver():
    cv = _cv()
    pal, _ = rod(cv, 6, 26, 13, 19, 3.4, "#e8b830", "plastic")
    for i in range(3):
        cv.px(8 + i * 2, 25 - i * 2, pal[1])
        cv.px(9 + i * 2, 24 - i * 2, pal[1])
    rod(cv, 14, 18, 15, 17, 1.7, DARK_STEEL, "metal")
    rod(cv, 16, 16, 25, 7, 0.9, STEEL, "chrome", 2)
    cv.px(26, 6, hexc("#e8eef8"))
    return finish(cv)


@item("crowbar")
def crowbar():
    cv = _cv()
    red = "#c8342e"
    pal, _ = rod(cv, 7, 27, 21, 11, 1.5, red, "paint")
    # the curved claw: a hook bending back down, split at the tip
    for (a, b, c, d) in ((21, 11, 23, 7), (23, 7, 26, 6), (26, 6, 28, 8), (28, 8, 27, 11)):
        rod(cv, a, b, c, d, 1.4, red, "paint")
    cv.px(28, 11, (0, 0, 0, 0))
    cv.px(27, 12, pal[1])
    # the flat pry end, bare steel where the paint wore off
    rod(cv, 5, 28, 8, 27, 1.1, STEEL, "metal")
    glint(cv, 24, 7, 0.8)
    return finish(cv)


@item("wirecutters")
def wirecutters():
    cv = _cv()
    red = "#d0342e"
    rod(cv, 6, 25, 14, 17, 2.1, red, "rubber")
    rod(cv, 11, 28, 16, 18, 2.1, red, "rubber")
    # bare steel where the grips end
    rod(cv, 14, 17, 16, 16, 1.4, DARK_STEEL, "metal")
    rod(cv, 16, 18, 17, 16, 1.4, DARK_STEEL, "metal")
    # jaws closing to a point, with the pivot bolt
    shade_mask(cv, poly_mask(W, W, [(15, 15), (19, 12), (26, 7), (22, 13), (18, 17)]), STEEL, "metal", bevel=1.4)
    shade_mask(cv, poly_mask(W, W, [(17, 17), (22, 14), (27, 9), (24, 15), (19, 19)]), STEEL, "metal", bevel=1.4)
    ball(cv, 17.5, 16.5, 1.8, 1.8, "#d8dce4", "chrome")
    cv.line(19, 15, 25, 10, shade(hexc(STEEL), -0.55))
    return finish(cv)


@item("multitool")
def multitool():
    cv = _cv()
    pal, _ = box(cv, 10, 6, 21, 27, "#e8c030", "plastic", 3, 2.5)
    scr = rect_m(W, W, 12, 9, 19, 15, 1)
    shade_mask(cv, scr, "#102030", "glass", bevel=1)
    for x, y, i in ((13, 12, 0), (14, 11, 1), (15, 13, 0), (16, 10, 1), (17, 12, 0), (18, 11, 1)):
        pass
    # buttons and the probe
    for (x, y) in ((13, 18), (16, 18), (13, 21), (16, 21)):
        box(cv, x, y, x + 1, y + 1, "#2c2a33", "rubber", 0, 1)
    box(cv, 19, 18, 20, 22, "#d83a3a", "plastic", 0, 1)
    rod(cv, 15, 5, 15, 2, 0.8, STEEL, "chrome", 2)
    finish(cv)
    return glowing(cv, [(13, 12, "#5aff9a"), (14, 11, "#5aff9a"), (15, 13, "#5aff9a"), (16, 11, "#5aff9a"), (17, 12, "#5aff9a"), (18, 10, "#5aff9a")])


def _welder(on):
    cv = _cv()
    # a tg welding tool: yellow fuel body, black grip, steel neck and a blue torch
    body = rect_m(W, W, 4, 12, 21, 19, 3)
    pal = shade_mask(cv, body, "#e2ae2c", "paint", height=cyl_height(body, "h"))
    cv.hline(6, 19, 18, pal[1])
    # warning label with a flame symbol
    box(cv, 8, 13, 13, 16, "#eae4d4", "paper", 0, 1)
    dots(cv, ((10, 14), (11, 15), (10, 15)), "#d85020")
    # filler cap and gauge
    box(cv, 16, 10, 18, 12, GUNMETAL, "metal", 0, 1)
    cv.px(17, 14, hexc("#d83a3a"))
    # neck and nozzle
    cyl(cv, 21, 13, 25, 17, STEEL, "metal", 1, "h")
    cyl(cv, 25, 14, 28, 16, "#c8a060", "metal", 0, "h")
    # grip hanging under the body
    box(cv, 8, 19, 12, 25, RUBBER, "rubber", 1, 1.5)
    cv.px(13, 20, hexc(DARK_STEEL))
    finish(cv)
    if not on:
        return cv
    return glowing(cv, [(29, 15, "#ffffff"), (29, 14, "#bfe8ff"), (29, 16, "#bfe8ff"), (30, 15, "#6ab8ff"), (31, 15, "#3a6aff")])


@item("welder")
def welder():
    return _welder(False)


@item("welder_on")
def welder_on():
    return _welder(True)


@item("cable_coil")
def cable_coil():
    cv = _cv()
    red = "#d0342e"
    # a neat coil seen from above: three wound rings around a hole, one end hanging free
    outer = ell_m(W, W, 15, 17, 10.5, 8.5)
    hole = ell_m(W, W, 15, 17, 3.2, 2.6)
    pal = shade_mask(cv, _sub(outer, hole), red, "rubber", height=sphere_height(outer) * 0.6)
    for rx, ry in ((8.2, 6.6), (5.8, 4.6)):
        ring = ell_m(W, W, 15, 17, rx, ry) & ~ell_m(W, W, 15, 17, rx - 0.9, ry - 0.9)
        cv.a[ring & outer & ~hole] = np.array(pal[0])
    cv.a[hole & ~ell_m(W, W, 15, 17, 2.2, 1.6)] = np.array(pal[0])
    rod(cv, 24, 13, 27, 8, 1.2, red, "rubber")
    cv.px(28, 7, hexc("#e8a050"))
    cv.px(28, 6, hexc("#f8d090"))
    return finish(cv)


def _sheets(col, mat="metal", n=3, mesh=False):
    cv = _cv()
    for i in range(n):
        dy = (n - 1 - i) * 3
        top = poly_mask(W, W, [(9, 11 + dy), (27, 11 + dy), (23, 18 + dy), (5, 18 + dy)])
        front = rect_m(W, W, 5, 18 + dy, 23, 19 + dy, 0)
        pal = shade_mask(cv, top, col, mat, bevel=1.2, alpha=0.85 if mat == "glass" else 1.0)
        cv.a[front] = np.array(shade(pal[len(pal) // 2], -0.35))
        if mesh:
            for x in range(9, 26, 4):
                cv.line(x, 11 + dy, x - 4, 18 + dy, hexc("#5c6474"))
    return finish(cv)


@item("sheet_metal")
def sheet_metal():
    return _sheets("#9aa3b3")


@item("sheet_glass")
def sheet_glass():
    return _sheets("#9fd0ec", "glass")


@item("sheet_rglass")
def sheet_rglass():
    return _sheets("#8cc0dc", "glass", mesh=True)


@item("sheet_plasteel")
def sheet_plasteel():
    return _sheets("#6a7486")


@item("sheet_wood")
def sheet_wood():
    cv = _sheets("#9a6a40", "paint")
    for y in (13, 16, 19):
        for x in range(9, 22, 5):
            cv.px(x, y + 1, hexc("#6a4228"))
    return cv


@item("sheet_plasma")
def sheet_plasma():
    return _sheets("#b04ae8", "glass")


@item("rods")
def rods():
    cv = _cv()
    # three thick rods in a bundle, square ends showing, tied with a yellow band
    for i in range(3):
        rod(cv, 4 + i * 3, 22 + i * 2, 21 + i * 3, 6 + i * 2, 1.05, STEEL, "metal", 1.6)
    band = poly_mask(W, W, [(12, 19), (16, 15), (21, 20), (17, 24)]) & cv.alpha_mask()
    shade_mask(cv, band, "#d8b040", "paint", bevel=1)
    return finish(cv)


@item("light_tube")
def light_tube():
    cv = _cv()
    tube = rect_m(W, W, 6, 14, 25, 17, 2)
    shade_mask(cv, tube, "#e8f4ff", "glass", height=cyl_height(tube, "h"))
    for x0 in (3, 26):
        cyl(cv, x0, 13, x0 + 2, 18, STEEL, "metal", 0, "h")
        cv.px(x0 - 1 if x0 == 3 else x0 + 3, 15, hexc(DARK_STEEL))
    return finish(cv)


def _shard(size):
    cv = _cv()
    pts = {"large": [(8, 26), (14, 6), (24, 24)], "medium": [(10, 25), (15, 11), (22, 23)], "small": [(11, 24), (16, 14), (21, 23)]}[size]
    m = poly_mask(W, W, pts)
    shade_mask(cv, m, "#a8dcf0", "glass", bevel=2)
    x0, y0 = pts[1]
    cv.line(x0, y0 + 2, x0 - 2, y0 + 8, WHITE)
    return finish(cv)


@item("glass_shard")
def glass_shard():
    return _shard("large")


@item("glass_shard_medium")
def glass_shard_medium():
    return _shard("medium")


@item("glass_shard_small")
def glass_shard_small():
    return _shard("small")


def _pipe(col):
    cv = _cv()
    # an elbow: vertical run turning to the right, with bolted flanges at both ends
    rod(cv, 11, 26, 11, 14, 3.0, col, "paint")
    rod(cv, 11, 14, 25, 14, 3.0, col, "paint")
    ball(cv, 12, 15, 3.4, 3.4, col, "paint")
    for (x0, y0, x1, y1) in ((7, 25, 15, 27), (24, 10, 26, 18)):
        box(cv, x0, y0, x1, y1, STEEL, "metal", 0, 1)
    return finish(cv)


for _layer, _col in (("supply", "#3a7ad8"), ("scrub", "#d84a3a"), ("hot", "#e8903a"), ("cold", "#3ad0d8")):
    REDRAWN["pipe_item_" + _layer] = (lambda c: (lambda: _pipe(c)))(_col)


@item("floor_tile")
def floor_tile():
    cv = _cv()
    for i in range(3):
        dy = (2 - i) * 2
        top = poly_mask(W, W, [(10, 12 + dy), (26, 12 + dy), (22, 20 + dy), (6, 20 + dy)])
        pal = shade_mask(cv, top, "#8a93a3", "metal", bevel=1)
        cv.a[rect_m(W, W, 6, 20 + dy, 22, 21 + dy, 0)] = np.array(pal[1])
    # the top tile's tread pattern
    for x in range(10, 22, 3):
        cv.px(x, 15, hexc("#6a7282"))
        cv.px(x + 1, 17, hexc("#6a7282"))
    return finish(cv)


@item("wallframe")
def wallframe():
    cv = _cv()
    g = "#8a93a3"
    for (a, b, c, d) in ((7, 7, 7, 26), (24, 7, 24, 26), (7, 7, 24, 7), (7, 26, 24, 26), (7, 26, 24, 7)):
        rod(cv, a, b, c, d, 1.2, g, "metal")
    for (x, y) in ((7, 7), (24, 7), (7, 26), (24, 26)):
        cv.px(x, y, hexc("#dce2ea"))
    return finish(cv)


@item("circuit_board")
def circuit_board():
    cv = _cv()
    pal, _ = box(cv, 6, 8, 25, 25, "#2f8a3a", "plastic", 1, 1.2)
    trace = hexc("#d8c060")
    for (a, b, c, d) in ((8, 12, 14, 12), (14, 12, 14, 18), (14, 18, 23, 18), (10, 21, 20, 21), (20, 21, 20, 10), (17, 10, 23, 10)):
        cv.line(a, b, c, d, trace)
    box(cv, 9, 14, 12, 18, "#1c1c24", "plastic", 0, 1)
    box(cv, 16, 12, 21, 15, "#1c1c24", "plastic", 0, 1)
    for x in range(7, 25, 2):
        cv.px(x, 25, hexc("#e8c040"))
    dots(cv, ((10, 14), (17, 12)), "#5a5a66")
    return finish(cv)


def _rcd(col, pipe=False):
    cv = _cv()
    pal, _ = box(cv, 5, 11, 22, 21, col, "plastic", 3, 2.5)
    # grip and trigger under the body
    shade_mask(cv, poly_mask(W, W, [(9, 20), (14, 20), (13, 27), (8, 27)]), RUBBER, "rubber", bevel=1.2)
    # nozzle and the matter/pipe canister on top
    cyl(cv, 22, 13, 27, 18, DARK_STEEL, "metal", 1, "h")
    cyl(cv, 27, 14, 29, 17, STEEL, "chrome", 0, "h")
    cyl(cv, 8, 7, 16, 11, "#3a3e4a" if not pipe else "#2a5a9a", "metal", 1, "h")
    box(cv, 15, 14, 20, 17, "#102030", "glass", 0, 1)
    finish(cv)
    return glowing(cv, [(16, 15, "#5ae8ff"), (17, 15, "#5ae8ff"), (18, 16, "#5ae8ff")])


@item("rcd")
def rcd():
    return _rcd("#e8c030")


@item("rpd")
def rpd():
    return _rcd("#3a7ad8", True)


@item("rcd_ammo")
def rcd_ammo():
    cv = _cv()
    pal, _ = cyl(cv, 9, 9, 22, 25, "#5a6272", "metal", 2)
    box(cv, 11, 13, 20, 19, "#e8c030", "paint", 0, 1)
    dots(cv, ((13, 15), (14, 16), (15, 15), (16, 16), (17, 15), (18, 16)), "#2a2530")
    box(cv, 13, 6, 18, 9, STEEL, "metal", 0, 1)
    return finish(cv)


@item("holofan")
def holofan():
    cv = _cv()
    box(cv, 7, 13, 20, 22, "#e8ecf2", "plastic", 2, 2)
    shade_mask(cv, poly_mask(W, W, [(9, 21), (14, 21), (13, 27), (8, 27)]), RUBBER, "rubber", bevel=1.2)
    dish = ell_m(W, W, 23, 16, 4.5, 5.5)
    shade_mask(cv, dish, "#3a8ad8", "glass", height=sphere_height(dish))
    finish(cv)
    return glowing(cv, [(24, 14, "#bfe8ff"), (24, 15, "#8ad0ff"), (25, 16, "#bfe8ff"), (24, 17, "#8ad0ff")])


def _scanner(col, screen_pts):
    cv = _cv()
    box(cv, 9, 6, 22, 27, col, "plastic", 3, 2.5)
    box(cv, 11, 9, 20, 16, "#0c1a24", "glass", 1, 1)
    for i, x in enumerate((12, 15, 18)):
        box(cv, x, 19, x + 1, 20, "#2c2a33", "rubber", 0, 1)
    box(cv, 13, 23, 18, 24, "#3a3e4a", "rubber", 0, 1)
    finish(cv)
    return glowing(cv, screen_pts)


@item("health_analyzer")
def health_analyzer():
    return _scanner("#e8ecf2", [(12, 12, "#5ae8a0"), (13, 12, "#5ae8a0"), (14, 11, "#5ae8a0"), (15, 13, "#5ae8a0"), (16, 12, "#5ae8a0"), (17, 12, "#5ae8a0"), (18, 12, "#5ae8a0"), (19, 12, "#5ae8a0")])


@new_item("forensic_scanner")
def forensic_scanner():
    # tg forensic scanner: a slate-grey unit with a blue fingerprint readout
    return _scanner("#4a5262", [(13, 11, "#5ab8ff"), (14, 10, "#5ab8ff"), (15, 10, "#5ab8ff"), (16, 10, "#5ab8ff"), (17, 11, "#5ab8ff"),
                                (13, 13, "#5ab8ff"), (15, 12, "#5ab8ff"), (16, 12, "#5ab8ff"), (18, 13, "#5ab8ff"), (14, 14, "#5ab8ff"), (17, 14, "#5ab8ff")])


@item("gas_analyzer")
def gas_analyzer():
    return _scanner("#e8c030", [(12, 14, "#5ae8ff"), (13, 13, "#5ae8ff"), (14, 12, "#5ae8ff"), (15, 12, "#5ae8ff"), (16, 13, "#5ae8ff"), (17, 11, "#5ae8ff"), (18, 11, "#5ae8ff"), (19, 12, "#5ae8ff")])


def _tank(col, stripe=None):
    cv = _cv()
    pal, body = cyl(cv, 11, 8, 20, 28, col, "paint", 4)
    if stripe:
        cv.a[rect_m(W, W, 11, 15, 20, 16, 0) & body] = np.array(hexc(stripe))
    # valve and pressure gauge on top
    cyl(cv, 13, 4, 18, 8, GUNMETAL, "metal", 1)
    ball(cv, 19, 5, 2.2, 2.2, "#e8ecf2", "plastic")
    cv.px(19, 5, hexc("#d83a3a"))
    glint(cv, 13, 11, 0.9)
    return finish(cv)


@item("tank_o2")
def tank_o2():
    return _tank("#2f62d0")


@item("tank_air")
def tank_air():
    return _tank("#b8c0cc", "#3a6ad8")


@item("tank_plasma")
def tank_plasma():
    return _tank("#e0742a", "#6a2a8a")


@item("tank_fuel")
def tank_fuel():
    return _tank("#d8a53a", "#2a2530")


def _flashlight(on):
    cv = _cv()
    # a black knurled body, a wider steel head and a round lens at the upper right
    rod(cv, 6, 24, 17, 15, 2.3, "#3a3e4a", "metal")
    for i in range(0, 8, 2):
        cv.px(8 + i, 22 - (i * 3) // 4, hexc("#1c1e26"))
    rod(cv, 17, 15, 21, 12, 3.4, STEEL, "metal")
    lens = ell_m(W, W, 23.2, 10.6, 2.4, 2.4)
    shade_mask(cv, lens, "#fff2a0" if on else "#8ab8d0", "glass", height=sphere_height(lens))
    cv.px(12, 18, hexc("#d83a3a"))
    finish(cv)
    if not on:
        return cv
    return glowing(cv, [(23, 10, "#ffffff"), (22, 11, "#fff8d0"), (24, 11, "#fff2a0"), (23, 12, "#fff2a0"), (26, 8, "#fff2a0")])


@item("flashlight")
def flashlight():
    return _flashlight(False)


@item("flashlight_on")
def flashlight_on():
    return _flashlight(True)


# ============================================================================ containers & kits
@item("toolbox_red")
def toolbox_red():
    return _toolbox("#c8342e")


@item("toolbox_blue")
def toolbox_blue():
    return _toolbox("#2f62c8")


@item("toolbox_yellow")
def toolbox_yellow():
    return _toolbox("#d8a530")


def _toolbox(col):
    cv = _cv()
    pal, bx = box(cv, 4, 13, 27, 26, col, "paint", 2, 2.5)
    cv.hline(5, 26, 17, pal[0])
    cv.hline(5, 26, 18, pal[-2])
    for x in (8, 22):
        box(cv, x, 16, x + 2, 19, STEEL, "metal", 0, 1)
    hm = capsule_mask(W, W, 11, 10, 20, 10, 1.1) | capsule_mask(W, W, 11, 10, 11, 13, 1.1) | capsule_mask(W, W, 20, 10, 20, 13, 1.1)
    shade_mask(cv, hm & ~bx, DARK_STEEL, "metal", bevel=1)
    cv.px(6, 24, pal[1])
    cv.px(25, 21, pal[1])
    return finish(cv)


def _medkit(col, cross="#d83a3a"):
    cv = _cv()
    pal, bx = box(cv, 5, 11, 26, 26, col, "plastic", 3, 3)
    shade_mask(cv, capsule_mask(W, W, 12, 8, 19, 8, 1.2) & ~bx, "#3a3a44", "rubber", bevel=1)
    cm = rect_m(W, W, 14, 13, 17, 23, 0) | rect_m(W, W, 10, 16, 21, 19, 0)
    shade_mask(cv, cm, cross, "plastic", bevel=1.2)
    cv.hline(6, 25, 21, pal[1])
    glint(cv, 6, 13, 0.7)
    return finish(cv)


REDRAWN["medkit"] = lambda: _medkit("#eef1f4")
REDRAWN["medkit_burn"] = lambda: _medkit("#e8a030", "#fff4e0")
REDRAWN["medkit_toxin"] = lambda: _medkit("#4ab83a", "#f0fff0")
REDRAWN["medkit_o2"] = lambda: _medkit("#3a6ad8", "#f0f6ff")


# the other batches register themselves into REDRAWN
import items_v2_med  # noqa: E402,F401
import items_v2_sec  # noqa: E402,F401
import items_v2_food  # noqa: E402,F401
import items_v2_body  # noqa: E402,F401
import items_v2_tg  # noqa: E402,F401
import items_v2_gen  # noqa: E402,F401
