"""Sky-airship theming pass for props (Skies of Arcadia / Treasure Planet, not SS13).

Everything the station generations drew that reads as a space station -- lockers, vending
machines, consoles, hazard-striped airlocks, gas canisters, chrome tables -- is redrawn here
in the airship vocabulary: oak planking, riveted iron bands, brass and copper fittings,
canvas, rope, leather, glass lanterns, gauges, warm painted markings.

`apply(pk)` runs after objects_v2.apply and before props_fx.finish_objects. Names, canvas
sizes and glow layers are unchanged; only the pictures change.
"""
import math

import numpy as np

import objects_v2 as v2
from common import Canvas, hexc, mix, ramp, rng_for, shade
from px import shade_mask, sphere_height, cyl_height

REDRAWN = {}
NEW = {}

# ------------------------------------------------------------------ palette
OAK = "#8a5b33"
OAK_L = "#a87a46"
OAK_D = "#5b3a21"
PINE = "#b98f5a"
TIMBER = "#6f4a2b"
IRON = "#55505b"
IRON_D = "#38343d"
BRASS = "#cf9f3c"
COPPER = "#bd6a3c"
CANVAS = "#dccfa4"
LEATHER = "#76472b"
ROPE = "#b89b62"
LAMP = "#ffc46a"
PAINT = {
    "eng": "#c9922e", "med": "#3f8a6a", "sec": "#8a3038", "sci": "#5b4a9a", "cmd": "#2f4f8a",
    "srv": "#4a8a52", "cargo": "#a8703a", "generic": "#7a7f8c", "maint": "#7a6a52", "ext": "#b8452e",
    "gen": OAK, "emerg": "#c8452e", "fire": "#b8342a", "winter": "#4a7a8c", "food": "#8a6a2e",
}

H = v2.H
R, E, P = v2.R, v2.E, v2.P
ground, done, _sp, cabinet = v2.ground, v2.done, v2._sp, v2.cabinet


def obj(*names):
    def deco(fn):
        for n in names:
            REDRAWN[n] = fn
        return fn
    return deco


# ------------------------------------------------------------------ toolkit
def px(cv, x, y, c):
    cv.px(x, y, H(c) if isinstance(c, str) else c)


def wood(cv, x0, y0, x1, y1, col=OAK, vertical=True, plank=5, seed="w", r=0, bevel=1.3):
    """Planked timber: shaded slab, seam lines every `plank` px, grain streaks, nail dots."""
    rng = rng_for(seed)
    pal = shade_mask(cv, R(cv, x0, y0, x1, y1, r), col, "paint", bevel=bevel)
    dk, lt = pal[0], pal[-1]
    n = 0
    if vertical:
        for i, x in enumerate(range(x0 + plank, x1, plank)):
            cv.vline(x, y0 + 1, y1 - 1, shade(H(col), -0.42))
            cv.vline(x + 1, y0 + 1, y1 - 1, shade(H(col), 0.14))
        for x in range(x0 + 1, x1):
            if rng.random() < 0.5:
                y = rng.randint(y0 + 2, max(y0 + 2, y1 - 5))
                for k in range(rng.randint(2, 5)):
                    if y + k < y1:
                        c = cv.get(x, y + k)
                        if c[3] > 0.5:
                            cv.px(x, y + k, shade(c, -0.14))
    else:
        for y in range(y0 + plank, y1, plank):
            cv.hline(x0 + 1, x1 - 1, y, shade(H(col), -0.42))
            cv.hline(x0 + 1, x1 - 1, y + 1, shade(H(col), 0.14))
        for y in range(y0 + 1, y1):
            if rng.random() < 0.45:
                x = rng.randint(x0 + 2, max(x0 + 2, x1 - 6))
                for k in range(rng.randint(2, 6)):
                    if x + k < x1:
                        c = cv.get(x + k, y)
                        if c[3] > 0.5:
                            cv.px(x + k, y, shade(c, -0.14))
    return pal


