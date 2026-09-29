"""Skyfarer objects, second pass: port furniture and the flora of the new rings.

Port pieces are hard-edged and man-made — a lamp post is a post, a sign is a board on a
bracket — because a quay has to read as somewhere people built rather than somewhere
things grew. The new flora is the opposite: silhouette first, one unexpected colour, and
enough asymmetry that a field of them does not tile visibly.

Everything is built from sky_objects' own primitives so the new pieces sit on the same
shelf as the old ones.
"""
import math

import numpy as np

from common import (Canvas, ellipse_mask, fbm, hexc, mix, ramp, rng_for, rrect_mask,
                    sel_outline, shade, value_noise)
from objects import Sprite, box3d, contact_shadow
from sky_objects import _clump, _flat, _rockish, _tree


# ------------------------------------------------------------------ port furniture
def port_lantern():
    """A tall iron post with a shuttered lamp. Lit from dusk by somebody whose job it is."""
    sp = Sprite()
    p = ramp("#3a4048", 7, 0.45)
    # post
    for y in range(12, 30):
        for x in range(14, 18):
            sp.cv.px(x, y, p[int(np.clip(5 - (x - 14), 0, 6))])
    # base flange
    for x in range(11, 21):
        sp.cv.px(x, 29, p[2])
        sp.cv.px(x, 28, p[5])
    # the lamp housing
    for y in range(4, 13):
        t = abs(y - 8) / 5.0
        w = int(6 - t * 2)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, p[int(np.clip(5 - abs(x - 13) * 0.3, 0, 6))])
    # glass, and what is behind it
    for y in range(6, 11):
        for x in range(13, 20):
            sp.g(x, y, hexc("#ffd8a0"))
    sp.g(16, 8, hexc("#fff4d8"))
    # a cross-bar somebody has hung a rope off
    for x in range(9, 24):
        sp.cv.px(x, 13, p[3])
    contact_shadow(sp.cv, 11, 21, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def port_sign():
    """A painted board on an iron bracket. Wall-mounted, so it hangs in the upper half."""
    sp = Sprite()
    wd = ramp("#7a5a38", 7, 0.45)
    ir = ramp("#3a4048", 7, 0.4)
    # bracket
    for y in range(3, 9):
        sp.cv.px(4, y, ir[4])
    for x in range(4, 14):
        sp.cv.px(x, 6, ir[5])
    for k in range(5):
        sp.cv.px(5 + k, 7 + k, ir[2])
    # the board, hanging
    m = rrect_mask(32, 32, 7, 9, 28, 23, 2)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, wd[int(np.clip(4 + (9 - xx) * 0.07 + (11 - yy) * 0.12, 0, 6))])
    # painted lettering, abstracted to bars because 32px cannot hold words
    rng = rng_for("port_sign")
    for row in range(3):
        y = 12 + row * 4
        x = 10
        while x < 25:
            w = rng.randint(2, 5)
            for k in range(w):
                sp.cv.px(x + k, y, hexc("#e8dcc0"))
                sp.cv.px(x + k, y + 1, hexc("#c8bca0"))
            x += w + 2
    for x in range(7, 29):
        sp.cv.px(x, 9, wd[6])
        sp.cv.px(x, 23, wd[1])
    sel_outline(sp.cv, 0.5)
    return sp


