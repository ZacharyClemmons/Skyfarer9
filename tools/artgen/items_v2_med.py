"""Item icons, second generation: medical and chemistry (see items_v2.py)."""
import math

import numpy as np

from common import hexc, mix
from items_v2 import (DARK_STEEL, REDRAWN, RUBBER, STEEL, W, WHITE, _cv, _sub, ball, box, cyl, dots,
                      glint, glowing, item, rod)
from px import (capsule_height, capsule_mask, cyl_height, ell_m, finish, poly_mask, rect_m, shade_mask,
                sphere_height)


@item("bruise_pack")
def bruise_pack():
    cv = _cv()
    # a soft white pouch with a red band and cross
    pal, bx = box(cv, 7, 10, 24, 24, "#eef0f2", "cloth", 3, 3)
    cv.a[rect_m(W, W, 7, 15, 24, 18, 0) & bx] = np.array(hexc("#c83a3a"))
    cv.a[rect_m(W, W, 15, 13, 16, 20, 0) & bx] = np.array(hexc("#ffffff"))
    cv.a[rect_m(W, W, 13, 16, 18, 17, 0) & bx] = np.array(hexc("#ffffff"))
    cv.hline(8, 23, 23, pal[1])
    return finish(cv)


@item("ointment")
def ointment():
    cv = _cv()
    # a squeezed tube lying diagonally, crimped end lower left, cap upper right
    body = poly_mask(W, W, [(5, 24), (9, 28), (22, 15), (18, 11)])
    shade_mask(cv, body, "#e8e0c8", "plastic", bevel=2)
    shade_mask(cv, poly_mask(W, W, [(4, 23), (6, 21), (11, 26), (9, 28)]), "#cfc6ae", "metal", bevel=1)
    rod(cv, 20, 13, 24, 9, 2.4, "#e89a30", "plastic")
    cv.line(10, 21, 16, 15, hexc("#e89a30"))
    cv.line(11, 22, 17, 16, hexc("#e89a30"))
    return finish(cv)


@item("gauze")
def gauze():
    cv = _cv()
    # a bandage roll: round end face with the wound spiral, body behind it, loose end trailing
    body = rect_m(W, W, 11, 9, 22, 21, 5)
    shade_mask(cv, body, "#e8e4da", "cloth", height=cyl_height(body, "h"))
    face = ell_m(W, W, 12, 15, 5.5, 6.5)
    pal = shade_mask(cv, face, "#f6f4ee", "cloth", bevel=2)
    for rx, ry in ((4.0, 5.0), (2.6, 3.4)):
        ring = ell_m(W, W, 12, 15, rx, ry) & ~ell_m(W, W, 12, 15, rx - 0.8, ry - 0.8)
        cv.a[ring] = np.array(pal[1])
    cv.a[ell_m(W, W, 12, 15, 1.2, 1.6)] = np.array(pal[0])
    tail = poly_mask(W, W, [(18, 20), (22, 19), (27, 27), (23, 28)])
    tp = shade_mask(cv, tail, "#f6f4ee", "cloth", bevel=1)
    cv.line(20, 21, 24, 27, tp[1])
    return finish(cv)


@item("suture")
def suture():
    cv = _cv()
    # a bold curved needle with blue thread looping off its eye
    for a in range(150, 320, 6):
        for r in (7.0, 7.8):
            x = 17 + math.cos(math.radians(a)) * r
            y = 17 + math.sin(math.radians(a)) * r
            cv.px(int(round(x)), int(round(y)), hexc("#d8dee8") if r < 7.4 else hexc("#8a94a4"))
    cv.px(24, 12, WHITE)
    cv.px(10, 20, hexc("#f0f4f8"))
    # the thread: loops down from the eye at the upper right
    pts = [(24, 13), (25, 17), (23, 21), (19, 23), (15, 24), (11, 26), (8, 27)]
    for (a, b), (c, d) in zip(pts, pts[1:]):
        cv.line(a, b, c, d, hexc("#3a6ad8"))
        cv.line(a, b + 1, c, d + 1, hexc("#28489a"))
    return finish(cv)


