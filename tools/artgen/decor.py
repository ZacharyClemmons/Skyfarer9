"""Station dressing: department wall signs, posters, filing cabinets, water coolers, desk
computers and lamps, a coffee machine, rugs and floor grime. The things that make a
tg map look lived in. Packed into objects.png by objects.build()."""
import math

import numpy as np

from common import Canvas, ellipse_mask, hexc, mix, ramp, rng_for, rrect_mask, sel_outline, shade, shaded_fill

DEPT = {"med": "#4ab8d8", "sec": "#d84a4a", "eng": "#e8a83a", "sci": "#b87ae8", "cmd": "#4a8ad8",
        "srv": "#5ac87a", "cargo": "#c8883a", "bar": "#d86a3a", "danger": "#e8c83a", "atmos": "#5ad0ff"}


def _plaque(sp, col, x0=6, y0=8, x1=25, y1=19):
    cv = sp.cv
    body = rrect_mask(32, 32, x0, y0, x1, y1, 1)
    shaded_fill(cv, body, "#1e2430", 0.3)
    c = hexc(col)
    for x in range(x0, x1 + 1):
        cv.px(x, y0, c)
        cv.px(x, y1, shade(c, -0.35))
    for y in range(y0, y1 + 1):
        cv.px(x0, y, c)
        cv.px(x1, y, shade(c, -0.2))
    for x in range(x0 + 1, x1):
        cv.px(x, y1 + 1, (0.0, 0.0, 0.05, 0.35))
    return cv


