"""Structures and machines: doors, machines, furniture, pipes, cables, exterior props, decals.

Every sprite is anchored bottom-centre on its tile. Sprites with emissive parts get a
companion `<name>_glow` sprite holding only the light-emitting pixels; the engine draws
those additively in HDR so they bloom.
"""
import math

import numpy as np

from common import (T, Canvas, ellipse_mask, fbm, hexc, mix, ramp, rng_for,
                    rrect_mask, sel_outline, shade, shaded_fill, value_noise)

N, E, S, W = 1, 2, 4, 8
OUTLINE = hexc("#16141d")

DEPT = {
    "generic": ("#8a93a3", "#5f6878"),
    "eng": ("#d8a53a", "#8a93a3"),
    "med": ("#e8eef4", "#4aa3d8"),
    "sec": ("#b8333d", "#5f6878"),
    "sci": ("#8a5ac8", "#e8eef4"),
    "cmd": ("#3a6ad8", "#d8b84a"),
    "maint": ("#7a6a52", "#d8a53a"),
    "ext": ("#c84a3a", "#e8e0d0"),
    "srv": ("#4a9a6a", "#e8eef4"),
    "cargo": ("#b8823a", "#5f6878"),
}


class Sprite:
    def __init__(self, w=T, h=T):
        self.cv = Canvas(w, h)
        self.glow = Canvas(w, h)
        self.has_glow = False

    def g(self, x, y, c):
        """paint an emissive pixel (also into the glow layer)"""
        self.cv.px(x, y, c)
        self.glow.px(x, y, c)
        self.has_glow = True


# ------------------------------------------------------------------ primitives
def box3d(cv, x0, y0, x1, y1, top_h, color, spread=0.4, outline=True, face_grad=True):
    """Chunky 3/4 view box: lighter top face, shaded front face."""
    p = ramp(color, 7, spread)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if y < y0 + top_h:
                i = 4
                if y == y0:
                    i = 5
            else:
                t = (y - (y0 + top_h)) / max(1, (y1 - (y0 + top_h)))
                i = 3 - int(t * 1.8) if face_grad else 3
            if x == x0:
                i = min(6, i + 1)
            if x == x1:
                i = max(0, i - 1)
            cv.px(x, y, p[i])
    # lip between top and face
    cv.hline(x0, x1, y0 + top_h, p[6])
    cv.hline(x0, x1, y0 + top_h + 1, p[2])
    cv.hline(x0 + 1, x1 - 1, y1, p[1])
    if outline:
        for x in range(x0, x1 + 1):
            cv.px(x, y0 - 1, OUTLINE)
            cv.px(x, y1 + 1, OUTLINE)
        for y in range(y0, y1 + 1):
            cv.px(x0 - 1, y, OUTLINE)
            cv.px(x1 + 1, y, OUTLINE)
    return p


def contact_shadow(cv, x0, x1, y, a=0.35):
    for x in range(x0, x1 + 1):
        cv.px(x, y, (0.05, 0.05, 0.12, a))
    for x in range(x0 + 1, x1):
        cv.px(x, y + 1, (0.05, 0.05, 0.12, a * 0.5))


def screen(sp, x0, y0, x1, y1, color, rng, style="text"):
    bg = hexc("#0b1a22")
    col = hexc(color)
    dim = mix(bg, col, 0.35)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            sp.cv.px(x, y, bg)
            sp.glow.px(x, y, mix(bg, col, 0.15))
    sp.has_glow = True
    if style == "text":
        for y in range(y0 + 1, y1, 2):
            ln = rng.randint(1, x1 - x0 - 1)
            for x in range(x0 + 1, x0 + 1 + ln):
                sp.g(x, y, col if rng.random() < 0.7 else dim)
    elif style == "graph":
        yy = (y0 + y1) // 2
        for x in range(x0 + 1, x1):
            yy = max(y0 + 1, min(y1 - 1, yy + rng.choice([-1, 0, 0, 1])))
            sp.g(x, yy, col)
    elif style == "bars":
        for x in range(x0 + 1, x1, 2):
            h = rng.randint(1, y1 - y0 - 1)
            for y in range(y1 - h, y1):
                sp.g(x, y, col)
    elif style == "map":
        for y in range(y0 + 1, y1):
            for x in range(x0 + 1, x1):
                if rng.random() < 0.35:
                    sp.g(x, y, dim)
        sp.g(rng.randint(x0 + 1, x1 - 1), rng.randint(y0 + 1, y1 - 1), hexc("#ff5050"))
    # glass glare
    sp.cv.px(x0, y0, mix(col, hexc("#ffffff"), 0.6))


def lamp(sp, x, y, color):
    sp.g(x, y, hexc(color))


# ------------------------------------------------------------------ doors
def airlock(dept, frame, glass=True):
    """frame 0 = closed ... 3 = fully open. 32x32."""
    main, stripe = DEPT[dept]
    sp = Sprite()
    cv = sp.cv
    fp = ramp("#4a5060", 7, 0.4)
    # frame (like a short wall): lintel on top, posts on sides
    for y in range(0, 32):
        for x in range(0, 32):
            if y < 7 or x < 3 or x > 28:
                i = 4 if y < 5 else 2
                if x < 3 or x > 28:
                    i = 3 if x in (1, 30) else 2
                cv.px(x, y, fp[i])
    cv.hline(0, 31, 0, fp[6])
    cv.hline(0, 31, 6, fp[0])
    cv.vline(0, 0, 31, fp[1])
    cv.vline(31, 0, 31, fp[0])
    # status light on lintel
    open_ = frame >= 3
    lamp(sp, 15, 3, "#ff4a3a" if frame == 0 else ("#ffd84a" if not open_ else "#5aff7a"))
    lamp(sp, 16, 3, "#ff4a3a" if frame == 0 else ("#ffd84a" if not open_ else "#5aff7a"))
    # door leaves slide into posts
    slide = [0, 5, 10, 13][frame]
    dp = ramp(main, 7, 0.38)
    sp_ = ramp(stripe, 5, 0.3)
    gl = [hexc(h) for h in ("#1c3048", "#2e5478", "#7ab8e0")]
    for leaf in (0, 1):
        if leaf == 0:
            lx0, lx1 = 3, 15 - slide
        else:
            lx0, lx1 = 16 + slide, 28
        if lx1 < lx0:
            continue
        for y in range(7, 31):
            for x in range(lx0, lx1 + 1):
                t = (y - 7) / 24
                i = 4 - int(t * 2.2)
                if x == lx0:
                    i += 1
                if x == lx1:
                    i -= 1
                cv.px(x, y, dp[max(0, min(6, i))])
            # stripe band
        for x in range(lx0, lx1 + 1):
            cv.px(x, 21, sp_[3])
            cv.px(x, 22, sp_[2])
            cv.px(x, 23, sp_[1])
        # window
        if glass:
            wx0 = lx0 + 3 if leaf == 0 else lx0 + 2
            wx1 = lx1 - 2 if leaf == 0 else lx1 - 3
            if wx1 > wx0:
                for y in range(10, 17):
                    for x in range(wx0, wx1 + 1):
                        cv.px(x, y, gl[1] if (x + y) % 5 else gl[2])
                cv.hline(wx0, wx1, 10, gl[0])
        # seam
        seam_x = lx1 if leaf == 0 else lx0
        cv.vline(seam_x, 7, 30, dp[0])
        # hazard stripes on maintenance / external
        if dept in ("maint", "ext"):
            for y in range(26, 30):
                for x in range(lx0, lx1 + 1):
                    if ((x + y) // 2) % 2 == 0:
                        cv.px(x, y, hexc("#1d1b22"))
                    else:
                        cv.px(x, y, hexc("#e0b23a"))
    if frame == 3:
        # dark gap / threshold track
        for x in range(3, 29):
            cv.px(x, 30, fp[0])
    cv.hline(0, 31, 31, OUTLINE)
    if dept == "ext":
        # frost on the frame
        for x in range(0, 32):
            if (x * 7) % 5 < 2:
                cv.px(x, 1, hexc("#eaf6ff"))
                cv.px(x, 2, hexc("#c8e2f5"))
    return sp


# ------------------------------------------------------------------ wall mounts
def apc():
    sp = Sprite()
    rng = rng_for("apc")
    cv = sp.cv
    box3d(cv, 8, 6, 23, 19, 2, "#9aa3b3", 0.35)
    screen(sp, 11, 10, 20, 14, "#5aff9a", rng, "bars")
    lamp(sp, 11, 17, "#5aff7a")
    lamp(sp, 14, 17, "#5aff7a")
    lamp(sp, 17, 17, "#ffcc4a")
    cv.hline(10, 21, 7, hexc("#d8a53a"))
    return sp


def air_alarm():
    sp = Sprite()
    rng = rng_for("aa")
    cv = sp.cv
    box3d(cv, 10, 7, 21, 18, 2, "#c9d0da", 0.35)
    screen(sp, 12, 10, 19, 15, "#5ad0ff", rng, "text")
    return sp


def fire_alarm():
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 12, 8, 19, 16, 2, "#c83a3a", 0.35)
    lamp(sp, 15, 12, "#ff6a4a")
    lamp(sp, 16, 12, "#ff6a4a")
    return sp


def light_fixture(on=True, broken=False):
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 5, 9, 26, 13, 1, "#aeb6c4", 0.3)
    if broken:
        for x in range(8, 24, 3):
            cv.px(x, 12, hexc("#5a5f6a"))
            cv.px(x + 1, 12, hexc("#c8d0dc"))
        return sp
    col = "#fff4d8" if on else "#8a8f9a"
    for x in range(7, 25):
        if on:
            sp.g(x, 12, hexc(col))
            sp.g(x, 11, hexc("#ffffff"))
        else:
            cv.px(x, 12, hexc(col))
    return sp


def emergency_light():
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 13, 9, 18, 13, 1, "#4a4f5c", 0.3)
    sp.g(15, 11, hexc("#ff3a2a"))
    sp.g(16, 11, hexc("#ff3a2a"))
    return sp


def extinguisher_cabinet(full=True):
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 11, 5, 20, 20, 1, "#b0b8c4", 0.3)
    for y in range(8, 19):
        for x in range(13, 19):
            cv.px(x, y, hexc("#2a3040"))
    if full:
        for y in range(9, 19):
            for x in range(14, 18):
                cv.px(x, y, hexc("#d83a3a") if x != 14 else hexc("#ff6a5a"))
        cv.px(15, 8, hexc("#1d1b22"))
    return sp


def intercom():
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 12, 8, 19, 16, 1, "#7a8494", 0.3)
    for y in range(11, 15, 2):
        cv.hline(13, 18, y, hexc("#2a2e38"))
    lamp(sp, 18, 9, "#5aff7a")
    return sp