@item("mesh")
def mesh():
    cv = _cv()
    pal, bx = box(cv, 6, 8, 25, 25, "#7ad8b0", "plastic", 2, 1.5)
    for k in range(9, 25, 3):
        cv.line(k, 8, 6, 8 + (k - 6), pal[1])
        cv.line(k, 25, 25, 25 - (25 - k), pal[1])
    cv.a[rect_m(W, W, 6, 8, 25, 11, 0) & bx] = np.array(hexc("#e8eef4"))
    cv.hline(9, 21, 9, hexc("#3a8a6a"))
    return finish(cv)


@item("bone_gel")
def bone_gel():
    cv = _cv()
    pal, body = cyl(cv, 11, 11, 20, 27, "#e8ecf2", "plastic", 3)
    cv.a[rect_m(W, W, 11, 15, 20, 23, 0) & body] = np.array(hexc("#4a8ad8"))
    cv.hline(13, 18, 18, hexc("#ffffff"))
    cv.hline(13, 16, 20, hexc("#c8d8f0"))
    cyl(cv, 13, 6, 18, 11, "#4a8ad8", "plastic", 1)
    return finish(cv)


@item("surgical_tape")
def surgical_tape():
    cv = _cv()
    outer = ell_m(W, W, 16, 17, 9, 8)
    core = ell_m(W, W, 16, 17, 4, 3.5)
    pal = shade_mask(cv, _sub(outer, core), "#f0ece0", "paper", height=sphere_height(outer) * 0.5)
    cv.a[core & ~ell_m(W, W, 16, 17, 3, 2.5)] = np.array(hexc("#b8a888"))
    cv.a[ell_m(W, W, 16, 17, 7, 6) & ~ell_m(W, W, 16, 17, 6.3, 5.3)] = np.array(pal[1])
    rod(cv, 24, 19, 27, 25, 1.2, "#f0ece0", "paper")
    return finish(cv)


@item("splint")
def splint():
    cv = _cv()
    for dx in (0, 5):
        rod(cv, 6 + dx, 26, 19 + dx, 6, 1.6, "#c8904a", "paint")
    for t in (0.3, 0.7):
        x, y = 6 + 13 * t, 26 - 20 * t
        shade_mask(cv, capsule_mask(W, W, int(x) - 2, int(y), int(x) + 7, int(y), 1.2), "#f0f0ec", "cloth", bevel=1)
    return finish(cv)


@item("bonesetter")
def bonesetter():
    cv = _cv()
    rod(cv, 6, 26, 15, 17, 1.5, STEEL, "metal")
    rod(cv, 11, 28, 17, 19, 1.5, STEEL, "metal")
    ball(cv, 16.5, 17.5, 2, 2, DARK_STEEL, "metal")
    rod(cv, 17, 16, 25, 8, 1.8, STEEL, "metal")
    rod(cv, 18, 18, 27, 11, 1.8, STEEL, "metal")
    for (a, b) in ((25, 8), (27, 11)):
        ball(cv, a, b, 2.4, 2.4, "#d8dee8", "chrome")
    return finish(cv)


@item("scalpel")
def scalpel():
    cv = _cv()
    rod(cv, 6, 26, 17, 15, 1.6, "#c8cfda", "metal")
    for i in range(3):
        cv.px(9 + i * 2, 22 - i * 2, hexc("#7a8496"))
    shade_mask(cv, poly_mask(W, W, [(16, 16), (19, 12), (26, 5), (24, 11), (19, 17)]), "#e8eef6", "chrome", bevel=1)
    cv.line(19, 13, 25, 6, WHITE)
    return finish(cv)