def iron(cv, x0, y0, x1, y1, col=IRON, rivets=True, step=4):
    pal = shade_mask(cv, R(cv, x0, y0, x1, y1, 0), col, "metal", bevel=1.0)
    if rivets:
        horiz = (x1 - x0) >= (y1 - y0)
        ym = (y0 + y1) // 2
        xm = (x0 + x1) // 2
        rng_ = range(x0 + 2, x1 - 1, step) if horiz else range(y0 + 2, y1 - 1, step)
        for t in rng_:
            x, y = (t, ym) if horiz else (xm, t)
            cv.px(x, y, pal[-1])
            cv.px(x + 1, y + 1, pal[0])
    return pal


def brass(cv, x0, y0, x1, y1, r=0, col=BRASS):
    return shade_mask(cv, R(cv, x0, y0, x1, y1, r), col, "metal", bevel=1.0)


def rivet_line(cv, x0, x1, y, col=BRASS, step=3):
    for x in range(x0, x1 + 1, step):
        cv.px(x, y, mix(H(col), hexc("#ffffff"), 0.35))
        cv.px(x, y + 1, shade(H(col), -0.5))


def round_brass(cv, cx, cy, r, col=BRASS):
    m = E(cv, cx, cy, r, r)
    return shade_mask(cv, m, col, "metal", height=sphere_height(m))


def gauge(sp, cx, cy, r=3, ang=0.6, face="#efe3bd", glow=True, needle="#8a2a1e"):
    """Brass-rimmed dial with a needle; the face glows a little from the lamp behind it."""
    cv = sp.cv
    round_brass(cv, cx, cy, r + 1, BRASS)
    fm = E(cv, cx, cy, r - 0.2, r - 0.2)
    cv.a[fm] = H(face)
    if glow:
        for y, x in zip(*np.nonzero(fm)):
            sp.glow.px(int(x), int(y), hexc(face, 0.5))
        sp.has_glow = True
    ex = int(round(cx + math.cos(ang) * (r - 1)))
    ey = int(round(cy + math.sin(ang) * (r - 1)))
    cv.line(int(cx), int(cy), ex, ey, H(needle))
    for k in range(0, 6):
        a = -2.6 + k * 0.85
        tx, ty = int(round(cx + math.cos(a) * r)), int(round(cy + math.sin(a) * r))
        if fm[ty, tx]:
            cv.px(tx, ty, shade(H(face), -0.45))
    cv.px(int(cx), int(cy), H("#2a1e14"))


def lamp_glass(sp, x, y, w=2, h=3, col=LAMP):
    """A little lantern: brass caps, glowing glass."""
    cv = sp.cv
    cv.hline(x - 1, x + w, y - 1, H(BRASS))
    cv.hline(x - 1, x + w, y + h, shade(H(BRASS), -0.35))
    for dy in range(h):
        for dx in range(w):
            sp.g(x + dx, y + dy, mix(H(col), hexc("#fff4d0"), 0.35 if dx == 0 and dy == 0 else 0.0))
    cv.vline(x - 1, y, y + h - 1, shade(H(BRASS), -0.25))
    cv.vline(x + w, y, y + h - 1, shade(H(BRASS), -0.5))


def warm(sp, x, y, col=LAMP):
    sp.g(x, y, H(col))


def stencil(cv, x, y, rows, col, dark=True):
    """Tiny painted lettering: rows of '.#' patterns."""
    c = H(col)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.px(x + i, y + j, c)


def rope_line(cv, x0, y0, x1, y1, col=ROPE):
    dx, dy = x1 - x0, y1 - y0
    n = max(abs(dx), abs(dy), 1)
    for i in range(n + 1):
        x, y = x0 + dx * i / n, y0 + dy * i / n
        c = shade(H(col), 0.12) if i % 2 == 0 else shade(H(col), -0.3)
        cv.px(int(round(x)), int(round(y)), c)


def retone(cv, stops):
    """Luminance-preserving recolour: opaque pixel luminance picks a colour from `stops`
    (dark..light hex list). Keeps the drawing's shading and line work, changes its material."""
    a = cv.a
    al = a[..., 3] > 0.02
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    pal = np.array([H(s)[:3] for s in stops])
    lo, hi = np.percentile(lum[al], 2) if al.any() else 0, np.percentile(lum[al], 98) if al.any() else 1
    t = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1) * (len(stops) - 1)
    i0 = np.clip(np.floor(t).astype(int), 0, len(stops) - 2)
    f = (t - i0)[..., None]
    rgb = pal[i0] * (1 - f) + pal[i0 + 1] * f
    a[..., :3] = np.where(al[..., None], rgb, a[..., :3])
    return cv