def status_display():
    """tg status display: a wall screen the engine writes the crawler ETA / alert onto."""
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 3, 5, 28, 21, 1, "#4a5262", 0.35)
    for y in range(8, 20):
        for x in range(5, 27):
            sp.cv.px(x, y, hexc("#08141a"))
    for x in range(5, 27):
        sp.g(x, 7, hexc("#2a6a8a"))  # lit top edge of the screen
    lamp(sp, 26, 20, "#5aff7a")
    return sp


# ------------------------------------------------------------------ floor devices
def vent(active=True, welded=False):
    sp = Sprite()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    m = ellipse_mask(32, 32, 16, 16, 9, 9)
    shaded_fill(cv, m, p[2], 0.35)
    inner = ellipse_mask(32, 32, 16, 16, 6.5, 6.5)
    cv.mask_fill(inner, hexc("#1d2028"))
    for y in range(11, 22, 2):
        for x in range(10, 23):
            if inner[y, x]:
                cv.px(x, y, p[3])
    sel_outline(cv)
    if welded:
        for x in range(9, 24):
            cv.px(x, 16, hexc("#9aa0a8"))
            cv.px(x, 17, hexc("#4a4f58"))
    return sp


def scrubber(active=True):
    sp = Sprite()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    m = rrect_mask(32, 32, 7, 8, 24, 23, 2)
    shaded_fill(cv, m, p[2], 0.35)
    for y in range(11, 21):
        for x in range(10, 22):
            cv.px(x, y, hexc("#1d2028") if (x % 3 == 0) else p[1])
    sel_outline(cv)
    return sp


PIPE_COLS = {"supply": "#3a7ad8", "scrub": "#d84a3a", "hot": "#e8903a", "cold": "#3ad0d8", "gen": "#c8ccd4", "aux": "#c8ccd4", "fuel": "#e8c84a"}


# tg piping layers 1-5: each is drawn (3 - layer) * 3 px up-left of the tile centre
TG_LAYER_OFF = {1: 6, 2: 3, 3: 0, 4: -3, 5: -6}


def pipe(layer, mask, broken=False, base=None, off=None):
    cv = Canvas()
    base = base or PIPE_COLS[layer]
    p = ramp(base, 5, 0.45)
    if off is None:
        off = {"supply": -3, "scrub": 3, "hot": -3, "cold": 3, "gen": 0, "aux": -6, "fuel": 0}[layer]
    cx, cy = 16 + off, 16 + off
    segs = []
    if mask & N:
        segs.append((cx, 0, cx, cy))
    if mask & S:
        segs.append((cx, cy, cx, 31))
    if mask & W:
        segs.append((0, cy, cx, cy))
    if mask & E:
        segs.append((cx, cy, 31, cy))
    if not segs:
        segs.append((cx - 3, cy, cx + 3, cy))
    for (x0, y0, x1, y1) in segs:
        if x0 == x1:
            for y in range(min(y0, y1), max(y0, y1) + 1):
                cv.px(x0 - 2, y, OUTLINE)
                cv.px(x0 - 1, y, p[3])
                cv.px(x0, y, p[2])
                cv.px(x0 + 1, y, p[1])
                cv.px(x0 + 2, y, OUTLINE)
        else:
            for x in range(min(x0, x1), max(x0, x1) + 1):
                cv.px(x, y0 - 2, OUTLINE)
                cv.px(x, y0 - 1, p[3])
                cv.px(x, y0, p[2])
                cv.px(x, y0 + 1, p[1])
                cv.px(x, y0 + 2, OUTLINE)
    # joint collar
    n_conn = bin(mask).count("1")
    if n_conn != 2 or mask in (N | E, E | S, S | W, W | N):
        for y in range(cy - 2, cy + 3):
            for x in range(cx - 2, cx + 3):
                cv.px(x, y, p[2])
        cv.px(cx - 1, cy - 1, p[4])
        for k in range(-3, 4):
            for (x, y) in ((cx + k, cy - 3), (cx + k, cy + 3), (cx - 3, cy + k), (cx + 3, cy + k)):
                if cv.get(x, y)[3] == 0:
                    cv.px(x, y, OUTLINE)
    # flange rings every half tile
    for (x0, y0, x1, y1) in segs:
        if x0 == x1:
            for y in (4, 27):
                if min(y0, y1) <= y <= max(y0, y1):
                    cv.hline(x0 - 2, x0 + 2, y, p[4])
        else:
            for x in (4, 27):
                if min(x0, x1) <= x <= max(x0, x1):
                    cv.vline(x, y0 - 2, y0 + 2, p[4])
    if broken:
        for (dx, dy) in ((0, 0), (1, -1), (-1, 1), (2, 1)):
            cv.px(cx + dx, cy + dy, hexc("#1d1b22"))
    return cv


def pipe_link():
    """tg layer adaptor: a collar block joining every piping layer on the tile."""
    cv = Canvas()
    p = ramp("#9aa3b3", 5, 0.45)
    for y in range(9, 24):
        for x in range(9, 24):
            cv.px(x, y, p[2] if 10 < x < 22 and 10 < y < 22 else OUTLINE)
    for k in range(11, 22, 3):
        cv.hline(11, 21, k, p[3])
    cv.px(12, 12, p[4])
    return cv


def cable(mask, color="#d83a3a"):
    cv = Canvas()
    p = ramp(color, 3, 0.4)
    c = 16
    for bit, (dx, dy) in ((N, (0, -1)), (S, (0, 1)), (E, (1, 0)), (W, (-1, 0))):
        if mask & bit:
            for k in range(0, 17):
                x, y = c + dx * k, c + dy * k
                if 0 <= x < 32 and 0 <= y < 32:
                    cv.px(x, y, p[1])
                    cv.px(x + (1 if dy else 0), y + (1 if dx else 0), p[0])
                    if k % 5 == 0:
                        cv.px(x, y, p[2])
    if mask == 0 or bin(mask).count("1") != 2:
        for y in range(14, 19):
            for x in range(14, 19):
                if (x - 16) ** 2 + (y - 16) ** 2 <= 5:
                    cv.px(x, y, p[1])
        cv.px(15, 15, p[2])
    return cv


def valve(open_):
    sp = Sprite()
    cv = sp.cv
    cv.paste(pipe("gen", E | W))
    box3d(cv, 12, 11, 19, 20, 2, "#8a93a3", 0.4)
    wheel = hexc("#d83a3a") if not open_ else hexc("#4ad86a")
    for x in range(11, 21):
        cv.px(x, 9, wheel)
    cv.vline(15, 9, 12, shade(wheel, -0.3))
    return sp


def pump(on):
    sp = Sprite()
    cv = sp.cv
    cv.paste(pipe("gen", E | W))
    box3d(cv, 10, 10, 21, 22, 3, "#5a6272", 0.4)
    lamp(sp, 19, 15, "#5aff7a" if on else "#ff4a3a")
    cv.px(13, 16, hexc("#9aa3b3"))
    cv.px(14, 17, hexc("#9aa3b3"))
    cv.px(15, 16, hexc("#9aa3b3"))
    return sp


def connector():
    sp = Sprite()
    cv = sp.cv
    cv.paste(pipe("gen", N))
    m = ellipse_mask(32, 32, 16, 18, 6, 5)
    shaded_fill(cv, m, "#8a93a3", 0.4)
    cv.px(16, 18, hexc("#1d1b22"))
    return sp


# ------------------------------------------------------------------ inline pipe machines (tg binary/trinary atmos devices)
def pipe_machine(kind, layer, state):
    """A machine body sitting on a pipe run, centred on that layer's lane. The pipe
    underneath (drawn by the pipe layer) shows which ways it connects."""
    sp = Sprite()
    cv = sp.cv
    off = {"supply": -3, "scrub": 3, "gen": 0, "aux": -6}[layer]
    cx, cy = 16 + off, 16 + off
    band = PIPE_COLS[layer] if layer in ("supply", "scrub") else "#9aa3b3"
    if kind == "pump":
        # a squat motor housing with a status lamp
        m = ellipse_mask(32, 32, cx, cy, 6.5, 6)
        shaded_fill(cv, m, "#5a6272", 0.45)
        for x in range(cx - 5, cx + 6):
            cv.px(x, cy + 3, shade(hexc(band), -0.1))
        cv.px(cx - 2, cy - 1, hexc("#9aa3b3"))
        cv.px(cx - 1, cy, hexc("#9aa3b3"))
        cv.px(cx, cy - 1, hexc("#9aa3b3"))
        lamp(sp, cx + 3, cy - 3, "#5aff7a" if state else "#ff4a3a")
    elif kind == "vpump":
        box3d(cv, cx - 6, cy - 5, cx + 5, cy + 6, 2, "#4a5262", 0.4)
        for x in range(cx - 4, cx + 4, 2):
            cv.px(x, cy + 1, hexc("#9aa3b3"))
        cv.hline(cx - 5, cx + 4, cy + 4, shade(hexc(band), -0.1))
        lamp(sp, cx + 3, cy - 3, "#5aff7a" if state else "#ff4a3a")
    elif kind == "valve":
        box3d(cv, cx - 3, cy - 3, cx + 3, cy + 4, 2, "#8a93a3", 0.4)
        wheel = hexc("#4ad86a") if state else hexc("#d83a3a")
        for x in range(cx - 5, cx + 6):
            cv.px(x, cy - 5, wheel)
        cv.vline(cx, cy - 5, cy - 2, shade(wheel, -0.3))
        cv.px(cx - 5, cy - 6, shade(wheel, 0.3))
        cv.px(cx + 5, cy - 6, shade(wheel, 0.3))
    elif kind == "filter":
        box3d(cv, cx - 6, cy - 6, cx + 5, cy + 5, 2, "#6a7486", 0.4)
        # the filter cartridge window
        cv.rect(cx - 3, cy - 2, cx + 2, cy + 2, hexc("#1d2230"))
        for x in range(cx - 3, cx + 3):
            cv.px(x, cy, hexc("#e87a2a" if state else "#3a3f4a"))
        lamp(sp, cx + 3, cy - 4, "#5aff7a" if state else "#ff4a3a")
    elif kind == "mixer":
        # tg gas mixer: a round-shouldered box with two inlet arrows meeting
        box3d(cv, cx - 6, cy - 6, cx + 5, cy + 5, 2, "#7a6a8a", 0.4)
        cv.rect(cx - 3, cy - 2, cx + 2, cy + 2, hexc("#1d2230"))
        arrow = hexc("#e8d84a" if state else "#3a3f4a")
        for k in range(3):
            cv.px(cx - 3 + k, cy - 2 + k, arrow)
            cv.px(cx - 3 + k, cy + 2 - k, arrow)
        cv.hline(cx, cx + 2, cy, arrow)
        lamp(sp, cx + 3, cy - 4, "#5aff7a" if state else "#ff4a3a")
    elif kind == "gate":
        # passive gate / pressure valve: a slim body with a one-way flap
        box3d(cv, cx - 4, cy - 4, cx + 4, cy + 4, 2, "#6a7486", 0.4)
        flap = hexc("#5aff7a" if state else "#8a93a3")
        cv.vline(cx, cy - 2, cy + 2, flap)
        cv.px(cx + 1, cy - 1, flap)
        cv.px(cx + 1, cy + 1, flap)
    return sp