@item("hemostat")
def hemostat():
    cv = _cv()
    for cx, cy in ((7, 25), (12, 28)):
        ring = ell_m(W, W, cx, cy, 2.6, 2.6) & ~ell_m(W, W, cx, cy, 1.1, 1.1)
        shade_mask(cv, ring, STEEL, "metal", bevel=1)
    rod(cv, 9, 23, 16, 17, 0.9, STEEL, "metal", 2)
    rod(cv, 13, 26, 17, 18, 0.9, STEEL, "metal", 2)
    ball(cv, 16.5, 17.5, 1.6, 1.6, DARK_STEEL, "metal")
    rod(cv, 17, 16, 26, 7, 0.8, "#d8dee8", "chrome", 2)
    rod(cv, 18, 17, 27, 9, 0.8, "#d8dee8", "chrome", 2)
    return finish(cv)


@item("retractor")
def retractor():
    cv = _cv()
    rod(cv, 6, 26, 20, 12, 1.4, STEEL, "metal")
    # two curved prongs splayed at the end
    rod(cv, 20, 12, 24, 6, 1.0, STEEL, "chrome", 2)
    rod(cv, 20, 12, 27, 11, 1.0, STEEL, "chrome", 2)
    rod(cv, 24, 6, 26, 7, 0.9, STEEL, "chrome", 2)
    rod(cv, 27, 11, 27, 13, 0.9, STEEL, "chrome", 2)
    rod(cv, 6, 26, 10, 22, 2.0, RUBBER, "rubber")
    return finish(cv)


@item("cautery")
def cautery():
    cv = _cv()
    rod(cv, 6, 26, 19, 13, 2.2, "#e8ecf2", "plastic")
    rod(cv, 19, 13, 24, 8, 1.0, STEEL, "chrome", 2)
    dots(cv, ((10, 21), (11, 20)), "#3a3e4a")
    finish(cv)
    return glowing(cv, [(25, 7, "#ffb050"), (24, 7, "#ff7a30"), (25, 6, "#ffe0a0")])


@item("circular_saw")
def circular_saw():
    cv = _cv()
    # a flat toothed blade behind a white motor housing with a black grip
    blade = ell_m(W, W, 21, 14, 7, 7)
    pal = shade_mask(cv, blade, "#c8d0dc", "metal", bevel=1.2)
    for a in range(0, 360, 24):
        x = 21 + math.cos(math.radians(a)) * 7.6
        y = 14 + math.sin(math.radians(a)) * 7.6
        cv.px(int(round(x)), int(round(y)), pal[3])
    cv.a[ell_m(W, W, 21, 14, 4.2, 4.2) & ~ell_m(W, W, 21, 14, 3.4, 3.4)] = np.array(pal[1])
    box(cv, 5, 14, 17, 22, "#e8ecf2", "plastic", 2, 2)
    ball(cv, 17, 17, 2.2, 2.2, DARK_STEEL, "metal")
    shade_mask(cv, poly_mask(W, W, [(7, 21), (12, 21), (11, 27), (6, 27)]), RUBBER, "rubber", bevel=1.2)
    cv.hline(7, 14, 16, hexc("#4ab8d8"))
    return finish(cv)


@item("surgical_drapes")
def surgical_drapes():
    cv = _cv()
    for y in (20, 15, 10):
        m = poly_mask(W, W, [(6, y), (25, y - 1), (26, y + 5), (5, y + 6)])
        pal = shade_mask(cv, m, "#4aa8a0", "cloth", bevel=2)
        cv.hline(6, 25, y + 5, pal[0])
    return finish(cv)