# ================================================================== sea lockers
LOCK_COL = {"eng": "eng", "med": "med", "sec": "sec", "sci": "sci", "gen": "gen", "emerg": "emerg",
            "fire": "fire", "winter": "winter", "cmd": "cmd"}


def sea_locker(kind, open_=False):
    sp = _sp(32, 48)
    cv = sp.cv
    paint = PAINT[LOCK_COL[kind]]
    wcol = OAK if kind != "winter" else "#7a6a58"
    ground(cv, 4, 27, 45)
    # top face
    shade_mask(cv, R(cv, 4, 4, 27, 9, 0), shade(H(wcol), 0.16), "paint", bevel=1.0)
    cv.hline(5, 26, 4, mix(H(wcol), hexc("#ffffff"), 0.35))
    cv.hline(4, 27, 9, shade(H(wcol), -0.35))
    wood(cv, 4, 10, 27, 44, wcol, True, 6, "lk" + kind, bevel=1.2)
    # door frame
    fr = shade(H(wcol), -0.55)
    cv.rect(6, 12, 25, 12, fr)
    cv.rect(6, 42, 25, 42, fr)
    cv.vline(6, 12, 42, fr)
    cv.vline(25, 12, 42, fr)
    if open_:
        for y in range(13, 42):
            for x in range(7, 25):
                cv.px(x, y, H("#1d1510"))
        # shelves inside with a few stores
        for y in (21, 30, 38):
            cv.hline(7, 24, y, H("#7a5230"))
            cv.hline(7, 24, y + 1, H("#3a2616"))
        rng = rng_for("lo" + kind)
        for (x, y, c) in ((9, 16, "#cfc3a0"), (13, 17, paint), (18, 15, "#a8823e"), (10, 25, "#b8552e"), (16, 26, "#dccfa4"),
                          (20, 27, "#5a7a9a"), (9, 34, "#a8823e"), (15, 34, "#6a4a2a"), (20, 33, "#cfc3a0")):
            cv.rect(x, y, x + 2, y + 3 if y < 30 else y + 2, H(c))
            cv.px(x, y, shade(H(c), 0.3))
        # the door swung wide on the left, edge-on
        wood(cv, 1, 11, 5, 43, shade(H(wcol), -0.1), True, 9, "lkd" + kind, bevel=1.0)
        iron(cv, 1, 16, 5, 18)
        iron(cv, 1, 36, 5, 38)
        cv.px(2, 28, H(BRASS))
    else:
        # iron straps
        for (a, b) in ((15, 17), (36, 38)):
            iron(cv, 4, a, 27, b, IRON, True, 4)
            cv.px(4, a, cv.get(4, a) * 0)  # nick corners
        # painted panel with a mark
        pm = R(cv, 9, 20, 22, 32, 1)
        pp = shade_mask(cv, pm, paint, "paint", bevel=1.0)
        cv.rect(9, 20, 22, 32, pp[2]) if False else None
        cv.hline(10, 21, 20, pp[-1])
        cv.hline(10, 21, 32, pp[0])
        mk = H("#efe3bd")
        if kind == "med":
            cv.rect(14, 22, 17, 30, mk)
            cv.rect(11, 25, 20, 27, mk)
        elif kind == "emerg":
            for a in np.linspace(0, math.tau, 24, endpoint=False):
                cv.px(int(round(15.5 + math.cos(a) * 4.6)), int(round(26 + math.sin(a) * 4.4)), mk)
                cv.px(int(round(15.5 + math.cos(a) * 3.4)), int(round(26 + math.sin(a) * 3.3)), H("#efe3bd"))
            cv.px(15, 22, H("#b0301e"))
            cv.px(16, 30, H("#b0301e"))
        elif kind == "fire":
            cv.rect(12, 22, 19, 30, shade(H(paint), -0.3))
            cv.px(15, 24, mk); cv.px(16, 24, mk); cv.rect(14, 25, 17, 29, H("#f0a030"))
        elif kind == "eng":
            for i in range(5):
                cv.hline(11, 20, 22 + i * 2, mix(H(paint), hexc("#ffffff"), 0.35 if i % 2 == 0 else 0.0))
            cv.vline(15, 22, 30, mk)
            cv.vline(16, 22, 30, mk)
        elif kind == "sec":
            cv.rect(13, 22, 18, 24, mk); cv.rect(14, 25, 17, 28, mk); cv.px(15, 29, mk); cv.px(16, 29, mk)
        elif kind == "sci":
            cv.rect(14, 22, 17, 24, mk); cv.rect(12, 25, 19, 30, mk); cv.rect(13, 26, 18, 29, shade(H(paint), 0.1))
        elif kind == "cmd":
            cv.px(15, 22, H(BRASS)); cv.px(16, 22, H(BRASS))
            cv.rect(13, 24, 18, 28, H(BRASS)); cv.px(15, 29, H(BRASS)); cv.px(16, 29, H(BRASS))
        elif kind == "winter":
            for i in range(4):
                cv.hline(11, 20, 22 + i * 2, mk)
        else:
            cv.hline(11, 20, 26, mk)
        # brass hasp and lock
        brass(cv, 21, 33, 25, 38, 0)
        cv.px(23, 35, H("#1d1510"))
        cv.px(23, 36, H("#1d1510"))
        # hinges
        for y in (14, 39):
            cv.rect(5, y, 7, y + 1, H(BRASS))
        warm(sp, 14, 34)
    return done(sp)