def thermomachine(freezer, on):
    """tg's thermomachine: a heater (red) or freezer (blue) cabinet with a readout."""
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 5, 26, 30)
    col = "#3a6ad8" if freezer else "#c84a3a"
    p = box3d(cv, 5, 6, 26, 29, 4, "#6a7486", 0.4)
    cv.rect(8, 12, 23, 15, hexc(col))
    cv.hline(8, 23, 12, shade(hexc(col), 0.35))
    cv.rect(9, 18, 17, 22, hexc("#101720"))
    if on:
        for x in range(10, 17, 2):
            sp.g(x, 20, hexc("#9ad8ff" if freezer else "#ffb05a"))
    for y in range(24, 28, 2):
        cv.hline(8, 23, y, p[4])
    lamp(sp, 21, 19, "#5aff7a" if on else "#ff4a3a")
    return sp


def recharger(charging):
    """tg weapon recharger: a desk unit with a cradle and a charge bar."""
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 6, 25, 27)
    p = box3d(cv, 6, 14, 25, 26, 3, "#5a6272", 0.4)
    cv.rect(9, 12, 22, 16, hexc("#2a2e38"))
    for x in range(9, 23, 2):
        sp.g(x, 22, hexc("#6ac8ff" if charging else "#2a4a5a"))
    lamp(sp, 23, 19, "#5aff7a" if charging else "#ffb84a")
    return sp


# ------------------------------------------------------------------ big machines
def reactor():
    """64x64 fission core. Glow sprite is the core window (engine tints it by heat)."""
    sp = Sprite(64, 64)
    cv = sp.cv
    rng = rng_for("reactor")
    contact_shadow(cv, 6, 57, 62)
    # base plinth
    box3d(cv, 5, 40, 58, 61, 5, "#3e4452", 0.4)
    # vessel: big rounded cylinder
    body = ellipse_mask(64, 64, 32, 30, 22, 26) & (np.mgrid[0:64, 0:64][0] < 56)
    shaded_fill(cv, body, "#6a7486", 0.45, noise=(value_noise(64, 64, 2, 3) - 0.5) * 0.06)
    # hazard band
    for y in range(44, 49):
        for x in range(10, 55):
            if body[y, x]:
                cv.px(x, y, hexc("#1d1b22") if ((x + y) // 3) % 2 else hexc("#e0b23a"))
    # core viewport
    core = ellipse_mask(64, 64, 32, 26, 9, 10)
    rim = ellipse_mask(64, 64, 32, 26, 11, 12) & ~core
    cv.mask_fill(rim, hexc("#2a2e38"))
    ys, xs = np.nonzero(core)
    for y, x in zip(ys, xs):
        d = math.hypot((x + 0.5 - 32) / 9, (y + 0.5 - 26) / 10)
        col = mix(hexc("#eafff8"), hexc("#2ad8a8"), min(1, d * 1.2))
        sp.g(x, y, col)
    # control rod heads on top
    for i, x in enumerate(range(16, 50, 6)):
        box3d(cv, x, 4, x + 3, 12, 2, "#9aa3b3", 0.35)
        lamp(sp, x + 1, 6, "#5aff7a" if i % 2 else "#ffd84a")
    # pipes out the sides
    for y in (40, 41, 42):
        cv.hline(0, 9, y, ramp("#e8903a", 3, 0.4)[1 if y == 41 else 0])
        cv.hline(54, 63, y, ramp("#3ad0d8", 3, 0.4)[1 if y == 41 else 0])
    sel_outline(cv, 0.5)
    return sp


def teg():
    """64x32 thermoelectric generator with two circulators."""
    sp = Sprite(64, 32)
    cv = sp.cv
    contact_shadow(cv, 3, 60, 30)
    box3d(cv, 20, 4, 43, 28, 6, "#5a6272", 0.4)
    for (x0, col) in ((3, "#e8903a"), (46, "#3ad0d8")):
        box3d(cv, x0, 10, x0 + 14, 28, 4, "#7a8494", 0.4)
        m = ellipse_mask(64, 32, x0 + 7.5, 20, 5, 5)
        cv.mask_fill(m, hexc("#2a2e38"))
        for a in range(0, 360, 60):
            x = int(x0 + 7.5 + math.cos(math.radians(a)) * 3.5)
            y = int(20 + math.sin(math.radians(a)) * 3.5)
            cv.px(x, y, hexc(col))
    screen(sp, 24, 13, 39, 21, "#ffcc4a", rng_for("teg"), "graph")
    for x in range(22, 42, 3):
        cv.px(x, 25, hexc("#1d1b22"))
    return sp


def smes():
    sp = Sprite(32, 48)
    cv = sp.cv
    contact_shadow(cv, 4, 27, 46)
    box3d(cv, 4, 6, 27, 45, 6, "#6a7486", 0.4)
    for i in range(5):
        y = 16 + i * 5
        for x in range(8, 24):
            sp.g(x, y, hexc("#5aff7a") if i > 0 else hexc("#2a5a3a"))
            sp.g(x, y + 1, hexc("#3ac85a") if i > 0 else hexc("#1a3a2a"))
    cv.hline(6, 25, 8, hexc("#d8a53a"))
    lamp(sp, 24, 42, "#ffd84a")
    return sp


def generator_portable(on=False):
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 5, 26, 30)
    box3d(cv, 5, 9, 26, 29, 5, "#c8a03a", 0.4)
    for y in range(17, 27, 2):
        cv.hline(8, 16, y, hexc("#3a3020"))
    lamp(sp, 22, 18, "#5aff7a" if on else "#ff4a3a")
    cv.rect(19, 21, 24, 26, hexc("#2a2e38"))
    return sp


def radiator():
    """Exterior heat exchange fins: frosty."""
    sp = Sprite()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    contact_shadow(cv, 2, 29, 30, 0.25)
    for x in range(3, 29, 3):
        for y in range(8, 29):
            cv.px(x, y, p[3])
            cv.px(x + 1, y, p[1])
        cv.px(x, 8, p[4])
    cv.hline(2, 29, 7, p[2])
    cv.hline(2, 29, 29, p[0])
    for x in range(2, 30):
        if (x * 13) % 7 < 3:
            cv.px(x, 7, hexc("#f4f8ff"))
            cv.px(x, 8, hexc("#dce5f5"))
    return sp


def heater(on=True):
    """Wall-mounted radiator panel (drawn on the wall face above its floor tile)."""
    sp = Sprite()
    cv = sp.cv
    p = box3d(cv, 4, 8, 27, 20, 1, "#9aa3b3", 0.35)
    for x in range(6, 26, 2):
        cv.vline(x, 11, 18, p[1])
        cv.vline(x + 1, 11, 18, p[5])
        if on:
            sp.g(x, 19, hexc("#ff8a3a"))
            sp.g(x + 1, 19, hexc("#ffb05a"))
    cv.hline(5, 26, 20, p[0])
    lamp(sp, 25, 10, "#5aff7a" if on else "#ff4a3a")
    return sp


def canister(kind):
    col = {"o2": "#3a6ad8", "n2": "#c83a3a", "air": "#b0b8c4", "plasma": "#e87a2a", "co2": "#2a2e38", "empty": "#e8e0c8",
           "n2o": "#e8e8ec", "h2o": "#4a6a8a"}[kind]
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 9, 22, 38)
    body = rrect_mask(32, 40, 9, 7, 22, 37, 4)
    shaded_fill(cv, body, col, 0.4)
    cv.rect(13, 3, 18, 7, hexc("#6a7486"))
    cv.px(13, 3, hexc("#9aa3b3"))
    m = rrect_mask(32, 40, 11, 17, 20, 23, 1)
    cv.mask_fill(m, hexc("#e8eef4") if kind != "air" else hexc("#3a3f4a"))
    for x in range(12, 20, 2):
        cv.px(x, 20, hexc("#3a3f4a") if kind != "air" else hexc("#e8eef4"))
    sel_outline(cv)
    return sp


def injector(on=True):
    """tg outlet_injector: a squat nozzle block with a grille that blows onto the tile."""
    sp = Sprite()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    m = rrect_mask(32, 32, 9, 10, 22, 22, 3)
    shaded_fill(cv, m, p[2], 0.35)
    for x in range(11, 21, 2):
        cv.vline(x, 12, 20, hexc("#1d2028"))
    lamp(sp, 21, 11, "#5aff7a" if on else "#ff4a3a")
    sel_outline(cv)
    return sp


def vent_siphon():
    """A vent pump set to siphon: the usual round vent with a red intake ring."""
    sp = vent()
    cv = sp.cv
    ring = ellipse_mask(32, 32, 16, 16, 9, 9) & ~ellipse_mask(32, 32, 16, 16, 7.5, 7.5)
    cv.mask_fill(ring, hexc("#c84a3a"))
    return sp


def passive_vent():
    """tg passive_vent: an open grated pipe end."""
    sp = Sprite()
    cv = sp.cv
    p = ramp("#6a7486", 5, 0.4)
    m = ellipse_mask(32, 32, 16, 16, 7, 7)
    shaded_fill(cv, m, p[2], 0.4)
    for y in range(12, 21, 2):
        cv.hline(11, 21, y, hexc("#1d2028"))
    sel_outline(cv)
    return sp


def pipe_tank():
    """tg stationary pressure tank: a fat horizontal cylinder on feet."""
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 3, 28, 38)
    body = rrect_mask(32, 40, 3, 12, 28, 34, 8)
    shaded_fill(cv, body, "#7a8494", 0.45)
    cv.hline(5, 26, 15, hexc("#aab3c3"))
    for x in (9, 22):
        cv.vline(x, 13, 33, hexc("#5a6272"))
    cv.rect(14, 8, 17, 12, hexc("#5a6272"))
    sel_outline(cv)
    return sp


def meter(level):
    """tg meter: a gauge clamped on the pipe; the bar grows with pressure."""
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 11, 6, 20, 15, 2, "#5a6272", 0.4)
    cv.rect(12, 9, 19, 13, hexc("#101418"))
    cols = ["#3a3f4a", "#4a8ad8", "#5ad87a", "#e8c84a", "#e84a3a"]
    for k in range(level):
        cv.rect(12 + k * 2, 11, 13 + k * 2, 13, hexc(cols[level]))
    if level:
        sp.g(19, 8, hexc(cols[level]))
    return sp