def sign(kind):
    """A department sign for the wall beside a door, with a lit pictogram."""
    from objects import Sprite
    sp = Sprite()
    col = DEPT[kind]
    cv = _plaque(sp, col)
    c = hexc(col)
    lit = mix(c, hexc("#ffffff"), 0.35)
    cx, cy = 15, 13
    if kind == "med":  # a cross
        for d in range(-3, 4):
            sp.g(cx + d, cy, lit)
            sp.g(cx, cy + d, lit)
            sp.g(cx + d, cy + 1, lit)
            sp.g(cx + 1, cy + d, lit)
    elif kind == "sec":  # a shield
        for y in range(-3, 5):
            w = 3 if y < 2 else 3 - (y - 1)
            for x in range(-w, w + 2):
                sp.g(cx + x, cy + y, lit if abs(x - 0.5) < w - 0.5 else c)
    elif kind in ("eng", "atmos"):  # a cog
        for a in range(0, 360, 15):
            r = 4.2 if (a // 45) % 2 == 0 else 3.2
            sp.g(int(round(cx + 0.5 + math.cos(math.radians(a)) * r)), int(round(cy + 0.5 + math.sin(math.radians(a)) * r)), lit)
        sp.g(cx, cy, lit)
        sp.g(cx + 1, cy + 1, lit)
    elif kind == "sci":  # a flask
        for y in range(-4, 5):
            w = 1 if y < 0 else 1 + (y + 1) // 2
            for x in range(-w, w + 1):
                sp.g(cx + x, cy + y, lit if y > 1 else c)
    elif kind == "cmd":  # a star
        for a in range(0, 360, 72):
            for k in range(5):
                sp.g(int(round(cx + math.cos(math.radians(a - 90)) * k)), int(round(cy + math.sin(math.radians(a - 90)) * k)), lit)
    elif kind == "srv":  # fork and spoon
        for y in range(-4, 5):
            sp.g(cx - 2, cy + y, lit)
            sp.g(cx + 2, cy + y, lit)
        sp.g(cx - 3, cy - 4, lit)
        sp.g(cx - 1, cy - 4, lit)
        sp.g(cx + 1, cy - 4, lit)
        sp.g(cx + 3, cy - 4, lit)
    elif kind == "cargo":  # a crate
        for y in range(-3, 4):
            for x in range(-4, 5):
                edge = abs(y) == 3 or abs(x) == 4 or x == y
                if edge:
                    sp.g(cx + x, cy + y, lit)
    elif kind == "bar":  # a cocktail glass
        for y in range(-4, 1):
            w = 4 + y
            for x in range(-w, w + 1):
                sp.g(cx + x, cy + y, lit if y == -4 or abs(x) == w else c)
        for y in range(1, 4):
            sp.g(cx, cy + y, lit)
        for x in range(-2, 3):
            sp.g(cx + x, cy + 4, lit)
    elif kind == "danger":  # a warning triangle
        for y in range(-4, 5):
            w = (y + 4) // 2
            for x in range(-w, w + 1):
                sp.g(cx + x, cy + y, c)
        for y in range(-2, 2):
            cv.px(cx, cy + y, hexc("#1d1b22"))
        cv.px(cx, cy + 3, hexc("#1d1b22"))
    return sp


def poster(v):
    """A framed poster: a few bold shapes, like tg's propaganda and safety posters."""
    from objects import Sprite
    sp = Sprite()
    cv = sp.cv
    rng = rng_for(f"poster{v}")
    pal = [["#d84a4a", "#e8e0c8", "#2a2a38"], ["#4a8ad8", "#e8e8e8", "#1a2a4a"], ["#e8c83a", "#2a2a2a", "#d86a3a"],
           ["#5ac87a", "#e8f0e8", "#2a4a3a"], ["#b87ae8", "#f0e0f8", "#3a2a5a"], ["#e8883a", "#f8f0e0", "#4a2a1a"]][v % 6]
    body = rrect_mask(32, 32, 9, 3, 22, 22, 0)
    cv.mask_fill(body, hexc(pal[1]))
    kind = v % 3
    if kind == 0:  # a big circle over a band
        m = ellipse_mask(32, 32, 15.5, 10, 4.5, 4.5)
        cv.mask_fill(m, hexc(pal[0]))
        for y in (17, 18):
            cv.hline(10, 21, y, hexc(pal[2]))
    elif kind == 1:  # diagonal stripes
        for y in range(4, 22):
            for x in range(10, 22):
                if (x + y) % 6 < 2:
                    cv.px(x, y, hexc(pal[0]))
        cv.rect(11, 15, 20, 19, hexc(pal[2]))
    else:  # a figure pointing
        cv.rect(14, 7, 17, 10, hexc(pal[2]))
        cv.rect(13, 11, 18, 17, hexc(pal[0]))
        cv.hline(18, 21, 12, hexc(pal[0]))
        for x in range(11, 21, 2):
            cv.px(x, 20, hexc(pal[2]))
    for x in range(9, 23):
        cv.px(x, 3, hexc("#b0b8c4"))
        cv.px(x, 22, hexc("#6a7486"))
        cv.px(x, 23, (0.0, 0.0, 0.05, 0.35))
    for y in range(3, 23):
        cv.px(9, y, hexc("#9aa3b3"))
        cv.px(22, y, hexc("#6a7486"))
    return sp


def filing_cabinet():
    from objects import Sprite, box3d, contact_shadow
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 8, 23, 38)
    box3d(cv, 8, 10, 23, 37, 3, "#7a8494", 0.35)
    for y in (16, 23, 30):
        cv.hline(10, 21, y, hexc("#4a5262"))
        cv.hline(14, 17, y + 3, hexc("#c8d0d8"))
    return sp


def water_cooler():
    from objects import Sprite, box3d, contact_shadow
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 10, 21, 38)
    box3d(cv, 10, 22, 21, 37, 2, "#d8dee6", 0.3)
    jug = rrect_mask(32, 40, 11, 8, 20, 21, 3)
    shaded_fill(cv, jug, "#5ab8e8", 0.45)
    for y in range(10, 20):
        cv.px(13, y, hexc("#b8e8ff", 0.8))
    cv.px(12, 27, hexc("#d84a4a"))
    cv.px(19, 27, hexc("#4a8ad8"))
    return sp


def desk_computer():
    """A monitor and keyboard sitting on a table."""
    from objects import Sprite, screen
    sp = Sprite()
    cv = sp.cv
    rng = rng_for("deskpc")
    for y in range(4, 15):
        for x in range(9, 23):
            cv.px(x, y, hexc("#3a4250"))
    screen(sp, 10, 5, 21, 13, "#5ad0ff", rng, "text")
    cv.rect(15, 15, 16, 16, hexc("#3a4250"))
    cv.hline(12, 19, 17, hexc("#5a6272"))
    for x in range(10, 22, 2):
        cv.px(x, 19, hexc("#9aa3b3"))
    sel_outline(cv, 0.5)
    return sp