for _k in LOCK_COL:
    REDRAWN[f"locker_{_k}"] = (lambda k: (lambda: sea_locker(k)))(_k)
    REDRAWN[f"locker_{_k}_open"] = (lambda k: (lambda: sea_locker(k, True)))(_k)


# ================================================================== crates
CRATE = {"gen": ("gen", OAK), "eng": ("eng", "#7a5a38"), "food": ("food", "#9a7a44"), "med": ("med", "#a88a5a"),
         "sci": ("sci", "#6a4a2e"), "sec": ("sec", "#5a3a24")}


def crate(kind, open_=False):
    paint, wcol = CRATE[kind]
    sp = _sp()
    cv = sp.cv
    ground(cv, 3, 28, 30)
    # top face (planks seen from above) then front
    top = shade(H(wcol), 0.22)
    wood(cv, 3, 6, 28, 12, top, False, 3, "ct" + kind, bevel=1.0)
    wood(cv, 3, 13, 28, 29, wcol, False, 5, "cf" + kind, bevel=1.2)
    cv.hline(3, 28, 13, shade(H(wcol), -0.5))
    if open_:
        # lid propped up behind, straw and goods showing
        for x in range(5, 27):
            for y in range(7, 12):
                cv.px(x, y, H("#3a2616"))
        rng = rng_for("cs" + kind)
        for x in range(5, 27):
            for y in range(8, 12):
                if rng.random() < 0.55:
                    cv.px(x, y, H("#d8b866") if rng.random() < 0.6 else H("#b8923e"))
        cv.rect(9, 6, 12, 10, H(PAINT[paint])); cv.rect(17, 5, 20, 9, H("#cfc3a0"))
        wood(cv, 4, 1, 27, 4, shade(H(wcol), 0.05), False, 3, "cl" + kind, bevel=1.0)
        cv.hline(4, 27, 5, shade(H(wcol), -0.55))
    # corner irons and centre band
    for x0 in (3, 25):
        iron(cv, x0, 14, x0 + 3, 29, IRON, False)
        cv.px(x0 + 1, 16, H(BRASS)); cv.px(x0 + 1, 26, H(BRASS))
    # rope handles / stencil
    pc = H(PAINT[paint])
    cv.rect(9, 18, 22, 24, pc)
    cv.hline(9, 22, 18, shade(pc, 0.25)); cv.hline(9, 22, 24, shade(pc, -0.4))
    mk = H("#efe3bd")
    if kind == "med":
        cv.rect(15, 19, 16, 23, mk); cv.rect(13, 20, 18, 22, mk)
    elif kind == "food":
        cv.rect(12, 20, 19, 22, mk); cv.px(13, 19, mk); cv.px(18, 19, mk)
    elif kind == "sec":
        cv.rect(13, 20, 18, 22, mk); cv.px(15, 19, mk); cv.px(16, 23, mk)
    elif kind == "eng":
        for x in range(11, 21, 2):
            cv.vline(x, 19, 23, mk)
    elif kind == "sci":
        cv.rect(13, 19, 18, 20, mk); cv.rect(12, 21, 19, 23, mk)
    else:
        cv.hline(11, 20, 21, mk)
    rope_line(cv, 6, 27, 25, 27, ROPE)
    warm(sp, 16, 28) if False else None
    return done(sp)


