"""Station objects, second generation: machines and furniture redrawn by hand in the 3/4
view the station uses (a lit top face, a front face, a contact shadow), shaded from surface
normals with the px.py materials, same names, canvas sizes and anchors as objects.py.

REDRAWN maps sprite name -> function returning an objects.Sprite (glow layer included);
objects.build() swaps these in just before packing.
"""
import math

import numpy as np

from common import hexc, mix, ramp, rng_for, shade
from px import (capsule_height, capsule_mask, cyl_height, ell_m, outline, poly_mask, rect_m, shade_mask,
                sphere_height)

REDRAWN = {}

STEEL = "#a9b3c2"
DARK_STEEL = "#6b7486"
GUNMETAL = "#4a505e"
RUBBER = "#2c2a33"
SHADOW = (0.03, 0.03, 0.09)


def obj(*names):
    def deco(fn):
        for n in names:
            REDRAWN[n] = fn
        return fn
    return deco


def _sp(w=32, h=32):
    from objects import Sprite
    return Sprite(w, h)


def H(c):
    return hexc(c) if isinstance(c, str) else c


# ------------------------------------------------------------------ canvas-aware helpers
def R(cv, x0, y0, x1, y1, r=0):
    return rect_m(cv.w, cv.h, x0, y0, x1, y1, r)


def E(cv, cx, cy, rx, ry):
    return ell_m(cv.w, cv.h, cx, cy, rx, ry)


def P(cv, pts):
    return poly_mask(cv.w, cv.h, pts)


def sheen(cv, x, y, a):
    """Blend a touch of white over what's there (a glare on glass or a polished edge)."""
    if 0 <= x < cv.w and 0 <= y < cv.h:
        cv.blend_px(x, y, np.array([1.0, 1.0, 1.0, a]))


def fill(cv, mask, c):
    cv.a[mask] = H(c)


def rod(cv, x0, y0, x1, y1, r, col, mat="metal"):
    m = capsule_mask(cv.w, cv.h, x0, y0, x1, y1, r)
    return shade_mask(cv, m, col, mat, height=capsule_height(cv.w, cv.h, x0, y0, x1, y1, r)), m


def panel(cv, x0, y0, x1, y1, col, mat="paint", r=0, bevel=1.5):
    m = R(cv, x0, y0, x1, y1, r)
    return shade_mask(cv, m, col, mat, bevel=bevel), m


def inset(cv, x0, y0, x1, y1, c="#15141c"):
    """A recessed slot / cavity: dark fill, the lip catching light along its lower edge."""
    c = H(c)
    cv.rect(x0, y0, x1, y1, c)
    cv.hline(x0, x1, y0, shade(c, -0.3))
    cv.hline(x0, x1, y1 + 1, mix(cv.get(x0, y1 + 1) if y1 + 1 < cv.h else c, hexc("#ffffff"), 0.25))


def screw(cv, x, y, base):
    p = shade(H(base), -0.35)
    cv.px(x, y, p)


def lamp(sp, x, y, c, size=1):
    c = H(c)
    for dx in range(size):
        for dy in range(size):
            sp.g(x + dx, y + dy, c)


def ground(cv, x0, x1, y, a=0.42):
    """Soft contact shadow: an oval of darkness under the footprint, strongest at the middle."""
    cx = (x0 + x1) / 2
    rx = (x1 - x0) / 2 + 1.5
    for dy, k in ((0, 1.0), (1, 0.55), (-1, 0.45)):
        yy = y + dy
        if not 0 <= yy < cv.h:
            continue
        for x in range(int(cx - rx), int(cx + rx) + 2):
            if 0 <= x < cv.w:
                fall = max(0.0, 1 - (abs(x + 0.5 - cx) / (rx + 0.5)) ** 2.5)
                if fall > 0:
                    cv.a[yy, x] = [*SHADOW, a * k * fall]