def yard_desk():
    """A drawing board on trestles, with a rack of rolled hull plans beside it."""
    sp = Sprite()
    p = box3d(sp.cv, 3, 12, 26, 28, 5, "#6a5238")
    # the board, tilted, with a drawing on it
    for y in range(8, 19):
        t = (y - 8) / 11.0
        x0 = int(5 + t * 1)
        x1 = int(23 - t * 1)
        for x in range(x0, x1):
            sp.cv.px(x, y, hexc("#d8d0bc") if (x + y) % 17 else hexc("#c0b8a4"))
    # a hull drawn on it: a keel line and a rib or two
    for x in range(8, 21):
        sp.cv.px(x, 13, hexc("#3a5a8a"))
    for x in (10, 14, 18):
        for y in range(10, 17):
            sp.cv.px(x, y, hexc("#6a8ab8"))
    # the plan rack
    for k in range(4):
        x = 25 + k % 2
        for y in range(14 + k, 26):
            sp.cv.px(x, y, ramp("#c8bca0", 7, 0.3)[4 - k % 3])
    contact_shadow(sp.cv, 3, 27, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def notice_board():
    """Charts, warnings, prices, and three notices about a missing ship."""
    sp = Sprite()
    wd = ramp("#6a5238", 7, 0.45)
    m = rrect_mask(32, 32, 2, 4, 30, 26, 1)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, wd[int(np.clip(3 + (5 - yy) * 0.1, 0, 6))])
    for x in range(2, 31):
        sp.cv.px(x, 4, wd[6])
        sp.cv.px(x, 26, wd[1])
    # the papers, overlapping, at slightly wrong angles
    rng = rng_for("notice_board")
    for _ in range(7):
        x0 = rng.randint(4, 22)
        y0 = rng.randint(6, 19)
        w = rng.randint(5, 9)
        h = rng.randint(5, 8)
        tone = rng.choice(["#e0d8c4", "#d0c8b0", "#e8e4d4"])
        skew = rng.choice([-1, 0, 0, 1])
        for y in range(h):
            for x in range(w):
                xx = x0 + x + (y * skew) // 4
                yy = y0 + y
                if 3 <= xx < 30 and 5 <= yy < 26:
                    sp.cv.px(xx, yy, hexc(tone))
        for y in range(1, h - 1, 2):
            for x in range(1, w - 1):
                xx = x0 + x + (y * skew) // 4
                if 3 <= xx < 30 and 5 <= y0 + y < 26 and (x + y) % 3:
                    sp.cv.px(xx, y0 + y, hexc("#7a7264"))
        # a pin
        sp.cv.px(x0 + w // 2, y0, hexc("#c84a4a"))
    sel_outline(sp.cv, 0.5)
    return sp


def star_dust():
    """Scattered starlight on the ground: cold light burning quietly through."""
    sp = Sprite()
    rng = rng_for("star_dust")
    for _ in range(34):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 11)
        x = int(16 + math.cos(a) * r)
        y = int(20 + math.sin(a) * r * 0.55)
        sp.g(x, y, hexc("#d8e8ff"))
        if rng.random() < 0.4:
            sp.g(x + rng.choice([-1, 1]), y, hexc("#9ab8e8"))
    return sp


# ------------------------------------------------------------------ new flora
def hearth_tree():
    """Broad, low and warm. The first islands people settled were these."""
    sp = Sprite()
    rng = rng_for("hearth_tree")
    _tree(sp, rng, "#7a5a38", "#5a8a44", h=22, spread=13, leafy=0.88, droop=0.12)
    # it runs warm, and you can see it on a cold morning
    for _ in range(7):
        x = rng.randint(13, 19)
        y = rng.randint(24, 29)
        sp.g(x, y, hexc("#e8a86a"))
    return sp


