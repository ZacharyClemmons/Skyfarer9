"""Item icons, second generation: clothing, ID cards, organs and limbs (see items_v2.py)."""
import numpy as np

from common import hexc, mix, shade
from items_v2 import REDRAWN, STEEL, W, WHITE, _cv, _sub, ball, box, cyl, dots, glint, item, rod
from px import capsule_height, capsule_mask, ell_m, finish, poly_mask, rect_m, shade_mask, sphere_height


# ============================================================================ clothing
def _coat(col, trim="#e8e0d0"):
    cv = _cv()
    body = poly_mask(W, W, [(10, 6), (21, 6), (24, 28), (7, 28)])
    sl = poly_mask(W, W, [(10, 7), (5, 12), (4, 24), (8, 24), (9, 13)]) | poly_mask(W, W, [(21, 7), (26, 12), (27, 24), (23, 24), (22, 13)])
    pal = shade_mask(cv, sl, col, "cloth", bevel=2)
    shade_mask(cv, body, col, "cloth", bevel=3)
    shade_mask(cv, ell_m(W, W, 15.5, 6.5, 6.5, 2.8), trim, "cloth", bevel=1.5, noise=0.4, seed=5)
    for y in range(9, 28):
        cv.px(15, y, pal[0] if y % 2 else pal[1])
    for (x0, x1) in ((9, 13), (18, 22)):
        cv.hline(x0, x1, 20, pal[0])
        cv.hline(x0, x1, 21, pal[-1])
    cv.hline(4, 7, 24, pal[0])
    cv.hline(24, 27, 24, pal[0])
    return finish(cv)


for _k, _c in (("gen", "#6a7486"), ("eng", "#d8a53a"), ("med", "#e8eef4"), ("sec", "#8a2a33"), ("sci", "#7a5ab8"),
               ("cmd", "#3a5ab8"), ("srv", "#4a9a6a"), ("cargo", "#b8823a")):
    REDRAWN["coat_" + _k] = (lambda c: (lambda: _coat(c)))(_c)


def _id(col):
    cv = _cv()
    pal, card = box(cv, 5, 10, 26, 24, "#e8ecf0", "plastic", 2, 1.5)
    shade_mask(cv, rect_m(W, W, 5, 10, 26, 13, 0) & card, col, "plastic", bevel=1)
    box(cv, 7, 15, 12, 21, "#8a9ab0", "paper", 0, 1)
    dots(cv, ((9, 17), (10, 17)), "#e0b890")
    cv.hline(8, 11, 19, hexc("#4a5a7a"))
    box(cv, 20, 15, 24, 18, "#d8b84a", "metal", 0, 1)
    for y in (16, 20, 22):
        cv.hline(14, 18 if y == 16 else 24, y, pal[1])
    return finish(cv)


for _k, _c in (("gen", "#9aa3b3"), ("eng", "#d8a53a"), ("med", "#4ab8d8"), ("sec", "#d84a4a"), ("sci", "#a87ae8"),
               ("cmd", "#4a8ad8"), ("cap", "#d8b84a"), ("srv", "#5ac87a"), ("cargo", "#c8883a")):
    REDRAWN["id_" + _k] = (lambda c: (lambda: _id(c)))(_c)


# ============================================================================ organs
FLESH = "#c84a58"


@item("organ_heart")
def heart():
    cv = _cv()
    m = ell_m(W, W, 13, 14, 5.5, 5.5) | ell_m(W, W, 19, 14, 5.5, 5.5) | poly_mask(W, W, [(8, 16), (24, 16), (16, 27)])
    shade_mask(cv, m, "#b8283a", "organic", height=sphere_height(m))
    rod(cv, 14, 8, 13, 4, 1.4, "#d86a78", "organic")
    rod(cv, 18, 8, 20, 5, 1.2, "#6a7ad8", "organic")
    cv.line(17, 13, 14, 22, hexc("#8a1a2a"))
    return finish(cv)


@item("organ_lungs")
def lungs():
    cv = _cv()
    for cx in (11, 21):
        m = ell_m(W, W, cx, 17, 5.5, 8.5)
        shade_mask(cv, m, "#e88a98", "organic", height=sphere_height(m))
    rod(cv, 16, 4, 16, 11, 1.3, "#f0c0c8", "organic")
    rod(cv, 16, 11, 13, 13, 1.0, "#f0c0c8", "organic")
    rod(cv, 16, 11, 19, 13, 1.0, "#f0c0c8", "organic")
    return finish(cv)