for _k in CRATE:
    REDRAWN[f"crate_{_k}"] = (lambda k: (lambda: crate(k)))(_k)
    REDRAWN[f"crate_{_k}_open"] = (lambda k: (lambda: crate(k, True)))(_k)


# ================================================================== bulkhead doors
def _door_paint(dept):
    return PAINT.get(dept, PAINT["generic"])


def bulkhead(dept, frame, glass=True):
    """frame 0 closed .. 3 open. Oak-plank leaves with iron strap hinges and a brass-ringed
    porthole, an oak lintel carrying a signal lantern (red shut, amber moving, green open)."""
    sp = _sp()
    cv = sp.cv
    paint = _door_paint(dept)
    post = IRON if dept in ("ext", "maint", "sec", "eng") else "#6a4526"
    # posts and lintel
    wood(cv, 0, 0, 31, 6, "#6a4526", False, 3, "lin" + dept, bevel=1.2)
    iron(cv, 0, 5, 31, 6, IRON_D, True, 5)
    for x0, x1 in ((0, 2), (29, 31)):
        shade_mask(cv, R(cv, x0, 7, x1, 31, 0), post, "paint" if post != IRON else "metal", bevel=1.0)
        for y in range(9, 30, 5):
            cv.px(x0 + 1, y, H(BRASS))
    open_ = frame >= 3
    col = "#ff4a3a" if frame == 0 else ("#ffbe4a" if not open_ else "#6aff8a")
    lamp_glass(sp, 15, 1, 2, 3, col)
    slide = [0, 5, 10, 13][frame]
    wcol = "#8a5b33" if dept not in ("ext", "maint") else "#6e5a44"
    for leaf in (0, 1):
        lx0, lx1 = (3, 15 - slide) if leaf == 0 else (16 + slide, 28)
        if lx1 < lx0:
            continue
        pal = wood(cv, lx0, 7, lx1, 30, wcol, True, 5, "dl%s%d" % (dept, leaf), bevel=1.2)
        # painted band, warm and hand-lettered rather than hazard striped
        if dept not in ("generic", "cmd"):
            for y, k in ((21, 0.25), (22, 0.0), (23, -0.3)):
                for x in range(lx0, lx1 + 1):
                    cv.px(x, y, shade(H(paint), k))
        if dept == "cmd":
            for x in range(lx0, lx1 + 1):
                cv.px(x, 21, H(BRASS)); cv.px(x, 22, shade(H(BRASS), -0.3))
        # iron straps
        for y in (9, 26):
            iron(cv, lx0, y, lx1, y + 1, IRON, True, 5)
        # porthole
        if glass:
            cx = (lx0 + lx1) // 2 + (1 if leaf == 0 else -1) * 0
            if lx1 - lx0 >= 6:
                pm = E(cv, cx + 0.5, 14.5, 3.5, 3.5)
                ring = E(cv, cx + 0.5, 14.5, 4.5, 4.5)
                cv.a[ring] = H("#7a5a24")
                cv.a[pm] = H("#1d3244")
                sp.glow.a[pm] = [0.5, 0.75, 0.9, 0.18]
                cv.px(cx - 1, 13, H("#9ac8e0")); cv.px(cx, 12, H("#c8e8f4"))
                cv.hline(cx - 2, cx + 3, 18, shade(H("#cf9f3c"), -0.3))
                cv.px(cx + 3, 12, H(BRASS)); cv.px(cx - 2, 17, H(BRASS))
        seam = lx1 if leaf == 0 else lx0
        cv.vline(seam, 7, 30, shade(H(wcol), -0.65))
        if dept == "ext":
            for y in range(27, 30):
                for x in range(lx0, lx1 + 1):
                    cv.px(x, y, mix(cv.get(x, y), hexc("#2c2a33"), 0.55))
    if frame == 3:
        for x in range(3, 29):
            cv.px(x, 30, H("#2a1e14"))
    cv.hline(0, 31, 31, H("#1d1712"))
    return sp