@item("syringe")
def syringe():
    cv = _cv()
    # plunger at the lower left, needle up and to the right
    rod(cv, 5, 27, 9, 23, 1.0, "#e8ecf2", "plastic")
    shade_mask(cv, capsule_mask(W, W, 4, 25, 8, 29, 0.9), "#e8ecf2", "plastic", bevel=1)
    shade_mask(cv, capsule_mask(W, W, 9, 23, 19, 13, 2.2), "#d8eef8", "glass", height=capsule_height(W, W, 9, 23, 19, 13, 2.2))
    shade_mask(cv, capsule_mask(W, W, 13, 19, 18, 14, 1.3), "#d83a3a", "glass", bevel=1)
    for i in range(3):
        cv.px(12 + i * 3, 18 - i * 3, hexc("#ffffff"))
    rod(cv, 19, 13, 26, 6, 0.6, "#dce2ea", "chrome", 2)
    return finish(cv)


@item("medipen")
def medipen():
    cv = _cv()
    rod(cv, 6, 26, 19, 13, 2.4, "#e8c030", "plastic")
    rod(cv, 19, 13, 23, 9, 2.5, "#d83a3a", "plastic")
    box(cv, 11, 17, 14, 20, "#ffffff", "paper", 0, 1)
    cv.px(12, 18, hexc("#d83a3a"))
    return finish(cv)


@item("pill_bottle")
def pill_bottle():
    cv = _cv()
    pal, body = cyl(cv, 10, 11, 21, 27, "#e8903a", "glass", 2)
    for (x, y, c) in ((12, 22, "#ffffff"), (15, 24, "#ffd0d0"), (18, 22, "#ffffff"), (13, 25, "#ffd0d0"), (17, 25, "#ffffff")):
        cv.px(x, y, hexc(c))
    cv.a[rect_m(W, W, 10, 15, 21, 19, 0) & body] = np.array(hexc("#f4f0e8"))
    cv.hline(12, 19, 17, hexc("#8a8078"))
    cyl(cv, 9, 7, 22, 11, "#f4f4f4", "plastic", 1)
    return finish(cv)


@item("pill")
def pill():
    cv = _cv()
    a = capsule_mask(W, W, 11, 19, 16, 15, 3)
    b = capsule_mask(W, W, 16, 15, 21, 12, 3)
    shade_mask(cv, a, "#f4f4f4", "plastic", height=capsule_height(W, W, 11, 19, 16, 15, 3))
    shade_mask(cv, _sub(b, a), "#d83a3a", "plastic", height=capsule_height(W, W, 16, 15, 21, 12, 3))
    return finish(cv)


@item("patch")
def patch():
    cv = _cv()
    pal, _ = box(cv, 9, 10, 23, 24, "#e8d8c0", "cloth", 3, 1.5)
    box(cv, 12, 13, 20, 21, "#d86a5a", "plastic", 2, 1.5)
    dots(cv, ((10, 11), (22, 11), (10, 23), (22, 23)), pal[1])
    return finish(cv)


def _vial(fill=None):
    cv = _cv()
    pal, body = cyl(cv, 11, 11, 20, 27, "#c8e4f0", "glass", 2)
    if fill:
        cv.a[rect_m(W, W, 12, 17, 19, 26, 1) & body] = np.array(np.r_[hexc(fill)[:3], 0.95])
        cv.hline(12, 19, 17, mix(hexc(fill), WHITE, 0.4))
    box(cv, 12, 19, 19, 23, "#f4f0e8", "paper", 0, 1)
    cv.hline(13, 18, 21, hexc("#8a8078"))
    cyl(cv, 13, 7, 18, 11, "#a86a3a", "rubber", 1)
    glint(cv, 12, 13)
    return finish(cv)


REDRAWN["bottle"] = lambda: _vial()
REDRAWN["bottle_filled"] = lambda: _vial("#4ab8d8")


@item("dropper")
def dropper():
    cv = _cv()
    shade_mask(cv, capsule_mask(W, W, 8, 24, 20, 12, 1.4), "#d8eef8", "glass", height=capsule_height(W, W, 8, 24, 20, 12, 1.4))
    rod(cv, 20, 12, 24, 8, 2.6, "#d83a3a", "rubber")
    cv.px(7, 25, hexc("#4ab8d8"))
    return finish(cv)