def portable_atmos(kind, on):
    """tg portable pump (yellow-grey, a big fan) and portable scrubber (blue-grey, a grille),
    on wheels with a gauge; the lamp shows it's running."""
    col = "#a8962a" if kind == "pump" else "#4a6a8a"
    sp = Sprite(32, 40)
    cv = sp.cv
    contact_shadow(cv, 7, 24, 38)
    box3d(cv, 7, 12, 24, 35, 3, col, 0.42)
    fan = ellipse_mask(32, 40, 15, 24, 6, 6)
    cv.mask_fill(fan, hexc("#1d2028"))
    if kind == "pump":
        for k in range(4):
            import math as _m
            a = k * _m.pi / 2 + (0.4 if on else 0.0)
            for r in range(1, 6):
                cv.px(int(15 + _m.cos(a) * r), int(24 + _m.sin(a) * r), hexc("#8a93a3"))
    else:
        for y in range(19, 30, 2):
            for x in range(10, 21):
                if fan[y, x]:
                    cv.px(x, y, hexc("#6a7486"))
    cv.rect(18, 14, 22, 17, hexc("#e8eef4"))
    cv.px(20, 15, hexc("#3a3f4a"))
    lamp(sp, 21, 30, "#5aff7a" if on else "#ff4a3a")
    for wx in (9, 22):
        cv.rect(wx - 1, 35, wx + 1, 37, hexc("#26242c"))
    sel_outline(cv)
    return sp