def _register_doors():
    for dept in ("generic", "eng", "med", "sec", "sci", "cmd", "maint", "ext", "srv", "cargo"):
        g = dept not in ("maint", "ext", "sec")
        for f in range(4):
            REDRAWN[f"airlock_{dept}_{f}"] = (lambda d, fr, gl: (lambda: bulkhead(d, fr, gl)))(dept, f, g)


_register_doors()


def shutter(frame, lights=""):
    """Iron-slat storm shutter that drops from the lintel (frame 0 open .. 3 shut)."""
    sp = _sp()
    cv = sp.cv
    rail = ramp("#6a5a3a", 5, 0.4)
    for x in (1, 2, 29, 30):
        cv.px(x, 30, rail[3 if x in (1, 29) else 1])
        cv.px(x, 29, rail[2])
    if frame == 0:
        for x in range(3, 29):
            cv.px(x, 6, H(IRON) if (x // 2) % 2 else H("#7a6438"))
        return sp
    bottom = [6, 14, 22, 30][frame]
    for y in range(1, bottom + 1):
        pal = ramp("#4e4a54", 5, 0.4)
        for x in range(2, 30):
            i = 3 if y % 3 else (1 if y % 6 == 0 else 0)
            if y % 3 == 1:
                i = 4
            if x in (2, 29):
                i = max(0, i - 2)
            cv.px(x, y, pal[i])
    for x in range(4, 29, 6):
        for y in range(3, bottom, 5):
            cv.px(x, y, H(BRASS))
    for y in range(max(1, bottom - 2), bottom + 1):
        for x in range(2, 30):
            cv.px(x, y, shade(H("#7a5a30"), -0.1 * (y - bottom + 3)))
    cv.hline(2, 29, bottom, H("#1a1410"))
    cv.vline(1, 0, bottom, H("#1a1410"))
    cv.vline(30, 0, bottom, H("#1a1410"))
    if lights:
        col = "#ff5a3a" if lights == "hot" else "#7ac8ff"
        for x in (6, 7, 24, 25):
            sp.g(x, 3, H(col)); sp.g(x, 4, H(col))
    return sp


for _f in range(4):
    REDRAWN[f"firelock_{_f}"] = (lambda f: (lambda: shutter(f)))(_f)
REDRAWN["firelock_3_cold"] = lambda: shutter(3, "cold")
REDRAWN["firelock_3_hot"] = lambda: shutter(3, "hot")


# ================================================================== deck markings (no hazard tape)
def _paint_edge():
    from common import Canvas
    cv = Canvas()
    for x in range(32):
        on = (x // 4) % 2 == 0
        c = hexc("#d8b070", 0.92) if on else hexc("#a8663a", 0.85)
        cv.px(x, 1, c)
        cv.px(x, 2, shade(c, -0.25) if on else hexc("#7a4626", 0.7))
    cv.hline(0, 31, 3, hexc("#000000", 0.18))
    return cv


def _paint_stripe():
    from common import Canvas
    cv = Canvas()
    for y in (1, 2, 29, 30):
        for x in range(32):
            if (x // 5) % 3 != 2:
                cv.px(x, y, hexc("#d8b070", 0.85) if y in (1, 29) else hexc("#a8663a", 0.85))
    return cv


def _paint_hatch():
    from common import Canvas
    cv = Canvas()
    for y in range(32):
        for x in range(32):
            if (x + y) % 8 < 2:
                cv.px(x, y, hexc("#d8b070", 0.10))
    return cv


REDRAWN["hazard_stripe"] = _paint_stripe
REDRAWN["hazard_hatch"] = _paint_hatch


def _hz(side):
    from objects import rotated
    return lambda: rotated(_paint_edge(), side)


for _s in "nesw":
    REDRAWN[f"hazard_{_s}"] = _hz(_s)


# ================================================================== pressure kegs (was gas canisters)
KEG_BODY = {}


def keg(kind):
    body_c, band_c, text_c = v2.CANISTER[kind]
    sp = _sp(32, 40)
    cv = sp.cv
    x0, x1 = 8, 23
    ground(cv, x0, x1, 37)
    body = R(cv, x0, 12, x1, 35, 0)
    # painted iron drum: colour reads from a distance (the gas), rivets and hoops read up close
    bc = mix(H(body_c), hexc("#8a6a44"), 0.18)
    pal = v2.cyl_cols(cv, body, bc)
    for (a, b) in ((16, 17), (31, 32)):
        v2.cyl_cols(cv, body & R(cv, 0, a, 31, b), H(IRON), spec=False)
    for y in (16, 31):
        for x in range(x0 + 1, x1, 3):
            cv.px(x, y, mix(H(BRASS), hexc("#ffffff"), 0.3))
    # painted band and stencil
    v2.cyl_cols(cv, body & R(cv, 0, 21, 31, 23), H(band_c), spec=False)
    tc = H(text_c)
    for y, (a, b) in ((26, (11, 19)), (28, (11, 17))):
        for x in range(a, b + 1):
            if (x + y) % 3:
                cv.px(x, y, mix(tc, cv.get(x, y), 0.15 if x < 16 else 0.4))
    # foot ring
    v2.cyl_cols(cv, R(cv, x0, 34, x1, 36, 0), H(IRON_D), spec=False)
    cv.hline(x0, x1, 33, pal[0])
    # domed brass crown
    cap = E(cv, 15.5, 12.0, 8.0, 3.4)
    cp = ramp(H(BRASS), 5, 0.5)
    cv.a[cap] = cp[3]
    cv.a[cap & ~E(cv, 16.5, 12.8, 7.4, 3.0)] = cp[4]
    cv.a[cap & ~E(cv, 15.5, 11.4, 8.0, 3.4)] = cp[2]
    for k in range(3):
        cv.px(10 + k * 3, 11, cp[4]) if k == 0 else None
    # valve wheel on a brass stem, and a dial
    brass(cv, 14, 6, 17, 10, 0)
    cv.hline(11, 20, 5, H(COPPER)); cv.hline(11, 20, 4, shade(H(COPPER), 0.3))
    cv.px(11, 5, shade(H(COPPER), -0.3)); cv.px(20, 5, shade(H(COPPER), -0.4))
    cv.vline(15, 3, 4, shade(H(BRASS), -0.2))
    gauge(sp, 21, 8, 2, 0.5, glow=True)
    # spigot on the flank
    brass(cv, 24, 25, 26, 27, 0)
    cv.px(26, 28, H("#3a2616"))
    rng = rng_for("keg" + kind)
    for _ in range(5):
        x, y = rng.randint(10, 21), rng.randint(24, 32)
        cv.px(x, y, shade(cv.get(x, y), -0.12))
    warm(sp, 12, 14, "#ffc46a") if kind != "empty" else None
    return done(sp)


for _k in v2.CANISTER:
    REDRAWN["canister_" + _k] = (lambda k: (lambda: keg(k)))(_k)


# ================================================================== the rest is loaded in parts
import theme_props  # noqa: E402,F401  (registers more redraws into REDRAWN)
import theme_mach  # noqa: E402,F401
EXTRA = []


def apply(pk):
    names = {n for n, _ in pk.items}
    for name, fn in REDRAWN.items():
        if name in names:
            pk.replace(name, fn())
    for name, fn in NEW.items():
        if name not in names:
            pk.add(name, fn())
    theme_props.apply(pk)
    for mod in EXTRA:
        mod.apply(pk)
    # Keep the glow atlas entries used by older manifests and cached art. These kegs
    # have no emissive paint in the new palette, so their glow layers are transparent.
    present = dict(pk.items)
    for kind in ("o2", "n2", "air", "plasma", "co2", "empty", "n2o", "h2o"):
        name = "canister_" + kind
        if name in present and name + "_glow" not in present:
            cv = present[name]
            pk.items.append((name + "_glow", Canvas(cv.w, cv.h)))
