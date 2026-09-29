"""Inventory / floor icons for clothing, in the paper-doll palette encoding.

Each icon is a 32x32 cell named `icon_<worn layer>` (icon_uniform_jumpsuit, icon_head_beanie...)
and is recoloured by the same shader and the same per-garment colours as the worn sprite,
so a red security jumpsuit is red in your hand too (like tg's per-job clothing icons).
Materials: 0 primary, 1 secondary, 2 accent, 3 fixed metal/dark.
"""
import numpy as np
from PIL import Image, ImageDraw

from common import T, rrect_mask
from mobs import Layer, expand


def poly(*pts):
    im = Image.new("L", (T, T), 0)
    ImageDraw.Draw(im).polygon(list(pts), fill=1)
    return np.array(im).astype(bool)


def ell(cx, cy, rx, ry):
    im = Image.new("L", (T, T), 0)
    ImageDraw.Draw(im).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=1)
    return np.array(im).astype(bool)


def R(x0, y0, x1, y1, r=0):
    return rrect_mask(T, T, x0, y0, x1, y1, r)


def hline(L, x0, x1, y, mat, s):
    for x in range(x0, x1 + 1):
        L.set(x, y, mat, s)


def vline(L, x, y0, y1, mat, s):
    for y in range(y0, y1 + 1):
        L.set(x, y, mat, s)


# ------------------------------------------------------------------ uniforms
def _suit_body(skirt=False):
    """A jumpsuit laid out flat: shoulders, angled sleeves, torso and legs."""
    torso = R(10, 6, 21, 18, 1)
    sleeve_l = poly((10, 6), (6, 9), (4, 16), (7, 17), (10, 12))
    sleeve_r = poly((21, 6), (25, 9), (27, 16), (24, 17), (21, 12))
    if skirt:
        legs = poly((10, 18), (21, 18), (24, 26), (7, 26))
    else:
        legs = R(10, 18, 14, 28) | R(17, 18, 21, 28) | R(10, 18, 21, 20)
    return torso, sleeve_l | sleeve_r, legs