def gloom_stalk():
    """Grows away from light, which on a lightless island is every direction at once."""
    sp = Sprite()
    rng = rng_for("gloom_stalk")
    p = ramp("#2a2a34", 7, 0.5)
    cap = ramp("#4a3a58", 7, 0.45)
    # the trunk, forking badly
    stems = [(16, 30, 0.0)]
    for _ in range(4):
        x, y, lean = stems[rng.randint(0, len(stems) - 1)]
        stems.append((x + rng.randint(-4, 4), y - rng.randint(6, 11), lean + rng.uniform(-0.3, 0.3)))
    for (x, y, lean) in stems:
        for k in range(10):
            xx = int(x + lean * k)
            yy = y - k
            if 0 <= xx < 32 and 0 <= yy < 32:
                sp.cv.px(xx, yy, p[int(np.clip(4 - k // 4, 0, 6))])
                sp.cv.px(xx + 1, yy, p[2])
    for (x, y, _l) in stems[1:]:
        m = ellipse_mask(32, 32, x, y - 9, rng.randint(3, 5), rng.randint(2, 4))
        ys, xs = np.nonzero(m)
        for (yy, xx) in zip(ys, xs):
            sp.cv.px(xx, yy, cap[int(np.clip(3 + (x - xx) * 0.2, 0, 6))])
    contact_shadow(sp.cv, 12, 20, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def lightning_tree():
    """Struck so often it has grown into the shape of the strike."""
    sp = Sprite()
    rng = rng_for("lightning_tree")
    p = ramp("#3a3630", 7, 0.5)
    # a trunk that forks the way a bolt does
    def branch(x, y, dx, n, w):
        for k in range(n):
            x += dx + rng.uniform(-0.5, 0.5)
            y -= 1
            for ww in range(max(1, w)):
                xx, yy = int(x) + ww, int(y)
                if 0 <= xx < 32 and 0 <= yy < 32:
                    sp.cv.px(xx, yy, p[int(np.clip(4 - ww, 0, 6))])
            if k == n // 2 and w > 1:
                branch(x, y, -dx * 1.6, n // 2, w - 1)
    branch(16, 30, 0.1, 18, 3)
    branch(16, 22, -0.8, 9, 2)
    branch(16, 19, 0.9, 8, 2)
    # fulgurite in the roots, still faintly charged
    for _ in range(9):
        x = rng.randint(11, 21)
        y = rng.randint(26, 30)
        sp.g(x, y, hexc("#9ad8ff"))
    contact_shadow(sp.cv, 11, 21, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def reef_fan():
    """A lattice of aether-grown coral that moves when nothing is moving it."""
    sp = Sprite()
    rng = rng_for("reef_fan")
    p = ramp("#c86a8a", 7, 0.45)
    base = (16, 29)
    for k in range(9):
        a = math.pi * (0.15 + 0.7 * k / 8.0) + math.pi
        length = rng.randint(12, 19)
        x, y = float(base[0]), float(base[1])
        for s in range(length):
            x += math.cos(a) * 1.0 + rng.uniform(-0.25, 0.25)
            y += math.sin(a) * 1.0
            xx, yy = int(x), int(y)
            if not (0 <= xx < 32 and 0 <= yy < 32):
                break
            sp.cv.px(xx, yy, p[int(np.clip(5 - s // 6, 0, 6))])
            # cross-members: it is a fan, not a bush
            if s % 4 == 2:
                for d in (-1, 1):
                    sp.cv.px(xx + d, yy, p[2])
    for _ in range(6):
        sp.g(rng.randint(9, 23), rng.randint(12, 24), hexc("#f0a8c0"))
    contact_shadow(sp.cv, 13, 19, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def aether_polyp():
    """It pulses, and cutting one open takes about a minute to go dark."""
    sp = Sprite()
    rng = rng_for("aether_polyp")
    p = ramp("#4a8a9a", 7, 0.45)
    for _ in range(5):
        cx = rng.randint(9, 23)
        cy = rng.randint(20, 28)
        r = rng.randint(3, 5)
        m = ellipse_mask(32, 32, cx, cy, r, int(r * 1.2))
        ys, xs = np.nonzero(m)
        for (yy, xx) in zip(ys, xs):
            sp.cv.px(xx, yy, p[int(np.clip(4 + (cx - xx) * 0.2 + (cy - yy) * 0.2, 0, 6))])
        sp.g(cx, cy - r // 2, hexc("#9ad8ff"))
        # the mouth
        for k in range(3):
            sp.cv.px(cx - 1 + k, cy - r, hexc("#1a3a44"))
    contact_shadow(sp.cv, 8, 24, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def tide_bell():
    """A hollow growth that rings when the aether runs. A gauge, and a lure."""
    sp = Sprite()
    p = ramp("#8ac0b0", 7, 0.45)
    for y in range(10, 25):
        t = (y - 10) / 15.0
        w = int(2 + t * 7)
        for x in range(16 - w, 16 + w):
            sp.cv.px(x, y, p[int(np.clip(5 - abs(x - 13) * 0.25, 0, 6))])
    for x in range(8, 25):
        sp.cv.px(x, 25, p[1])
    for y in range(25, 30):
        sp.cv.px(16, y, p[3])
    sp.g(16, 21, hexc("#d8fff0"))
    contact_shadow(sp.cv, 12, 20, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def rust_spar():
    """A spar off something big, driven into the ground point-first."""
    sp = Sprite()
    rng = rng_for("rust_spar")
    p = ramp("#7a5a42", 7, 0.5)
    rust = ramp("#a8603a", 7, 0.4)
    lean = 0.22
    for k in range(26):
        x = int(18 - lean * k)
        y = 30 - k
        for w in range(4 - k // 12):
            sp.cv.px(x + w, y, (rust if rng.random() < 0.35 else p)[int(np.clip(4 - w, 0, 6))])
    # a torn plate still bolted to it
    for y in range(8, 16):
        for x in range(8, 15):
            if (x + y) % 7:
                sp.cv.px(x, y, p[int(np.clip(4 + (9 - x) * 0.2, 0, 6))])
    for _ in range(9):
        sp.cv.px(rng.randint(8, 20), rng.randint(9, 28), rust[5])
    contact_shadow(sp.cv, 10, 20, 30)
    sel_outline(sp.cv, 0.5)
    return sp


def hull_plate_heap():
    """Somebody stacked it. Somebody intended to come back for it."""
    sp = Sprite()
    rng = rng_for("hull_plate_heap")
    p = ramp("#77808e", 7, 0.5)
    rust = ramp("#8a5a3a", 7, 0.4)
    for k in range(6):
        y = 27 - k * 2
        x0 = 5 + rng.randint(0, 4)
        w = rng.randint(14, 22)
        for x in range(x0, min(30, x0 + w)):
            sp.cv.px(x, y, (rust if rng.random() < 0.25 else p)[5])
            sp.cv.px(x, y + 1, p[2])
    contact_shadow(sp.cv, 5, 28, 29)
    sel_outline(sp.cv, 0.5)
    return sp


def chalk_figure():
    """Cut into the turf down to the white, by people who wanted it seen from the air."""
    sp = Sprite()
    w = hexc("#f0ece0")
    # a person with too many arms
    for y in range(8, 20):
        sp.cv.px(16, y, w)
        sp.cv.px(17, y, w)
    for k in range(5):
        a = k / 4.0 * math.pi
        for r in range(2, 9):
            sp.cv.px(int(16 + math.cos(a + math.pi) * r), int(13 + math.sin(a + math.pi) * r * 0.7), w)
    for k in range(7):
        sp.cv.px(14 - k // 2, 20 + k, w)
        sp.cv.px(19 + k // 2, 20 + k, w)
    m = ellipse_mask(32, 32, 16, 6, 3, 3)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        sp.cv.px(xx, yy, w)
    # the turf it is cut out of, showing at the edges
    sel_outline(sp.cv, 0.35)
    return sp


def mirror_pool():
    """Still, and rather deeper than the island is thick."""
    sp = Sprite()
    m = ellipse_mask(32, 32, 16, 20, 13, 8)
    ys, xs = np.nonzero(m)
    for (yy, xx) in zip(ys, xs):
        d = math.hypot((xx - 16) / 13.0, (yy - 20) / 8.0)
        c = mix(hexc("#c8dcea"), hexc("#3a4a62"), d * 0.9)
        sp.cv.px(xx, yy, (c[0], c[1], c[2], 1.0))
    # the reflection, a half-second late
    for k in range(20):
        x = 8 + k
        sp.cv.px(x, 18 + int(math.sin(k * 0.4) * 1.5), (1, 1, 1, 0.5))
    sp.g(11, 16, hexc("#ffffff"))
    sel_outline(sp.cv, 0.4)
    return sp


def ember_spire():
    """Glass drawn up out of a vent and left standing, still warm at the base."""
    sp = Sprite()
    sp2 = _rockish("ember_spire", "#5a3428", 6, 11, 25, "#ff8a3a", spiky=True)
    sp.cv.a[:] = sp2.cv.a
    rng = rng_for("ember_spire2")
    for _ in range(11):
        sp.g(rng.randint(12, 20), rng.randint(22, 29), hexc("#ff7a2a"))
    return sp


def storm_spire():
    sp = Sprite()
    sp2 = _rockish("storm_spire", "#5a6070", 7, 11, 24, "#9ad8ff", spiky=True)
    sp.cv.a[:] = sp2.cv.a
    rng = rng_for("storm_spire2")
    for _ in range(9):
        sp.g(rng.randint(11, 21), rng.randint(6, 18), hexc("#b8d8ff"))
    return sp


def moss_bed():
    return _flat("moss_bed", "#4a7a52", 13, "#8ac878")


def pale_fungus():
    return _clump("pale_fungus", "#b8b0a8", 20, 18, 30, 11, 9, "#e8e0d8")


def fulgurite():
    sp = _rockish("fulgurite", "#c0b8d8", 6, 8, 26, "#9ad8ff", spiky=True)
    return sp


# ------------------------------------------------------------------ registration
def build_into(pk):
    # port furniture
    pk.add("port_lantern", port_lantern())
    pk.add("port_sign", port_sign())
    pk.add("yard_desk", yard_desk())
    pk.add("notice_board", notice_board())
    pk.add("star_dust", star_dust())
    # new flora
    pk.add("hearth_tree", hearth_tree())
    pk.add("moss_bed", moss_bed())
    pk.add("chalk_figure", chalk_figure())
    pk.add("reef_fan", reef_fan())
    pk.add("aether_polyp", aether_polyp())
    pk.add("tide_bell", tide_bell())
    pk.add("rust_spar", rust_spar())
    pk.add("hull_plate_heap", hull_plate_heap())
    pk.add("mirror_pool", mirror_pool())
    pk.add("ember_spire", ember_spire())
    pk.add("lightning_tree", lightning_tree())
    pk.add("storm_spire", storm_spire())
    pk.add("fulgurite", fulgurite())
    pk.add("gloom_stalk", gloom_stalk())
    pk.add("pale_fungus", pale_fungus())
    from sky_port import build_into as port_build
    port_build(pk)