def desk_lamp():
    from objects import Sprite
    sp = Sprite()
    cv = sp.cv
    base = ramp("#3a4a3a", 3, 0.4)
    cv.hline(13, 18, 19, base[1])
    cv.hline(14, 17, 18, base[2])
    for y in range(11, 18):
        cv.px(15 + (1 if y < 14 else 0), y, base[2])
    shade_m = rrect_mask(32, 32, 14, 7, 21, 11, 1)
    shaded_fill(cv, shade_m, "#3a8a4a", 0.4)
    for x in range(15, 21):
        sp.g(x, 12, hexc("#fff0b0"))
    sel_outline(cv, 0.5)
    return sp


def coffee_machine():
    from objects import Sprite, box3d, contact_shadow
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 8, 23, 38)
    box3d(cv, 8, 10, 23, 37, 3, "#2a2a30", 0.35)
    cv.rect(11, 16, 20, 25, hexc("#141418"))
    cv.rect(14, 22, 17, 25, hexc("#e8e0c8"))
    cv.rect(15, 23, 16, 24, hexc("#6a3a1a"))
    sp.g(20, 13, hexc("#ff4a3a"))
    sp.g(18, 13, hexc("#5aff7a"))
    for x in range(11, 21):
        cv.px(x, 29, hexc("#5a5a62"))
    return sp


def rug_fill(col):
    cv = Canvas()
    base = hexc(col)
    rng = rng_for("rug" + col)
    for y in range(32):
        for x in range(32):
            k = ((x // 4) + (y // 4)) % 2
            c = shade(base, -0.12 if k else 0.04)
            if (x + y) % 8 == 0:
                c = shade(base, 0.18)
            cv.px(x, y, np.append(c[:3], 0.9))
    return cv


def rug_edge(col):
    """Fringed border along the top edge of a rug tile (rotated for the other sides)."""
    cv = Canvas()
    b = hexc(col)
    for x in range(32):
        cv.px(x, 0, np.append(shade(b, 0.35)[:3], 0.9))
        cv.px(x, 1, np.append(shade(b, -0.45)[:3], 0.95))
        cv.px(x, 2, np.append(mix(b, hexc("#e8d8a0"), 0.6)[:3], 0.95))
        cv.px(x, 3, np.append(shade(b, -0.45)[:3], 0.95))
    return cv


def grime(v):
    """Dirt and scuffs for maintenance and well-trodden floors."""
    cv = Canvas()
    rng = rng_for(f"grime{v}")
    for k in range(3 + v):
        cx, cy = rng.uniform(4, 28), rng.uniform(4, 28)
        r = rng.uniform(2.0, 5.5)
        for y in range(32):
            for x in range(32):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                if d < 1.0 and rng.random() < 0.8 - d * 0.5:
                    a = (1.0 - d) * rng.uniform(0.12, 0.3)
                    cv.blend_px(x, y, np.array([0.1, 0.08, 0.06, a]))
    for k in range(6):
        x, y = rng.randint(1, 30), rng.randint(1, 30)
        cv.blend_px(x, y, np.array([0.05, 0.04, 0.03, 0.35]))
    return cv


def add_all(pk):
    from objects import rotated
    for k in DEPT:
        pk.add("sign_" + k, sign(k))
    for v in range(6):
        pk.add(f"poster_{v}", poster(v))
    pk.add("filing_cabinet", filing_cabinet())
    pk.add("water_cooler", water_cooler())
    pk.add("desk_computer", desk_computer())
    pk.add("desk_lamp", desk_lamp())
    pk.add("coffee_machine", coffee_machine())
    for name, col in (("red", "#8a2a33"), ("blue", "#2a4a8a"), ("green", "#2a6a4a"), ("brown", "#6a4a2a")):
        pk.add(f"rug_{name}", rug_fill(col))
        for side in "nesw":
            pk.add(f"rug_{name}_{side}", rotated(rug_edge(col), side))
    for v in range(4):
        pk.add(f"grime_{v}", grime(v))