def _beaker(fill=None):
    cv = _cv()
    glass = rect_m(W, W, 10, 8, 21, 26, 1)
    shade_mask(cv, glass, "#b8d8e8", "glass", height=cyl_height(glass, "v"))
    if fill:
        liq = rect_m(W, W, 11, 15, 20, 25, 0)
        lp = shade_mask(cv, liq, fill, "glass", height=cyl_height(liq, "v"), alpha=0.95)
        cv.hline(11, 20, 15, mix(lp[-1], WHITE, 0.4))
    for y in (12, 16, 20):
        cv.hline(18, 20, y, hexc("#e8f4fa"))
    cv.hline(9, 22, 8, hexc("#e8f4fa"))
    cv.px(8, 8, hexc("#e8f4fa"))
    glint(cv, 11, 10)
    glint(cv, 11, 11)
    return finish(cv)


REDRAWN["beaker"] = lambda: _beaker()
REDRAWN["beaker_filled"] = lambda: _beaker("#4ab8d8")


def _blood_pack(full):
    cv = _cv()
    bag = rect_m(W, W, 8, 8, 23, 25, 4)
    shade_mask(cv, bag, "#e8f0f4", "glass", bevel=3)
    if full:
        shade_mask(cv, rect_m(W, W, 9, 12, 22, 24, 3), "#b0182a", "organic", bevel=2.5, alpha=0.95)
    box(cv, 11, 14, 20, 18, "#f4f0e8", "paper", 0, 1)
    cv.hline(12, 17, 16, hexc("#c83a3a"))
    rod(cv, 15, 5, 16, 8, 1.0, "#d8dee8", "plastic")
    rod(cv, 16, 25, 19, 29, 0.8, "#c8d0d8", "plastic")
    return finish(cv)


REDRAWN["blood_pack"] = lambda: _blood_pack(False)
REDRAWN["blood_pack_full"] = lambda: _blood_pack(True)


@item("defib")
def defib():
    cv = _cv()
    # the unit: a yellow case with a screen and dial
    box(cv, 4, 15, 23, 28, "#e8c030", "plastic", 3, 2.5)
    box(cv, 7, 18, 14, 23, "#0c1a24", "glass", 1, 1)
    ball(cv, 18, 21, 2.2, 2.2, "#3a3e4a", "plastic")
    box(cv, 7, 25, 20, 26, "#c89a20", "plastic", 0, 1)
    # two paddles resting on top, with their coiled leads
    for x0 in (7, 15):
        box(cv, x0, 10, x0 + 5, 14, "#d8dee8", "metal", 1, 1.2)
        box(cv, x0 + 1, 7, x0 + 4, 10, "#d83a3a", "plastic", 1, 1)
    for (a, b, c, d) in ((24, 18, 27, 12), (27, 12, 21, 8)):
        cv.line(a, b, c, d, hexc("#2a2a32"))
    finish(cv)
    return glowing(cv, [(8, 20, "#5aff9a"), (9, 21, "#5aff9a"), (10, 19, "#5aff9a"), (11, 21, "#5aff9a"), (12, 20, "#5aff9a")])


@item("spray_bottle")
def spray_bottle():
    cv = _cv()
    cyl(cv, 10, 13, 21, 28, "#4a9ad8", "plastic", 3)
    box(cv, 12, 17, 19, 23, "#f4f0e8", "paper", 0, 1)
    dots(cv, ((14, 19), (15, 20), (16, 19), (17, 21)), "#4a9ad8")
    head = poly_mask(W, W, [(12, 13), (19, 13), (19, 8), (25, 8), (25, 11), (21, 11), (21, 13)]) | rect_m(W, W, 12, 8, 19, 13, 1)
    shade_mask(cv, head, "#f4f4f4", "plastic", bevel=1.2)
    shade_mask(cv, poly_mask(W, W, [(14, 13), (17, 13), (16, 18), (14, 17)]), "#f4f4f4", "plastic", bevel=1)
    return finish(cv)