@item("organ_liver")
def liver():
    cv = _cv()
    m = poly_mask(W, W, [(5, 15), (11, 10), (24, 10), (28, 13), (22, 20), (12, 23)])
    shade_mask(cv, m, "#7a2a2a", "organic", bevel=3)
    cv.line(17, 11, 15, 21, hexc("#5a1a1a"))
    return finish(cv)


@item("organ_stomach")
def stomach():
    cv = _cv()
    m = ell_m(W, W, 16, 18, 8, 6.5) | capsule_mask(W, W, 10, 9, 12, 14, 2.2) | capsule_mask(W, W, 22, 21, 26, 26, 1.8)
    shade_mask(cv, m, "#e8909a", "organic", height=sphere_height(m))
    return finish(cv)


@item("organ_brain")
def brain():
    cv = _cv()
    m = ell_m(W, W, 16, 16, 11, 8.5)
    pal = shade_mask(cv, m, "#e8a0b0", "organic", height=sphere_height(m))
    cv.line(16, 8, 16, 24, pal[0])
    for (a, b, c, d) in ((9, 12, 12, 15), (11, 19, 14, 17), (20, 11, 22, 15), (19, 20, 23, 18), (7, 17, 10, 17), (22, 17, 25, 16)):
        cv.line(a, b, c, d, pal[1])
    return finish(cv)


@item("organ_eyes")
def eyes():
    cv = _cv()
    for cx in (11, 21):
        m = ell_m(W, W, cx, 16, 4.5, 4.5)
        shade_mask(cv, m, "#f4f0ec", "plastic", height=sphere_height(m))
        ball(cv, cx + 1, 15, 2, 2, "#3a8ad8", "glass")
        cv.px(cx + 1, 15, hexc("#101018"))
        rod(cv, cx - 3, 20, cx - 5, 24, 0.8, "#c84a58", "organic")
    return finish(cv)


def _appendix(inflamed):
    cv = _cv()
    col = "#d84a4a" if inflamed else "#e8909a"
    rod(cv, 11, 8, 14, 16, 2.6, col, "organic")
    rod(cv, 14, 16, 20, 22, 2.2 if not inflamed else 3.0, col, "organic")
    rod(cv, 20, 22, 22, 26, 1.6 if not inflamed else 2.6, col, "organic")
    if inflamed:
        dots(cv, ((18, 20), (21, 24)), "#f0e070")
    return finish(cv)


REDRAWN["organ_appendix"] = lambda: _appendix(False)
REDRAWN["organ_appendix_inflamed"] = lambda: _appendix(True)


# ============================================================================ severed limbs
SKIN = "#e0ac8a"


def _stump(cv, x, y):
    ball(cv, x, y, 2.4, 2.4, "#b82838", "organic")
    cv.px(int(x), int(y), hexc("#f0e8e0"))


@item("limb_arm")
def limb_arm():
    cv = _cv()
    rod(cv, 7, 25, 17, 14, 2.6, SKIN, "organic")
    rod(cv, 17, 14, 22, 9, 2.3, SKIN, "organic")
    hand = ell_m(W, W, 24, 7, 3.2, 3)
    shade_mask(cv, hand, SKIN, "organic", height=sphere_height(hand))
    _stump(cv, 6.5, 25.5)
    return finish(cv)


@item("limb_leg")
def limb_leg():
    cv = _cv()
    rod(cv, 8, 24, 16, 14, 3.3, SKIN, "organic")
    rod(cv, 16, 14, 22, 7, 2.6, SKIN, "organic")
    foot = poly_mask(W, W, [(20, 4), (24, 3), (28, 7), (25, 9), (21, 9)])
    shade_mask(cv, foot, "#3a3a44", "rubber", bevel=1.2)
    _stump(cv, 7.5, 24.5)
    return finish(cv)


@item("limb_head")
def limb_head():
    cv = _cv()
    head = ell_m(W, W, 16, 15, 7.5, 8.5)
    shade_mask(cv, head, SKIN, "organic", height=sphere_height(head))
    hair = ell_m(W, W, 16, 11, 8, 5.5) & ~ell_m(W, W, 16, 16, 6.5, 5.5)
    shade_mask(cv, hair & head | (hair & ell_m(W, W, 16, 12, 8.5, 6)), "#4a2e1e", "cloth", bevel=1.5)
    dots(cv, ((13, 16), (19, 16)), "#1a1a24")
    cv.hline(14, 18, 20, hexc("#8a4a3a"))
    ball(cv, 16, 25, 3.2, 1.8, "#b82838", "organic")
    return finish(cv)