def cabinet(cv, x0, y0, x1, y1, top_h, col, mat="paint", top=None, r=1, bevel=1.6):
    """A 3/4 box: flat lit top face of `top_h` rows, then the front face; returns (front ramp,
    top ramp, front mask)."""
    col = H(col)
    top = H(top) if top is not None else shade(col, 0.2)
    tm = R(cv, x0, y0, x1, y0 + top_h - 1, 0)
    fm = R(cv, x0, y0 + top_h, x1, y1, 0)
    fp = shade_mask(cv, fm, col, mat, bevel=bevel)
    tp = shade_mask(cv, tm, top, mat, bevel=1.0)
    cv.hline(x0 + 1, x1 - 1, y0, mix(tp[-1], hexc("#ffffff"), 0.2))
    # the edge where top meets front catches the light, the face just under it is shaded
    cv.hline(x0, x1, y0 + top_h, mix(fp[-1], hexc("#ffffff"), 0.15))
    cv.hline(x0 + 1, x1 - 1, y0 + top_h + 1, fp[len(fp) // 2 - 1])
    if r:
        for (x, y) in ((x0, y0), (x1, y0)):
            cv.px(x, y, (0, 0, 0, 0))
    return fp, tp, fm


def door(cv, x0, y0, x1, y1, col, mat="paint"):
    """A raised door / panel on a front face: lit top-left lip, shaded bottom-right lip."""
    col = H(col)
    pal = shade_mask(cv, R(cv, x0, y0, x1, y1, 0), col, mat, bevel=1.2)
    cv.hline(x0, x1, y0, pal[-1])
    cv.vline(x0, y0, y1, pal[-1])
    cv.hline(x0, x1, y1, pal[0])
    cv.vline(x1, y0, y1, pal[0])
    return pal


def slits(cv, x0, x1, ys, pal):
    for y in ys:
        cv.hline(x0, x1, y, pal[0])
        cv.hline(x0, x1, y + 1, pal[-1])


def screen(sp, x0, y0, x1, y1, col, style="text", seed="scr"):
    """A glowing screen with a dark bezel lip and a glare corner."""
    from objects import screen as _scr
    _scr(sp, x0, y0, x1, y1, col, rng_for(seed), style)
    c = H(col)
    sp.cv.hline(x0, x1, y0 - 1, H("#101018"))
    sp.cv.vline(x0 - 1, y0 - 1, y1, H("#101018"))
    for i in range(3):
        sp.cv.px(x1 - 1 - i, y0 + i, mix(c, hexc("#ffffff"), 0.35 - i * 0.1))


def done(sp):
    """Outline everything that isn't shadow; the shadow is kept soft underneath."""
    cv = sp.cv
    a = cv.a
    shadow_px = (a[:, :, 3] < 0.6) & (a[:, :, 3] > 0) & (np.abs(a[:, :, 0] - SHADOW[0]) < 0.01)
    keep = a.copy()
    cv.a = a.copy()
    cv.a[shadow_px] = 0
    outline(cv, True)
    solid = cv.a[:, :, 3] > 0.05
    back = keep.copy()
    back[~shadow_px] = 0
    back[solid] = cv.a[solid]
    cv.a = back
    return sp


# ============================================================================ gas canisters
CANISTER = {
    # TG canister body/band palette; keep the established procedural cylinder art.
    "tritium": ("#3fcd40", "#000000", "#e8eef4"),
    "nob": ("#6399fc", "#b2b2b2", "#e8eef4"),
    "nitrium": ("#7b4732", "#e8eef4", "#e8eef4"),
    "bz": ("#9b5d7f", "#d0d2a0", "#e8eef4"),
    "pluox": ("#2786e5", "#e8eef4", "#e8eef4"),
    "miasma": ("#009823", "#f7d5d3", "#e8eef4"),
    "freon": ("#6696ee", "#fefb30", "#e8eef4"),
    "h2": ("#eaeaea", "#be3455", "#e8eef4"),
    "healium": ("#009823", "#ff0e00", "#e8eef4"),
    "proto_nitrate": ("#008200", "#33cc33", "#e8eef4"),
    "zauker": ("#009a00", "#006600", "#e8eef4"),
    "halon": ("#9b5d7f", "#368bff", "#e8eef4"),
    "he": ("#9b5d7f", "#368bff", "#e8eef4"),
    "antinob": ("#333333", "#fefb30", "#e8eef4"),
    # body, band, label text colour, stencil
    "o2": ("#2f62c8", "#e8eef4", "#e8eef4"),
    "n2": ("#b8323a", "#e8eef4", "#e8eef4"),
    "air": ("#a9b1bf", "#3a6ad8", "#2a2e38"),
    "plasma": ("#e0762a", "#2a2530", "#2a2530"),
    "co2": ("#34343e", "#e8eef4", "#e8eef4"),
    "empty": ("#d8cfb6", "#8a8472", "#5a5446"),
    "n2o": ("#e8e8ec", "#c83a3a", "#c83a3a"),
    "h2o": ("#4a6a8a", "#9ad0e8", "#dcecf8"),
}


def cyl_cols(cv, mask, base, spec=True, n=6, spread=0.55, top_boost=None):
    """Hand-style vertical cylinder: every column gets one tone from a fixed profile (dark
    rim, lit left third, a 1 px specular line, falling off to a reflected-light right rim)."""
    pal = ramp(base, n, spread)
    ys, xs = np.nonzero(mask)
    x0, x1 = xs.min(), xs.max()
    wdt = x1 - x0 + 1
    for x in range(x0, x1 + 1):
        u = (x - x0 + 0.5) / wdt  # 0..1 across
        if u < 0.1:
            k = 1
        elif u < 0.38:
            k = n - 2
        elif u < 0.62:
            k = n // 2
        elif u < 0.84:
            k = n // 2 - 1
        elif u < 0.93:
            k = 0
        else:
            k = 1  # bounce light off the floor/wall
        col = pal[k]
        for y in np.nonzero(mask[:, x])[0]:
            cv.a[y, x] = col
    if spec:
        sx = x0 + max(1, int(wdt * 0.26))
        for y in np.nonzero(mask[:, sx])[0]:
            cv.a[y, sx] = mix(pal[-1], hexc("#ffffff"), 0.45)
    return pal


def canister(kind):
    body_c, band_c, text_c = CANISTER[kind]
    sp = _sp(32, 40)
    cv = sp.cv
    x0, x1 = 8, 23
    ground(cv, x0, x1, 37)
    # the tank body, then the dark foot ring it stands in
    body = R(cv, x0, 10, x1, 35, 0)
    pal = cyl_cols(cv, body, H(body_c))
    for (y0, y1) in ((13, 14), (31, 32)):
        cyl_cols(cv, body & R(cv, 0, y0, 31, y1), H(band_c), spec=False)
    if kind == "plasma":
        for x in range(x0, x1 + 1):
            for y in (31, 32):
                if (x - y) % 4 < 2:
                    cv.px(x, y, shade(H("#e8c83a"), -0.2 if x > 17 else 0))
    if kind == "n2o":
        for y in (18, 22, 26):
            cyl_cols(cv, body & R(cv, 0, y, 31, y), H(band_c), spec=False)
    foot = R(cv, x0, 34, x1, 36, 0)
    cyl_cols(cv, foot, H(GUNMETAL), spec=False)
    cv.hline(x0, x1, 33, pal[0])
    # stencilled name
    if kind != "n2o":
        tc = H(text_c)
        for y, (a, b) in ((19, (11, 19)), (21, (11, 17))):
            for x in range(a, b + 1):
                if x != 14 and x != 18 or y == 22:
                    cv.px(x, y, mix(tc, cv.get(x, y), 0.25 if x > 16 else 0.0))
    # the shoulder: the top of the cylinder seen from above, a lit ellipse with a dark rim
    cap = E(cv, 15.5, 10.0, 8.0, 3.0)
    cp = ramp(shade(H(body_c), 0.12), 5, 0.45)
    fill(cv, cap, cp[3])
    fill(cv, cap & ~E(cv, 16.5, 10.8, 7.4, 2.8), cp[4])
    fill(cv, cap & ~E(cv, 15.5, 9.4, 8.0, 3.0), cp[2])
    # valve: neck, handwheel, and the pressure gauge beside it
    cv.rect(14, 5, 17, 9, H("#8a93a3"))
    cv.vline(14, 5, 9, H("#c8d0dc"))
    cv.vline(17, 5, 9, H("#5a6272"))
    wheel = E(cv, 15.5, 4.5, 4.0, 1.7)
    fill(cv, wheel, H("#26242c"))
    fill(cv, wheel & ~E(cv, 15.5, 4.5, 2.4, 0.6), H("#4a4f5c"))
    cv.hline(13, 15, 3, H("#6b7486"))
    cv.px(15, 4, H("#8a93a3"))
    g = E(cv, 21.0, 7.5, 2.0, 2.0)
    fill(cv, g, H("#dfe6ee"))
    cv.px(20, 7, H("#ffffff"))
    cv.px(21, 8, H("#1a1a24"))
    cv.px(22, 7, H("#c83a3a"))
    cv.px(19, 9, H("#5a6272"))
    # outlet port on the right flank
    cv.rect(24, 23, 25, 25, H("#6b7486"))
    cv.px(24, 23, H("#a9b3c2"))
    rng = rng_for("can" + kind)
    for _ in range(4):
        x, y = rng.randint(10, 21), rng.randint(24, 30)
        cv.px(x, y, shade(cv.get(x, y), -0.12))
    lamp(sp, 11, 10, "#5aff7a" if kind != "empty" else "#ff9a3a")
    return done(sp)


for _k in CANISTER:
    REDRAWN["canister_" + _k] = (lambda k: (lambda: canister(k)))(_k)


NEW = {}  # objects that only exist in the second generation


def new_obj(*names):
    def deco(fn):
        for n in names:
            NEW[n] = fn
        return fn
    return deco


def apply(pk):
    names = {n for n, _ in pk.items}
    for name, fn in REDRAWN.items():
        if name in names:
            pk.replace(name, fn())
    for name, fn in NEW.items():
        if name not in names:
            pk.add(name, fn())


import objects_v2_furn  # noqa: E402,F401
import objects_v2_mach  # noqa: E402,F401
import objects_v2_wall  # noqa: E402,F401
import objects_v2_tg  # noqa: E402,F401
import objects_v2_gen  # noqa: E402,F401