def fuel_tank(open_=False):
    """Wheeled welding-fuel tank lying on its side (tg: /obj/structure/reagent_dispensers/fueltank)."""
    sp = Sprite(32, 32)
    cv = sp.cv
    contact_shadow(cv, 4, 27, 30)
    body = rrect_mask(32, 32, 4, 12, 27, 27, 5)
    shaded_fill(cv, body, "#c8322a", 0.4)
    cv.hline(6, 25, 14, hexc("#e86a5a"))
    # hazard band
    for x in range(9, 23):
        cv.px(x, 19, hexc("#e0b23a") if (x // 2) % 2 else hexc("#1d1b22"))
        cv.px(x, 20, hexc("#e0b23a") if (x // 2) % 2 else hexc("#1d1b22"))
    cv.rect(14, 9, 17, 11, hexc("#6a7486"))
    cv.px(14, 9, hexc("#9aa3b3"))
    # wheels
    for wx in (8, 23):
        cv.rect(wx - 1, 27, wx + 1, 29, hexc("#26242c"))
    # tap
    cv.rect(27, 21, 28, 22, hexc("#9aa3b3"))
    if open_:
        cv.px(28, 23, hexc("#b8903a"))
        cv.px(28, 25, hexc("#b8903a", 0.8))
    sel_outline(cv)
    return sp


def console(kind):
    col = {"eng": "#d8a53a", "med": "#4ab8d8", "sec": "#d84a4a", "sci": "#b87ae8", "cmd": "#4a8ad8",
           "reactor": "#2ad8a8", "cargo": "#e8a84a", "atmos": "#5ad0ff", "comms": "#8ad85a"}[kind]
    sp = Sprite(32, 40)
    cv = sp.cv
    rng = rng_for("con" + kind)
    contact_shadow(cv, 4, 27, 38)
    # desk
    box3d(cv, 4, 24, 27, 37, 5, "#4a5060", 0.4)
    # angled monitor
    box3d(cv, 5, 5, 26, 23, 2, "#5a6272", 0.35)
    style = {"reactor": "graph", "sec": "map", "atmos": "graph", "cargo": "text", "med": "graph"}.get(kind, "text")
    screen(sp, 8, 9, 23, 20, col, rng, style)
    # keyboard
    for x in range(7, 25, 2):
        cv.px(x, 27, hexc("#9aa3b3"))
        cv.px(x, 29, hexc("#9aa3b3"))
    cv.hline(6, 25, 25, hexc(col))
    return sp


def vending(kind):
    col, label = {"snack": ("#3a6ad8", "#ffd84a"), "cocoa": ("#7a4a2e", "#ffb87a"), "drink": ("#c83a3a", "#e8f4ff"),
                  "med": ("#e8eef4", "#4ab8d8"), "tool": ("#d8a53a", "#2a2e38"), "winter": ("#3a8a9a", "#eaf8ff")}[kind]
    sp = Sprite(32, 48)
    cv = sp.cv
    rng = rng_for("vend" + kind)
    contact_shadow(cv, 5, 26, 46)
    box3d(cv, 5, 4, 26, 45, 4, col, 0.42)
    # glass front with products
    for y in range(12, 36):
        for x in range(8, 20):
            cv.px(x, y, hexc("#1c2838"))
    for row in range(4):
        y = 13 + row * 6
        cv.hline(8, 19, y + 5, hexc("#6a7486"))
        for x in range(9, 19, 3):
            pc = hexc(["#e84a4a", "#4ae86a", "#ffd84a", "#4ab8ff", "#e8e8e8", "#ff8ad8"][rng.randint(0, 5)])
            cv.rect(x, y + 1, x + 1, y + 4, pc)
            cv.px(x, y + 1, shade(pc, 0.4))
    # glass sheen
    for i in range(10):
        cv.px(9 + i, 34 - i * 2, (1, 1, 1, 0.25))
    # side panel: coin slot & buttons
    for y in range(14, 30, 3):
        lamp(sp, 22, y, label if y != 14 else "#5aff7a")
    cv.rect(21, 32, 24, 34, hexc("#1d1b22"))
    # lit sign
    for x in range(8, 24):
        sp.g(x, 8, hexc(label))
        sp.g(x, 9, shade(hexc(label), -0.2))
    cv.rect(8, 38, 19, 41, hexc("#1d1b22"))
    return sp


def pipe_dispenser():
    """tg pipe dispenser: a squat yellow-grey machine, a screen, and a hopper with pipe
    fittings showing through the hatch."""
    sp = Sprite(32, 40)
    cv = sp.cv
    rng = rng_for("pipedisp")
    contact_shadow(cv, 4, 27, 38)
    box3d(cv, 4, 8, 27, 37, 4, "#8a8f5a", 0.4)
    # hazard band
    for x in range(6, 26):
        cv.px(x, 13, hexc("#e8c84a") if (x // 2) % 2 == 0 else hexc("#2a2e38"))
    # screen
    screen(sp, 7, 16, 18, 22, "#5ad0ff", rng, "text")
    # buttons
    lamp(sp, 21, 17, "#3a7ad8")
    lamp(sp, 24, 17, "#d84a3a")
    lamp(sp, 21, 21, "#5aff7a")
    # output hatch with fittings inside
    cv.rect(7, 26, 24, 34, hexc("#1d1b22"))
    for (x, col) in ((9, "#3a7ad8"), (14, "#d84a3a"), (19, "#3a7ad8")):
        pal = ramp(col, 5, 0.45)
        for y in range(28, 33):
            cv.px(x, y, pal[3])
            cv.px(x + 1, y, pal[2])
            cv.px(x + 2, y, pal[1])
        cv.hline(x - 1, x + 3, 28, pal[4])
    cv.hline(7, 24, 25, hexc("#6a7486"))
    return sp


def locker(kind, open_=False):
    col, stripe = {"eng": ("#d8a53a", "#5f6878"), "med": ("#e8eef4", "#4aa3d8"), "sec": ("#8a2a33", "#d8d0c0"),
                   "sci": ("#7a5ab8", "#e8eef4"), "gen": ("#6a7486", "#9aa3b3"), "emerg": ("#3a6ad8", "#e8eef4"),
                   "fire": ("#c83a3a", "#e8e8e8"), "winter": ("#3a8a9a", "#eaf8ff"), "cmd": ("#3a5ab8", "#d8b84a")}[kind]
    sp = Sprite(32, 48)
    cv = sp.cv
    contact_shadow(cv, 6, 25, 46)
    p = box3d(cv, 6, 6, 25, 45, 4, col, 0.4)
    if open_:
        for y in range(12, 44):
            for x in range(8, 24):
                cv.px(x, y, hexc("#1d1b22") if y < 43 else p[1])
        cv.hline(8, 23, 20, p[2])
        # door swung open to the right
        for y in range(11, 45):
            cv.px(25, y, p[5])
            cv.px(26, y, p[3])
            cv.px(27, y, p[1])
    else:
        for y in range(14, 40, 3):
            cv.hline(9, 14, y, p[1])
        cv.hline(7, 24, 26, hexc(stripe))
        cv.hline(7, 24, 27, shade(hexc(stripe), -0.25))
        cv.vline(20, 22, 30, p[6])
        lamp(sp, 21, 18, "#5aff7a")
    return sp


def crate(open_=False, kind="gen"):
    col = {"gen": "#8a7a4a", "eng": "#d8a53a", "med": "#e8eef4", "sec": "#8a2a33", "food": "#4a9a6a", "sci": "#7a5ab8"}[kind]
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 4, 27, 30)
    p = box3d(cv, 4, 10 if not open_ else 13, 27, 29, 6, col, 0.42)
    if open_:
        cv.rect(6, 14, 25, 17, hexc("#1d1b22"))
        box3d(cv, 4, 4, 27, 9, 2, col, 0.4, outline=True)
    else:
        for x in (8, 23):
            cv.vline(x, 17, 28, p[1])
        cv.hline(5, 26, 22, p[2])
        cv.rect(14, 18, 17, 20, hexc("#c8ccd4"))
    return sp


TABLE_COLS = {"steel": "#8a93a3", "wood": "#8a5a3b", "glass": "#9fd0ec", "counter": "#c8c0b0", "bar": "#5a3220", "reinforced": "#6a7486"}


def table(kind="steel", mask=0):
    """A table piece that joins its neighbours (tg smoothing): mask bits N=1 E=2 S=4 W=8
    say which sides continue into another table of the same kind, so rows become one
    long surface with legs only at the outer corners and a front apron only on the
    bottom edge. Counters and the bar have a full front panel instead of legs."""
    col = TABLE_COLS[kind]
    sp = Sprite()
    cv = sp.cv
    n, e, s_, w = bool(mask & N), bool(mask & E), bool(mask & S), bool(mask & W)
    solid = kind in ("counter", "bar")
    p = ramp(col, 7, 0.4)
    y0 = 0 if n else 8
    y1 = 31 if s_ else 21
    x0 = 0 if w else 2
    x1 = 31 if e else 29
    if not s_:
        contact_shadow(cv, x0 + 1, x1 - 1, 30)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = 4 if y > y0 or n else 6
            if kind == "wood" or kind == "bar":
                # wood grain: long streaks along the run
                if (y * 7 + (x // 9) * 3) % 5 == 0:
                    i = 3
                if kind == "bar" and (x + y * 3) % 23 == 0:
                    i = 5
            elif (x + y) % 17 == 0:
                i = 5
            c = p[i]
            if kind == "glass":
                c = np.append(c[:3], 0.8)
            cv.px(x, y, c)
    # polished edge highlights
    if not n:
        cv.hline(x0, x1, y0, p[6])
    if kind == "bar":
        # brass rail along the customer side (the front, or the west edge of a N-S run)
        if not s_:
            cv.hline(x0, x1, y1, hexc("#d8b050"))
            cv.hline(x0, x1, y1 - 1, hexc("#8a6a30"))
        if not w and (n or s_):
            cv.vline(x0, y0, y1, hexc("#d8b050"))
            cv.vline(x0 + 1, y0, y1, hexc("#8a6a30"))
    if not s_:
        if solid:
            # full front panel: wood panelling (bar) or cabinet doors (counter)
            front = hexc("#3a2014") if kind == "bar" else p[2]
            cv.rect(x0, 22, x1, 29, front)
            cv.hline(x0, x1, 22, p[1] if kind != "bar" else hexc("#2a160e"))
            step = 6 if kind == "bar" else 8
            for x in range(x0 + 3, x1, step):
                cv.vline(x, 24, 28, p[1] if kind != "bar" else hexc("#6a3a22"))
            cv.hline(x0, x1, 29, hexc("#1d1b22"))
        else:
            cv.hline(x0, x1, 22, p[2])
            cv.hline(x0, x1, 23, p[1])
            for (lx, has) in ((3, not w), (27, not e)):
                if has:
                    cv.vline(lx, 24, 29, p[2])
                    cv.vline(lx + 1, 24, 29, p[1])
    # outline on the open sides only
    if not n:
        cv.hline(x0, x1, y0 - 1, OUTLINE)
    if not s_:
        cv.hline(x0, x1, 30 if solid else 24, OUTLINE)
    bottom = 31 if s_ else (29 if solid else 23)
    if not w:
        cv.vline(x0 - 1, y0, bottom, OUTLINE)
    if not e:
        cv.vline(x1 + 1, y0, bottom, OUTLINE)
    return sp


def chair(d, kind="steel"):
    col = {"steel": "#8a93a3", "office": "#2e3440", "wood": "#8a5a3b", "comfy": "#7a2e3a", "shuttle": "#3a5a8a"}[kind]
    sp = Sprite()
    cv = sp.cv
    p = ramp(col, 7, 0.4)
    contact_shadow(cv, 9, 22, 29)
    # seat
    seat = rrect_mask(32, 32, 9, 16, 22, 23, 1)
    shaded_fill(cv, seat, p[4], 0.35)
    # legs
    for x in (10, 21):
        cv.vline(x, 24, 28, p[1])
    if d == "s":  # facing down -> back rest at top
        back = rrect_mask(32, 32, 9, 7, 22, 15, 1)
        shaded_fill(cv, back, p[3], 0.35)
    elif d == "n":
        back = rrect_mask(32, 32, 9, 20, 22, 26, 1)
        shaded_fill(cv, back, p[3], 0.35)
    elif d == "e":
        back = rrect_mask(32, 32, 8, 8, 11, 23, 1)
        shaded_fill(cv, back, p[3], 0.35)
    else:
        back = rrect_mask(32, 32, 20, 8, 23, 23, 1)
        shaded_fill(cv, back, p[3], 0.35)
    sel_outline(cv, 0.5)
    return sp


def bed(sheet="#3a6ad8"):
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 4, 27, 30)
    frame = rrect_mask(32, 32, 4, 4, 27, 28, 1)
    shaded_fill(cv, frame, "#8a93a3", 0.35)
    mattress = rrect_mask(32, 32, 6, 5, 25, 26, 2)
    shaded_fill(cv, mattress, "#e8eef4", 0.3)
    pillow = rrect_mask(32, 32, 8, 6, 23, 10, 2)
    shaded_fill(cv, pillow, "#ffffff", 0.25)
    blanket = rrect_mask(32, 32, 6, 13, 25, 26, 1)
    shaded_fill(cv, blanket, sheet, 0.4)
    cv.hline(6, 25, 13, shade(hexc(sheet), 0.35))
    sel_outline(cv, 0.5)
    return sp


def microwave(on=False):
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 6, 8, 25, 22, 3, "#c8ccd4", 0.35)
    for y in range(13, 20):
        for x in range(8, 19):
            if on:
                sp.g(x, y, hexc("#ffd88a") if (x + y) % 3 else hexc("#ffb84a"))
            else:
                cv.px(x, y, hexc("#1d2028"))
    for y in range(13, 20, 2):
        lamp(sp, 22, y, "#5aff7a" if y == 13 else "#9aa3b3")
    return sp


def oven():
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 4, 27, 30)
    box3d(cv, 4, 6, 27, 29, 6, "#3a3f4a", 0.35)
    for (x, y) in ((9, 8), (21, 8), (9, 11), (21, 11)):
        m = ellipse_mask(32, 32, x + 0.5, y + 0.5, 3, 1.5)
        cv.mask_fill(m, hexc("#1d1b22"))
    cv.rect(7, 17, 24, 26, hexc("#1d1b22"))
    cv.hline(8, 23, 18, hexc("#5a5f6a"))
    for x in range(7, 25, 4):
        lamp(sp, x, 14, "#ff8a3a")
    return sp


def fridge():
    sp = Sprite(32, 48)
    cv = sp.cv
    contact_shadow(cv, 5, 26, 46)
    p = box3d(cv, 5, 4, 26, 45, 4, "#e0e6ee", 0.3)
    cv.hline(6, 25, 20, p[1])
    cv.vline(23, 10, 18, p[1])
    cv.vline(23, 23, 40, p[1])
    lamp(sp, 8, 12, "#5ad0ff")
    return sp


def sink():
    sp = Sprite()
    cv = sp.cv
    box3d(cv, 6, 10, 25, 22, 3, "#c8d0dc", 0.3)
    basin = ellipse_mask(32, 32, 16, 16, 7, 3)
    cv.mask_fill(basin, hexc("#7a8ea0"))
    cv.vline(16, 7, 12, hexc("#9aa3b3"))
    cv.px(16, 7, hexc("#e8eef4"))
    return sp


def hydro_tray():
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 3, 28, 30)
    box3d(cv, 3, 12, 28, 29, 4, "#5a6a72", 0.4)
    soil = rrect_mask(32, 32, 5, 13, 26, 16, 1)
    cv.mask_fill(soil, hexc("#4a3526"))
    for x in range(6, 26, 3):
        cv.px(x, 14, hexc("#6a4a32"))
    lamp(sp, 25, 22, "#5aff7a")
    lamp(sp, 25, 25, "#5ad0ff")
    return sp


def plant(kind, stage):
    """Growth overlay for hydroponics trays (stage 0..4, 4 = harvestable)."""
    cv = Canvas()
    rng = rng_for(f"plant{kind}{stage}")
    leaf = ramp({"wheat": "#b8c84a", "tomato": "#4a9a3a", "potato": "#5a8a3a", "berry": "#3a8a6a", "lichen": "#3ad8b8"}[kind], 5, 0.45)
    h = [2, 5, 9, 12, 13][stage]
    for stem in range(3 + stage):
        x = 8 + stem * 16 // (3 + stage) + rng.randint(0, 2)
        for i in range(h):
            y = 14 - i
            xx = x + int(math.sin(i * 0.6 + stem) * 1.2)
            cv.px(xx, y, leaf[1 + (i % 3)])
            if i > 2 and i % 3 == 0:
                cv.px(xx - 1, y, leaf[3])
                cv.px(xx + 1, y - 1, leaf[2])
        if stage == 4:
            fruit = {"wheat": "#ffe07a", "tomato": "#e83a2a", "potato": "#c8a06a", "berry": "#7a4ae8", "lichen": "#aaffee"}[kind]
            cv.px(x, 14 - h, hexc(fruit))
            cv.px(x + 1, 14 - h + 1, shade(hexc(fruit), -0.3))
    return cv


def sleeper(occupied=False):
    sp = Sprite(64, 32)
    cv = sp.cv
    contact_shadow(cv, 4, 59, 30)
    box3d(cv, 4, 12, 59, 29, 4, "#d8dee6", 0.3)
    pod = rrect_mask(64, 32, 8, 6, 46, 20, 6)
    shaded_fill(cv, pod, "#9fd0ec", 0.4)
    for x in range(12, 44, 4):
        cv.px(x, 8, (1, 1, 1, 0.8))
    screen(sp, 49, 15, 57, 22, "#4ab8d8", rng_for("sleeper"), "graph")
    return sp


def med_bed():
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 4, 27, 30)
    box3d(cv, 4, 8, 27, 26, 4, "#e8eef4", 0.3)
    cv.hline(5, 26, 12, hexc("#4aa3d8"))
    for x in (6, 25):
        cv.vline(x, 27, 29, hexc("#6a7486"))
    return sp


def chem_dispenser():
    sp = Sprite(32, 40)
    cv = sp.cv
    rng = rng_for("chem")
    contact_shadow(cv, 4, 27, 38)
    box3d(cv, 4, 6, 27, 37, 4, "#e8eef4", 0.3)
    for i, col in enumerate(("#e84a4a", "#4ae86a", "#4ab8ff", "#ffd84a", "#e84ae8", "#e8e8e8")):
        x = 7 + i * 3
        sp.g(x, 13, hexc(col))
        sp.g(x, 14, shade(hexc(col), -0.3))
    screen(sp, 8, 18, 23, 24, "#5ad0ff", rng, "text")
    cv.rect(12, 28, 19, 34, hexc("#2a2e38"))
    return sp


def trash_bin():
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 9, 22, 29)
    body = rrect_mask(32, 32, 9, 12, 22, 28, 2)
    shaded_fill(cv, body, "#4a8a5a", 0.4)
    lid = ellipse_mask(32, 32, 16, 12, 7, 2.5)
    shaded_fill(cv, lid, "#5aa06a", 0.35)
    sel_outline(cv, 0.5)
    return sp


def disposal():
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 6, 25, 30)
    box3d(cv, 6, 8, 25, 29, 7, "#6a7486", 0.4)
    m = ellipse_mask(32, 32, 16, 11, 7, 3)
    cv.mask_fill(m, hexc("#101014"))
    lamp(sp, 22, 22, "#5aff7a")
    return sp