def uniform_icon(kind):
    L = Layer()
    torso, sleeves, legs = _suit_body(kind == "skirt")
    L.fill(legs, 0, base=2.9)
    L.fill(sleeves, 0, base=3.1)
    L.fill(torso, 0, base=3.4)
    L.darken(expand(sleeves, 1) & torso & ~sleeves, 1)
    # cuffs (secondary)
    L.fill(poly((4, 15), (7, 16), (7, 17), (4, 16)) | R(4, 15, 6, 16), 1, flat=True, base=3)
    L.fill(R(25, 15, 27, 16), 1, flat=True, base=3)
    if kind == "scrubs":
        # v-neck
        for i in range(4):
            L.set(14 + i // 2, 6 + i, 1, 2)
            L.set(17 - i // 2, 6 + i, 1, 2)
        L.fill(R(17, 11, 19, 13), 1, base=3, amp=0.5)  # breast pocket
    else:
        # collar
        L.fill(poly((13, 6), (15, 6), (15, 9), (12, 8)), 1, base=4, amp=0.5)
        L.fill(poly((16, 6), (18, 6), (19, 8), (16, 9)), 1, base=4, amp=0.5)
        # zip / placket
        vline(L, 15, 9, 17, 0, 2)
        vline(L, 16, 9, 17, 0, 4)
        # belt (accent) + buckle (metal)
        hline(L, 10, 21, 17, 2, 2)
        L.set(15, 17, 3, 5)
        L.set(16, 17, 3, 4)
        L.fill(R(18, 10, 20, 12), 0, base=2.2, amp=0.3)  # pocket
        L.set(18, 10, 1, 3)
        L.set(19, 10, 1, 3)
        L.set(20, 10, 1, 3)
    if kind == "formal":
        for y in (10, 12, 14):
            L.set(13, y, 2, 5)
        L.fill(R(8, 6, 11, 7), 2, flat=True, base=4)  # epaulettes
        L.fill(R(20, 6, 23, 7), 2, flat=True, base=4)
    L.outline()
    return L


# ------------------------------------------------------------------ over-suits
def coat_icon(kind):
    L = Layer()
    if kind in ("winter", "labcoat"):
        body = poly((10, 5), (21, 5), (23, 28), (8, 28))
        sleeves = poly((10, 5), (5, 9), (3, 19), (7, 20), (10, 12)) | poly((21, 5), (26, 9), (28, 19), (24, 20), (21, 12))
        L.fill(sleeves, 0, base=3.0)
        L.fill(body, 0, base=3.3)
        L.darken(expand(sleeves, 1) & body & ~sleeves, 1)
        if kind == "winter":
            ex = np.zeros((T, T))
            ex[::2, ::2] = 0.6
            fur = (R(9, 3, 22, 7, 2) | R(8, 26, 23, 29, 1) | R(3, 18, 7, 21, 1) | R(24, 18, 28, 21, 1)) & ~R(13, 4, 18, 5)
            L.fill(fur, 1, base=4, amp=0.8, extra=ex)
            vline(L, 15, 8, 25, 0, 2)
            vline(L, 16, 8, 25, 0, 4)
            for y in (11, 15, 19, 23):
                L.set(14, y, 2, 5)  # toggles
                L.set(17, y, 2, 4)
            hline(L, 10, 12, 21, 0, 1)
            hline(L, 19, 21, 21, 0, 1)
        else:
            # open front showing the lining, lapels, pens in the pocket
            L.fill(poly((14, 6), (17, 6), (18, 27), (13, 27)), 0, base=1.6, amp=0.4)
            L.fill(poly((11, 5), (14, 5), (14, 14), (12, 11)), 0, base=4.2, amp=0.5)
            L.fill(poly((17, 5), (20, 5), (19, 11), (17, 14)), 0, base=4.2, amp=0.5)
            hline(L, 19, 21, 13, 0, 2)
            L.set(20, 12, 2, 5)
            L.set(21, 11, 3, 4)
    elif kind == "hazard":
        vest = poly((9, 6), (13, 6), (15, 11), (16, 11), (18, 6), (22, 6), (23, 24), (8, 24))
        vest &= ~(R(6, 7, 9, 14, 2) | R(22, 7, 25, 14, 2))
        L.fill(vest, 0, base=3.4)
        L.fill(vest & (R(0, 15, 31, 16) | R(0, 20, 31, 21)), 1, flat=True, base=5)
        vline(L, 15, 12, 24, 0, 2)
    elif kind == "armor":
        vest = R(8, 7, 23, 24, 3) & ~R(13, 5, 18, 9, 2)
        L.fill(vest, 0, base=3.1)
        L.fill(R(8, 7, 11, 10, 1) | R(20, 7, 23, 10, 1), 0, base=4.2, amp=0.5)  # shoulder pads
        L.fill(R(11, 12, 20, 19, 1), 1, base=3.4, amp=1.0)  # trauma plate
        hline(L, 8, 23, 21, 3, 2)
        L.set(12, 21, 3, 5)
        L.set(19, 21, 3, 5)
    elif kind == "apron":
        body = poly((11, 9), (20, 9), (20, 13), (23, 16), (22, 27), (9, 27), (8, 16), (11, 13))
        L.fill(body, 0, base=3.4)
        L.fill(R(12, 18, 19, 22, 1), 0, base=2.4, amp=0.4)  # pocket
        hline(L, 12, 19, 18, 1, 4)
        for x0, x1 in ((11, 12), (19, 20)):  # neck strap
            L.fill(poly((x0, 9), (x1, 9), (x1 + (2 if x0 > 15 else -2), 4), (x0 + (2 if x0 > 15 else -2), 4)), 1, flat=True, base=3)
        L.fill(R(4, 15, 8, 16) | R(23, 15, 27, 16), 1, flat=True, base=3)  # waist ties
    L.outline()
    return L


# ------------------------------------------------------------------ headwear
def hat_icon(kind):
    L = Layer()
    if kind == "hood":
        m = ell(16, 15, 10, 11) & ~ell(16, 18, 6, 7)
        m |= R(7, 22, 25, 26, 2)
        m &= ~R(11, 16, 21, 26)
        L.fill(m, 0, base=3.1)
        ex = np.zeros((T, T))
        ex[::2, ::2] = 0.6
        L.fill(expand(ell(16, 18, 6, 7), 1) & ~ell(16, 18, 6, 7) & m, 1, base=4, amp=0.8, extra=ex)
        L.fill(ell(16, 18, 6, 7) & R(0, 0, 31, 22), 3, base=1.2, amp=0.3)  # dark inside
    elif kind == "beanie":
        dome = ell(16, 19, 10, 10) & R(0, 0, 31, 22)
        L.fill(dome, 0, base=3.2)
        for x in range(8, 25, 3):
            vline(L, x, 13, 21, 0, 2)
        L.fill(R(6, 20, 26, 25, 2), 1, base=3.4, amp=0.6)
        for x in range(7, 26, 2):
            vline(L, x, 21, 24, 1, 2)
        ex = np.zeros((T, T))
        ex[::2, 1::2] = 0.7
        L.fill(ell(16, 7, 3, 3), 2, base=4, amp=0.8, extra=ex)
    elif kind == "hardhat":
        L.fill(ell(16, 18, 10, 9) & R(0, 0, 31, 20), 0, base=3.4)
        L.fill(R(3, 20, 28, 23, 2), 0, base=2.6, amp=0.6)
        vline(L, 16, 10, 19, 0, 5)
        vline(L, 15, 10, 19, 0, 4)
        L.fill(R(13, 12, 18, 16, 1), 2, base=5, amp=0.3)  # lamp
    elif kind == "helmet":
        m = ell(16, 17, 10, 10) & R(0, 0, 31, 26)
        m |= R(6, 17, 9, 26, 1) | R(23, 17, 26, 26, 1)
        m &= ~R(10, 20, 22, 26)
        L.fill(m, 0, base=3.1)
        L.fill(R(9, 16, 23, 20, 2), 1, base=4, amp=0.9)  # visor
        L.set(11, 17, 1, 5)
        L.set(12, 17, 1, 5)
    elif kind == "beret":
        L.fill(ell(15, 17, 11, 6), 0, base=3.0)
        L.fill(R(8, 21, 22, 23, 1), 0, base=2.2, amp=0.4)
        L.fill(R(9, 14, 11, 16, 1), 2, base=5, amp=0.3)
    elif kind == "cap":
        L.fill(ell(15, 18, 9, 8) & R(0, 0, 31, 20), 0, base=3.2)
        L.fill(poly((15, 19), (28, 19), (27, 23), (15, 22)), 0, base=2.6, amp=0.6)  # bill
        L.fill(R(6, 19, 15, 21), 1, flat=True, base=3)
        L.set(15, 10, 1, 4)
    elif kind == "chef":
        ex = np.zeros((T, T))
        ex[3::6, :] = -0.6
        puff = ell(11, 11, 6, 6) | ell(20, 11, 6, 6) | ell(16, 8, 6, 6) | R(9, 11, 23, 22, 2)
        L.fill(puff, 0, base=3.8, amp=1.2, extra=ex)
        L.fill(R(8, 20, 24, 25, 1), 1, base=3.5, amp=0.6)
    elif kind == "captain":
        L.fill(ell(16, 15, 12, 6), 0, base=3.0)
        L.fill(R(7, 15, 25, 21, 1), 0, base=3.2)
        L.fill(R(7, 18, 25, 19), 2, flat=True, base=4)  # gold band
        L.fill(poly((9, 21), (23, 21), (25, 25), (7, 25)), 3, base=1.8, amp=0.6)  # peak
        L.fill(ell(16, 13, 2, 2), 2, base=5, amp=0.3)  # badge
    L.outline()
    return L


# ------------------------------------------------------------------ masks
def mask_icon(kind):
    L = Layer()
    if kind == "gasmask":
        L.fill(ell(16, 14, 9, 10), 0, base=2.9)
        for cx in (12, 20):
            L.fill(ell(cx, 12, 3, 3), 1, base=4.2, amp=0.8)
            L.set(cx - 1, 11, 1, 5)
        L.fill(R(12, 20, 20, 28, 2), 3, base=2.6, amp=1.0)  # filter
        for y in (22, 24, 26):
            hline(L, 13, 19, y, 3, 1)
        vline(L, 5, 10, 18, 0, 2)  # strap stubs
        vline(L, 27, 10, 18, 0, 2)
    elif kind == "breath":
        L.fill(ell(12, 13, 6, 5), 0, base=3.6, amp=0.9)
        L.fill(ell(12, 13, 3, 2), 0, base=2.2, amp=0.3)
        tube = poly((16, 16), (18, 16), (24, 24), (25, 28), (23, 28), (22, 25))
        L.fill(tube, 3, base=2.6, amp=1.0)
        for i in range(3):
            L.set(19 + i * 2, 19 + i * 3, 3, 4)
        vline(L, 5, 9, 16, 3, 1)
        vline(L, 19, 9, 13, 3, 1)
    elif kind == "scarf":
        band = poly((4, 8), (27, 12), (26, 17), (3, 13))
        tail = R(18, 14, 23, 28, 1)
        L.fill(band, 0, base=3.2)
        L.fill(tail, 0, base=3.0)
        stripes = (R(0, 18, 31, 19) | R(0, 23, 31, 24)) & tail
        stripes |= band & (poly((9, 8), (11, 8), (10, 15), (8, 15)) | poly((15, 9), (17, 9), (16, 16), (14, 16)))
        L.fill(stripes, 1, flat=True, base=4)
        for x in range(18, 24, 2):
            L.set(x, 29, 1, 3)
            L.set(x, 30, 1, 2)
    L.outline()
    return L


# ------------------------------------------------------------------ small wearables
def shoes_icon():
    L = Layer()
    for ox, oy in ((2, 11), (14, 17)):
        upper = poly((ox + 2, oy), (ox + 7, oy), (ox + 8, oy + 4), (ox + 14, oy + 6), (ox + 15, oy + 9), (ox + 1, oy + 9))
        L.fill(upper, 0, base=3.2)
        L.fill(R(ox + 1, oy + 9, ox + 15, oy + 10), 0, base=1.5, amp=0.3)  # sole
        hline(L, ox + 4, ox + 7, oy + 3, 0, 5)  # laces
        L.set(ox + 5, oy + 5, 0, 5)
        L.set(ox + 6, oy + 5, 0, 5)
        L.set(ox + 3, oy + 1, 0, 1)  # opening
        L.set(ox + 4, oy + 1, 0, 1)
        L.set(ox + 5, oy + 1, 0, 1)
    L.outline()
    return L


def gloves_icon():
    L = Layer()
    for ox, flip in ((2, False), (16, True)):
        m = R(ox + 1, 13, ox + 11, 21, 2)  # palm
        for k, h in enumerate((5, 7, 7, 5)):  # fingers, with a gap between each
            fx = ox + 1 + k * 3 if not flip else ox + 10 - k * 3
            m |= R(fx, 13 - h, fx + 1, 14, 1)
        tx = ox + 11 if not flip else ox - 1
        m |= poly((tx, 15), (tx + (3 if not flip else -3), 12), (tx + (4 if not flip else -4), 13), (tx + (1 if not flip else -1), 19))
        L.fill(m, 0, base=3.3)
        cuff = R(ox + 1, 21, ox + 11, 26, 1)
        L.fill(cuff, 0, base=2.4, amp=0.5)
        hline(L, ox + 1, ox + 11, 21, 0, 1)
        for x in range(ox + 2, ox + 11, 2):
            L.set(x, 24, 0, 1)
    L.outline()
    return L


def backpack_icon():
    L = Layer()
    L.fill(R(7, 6, 24, 28, 4), 0, base=3.2)
    L.fill(R(7, 6, 24, 15, 4), 1, base=3.4, amp=1.0)  # flap
    hline(L, 8, 23, 15, 1, 1)
    L.fill(R(11, 19, 20, 26, 2), 0, base=2.6, amp=0.6)  # front pocket
    hline(L, 11, 20, 19, 0, 4)
    L.fill(R(14, 13, 17, 17, 1), 3, base=3.5, amp=0.8)  # buckle
    L.fill(R(13, 2, 18, 6, 2) & ~R(15, 4, 16, 6), 1, base=3, amp=0.5)  # carry handle
    L.outline()
    return L


def toolbelt_icon():
    L = Layer()
    belt = poly((2, 14), (29, 12), (29, 16), (2, 18))
    L.fill(belt, 0, base=3.0, amp=0.8)
    L.fill(R(13, 12, 18, 17, 1), 3, base=3.8, amp=0.9)  # buckle
    L.fill(R(14, 13, 17, 16), 0, base=2.0, amp=0.2)
    for x0, x1 in ((4, 10), (21, 27)):  # pouches
        L.fill(R(x0, 17, x1, 25, 1), 0, base=3.2, amp=1.0)
        hline(L, x0, x1, 19, 0, 2)
    L.fill(R(6, 9, 7, 15), 3, base=4, amp=0.5)  # a screwdriver handle poking out
    L.fill(R(23, 10, 25, 13), 1, base=3.5, amp=0.5)  # something in the other pouch
    L.outline()
    return L


def all_icons():
    out = {}
    for u in ("jumpsuit", "scrubs", "formal", "skirt"):
        out[f"icon_uniform_{u}"] = uniform_icon(u)
    for c in ("winter", "labcoat", "hazard", "armor", "apron"):
        out[f"icon_suit_{c}"] = coat_icon(c)
    for h in ("hood", "beanie", "hardhat", "helmet", "beret", "cap", "chef", "captain"):
        out[f"icon_head_{h}"] = hat_icon(h)
    for m in ("gasmask", "breath", "scarf"):
        out[f"icon_mask_{m}"] = mask_icon(m)
    out["icon_shoes"] = shoes_icon()
    out["icon_gloves"] = gloves_icon()
    out["icon_backpack"] = backpack_icon()
    out["icon_toolbelt"] = toolbelt_icon()
    return {k: v.to_canvas() for k, v in out.items()}