def potted_plant(v=0):
    sp = Sprite(32, 40)
    cv = sp.cv
    rng = rng_for(f"pot{v}")
    contact_shadow(cv, 10, 21, 38)
    pot = rrect_mask(32, 40, 10, 27, 21, 37, 2)
    shaded_fill(cv, pot, "#b8784a", 0.4)
    leaf = ramp("#3a8a4a" if v == 0 else "#2a7a6a", 5, 0.5)
    for i in range(28):
        a = rng.uniform(-2.6, -0.5)
        ln = rng.uniform(6, 16)
        x0, y0 = 15.5, 27
        for k in range(int(ln)):
            x = int(x0 + math.cos(a) * k + math.sin(k * 0.3) * 0.5)
            y = int(y0 + math.sin(a) * k)
            cv.px(x, y, leaf[min(4, 1 + k * 3 // int(ln) + (1 if a < -1.6 else 0))])
    sel_outline(cv, 0.5)
    return sp


def bookshelf():
    sp = Sprite(32, 48)
    cv = sp.cv
    rng = rng_for("books")
    contact_shadow(cv, 3, 28, 46)
    p = box3d(cv, 3, 6, 28, 45, 3, "#6a4630", 0.4)
    for shelf in range(4):
        y = 11 + shelf * 9
        cv.rect(5, y, 26, y + 7, hexc("#2a1c14"))
        x = 5
        while x < 26:
            w = rng.randint(1, 2)
            h = rng.randint(5, 7)
            col = hexc(["#8a2a33", "#2a5a8a", "#3a7a4a", "#c8a03a", "#6a4a8a", "#d8d0c0"][rng.randint(0, 5)])
            cv.rect(x, y + 7 - h, min(26, x + w - 1), y + 6, col)
            cv.px(x, y + 7 - h, shade(col, 0.4))
            x += w + (1 if rng.random() < 0.2 else 0)
        cv.hline(5, 26, y + 7, p[4])
    return sp


# ------------------------------------------------------------------ exterior props
def floodlight(on=True):
    sp = Sprite(32, 64)
    cv = sp.cv
    contact_shadow(cv, 11, 20, 62)
    # tripod base
    box3d(cv, 11, 55, 20, 61, 2, "#4a5060", 0.4)
    for y in range(12, 55):
        cv.px(15, y, hexc("#6a7486"))
        cv.px(16, y, hexc("#3e4452"))
    box3d(cv, 8, 4, 23, 12, 2, "#c8a03a", 0.4)
    if on:
        for x in range(10, 22):
            sp.g(x, 9, hexc("#fffbe8"))
            sp.g(x, 10, hexc("#ffe8b8"))
    # snow on top
    cv.hline(8, 23, 3, hexc("#f4f8ff"))
    cv.hline(9, 22, 4, hexc("#dce5f5"))
    return sp


def antenna():
    sp = Sprite(32, 64)
    cv = sp.cv
    contact_shadow(cv, 9, 22, 62)
    box3d(cv, 10, 54, 21, 61, 2, "#4a5060", 0.4)
    for y in range(8, 54):
        cv.px(15, y, hexc("#9aa3b3"))
        cv.px(16, y, hexc("#5a6272"))
        if y % 6 == 0:
            cv.hline(13, 18, y, hexc("#7a8494"))
    dish = ellipse_mask(32, 64, 16, 14, 9, 4)
    shaded_fill(cv, dish, "#d8dee6", 0.4)
    lamp(sp, 16, 5, "#ff3a2a")
    return sp


def drift(v):
    """Soft snow mound decoration."""
    cv = Canvas(64, 32)
    rng = rng_for(f"drift{v}")
    snow = [hexc(h) for h in ("#8b9dc8", "#a9b9dd", "#c5d2ec", "#dce5f5", "#edf2fb", "#fafcff")]
    cx, cy = 32, 20
    rx, ry = 24 + rng.randint(-4, 4), 9 + rng.randint(-2, 2)
    for y in range(32):
        for x in range(64):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            wob = math.sin(x * 0.3 + v) * 0.08
            d = dx * dx + dy * dy
            if d < 1 + wob:
                h = 1 - d
                lit = -dx * 0.35 - dy * 0.9
                v2 = 0.45 + lit * 0.45 + h * 0.2
                i = int(np.clip(v2 * 6, 0, 5))
                cv.px(x, y, snow[i])
    # soft shadow on the lower right
    for y in range(32):
        for x in range(64):
            dx = (x + 0.5 - cx - 3) / rx
            dy = (y + 0.5 - cy - 2) / ry
            if dx * dx + dy * dy < 1 and cv.get(x, y)[3] == 0:
                cv.px(x, y, (0.35, 0.42, 0.62, 0.25))
    return cv


def ice_crystal(v):
    sp = Sprite(32, 40)
    cv = sp.cv
    rng = rng_for(f"crys{v}")
    contact_shadow(cv, 8, 23, 38)
    pal = [hexc(h) for h in ("#1f6f8f", "#2aa3c8", "#5ad8f0", "#aaf4ff", "#eafcff")]
    for k in range(rng.randint(3, 5)):
        bx = rng.randint(10, 21)
        h = rng.randint(10, 26)
        w = rng.randint(2, 3)
        lean = rng.uniform(-0.3, 0.3)
        for i in range(h):
            y = 37 - i
            x0 = int(bx + lean * i)
            ww = max(1, int(w * (1 - i / h) + 0.7))
            for dx in range(-ww, ww + 1):
                col = pal[2] if dx < 0 else (pal[1] if dx > 0 else pal[3])
                if i == h - 1:
                    col = pal[4]
                cv.px(x0 + dx, y, col)
                if dx == 0 and i % 3 == 0:
                    sp.glow.px(x0 + dx, y, pal[3])
                    sp.has_glow = True
    sel_outline(cv, 0.4)
    return sp


def boulder(v):
    sp = Sprite()
    cv = sp.cv
    rng = rng_for(f"boulder{v}")
    contact_shadow(cv, 5, 26, 29)
    m = ellipse_mask(32, 32, 16, 20, 10 + rng.randint(-2, 2), 8)
    n = (fbm(32, 32, v * 11, 3, 8) - 0.5) * 0.3
    shaded_fill(cv, m, "#5d6576", 0.55, noise=n)
    # snow cap
    cap = ellipse_mask(32, 32, 15, 15, 8, 4) & m
    cv.mask_fill(cap, hexc("#edf2fb"))
    cap2 = ellipse_mask(32, 32, 14, 14, 5, 2) & m
    cv.mask_fill(cap2, hexc("#fafcff"))
    sel_outline(cv, 0.5)
    return sp


def lichen(v):
    """Bioluminescent frost lichen — soft cyan glow patches on snow."""
    sp = Sprite()
    rng = rng_for(f"lichen{v}")
    pal = [hexc(h) for h in ("#1a8a8a", "#2ad8c8", "#8affee")]
    for _ in range(rng.randint(5, 9)):
        cx, cy = rng.randint(6, 25), rng.randint(6, 25)
        for k in range(rng.randint(3, 7)):
            x = cx + rng.randint(-2, 2)
            y = cy + rng.randint(-2, 2)
            c = pal[rng.randint(0, 2)]
            sp.cv.px(x, y, c)
            if c is not pal[0]:
                sp.glow.px(x, y, c)
                sp.has_glow = True
    return sp


def supply_pod():
    sp = Sprite(64, 48)
    cv = sp.cv
    contact_shadow(cv, 8, 55, 46)
    body = rrect_mask(64, 48, 10, 10, 53, 45, 6)
    shaded_fill(cv, body, "#8a93a3", 0.45)
    for y in range(22, 27):
        for x in range(10, 54):
            if body[y, x]:
                cv.px(x, y, hexc("#c8a03a") if ((x + y) // 3) % 2 else hexc("#1d1b22"))
    lamp(sp, 30, 14, "#ff3a2a")
    lamp(sp, 33, 14, "#ff3a2a")
    # scorch + snow piled around
    for x in range(8, 56):
        if (x * 7) % 5 < 3:
            cv.px(x, 44, hexc("#f4f8ff"))
    sel_outline(cv, 0.5)
    return sp


def fence(mask):
    cv = Canvas()
    p = ramp("#6a7486", 5, 0.4)
    for bit, (x0, y0, x1, y1) in ((E, (16, 20, 31, 20)), (W, (0, 20, 16, 20)), (N, (16, 0, 16, 20)), (S, (16, 20, 16, 31))):
        if mask & bit:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    cv.px(x, y, p[3])
                    cv.px(x, y - 6 if x0 != x1 else y, p[3])
    for y in range(10, 26):
        cv.px(16, y, p[2])
        cv.px(17, y, p[0])
    cv.px(16, 9, hexc("#f4f8ff"))
    return cv


def girder():
    sp = Sprite()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    for x in (4, 5, 26, 27):
        cv.vline(x, 6, 29, p[2 if x % 2 == 0 else 1])
    for y in (6, 7, 17, 18, 28, 29):
        cv.hline(4, 27, y, p[3 if y % 2 == 0 else 1])
    for i in range(20):
        cv.px(6 + i, 8 + i // 2, p[2])
    return sp


def grille(broken=False, damaged=False):
    """broken: tg "brokengrille" (bent open, walkable). damaged: tg "grille50_x", a few rods
    bent out of line once it's under half integrity."""
    cv = Canvas()
    p = ramp("#7a8494", 5, 0.4)
    for x in range(2, 31, 4):
        bend = damaged and x in (10, 22)
        for y in range(2, 30):
            if broken and (x * y) % 7 < 2:
                continue
            if damaged and x in (14, 18) and 11 <= y <= 20:
                continue  # snapped rods
            dx = int(round(3 * np.sin((y - 2) / 28 * np.pi))) * (-1 if x == 10 else 1) if bend else 0
            cv.px(x + dx, y, p[2])
            cv.px(x + dx + 1, y, p[0])
    for y in range(2, 31, 4):
        for x in range(2, 30):
            if broken and (x * y) % 5 < 1:
                continue
            if damaged and y in (14, 18) and 12 <= x <= 21:
                continue
            cv.px(x, y, p[3])
    return cv


# ------------------------------------------------------------------ decals
def decal_glass(v):
    """tg /obj/effect/decal/cleanable/glass: the tiny shards a shattered pane leaves on the floor."""
    cv = Canvas()
    rng = rng_for(f"glassdebris{v}")
    body = hexc("#c4e8fa", 0.9)
    edge = hexc("#16283a", 0.7)
    glint = hexc("#ffffff", 1.0)
    for _ in range(12 + v * 3):
        x, y = rng.randint(4, 27), rng.randint(6, 28)
        ln = rng.randint(1, 3)
        dx, dy = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
        for k in range(ln):
            cv.px(x + dx * k, y + dy * k, body)
        cv.px(x + dx * ln, y + dy * ln + 1, edge)
        if rng.random() < 0.3:
            cv.px(x, y, glint)
    return cv


def decal_blood(v):
    cv = Canvas()
    rng = rng_for(f"blood{v}")
    p = [hexc(h) for h in ("#4a0a12", "#7a121e", "#a81e2a")]
    cx, cy = rng.randint(12, 20), rng.randint(12, 20)
    m = np.zeros((32, 32), bool)
    for _ in range(6):
        ox, oy = cx + rng.randint(-5, 5), cy + rng.randint(-5, 5)
        m |= ellipse_mask(32, 32, ox, oy, rng.uniform(1.5, 4.5), rng.uniform(1.5, 3.5))
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        cv.px(x, y, p[1])
    for _ in range(8):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(7, 12)
        cv.px(int(cx + math.cos(a) * r), int(cy + math.sin(a) * r), p[2])
    sel_outline(cv, color=p[0])
    cv.px(cx - 1, cy - 1, p[2])
    return cv


def decal_puddle(kind="water", v=0):
    cv = Canvas()
    rng = rng_for(f"pud{kind}{v}")
    col = {"water": ("#6aa8d8", 0.45), "vomit": ("#9aa83a", 0.85), "oil": ("#1d1b22", 0.8), "coolant": ("#3ad0d8", 0.55)}[kind]
    m = np.zeros((32, 32), bool)
    for _ in range(5):
        m |= ellipse_mask(32, 32, 16 + rng.randint(-6, 6), 16 + rng.randint(-5, 5), rng.uniform(3, 7), rng.uniform(2, 5))
    base = hexc(col[0], col[1])
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        cv.px(x, y, base)
    for _ in range(4):
        x, y = rng.randint(8, 24), rng.randint(8, 24)
        if m[y, x]:
            cv.px(x, y, hexc("#ffffff", 0.6))
    return cv


def decal_liquid(kind, size):
    """Spreading liquid puddle; size 0 small splash .. 2 fills the tile."""
    cv = Canvas()
    rng = rng_for(f"liq{kind}{size}")
    col = {"water": ("#6aa8d8", 0.45), "vomit": ("#9aa83a", 0.85), "oil": ("#1d1b22", 0.8),
           "coolant": ("#3ad0d8", 0.55), "fuel": ("#b8903a", 0.6), "ice": ("#cfe8fa", 0.7),
           "blood": ("#8a121e", 0.8)}[kind]
    m = np.zeros((32, 32), bool)
    blobs, rx, ry, spread = [(3, 4, 3, 3), (5, 7, 5, 6), (8, 10, 8, 9)][size]
    for _ in range(blobs):
        m |= ellipse_mask(32, 32, 16 + rng.randint(-spread, spread), 16 + rng.randint(-spread, spread),
                          rng.uniform(rx * 0.6, rx), rng.uniform(ry * 0.6, ry))
    base = hexc(col[0], col[1])
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        cv.px(x, y, base)
    edge = hexc(col[0], min(1.0, col[1] + 0.2))
    for y, x in zip(ys, xs):
        if not (m[max(0, y - 1), x] and m[min(31, y + 1), x] and m[y, max(0, x - 1)] and m[y, min(31, x + 1)]):
            cv.px(x, y, shade(edge, -0.15) if kind != "ice" else hexc("#ffffff", 0.8))
    shine = "#ffffff"
    for _ in range(2 + size * 3):
        x, y = rng.randint(4, 27), rng.randint(4, 27)
        if m[y, x]:
            cv.px(x, y, hexc(shine, 0.6))
            if kind == "ice" and x + 1 < 32 and m[y, x + 1]:
                cv.px(x + 1, y, hexc(shine, 0.45))
    if kind == "ice":
        for _ in range(size + 1):
            x0, y0 = rng.randint(8, 22), rng.randint(8, 22)
            for k in range(rng.randint(3, 6)):
                if m[min(31, y0 + k // 2), min(31, x0 + k)]:
                    cv.px(x0 + k, y0 + k // 2, hexc("#8ab0cc", 0.7))
    return cv


def mouse(d, dead=False, tail_phase=0):
    """A small grey mouse (tinted in engine). d in e/w/n/s."""
    cv = Canvas()
    body = hexc("#b8b4b0")
    dark = hexc("#7a7672")
    light = hexc("#e4e0dc")
    pink = hexc("#e8a0a8")
    eye = hexc("#1a1418")
    if dead:
        # on its back, feet in the air
        m = ellipse_mask(32, 32, 16, 27, 5, 2.5)
        cv.mask_fill(m, body)
        cv.hline(13, 19, 26, light)
        for fx in (13, 15, 17, 19):
            cv.px(fx, 24, pink)
        cv.px(21, 26, pink)
        cv.px(22, 27, eye)
        cv.line(10, 28, 6, 29, pink)
        sel_outline(cv, color=hexc("#2a2628"))
        return cv
    if d in ("e", "w"):
        m = ellipse_mask(32, 32, 15, 27, 5, 2.6)
        m |= ellipse_mask(32, 32, 20, 26.5, 2.6, 2.0)
        cv.mask_fill(m, body)
        cv.hline(12, 18, 29, dark)
        cv.hline(12, 17, 25, light)
        cv.px(22, 27, pink)  # nose
        cv.px(21, 26, eye)
        cv.px(18, 24, pink)  # ear
        cv.px(19, 24, body)
        cv.px(13, 29, pink)
        cv.px(18, 29, pink)
        ty = 28 if tail_phase == 0 else 27
        cv.line(10, 28, 7, ty, pink)
        cv.line(7, ty, 5, ty - 1, pink)
        sel_outline(cv, color=hexc("#2a2628"))
        return cv.flip_h() if d == "w" else cv
    # facing north (away) or south (towards the viewer)
    m = ellipse_mask(32, 32, 16, 26, 3.2, 4.2)
    cv.mask_fill(m, body)
    if d == "s":
        cv.px(14, 22, pink)
        cv.px(18, 22, pink)
        cv.px(15, 25, eye)
        cv.px(17, 25, eye)
        cv.px(16, 27, pink)
        cv.vline(16, 29, 30, light)
    else:
        cv.px(14, 23, pink)
        cv.px(18, 23, pink)
        cv.vline(16, 29, 31, pink)
        cv.hline(15, 17, 24, dark)
    sel_outline(cv, color=hexc("#2a2628"))
    return cv


def decal_scorch(v):
    cv = Canvas()
    rng = rng_for(f"scorch{v}")
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 16, y - 16) / 14
            n = rng.random() * 0.4
            a = max(0, 1 - d - n) * 0.8
            if a > 0.05:
                cv.px(x, y, (0.06, 0.05, 0.05, a))
    return cv


def footprints(d, snow=False):
    cv = Canvas()
    col = (0.62, 0.7, 0.86, 0.9) if snow else (0.1, 0.1, 0.12, 0.25)
    hi = (1, 1, 1, 0.8) if snow else None
    pts = [(12, 8), (19, 20)] if d in ("n", "s") else [(8, 13), (20, 19)]
    for (x, y) in pts:
        if d in ("n", "s"):
            for yy in range(y, y + 5):
                cv.hline(x, x + 1, yy, col)
            if hi:
                cv.hline(x, x + 1, y + (5 if d == "n" else -1), hi)
        else:
            for xx in range(x, x + 5):
                cv.vline(xx, y, y + 1, col)
            if hi:
                cv.vline(x + (5 if d == "w" else -1), y, y + 1, hi)
    return cv


def hazard_stripe():
    cv = Canvas()
    for y in range(32):
        for x in range(32):
            if y < 3 or y > 28:
                cv.px(x, y, hexc("#e0b23a", 0.85) if ((x + y) // 4) % 2 else hexc("#1d1b22", 0.85))
    return cv


def dept_edge(color):
    """Coloured trim line along the top edge of a floor tile (rotated in engine)."""
    cv = Canvas()
    p = ramp(color, 3, 0.3)
    cv.hline(0, 31, 1, np.append(p[2][:3], 0.9))
    cv.hline(0, 31, 2, np.append(p[1][:3], 0.9))
    cv.hline(0, 31, 3, np.append(p[0][:3], 0.6))
    return cv


def rotated(cv, side):
    """Turn a top-edge decal to face another side: n (as drawn), e, s or w."""
    k = {"n": 0, "e": -1, "s": 2, "w": 1}[side]
    return Canvas.from_array(np.rot90(cv.a, k).copy())


def hazard_edge():
    """Yellow-black caution stripes along the top edge of a tile (tg's loading-area border)."""
    cv = Canvas()
    for y in range(0, 5):
        for x in range(32):
            on = ((x + y) // 3) % 2 == 0
            cv.px(x, y, hexc("#e8b83a", 0.92) if on else hexc("#1d1b22", 0.9))
    cv.hline(0, 31, 5, hexc("#000000", 0.25))
    return cv


def hazard_hatch():
    """Faint diagonal hatching inside a hazard zone."""
    cv = Canvas()
    for y in range(32):
        for x in range(32):
            if (x + y) % 8 < 2:
                cv.px(x, y, hexc("#e8b83a", 0.13))
    return cv


# ------------------------------------------------------------------ packer
# ------------------------------------------------------------------ evacuation crawler
def crawler_engine():
    """Diesel-electric drive unit at the back of the crawler."""
    sp = Sprite()
    cv = sp.cv
    contact_shadow(cv, 3, 28, 30)
    box3d(cv, 3, 8, 28, 29, 6, "#5a6272", 0.4)
    o = ramp("#c8622e", 5, 0.4)
    cv.rect(6, 17, 25, 21, o[2])  # orange housing band
    cv.hline(6, 25, 17, o[4])
    for x in range(7, 25, 3):  # cooling fins
        cv.vline(x, 23, 27, hexc("#2a2e38"))
    # exhaust stack
    ex = ramp("#3a3f4a", 5, 0.4)
    cv.rect(21, 2, 24, 9, ex[2])
    cv.vline(21, 2, 9, ex[3])
    cv.hline(20, 25, 2, ex[4])
    for x in range(8, 16):  # intake grille glowing with heat
        sp.g(x, 11, hexc("#ff7a2a") if x % 2 else hexc("#c8401a"))
    lamp(sp, 26, 19, "#5aff7a")
    return sp


def tread(part, horizontal=False):
    """Top-down caterpillar track segment: mid, or an end ('a' = start, 'b' = end)."""
    cv = Canvas()
    rub = ramp("#2c2a30", 5, 0.5)
    stl = ramp("#8a93a3", 5, 0.45)
    y0 = 3 if part == "a" else 0
    y1 = 28 if part == "b" else 31
    for y in range(y0, y1 + 1):
        for x in range(5, 27):
            i = 2
            if (y + 1) % 5 == 0:
                i = 4  # cleat
            elif y % 5 == 0:
                i = 1
            if x in (5, 26):
                i = 0
            cv.px(x, y, rub[i])
        # side rails with bogie wheels peeking out
        cv.px(4, y, stl[1])
        cv.px(27, y, stl[1])
    for y in range(y0 + 4, y1 - 2, 10):
        for x in (3, 4, 27, 28):
            cv.px(x, y, stl[3])
            cv.px(x, y + 1, stl[2])
    if part in ("a", "b"):
        yy = y0 if part == "a" else y1
        for x in range(7, 25):
            cv.px(x, yy, rub[0])
        sprocket = ellipse_mask(32, 32, 16, yy + (3 if part == "a" else -3), 4, 3)
        shaded_fill(cv, sprocket, "#8a93a3", 0.4)
    if horizontal:
        cv.a = cv.a.transpose(1, 0, 2).copy()
    return cv


class Packer:
    def __init__(self, width=1024):
        self.width = width
        self.items = []

    def add(self, name, spr):
        if isinstance(spr, Sprite):
            self.items.append((name, spr.cv))
            if spr.has_glow:
                self.items.append((name + "_glow", spr.glow))
        else:
            self.items.append((name, spr))

    def replace(self, name, spr):
        """Swap a sprite (and its glow layer) for a new drawing, keeping its name."""
        old = dict(self.items)
        if name not in old:
            raise KeyError(name)
        cv = spr.cv if isinstance(spr, Sprite) else spr
        if (cv.w, cv.h) != (old[name].w, old[name].h):
            raise ValueError(f"{name}: redraw changed sprite size")
        had_glow = name + "_glow" in old
        self.items = [it for it in self.items if it[0] not in (name, name + "_glow")]
        self.items.append((name, cv))
        if had_glow:
            glow = spr.glow if isinstance(spr, Sprite) and spr.has_glow else Canvas(cv.w, cv.h)
            self.items.append((name + "_glow", glow))

    def pack(self):
        # shelf pack, tallest first
        order = sorted(self.items, key=lambda it: (-it[1].h, it[0]))
        x = y = shelf_h = 0
        placed = {}
        for name, cv in order:
            if x + cv.w > self.width:
                x = 0
                y += shelf_h
                shelf_h = 0
            placed[name] = (x, y, cv.w, cv.h)
            x += cv.w
            shelf_h = max(shelf_h, cv.h)
        H = y + shelf_h
        sheet = Canvas(self.width, H)
        lookup = dict(self.items)
        for name, (px, py, w, h) in placed.items():
            sheet.paste(lookup[name], px, py)
        return sheet, placed


def build(manifest):
    from common import save
    pk = Packer()
    from sky_objects import build_into as sky_objects_build
    sky_objects_build(pk)
    for dept in DEPT:
        for f in range(4):
            pk.add(f"airlock_{dept}_{f}", airlock(dept, f, glass=dept not in ("maint", "ext", "sec")))
    pk.add("apc", apc())
    pk.add("air_alarm", air_alarm())
    pk.add("fire_alarm", fire_alarm())
    pk.add("light_on", light_fixture(True))
    pk.add("light_off", light_fixture(False))
    pk.add("light_broken", light_fixture(True, True))
    pk.add("emergency_light", emergency_light())
    pk.add("extinguisher_cabinet", extinguisher_cabinet(True))
    pk.add("extinguisher_cabinet_empty", extinguisher_cabinet(False))
    pk.add("intercom", intercom())
    pk.add("status_display", status_display())
    pk.add("vent", vent())
    pk.add("vent_welded", vent(welded=True))
    pk.add("scrubber", scrubber())
    for layer in PIPE_COLS:
        for m in range(16):
            pk.add(f"pipe_{layer}_{m}", pipe(layer, m))
    pk.add("pipe_leak", pipe("gen", 0, True))
    # tintable pipes for tg's coloured lines, one set per piping layer (drawn modulated)
    for tl in (2, 3, 4, 5):
        for m in range(1, 16):
            pk.add(f"pipe_t{tl}_{m}", pipe("gen", m, base="#eef0f4", off=TG_LAYER_OFF[tl]))
    pk.add("pipe_link", pipe_link())
    pk.add("pipe_dispenser", pipe_dispenser())
    for m in range(16):
        pk.add(f"cable_{m}", cable(m))
    pk.add("valve_open", valve(True))
    pk.add("valve_closed", valve(False))
    pk.add("pump_on", pump(True))
    pk.add("pump_off", pump(False))
    pk.add("connector", connector())
    pk.add("recharger", recharger(False))
    pk.add("recharger_on", recharger(True))
    for layer in ("supply", "scrub", "gen", "aux"):
        for kind in ("pump", "vpump", "valve", "filter", "mixer", "gate"):
            pk.add(f"{kind}_{layer}_on", pipe_machine(kind, layer, True))
            pk.add(f"{kind}_{layer}_off", pipe_machine(kind, layer, False))
    for fr in (False, True):
        for on in (False, True):
            pk.add(f"thermo_{'freezer' if fr else 'heater'}_{'on' if on else 'off'}", thermomachine(fr, on))
    pk.add("reactor", reactor())
    pk.add("teg", teg())
    pk.add("smes", smes())
    pk.add("generator", generator_portable(False))
    pk.add("generator_on", generator_portable(True))
    pk.add("radiator", radiator())
    pk.add("heater_on", heater(True))
    pk.add("heater_off", heater(False))
    for k in ("o2", "n2", "air", "plasma", "co2", "empty", "n2o", "h2o"):
        pk.add(f"canister_{k}", canister(k))
    from objects_v2 import CANISTER, canister as detailed_canister
    for k in CANISTER:
        if k not in ("o2", "n2", "air", "plasma", "co2", "empty", "n2o", "h2o"):
            pk.add(f"canister_{k}", detailed_canister(k))
    for kd in ("pump", "scrubber"):
        pk.add(f"portable_{kd}", portable_atmos(kd, False))
        pk.add(f"portable_{kd}_on", portable_atmos(kd, True))
    pk.add("injector", injector(True))
    pk.add("injector_off", injector(False))
    pk.add("vent_siphon", vent_siphon())
    pk.add("passive_vent", passive_vent())
    pk.add("pipe_tank", pipe_tank())
    for lv in range(5):
        pk.add(f"meter_{lv}", meter(lv))
    for k in ("eng", "med", "sec", "sci", "cmd", "reactor", "cargo", "atmos", "comms"):
        pk.add(f"console_{k}", console(k))
    for k in ("snack", "cocoa", "drink", "med", "tool", "winter"):
        pk.add(f"vending_{k}", vending(k))
    for k in ("eng", "med", "sec", "sci", "gen", "emerg", "fire", "winter", "cmd"):
        pk.add(f"locker_{k}", locker(k))
        pk.add(f"locker_{k}_open", locker(k, True))
    for k in ("gen", "eng", "med", "sec", "food", "sci"):
        pk.add(f"crate_{k}", crate(False, k))
        pk.add(f"crate_{k}_open", crate(True, k))
    for k in TABLE_COLS:
        pk.add(f"table_{k}", table(k))
        for m in range(16):
            pk.add(f"table_{k}_{m}", table(k, m))
    for k in ("steel", "office", "wood", "comfy", "shuttle"):
        for d in "nesw":
            pk.add(f"chair_{k}_{d}", chair(d, k))
    for i, col in enumerate(("#3a6ad8", "#c83a3a", "#4a9a6a", "#d8a53a", "#8a5ac8", "#e8eef4")):
        pk.add(f"bed_{i}", bed(col))
    pk.add("microwave", microwave(False))
    pk.add("microwave_on", microwave(True))
    pk.add("oven", oven())
    pk.add("fridge", fridge())
    pk.add("sink", sink())
    pk.add("hydro_tray", hydro_tray())
    for k in ("wheat", "tomato", "potato", "berry", "lichen"):
        for st in range(5):
            pk.add(f"plant_{k}_{st}", plant(k, st))
    pk.add("sleeper", sleeper())
    pk.add("med_bed", med_bed())
    pk.add("chem_dispenser", chem_dispenser())
    pk.add("trash_bin", trash_bin())
    pk.add("disposal", disposal())
    for v in range(2):
        pk.add(f"potted_plant_{v}", potted_plant(v))
    pk.add("bookshelf", bookshelf())
    pk.add("floodlight", floodlight(True))
    pk.add("floodlight_off", floodlight(False))
    pk.add("antenna", antenna())
    for v in range(4):
        pk.add(f"drift_{v}", drift(v))
    for v in range(3):
        pk.add(f"ice_crystal_{v}", ice_crystal(v))
        pk.add(f"boulder_{v}", boulder(v))
        pk.add(f"lichen_{v}", lichen(v))
    pk.add("supply_pod", supply_pod())
    pk.add("fuel_tank", fuel_tank())
    pk.add("fuel_tank_open", fuel_tank(True))
    for m in range(16):
        pk.add(f"fence_{m}", fence(m))
    pk.add("girder", girder())
    pk.add("grille", grille())
    pk.add("grille_broken", grille(True))
    pk.add("grille_damaged", grille(damaged=True))
    for v in range(3):
        pk.add(f"blood_{v}", decal_blood(v))
        pk.add(f"glass_debris_{v}", decal_glass(v))
        pk.add(f"scorch_{v}", decal_scorch(v))
    for k in ("water", "vomit", "oil", "coolant"):
        pk.add(f"puddle_{k}", decal_puddle(k))
    for k in ("water", "vomit", "oil", "coolant", "fuel", "ice", "blood"):
        for sz in range(3):
            pk.add(f"liquid_{k}_{sz}", decal_liquid(k, sz))
    for d in "nesw":
        pk.add(f"mouse_{d}", mouse(d))
    pk.add("mouse_e_1", mouse("e", tail_phase=1))
    pk.add("mouse_w_1", mouse("w", tail_phase=1))
    pk.add("mouse_dead", mouse("e", dead=True))
    for d in "nesw":
        pk.add(f"footprints_{d}", footprints(d))
        pk.add(f"snowprints_{d}", footprints(d, True))
    pk.add("hazard_stripe", hazard_stripe())
    pk.add("crawler_engine", crawler_engine())
    for part in ("a", "mid", "b"):
        pk.add(f"tread_v_{part}", tread(part))
        pk.add(f"tread_h_{part}", tread(part, True))
    for dept, col in (("eng", "#d8a53a"), ("med", "#4ab8d8"), ("sec", "#d84a4a"), ("sci", "#a87ae8"), ("cmd", "#4a8ad8"), ("srv", "#5ac87a"), ("cargo", "#c8883a")):
        pk.add(f"edge_{dept}", dept_edge(col))
        for side in "nesw":
            pk.add(f"edge_{dept}_{side}", rotated(dept_edge(col), side))
    for side in "nesw":
        pk.add(f"hazard_{side}", rotated(hazard_edge(), side))
    pk.add("hazard_hatch", hazard_hatch())
    import decor
    decor.add_all(pk)
    import decor2
    decor2.add_all(pk)
    import tgport
    tgport.add_objects(pk)
    import objects_v2
    objects_v2.apply(pk)
    import theme
    theme.apply(pk)
    import props_fx
    props_fx.finish_objects(pk)
    sheet, placed = pk.pack()
    save(sheet, "objects.png")
    manifest["objects"] = {k: list(v) for k, v in placed.items()}
